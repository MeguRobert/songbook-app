import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/core/constants/engraving_constants.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_layout.dart';

/// Vertical space between staff systems.
///
/// The advance from one system to the next was a fixed sum — staff bottom, one
/// lyric row, a margin, the system gap — computed without ever looking at
/// whether the system had lyrics. That is wrong in both directions:
///
///   - An engraved score commonly carries no `<lyric>` elements at all; its
///     syllables hang off the individual beats and there are none. Every system
///     of an imported score still reserved a lyric row nothing was drawn in,
///     which is the large vertical gap visible on SÉ-90.
///   - A score with three verses stacked under the notes needs three rows, and
///     got one, so the second and third ran into the system below.
void main() {
  SheetMusicLayoutEngine engine({double width = 2000}) =>
      SheetMusicLayoutEngine(
        availableWidth: width,
        transposePitch: (pitch, _) => pitch,
        transposeChord: (chord, _) => chord,
        showChords: false,
      );

  /// One measure whose single note carries [syllables] stacked lyric lines.
  NotatedMeasure measure({List<String>? syllables, bool lineBreakAfter = true}) {
    return NotatedMeasure(
      beats: [
        NotatedBeat(
          pitch: 'G4',
          duration: NoteDuration.whole,
          syllable: syllables?.first,
          syllables: syllables != null && syllables.length > 1
              ? syllables
              : null,
        ),
      ],
      lineBreakAfter: lineBreakAfter,
    );
  }

  SongNotation notationOf(List<NotatedMeasure> measures) => SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [NotatedVerse(number: 1, measures: measures)],
      );

  /// Vertical distance between the first two systems.
  double gapOf(SheetMusicLayout layout) =>
      layout.systems[1].y - layout.systems[0].y;

  group('a system with no lyrics', () {
    test('sits closer to the next than one with lyrics does', () {
      final withLyrics = engine().calculateLayout(
        notationOf([measure(syllables: ['Mint']), measure(syllables: ['a'])]),
        0,
      );
      final without = engine()
          .calculateLayout(notationOf([measure(), measure()]), 0);

      expect(withLyrics.systems, hasLength(2), reason: 'the fixture premise');
      expect(without.systems, hasLength(2), reason: 'the fixture premise');
      expect(gapOf(without), lessThan(gapOf(withLyrics)));
    });

    test('still leaves room below the staff for stems and ledger lines', () {
      final layout =
          engine().calculateLayout(notationOf([measure(), measure()]), 0);

      final firstStaffBottom = layout.systems[0].staffBottom;
      expect(layout.systems[1].y - firstStaffBottom,
          greaterThanOrEqualTo(EngravingConstants.systemSpacing));
    });

    test('makes the whole score shorter', () {
      final withLyrics = engine().calculateLayout(
        notationOf([measure(syllables: ['Mint']), measure(syllables: ['a'])]),
        0,
      );
      final without = engine()
          .calculateLayout(notationOf([measure(), measure()]), 0);

      expect(without.totalHeight, lessThan(withLyrics.totalHeight));
    });
  });

  group('a system with several stacked lyric lines', () {
    test('pushes the next system further down than one line does', () {
      final oneLine = engine().calculateLayout(
        notationOf([measure(syllables: ['Mint']), measure(syllables: ['a'])]),
        0,
      );
      final threeLines = engine().calculateLayout(
        notationOf([
          measure(syllables: ['Mint', 'Kél', 'Jöjj']),
          measure(syllables: ['a', 'a', 'el']),
        ]),
        0,
      );

      expect(gapOf(threeLines), greaterThan(gapOf(oneLine)));
    });

    test('leaves room for every row, not just the first', () {
      final layout = engine().calculateLayout(
        notationOf([
          measure(syllables: ['Mint', 'Kél', 'Jöjj']),
          measure(syllables: ['a', 'a', 'el']),
        ]),
        0,
      );

      // The lowest syllable of the first system must clear the top of the
      // second. This is the collision the fixed one-row reservation caused.
      final lowest = layout.systems[0].syllables
          .map((s) => s.y)
          .reduce((a, b) => a > b ? a : b);
      expect(lowest, lessThan(layout.systems[1].y));
    });
  });

  test('one lyric line spaces systems exactly as it always did', () {
    // A regression guard on every bundled song: they all have one lyric line,
    // and this fix must not move them a pixel.
    final layout = engine().calculateLayout(
      notationOf([measure(syllables: ['Mint']), measure(syllables: ['a'])]),
      0,
    );

    expect(
      gapOf(layout),
      EngravingConstants.staffHeight +
          EngravingConstants.lyricBelowStaff +
          EngravingConstants.lyricRowHeight +
          EngravingConstants.systemSpacing,
    );
  });
}
