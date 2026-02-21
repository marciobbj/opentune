import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/track_settings.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/playlist.dart';
import '../../data/datasources/local_database.dart';
import '../../core/utils/waveform_extractor.dart';

// ── Audio Player Instance ──
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

// ── Player State ──
class PlayerState {
  final Track? currentTrack;
  final TrackSettings settings;
  final List<Section> sections;
  final List<double>? waveformData;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final List<Track> queue;
  final int queueIndex;

  const PlayerState({
    this.currentTrack,
    this.settings = const TrackSettings(trackId: 0),
    this.sections = const [],
    this.waveformData,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.queue = const [],
    this.queueIndex = 0,
  });

  double get progress =>
      duration.inMilliseconds > 0
          ? position.inMilliseconds / duration.inMilliseconds
          : 0.0;

  bool get hasNext => queue.isNotEmpty && queueIndex < queue.length - 1;
  bool get hasPrevious => queue.isNotEmpty && queueIndex > 0;

  PlayerState copyWith({
    Track? currentTrack,
    TrackSettings? settings,
    List<Section>? sections,
    List<double>? waveformData,
    bool clearWaveform = false,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    List<Track>? queue,
    int? queueIndex,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      settings: settings ?? this.settings,
      sections: sections ?? this.sections,
      waveformData: clearWaveform ? null : (waveformData ?? this.waveformData),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
    );
  }
}

