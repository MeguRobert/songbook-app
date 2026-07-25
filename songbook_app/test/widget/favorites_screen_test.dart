import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/favorites/favorites_screen.dart';

import 'helpers.dart';

String favoritesJson(List<int> numbers) => json.encode([
      for (var i = 0; i < numbers.length; i++)
        {
          'songNumber': numbers[i],
          'addedAt': '2026-01-01T00:00:00.000',
          'sortOrder': i,
        },
    ]);

void main() {
  final songs = [
    makeTestSong(number: 1, title: 'Not a favorite'),
    makeTestSong(number: 42, title: 'A favorite song'),
  ];

  testWidgets('shows the empty state when there are no favorites',
      (tester) async {
    await pumpScreen(
      tester,
      const FavoritesScreen(),
      overrides: [songsProvider.overrideWith((ref) async => songs)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.text('Browse Songs'), findsOneWidget);
  });

  testWidgets('lists only favorited songs', (tester) async {
    await pumpScreen(
      tester,
      const FavoritesScreen(),
      prefs: {'favorites': favoritesJson([42])},
      overrides: [songsProvider.overrideWith((ref) async => songs)],
    );
    await tester.pumpAndSettle();

    expect(find.text('A favorite song'), findsOneWidget);
    expect(find.text('Not a favorite'), findsNothing);
    expect(find.byIcon(Icons.favorite), findsWidgets);
  });
}
