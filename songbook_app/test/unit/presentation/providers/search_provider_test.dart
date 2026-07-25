import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/search_provider.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';

Song song(int number, String title, {List<String> tags = const []}) => Song(
      number: number,
      title: title,
      originalKey: 'C',
      verses: const [],
      tags: tags,
    );

final testSongs = [
  song(1, 'Aki nem jár hitlenek tanácsán', tags: ['zsoltár']),
  song(42, 'Mint a szép híves patakra', tags: ['zsoltár']),
  song(151, 'Uram Isten, siess', tags: ['dicséret']),
];

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    songsProvider.overrideWith((ref) async => testSongs),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initial state', () {
    test('starts empty', () async {
      final container = await makeContainer();
      final state = container.read(searchProvider);
      expect(state.query, '');
      expect(state.results, isEmpty);
      expect(state.isSearching, isFalse);
      expect(state.recentSearches, isEmpty);
      expect(state.hasQuery, isFalse);
      expect(state.hasResults, isFalse);
    });
  });

  group('search', () {
    test('sets query and ranked results', () async {
      final container = await makeContainer();
      await container.read(searchProvider.notifier).search('uram');

      final state = container.read(searchProvider);
      expect(state.query, 'uram');
      expect(state.results.map((s) => s.number), [151]);
      expect(state.isSearching, isFalse);
      expect(state.hasQuery, isTrue);
      expect(state.hasResults, isTrue);

      expect(container.read(searchResultsProvider), state.results);
      expect(container.read(searchQueryProvider), 'uram');
    });

    test('exact number query returns that song only', () async {
      final container = await makeContainer();
      await container.read(searchProvider.notifier).search('42');
      expect(container.read(searchProvider).results.map((s) => s.number), [42]);
    });

    test('empty query clears results', () async {
      final container = await makeContainer();
      final notifier = container.read(searchProvider.notifier);
      await notifier.search('uram');
      await notifier.search('');

      final state = container.read(searchProvider);
      expect(state.query, '');
      expect(state.results, isEmpty);
      expect(state.isSearching, isFalse);
    });

    test('repeating the same query is a no-op', () async {
      final container = await makeContainer();
      final notifier = container.read(searchProvider.notifier);
      await notifier.search('uram');
      final before = container.read(searchProvider);
      await notifier.search('uram');
      expect(identical(container.read(searchProvider), before), isTrue);
    });

    test('non-matching query yields empty results', () async {
      final container = await makeContainer();
      await container.read(searchProvider.notifier).search('semmi');
      final state = container.read(searchProvider);
      expect(state.results, isEmpty);
      expect(state.hasResults, isFalse);
    });
  });

  group('clear', () {
    test('resets query and results but keeps recent searches', () async {
      final container = await makeContainer();
      final notifier = container.read(searchProvider.notifier);
      await notifier.search('uram');
      notifier.addToRecentSearches('uram');

      notifier.clear();

      final state = container.read(searchProvider);
      expect(state.query, '');
      expect(state.results, isEmpty);
      expect(state.recentSearches, ['uram']);
    });
  });

  group('recent searches', () {
    test('inserts at the front', () async {
      final container = await makeContainer();
      final notifier = container.read(searchProvider.notifier);
      notifier.addToRecentSearches('first');
      notifier.addToRecentSearches('second');
      expect(container.read(searchProvider).recentSearches,
          ['second', 'first']);
    });

    test('moves an existing entry to the front instead of duplicating',
        () async {
      final container = await makeContainer();
      final notifier = container.read(searchProvider.notifier);
      notifier.addToRecentSearches('a');
      notifier.addToRecentSearches('b');
      notifier.addToRecentSearches('a');
      expect(container.read(searchProvider).recentSearches, ['a', 'b']);
    });

    test('ignores empty queries', () async {
      final container = await makeContainer();
      container.read(searchProvider.notifier).addToRecentSearches('');
      expect(container.read(searchProvider).recentSearches, isEmpty);
    });

    test('keeps at most 10 entries', () async {
      final container = await makeContainer();
      final notifier = container.read(searchProvider.notifier);
      for (var i = 1; i <= 12; i++) {
        notifier.addToRecentSearches('query$i');
      }
      final recent = container.read(searchProvider).recentSearches;
      expect(recent, hasLength(10));
      expect(recent.first, 'query12');
      expect(recent, isNot(contains('query1')));
      expect(recent, isNot(contains('query2')));
    });

    test('clearRecentSearches empties the list', () async {
      final container = await makeContainer();
      final notifier = container.read(searchProvider.notifier);
      notifier.addToRecentSearches('x');
      notifier.clearRecentSearches();
      expect(container.read(searchProvider).recentSearches, isEmpty);
    });
  });

  group('allTagsProvider', () {
    test('collects lowercased unique tags from all songs', () async {
      final container = await makeContainer();
      final tags = await container.read(allTagsProvider.future);
      expect(tags, {'zsoltár', 'dicséret'});
    });
  });

  group('SearchState.copyWith', () {
    test('overrides fields independently', () {
      const state = SearchState();
      expect(state.copyWith(query: 'q').query, 'q');
      expect(state.copyWith(query: 'q').results, isEmpty);
      expect(state.copyWith(isSearching: true).isSearching, isTrue);
      expect(state.copyWith(recentSearches: ['r']).recentSearches, ['r']);
    });
  });
}
