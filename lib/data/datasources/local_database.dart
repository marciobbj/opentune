import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/track_settings.dart';
import '../../domain/entities/playlist.dart';

class LocalDatabase {
  static Database? _database;
  static const String _dbName = 'opentune.db';
  static const int _dbVersion = 1;

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT DEFAULT '',
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
    final maps = await db.query('tracks',
        where: 'filePath = ?', whereArgs: [filePath]);
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
    final maps = await db.query('playlists', orderBy: 'updatedAt DESC');
    final playlists = <Playlist>[];

    for (final map in maps) {
      final trackMaps = await db.query(
        'playlist_tracks',
        where: 'playlistId = ?',
        whereArgs: [map['id']],
        orderBy: 'orderIndex ASC',
      );
      final trackIds =
          trackMaps.map((m) => m['trackId'] as int).toList();
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

    final count = (await db.query(
      'playlist_tracks',
      where: 'playlistId = ?',
      whereArgs: [playlistId],
    ))
        .length;

    await db.insert('playlist_tracks', {
      'playlistId': playlistId,
      'trackId': trackId,
      'orderIndex': count,
    });
  }

  static Future<void> removeTrackFromPlaylist(
      int playlistId, int trackId) async {
    final db = await database;
    await db.delete(
      'playlist_tracks',
      where: 'playlistId = ? AND trackId = ?',
      whereArgs: [playlistId, trackId],
    );
  }

  static Future<void> deletePlaylist(int id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }
}
