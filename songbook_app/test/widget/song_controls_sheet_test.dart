import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';

import 'helpers.dart';

void main() {
  /// Opens the controls sheet with [viewConfig] as the stored default view
  /// ("notation:chords" — the default 'false:true' is the Chords preset).
  Future<void> openControlsSheet(
    WidgetTester tester, {
    String viewConfig = 'false:true',
  }) async {
    // Tear the tree down first. Re-pumping the same widget type reuses the
    // element tree, so a modal sheet left open by a previous call survives and
    // its barrier swallows the tap on the FAB.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final song = makeTestSong(); // originalKey Bb
    await pumpScreen(
      tester,
      const SongViewScreen(songNumber: 42),
      prefs: {'settings_view_config': viewConfig},
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

  /// Offset of a section header from the top of the sheet.
  double headerY(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  /// Whether the transpose steppers can actually be pressed.
  bool transposeEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed !=
      null;

  // Audit finding S12. Transposition only ever changes chord symbols or the
  // staff; in the Lyrics preset both are hidden, so the controls sat there
  // reporting a key change nothing on screen reflected. They are disabled
  // rather than removed — see the layout-stability group below.
  group('transpose + capo are inert where they do nothing', () {
    testWidgets('operable in the Chords preset', (tester) async {
      await openControlsSheet(tester, viewConfig: 'false:true');

      expect(find.text('TRANSPOSE'), findsOneWidget);
      expect(find.text('CAPO'), findsOneWidget);
      expect(transposeEnabled(tester), isTrue);
    });

    testWidgets('operable in the Sheet Music preset', (tester) async {
      await openControlsSheet(tester, viewConfig: 'true:true');

      expect(transposeEnabled(tester), isTrue);
    });

    testWidgets('disabled, with a reason, in the Lyrics-only preset',
        (tester) async {
      await openControlsSheet(tester, viewConfig: 'false:false');

      expect(transposeEnabled(tester), isFalse);
      expect(find.textContaining('no chords in this view'), findsNWidgets(2));
    });

    testWidgets('go inert when the user switches to Lyrics in the sheet',
        (tester) async {
      await openControlsSheet(tester, viewConfig: 'false:true');
      expect(transposeEnabled(tester), isTrue);

      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();

      expect(transposeEnabled(tester), isFalse);
    });

    testWidgets('auto-scroll is disabled in Sheet Music', (tester) async {
      await openControlsSheet(tester, viewConfig: 'true:true');

      final play = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.play_arrow),
      );
      expect(play.onPressed, isNull);
      expect(find.textContaining('not in sheet music view'), findsOneWidget);
    });
  });

  // Robert, testing the installed web app on a phone: dismissing the sheet
  // required hitting the 4px drag handle exactly, because the scroll view
  // swallowed every vertical drag over the content.
  group('swipe-to-dismiss', () {
    testWidgets('a downward swipe over the controls closes the sheet',
        (tester) async {
      await openControlsSheet(tester);
      expect(find.text('VIEW'), findsOneWidget);

      // Start the drag on the section content, nowhere near the handle.
      await tester.fling(find.text('TEXT SIZE'), const Offset(0, 600), 1200);
      await tester.pumpAndSettle();

      expect(find.text('VIEW'), findsNothing);
    });

    testWidgets('the handle still works', (tester) async {
      await openControlsSheet(tester);

      await tester.fling(
        find.byType(DraggableScrollableSheet),
        const Offset(0, 600),
        1200,
      );
      await tester.pumpAndSettle();

      expect(find.text('VIEW'), findsNothing);
    });

    testWidgets('scrolling up inside the sheet does not dismiss it',
        (tester) async {
      await openControlsSheet(tester);

      await tester.drag(find.text('TEXT SIZE'), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('VIEW'), findsOneWidget);
    });
  });

  // Robert: switching presets repeatedly was re-aiming practice, because the
  // sheet is bottom-anchored and dropping a section slid everything above it.
  group('layout does not move between views', () {
    testWidgets('every section is present in all three presets',
        (tester) async {
      for (final config in ['true:true', 'false:true', 'false:false']) {
        await openControlsSheet(tester, viewConfig: config);

        expect(find.text('VIEW'), findsOneWidget, reason: config);
        expect(find.text('TEXT SIZE'), findsOneWidget, reason: config);
        expect(find.text('TRANSPOSE'), findsOneWidget, reason: config);
        expect(find.text('CAPO'), findsOneWidget, reason: config);
        expect(find.text('AUTO-SCROLL'), findsOneWidget, reason: config);
      }
    });

    testWidgets('section positions are identical across presets',
        (tester) async {
      Map<String, double> layoutFor(WidgetTester t) => {
            for (final s in ['VIEW', 'TEXT SIZE', 'TRANSPOSE', 'CAPO'])
              s: headerY(t, s),
          };

      await openControlsSheet(tester, viewConfig: 'true:true');
      final sheetMusic = layoutFor(tester);

      await openControlsSheet(tester, viewConfig: 'false:true');
      final chords = layoutFor(tester);

      await openControlsSheet(tester, viewConfig: 'false:false');
      final lyrics = layoutFor(tester);

      expect(chords, equals(sheetMusic));
      expect(lyrics, equals(sheetMusic));
    });

    testWidgets('the preset chips stay put when switching preset in place',
        (tester) async {
      await openControlsSheet(tester, viewConfig: 'false:true');
      final lyricsChip = tester.getTopLeft(find.text('Lyrics'));
      final sheetMusicChip = tester.getTopLeft(find.text('Sheet Music'));
      final textSize = headerY(tester, 'TEXT SIZE');

      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();

      // Tapping Lyrics must leave the chip under the finger, and Sheet Music
      // still where it was, so the next switch needs no re-aiming.
      expect(tester.getTopLeft(find.text('Lyrics')), lyricsChip);
      expect(tester.getTopLeft(find.text('Sheet Music')), sheetMusicChip);
      expect(headerY(tester, 'TEXT SIZE'), textSize);
    });

    testWidgets('TEXT SIZE sits directly under VIEW in every preset',
        (tester) async {
      for (final config in ['true:true', 'false:true', 'false:false']) {
        await openControlsSheet(tester, viewConfig: config);

        expect(headerY(tester, 'TEXT SIZE'), greaterThan(headerY(tester, 'VIEW')),
            reason: config);
        expect(
          headerY(tester, 'TEXT SIZE'),
          lessThan(headerY(tester, 'TRANSPOSE')),
          reason: config,
        );
      }
    });
  });
}
