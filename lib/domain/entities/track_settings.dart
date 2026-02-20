class TrackSettings {
  final int? id;
  final int trackId;
  final double tempo;       // 0.5 to 2.0 (1.0 = original speed)
  final double pitch;       // -12 to +12 semitones
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool loopEnabled;
  final Duration lastPosition;

  const TrackSettings({
    this.id,
    required this.trackId,
    this.tempo = 1.0,
    this.pitch = 0.0,
    this.loopStart,
    this.loopEnd,
    this.loopEnabled = false,
    this.lastPosition = Duration.zero,
  });

  bool get hasLoop => loopStart != null && loopEnd != null;

  String get pitchLabel {
    if (pitch == 0) return 'Original';
    final semitones = pitch.round();
    final notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final index = ((semitones % 12) + 12) % 12;
    return '${pitch > 0 ? "+" : ""}$semitones (${notes[index]})';
  }

  String get tempoLabel {
    final percent = (tempo * 100).round();
    return '$percent%';
  }

  TrackSettings copyWith({
    int? id,
    int? trackId,
    double? tempo,
    double? pitch,
    Duration? loopStart,
    Duration? loopEnd,
    bool? loopEnabled,
    Duration? lastPosition,
    bool clearLoop = false,
  }) {
    return TrackSettings(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      tempo: tempo ?? this.tempo,
      pitch: pitch ?? this.pitch,
      loopStart: clearLoop ? null : (loopStart ?? this.loopStart),
      loopEnd: clearLoop ? null : (loopEnd ?? this.loopEnd),
      loopEnabled: loopEnabled ?? this.loopEnabled,
      lastPosition: lastPosition ?? this.lastPosition,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trackId': trackId,
      'tempo': tempo,
      'pitch': pitch,
      'loopStartMs': loopStart?.inMilliseconds,
      'loopEndMs': loopEnd?.inMilliseconds,
      'loopEnabled': loopEnabled ? 1 : 0,
      'lastPositionMs': lastPosition.inMilliseconds,
    };
  }

  factory TrackSettings.fromMap(Map<String, dynamic> map) {
    return TrackSettings(
      id: map['id'] as int?,
      trackId: map['trackId'] as int,
      tempo: (map['tempo'] as num?)?.toDouble() ?? 1.0,
      pitch: (map['pitch'] as num?)?.toDouble() ?? 0.0,
      loopStart: map['loopStartMs'] != null
          ? Duration(milliseconds: map['loopStartMs'] as int)
          : null,
      loopEnd: map['loopEndMs'] != null
          ? Duration(milliseconds: map['loopEndMs'] as int)
          : null,
      loopEnabled: (map['loopEnabled'] as int?) == 1,
      lastPosition: Duration(
        milliseconds: (map['lastPositionMs'] as int?) ?? 0,
      ),
    );
  }
}
