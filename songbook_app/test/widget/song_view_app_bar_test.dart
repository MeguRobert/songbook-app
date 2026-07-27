import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';

import 'helpers.dart';

/// Phase 0 — app-bar declutter.
///
/// The bar used to carry back + "42. Title" + four actions (tags, auto-scroll,
/// presentation, favourite). On a phone that left the title a few characters
/// wide, which is the UAT complaint this file pins down: a long Hungarian hymn
/// title has to be readable.
///
/// The rules asserted here:
///   - number and title are separate, so the number never eats title width
///   - the title gets two lines before it ellipsizes
///   - exactly one action stays in the bar (favourite); the rest live behind
///     an overflow menu
///   - auto-scroll is NOT in the bar at all — the controls sheet already owns
///     it, and two controls for one piece of state is how they drift apart
const _longTitle = 'Áldjad az Urat, ki mindent oly dicsőn igazgat';

Song makeLongTitledSong() => const Song(
      number: 151,
      title: _longTitle,
      originalKey: 'Bb',
      verses: [Verse(number: 1, plainText: 'Egy sor szöveg')],
      tags: ['dicséret'],
    );

Future<void> pumpSongView(WidgetTester tester, Song song) async {
  await pumpScreen(
    tester,
    SongViewScreen(songNumber: song.number),
    // No notation -> ChordView, so the test needs no sheet-music assets.
    prefs: const {'settings_view_config': 'false:true'},
    overrides: [
      songByNumberProvider.overrideWith(
          (ref, number) async => number == song.number ? song : null),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('song view app bar', () {
    testWidgets('shows the number and the title as separate elements',
        (tester) async {
      await pumpSongView(tester, makeLongTitledSong());

      // The old bar rendered one string, "151. Áldjad az Urat…", so the number
      // and its separator consumed title width on every song.
      expect(find.text('151. $_longTitle'), findsNothing);
      expect(find.text('151'), findsOneWidget);
      expect(find.text(_longTitle), findsOneWidget);
    });

    testWidgets('gives a long title two lines before ellipsizing',
        (tester) async {
      await pumpSongView(tester, makeLongTitledSong());

      final title = tester.widget<Text>(find.text(_longTitle));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
    });

    testWidgets('keeps only the favourite action in the bar', (tester) async {
      await pumpSongView(tester, makeLongTitledSong());

      final actions = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      );

      // Favourite + overflow. The harness mounts this screen as `home:`, so
      // there is nothing to pop and AppBar adds no back button — in the real
      // app it is one more. Guarding the count is the point: a fourth action
      // is exactly the regression that made the title unreadable.
      expect(tester.widgetList<IconButton>(actions).length, 2);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('does not duplicate the auto-scroll control in the bar',
        (tester) async {
      await pumpSongView(tester, makeLongTitledSong());

      // Auto-scroll lives in the controls sheet (section 5), with a play/pause
      // button AND a speed slider. A second, speed-less copy in the app bar was
      // the same state behind two different affordances.
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(find.byIcon(Icons.pause_circle_outline), findsNothing);
    });

    testWidgets('moves presentation and tag editing into the overflow menu',
        (tester) async {
      await pumpSongView(tester, makeLongTitledSong());

      expect(find.byIcon(Icons.fullscreen), findsNothing);
      expect(find.byIcon(Icons.label_outline), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Presentation mode'), findsOneWidget);
      expect(find.text('Edit tags'), findsOneWidget);
    });

    testWidgets('overflow menu actually opens the tag editor', (tester) async {
      await pumpSongView(tester, makeLongTitledSong());

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit tags'));
      await tester.pumpAndSettle();

      // TagEditorSheet seeds itself from the song's current tags.
      expect(find.text('dicséret'), findsWidgets);
    });

    testWidgets('bar grows with the text scale instead of overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpScreen(
        tester,
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: SongViewScreen(songNumber: 151),
        ),
        prefs: const {'settings_view_config': 'false:true'},
        overrides: [
          songByNumberProvider.overrideWith(
              (ref, number) => Future.value(
                  number == 151 ? makeLongTitledSong() : null)),
        ],
      );
      await tester.pumpAndSettle();

      // A fixed 56px toolbar cannot hold two lines of doubled text; the height
      // has to be derived from the scaler or this overflows in yellow stripes.
      expect(tester.takeException(), isNull);
      expect(find.text(_longTitle), findsOneWidget);
    });
  });
}
