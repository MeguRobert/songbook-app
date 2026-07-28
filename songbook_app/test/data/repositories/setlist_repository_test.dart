import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/repositories/setlist_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SetlistRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = SetlistRepository(LocalDataSource(prefs));
  });

  group('create', () {
    test('creates a named, empty setlist with an id', () async {
      final created = await repo.createSetlist('Sunday Morning');

      expect(created.name, 'Sunday Morning');
      expect(created.songIds, isEmpty);
      expect(created.id, isNotEmpty);

      final all = repo.getSetlists();
      expect(all.length, 1);
      expect(all.first.id, created.id);
    });
  });

  group('addSong', () {
    test('appends songs in order', () async {
      final s = await repo.createSetlist('S');
      await repo.addSong(s.id, const SongId.hymnal(42));
      await repo.addSong(s.id, const SongId.hymnal(1));
      await repo.addSong(s.id, const SongId.hymnal(151));

      expect(
        repo.getById(s.id)!.songIds,
        equals(const [SongId.hymnal(42), SongId.hymnal(1), SongId.hymnal(151)]),
      );
    });

    test('is idempotent for an already-present song', () async {
      final s = await repo.createSetlist('S');
      await repo.addSong(s.id, const SongId.hymnal(42));
      await repo.addSong(s.id, const SongId.hymnal(42));

      expect(repo.getById(s.id)!.songIds, equals(const [SongId.hymnal(42)]));
    });
  });

  group('removeSong', () {
    test('removes the song', () async {
      final s = await repo.createSetlist('S');
      await repo.addSong(s.id, const SongId.hymnal(1));
      await repo.addSong(s.id, const SongId.hymnal(42));
      await repo.removeSong(s.id, const SongId.hymnal(1));

      expect(repo.getById(s.id)!.songIds, equals(const [SongId.hymnal(42)]));
    });

    test('removing a missing song is a successful no-op', () async {
      final s = await repo.createSetlist('S');
      await repo.addSong(s.id, const SongId.hymnal(1));

      final result = await repo.removeSong(s.id, const SongId.hymnal(999));

      expect(result, isTrue);
      expect(repo.getById(s.id)!.songIds, equals(const [SongId.hymnal(1)]));
    });
  });

  group('reorderSongs', () {
    test('applies the exact requested order', () async {
      final s = await repo.createSetlist('S');
      await repo.addSong(s.id, const SongId.hymnal(1));
      await repo.addSong(s.id, const SongId.hymnal(42));
      await repo.addSong(s.id, const SongId.hymnal(151));

      await repo.reorderSongs(
        s.id,
        const [SongId.hymnal(151), SongId.hymnal(1), SongId.hymnal(42)],
      );

      expect(
        repo.getById(s.id)!.songIds,
        equals(const [SongId.hymnal(151), SongId.hymnal(1), SongId.hymnal(42)]),
      );
    });
  });

  group('rename + delete', () {
    test('rename changes the name', () async {
      final s = await repo.createSetlist('Old');
      await repo.renameSetlist(s.id, 'New');

      expect(repo.getById(s.id)!.name, 'New');
    });

    test('delete removes the setlist', () async {
      final s = await repo.createSetlist('S');
      await repo.deleteSetlist(s.id);

      expect(repo.getById(s.id), isNull);
      expect(repo.getSetlists(), isEmpty);
    });
  });

  group('unknown id', () {
    test('mutators return false and do not throw', () async {
      expect(await repo.renameSetlist('nope', 'x'), isFalse);
      expect(await repo.deleteSetlist('nope'), isFalse);
      expect(await repo.addSong('nope', const SongId.hymnal(1)), isFalse);
      expect(await repo.removeSong('nope', const SongId.hymnal(1)), isFalse);
      expect(
        await repo.reorderSongs('nope', const [SongId.hymnal(1)]),
        isFalse,
      );
    });
  });

  group('persistence across instances', () {
    test('a fresh repository over the same prefs reads setlists back', () async {
      final s = await repo.createSetlist('Service');
      await repo.addSong(s.id, const SongId.hymnal(1));
      await repo.addSong(s.id, const SongId.hymnal(42));
      await repo.reorderSongs(
        s.id,
        const [SongId.hymnal(42), SongId.hymnal(1)],
      );

      // Simulate a restart: a brand-new datasource + repository over the same
      // backing SharedPreferences.
      final reopened = SetlistRepository(LocalDataSource(prefs));
      final restored = reopened.getById(s.id);

      expect(restored, isNotNull);
      expect(restored!.name, 'Service');
      expect(
        restored.songIds,
        equals(const [SongId.hymnal(42), SongId.hymnal(1)]),
      );
    });
  });
}
