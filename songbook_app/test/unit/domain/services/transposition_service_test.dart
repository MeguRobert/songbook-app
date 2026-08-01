import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/domain/services/transposition_service.dart';

void main() {
  const service = TranspositionService();

  LyricLine lineWith(List<(String, int)> chords, {String text = 'la la la'}) {
    return LyricLine(
      text: text,
      chords: [
        for (final (chord, pos) in chords)
          ChordPosition(chord: chord, position: pos),
      ],
    );
  }

  group('transposeChord', () {
    test('defaults to sharp notation without a target key', () {
      expect(service.transposeChord('C', 1), 'C#');
      expect(service.transposeChord('A', 1), 'A#');
    });

    test('uses flat notation when target key is a flat key', () {
      expect(service.transposeChord('C', 1, targetKey: 'Db'), 'Db');
      expect(service.transposeChord('A', 1, targetKey: 'Bb'), 'Bb');
      expect(service.transposeChord('Gm', 1, targetKey: 'Abm'), 'G#m');
    });

    test('uses sharp notation when target key is a sharp key', () {
      expect(service.transposeChord('F', 1, targetKey: 'F#'), 'F#');
      expect(service.transposeChord('C', 2, targetKey: 'D'), 'D');
    });

    test('transpose by 0 returns the chord unchanged', () {
      expect(service.transposeChord('Gm7', 0), 'Gm7');
      expect(service.transposeChord('Gm7', 0, targetKey: 'Bb'), 'Gm7');
    });

    test('invalid chords pass through unchanged', () {
      expect(service.transposeChord('xyz', 3), 'xyz');
      expect(service.transposeChord('', 3), '');
    });

    test('a German chord transposes as B natural', () {
      expect(service.transposeChord('H', 3), 'D');
    });
  });

  group('transposeLine', () {
    test('transposes every chord, preserving positions and text', () {
      final line = lineWith([('C', 0), ('F', 4), ('G7', 8)]);
      final result = service.transposeLine(line, 2);

      expect(result.text, line.text);
      expect(result.chords.map((c) => c.chord), ['D', 'G', 'A7']);
      expect(result.chords.map((c) => c.position), [0, 4, 8]);
    });

    test('returns the same instance for 0 semitones', () {
      final line = lineWith([('C', 0)]);
      expect(identical(service.transposeLine(line, 0), line), isTrue);
    });

    test('returns the same instance for a line without chords', () {
      final line = lineWith([]);
      expect(identical(service.transposeLine(line, 3), line), isTrue);
    });

    test('respects target key notation', () {
      final line = lineWith([('C', 0), ('E', 5)]);
      final result = service.transposeLine(line, 1, targetKey: 'Db');
      expect(result.chords.map((c) => c.chord), ['Db', 'F']);
    });

    test('does not mutate the original line', () {
      final line = lineWith([('C', 0)]);
      service.transposeLine(line, 2);
      expect(line.chords.single.chord, 'C');
    });
  });

  group('transposeVerse', () {
    test('transposes chords in every line', () {
      final verse = Verse(
        number: 1,
        hasNotation: true,
        lines: [
          lineWith([('C', 0)], text: 'first'),
          lineWith([('G', 2), ('Am', 6)], text: 'second'),
        ],
      );

      final result = service.transposeVerse(verse, 2);

      expect(result.number, 1);
      expect(result.hasNotation, isTrue);
      expect(result.lines[0].chords.single.chord, 'D');
      expect(result.lines[1].chords.map((c) => c.chord), ['A', 'Bm']);
    });

    test('returns the same instance for 0 semitones', () {
      final verse = Verse(number: 1, lines: [lineWith([('C', 0)])]);
      expect(identical(service.transposeVerse(verse, 0), verse), isTrue);
    });

    test('returns the same instance for a verse without lines', () {
      const verse = Verse(number: 2, plainText: 'plain verse');
      expect(identical(service.transposeVerse(verse, 3), verse), isTrue);
    });

    test('leaves chord-less lines untouched within a mixed verse', () {
      final verse = Verse(
        number: 1,
        lines: [
          lineWith([], text: 'no chords here'),
          lineWith([('D', 0)], text: 'has a chord'),
        ],
      );
      final result = service.transposeVerse(verse, 1);
      expect(result.lines[0].chords, isEmpty);
      expect(result.lines[0].text, 'no chords here');
      expect(result.lines[1].chords.single.chord, 'D#');
    });
  });

  group('calculateTargetKey', () {
    test('transposes major and minor keys', () {
      expect(service.calculateTargetKey('C', 2), 'D');
      expect(service.calculateTargetKey('Am', 3), 'Cm');
    });

    test('keeps flat spelling for flat keys', () {
      expect(service.calculateTargetKey('Bb', -2), 'Ab');
      expect(service.calculateTargetKey('F', 1), 'Gb');
    });

    test('0 semitones is identity across all displayed keys', () {
      for (final key in service.getAvailableKeys()) {
        expect(service.calculateTargetKey(key, 0), key, reason: key);
      }
    });
  });

  group('getSemitonesBetweenKeys', () {
    test('delegates to shortest-path semitone calculation', () {
      expect(service.getSemitonesBetweenKeys('C', 'D'), 2);
      expect(service.getSemitonesBetweenKeys('C', 'G'), -5);
      expect(service.getSemitonesBetweenKeys('G', 'C'), 5);
      expect(service.getSemitonesBetweenKeys('C', 'C'), 0);
    });

    test('returns 0 for unknown keys', () {
      expect(service.getSemitonesBetweenKeys('X', 'C'), 0);
    });
  });

  group('getAvailableKeys', () {
    test('returns the 12 chromatic display keys', () {
      expect(service.getAvailableKeys(), hasLength(12));
      expect(service.getAvailableKeys().first, 'C');
    });
  });

  group('getTranspositionDisplayName', () {
    test('0 is Original', () {
      expect(service.getTranspositionDisplayName(0), 'Original');
    });

    test('positive amounts get a plus sign', () {
      expect(service.getTranspositionDisplayName(1), '+1');
      expect(service.getTranspositionDisplayName(5), '+5');
    });

    test('negative amounts keep the minus sign', () {
      expect(service.getTranspositionDisplayName(-1), '-1');
      expect(service.getTranspositionDisplayName(-6), '-6');
    });
  });
}
