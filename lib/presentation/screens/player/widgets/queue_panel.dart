import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/track.dart';

class QueuePanel extends StatelessWidget {
  final List<Track> queue;
  final int currentIndex;
  final VoidCallback? onClose;
  final void Function(int index)? onTapTrack;
  final void Function(int index)? onRemoveTrack;
  final void Function(int oldIndex, int newIndex)? onReorder;

  const QueuePanel({
    super.key,
    required this.queue,
    required this.currentIndex,
    this.onClose,
    this.onTapTrack,
    this.onRemoveTrack,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.bgCard.withValues(alpha: 0.95),
        border: Border(
          left: BorderSide(
            color: context.colors.surfaceBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 8,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.colors.surfaceBorder.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Queue',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${queue.length} track${queue.length != 1 ? "s" : ""}',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colors.textMuted,
                    size: 20,
                  ),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Queue list
          Expanded(
            child: queue.isEmpty
                ? _buildEmptyState(context)
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: queue.length,
                    onReorder: (oldIndex, newIndex) {
                      onReorder?.call(oldIndex, newIndex);
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final elevation = Tween<double>(
                            begin: 0,
                            end: 6,
                          ).evaluate(animation);
                          return Material(
                            elevation: elevation,
                            color: context.colors.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final track = queue[index];
                      final isCurrent = index == currentIndex;

                      return Dismissible(
                        key: ValueKey(track.id ?? index),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => onRemoveTrack?.call(index),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.withValues(alpha: 0.7),
                            size: 20,
                          ),
                        ),
                        child: _QueueTrackTile(
                          key: ValueKey('tile_${track.id ?? index}'),
                          track: track,
                          isCurrent: isCurrent,
                          index: index,
                          onTap: () => onTapTrack?.call(index),
                          onRemove: () => onRemoveTrack?.call(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_outlined,
              color: context.colors.textMuted.withValues(alpha: 0.4),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'Queue is empty',
              style: TextStyle(color: context.colors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Play from a playlist\nto build a queue',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textDisabled,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueTrackTile extends StatelessWidget {
  final Track track;
  final bool isCurrent;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _QueueTrackTile({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.index,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: isCurrent
              ? BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                )
              : null,
          child: Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: context.colors.textMuted.withValues(alpha: 0.4),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),

              // Track icon / playing indicator
              SizedBox(
                width: 24,
                height: 24,
                child: isCurrent
                    ? Icon(
                        Icons.equalizer_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      )
                    : Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(width: 8),

              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.artist,
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Remove button
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: context.colors.textMuted.withValues(alpha: 0.5),
                  size: 16,
                ),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                splashRadius: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
