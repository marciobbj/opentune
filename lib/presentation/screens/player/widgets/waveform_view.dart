import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/section.dart';

// ── Drag state for section handle dragging ──
class _SectionDragState {
  final Section section;
  final bool isDragStart; // true = dragging start handle, false = end handle
  Duration currentTime;

  _SectionDragState({
    required this.section,
    required this.isDragStart,
    required this.currentTime,
  });
}

// ── Drag state for loop handle dragging ──
class _LoopDragState {
  final bool isDragStart; // true = dragging A handle, false = B handle
  final Duration originalStart;
  final Duration originalEnd;
  Duration currentTime;

  _LoopDragState({
    required this.isDragStart,
    required this.originalStart,
    required this.originalEnd,
    required this.currentTime,
  });
}

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
  // Drag overlay state
  final int? draggingSectionId;
  final Duration? dragStartOverride;
  final Duration? dragEndOverride;
  final Duration? loopDragStartOverride;
  final Duration? loopDragEndOverride;

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
    this.draggingSectionId,
    this.dragStartOverride,
    this.dragEndOverride,
    this.loopDragStartOverride,
    this.loopDragEndOverride,
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

  /// Resolve effective start/end for a section, applying drag override
  Duration _effectiveStart(Section section) {
    if (section.id == draggingSectionId && dragStartOverride != null) {
      return dragStartOverride!;
    }
    return section.startTime;
  }

  Duration _effectiveEnd(Section section) {
    if (section.id == draggingSectionId && dragEndOverride != null) {
      return dragEndOverride!;
    }
    return section.endTime;
  }

  Duration? get _effectiveLoopStart => loopDragStartOverride ?? loopStart;

  Duration? get _effectiveLoopEnd => loopDragEndOverride ?? loopEnd;

  double _timeToX(Duration time, double width) {
    return (time.inMilliseconds / duration.inMilliseconds) * width;
  }

  void _drawSections(Canvas canvas, Size size) {
    if (duration <= Duration.zero) return;

    for (final section in sections) {
      final startX = _timeToX(_effectiveStart(section), size.width);
      final endX = _timeToX(_effectiveEnd(section), size.width);
      final isDragging = section.id == draggingSectionId;

      // Background fill
      final paint = Paint()
        ..color = section.color.withValues(alpha: isDragging ? 0.14 : 0.08)
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTRB(startX, 0, endX, size.height), paint);

      // Start boundary line
      final startBorderPaint = Paint()
        ..color = section.color.withValues(alpha: isDragging ? 0.8 : 0.4)
        ..strokeWidth = isDragging ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX, size.height),
        startBorderPaint,
      );

      // End boundary line
      final endBorderPaint = Paint()
        ..color = section.color.withValues(alpha: isDragging ? 0.8 : 0.4)
        ..strokeWidth = isDragging ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(endX, 0),
        Offset(endX, size.height),
        endBorderPaint,
      );

      // Draw drag handles on both boundaries
      _drawHandle(canvas, startX, size.height, section.color, isDragging);
      _drawHandle(canvas, endX, size.height, section.color, isDragging);

      // Section label chip at top
      _drawSectionLabel(canvas, startX, endX, section, size.width);
    }
  }

  void _drawHandle(
    Canvas canvas,
    double x,
    double height,
    Color color,
    bool active,
  ) {
    final centerY = height / 2;
    final handleWidth = active ? 10.0 : 7.0;
    final handleHeight = 28.0;

    // Handle background pill
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, centerY),
        width: handleWidth,
        height: handleHeight,
      ),
      Radius.circular(handleWidth / 2),
    );

    final bgPaint = Paint()
      ..color = color.withValues(alpha: active ? 0.6 : 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRect, bgPaint);

    if (active) {
      // Glow when dragging
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawRRect(bgRect, glowPaint);
    }

    // Grip lines (3 small horizontal lines)
    final gripPaint = Paint()
      ..color = Colors.white.withValues(alpha: active ? 0.9 : 0.6)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (int i = -1; i <= 1; i++) {
      final gy = centerY + i * 4.0;
      canvas.drawLine(Offset(x - 2.0, gy), Offset(x + 2.0, gy), gripPaint);
    }
  }

  void _drawSectionLabel(
    Canvas canvas,
    double startX,
    double endX,
    Section section,
    double totalWidth,
  ) {
    final centerX = (startX + endX) / 2;
    final label = section.label;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: section.color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final sectionWidth = endX - startX;
    final maxChipWidth = sectionWidth - 4;
    final chipHeight = 18.0;
    final chipY = 6.0;

    if (maxChipWidth <= 8) return;

    // Relayout with ellipsis if text is wider than the section allows
    final constrainedTextWidth = maxChipWidth - 12;
    if (textPainter.width > constrainedTextWidth) {
      final ellipsizedPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: section.color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
        ellipsis: '…',
        maxLines: 1,
      )..layout(maxWidth: constrainedTextWidth);

      final chipWidth = ellipsizedPainter.width + 12;

      final chipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(startX + 2, chipY, chipWidth, chipHeight),
        const Radius.circular(5),
      );

      final chipBg = Paint()
        ..color = section.color.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(chipRect, chipBg);

      final chipBorder = Paint()
        ..color = section.color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawRRect(chipRect, chipBorder);

      ellipsizedPainter.paint(
        canvas,
        Offset(
          startX + 2 + 6,
          chipY + (chipHeight - ellipsizedPainter.height) / 2,
        ),
      );
      return;
    }

    final chipWidth = textPainter.width + 12;

    // Clamp so the chip doesn't overflow the section or the waveform
    final clampedCenterX = centerX.clamp(
      startX + chipWidth / 2,
      endX - chipWidth / 2,
    );

    final chipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(clampedCenterX, chipY + chipHeight / 2),
        width: chipWidth,
        height: chipHeight,
      ),
      const Radius.circular(5),
    );

    // Chip background
    final chipBg = Paint()
      ..color = section.color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(chipRect, chipBg);

    // Chip border
    final chipBorder = Paint()
      ..color = section.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(chipRect, chipBorder);

    // Text
    textPainter.paint(
      canvas,
      Offset(
        clampedCenterX - textPainter.width / 2,
        chipY + (chipHeight - textPainter.height) / 2,
      ),
    );
  }

  void _drawLoopRegion(Canvas canvas, Size size) {
    final effectiveStart = _effectiveLoopStart!;
    final effectiveEnd = _effectiveLoopEnd!;
    final startX =
        (effectiveStart.inMilliseconds / duration.inMilliseconds) * size.width;
    final endX =
        (effectiveEnd.inMilliseconds / duration.inMilliseconds) * size.width;
    final isDragging =
        loopDragStartOverride != null || loopDragEndOverride != null;
    final loopColor = loopEnabled ? primaryColor : mutedColor;

    // Loop region background
    final bgPaint = Paint()
      ..color = loopEnabled
          ? primaryColor.withValues(alpha: isDragging ? 0.14 : 0.08)
          : mutedColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTRB(startX, 0, endX, size.height), bgPaint);

    // Loop boundary lines
    final linePaint = Paint()
      ..color = loopColor
      ..strokeWidth = isDragging ? 2.5 : 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), linePaint);
    canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), linePaint);

    // Draw drag handles on both boundaries, matching section handles.
    _drawHandle(
      canvas,
      startX,
      size.height,
      loopColor,
      loopDragStartOverride != null,
    );
    _drawHandle(
      canvas,
      endX,
      size.height,
      loopColor,
      loopDragEndOverride != null,
    );

    // Draw A/B labels
    _drawMarkerLabel(canvas, startX, 'A', loopColor);
    _drawMarkerLabel(canvas, endX, 'B', loopColor);
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
      Rect.fromCenter(center: Offset(x, 14), width: 20, height: 18),
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
        // Unplayed portion — white with low opacity for contrast over album art
        color = Colors.white.withValues(alpha: 0.25);
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
        old.loopEnabled != loopEnabled ||
        old.draggingSectionId != draggingSectionId ||
        old.dragStartOverride != dragStartOverride ||
        old.dragEndOverride != dragEndOverride ||
        old.loopDragStartOverride != loopDragStartOverride ||
        old.loopDragEndOverride != loopDragEndOverride;
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
  final ValueChanged<Section>? onSectionUpdated;
  final ValueChanged<Section?>? onSectionDragging;
  final void Function(Duration start, Duration end)? onLoopUpdated;
  /// When set, dragging loop or section handles of this section moves both together.
  final void Function(Duration start, Duration end)? onLoopBoundUpdated;
  final int? loopBoundSectionId;
  final Section? draggingSection;
  final String? albumArtPath;

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
    this.onSectionUpdated,
    this.onSectionDragging,
    this.onLoopUpdated,
    this.onLoopBoundUpdated,
    this.loopBoundSectionId,
    this.draggingSection,
    this.albumArtPath,
  });

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  _SectionDragState? _dragState;
  _LoopDragState? _loopDragState;
  bool _albumArtExists = false;
  bool _isPlayheadDrag = false;

  static const double _handleHitRadius = 18.0;
  static const double _playheadHitRadius = 12.0;
  static const int _minSectionMs = 1000; // 1 second minimum
  static const int _minLoopMs = 1000; // 1 second minimum

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _updateAlbumArtExists();
  }

  @override
  void didUpdateWidget(covariant WaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumArtPath != widget.albumArtPath) {
      _updateAlbumArtExists();
    }
  }

  void _updateAlbumArtExists() {
    _albumArtExists =
        widget.albumArtPath != null && File(widget.albumArtPath!).existsSync();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  // ── Hit testing: find if touch is near a range handle ──

  /// Returns true if the touch is near the playhead cursor.
  bool _hitTestPlayhead(Offset localPos, double width) {
    if (widget.duration <= Duration.zero) return false;
    final cursorX = widget.progress * width;
    return (localPos.dx - cursorX).abs() <= _playheadHitRadius;
  }

  /// Returns a drag state if the position hits a loop handle, null otherwise.
  _LoopDragState? _hitTestLoopHandle(Offset localPos, double width) {
    if (widget.duration <= Duration.zero ||
        widget.loopStart == null ||
        widget.loopEnd == null) {
      return null;
    }

    final totalMs = widget.duration.inMilliseconds.toDouble();
    final startX = (widget.loopStart!.inMilliseconds / totalMs) * width;
    final endX = (widget.loopEnd!.inMilliseconds / totalMs) * width;

    // Check B first so it wins when A/B are close together.
    if ((localPos.dx - endX).abs() <= _handleHitRadius) {
      return _LoopDragState(
        isDragStart: false,
        originalStart: widget.loopStart!,
        originalEnd: widget.loopEnd!,
        currentTime: widget.loopEnd!,
      );
    }
    if ((localPos.dx - startX).abs() <= _handleHitRadius) {
      return _LoopDragState(
        isDragStart: true,
        originalStart: widget.loopStart!,
        originalEnd: widget.loopEnd!,
        currentTime: widget.loopStart!,
      );
    }
    return null;
  }

  /// Returns a drag state if the position hits a section handle, null otherwise.
  _SectionDragState? _hitTestHandle(Offset localPos, double width) {
    if (widget.duration <= Duration.zero) return null;
    final totalMs = widget.duration.inMilliseconds.toDouble();

    for (final section in widget.sections) {
      final startX = (section.startTime.inMilliseconds / totalMs) * width;
      final endX = (section.endTime.inMilliseconds / totalMs) * width;

      // Check end handle first (so it wins when start==end overlap)
      if ((localPos.dx - endX).abs() <= _handleHitRadius) {
        return _SectionDragState(
          section: section,
          isDragStart: false,
          currentTime: section.endTime,
        );
      }
      if ((localPos.dx - startX).abs() <= _handleHitRadius) {
        return _SectionDragState(
          section: section,
          isDragStart: true,
          currentTime: section.startTime,
        );
      }
    }
    return null;
  }

  Duration _xToTime(double x, double width) {
    final totalMs = widget.duration.inMilliseconds.toDouble();
    final ms = (x / width * totalMs).round().clamp(0, totalMs.round());
    return Duration(milliseconds: ms);
  }

  // ── Gesture handlers ──

  void _handlePanStart(DragStartDetails details, BoxConstraints constraints) {
    // 1. Playhead has highest priority — always draggable
    if (_hitTestPlayhead(details.localPosition, constraints.maxWidth)) {
      setState(() => _isPlayheadDrag = true);
      return;
    }

    // 2. Loop handles
    final loopHit = _hitTestLoopHandle(
      details.localPosition,
      constraints.maxWidth,
    );
    if (loopHit != null && (widget.onLoopUpdated != null || widget.onLoopBoundUpdated != null)) {
      // If loop is bound to a section, also start a section drag for visual sync
      if (widget.loopBoundSectionId != null) {
        final boundSection = widget.sections
            .where((s) => s.id == widget.loopBoundSectionId)
            .firstOrNull;
        if (boundSection != null) {
          setState(() {
            _loopDragState = loopHit;
            _dragState = _SectionDragState(
              section: boundSection,
              isDragStart: loopHit.isDragStart,
              currentTime: loopHit.isDragStart
                  ? boundSection.startTime
                  : boundSection.endTime,
            );
          });
          return;
        }
      }
      setState(() => _loopDragState = loopHit);
      return;
    }

    // 3. Section handles
    final hit = _hitTestHandle(details.localPosition, constraints.maxWidth);
    if (hit != null && widget.onSectionUpdated != null) {
      // If this section is bound to the loop, also start a loop drag for visual sync
      if (widget.loopBoundSectionId != null &&
          hit.section.id == widget.loopBoundSectionId &&
          widget.loopStart != null &&
          widget.loopEnd != null) {
        setState(() {
          _dragState = hit;
          _loopDragState = _LoopDragState(
            isDragStart: hit.isDragStart,
            originalStart: widget.loopStart!,
            originalEnd: widget.loopEnd!,
            currentTime: hit.isDragStart
                ? widget.loopStart!
                : widget.loopEnd!,
          );
        });
      } else {
        setState(() => _dragState = hit);
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isPlayheadDrag) {
      // Dragging the playhead — seek directly
      if (widget.onSeek == null) return;
      final progress = details.localPosition.dx / constraints.maxWidth;
      widget.onSeek!(progress.clamp(0.0, 1.0));
    } else if (_loopDragState != null && _dragState != null) {
      // Bound drag: loop + section move together
      final time = _xToTime(
        details.localPosition.dx.clamp(0, constraints.maxWidth),
        constraints.maxWidth,
      );
      final clampedLoopTime = _clampLoopDragTime(time);
      setState(() {
        _loopDragState!.currentTime = clampedLoopTime;
        _dragState!.currentTime = clampedLoopTime;
      });
      // Notify parent of live drag position
      final ds = _dragState!;
      final transient = ds.isDragStart
          ? ds.section.copyWith(startTime: ds.currentTime)
          : ds.section.copyWith(endTime: ds.currentTime);
      widget.onSectionDragging?.call(transient);
    } else if (_loopDragState != null) {
      // Dragging a loop handle only
      final time = _xToTime(
        details.localPosition.dx.clamp(0, constraints.maxWidth),
        constraints.maxWidth,
      );
      setState(() {
        _loopDragState!.currentTime = _clampLoopDragTime(time);
      });
    } else if (_dragState != null) {
      // Dragging a section handle only
      final time = _xToTime(
        details.localPosition.dx.clamp(0, constraints.maxWidth),
        constraints.maxWidth,
      );
      setState(() {
        _dragState!.currentTime = _clampDragTime(time);
      });
      // Notify parent of live drag position
      final ds = _dragState!;
      final transient = ds.isDragStart
          ? ds.section.copyWith(startTime: ds.currentTime)
          : ds.section.copyWith(endTime: ds.currentTime);
      widget.onSectionDragging?.call(transient);
    } else {
      // Normal seek
      if (widget.onSeek == null) return;
      final progress = details.localPosition.dx / constraints.maxWidth;
      widget.onSeek!(progress.clamp(0.0, 1.0));
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isPlayheadDrag) {
      setState(() => _isPlayheadDrag = false);
    } else if (_loopDragState != null && _dragState != null) {
      // Bound drag — commit both together
      _commitBoundDrag();
    } else if (_loopDragState != null) {
      _commitLoopDrag();
    } else if (_dragState != null) {
      _commitDrag();
    }
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    // Only seek if not near a handle or playhead (handles are for dragging)
    if (widget.onSeek == null) return;
    // Playhead tap = seek (allow it, no need to block)
    final loopHit = _hitTestLoopHandle(
      details.localPosition,
      constraints.maxWidth,
    );
    if (loopHit != null) return; // Don't seek when tapping on a loop handle
    final hit = _hitTestHandle(details.localPosition, constraints.maxWidth);
    if (hit != null) return; // Don't seek when tapping on a handle
    final progress = details.localPosition.dx / constraints.maxWidth;
    widget.onSeek!(progress.clamp(0.0, 1.0));
  }

  /// Clamp the drag time to enforce minimum section duration
  Duration _clampDragTime(Duration time) {
    final ds = _dragState!;
    if (ds.isDragStart) {
      // Start handle: can't go past (endTime - min)
      final maxTime =
          ds.section.endTime - const Duration(milliseconds: _minSectionMs);
      if (time > maxTime) return maxTime;
      if (time < Duration.zero) return Duration.zero;
      return time;
    } else {
      // End handle: can't go before (startTime + min)
      final minTime =
          ds.section.startTime + const Duration(milliseconds: _minSectionMs);
      if (time < minTime) return minTime;
      if (time > widget.duration) return widget.duration;
      return time;
    }
  }

  /// Clamp the drag time to enforce minimum loop duration
  Duration _clampLoopDragTime(Duration time) {
    final ds = _loopDragState!;
    if (ds.isDragStart) {
      final maxTime = ds.originalEnd - const Duration(milliseconds: _minLoopMs);
      if (time > maxTime) return maxTime;
      if (time < Duration.zero) return Duration.zero;
      return time;
    } else {
      final minTime =
          ds.originalStart + const Duration(milliseconds: _minLoopMs);
      if (time < minTime) return minTime;
      if (time > widget.duration) return widget.duration;
      return time;
    }
  }

  void _commitLoopDrag() {
    final ds = _loopDragState!;
    final updatedStart = ds.isDragStart ? ds.currentTime : ds.originalStart;
    final updatedEnd = ds.isDragStart ? ds.originalEnd : ds.currentTime;
    widget.onLoopUpdated?.call(updatedStart, updatedEnd);
    setState(() => _loopDragState = null);
  }

  /// Commit a bound drag where both loop and section were being dragged together.
  void _commitBoundDrag() {
    final lds = _loopDragState!;
    final updatedStart = lds.isDragStart ? lds.currentTime : lds.originalStart;
    final updatedEnd = lds.isDragStart ? lds.originalEnd : lds.currentTime;
    // Use the bound callback to sync both section and loop
    if (widget.onLoopBoundUpdated != null) {
      widget.onLoopBoundUpdated!(updatedStart, updatedEnd);
    } else {
      widget.onLoopUpdated?.call(updatedStart, updatedEnd);
    }
    widget.onSectionDragging?.call(null);
    setState(() {
      _loopDragState = null;
      _dragState = null;
    });
  }

  void _commitDrag() {
    final ds = _dragState!;
    final updated = ds.isDragStart
        ? ds.section.copyWith(startTime: ds.currentTime)
        : ds.section.copyWith(endTime: ds.currentTime);
    widget.onSectionUpdated?.call(updated);
    widget.onSectionDragging?.call(null);
    setState(() => _dragState = null);
  }

  @override
  Widget build(BuildContext context) {
    // Compute drag overlay for painter — local drag takes priority, then external
    int? draggingSectionId;
    Duration? dragStartOverride;
    Duration? dragEndOverride;
    Duration? loopDragStartOverride;
    Duration? loopDragEndOverride;

    if (_loopDragState != null) {
      if (_loopDragState!.isDragStart) {
        loopDragStartOverride = _loopDragState!.currentTime;
        loopDragEndOverride = _loopDragState!.originalEnd;
      } else {
        loopDragStartOverride = _loopDragState!.originalStart;
        loopDragEndOverride = _loopDragState!.currentTime;
      }
    }

    if (_dragState != null) {
      // Local drag (user dragging waveform handles)
      draggingSectionId = _dragState!.section.id;
      if (_dragState!.isDragStart) {
        dragStartOverride = _dragState!.currentTime;
        dragEndOverride = _dragState!.section.endTime;
      } else {
        dragStartOverride = _dragState!.section.startTime;
        dragEndOverride = _dragState!.currentTime;
      }
    } else if (widget.draggingSection != null) {
      // External drag (user dragging top bar pill)
      draggingSectionId = widget.draggingSection!.id;
      dragStartOverride = widget.draggingSection!.startTime;
      dragEndOverride = widget.draggingSection!.endTime;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (d) => _handleTap(d, constraints),
          onPanStart: (d) => _handlePanStart(d, constraints),
          onPanUpdate: (d) => _handlePanUpdate(d, constraints),
          onPanEnd: _handlePanEnd,
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Album art background (blurred & faded)
                  if (_albumArtExists)
                    RepaintBoundary(
                      child: Opacity(
                        opacity: 0.20,
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: 10,
                            sigmaY: 10,
                            tileMode: TileMode.decal,
                          ),
                          child: Image.file(
                            File(widget.albumArtPath!),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            cacheWidth: 400,
                            filterQuality: FilterQuality.low,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  // Waveform overlay
                  CustomPaint(
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
                      draggingSectionId: draggingSectionId,
                      dragStartOverride: dragStartOverride,
                      dragEndOverride: dragEndOverride,
                      loopDragStartOverride: loopDragStartOverride,
                      loopDragEndOverride: loopDragEndOverride,
                    ),
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                ],
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
    final envelope =
        0.3 +
        0.4 * math.sin(t * math.pi) +
        0.2 * math.sin(t * math.pi * 3) +
        0.1 * math.sin(t * math.pi * 7);
    final noise = random.nextDouble() * 0.3;
    data.add((envelope + noise).clamp(0.05, 1.0));
  }
  return data;
}
