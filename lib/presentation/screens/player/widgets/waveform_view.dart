import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/section.dart';

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Duration duration;
  final List<Section> sections;
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool loopEnabled;
  final double zoomLevel;
  final double scrollOffset;
  final Color primaryColor;
  final Color mutedColor;
  final Color inactiveColor;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.duration,
    required this.sections,
    required this.primaryColor,
    required this.mutedColor,
    required this.inactiveColor,
    this.loopStart,
    this.loopEnd,
    this.loopEnabled = false,
    this.zoomLevel = 1.0,
    this.scrollOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final midY = size.height / 2;

    // Draw section backgrounds
    _drawSections(canvas, size);

    // Draw loop region
    if (loopStart != null && loopEnd != null && duration > Duration.zero) {
      _drawLoopRegion(canvas, size);
    }

    // Draw waveform
    _drawWaveform(canvas, size, midY);

    // Draw cursor
    _drawCursor(canvas, size);
  }

  void _drawSections(Canvas canvas, Size size) {
    if (duration <= Duration.zero) return;

    for (final section in sections) {
      final startX = (section.startTime.inMilliseconds /
              duration.inMilliseconds) *
          size.width;
      final endX = (section.endTime.inMilliseconds /
              duration.inMilliseconds) *
          size.width;

      final paint = Paint()
        ..color = section.color.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTRB(startX, 0, endX, size.height),
        paint,
      );

      // Section border line
      final borderPaint = Paint()
        ..color = section.color.withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), borderPaint);
    }
  }

  void _drawLoopRegion(Canvas canvas, Size size) {
    final startX = (loopStart!.inMilliseconds /
            duration.inMilliseconds) *
        size.width;
    final endX = (loopEnd!.inMilliseconds /
            duration.inMilliseconds) *
        size.width;

    // Loop region background
    final bgPaint = Paint()
      ..color = loopEnabled
          ? primaryColor.withValues(alpha: 0.08)
          : mutedColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(startX, 0, endX, size.height),
      bgPaint,
    );

    // Loop boundary lines
    final linePaint = Paint()
      ..color = loopEnabled ? primaryColor : mutedColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), linePaint);
    canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), linePaint);

    // Draw A/B labels
    _drawMarkerLabel(canvas, startX, 'A', loopEnabled ? primaryColor : mutedColor);
    _drawMarkerLabel(canvas, endX, 'B', loopEnabled ? primaryColor : mutedColor);
  }

  void _drawMarkerLabel(Canvas canvas, double x, String label, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, 14),
        width: 20,
        height: 18,
      ),
      const Radius.circular(4),
    );

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(bgRect, bgPaint);
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, 14 - textPainter.height / 2),
    );
  }

  void _drawWaveform(Canvas canvas, Size size, double midY) {
    final barWidth = size.width / waveformData.length;
    final maxBarHeight = size.height * 0.42;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth;
      final barProgress = i / waveformData.length;
      final amplitude = waveformData[i].clamp(0.0, 1.0);
      final barHeight = math.max(amplitude * maxBarHeight, 1.5);

      Color color;
      if (barProgress <= progress) {
        // Played portion — gradient from cyan to purple
        final t = barProgress / math.max(progress, 0.001);
        color = Color.lerp(
          Color.alphaBlend(Colors.black.withValues(alpha: 0.3), primaryColor),
          primaryColor,
          t,
        )!;
      } else {
        // Unplayed portion
        color = inactiveColor;
      }

      final paint = Paint()
        ..color = color
        ..strokeWidth = math.max(barWidth - 0.8, 1.0)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(x, midY - barHeight),
        Offset(x, midY + barHeight),
        paint,
      );
    }
  }

  void _drawCursor(Canvas canvas, Size size) {
    final cursorX = progress * size.width;

    // Glow effect
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    canvas.drawLine(
      Offset(cursorX, 0),
      Offset(cursorX, size.height),
      glowPaint,
    );

    // Main cursor line
    final cursorPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(cursorX, 0),
      Offset(cursorX, size.height),
      cursorPaint,
    );

    // Cursor dot at center
    canvas.drawCircle(
      Offset(cursorX, size.height / 2),
      3.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant WaveformPainter old) {
    return old.progress != progress ||
        old.waveformData != waveformData ||
        old.sections != sections ||
        old.loopStart != loopStart ||
        old.loopEnd != loopEnd ||
        old.loopEnabled != loopEnabled;
  }
}

class WaveformView extends StatefulWidget {
  final List<double> waveformData;
  final double progress;
  final Duration duration;
  final Duration position;
  final List<Section> sections;
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool loopEnabled;
  final ValueChanged<double>? onSeek;

  const WaveformView({
    super.key,
    required this.waveformData,
    required this.progress,
    required this.duration,
    required this.position,
    this.sections = const [],
    this.loopStart,
    this.loopEnd,
    this.loopEnabled = false,
    this.onSeek,
  });

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    if (widget.onSeek == null) return;
    final progress = details.localPosition.dx / constraints.maxWidth;
    widget.onSeek!(progress.clamp(0.0, 1.0));
  }

  void _handleDrag(DragUpdateDetails details, BoxConstraints constraints) {
    if (widget.onSeek == null) return;
    final progress = details.localPosition.dx / constraints.maxWidth;
    widget.onSeek!(progress.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (d) => _handleTap(d, constraints),
          onPanUpdate: (d) => _handleDrag(d, constraints),
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              color: context.colors.bgDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.colors.surfaceBorder.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: WaveformPainter(
                  waveformData: widget.waveformData,
                  progress: widget.progress,
                  duration: widget.duration,
                  sections: widget.sections,
                  primaryColor: Theme.of(context).colorScheme.primary,
                  mutedColor: context.colors.textMuted,
                  inactiveColor: context.colors.waveformInactive,
                  loopStart: widget.loopStart,
                  loopEnd: widget.loopEnd,
                  loopEnabled: widget.loopEnabled,
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Generates simulated waveform data from nothing (for demo/placeholder)
List<double> generateDemoWaveform(int sampleCount) {
  final random = math.Random(42);
  final data = <double>[];

  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleCount;
    // Create a realistic-looking waveform envelope
    final envelope = 0.3 +
        0.4 * math.sin(t * math.pi) +
        0.2 * math.sin(t * math.pi * 3) +
        0.1 * math.sin(t * math.pi * 7);
    final noise = random.nextDouble() * 0.3;
    data.add((envelope + noise).clamp(0.05, 1.0));
  }
  return data;
}
