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
}
