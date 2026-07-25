import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/data/repositories/song_repository.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/search_provider.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/providers/tag_provider.dart';

Song song(int number, String title, {List<String> tags = const []}) => Song(
      number: number,
      title: title,
      originalKey: 'C',
      verses: const [],
      tags: tags,
    );

final fixtureSongs = [
  song(1, 'Advent Praise', tags: ['praise', 'advent']),
  song(2, 'Morning Praise', tags: ['praise']),
  song(3, 'Communion Hymn', tags: ['advent', 'communion']),
];

Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      songsProvider.overrideWith((ref) async => fixtureSongs),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggleTag adds then removes a tag', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(searchProvider.notifier);

    await notifier.toggleTag('praise');
    expect(container.read(searchProvider).activeTags, {'praise'});

    await notifier.toggleTag('praise');
    expect(container.read(searchProvider).activeTags, isEmpty);
  });

  test('tag-only filter (empty query) returns songs carrying the tag', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);

    await container.read(searchProvider.notifier).toggleTag('praise');

    final results = container.read(searchProvider).results;
    expect(results.map((s) => s.number), equals([1, 2]));
  });

  test('two tags use AND semantics', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(searchProvider.notifier);

    await notifier.toggleTag('praise');
    await notifier.toggleTag('advent');

    final results = container.read(searchProvider).results;
    expect(results.map((s) => s.number), equals([1]));
  });

  test('query narrows within the tag-filtered set', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(searchProvider.notifier);

    await notifier.toggleTag('advent'); // songs 1 and 3
    await notifier.search('communion'); // title match within those

    final results = container.read(searchProvider).results;
    expect(results.map((s) => s.number), equals([3]));
  });

  test('clearTags resets the filter and results', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(searchProvider.notifier);

    await notifier.toggleTag('praise');
    await notifier.clearTags();

    final state = container.read(searchProvider);
    expect(state.activeTags, isEmpty);
    expect(state.results, isEmpty); // no query + no tags → nothing to show
  });

  test('clear() resets query and tags', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(searchProvider.notifier);

    await notifier.toggleTag('praise');
    await notifier.search('praise');
    notifier.clear();

    final state = container.read(searchProvider);
    expect(state.query, '');
    expect(state.activeTags, isEmpty);
    expect(state.results, isEmpty);
  });

  // Audit finding S9. The results list is a snapshot taken when the filter last
  // ran; editing a song's tags from another screen has to push a new snapshot,
  // or an open search keeps showing the pre-edit answer.
  group('results follow tag edits', () {
    /// Container whose songsProvider is the REAL one, so a tag override
    /// actually invalidates it (the fixture-override container cannot).
    Future<ProviderContainer> makeLiveContainer() async {
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          songRepositoryProvider.overrideWith(
            (ref) => _FakeSongRepository(LocalDataSource(prefs), fixtureSongs),
          ),
        ],
      );
    }

    /// Lets songsProvider rebuild and the search recompute settle.
    Future<void> settle(ProviderContainer container) async {
      await container.read(songsProvider.future);
      await Future<void>.delayed(Duration.zero);
    }

    test('a song gaining the active tag joins the open result list', () async {
      final container = await makeLiveContainer();
      addTearDown(container.dispose);

      await container.read(searchProvider.notifier).toggleTag('praise');
      expect(container.read(searchProvider).results.map((s) => s.number),
          equals([1, 2]));

      await container
          .read(tagOverridesProvider.notifier)
          .setTags(3, ['communion', 'praise']);
      await settle(container);

      expect(container.read(searchProvider).results.map((s) => s.number),
          equals([1, 2, 3]));
    });

    test('a song losing the active tag leaves the open result list', () async {
      final container = await makeLiveContainer();
      addTearDown(container.dispose);

      await container.read(searchProvider.notifier).toggleTag('praise');
      expect(container.read(searchProvider).results.map((s) => s.number),
          equals([1, 2]));

      await container.read(tagOverridesProvider.notifier).setTags(2, []);
      await settle(container);

      expect(container.read(searchProvider).results.map((s) => s.number),
          equals([1]));
    });

    test('a text-query result set picks up edited tags', () async {
      final container = await makeLiveContainer();
      addTearDown(container.dispose);

      await container.read(searchProvider.notifier).search('praise');
      expect(container.read(searchProvider).results.map((s) => s.number),
          equals([1, 2]));

      await container
          .read(tagOverridesProvider.notifier)
          .setTags(1, ['renamed']);
      await settle(container);

      // Song 1 still matches on its title ("Advent Praise") — it just carries
      // the edited tags now, and ranks below song 2 having lost the tag match.
      final results = container.read(searchProvider).results;
      final songOne = results.firstWhere((s) => s.number == 1);
      expect(songOne.tags, equals(['renamed']));
    });
  });

  group('lyrics fallback', _lyricsFallbackTests);
}

