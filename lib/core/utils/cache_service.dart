import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Centralizes cache management for the application.
///
/// Currently covers:
///   - Waveform cache files (stored in `<tmpDir>/waveform_cache/`)
///   - Flutter in-memory image cache (decoded bitmaps held in RAM)
class CacheService {
  CacheService._();

  /// Returns the total size (in bytes) of on-disk cache files.
  ///
  /// Note: the Flutter in-memory image cache is not included here because
  /// it has no persistent footprint on disk; its size is RAM-only.
  static Future<int> getCacheSize() async {
    int total = 0;
    total += await _directorySize(await _waveformCacheDir());
    return total;
  }

  /// Clears all application caches:
  ///   1. On-disk waveform cache files.
  ///   2. Flutter's in-memory decoded-image cache (frees RAM).
  ///
  /// Returns the number of **disk** bytes freed.
  static Future<int> clearAll() async {
    int freed = 0;

    // 1. Waveform files on disk.
    freed += await _clearDirectory(await _waveformCacheDir());

    // 2. Flutter's in-memory image cache (album art shown behind the player,
    //    library thumbnails, etc.). This only frees RAM — the original
    //    image files on disk are untouched.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    return freed;
  }

  // ── Waveform cache ──────────────────────────────────────────────────────────

  static Future<Directory> _waveformCacheDir() async {
    final tmpDir = await getTemporaryDirectory();
    return Directory(path.join(tmpDir.path, 'waveform_cache'));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Future<int> _directorySize(Directory dir) async {
    if (!dir.existsSync()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  /// Deletes everything inside [dir] (but keeps the directory itself).
  /// Returns the number of bytes freed.
  static Future<int> _clearDirectory(Directory dir) async {
    if (!dir.existsSync()) return 0;
    int freed = 0;
    await for (final entity in dir.list()) {
      try {
        final size = entity is File ? await entity.length() : 0;
        await entity.delete(recursive: true);
        freed += size;
      } catch (_) {}
    }
    return freed;
  }

  /// Human-readable representation of [bytes].
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
