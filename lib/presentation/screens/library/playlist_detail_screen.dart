import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/local_database.dart';
import '../../../domain/entities/playlist.dart';
import '../../../domain/entities/track.dart';
import '../../providers/player_provider.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late Playlist _playlist;
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() => _isLoading = true);
    // Reload playlist to get latest trackIds
    final playlists = await LocalDatabase.getAllPlaylists();
    final current = playlists.where((p) => p.id == _playlist.id).firstOrNull;
    if (current != null) {
      _playlist = current;
    }

    final tracks = <Track>[];
    for (final trackId in _playlist.trackIds) {
      final track = await LocalDatabase.getTrackById(trackId);
      if (track != null) tracks.add(track);
    }
    if (mounted) {
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.markerColors[
        (_playlist.id ?? 0) % AppColors.markerColors.length];

    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: CustomScrollView(
        slivers: [
          // App bar with gradient
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.bgDark,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.bgDarkest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
              ),
            ),
            actions: [
              PopupMenuButton(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
                color: AppColors.bgCard,
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 20),
                        SizedBox(width: 8),
                        Text('Add Tracks', style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(Icons.file_upload_rounded, color: AppColors.textSecondary, size: 20),
                        SizedBox(width: 8),
                        Text('Import & Add', style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'add') _showAddExistingTracksDialog();
                  if (value == 'import') _importAndAdd();
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _playlist.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Icon(
                    Icons.folder_rounded,
                    color: color.withValues(alpha: 0.3),
                    size: 80,
                  ),
                ),
              ),
            ),
          ),

          // Description
          if (_playlist.description.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  _playlist.description,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),

          // Track count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.music_note_rounded, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${_tracks.length} track${_tracks.length != 1 ? "s" : ""}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const Spacer(),
                  if (_tracks.isNotEmpty)
                    TextButton.icon(
                      onPressed: _playAll,
                      icon: Icon(Icons.play_arrow_rounded, color: color, size: 18),
                      label: Text('Play All', style: TextStyle(color: color, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),

          // Track list
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No tracks in this playlist',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddExistingTracksDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Tracks'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: AppColors.bgDarkest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: _tracks.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final track = _tracks[index];
                  return ReorderableDragStartListener(
                    key: ValueKey(track.id),
                    index: index,
                    child: _PlaylistTrackTile(
                      track: track,
                      index: index + 1,
                      color: color,
                      onTap: () => _openTrack(track),
                      onRemove: () => _removeTrack(track),
                    ),
                  );
                },
              ),
            ),

          // Bottom spacer
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExistingTracksDialog,
        backgroundColor: color,
        foregroundColor: AppColors.bgDarkest,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _playAll() {
    if (_tracks.isEmpty) return;
    final notifier = ref.read(playerProvider.notifier);
    notifier.loadTrack(_tracks.first);
  }

  void _openTrack(Track track) {
    final notifier = ref.read(playerProvider.notifier);
    notifier.loadTrack(track);
    // Pop back and switch to player tab would be ideal
    Navigator.pop(context);
  }

  Future<void> _removeTrack(Track track) async {
    await LocalDatabase.removeTrackFromPlaylist(_playlist.id!, track.id!);
    _loadTracks();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final track = _tracks.removeAt(oldIndex);
      _tracks.insert(newIndex, track);
    });
    // TODO: persist reorder to DB
  }

  void _showAddExistingTracksDialog() async {
    final allTracks = await LocalDatabase.getAllTracks();
    final existingIds = _playlist.trackIds.toSet();
    final available = allTracks.where((t) => !existingIds.contains(t.id)).toList();

    if (!mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No more tracks to add. Import new tracks first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final selected = <int>{};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Add Tracks',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              content: SizedBox(
                width: 400,
                height: 300,
                child: ListView.builder(
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final track = available[index];
                    final isSelected = selected.contains(track.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            selected.add(track.id!);
                          } else {
                            selected.remove(track.id);
                          }
                        });
                      },
                      title: Text(
                        track.title,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                      subtitle: Text(
                        track.artist,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      activeColor: AppColors.primary,
                      checkColor: AppColors.bgDarkest,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty ? null : () async {
                    for (final trackId in selected) {
                      await LocalDatabase.addTrackToPlaylist(_playlist.id!, trackId);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadTracks();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.bgDarkest,
                  ),
                  child: Text(
                    'Add ${selected.length} track${selected.length != 1 ? "s" : ""}',
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

  Future<void> _importAndAdd() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac', 'wav', 'ogg', 'aac', 'm4a', 'opus', 'wma', 'aiff'],
        dialogTitle: 'Import & add to playlist',
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        if (file.path == null) continue;
        final f = File(file.path!);
        if (!await f.exists()) continue;

        var existing = await LocalDatabase.getTrackByPath(file.path!);
        if (existing == null) {
          final fileName = file.path!.split('/').last;
          final nameWithoutExt = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;

          final now = DateTime.now();
          final track = Track(
            title: nameWithoutExt,
            artist: 'Unknown Artist',
            filePath: file.path!,
            duration: Duration.zero,
            createdAt: now,
            updatedAt: now,
          );
          final id = await LocalDatabase.insertTrack(track);
          existing = track.copyWith(id: id);
        }

        await LocalDatabase.addTrackToPlaylist(_playlist.id!, existing.id!);
      }

      _loadTracks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// ── Track tile for playlist ──

class _PlaylistTrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _PlaylistTrackTile({
    required this.track,
    required this.index,
    required this.color,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Track number
                SizedBox(
                  width: 28,
                  child: Text(
                    '$index',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track.artist,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Reorder handle
                const Icon(
                  Icons.drag_handle_rounded,
                  color: AppColors.textDisabled,
                  size: 20,
                ),

                // Remove
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  tooltip: 'Remove from playlist',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