/// Falls back to scanning lyrics only when nothing matched on metadata, so a
/// common word in a verse cannot outrank a real title hit.
void _lyricsFallbackTests() {
  Song withLyrics(int number, String title, List<String> lines) => Song(
        number: number,
        title: title,
        originalKey: 'C',
        verses: [
          Verse(number: 1, lines: [for (final t in lines) LyricLine(text: t)]),
        ],
      );

  final catalog = [
    withLyrics(1, 'Szent Isten, kit a seregek', ['dicsérnek szüntelen']),
    withLyrics(42, 'Mint a szép híves patakra', ['a szarvas kívánkozik']),
  ];

  Future<ProviderContainer> container() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        songsProvider.overrideWith((ref) async => catalog),
      ],
    );
  }

  test('a lyrics-only phrase finds the song and carries a snippet', () async {
    final c = await container();
    addTearDown(c.dispose);

    await c.read(searchProvider.notifier).search('szarvas');

    final state = c.read(searchProvider);
    expect(state.results.map((s) => s.number), [42]);
    expect(state.lyricSnippets[42], contains('szarvas'));
    expect(state.matchedLyricsOnly, isTrue);
  });

  test('a title match wins and never triggers the lyrics scan', () async {
    final c = await container();
    addTearDown(c.dispose);

    await c.read(searchProvider.notifier).search('patakra');

    final state = c.read(searchProvider);
    expect(state.results.map((s) => s.number), [42]);
    expect(state.lyricSnippets, isEmpty);
    expect(state.matchedLyricsOnly, isFalse);
  });

  test('snippets are cleared when the query changes to a title match',
      () async {
    final c = await container();
    addTearDown(c.dispose);
    final notifier = c.read(searchProvider.notifier);

    await notifier.search('szarvas');
    expect(c.read(searchProvider).lyricSnippets, isNotEmpty);

    await notifier.search('patakra');
    expect(c.read(searchProvider).lyricSnippets, isEmpty);
  });

  test('genuinely absent text still yields no results', () async {
    final c = await container();
    addTearDown(c.dispose);

    await c.read(searchProvider.notifier).search('villamos');

    final state = c.read(searchProvider);
    expect(state.results, isEmpty);
    expect(state.lyricSnippets, isEmpty);
  });

  test('the lyrics scan stays inside the active tag filter', () async {
    final tagged = [
      Song(
        number: 5,
        title: 'Tagged',
        originalKey: 'C',
        tags: const ['advent'],
        verses: const [
          Verse(number: 1, plainText: 'a szarvas fut'),
        ],
      ),
      Song(
        number: 6,
        title: 'Untagged',
        originalKey: 'C',
        verses: const [
          Verse(number: 1, plainText: 'a szarvas fut'),
        ],
      ),
    ];
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      songsProvider.overrideWith((ref) async => tagged),
    ]);
    addTearDown(c.dispose);
    final notifier = c.read(searchProvider.notifier);

    await notifier.toggleTag('advent');
    await notifier.search('szarvas');

    expect(c.read(searchProvider).results.map((s) => s.number), [5]);
  });

  test('clear() drops snippets along with the query', () async {
    final c = await container();
    addTearDown(c.dispose);
    final notifier = c.read(searchProvider.notifier);

    await notifier.search('szarvas');
    notifier.clear();

    expect(c.read(searchProvider).lyricSnippets, isEmpty);
  });
}

/// Minimal SongRepository stand-in returning a fixed list (avoids loading the
/// bundled asset and lets songsProvider exercise the override merge).
class _FakeSongRepository extends SongRepository {
  final List<Song> _songs;
  _FakeSongRepository(super.localDataSource, this._songs);

  @override
  Future<List<Song>> getAllSongs() async => _songs;
}
