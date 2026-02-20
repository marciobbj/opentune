import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/section.dart';

class MiniWaveform extends StatelessWidget {
  final List<double> waveformData;
  final double progress;
  final Duration duration;
  final List<Section> sections;
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool loopEnabled;
  final ValueChanged<double>? onSeek;

  const MiniWaveform({
    super.key,
    required this.waveformData,
    required this.progress,
    required this.duration,
    this.sections = const [],
    this.loopStart,
    this.loopEnd,
    this.loopEnabled = false,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) {
            if (onSeek == null) return;
            final pos = details.localPosition.dx / constraints.maxWidth;
            onSeek!(pos.clamp(0.0, 1.0));
          },
          onPanUpdate: (details) {
            if (onSeek == null) return;
            final pos = details.localPosition.dx / constraints.maxWidth;
            onSeek!(pos.clamp(0.0, 1.0));
          },
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgMedium,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.surfaceBorder.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _MiniWaveformPainter(
                  waveformData: waveformData,
                  progress: progress,
                  duration: duration,
                  sections: sections,
                  loopStart: loopStart,
                  loopEnd: loopEnd,
                  loopEnabled: loopEnabled,
                ),
                size: Size(constraints.maxWidth, 40),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Duration duration;
  final List<Section> sections;
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool loopEnabled;

  _MiniWaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.duration,
    this.sections = const [],
    this.loopStart,
    this.loopEnd,
    this.loopEnabled = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final midY = size.height / 2;
    final totalMs = duration.inMilliseconds.toDouble();

    // Draw section colored backgrounds
    if (totalMs > 0) {
      for (final section in sections) {
        final startX = (section.startTime.inMilliseconds / totalMs) * size.width;
        final endX = (section.endTime.inMilliseconds / totalMs) * size.width;
        final paint = Paint()
          ..color = section.color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTRB(startX, 0, endX, size.height), paint);
      }
    }

    // Draw loop region
    if (loopStart != null && loopEnd != null && totalMs > 0) {
      final startX = (loopStart!.inMilliseconds / totalMs) * size.width;
      final endX = (loopEnd!.inMilliseconds / totalMs) * size.width;
      final paint = Paint()
        ..color = (loopEnabled ? AppColors.primary : AppColors.textMuted)
            .withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTRB(startX, 0, endX, size.height), paint);

      final borderPaint = Paint()
        ..color = loopEnabled ? AppColors.primary : AppColors.textMuted
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), borderPaint);
      canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), borderPaint);
    }

    // Draw mini waveform bars
    final barWidth = size.width / waveformData.length;
    final maxBarHeight = size.height * 0.38;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth;
      final barProgress = i / waveformData.length;
      final amplitude = waveformData[i].clamp(0.0, 1.0);
      final barHeight = math.max(amplitude * maxBarHeight, 0.5);

      final color = barProgress <= progress
          ? AppColors.primary.withValues(alpha: 0.8)
          : AppColors.textMuted.withValues(alpha: 0.3);

      final paint = Paint()
        ..color = color
        ..strokeWidth = math.max(barWidth - 0.3, 0.5)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, midY - barHeight),
        Offset(x, midY + barHeight),
        paint,
      );
    }

    // Cursor
    final cursorX = progress * size.width;
    canvas.drawLine(
      Offset(cursorX, 0),
      Offset(cursorX, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniWaveformPainter old) {
    return old.progress != progress ||
        old.loopEnabled != loopEnabled ||
        old.loopStart != loopStart ||
        old.loopEnd != loopEnd;
  }
}
