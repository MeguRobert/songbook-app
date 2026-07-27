import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';

import 'helpers.dart';

SongNotation makeNotation() {
  return const SongNotation(
    originalKey: 'Bb',
    timeSignature: '4/4',
    verses: [
      NotatedVerse(number: 1, measures: [
        NotatedMeasure(beats: [
          NotatedBeat(
            pitch: 'Bb4',
            duration: NoteDuration.quarter,
            syllable: 'Mint',
            chord: 'Bb',
          ),
          NotatedBeat(pitch: 'C5', duration: NoteDuration.quarter,
              syllable: 'a'),
          NotatedBeat(pitch: 'D5', duration: NoteDuration.half,
              syllable: 'szep', dotted: true),
        ]),
        NotatedMeasure(beats: [
          NotatedBeat(pitch: 'R', duration: NoteDuration.quarter),
          NotatedBeat(pitch: 'F4', duration: NoteDuration.eighth,
              tieStart: true),
          NotatedBeat(pitch: 'F4', duration: NoteDuration.eighth,
              tieEnd: true),
        ], repeatEnd: true),
      ]),
    ],
    pickup: [NotatedBeat(pitch: 'F4', duration: NoteDuration.quarter)],
  );
}

void main() {
  testWidgets('renders the custom Canvas notation renderer without errors',
      (tester) async {
    final song = makeTestSong().copyWith(notation: makeNotation());
    await pumpScreen(
      tester,
      const SongViewScreen(songNumber: 42),
      overrides: [
        songByNumberProvider.overrideWith(
            (ref, number) async => number == 42 ? song : null),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
    // App bar renders the number and title on separate lines (Phase 0).
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Mint a szép híves patakra'), findsOneWidget);
  });

  testWidgets(
      'renders the transposed Canvas notation without errors',
      (tester) async {
    final song = makeTestSong().copyWith(notation: makeNotation());
    await pumpScreen(
      tester,
      const SongViewScreen(songNumber: 42),
      overrides: [
        songByNumberProvider.overrideWith(
            (ref, number) async => number == 42 ? song : null),
      ],
    );
    await tester.pumpAndSettle();

    // Transpose up twice through the provider (as the controls sheet would).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SongViewScreen)),
      listen: false,
    );
    container.read(songViewProvider.notifier).transposeUp();
    container.read(songViewProvider.notifier).transposeUp();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets(
      'falls back to the no-sheet-music notice when the song has neither '
      'notation nor legacy sheet music', (tester) async {
    final song = makeTestSong(); // no notation, no sheetMusic
    await pumpScreen(
      tester,
      const SongViewScreen(songNumber: 42),
      overrides: [
        songByNumberProvider.overrideWith(
            (ref, number) async => number == 42 ? song : null),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No sheet music available for this song'), findsOneWidget);
    // Legacy view shows plain verses; second verse text should appear.
    expect(find.textContaining('Second verse plain text'), findsWidgets);
  });
}
