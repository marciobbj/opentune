import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/track_settings.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/playlist_sort.dart';

class LocalDatabase {
  static Database? _database;
  static const String _dbName = 'opentune.db';
  static const int _dbVersion = 5;

  /// Display name of the built-in favorites playlist.
  static const String favoritesPlaylistName = 'Favorites';

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String dbPath;
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      final appSupportDir = await getApplicationSupportDirectory();
      await appSupportDir.create(recursive: true);
      dbPath = appSupportDir.path;
      await _migrateLegacyDesktopDatabase(join(dbPath, _dbName));
    } else {
      dbPath = await getDatabasesPath();
      await Directory(dbPath).create(recursive: true);
    }
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _ensureFavoritesPlaylist,
    );
  }

  /// Migrates the database from the legacy sqflite_common_ffi location
  /// (`.dart_tool/sqflite_common_ffi/databases/opentune.db`, used up to v0.7.1)
  /// to the new Application Support directory, keeping the legacy file intact
  /// as a backup.
  ///
  /// Also handles the case where v0.8.0 was already opened once and created an
  /// empty database at [targetPath] while the user's populated database is
  /// still in the legacy path.
  static Future<void> _migrateLegacyDesktopDatabase(String targetPath) async {
    try {
      final candidateDirs = <String>{
        Directory.current.path,
        if (Platform.environment['HOME'] case final home? when home.isNotEmpty)
          home,
        if (Platform.environment['USERPROFILE'] case final profile?
            when profile.isNotEmpty)
          profile,
      };

      File? legacyFile;
      for (final baseDir in candidateDirs) {
        final candidate = File(
          join(
            baseDir,
            '.dart_tool',
            'sqflite_common_ffi',
            'databases',
            _dbName,
          ),
        );
        if (await candidate.exists() && candidate.path != targetPath) {
          legacyFile = candidate;
          break;
        }
      }

      if (legacyFile == null) return;

      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        // Check if the current target DB already has user tracks; if it's empty
        // and the legacy DB has tracks, migrate over the empty DB.
        final targetHasData = await _databaseHasTracks(targetPath);
        if (targetHasData) return;

        final legacyHasData = await _databaseHasTracks(legacyFile.path);
        if (!legacyHasData) return;
      }

      // Copy main database file (keeping legacy file untouched)
      await legacyFile.copy(targetPath);

      // Copy WAL / SHM sidecar files if present so uncommitted WAL frames aren't lost
      for (final suffix in ['-wal', '-shm']) {
        final legacySidecar = File('${legacyFile.path}$suffix');
        final targetSidecar = File('$targetPath$suffix');
        if (await legacySidecar.exists()) {
          await legacySidecar.copy(targetSidecar.path);
        } else if (await targetSidecar.exists()) {
          await targetSidecar.delete();
        }
      }
    } catch (e) {
      debugPrint('Failed to migrate legacy database: $e');
    }
  }

  static Future<bool> _databaseHasTracks(String dbFilePath) async {
    Database? db;
    try {
      db = await openDatabase(dbFilePath, readOnly: true);
      final result = await db.rawQuery('SELECT COUNT(*) AS cnt FROM tracks');
      final count = (result.firstOrNull?['cnt'] as int?) ?? 0;
      return count > 0;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  /// Makes sure the built-in Favorites playlist exists.
  static Future<void> _ensureFavoritesPlaylist(Database db) async {
    final existing = await db.query(
      'playlists',
      columns: ['id'],
      where: 'isFavorites = 1',
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toIso8601String();
    await db.insert('playlists', {
      'name': favoritesPlaylistName,
      'description': 'Your starred tracks',
      'isFavorites': 1,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT DEFAULT '',
        albumArtPath TEXT,
        bookmarkData TEXT,
        filePath TEXT NOT NULL UNIQUE,
        durationMs INTEGER NOT NULL,
        originalBpm REAL DEFAULT 120.0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trackId INTEGER NOT NULL,
        label TEXT NOT NULL,
        startTimeMs INTEGER NOT NULL,
        endTimeMs INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        FOREIGN KEY (trackId) REFERENCES tracks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE track_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trackId INTEGER NOT NULL UNIQUE,
        tempo REAL DEFAULT 1.0,
        pitch REAL DEFAULT 0.0,
        loopStartMs INTEGER,
        loopEndMs INTEGER,
        loopEnabled INTEGER DEFAULT 0,
        lastPositionMs INTEGER DEFAULT 0,
        FOREIGN KEY (trackId) REFERENCES tracks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        isFavorites INTEGER DEFAULT 0,
        sortMode TEXT DEFAULT 'custom',
        sortAscending INTEGER DEFAULT 1,
        shuffleSeed INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlistId INTEGER NOT NULL,
        trackId INTEGER NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        FOREIGN KEY (playlistId) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (trackId) REFERENCES tracks(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tracks ADD COLUMN albumArtPath TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tracks ADD COLUMN bookmarkData TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE playlists ADD COLUMN isFavorites INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE playlists ADD COLUMN sortMode TEXT DEFAULT 'custom'",
      );
      await db.execute(
        'ALTER TABLE playlists ADD COLUMN sortAscending INTEGER DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE playlists ADD COLUMN shuffleSeed INTEGER DEFAULT 0',
      );
    }
  }

  // ── Track CRUD ──

  static Future<int> insertTrack(Track track) async {
    final db = await database;
    return db.insert('tracks', track.toMap()..remove('id'));
  }

  static Future<List<Track>> getAllTracks() async {
    final db = await database;
    final maps = await db.query('tracks', orderBy: 'title ASC');
    return maps.map((m) => Track.fromMap(m)).toList();
  }

  static Future<Track?> getTrackById(int id) async {
    final db = await database;
    final maps = await db.query('tracks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Track.fromMap(maps.first);
  }

  static Future<Track?> getTrackByPath(String filePath) async {
    final db = await database;
    final maps = await db.query(
      'tracks',
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
    if (maps.isEmpty) return null;
    return Track.fromMap(maps.first);
  }

  static Future<void> updateTrack(Track track) async {
    final db = await database;
    await db.update(
      'tracks',
      track.toMap(),
      where: 'id = ?',
      whereArgs: [track.id],
    );
  }

  static Future<void> deleteTrack(int id) async {
    final db = await database;
    // Remove from any playlists first (handles cases where foreign keys pragma was not active)
    await db.delete('playlist_tracks', where: 'trackId = ?', whereArgs: [id]);
    await db.delete('tracks', where: 'id = ?', whereArgs: [id]);
  }

  // ── Section CRUD ──

  static Future<int> insertSection(Section section) async {
    final db = await database;
    return db.insert('sections', section.toMap()..remove('id'));
  }

  static Future<List<Section>> getSectionsForTrack(int trackId) async {
    final db = await database;
    final maps = await db.query(
      'sections',
      where: 'trackId = ?',
      whereArgs: [trackId],
      orderBy: 'startTimeMs ASC',
    );
    return maps.map((m) => Section.fromMap(m)).toList();
  }

  static Future<void> updateSection(Section section) async {
    final db = await database;
    await db.update(
      'sections',
      section.toMap(),
      where: 'id = ?',
      whereArgs: [section.id],
    );
  }

  static Future<void> deleteSection(int id) async {
    final db = await database;
    await db.delete('sections', where: 'id = ?', whereArgs: [id]);
  }

  // ── TrackSettings CRUD ──

  static Future<void> upsertTrackSettings(TrackSettings settings) async {
    final db = await database;
    final existing = await db.query(
      'track_settings',
      where: 'trackId = ?',
      whereArgs: [settings.trackId],
    );

    if (existing.isEmpty) {
      await db.insert('track_settings', settings.toMap()..remove('id'));
    } else {
      await db.update(
        'track_settings',
        settings.toMap()..remove('id'),
        where: 'trackId = ?',
        whereArgs: [settings.trackId],
      );
    }
  }

  static Future<TrackSettings?> getTrackSettings(int trackId) async {
    final db = await database;
    final maps = await db.query(
      'track_settings',
      where: 'trackId = ?',
      whereArgs: [trackId],
    );
    if (maps.isEmpty) return null;
    return TrackSettings.fromMap(maps.first);
  }

  // ── Playlist CRUD ──

  static Future<int> insertPlaylist(Playlist playlist) async {
    final db = await database;
    return db.insert('playlists', playlist.toMap()..remove('id'));
  }

  static Future<List<Playlist>> getAllPlaylists() async {
    final db = await database;
    // The Favorites playlist is always pinned first.
    final maps = await db.query(
      'playlists',
      orderBy: 'isFavorites DESC, updatedAt DESC',
    );
    final playlists = <Playlist>[];

    for (final map in maps) {
      final trackMaps = await db.query(
        'playlist_tracks',
        where: 'playlistId = ?',
        whereArgs: [map['id']],
        orderBy: 'orderIndex ASC',
      );
      final trackIds = trackMaps.map((m) => m['trackId'] as int).toList();
      playlists.add(Playlist.fromMap(map).copyWith(trackIds: trackIds));
    }

    return playlists;
  }

  static Future<void> addTrackToPlaylist(int playlistId, int trackId) async {
    final db = await database;
    final existing = await db.query(
      'playlist_tracks',
      where: 'playlistId = ? AND trackId = ?',
      whereArgs: [playlistId, trackId],
    );
    if (existing.isNotEmpty) return;

    // Use MAX + 1 (instead of COUNT) so the order stays correct after removals.
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(orderIndex), -1) + 1 AS nextIndex '
      'FROM playlist_tracks WHERE playlistId = ?',
      [playlistId],
    );
    final nextIndex = (result.first['nextIndex'] as int?) ?? 0;

    await db.insert('playlist_tracks', {
      'playlistId': playlistId,
      'trackId': trackId,
      'orderIndex': nextIndex,
    });
  }

  static Future<void> removeTrackFromPlaylist(
    int playlistId,
    int trackId,
  ) async {
    final db = await database;
    await db.delete(
      'playlist_tracks',
      where: 'playlistId = ? AND trackId = ?',
      whereArgs: [playlistId, trackId],
    );
  }

  /// Persists the sort settings of a playlist. Doesn't touch `updatedAt`, so
  /// changing the view order doesn't reorder the playlist list.
  static Future<void> updatePlaylistSort(
    int playlistId, {
    required PlaylistSortMode mode,
    required bool ascending,
    required int shuffleSeed,
  }) async {
    final db = await database;
    await db.update(
      'playlists',
      {
        'sortMode': mode.key,
        'sortAscending': ascending ? 1 : 0,
        'shuffleSeed': shuffleSeed,
      },
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  /// Persists the manual (custom) order of a playlist.
  static Future<void> reorderPlaylistTracks(
    int playlistId,
    List<int> orderedTrackIds,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (var i = 0; i < orderedTrackIds.length; i++) {
      batch.update(
        'playlist_tracks',
        {'orderIndex': i},
        where: 'playlistId = ? AND trackId = ?',
        whereArgs: [playlistId, orderedTrackIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Maps each track id of a playlist to a value that grows with the time it
  /// was added (the auto-increment row id of `playlist_tracks`, which is not
  /// affected by manual reordering).
  static Future<Map<int, int>> getPlaylistAddedRanks(int playlistId) async {
    final db = await database;
    final rows = await db.query(
      'playlist_tracks',
      columns: ['id', 'trackId'],
      where: 'playlistId = ?',
      whereArgs: [playlistId],
    );
    return {for (final r in rows) r['trackId'] as int: r['id'] as int};
  }

  static Future<void> deletePlaylist(int id) async {
    final db = await database;
    // The built-in Favorites playlist can never be deleted.
    await db.delete(
      'playlists',
      where: 'id = ? AND COALESCE(isFavorites, 0) = 0',
      whereArgs: [id],
    );
  }

  // ── Favorites ──

  /// Returns the id of the built-in Favorites playlist (creating it if needed).
  static Future<int> getFavoritesPlaylistId() async {
    final db = await database;
    var rows = await db.query(
      'playlists',
      columns: ['id'],
      where: 'isFavorites = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      await _ensureFavoritesPlaylist(db);
      rows = await db.query(
        'playlists',
        columns: ['id'],
        where: 'isFavorites = 1',
        limit: 1,
      );
    }
    return rows.first['id'] as int;
  }

  /// Ids of all tracks currently marked as favorite.
  static Future<Set<int>> getFavoriteTrackIds() async {
    final db = await database;
    final playlistId = await getFavoritesPlaylistId();
    final rows = await db.query(
      'playlist_tracks',
      columns: ['trackId'],
      where: 'playlistId = ?',
      whereArgs: [playlistId],
    );
    return rows.map((r) => r['trackId'] as int).toSet();
  }

  /// Marks / unmarks a track as favorite by adding or removing it from the
  /// Favorites playlist.
  static Future<void> setTrackFavorite(int trackId, bool favorite) async {
    final playlistId = await getFavoritesPlaylistId();
    if (favorite) {
      await addTrackToPlaylist(playlistId, trackId);
    } else {
      await removeTrackFromPlaylist(playlistId, trackId);
    }
  }
}
