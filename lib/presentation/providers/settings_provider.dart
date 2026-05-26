import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final Color? customPrimaryColor;
  final ThemeMode themeMode;
  final bool clearColor;
  final bool showAlbumArtInPlayer;
  final bool startQueueFromBeginning;

  const SettingsState({
    this.customPrimaryColor,
    this.themeMode = ThemeMode.system,
    this.clearColor = false,
    this.showAlbumArtInPlayer = true,
    this.startQueueFromBeginning = false,
  });

  SettingsState copyWith({
    Color? customPrimaryColor,
    ThemeMode? themeMode,
    bool clearColor = false,
    bool? showAlbumArtInPlayer,
    bool? startQueueFromBeginning,
  }) {
    return SettingsState(
      customPrimaryColor: clearColor
          ? null
          : (customPrimaryColor ?? this.customPrimaryColor),
      themeMode: themeMode ?? this.themeMode,
      showAlbumArtInPlayer: showAlbumArtInPlayer ?? this.showAlbumArtInPlayer,
      startQueueFromBeginning:
          startQueueFromBeginning ?? this.startQueueFromBeginning,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const String _customPrimaryColorKey = 'custom_primary_color';
  static const String _themeModeKey = 'theme_mode';
  static const String _showAlbumArtInPlayerKey = 'show_album_art_in_player';
  static const String _startQueueFromBeginningKey =
      'start_queue_from_beginning';

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
      mode = ThemeMode.values.firstWhere(
        (e) => e.toString() == modeStr,
        orElse: () => ThemeMode.system,
      );
    }

    // Load showAlbumArtInPlayer
    final showAlbumArt = prefs.getBool(_showAlbumArtInPlayerKey) ?? true;

    // Load queue playback preference
    final startQueueFromBeginning =
        prefs.getBool(_startQueueFromBeginningKey) ?? false;

    state = state.copyWith(
      customPrimaryColor: color,
      themeMode: mode,
      showAlbumArtInPlayer: showAlbumArt,
      startQueueFromBeginning: startQueueFromBeginning,
    );
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

  Future<void> setShowAlbumArtInPlayer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAlbumArtInPlayerKey, value);
    state = state.copyWith(showAlbumArtInPlayer: value);
  }

  Future<void> setStartQueueFromBeginning(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startQueueFromBeginningKey, value);
    state = state.copyWith(startQueueFromBeginning: value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
