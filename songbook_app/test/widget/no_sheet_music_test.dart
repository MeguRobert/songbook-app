import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';
import 'package:songbook_app/presentation/screens/song_view/widgets/chord_view.dart';
import 'package:songbook_app/presentation/screens/song_view/widgets/sheet_music_view.dart';
import 'package:songbook_app/presentation/screens/song_view/widgets/song_controls_sheet.dart';

import 'helpers.dart';

/// Opening a song that has no engraved music, in sheet-music view.
///
/// This used to land on a "No sheet music available for this song" placeholder
/// with a "Switch to chord view" instruction — a dead end that told the user to
/// do by hand what the app could do itself, and whose text was the one thing on
/// screen that ignored the text-size setting.
///
/// So: fall through to the chords, say so once, and disable the preset that
/// cannot work.

Song withoutSheetMusic() => const Song(
      number: 7,
      title: 'Pasted song',
      originalKey: 'G',
      explicitId: SongId.user('nosheet'),
      verses: [Verse(number: 1, plainText: 'Az Úrra bízom életem')],
    );

Song withNotation() => const Song(
      number: 8,
      title: 'Engraved song',
      originalKey: 'C',
      notation: SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'C4', duration: NoteDuration.whole),
            ]),
          ]),
        ],
      ),
      verses: [Verse(number: 1, plainText: 'x')],
    );

/// Mounts the song view with the SHEET MUSIC preset in effect.
Future<void> pumpInSheetMusicView(WidgetTester tester, Song song) async {
  await pumpScreen(
    tester,
    SongViewScreen(songId: song.id),
    prefs: const {'settings_view_config': 'true:true'},
    overrides: [
      songByIdProvider
          .overrideWith((ref, id) async => id == song.id ? song : null),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('a song with no engraved music', () {
    testWidgets('falls through to the chords instead of a dead placeholder',
        (tester) async {
      await pumpInSheetMusicView(tester, withoutSheetMusic());

      expect(find.byType(ChordView), findsOneWidget);
      expect(find.byType(SheetMusicView), findsNothing);
      expect(find.textContaining('No sheet music available'), findsNothing);
      expect(find.textContaining('Switch to chord view'), findsNothing);
      expect(find.textContaining('Az Úrra bízom életem'), findsWidgets);
    });

    testWidgets('says so once, rather than silently showing something else',
        (tester) async {
      await pumpInSheetMusicView(tester, withoutSheetMusic());

      // Silently swapping the view would leave the controls sheet and the screen
      // disagreeing with no explanation for which won.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('No sheet music'), findsOneWidget);
    });

    testWidgets('offers the sheet-music preset as disabled', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(
          body: SongControlsSheet(originalKey: 'G', canShowSheetMusic: false),
        ),
        prefs: const {'settings_view_config': 'true:true'},
      );
      await tester.pumpAndSettle();

      // Present but inert, not removed: a control that vanishes per song makes
      // the sheet a different shape every time it opens.
      final chip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Sheet Music'));
      expect(chip.onSelected, isNull);
      expect(find.textContaining('no sheet music for this song'), findsOneWidget);
    });
  });

  group('a song that does have engraved music', () {
    testWidgets('still renders the sheet', (tester) async {
      await pumpInSheetMusicView(tester, withNotation());

      expect(find.byType(SheetMusicView), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('keeps the sheet-music preset enabled', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(
          body: SongControlsSheet(originalKey: 'C', canShowSheetMusic: true),
        ),
        prefs: const {'settings_view_config': 'true:true'},
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Sheet Music'));
      expect(chip.onSelected, isNotNull);
    });
  });
}
