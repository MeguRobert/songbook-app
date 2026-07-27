import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/core/utils/chord_transposer.dart';

void main() {
  group('ChordTransposer.parseChord', () {
    test('parses plain major chord', () {
      expect(ChordTransposer.parseChord('C'), ('C', ''));
      expect(ChordTransposer.parseChord('G'), ('G', ''));
    });

    test('parses sharp and flat roots', () {
      expect(ChordTransposer.parseChord('F#'), ('F#', ''));
      expect(ChordTransposer.parseChord('Bb'), ('Bb', ''));
    });

    test('parses root plus quality', () {
      expect(ChordTransposer.parseChord('Gm7'), ('G', 'm7'));
      expect(ChordTransposer.parseChord('F#dim'), ('F#', 'dim'));
      expect(ChordTransposer.parseChord('Bbmaj7'), ('Bb', 'maj7'));
      expect(ChordTransposer.parseChord('Asus4'), ('A', 'sus4'));
      expect(ChordTransposer.parseChord('Cadd9'), ('C', 'add9'));
    });

    test('parses slash chords keeping bass in quality', () {
      expect(ChordTransposer.parseChord('C/G'), ('C', '/G'));
      expect(ChordTransposer.parseChord('D7/F#'), ('D', '7/F#'));
    });

    test('returns null for invalid input', () {
      expect(ChordTransposer.parseChord(''), isNull);
      expect(ChordTransposer.parseChord('H'), isNull); // no German notation
      expect(ChordTransposer.parseChord('c'), isNull); // lowercase not a chord
      expect(ChordTransposer.parseChord('7'), isNull);
      expect(ChordTransposer.parseChord('#C'), isNull);
      expect(ChordTransposer.parseChord(' C'), isNull); // leading whitespace
    });
  });

  group('ChordTransposer.transposeChord', () {
    test('transpose by 0 is identity (idempotence), even for invalid input',
        () {
      expect(ChordTransposer.transposeChord('C', 0), 'C');
      expect(ChordTransposer.transposeChord('Gm7', 0), 'Gm7');
      expect(ChordTransposer.transposeChord('not-a-chord', 0), 'not-a-chord');
      expect(ChordTransposer.transposeChord('', 0), '');
    });

    test('transposes all 12 semitones up from C (sharp notation)', () {
      const expected = [
        'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
      ];
      for (var i = 0; i < 12; i++) {
        expect(ChordTransposer.transposeChord('C', i), expected[i],
            reason: 'C + $i semitones');
      }
    });

    test('transposes all 12 semitones up from C (flat notation)', () {
      const expected = [
        'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
      ];
      for (var i = 0; i < 12; i++) {
        expect(ChordTransposer.transposeChord('C', i, useFlats: true),
            expected[i],
            reason: 'C + $i semitones (flats)');
      }
    });

    test('covers the full symmetric project range -6..+5', () {
      // From G: chromatic positions relative to G with sharp naming.
      const byOffset = {
        -6: 'C#',
        -5: 'D',
        -4: 'D#',
        -3: 'E',
        -2: 'F',
        -1: 'F#',
        0: 'G',
        1: 'G#',
        2: 'A',
        3: 'A#',
        4: 'B',
        5: 'C',
      };
      byOffset.forEach((semitones, expected) {
        expect(ChordTransposer.transposeChord('G', semitones), expected,
            reason: 'G ${semitones >= 0 ? '+' : ''}$semitones');
      });
    });

    test('wraps around at the top (B upward)', () {
      expect(ChordTransposer.transposeChord('B', 1), 'C');
      expect(ChordTransposer.transposeChord('B', 2), 'C#');
      expect(ChordTransposer.transposeChord('A#', 3), 'C#');
    });

    test('wraps around at the bottom (C downward)', () {
      expect(ChordTransposer.transposeChord('C', -1), 'B');
      expect(ChordTransposer.transposeChord('C', -2), 'A#');
      expect(ChordTransposer.transposeChord('C', -2, useFlats: true), 'Bb');
      expect(ChordTransposer.transposeChord('D', -6), 'G#');
    });

    test('handles offsets beyond one octave', () {
      expect(ChordTransposer.transposeChord('C', 12), 'C');
      expect(ChordTransposer.transposeChord('C', -12), 'C');
      expect(ChordTransposer.transposeChord('C', 13), 'C#');
      expect(ChordTransposer.transposeChord('C', -13), 'B');
      expect(ChordTransposer.transposeChord('G', 24), 'G');
    });

    test('preserves chord quality through transposition', () {
      expect(ChordTransposer.transposeChord('Gm7', 2), 'Am7');
      expect(ChordTransposer.transposeChord('Cmaj7', 1), 'C#maj7');
      expect(ChordTransposer.transposeChord('Dsus4', -2), 'Csus4');
      expect(ChordTransposer.transposeChord('Adim7', 3), 'Cdim7');
    });

    test('flat root input is found via flat-note lookup', () {
      expect(ChordTransposer.transposeChord('Bb', 2), 'C');
      expect(ChordTransposer.transposeChord('Eb', 1), 'E');
      expect(ChordTransposer.transposeChord('Db', -1), 'C');
    });

    test('enharmonic equivalents transpose to the same pitch class', () {
      // F# and Gb are the same pitch; +1 lands on G either way.
      expect(ChordTransposer.transposeChord('F#', 1), 'G');
      expect(ChordTransposer.transposeChord('Gb', 1), 'G');
      // Same pitch, notation follows the useFlats flag.
      expect(ChordTransposer.transposeChord('C#', 1), 'D');
      expect(ChordTransposer.transposeChord('Db', 1, useFlats: true), 'D');
    });

    test('up N then down N returns to the original pitch (sharp spelling)',
        () {
      for (final chord in ['C', 'E', 'G', 'B', 'F#m7']) {
        for (var n = 1; n <= 6; n++) {
          final up = ChordTransposer.transposeChord(chord, n);
          expect(ChordTransposer.transposeChord(up, -n), chord,
              reason: '$chord +$n -$n');
        }
      }
    });

    test('transposes the bass note of a slash chord, not just the root', () {
      // Regression: parseChord hands back "/B" as opaque quality, so the bass
      // used to ride along untransposed and G/B +2 came out as A/B.
      expect(ChordTransposer.transposeChord('G/B', 2), 'A/C#');
      expect(ChordTransposer.transposeChord('C/E', 2), 'D/F#');
      expect(ChordTransposer.transposeChord('D/F#', -2), 'C/E');
      expect(ChordTransposer.transposeChord('D7/F#', 2), 'E7/G#');
      expect(ChordTransposer.transposeChord('Am7/G', 3), 'Cm7/A#');
    });

    test('slash chords follow useFlats on both sides', () {
      expect(ChordTransposer.transposeChord('Bb/D', 2), 'C/E');
      expect(ChordTransposer.transposeChord('Bb/D', 1, useFlats: true),
          'B/Eb');
      expect(ChordTransposer.transposeChord('C/E', 1, useFlats: true),
          'Db/F');
      // Only the bass gains an accidental here.
      expect(ChordTransposer.transposeChord('C/G', 2), 'D/A');
      expect(ChordTransposer.transposeChord('C/A', 3), 'D#/C');
    });

    test('slash chords round-trip and wrap like plain chords', () {
      // Sharp-spelled only: a flat root comes back sharp-spelled by default,
      // exactly as it does for plain chords.
      for (final chord in ['G/B', 'C/E', 'F#m7/A']) {
        for (var n = 1; n <= 6; n++) {
          final up = ChordTransposer.transposeChord(chord, n);
          expect(ChordTransposer.transposeChord(up, -n), chord,
              reason: '$chord +$n -$n');
        }
      }
      expect(ChordTransposer.transposeChord('B/G#', 1), 'C/A');
      expect(ChordTransposer.transposeChord('G/B', 0), 'G/B');
    });

    test('an unresolvable side leaves the whole slash chord alone', () {
      // Half-transposing would quietly change the harmony.
      expect(ChordTransposer.transposeChord('G/H', 2), 'G/H');
      expect(ChordTransposer.transposeChord('x/G', 2), 'x/G');
      expect(ChordTransposer.transposeChord('Cb/G', 2), 'Cb/G');
    });

    test('returns unparseable chords unchanged', () {
      expect(ChordTransposer.transposeChord('H', 2), 'H');
      expect(ChordTransposer.transposeChord('', 2), '');
      expect(ChordTransposer.transposeChord('x7', 2), 'x7');
    });

    test('returns chords with unknown roots unchanged', () {
      // 'Cb' parses as root 'Cb' which is in neither note table.
      expect(ChordTransposer.transposeChord('Cb', 2), 'Cb');
      expect(ChordTransposer.transposeChord('E#', 2), 'E#');
    });
  });

  group('ChordTransposer.semitonesBetween', () {
    test('returns 0 for identical keys', () {
      expect(ChordTransposer.semitonesBetween('C', 'C'), 0);
      expect(ChordTransposer.semitonesBetween('Bb', 'Bb'), 0);
    });

    test('returns positive for short upward path', () {
      expect(ChordTransposer.semitonesBetween('C', 'D'), 2);
      expect(ChordTransposer.semitonesBetween('C', 'F'), 5);
      expect(ChordTransposer.semitonesBetween('G', 'A'), 2);
    });

    test('normalizes wide upward jumps to negative (shortest path)', () {
      expect(ChordTransposer.semitonesBetween('C', 'G'), -5); // 7 -> -5
      expect(ChordTransposer.semitonesBetween('C', 'B'), -1); // 11 -> -1
    });

    test('normalizes wide downward jumps to positive (shortest path)', () {
      expect(ChordTransposer.semitonesBetween('G', 'C'), 5); // -7 -> +5
      expect(ChordTransposer.semitonesBetween('B', 'C'), 1); // -11 -> +1
    });

    test('tritone stays at +6 (not normalized to -6)', () {
      // diff == 6 does not trigger the `> 6` normalization branch.
      expect(ChordTransposer.semitonesBetween('C', 'F#'), 6);
      expect(ChordTransposer.semitonesBetween('F#', 'C'), -6);
    });

    test('handles minor keys by stripping the m suffix', () {
      expect(ChordTransposer.semitonesBetween('Am', 'Cm'), 3);
      expect(ChordTransposer.semitonesBetween('Dm', 'Am'), -5);
    });

    test('handles flat-spelled keys', () {
      expect(ChordTransposer.semitonesBetween('Bb', 'C'), 2);
      expect(ChordTransposer.semitonesBetween('Eb', 'F'), 2);
    });

    test('returns 0 when either key is invalid', () {
      expect(ChordTransposer.semitonesBetween('H', 'C'), 0);
      expect(ChordTransposer.semitonesBetween('C', 'H'), 0);
      expect(ChordTransposer.semitonesBetween('', ''), 0);
    });
  });

  group('ChordTransposer.shouldUseFlats', () {
    test('true for flat major keys', () {
      for (final key in ['F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb']) {
        expect(ChordTransposer.shouldUseFlats(key), isTrue, reason: key);
      }
    });

    test('true for flat minor keys', () {
      for (final key in ['Dm', 'Gm', 'Cm', 'Fm', 'Bbm', 'Ebm']) {
        expect(ChordTransposer.shouldUseFlats(key), isTrue, reason: key);
      }
    });

    test('false for sharp-side and neutral keys', () {
      for (final key in ['C', 'G', 'D', 'A', 'E', 'B', 'F#', 'Am', 'Em']) {
        expect(ChordTransposer.shouldUseFlats(key), isFalse, reason: key);
      }
    });
  });

  group('ChordTransposer.transposeKey', () {
    test('transposes major keys', () {
      expect(ChordTransposer.transposeKey('C', 2), 'D');
      expect(ChordTransposer.transposeKey('G', 5), 'C');
    });

    test('transposes minor keys preserving the m suffix', () {
      expect(ChordTransposer.transposeKey('Am', 2), 'Bm');
      expect(ChordTransposer.transposeKey('Em', -2), 'Dm');
    });

    test('flat keys keep flat spelling', () {
      expect(ChordTransposer.transposeKey('Bb', 2), 'C');
      expect(ChordTransposer.transposeKey('F', 1), 'Gb');
      expect(ChordTransposer.transposeKey('Eb', -2), 'Db');
      expect(ChordTransposer.transposeKey('Gm', 1), 'Abm');
    });

    test('sharp keys keep sharp spelling', () {
      expect(ChordTransposer.transposeKey('G', 1), 'G#');
      expect(ChordTransposer.transposeKey('D', -1), 'C#');
      expect(ChordTransposer.transposeKey('Am', 1), 'A#m');
    });

    test('transpose by 0 is identity', () {
      expect(ChordTransposer.transposeKey('Bb', 0), 'Bb');
      expect(ChordTransposer.transposeKey('F#m', 0), 'F#m');
    });
  });

  group('ChordTransposer.getAllKeys', () {
    test('returns all 12 distinct keys in chromatic order', () {
      final keys = ChordTransposer.getAllKeys();
      expect(keys, [
        'C', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B',
      ]);
      expect(keys.toSet().length, 12);
    });
  });
}