// ── Player Notifier ──
class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _player;
  final List<StreamSubscription> _subscriptions = [];

  PlayerNotifier(this._player) : super(const PlayerState()) {
    _listenToPlayer();
  }

  void _listenToPlayer() {
    _subscriptions.add(
      _player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
        _checkLoopBoundary(pos);
      }),
    );

    _subscriptions.add(
      _player.durationStream.listen((dur) {
        if (dur != null) {
          state = state.copyWith(duration: dur);
        }
      }),
    );

    _subscriptions.add(
      _player.playingStream.listen((playing) {
        state = state.copyWith(isPlaying: playing);
      }),
    );

    _subscriptions.add(
      _player.bufferedPositionStream.listen((buf) {
        state = state.copyWith(bufferedPosition: buf);
      }),
    );

    _subscriptions.add(
      _player.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          if (state.settings.loopEnabled && state.settings.hasLoop) {
            _player.seek(state.settings.loopStart!);
            _player.play();
          } else if (state.hasNext) {
            skipToNextTrack();
          }
        }
      }),
    );
  }

  void _checkLoopBoundary(Duration position) {
    if (!state.settings.loopEnabled || !state.settings.hasLoop) return;
    final loopEnd = state.settings.loopEnd!;
    if (position >= loopEnd) {
      _player.seek(state.settings.loopStart!);
    }
  }

  void updateCurrentTrackMetadata(Track updatedTrack) {
    if (state.currentTrack?.id == updatedTrack.id) {
      state = state.copyWith(currentTrack: updatedTrack);
    }
    
    // Also update in queue if exists
    final qIndex = state.queue.indexWhere((t) => t.id == updatedTrack.id);
    if (qIndex != -1) {
      final newQueue = List<Track>.from(state.queue);
      newQueue[qIndex] = updatedTrack;
      state = state.copyWith(queue: newQueue);
    }
  }

  Future<void> loadTrack(Track track) async {
    state = state.copyWith(isLoading: true, currentTrack: track, clearWaveform: true);

    try {
      // Load saved settings
      final savedSettings = await LocalDatabase.getTrackSettings(track.id!);
      final settings = savedSettings ??
          TrackSettings(trackId: track.id!);

      // Load sections
      final sections = await LocalDatabase.getSectionsForTrack(track.id!);

      // Set the audio source
      await _player.setFilePath(track.filePath);

      // Apply saved settings
      await _player.setSpeed(settings.tempo);

      // Seek to last position
      if (settings.lastPosition > Duration.zero) {
        await _player.seek(settings.lastPosition);
      }

      // Extract waveform
      final waveform = await WaveformExtractor.extract(track.filePath);

      state = state.copyWith(
        currentTrack: track,
        settings: settings,
        sections: sections,
        waveformData: waveform,
        isLoading: false,
        duration: _player.duration ?? Duration.zero,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> loadQueue(List<Track> queue, {int initialIndex = 0}) async {
    if (queue.isEmpty) return;
    state = state.copyWith(queue: queue, queueIndex: initialIndex);
    await loadTrack(queue[initialIndex]);
    await play(); // Autoplay when loading a queue
  }

  Future<void> skipToNextTrack() async {
    if (state.hasNext) {
      final nextIndex = state.queueIndex + 1;
      state = state.copyWith(queueIndex: nextIndex);
      await loadTrack(state.queue[nextIndex]);
      await play(); // Autoplay next track
    }
  }

  Future<void> skipToPreviousTrack() async {
    // If the track just started, go to previous track. 
    // Otherwise, behavior of typical "previous" button is to restart current track.
    if (state.position.inSeconds > 3 || !state.hasPrevious) {
      await seek(Duration.zero);
    } else if (state.hasPrevious) {
      final prevIndex = state.queueIndex - 1;
      state = state.copyWith(queueIndex: prevIndex);
      await loadTrack(state.queue[prevIndex]);
      await play(); // Autoplay previous track
    }
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
    _saveCurrentState();
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      // If loop is on, ensure we start from the loop region
      if (state.settings.loopEnabled && state.settings.hasLoop) {
        final pos = state.position;
        final loopStart = state.settings.loopStart!;
        final loopEnd = state.settings.loopEnd!;
        if (pos < loopStart || pos >= loopEnd) {
          await seek(loopStart);
        }
      }
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekToProgress(double progress) async {
    final position = Duration(
      milliseconds: (state.duration.inMilliseconds * progress).round(),
    );
    await seek(position);
  }

  Future<void> skipForward([Duration amount = const Duration(seconds: 10)]) async {
    final newPos = state.position + amount;
    await seek(newPos > state.duration ? state.duration : newPos);
  }

  Future<void> skipBackward([Duration amount = const Duration(seconds: 10)]) async {
    final newPos = state.position - amount;
    await seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> skipToStart() async {
    if (state.settings.loopEnabled && state.settings.hasLoop) {
      await seek(state.settings.loopStart!);
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> skipToEnd() async {
    if (state.settings.loopEnabled && state.settings.hasLoop) {
      await seek(state.settings.loopEnd!);
    } else {
      await seek(state.duration);
    }
  }

  // ── Tempo ──

  Future<void> setTempo(double tempo) async {
    final clamped = tempo.clamp(0.25, 2.0);
    await _player.setSpeed(clamped);
    state = state.copyWith(
      settings: state.settings.copyWith(tempo: clamped),
    );
    _saveCurrentState();
  }

  // ── Pitch ──

  Future<void> setPitch(double semitones) async {
    final clamped = semitones.clamp(-12.0, 12.0);
    // Convert semitones to pitch factor: 2^(semitones/12)
    final pitchFactor = _semitonesToPitch(clamped);
    await _player.setPitch(pitchFactor);
    state = state.copyWith(
      settings: state.settings.copyWith(pitch: clamped),
    );
    _saveCurrentState();
  }

  double _semitonesToPitch(double semitones) {
    return math.pow(2.0, semitones / 12.0).toDouble();
  }

  // ── Loop ──

  /// Find the section that contains the current playback position
  Section? _findActiveSection() {
    for (final section in state.sections) {
      if (state.position >= section.startTime && state.position <= section.endTime) {
        return section;
      }
    }
    return null;
  }

  void toggleLoop() {
    if (state.settings.loopEnabled) {
      // Disable loop
      state = state.copyWith(
        settings: state.settings.copyWith(
          loopEnabled: false,
          clearLoop: true,
        ),
      );
    } else {
      // Enable loop — find active section or loop entire track
      final activeSection = _findActiveSection();
      if (activeSection != null) {
        state = state.copyWith(
          settings: state.settings.copyWith(
            loopStart: activeSection.startTime,
            loopEnd: activeSection.endTime,
            loopEnabled: true,
          ),
        );
      } else {
        // Loop entire track
        state = state.copyWith(
          settings: state.settings.copyWith(
            loopStart: Duration.zero,
            loopEnd: state.duration,
            loopEnabled: true,
          ),
        );
      }
    }
    _saveCurrentState();
  }

  void setLoopToSection(Section section) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        loopStart: section.startTime,
        loopEnd: section.endTime,
        loopEnabled: true,
      ),
    );
    _saveCurrentState();
  }

  void setFullTrackLoop() {
    state = state.copyWith(
      settings: state.settings.copyWith(
        loopStart: Duration.zero,
        loopEnd: state.duration,
        loopEnabled: true,
      ),
    );
    _saveCurrentState();
  }

  void setCustomLoop(Duration start, Duration end) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        loopStart: start,
        loopEnd: end,
        loopEnabled: true,
      ),
    );
    _saveCurrentState();
  }

  void clearLoop() {
    state = state.copyWith(
      settings: state.settings.copyWith(clearLoop: true, loopEnabled: false),
    );
    _saveCurrentState();
  }

  // ── Sections ──

  Future<void> addSection(String label, Duration start, Duration end, int colorValue) async {
    if (state.currentTrack == null) return;
    final section = Section(
      trackId: state.currentTrack!.id!,
      label: label,
      startTime: start,
      endTime: end,
      color: Color(colorValue),
      orderIndex: state.sections.length,
    );
    await LocalDatabase.insertSection(section);
    await _reloadSections();
  }

  Future<void> updateSection(Section section) async {
    await LocalDatabase.updateSection(section);
    await _reloadSections();
    // If loop was set to this section, update loop bounds
    if (state.settings.loopEnabled &&
        state.settings.loopStart != null) {
      // Check if the current loop matches any section that was just updated
      final updated = state.sections.where((s) => s.id == section.id).firstOrNull;
      if (updated != null) {
        state = state.copyWith(
          settings: state.settings.copyWith(
            loopStart: updated.startTime,
            loopEnd: updated.endTime,
          ),
        );
      }
    }
  }

  Future<void> deleteSection(int sectionId) async {
    await LocalDatabase.deleteSection(sectionId);
    await _reloadSections();
  }

  Future<void> _reloadSections() async {
    if (state.currentTrack != null) {
      final sections = await LocalDatabase.getSectionsForTrack(state.currentTrack!.id!);
      state = state.copyWith(sections: sections);
    }
  }

  Future<void> seekToSection(Section section) async {
    await seek(section.startTime);
    // Set loop to this section and enable it
    setLoopToSection(section);
  }

  // ── Persistence ──

  Future<void> _saveCurrentState() async {
    if (state.currentTrack == null) return;
    final settings = state.settings.copyWith(
      lastPosition: state.position,
    );
    await LocalDatabase.upsertTrackSettings(settings);
  }

  @override
  void dispose() {
    _saveCurrentState();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

// ── Provider ──
final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return PlayerNotifier(player);
});

// ── Track List Provider ──
final trackListProvider = FutureProvider<List<Track>>((ref) async {
  return LocalDatabase.getAllTracks();
});

// ── Playlist List Provider ──
final playlistListProvider = FutureProvider<List<Playlist>>((ref) async {
  return LocalDatabase.getAllPlaylists();
});
