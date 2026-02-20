import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class BottomControls extends StatelessWidget {
  final double tempo;
  final double pitch;
  final bool loopEnabled;
  final bool hasLoop;
  final int sectionCount;
  final VoidCallback? onTempoTap;
  final VoidCallback? onPitchTap;
  final VoidCallback? onLoopToggle;
  final VoidCallback? onSectionsTap;

  const BottomControls({
    super.key,
    required this.tempo,
    required this.pitch,
    required this.loopEnabled,
    required this.hasLoop,
    this.sectionCount = 0,
    this.onTempoTap,
    this.onPitchTap,
    this.onLoopToggle,
    this.onSectionsTap,
  });

  String get _tempoText => '${(tempo * 100).round()}%';
  String get _pitchText {
    if (pitch == 0) return '0 st';
    final semitones = pitch.round();
    return '${semitones > 0 ? "+" : ""}$semitones st';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        left: 16,
        right: 16,
        top: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bgDarkest.withValues(alpha: 0.0),
            AppColors.bgDarkest.withValues(alpha: 0.95),
            AppColors.bgDarkest,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Tempo
          _ControlChip(
            label: 'Tempo',
            value: _tempoText,
            icon: Icons.speed_rounded,
            isActive: tempo != 1.0,
            activeColor: AppColors.primary,
            onTap: onTempoTap,
          ),

          // Pitch
          _ControlChip(
            label: 'Pitch',
            value: _pitchText,
            icon: Icons.tune_rounded,
            isActive: pitch != 0,
            activeColor: AppColors.secondary,
            onTap: onPitchTap,
          ),

          // Sections
          _ControlChip(
            label: 'Sections',
            value: sectionCount > 0 ? '$sectionCount' : 'Add',
            icon: Icons.bookmarks_rounded,
            isActive: sectionCount > 0,
            activeColor: AppColors.markerOrange,
            onTap: onSectionsTap,
          ),

          // Loop toggle
          _ControlChip(
            label: 'Loop',
            value: loopEnabled ? 'ON' : 'OFF',
            icon: Icons.repeat_rounded,
            isActive: loopEnabled,
            activeColor: AppColors.markerCyan,
            onTap: onLoopToggle,
          ),
        ],
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  const _ControlChip({
    required this.label,
    required this.value,
    required this.icon,
    this.isActive = false,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.bgCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.4)
                : AppColors.surfaceBorder.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: isActive ? activeColor : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? activeColor.withValues(alpha: 0.7)
                    : AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
