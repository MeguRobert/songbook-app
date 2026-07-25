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

  /// Matching lyric line per song number, populated only when the results came
  /// from the lyrics fallback. A lyrics hit shows nothing in its title to
  /// explain itself, so the line that matched is displayed under it.
  final Map<int, String> lyricSnippets;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.recentSearches = const [],
    this.activeTags = const {},
    this.lyricSnippets = const {},
  });

  SearchState copyWith({
    String? query,
    List<Song>? results,
    bool? isSearching,
    List<String>? recentSearches,
    Set<String>? activeTags,
    Map<int, String>? lyricSnippets,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      recentSearches: recentSearches ?? this.recentSearches,
      activeTags: activeTags ?? this.activeTags,
      lyricSnippets: lyricSnippets ?? this.lyricSnippets,
    );
  }

  bool get hasQuery => query.isNotEmpty;
  bool get hasResults => results.isNotEmpty;
  bool get hasTags => activeTags.isNotEmpty;

  /// Whether these results were found by scanning verse text rather than
  /// titles — drives the "found in lyrics" header.
  bool get matchedLyricsOnly => lyricSnippets.isNotEmpty;

  /// Whether the results area should be shown (vs. the recent-searches hint).
  bool get isFiltering => hasQuery || hasTags;
}

/// Notifier for search functionality
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  /// The song catalog the current [SearchState.results] were computed from.
  /// Kept so [onCatalogUpdated] can tell a genuine change (a tag edit) from
  /// the catalog simply finishing its first load.
  List<Song>? _catalog;

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

    final cached = _catalog;
    final List<Song> allSongs =
        cached ?? await _ref.read(songsProvider.future);
    _catalog = allSongs;

    // The filter can be cleared while the catalog is loading (type, then hit
    // the X). Without this second check the post-await path treats "no query,
    // no tags" as "no narrowing" and publishes the ENTIRE catalog as results.
    if (!state.isFiltering) {
      state = state.copyWith(results: [], isSearching: false);
      return;
    }

    final searchService = _ref.read(searchServiceProvider);

    var songs = allSongs;
    if (state.hasTags) {
      songs = searchService.filterByTags(songs, state.activeTags);
    }

    if (!state.hasQuery) {
      state = state.copyWith(
        results: songs,
        isSearching: false,
        lyricSnippets: const {},
      );
      return;
    }

    final results = searchService.search(songs, state.query);
    if (results.isNotEmpty) {
      state = state.copyWith(
        results: results,
        isSearching: false,
        lyricSnippets: const {},
      );
      return;
    }

    // Nothing matched on title, number, reference, tag or tune. Only now scan
    // verse text: run unconditionally, a common word like "az" would bury
    // every real title match under the whole hymnal. Tag filters still apply —
    // `songs` is already narrowed.
    final lyricHits = searchService.searchLyrics(songs, state.query);
    state = state.copyWith(
      results: lyricHits.map((h) => h.song).toList(),
      isSearching: false,
      lyricSnippets: {
        for (final hit in lyricHits) hit.song.number: hit.snippet,
      },
    );
  }

  /// Re-runs the current filter against a changed song catalog.
  ///
  /// Wired to [songsProvider] from the provider body (see [searchProvider]).
  /// The results list is a snapshot, so without this an open search kept
  /// showing pre-edit tags — and a song that gained or lost the active tag
  /// never joined or left the list.
  ///
  /// The catalog merely *finishing its first load* is not a change: the
  /// [_recompute] that triggered it is already awaiting the same list, and
  /// recomputing here would publish a second, identical results list.
  Future<void> onCatalogUpdated(List<Song> songs) async {
    final previous = _catalog;
    _catalog = songs;
    if (previous == null || identical(previous, songs)) return;
    if (state.isFiltering) await _recompute();
  }

  void clear() {
    state = state.copyWith(
      query: '',
      results: [],
      isSearching: false,
      activeTags: {},
      lyricSnippets: const {},
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
  final notifier = SearchNotifier(ref);
  // Audit finding S9: results were computed with a one-shot `read` of
  // songsProvider, so a tag edit made elsewhere never reached an open search.
  // Listening here rather than watching inside the notifier keeps the
  // subscription tied to the provider's own lifecycle.
  ref.listen<AsyncValue<List<Song>>>(songsProvider, (previous, next) {
    if (next is AsyncData<List<Song>>) notifier.onCatalogUpdated(next.value);
  });
  return notifier;
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
