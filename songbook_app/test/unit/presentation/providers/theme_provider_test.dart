import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/core/theme/app_theme.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/theme_provider.dart';

Future<ProviderContainer> makeContainer(
    {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initial load', () {
    test('defaults to system when nothing is stored', () async {
      final container = await makeContainer();
      expect(container.read(themeModeProvider), AppThemeMode.system);
    });

    test('loads the persisted mode', () async {
      final container =
          await makeContainer(prefs: {'settings_theme_mode': 'dark'});
      expect(container.read(themeModeProvider), AppThemeMode.dark);
    });

    test('unknown persisted value falls back to system', () async {
      final container =
          await makeContainer(prefs: {'settings_theme_mode': 'sepia'});
      expect(container.read(themeModeProvider), AppThemeMode.system);
    });
  });

  group('setThemeMode', () {
    test('updates state and persists', () async {
      final container = await makeContainer();
      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(AppThemeMode.light);

      expect(container.read(themeModeProvider), AppThemeMode.light);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('settings_theme_mode'), 'light');
    });
  });

  group('toggleTheme', () {
    test('cycles light -> dark -> system -> light', () async {
      final container =
          await makeContainer(prefs: {'settings_theme_mode': 'light'});
      final notifier = container.read(themeModeProvider.notifier);

      await notifier.toggleTheme();
      expect(container.read(themeModeProvider), AppThemeMode.dark);
      await notifier.toggleTheme();
      expect(container.read(themeModeProvider), AppThemeMode.system);
      await notifier.toggleTheme();
      expect(container.read(themeModeProvider), AppThemeMode.light);
    });
  });

  group('flutterThemeModeProvider', () {
    test('maps app theme mode to Flutter ThemeMode', () async {
      final container = await makeContainer();
      expect(container.read(flutterThemeModeProvider), ThemeMode.system);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(AppThemeMode.dark);
      expect(container.read(flutterThemeModeProvider), ThemeMode.dark);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(AppThemeMode.light);
      expect(container.read(flutterThemeModeProvider), ThemeMode.light);
    });
  });

  test('disposing the container after use does not throw', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ]);
    await container
        .read(themeModeProvider.notifier)
        .setThemeMode(AppThemeMode.dark);
    expect(container.dispose, returnsNormally);
  });
}
