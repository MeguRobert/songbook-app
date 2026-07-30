import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';

import 'helpers.dart';

/// Saving, exercised through a REAL GoRouter.
///
/// The plain widget harness has no router, so every earlier test stopped short
/// of the Save handler's navigation and the whole path went uncovered. What
/// hid there: `_BookField` used `Autocomplete`, whose `fieldViewBuilder` runs
/// on every build, and mirrored its controller by attaching a listener there.
/// Listeners accumulated one per rebuild, each calling setState — so tapping
/// Save rebuilt, fired a listener, called setState during build and threw
/// before anything was written. The song silently never saved.
void main() {
  testWidgets('Save writes the song, then navigates to it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(initialLocation: '/import', routes: [
      GoRoute(path: '/import', builder: (_, __) => const ImportSongScreen()),
      GoRoute(path: '/song/:id', builder: (_, s) => const Scaffold(body: Text('SONG PAGE'))),
    ]);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: localizedRouterApp(router),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'G       C\nAz Úrra bízom életem\n');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Teszt ének');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Number'), '7');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Songbook'), 'Saját énekek');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final saved = container.read(userSongsProvider);
    expect(saved, hasLength(1));
    expect(saved.single.title, 'Teszt ének');
    expect(saved.single.book, 'Saját énekek');
    expect(find.text('SONG PAGE'), findsOneWidget);
  });
}

