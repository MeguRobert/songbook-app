import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/l10n/app_localizations.dart';
import 'package:songbook_app/presentation/providers/locale_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/settings/settings_screen.dart';

import 'helpers.dart';

/// The translations have to reach the screen, not merely exist in an ARB file.
///
/// The ARB-level guards live in test/l10n; these pump a real widget, because the
/// ways this breaks are all in the wiring: a delegate missing from MaterialApp, a
/// const default string no localisation can reach, a screen still holding its own
/// literal.
///
/// Settings is the subject because it needs no router and it is the one screen
/// that must be legible in a language you did not mean to select.
void main() {
  group('the interface follows the chosen language', () {
    testWidgets('Hungarian', (tester) async {
      await pumpScreen(tester, const SettingsScreen(),
          locale: const Locale('hu'));
      await tester.pumpAndSettle();

      expect(find.text('Beállítások'), findsWidgets);
      expect(find.text('Nyelv'), findsWidgets);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('Romanian', (tester) async {
      await pumpScreen(tester, const SettingsScreen(),
          locale: const Locale('ro'));
      await tester.pumpAndSettle();

      expect(find.text('Setări'), findsWidgets);
      expect(find.text('Limbă'), findsWidgets);
    });

    testWidgets('English', (tester) async {
      await pumpScreen(tester, const SettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Language'), findsWidgets);
    });
  });

  group('the language picker', () {
    testWidgets('offers every language plus "follow the device"',
        (tester) async {
      await pumpScreen(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language').first);
      await tester.pumpAndSettle();

      // Named in their own languages, so the list stays readable whatever the
      // interface is currently set to.
      expect(find.text('Magyar'), findsOneWidget);
      expect(find.text('Română'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Match my device'), findsWidgets);
    });

    testWidgets('picking one changes the app, not just a stored value',
        (tester) async {
      // Mounted the way app.dart mounts it — MaterialApp.locale watching the
      // provider — because that chain is the thing under test. pumpScreen pins
      // the locale so its assertions can be written in one language, which would
      // mask exactly this.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(localeProvider),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const SettingsScreen(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Language').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Magyar'));
      await tester.pumpAndSettle();

      expect(find.text('Nyelv'), findsWidgets);
      expect(find.text('Language'), findsNothing);
    });
  });

  group('a stored language this build does not have', () {
    test('is ignored rather than honoured', () async {
      // Dropping a language from the ARB set must not leave someone stuck in it
      // with no way back — the override resolves to null, which means "follow
      // the device".
      SharedPreferences.setMockInitialValues({'settings_locale': 'de'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(localeProvider), isNull);
    });

    test('a supported one is restored', () async {
      SharedPreferences.setMockInitialValues({'settings_locale': 'ro'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(localeProvider)?.languageCode, 'ro');
    });
  });
}
