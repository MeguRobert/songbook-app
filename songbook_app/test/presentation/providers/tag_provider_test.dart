import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/repositories/song_repository.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/providers/tag_provider.dart';

Song song(int number, {List<String> tags = const []}) => Song(
      number: number,
      title: 'Song $number',
      originalKey: 'C',
      verses: const [],
      tags: tags,
    );

final fixtureSongs = [
  song(1, tags: ['praise', 'advent']),
  song(2, tags: ['praise']),
  song(3, tags: ['communion']),
];

Future<ProviderContainer> makeContainer() async {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('tagsProvider', () {
    test('derives counts from the effective songs', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final tags = await container.read(tagsProvider.future);
      expect(tags.first.name, 'praise');
      expect(tags.first.songCount, 2);
      expect(tags.map((t) => t.name),
          containsAll(['praise', 'advent', 'communion']));
    });
  });

  group('tagOverridesProvider', () {
    test('setTags updates state and re-emits songs with edited tags', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      // Prime songsProvider.
      await container.read(songsProvider.future);

      await container
          .read(tagOverridesProvider.notifier)
          .setTags(const SongId.hymnal(3), ['evening', 'communion']);

      expect(container.read(tagOverridesProvider)[const SongId.hymnal(3)],
          equals(['evening', 'communion']));

      final songs = await container.read(songsProvider.future);
      expect(songs.firstWhere((s) => s.number == 3).tags,
          equals(['evening', 'communion']));
    });

    test('addTag ignores blank and case-insensitive duplicate', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(tagOverridesProvider.notifier);
      await notifier
          .addTag(const SongId.hymnal(2), '  ', ['praise']); // blank
      expect(
          container
              .read(tagOverridesProvider)
              .containsKey(const SongId.hymnal(2)),
          isFalse);

      await notifier
          .addTag(const SongId.hymnal(2), 'PRAISE', ['praise']); // dup
      expect(
          container
              .read(tagOverridesProvider)
              .containsKey(const SongId.hymnal(2)),
          isFalse);

      await notifier.addTag(const SongId.hymnal(2), 'morning', ['praise']);
      expect(container.read(tagOverridesProvider)[const SongId.hymnal(2)],
          equals(['praise', 'morning']));
    });

    test('removeTag drops the tag (case-insensitive)', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container
          .read(tagOverridesProvider.notifier)
          .removeTag(const SongId.hymnal(1), 'ADVENT', ['praise', 'advent']);

      expect(container.read(tagOverridesProvider)[const SongId.hymnal(1)],
          equals(['praise']));
    });

    // setTags([]) means "this song has no tags" and must persist as an EMPTY
    // override. Routing it to clearOverride made the bundled tags reappear, so
    // a user could never remove a song's last tag. Reverting to bundled tags is
    // clearOverride's job ("Reset to default"), covered separately below.
    test('setTags([]) persists an empty override, it does not clear it',
        () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(tagOverridesProvider.notifier);
      await notifier.setTags(const SongId.hymnal(1), ['x']);
      expect(
          container
              .read(tagOverridesProvider)
              .containsKey(const SongId.hymnal(1)),
          isTrue);

      await notifier.setTags(const SongId.hymnal(1), []);
      expect(
          container
              .read(tagOverridesProvider)
              .containsKey(const SongId.hymnal(1)),
          isTrue);
      expect(container.read(tagOverridesProvider)[const SongId.hymnal(1)],
          isEmpty);
    });

    test('clearOverride reverts to the bundled tags', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(tagOverridesProvider.notifier);
      await notifier.setTags(const SongId.hymnal(1), ['x']);
      expect(
          container
              .read(tagOverridesProvider)
              .containsKey(const SongId.hymnal(1)),
          isTrue);

      await notifier.clearOverride(const SongId.hymnal(1));
      expect(
          container
              .read(tagOverridesProvider)
              .containsKey(const SongId.hymnal(1)),
          isFalse);
    });

    test('overrides seed from persistence on construction', () async {
      SharedPreferences.setMockInitialValues({
        'song_tag_overrides': '{"hymnal:5":["seeded"]}',
      });
      final container = await makeContainer();
      addTearDown(container.dispose);

      expect(container.read(tagOverridesProvider)[const SongId.hymnal(5)],
          equals(['seeded']));
    });

    // Upgrade path. Overrides written before song ids existed are keyed by a
    // bare song number; SongId.tryParse reads those as hymnal ids, so the
    // edits keep applying to the same songs after the upgrade.
    test('overrides stored under bare-number keys still apply to the song',
        () async {
      SharedPreferences.setMockInitialValues({
        'song_tag_overrides': '{"42":["advent"]}',
      });
      final prefs = await SharedPreferences.getInstance();
      final catalog = [...fixtureSongs, song(42, tags: ['praise'])];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          songRepositoryProvider.overrideWith(
            (ref) => _FakeSongRepository(LocalDataSource(prefs), catalog),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(tagOverridesProvider),
          {const SongId.hymnal(42): ['advent']});

      final songs = await container.read(songsProvider.future);
      expect(songs.firstWhere((s) => s.number == 42).tags, equals(['advent']));
    });
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
