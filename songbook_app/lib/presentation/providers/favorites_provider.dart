import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import 'providers.dart';
import 'song_provider.dart';

/// State for favorites
class FavoritesState {
  final Set<int> favoriteSongNumbers;
  final bool isLoading;

  const FavoritesState({
    this.favoriteSongNumbers = const {},
    this.isLoading = false,
  });

  FavoritesState copyWith({
    Set<int>? favoriteSongNumbers,
    bool? isLoading,
  }) {
    return FavoritesState(
      favoriteSongNumbers: favoriteSongNumbers ?? this.favoriteSongNumbers,
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
    state = state.copyWith(favoriteSongNumbers: favorites.toSet());
  }

  Future<void> toggleFavorite(int songNumber) async {
    state = state.copyWith(isLoading: true);

    final repository = _ref.read(favoritesRepositoryProvider);
    await repository.toggleFavorite(songNumber);

    final newFavorites = Set<int>.from(state.favoriteSongNumbers);
    if (newFavorites.contains(songNumber)) {
      newFavorites.remove(songNumber);
    } else {
      newFavorites.add(songNumber);
    }

    state = state.copyWith(
      favoriteSongNumbers: newFavorites,
      isLoading: false,
    );
  }

  Future<void> addFavorite(int songNumber) async {
    if (state.isFavorite(songNumber)) return;

    state = state.copyWith(isLoading: true);

    final repository = _ref.read(favoritesRepositoryProvider);
    await repository.addFavorite(songNumber);

    state = state.copyWith(
      favoriteSongNumbers: {...state.favoriteSongNumbers, songNumber},
      isLoading: false,
    );
  }

  Future<void> removeFavorite(int songNumber) async {
    if (!state.isFavorite(songNumber)) return;

    state = state.copyWith(isLoading: true);

    final repository = _ref.read(favoritesRepositoryProvider);
    await repository.removeFavorite(songNumber);

    final newFavorites = Set<int>.from(state.favoriteSongNumbers)
      ..remove(songNumber);

    state = state.copyWith(
      favoriteSongNumbers: newFavorites,
      isLoading: false,
    );
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

/// Provider for favorite songs
final favoriteSongsProvider = FutureProvider<List<Song>>((ref) async {
  final favoritesState = ref.watch(favoritesProvider);
  final songs = await ref.watch(songsProvider.future);

  final favoriteNumbers = favoritesState.favoriteSongNumbers;
  return songs.where((s) => favoriteNumbers.contains(s.number)).toList();
});
