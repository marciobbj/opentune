import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/local_database.dart';
import '../../../domain/entities/playlist.dart';
import '../../../domain/entities/track.dart';
import '../../providers/player_provider.dart';
import '../../providers/navigation_provider.dart';

import '../../shared/edit_track_dialog.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
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
    final color = AppColors
        .markerColors[(_playlist.id ?? 0) % context.colors.markerColors.length];

    return Scaffold(
      backgroundColor: context.colors.bgDarkest,
      body: CustomScrollView(
        slivers: [
          // App bar with gradient
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: context.colors.bgDark,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.colors.bgDarkest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: context.colors.textPrimary,
                  size: 20,
                ),
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: context.colors.textPrimary,
                ),
                color: context.colors.bgCard,
                itemBuilder: (ctx) => <PopupMenuEntry<String>>[
                  PopupMenuItem(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: context.colors.textSecondary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Add Tracks',
                          style: TextStyle(color: context.colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(
                          Icons.file_upload_rounded,
                          color: context.colors.textSecondary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Import & Add',
                          style: TextStyle(color: context.colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          color: context.colors.textSecondary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Rename Playlist',
                          style: TextStyle(color: context.colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: context.colors.error,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete Playlist',
                          style: TextStyle(color: context.colors.error),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'add') _showAddExistingTracksDialog();
                  if (value == 'import') _importAndAdd();
                  if (value == 'rename') _showRenamePlaylistDialog();
                  if (value == 'delete') _showDeletePlaylistDialog();
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
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15)),
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
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 13,
                  ),
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
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (_tracks.isNotEmpty)
                    TextButton.icon(
                      onPressed: _playAll,
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: color,
                        size: 18,
                      ),
                      label: Text(
                        'Play All',
                        style: TextStyle(color: color, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Track list
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
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
                      color: context.colors.textMuted.withValues(alpha: 0.4),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tracks in this playlist',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddExistingTracksDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Tracks'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: context.colors.bgDarkest,
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
                      onTap: () => _openTrack(track, index),
                      onEdit: () => _editTrackMetadata(track),
                      onCopyMetadata: () => _copyMetadataFromTrack(track),
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
        foregroundColor: context.colors.bgDarkest,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _playAll() {
    if (_tracks.isEmpty) return;
    final notifier = ref.read(playerProvider.notifier);
    notifier.loadQueue(_tracks);
    // Switch to Player tab
    ref.read(navigationProvider.notifier).state = 1;
    Navigator.pop(context);
  }

  void _openTrack(Track track, int index) {
    final notifier = ref.read(playerProvider.notifier);
    notifier.loadQueue(_tracks, initialIndex: index);
    // Switch to Player tab
    ref.read(navigationProvider.notifier).state = 1;
    Navigator.pop(context);
  }

  void _showRenamePlaylistDialog() {
    final controller = TextEditingController(text: _playlist.name);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.colors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Rename Playlist',
            style: TextStyle(color: context.colors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.bgDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
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
                final name = controller.text.trim();
                if (name.isEmpty) return;
                final db = await LocalDatabase.database;
                await db.update(
                  'playlists',
                  {'name': name, 'updatedAt': DateTime.now().toIso8601String()},
                  where: 'id = ?',
                  whereArgs: [_playlist.id],
                );
                if (ctx.mounted) Navigator.pop(ctx);

                // Reload playlist explicitly
                final updated = await LocalDatabase.getAllPlaylists();
                final current = updated
                    .where((p) => p.id == _playlist.id)
                    .firstOrNull;
                if (current != null && mounted) {
                  setState(() {
                    _playlist = current;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: context.colors.bgDarkest,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeletePlaylistDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.colors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Playlist',
            style: TextStyle(color: context.colors.error),
          ),
          content: Text(
            'Are you sure you want to delete "${_playlist.name}"?\nThis action cannot be undone.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (ctx.mounted) Navigator.pop(ctx);
                await LocalDatabase.deletePlaylist(_playlist.id!);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: context.colors.bgDarkest,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeTrack(Track track) async {
    await LocalDatabase.removeTrackFromPlaylist(_playlist.id!, track.id!);
    _loadTracks();
  }

  Future<void> _editTrackMetadata(Track track) async {
    final updatedTrack = await showDialog<Track>(
      context: context,
      builder: (ctx) => EditTrackDialog(track: track),
    );

    if (updatedTrack != null) {
      await LocalDatabase.updateTrack(updatedTrack);
      await _loadTracks();
      ref
          .read(playerProvider.notifier)
          .updateCurrentTrackMetadata(updatedTrack);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Track metadata updated'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    }
  }

  Future<void> _copyMetadataFromTrack(Track targetTrack) async {
    final allTracks = await LocalDatabase.getAllTracks();
    final otherTracks = allTracks.where((t) => t.id != targetTrack.id).toList();
    final searchController = TextEditingController();
    var filtered = List<Track>.from(otherTracks);
    final fields = {'title': false, 'artist': true, 'album': true};

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Copy metadata to "${targetTrack.title}"',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              content: SizedBox(
                width: 400,
                height: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field selection
                    Text(
                      'Fields to copy:',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: fields.keys.map((field) {
                        final checked = fields[field]!;
                        final label = field[0].toUpperCase() + field.substring(1);
                        return FilterChip(
                          selected: checked,
                          label: Text(
                            label,
                            style: TextStyle(
                              color: checked
                                  ? context.colors.bgDarkest
                                  : context.colors.textSecondary,
                              fontSize: 12,
                              fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: context.colors.bgDark,
                          checkmarkColor: context.colors.bgDarkest,
                          side: BorderSide(
                            color: checked
                                ? Theme.of(context).colorScheme.primary
                                : context.colors.surfaceBorder.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: (v) {
                            setDialogState(() => fields[field] = v);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Search
                    Text(
                      'Select source track:',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchController,
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search tracks...',
                        hintStyle: TextStyle(
                          color: context.colors.textMuted.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: context.colors.textMuted,
                          size: 20,
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    searchController.clear();
                                    filtered = List<Track>.from(otherTracks);
                                  });
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  color: context.colors.textMuted,
                                  size: 18,
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: context.colors.bgDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (query) {
                        setDialogState(() {
                          final q = query.toLowerCase();
                          filtered = otherTracks
                              .where((t) =>
                                  t.title.toLowerCase().contains(q) ||
                                  t.artist.toLowerCase().contains(q))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Track list
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No tracks found',
                                style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final track = filtered[index];
                                final hasSelection = fields.values.any((v) => v);
                                return ListTile(
                                  dense: true,
                                  enabled: hasSelection,
                                  title: Text(
                                    track.title,
                                    style: TextStyle(
                                      color: hasSelection
                                          ? context.colors.textPrimary
                                          : context.colors.textDisabled,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${track.artist}${track.album.isNotEmpty ? " · ${track.album}" : ""}',
                                    style: TextStyle(
                                      color: hasSelection
                                          ? context.colors.textMuted
                                          : context.colors.textDisabled,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  leading: Icon(
                                    Icons.music_note_rounded,
                                    color: hasSelection
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
                                        : context.colors.textDisabled,
                                    size: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onTap: hasSelection
                                      ? () => Navigator.pop(ctx, {
                                            'track': track,
                                            'fields': Map<String, bool>.from(fields),
                                          })
                                      : null,
                                );
                              },
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
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final sourceTrack = result['track'] as Track;
    final selectedFields = result['fields'] as Map<String, bool>;

    final updatedTrack = targetTrack.copyWith(
      title: selectedFields['title'] == true ? sourceTrack.title : null,
      artist: selectedFields['artist'] == true ? sourceTrack.artist : null,
      album: selectedFields['album'] == true ? sourceTrack.album : null,
      updatedAt: DateTime.now(),
    );

    await LocalDatabase.updateTrack(updatedTrack);
    await _loadTracks();
    ref.read(playerProvider.notifier).updateCurrentTrackMetadata(updatedTrack);

    if (mounted) {
      final copiedFields = selectedFields.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied $copiedFields from "${sourceTrack.title}"'),
          backgroundColor: context.colors.success,
        ),
      );
    }
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
    final available = allTracks
        .where((t) => !existingIds.contains(t.id))
        .toList();

    if (!mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No more tracks to add. Import new tracks first.'),
          backgroundColor: context.colors.warning,
        ),
      );
      return;
    }

    final selected = <int>{};
    final searchController = TextEditingController();
    var filtered = List<Track>.from(available);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Add Tracks',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: 400,
                height: 360,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search tracks...',
                        hintStyle: TextStyle(
                          color: context.colors.textMuted.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: context.colors.textMuted,
                          size: 20,
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    searchController.clear();
                                    filtered = List<Track>.from(available);
                                  });
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  color: context.colors.textMuted,
                                  size: 18,
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: context.colors.bgDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (query) {
                        setDialogState(() {
                          final q = query.toLowerCase();
                          filtered = available
                              .where((t) =>
                                  t.title.toLowerCase().contains(q) ||
                                  t.artist.toLowerCase().contains(q))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No tracks found',
                                style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final track = filtered[index];
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
                                    style: TextStyle(
                                      color: context.colors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    track.artist,
                                    style: TextStyle(
                                      color: context.colors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  activeColor: Theme.of(context).colorScheme.primary,
                                  checkColor: context.colors.bgDarkest,
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
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
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          for (final trackId in selected) {
                            await LocalDatabase.addTrackToPlaylist(
                              _playlist.id!,
                              trackId,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadTracks();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: context.colors.bgDarkest,
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.colors.error,
          ),
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
  final VoidCallback? onEdit;
  final VoidCallback? onCopyMetadata;
  final VoidCallback? onRemove;

  const _PlaylistTrackTile({
    required this.track,
    required this.index,
    required this.color,
    this.onTap,
    this.onEdit,
    this.onCopyMetadata,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: context.colors.bgCard.withValues(alpha: 0.4),
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
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track.artist,
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Drag & More logic
                Icon(
                  Icons.drag_handle_rounded,
                  color: context.colors.textDisabled,
                  size: 20,
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: context.colors.textMuted,
                    size: 20,
                  ),
                  color: context.colors.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'copy_meta') onCopyMetadata?.call();
                    if (value == 'remove') onRemove?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        'Edit metadata',
                        style: TextStyle(color: context.colors.textPrimary),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy_meta',
                      child: Text(
                        'Copy metadata from...',
                        style: TextStyle(color: context.colors.textPrimary),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        'Remove from playlist',
                        style: TextStyle(color: context.colors.warning),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
