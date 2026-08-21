import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/import_notice.dart';
import 'package:songbook_app/domain/services/photo_text_bridge.dart';

/// Undoing a merged chord run.
///
/// Tesseract joins glyphs into a word on horizontal spacing, so a chord row
/// printed `D G  D` with narrow gaps arrives as the single word `DGD`, and
/// `G - C - D - ( C )` as `G-C-D-(C)`. Neither is a chord symbol, so the
/// all-or-nothing rule read the whole row as lyrics and the chords were stored
/// as words.
///
/// Measured in a real browser over the corpus in `tools/fixtures/photos/`, that
/// one merge took `185-jezus-krisztusom` to **zero** chords found and cost
/// `app-jezus-szivedbe-lat` well over half of its. It is the reason
/// `songbook_app/tool/browser_reader_harness.dart` exists: unit tests fake the
/// recognizer, so nothing here could see it.
///
/// The tests that matter most in this file are the ones that prove the split
/// *cannot* cut up prose.
void main() {
  const bridge = PhotoTextBridge();

  /// A word whose glyphs sit at [gaps]-separated boxes, [width] each.
  ///
  /// `letters` is what the engine reported as one word; the boxes are laid out
  /// left to right with the gap before each glyph taken from [gaps].
  OcrWord merged(String letters,
      {double width = 10, List<double> gaps = const [], double y = 100}) {
    final symbols = <OcrWord>[];
    var x = 0.0;
    for (var i = 0; i < letters.length; i++) {
      x += i == 0 ? 0 : (i - 1 < gaps.length ? gaps[i - 1] : 1.0);
      symbols.add(OcrWord(
          text: letters[i], x0: x, y0: y, x1: x + width, y1: y + 20));
      x += width;
    }
    return OcrWord(
      text: letters,
      x0: symbols.first.x0,
      y0: y,
      x1: symbols.last.x1,
      y1: y + 20,
      symbols: symbols,
    );
  }

  List<String> textsOf(List<OcrWord> words) =>
      words.map((w) => w.text).toList();

  group('a merged run of chords is pulled apart', () {
    test('DGD becomes D, G and D', () {
      // The exact case from 185-jezus-krisztusom, which reported no chords at
      // all before this.
      final split = bridge.splitMergedChords(
          [merged('DGD', gaps: [12, 12])]);
      expect(textsOf(split), ['D', 'G', 'D']);
    });

    test('the pieces keep the glyph boxes they came from', () {
      final split = bridge.splitMergedChords([merged('DG', gaps: [12])]);
      expect(split.first.x1, lessThan(split.last.x0),
          reason: 'the second piece must start after the first ends');
      expect(split.first.y0, 100);
      expect(split.last.y1, 120);
    });

    test('a dash fused to a chord splits into punctuation and chord', () {
      // `D - C` printed tightly arrives as `-C` after the D.
      final split = bridge.splitMergedChords([merged('-C', gaps: [12])]);
      expect(textsOf(split), ['-', 'C']);
    });

    test('a whole turnaround splits', () {
      final split = bridge.splitMergedChords(
          [merged('G-C-D-C', gaps: [12, 12, 12, 12, 12, 12])]);
      expect(textsOf(split), ['G', '-', 'C', '-', 'D', '-', 'C']);
    });

    test('a bracketed chord is left whole, because it already reads', () {
      // `(C)` is a chord symbol as it stands — ChordSheetParser unwraps the
      // brackets — so there is nothing to undo and cutting it would only make
      // three pieces where one worked.
      final split =
          bridge.splitMergedChords([merged('(C)', gaps: [12, 12])]);
      expect(textsOf(split), ['(C)']);
    });

    test('a turnaround ending in a bracketed chord splits', () {
      // The real row from app-jezus-szivedbe-lat: `G - C - D - ( C )`, which
      // the engine returned as one word.
      final split = bridge.splitMergedChords(
          [merged('G-C-D-(C)', gaps: List.filled(8, 12))]);
      expect(textsOf(split), ['G', '-', 'C', '-', 'D', '-', '(', 'C', ')']);
    });
  });

  group('and prose is left alone', () {
    test('a Hungarian word is never cut, however its glyphs sit', () {
      // The guard that matters: every piece would have to be a chord, and
      // `sz`, `ívem` and `ben` are not.
      final split = bridge.splitMergedChords(
          [merged('szívemben', gaps: [12, 12, 12, 12, 12, 12, 12, 12])]);
      expect(textsOf(split), ['szívemben']);
    });

    test('Am is not cut into A and m', () {
      // `A` is a chord and `m` names no pitch, so the all-or-nothing check
      // refuses the split even with a wide gap between the two glyphs.
      final split = bridge.splitMergedChords([merged('Am', gaps: [14])]);
      expect(textsOf(split), ['Am']);
    });

    test('a word that is already a chord is never touched', () {
      // `Em7`'s glyphs are as tightly spaced as `DGD`'s, and `Cadd9`'s are not.
      // Neither may be split, because both already read correctly.
      for (final chord in ['Em7', 'Cadd9', 'D7', 'Bbmaj7', 'C#m']) {
        final split = bridge.splitMergedChords(
            [merged(chord, gaps: List.filled(chord.length - 1, 14))]);
        expect(textsOf(split), [chord], reason: chord);
      }
    });

    test('Ha is not cut into H and a', () {
      // Both halves *are* chord tokens, so only the gap test stands between
      // this and a lyric turning into two chords. Normal letter spacing is
      // nowhere near the gate.
      final split = bridge.splitMergedChords([merged('Ha', gaps: [1])]);
      expect(textsOf(split), ['Ha']);
    });
  });

  group('the split is conservative', () {
    test('glyphs at ordinary letter spacing are one word', () {
      final split = bridge.splitMergedChords([merged('DGD', gaps: [1, 1])]);
      expect(textsOf(split), ['DGD']);
    });

    test('a word with no symbols reported is returned untouched', () {
      // An engine that does not report glyph boxes must lose nothing.
      const word = OcrWord(text: 'DGD', x0: 0, y0: 0, x1: 30, y1: 20);
      expect(textsOf(bridge.splitMergedChords([word])), ['DGD']);
    });

    test('a single glyph cannot be a merge', () {
      final split = bridge.splitMergedChords([merged('D')]);
      expect(textsOf(split), ['D']);
    });

    test('an empty list stays empty', () {
      expect(bridge.splitMergedChords([]), isEmpty);
    });
  });

  group('the reading changes as a result', () {
    List<OcrWord> lyricRow(String text, double y) => [
          OcrWord(text: text, x0: 0, y0: y, x1: 10.0 * text.length, y1: y + 20),
        ];

    test('a row that was lyrics becomes chords over the line below', () {
      // End to end: before the split this emitted `DGD` as a line of words and
      // the song imported with no chords on it.
      final reading = bridge.read([
        merged('DGD', gaps: [24, 24], y: 100),
        ...lyricRow('vagy Te minden utamon.', 140),
      ]);
      expect(reading.chordPro, contains('D'));
      expect(reading.chordPro, isNot(contains('DGD')));
      expect(reading.notices,
          isNot(contains(
              const ImportNotice(ImportNoticeCode.photoNoChords))));
    });

    test('and a row of prose still reads as prose', () {
      final reading = bridge.read([
        merged('szívemben', gaps: [24, 24, 24, 24, 24, 24, 24, 24], y: 100),
        ...lyricRow('vagy Te minden utamon.', 140),
      ]);
      expect(reading.chordPro, contains('szívemben'));
    });
  });
}
