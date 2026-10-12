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
  /// Sample rate used for analysis on desktop. Must be high enough to keep
  /// the frequencies the ear is most sensitive to (1–5 kHz); resampling to a
  /// very low rate low-passes the signal and over-represents bass.
  static const int _ffmpegSampleRate = 11025;

  /// Approximation of ITU-R BS.1770 K-weighting: removes sub-bass rumble and
  /// boosts the upper mids/highs so the envelope tracks perceived loudness
  /// instead of raw (bass-dominated) energy.
  static const String _ffmpegWeightingFilter =
      'highpass=f=40,highshelf=f=1500:g=4';

  static const int _cacheVersion = 3;

  /// Number of sub-windows per bin used to capture short loud moments.
  static const int _subWindows = 4;

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
        '-af',
        _ffmpegWeightingFilter,
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
    final int length = waveform.length;
    if (length == 0 || bins <= 0) return _generateEmpty(bins);

    final acc = _EnvelopeAccumulator(bins, _subWindows);
    final int totalSubs = bins * _subWindows;

    // Each pixel holds the min/max of a short (~10 ms) window. Treat its
    // absolute peak as an amplitude sample and aggregate it exactly like the
    // PCM path (RMS + loudest sub-window), so desktop and mobile render the
    // same track with the same proportions.
    for (int j = 0; j < length; j++) {
      final double maxVal = waveform.getPixelMax(j).abs().toDouble();
      final double minVal = waveform.getPixelMin(j).abs().toDouble();
      final double peak = math.max(maxVal, minVal);
      // Fractional mapping: every bin covers the same span of time.
      final int sub = (j * totalSubs) ~/ length;
      acc.add(sub, peak * peak);
    }

    return _normalize(acc.envelope());
  }

  /// Perceptual normalization.
  ///
  /// Loudness perception is logarithmic, so values are mapped in dB:
  /// - The reference level is a high percentile (not the absolute peak), so a
  ///   single transient or clipped spot doesn't shrink the whole waveform.
  /// - The displayed dynamic range adapts to the track: compressed masters
  ///   (everything near the top) get a narrow window to reveal variation,
  ///   while dynamic tracks get a wide window so quiet intros stay visible.
  static List<double> _normalize(List<double> raw) {
    final int n = raw.length;
    if (n == 0) return raw;

    double toDb(double v) => 20 * math.log(math.max(v, 1e-9)) / math.ln10;

    final sorted = List<double>.from(raw)..sort();
    final double ref = sorted[((n - 1) * 0.995).round()];
    if (ref <= 0) return _generateEmpty(n);
    final double refDb = toDb(ref);

    // Find the quiet level among bins that actually contain sound, so
    // leading/trailing silence doesn't widen the window.
    final audible = sorted.where((v) => toDb(v) - refDb > -70).toList();
    final double p10 = audible.isEmpty
        ? ref
        : audible[(audible.length * 0.10).floor()];
    final double p10Db = toDb(p10) - refDb;

    // Window floor: ~6 dB below the quiet level, between -48 dB and -18 dB.
    final double floorDb = (p10Db - 6).clamp(-48.0, -18.0);

    return List<double>.generate(n, (i) {
      final double db = toDb(raw[i]) - refDb;
      final double t = ((db - floorDb) / -floorDb).clamp(0.0, 1.0);
      // Slight ease-in keeps contrast near the top of the range.
      return math.pow(t, 1.3).toDouble().clamp(0.05, 1.0);
    });
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
      if (totalSamples <= 0 || bins <= 0) return _generateEmpty(bins);

      final pcmFile = File(pcmFilePath);

      final acc = _EnvelopeAccumulator(bins, _subWindows);
      final int totalSubs = bins * _subWindows;

      var sampleIndex = 0;
      int? carryByte;

      void addSample(int rawSample) {
        // Fractional mapping: every bin covers the same span of time, so the
        // waveform stays aligned with the playback cursor.
        var sub = (sampleIndex * totalSubs) ~/ totalSamples;
        if (sub >= totalSubs) sub = totalSubs - 1;

        final sample = rawSample / 32768.0;
        acc.add(sub, sample * sample);

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

      return _normalize(acc.envelope());
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

/// Accumulates squared amplitudes into `bins * subWindows` slots and turns
/// them into a per-bin envelope. Shared by the native and FFmpeg paths so
/// both produce the same metric.
class _EnvelopeAccumulator {
  final int bins;
  final int subWindows;
  final Float64List _sumSq;
  final Int32List _counts;

  _EnvelopeAccumulator(this.bins, this.subWindows)
    : _sumSq = Float64List(bins * subWindows),
      _counts = Int32List(bins * subWindows);

  void add(int subIndex, double squared) {
    _sumSq[subIndex] += squared;
    _counts[subIndex] += 1;
  }

  /// Per bin: 75% full-bin RMS + 25% loudest sub-window RMS. The RMS part
  /// tracks sustained loudness; the sub-window part keeps short accents
  /// visible without letting isolated transients dominate.
  List<double> envelope() {
    final raw = List<double>.filled(bins, 0.0);
    for (int bin = 0; bin < bins; bin++) {
      double totalSq = 0.0;
      int totalCount = 0;
      double peakRms = 0.0;
      for (int s = 0; s < subWindows; s++) {
        final o = bin * subWindows + s;
        final c = _counts[o];
        if (c == 0) continue;
        totalSq += _sumSq[o];
        totalCount += c;
        final rms = math.sqrt(_sumSq[o] / c);
        if (rms > peakRms) peakRms = rms;
      }
      if (totalCount == 0) {
        raw[bin] = -1.0; // marker: no samples landed in this bin
        continue;
      }
      final fullRms = math.sqrt(totalSq / totalCount);
      raw[bin] = fullRms * 0.75 + peakRms * 0.25;
    }

    // Bins with no samples (very short tracks) borrow the previous value so
    // they don't show up as false gaps. Real silence (0.0) is kept as is.
    for (int bin = 0; bin < bins; bin++) {
      if (raw[bin] < 0) raw[bin] = bin > 0 ? raw[bin - 1] : 0.0;
    }
    return raw;
  }
}
