import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/recent_searches_provider.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_list/song_list_screen.dart';

import 'helpers.dart';

/// Recently *searched*, in place of recently *viewed*.
///
/// The recents rail sat above the song list and cost a row of vertical space on
/// every visit to the screen you spend most time on, to answer a question — "what
/// did I open last?" — that the list itself mostly answers. What is genuinely
/// tedious is retyping a query, and that is only ever wanted at the moment the
/// search field is open and empty, where nothing was being shown at all.

Song song(int number, String title, String lyric) => Song(
      number: number,
      title: title,
      originalKey: 'C',
      verses: [
        Verse(number: 1, lines: [LyricLine(text: lyric)]),
      ],
    );

final songs = [
  song(42, 'Mint a szép híves patakra', 'a szarvas kívánkozik'),
  song(151, 'Uram Isten, siess', 'ne késsél segítségemmel'),
];

Future<void> pumpList(
  WidgetTester tester, {
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

Future<void> openSearch(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.search));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the recently-viewed rail is gone from the list', (tester) async {
    await pumpList(tester);

    // The rail widget is deleted, so this asserts on what it used to render.
    expect(find.text('Recently viewed'), findsNothing);
    expect(find.text('Recent'), findsNothing);
    // The list itself is untouched.
    expect(find.text('Mint a szép híves patakra'), findsOneWidget);
  });

  group('while searching', () {
    testWidgets('an empty field offers nothing until there is a history',
        (tester) async {
      await pumpList(tester);
      await openSearch(tester);

      // No empty "Recent searches" heading standing over nothing.
      expect(find.text('Recent searches'), findsNothing);
    });

    testWidgets('a query is remembered once a result is opened', (tester) async {
      // Through a real router, because the recording hangs off the same tap that
      // navigates — a router-less harness cannot reach it at all.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        songsProvider.overrideWith((ref) async => songs),
      ]);
      addTearDown(container.dispose);
      final router = GoRouter(initialLocation: '/', routes: [
        GoRoute(path: '/', builder: (_, __) => const SongListScreen()),
        GoRoute(
            path: '/song/:id',
            builder: (_, __) => const Scaffold(body: Text('SONG'))),
      ]);
      addTearDown(router.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: localizedRouterApp(router),
      ));
      await tester.pumpAndSettle();

      await openSearch(tester);
      await tester.enterText(find.byType(TextField), 'szarvas');
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsNothing,
          reason: 'not while there are results to look at');

      await tester.tap(find.text('Mint a szép híves patakra'));
      await tester.pumpAndSettle();

      expect(container.read(recentSearchesProvider), ['szarvas']);
    });

    testWidgets('tapping a remembered query runs it again', (tester) async {
      await pumpList(tester, prefs: const {
        'recent_searches': '["szarvas"]',
      });
      await openSearch(tester);
      await tester.tap(find.text('szarvas'));
      await tester.pumpAndSettle();

      expect(find.text('Mint a szép híves patakra'), findsWidgets);
      expect(find.text('Uram Isten, siess'), findsNothing);
    });

    testWidgets('the history can be cleared', (tester) async {
      await pumpList(tester, prefs: const {
        'recent_searches': '["szarvas","isten"]',
      });
      await openSearch(tester);
      expect(find.text('szarvas'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Recent searches'), findsNothing);
      expect(find.text('szarvas'), findsNothing);
    });
  });
}
