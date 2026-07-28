import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/favorite.dart';
import 'package:songbook_app/data/models/song_id.dart';

void main() {
  final when = DateTime(2026, 7, 2, 12, 30);

  group('JSON', () {
    test('fromJson parses all fields', () {
      final fav = Favorite.fromJson({
        'songId': 'hymnal:42',
        'addedAt': '2026-07-02T12:30:00.000',
        'sortOrder': 3,
      });
      expect(fav.songId, const SongId.hymnal(42));
      expect(fav.addedAt, when);
      expect(fav.sortOrder, 3);
    });

    test('missing sortOrder defaults to 0', () {
      final fav = Favorite.fromJson({
        'songId': 'hymnal:1',
        'addedAt': '2026-01-01T00:00:00.000',
      });
      expect(fav.sortOrder, 0);
    });

    test('toJson emits ISO-8601 date', () {
      final fav = Favorite(
        songId: const SongId.hymnal(7),
        addedAt: when,
        sortOrder: 1,
      );
      expect(fav.toJson(), {
        'songId': 'hymnal:7',
        'addedAt': '2026-07-02T12:30:00.000',
        'sortOrder': 1,
      });
    });

    // SongIdConverter accepts a bare int and reads it as a hymnal number —
    // that is the upgrade path for every payload written before song ids
    // existed. (Whether the *key* still matches is covered by the legacy
    // payload group in local_datasource_test.dart.)
    test('accepts a bare int song id and reads it as a hymnal number', () {
      final fav = Favorite.fromJson({
        'songId': 42,
        'addedAt': '2026-07-02T12:30:00.000',
      });

      expect(fav.songId, const SongId.hymnal(42));
    });

    test('round-trips through JSON', () {
      final fav = Favorite(
        songId: const SongId.hymnal(9),
        addedAt: when,
        sortOrder: 5,
      );
      final decoded = Favorite.fromJson(fav.toJson());
      expect(decoded.songId, fav.songId);
      expect(decoded.addedAt, fav.addedAt);
      expect(decoded.sortOrder, fav.sortOrder);
    });
  });

  group('copyWith', () {
    test('overrides fields independently', () {
      final fav = Favorite(songId: const SongId.hymnal(1), addedAt: when);
      expect(
        fav.copyWith(songId: const SongId.hymnal(2)).songId,
        const SongId.hymnal(2),
      );
      expect(fav.copyWith(sortOrder: 9).sortOrder, 9);
      expect(fav.copyWith(sortOrder: 9).addedAt, when);
      final later = when.add(const Duration(days: 1));
      expect(fav.copyWith(addedAt: later).addedAt, later);
    });
  });

  group('equality', () {
    // Covers every field, sortOrder included: providers compare old/new values
    // with == to decide whether to rebuild, so an id-only comparison would
    // report "no change" after a reorder and the list would never redraw. That
    // is exactly how Setlist.== broke setlist editing.
    test('covers all fields, including sortOrder', () {
      final a = Favorite(
        songId: const SongId.hymnal(5),
        addedAt: when,
        sortOrder: 0,
      );
      final same = Favorite(
        songId: const SongId.hymnal(5),
        addedAt: when,
        sortOrder: 0,
      );
      final laterAddedAt = Favorite(
        songId: const SongId.hymnal(5),
        addedAt: when.add(const Duration(days: 3)),
        sortOrder: 0,
      );
      final reordered = Favorite(
        songId: const SongId.hymnal(5),
        addedAt: when,
        sortOrder: 7,
      );

      expect(a, same);
      expect(a.hashCode, same.hashCode);

      expect(a, isNot(laterAddedAt));
      expect(a, isNot(reordered));
      expect(
        a,
        isNot(Favorite(songId: const SongId.hymnal(6), addedAt: when)),
      );
    });
  });
}
