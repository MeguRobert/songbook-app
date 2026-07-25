import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_list/song_list_screen.dart';

import 'helpers.dart';

/// Books and tags stopped being pushed screens and became sheets over the
/// list. These cover what the retired `tag_browser_screen_test.dart` covered,
/// plus the one-tap escape from a book filter.
void main() {
  Song song(int number, {List<String> tags = const [], String? book}) => Song(
        number: number,
        title: 'Song $number',
        originalKey: 'C',
        verses: const [],
        tags: tags,
        book: book,
      );

  Future<void> pumpSongs(
    WidgetTester tester,
    List<Song> songs, {
    Map<String, Object> prefs = const {},
  }) async {
    await pumpScreen(
      tester,
      const SongListScreen(),
      prefs: prefs,
      overrides: [songsProvider.overrideWith((ref) async => songs)],
    );
    await tester.pumpAndSettle();
  }

  group('tag filter sheet', () {
    final tagged = [
      song(1, tags: ['praise', 'advent']),
      song(2, tags: ['praise']),
    ];

    Future<void> openTagSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Tags'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists every tag with its song count', (tester) async {
      await pumpSongs(tester, tagged);
      await openTagSheet(tester);

      expect(find.text('praise (2)'), findsOneWidget);
      expect(find.text('advent (1)'), findsOneWidget);
    });

    testWidgets('shows the empty state when no song has tags', (tester) async {
      await pumpSongs(tester, [song(1), song(2)]);
      await openTagSheet(tester);

      expect(find.text('No tags yet'), findsOneWidget);
    });

    testWidgets('picking a tag filters the list without leaving it',
        (tester) async {
      await pumpSongs(tester, tagged);
      await openTagSheet(tester);

      await tester.tap(find.text('advent (1)'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(SongListScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Song 1'), findsOneWidget);
      expect(find.text('Song 2'), findsNothing);
    });

    testWidgets('an active tag is always visible as a removable chip',
        (tester) async {
      await pumpSongs(tester, tagged);
      await openTagSheet(tester);
      await tester.tap(find.text('advent (1)'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(SongListScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, 'advent'), findsOneWidget);

      await tester.tap(find.text('Clear tags'));
      await tester.pumpAndSettle();

      expect(find.text('Song 2'), findsOneWidget);
    });
  });

  group('book filter', () {
    final books = [
      song(1, book: 'Zsoltárok'),
      song(2, book: 'Dicséretek'),
    ];

    testWidgets('no back button is offered while showing all songs',
        (tester) async {
      await pumpSongs(tester, books);

      expect(find.text('Songbook'), findsOneWidget);
      expect(find.byTooltip('Back to all songs'), findsNothing);
    });

    testWidgets('a selected book titles the bar and offers a back button',
        (tester) async {
      await pumpSongs(tester, books,
          prefs: {'settings_selected_book': 'Zsoltárok'});

      expect(find.text('Zsoltárok'), findsOneWidget);
      expect(find.byTooltip('Back to all songs'), findsOneWidget);
      expect(find.text('Song 1'), findsOneWidget);
      expect(find.text('Song 2'), findsNothing);
    });

    testWidgets('that back button returns to all songs in one tap',
        (tester) async {
      await pumpSongs(tester, books,
          prefs: {'settings_selected_book': 'Zsoltárok'});

      await tester.tap(find.byTooltip('Back to all songs'));
      await tester.pumpAndSettle();

      expect(find.text('Songbook'), findsOneWidget);
      expect(find.byTooltip('Back to all songs'), findsNothing);
      expect(find.text('Song 1'), findsOneWidget);
      expect(find.text('Song 2'), findsOneWidget);
    });

    testWidgets('the book sheet selects a book without leaving the list',
        (tester) async {
      await pumpSongs(tester, books);

      await tester.tap(find.byTooltip('Books'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dicséretek'));
      await tester.pumpAndSettle();

      expect(find.text('Dicséretek'), findsOneWidget);
      expect(find.text('Song 2'), findsOneWidget);
      expect(find.text('Song 1'), findsNothing);
    });
  });

  group('app bar action order', () {
    testWidgets('search sits leftmost in the trailing group', (tester) async {
      await pumpSongs(tester, [song(1)]);

      final searchX = tester.getCenter(find.byIcon(Icons.search)).dx;
      final booksX = tester.getCenter(find.byTooltip('Books')).dx;
      final tagsX = tester.getCenter(find.byTooltip('Tags')).dx;

      expect(searchX, lessThan(booksX));
      expect(booksX, lessThan(tagsX));
    });
  });
}
