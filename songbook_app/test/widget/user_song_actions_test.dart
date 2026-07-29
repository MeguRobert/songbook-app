import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';
import 'package:songbook_app/router/app_router.dart';

import 'helpers.dart';

/// Editing and deleting a song the user added.
///
/// `UserSongRepository.delete`/`update` and their notifier wrappers shipped
/// tested but with no caller anywhere in the UI, so a song imported with a typo
/// — or one whose chord sheet parsed badly — was permanent. These pin the two
/// entry points, and the fact that they are offered for user songs *only*: a
/// bundled hymnal song lives in a read-only asset and cannot be written back to.

Song userSong({
  String ref = 'abc',
  String title = 'Az Úrra bízom életem',
  int number = 1,
  String? book = 'Saját énekek',
}) =>
    Song(
      number: number,
      title: title,
      originalKey: 'G',
      book: book,
      explicitId: SongId.user(ref),
      verses: const [
        Verse(number: 1, lines: [LyricLine(text: 'Az Úrra bízom életem')]),
      ],
      tags: const ['bizalom'],
    );

Future<void> pumpSongView(WidgetTester tester, Song song) async {
  await pumpScreen(
    tester,
    SongViewScreen(songId: song.id),
    // No notation -> ChordView, so the test needs no sheet-music assets.
    prefs: const {'settings_view_config': 'false:true'},
    overrides: [
      songByIdProvider
          .overrideWith((ref, id) async => id == song.id ? song : null),
    ],
  );
  await tester.pumpAndSettle();
}

/// Mounts the song view on a real router over real storage, seeded with [song].
Future<ProviderContainer> pumpRoutedSongView(
  WidgetTester tester,
  Song song,
) async {
  final container = await makeAppContainer(
      prefs: const {'settings_view_config': 'false:true'});
  await container.read(userSongsProvider.notifier).add(song);

  // The real path constants and the real screens, so a route that is never
  // registered — or registered under a different path — fails here.
  final router = GoRouter(
    initialLocation: '/',
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
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  router.push(AppRoutes.songPath(song.id));
  await tester.pumpAndSettle();
  return container;
}

Future<void> openOverflow(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

Future<void> tapMenuItem(WidgetTester tester, String label) async {
  await openOverflow(tester);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('overflow menu', () {
    testWidgets('offers edit and delete for a song the user added',
        (tester) async {
      await pumpSongView(tester, userSong());
      await openOverflow(tester);

      expect(find.text('Edit song'), findsOneWidget);
      expect(find.text('Delete song'), findsOneWidget);
    });

    testWidgets('offers neither for a bundled hymnal song', (tester) async {
      // songs.json is a read-only asset: there is nothing to write back to.
      await pumpSongView(tester, makeTestSong());
      await openOverflow(tester);

      expect(find.text('Edit song'), findsNothing);
      expect(find.text('Delete song'), findsNothing);
      // The actions that apply to every song are untouched.
      expect(find.text('Presentation mode'), findsOneWidget);
      expect(find.text('Edit tags'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('asks first, and a cancel keeps the song', (tester) async {
      final container = await pumpRoutedSongView(tester, userSong());

      await tapMenuItem(tester, 'Delete song');

      // Destructive and unrecoverable: the song exists only on this device and
      // there is no undo.
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(container.read(userSongsProvider), hasLength(1));
      expect(find.text('Az Úrra bízom életem'), findsWidgets);
    });

    testWidgets('confirming removes the song and leaves the screen',
        (tester) async {
      final container = await pumpRoutedSongView(tester, userSong());

      await tapMenuItem(tester, 'Delete song');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(container.read(userSongsProvider), isEmpty);
      // Staying put would leave the screen describing a song that no longer
      // exists — "Song not found" where the song used to be.
      expect(find.text('HOME'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('edit', () {
    testWidgets('opens prefilled with what was saved', (tester) async {
      await pumpRoutedSongView(
          tester, userSong(title: 'Elírt cím', number: 7, book: 'Ifjúsági'));

      await tapMenuItem(tester, 'Edit song');

      expect(find.text('Edit song'), findsWidgets);
      expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Title'))
              .controller!
              .text,
          'Elírt cím');
      expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Number'))
              .controller!
              .text,
          '7');
      expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Songbook'))
              .controller!
              .text,
          'Ifjúsági');
    });

    testWidgets('prefills the words and chords as editable ChordPro',
        (tester) async {
      // The box used to open empty, so correcting a lyric meant selecting the
      // song out of the preview and pasting it back — which arrives as one
      // unbroken line, since a cross-widget selection carries no line breaks.
      await pumpRoutedSongView(tester, userSong());
      await tapMenuItem(tester, 'Edit song');

      final pasted = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!
          .text;

      expect(pasted, contains('{title: Az Úrra bízom életem}'));
      expect(pasted, contains('Az Úrra bízom életem'));
      // Real line breaks, not one run-together line.
      expect(const LineSplitter().convert(pasted).length, greaterThan(2));
    });

    testWidgets('saving replaces the song instead of adding a second one',
        (tester) async {
      final container =
          await pumpRoutedSongView(tester, userSong(title: 'Elírt cím'));
      final storedId = container.read(userSongsProvider).single.id;

      await tapMenuItem(tester, 'Edit song');
      await tester.enterText(
          find.widgetWithText(TextField, 'Title'), 'Javított cím');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final songs = container.read(userSongsProvider);
      expect(songs, hasLength(1));
      expect(songs.single.title, 'Javított cím');
      // Same identity: every favourite, setlist and tag override still points
      // at this song. A new id would orphan all of them.
      expect(songs.single.id, storedId);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the tags the song already carried', (tester) async {
      // The draft is rebuilt from the form, which has no tag field. Tags are
      // edited elsewhere (the tag sheet), so a save here must not wipe them.
      final container = await pumpRoutedSongView(tester, userSong());

      await tapMenuItem(tester, 'Edit song');
      await tester.enterText(
          find.widgetWithText(TextField, 'Title'), 'Javított cím');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(container.read(userSongsProvider).single.tags, ['bizalom']);
    });

    testWidgets('clearing the songbook actually clears it', (tester) async {
      // `copyWith(book: null)` cannot express this — the `??` fallback keeps the
      // old value — so an edit that drops a field has to build the song afresh.
      final container =
          await pumpRoutedSongView(tester, userSong(book: 'Ifjúsági'));

      await tapMenuItem(tester, 'Edit song');
      await tester.enterText(find.widgetWithText(TextField, 'Songbook'), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(container.read(userSongsProvider).single.book, isNull);
    });

    testWidgets('returns to the song, which shows the correction',
        (tester) async {
      await pumpRoutedSongView(tester, userSong(title: 'Elírt cím'));

      await tapMenuItem(tester, 'Edit song');
      await tester.enterText(
          find.widgetWithText(TextField, 'Title'), 'Javított cím');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Back on the song view — not pushed forward onto another copy of it —
      // with the app bar reflecting the edit.
      expect(find.byType(SongViewScreen), findsOneWidget);
      expect(find.byType(ImportSongScreen), findsNothing);
      expect(find.text('Javított cím'), findsWidgets);
    });
  });
}
