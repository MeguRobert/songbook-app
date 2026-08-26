import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/chord_sheet_parser.dart';
import 'package:songbook_app/presentation/widgets/import/line_list.dart';

import 'helpers.dart';

/// The editable line list, which is what makes this screen the gold editor.
///
/// Two things can be done to a row and they are not equally useful. Tapping a
/// chord to correct it is the common repair by a wide margin — the reader
/// misreads a glyph now and then, `Csus2` coming back as `5US2` on
/// `125-nincs-mas-isten`, and once the token is right the parser classifies the
/// row on its own with a real chord in storage. Saying what kind a whole row is
/// is the fallback, for a row the rule cannot be talked into reading correctly.
void main() {
  const parser = ChordSheetParser();

  /// A row the rule genuinely refuses: one chord and one unreadable token is
  /// under the tolerance floor, so the whole row falls to lyrics.
  const sheet = 'Em    5US2\n'
      'Az Úr irgalma végtelen';

  ({List<(int, LineKind?)> kinds, List<(int, int, String)> tokens}) taps() =>
      (kinds: <(int, LineKind?)>[], tokens: <(int, int, String)>[]);

  Future<void> pumpList(
    WidgetTester tester, {
    String text = sheet,
    LineKinds kinds = const LineKinds.none(),
    void Function(int, LineKind?)? onKind,
    void Function(int, int, String)? onToken,
  }) =>
      pumpScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: LineList(
              text: text,
              kinds: kinds,
              onKind: onKind ?? (_, __) {},
              onToken: onToken ?? (_, __, ___) {},
            ),
          ),
        ),
      );

  group('what each row says it is', () {
    test('the fixture really does read as lyrics', () {
      // The premise of half this file. Asserted rather than assumed, because
      // `D 5US2 G` would NOT need an override - the tolerance rule accepts one
      // odd stray beside two chords.
      expect(parser.isChordLine('Em    5US2'), isFalse);
      expect(parser.isChordLine('D     5US2   G'), isTrue);
    });

    testWidgets('a chord row is badged as chords and shown as chips',
        (tester) async {
      await pumpList(tester, text: 'D     G\nAz Úr irgalma');
      await tester.pumpAndSettle();

      expect(find.text('chords'), findsWidgets);
      // Each token is its own tappable thing.
      expect(find.text('D'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
    });

    testWidgets('a lyric row is shown as its own text, not split up',
        (tester) async {
      await pumpList(tester, text: 'D     G\nAz Úr irgalma');
      await tester.pumpAndSettle();

      expect(find.text('Az Úr irgalma'), findsOneWidget);
    });

    testWidgets('a token the rule cannot spell is marked', (tester) async {
      // The one worth tapping, so it is the one that stands out.
      await pumpList(tester,
          text: 'Em    5US2', kinds: const LineKinds({0: LineKind.chords}));
      await tester.pumpAndSettle();

      final marked = tester.widget<Text>(find.text('5US2'));
      expect(marked.style?.decoration, TextDecoration.underline);
      final fine = tester.widget<Text>(find.text('Em'));
      expect(fine.style?.decoration, isNull);
    });
  });

  group('changing a row’s kind', () {
    testWidgets('tapping chords on a lyric row asks for the override',
        (tester) async {
      final seen = taps();
      await pumpList(tester, onKind: (i, k) => seen.kinds.add((i, k)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'chords').first);
      await tester.pumpAndSettle();

      expect(seen.kinds, [(0, LineKind.chords)]);
    });

    testWidgets('tapping the kind a row already is hands it back to the parser',
        (tester) async {
      // So an override can always be undone by the control that made it, rather
      // than being a one-way door.
      final seen = taps();
      await pumpList(tester,
          kinds: const LineKinds({0: LineKind.chords}),
          onKind: (i, k) => seen.kinds.add((i, k)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'chords').first);
      await tester.pumpAndSettle();

      expect(seen.kinds, [(0, null)]);
    });

    testWidgets('an overridden row is badged differently from a decided one',
        (tester) async {
      await pumpList(tester, kinds: const LineKinds({0: LineKind.chords}));
      await tester.pumpAndSettle();

      // The tooltip is the visible difference: one of them is a person's answer
      // and the other is a guess, and only the guess is worth arguing with.
      expect(
          find.byWidgetPredicate((w) => w is Tooltip && w.message == 'you set this'),
          findsOneWidget);
    });
  });

  group('correcting a token', () {
    testWidgets('tapping a chip reports the line, the column and the token',
        (tester) async {
      final seen = taps();
      await pumpList(tester,
          text: 'Em    5US2',
          kinds: const LineKinds({0: LineKind.chords}),
          onToken: (i, c, t) => seen.tokens.add((i, c, t)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('5US2'));
      await tester.pumpAndSettle();

      // Column 6, which is where `5US2` starts - the column IS the chord's
      // position, so the caller needs it to splice a replacement in.
      expect(seen.tokens, [(0, 6, '5US2')]);
    });

    testWidgets('a lyric row has no chips to tap', (tester) async {
      final seen = taps();
      await pumpList(tester,
          text: 'Az Úr irgalma végtelen',
          onToken: (i, c, t) => seen.tokens.add((i, c, t)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Az Úr irgalma végtelen'));
      await tester.pumpAndSettle();

      expect(seen.tokens, isEmpty);
    });
  });

  group('the indexes stay honest', () {
    testWidgets('a blank line keeps its place in the numbering',
        (tester) async {
      // Line indexes are into the text counting blanks, because that is what
      // LineKinds means by an index. A blank shown as nothing would make the
      // list disagree with the parser about which line is which.
      final seen = taps();
      await pumpList(tester,
          text: 'Az Úr irgalma\n\nD     G',
          onKind: (i, k) => seen.kinds.add((i, k)));
      await tester.pumpAndSettle();

      // The last row is index 2, not 1.
      await tester.tap(find.widgetWithText(TextButton, 'words').last);
      await tester.pumpAndSettle();

      expect(seen.kinds, [(2, LineKind.lyric)]);
    });
  });
}
