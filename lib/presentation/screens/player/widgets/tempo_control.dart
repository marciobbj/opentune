import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TempoControl extends StatelessWidget {
  final double tempo;
  final double originalBpm;
  final ValueChanged<double>? onChanged;

  const TempoControl({
    super.key,
    required this.tempo,
    this.originalBpm = 120.0,
    this.onChanged,
  });

  String get _tempoLabel => '${(tempo * 100).round()}%';

  String get _bpmLabel {
    final bpm = (originalBpm * tempo).round();
    return '$bpm';
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
              _bpmLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'bpm',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Speed: $_tempoLabel',
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
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceBorder,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: tempo,
              min: 0.25,
              max: 2.0,
              divisions: 35,
              onChanged: onChanged,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0.25x', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            // Quick presets
            _TempoPreset(label: '0.5x', value: 0.5, current: tempo, onTap: onChanged),
            _TempoPreset(label: '0.75x', value: 0.75, current: tempo, onTap: onChanged),
            _TempoPreset(label: '1x', value: 1.0, current: tempo, onTap: onChanged),
            _TempoPreset(label: '1.25x', value: 1.25, current: tempo, onTap: onChanged),
            _TempoPreset(label: '1.5x', value: 1.5, current: tempo, onTap: onChanged),
            _TempoPreset(label: '2x', value: 2.0, current: tempo, onTap: onChanged),
          ],
        ),
      ],
    );
  }
}

class _TempoPreset extends StatelessWidget {
  final String label;
  final double value;
  final double current;
  final ValueChanged<double>? onTap;

  const _TempoPreset({
    required this.label,
    required this.value,
    required this.current,
    this.onTap,
  });

  bool get isActive => (current - value).abs() < 0.01;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap?.call(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.textMuted,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
