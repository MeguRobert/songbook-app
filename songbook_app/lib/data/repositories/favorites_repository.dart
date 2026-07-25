import '../datasources/local/local_datasource.dart';
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
  /// existed, all sortOrder 0) fall back to song number for a stable result.
  List<Favorite> getFavorites() {
    final favorites = _localDataSource.getFavorites();
    favorites.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.songNumber.compareTo(b.songNumber);
    });
    return favorites;
  }

  /// Gets favorite song numbers
  List<int> getFavoriteSongNumbers() {
    return getFavorites().map((f) => f.songNumber).toList();
  }

  /// Adds a song to favorites
  Future<bool> addFavorite(int songNumber) {
    return _localDataSource.addFavorite(songNumber);
  }

  /// Removes a song from favorites
  Future<bool> removeFavorite(int songNumber) {
    return _localDataSource.removeFavorite(songNumber);
  }

  /// Toggles the favorite status of a song
  Future<bool> toggleFavorite(int songNumber) async {
    if (isFavorite(songNumber)) {
      return removeFavorite(songNumber);
    } else {
      return addFavorite(songNumber);
    }
  }

  /// Checks if a song is a favorite
  bool isFavorite(int songNumber) {
    return _localDataSource.isFavorite(songNumber);
  }

  /// Gets the number of favorites
  int get favoriteCount => getFavorites().length;

  /// Reorders favorites
  Future<bool> reorderFavorites(List<int> orderedSongNumbers) async {
    final favorites = getFavorites();
    final updatedFavorites = <Favorite>[];

    for (int i = 0; i < orderedSongNumbers.length; i++) {
      final songNumber = orderedSongNumbers[i];
      final existing = favorites.firstWhere(
        (f) => f.songNumber == songNumber,
        orElse: () => Favorite(
          songNumber: songNumber,
          addedAt: DateTime.now(),
        ),
      );
      updatedFavorites.add(existing.copyWith(sortOrder: i));
    }

    return _localDataSource.saveFavorites(updatedFavorites);
  }

  /// Gets favorite songs sorted by order
  Future<List<Song>> getFavoriteSongs(
    Future<List<Song>> Function(List<int>) songLoader,
  ) async {
    final favorites = getFavorites();
    if (favorites.isEmpty) return [];

    // Sort by sortOrder
    favorites.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final songNumbers = favorites.map((f) => f.songNumber).toList();

    final songs = await songLoader(songNumbers);

    // Maintain the favorite order
    final songMap = {for (var s in songs) s.number: s};
    return songNumbers
        .where((n) => songMap.containsKey(n))
        .map((n) => songMap[n]!)
        .toList();
  }
}
