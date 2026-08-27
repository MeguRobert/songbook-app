import '../../data/models/song_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import 'providers.dart';
import 'song_provider.dart';

/// State for favorites
class FavoritesState {
  final Set<SongId> favoriteSongIds;

  /// Favorites in user-defined display order (by `Favorite.sortOrder`).
  /// The Set above answers "is this a favorite?"; it cannot carry order, so
  /// reordering needs this list.
  final List<SongId> orderedSongIds;
  final bool isLoading;

  const FavoritesState({
    this.favoriteSongIds = const {},
    this.orderedSongIds = const [],
    this.isLoading = false,
  });

  FavoritesState copyWith({
    Set<SongId>? favoriteSongIds,
    List<SongId>? orderedSongIds,
    bool? isLoading,
  }) {
    return FavoritesState(
      favoriteSongIds: favoriteSongIds ?? this.favoriteSongIds,
      orderedSongIds: orderedSongIds ?? this.orderedSongIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool isFavorite(SongId songId) => favoriteSongIds.contains(songId);

  int get count => favoriteSongIds.length;
}

/// Notifier for managing favorites
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref _ref;

  FavoritesNotifier(this._ref) : super(const FavoritesState()) {
    _loadFavorites();

    // Cross-device sync, if this build has it at all. The guard is synchronous
    // and returns before anything else happens, so a build with the flag off
    // has precisely the constructor it had before sync existed -- one local
    // read, no auth stream, no extra state emission.
    if (!_ref.read(favoritesRepositoryProvider).syncsAcrossDevices) return;

    // On every auth transition, not only at startup: signing in is the moment
    // the account's favourites become relevant, and signing out is the moment
    // to stop pushing.
    _ref.listen(authStateChangesProvider, (_, __) => _syncWithAccount());
    _syncWithAccount();
  }

  /// Merges with the account, then reloads from storage.
  ///
  /// Never throws and never reports failure: the repository treats an
  /// unreachable server as "carry on with what is on the device", which is a
  /// normal state for this app rather than an error to put on screen.
  Future<void> _syncWithAccount() async {
    await _ref.read(favoritesRepositoryProvider).sync();
    if (!mounted) return;
    _loadFavorites();
  }

  void _loadFavorites() {
    final repository = _ref.read(favoritesRepositoryProvider);
    final favorites = repository.getFavoriteSongIds();
    state = state.copyWith(
      favoriteSongIds: favorites.toSet(),
      orderedSongIds: favorites,
    );
  }

  /// Persists a new display order and refreshes state from storage.
  Future<void> reorder(List<SongId> orderedSongIds) async {
    await _ref
        .read(favoritesRepositoryProvider)
        .reorderFavorites(orderedSongIds);
    _loadFavorites();
  }

  Future<void> toggleFavorite(SongId songId) async {
    state = state.copyWith(isLoading: true);

    final repository = _ref.read(favoritesRepositoryProvider);
    await repository.toggleFavorite(songId);

    // Reload from storage rather than patching the Set by hand: the ordered
    // list has to stay in step with it, and storage is the source of truth for
    // sortOrder. Updating only the Set left the Favorites screen empty.
    _loadFavorites();
    state = state.copyWith(isLoading: false);
  }

  Future<void> addFavorite(SongId songId) async {
    if (state.isFavorite(songId)) return;

    state = state.copyWith(isLoading: true);

    final repository = _ref.read(favoritesRepositoryProvider);
    await repository.addFavorite(songId);

    // Reload so favoriteSongIds and orderedSongIds stay in step.
    _loadFavorites();
    state = state.copyWith(isLoading: false);
  }

  Future<void> removeFavorite(SongId songId) async {
    if (!state.isFavorite(songId)) return;

    state = state.copyWith(isLoading: true);

    final repository = _ref.read(favoritesRepositoryProvider);
    await repository.removeFavorite(songId);

    // Reload so favoriteSongIds and orderedSongIds stay in step.
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
final isFavoriteProvider = Provider.family<bool, SongId>((ref, songId) {
  return ref.watch(favoritesProvider).isFavorite(songId);
});

/// Provider for favorite songs, in the user's chosen order.
///
/// Iterates `orderedSongIds` rather than filtering the catalog, so the list
/// follows `Favorite.sortOrder`. Filtering `songs` instead returned catalog
/// (song-number) order and silently ignored any reorder.
final favoriteSongsProvider = FutureProvider<List<Song>>((ref) async {
  final favoritesState = ref.watch(favoritesProvider);
  final songs = await ref.watch(songsProvider.future);

  final byId = {for (final s in songs) s.id: s};
  return favoritesState.orderedSongIds
      .where(byId.containsKey)
      .map((id) => byId[id]!)
      .toList();
});
