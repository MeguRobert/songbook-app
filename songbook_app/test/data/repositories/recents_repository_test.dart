import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/repositories/recents_repository.dart';

Future<RecentsRepository> makeRepo() async {
  final prefs = await SharedPreferences.getInstance();
  return RecentsRepository(LocalDataSource(prefs));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RecentsRepository', () {
    test('starts empty', () async {
      final repo = await makeRepo();
      expect(repo.getRecentSongs(), isEmpty);
      expect(repo.lastViewed, isNull);
    });

    test('records most-recent first', () async {
      final repo = await makeRepo();
      await repo.record(const SongId.hymnal(1), now: DateTime(2026, 1, 1));
      await repo.record(const SongId.hymnal(42), now: DateTime(2026, 1, 2));
      await repo.record(const SongId.hymnal(7), now: DateTime(2026, 1, 3));

      expect(
        repo.getRecentSongIds(),
        equals(const [SongId.hymnal(7), SongId.hymnal(42), SongId.hymnal(1)]),
      );
      expect(repo.lastViewed, const SongId.hymnal(7));
    });

    test('re-viewing a song moves it to the front without duplicating',
        () async {
      final repo = await makeRepo();
      await repo.record(const SongId.hymnal(1), now: DateTime(2026, 1, 1));
      await repo.record(const SongId.hymnal(42), now: DateTime(2026, 1, 2));
      await repo.record(const SongId.hymnal(1), now: DateTime(2026, 1, 3));

      expect(
        repo.getRecentSongIds(),
        equals(const [SongId.hymnal(1), SongId.hymnal(42)]),
      );
    });

    test('caps the list at the configured limit', () async {
      final repo = await makeRepo();
      final limit = LocalDataSource.recentsLimit;
      for (var i = 0; i < limit + 5; i++) {
        await repo.record(SongId.hymnal(i),
            now: DateTime(2026, 1, 1).add(Duration(days: i)));
      }

      final ids = repo.getRecentSongIds();
      expect(ids.length, limit);
      // Newest first: the last recorded (limit+4) is at the front; the oldest
      // five (0..4) were dropped.
      expect(ids.first, SongId.hymnal(limit + 4));
      expect(ids.contains(const SongId.hymnal(0)), isFalse);
      expect(ids.contains(const SongId.hymnal(4)), isFalse);
      expect(ids.contains(const SongId.hymnal(5)), isTrue);
    });

    test('clear empties the list', () async {
      final repo = await makeRepo();
      await repo.record(const SongId.hymnal(1));
      await repo.clear();
      expect(repo.getRecentSongs(), isEmpty);
    });

    test('persists across repository instances over the same prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      await RecentsRepository(LocalDataSource(prefs))
          .record(const SongId.hymnal(99), now: DateTime(2026, 1, 1));

      final fresh = RecentsRepository(LocalDataSource(prefs));
      expect(fresh.getRecentSongIds(), equals(const [SongId.hymnal(99)]));
    });

    // Upgrade path. Every recent written before song ids existed stores the
    // song as a bare int under 'n'; the key did not change, and
    // SongId.fromJson reads an int as a hymnal number, so history survives.
    test('reads a pre-SongId record (bare int under "n") as a hymnal id',
        () async {
      SharedPreferences.setMockInitialValues({
        'recent_songs': json.encode([
          {'n': 42, 't': DateTime(2026, 1, 2).millisecondsSinceEpoch},
          {'n': 1, 't': DateTime(2026, 1, 1).millisecondsSinceEpoch},
        ]),
      });
      final repo = await makeRepo();

      expect(
        repo.getRecentSongIds(),
        equals(const [SongId.hymnal(42), SongId.hymnal(1)]),
      );
      expect(repo.lastViewed, const SongId.hymnal(42));
      expect(repo.getRecentSongs().first.viewedAt, DateTime(2026, 1, 2));
    });

    // ...and rewriting that history persists the canonical form, so the
    // upgrade is one-way rather than re-reading legacy shapes forever.
    test('re-recording a legacy entry rewrites it in canonical form', () async {
      SharedPreferences.setMockInitialValues({
        'recent_songs': json.encode([
          {'n': 42, 't': DateTime(2026, 1, 1).millisecondsSinceEpoch},
        ]),
      });
      final repo = await makeRepo();
      await repo.record(const SongId.hymnal(42), now: DateTime(2026, 1, 3));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('recent_songs'), contains('"n":"hymnal:42"'));
      expect(repo.getRecentSongIds(), equals(const [SongId.hymnal(42)]));
    });
  });
}
