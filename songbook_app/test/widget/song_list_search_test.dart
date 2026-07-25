import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_list/song_list_screen.dart';
import 'package:songbook_app/presentation/screens/song_list/widgets/searchable_app_bar.dart';

import 'helpers.dart';

/// Search moved out of its own route and into the song list's app bar. These
/// cover the behaviour the retired `search_screen_test.dart` covered, plus the
/// in-place expansion and the lyrics fallback.
void main() {
  Song withLyrics(int number, String title, List<String> lines) => Song(
        number: number,
        title: title,
        originalKey: 'C',
        verses: [
          Verse(
            number: 1,
            lines: [for (final t in lines) LyricLine(text: t)],
          ),
        ],
      );

  final songs = [
    withLyrics(42, 'Mint a szép híves patakra', ['a szarvas kívánkozik']),
    withLyrics(151, 'Uram Isten, siess', ['ne késsél segítségemmel']),
  ];

  Future<void> pumpSongs(WidgetTester tester) async {
    await pumpScreen(
      tester,
      const SongListScreen(),
      overrides: [songsProvider.overrideWith((ref) async => songs)],
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
  }

  group('opening and closing', () {
    testWidgets('the list shows its title and no field until search is tapped',
        (tester) async {
      await pumpSongs(tester);

      expect(find.text('Songbook'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tapping search reveals a field in the app bar itself',
        (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SearchableAppBar),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
        reason: 'the field belongs to the app bar, not a pushed route',
      );
    });

    testWidgets('the field holds focus once open', (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus, isTrue);
      expect(field.autofocus, isTrue);
    });

    testWidgets('the reveal is animated, not instant', (tester) async {
      await pumpSongs(tester);
      await tester.tap(find.byIcon(Icons.search));

      await tester.pump(); // start
      await tester.pump(const Duration(milliseconds: 60));
      final midway = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(SearchableAppBar),
              matching: find.byType(Opacity),
            )
            .last,
      );
      expect(midway.opacity, greaterThan(0.0));
      expect(midway.opacity, lessThan(1.0));

      await tester.pumpAndSettle();
    });

    testWidgets('closing search restores the title and clears the filter',
        (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 'uram');
      await tester.pumpAndSettle();
      expect(find.text('Mint a szép híves patakra'), findsNothing);

      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();

      // A collapsed bar must not leave an invisible query narrowing the list.
      expect(find.text('Songbook'), findsOneWidget);
      expect(find.text('Mint a szép híves patakra'), findsOneWidget);
      expect(find.text('Uram Isten, siess'), findsOneWidget);
    });
  });

  group('querying', () {
    testWidgets('a title query filters the list in place', (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 'uram');
      await tester.pumpAndSettle();

      expect(find.text('Uram Isten, siess'), findsOneWidget);
      expect(find.text('Mint a szép híves patakra'), findsNothing);
    });

    testWidgets('a number query shows the exact song', (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), '42');
      await tester.pumpAndSettle();

      expect(find.text('Mint a szép híves patakra'), findsOneWidget);
      expect(find.text('Uram Isten, siess'), findsNothing);
    });

    testWidgets('a query matching nothing at all shows the empty state',
        (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 'villamos');
      await tester.pumpAndSettle();

      expect(find.text('No songs found'), findsOneWidget);
    });

    testWidgets('the clear button empties the field and restores the list',
        (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 'uram');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.text('Mint a szép híves patakra'), findsOneWidget);
    });
  });

  group('lyrics fallback', () {
    testWidgets('a phrase found only in the lyrics still finds the song',
        (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 'szarvas');
      await tester.pumpAndSettle();

      expect(find.text('Mint a szép híves patakra'), findsOneWidget);
      expect(find.text('Uram Isten, siess'), findsNothing);
    });

    testWidgets('the matching line is shown so the hit explains itself',
        (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 'szarvas');
      await tester.pumpAndSettle();

      expect(find.text('a szarvas kívánkozik'), findsOneWidget);
      expect(find.textContaining('found in the lyrics'), findsOneWidget);
    });

    testWidgets('a title match never shows the lyrics banner', (tester) async {
      await pumpSongs(tester);
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 'patakra');
      await tester.pumpAndSettle();

      expect(find.text('Mint a szép híves patakra'), findsOneWidget);
      expect(find.textContaining('found in the lyrics'), findsNothing);
    });
  });
}
