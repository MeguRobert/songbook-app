import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_painter.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_renderer.dart';

import 'helpers.dart';

/// The engraved sheet has to fit the phone it opens on.
///
/// The layout engine spaces measures to a minimum practical width and puts 2–4
/// of them on a system, so on a narrow screen a system comes out wider than the
/// viewport. Nothing scaled it back down, so the sheet loaded overflowing and had
/// to be pinched *out* before it could be read — reported as "sheet music is too
/// big on phone when it loads".

/// Wide on purpose: enough measures that a system cannot fit a 360 px phone.
SongNotation wideNotation() => SongNotation(
      originalKey: 'C',
      timeSignature: '4/4',
      verses: [
        NotatedVerse(
          number: 1,
          measures: [
            for (var m = 0; m < 8; m++)
              NotatedMeasure(beats: [
                for (final pitch in ['C4', 'D4', 'E4', 'F4'])
                  NotatedBeat(
                      pitch: pitch,
                      duration: NoteDuration.quarter,
                      syllable: 'la'),
              ]),
          ],
        ),
      ],
    );

Song wideSong() => Song(
      number: 1,
      title: 'Wide',
      originalKey: 'C',
      notation: wideNotation(),
      verses: const [Verse(number: 1, plainText: 'x')],
    );

/// The engraved canvas, which is the thing that must not overflow.
final canvasFinder = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is SheetMusicPainter);

Future<Size> pumpAt(
  WidgetTester tester,
  double width, {
  double textScale = 1.0,
}) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: SizedBox(
        width: width,
        child: SheetMusicRenderer(
          song: wideSong(),
          notation: wideNotation(),
          textScale: textScale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.getSize(canvasFinder);
}

void main() {
  testWidgets('fits the width it is given on first paint', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final size = await pumpAt(tester, 360);

    expect(size.width, lessThanOrEqualTo(360.5),
        reason: 'the sheet must not open wider than the phone');
  });

  testWidgets('a wider screen gets a proportionally wider sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final narrow = await pumpAt(tester, 360);
    final wide = await pumpAt(tester, 720);

    // Fitting must not mean "always shrink to one fixed size": a tablet should
    // use the room it has.
    expect(wide.width, greaterThan(narrow.width));
    expect(wide.width, lessThanOrEqualTo(720.5));
  });

  testWidgets('zoom still enlarges it past the fit', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fitted = await pumpAt(tester, 360);
    final zoomed = await pumpAt(tester, 360, textScale: 2.0);

    // Fit sets where zoom starts from, it does not cap it — pinching out has to
    // keep working, and scroll horizontally as it always did.
    expect(zoomed.width, closeTo(fitted.width * 2, 1.0));
  });
}
