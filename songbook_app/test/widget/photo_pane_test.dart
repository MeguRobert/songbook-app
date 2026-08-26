import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/widgets/import/photo_pane.dart';

import 'helpers.dart';

/// The photograph a reading came from, shown beside the reading.
///
/// The gold editor in `tools/ocr_harness` has had this from the first day and it
/// is the single thing that makes correcting a page tractable: a chord in the
/// wrong column, a lost accent, a row read as lyrics are all obvious next to the
/// page and none of them are visible without it. The app read the bytes and
/// dropped them.
///
/// A `PhotoPane` and not part of the screen, because the file picker is a
/// platform channel that a widget test cannot drive — so the only way to cover
/// what a picked photograph looks like is to hand it one directly.
void main() {
  /// The smallest thing `Image.memory` will decode: a 1x1 PNG.
  final onePixelPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  Future<void> pumpPane(WidgetTester tester, {String? name}) => pumpScreen(
        tester,
        Scaffold(
          body: PhotoPane(bytes: onePixelPng, height: 200, name: name),
        ),
      );

  testWidgets('it shows the photograph under its own heading', (tester) async {
    await pumpPane(tester);
    await tester.pumpAndSettle();

    expect(find.text('PHOTO'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('it can be zoomed, because the reason to look is one character',
      (tester) async {
    await pumpPane(tester);
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer));
    expect(viewer.maxScale, greaterThan(1));
    // Clipped rather than free: the page is being compared with the reading
    // beside it, and a photograph escaping its box over the top of that is worse
    // than not being able to fling it about.
    expect(viewer.clipBehavior, Clip.hardEdge);
    expect(find.textContaining('zoom'), findsOneWidget);
  });

  testWidgets('it names the file when there is a name', (tester) async {
    await pumpPane(tester, name: '105-kosz-jol-vagyok.jpg');
    await tester.pumpAndSettle();

    expect(find.textContaining('105-kosz-jol-vagyok.jpg'), findsOneWidget);
  });

  testWidgets('it keeps its height so the row beside it does not jump',
      (tester) async {
    await pumpPane(tester);
    await tester.pumpAndSettle();

    // Not `.first`, which is a 4px spacer: the one that matters is the box the
    // image lives in.
    expect(
        find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == 200,
            description: 'the pane holding the image at its given height'),
        findsOneWidget);
  });

  testWidgets('bytes that do not decode do not take the review down',
      (tester) async {
    // The reading is already in hand by the time this is built, and it is the
    // thing being reviewed. A photograph that will not decode is a shame, not a
    // reason to lose the import.
    await pumpScreen(
      tester,
      Scaffold(
        body: PhotoPane(
          bytes: Uint8List.fromList(const [1, 2, 3, 4]),
          height: 200,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text('PHOTO'), findsOneWidget);
  });
}
