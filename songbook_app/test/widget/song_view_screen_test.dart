import 'package:songbook_app/data/models/song_id.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/autoscroll_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';
import 'package:songbook_app/presentation/screens/song_view/widgets/chord_view.dart';
import 'package:songbook_app/presentation/screens/song_view/widgets/sheet_music_view.dart';

import 'helpers.dart';

/// A song long enough that the chord view actually scrolls in a test viewport.
/// A song that CAN render sheet music, for the cases that need the Sheet Music
/// preset to be observable rather than falling through to the chords.
Song makeNotatedSong({int number = 42}) => Song(
      number: number,
      title: 'Engraved',
      originalKey: 'C',
      notation: const SongNotation(
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
      verses: const [Verse(number: 1, plainText: 'Egy sor szöveg')],
    );

Song makeScrollableSong() => Song(
      number: 42,
      title: 'Mint a szép híves patakra',
      originalKey: 'Bb',
      verses: [
        for (var i = 1; i <= 40; i++)
          Verse(number: i, plainText: 'Verse $i line of text'),
      ],
      tags: const [],
    );

void main() {
  testWidgets('renders song title, lyrics and transposed chords in chord view',
      (tester) async {
    final song = makeTestSong();
    await pumpScreen(
      tester,
      SongViewScreen(songId: const SongId.hymnal(42)),
      // Global config without notation -> ChordView (no sheet music assets).
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByIdProvider.overrideWith(
            (ref, id) async => id == const SongId.hymnal(42) ? song : null),
      ],
    );
    await tester.pumpAndSettle();

    // Number and title are separate app-bar lines since the Phase 0 declutter;
    // see song_view_app_bar_test.dart for the full set of rules.
    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('Mint a szép híves patakra'), findsWidgets);
    expect(find.text('Second verse plain text'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    // Presentation mode moved behind the overflow menu.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('toggling the favorite icon updates its state', (tester) async {
    final song = makeTestSong();
    await pumpScreen(
      tester,
      SongViewScreen(songId: const SongId.hymnal(42)),
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByIdProvider.overrideWith(
            (ref, id) async => id == const SongId.hymnal(42) ? song : null),
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
      SongViewScreen(songId: const SongId.hymnal(999)),
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByIdProvider.overrideWith((ref, number) async => null),
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
      SongViewScreen(songId: const SongId.hymnal(42)),
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByIdProvider
            .overrideWith((ref, id) async => id == const SongId.hymnal(42) ? song : null),
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
    expect(find.text('Mint a szép híves patakra'), findsWidgets);
  });

  testWidgets('disposes cleanly when navigating away', (tester) async {
    final song = makeTestSong();
    await pumpScreen(
      tester,
      SongViewScreen(songId: const SongId.hymnal(42)),
      prefs: {'settings_view_config': 'false:true'},
      overrides: [
        songByIdProvider
            .overrideWith((ref, id) async => id == const SongId.hymnal(42) ? song : null),
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

  // Audit finding S11. Pushing presentation mode covers the song view with an
  // opaque route, which mutes the ticker via TickerMode — but a muted Ticker
  // keeps its start time, so the first tick after returning carries the whole
  // time spent away as one `dt` and the page teleports.
  group('auto-scroll across a pushed route', () {
    double offsetOf(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ChordView, skipOffstage: false),
            matching: find.byType(Scrollable, skipOffstage: false),
          ),
        )
        .position
        .pixels;

    /// pumpAndSettle never settles while the auto-scroll ticker is active.
    Future<void> pumpFrames(WidgetTester tester, int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('ten seconds away does not teleport the scroll position',
        (tester) async {
      final song = makeScrollableSong();
      await pumpScreen(
        tester,
        SongViewScreen(songId: const SongId.hymnal(42)),
        prefs: {'settings_view_config': 'false:true'},
        overrides: [
          songByIdProvider
              .overrideWith((ref, id) async => id == const SongId.hymnal(42) ? song : null),
        ],
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SongViewScreen));
      final container = ProviderScope.containerOf(element, listen: false);
      final navigator = Navigator.of(element);

      container.read(autoScrollProvider.notifier).play();
      await pumpFrames(tester, 10); // ~1s of scrolling at 40 px/s
      final before = offsetOf(tester);
      expect(before, greaterThan(0), reason: 'auto-scroll should have moved');

      // Cover the screen the way presentation mode does.
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('presentation')),
        ),
      );
      await pumpFrames(tester, 6); // let the push transition finish
      final covered = offsetOf(tester);

      await tester.pump(const Duration(seconds: 10)); // time spent away

      // The framework already stops the ticker while an opaque route covers
      // us: Overlay marks the entry below with tickerEnabled:false and
      // TickerMode mutes it. The audit's "keeps running" premise was wrong —
      // the damage was entirely the stale elapsed clock, below.
      expect(offsetOf(tester), covered);

      navigator.pop();
      await pumpFrames(tester, 6);

      final after = offsetOf(tester);
      // Transitions themselves are worth a few tens of pixels at 40 px/s. The
      // bug produced the full 10 s × 40 px/s = 400 px in a single frame.
      expect(after - before, lessThan(120));
    });
  });

  // Audit finding S13. openSong() runs in a post-frame callback, so the frame
  // that first paints a newly opened song was still describing the previous
  // one — its transpose, its zoom, even its preset.
  group('first frame of a newly opened song', () {
    late ProviderContainer container;

    Widget appFor(SongId songId) => UncontrolledProviderScope(
          container: container,
          child: localizedApp(SongViewScreen(songId: songId)),
        );

    Future<void> setUpContainer({
      Map<String, Object> prefs = const {'settings_view_config': 'false:true'},
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final sharedPreferences = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          songByIdProvider.overrideWith(
            // WITH notation: the Sheet Music preset is only observable on a song
            // that has something to engrave. A song without one now falls
            // through to the chords, which would make both songs here render
            // ChordView and the assertion below vacuous.
            (ref, id) async => makeNotatedSong(number: id.hymnalNumber ?? 0),
          ),
        ],
      );
      addTearDown(container.dispose);
    }

    testWidgets('does not inherit the previous song\'s transpose or zoom',
        (tester) async {
      await setUpContainer();

      await tester.pumpWidget(appFor(const SongId.hymnal(42)));
      await tester.pumpAndSettle();

      container.read(songViewProvider.notifier).setTranspose(3);
      container.read(songViewProvider.notifier).setTextScale(1.8);
      await tester.pumpAndSettle();
      expect(tester.widget<ChordView>(find.byType(ChordView)).transpose, 3);

      // Exactly one frame: openSong() for song 43 has been scheduled but its
      // state change cannot land until the frame after this one.
      await tester.pumpWidget(appFor(const SongId.hymnal(43)));
      await tester.pump();

      final firstFrame = tester.widget<ChordView>(find.byType(ChordView));
      expect(firstFrame.song.number, 43);
      expect(firstFrame.transpose, 0);
      expect(firstFrame.textScale, 1.0);
    });

    testWidgets('does not inherit the previous song\'s preset', (tester) async {
      // Global default is Sheet Music; song 42 is pinned to Lyrics-only.
      await setUpContainer(prefs: {
        'settings_view_config': 'true:true',
        'settings_song_view_config_42': 'false:false',
      });

      await tester.pumpWidget(appFor(const SongId.hymnal(42)));
      await tester.pumpAndSettle();
      expect(tester.widget<ChordView>(find.byType(ChordView)).showChords,
          isFalse);

      await tester.pumpWidget(appFor(const SongId.hymnal(43)));
      await tester.pump();

      // Song 43 has no override, so it must open on the global Sheet Music
      // default — not carry song 42's Lyrics-only preset into frame one.
      expect(find.byType(ChordView), findsNothing);
      expect(find.byType(SheetMusicView), findsOneWidget);
    });

    testWidgets('honours the new song\'s own saved preset on frame one',
        (tester) async {
      await setUpContainer(prefs: {
        'settings_view_config': 'true:true',
        'settings_song_view_config_43': 'false:true',
      });

      await tester.pumpWidget(appFor(const SongId.hymnal(42)));
      await tester.pumpAndSettle();

      await tester.pumpWidget(appFor(const SongId.hymnal(43)));
      await tester.pump();

      final firstFrame = tester.widget<ChordView>(find.byType(ChordView));
      expect(firstFrame.showChords, isTrue);
    });
  });
}
