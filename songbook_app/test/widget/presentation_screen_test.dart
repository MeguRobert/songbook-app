import 'package:flutter/material.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/presentation/presentation_screen.dart';

import 'helpers.dart';

void main() {
  Future<void> pumpPresentation(WidgetTester tester) async {
    final song = makeTestSong();
    await pumpScreen(
      tester,
      PresentationScreen(songId: const SongId.hymnal(42)),
      overrides: [
        songByIdProvider.overrideWith(
            (ref, id) async => id == const SongId.hymnal(42) ? song : null),
      ],
    );
    // Let the song future resolve and the auto-hide timer (3s) elapse.
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('builds and shows the first verse content', (tester) async {
    await pumpPresentation(tester);
    // First page shows the first verse's structured lines.
    expect(find.textContaining('Mint a szép híves patakra'), findsWidgets);
  });

  group('background colour is the presentation\'s own, not the app theme\'s',
      () {
    /// The [Scaffold] the pages are painted on.
    Color backgroundOf(WidgetTester tester) {
      return tester
          .widgetList<Scaffold>(find.byType(Scaffold))
          .map((s) => s.backgroundColor)
          .whereType<Color>()
          .first;
    }

    Future<void> pumpIn(WidgetTester tester, ThemeMode mode) async {
      final song = makeTestSong();
      await pumpScreen(
        tester,
        PresentationScreen(songId: const SongId.hymnal(42)),
        prefs: {
          'settings_theme_mode': mode == ThemeMode.dark ? 'dark' : 'light',
          // Start in projection (dark) mode, so the toggle has somewhere to go.
          'settings_projection_mode': true,
        },
        themeMode: mode,
        overrides: [
          songByIdProvider.overrideWith(
              (ref, id) async => id == const SongId.hymnal(42) ? song : null),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      // The controls auto-hide after 3s; a tap on them lands on nothing until
      // the page has been tapped once to bring them back.
      await tester.tap(find.byType(PageView), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('dark app theme: switching to light gives a white background',
        (tester) async {
      // The reported bug. Projection mode was black-on-white by hand, but its
      // opposite fell back to `theme.scaffoldBackgroundColor` — which in a dark
      // app theme is dark, so the sun button appeared to do nothing at all.
      await pumpIn(tester, ThemeMode.dark);
      expect(backgroundOf(tester), Colors.black);

      await tester.tap(find.byIcon(Icons.wb_sunny));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(backgroundOf(tester), Colors.white);
    });

    testWidgets('light app theme behaves identically', (tester) async {
      // Which room the projector is in has nothing to do with the app's theme,
      // so both directions must work from either.
      await pumpIn(tester, ThemeMode.light);
      expect(backgroundOf(tester), Colors.black);

      await tester.tap(find.byIcon(Icons.wb_sunny));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(backgroundOf(tester), Colors.white);
    });
  });

  testWidgets('unknown song renders without crashing', (tester) async {
    await pumpScreen(
      tester,
      PresentationScreen(songId: const SongId.hymnal(999)),
      overrides: [
        songByIdProvider.overrideWith((ref, number) async => null),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
