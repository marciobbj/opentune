import 'dart:math';

import 'track.dart';

/// Predefined ways of ordering the tracks inside a playlist.
///
/// The selected mode (plus direction and shuffle seed) is persisted per
/// playlist in the `playlists` table.
enum PlaylistSortMode {
  /// Manual order (drag & drop), stored in `playlist_tracks.orderIndex`.
  custom('custom', 'Custom'),
  title('title', 'Title'),
  artist('artist', 'Artist'),
  album('album', 'Album'),

  /// When the track was added to this playlist.
  dateAdded('dateAdded', 'Date Added'),

  /// When the track was imported into the library.
  dateImported('dateImported', 'Date Imported'),

  /// When the track metadata was last modified.
  dateModified('dateModified', 'Date Modified'),
  duration('duration', 'Duration'),
  bpm('bpm', 'BPM'),

  /// Random order. Uses a persisted seed so the order stays stable until the
  /// user explicitly reshuffles.
  random('random', 'Random');

  const PlaylistSortMode(this.key, this.label);

  /// Value stored in the database.
  final String key;
  final String label;

  static PlaylistSortMode fromKey(String? key) {
    return PlaylistSortMode.values.firstWhere(
      (m) => m.key == key,
      orElse: () => PlaylistSortMode.custom,
    );
  }

  /// Whether ascending / descending makes sense for this mode.
  bool get supportsDirection =>
      this != PlaylistSortMode.custom && this != PlaylistSortMode.random;

  /// Natural direction used when the mode is first selected
  /// (A→Z for text, newest first for dates, shortest/slowest first otherwise).
  bool get defaultAscending => switch (this) {
    PlaylistSortMode.dateAdded ||
    PlaylistSortMode.dateImported ||
    PlaylistSortMode.dateModified => false,
    _ => true,
  };
}

/// Returns [tracks] ordered according to [mode].
///
/// [tracks] must be in the playlist's manual (custom) order.
/// [addedRank] maps a track id to a value that increases with the time the
/// track was added to the playlist.
List<Track> sortPlaylistTracks(
  List<Track> tracks, {
  required PlaylistSortMode mode,
  required bool ascending,
  required int shuffleSeed,
  Map<int, int> addedRank = const {},
}) {
  if (mode == PlaylistSortMode.custom) return List<Track>.from(tracks);

  if (mode == PlaylistSortMode.random) {
    // Shuffle from a canonical order (by id) so the result only depends on
    // the seed and the set of tracks, not on the current manual order.
    final result = List<Track>.from(tracks)
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    result.shuffle(Random(shuffleSeed));
    return result;
  }

  // Manual position is used as the final tie-breaker to keep sorting stable.
  final manualIndex = <Track, int>{
    for (var i = 0; i < tracks.length; i++) tracks[i]: i,
  };

  int text(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  int primary(Track a, Track b) => switch (mode) {
    PlaylistSortMode.title => text(a.title, b.title),
    PlaylistSortMode.artist => text(a.artist, b.artist),
    PlaylistSortMode.album => text(a.album, b.album),
    PlaylistSortMode.dateAdded => (addedRank[a.id] ?? 0).compareTo(
      addedRank[b.id] ?? 0,
    ),
    PlaylistSortMode.dateImported => a.createdAt.compareTo(b.createdAt),
    PlaylistSortMode.dateModified => a.updatedAt.compareTo(b.updatedAt),
    PlaylistSortMode.duration => a.duration.compareTo(b.duration),
    PlaylistSortMode.bpm => a.originalBpm.compareTo(b.originalBpm),
    PlaylistSortMode.custom || PlaylistSortMode.random => 0,
  };

  // Secondary keys that make grouped sorts (artist/album) read naturally.
  int secondary(Track a, Track b) => switch (mode) {
    PlaylistSortMode.artist => _chain([
      text(a.album, b.album),
      text(a.title, b.title),
    ]),
    PlaylistSortMode.album => _chain([
      text(a.artist, b.artist),
      text(a.title, b.title),
    ]),
    PlaylistSortMode.title => text(a.artist, b.artist),
    _ => text(a.title, b.title),
  };

  final result = List<Track>.from(tracks);
  result.sort((a, b) {
    var cmp = primary(a, b);
    if (!ascending) cmp = -cmp;
    if (cmp != 0) return cmp;
    cmp = secondary(a, b);
    if (cmp != 0) return cmp;
    return manualIndex[a]!.compareTo(manualIndex[b]!);
  });
  return result;
}

int _chain(List<int> comparisons) =>
    comparisons.firstWhere((c) => c != 0, orElse: () => 0);
