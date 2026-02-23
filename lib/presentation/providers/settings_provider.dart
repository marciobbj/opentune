import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final Color? customPrimaryColor;
  final ThemeMode themeMode;
  final bool clearColor;

  const SettingsState({
    this.customPrimaryColor,
    this.themeMode = ThemeMode.system,
    this.clearColor = false,
  });

  SettingsState copyWith({
    Color? customPrimaryColor,
    ThemeMode? themeMode,
    bool clearColor = false,
  }) {
    return SettingsState(
      customPrimaryColor: clearColor ? null : (customPrimaryColor ?? this.customPrimaryColor),
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const String _customPrimaryColorKey = 'custom_primary_color';
  static const String _themeModeKey = 'theme_mode';

  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Color
    Color? color;
    final colorValue = prefs.getInt(_customPrimaryColorKey);
    if (colorValue != null) {
      color = Color(colorValue);
    }
    
    // Load ThemeMode
    ThemeMode mode = ThemeMode.system;
    final modeStr = prefs.getString(_themeModeKey);
    if (modeStr != null) {
      mode = ThemeMode.values.firstWhere((e) => e.toString() == modeStr, orElse: () => ThemeMode.system);
    }
    
    state = state.copyWith(customPrimaryColor: color, themeMode: mode);
  }

  Future<void> setCustomPrimaryColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_customPrimaryColorKey, color.toARGB32());
    state = state.copyWith(customPrimaryColor: color);
  }

  Future<void> resetPrimaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customPrimaryColorKey);
    state = state.copyWith(clearColor: true);
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.toString());
    state = state.copyWith(themeMode: mode);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
