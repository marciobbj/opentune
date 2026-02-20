import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/track.dart';
import '../../../domain/entities/section.dart';
import '../../../data/datasources/local_database.dart';
import '../../providers/player_provider.dart';
import 'widgets/waveform_view.dart';
import 'widgets/transport_controls.dart';
import 'widgets/top_bar.dart';
import 'widgets/bottom_controls.dart';
import 'widgets/mini_waveform.dart';
import 'widgets/tempo_control.dart';
import 'widgets/pitch_control.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              color: AppColors.bgDarkest,
            ),
          ),

          // Main content
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                // Top bar
                TopBar(
                  trackTitle: state.currentTrack?.title ?? 'No Track Loaded',
                  trackArtist: state.currentTrack != null
                      ? [state.currentTrack!.artist, state.currentTrack!.album]
                          .where((s) => s.isNotEmpty && s != 'Unknown Artist')
                          .join(' — ')
                      : 'Import a track to start practicing',
                  duration: state.duration,
                  position: state.position,
                  sections: state.sections,
                  onBackPressed: () => Navigator.of(context).maybePop(),
                ),

                // Main waveform
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: WaveformView(
                      waveformData: state.waveformData ?? _demoWaveform,
                      progress: state.progress,
                      duration: state.duration,
                      position: state.position,
                      sections: state.sections,
                      loopStart: state.settings.loopStart,
                      loopEnd: state.settings.loopEnd,
                      loopEnabled: state.settings.loopEnabled,
                      onSeek: (progress) => notifier.seekToProgress(progress),
                    ),
                  ),
                ),

                // Mini waveform & time
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      MiniWaveform(
                        waveformData: state.waveformData ?? _demoWaveform,
                        progress: state.progress,
                        duration: state.duration,
                        sections: state.sections,
                        loopStart: state.settings.loopStart,
                        loopEnd: state.settings.loopEnd,
                        loopEnabled: state.settings.loopEnabled,
                        onSeek: (progress) =>
                            notifier.seekToProgress(progress),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(state.position),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            '-${_formatDuration(state.duration - state.position)}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Transport controls
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TransportControls(
                    isPlaying: state.isPlaying,
                    isLoading: state.isLoading,
                    onPlayPause: () => notifier.togglePlayPause(),
                    onSkipForward: () => notifier.skipForward(),
                    onSkipBackward: () => notifier.skipBackward(),
                    onSkipToStart: () => notifier.skipToStart(),
                    onSkipToEnd: () => notifier.skipToEnd(),
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
                            originalBpm: state.currentTrack?.originalBpm ?? 120.0,
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
                  onSectionsTap: () => _showSectionsSheet(context, state, notifier),
                  onLoopToggle: () => _showLoopSelector(context, state, notifier),
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
  void _showLoopSelector(BuildContext context, PlayerState state, PlayerNotifier notifier) {
    if (state.currentTrack == null) return;

    final totalMs = state.duration.inMilliseconds.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
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
                if (loopStart == Duration.zero && loopEnd == currentState.duration) {
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
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Loop Mode',
                        style: TextStyle(
                          color: AppColors.textPrimary,
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
                      color: AppColors.textMuted,
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
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SECTIONS',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...currentState.sections.map((section) {
                        final isThisSection = activeMode == 'section' && activeSectionId == section.id;
                        return _LoopOptionTile(
                          icon: Icons.bookmark_rounded,
                          label: section.label,
                          subtitle: '${_formatDuration(section.startTime)} → ${_formatDuration(section.endTime)}',
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
                        _showCustomLoopDialog(context, state, notifier, totalMs);
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

  void _showCustomLoopDialog(BuildContext context, PlayerState state, PlayerNotifier notifier, double totalMs) {
    double startMs = state.settings.loopStart?.inMilliseconds.toDouble() ??
        state.position.inMilliseconds.toDouble().clamp(0, totalMs);
    double endMs = state.settings.loopEnd?.inMilliseconds.toDouble() ??
        (startMs + 30000).clamp(0, totalMs);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Custom Loop Range',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
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
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                    foregroundColor: AppColors.bgDarkest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Set Loop', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSectionsSheet(BuildContext context, PlayerState state, PlayerNotifier notifier) {
    if (state.currentTrack == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sections',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddSectionDialog(context, state, notifier);
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: AppColors.primary,
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
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No sections yet',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add sections to mark parts of the song\n(Verse, Chorus, Solo, etc.)',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
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
                            final isActive = currentState.position >= section.startTime &&
                                currentState.position <= section.endTime;
                            return _SectionTile(
                              section: section,
                              isActive: isActive,
                              onTap: () {
                                notifier.seekToSection(section);
                                Navigator.pop(context);
                              },
                              onEdit: () {
                                Navigator.pop(context);
                                _showEditSectionDialog(
                                  this.context, state, notifier, section,
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
                          Navigator.pop(context);
                          _showAddSectionDialog(context, state, notifier);
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Section'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
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

  void _showAddSectionDialog(BuildContext context, PlayerState state, PlayerNotifier notifier) {
    _showSectionDialog(
      context: context,
      state: state,
      notifier: notifier,
      title: 'Add Section',
      confirmLabel: 'Add',
    );
  }

  void _showEditSectionDialog(BuildContext context, PlayerState state, PlayerNotifier notifier, Section section) {
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
    double startMs = existingSection?.startTime.inMilliseconds.toDouble() ??
        state.position.inMilliseconds.toDouble().clamp(0, totalMs);
    double endMs = existingSection?.endTime.inMilliseconds.toDouble() ??
        (startMs + 30000).clamp(0, totalMs);

    int selectedColorIndex = 0;
    if (existingSection != null) {
      final idx = AppColors.markerColors.indexWhere(
        (c) => c.toARGB32() == existingSection.color.toARGB32(),
      );
      selectedColorIndex = idx >= 0 ? idx : 0;
    } else {
      selectedColorIndex = state.sections.length % AppColors.markerColors.length;
    }

    final sectionLabels = ['Intro', 'Verse', 'Pre-Chorus', 'Chorus', 'Bridge', 'Solo', 'Outro', 'Riff', 'Break'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                title,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
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
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Section Name',
                          labelStyle: const TextStyle(color: AppColors.textMuted),
                          hintText: 'e.g. Verse 1, Chorus, Solo...',
                          hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppColors.bgDark,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.bgMedium,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: nameController.text == label
                                      ? AppColors.primary.withValues(alpha: 0.5)
                                      : AppColors.surfaceBorder.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: nameController.text == label
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
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
                      const Text(
                        'Color',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(
                          AppColors.markerColors.length,
                          (i) => GestureDetector(
                            onTap: () => setDialogState(() => selectedColorIndex = i),
                            child: Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.markerColors[i],
                                shape: BoxShape.circle,
                                border: selectedColorIndex == i
                                    ? Border.all(color: Colors.white, width: 2.5)
                                    : null,
                                boxShadow: selectedColorIndex == i
                                    ? [BoxShadow(
                                        color: AppColors.markerColors[i].withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      )]
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
                        color: AppColors.markerColors[selectedColorIndex],
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
                        color: AppColors.markerColors[selectedColorIndex],
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
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                          color: AppColors.markerColors[selectedColorIndex],
                        ),
                      );
                    } else {
                      // Add new
                      await notifier.addSection(
                        name,
                        Duration(milliseconds: startMs.round()),
                        Duration(milliseconds: endMs.round()),
                        AppColors.markerColors[selectedColorIndex].toARGB32(),
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.bgDarkest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
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
        color: AppColors.bgCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.surfaceBorder.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }

  void _showImportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
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
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Icon(
                  Icons.library_music_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Import a Track',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select an audio file to start practicing.\nSupported formats: MP3, WAV, FLAC, AAC, OGG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.bgDarkest,
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
            const SnackBar(
              content: Text('File not found. Please check the path.'),
              backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac', 'wav', 'ogg', 'aac', 'm4a', 'opus', 'wma', 'aiff'],
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
          backgroundColor: AppColors.bgCard,
          title: const Text(
            'Enter audio file path',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '/path/to/audio.flac',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.bgDark,
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
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.bgDarkest,
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
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: AppColors.bgDarkest, size: 24),
              SizedBox(width: 8),
              Text(
                'Import Track',
                style: TextStyle(
                  color: AppColors.bgDarkest,
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
            : AppColors.bgMedium.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? section.color.withValues(alpha: 0.4)
              : AppColors.surfaceBorder.withValues(alpha: 0.2),
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
                          color: isActive ? section.color : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatTime(section.startTime)} → ${_formatTime(section.endTime)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
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
                    color: isActive ? section.color : AppColors.textMuted,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  tooltip: 'Edit section',
                ),

                // Delete
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                    size: 18,
                  ),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  tooltip: 'Delete section',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row with label, editable time display, and slider
class _LoopOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final Color color;
  final VoidCallback? onTap;

  const _LoopOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.1)
            : AppColors.bgMedium.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.5)
              : AppColors.surfaceBorder.withValues(alpha: 0.15),
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
                Icon(
                  icon,
                  color: isActive ? color : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isActive ? color : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Icon(
                    Icons.check_circle_rounded,
                    color: color,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
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
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            GestureDetector(
              onTap: () => _showTimeInputDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.surfaceBorder.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(durationMs),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_rounded,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: AppColors.surfaceBorder,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: durationMs.clamp(0, totalMs),
            min: 0,
            max: totalMs,
            onChanged: onSliderChanged,
          ),
        ),
      ],
    );
  }

  void _showTimeInputDialog(BuildContext context) {
    final d = Duration(milliseconds: durationMs.round());
    final minCtrl = TextEditingController(text: d.inMinutes.remainder(60).toString());
    final secCtrl = TextEditingController(text: d.inSeconds.remainder(60).toString());

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Set $label Time',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 60,
                child: TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Min',
                    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    filled: true,
                    fillColor: AppColors.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: secCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Sec',
                    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    filled: true,
                    fillColor: AppColors.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final mins = int.tryParse(minCtrl.text) ?? 0;
                final secs = int.tryParse(secCtrl.text) ?? 0;
                final ms = ((mins * 60) + secs) * 1000;
                onTimeEdited(ms.toDouble());
                Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: AppColors.bgDarkest,
              ),
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }
}
