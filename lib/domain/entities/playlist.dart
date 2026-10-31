import 'playlist_sort.dart';

class Playlist {
  final int? id;
  final String name;
  final String description;
  final List<int> trackIds;

  /// True for the built-in "Favorites" playlist. Starred tracks are stored
  /// here automatically; it can't be renamed or deleted by the user.
  final bool isFavorites;

  /// How the tracks of this playlist are displayed / queued.
  final PlaylistSortMode sortMode;

  /// Direction for [sortMode] (ignored for custom and random).
  final bool sortAscending;

  /// Seed used when [sortMode] is [PlaylistSortMode.random], so the shuffled
  /// order is persisted until the user reshuffles.
  final int shuffleSeed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    this.id,
    required this.name,
    this.description = '',
    this.trackIds = const [],
    this.isFavorites = false,
    this.sortMode = PlaylistSortMode.custom,
    this.sortAscending = true,
    this.shuffleSeed = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Playlist copyWith({
    int? id,
    String? name,
    String? description,
    List<int>? trackIds,
    bool? isFavorites,
    PlaylistSortMode? sortMode,
    bool? sortAscending,
    int? shuffleSeed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackIds: trackIds ?? this.trackIds,
      isFavorites: isFavorites ?? this.isFavorites,
      sortMode: sortMode ?? this.sortMode,
      sortAscending: sortAscending ?? this.sortAscending,
      shuffleSeed: shuffleSeed ?? this.shuffleSeed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isFavorites': isFavorites ? 1 : 0,
      'sortMode': sortMode.key,
      'sortAscending': sortAscending ? 1 : 0,
      'shuffleSeed': shuffleSeed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      isFavorites: (map['isFavorites'] as int? ?? 0) == 1,
      sortMode: PlaylistSortMode.fromKey(map['sortMode'] as String?),
      sortAscending: (map['sortAscending'] as int? ?? 1) == 1,
      shuffleSeed: map['shuffleSeed'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  @override
  String toString() =>
      'Playlist(id: $id, name: $name, tracks: ${trackIds.length})';
}
