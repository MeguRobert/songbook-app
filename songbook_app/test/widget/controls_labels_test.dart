import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/widgets/song_controls_sheet.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';

import 'helpers.dart';

/// UAT wording and iconography.
///
/// All of these came back from using the app on a phone: the icons did not say
/// what the views were, and the auto-scroll speed was reported in the unit the
/// code happens to count in rather than anything a singer would recognise.

Future<void> pumpControls(WidgetTester tester) async {
  await pumpScreen(
    tester,
    const Scaffold(body: SongControlsSheet(originalKey: 'C')),
    prefs: const {'settings_view_config': 'false:true'},
  );
  await tester.pumpAndSettle();
}

void main() {
  group('view icons', () {
    testWidgets('sheet music is a musical note, chords are chord letters',
        (tester) async {
      await pumpControls(tester);

      // Was a piano for sheet music and a musical note for chords, which read
      // as "an instrument" and "music" rather than as the two things on offer.
      // Chords get letters because that is literally what is drawn above the
      // lyric — and because a guitar would imply guitar-only, in an app whose
      // songs are played on organ and piano too. (Stock Material has no guitar.)
      final sheetMusic = find.widgetWithIcon(ChoiceChip, Icons.music_note);
      final chords = find.widgetWithIcon(ChoiceChip, Icons.abc);

      expect(sheetMusic, findsOneWidget);
      expect(chords, findsOneWidget);
      expect(find.descendant(of: sheetMusic, matching: find.text('Sheet Music')),
          findsOneWidget);
      expect(find.descendant(of: chords, matching: find.text('Chords')),
          findsOneWidget);
      expect(find.byIcon(Icons.piano), findsNothing);
    });
  });

  group('auto-scroll speed', () {
    testWidgets('is named, not measured in pixels', (tester) async {
      await pumpControls(tester);

      // "40 px/s" is the unit the ticker counts in. Nobody sings in pixels.
      expect(find.textContaining('px/s'), findsNothing);
      expect(find.textContaining('px per'), findsNothing);
      final slider = tester.widget<Slider>(find.byType(Slider).last);
      expect(slider.label, isNotNull);
      expect(slider.label, isNot(contains('px')));
    });

    testWidgets('names every step across the range', (tester) async {
      await pumpControls(tester);
      final slider = tester.widget<Slider>(find.byType(Slider).last);

      // Whatever the naming scheme, it has to cover the whole slider — a label
      // that goes blank at one end is worse than the number it replaced.
      for (var v = slider.min; v <= slider.max; v += 1) {
        expect(SongControlsSheet.speedLabel(v), isNotEmpty,
            reason: 'speed $v');
      }
      expect(SongControlsSheet.speedLabel(slider.min), 'Slowest');
      expect(SongControlsSheet.speedLabel(slider.max), 'Fastest');
    });
  });

  group('presentation mode', () {
    testWidgets('is a slideshow canvas, not a fullscreen arrow', (tester) async {
      await pumpScreen(
        tester,
        SongViewScreen(songId: makeTestSong().id),
        prefs: const {'settings_view_config': 'false:true'},
        overrides: [
          songByIdProvider.overrideWith((ref, id) async =>
              id == makeTestSong().id ? makeTestSong() : null),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // A screen with a play button says "start presenting". The fullscreen
      // arrows say "make this bigger", which is a different promise.
      expect(find.byIcon(Icons.slideshow), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
    });
  });
}
