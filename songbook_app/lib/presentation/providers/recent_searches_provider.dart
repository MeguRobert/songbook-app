import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Search queries the user has actually used, most recent first.
///
/// Replaces the recently-*viewed* rail. That rail cost a row of vertical space on
/// every visit to the busiest screen in the app, to answer a question the sorted
/// list mostly answers by itself. Retyping a query is the genuinely tedious part,
/// and it is only ever wanted at one moment — the search field open and empty —
/// where nothing was being offered at all.
///
/// A query is recorded when the user opens a result, not on every keystroke: the
/// field searches as you type, so keystroke-recording would fill the history with
/// prefixes of a single word.
class RecentSearchesNotifier extends StateNotifier<List<String>> {
  final Ref _ref;

  RecentSearchesNotifier(this._ref)
      : super(_ref.read(localDataSourceProvider).getRecentSearches());

  Future<void> record(String query) async {
    await _ref.read(localDataSourceProvider).recordRecentSearch(query);
    state = _ref.read(localDataSourceProvider).getRecentSearches();
  }

  Future<void> clear() async {
    await _ref.read(localDataSourceProvider).clearRecentSearches();
    state = const [];
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier(ref);
});
