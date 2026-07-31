import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/core/constants/engraving_constants.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_layout.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_painter.dart';

/// Engraving every voice of a four-part score at once, on stacked staves.
///
/// The single-voice path spaces each measure from its own notes, which is why
/// this could not be done by simply calling it four times: soprano and bass would
/// land their bar lines at different x and the score would read as *wrong* rather
/// than as unfinished. The whole point of these tests is the shared horizontal
/// grid — every voice's note at the same moment in the bar sits at the same x,
/// and one bar line serves the whole group.
void main() {
  SheetMusicLayoutEngine engine({double width = 2000}) =>
      SheetMusicLayoutEngine(
        availableWidth: width,
        transposePitch: (pitch, _) => pitch,
        transposeChord: (chord, _) => chord,
      );

  NotatedMeasure quarters(List<String> pitches,
          {bool lineBreakAfter = false,
          bool repeatEnd = false,
          int? volta,
          List<String?>? syllables}) =>
      NotatedMeasure(
        beats: [
          for (var i = 0; i < pitches.length; i++)
            NotatedBeat(
              pitch: pitches[i],
              duration: NoteDuration.quarter,
              syllable: syllables == null ? null : syllables[i],
            ),
        ],
        lineBreakAfter: lineBreakAfter,
        repeatEnd: repeatEnd,
        volta: volta,
      );

  NotatedMeasure halves(List<String> pitches) => NotatedMeasure(
        beats: [
          for (final pitch in pitches)
            NotatedBeat(pitch: pitch, duration: NoteDuration.half),
        ],
      );

  /// A four-part hymn: soprano in quarters with words, alto in quarters, tenor
  /// and bass in halves. The differing rhythms are the point — a shared grid is
  /// only interesting when the voices do not agree on where the beats are.
  SongNotation satb({
    bool lineBreakAfterFirst = false,
    bool repeatEndOnFirst = false,
    int? voltaOnSecond,
  }) =>
      SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            quarters(['G4', 'A4', 'B4', 'C5'],
                lineBreakAfter: lineBreakAfterFirst,
                repeatEnd: repeatEndOnFirst,
                syllables: ['Ó', 'jöjj', 'jöjj', 'el']),
            quarters(['C5', 'B4', 'A4', 'G4'], volta: voltaOnSecond),
          ]),
        ],
        voices: [
          NotatedVoice(name: 'Alto', measures: [
            quarters(['E4', 'E4', 'D4', 'E4']),
            quarters(['E4', 'D4', 'C4', 'E4']),
          ]),
          NotatedVoice(name: 'Tenor', measures: [
            halves(['C4', 'B3']),
            halves(['A3', 'C4']),
          ]),
          NotatedVoice(name: 'Bass', measures: [
            halves(['C3', 'G2']),
            halves(['F2', 'C3']),
          ]),
        ],
      );

  group('the grand staff', () {
    test('lays out one staff per voice', () {
      final layout = engine().calculateGrandStaffLayout(satb(), 0);

      expect(layout.systems, hasLength(4));
      expect(layout.systems.map((s) => s.label),
          ['Melody', 'Alto', 'Tenor', 'Bass']);
    });

    test('every staff of one line of music shares a system index', () {
      // The painter draws the time signature on the first system only. With four
      // staves to a line, "first" has to mean the line, not the staff, or three
      // of the four would silently lose it.
      final layout = engine().calculateGrandStaffLayout(satb(), 0);

      expect(layout.systems.map((s) => s.systemIndex), [0, 0, 0, 0]);
    });

    test('the staves stack downwards, each clear of the one above', () {
      final layout = engine().calculateGrandStaffLayout(satb(), 0);

      for (var i = 1; i < layout.systems.length; i++) {
        expect(layout.systems[i].y,
            greaterThanOrEqualTo(layout.systems[i - 1].contentBottom),
            reason: 'staff $i overlaps the content of staff ${i - 1}');
      }
    });

    test('a line break in the melody breaks every voice at the same bar', () {
      // Repeats, voltas and system breaks belong to the BAR, not to the line
      // singing it, so the melody's structure decides for the whole group.
      final layout = engine(width: 400)
          .calculateGrandStaffLayout(satb(lineBreakAfterFirst: true), 0);

      expect(layout.systems.map((s) => s.systemIndex),
          [0, 0, 0, 0, 1, 1, 1, 1]);
      for (final system in layout.systems) {
        expect(system.endMeasure, system.startMeasure,
            reason: 'one measure to a line, per the fixture');
      }
    });
  });

  group('the shared horizontal grid', () {
    test('voices agreeing on a beat put their notes at the same x', () {
      final layout = engine().calculateGrandStaffLayout(satb(), 0);
      final melody = layout.systems[0];
      final bass = layout.systems[3];

      // Bass halves fall on beats 1 and 3 of each bar, so they coincide with the
      // melody's 1st and 3rd quarters.
      expect(bass.notes[0].x, melody.notes[0].x);
      expect(bass.notes[1].x, melody.notes[2].x);
      expect(bass.notes[2].x, melody.notes[4].x);
    });

    test('every staff of a line is the same width', () {
      // Bar lines are drawn once for the group, so a staff that disagreed about
      // its width would have staff lines running past them.
      final layout = engine().calculateGrandStaffLayout(satb(), 0);

      expect(layout.systems.map((s) => s.width).toSet(), hasLength(1));
      expect(layout.systems.map((s) => s.x).toSet(), hasLength(1));
    });

    test('a bar line runs from the top staff to the bottom of the last', () {
      final layout = engine().calculateGrandStaffLayout(satb(), 0);
      final top = layout.systems.first;
      final bottom = layout.systems.last;

      expect(top.barLines, isNotEmpty);
      for (final line in top.barLines) {
        expect(line.topY, top.staffTop);
        expect(line.bottomY, bottom.staffBottom);
      }
    });

    test('the lower staves carry no bar lines of their own', () {
      // One line already covers them. Drawing per staff as well would double the
      // stroke inside every staff.
      final layout = engine().calculateGrandStaffLayout(satb(), 0);

      for (final system in layout.systems.skip(1)) {
        expect(system.barLines, isEmpty);
      }
    });

    test('a repeat gets one pair of dots per staff', () {
      // The bar line spans the whole group, so its own topY says nothing about
      // where the staves inside it are — without an anchor per staff every dot
      // would land on the top one.
      final layout = engine()
          .calculateGrandStaffLayout(satb(repeatEndOnFirst: true), 0);

      final repeat = layout.systems.first.barLines
          .where((b) => b.repeatEnd)
          .toList();
      expect(repeat, hasLength(1));
      expect(repeat.single.repeatDotStaffTops,
          layout.systems.map((s) => s.staffTop).toList());
    });

    test('a volta bracket is spanned once, over the top staff', () {
      final layout =
          engine().calculateGrandStaffLayout(satb(voltaOnSecond: 2), 0);

      expect(layout.systems.first.voltas, hasLength(1));
      for (final system in layout.systems.skip(1)) {
        expect(system.voltas, isEmpty);
      }
    });
  });

  group('clefs', () {
    test('a voice that lives below middle C is written in the bass clef', () {
      final layout = engine().calculateGrandStaffLayout(satb(), 0);

      expect(layout.systems.map((s) => s.clef), [
        StaffClef.treble, // melody, G4–C5
        StaffClef.treble, // alto, C4–E4
        StaffClef.bass, // tenor, A3–C4
        StaffClef.bass, // bass, F2–C3
      ]);
    });

    test('the bass clef puts G2 on the bottom line', () {
      // Treble reads the bottom line as E4 and bass as G2 — twelve diatonic
      // steps apart, which is the whole difference between the two clefs here.
      const bottom = 100.0;
      expect(
        EngravingConstants.getYPositionForPitch('G2', bottom,
            clef: StaffClef.bass),
        bottom,
      );
      expect(
        EngravingConstants.getYPositionForPitch('E4', bottom,
            clef: StaffClef.treble),
        bottom,
      );
    });

    test('the treble clef is unchanged by the clef argument being added', () {
      // Every existing caller relies on the default.
      const bottom = 100.0;
      for (final pitch in ['C4', 'F5', 'A3', 'B4']) {
        expect(
          EngravingConstants.getYPositionForPitch(pitch, bottom),
          EngravingConstants.getYPositionForPitch(pitch, bottom,
              clef: StaffClef.treble),
        );
      }
    });
  });

  group('lyrics', () {
    test('the words stay under the staff whose beats carry them', () {
      // Only the melody has syllables in an imported four-part score; the other
      // voices are notes alone. Rendering each staff's own words means the bass
      // does not repeat the soprano's text under it.
      final layout = engine().calculateGrandStaffLayout(satb(), 0);

      expect(layout.systems.first.syllables, isNotEmpty);
      for (final system in layout.systems.skip(1)) {
        expect(system.syllables, isEmpty);
      }
    });
  });

  group('degenerate input', () {
    test('a single-voice score is laid out exactly as it always was', () {
      // Nothing to stack, so this must not pay the grand staff's costs — no
      // label inset, no spanning bar lines.
      final notation = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [quarters(['G4', 'A4', 'B4', 'C5'])])
        ],
      );

      final grand = engine().calculateGrandStaffLayout(notation, 0);
      final plain = engine().calculateLayout(notation, 0);

      expect(grand.systems, hasLength(plain.systems.length));
      expect(grand.totalWidth, plain.totalWidth);
      expect(grand.systems.single.x, plain.systems.single.x);
      expect(grand.systems.single.notes.map((n) => n.x),
          plain.systems.single.notes.map((n) => n.x));
    });

    test('a score with no measures at all produces no staves', () {
      final layout = engine().calculateGrandStaffLayout(
        SongNotation(
          originalKey: 'C',
          timeSignature: '4/4',
          verses: const [NotatedVerse(number: 1, measures: [])],
          voices: const [NotatedVoice(name: 'Bass', measures: [])],
        ),
        0,
      );

      expect(layout.systems, isEmpty);
    });

    test('a voice longer than the melody keeps its extra bars', () {
      final layout = engine().calculateGrandStaffLayout(
        SongNotation(
          originalKey: 'C',
          timeSignature: '4/4',
          verses: [
            NotatedVerse(number: 1, measures: [quarters(['G4', 'A4'])])
          ],
          voices: [
            NotatedVoice(name: 'Bass', measures: [
              halves(['C3']),
              halves(['G2']),
            ]),
          ],
        ),
        0,
      );

      // Two lines of music: the melody runs out after the first, and the bass's
      // second bar must not be dropped.
      final bassNotes =
          layout.systems.where((s) => s.label == 'Bass').expand((s) => s.notes);
      expect(bassNotes, hasLength(2));
    });
  });

  group('the right-hand edge', () {
    // The staff lines used to be drawn to the system's full width while the final
    // bar line sat a right margin short of it, so every system ended with the
    // five lines poking out past the double bar. One staff made that a blemish;
    // four staves make it the first thing you see.
    test('a grand staff stops its lines at the bar line that closes it', () {
      final layout = engine().calculateGrandStaffLayout(satb(), 0);
      final top = layout.systems.first;

      expect(top.barLines, isNotEmpty, reason: 'the fixture premise');
      expect(top.staffLineEndX, closeTo(top.barLines.last.x, 0.01));
    });

    test('the lower staves end where the shared bar line does', () {
      // They carry no bar lines of their own, so this only holds because every
      // staff of a line shares one width.
      final layout = engine().calculateGrandStaffLayout(satb(), 0);
      final closing = layout.systems.first.barLines.last.x;

      for (final system in layout.systems) {
        expect(system.staffLineEndX, closeTo(closing, 0.01));
      }
    });

    test('a single staff does the same', () {
      final layout = engine().calculateLayout(
        SongNotation(
          originalKey: 'C',
          timeSignature: '4/4',
          verses: [
            NotatedVerse(number: 1, measures: [quarters(['G4', 'A4'])]),
          ],
        ),
        0,
      );
      final system = layout.systems.single;

      expect(system.staffLineEndX, closeTo(system.barLines.last.x, 0.01));
    });
  });

  group('what the painter is told to draw', () {
    // The painter itself is checked with a browser screenshot — a pixel
    // assertion on a Bravura glyph tests the font. What is testable is the
    // decisions it makes: which glyph, hung from which line, and where the
    // repeat dots go.
    test('each clef names its glyph and the line it hangs from', () {
      // Both are drawn from their own baseline, so one formula serves both: the
      // G clef's baseline is its G line, second from the bottom, and the F
      // clef's is its F line, fourth from the bottom.
      expect(StaffClef.treble.glyph, '');
      expect(StaffClef.treble.anchorLineFromTop, 3);
      expect(StaffClef.bass.glyph, '');
      expect(StaffClef.bass.anchorLineFromTop, 1);
    });

    test('a bar line serving one staff anchors its dots on that staff', () {
      const line =
          PositionedBarLine(x: 0, topY: 40, bottomY: 80, repeatEnd: true);
      expect(line.dotAnchors, [40.0]);
    });

    test('a bar line serving a group anchors dots on every staff it crosses',
        () {
      const line = PositionedBarLine(
        x: 0,
        topY: 40,
        bottomY: 300,
        repeatEnd: true,
        repeatDotStaffTops: [40, 130, 220],
      );
      expect(line.dotAnchors, [40.0, 130.0, 220.0]);
    });
  });

  group('the engraved output', () {
    // As with the repeats tests, this paints for real rather than asserting on
    // pixels: what a test can catch here is the painter throwing on a shape it
    // has never seen — a bar line taller than its own staff, a clef it does not
    // know, a staff label where none was ever drawn.
    testWidgets('paints a four-part score without throwing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CustomPaint(
          size: const Size(400, 800),
          painter: SheetMusicPainter(
            layout: engine().calculateGrandStaffLayout(
                satb(repeatEndOnFirst: true, voltaOnSecond: 2), 0),
            noteColor: const Color(0xFF000000),
            staffColor: const Color(0xFF000000),
            lyricColor: const Color(0xFF000000),
            chordColor: const Color(0xFF000000),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
