import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background shades
  static const Color bgDarkest = Color(0xFF0A0E17);
  static const Color bgDark = Color(0xFF0D1117);
  static const Color bgMedium = Color(0xFF141B27);
  static const Color bgLight = Color(0xFF1A2332);
  static const Color bgCard = Color(0xFF1E2A3A);
  static const Color bgElevated = Color(0xFF243447);

  // Surface
  static const Color surface = Color(0xFF1A2332);
  static const Color surfaceLight = Color(0xFF243447);
  static const Color surfaceBorder = Color(0xFF2D3F54);

  // Primary accent — Orange
  static const Color primary = Color(0xFFFF6C08);
  static const Color primaryLight = Color(0xFFFF9A4D);
  static const Color primaryDark = Color(0xFFCC5500);

  // Secondary accent — Electric Purple
  static const Color secondary = Color(0xFF7C3AED);
  static const Color secondaryLight = Color(0xFFA78BFA);
  static const Color secondaryDark = Color(0xFF5B21B6);

  // Waveform
  static const Color waveformActive = Color(0xFFFF6C08);
  static const Color waveformPlayed = Color(0xFF4A5568);
  static const Color waveformInactive = Color(0xFF2D3748);
  static const Color waveformCursor = Color(0xFFFFFFFF);

  // Section marker colors
  static const Color markerGreen = Color(0xFF10B981);
  static const Color markerYellow = Color(0xFFEAB308);
  static const Color markerRed = Color(0xFFEF4444);
  static const Color markerBlue = Color(0xFF3B82F6);
  static const Color markerPurple = Color(0xFF8B5CF6);
  static const Color markerOrange = Color(0xFFF97316);
  static const Color markerPink = Color(0xFFEC4899);
  static const Color markerCyan = Color(0xFF06B6D4);

  static const List<Color> markerColors = [
    markerGreen,
    markerYellow,
    markerRed,
    markerBlue,
    markerPurple,
    markerOrange,
    markerPink,
    markerCyan,
  ];

  // Text
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // Functional
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

}
