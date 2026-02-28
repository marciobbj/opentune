import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/track.dart';
import '../../../domain/entities/section.dart';
import '../../../data/datasources/local_database.dart';
import '../../providers/player_provider.dart';
import '../../providers/navigation_provider.dart';
import 'widgets/waveform_view.dart';
import 'widgets/transport_controls.dart';
import 'widgets/top_bar.dart';
import 'widgets/bottom_controls.dart';
import 'widgets/mini_waveform.dart';
import 'widgets/tempo_control.dart';
import 'widgets/pitch_control.dart';
import 'widgets/queue_panel.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin {
  late List<double> _demoWaveform;
  bool _showTempoPanel = false;
  bool _showPitchPanel = false;
  bool _showQueuePanel = false;
  Section? _draggingSection;

  @override
  void initState() {
    super.initState();
    _demoWaveform = generateDemoWaveform(200);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleTempoPanel() {
    setState(() {
      _showTempoPanel = !_showTempoPanel;
      if (_showTempoPanel) _showPitchPanel = false;
    });
  }

  void _togglePitchPanel() {
    setState(() {
      _showPitchPanel = !_showPitchPanel;
      if (_showPitchPanel) _showTempoPanel = false;
    });
  }

  void _toggleQueuePanel() {
    setState(() => _showQueuePanel = !_showQueuePanel);
  }

  void _onSectionDragging(Section? section) {
    setState(() => _draggingSection = section);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: context.colors.bgDarkest,
      body: Stack(
        children: [
          // Background gradient
          Container(decoration: BoxDecoration(color: context.colors.bgDarkest)),

          // Main content
          SafeArea(
            top: false,
            bottom: false,
            child: Row(
              children: [
                // Player content
                Expanded(
                  child: Column(
                    children: [
                      // Top bar
                      TopBar(
                        trackTitle:
                            state.currentTrack?.title ?? 'No Track Loaded',
                        trackArtist: state.currentTrack != null
                            ? [
                                    state.currentTrack!.artist,
                                    state.currentTrack!.album,
                                  ]
                                  .where(
                                    (s) =>
                                        s.isNotEmpty && s != 'Unknown Artist',
                                  )
                                  .join(' — ')
                            : 'Import a track to start practicing',
                        albumArtPath: state.currentTrack?.albumArtPath,
                        duration: state.duration,
                        position: state.position,
                        sections: state.sections,
                        onBackPressed: () =>
                            ref.read(navigationProvider.notifier).state = 0,
                        onQueueToggle: _toggleQueuePanel,
                        isQueueOpen: _showQueuePanel,
                        queueCount: state.queue.length,
                        onSectionUpdated: (section) =>
                            notifier.updateSection(section),
                        onSectionDragging: _onSectionDragging,
                        draggingSection: _draggingSection,
                      ),

                      // Main waveform
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: WaveformView(
                              key: ValueKey(state.waveformData),
                              waveformData: state.waveformData ?? _demoWaveform,
                              progress: state.progress,
                              duration: state.duration,
                              position: state.position,
                              sections: state.sections,
                              loopStart: state.settings.loopStart,
                              loopEnd: state.settings.loopEnd,
                              loopEnabled: state.settings.loopEnabled,
                              onSeek: (progress) =>
                                  notifier.seekToProgress(progress),
                              onSectionUpdated: (section) =>
                                  notifier.updateSection(section),
                              onSectionDragging: _onSectionDragging,
                              draggingSection: _draggingSection,
                            ),
                          ),
                        ),
                      ),

                      // Mini waveform & time
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: MiniWaveform(
                                key: ValueKey(state.waveformData),
                                waveformData:
                                    state.waveformData ?? _demoWaveform,
                                progress: state.progress,
                                duration: state.duration,
                                sections: state.sections,
                                loopStart: state.settings.loopStart,
                                loopEnd: state.settings.loopEnd,
                                loopEnabled: state.settings.loopEnabled,
                                onSeek: (progress) =>
                                    notifier.seekToProgress(progress),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(state.position),
                                  style: TextStyle(
                                    color: context.colors.textMuted,
                                    fontSize: 12,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                Text(
                                  '-${_formatDuration(state.duration - state.position)}',
                                  style: TextStyle(
                                    color: context.colors.textMuted,
                                    fontSize: 12,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Player Controls & Volume
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Centralized transport controls
                            TransportControls(
                              isPlaying: state.isPlaying,
                              isLoading: state.isLoading,
                              onPlayPause: () => notifier.togglePlayPause(),
                              onSkipForward: () => notifier.skipForward(),
                              onSkipBackward: () => notifier.skipBackward(),
                              onSkipToStart: () =>
                                  notifier.skipToPreviousTrack(),
                              onSkipToEnd: () => notifier.skipToNextTrack(),
                            ),

                            // Compact volume slider on the right
                            Positioned(
                              right: 20,
                              child: SizedBox(
                                width: 100,
                                child: Row(
                                  children: [
                                    Icon(
                                      state.volume == 0
                                          ? Icons.volume_off_rounded
                                          : state.volume < 0.5
                                          ? Icons.volume_down_rounded
                                          : Icons.volume_up_rounded,
                                      color: context.colors.textMuted
                                          .withValues(alpha: 0.6),
                                      size: 14,
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 3.5,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 10,
                                              ),
                                          activeTrackColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          inactiveTrackColor: context
                                              .colors
                                              .surfaceBorder
                                              .withValues(alpha: 0.15),
                                          thumbColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        child: Slider(
                                          value: state.volume,
                                          onChanged: (v) =>
                                              notifier.setVolume(v),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tempo/Pitch panels (expandable)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _showTempoPanel
                            ? _buildExpandablePanel(
                                child: TempoControl(
                                  tempo: state.settings.tempo,
                                  originalBpm:
                                      state.currentTrack?.originalBpm ?? 120.0,
                                  onChanged: (v) => notifier.setTempo(v),
                                ),
                              )
                            : _showPitchPanel
                            ? _buildExpandablePanel(
                                child: PitchControl(
                                  pitch: state.settings.pitch,
                                  onChanged: (v) => notifier.setPitch(v),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Bottom controls
                      BottomControls(
                        tempo: state.settings.tempo,
                        pitch: state.settings.pitch,
                        loopEnabled: state.settings.loopEnabled,
                        hasLoop: state.settings.hasLoop,
                        sectionCount: state.sections.length,
                        onTempoTap: _toggleTempoPanel,
                        onPitchTap: _togglePitchPanel,
                        onSectionsTap: () =>
                            _showSectionsSheet(context, state, notifier),
                        onLoopToggle: () =>
                            _showLoopSelector(context, state, notifier),
                      ),
                    ],
                  ),
                ),

                // Queue panel (slides in from right)
                ClipRect(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: _showQueuePanel
                        ? (MediaQuery.of(context).size.width * 0.3).clamp(
                            200.0,
                            350.0,
                          )
                        : 0,
                    child: _showQueuePanel
                        ? QueuePanel(
                            queue: state.queue,
                            currentIndex: state.queueIndex,
                            onClose: _toggleQueuePanel,
                            onTapTrack: (index) =>
                                notifier.skipToQueueIndex(index),
                            onRemoveTrack: (index) =>
                                notifier.removeFromQueue(index),
                            onReorder: (oldIndex, newIndex) =>
                                notifier.reorderQueue(oldIndex, newIndex),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          // FAB to import track
          if (state.currentTrack == null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 160,
              left: 0,
              right: 0,
              child: Center(
                child: _ImportTrackButton(
                  onPressed: () => _showImportDialog(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLoopSelector(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    if (state.currentTrack == null) return;

    final totalMs = state.duration.inMilliseconds.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final currentState = ref.read(playerProvider);
            final loopEnabled = currentState.settings.loopEnabled;
            final loopStart = currentState.settings.loopStart;
            final loopEnd = currentState.settings.loopEnd;

            // Determine current loop mode
            String activeMode = 'off';
            int? activeSectionId;
            if (loopEnabled && loopStart != null && loopEnd != null) {
              // Check if loop matches a section
              for (final s in currentState.sections) {
                if (s.startTime == loopStart && s.endTime == loopEnd) {
                  activeMode = 'section';
                  activeSectionId = s.id;
                  break;
                }
              }
              if (activeMode != 'section') {
                if (loopStart == Duration.zero &&
                    loopEnd == currentState.duration) {
                  activeMode = 'full';
                } else {
                  activeMode = 'custom';
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Loop Mode',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Off
                    _LoopOptionTile(
                      icon: Icons.block_rounded,
                      label: 'Off',
                      subtitle: 'No loop',
                      isActive: !loopEnabled,
                      color: context.colors.textMuted,
                      onTap: () {
                        notifier.clearLoop();
                        Navigator.pop(ctx);
                      },
                    ),

                    // Full Track
                    _LoopOptionTile(
                      icon: Icons.all_inclusive_rounded,
                      label: 'Full Track',
                      subtitle: _formatDuration(currentState.duration),
                      isActive: activeMode == 'full',
                      color: AppColors.markerCyan,
                      onTap: () {
                        notifier.setFullTrackLoop();
                        Navigator.pop(ctx);
                      },
                    ),

                    // Sections
                    if (currentState.sections.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SECTIONS',
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...currentState.sections.map((section) {
                        final isThisSection =
                            activeMode == 'section' &&
                            activeSectionId == section.id;
                        return _LoopOptionTile(
                          icon: Icons.bookmark_rounded,
                          label: section.label,
                          subtitle:
                              '${_formatDuration(section.startTime)} → ${_formatDuration(section.endTime)}',
                          isActive: isThisSection,
                          color: section.color,
                          onTap: () {
                            notifier.seekToSection(section);
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                    ],

                    const SizedBox(height: 8),

                    // Custom A→B
                    _LoopOptionTile(
                      icon: Icons.tune_rounded,
                      label: 'Custom Range',
                      subtitle: activeMode == 'custom'
                          ? '${_formatDuration(loopStart!)} → ${_formatDuration(loopEnd!)}'
                          : 'Set a custom loop range',
                      isActive: activeMode == 'custom',
                      color: AppColors.markerOrange,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCustomLoopDialog(
                          context,
                          state,
                          notifier,
                          totalMs,
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomLoopDialog(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    double totalMs,
  ) {
    double startMs =
        state.settings.loopStart?.inMilliseconds.toDouble() ??
        state.position.inMilliseconds.toDouble().clamp(0, totalMs);
    double endMs =
        state.settings.loopEnd?.inMilliseconds.toDouble() ??
        (startMs + 30000).clamp(0, totalMs);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Custom Loop Range',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TimeInputRow(
                      label: 'Loop Start (A)',
                      durationMs: startMs,
                      totalMs: totalMs,
                      color: AppColors.markerOrange,
                      onSliderChanged: (v) {
                        setDialogState(() {
                          startMs = v;
                          if (endMs <= startMs) {
                            endMs = (startMs + 1000).clamp(0, totalMs);
                          }
                        });
                      },
                      onTimeEdited: (ms) {
                        setDialogState(() {
                          startMs = ms.clamp(0, totalMs);
                          if (endMs <= startMs) {
                            endMs = (startMs + 1000).clamp(0, totalMs);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _TimeInputRow(
                      label: 'Loop End (B)',
                      durationMs: endMs,
                      totalMs: totalMs,
                      color: AppColors.markerOrange,
                      onSliderChanged: (v) {
                        setDialogState(() {
                          endMs = v;
                          if (startMs >= endMs) {
                            startMs = (endMs - 1000).clamp(0, totalMs);
                          }
                        });
                      },
                      onTimeEdited: (ms) {
                        setDialogState(() {
                          endMs = ms.clamp(0, totalMs);
                          if (startMs >= endMs) {
                            startMs = (endMs - 1000).clamp(0, totalMs);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Loop duration: ${_formatDurationPrecise(Duration(milliseconds: (endMs - startMs).round()))}',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    notifier.setCustomLoop(
                      Duration(milliseconds: startMs.round()),
                      Duration(milliseconds: endMs.round()),
                    );
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.markerOrange,
                    foregroundColor: context.colors.bgDarkest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Set Loop',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSectionsSheet(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    if (state.currentTrack == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Re-read sections from provider
            final currentState = ref.read(playerProvider);
            final sections = currentState.sections;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ctx.colors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sections',
                          style: TextStyle(
                            color: ctx.colors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAddSectionDialog(
                              this.context,
                              state,
                              notifier,
                            );
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                ctx,
                              ).colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: Theme.of(ctx).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (sections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bookmarks_outlined,
                              color: ctx.colors.textMuted.withValues(
                                alpha: 0.5,
                              ),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No sections yet',
                              style: TextStyle(
                                color: ctx.colors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add sections to mark parts of the song\n(Verse, Chorus, Solo, etc.)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ctx.colors.textDisabled,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sections.length,
                          itemBuilder: (context, index) {
                            final section = sections[index];
                            final isActive =
                                currentState.position >= section.startTime &&
                                currentState.position <= section.endTime;
                            return _SectionTile(
                              section: section,
                              isActive: isActive,
                              onTap: () {
                                notifier.seekToSection(section);
                                Navigator.pop(ctx);
                              },
                              onEdit: () {
                                Navigator.pop(ctx);
                                _showEditSectionDialog(
                                  this.context,
                                  state,
                                  notifier,
                                  section,
                                );
                              },
                              onDelete: () async {
                                await notifier.deleteSection(section.id!);
                                setSheetState(() {});
                              },
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Add section button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddSectionDialog(this.context, state, notifier);
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Section'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(ctx).colorScheme.primary,
                          side: BorderSide(
                            color: Theme.of(
                              ctx,
                            ).colorScheme.primary.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddSectionDialog(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    _showSectionDialog(
      context: context,
      state: state,
      notifier: notifier,
      title: 'Add Section',
      confirmLabel: 'Add',
    );
  }

  void _showEditSectionDialog(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    Section section,
  ) {
    _showSectionDialog(
      context: context,
      state: state,
      notifier: notifier,
      title: 'Edit Section',
      confirmLabel: 'Save',
      existingSection: section,
    );
  }

  void _showSectionDialog({
    required BuildContext context,
    required PlayerState state,
    required PlayerNotifier notifier,
    required String title,
    required String confirmLabel,
    Section? existingSection,
  }) {
    if (state.currentTrack == null) return;

    final totalMs = state.duration.inMilliseconds.toDouble();
    if (totalMs <= 0) return;

    final nameController = TextEditingController(
      text: existingSection?.label ?? '',
    );
    double startMs =
        existingSection?.startTime.inMilliseconds.toDouble() ??
        state.position.inMilliseconds.toDouble().clamp(0, totalMs);
    double endMs =
        existingSection?.endTime.inMilliseconds.toDouble() ??
        (startMs + 30000).clamp(0, totalMs);

    int selectedColorIndex = 0;
    if (existingSection != null) {
      final idx = context.colors.markerColors.indexWhere(
        (c) => c.toARGB32() == existingSection.color.toARGB32(),
      );
      selectedColorIndex = idx >= 0 ? idx : 0;
    } else {
      selectedColorIndex =
          state.sections.length % context.colors.markerColors.length;
    }

    final sectionLabels = [
      'Intro',
      'Verse',
      'Pre-Chorus',
      'Chorus',
      'Bridge',
      'Solo',
      'Outro',
      'Riff',
      'Break',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        style: TextStyle(color: context.colors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Section Name',
                          labelStyle: TextStyle(
                            color: context.colors.textMuted,
                          ),
                          hintText: 'e.g. Verse 1, Chorus, Solo...',
                          hintStyle: TextStyle(
                            color: context.colors.textMuted.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          filled: true,
                          fillColor: context.colors.bgDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Quick label buttons
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sectionLabels.map((label) {
                          return GestureDetector(
                            onTap: () {
                              nameController.text = label;
                              setDialogState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.bgMedium,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: nameController.text == label
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.5)
                                      : context.colors.surfaceBorder.withValues(
                                          alpha: 0.3,
                                        ),
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: nameController.text == label
                                      ? Theme.of(context).colorScheme.primary
                                      : context.colors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Color picker
                      Text(
                        'Color',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(
                          context.colors.markerColors.length,
                          (i) => GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedColorIndex = i),
                            child: Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: context.colors.markerColors[i],
                                shape: BoxShape.circle,
                                border: selectedColorIndex == i
                                    ? Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      )
                                    : null,
                                boxShadow: selectedColorIndex == i
                                    ? [
                                        BoxShadow(
                                          color: context.colors.markerColors[i]
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Start time row with editable field
                      _TimeInputRow(
                        label: 'Start',
                        durationMs: startMs,
                        totalMs: totalMs,
                        color: context.colors.markerColors[selectedColorIndex],
                        onSliderChanged: (v) {
                          setDialogState(() {
                            startMs = v;
                            if (endMs <= startMs) {
                              endMs = (startMs + 1000).clamp(0, totalMs);
                            }
                          });
                        },
                        onTimeEdited: (ms) {
                          setDialogState(() {
                            startMs = ms.clamp(0, totalMs);
                            if (endMs <= startMs) {
                              endMs = (startMs + 1000).clamp(0, totalMs);
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 8),

                      // End time row with editable field
                      _TimeInputRow(
                        label: 'End',
                        durationMs: endMs,
                        totalMs: totalMs,
                        color: context.colors.markerColors[selectedColorIndex],
                        onSliderChanged: (v) {
                          setDialogState(() {
                            endMs = v;
                            if (startMs >= endMs) {
                              startMs = (endMs - 1000).clamp(0, totalMs);
                            }
                          });
                        },
                        onTimeEdited: (ms) {
                          setDialogState(() {
                            endMs = ms.clamp(0, totalMs);
                            if (startMs >= endMs) {
                              startMs = (endMs - 1000).clamp(0, totalMs);
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 8),

                      // Duration info
                      Center(
                        child: Text(
                          'Duration: ${_formatDurationPrecise(Duration(milliseconds: (endMs - startMs).round()))}',
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    if (existingSection != null) {
                      // Edit existing
                      await notifier.updateSection(
                        existingSection.copyWith(
                          label: name,
                          startTime: Duration(milliseconds: startMs.round()),
                          endTime: Duration(milliseconds: endMs.round()),
                          color:
                              context.colors.markerColors[selectedColorIndex],
                        ),
                      );
                    } else {
                      // Add new
                      await notifier.addSection(
                        name,
                        Duration(milliseconds: startMs.round()),
                        Duration(milliseconds: endMs.round()),
                        context.colors.markerColors[selectedColorIndex]
                            .toARGB32(),
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: context.colors.bgDarkest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDurationPrecise(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$minutes:$seconds.$millis';
  }

  Widget _buildExpandablePanel({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.bgCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.surfaceBorder.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }

  void _showImportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Icon(
                  Icons.library_music_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Import a Track',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select an audio file to start practicing.\nSupported formats: MP3, WAV, FLAC, AAC, OGG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _importTrack();
                    },
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Browse Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: context.colors.bgDarkest,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _importTrack() async {
    try {
      final filePath = await _pickAudioFile();
      if (filePath == null || filePath.trim().isEmpty) return;

      // Validate file exists
      final file = File(filePath.trim());
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File not found. Please check the path.'),
              backgroundColor: context.colors.error,
            ),
          );
        }
        return;
      }

      final notifier = ref.read(playerProvider.notifier);
      final track = await _createTrackFromFile(filePath.trim());
      await notifier.loadTrack(track);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing track: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  Future<String?> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'flac',
          'wav',
          'ogg',
          'aac',
          'm4a',
          'opus',
          'wma',
          'aiff',
        ],
        dialogTitle: 'Select an audio file',
      );
      return result?.files.single.path;
    } catch (e) {
      // Fallback to manual path input if file picker fails
      return _showManualPathDialog();
    }
  }

  Future<String?> _showManualPathDialog() async {
    String? path;
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: context.colors.bgCard,
          title: Text(
            'Enter audio file path',
            style: TextStyle(color: context.colors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              hintText: '/path/to/audio.flac',
              hintStyle: TextStyle(color: context.colors.textMuted),
              filled: true,
              fillColor: context.colors.bgDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) {
              path = value;
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                path = controller.text;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: context.colors.bgDarkest,
              ),
              child: const Text('Load'),
            ),
          ],
        );
      },
    );
    return path;
  }

  Future<Track> _createTrackFromFile(String filePath) async {
    final now = DateTime.now();
    final fileName = filePath.split('/').last;
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    // Try to get from DB first
    final existing = await LocalDatabase.getTrackByPath(filePath);
    if (existing != null) return existing;

    // Create new track
    final track = Track(
      title: nameWithoutExt,
      artist: 'Unknown Artist',
      filePath: filePath,
      duration: Duration.zero,
      createdAt: now,
      updatedAt: now,
    );

    final id = await LocalDatabase.insertTrack(track);
    return track.copyWith(id: id);
  }
}

class _ImportTrackButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _ImportTrackButton({this.onPressed});

  @override
  State<_ImportTrackButton> createState() => _ImportTrackButtonState();
}

class _ImportTrackButtonState extends State<_ImportTrackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PulseAnimatedBuilder(
      listenable: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _pulseAnimation.value, child: child);
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                color: context.colors.bgDarkest,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Import Track',
                style: TextStyle(
                  color: context.colors.bgDarkest,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseAnimatedBuilder extends StatelessWidget {
  final Listenable listenable;
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const _PulseAnimatedBuilder({
    required this.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _PulseAnimatedWidget(
      animation: listenable as Animation<double>,
      builder: builder,
      child: child,
    );
  }
}

class _PulseAnimatedWidget extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const _PulseAnimatedWidget({
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

class _SectionTile extends StatelessWidget {
  final Section section;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SectionTile({
    required this.section,
    this.isActive = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? section.color.withValues(alpha: 0.1)
            : context.colors.bgMedium.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? section.color.withValues(alpha: 0.4)
              : context.colors.surfaceBorder.withValues(alpha: 0.2),
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Color indicator
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: section.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),

                // Section info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.label,
                        style: TextStyle(
                          color: isActive
                              ? section.color
                              : context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatTime(section.startTime)} → ${_formatTime(section.endTime)}',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_rounded,
                    color: context.colors.textMuted,
                    size: 18,
                  ),
                ),

                // Delete
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: context.colors.error.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoopOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _LoopOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.1)
            : context.colors.bgMedium.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: isActive ? color : context.colors.textMuted),
        title: Text(
          label,
          style: TextStyle(
            color: isActive
                ? context.colors.textPrimary
                : context.colors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: context.colors.textMuted, fontSize: 11),
        ),
        trailing: isActive
            ? Icon(Icons.check_circle_rounded, color: color, size: 20)
            : null,
      ),
    );
  }
}

class _TimeInputRow extends StatelessWidget {
  final String label;
  final double durationMs;
  final double totalMs;
  final Color color;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<double> onTimeEdited;

  const _TimeInputRow({
    required this.label,
    required this.durationMs,
    required this.totalMs,
    required this.color,
    required this.onSliderChanged,
    required this.onTimeEdited,
  });

  String _formatTime(double ms) {
    final d = Duration(milliseconds: ms.round());
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$minutes:$seconds.$millis';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () async {
                final result = await _showTimeEditDialog(context);
                if (result != null) onTimeEdited(result);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.bgMedium,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatTime(durationMs),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: color,
            inactiveTrackColor: context.colors.surfaceBorder.withValues(
              alpha: 0.3,
            ),
            thumbColor: color,
          ),
          child: Slider(
            value: durationMs,
            max: totalMs,
            onChanged: onSliderChanged,
          ),
        ),
      ],
    );
  }

  Future<double?> _showTimeEditDialog(BuildContext context) async {
    final d = Duration(milliseconds: durationMs.round());
    final minController = TextEditingController(text: d.inMinutes.toString());
    final secController = TextEditingController(
      text: d.inSeconds.remainder(60).toString(),
    );

    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgCard,
        title: Text('Set $label', style: TextStyle(fontSize: 16)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Min'),
                autofocus: true,
              ),
            ),
            const SizedBox(width: 12),
            Text(':', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: secController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Sec'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final m = int.tryParse(minController.text) ?? 0;
              final s = int.tryParse(secController.text) ?? 0;
              Navigator.pop(ctx, (m * 60 + s) * 1000.0);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
