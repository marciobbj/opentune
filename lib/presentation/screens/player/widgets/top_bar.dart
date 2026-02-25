import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/section.dart';

class TopBar extends StatelessWidget {
  final String trackTitle;
  final String trackArtist;
  final Duration duration;
  final Duration position;
  final List<Section> sections;
  final VoidCallback? onQueueToggle;
  final VoidCallback? onBackPressed;
  final bool isQueueOpen;
  final int queueCount;
  final ValueChanged<Section>? onSectionUpdated;
  final ValueChanged<Section?>? onSectionDragging;
  final Section? draggingSection;

  const TopBar({
    super.key,
    required this.trackTitle,
    required this.trackArtist,
    required this.duration,
    required this.position,
    this.sections = const [],
    this.onQueueToggle,
    this.onBackPressed,
    this.isQueueOpen = false,
    this.queueCount = 0,
    this.onSectionUpdated,
    this.onSectionDragging,
    this.draggingSection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        bottom: 0,
      ),
      decoration: BoxDecoration(
        color: context.colors.bgDarkest.withValues(alpha: 0.95),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track info row
          Row(
            children: [
              if (onBackPressed != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                  color: context.colors.textSecondary,
                  onPressed: onBackPressed,
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      trackTitle,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trackArtist,
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Badge(
                  isLabelVisible: queueCount > 0 && !isQueueOpen,
                  label: Text(
                    '$queueCount',
                    style: TextStyle(
                      color: context.colors.bgDarkest,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    isQueueOpen
                        ? Icons.queue_music_rounded
                        : Icons.queue_music_outlined,
                    size: 22,
                  ),
                ),
                color: isQueueOpen
                    ? Theme.of(context).colorScheme.primary
                    : context.colors.textSecondary,
                onPressed: onQueueToggle,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Section markers timeline
          if (sections.isNotEmpty)
            SizedBox(
              height: 28,
              child: _SectionTimeline(
                sections: sections,
                duration: duration,
                position: position,
                onSectionUpdated: onSectionUpdated,
                onSectionDragging: onSectionDragging,
                draggingSection: draggingSection,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTimeline extends StatefulWidget {
  final List<Section> sections;
  final Duration duration;
  final Duration position;
  final ValueChanged<Section>? onSectionUpdated;
  final ValueChanged<Section?>? onSectionDragging;
  final Section? draggingSection;

  const _SectionTimeline({
    required this.sections,
    required this.duration,
    required this.position,
    this.onSectionUpdated,
    this.onSectionDragging,
    this.draggingSection,
  });

  @override
  State<_SectionTimeline> createState() => _SectionTimelineState();
}

class _SectionTimelineState extends State<_SectionTimeline> {
  // Drag state
  Section? _draggingSection;
  double _dragOffsetX = 0; // current left position during drag
  double _dragAnchorX = 0; // where inside the chip the user grabbed

  @override
  Widget build(BuildContext context) {
    if (widget.duration <= Duration.zero) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalMs = widget.duration.inMilliseconds.toDouble();
        final width = constraints.maxWidth;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Background bar
            Container(
              height: 3,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: context.colors.surfaceBorder.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Section blocks
            ...widget.sections.map((section) {
              final isLocalDrag =
                  _draggingSection != null &&
                  _draggingSection!.id == section.id;
              final isExternalDrag =
                  !isLocalDrag &&
                  widget.draggingSection != null &&
                  widget.draggingSection!.id == section.id;
              final isDragging = isLocalDrag || isExternalDrag;

              final double startX;
              final double endX;
              final double sectionWidth;

              if (isLocalDrag) {
                // Use local drag pixel position
                final sectionMs =
                    section.endTime.inMilliseconds -
                    section.startTime.inMilliseconds;
                sectionWidth = ((sectionMs / totalMs) * width).clamp(
                  20.0,
                  width,
                );
                startX = _dragOffsetX;
                endX = startX + sectionWidth;
              } else if (isExternalDrag) {
                // Use external drag section times (from waveform handle drag)
                final ds = widget.draggingSection!;
                startX = (ds.startTime.inMilliseconds / totalMs) * width;
                endX = (ds.endTime.inMilliseconds / totalMs) * width;
                sectionWidth = (endX - startX).clamp(20.0, width);
              } else {
                startX = (section.startTime.inMilliseconds / totalMs) * width;
                endX = (section.endTime.inMilliseconds / totalMs) * width;
                sectionWidth = (endX - startX).clamp(20.0, width);
              }

              final isActive =
                  !isDragging &&
                  widget.position >= section.startTime &&
                  widget.position <= section.endTime;

              return Positioned(
                left: startX,
                top: 0,
                child: GestureDetector(
                  onHorizontalDragStart: widget.onSectionUpdated != null
                      ? (details) {
                          setState(() {
                            _draggingSection = section;
                            _dragAnchorX = details.localPosition.dx;
                            _dragOffsetX =
                                (section.startTime.inMilliseconds / totalMs) *
                                width;
                          });
                        }
                      : null,
                  onHorizontalDragUpdate: widget.onSectionUpdated != null
                      ? (details) {
                          if (_draggingSection?.id != section.id) return;
                          final sectionMs =
                              section.endTime.inMilliseconds -
                              section.startTime.inMilliseconds;
                          final sectionW = (sectionMs / totalMs) * width;
                          // New left = constrained to [0, width - sectionW]
                          final newOffsetX =
                              (details.globalPosition.dx -
                                      _dragAnchorX -
                                      _getTimelineGlobalLeft(context))
                                  .clamp(0.0, width - sectionW);
                          setState(() {
                            _dragOffsetX = newOffsetX;
                          });
                          // Notify parent of live drag position
                          final newStartMs = (newOffsetX / width * totalMs).round().clamp(0, totalMs.round());
                          final newEndMs = (newStartMs + sectionMs).clamp(0, totalMs.round());
                          widget.onSectionDragging?.call(section.copyWith(
                            startTime: Duration(milliseconds: newStartMs),
                            endTime: Duration(milliseconds: newEndMs),
                          ));
                        }
                      : null,
                  onHorizontalDragEnd: widget.onSectionUpdated != null
                      ? (details) {
                          if (_draggingSection?.id != section.id) return;
                          _commitDrag(width, totalMs, section);
                        }
                      : null,
                  onHorizontalDragCancel: () {
                    setState(() => _draggingSection = null);
                    widget.onSectionDragging?.call(null);
                  },
                  child: AnimatedContainer(
                    duration: isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    width: sectionWidth,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDragging
                          ? section.color.withValues(alpha: 0.25)
                          : isActive
                          ? section.color.withValues(alpha: 0.15)
                          : section.color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDragging
                            ? section.color.withValues(alpha: 0.8)
                            : section.color.withValues(
                                alpha: isActive ? 0.6 : 0.25,
                              ),
                        width: isDragging
                            ? 1.5
                            : isActive
                            ? 1.5
                            : 0.5,
                      ),
                      boxShadow: isDragging
                          ? [
                              BoxShadow(
                                color: section.color.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      section.label,
                      style: TextStyle(
                        color: section.color,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  double _getTimelineGlobalLeft(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return 0;
    return renderBox.localToGlobal(Offset.zero).dx;
  }

  void _commitDrag(double width, double totalMs, Section section) {
    final sectionDurationMs =
        section.endTime.inMilliseconds - section.startTime.inMilliseconds;

    // Convert drag pixel position to time
    final newStartMs = (_dragOffsetX / width * totalMs).round().clamp(
      0,
      totalMs.round(),
    );
    final newEndMs = (newStartMs + sectionDurationMs).clamp(0, totalMs.round());

    // Adjust start if end hit the wall
    final adjustedStartMs = newEndMs == totalMs.round()
        ? (totalMs.round() - sectionDurationMs).clamp(0, totalMs.round())
        : newStartMs;

    final updated = section.copyWith(
      startTime: Duration(milliseconds: adjustedStartMs),
      endTime: Duration(
        milliseconds: (adjustedStartMs + sectionDurationMs).clamp(
          0,
          totalMs.round(),
        ),
      ),
    );

    widget.onSectionUpdated?.call(updated);
    widget.onSectionDragging?.call(null);
    setState(() => _draggingSection = null);
  }
}
