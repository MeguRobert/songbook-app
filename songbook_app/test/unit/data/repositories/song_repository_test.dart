import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/repositories/song_repository.dart';

class MockLocalDataSource extends Mock implements LocalDataSource {}

Song song(int number) =>
    Song(number: number, title: 'Song $number', originalKey: 'C', verses: const []);

void main() {
  late MockLocalDataSource dataSource;
  late SongRepository repository;

  setUp(() {
    dataSource = MockLocalDataSource();
    repository = SongRepository(dataSource);
  });

  test('getAllSongs delegates to the data source', () async {
    final songs = [song(1), song(2)];
    when(() => dataSource.loadSongs()).thenAnswer((_) async => songs);

    expect(await repository.getAllSongs(), songs);
    verify(() => dataSource.loadSongs()).called(1);
  });

  test('getSongByNumber delegates to the data source', () async {
    final target = song(5);
    when(() => dataSource.getSongByNumber(5)).thenAnswer((_) async => target);
    when(() => dataSource.getSongByNumber(6)).thenAnswer((_) async => null);

    expect(await repository.getSongByNumber(5), target);
    expect(await repository.getSongByNumber(6), isNull);
  });

  group('getSongsByNumbers', () {
    test('filters the full list by the requested numbers', () async {
      when(() => dataSource.loadSongs())
          .thenAnswer((_) async => [song(1), song(2), song(3)]);

      final result = await repository.getSongsByNumbers([3, 1]);
      expect(result.map((s) => s.number), [1, 3]);
    });

    test('ignores unknown numbers', () async {
      when(() => dataSource.loadSongs()).thenAnswer((_) async => [song(1)]);
      final result = await repository.getSongsByNumbers([1, 99]);
      expect(result.map((s) => s.number), [1]);
    });

    test('empty request yields empty result', () async {
      when(() => dataSource.loadSongs())
          .thenAnswer((_) async => [song(1), song(2)]);
      expect(await repository.getSongsByNumbers([]), isEmpty);
    });
  });

  test('getSongCount returns the number of loaded songs', () async {
    when(() => dataSource.loadSongs())
        .thenAnswer((_) async => [song(1), song(2), song(3)]);
    expect(await repository.getSongCount(), 3);
  });

  test('refresh clears the data source cache', () {
    when(() => dataSource.clearSongCache()).thenReturn(null);
    repository.refresh();
    verify(() => dataSource.clearSongCache()).called(1);
  });
}
