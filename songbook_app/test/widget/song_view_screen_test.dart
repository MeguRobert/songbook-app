import 'package:flutter/gestures.dart';
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

  // Regression guard. A bad merge once spliced dispose()'s body into the
  // Ctrl+wheel zoom handler, so a single scroll-zoom disposed the auto-scroll
  // Ticker and the live ScrollController and marked the State defunct. It was
  // valid Dart, so analyze and every existing test passed it. These two tests
  // exercise the two lifecycles that break when that happens.
  testWidgets('scroll-zoom does not tear down the screen', (tester) async {
    final song = makeTestSong();
    await pumpScreen(
      tester,
      const SongViewScreen(songNumber: 42),
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByNumberProvider
            .overrideWith((ref, number) async => number == 42 ? song : null),
      ],
    );
    await tester.pumpAndSettle();

    // Two zoom notches, as a mouse wheel with Ctrl held would deliver them.
    final center = tester.getCenter(find.byType(SongViewScreen));
    for (var i = 0; i < 2; i++) {
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(center),
      );
      await tester.sendEventToBinding(
        pointer.scale(1.2),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();

    // Still mounted and rendering: nothing was disposed out from under us.
    expect(tester.takeException(), isNull);
    expect(find.text('42. Mint a szép híves patakra'), findsOneWidget);
  });

  testWidgets('disposes cleanly when navigating away', (tester) async {
    final song = makeTestSong();
    await pumpScreen(
      tester,
      const SongViewScreen(songNumber: 42),
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByNumberProvider
            .overrideWith((ref, number) async => number == 42 ? song : null),
      ],
    );
    await tester.pumpAndSettle();

    // Replace the screen — every controller/ticker must be released exactly
    // once. A leaked Ticker throws "was disposed with an active Ticker"; a
    // double-disposed controller throws "used after being disposed".
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
