import '../datasources/local/local_datasource.dart';
import '../models/song_id.dart';
import '../models/favorite.dart';
import '../models/song.dart';

/// Repository for managing favorite songs
class FavoritesRepository {
  final LocalDataSource _localDataSource;

  FavoritesRepository(this._localDataSource);

  /// Gets all favorites in user-defined display order.
  ///
  /// Sorted by [Favorite.sortOrder] so a reorder actually shows up; the stored
  /// blob is in insertion order. Ties (e.g. entries written before reordering
  /// existed, all sortOrder 0) fall back to song id for a stable result.
  List<Favorite> getFavorites() {
    final favorites = _localDataSource.getFavorites();
    favorites.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.songId.compareTo(b.songId);
    });
    return favorites;
  }

  /// Gets favorite song ids
  List<SongId> getFavoriteSongIds() {
    return getFavorites().map((f) => f.songId).toList();
  }

  /// Adds a song to favorites
  Future<bool> addFavorite(SongId songId) {
    return _localDataSource.addFavorite(songId);
  }

  /// Removes a song from favorites
  Future<bool> removeFavorite(SongId songId) {
    return _localDataSource.removeFavorite(songId);
  }

  /// Toggles the favorite status of a song
  Future<bool> toggleFavorite(SongId songId) async {
    if (isFavorite(songId)) {
      return removeFavorite(songId);
    } else {
      return addFavorite(songId);
    }
  }

  /// Checks if a song is a favorite
  bool isFavorite(SongId songId) {
    return _localDataSource.isFavorite(songId);
  }

  /// Gets the number of favorites
  int get favoriteCount => getFavorites().length;

  /// Reorders favorites
  Future<bool> reorderFavorites(List<SongId> orderedSongIds) async {
    final favorites = getFavorites();
    final updatedFavorites = <Favorite>[];

    for (int i = 0; i < orderedSongIds.length; i++) {
      final songId = orderedSongIds[i];
      final existing = favorites.firstWhere(
        (f) => f.songId == songId,
        orElse: () => Favorite(
          songId: songId,
          addedAt: DateTime.now(),
        ),
      );
      updatedFavorites.add(existing.copyWith(sortOrder: i));
    }

    return _localDataSource.saveFavorites(updatedFavorites);
  }

  /// Gets favorite songs sorted by order
  Future<List<Song>> getFavoriteSongs(
    Future<List<Song>> Function(List<SongId>) songLoader,
  ) async {
    final favorites = getFavorites();
    if (favorites.isEmpty) return [];

    // Sort by sortOrder
    favorites.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final songIds = favorites.map((f) => f.songId).toList();

    final songs = await songLoader(songIds);

    // Maintain the favorite order
    final songMap = {for (var s in songs) s.id: s};
    return songIds
        .where(songMap.containsKey)
        .map((id) => songMap[id]!)
        .toList();
  }
}
