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

  /// Active tag filters (AND semantics). Transient — not persisted.
  final Set<String> activeTags;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.recentSearches = const [],
    this.activeTags = const {},
  });

  SearchState copyWith({
    String? query,
    List<Song>? results,
    bool? isSearching,
    List<String>? recentSearches,
    Set<String>? activeTags,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      recentSearches: recentSearches ?? this.recentSearches,
      activeTags: activeTags ?? this.activeTags,
    );
  }

  bool get hasQuery => query.isNotEmpty;
  bool get hasResults => results.isNotEmpty;
  bool get hasTags => activeTags.isNotEmpty;

  /// Whether the results area should be shown (vs. the recent-searches hint).
  bool get isFiltering => hasQuery || hasTags;
}

/// Notifier for search functionality
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchNotifier(this._ref) : super(const SearchState());

  Future<void> search(String query) async {
    // Repeating the identical query is a no-op — it would otherwise re-run the
    // search on every keystroke that leaves the text unchanged. Tag filters do
    // not need this path: toggleTag/setTags/clearTags recompute on their own.
    if (query == state.query) return;

    state = state.copyWith(query: query, isSearching: true);
    await _recompute();
  }

  /// Toggles a tag filter (case-insensitive) and recomputes results.
  Future<void> toggleTag(String tag) async {
    final next = <String>{...state.activeTags};
    final lower = tag.toLowerCase();
    final existing = next.where((t) => t.toLowerCase() == lower).toList();
    if (existing.isEmpty) {
      next.add(tag);
    } else {
      next.removeWhere((t) => t.toLowerCase() == lower);
    }
    state = state.copyWith(activeTags: next);
    await _recompute();
  }

  /// Replaces the active tag filters.
  Future<void> setTags(Set<String> tags) async {
    state = state.copyWith(activeTags: {...tags});
    await _recompute();
  }

  /// Clears all active tag filters.
  Future<void> clearTags() async {
    state = state.copyWith(activeTags: {});
    await _recompute();
  }

  /// Recomputes results from the current query AND active tags.
  ///
  /// Tags filter first (AND); the query then narrows within the tagged set. An
  /// empty query with active tags shows all songs carrying those tags.
  Future<void> _recompute() async {
    if (!state.isFiltering) {
      state = state.copyWith(results: [], isSearching: false);
      return;
    }

    final allSongs = await _ref.read(songsProvider.future);
    final searchService = _ref.read(searchServiceProvider);

    var songs = allSongs;
    if (state.hasTags) {
      songs = searchService.filterByTags(songs, state.activeTags);
    }

    final results =
        state.hasQuery ? searchService.search(songs, state.query) : songs;

    state = state.copyWith(results: results, isSearching: false);
  }

  void clear() {
    state = state.copyWith(
      query: '',
      results: [],
      isSearching: false,
      activeTags: {},
    );
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
