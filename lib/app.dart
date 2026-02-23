import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/providers/settings_provider.dart';

class OpenTuneApp extends ConsumerWidget {
  const OpenTuneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customPrimary = ref.watch(settingsProvider.select((state) => state.customPrimaryColor));
    final themeMode = ref.watch(settingsProvider.select((state) => state.themeMode));
    
    // Force dark system UI overlay for now
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeMode == ThemeMode.light ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: themeMode == ThemeMode.light ? const Color(0xFFF8FAFC) : const Color(0xFF0A0E17),
        systemNavigationBarIconBrightness: themeMode == ThemeMode.light ? Brightness.dark : Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'OpenTune',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(customPrimary: customPrimary),
      darkTheme: AppTheme.darkTheme(customPrimary: customPrimary),
      home: const HomeScreen(),
    );
  }
}
