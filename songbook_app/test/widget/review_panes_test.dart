import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/widgets/content_pane.dart';
import 'package:songbook_app/presentation/widgets/import/review_panes.dart';

import 'helpers.dart';

/// The photograph beside the reading - or above it, when there is no room.
///
/// This is tested on its own because the decision it makes could not be seen
/// from the screen: the breakpoint was 900, the screen's pane is capped at 800,
/// and so the side-by-side branch was dead code from the day it shipped. Every
/// widget test passed. It was found by building the app and looking at it.
void main() {
  const photoKey = Key('photo');
  const previewKey = Key('preview');

  Future<void> pumpAt(WidgetTester tester, double width, {bool photo = true}) =>
      pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ReviewPanes(
                photo: photo
                    ? const SizedBox(key: photoKey, height: 100)
                    : null,
                preview: const SizedBox(key: previewKey, height: 100),
              ),
            ),
          ),
        ),
      );

  testWidgets('with no photograph there is only the preview', (tester) async {
    await pumpAt(tester, 800, photo: false);
    await tester.pumpAndSettle();

    expect(find.byKey(previewKey), findsOneWidget);
    expect(find.byKey(photoKey), findsNothing);
    expect(
      find.descendant(of: find.byType(ReviewPanes), matching: find.byType(Row)),
      findsNothing,
    );
  });

  testWidgets('side by side wherever the screen’s own pane allows it', (
    tester,
  ) async {
    // 768 is what the import screen actually hands over on a desktop window:
    // ContentWidths.list less the padding. If this stacks, no window of any
    // size will ever show the two beside each other.
    await pumpAt(tester, 768);
    await tester.pumpAndSettle();

    final photo = tester.getTopLeft(find.byKey(photoKey));
    final preview = tester.getTopLeft(find.byKey(previewKey));
    expect(photo.dy, preview.dy, reason: 'the same row');
    expect(photo.dx, lessThan(preview.dx), reason: 'photograph first');
  });

  testWidgets('stacked on a phone, photograph first', (tester) async {
    await pumpAt(tester, 390);
    await tester.pumpAndSettle();

    final photo = tester.getTopLeft(find.byKey(photoKey));
    final preview = tester.getTopLeft(find.byKey(previewKey));
    expect(photo.dx, preview.dx, reason: 'the same column');
    expect(
      photo.dy,
      lessThan(preview.dy),
      reason: 'a phone is where photos get taken; the page comes first',
    );
  });

  test('the breakpoint is one the screen can reach', () {
    // Pinned, with the arithmetic: the pane is ContentWidths.list wide and the
    // screen pads it by 16 a side. A breakpoint above 768 can never be met.
    expect(
      ReviewPanes.sideBySideAt,
      lessThanOrEqualTo(ContentWidths.list - 32),
    );
  });
}
