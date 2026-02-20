import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:just_waveform/just_waveform.dart';

class WaveformExtractor {
  static Future<List<double>> extract(String filePath, {int bins = 200}) async {
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

  static Future<List<double>> _extractViaNative(String filePath, int bins) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(path.join(tempDir.path, 'temp_waveform_${DateTime.now().millisecondsSinceEpoch}.wave'));
    
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

  static Future<List<double>> _extractViaFFmpeg(String filePath, int bins) async {
    final result = await Process.run(
      'ffmpeg',
      [
        '-v', 'error',
        '-i', filePath,
        '-ac', '1',
        '-filter:a', 'aresample=100',
        '-map', '0:a',
        '-c:a', 'pcm_s16le',
        '-f', 's16le',
        '-'
      ],
      stdoutEncoding: null,
    );

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
    
    final List<double> out = List.filled(bins, 0.0);
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
      out[i] = avg;
      if (avg > maxAmplitude) maxAmplitude = avg;
    }
    
    if (maxAmplitude > 0) {
      for (int i = 0; i < bins; i++) {
        out[i] = (out[i] / maxAmplitude).clamp(0.05, 1.0);
      }
    } else {
      for (int i = 0; i < bins; i++) {
        out[i] = 0.05;
      }
    }
    return out;
  }

  static List<double> _processChunks(Int16List pcmData, int bins) {
    if (pcmData.isEmpty) return _generateEmpty(bins);
    
    final int samplesPerBin = pcmData.length ~/ bins;
    if (samplesPerBin == 0) return _generateEmpty(bins);

    final List<double> waveform = List.filled(bins, 0.0);
    double maxAmplitude = 0.0;

    for (int i = 0; i < bins; i++) {
      int start = i * samplesPerBin;
      int end = (i == bins - 1) ? pcmData.length : (i + 1) * samplesPerBin;

      double sumSq = 0.0;
      for (int j = start; j < end; j++) {
        final double sample = pcmData[j] / 32768.0; 
        sumSq += sample * sample;
      }
      
      final rms = math.sqrt(sumSq / (end - start));
      waveform[i] = rms;
      if (rms > maxAmplitude) {
        maxAmplitude = rms;
      }
    }

    if (maxAmplitude > 0) {
      for (int i = 0; i < bins; i++) {
        waveform[i] = (waveform[i] / maxAmplitude).clamp(0.05, 1.0);
      }
    } else {
      for (int i = 0; i < bins; i++) {
        waveform[i] = 0.05;
      }
    }

    return waveform;
  }

  static List<double> _generateEmpty(int bins) {
    return List.filled(bins, 0.05);
  }
}
