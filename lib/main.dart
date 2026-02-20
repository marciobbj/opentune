import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI database factory for desktop platforms
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Ensure cache directory exists for MPV (fixes release build segfault)
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final mpvCacheDir = Directory('${cacheDir.path}/mpv');
      if (!await mpvCacheDir.exists()) {
        await mpvCacheDir.create(recursive: true);
      }
    } catch (_) {
      // Ignore cache dir creation failures
    }
  }

  // Initialize MediaKit for desktop audio playback (FLAC, MP3, WAV, OGG, AAC, etc.)
  JustAudioMediaKit.ensureInitialized();
  // Reduce buffer to avoid file cache issues in release builds
  JustAudioMediaKit.bufferSize = 2 * 1024 * 1024;

  runApp(
    const ProviderScope(
      child: OpenTuneApp(),
    ),
  );
}
