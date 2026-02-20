import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PitchControl extends StatelessWidget {
  final double pitch;
  final ValueChanged<double>? onChanged;

  const PitchControl({
    super.key,
    required this.pitch,
    this.onChanged,
  });

  String get _mainLabel {
    final semitones = pitch.round();
    if (semitones == 0) return '0';
    return '${semitones > 0 ? "+" : ""}$semitones';
  }

  String get _descriptionLabel {
    final semitones = pitch.round().abs();
    if (pitch == 0) return 'Original pitch';
    if (pitch > 0) {
      return '$semitones semitone${semitones != 1 ? "s" : ""} up';
    } else {
      return '$semitones semitone${semitones != 1 ? "s" : ""} down';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _mainLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'st',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _descriptionLabel,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.secondary,
              inactiveTrackColor: AppColors.surfaceBorder,
              thumbColor: AppColors.secondary,
              overlayColor: AppColors.secondary.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: pitch,
              min: -12.0,
              max: 12.0,
              divisions: 24,
              onChanged: onChanged,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('-12', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            GestureDetector(
              onTap: () => onChanged?.call(0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: pitch == 0
                      ? AppColors.secondary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: pitch == 0
                      ? Border.all(color: AppColors.secondary.withValues(alpha: 0.4))
                      : null,
                ),
                child: Text(
                  'Reset',
                  style: TextStyle(
                    color: pitch == 0 ? AppColors.secondary : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: pitch == 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            const Text('+12', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
