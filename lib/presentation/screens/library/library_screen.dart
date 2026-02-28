import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
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
import 'playlist_detail_screen.dart';

enum TrackSortField { title, artist, album, dateAdded }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<Playlist> _playlists = [];
  List<Track> _allTracks = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  TrackSortField _sortField = TrackSortField.dateAdded;
  bool _sortAscending = false;

  List<Track> get _filteredTracks {
    var tracks = List<Track>.from(_allTracks);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      tracks = tracks.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.artist.toLowerCase().contains(q) ||
        t.album.toLowerCase().contains(q)
      ).toList();
    }

    // Sort
    tracks.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case TrackSortField.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case TrackSortField.artist:
          cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        case TrackSortField.album:
          cmp = a.album.toLowerCase().compareTo(b.album.toLowerCase());
        case TrackSortField.dateAdded:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return tracks;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final playlists = await LocalDatabase.getAllPlaylists();
    final rawTracks = await LocalDatabase.getAllTracks();

    final validTracks = <Track>[];
    for (final track in rawTracks) {
      if (!File(track.filePath).existsSync()) {
        await LocalDatabase.deleteTrack(track.id!);
      } else {
        validTracks.add(track);
      }
    }

    if (mounted) {
      setState(() {
        _playlists = playlists;
        _allTracks = validTracks;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeTrackFromLibrary(Track track) async {
    // Delete from database
    await LocalDatabase.deleteTrack(track.id!);
    // Refresh data
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${track.title}" from library'),
          backgroundColor: context.colors.success,
        ),
      );
    }
  }

  Future<void> _editTrackMetadata(Track track) async {
    final updatedTrack = await showDialog<Track>(
      context: context,
      builder: (ctx) => EditTrackDialog(track: track),
    );

    if (updatedTrack != null) {
      await LocalDatabase.updateTrack(updatedTrack);
      await _loadData();
      ref
          .read(playerProvider.notifier)
          .updateCurrentTrackMetadata(updatedTrack);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Track updated'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    }
  }

  Future<void> _copyMetadataFromTrack(Track targetTrack) async {
    final searchController = TextEditingController();
    final otherTracks = _allTracks.where((t) => t.id != targetTrack.id).toList();
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
    await _loadData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgDarkest,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Library',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_playlists.length} playlists · ${_allTracks.length} tracks',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  // Import track button
                  IconButton(
                    onPressed: _importTrack,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: Theme.of(context).colorScheme.primary,
                      child: _buildContent(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePlaylistDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: context.colors.bgDarkest,
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text(
          'New Playlist',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // Playlists Section
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'PLAYLISTS',
              style: TextStyle(
                color: context.colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),

        if (_playlists.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyPlaylists())
        else
          SliverToBoxAdapter(
            child: SizedBox(
              height: 140,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _PlaylistCard(
                      playlist: _playlists[index],
                      trackCount: _playlists[index].trackIds.length,
                      onTap: () => _openPlaylist(_playlists[index]),
                      onOptionsTap: () =>
                          _showPlaylistOptions(_playlists[index]),
                    ),
                  );
                },
              ),
            ),
          ),

        // All tracks section header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                Text(
                  'ALL TRACKS',
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? '${_filteredTracks.length} of ${_allTracks.length}'
                      : '${_allTracks.length}',
                  style: TextStyle(
                    color: context.colors.textMuted.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search + Sort controls
        if (_allTracks.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by title, artist, album...',
                      hintStyle: TextStyle(
                        color: context.colors.textMuted.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: context.colors.textMuted,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
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
                      setState(() => _searchQuery = query);
                    },
                  ),
                  const SizedBox(height: 10),
                  // Sort controls
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: TrackSortField.values.map((field) {
                              final selected = _sortField == field;
                              final label = switch (field) {
                                TrackSortField.title => 'Title',
                                TrackSortField.artist => 'Artist',
                                TrackSortField.album => 'Album',
                                TrackSortField.dateAdded => 'Date Added',
                              };
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  selected: selected,
                                  label: Text(
                                    label,
                                    style: TextStyle(
                                      color: selected
                                          ? context.colors.bgDarkest
                                          : context.colors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                  selectedColor: Theme.of(context).colorScheme.primary,
                                  backgroundColor: context.colors.bgDark,
                                  side: BorderSide(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : context.colors.surfaceBorder.withValues(alpha: 0.3),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  showCheckmark: false,
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (_) {
                                    setState(() {
                                      if (_sortField == field) {
                                        _sortAscending = !_sortAscending;
                                      } else {
                                        _sortField = field;
                                        _sortAscending = field == TrackSortField.title ||
                                            field == TrackSortField.artist ||
                                            field == TrackSortField.album;
                                      }
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() => _sortAscending = !_sortAscending);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: context.colors.bgDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.colors.surfaceBorder.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            _sortAscending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: context.colors.textSecondary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        if (_allTracks.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyTracks())
        else if (_filteredTracks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: Text(
                  'No tracks match your search',
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _TrackTile(
                  track: _filteredTracks[index],
                  onTap: () => _openTrackInPlayer(_filteredTracks[index]),
                  onAddToPlaylist: () =>
                      _showAddToPlaylistDialog(_filteredTracks[index]),
                  onEditTrack: () => _editTrackMetadata(_filteredTracks[index]),
                  onCopyMetadata: () =>
                      _copyMetadataFromTrack(_filteredTracks[index]),
                  onRemoveFromLibrary: () =>
                      _removeTrackFromLibrary(_filteredTracks[index]),
                ),
                childCount: _filteredTracks.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyPlaylists() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.colors.bgCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.surfaceBorder.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_rounded,
            color: context.colors.textMuted.withValues(alpha: 0.4),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'No playlists yet',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create playlists to organize your practice sessions',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTracks() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.colors.bgCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.surfaceBorder.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.music_off_rounded,
            color: context.colors.textMuted.withValues(alpha: 0.4),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'No tracks imported',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Import audio files to start practicing',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Actions ──

  void _openPlaylist(Playlist playlist) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
    _loadData(); // Refresh on return
  }

  void _openTrackInPlayer(Track track) {
    final notifier = ref.read(playerProvider.notifier);
    notifier.loadTrack(track);
    // Switch to Player tab (index 1)
    ref.read(navigationProvider.notifier).state = 1;
  }

  Future<void> _importTrack() async {
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
        dialogTitle: 'Select audio files',
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      int imported = 0;
      for (final file in result.files) {
        if (file.path == null) continue;
        final f = File(file.path!);
        if (!await f.exists()) continue;

        final existing = await LocalDatabase.getTrackByPath(file.path!);
        if (existing != null) continue;

        final fileName = file.path!.split('/').last;
        final nameWithoutExt = fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;

        // Read metadata from the audio file
        String metaTitle = nameWithoutExt;
        String metaArtist = 'Unknown Artist';
        String metaAlbum = '';
        Duration metaDuration = Duration.zero;

        try {
          final metadata = readMetadata(f, getImage: false);
          if (metadata.title != null && metadata.title!.trim().isNotEmpty) {
            metaTitle = metadata.title!.trim();
          }
          if (metadata.artist != null && metadata.artist!.trim().isNotEmpty) {
            metaArtist = metadata.artist!.trim();
          }
          if (metadata.album != null && metadata.album!.trim().isNotEmpty) {
            metaAlbum = metadata.album!.trim();
          }
          if (metadata.duration != null) {
            metaDuration = metadata.duration!;
          }
        } catch (_) {
          // Metadata extraction failed — keep defaults from filename
        }

        final now = DateTime.now();
        final track = Track(
          title: metaTitle,
          artist: metaArtist,
          album: metaAlbum,
          filePath: file.path!,
          duration: metaDuration,
          createdAt: now,
          updatedAt: now,
        );
        await LocalDatabase.insertTrack(track);
        imported++;
      }

      if (mounted && imported > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $imported track${imported > 1 ? "s" : ""}'),
            backgroundColor: context.colors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final presetIcons = [
      {'name': 'Show ao Vivo', 'icon': '🎸'},
      {'name': 'Barzinho', 'icon': '🍻'},
      {'name': 'Ensaio', 'icon': '🎵'},
      {'name': 'Estudo', 'icon': '📚'},
      {'name': 'Covers', 'icon': '🎤'},
      {'name': 'Originais', 'icon': '✨'},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.colors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'New Playlist',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: TextStyle(color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Playlist Name',
                    labelStyle: TextStyle(color: context.colors.textMuted),
                    hintText: 'e.g. Show de Agosto, Barzinho...',
                    hintStyle: TextStyle(
                      color: context.colors.textMuted.withValues(alpha: 0.5),
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
                // Quick presets
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presetIcons.map((p) {
                    return GestureDetector(
                      onTap: () {
                        nameController.text = p['name']!;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.bgMedium,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.colors.surfaceBorder.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          '${p["icon"]} ${p["name"]}',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: TextStyle(color: context.colors.textPrimary),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: context.colors.textMuted),
                    hintText: 'What is this playlist for?',
                    hintStyle: TextStyle(
                      color: context.colors.textMuted.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: context.colors.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
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
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final now = DateTime.now();
                final playlist = Playlist(
                  name: name,
                  description: descController.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                );
                await LocalDatabase.insertPlaylist(playlist);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: context.colors.bgDarkest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Create',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPlaylistOptions(Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  playlist.name,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    Icons.edit_rounded,
                    color: context.colors.textSecondary,
                  ),
                  title: Text(
                    'Rename',
                    style: TextStyle(color: context.colors.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenamePlaylistDialog(playlist);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: context.colors.error,
                  ),
                  title: Text(
                    'Delete Playlist',
                    style: TextStyle(color: context.colors.error),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await LocalDatabase.deletePlaylist(playlist.id!);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenamePlaylistDialog(Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
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
                  whereArgs: [playlist.id],
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
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

  void _showAddToPlaylistDialog(Track track) {
    if (_playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Create a playlist first'),
          backgroundColor: context.colors.warning,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add to Playlist',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ..._playlists.map((playlist) {
                  final alreadyAdded = playlist.trackIds.contains(track.id);
                  return ListTile(
                    leading: Icon(
                      alreadyAdded
                          ? Icons.check_circle_rounded
                          : Icons.folder_rounded,
                      color: alreadyAdded
                          ? context.colors.success
                          : context.colors.markerColors[(playlist.id ?? 0) %
                                context.colors.markerColors.length],
                    ),
                    title: Text(
                      playlist.name,
                      style: TextStyle(color: context.colors.textPrimary),
                    ),
                    subtitle: Text(
                      '${playlist.trackIds.length} tracks',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: alreadyAdded
                        ? Text(
                            'Added',
                            style: TextStyle(
                              color: context.colors.success,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    onTap: alreadyAdded
                        ? null
                        : () async {
                            await LocalDatabase.addTrackToPlaylist(
                              playlist.id!,
                              track.id!,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added to "${playlist.name}"'),
                                  backgroundColor: context.colors.success,
                                ),
                              );
                            }
                          },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Playlist Card ──

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final int trackCount;
  final VoidCallback? onTap;
  final VoidCallback? onOptionsTap;

  const _PlaylistCard({
    required this.playlist,
    required this.trackCount,
    this.onTap,
    this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = context
        .colors
        .markerColors[(playlist.id ?? 0) % context.colors.markerColors.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: context.colors.bgCard.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.folder_rounded, color: color, size: 28),
                GestureDetector(
                  onTap: onOptionsTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: context.colors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$trackCount track${trackCount != 1 ? "s" : ""}',
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Track Tile ──

class _TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onEditTrack;
  final VoidCallback? onCopyMetadata;
  final VoidCallback? onRemoveFromLibrary;

  const _TrackTile({
    required this.track,
    this.onTap,
    this.onAddToPlaylist,
    this.onEditTrack,
    this.onCopyMetadata,
    this.onRemoveFromLibrary,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
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
                    if (value == 'add') onAddToPlaylist?.call();
                    if (value == 'edit') onEditTrack?.call();
                    if (value == 'copy_meta') onCopyMetadata?.call();
                    if (value == 'remove') onRemoveFromLibrary?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'add',
                      child: Text(
                        'Add to playlist',
                        style: TextStyle(color: context.colors.textPrimary),
                      ),
                    ),
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
                        'Remove from library',
                        style: TextStyle(color: context.colors.error),
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
