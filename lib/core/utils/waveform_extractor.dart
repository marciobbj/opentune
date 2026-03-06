import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:just_waveform/just_waveform.dart';

import 'ffmpeg_manager.dart';

class WaveformExtractor {
  static const int _ffmpegSampleRate = 2000;
  static const int _cacheVersion = 2;

  static Future<List<double>> extract(String filePath, {int bins = 300}) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return _generateEmpty(bins);
      }

      final stat = await file.stat();
      final cached = await _readCache(filePath, bins, stat);
      if (cached != null) {
        return cached;
      }

      late final List<double> waveform;

      // Use native decoders for mobile platforms via just_waveform,
      // or macOS if supported. For desktop (Linux/Windows), fallback to FFMPEG.
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        waveform = await _extractViaNative(filePath, bins);
      } else {
        waveform = await _extractViaFFmpeg(filePath, bins);
      }

      if (_isCacheable(waveform)) {
        await _writeCache(filePath, bins, stat, waveform);
      }

      return waveform;
    } catch (e) {
      return _generateEmpty(bins);
    }
  }

  static Future<List<double>> _extractViaNative(
    String filePath,
    int bins,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      path.join(
        tempDir.path,
        'temp_waveform_${DateTime.now().millisecondsSinceEpoch}.wave',
      ),
    );

    try {
      final progressStream = JustWaveform.extract(
        audioInFile: File(filePath),
        waveOutFile: tempFile,
        zoom: const WaveformZoom.pixelsPerSecond(100),
      );

      Waveform? extractedWaveform;
      await for (final progress in progressStream) {
        if (progress.progress == 1.0 && progress.waveform != null) {
          extractedWaveform = progress.waveform;
        }
      }

      if (extractedWaveform != null) {
        return await Isolate.run(() {
          return _processJustWaveform(extractedWaveform!, bins);
        });
      }
    } catch (e) {
      // Return empty if extraction fails
    } finally {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    }
    return _generateEmpty(bins);
  }

  static Future<List<double>> _extractViaFFmpeg(
    String filePath,
    int bins,
  ) async {
    // Resolve FFmpeg path: prefer locally downloaded binary, fall back to PATH
    final manager = FfmpegManager.instance;
    await manager.initialize();
    final ffmpeg = manager.ffmpegPath ?? 'ffmpeg';

    final tempDir = await getTemporaryDirectory();
    final pcmFile = File(
      path.join(
        tempDir.path,
        'temp_waveform_pcm_${DateTime.now().millisecondsSinceEpoch}.raw',
      ),
    );

    try {
      final result = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-y',
        '-i',
        filePath,
        '-ac',
        '1',
        '-ar',
        '$_ffmpegSampleRate',
        '-map',
        '0:a',
        '-c:a',
        'pcm_s16le',
        '-f',
        's16le',
        pcmFile.path,
      ], stdoutEncoding: null);

      if (result.exitCode != 0 || !await pcmFile.exists()) {
        return _generateEmpty(bins);
      }

      final byteLength = await pcmFile.length();
      final totalSamples = byteLength ~/ Int16List.bytesPerElement;
      if (totalSamples <= 0) {
        return _generateEmpty(bins);
      }

      return await _processPcmFile(pcmFile.path, bins, totalSamples);
    } finally {
      if (await pcmFile.exists()) {
        try {
          await pcmFile.delete();
        } catch (_) {}
      }
    }
  }

  static List<double> _processJustWaveform(Waveform waveform, int bins) {
    if (waveform.length == 0) return _generateEmpty(bins);

    final int pixelsPerBin = waveform.length ~/ bins;
    if (pixelsPerBin == 0) return _generateEmpty(bins);

    final List<double> raw = List.filled(bins, 0.0);
    double maxAmplitude = 0.0;

    for (int i = 0; i < bins; i++) {
      int start = i * pixelsPerBin;
      int end = (i == bins - 1) ? waveform.length : (i + 1) * pixelsPerBin;

      double sum = 0.0;
      for (int j = start; j < end; j++) {
        final double maxVal = waveform.getPixelMax(j).abs().toDouble();
        final double minVal = waveform.getPixelMin(j).abs().toDouble();
        sum += math.max(maxVal, minVal);
      }

      final double avg = sum / (end - start);
      raw[i] = avg;
      if (avg > maxAmplitude) maxAmplitude = avg;
    }

    if (maxAmplitude <= 0) return _generateEmpty(bins);

    return _normalize(raw);
  }

  /// Adaptive normalization that adjusts contrast based on the audio's
  /// dynamic range.
  ///
  /// For dynamic audio (big difference between quiet and loud parts),
  /// preserves the real proportions. For compressed/loud audio (everything
  /// near the peak), applies a stronger power curve to reveal variation
  /// that would otherwise look like a flat wall.
  static List<double> _normalize(List<double> raw) {
    final int n = raw.length;
    if (n == 0) return raw;

    double peak = 0.0;
    for (int i = 0; i < n; i++) {
      if (raw[i] > peak) peak = raw[i];
    }

    if (peak <= 0) {
      return List.filled(n, 0.05);
    }

    // Normalize to 0–1 by peak
    for (int i = 0; i < n; i++) {
      raw[i] = raw[i] / peak;
    }

    // Measure how compressed the audio is using the 10th percentile.
    // High p10 = compressed (everything loud), low p10 = dynamic.
    final sorted = List<double>.from(raw)..sort();
    final double p10 = sorted[(n * 0.10).floor()];

    // Adaptive exponent:
    //   p10 ≈ 0   (dynamic)    → exponent ≈ 0.9  (gentle lift for quiet parts)
    //   p10 ≈ 0.5 (moderate)   → exponent ≈ 1.5
    //   p10 ≈ 0.8 (compressed) → exponent ≈ 2.2  (spread out the top cluster)
    final double exponent = 0.9 + p10 * 1.6;

    for (int i = 0; i < n; i++) {
      raw[i] = math.pow(raw[i], exponent).toDouble().clamp(0.05, 1.0);
    }

    return raw;
  }

  static List<double> _generateEmpty(int bins) {
    return List.filled(bins, 0.05);
  }

  static Future<List<double>> _processPcmFile(
    String pcmFilePath,
    int bins,
    int totalSamples,
  ) async {
    return Isolate.run(() async {
      if (totalSamples <= 0) return _generateEmpty(bins);

      final pcmFile = File(pcmFilePath);

      final int samplesPerBin = totalSamples ~/ bins;
      if (samplesPerBin == 0) return _generateEmpty(bins);

      const int subWindows = 4;
      final fullSumSq = List<double>.filled(bins, 0.0);
      final fullCounts = List<int>.filled(bins, 0);
      final subSumSq = List<double>.filled(bins * subWindows, 0.0);
      final subCounts = List<int>.filled(bins * subWindows, 0);

      var sampleIndex = 0;
      int? carryByte;

      void addSample(int rawSample) {
        var bin = sampleIndex ~/ samplesPerBin;
        if (bin >= bins) bin = bins - 1;

        final sample = rawSample / 32768.0;
        final squared = sample * sample;
        fullSumSq[bin] += squared;
        fullCounts[bin] += 1;

        final relativeIndex = sampleIndex - (bin * samplesPerBin);
        final subIndex = ((relativeIndex * subWindows) ~/ samplesPerBin).clamp(
          0,
          subWindows - 1,
        );
        final offset = bin * subWindows + subIndex;
        subSumSq[offset] += squared;
        subCounts[offset] += 1;

        sampleIndex += 1;
      }

      await for (final chunk in pcmFile.openRead()) {
        final bytes = Uint8List.fromList(chunk);
        var offset = 0;

        if (carryByte != null && bytes.isNotEmpty) {
          final value = carryByte | (bytes[0] << 8);
          addSample(value >= 0x8000 ? value - 0x10000 : value);
          carryByte = null;
          offset = 1;
        }

        for (int i = offset; i + 1 < bytes.length; i += 2) {
          final value = bytes[i] | (bytes[i + 1] << 8);
          addSample(value >= 0x8000 ? value - 0x10000 : value);
        }

        if ((bytes.length - offset).isOdd) {
          carryByte = bytes.last;
        }
      }

      final raw = List<double>.filled(bins, 0.0);
      double maxAmplitude = 0.0;

      for (int bin = 0; bin < bins; bin++) {
        if (fullCounts[bin] == 0) continue;

        final fullRms = math.sqrt(fullSumSq[bin] / fullCounts[bin]);
        double peakRms = 0.0;
        for (int sub = 0; sub < subWindows; sub++) {
          final offset = bin * subWindows + sub;
          if (subCounts[offset] == 0) continue;
          final rms = math.sqrt(subSumSq[offset] / subCounts[offset]);
          if (rms > peakRms) peakRms = rms;
        }

        final value = fullRms * 0.75 + peakRms * 0.25;
        raw[bin] = value;
        if (value > maxAmplitude) maxAmplitude = value;
      }

      if (maxAmplitude <= 0) return _generateEmpty(bins);

      return _normalize(raw);
    });
  }

  static bool _isCacheable(List<double> waveform) {
    return waveform.isNotEmpty && waveform.any((value) => value > 0.05);
  }

  static Future<List<double>?> _readCache(
    String filePath,
    int bins,
    FileStat stat,
  ) async {
    try {
      final cacheFile = await _cacheFile(filePath, bins, stat);
      if (!await cacheFile.exists()) return null;

      final bytes = await cacheFile.readAsBytes();
      if (bytes.isEmpty || bytes.length % Float32List.bytesPerElement != 0) {
        return null;
      }

      final floats = Float32List.view(bytes.buffer, 0, bytes.length ~/ 4);
      if (floats.isEmpty) return null;
      return floats.toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(
    String filePath,
    int bins,
    FileStat stat,
    List<double> waveform,
  ) async {
    try {
      final cacheFile = await _cacheFile(filePath, bins, stat);
      await cacheFile.parent.create(recursive: true);
      final data = Float32List.fromList(waveform);
      await cacheFile.writeAsBytes(data.buffer.asUint8List(), flush: false);
    } catch (_) {}
  }

  static Future<File> _cacheFile(
    String filePath,
    int bins,
    FileStat stat,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(path.join(tempDir.path, 'waveform_cache'));
    final key = _cacheKey(filePath, bins, stat);
    return File(path.join(cacheDir.path, '$key.bin'));
  }

  static String _cacheKey(String filePath, int bins, FileStat stat) {
    final payload = [
      filePath,
      stat.size,
      stat.modified.millisecondsSinceEpoch,
      bins,
      _cacheVersion,
      _ffmpegSampleRate,
    ].join('|');
    return base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
  }
}
