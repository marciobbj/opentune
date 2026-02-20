class Track {
  final int? id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final Duration duration;
  final double originalBpm;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Track({
    this.id,
    required this.title,
    required this.artist,
    this.album = '',
    required this.filePath,
    required this.duration,
    this.originalBpm = 120.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Track copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    String? filePath,
    Duration? duration,
    double? originalBpm,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      originalBpm: originalBpm ?? this.originalBpm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'filePath': filePath,
      'durationMs': duration.inMilliseconds,
      'originalBpm': originalBpm,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as int?,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String? ?? '',
      filePath: map['filePath'] as String,
      duration: Duration(milliseconds: map['durationMs'] as int),
      originalBpm: (map['originalBpm'] as num?)?.toDouble() ?? 120.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  @override
  String toString() => 'Track(id: $id, title: $title, artist: $artist)';
}
