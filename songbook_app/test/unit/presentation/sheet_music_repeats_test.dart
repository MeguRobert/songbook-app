import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_layout.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_painter.dart';

/// The layout side of repeat signs and volta brackets.
///
/// [NotatedMeasure] carried `repeatStart` and `repeatEnd` from the beginning, but
/// only `repeatEnd` was ever drawn: the layout engine hard-coded `repeatStart` to
/// its default on every bar line it built, so a left repeat could not appear
/// however the model was populated. Voltas had no representation at all.
///
/// These are engine tests rather than golden images. What matters is that the
/// engine *decides* to put a repeat on the right bar line and spans a bracket
/// over the right measures; where exactly the dots land is the painter's, and a
/// pixel assertion on that is a test of Bravura, not of this code.
void main() {
  // Identity transposition: these tests are about bar lines, and a transposing
  // stub would only make the fixtures harder to read.
  SheetMusicLayoutEngine engine({double width = 400}) => SheetMusicLayoutEngine(
        availableWidth: width,
        transposePitch: (pitch, _) => pitch,
        transposeChord: (chord, _) => chord,
      );

  NotatedMeasure measure({
    bool repeatStart = false,
    bool repeatEnd = false,
    int? volta,
  }) {
    return NotatedMeasure(
      beats: const [
        NotatedBeat(pitch: 'G4', duration: NoteDuration.whole),
      ],
      repeatStart: repeatStart,
      repeatEnd: repeatEnd,
      volta: volta,
    );
  }

  SongNotation notationOf(List<NotatedMeasure> measures) => SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [NotatedVerse(number: 1, measures: measures)],
      );

  group('repeat bar lines', () {
    test('a closing repeat marks the bar line after its measure', () {
      final layout = engine()
          .calculateLayout(notationOf([measure(repeatEnd: true), measure()]), 0);

      final withRepeatEnd =
          layout.systems.expand((s) => s.barLines).where((b) => b.repeatEnd);
      expect(withRepeatEnd, hasLength(1));
    });

    test('an opening repeat marks the bar line before its measure', () {
      // Measure 2 opens the repeat, so the mark belongs on the line between
      // measures 1 and 2 — not on a line of its own, and not after measure 2.
      final layout = engine().calculateLayout(
          notationOf([measure(), measure(repeatStart: true)]), 0);

      final lines = layout.systems.single.barLines;
      final opening = lines.where((b) => b.repeatStart).toList();
      expect(opening, hasLength(1));
      // Second of the three lines: opening-of-system, between, end-of-system.
      expect(lines.indexOf(opening.single), 1);
    });

    test('an opening repeat on the very first measure marks the opening line',
        () {
      final layout = engine()
          .calculateLayout(notationOf([measure(repeatStart: true)]), 0);

      expect(layout.systems.single.barLines.first.repeatStart, isTrue);
    });

    test('back-to-back repeats put both marks on one bar line', () {
      // The `:||:` of a hymn whose refrain repeats straight into the next verse.
      final layout = engine().calculateLayout(
        notationOf([measure(repeatEnd: true), measure(repeatStart: true)]),
        0,
      );

      final shared = layout.systems.single.barLines
          .where((b) => b.repeatStart && b.repeatEnd);
      expect(shared, hasLength(1));
    });

    test('a score with no repeats marks no bar line', () {
      final layout =
          engine().calculateLayout(notationOf([measure(), measure()]), 0);

      final marked = layout.systems
          .expand((s) => s.barLines)
          .where((b) => b.repeatStart || b.repeatEnd);
      expect(marked, isEmpty);
    });
  });

  group('volta brackets', () {
    test('a run of measures sharing a number becomes one bracket', () {
      // Wide enough that all three measures share a system: a run split by a
      // line break is deliberately two brackets, which the last test covers.
      final layout = engine(width: 2000).calculateLayout(
        notationOf([
          measure(),
          measure(volta: 1),
          measure(volta: 1),
        ]),
        0,
      );

      expect(layout.systems, hasLength(1), reason: 'the fixture premise');
      final voltas = layout.systems.single.voltas;
      expect(voltas, hasLength(1));
      expect(voltas.single.number, 1);
    });

    test('two different numbers become two brackets', () {
      final layout = engine().calculateLayout(
        notationOf([
          measure(volta: 1, repeatEnd: true),
          measure(volta: 2),
        ]),
        0,
      );

      final voltas = layout.systems.expand((s) => s.voltas).toList();
      expect(voltas.map((v) => v.number), [1, 2]);
    });

    test('a bracket spans from the start of its first measure to the end of '
        'its last', () {
      final layout = engine(width: 2000).calculateLayout(
        notationOf([measure(), measure(volta: 1), measure(volta: 1)]),
        0,
      );

      expect(layout.systems, hasLength(1), reason: 'the fixture premise');
      final volta = layout.systems.single.voltas.single;
      expect(volta.endX, greaterThan(volta.startX));
      // It starts after the first (unbracketed) measure, so it cannot begin at
      // the left margin.
      expect(volta.startX, greaterThan(layout.systems.first.x));
    });

    test('a bracket that continues past a line break is drawn on both systems',
        () {
      // An engraver splits the bracket too. Each half gets a hook only at the
      // end that is a real end of the run.
      final layout = engine(width: 400).calculateLayout(
        notationOf([
          NotatedMeasure(
            beats: const [NotatedBeat(pitch: 'G4', duration: NoteDuration.whole)],
            volta: 1,
            lineBreakAfter: true,
          ),
          measure(volta: 1),
        ]),
        0,
      );

      expect(layout.systems, hasLength(2), reason: 'the fixture premise');
      final first = layout.systems[0].voltas.single;
      final second = layout.systems[1].voltas.single;
      expect(first.number, 1);
      expect(second.number, 1);
      expect(first.hasStartHook, isTrue);
      expect(first.hasEndHook, isFalse, reason: 'the run continues below');
      expect(second.hasStartHook, isFalse, reason: 'the run began above');
      expect(second.hasEndHook, isTrue);
    });

    test('a score with no voltas produces no brackets', () {
      final layout =
          engine().calculateLayout(notationOf([measure(), measure()]), 0);

      expect(layout.systems.expand((s) => s.voltas), isEmpty);
    });
  });

  group('spacing', () {
    test('a closing repeat widens its measure to fit the dots', () {
      // The dots go to the LEFT of a closing repeat's thick line, so without
      // reserved space they land on the last note head of the bar.
      final plain =
          engine(width: 2000).calculateLayout(notationOf([measure()]), 0);
      final repeated = engine(width: 2000)
          .calculateLayout(notationOf([measure(repeatEnd: true)]), 0);

      expect(repeated.systems.single.barLines.last.x,
          greaterThan(plain.systems.single.barLines.last.x));
    });

    test('an opening repeat pushes the first note clear of the dots', () {
      // Mirror image: these dots go to the RIGHT of the system's opening line,
      // which already sits only 5px before the first note.
      final plain =
          engine(width: 2000).calculateLayout(notationOf([measure()]), 0);
      final repeated = engine(width: 2000)
          .calculateLayout(notationOf([measure(repeatStart: true)]), 0);

      expect(repeated.systems.single.notes.first.x,
          greaterThan(plain.systems.single.notes.first.x));
    });
  });

  group('the engraved output', () {
    // The painter itself is checked with a browser screenshot, not here: a pixel
    // assertion on a Bravura glyph tests the font. What a test CAN catch is the
    // painter throwing — a null volta number, a hook drawn off a system with no
    // measures — which is why this paints for real rather than inspecting.
    testWidgets('paints repeats and voltas without throwing', (tester) async {
      final notation = notationOf([
        measure(repeatStart: true),
        measure(volta: 1, repeatEnd: true),
        measure(volta: 2),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: CustomPaint(
          size: const Size(400, 300),
          painter: SheetMusicPainter(
            layout: engine().calculateLayout(notation, 0),
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

    testWidgets('paints a volta on a system with no measures at all',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CustomPaint(
          size: const Size(400, 300),
          painter: SheetMusicPainter(
            layout: engine().calculateLayout(notationOf(const []), 0),
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
