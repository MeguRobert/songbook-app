import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/verse.dart';

void main() {
  group('JSON', () {
    test('fromJson parses a full structured verse', () {
      final verse = Verse.fromJson({
        'number': 1,
        'hasNotation': true,
        'lines': [
          {
            'text': 'first line',
            'chords': [
              {'chord': 'C', 'position': 0},
            ],
          },
          {'text': 'second line'},
        ],
      });
      expect(verse.number, 1);
      expect(verse.hasNotation, isTrue);
      expect(verse.lines, hasLength(2));
      expect(verse.lines[0].chords.single.chord, 'C');
      expect(verse.lines[1].chords, isEmpty);
      expect(verse.plainText, isNull);
    });

    test('fromJson parses a plain-text verse with defaults', () {
      final verse = Verse.fromJson({
        'number': 2,
        'plainText': 'A plain second verse',
      });
      expect(verse.number, 2);
      expect(verse.hasNotation, isFalse);
      expect(verse.lines, isEmpty);
      expect(verse.plainText, 'A plain second verse');
    });

    test('toJson emits all fields', () {
      const verse = Verse(number: 3, plainText: 'text');
      final json = verse.toJson();
      expect(json['number'], 3);
      expect(json['hasNotation'], isFalse);
      expect(json['lines'], isEmpty);
      expect(json['plainText'], 'text');
    });
  });

  group('displayText', () {
    test('prefers plainText when present', () {
      const verse = Verse(
        number: 1,
        plainText: 'plain wins',
        lines: [LyricLine(text: 'line text')],
      );
      expect(verse.displayText, 'plain wins');
    });

    test('joins line texts when plainText is null', () {
      const verse = Verse(
        number: 1,
        lines: [LyricLine(text: 'one'), LyricLine(text: 'two')],
      );
      expect(verse.displayText, 'one\ntwo');
    });

    test('falls back to lines when plainText is empty', () {
      const verse = Verse(
        number: 1,
        plainText: '',
        lines: [LyricLine(text: 'fallback')],
      );
      expect(verse.displayText, 'fallback');
    });

    test('is empty for a verse with no content', () {
      expect(const Verse(number: 1).displayText, '');
    });
  });

  group('displayLines', () {
    // Exists because searching per line was joining every verse into one string
    // and splitting it straight back apart — per song, on every keystroke. The
    // lines were already separate. `displayText` is now derived from this, so the
    // plainText-wins rule lives in one place rather than two that can drift.
    test('is one entry per line when plainText is null', () {
      const verse = Verse(
        number: 1,
        lines: [LyricLine(text: 'one'), LyricLine(text: 'two')],
      );
      expect(verse.displayLines, ['one', 'two']);
    });

    test('splits plainText, which wins when present', () {
      const verse = Verse(
        number: 1,
        plainText: 'plain one\nplain two',
        lines: [LyricLine(text: 'ignored')],
      );
      expect(verse.displayLines, ['plain one', 'plain two']);
    });

    test('falls back to lines when plainText is empty', () {
      const verse = Verse(number: 1, plainText: '', lines: [
        LyricLine(text: 'fallback'),
      ]);
      expect(verse.displayLines, ['fallback']);
    });

    test('is empty for a verse with no content', () {
      expect(const Verse(number: 1).displayLines, isEmpty);
    });

    test('agrees with displayText for every shape', () {
      // The invariant that makes reading one instead of the other safe.
      const verses = [
        Verse(number: 1, lines: [LyricLine(text: 'a'), LyricLine(text: 'b')]),
        Verse(number: 2, plainText: 'x\ny'),
        Verse(number: 3, plainText: 'single'),
        Verse(number: 4, plainText: '', lines: [LyricLine(text: 'z')]),
        Verse(number: 5),
      ];
      for (final verse in verses) {
        expect(verse.displayLines.join('\n'), verse.displayText,
            reason: 'verse ${verse.number}');
      }
    });
  });

  group('hasChordData', () {
    test('true when any line has chords', () {
      const verse = Verse(
        number: 1,
        lines: [
          LyricLine(text: 'a'),
          LyricLine(text: 'b', chords: [ChordPosition(chord: 'C', position: 0)]),
        ],
      );
      expect(verse.hasChordData, isTrue);
    });

    test('false when no line has chords', () {
      const verse = Verse(number: 1, lines: [LyricLine(text: 'a')]);
      expect(verse.hasChordData, isFalse);
      expect(const Verse(number: 1).hasChordData, isFalse);
    });
  });

  group('copyWith', () {
    test('overrides fields independently', () {
      const verse = Verse(number: 1, hasNotation: true, plainText: 'p');
      expect(verse.copyWith(number: 2).number, 2);
      expect(verse.copyWith(number: 2).hasNotation, isTrue);
      expect(verse.copyWith(hasNotation: false).hasNotation, isFalse);
      expect(verse.copyWith(lines: [const LyricLine(text: 'l')]).lines,
          hasLength(1));
    });
  });

  group('equality', () {
    test('compares every field, lines included', () {
      const a = Verse(number: 1, plainText: 'x');
      const b = Verse(number: 1, plainText: 'x', lines: [LyricLine(text: 'l')]);
      // `lines` used to be excluded here, which made an edited verse compare
      // equal to the version it replaced.
      expect(a, isNot(b));
      expect(a, isNot(const Verse(number: 2, plainText: 'x')));
      expect(a, isNot(const Verse(number: 1, plainText: 'y')));
      expect(a, isNot(const Verse(number: 1, plainText: 'x', hasNotation: true)));

      expect(a, const Verse(number: 1, plainText: 'x'));
      expect(b, const Verse(number: 1, plainText: 'x',
          lines: [LyricLine(text: 'l')]));
    });

    test('an edited verse differs from the one it replaced', () {
      const original = Verse(number: 1, lines: [LyricLine(text: 'eredeti')]);
      final edited = original.copyWith(
        lines: [const LyricLine(text: 'javított')],
      );

      expect(edited, isNot(original));
      expect(edited.hashCode, isNot(original.hashCode));
    });

    test('equal verses hash equally', () {
      const a = Verse(number: 1, lines: [LyricLine(text: 'l')]);
      const b = Verse(number: 1, lines: [LyricLine(text: 'l')]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // Set membership relies on the hash contract holding. Built at runtime,
      // not as a literal: two equal const operands get folded at compile time,
      // so `{a, b}` would prove nothing about hashCode.
      final deduped = <Verse>{}
        ..add(a)
        ..add(b);
      expect(deduped, hasLength(1));
    });
  });
}
