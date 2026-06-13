import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
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
      await repo.record(1, now: DateTime(2026, 1, 1));
      await repo.record(42, now: DateTime(2026, 1, 2));
      await repo.record(7, now: DateTime(2026, 1, 3));

      expect(repo.getRecentSongNumbers(), equals([7, 42, 1]));
      expect(repo.lastViewed, 7);
    });

    test('re-viewing a song moves it to the front without duplicating',
        () async {
      final repo = await makeRepo();
      await repo.record(1, now: DateTime(2026, 1, 1));
      await repo.record(42, now: DateTime(2026, 1, 2));
      await repo.record(1, now: DateTime(2026, 1, 3));

      expect(repo.getRecentSongNumbers(), equals([1, 42]));
    });

    test('caps the list at the configured limit', () async {
      final repo = await makeRepo();
      final limit = LocalDataSource.recentsLimit;
      for (var i = 0; i < limit + 5; i++) {
        await repo.record(i, now: DateTime(2026, 1, 1).add(Duration(days: i)));
      }

      final numbers = repo.getRecentSongNumbers();
      expect(numbers.length, limit);
      // Newest first: the last recorded (limit+4) is at the front; the oldest
      // five (0..4) were dropped.
      expect(numbers.first, limit + 4);
      expect(numbers.contains(0), isFalse);
      expect(numbers.contains(4), isFalse);
      expect(numbers.contains(5), isTrue);
    });

    test('clear empties the list', () async {
      final repo = await makeRepo();
      await repo.record(1);
      await repo.clear();
      expect(repo.getRecentSongs(), isEmpty);
    });

    test('persists across repository instances over the same prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      await RecentsRepository(LocalDataSource(prefs))
          .record(99, now: DateTime(2026, 1, 1));

      final fresh = RecentsRepository(LocalDataSource(prefs));
      expect(fresh.getRecentSongNumbers(), equals([99]));
    });
  });
}
