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
    expect(find.text('PREVIEW'), findsOneWidget);
    // Two blank-line-separated blocks became two verses.
    expect(find.text('2 verses'), findsOneWidget);
  });

  testWidgets('the preview is the real ChordView, not a lookalike',
      (tester) async {
    await pumpImport(tester);
    await pasteAndParse(tester, _twoLine);
    // Entering a title is what makes the draft valid enough to render.
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Az Úrra bízom életem');
    await tester.pumpAndSettle();

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

  testWidgets('parser warnings are surfaced, not swallowed', (tester) async {
    await pumpImport(tester);
    // A lone bare root is ambiguous, so the parser keeps it as lyrics and
    // warns. That warning has to reach the user while it is still cheap to fix.
    await pasteAndParse(tester, 'A\nEgy sor szöveg');

    // Wording adapts to the count ('this line' / 'these lines'), so match
    // the invariant: the warning block is on screen.
    expect(find.textContaining('Check'), findsWidgets);

    // And the warning itself, run through the localised formatter. The parser
    // reports a CODE now, so a screen that forgot to format one would show
    // nothing at all here rather than English — which the heading above cannot
    // tell you, since it was already translated.
    expect(
      find.textContaining(
          'Line 1: "A" could be a one-chord line or a lyric; kept as a lyric.'),
      findsOneWidget,
    );
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

  testWidgets('Save becomes available once a title is given', (tester) async {
    await pumpImport(tester);
    await pasteAndParse(tester, _twoLine);

    TextButton saveButton() => tester.widget<TextButton>(
          find.ancestor(
              of: find.text('Save'), matching: find.byType(TextButton)),
        );
    expect(saveButton().onPressed, isNull, reason: 'no title yet');

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Az Úrra bízom életem');
    await tester.pumpAndSettle();

    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('the preview actually renders the chords, not just the lyrics',
      (tester) async {
    // Regression: ChordView gated chord rendering on Verse.hasNotation, which
    // is false for every imported song. Chords parsed correctly and were then
    // silently dropped on the way to the screen — in the real song view too,
    // not only here.
    await pumpImport(tester);
    await pasteAndParse(tester, _twoLine);
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Az Úrra bízom életem');
    await tester.pumpAndSettle();

    expect(find.text('G'), findsWidgets);
    expect(find.text('C'), findsWidgets);
    expect(find.text('D'), findsWidgets);
  });
}
