import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';
import 'package:songbook_app/presentation/screens/notation_editor/notation_editor_screen.dart';
import 'package:songbook_app/presentation/screens/presentation/presentation_screen.dart';
import 'package:songbook_app/presentation/screens/setlists/setlist_detail_screen.dart';
import 'package:songbook_app/presentation/screens/song_list/song_list_screen.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';
import 'package:songbook_app/router/app_router.dart';

import 'helpers.dart';

/// One thing the router told the platform about the URL.
typedef _Entry = ({String uri, Object? state, bool replace});

/// Records what the browser's address bar and history would have been told.
///
/// `SystemNavigator.routeInformationUpdated` is the *only* channel between the
/// router and the browser URL on web, so recording it is how a VM test asserts
/// on something that is otherwise only visible in a browser. `replace` is the
/// difference between "the address bar changed" and "a history entry was
/// created", which is what makes the back button work.
class _AddressBar {
  _AddressBar(this._tester) {
    _tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          final args = call.arguments as Map<Object?, Object?>;
          entries.add((
            uri: args['uri'] as String,
            state: args['state'],
            replace: args['replace'] as bool,
          ));
        }
        return null;
      },
    );
    addTearDown(() => _tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, null));
  }

  final WidgetTester _tester;

  final entries = <_Entry>[];

  /// What the address bar shows now.
  String get url => entries.isEmpty ? '<never reported>' : entries.last.uri;

  /// Every location that got its own history entry, oldest first.
  List<String> get history =>
      entries.where((e) => !e.replace).map((e) => e.uri).toList();

  /// Presses the browser's Back button by replaying an earlier history entry
  /// the way the engine does — same uri, same opaque state.
  Future<void> back(_Entry to) async {
    await _tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(MethodCall(
        'pushRouteInformation',
        <String, Object?>{'location': to.uri, 'state': to.state},
      )),
      (_) {},
    );
    await _tester.pumpAndSettle();
  }
}

/// Mounts the real app router over real storage.
Future<(GoRouter, _AddressBar)> pumpApp(WidgetTester tester) async {
  final bar = _AddressBar(tester);
  final container = await makeAppContainer();
  final router = container.read(routerProvider);
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: localizedRouterApp(router),
  ));
  await tester.pumpAndSettle();
  return (router, bar);
}

/// Cold-loads [location] against the real route table — what a pasted link,
/// a bookmark or a hand-edited address bar does.
///
/// On web the browser's URL beats `initialLocation`, so this is as close as a VM
/// test gets to a fresh tab; the location goes through the same parser and
/// matcher either way.
Future<GoRouter> pumpAppAt(
  WidgetTester tester,
  String location, {
  List<Song> userSongs = const [],
}) async {
  final container =
      await makeAppContainer(prefs: const {'settings_view_config': 'false:true'});
  for (final song in userSongs) {
    await container.read(userSongsProvider.notifier).add(song);
  }
  final router = createAppRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: localizedRouterApp(router),
  ));
  await tester.pumpAndSettle();
  return router;
}

/// A song the user added, so a `user:` deep link has something to resolve to.
Song savedSong({String ref = 'abc'}) => Song(
      number: 1,
      title: 'Az Úrra bízom életem',
      originalKey: 'G',
      explicitId: SongId.user(ref),
      verses: const [
        Verse(number: 1, lines: [LyricLine(text: 'Az Úrra bízom életem')]),
      ],
    );

