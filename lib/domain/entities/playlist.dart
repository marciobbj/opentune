class Playlist {
  final int? id;
  final String name;
  final String description;
  final List<int> trackIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    this.id,
    required this.name,
    this.description = '',
    this.trackIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Playlist copyWith({
    int? id,
    String? name,
    String? description,
    List<int>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  @override
  String toString() =>
      'Playlist(id: $id, name: $name, tracks: ${trackIds.length})';
}
