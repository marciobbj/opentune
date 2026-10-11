import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local_database.dart';

/// Holds the set of track ids currently marked as favorite (starred).
///
/// Favorites are persisted as membership in the built-in "Favorites"
/// playlist, so starring a track automatically adds it to that playlist.
class FavoritesNotifier extends StateNotifier<Set<int>> {
  FavoritesNotifier() : super(const <int>{}) {
    refresh();
  }

  /// Re-reads favorites from the database. Call this after any code path that
  /// mutates the Favorites playlist directly (e.g. playlist screens).
  Future<void> refresh() async {
    final ids = await LocalDatabase.getFavoriteTrackIds();
    if (!mounted) return;
    if (!setEquals(ids, state)) state = ids;
  }

  bool isFavorite(int? trackId) => trackId != null && state.contains(trackId);

  /// Toggles the favorite state of [trackId]. Returns the new state.
  Future<bool> toggle(int trackId) async {
    final newValue = !state.contains(trackId);
    await setFavorite(trackId, newValue);
    return newValue;
  }

  Future<void> setFavorite(int trackId, bool favorite) async {
    // Persist first so listeners reloading playlists see the new data.
    // (SQLite writes are fast enough that the star still feels instant.)
    await LocalDatabase.setTrackFavorite(trackId, favorite);
    if (!mounted) return;
    state = favorite ? {...state, trackId} : ({...state}..remove(trackId));
  }

  /// Sets the favorite state for many tracks at once.
  Future<void> setFavoriteMany(Iterable<int> trackIds, bool favorite) async {
    for (final id in trackIds) {
      await LocalDatabase.setTrackFavorite(id, favorite);
    }
    await refresh();
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<int>>(
  (ref) => FavoritesNotifier(),
);
