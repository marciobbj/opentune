import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/track_settings.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/playlist.dart';
import '../../data/datasources/local_database.dart';
import '../../core/utils/waveform_extractor.dart';
import '../../core/utils/bookmark_service.dart';
import 'settings_provider.dart';
import 'favorites_provider.dart';

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
  final double volume;
  final bool isShuffled;
  final List<Track> originalQueue;
  final int? activePlaylistId;
  final bool isFavoritesQueue;

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
    this.volume = 1.0,
    this.isShuffled = false,
    this.originalQueue = const [],
    this.activePlaylistId,
    this.isFavoritesQueue = false,
  });

  double get progress => duration.inMilliseconds > 0
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
    double? volume,
    bool? isShuffled,
    List<Track>? originalQueue,
    int? activePlaylistId,
    bool clearActivePlaylist = false,
    bool? isFavoritesQueue,
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
      volume: volume ?? this.volume,
      isShuffled: isShuffled ?? this.isShuffled,
      originalQueue: originalQueue ?? this.originalQueue,
      activePlaylistId: clearActivePlaylist
          ? null
          : (activePlaylistId ?? this.activePlaylistId),
      isFavoritesQueue:
          isFavoritesQueue ??
          (clearActivePlaylist ? false : this.isFavoritesQueue),
    );
  }
}

// ── Player Notifier ──
class PlayerNotifier extends StateNotifier<PlayerState> {
  static const String _lastTrackIdKey = 'last_played_track_id';
  static const String _volumeKey = 'last_played_volume';

  final AudioPlayer _player;
  final Ref _ref;
  final List<StreamSubscription> _subscriptions = [];
  Timer? _persistTimer;
  int _loadGeneration = 0;
  String? _activeBookmarkPath;
  ProviderSubscription<Set<int>>? _favoritesSub;

  PlayerNotifier(this._player, this._ref) : super(const PlayerState()) {
    _player.setVolume(0.3);
    _listenToPlayer();
    _listenToFavorites();
    unawaited(_restorePersistentPlayerState());
  }

  bool _isStaleLoad(int loadId) => loadId != _loadGeneration;

  bool get _startQueueFromBeginning =>
      _ref.read(settingsProvider).startQueueFromBeginning;

  Future<void> _releaseActiveBookmark() async {
    final path = _activeBookmarkPath;
    _activeBookmarkPath = null;
    if (path != null) {
      await BookmarkService.stopAccessing(path);
    }
  }

