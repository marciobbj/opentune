import 'package:flutter/material.dart';
import 'app_colors.dart';

class ThemeColors {
  final BuildContext context;
  ThemeColors(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bgDarkest => isDark ? AppColors.bgDarkest : const Color(0xFFF8FAFC);
  Color get bgDark => isDark ? AppColors.bgDark : const Color(0xFFF1F5F9);
  Color get bgMedium => isDark ? AppColors.bgMedium : const Color(0xFFE2E8F0);
  Color get bgLight => isDark ? AppColors.bgLight : const Color(0xFFCBD5E1);
  Color get bgCard => isDark ? AppColors.bgCard : const Color(0xFFFFFFFF);
  Color get bgElevated => isDark ? AppColors.bgElevated : const Color(0xFFFFFFFF);

  Color get surface => isDark ? AppColors.surface : const Color(0xFFFFFFFF);
  Color get surfaceLight => isDark ? AppColors.surfaceLight : const Color(0xFFF8FAFC);
  Color get surfaceBorder => isDark ? AppColors.surfaceBorder : const Color(0xFFE2E8F0);

  Color get primary => Theme.of(context).colorScheme.primary;
  Color get primaryLight => isDark ? AppColors.primaryLight : primary.withValues(alpha: 0.8);
  Color get primaryDark => isDark ? AppColors.primaryDark : primary;

  Color get secondary => AppColors.secondary;
  Color get secondaryLight => AppColors.secondaryLight;
  Color get secondaryDark => AppColors.secondaryDark;

  Color get waveformActive => primary;
  Color get waveformPlayed => isDark ? AppColors.waveformPlayed : const Color(0xFF94A3B8);
  Color get waveformInactive => isDark ? AppColors.waveformInactive : const Color(0xFFE2E8F0);
  Color get waveformCursor => isDark ? AppColors.waveformCursor : const Color(0xFF0F172A);

  Color get textPrimary => isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? AppColors.textSecondary : const Color(0xFF475569);
  Color get textMuted => isDark ? AppColors.textMuted : const Color(0xFF64748B);
  Color get textDisabled => isDark ? AppColors.textDisabled : const Color(0xFF94A3B8);

  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;

  List<Color> get markerColors => AppColors.markerColors;
}

extension AppThemeColors on BuildContext {
  ThemeColors get colors => ThemeColors(this);
}
