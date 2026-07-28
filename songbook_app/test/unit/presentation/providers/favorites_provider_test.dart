import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/presentation/providers/favorites_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';

String favoritesJson(List<int> numbers) => json.encode([
      for (var i = 0; i < numbers.length; i++)
        {
          'songId': SongId.hymnal(numbers[i]).value,
          'addedAt': '2026-01-01T00:00:00.000',
          'sortOrder': i,
        },
    ]);

Song song(int number) =>
    Song(number: number, title: 'Song $number', originalKey: 'C', verses: const []);

Future<ProviderContainer> makeContainer({
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initial load', () {
    test('starts empty when nothing is stored', () async {
      final container = await makeContainer();
      final state = container.read(favoritesProvider);
      expect(state.favoriteSongIds, isEmpty);
      expect(state.count, 0);
      expect(state.isLoading, isFalse);
    });

    test('loads persisted favorites', () async {
      final container = await makeContainer(
          prefs: {'favorites': favoritesJson([42, 7])});
      final state = container.read(favoritesProvider);
      expect(state.favoriteSongIds,
          {const SongId.hymnal(42), const SongId.hymnal(7)});
      expect(state.isFavorite(const SongId.hymnal(42)), isTrue);
      expect(state.isFavorite(const SongId.hymnal(1)), isFalse);
    });
  });

  group('toggleFavorite', () {
    test('adds a non-favorite and persists it', () async {
      final container = await makeContainer();
      await container
          .read(favoritesProvider.notifier)
          .toggleFavorite(const SongId.hymnal(5));

      expect(
          container.read(favoritesProvider).isFavorite(const SongId.hymnal(5)),
          isTrue);
      final raw =
          container.read(sharedPreferencesProvider).getString('favorites');
      expect(raw, contains('"songId":"hymnal:5"'));
    });

    test('removes an existing favorite and persists the removal', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([5])});
      await container
          .read(favoritesProvider.notifier)
          .toggleFavorite(const SongId.hymnal(5));

      expect(
          container.read(favoritesProvider).isFavorite(const SongId.hymnal(5)),
          isFalse);
      final raw =
          container.read(sharedPreferencesProvider).getString('favorites');
      expect(raw, isNot(contains('"songId":"hymnal:5"')));
    });

    test('clears isLoading when done', () async {
      final container = await makeContainer();
      await container
          .read(favoritesProvider.notifier)
          .toggleFavorite(const SongId.hymnal(5));
      expect(container.read(favoritesProvider).isLoading, isFalse);
    });
  });

  group('addFavorite', () {
    test('adds and persists', () async {
      final container = await makeContainer();
      await container
          .read(favoritesProvider.notifier)
          .addFavorite(const SongId.hymnal(9));
      expect(container.read(favoritesProvider).favoriteSongIds,
          {const SongId.hymnal(9)});
    });

    test('is a no-op when already a favorite', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([9])});
      await container
          .read(favoritesProvider.notifier)
          .addFavorite(const SongId.hymnal(9));
      expect(container.read(favoritesProvider).favoriteSongIds,
          {const SongId.hymnal(9)});
      expect(container.read(favoritesProvider).count, 1);
    });
  });

  group('removeFavorite', () {
    test('removes and persists', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([9, 10])});
      await container
          .read(favoritesProvider.notifier)
          .removeFavorite(const SongId.hymnal(9));
      expect(container.read(favoritesProvider).favoriteSongIds,
          {const SongId.hymnal(10)});
    });

    test('is a no-op when not a favorite', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([10])});
      await container
          .read(favoritesProvider.notifier)
          .removeFavorite(const SongId.hymnal(9));
      expect(container.read(favoritesProvider).favoriteSongIds,
          {const SongId.hymnal(10)});
    });
  });

  group('refresh', () {
    test('reloads state from the repository', () async {
      final container = await makeContainer();
      // Instantiate the notifier first (providers are created lazily).
      expect(
          container.read(favoritesProvider).isFavorite(const SongId.hymnal(77)),
          isFalse);

      // Write directly through the datasource, bypassing the notifier.
      final dataSource = container.read(localDataSourceProvider);
      await dataSource.addFavorite(const SongId.hymnal(77));
      expect(
          container.read(favoritesProvider).isFavorite(const SongId.hymnal(77)),
          isFalse,
          reason: 'notifier state is stale until refresh');

      container.read(favoritesProvider.notifier).refresh();
      expect(
          container.read(favoritesProvider).isFavorite(const SongId.hymnal(77)),
          isTrue);
    });
  });

  group('derived providers', () {
    test('isFavoriteProvider reflects membership per song', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([3])});
      expect(
          container.read(isFavoriteProvider(const SongId.hymnal(3))), isTrue);
      expect(
          container.read(isFavoriteProvider(const SongId.hymnal(4))), isFalse);

      await container
          .read(favoritesProvider.notifier)
          .addFavorite(const SongId.hymnal(4));
      expect(
          container.read(isFavoriteProvider(const SongId.hymnal(4))), isTrue);
    });

    test('favoriteSongsProvider filters the song list', () async {
      final container = await makeContainer(
        prefs: {'favorites': favoritesJson([2, 3])},
        overrides: [
          songsProvider.overrideWith((ref) async => [song(1), song(2), song(3)]),
        ],
      );
      final favoriteSongs = await container.read(favoriteSongsProvider.future);
      expect(favoriteSongs.map((s) => s.number), [2, 3]);
    });
  });

  group('FavoritesState', () {
    test('copyWith overrides fields independently', () {
      // Built at runtime, not `const`: a const set may not hold values that
      // override `==`, which SongId does.
      final state = FavoritesState(favoriteSongIds: {const SongId.hymnal(1)});
      expect(state.copyWith(isLoading: true).isLoading, isTrue);
      expect(state.copyWith(isLoading: true).favoriteSongIds,
          {const SongId.hymnal(1)});
      expect(
          state
              .copyWith(favoriteSongIds: {const SongId.hymnal(2)})
              .favoriteSongIds,
          {const SongId.hymnal(2)});
    });
  });

  test('disposing the container after a toggle does not throw', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ]);
    await container
        .read(favoritesProvider.notifier)
        .toggleFavorite(const SongId.hymnal(1));
    expect(container.dispose, returnsNormally);
  });

  // The Set answers "is this a favourite?" but cannot carry order, so display
  // order lives in a parallel list. Every mutation must keep the two in step —
  // updating only the Set left the Favorites screen showing nothing.
  group('display order', () {
    test('ordered list follows sortOrder and stays in step with the set',
        () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([42, 7])});
      final notifier = container.read(favoritesProvider.notifier);

      expect(container.read(favoritesProvider).orderedSongIds,
          const [SongId.hymnal(42), SongId.hymnal(7)]);

      await notifier.toggleFavorite(const SongId.hymnal(1));
      final afterAdd = container.read(favoritesProvider);
      expect(afterAdd.favoriteSongIds, {
        const SongId.hymnal(42),
        const SongId.hymnal(7),
        const SongId.hymnal(1),
      });
      expect(afterAdd.orderedSongIds.toSet(), {
        const SongId.hymnal(42),
        const SongId.hymnal(7),
        const SongId.hymnal(1),
      });

      await notifier.toggleFavorite(const SongId.hymnal(7));
      final afterRemove = container.read(favoritesProvider);
      expect(afterRemove.favoriteSongIds,
          {const SongId.hymnal(42), const SongId.hymnal(1)});
      expect(afterRemove.orderedSongIds.toSet(),
          {const SongId.hymnal(42), const SongId.hymnal(1)});
    });

    test('reorder persists the new order', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([42, 7, 1])});
      final notifier = container.read(favoritesProvider.notifier);

      await notifier.reorder(
        const [SongId.hymnal(1), SongId.hymnal(42), SongId.hymnal(7)],
      );
      expect(container.read(favoritesProvider).orderedSongIds,
          const [SongId.hymnal(1), SongId.hymnal(42), SongId.hymnal(7)]);

      // Survives a fresh notifier reading the same storage.
      final reread = container.read(favoritesRepositoryProvider);
      expect(reread.getFavoriteSongIds(),
          const [SongId.hymnal(1), SongId.hymnal(42), SongId.hymnal(7)]);
    });
  });
}
