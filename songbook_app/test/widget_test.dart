import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/app.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/widgets/scaffold_with_nav_bar.dart';

import 'widget/helpers.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final songs = [makeTestSong()];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Real songs load from rootBundle assets, which does not complete
          // under the widget-test fake-async zone; use fixture data instead.
          songsProvider.overrideWith((ref) async => songs),
        ],
        child: const SongbookApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('App starts on the song list with bottom navigation',
      (tester) async {
    await pumpApp(tester);

    // Home route: song list inside the navigation shell.
    expect(find.byType(ScaffoldWithNavBar), findsOneWidget);
    expect(find.text('Songbook'), findsOneWidget);
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches between shell screens',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);

    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();
    expect(find.text('Songbook'), findsOneWidget);
  });
}
