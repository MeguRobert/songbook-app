import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_list/song_list_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('renders the song list with titles and numbers',
      (tester) async {
    final songs = [
      makeTestSong(number: 1, title: 'First Song'),
      makeTestSong(number: 2, title: 'Second Song'),
    ];
    await pumpScreen(
      tester,
      const SongListScreen(),
      overrides: [songsProvider.overrideWith((ref) async => songs)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Songbook'), findsOneWidget);
    expect(find.text('First Song'), findsOneWidget);
    expect(find.text('Second Song'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no songs',
      (tester) async {
    await pumpScreen(
      tester,
      const SongListScreen(),
      overrides: [songsProvider.overrideWith((ref) async => [])],
    );
    await tester.pumpAndSettle();

    expect(find.text('No songs available'), findsOneWidget);
    expect(find.byIcon(Icons.music_off), findsOneWidget);
  });

  testWidgets('shows a loading indicator while songs load', (tester) async {
    final never = Completer<List<Song>>();
    await pumpScreen(
      tester,
      const SongListScreen(),
      overrides: [
        songsProvider.overrideWith((ref) => never.future),
      ],
    );
    // No settle: the future never completes within the test.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
