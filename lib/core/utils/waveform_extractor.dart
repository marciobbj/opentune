import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:just_waveform/just_waveform.dart';

import 'ffmpeg_manager.dart';

class WaveformExtractor {
  static Future<List<double>> extract(String filePath, {int bins = 300}) async {
    try {
      if (!File(filePath).existsSync()) {
        return _generateEmpty(bins);
      }

      // Use native decoders for mobile platforms via just_waveform,
      // or macOS if supported. For desktop (Linux/Windows), fallback to FFMPEG.
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        return await _extractViaNative(filePath, bins);
      } else {
        return await _extractViaFFmpeg(filePath, bins);
      }
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

    final result = await Process.run(ffmpeg, [
      '-v',
      'error',
      '-i',
      filePath,
      '-ac',
      '1',
      '-filter:a',
      'aresample=8000',
      '-map',
      '0:a',
      '-c:a',
      'pcm_s16le',
      '-f',
      's16le',
      '-',
    ], stdoutEncoding: null);

    if (result.exitCode != 0) {
      return _generateEmpty(bins);
    }

    final bytes = result.stdout as List<int>;
    if (bytes.isEmpty) {
      return _generateEmpty(bins);
    }

    return await Isolate.run(() {
      final int16List = Int16List.view(Uint8List.fromList(bytes).buffer);
      return _processChunks(int16List, bins);
    });
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

  static List<double> _processChunks(Int16List pcmData, int bins) {
    if (pcmData.isEmpty) return _generateEmpty(bins);

    final int samplesPerBin = pcmData.length ~/ bins;
    if (samplesPerBin == 0) return _generateEmpty(bins);

    // Hybrid approach: compute the full-bin RMS (overall energy) and
    // the peak sub-window RMS (transient detail), then blend them.
    // 70% full RMS + 30% peak sub-RMS keeps transients visible
    // without letting them tower over everything else.
    const int subWindows = 4;
    final List<double> raw = List.filled(bins, 0.0);
    double maxAmplitude = 0.0;

    for (int i = 0; i < bins; i++) {
      int binStart = i * samplesPerBin;
      int binEnd = (i == bins - 1) ? pcmData.length : (i + 1) * samplesPerBin;
      int binLen = binEnd - binStart;
      int subLen = binLen ~/ subWindows;
      if (subLen == 0) subLen = binLen;

      // Full-bin RMS
      double fullSumSq = 0.0;
      for (int j = binStart; j < binEnd; j++) {
        final double sample = pcmData[j] / 32768.0;
        fullSumSq += sample * sample;
      }
      final double fullRms = math.sqrt(fullSumSq / binLen);

      // Peak sub-window RMS
      double peakRms = 0.0;
      for (int s = 0; s < subWindows; s++) {
        int subStart = binStart + s * subLen;
        int subEnd = (s == subWindows - 1) ? binEnd : subStart + subLen;
        if (subStart >= binEnd) break;

        double sumSq = 0.0;
        for (int j = subStart; j < subEnd; j++) {
          final double sample = pcmData[j] / 32768.0;
          sumSq += sample * sample;
        }
        final rms = math.sqrt(sumSq / (subEnd - subStart));
        if (rms > peakRms) peakRms = rms;
      }

      // Blend: mostly the overall energy, with a boost from transients
      final value = fullRms * 0.7 + peakRms * 0.3;
      raw[i] = value;
      if (value > maxAmplitude) maxAmplitude = value;
    }

    if (maxAmplitude <= 0) return _generateEmpty(bins);

    return _normalize(raw);
  }

  /// Percentile-based normalization that works well for both quiet and
  /// heavily compressed (loud) audio.
  ///
  /// Instead of stretching between absolute min/max (where outliers
  /// distort the result), we use the 5th and 95th percentiles as
  /// reference points. This means:
  ///   - The quietest ~5% of bins map to the floor
  ///   - The loudest ~5% of bins map to the ceiling
  ///   - Everything in between is evenly distributed
  ///
  /// The result: compressed rock tracks show real variation instead of
  /// a flat wall, and quiet tracks don't get their transients exaggerated.
  static List<double> _normalize(List<double> raw) {
    final int n = raw.length;
    if (n == 0) return raw;

    final sorted = List<double>.from(raw)..sort();
    final double p5 = sorted[(n * 0.05).floor()];
    final double p95 = sorted[(n * 0.95).floor().clamp(0, n - 1)];
    final double range = p95 - p5;

    if (range <= 0) {
      return List.filled(n, 0.5);
    }

    for (int i = 0; i < n; i++) {
      raw[i] = ((raw[i] - p5) / range).clamp(0.05, 1.0);
    }

    return raw;
  }

  static List<double> _generateEmpty(int bins) {
    return List.filled(bins, 0.05);
  }
}
