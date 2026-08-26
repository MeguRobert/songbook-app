import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';
import 'package:songbook_app/presentation/widgets/import/line_list.dart';

import 'helpers.dart';

/// The line list wired to the screen: an action, a re-parse, a changed preview.
///
/// `line_list_test.dart` covers what the widget reports. This covers what the
/// screen does about it, which is the part that can put a wrong chord into
/// storage.
void main() {
  /// A row the rule refuses - one chord and one unreadable token is under the
  /// tolerance floor - over a line of words.
  const misread = 'Em    5US2\n'
      'Az Úr irgalma végtelen';

  Future<void> pasteAndParse(WidgetTester tester, String text) async {
    await pumpScreen(tester, const ImportSongScreen());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();
  }

  /// The chip for [token] in the line list - not the same text in the paste box
  /// above it, which is why this exists.
  Finder chip(String token) => find.descendant(
      of: find.byType(LineList), matching: find.text(token));

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  /// The paste box, scrolled back into being. A ListView does not build what is
  /// off screen, so after working in the line list the box does not exist to
  /// read until it is on screen again.
  Future<TextField> pasteBox(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('PASTE THE SONG'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    return tester.widget<TextField>(find.byType(TextField).first);
  }

  testWidgets('the list appears once there is something parsed',
      (tester) async {
    await pasteAndParse(tester, misread);
    await reveal(tester, find.text('LINES'));

    expect(find.text('LINES'), findsOneWidget);
    // Both rows read as words, which is the defect being corrected.
    expect(find.widgetWithText(TextButton, 'words'), findsNWidgets(2));
  });

  testWidgets('making a row chords changes what the preview holds',
      (tester) async {
    await pasteAndParse(tester, misread);
    await reveal(tester, find.text('LINES'));

    // Before: two lines of words, so the lyric shows on its own.
    expect(find.text('Em    5US2'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'chords').first);
    await tester.pumpAndSettle();

    // After: the row is chords over the line under it, so the raw row is no
    // longer shown as a lyric anywhere - it became chips plus a preview.
    await reveal(tester, find.text('LINES'));
    expect(find.widgetWithText(TextButton, 'chords'), findsNWidgets(2));
  });

  testWidgets('correcting a token rewrites the box and keeps the columns',
      (tester) async {
    await pasteAndParse(tester, misread);
    await reveal(tester, find.text('LINES'));

    // Make it a chord row first, so the token is a tappable chip.
    await tester.tap(find.widgetWithText(TextButton, 'chords').first);
    await tester.pumpAndSettle();
    await reveal(tester, chip('5US2'));

    await tester.tap(chip('5US2'));
    await tester.pumpAndSettle();

    expect(find.text('Correct this chord'), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'Csus2');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // The box now holds the correction, and `Em` has not moved: the replacement
    // is spliced at the token's own column, so only what is to its right shifts.
    final box = await pasteBox(tester);
    expect(box.controller?.text, startsWith('Em    Csus2'));
  });

  testWidgets('an empty correction is a cancel', (tester) async {
    // Deleting a chord is what the words box is for; doing it from here would
    // silently shorten the row.
    await pasteAndParse(tester, misread);
    await reveal(tester, find.text('LINES'));
    await tester.tap(find.widgetWithText(TextButton, 'chords').first);
    await tester.pumpAndSettle();
    await reveal(tester, chip('5US2'));

    await tester.tap(chip('5US2'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final box = await pasteBox(tester);
    expect(box.controller?.text, misread);
  });

  testWidgets('Parse again forgets every override', (tester) async {
    // An override belongs to the text it was made against, and line 7 is a
    // different line after a re-read.
    await pasteAndParse(tester, misread);
    await reveal(tester, find.text('LINES'));
    await tester.tap(find.widgetWithText(TextButton, 'chords').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Parse'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('LINES'));

    // Back to the parser's own answer: both rows words again.
    expect(find.widgetWithText(TextButton, 'words'), findsNWidgets(2));
  });
}
