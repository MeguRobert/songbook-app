import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';

import 'helpers.dart';

void main() {
  Future<void> openControlsSheet(WidgetTester tester) async {
    final song = makeTestSong(); // originalKey Bb
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

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
  }

  testWidgets('opens from the FAB and shows all three sections',
      (tester) async {
    await openControlsSheet(tester);

    expect(find.text('VIEW'), findsOneWidget);
    expect(find.text('TRANSPOSE'), findsOneWidget);
    expect(find.text('TEXT SIZE'), findsOneWidget);
    expect(find.text('Sheet Music'), findsOneWidget);
    expect(find.text('Chords'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
  });

  testWidgets('transpose + button changes the displayed key', (tester) async {
    await openControlsSheet(tester);

    // Original key Bb; +1 with flat spelling -> B (Bb is a flat key,
    // Bb +1 = B natural in flat table).
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SongViewScreen)),
      listen: false,
    );
    expect(container.read(transposeProvider), 1);
    expect(find.text('Reset to Bb'), findsOneWidget);
  });

  testWidgets('selecting the Lyrics preset updates the view config',
      (tester) async {
    await openControlsSheet(tester);

    await tester.tap(find.text('Lyrics'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SongViewScreen)),
      listen: false,
    );
    final state = container.read(songViewProvider);
    expect(state!.activeViewConfig?.isLyricsOnlyPreset, isTrue);
  });
}