void main() {
  const song = SongId.hymnal(42);

  group('the address bar follows navigation', () {
    testWidgets('switching to a tab puts the tab in the URL', (tester) async {
      final (router, bar) = await pumpApp(tester);
      router.go(AppRoutes.settings);
      await tester.pumpAndSettle();

      expect(bar.url, '/settings');
    });

    testWidgets('opening a song puts the song in the URL', (tester) async {
      final (router, bar) = await pumpApp(tester);
      router.push(AppRoutes.songPath(song));
      await tester.pumpAndSettle();

      expect(bar.url, '/song/hymnal:42');
    });

    testWidgets('opening a song adds a history entry to go back to',
        (tester) async {
      final (router, bar) = await pumpApp(tester);
      router.push(AppRoutes.songPath(song));
      await tester.pumpAndSettle();

      expect(bar.history, contains('/song/hymnal:42'));
    });

    testWidgets('presentation mode has its own URL', (tester) async {
      final (router, bar) = await pumpApp(tester);
      router.push(AppRoutes.songPath(song));
      await tester.pumpAndSettle();
      router.push(AppRoutes.presentationPath(song));
      await tester.pumpAndSettle();

      expect(bar.url, '/presentation/hymnal:42');
    });

    testWidgets('the browser back button leaves the song', (tester) async {
      final (router, bar) = await pumpApp(tester);
      final atList = bar.entries.last;
      router.push(AppRoutes.songPath(song));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/song/hymnal:42',
          reason: 'the song must be open, or Back proves nothing');

      await bar.back(atList);

      expect(router.state.uri.path, AppRoutes.home);
    });
  });

  /// A [SongId] is `source:ref`, so every song URL carries a colon in a path
  /// segment. It is legal there unencoded (RFC 3986 `pchar`), and go_router
  /// percent-decodes path parameters — so both spellings of the same link have
  /// to land on the same song, because whichever one the user copied is the one
  /// that has to work.
  group('a pasted song link opens that song', () {
    testWidgets('a bundled hymnal id', (tester) async {
      await pumpAppAt(tester, '/song/hymnal:42');

      expect(
        tester.widget<SongViewScreen>(find.byType(SongViewScreen)).songId,
        const SongId.hymnal(42),
      );
    });

    testWidgets('a user song id', (tester) async {
      await pumpAppAt(tester, '/song/user:abc',
          userSongs: [savedSong(ref: 'abc')]);

      expect(
        tester.widget<SongViewScreen>(find.byType(SongViewScreen)).songId,
        const SongId.user('abc'),
      );
      expect(find.text('Az Úrra bízom életem'), findsWidgets);
    });

    testWidgets('a percent-encoded colon names the same song', (tester) async {
      await pumpAppAt(tester, '/song/hymnal%3A42');

      expect(
        tester.widget<SongViewScreen>(find.byType(SongViewScreen)).songId,
        const SongId.hymnal(42),
      );
    });

    testWidgets('presentation mode', (tester) async {
      await pumpAppAt(tester, '/presentation/hymnal:42');

      expect(
        tester.widget<PresentationScreen>(find.byType(PresentationScreen)).songId,
        const SongId.hymnal(42),
      );
    });

    testWidgets('the correction screen for a user song', (tester) async {
      await pumpAppAt(tester, '/song/user:abc/edit',
          userSongs: [savedSong(ref: 'abc')]);

      expect(
        tester.widget<ImportSongScreen>(find.byType(ImportSongScreen)).editingId,
        const SongId.user('abc'),
      );
    });

    testWidgets('the notation editor', (tester) async {
      await pumpAppAt(tester, '/song/user:abc/notation',
          userSongs: [savedSong(ref: 'abc')]);

      expect(
        tester
            .widget<NotationEditorScreen>(find.byType(NotationEditorScreen))
            .songId,
        const SongId.user('abc'),
      );
    });

    testWidgets('a setlist', (tester) async {
      await pumpAppAt(tester, '/setlists/xyz');

      expect(
        tester
            .widget<SetlistDetailScreen>(find.byType(SetlistDetailScreen))
            .setlistId,
        'xyz',
      );
    });

    testWidgets('a path that is not a route shows the 404, not a song',
        (tester) async {
      await pumpAppAt(tester, '/nonsense');

      expect(find.byType(SongViewScreen), findsNothing);
      expect(find.text('Page not found'), findsOneWidget);
    });
  });

  /// Search and the tag browser were folded into the song list, so their paths
  /// only exist to keep old links alive. Pinned here because a redirect that
  /// quietly stops carrying its `tag` looks identical to one that works.
  group('a link to a retired path still lands somewhere useful', () {
    String? seededTag(WidgetTester tester) =>
        tester.widget<SongListScreen>(find.byType(SongListScreen)).initialTag;

    testWidgets('/search opens the list', (tester) async {
      final router = await pumpAppAt(tester, '/search');

      expect(router.state.uri.path, AppRoutes.home);
      expect(seededTag(tester), isNull);
    });

    testWidgets('/search?tag= seeds the tag filter', (tester) async {
      await pumpAppAt(tester, '/search?tag=zsolt%C3%A1r');

      expect(seededTag(tester), 'zsoltár');
    });

    testWidgets('?tag= on the list itself seeds the tag filter',
        (tester) async {
      await pumpAppAt(tester, '/?tag=zsolt%C3%A1r');

      expect(seededTag(tester), 'zsoltár');
    });

    testWidgets('/books opens the list', (tester) async {
      final router = await pumpAppAt(tester, '/books');

      expect(router.state.uri.path, AppRoutes.home);
    });

    testWidgets('/tags opens the list', (tester) async {
      final router = await pumpAppAt(tester, '/tags');

      expect(router.state.uri.path, AppRoutes.home);
    });
  });
}
