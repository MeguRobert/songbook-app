import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/presentation/providers/favorites_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';

String favoritesJson(List<int> numbers) => json.encode([
      for (var i = 0; i < numbers.length; i++)
        {
          'songNumber': numbers[i],
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
      expect(state.favoriteSongNumbers, isEmpty);
      expect(state.count, 0);
      expect(state.isLoading, isFalse);
    });

    test('loads persisted favorites', () async {
      final container = await makeContainer(
          prefs: {'favorites': favoritesJson([42, 7])});
      final state = container.read(favoritesProvider);
      expect(state.favoriteSongNumbers, {42, 7});
      expect(state.isFavorite(42), isTrue);
      expect(state.isFavorite(1), isFalse);
    });
  });

  group('toggleFavorite', () {
    test('adds a non-favorite and persists it', () async {
      final container = await makeContainer();
      await container.read(favoritesProvider.notifier).toggleFavorite(5);

      expect(container.read(favoritesProvider).isFavorite(5), isTrue);
      final raw =
          container.read(sharedPreferencesProvider).getString('favorites');
      expect(raw, contains('"songNumber":5'));
    });

    test('removes an existing favorite and persists the removal', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([5])});
      await container.read(favoritesProvider.notifier).toggleFavorite(5);

      expect(container.read(favoritesProvider).isFavorite(5), isFalse);
      final raw =
          container.read(sharedPreferencesProvider).getString('favorites');
      expect(raw, isNot(contains('"songNumber":5')));
    });

    test('clears isLoading when done', () async {
      final container = await makeContainer();
      await container.read(favoritesProvider.notifier).toggleFavorite(5);
      expect(container.read(favoritesProvider).isLoading, isFalse);
    });
  });

  group('addFavorite', () {
    test('adds and persists', () async {
      final container = await makeContainer();
      await container.read(favoritesProvider.notifier).addFavorite(9);
      expect(container.read(favoritesProvider).favoriteSongNumbers, {9});
    });

    test('is a no-op when already a favorite', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([9])});
      await container.read(favoritesProvider.notifier).addFavorite(9);
      expect(container.read(favoritesProvider).favoriteSongNumbers, {9});
      expect(container.read(favoritesProvider).count, 1);
    });
  });

  group('removeFavorite', () {
    test('removes and persists', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([9, 10])});
      await container.read(favoritesProvider.notifier).removeFavorite(9);
      expect(container.read(favoritesProvider).favoriteSongNumbers, {10});
    });

    test('is a no-op when not a favorite', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([10])});
      await container.read(favoritesProvider.notifier).removeFavorite(9);
      expect(container.read(favoritesProvider).favoriteSongNumbers, {10});
    });
  });

  group('refresh', () {
    test('reloads state from the repository', () async {
      final container = await makeContainer();
      // Instantiate the notifier first (providers are created lazily).
      expect(container.read(favoritesProvider).isFavorite(77), isFalse);

      // Write directly through the datasource, bypassing the notifier.
      final dataSource = container.read(localDataSourceProvider);
      await dataSource.addFavorite(77);
      expect(container.read(favoritesProvider).isFavorite(77), isFalse,
          reason: 'notifier state is stale until refresh');

      container.read(favoritesProvider.notifier).refresh();
      expect(container.read(favoritesProvider).isFavorite(77), isTrue);
    });
  });

  group('derived providers', () {
    test('isFavoriteProvider reflects membership per song', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([3])});
      expect(container.read(isFavoriteProvider(3)), isTrue);
      expect(container.read(isFavoriteProvider(4)), isFalse);

      await container.read(favoritesProvider.notifier).addFavorite(4);
      expect(container.read(isFavoriteProvider(4)), isTrue);
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
      const state = FavoritesState(favoriteSongNumbers: {1});
      expect(state.copyWith(isLoading: true).isLoading, isTrue);
      expect(state.copyWith(isLoading: true).favoriteSongNumbers, {1});
      expect(state.copyWith(favoriteSongNumbers: {2}).favoriteSongNumbers, {2});
    });
  });

  test('disposing the container after a toggle does not throw', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ]);
    await container.read(favoritesProvider.notifier).toggleFavorite(1);
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

      expect(container.read(favoritesProvider).orderedSongNumbers, [42, 7]);

      await notifier.toggleFavorite(1);
      final afterAdd = container.read(favoritesProvider);
      expect(afterAdd.favoriteSongNumbers, {42, 7, 1});
      expect(afterAdd.orderedSongNumbers.toSet(), {42, 7, 1});

      await notifier.toggleFavorite(7);
      final afterRemove = container.read(favoritesProvider);
      expect(afterRemove.favoriteSongNumbers, {42, 1});
      expect(afterRemove.orderedSongNumbers.toSet(), {42, 1});
    });

    test('reorder persists the new order', () async {
      final container =
          await makeContainer(prefs: {'favorites': favoritesJson([42, 7, 1])});
      final notifier = container.read(favoritesProvider.notifier);

      await notifier.reorder([1, 42, 7]);
      expect(container.read(favoritesProvider).orderedSongNumbers, [1, 42, 7]);

      // Survives a fresh notifier reading the same storage.
      final reread = container.read(favoritesRepositoryProvider);
      expect(reread.getFavoriteSongNumbers(), [1, 42, 7]);
    });
  });
}
