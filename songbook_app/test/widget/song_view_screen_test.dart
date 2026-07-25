import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('renders song title, lyrics and transposed chords in chord view',
      (tester) async {
    final song = makeTestSong();
    await pumpScreen(
      tester,
      const SongViewScreen(songNumber: 42),
      // Global config without notation -> ChordView (no sheet music assets).
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByNumberProvider.overrideWith(
            (ref, number) async => number == 42 ? song : null),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('42. Mint a szép híves patakra'), findsOneWidget);
    expect(find.textContaining('Mint a szép híves patakra'), findsWidgets);
    expect(find.text('Second verse plain text'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('toggling the favorite icon updates its state', (tester) async {
    final song = makeTestSong();
    await pumpScreen(
      tester,
      const SongViewScreen(songNumber: 42),
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByNumberProvider.overrideWith(
            (ref, number) async => number == 42 ? song : null),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('shows not-found for an unknown song number', (tester) async {
    await pumpScreen(
      tester,
      const SongViewScreen(songNumber: 999),
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByNumberProvider.overrideWith((ref, number) async => null),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Song not found'), findsWidgets);
  });
}
