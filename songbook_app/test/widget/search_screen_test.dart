import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/search/search_screen.dart';

import 'helpers.dart';

void main() {
  final songs = [
    makeTestSong(number: 42, title: 'Mint a szép híves patakra'),
    makeTestSong(number: 151, title: 'Uram Isten, siess'),
  ];

  Future<void> pumpSearch(WidgetTester tester) async {
    await pumpScreen(
      tester,
      const SearchScreen(),
      overrides: [songsProvider.overrideWith((ref) async => songs)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the search field with hint', (tester) async {
    await pumpSearch(tester);
    expect(find.text('Search by number, title, or reference...'),
        findsOneWidget);
  });

  testWidgets('typing a query shows matching results', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'uram');
    await tester.pumpAndSettle();

    expect(find.text('Uram Isten, siess'), findsOneWidget);
    expect(find.text('Mint a szép híves patakra'), findsNothing);
  });

  testWidgets('searching by number shows the exact song', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '42');
    await tester.pumpAndSettle();

    expect(find.text('Mint a szép híves patakra'), findsOneWidget);
    expect(find.text('Uram Isten, siess'), findsNothing);
  });

  testWidgets('non-matching query shows the no-results state',
      (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'nincs ilyen');
    await tester.pumpAndSettle();

    expect(find.text('No songs found'), findsOneWidget);
  });

  testWidgets('clear button resets the query', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'uram');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.clear), findsNothing);
    expect(find.text('Uram Isten, siess'), findsNothing);
  });
}
