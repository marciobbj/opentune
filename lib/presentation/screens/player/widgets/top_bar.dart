import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/section.dart';

class TopBar extends StatelessWidget {
  final String trackTitle;
  final String trackArtist;
  final Duration duration;
  final Duration position;
  final List<Section> sections;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onBackPressed;

  const TopBar({
    super.key,
    required this.trackTitle,
    required this.trackArtist,
    required this.duration,
    required this.position,
    this.sections = const [],
    this.onMenuPressed,
    this.onBackPressed,
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
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                color: context.colors.textSecondary,
                onPressed: onMenuPressed,
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
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTimeline extends StatelessWidget {
  final List<Section> sections;
  final Duration duration;
  final Duration position;

  const _SectionTimeline({
    required this.sections,
    required this.duration,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    if (duration <= Duration.zero) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalMs = duration.inMilliseconds.toDouble();
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
            ...sections.map((section) {
              final startX = (section.startTime.inMilliseconds / totalMs) * width;
              final endX = (section.endTime.inMilliseconds / totalMs) * width;
              final sectionWidth = (endX - startX).clamp(20.0, width);

              final isActive = position >= section.startTime &&
                  position <= section.endTime;

              return Positioned(
                left: startX,
                top: 0,
                child: Container(
                  width: sectionWidth,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive
                        ? section.color.withValues(alpha: 0.15)
                        : section.color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: section.color.withValues(alpha: isActive ? 0.6 : 0.25),
                      width: isActive ? 1.5 : 0.5,
                    ),
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
              );
            }),
          ],
        );
      },
    );
  }
}
