import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/data/models/lyric_line.dart';

void main() {
  group('JSON', () {
    test('fromJson parses text and chords', () {
      final line = LyricLine.fromJson({
        'text': 'Mint a szép híves patakra',
        'chords': [
          {'chord': 'Bb', 'position': 0},
          {'chord': 'F', 'position': 11},
        ],
      });
      expect(line.text, 'Mint a szép híves patakra');
      expect(line.chords, hasLength(2));
      expect(line.chords[0], const ChordPosition(chord: 'Bb', position: 0));
      expect(line.chords[1], const ChordPosition(chord: 'F', position: 11));
    });

    test('missing chords defaults to empty list', () {
      final line = LyricLine.fromJson({'text': 'no chords'});
      expect(line.chords, isEmpty);
      expect(line.hasChords, isFalse);
    });

    test('round-trips through JSON', () {
      const line = LyricLine(
        text: 'la la',
        chords: [ChordPosition(chord: 'C', position: 3)],
      );
      final json = line.toJson();
      // Nested objects are emitted as model instances (no explicitToJson);
      // normalize via their own toJson for the round-trip.
      final decoded = LyricLine.fromJson({
        'text': json['text'],
        'chords': [
          for (final c in line.chords) c.toJson(),
        ],
      });
      expect(decoded, line);
    });
  });

  group('hasChords', () {
    test('true when chords present', () {
      const line = LyricLine(
        text: 'x',
        chords: [ChordPosition(chord: 'C', position: 0)],
      );
      expect(line.hasChords, isTrue);
    });

    test('false when empty', () {
      expect(const LyricLine(text: 'x').hasChords, isFalse);
    });
  });

  group('copyWith', () {
    test('overrides fields independently', () {
      const line = LyricLine(
        text: 'orig',
        chords: [ChordPosition(chord: 'C', position: 0)],
      );
      expect(line.copyWith(text: 'new').text, 'new');
      expect(line.copyWith(text: 'new').chords, line.chords);
      expect(line.copyWith(chords: []).chords, isEmpty);
      expect(line.copyWith(chords: []).text, 'orig');
    });
  });

  group('equality', () {
    test('deep-compares the chord list', () {
      const a = LyricLine(
        text: 'x',
        chords: [ChordPosition(chord: 'C', position: 0)],
      );
      final b = LyricLine(
        text: 'x',
        chords: [const ChordPosition(chord: 'C', position: 0)],
      );
      expect(a, b);
    });

    test('differs on text', () {
      expect(const LyricLine(text: 'a'), isNot(const LyricLine(text: 'b')));
    });

    test('differs on chord content and length', () {
      const base = LyricLine(
        text: 'x',
        chords: [ChordPosition(chord: 'C', position: 0)],
      );
      expect(base,
          isNot(const LyricLine(text: 'x', chords: [
            ChordPosition(chord: 'D', position: 0),
          ])));
      expect(base, isNot(const LyricLine(text: 'x', chords: [])));
    });
  });
}
