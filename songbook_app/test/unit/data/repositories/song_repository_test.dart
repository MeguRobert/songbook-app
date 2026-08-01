import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/datasources/remote/remote_song_datasource.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/repositories/song_repository.dart';

class MockLocalDataSource extends Mock implements LocalDataSource {}

class MockRemoteSongDataSource extends Mock implements RemoteSongDataSource {}

Song song(int number, {String? title}) => Song(
      number: number,
      title: title ?? 'Song $number',
      originalKey: 'C',
      verses: const [],
    );

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

  // Deliberately NOT delegating to LocalDataSource.getSongByNumber: that would
  // search the bundled asset only, so any song that exists solely on the server
  // would be invisible to every lookup by number — favourites, setlists and the
  // router all go through here.
  test('getSongByNumber searches the merged catalogue, not just the asset',
      () async {
    when(() => dataSource.loadSongs())
        .thenAnswer((_) async => [song(5), song(7)]);

    expect((await repository.getSongByNumber(5))?.number, 5);
    expect(await repository.getSongByNumber(6), isNull);
    verifyNever(() => dataSource.getSongByNumber(any()));
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

  // The bundled asset is the floor. These cover the guarantee that adding a
  // backend did not make the app depend on one.
  group('with a remote catalogue', () {
    late MockRemoteSongDataSource remote;

    setUp(() {
      remote = MockRemoteSongDataSource();
      repository = SongRepository(dataSource, remote);
    });

    test('server songs are merged over the bundled ones', () async {
      when(() => dataSource.loadSongs())
          .thenAnswer((_) async => [song(1), song(42)]);
      when(() => remote.fetchSongs())
          .thenAnswer((_) async => [song(42, title: 'server copy'), song(90)]);

      final result = await repository.getAllSongs();

      expect(result.map((s) => s.number), [1, 42, 90],
          reason: 'sorted, and the server-only song 90 is present');
      expect(result.firstWhere((s) => s.number == 42).title, 'server copy',
          reason: 'same SongId (hymnal:42), so the server copy replaces the '
              'bundled one rather than duplicating it');
    });

    test('a remote failure falls back to the bundled catalogue', () async {
      when(() => dataSource.loadSongs())
          .thenAnswer((_) async => [song(1), song(2)]);
      when(() => remote.fetchSongs()).thenThrow(Exception('offline'));

      final result = await repository.getAllSongs();

      expect(result.map((s) => s.number), [1, 2],
          reason: 'offline, a paused project and a timeout are all normal '
              'states for this app, not errors to surface');
    });

    test('a remote failure is not cached, so a later read retries', () async {
      when(() => dataSource.loadSongs()).thenAnswer((_) async => [song(1)]);
      var attempts = 0;
      when(() => remote.fetchSongs()).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw Exception('offline');
        return [song(90)];
      });

      final offline = await repository.getAllSongs();
      expect(offline.map((s) => s.number), [1]);

      final online = await repository.getAllSongs();
      expect(online.map((s) => s.number), [1, 90],
          reason: 'connectivity comes back mid-session; the failure must not '
              'be cached as though the server had answered');
      expect(attempts, 2);
    });

    test('a successful merge is cached, so one fetch serves the session',
        () async {
      when(() => dataSource.loadSongs()).thenAnswer((_) async => [song(1)]);
      when(() => remote.fetchSongs()).thenAnswer((_) async => [song(90)]);

      await repository.getAllSongs();
      await repository.getAllSongs();
      await repository.getSongCount();

      verify(() => remote.fetchSongs()).called(1);
    });

    test('refresh re-attempts the server', () async {
      when(() => dataSource.loadSongs()).thenAnswer((_) async => [song(1)]);
      when(() => dataSource.clearSongCache()).thenReturn(null);
      when(() => remote.fetchSongs()).thenAnswer((_) async => [song(90)]);

      await repository.getAllSongs();
      repository.refresh();
      await repository.getAllSongs();

      verify(() => remote.fetchSongs()).called(2);
    });
  });
}
