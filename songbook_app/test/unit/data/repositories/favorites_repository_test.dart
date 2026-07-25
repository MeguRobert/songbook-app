import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/favorite.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/repositories/favorites_repository.dart';

class MockLocalDataSource extends Mock implements LocalDataSource {}

Favorite fav(int number, {int sortOrder = 0}) =>
    Favorite(songNumber: number, addedAt: DateTime(2026), sortOrder: sortOrder);

Song song(int number) =>
    Song(number: number, title: 'Song $number', originalKey: 'C', verses: const []);

void main() {
  late MockLocalDataSource dataSource;
  late FavoritesRepository repository;

  setUp(() {
    dataSource = MockLocalDataSource();
    repository = FavoritesRepository(dataSource);
  });

  setUpAll(() {
    registerFallbackValue(<Favorite>[]);
  });

  group('getFavorites / getFavoriteSongNumbers / favoriteCount', () {
    test('delegate to the data source', () {
      final favorites = [fav(1), fav(2, sortOrder: 1)];
      when(() => dataSource.getFavorites()).thenReturn(favorites);

      expect(repository.getFavorites(), favorites);
      expect(repository.getFavoriteSongNumbers(), [1, 2]);
      expect(repository.favoriteCount, 2);
    });

    test('empty data source yields empty results', () {
      when(() => dataSource.getFavorites()).thenReturn([]);
      expect(repository.getFavorites(), isEmpty);
      expect(repository.getFavoriteSongNumbers(), isEmpty);
      expect(repository.favoriteCount, 0);
    });
  });

  group('add / remove / isFavorite', () {
    test('addFavorite delegates', () async {
      when(() => dataSource.addFavorite(5)).thenAnswer((_) async => true);
      expect(await repository.addFavorite(5), isTrue);
      verify(() => dataSource.addFavorite(5)).called(1);
    });

    test('removeFavorite delegates', () async {
      when(() => dataSource.removeFavorite(5)).thenAnswer((_) async => true);
      expect(await repository.removeFavorite(5), isTrue);
      verify(() => dataSource.removeFavorite(5)).called(1);
    });

    test('isFavorite delegates', () {
      when(() => dataSource.isFavorite(5)).thenReturn(true);
      when(() => dataSource.isFavorite(6)).thenReturn(false);
      expect(repository.isFavorite(5), isTrue);
      expect(repository.isFavorite(6), isFalse);
    });
  });

  group('toggleFavorite', () {
    test('removes when already a favorite', () async {
      when(() => dataSource.isFavorite(5)).thenReturn(true);
      when(() => dataSource.removeFavorite(5)).thenAnswer((_) async => true);

      await repository.toggleFavorite(5);

      verify(() => dataSource.removeFavorite(5)).called(1);
      verifyNever(() => dataSource.addFavorite(any()));
    });

    test('adds when not a favorite', () async {
      when(() => dataSource.isFavorite(5)).thenReturn(false);
      when(() => dataSource.addFavorite(5)).thenAnswer((_) async => true);

      await repository.toggleFavorite(5);

      verify(() => dataSource.addFavorite(5)).called(1);
      verifyNever(() => dataSource.removeFavorite(any()));
    });
  });

  group('reorderFavorites', () {
    test('re-assigns sortOrder to match the given order', () async {
      when(() => dataSource.getFavorites())
          .thenReturn([fav(1, sortOrder: 0), fav(2, sortOrder: 1), fav(3, sortOrder: 2)]);
      when(() => dataSource.saveFavorites(any())).thenAnswer((_) async => true);

      await repository.reorderFavorites([3, 1, 2]);

      final saved = verify(() => dataSource.saveFavorites(captureAny()))
          .captured.single as List<Favorite>;
      expect(saved.map((f) => f.songNumber), [3, 1, 2]);
      expect(saved.map((f) => f.sortOrder), [0, 1, 2]);
    });

    test('creates a new entry for an unknown song number', () async {
      when(() => dataSource.getFavorites()).thenReturn([fav(1)]);
      when(() => dataSource.saveFavorites(any())).thenAnswer((_) async => true);

      await repository.reorderFavorites([1, 99]);

      final saved = verify(() => dataSource.saveFavorites(captureAny()))
          .captured.single as List<Favorite>;
      expect(saved.map((f) => f.songNumber), [1, 99]);
      expect(saved.map((f) => f.sortOrder), [0, 1]);
    });
  });

  group('getFavoriteSongs', () {
    test('returns songs in sortOrder, skipping unloadable numbers', () async {
      when(() => dataSource.getFavorites()).thenReturn([
        fav(10, sortOrder: 2),
        fav(20, sortOrder: 0),
        fav(30, sortOrder: 1),
      ]);

      final result = await repository.getFavoriteSongs((numbers) async {
        // Loader returns songs out of order and misses 30.
        expect(numbers, [20, 30, 10]);
        return [song(10), song(20)];
      });

      expect(result.map((s) => s.number), [20, 10]);
    });

    test('returns empty list without calling the loader when no favorites',
        () async {
      when(() => dataSource.getFavorites()).thenReturn([]);
      var loaderCalled = false;

      final result = await repository.getFavoriteSongs((numbers) async {
        loaderCalled = true;
        return [];
      });

      expect(result, isEmpty);
      expect(loaderCalled, isFalse);
    });
  });
}
