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
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'st',
              style: TextStyle(
                color: context.colors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _descriptionLabel,
          style: TextStyle(
            color: context.colors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: context.colors.secondary,
              inactiveTrackColor: context.colors.surfaceBorder,
              thumbColor: context.colors.secondary,
              overlayColor: context.colors.secondary.withValues(alpha: 0.12),
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
            Text('-12', style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
            GestureDetector(
              onTap: () => onChanged?.call(0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: pitch == 0
                      ? context.colors.secondary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: pitch == 0
                      ? Border.all(color: context.colors.secondary.withValues(alpha: 0.4))
                      : null,
                ),
                child: Text(
                  'Reset',
                  style: TextStyle(
                    color: pitch == 0 ? context.colors.secondary : context.colors.textMuted,
                    fontSize: 11,
                    fontWeight: pitch == 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            Text('+12', style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
