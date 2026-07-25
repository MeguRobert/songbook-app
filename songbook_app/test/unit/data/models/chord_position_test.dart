import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/chord_position.dart';

void main() {
  group('ChordPosition JSON', () {
    test('fromJson parses required fields', () {
      final cp = ChordPosition.fromJson({'chord': 'Bb', 'position': 4});
      expect(cp.chord, 'Bb');
      expect(cp.position, 4);
    });

    test('toJson emits both fields', () {
      const cp = ChordPosition(chord: 'F7', position: 0);
      expect(cp.toJson(), {'chord': 'F7', 'position': 0});
    });

    test('round-trips through JSON', () {
      const cp = ChordPosition(chord: 'Gm', position: 12);
      expect(ChordPosition.fromJson(cp.toJson()), cp);
    });
  });

  group('copyWith', () {
    test('overrides selected fields', () {
      const cp = ChordPosition(chord: 'C', position: 2);
      expect(cp.copyWith(chord: 'D'),
          const ChordPosition(chord: 'D', position: 2));
      expect(cp.copyWith(position: 9),
          const ChordPosition(chord: 'C', position: 9));
    });

    test('no arguments returns an equal object', () {
      const cp = ChordPosition(chord: 'C', position: 2);
      expect(cp.copyWith(), cp);
    });
  });

  group('equality', () {
    test('value equality on both fields', () {
      expect(const ChordPosition(chord: 'C', position: 1),
          const ChordPosition(chord: 'C', position: 1));
      expect(const ChordPosition(chord: 'C', position: 1),
          isNot(const ChordPosition(chord: 'C', position: 2)));
      expect(const ChordPosition(chord: 'C', position: 1),
          isNot(const ChordPosition(chord: 'D', position: 1)));
    });

    test('equal objects share hashCode', () {
      expect(const ChordPosition(chord: 'C', position: 1).hashCode,
          const ChordPosition(chord: 'C', position: 1).hashCode);
    });
  });

  test('toString contains chord and position', () {
    expect(const ChordPosition(chord: 'Em', position: 3).toString(),
        'ChordPosition(chord: Em, position: 3)');
  });
}
