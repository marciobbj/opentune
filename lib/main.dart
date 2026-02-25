import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI database factory for desktop platforms
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Ensure cache and temp directories exist for MPV (fixes file cache errors and segfaults)
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final mpvCacheDir = Directory('${cacheDir.path}/mpv');
      if (!await mpvCacheDir.exists()) {
        await mpvCacheDir.create(recursive: true);
      }

      // Set TMPDIR to the app's cache directory so MPV has a reliable place for lavf cache
      Platform.environment['TMPDIR'] = mpvCacheDir.path;
    } catch (_) {
      // Ignore directory creation failures
    }
  }

  // Initialize MediaKit for desktop audio playback
  // macOS needs explicit opt-in for MediaKit (enables pitch shifting via mpv)
  JustAudioMediaKit.ensureInitialized(
    macOS: Platform.isMacOS,
  );
  // Set buffer size and ignore minor lavf cache errors in logs
  JustAudioMediaKit.bufferSize = 1 * 1024 * 1024;
  JustAudioMediaKit.mpvLogLevel = MPVLogLevel.warn;

  runApp(
    const ProviderScope(
      child: OpenTuneApp(),
    ),
  );
}
