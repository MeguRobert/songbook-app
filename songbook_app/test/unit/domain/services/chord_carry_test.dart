import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/domain/services/chord_carry.dart';

/// A songbook prints the chords over verse 1 and the later verses as words
/// alone — the reader is expected to play the same shape again. Every importer
/// therefore produces a song whose second verse cannot be played from, which is
/// exactly the verse you are on when you stop looking at the page.
void main() {
  const carry = ChordCarry();

  Verse verse(int number, List<LyricLine> lines) =>
      Verse(number: number, lines: lines);

  LyricLine chorded(String text, Map<int, String> chords) => LyricLine(
        text: text,
        chords: [
          for (final entry in chords.entries)
            ChordPosition(chord: entry.value, position: entry.key),
        ],
      );

  group('ChordCarry.carry', () {
    test('a chordless later verse takes the first verse\'s chords', () {
      final result = carry.carry([
        verse(1, [chorded('Csak egy az út', {0: 'D', 9: 'A'})]),
        verse(2, [const LyricLine(text: 'és minden reggel')]),
      ]);

      expect(result[1].lines.single.chords, const [
        ChordPosition(chord: 'D', position: 0),
        ChordPosition(chord: 'A', position: 9),
      ]);
    });

    test('the first verse is returned untouched', () {
      final first = chorded('Csak egy az út', {0: 'D'});
      final result = carry.carry([
        verse(1, [first]),
        verse(2, [const LyricLine(text: 'és minden reggel')]),
      ]);

      expect(result.first.lines.single, first);
    });

    test('a verse with its own chords is left alone', () {
      // Its chords were read off the page; a guess must not overwrite them.
      final own = chorded('és minden reggel', {3: 'G'});
      final result = carry.carry([
        verse(1, [chorded('Csak egy az út', {0: 'D', 9: 'A'})]),
        verse(2, [own]),
      ]);

      expect(result[1].lines.single, own);
    });

    test('one chorded line is enough to leave the whole verse alone', () {
      // Half a verse read correctly still means the page had chords there.
      final result = carry.carry([
        verse(1, [chorded('a', {0: 'D'}), chorded('b', {0: 'A'})]),
        verse(2, [
          const LyricLine(text: 'c'),
          chorded('d', {0: 'G'}),
        ]),
      ]);

      expect(result[1].lines.first.chords, isEmpty);
    });

    test('nothing happens when the first verse has no chords either', () {
      final result = carry.carry([
        verse(1, [const LyricLine(text: 'Csak egy az út')]),
        verse(2, [const LyricLine(text: 'és minden reggel')]),
      ]);

      expect(result[1].lines.single.chords, isEmpty);
    });

    test('a line past the end of the first verse gets nothing', () {
      final result = carry.carry([
        verse(1, [chorded('Csak egy az út', {0: 'D'})]),
        verse(2, [
          const LyricLine(text: 'és minden reggel'),
          const LyricLine(text: 'újra kezdem el'),
        ]),
      ]);

      expect(result[1].lines.first.chords, hasLength(1));
      expect(result[1].lines.last.chords, isEmpty);
    });

    test('a chord past the end of a shorter line moves to the end of it', () {
      // Verse 1's line is long and verse 2's is short. Left where it was, the
      // chord would hang in space well beyond its own words.
      final result = carry.carry([
        verse(1, [chorded('Csak egy az út, mely hozzád visz', {28: 'Hm'})]),
        verse(2, [const LyricLine(text: 'rövid')]),
      ]);

      expect(result[1].lines.single.chords,
          const [ChordPosition(chord: 'Hm', position: 5)]);
    });

    test('every later verse is filled, not only the second', () {
      final result = carry.carry([
        verse(1, [chorded('egy', {0: 'D'})]),
        verse(2, [const LyricLine(text: 'kettő')]),
        verse(3, [const LyricLine(text: 'három')]),
      ]);

      expect(result[2].lines.single.chords.single.chord, 'D');
    });

    test('an empty song is returned as it came', () {
      expect(carry.carry(const []), isEmpty);
    });

    test('a single verse is returned as it came', () {
      final only = verse(1, [chorded('egy', {0: 'D'})]);
      expect(carry.carry([only]), [only]);
    });

    test('verse numbering and notation flags survive', () {
      final result = carry.carry([
        Verse(number: 1, hasNotation: true, lines: [chorded('egy', {0: 'D'})]),
        const Verse(number: 2, lines: [LyricLine(text: 'kettő')]),
      ]);

      expect(result[1].number, 2);
      expect(result.first.hasNotation, isTrue);
      expect(result[1].hasNotation, isFalse);
    });

    test('a verse stored as plain text is left alone', () {
      // Nowhere to put a chord: plainText carries no positions.
      const plain = Verse(number: 2, plainText: 'és minden reggel');
      final result = carry.carry([
        verse(1, [chorded('egy', {0: 'D'})]),
        plain,
      ]);

      expect(result[1], plain);
    });
  });
}
