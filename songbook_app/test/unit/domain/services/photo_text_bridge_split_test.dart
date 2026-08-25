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
      {double width = 10,
      List<double> gaps = const [],
      double y = 100,
      double x0 = 0}) {
    final symbols = <OcrWord>[];
    var x = x0;
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

  group('a row that turns out to be chords after all', () {
    // The gate that opens a word is a proportion of that word's own glyphs, and
    // it cannot be lowered: measured over the corpus, Hungarian `ha` carries a
    // gap of 0.38 of its glyph width and `125-nincs-mas-isten`'s `CGD` needs
    // 0.42 cut. So a second attempt is made with no gate at all, and what keeps
    // it safe is not geometry but the VERDICT: the cut is kept only if it turns
    // a row that did not read as chords into one that does.
    //
    // Calibrated the way every rule in this family has been - against every line
    // of every gold file and of every song the app ships, 284 of them, this
    // flips **none**. `be de` would indeed cut to `b e d e`, and no line in the
    // songbook is `be de`.
    test('CGD becomes C, G and D once the row is asked', () {
      // 125-nincs-mas-isten: 26 px glyphs with gaps of 13 and 11, so the 0.6
      // gate of 15.6 never opens the word and the first pass does nothing.
      final row = [
        merged('Em', width: 26, gaps: [3]),
        merged('CGD', width: 26, gaps: [13, 11], x0: 400),
      ];
      expect(textsOf(bridge.asChordRow(row)), ['Em', 'C', 'G', 'D']);
    });

    test('CDG too, with its two equal gaps', () {
      final row = [
        merged('Em', width: 26, gaps: [3]),
        merged('CDG', width: 26, gaps: [12, 12], x0: 400),
      ];
      expect(textsOf(bridge.asChordRow(row)), ['Em', 'C', 'D', 'G']);
    });

    test('a row already reading as chords is handed back untouched', () {
      final row = [
        merged('Em', width: 26, gaps: [3]),
        merged('C', width: 26, x0: 400),
      ];
      expect(bridge.asChordRow(row), same(row));
    });

    test('a line of words is handed back untouched', () {
      // `De hogyha ezen futsz` - `De` does cut to `D` and `e`, both perfectly
      // good chords, and the row still has three words in it, so the verdict
      // does not flip and the cut is thrown away.
      final row = [
        merged('De', width: 26, gaps: [4]),
        merged('hogyha', width: 26, gaps: [5, 5, 5, 5, 5], x0: 200),
        merged('ezen', width: 26, gaps: [5, 5, 5], x0: 500),
        merged('futsz', width: 26, gaps: [5, 5, 5, 5], x0: 700),
      ];
      expect(textsOf(bridge.asChordRow(row)),
          ['De', 'hogyha', 'ezen', 'futsz']);
    });

    test('a two-word line whose words are note letters is left alone', () {
      // The sharp edge of the rule, and the reason the guard is the verdict
      // rather than the geometry: `ha` and `de` both cut into bare note
      // letters. What saves the line is that the row it is in has words in it.
      final row = [
        merged('Ha', width: 26, gaps: [4]),
        merged('nem', width: 26, gaps: [5, 5], x0: 200),
        merged('tudod', width: 26, gaps: [5, 5, 5, 5], x0: 400),
      ];
      expect(textsOf(bridge.asChordRow(row)), ['Ha', 'nem', 'tudod']);
    });
  });

  group('the glyph boxes survive the page being straightened', () {
    // `deskew` used to rebuild every word through `movedTo`, which dropped
    // `symbols` - so by the time rows were grouped there were no glyph boxes
    // left to cut a merged run on. That is why the second attempt could not
    // exist until now.
    test('a deskewed word still knows where its glyphs are', () {
      final word = merged('CGD', width: 26, gaps: [13, 11]);
      final straight = bridge.deskew([word], 2.0);
      expect(straight.single.symbols, hasLength(3));
    });

    test('and the gaps between them are unchanged', () {
      final word = merged('CGD', width: 26, gaps: [13, 11]);
      final before = [
        for (var i = 1; i < word.symbols.length; i++)
          word.symbols[i].x0 - word.symbols[i - 1].x1,
      ];
      final after = bridge.deskew([word], 2.0).single.symbols;
      final gaps = [
        for (var i = 1; i < after.length; i++) after[i].x0 - after[i - 1].x1,
      ];
      expect(gaps, before);
    });
  });

  group('a piece that is not a chord is cut again', () {
    // `185-jezus-krisztusom` returns `D G D` as the single word `DGD`, glyphs
    // 52 px wide with gaps of 46 and 30. The gate is 0.6 of the glyph width -
    // 31.2 - so the first gap cuts and the second misses **by 1.2 pixels**. That
    // left `D` and `GD`, `GD` is not a chord symbol, and the all-or-nothing
    // guard threw the whole split away: the row read as a lyric line, which is
    // both that page's extra line and most of its 0.600 chord recall.
    //
    // Measured over every multi-glyph word on all nine pages of the corpus, the
    // gate cannot simply be lowered: the Hungarian `ha` of `151-zengjed-a-dalt`
    // carries a gap of 0.38 of its glyph width and the `CGD` of
    // `125-nincs-mas-isten` needs 0.42 cut. A gate between them would be luck.
    //
    // So the gate stays where it is and keeps deciding which words are even
    // candidates - `De` at 0.15 and `ha` at 0.38 never open at all - and a piece
    // that comes out of an opened word without reading as a chord is cut once
    // more at its own widest gap.
    test('DGD becomes D, G and D even when the second gap misses the gate', () {
      // The real geometry: 52 px glyphs, gaps of 46 and 30, gate 31.2.
      final split = bridge.splitMergedChords(
          [merged('DGD', width: 52, gaps: [46, 30])]);
      expect(textsOf(split), ['D', 'G', 'D']);
    });

    test('the pieces keep the columns they were printed in', () {
      final split = bridge.splitMergedChords(
          [merged('DGD', width: 52, gaps: [46, 30])]);
      expect(split[0].x1, lessThan(split[1].x0));
      expect(split[1].x1, lessThan(split[2].x0));
    });

    test('a piece that cannot become chords abandons the whole split', () {
      // `bőrömbe` on 105-kosz-jol-vagyok: 20 px glyphs, one gap of 16 that
      // clears the gate of 12. It cuts to `bő` + `römbe`, and `bő` cuts again
      // to `b` - a chord - and `ő`, which is not one. All or nothing still.
      final split = bridge.splitMergedChords(
          [merged('bőrömbe', width: 20, gaps: [8, 16, 2, 2, 5, 3])]);
      expect(textsOf(split), ['bőrömbe']);
    });

    test('a word the gate never opens is never a candidate', () {
      // This is the guard that matters, and it is the gate rather than the chord
      // check. `De` and `ha` and `be` and `de` are ordinary Hungarian words that
      // would partition into bare note letters, and their gaps are 0.14 to 0.38
      // of their glyph width - nowhere near 0.6. Measured on 084-van-egy-ut,
      // 151-zengjed-a-dalt, 125-nincs-mas-isten and 166-tekozlo-fiu.
      for (final (text, width, gap) in [
        ('De', 27.0, 4.0),
        ('Ha', 28.5, 5.0),
        ('ha', 10.5, 4.0),
        ('be', 24.5, -10.0),
        ('de', 19.0, -5.0),
      ]) {
        final split = bridge
            .splitMergedChords([merged(text, width: width, gaps: [gap])]);
        expect(textsOf(split), [text],
            reason: '$text must not become two chords');
      }
    });

    test('prose the gate does open still cannot become chords', () {
      // `ici-picit` on 084-van-egy-ut: 9 px glyphs, every gap between 6 and 8,
      // so a gate of 5.4 cuts it into all nine of its letters. `i` is not a
      // chord and cannot be cut further, so the split is abandoned - which is
      // what has always happened, and this is the test that says the new
      // recursion did not change it.
      final split = bridge.splitMergedChords(
          [merged('ici-picit', width: 9, gaps: [7, 7, 7, 6, 8, 6, 7, 7])]);
      expect(textsOf(split), ['ici-picit']);
    });

    test('the recursion terminates on a single glyph', () {
      final split = bridge.splitMergedChords(
          [merged('xy', width: 20, gaps: [40])]);
      expect(textsOf(split), ['xy']);
    });
  });

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
