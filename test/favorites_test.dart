import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:opentune/domain/entities/playlist.dart';
import 'package:opentune/domain/entities/track.dart';
import 'package:opentune/data/datasources/local_database.dart';
import 'package:opentune/presentation/providers/favorites_provider.dart';
import 'package:opentune/presentation/providers/player_provider.dart';

void main() {
  late Directory tempDbDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDbDir = await Directory.systemTemp.createTemp('opentune_test_db_');
    await databaseFactory.setDatabasesPath(tempDbDir.path);
  });

  tearDownAll(() async {
    if (await tempDbDir.exists()) {
      await tempDbDir.delete(recursive: true);
    }
  });

  group('Playlist model', () {
    test('isFavorites serialization', () {
      final p1 = Playlist(
        name: 'Favorites',
        isFavorites: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final map = p1.toMap();
      expect(map['isFavorites'], 1);

      final p2 = Playlist.fromMap(map);
      expect(p2.isFavorites, isTrue);
      expect(p2.name, 'Favorites');

      final regular = Playlist(
        name: 'My Playlist',
        isFavorites: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(regular.toMap()['isFavorites'], 0);
      expect(Playlist.fromMap(regular.toMap()).isFavorites, isFalse);
    });
  });

  group('LocalDatabase Favorites Integration', () {
    test('Initializes favorites playlist and manages starred tracks', () async {
      // 1. Ensure concurrent initial calls (like startup of LibraryScreen,
      // FavoritesNotifier, and PlayerNotifier) share the same initialization
      // and do not close or corrupt each other's database instance.
      final results = await Future.wait([
        LocalDatabase.getAllPlaylists(),
        LocalDatabase.getAllTracks(),
        LocalDatabase.getFavoriteTrackIds(),
        LocalDatabase.getFavoritesPlaylistId(),
      ]);

      final playlists = results[0] as List<Playlist>;
      final favId = results[3] as int;
      expect(favId, isPositive);
      expect(playlists.isNotEmpty, isTrue);
      expect(playlists.first.isFavorites, isTrue);
      expect(playlists.first.name, LocalDatabase.favoritesPlaylistName);

      // 2. Add test tracks
      final now = DateTime.now();
      final track1Id = await LocalDatabase.insertTrack(
        Track(
          title: 'Track A',
          artist: 'Artist A',
          filePath: '/tmp/test_a.mp3',
          duration: const Duration(seconds: 120),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final track2Id = await LocalDatabase.insertTrack(
        Track(
          title: 'Track B',
          artist: 'Artist B',
          filePath: '/tmp/test_b.mp3',
          duration: const Duration(seconds: 150),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 3. Mark track1 as favorite
      await LocalDatabase.setTrackFavorite(track1Id, true);
      var favIds = await LocalDatabase.getFavoriteTrackIds();
      expect(favIds.contains(track1Id), isTrue);
      expect(favIds.contains(track2Id), isFalse);

      // Verify Favorites playlist has track1
      var updatedPlaylists = await LocalDatabase.getAllPlaylists();
      final favPlaylist = updatedPlaylists.firstWhere((p) => p.isFavorites);
      expect(favPlaylist.trackIds, contains(track1Id));

      // 4. Mark track2 as favorite
      await LocalDatabase.setTrackFavorite(track2Id, true);
      favIds = await LocalDatabase.getFavoriteTrackIds();
      expect(favIds.contains(track1Id), isTrue);
      expect(favIds.contains(track2Id), isTrue);

      // 5. Unmark track1
      await LocalDatabase.setTrackFavorite(track1Id, false);
      favIds = await LocalDatabase.getFavoriteTrackIds();
      expect(favIds.contains(track1Id), isFalse);
      expect(favIds.contains(track2Id), isTrue);

      // 6. Favorites playlist cannot be deleted
      await LocalDatabase.deletePlaylist(favId);
      final playlistsAfterDeleteAttempt = await LocalDatabase.getAllPlaylists();
      expect(playlistsAfterDeleteAttempt.any((p) => p.isFavorites), isTrue);

      // Cleanup tracks
      await LocalDatabase.deleteTrack(track1Id);
      await LocalDatabase.deleteTrack(track2Id);
    });
  });

  group('FavoritesNotifier', () {
    test('Toggles and refreshes correctly', () async {
      final notifier = FavoritesNotifier();
      await notifier.refresh();

      final now = DateTime.now();
      final trackId = await LocalDatabase.insertTrack(
        Track(
          title: 'Test Track',
          artist: 'Test Artist',
          filePath: '/tmp/notifier_test.mp3',
          duration: const Duration(seconds: 60),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(notifier.isFavorite(trackId), isFalse);

      // Toggle ON
      final result1 = await notifier.toggle(trackId);
      expect(result1, isTrue);
      expect(notifier.isFavorite(trackId), isTrue);

      // Toggle OFF
      final result2 = await notifier.toggle(trackId);
      expect(result2, isFalse);
      expect(notifier.isFavorite(trackId), isFalse);

      // Cleanup
      await LocalDatabase.deleteTrack(trackId);
    });
  });

  group('PlayerState favorites queue state', () {
    test('isFavoritesQueue and activePlaylistId in copyWith and defaults', () {
      const state = PlayerState();
      expect(state.isFavoritesQueue, isFalse);
      expect(state.activePlaylistId, isNull);

      final withFav = state.copyWith(
        activePlaylistId: 42,
        isFavoritesQueue: true,
      );
      expect(withFav.isFavoritesQueue, isTrue);
      expect(withFav.activePlaylistId, 42);

      final cleared = withFav.copyWith(clearActivePlaylist: true);
      expect(cleared.isFavoritesQueue, isFalse);
      expect(cleared.activePlaylistId, isNull);
    });
  });
}
