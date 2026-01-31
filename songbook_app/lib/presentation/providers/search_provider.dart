import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import 'providers.dart';
import 'song_provider.dart';

/// State for search
class SearchState {
  final String query;
  final List<Song> results;
  final bool isSearching;
  final List<String> recentSearches;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.recentSearches = const [],
  });

  SearchState copyWith({
    String? query,
    List<Song>? results,
    bool? isSearching,
    List<String>? recentSearches,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }

  bool get hasQuery => query.isNotEmpty;
  bool get hasResults => results.isNotEmpty;
}

/// Notifier for search functionality
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchNotifier(this._ref) : super(const SearchState());

  Future<void> search(String query) async {
    if (query == state.query) return;

    state = state.copyWith(query: query, isSearching: true);

    if (query.isEmpty) {
      state = state.copyWith(results: [], isSearching: false);
      return;
    }

    final songs = await _ref.read(songsProvider.future);
    final searchService = _ref.read(searchServiceProvider);
    final results = searchService.search(songs, query);

    state = state.copyWith(results: results, isSearching: false);
  }

  void clear() {
    state = state.copyWith(query: '', results: [], isSearching: false);
  }

  void addToRecentSearches(String query) {
    if (query.isEmpty) return;

    final recent = List<String>.from(state.recentSearches);
    recent.remove(query); // Remove if exists
    recent.insert(0, query); // Add to front
    if (recent.length > 10) {
      recent.removeLast(); // Keep only last 10
    }

    state = state.copyWith(recentSearches: recent);
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
  }
}

/// Provider for search state
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

/// Provider for search results
final searchResultsProvider = Provider<List<Song>>((ref) {
  return ref.watch(searchProvider).results;
});

/// Provider for search query
final searchQueryProvider = Provider<String>((ref) {
  return ref.watch(searchProvider).query;
});

/// Provider for all unique tags
final allTagsProvider = FutureProvider<Set<String>>((ref) async {
  final songs = await ref.watch(songsProvider.future);
  final searchService = ref.read(searchServiceProvider);
  return searchService.getAllTags(songs);
});
