import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/core/theme/app_theme.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/data/repositories/song_repository.dart';
import 'package:songbook_app/l10n/app_localizations.dart';
import 'package:songbook_app/presentation/providers/providers.dart';

/// Builds a test song with one structured verse (with chords) and one
/// plain-text verse.
Song makeTestSong({
  int number = 42,
  String title = 'Mint a szép híves patakra',
  String originalKey = 'Bb',
}) {
  return Song(
    number: number,
    title: title,
    reference: 'Zsolt 42',
    originalKey: originalKey,
    verses: const [
      Verse(
        number: 1,
        hasNotation: true,
        lines: [
          LyricLine(
            text: 'Mint a szép híves patakra',
            chords: [ChordPosition(chord: 'Bb', position: 0)],
          ),
          LyricLine(text: 'A szarvas kívánkozik'),
        ],
      ),
      Verse(number: 2, plainText: 'Second verse plain text'),
    ],
    tags: const ['zsoltár'],
  );
}

/// The bundled catalogue with the asset read taken out.
///
/// `rootBundle.loadString` never completes inside `testWidgets` — the fake-async
/// zone does not pump the message loop the asset bundle waits on — so a widget
/// test that lets `songsProvider` reach `assets/data/songs.json` hangs in
/// `pumpAndSettle` with a spinner on screen. Overriding only this keeps every
/// seam that matters live: notifier -> storage -> catalogue merge -> lookup by
/// id.
class EmptyBundledCatalogue extends SongRepository {
  EmptyBundledCatalogue(super.dataSource);

  @override
  Future<List<Song>> getAllSongs() async => const [];
}

/// A container over mocked SharedPreferences with the bundled catalogue stubbed
/// empty, for tests that drive the real providers rather than overriding them.
Future<ProviderContainer> makeAppContainer({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
    songRepositoryProvider
        .overrideWithValue(EmptyBundledCatalogue(LocalDataSource(preferences))),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Localisation wiring for the tests that build their own [MaterialApp] rather
/// than going through [pumpScreen] — a real router, or a custom MediaQuery.
///
/// Without the delegates `AppLocalizations.of` throws, which is a failure about
/// the harness rather than about anything under test.
const localizationsForTest = (
  delegates: AppLocalizations.localizationsDelegates,
  locales: AppLocalizations.supportedLocales,
  locale: Locale('en'),
);

/// A localised [MaterialApp.router], for tests that need real navigation.
Widget localizedRouterApp(RouterConfig<Object> router) => MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    );

/// A localised [MaterialApp] around a single [home] widget.
Widget localizedApp(Widget home) => MaterialApp(
      home: home,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    );

/// Pumps [child] inside a ProviderScope + MaterialApp with a mocked
/// SharedPreferences (seeded with [prefs]) and any extra [overrides].
/// [themeMode] mounts the app's REAL light/dark themes rather than Material's
/// defaults, for the screens whose colours are derived from them.
///
/// [locale] defaults to English so the assertions in these tests can be written
/// in one language; pass another to check a translation actually reaches the
/// screen. Every pumped widget gets the localisation delegates either way —
/// without them `AppLocalizations.of` throws, which is not a failure any test
/// here is about.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  ThemeMode? themeMode,
  Locale? locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ...overrides,
      ],
      child: themeMode == null
          ? MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              home: child,
            )
          : MaterialApp(
              theme: createLightTheme(),
              darkTheme: createDarkTheme(),
              themeMode: themeMode,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              home: child,
            ),
    ),
  );
}
