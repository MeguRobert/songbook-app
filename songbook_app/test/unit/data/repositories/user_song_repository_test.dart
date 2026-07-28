import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/data/models/view_config.dart';
import 'package:songbook_app/data/repositories/settings_repository.dart';
import 'package:songbook_app/data/repositories/user_song_repository.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';

Song draft({
  String title = 'Az Úrra bízom életem',
  int number = 1,
  String? book = 'Saját énekek',
}) =>
    Song(
      number: number,
      title: title,
      originalKey: 'G',
      book: book,
      verses: const [
        Verse(
          number: 1,
          lines: [
            LyricLine(
              text: 'Az Úrra bízom életem',
              chords: [
                ChordPosition(chord: 'G', position: 0),
                ChordPosition(chord: 'C', position: 8),
              ],
            ),
          ],
        ),
      ],
      tags: const ['bizalom'],
    );

Future<UserSongRepository> makeRepository([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final dataSource = LocalDataSource(await SharedPreferences.getInstance());
  return UserSongRepository(dataSource, SettingsRepository(dataSource));
}

void main() {
  group('storage', () {
    test('add assigns an id and returns the stored song', () async {
      final repo = await makeRepository();
      final stored = await repo.add(draft());

      expect(stored.explicitId, isNotNull);
      expect(stored.id.source, SongSource.user);
      // The bundled catalogue derives its id from the number; a user song must
      // not, or it would collide with the hymnal song of the same number.
      expect(stored.id, isNot(const SongId.hymnal(1)));
    });

    test('survives a round-trip with verses, chords and tags', () async {
      final repo = await makeRepository();
      final stored = await repo.add(draft());

      final reloaded = repo.getById(stored.id);
      expect(reloaded, isNotNull);
      expect(reloaded, stored); // value equality over every field
      expect(reloaded!.verses.single.lines.single.chords,
          const [ChordPosition(chord: 'G', position: 0),
                 ChordPosition(chord: 'C', position: 8)]);
      expect(reloaded.tags, ['bizalom']);
      expect(reloaded.book, 'Saját énekek');
    });

    test('two user songs may share a number in different books', () async {
      final repo = await makeRepository();
      final a = await repo.add(draft(title: 'Első', book: 'Saját énekek'));
      final b = await repo.add(draft(title: 'Másik', book: 'Ifjúsági'));

      // Same number, different books, different identities. This is the case
      // that a number-based identity could not represent.
      expect(a.number, b.number);
      expect(a.id, isNot(b.id));
      expect(repo.getAll(), hasLength(2));
    });

    test('adding the same song twice replaces rather than duplicates',
        () async {
      final repo = await makeRepository();
      final stored = await repo.add(draft());
      await repo.update(stored.copyWith(title: 'Javított cím'));

      expect(repo.getAll(), hasLength(1));
      expect(repo.getById(stored.id)!.title, 'Javított cím');
    });

    test('delete removes only the targeted song', () async {
      final repo = await makeRepository();
      final a = await repo.add(draft(title: 'Egy'));
      final b = await repo.add(draft(title: 'Kettő'));

      expect(await repo.delete(a.id), isTrue);
      expect(repo.getAll().map((s) => s.title), ['Kettő']);
      expect(repo.getById(b.id), isNotNull);
      // Deleting something absent is a no-op, not an error.
      expect(await repo.delete(a.id), isFalse);
    });

    test('one unreadable record does not take the collection with it',
        () async {
      // Mirrors _decodeRecords' per-record tolerance: a corrupt entry must not
      // make every other user song vanish.
      final repo = await makeRepository({
        'user_songs': '[{"nonsense": true}, '
            '{"number":1,"title":"Ép","originalKey":"G","verses":[],'
            '"id":"user:abc"}]',
      });
      expect(repo.getAll().map((s) => s.title), ['Ép']);
    });
  });

  group('merged into the catalogue', () {
    test('a user song appears in songsProvider alongside bundled ones',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final before = await container.read(songsProvider.future);
      expect(before.any((s) => s.id.isUserSong), isFalse);

      final stored =
          await container.read(userSongsProvider.notifier).add(draft());

      // The provider must republish: storage is not reactive, so without that
      // the song saves and simply never shows up.
      final after = await container.read(songsProvider.future);
      expect(after, hasLength(before.length + 1));
      expect(after.map((s) => s.id), contains(stored.id));

      // Bundled songs are untouched and still come first.
      expect(after.take(before.length).map((s) => s.id),
          before.map((s) => s.id));
    });

    test('a user song is addressable by songByIdProvider', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final stored =
          await container.read(userSongsProvider.notifier).add(draft());
      final found =
          await container.read(songByIdProvider(stored.id).future);

      expect(found?.title, 'Az Úrra bízom életem');
    });

    test('removing a user song drops it from the catalogue', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userSongsProvider.notifier);
      final stored = await notifier.add(draft());
      expect((await container.read(songsProvider.future)).map((s) => s.id),
          contains(stored.id));

      await notifier.remove(stored.id);
      expect((await container.read(songsProvider.future)).map((s) => s.id),
          isNot(contains(stored.id)));
    });
  });

  group('view preference', () {
    test('an imported song opens in chord view, not on the sheet-music '
        'placeholder', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = LocalDataSource(prefs);
      final settings = SettingsRepository(dataSource);
      final repo = UserSongRepository(dataSource, settings);

      final stored = await repo.add(draft());

      // The global default is sheet music and an imported song has none, so
      // without a per-song override every one lands on "no sheet music
      // available". Stored as an override, so the controls sheet reflects it
      // too rather than highlighting a preset that is not in effect.
      expect(settings.getSongViewConfig(stored.id), const ViewConfig.chords());
    });
  });
}
