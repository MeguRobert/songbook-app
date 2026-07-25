import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/setlist.dart';

Setlist makeSetlist({
  String id = 'sl_1',
  String name = 'Sunday Morning',
  List<int> songNumbers = const [1, 42, 151],
}) {
  final created = DateTime.utc(2026, 1, 1, 9);
  final updated = DateTime.utc(2026, 1, 2, 10);
  return Setlist(
    id: id,
    name: name,
    songNumbers: songNumbers,
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
      expect(restored.songNumbers, equals(original.songNumbers));
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('preserves song order through serialization', () {
      final original = makeSetlist(songNumbers: const [151, 1, 90, 42]);

      final restored = Setlist.fromJson(original.toJson());

      expect(restored.songNumbers, equals([151, 1, 90, 42]));
    });

    test('tolerates a missing songNumbers key (defaults to empty)', () {
      final json = {
        'id': 'sl_x',
        'name': 'Empty',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      final restored = Setlist.fromJson(json);

      expect(restored.songNumbers, isEmpty);
    });
  });

  group('Setlist behavior', () {
    test('length and isEmpty reflect songNumbers', () {
      expect(makeSetlist(songNumbers: const []).isEmpty, isTrue);
      expect(makeSetlist(songNumbers: const []).length, 0);
      expect(makeSetlist(songNumbers: const [1, 2]).length, 2);
      expect(makeSetlist(songNumbers: const [1, 2]).isEmpty, isFalse);
    });

    test('copyWith updates only provided fields', () {
      final original = makeSetlist();

      final renamed = original.copyWith(name: 'Evening Service');

      expect(renamed.name, 'Evening Service');
      expect(renamed.id, original.id);
      expect(renamed.songNumbers, equals(original.songNumbers));
      expect(renamed.createdAt, original.createdAt);
    });

    test('equality is id-based', () {
      final a = makeSetlist(id: 'sl_1', name: 'A', songNumbers: const [1]);
      final b = makeSetlist(id: 'sl_1', name: 'B', songNumbers: const [2, 3]);
      final c = makeSetlist(id: 'sl_2', name: 'A', songNumbers: const [1]);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });
}
