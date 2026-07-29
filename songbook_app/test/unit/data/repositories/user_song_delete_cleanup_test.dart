import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/data/models/view_config.dart';
import 'package:songbook_app/presentation/providers/favorites_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/setlist_provider.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/providers/tag_provider.dart';

/// What deleting a user song has to take with it.
///
/// A user song's [SongId] carries a timestamp and six random digits, so it is
/// never reissued. Every reference left behind therefore points at something
/// that can never resolve again: favourites, setlists and the tag browser all
/// skip ids they cannot find, so the leftovers are invisible — and permanent.
/// The per-song view config is the sharpest case, because `add` writes it itself.
///
/// In-memory state matters as much as storage here. Each of these collections is
/// a notifier that loaded once at startup; clearing the stored record without
/// telling the notifier leaves the favourite heart still filled.

Song draft({String title = 'Az Úrra bízom életem'}) => Song(
      number: 1,
      title: title,
      originalKey: 'G',
      book: 'Saját énekek',
      verses: const [
        Verse(number: 1, lines: [LyricLine(text: 'Az Úrra bízom életem')]),
      ],
    );

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('clears the per-song view config that add() wrote', () async {
    final container = await makeContainer();
    final stored = await container.read(userSongsProvider.notifier).add(draft());
    final settings = container.read(settingsRepositoryProvider);
    expect(settings.getSongViewConfig(stored.id), const ViewConfig.chords());

    await container.read(userSongsProvider.notifier).remove(stored.id);

    expect(settings.getSongViewConfig(stored.id), isNull);
  });

  test('clears a per-song auto-scroll speed', () async {
    final container = await makeContainer();
    final stored = await container.read(userSongsProvider.notifier).add(draft());
    final settings = container.read(settingsRepositoryProvider);
    await settings.setAutoScrollSpeed(stored.id, 90);

    await container.read(userSongsProvider.notifier).remove(stored.id);

    expect(settings.getAutoScrollSpeed(stored.id), 40); // back to the default
  });

  test('drops the favourite, in storage and on screen', () async {
    final container = await makeContainer();
    final stored = await container.read(userSongsProvider.notifier).add(draft());
    await container.read(favoritesProvider.notifier).addFavorite(stored.id);
    expect(container.read(isFavoriteProvider(stored.id)), isTrue);

    await container.read(userSongsProvider.notifier).remove(stored.id);

    expect(container.read(favoritesRepositoryProvider).getFavoriteSongIds(),
        isEmpty);
    // The notifier loaded its state once at startup: clearing storage alone
    // would leave the heart filled.
    expect(container.read(isFavoriteProvider(stored.id)), isFalse);
  });

  test('drops the song from every setlist that held it', () async {
    final container = await makeContainer();
    final stored = await container.read(userSongsProvider.notifier).add(draft());
    final setlists = container.read(setlistsProvider.notifier);
    final morning = await setlists.create('Vasárnap délelőtt');
    final evening = await setlists.create('Vasárnap este');
    await setlists.addSong(morning.id, stored.id);
    await setlists.addSong(evening.id, stored.id);
    await setlists.addSong(evening.id, const SongId.hymnal(151));

    await container.read(userSongsProvider.notifier).remove(stored.id);

    final stateAfter = container.read(setlistsProvider);
    expect(stateAfter.firstWhere((s) => s.id == morning.id).songIds, isEmpty);
    // The hymnal song beside it is untouched.
    expect(stateAfter.firstWhere((s) => s.id == evening.id).songIds,
        [const SongId.hymnal(151)]);
  });

  test('clears its tag override', () async {
    final container = await makeContainer();
    final stored = await container.read(userSongsProvider.notifier).add(draft());
    await container
        .read(tagOverridesProvider.notifier)
        .setTags(stored.id, ['bizalom']);

    await container.read(userSongsProvider.notifier).remove(stored.id);

    expect(container.read(tagRepositoryProvider).getOverrides(), isEmpty);
    expect(container.read(tagOverridesProvider), isEmpty);
  });

  test('leaves another user song and its references alone', () async {
    final container = await makeContainer();
    final notifier = container.read(userSongsProvider.notifier);
    final doomed = await notifier.add(draft(title: 'Törlendő'));
    final keeper = await notifier.add(draft(title: 'Megtartandó'));
    await container.read(favoritesProvider.notifier).addFavorite(keeper.id);

    await notifier.remove(doomed.id);

    expect(container.read(userSongsProvider).map((s) => s.title),
        ['Megtartandó']);
    expect(container.read(isFavoriteProvider(keeper.id)), isTrue);
    expect(
        container.read(settingsRepositoryProvider).getSongViewConfig(keeper.id),
        const ViewConfig.chords());
  });
}
