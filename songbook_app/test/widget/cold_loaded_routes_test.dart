import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';
import 'package:songbook_app/presentation/screens/notation_editor/notation_editor_screen.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';
import 'package:songbook_app/router/app_router.dart';

import 'helpers.dart';

/// The two editing screens, reached with nothing beneath them on the stack.
///
/// `optionURLReflectsImperativeAPIs` is on, so `/import`, `/song/:id/edit` and
/// `/song/:id/notation` appear in the address bar and are therefore reloadable.
/// A reload lands on that route cold — it is the *only* entry on the stack — and
/// both screens finished with a bare `context.pop()`, which go_router answers
/// with `GoError('There is nothing to pop')`. The save itself completed, so
/// nothing was lost, but the button looked dead: no navigation, and in a release
/// build no visible error either.
///
/// Every one of these tests would pass against a pushed route. Cold-loading is
/// the whole point.

Song notatedUserSong() => Song(
      number: 1,
      title: 'Az Úrra bízom életem',
      originalKey: 'C',
      timeSignature: '4/4',
      explicitId: const SongId.user('abc'),
      notation: const SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(beats: [
              NotatedBeat(
                  pitch: 'C4', duration: NoteDuration.quarter, syllable: 'Az'),
              NotatedBeat(
                  pitch: 'D4', duration: NoteDuration.quarter, syllable: 'Úr-'),
            ]),
          ]),
        ],
      ),
      verses: const [Verse(number: 1, plainText: 'Az Úrra bízom életem')],
    );

/// Mounts the app with [location] as the one and only entry on the stack.
///
/// `initialLocation`, not a `push`: a pushed route always has the home route
/// under it, which is exactly the case that never reproduced this.
Future<ProviderContainer> pumpCold(
  WidgetTester tester,
  Song song,
  String location,
) async {
  final container = await makeAppContainer(
      prefs: const {'settings_view_config': 'false:true'});
  await container.read(userSongsProvider.notifier).add(song);

  // The real path constants and the real screens: a fallback that navigates
  // somewhere unregistered fails here rather than on a phone.
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(
        path: AppRoutes.song,
        builder: (_, s) =>
            SongViewScreen(songId: SongId.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: AppRoutes.editSong,
        builder: (_, s) => ImportSongScreen(
          editingId: SongId.parse(s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.editNotation,
        builder: (_, s) => NotationEditorScreen(
          songId: SongId.parse(s.pathParameters['id']!),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: localizedRouterApp(router),
  ));
  await tester.pumpAndSettle();
  return container;
}

/// Corrects one beat so the editor has something to save.
Future<void> correctABeat(WidgetTester tester) async {
  await tester.tap(find.text('D4'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('beat-note')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('F').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
}

void main() {
  group('the notation editor, cold-loaded', () {
    testWidgets('Save writes the correction and lands on the song',
        (tester) async {
      final song = notatedUserSong();
      final container =
          await pumpCold(tester, song, AppRoutes.editNotationPath(song.id));
      await correctABeat(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'a bare context.pop() here throws GoError');
      expect(
          container.read(userSongsProvider).single.notation!.verses.first
              .measures.first.beats[1].pitch,
          'F4');
      // Somewhere sensible rather than stuck: the song that was corrected.
      expect(find.byType(NotationEditorScreen), findsNothing);
      expect(find.byType(SongViewScreen), findsOneWidget);
    });

    testWidgets('discarding lands on the song rather than throwing',
        (tester) async {
      // Reachable through the system back gesture even with no back button in
      // the app bar, which is what a phone's back button and a browser's back
      // both arrive as.
      final song = notatedUserSong();
      final container =
          await pumpCold(tester, song, AppRoutes.editNotationPath(song.id));
      await correctABeat(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(NotationEditorScreen), findsNothing);
      expect(find.byType(SongViewScreen), findsOneWidget);
      // Discarded means discarded: the correction was never written.
      expect(
          container.read(userSongsProvider).single.notation!.verses.first
              .measures.first.beats[1].pitch,
          'D4');
    });
  });

  group('the song editor, cold-loaded', () {
    testWidgets('Save keeps the song and lands on it', (tester) async {
      // Editing prefills from the stored song, so Save is live on the first
      // frame and needs no edit to reach the branch that pops.
      final song = notatedUserSong();
      final container =
          await pumpCold(tester, song, AppRoutes.editSongPath(song.id));

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'a bare context.pop() here throws GoError');
      expect(container.read(userSongsProvider).single.title,
          'Az Úrra bízom életem');
      expect(find.byType(ImportSongScreen), findsNothing);
      expect(find.byType(SongViewScreen), findsOneWidget);
    });
  });
}
