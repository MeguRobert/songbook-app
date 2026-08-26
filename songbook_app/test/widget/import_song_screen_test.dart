import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';
import 'package:songbook_app/presentation/screens/song_view/widgets/chord_view.dart';

import 'helpers.dart';

/// The paste-to-import flow. The parser itself is covered exhaustively in
/// `chord_sheet_parser_test.dart`; these check the screen wires it up, guesses
/// only what it should, and refuses to save an incomplete song.
const _twoLine = '''
G       C
Az Úrra bízom életem

G       D
Ő megtart engem
''';

Future<void> pumpImport(WidgetTester tester) async {
  await pumpScreen(tester, const ImportSongScreen());
  await tester.pumpAndSettle();
}

Future<void> pasteAndParse(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Parse'));
  await tester.pumpAndSettle();
}

/// Scrolls the preview into view.
///
/// It sits below the fold, and a ListView does not build what is not on screen —
/// so `find.text('PREVIEW')` reports it missing when it is perfectly correct,
/// two rows further down. What is above it has changed more than once (a "More
/// ways to add" expander, then the sheet-music question under the Photo button),
/// which is the argument for scrolling rather than counting on the layout.
Future<void> revealPreview(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('PREVIEW'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// Names the song and scrolls the preview into view.
///
/// A title is what makes the draft valid enough to render at all.
Future<void> nameAndRevealPreview(WidgetTester tester, String title) async {
  await tester.enterText(find.widgetWithText(TextField, 'Title'), title);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('PREVIEW'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Save is disabled until there is something to save',
      (tester) async {
    await pumpImport(tester);

    final save = tester.widget<TextButton>(
      find.ancestor(of: find.text('Save'), matching: find.byType(TextButton)),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('parsing reveals the details form and a live preview',
      (tester) async {
    await pumpImport(tester);
    await pasteAndParse(tester, _twoLine);

    expect(find.text('DETAILS'), findsOneWidget);
    await revealPreview(tester);
    expect(find.text('PREVIEW'), findsOneWidget);
    // Two blank-line-separated blocks became two verses.
    expect(find.text('2 verses'), findsOneWidget);
  });

  testWidgets('the preview is the real ChordView, not a lookalike',
      (tester) async {
    await pumpImport(tester);
    await pasteAndParse(tester, _twoLine);
    await nameAndRevealPreview(tester, 'Az Úrra bízom életem');

    // Same widget the song view uses, so what is approved here is what ships.
    expect(find.byType(ChordView), findsOneWidget);
  });

  testWidgets('a title directive prefills the field but typing wins',
      (tester) async {
    await pumpImport(tester);
    await pasteAndParse(tester, '{title: Régi cím}\n[G]Egy sor');

    expect(find.widgetWithText(TextField, 'Régi cím'), findsOneWidget);

    // Correcting the guess, then re-parsing, must not revert the correction.
    await tester.enterText(
        find.widgetWithText(TextField, 'Régi cím'), 'Saját cím');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Saját cím'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Régi cím'), findsNothing);
  });

  testWidgets('the key is guessed from the first chord and says so',
      (tester) async {
    await pumpImport(tester);
    await pasteAndParse(tester, _twoLine);

    expect(find.textContaining('Key guessed as G'), findsOneWidget);
  });

  testWidgets('a lone root is read as a chord, not warned about', (tester) async {
    await pumpImport(tester);
    // The rule that kept a one-letter line as lyrics is gone: no hymnal line is
    // one character long, and it cost four real chords across two pages of the
    // measurement corpus. The rare misread is the moderation queue's job.
    await pasteAndParse(tester, 'A\nEgy sor szöveg');

    expect(find.textContaining('could be a one-chord line'), findsNothing);
  });

  testWidgets('Hungarian lyrics are not eaten as chords', (tester) async {
    await pumpImport(tester);
    await pasteAndParse(tester, 'Csak Egy Az\nÉs még egy sor');
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Teszt');
    await tester.pumpAndSettle();

    // The words survive intact in the preview rather than being parsed as
    // C, E and A.
    expect(find.textContaining('Csak Egy Az'), findsWidgets);
  });

  TextButton saveButtonIn(WidgetTester tester) => tester.widget<TextButton>(
        find.ancestor(of: find.text('Save'), matching: find.byType(TextButton)),
      );

  String fieldText(WidgetTester tester, String label) => tester
      .widget<TextField>(find.widgetWithText(TextField, label))
      .controller!
      .text;

  testWidgets('Save needs a number as well as a title', (tester) async {
    // The number used to be optional, and a missing one was stored as 0 —
    // which is not "no number" to anything downstream. It sorts ahead of every
    // real song and prints as a number in the list.
    await pumpImport(tester);
    await pasteAndParse(tester, _twoLine);

    expect(saveButtonIn(tester).onPressed, isNull, reason: 'no title yet');

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Az Úrra bízom életem');
    await tester.pumpAndSettle();
    expect(saveButtonIn(tester).onPressed, isNull,
        reason: 'title but still no number');

    await tester.enterText(find.widgetWithText(TextField, 'Number'), '147');
    await tester.pumpAndSettle();
    expect(saveButtonIn(tester).onPressed, isNotNull);
  });

  testWidgets('a number that is not a whole number above zero is refused',
      (tester) async {
    await pumpImport(tester);
    await pasteAndParse(tester, _twoLine);
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Az Úrra bízom életem');

    for (final bad in ['0', '-3', 'abc']) {
      await tester.enterText(find.widgetWithText(TextField, 'Number'), bad);
      await tester.pumpAndSettle();
      expect(saveButtonIn(tester).onPressed, isNull, reason: bad);
    }
  });

  testWidgets('a number worn at the front of the title moves to the number box',
      (tester) async {
    // What a photographed page gives you: "147. Isten fénye". Kept whole it
    // became the title, and the number box stayed empty.
    await pumpImport(tester);
    await pasteAndParse(tester, '{title: 147. Isten fénye}\n[G]Fény ragyog');
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'Title'), 'Isten fénye');
    expect(fieldText(tester, 'Number'), '147');
  });

  testWidgets('a title that merely begins with digits keeps them',
      (tester) async {
    await pumpImport(tester);
    await pasteAndParse(tester, '{title: 10 000 angyal}\n[G]Fény ragyog');
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'Title'), '10 000 angyal');
    expect(fieldText(tester, 'Number'), isEmpty);
  });

  testWidgets('the preview actually renders the chords, not just the lyrics',
      (tester) async {
    // Regression: ChordView gated chord rendering on Verse.hasNotation, which
    // is false for every imported song. Chords parsed correctly and were then
    // silently dropped on the way to the screen — in the real song view too,
    // not only here.
    await pumpImport(tester);
    await pasteAndParse(tester, _twoLine);
    await nameAndRevealPreview(tester, 'Az Úrra bízom életem');

    expect(find.text('G'), findsWidgets);
    expect(find.text('C'), findsWidgets);
    expect(find.text('D'), findsWidgets);
  });
}
