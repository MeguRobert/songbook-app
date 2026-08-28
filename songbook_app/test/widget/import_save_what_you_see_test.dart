import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';

import 'helpers.dart';

/// Saving stores what is on the screen, not what was last parsed.
///
/// Reported from the live app, in Hungarian, as *"I can edit them, but no
/// matter that I save, it doesn't get saved"* — and it was exactly that. The
/// paste box does not re-parse as it is typed in, and the screen treated the
/// typing as an *offer* that only Parse accepted, so `_pending` was reset to
/// the stored song on every keystroke. Correcting a lyric and pressing Save
/// wrote the OLD verses back, reported success, and said nothing.
///
/// The tell that made it look random: a title-only edit worked, because the
/// title is read straight off its controller. Only the words were lost. Both
/// halves are covered here, because a fix that saved the words by breaking the
/// title would otherwise look like a pass.
///
/// Driven through a real GoRouter, for the same reason
/// `import_song_save_test.dart` is: Save navigates, and the edit screen is
/// reached by a route. A harness without a router stops short of both.
void main() {
  late ProviderContainer container;
  late GoRouter router;

  /// A router with the three routes this exercise needs, mirroring the real
  /// one's shape — `/song/:id/edit` has three segments so it cannot collide
  /// with `/song/:id`.
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    router = GoRouter(initialLocation: '/import', routes: [
      GoRoute(path: '/import', builder: (_, __) => const ImportSongScreen()),
      GoRoute(
        path: '/song/:id/edit',
        builder: (_, state) => ImportSongScreen(
          editingId: SongId.tryParse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
          path: '/song/:id',
          builder: (_, __) => const Scaffold(body: Text('SONG PAGE'))),
    ]);
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: localizedRouterApp(router),
    ));
    await tester.pumpAndSettle();
  }

  /// Creates one song the ordinary way, and returns to its edit screen.
  Future<void> createThenEdit(WidgetTester tester) async {
    await tester.enterText(
        find.byType(TextField).first, 'D        G\nEredeti sor\n');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Eredeti cím');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Number'), '902');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = container.read(userSongsProvider).single;
    router.go('/song/${stored.id}/edit');
    await tester.pumpAndSettle();
  }

  String wordsOf(Song song) =>
      song.verses.expand((v) => v.lines.map((l) => l.text)).join(' ');

  testWidgets('words typed into the box are saved without pressing Parse',
      (tester) async {
    await pumpApp(tester);
    await createThenEdit(tester);

    // Correct the words — deliberately WITHOUT pressing Parse, which is what a
    // person does when the button they want says Save.
    await tester.enterText(
        find.byType(TextField).first, 'D        G\nJavitott sor\n');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final saved = container.read(userSongsProvider).single;
    expect(wordsOf(saved), contains('Javitott sor'),
        reason: 'the words on screen are what Save must store');
    expect(wordsOf(saved), isNot(contains('Eredeti sor')),
        reason: 'the previously parsed words must not survive the correction');
  });

  testWidgets('a title-only change still saves, and keeps the words',
      (tester) async {
    // The half that always worked. Kept so a fix for the words above cannot
    // quietly break it.
    await pumpApp(tester);
    await createThenEdit(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Csak a cím');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final saved = container.read(userSongsProvider).single;
    expect(saved.title, 'Csak a cím');
    expect(wordsOf(saved), contains('Eredeti sor'),
        reason: 'an untouched box must not lose the words it already held');
  });

  testWidgets('emptying the box is refused rather than stored as nothing',
      (tester) async {
    // The re-parse on save can change the answer to "is there anything to
    // save", so the blockers are re-checked after it. Without that, clearing
    // the box and pressing Save would overwrite the song with no verses.
    await pumpApp(tester);
    await createThenEdit(tester);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final saved = container.read(userSongsProvider).single;
    expect(wordsOf(saved), contains('Eredeti sor'),
        reason: 'a song must not be emptied by a save it should have refused');
  });
}