  void _scheduleStateSave() {
    _persistTimer?.cancel();
    if (state.currentTrack == null) return;

    _persistTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_saveCurrentState());
    });
  }

  Future<void> _restorePersistentPlayerState() async {
    final prefs = await SharedPreferences.getInstance();

    final savedVolume = prefs.getDouble(_volumeKey);
    if (savedVolume != null) {
      final clampedVolume = savedVolume.clamp(0.0, 1.0).toDouble();
      await _player.setVolume(clampedVolume);
    }

    final lastTrackId = prefs.getInt(_lastTrackIdKey);
    if (lastTrackId == null) return;

    final track = await LocalDatabase.getTrackById(lastTrackId);
    if (track == null) {
      await prefs.remove(_lastTrackIdKey);
      return;
    }

    await loadTrack(track);
  }

  void _listenToPlayer() {
    _subscriptions.add(
      _player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
        _checkLoopBoundary(pos);
        _scheduleStateSave();
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
      _player.volumeStream.listen((vol) {
        state = state.copyWith(volume: vol);
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

  void _listenToFavorites() {
    _favoritesSub = _ref.listen<Set<int>>(favoritesProvider, (
      previous,
      next,
    ) async {
      if (!state.isFavoritesQueue) return;
      if (previous == null) return;

      // Tracks newly added to favorites:
      final addedIds = next.difference(previous);
      if (addedIds.isNotEmpty) {
        for (final trackId in addedIds) {
          if (!state.queue.any((t) => t.id == trackId)) {
            final track = await LocalDatabase.getTrackById(trackId);
            if (track != null && state.isFavoritesQueue) {
              if (!state.queue.any((t) => t.id == track.id)) {
                final baseOriginal = state.originalQueue.isEmpty
                    ? List<Track>.from(state.queue)
                    : List<Track>.from(state.originalQueue);
                state = state.copyWith(
                  queue: [...state.queue, track],
                  originalQueue: [...baseOriginal, track],
                );
              }
            }
          }
        }
      }

      // Tracks removed from favorites:
      final removedIds = previous.difference(next);
      if (removedIds.isNotEmpty) {
        for (final trackId in removedIds) {
          final index = state.queue.indexWhere((t) => t.id == trackId);
          // If in queue and not currently playing, remove it:
          if (index != -1 && index != state.queueIndex) {
            removeFromQueue(index);
          }
        }
      }
    });
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

  Future<void> loadTrack(Track track, {bool startFromBeginning = false}) async {
    final loadId = ++_loadGeneration;
    _persistTimer?.cancel();
    state = state.copyWith(
      isLoading: true,
      currentTrack: track,
      clearWaveform: true,
    );

    try {
      await _releaseActiveBookmark();

      // Ensure file access via bookmark if needed (macOS sandbox)
      var activeTrack = track;
      String? activeBookmarkPath;
      if (!File(track.filePath).existsSync() && track.bookmarkData != null) {
        final resolvedPath = await BookmarkService.startAccessing(
          track.bookmarkData!,
          onStaleBookmark: (newData) async {
            final updated = track.copyWith(bookmarkData: newData);
            await LocalDatabase.updateTrack(updated);
            activeTrack = updated;
          },
        );
        if (resolvedPath != null && resolvedPath != track.filePath) {
          activeTrack = activeTrack.copyWith(filePath: resolvedPath);
          await LocalDatabase.updateTrack(activeTrack);
        }
        activeBookmarkPath = resolvedPath;
      } else if (track.bookmarkData != null) {
        // File exists but still start accessing via bookmark for sandbox compliance
        activeBookmarkPath = await BookmarkService.startAccessing(
          track.bookmarkData!,
        );
      }

      if (_isStaleLoad(loadId)) {
        if (activeBookmarkPath != null) {
          await BookmarkService.stopAccessing(activeBookmarkPath);
        }
        return;
      }

      // Load saved settings
      final savedSettings = await LocalDatabase.getTrackSettings(
        activeTrack.id!,
      );
      final settings = savedSettings ?? TrackSettings(trackId: activeTrack.id!);

      // Load sections
      final sections = await LocalDatabase.getSectionsForTrack(activeTrack.id!);

      if (_isStaleLoad(loadId)) {
        if (activeBookmarkPath != null) {
          await BookmarkService.stopAccessing(activeBookmarkPath);
        }
        return;
      }

      // Set the audio source
      await _player.setFilePath(activeTrack.filePath);
      if (_isStaleLoad(loadId)) {
        if (activeBookmarkPath != null) {
          await BookmarkService.stopAccessing(activeBookmarkPath);
        }
        return;
      }

      // Apply saved settings
      await _player.setSpeed(settings.tempo);
      await _player.setPitch(_semitonesToPitch(settings.pitch));

      if (!startFromBeginning && settings.lastPosition > Duration.zero) {
        await _player.seek(settings.lastPosition);
      } else {
        await _player.seek(Duration.zero);
      }

      _activeBookmarkPath = activeBookmarkPath;

      state = state.copyWith(
        currentTrack: activeTrack,
        settings: settings,
        sections: sections,
        isLoading: false,
        duration: _player.duration ?? Duration.zero,
      );

      await _saveCurrentState();

      // Extract waveform asynchronously
      WaveformExtractor.extract(activeTrack.filePath)
          .then((waveform) {
            if (_isStaleLoad(loadId)) return;
            state = state.copyWith(waveformData: waveform);
          })
          .catchError((_) {
            // Ignore extraction errors
          });
    } catch (e) {
      if (!_isStaleLoad(loadId)) {
        state = state.copyWith(isLoading: false);
      }
      rethrow;
    }
  }

  Future<void> loadQueue(
    List<Track> queue, {
    int initialIndex = 0,
    int? playlistId,
    bool isFavoritesQueue = false,
  }) async {
    if (queue.isEmpty) return;
    state = state.copyWith(
      queue: queue,
      queueIndex: initialIndex,
      originalQueue: queue,
      isShuffled: false,
      activePlaylistId: playlistId,
      isFavoritesQueue: isFavoritesQueue,
    );
    await loadTrack(
      queue[initialIndex],
      startFromBeginning: _startQueueFromBeginning,
    );
    await play(); // Autoplay when loading a queue
  }

  Future<void> addToQueue(List<Track> tracks) async {
    if (tracks.isEmpty) return;

    if (state.queue.isEmpty) {
      await loadQueue(tracks);
      return;
    }

    final baseOriginal = state.originalQueue.isEmpty
        ? List<Track>.from(state.queue)
        : List<Track>.from(state.originalQueue);

    state = state.copyWith(
      queue: [...state.queue, ...tracks],
      originalQueue: [...baseOriginal, ...tracks],
    );
  }

  void clearQueue() {
    state = state.copyWith(
      queue: [],
      queueIndex: 0,
      isShuffled: false,
      originalQueue: [],
      clearActivePlaylist: true,
      isFavoritesQueue: false,
    );
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final newQueue = List<Track>.from(state.queue)..removeAt(index);
    int newIndex = state.queueIndex;

    if (newQueue.isEmpty) {
      state = state.copyWith(
        queue: [],
        queueIndex: 0,
        clearActivePlaylist: true,
        isFavoritesQueue: false,
      );
      return;
    }

    // Adjust current index if needed
    if (index < newIndex) {
      newIndex--;
    } else if (index == newIndex) {
      // Removed the currently playing track — stay at same index (next track)
      newIndex = newIndex.clamp(0, newQueue.length - 1);
    }

    state = state.copyWith(queue: newQueue, queueIndex: newIndex);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final queue = List<Track>.from(state.queue);
    final item = queue.removeAt(oldIndex);
    if (newIndex > oldIndex) newIndex--;
    queue.insert(newIndex, item);

    // Adjust queueIndex to follow the currently playing track
    int currentIndex = state.queueIndex;
    if (currentIndex == oldIndex) {
      currentIndex = newIndex;
    } else {
      if (oldIndex < currentIndex && newIndex >= currentIndex) {
        currentIndex--;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        currentIndex++;
      }
    }

    state = state.copyWith(queue: queue, queueIndex: currentIndex);
  }

  Future<void> skipToQueueIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(queueIndex: index);
    await loadTrack(
      state.queue[index],
      startFromBeginning: _startQueueFromBeginning,
    );
    await play();
  }

  Future<void> skipToNextTrack() async {
    if (state.hasNext) {
      final nextIndex = state.queueIndex + 1;
      state = state.copyWith(queueIndex: nextIndex);
      await loadTrack(
        state.queue[nextIndex],
        startFromBeginning: _startQueueFromBeginning,
      );
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
      await loadTrack(
        state.queue[prevIndex],
        startFromBeginning: _startQueueFromBeginning,
      );
      await play(); // Autoplay previous track
    }
  }

  void toggleShuffle() {
    if (state.queue.length <= 1) return;

    if (state.isShuffled) {
      // Restore original order
      final currentTrack = state.currentTrack;
      final restored = List<Track>.from(state.originalQueue);
      final newIndex = currentTrack != null
          ? restored
                .indexWhere((t) => t.id == currentTrack.id)
                .clamp(0, restored.length - 1)
          : 0;
      state = state.copyWith(
        queue: restored,
        queueIndex: newIndex,
        isShuffled: false,
      );
    } else {
      // Save original order and shuffle
      final original = List<Track>.from(state.queue);
      final currentTrack = state.queue[state.queueIndex];
      final remaining = List<Track>.from(state.queue)
        ..removeAt(state.queueIndex);
      remaining.shuffle(Random());
      final shuffled = [currentTrack, ...remaining];
      state = state.copyWith(
        originalQueue: original,
        queue: shuffled,
        queueIndex: 0,
        isShuffled: true,
      );
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
    _scheduleStateSave();
  }

  Future<void> seekToProgress(double progress) async {
    final position = Duration(
      milliseconds: (state.duration.inMilliseconds * progress).round(),
    );
    await seek(position);
  }

  Future<void> skipForward([
    Duration amount = const Duration(seconds: 10),
  ]) async {
    final newPos = state.position + amount;
    await seek(newPos > state.duration ? state.duration : newPos);
  }

  Future<void> skipBackward([
    Duration amount = const Duration(seconds: 10),
  ]) async {
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
    state = state.copyWith(settings: state.settings.copyWith(tempo: clamped));
    _saveCurrentState();
  }

  // ── Pitch ──

  Future<void> setPitch(double semitones) async {
    final clamped = semitones.clamp(-12.0, 12.0);
    // Convert semitones to pitch factor: 2^(semitones/12)
    final pitchFactor = _semitonesToPitch(clamped);
    await _player.setPitch(pitchFactor);
    state = state.copyWith(settings: state.settings.copyWith(pitch: clamped));
    _saveCurrentState();
  }

  double _semitonesToPitch(double semitones) {
    return math.pow(2.0, semitones / 12.0).toDouble();
  }

  // ── Volume ──

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _player.setVolume(clamped);
    state = state.copyWith(volume: clamped);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, clamped);
  }

  // ── Loop ──

  /// Find the section that contains the current playback position
  Section? _findActiveSection() {
    for (final section in state.sections) {
      if (state.position >= section.startTime &&
          state.position <= section.endTime) {
        return section;
      }
    }
    return null;
  }

  void toggleLoop() {
    if (state.settings.loopEnabled) {
      // Disable loop
      state = state.copyWith(
        settings: state.settings.copyWith(loopEnabled: false, clearLoop: true),
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

  /// Find the section whose bounds exactly match the current loop bounds.
  /// Returns null if no section matches (custom loop or full-track loop).
  Section? findSectionBoundToLoop() {
    if (!state.settings.loopEnabled || !state.settings.hasLoop) return null;
    final loopStart = state.settings.loopStart!;
    final loopEnd = state.settings.loopEnd!;
    for (final section in state.sections) {
      if (section.startTime == loopStart && section.endTime == loopEnd) {
        return section;
      }
    }
    return null;
  }

  /// Update both loop bounds AND the bound section simultaneously.
  /// Used when dragging loop handles while bound to a section.
  Future<void> updateLoopBoundToSection(Duration start, Duration end) async {
    final boundSection = findSectionBoundToLoop();
    // Update loop bounds
    state = state.copyWith(
      settings: state.settings.copyWith(
        loopStart: start,
        loopEnd: end,
        loopEnabled: true,
      ),
    );
    // If bound to a section, update that section too
    if (boundSection != null) {
      final updated = boundSection.copyWith(startTime: start, endTime: end);
      await LocalDatabase.updateSection(updated);
      await _reloadSections();
    }
    _saveCurrentState();
  }

  /// Seek to the start of the section currently bound to the loop.
  /// Does nothing if loop is off or not bound to a section.
  Future<void> seekToLoopSectionStart() async {
    final boundSection = findSectionBoundToLoop();
    if (boundSection == null) return;
    await seek(state.settings.loopStart!);
    await play();
  }

  void clearLoop() {
    state = state.copyWith(
      settings: state.settings.copyWith(clearLoop: true, loopEnabled: false),
    );
    _saveCurrentState();
  }

  // ── Sections ──

  Future<void> addSection(
    String label,
    Duration start,
    Duration end,
    int colorValue,
  ) async {
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
    if (state.settings.loopEnabled && state.settings.loopStart != null) {
      // Check if the current loop matches any section that was just updated
      final updated = state.sections
          .where((s) => s.id == section.id)
          .firstOrNull;
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
      final sections = await LocalDatabase.getSectionsForTrack(
        state.currentTrack!.id!,
      );
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
    final currentTrack = state.currentTrack;
    if (currentTrack?.id == null) return;
    final settings = state.settings.copyWith(lastPosition: state.position);
    await LocalDatabase.upsertTrackSettings(settings);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastTrackIdKey, currentTrack!.id!);
    await prefs.setDouble(_volumeKey, state.volume);
  }

  @override
  void dispose() {
    _loadGeneration++;
    _persistTimer?.cancel();
    _favoritesSub?.close();
    unawaited(_releaseActiveBookmark());
    _saveCurrentState();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

// ── Provider ──
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  final player = ref.watch(audioPlayerProvider);
  return PlayerNotifier(player, ref);
});

// ── Track List Provider ──
final trackListProvider = FutureProvider<List<Track>>((ref) async {
  return LocalDatabase.getAllTracks();
});

// ── Playlist List Provider ──
final playlistListProvider = FutureProvider<List<Playlist>>((ref) async {
  return LocalDatabase.getAllPlaylists();
});
