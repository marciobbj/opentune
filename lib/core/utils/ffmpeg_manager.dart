import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages FFmpeg availability for desktop platforms (Linux/Windows).
///
/// Checks system PATH first, then falls back to a locally downloaded binary.
/// macOS is excluded (uses native decoders).
class FfmpegManager {
  static const String _prefKeyFirstRunComplete = 'ffmpegFirstRunComplete';
  static const String _prefKeyLocalPath = 'ffmpegLocalPath';
  static const String _prefKeyPromptShown = 'ffmpegPromptShown';

  static FfmpegManager? _instance;

  String? _resolvedPath;
  bool _initialized = false;

  FfmpegManager._();

  static FfmpegManager get instance {
    _instance ??= FfmpegManager._();
    return _instance!;
  }

  /// Whether FFmpeg handling is needed on this platform.
  static bool get isRequired =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows);

  /// The resolved FFmpeg executable path, or 'ffmpeg' if on PATH.
  /// Returns null if not yet initialized or unavailable.
  String? get ffmpegPath => _resolvedPath;

  /// Whether first-run setup has been completed (either FFmpeg found on PATH
  /// or user downloaded it).
  Future<bool> get isFirstRunComplete async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyFirstRunComplete) ?? false;
  }

  /// Whether the FFmpeg download prompt has already been shown to the user.
  /// Once true, the dialog should never appear again (regardless of outcome).
  Future<bool> get isPromptShown async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyPromptShown) ?? false;
  }

  /// Mark that the FFmpeg prompt has been shown. Call this immediately after
  /// displaying the dialog, before awaiting user interaction.
  Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyPromptShown, true);
  }

  /// Initialize: detect FFmpeg on PATH or via stored local path.
  /// Returns true if FFmpeg is available.
  Future<bool> initialize() async {
    if (_initialized && _resolvedPath != null) return true;

    // 1. Check system PATH
    if (await _isOnSystemPath()) {
      _resolvedPath = 'ffmpeg';
      _initialized = true;
      await _markComplete(null);
      return true;
    }

    // 2. Check stored local path
    final prefs = await SharedPreferences.getInstance();
    final storedPath = prefs.getString(_prefKeyLocalPath);
    if (storedPath != null && await File(storedPath).exists()) {
      _resolvedPath = storedPath;
      _initialized = true;
      return true;
    }

    // 3. Check default local location (maybe downloaded but prefs lost)
    final defaultLocal = await _localBinaryPath();
    if (await File(defaultLocal).exists()) {
      _resolvedPath = defaultLocal;
      _initialized = true;
      await _markComplete(defaultLocal);
      return true;
    }

    return false;
  }

  /// Download FFmpeg to the local app support directory.
  /// [onProgress] receives values 0.0–1.0 (or -1 for indeterminate).
  /// Returns the local path on success, null on failure.
  Future<String?> download({void Function(double progress)? onProgress}) async {
    final localPath = await _localBinaryPath();
    final localDir = Directory(path.dirname(localPath));
    if (!await localDir.exists()) {
      await localDir.create(recursive: true);
    }

    final url = _downloadUrl();
    if (url == null) return null;

    final tmpFile = File('$localPath.tmp');

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final contentLength = response.contentLength;
      int received = 0;

      final sink = tmpFile.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress?.call(received / contentLength);
        } else {
          onProgress?.call(-1);
        }
      }
      await sink.flush();
      await sink.close();
      client.close();

      // For Linux: the download is a tar.xz archive — extract the binary.
      // For Windows: the download is a zip — extract the binary.
      // We use lightweight extraction via Process since we're on desktop.
      final extractedPath = await _extractBinary(tmpFile.path, localPath);
      if (extractedPath == null) return null;

      // Set executable permission on Linux
      if (Platform.isLinux) {
        await Process.run('chmod', ['+x', extractedPath]);
      }

      _resolvedPath = extractedPath;
      _initialized = true;
      await _markComplete(extractedPath);

      return extractedPath;
    } catch (e) {
      debugPrint('FFmpeg download failed: $e');
      return null;
    } finally {
      // Clean up temp file
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Mark first-run as complete and store the local path if provided.
  Future<void> _markComplete(String? localPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyFirstRunComplete, true);
    if (localPath != null) {
      await prefs.setString(_prefKeyLocalPath, localPath);
    }
  }

  /// Check whether 'ffmpeg' is available on the system PATH.
  Future<bool> _isOnSystemPath() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// The expected local binary path under application support.
  Future<String> _localBinaryPath() async {
    final appDir = await getApplicationSupportDirectory();
    final binaryName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    return path.join(appDir.path, 'ffmpeg', binaryName);
  }

  /// Download URL for a static FFmpeg build.
  /// Linux: John Van Sickle's static builds (amd64).
  /// Windows: BtbN GitHub releases (win64 GPL).
  String? _downloadUrl() {
    if (Platform.isLinux) {
      return 'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz';
    } else if (Platform.isWindows) {
      return 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip';
    }
    return null;
  }

  /// Extract the ffmpeg binary from the downloaded archive.
  /// Returns the final binary path on success, null on failure.
  Future<String?> _extractBinary(String archivePath, String targetPath) async {
    final extractDir = Directory('${path.dirname(targetPath)}/extract_tmp');
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    try {
      if (Platform.isLinux) {
        // tar.xz extraction
        final result = await Process.run('tar', [
          'xf',
          archivePath,
          '-C',
          extractDir.path,
          '--strip-components=1',
        ]);
        if (result.exitCode != 0) {
          debugPrint('tar extraction failed: ${result.stderr}');
          return null;
        }
        // The static build has ffmpeg at the top level after stripping
        final extracted = File(path.join(extractDir.path, 'ffmpeg'));
        if (await extracted.exists()) {
          await extracted.copy(targetPath);
          return targetPath;
        }
        return null;
      } else if (Platform.isWindows) {
        // zip extraction via PowerShell
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Expand-Archive -Path "$archivePath" -DestinationPath "${extractDir.path}" -Force',
        ]);
        if (result.exitCode != 0) {
          debugPrint('zip extraction failed: ${result.stderr}');
          return null;
        }
        // Find ffmpeg.exe recursively in extracted dir
        final ffmpegExe = await _findFile(extractDir, 'ffmpeg.exe');
        if (ffmpegExe != null) {
          await File(ffmpegExe).copy(targetPath);
          return targetPath;
        }
        return null;
      }
      return null;
    } finally {
      // Cleanup extraction temp dir
      try {
        if (await extractDir.exists()) {
          await extractDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Recursively find a file by name in a directory.
  Future<String?> _findFile(Directory dir, String fileName) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && path.basename(entity.path) == fileName) {
        return entity.path;
      }
    }
    return null;
  }
}
