import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/favorite.dart';

void main() {
  final when = DateTime(2026, 7, 2, 12, 30);

  group('JSON', () {
    test('fromJson parses all fields', () {
      final fav = Favorite.fromJson({
        'songNumber': 42,
        'addedAt': '2026-07-02T12:30:00.000',
        'sortOrder': 3,
      });
      expect(fav.songNumber, 42);
      expect(fav.addedAt, when);
      expect(fav.sortOrder, 3);
    });

    test('missing sortOrder defaults to 0', () {
      final fav = Favorite.fromJson({
        'songNumber': 1,
        'addedAt': '2026-01-01T00:00:00.000',
      });
      expect(fav.sortOrder, 0);
    });

    test('toJson emits ISO-8601 date', () {
      final fav = Favorite(songNumber: 7, addedAt: when, sortOrder: 1);
      expect(fav.toJson(), {
        'songNumber': 7,
        'addedAt': '2026-07-02T12:30:00.000',
        'sortOrder': 1,
      });
    });

    test('round-trips through JSON', () {
      final fav = Favorite(songNumber: 9, addedAt: when, sortOrder: 5);
      final decoded = Favorite.fromJson(fav.toJson());
      expect(decoded.songNumber, fav.songNumber);
      expect(decoded.addedAt, fav.addedAt);
      expect(decoded.sortOrder, fav.sortOrder);
    });
  });

  group('copyWith', () {
    test('overrides fields independently', () {
      final fav = Favorite(songNumber: 1, addedAt: when);
      expect(fav.copyWith(songNumber: 2).songNumber, 2);
      expect(fav.copyWith(sortOrder: 9).sortOrder, 9);
      expect(fav.copyWith(sortOrder: 9).addedAt, when);
      final later = when.add(const Duration(days: 1));
      expect(fav.copyWith(addedAt: later).addedAt, later);
    });
  });

  group('equality', () {
    test('is based on songNumber only', () {
      final a = Favorite(songNumber: 5, addedAt: when, sortOrder: 0);
      final b = Favorite(
        songNumber: 5,
        addedAt: when.add(const Duration(days: 3)),
        sortOrder: 7,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(Favorite(songNumber: 6, addedAt: when)));
    });
  });
}
