import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import 'providers.dart';
import 'song_provider.dart';

/// State for favorites
class FavoritesState {
  final Set<int> favoriteSongNumbers;

  /// Favorites in user-defined display order (by `Favorite.sortOrder`).
  /// The Set above answers "is this a favorite?"; it cannot carry order, so
  /// reordering needs this list.
  final List<int> orderedSongNumbers;
  final bool isLoading;

  const FavoritesState({
    this.favoriteSongNumbers = const {},
    this.orderedSongNumbers = const [],
    this.isLoading = false,
  });

  FavoritesState copyWith({
    Set<int>? favoriteSongNumbers,
    List<int>? orderedSongNumbers,
    bool? isLoading,
  }) {
    return FavoritesState(
      favoriteSongNumbers: favoriteSongNumbers ?? this.favoriteSongNumbers,
      orderedSongNumbers: orderedSongNumbers ?? this.orderedSongNumbers,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool isFavorite(int songNumber) => favoriteSongNumbers.contains(songNumber);

  int get count => favoriteSongNumbers.length;
}

/// Notifier for managing favorites
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref _ref;

  FavoritesNotifier(this._ref) : super(const FavoritesState()) {
    _loadFavorites();
  }

  void _loadFavorites() {
    final repository = _ref.read(favoritesRepositoryProvider);
    final favorites = repository.getFavoriteSongNumbers();
    state = state.copyWith(
      favoriteSongNumbers: favorites.toSet(),
      orderedSongNumbers: favorites,
    );
  }

  /// Persists a new display order and refreshes state from storage.
  Future<void> reorder(List<int> orderedSongNumbers) async {
    await _ref
        .read(favoritesRepositoryProvider)
        .reorderFavorites(orderedSongNumbers);
    _loadFavorites();
  }

  Future<void> toggleFavorite(int songNumber) async {
    state = state.copyWith(isLoading: true);

    final repository = _ref.read(favoritesRepositoryProvider);
    await repository.toggleFavorite(songNumber);

    // Reload from storage rather than patching the Set by hand: the ordered
    // list has to stay in step with it, and storage is the source of truth for
    // sortOrder. Updating only the Set left the Favorites screen empty.
    _loadFavorites();
    state = state.copyWith(isLoading: false);
  }

  Future<void> addFavorite(int songNumber) async {
    if (state.isFavorite(songNumber)) return;

    state = state.copyWith(isLoading: true);

    final repository = _ref.read(favoritesRepositoryProvider);
    await repository.addFavorite(songNumber);

    // Reload so favoriteSongNumbers and orderedSongNumbers stay in step.
    _loadFavorites();
    state = state.copyWith(isLoading: false);
  }

  Future<void> removeFavorite(int songNumber) async {
    if (!state.isFavorite(songNumber)) return;

    state = state.copyWith(isLoading: true);

    final repository = _ref.read(favoritesRepositoryProvider);
    await repository.removeFavorite(songNumber);

    // Reload so favoriteSongNumbers and orderedSongNumbers stay in step.
    _loadFavorites();
    state = state.copyWith(isLoading: false);
  }

  void refresh() {
    _loadFavorites();
  }
}

/// Provider for favorites state
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref);
});

/// Provider to check if a specific song is a favorite
final isFavoriteProvider = Provider.family<bool, int>((ref, songNumber) {
  return ref.watch(favoritesProvider).isFavorite(songNumber);
});

/// Provider for favorite songs, in the user's chosen order.
///
/// Iterates `orderedSongNumbers` rather than filtering the catalog, so the list
/// follows `Favorite.sortOrder`. Filtering `songs` instead returned catalog
/// (song-number) order and silently ignored any reorder.
final favoriteSongsProvider = FutureProvider<List<Song>>((ref) async {
  final favoritesState = ref.watch(favoritesProvider);
  final songs = await ref.watch(songsProvider.future);

  final byNumber = {for (final s in songs) s.number: s};
  return favoritesState.orderedSongNumbers
      .where(byNumber.containsKey)
      .map((n) => byNumber[n]!)
      .toList();
});
