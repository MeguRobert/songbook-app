import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/setlist.dart';
import 'package:songbook_app/data/models/song_id.dart';

Setlist makeSetlist({
  String id = 'sl_1',
  String name = 'Sunday Morning',
  List<SongId> songIds = const [
    SongId.hymnal(1),
    SongId.hymnal(42),
    SongId.hymnal(151),
  ],
}) {
  final created = DateTime.utc(2026, 1, 1, 9);
  final updated = DateTime.utc(2026, 1, 2, 10);
  return Setlist(
    id: id,
    name: name,
    songIds: songIds,
    createdAt: created,
    updatedAt: updated,
  );
}

void main() {
  group('Setlist JSON', () {
    test('round-trips all fields', () {
      final original = makeSetlist();

      final restored = Setlist.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.songIds, equals(original.songIds));
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('preserves song order through serialization', () {
      final original = makeSetlist(songIds: const [
        SongId.hymnal(151),
        SongId.hymnal(1),
        SongId.hymnal(90),
        SongId.hymnal(42),
      ]);

      final restored = Setlist.fromJson(original.toJson());

      expect(
          restored.songIds,
          equals(const [
            SongId.hymnal(151),
            SongId.hymnal(1),
            SongId.hymnal(90),
            SongId.hymnal(42),
          ]));
    });

    test('tolerates a missing songIds key (defaults to empty)', () {
      final json = {
        'id': 'sl_x',
        'name': 'Empty',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      final restored = Setlist.fromJson(json);

      expect(restored.songIds, isEmpty);
    });
  });

  group('Setlist behavior', () {
    test('length and isEmpty reflect songIds', () {
      expect(makeSetlist(songIds: const []).isEmpty, isTrue);
      expect(makeSetlist(songIds: const []).length, 0);
      expect(makeSetlist(songIds: const [SongId.hymnal(1), SongId.hymnal(2)]).length, 2);
      expect(makeSetlist(songIds: const [SongId.hymnal(1), SongId.hymnal(2)]).isEmpty, isFalse);
    });

    test('copyWith updates only provided fields', () {
      final original = makeSetlist();

      final renamed = original.copyWith(name: 'Evening Service');

      expect(renamed.name, 'Evening Service');
      expect(renamed.id, original.id);
      expect(renamed.songIds, equals(original.songIds));
      expect(renamed.createdAt, original.createdAt);
    });

    // Equality must cover songIds: providers compare old/new values with
    // == to decide whether to rebuild, so id-only equality silently suppressed
    // UI updates after add/remove/reorder.
    test('equality is value-based, including songIds', () {
      final a = makeSetlist(id: 'sl_1', name: 'A', songIds: const [SongId.hymnal(1)]);
      final sameAsA =
          makeSetlist(id: 'sl_1', name: 'A', songIds: const [SongId.hymnal(1)]);
      final differentSongs =
          makeSetlist(id: 'sl_1', name: 'A', songIds: const [SongId.hymnal(1), SongId.hymnal(2)]);
      final differentOrder =
          makeSetlist(id: 'sl_1', name: 'A', songIds: const [SongId.hymnal(2), SongId.hymnal(1)]);
      final differentName =
          makeSetlist(id: 'sl_1', name: 'B', songIds: const [SongId.hymnal(1)]);
      final differentId =
          makeSetlist(id: 'sl_2', name: 'A', songIds: const [SongId.hymnal(1)]);

      expect(a, equals(sameAsA));
      expect(a.hashCode, sameAsA.hashCode);

      // The cases that previously compared equal and broke the UI:
      expect(a, isNot(equals(differentSongs)));
      expect(a, isNot(equals(differentOrder)));
      expect(a, isNot(equals(differentName)));
      expect(a, isNot(equals(differentId)));
    });
  });
}
