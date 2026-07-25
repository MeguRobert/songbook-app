import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/view_config.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/settings_provider.dart';

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
    test('uses defaults when nothing is stored', () async {
      final container = await makeContainer();
      final state = container.read(settingsProvider);
      expect(state.fontSize, 18.0);
      expect(state.viewConfig, const ViewConfig());
    });

    test('loads persisted settings', () async {
      final container = await makeContainer(prefs: {
        'settings_font_size': 24,
        'settings_view_config': 'false:true',
      });
      final state = container.read(settingsProvider);
      expect(state.fontSize, 24.0);
      expect(state.viewConfig, const ViewConfig.chords());
    });
  });

  group('setFontSize', () {
    test('updates state and persists rounded value', () async {
      final container = await makeContainer();
      await container.read(settingsProvider.notifier).setFontSize(20.0);

      expect(container.read(settingsProvider).fontSize, 20.0);
      expect(container.read(fontSizeProvider), 20.0);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getInt('settings_font_size'), 20);
    });
  });

  group('increase/decrease font size', () {
    test('increase steps by 2 and caps at 32', () async {
      final container = await makeContainer(prefs: {'settings_font_size': 30});
      final notifier = container.read(settingsProvider.notifier);

      notifier.increaseFontSize();
      await pumpEventQueue();
      expect(container.read(settingsProvider).fontSize, 32.0);

      notifier.increaseFontSize(); // at cap: no-op
      await pumpEventQueue();
      expect(container.read(settingsProvider).fontSize, 32.0);
    });

    test('decrease steps by 2 and floors at 12', () async {
      final container = await makeContainer(prefs: {'settings_font_size': 14});
      final notifier = container.read(settingsProvider.notifier);

      notifier.decreaseFontSize();
      await pumpEventQueue();
      expect(container.read(settingsProvider).fontSize, 12.0);

      notifier.decreaseFontSize(); // at floor: no-op
      await pumpEventQueue();
      expect(container.read(settingsProvider).fontSize, 12.0);
    });
  });

  group('view config', () {
    test('setViewConfig updates state and persists', () async {
      final container = await makeContainer();
      await container
          .read(settingsProvider.notifier)
          .setViewConfig(const ViewConfig.lyricsOnly());

      expect(container.read(settingsProvider).viewConfig,
          const ViewConfig.lyricsOnly());
      expect(container.read(viewConfigProvider), const ViewConfig.lyricsOnly());
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('settings_view_config'), 'false:false');
    });

    test('setPreset applies and persists the preset', () async {
      final container = await makeContainer();
      await container
          .read(settingsProvider.notifier)
          .setPreset(const ViewConfig.chords());
      expect(container.read(settingsProvider).viewConfig,
          const ViewConfig.chords());
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('settings_view_config'), 'false:true');
    });
  });

  group('SettingsState.copyWith', () {
    test('overrides fields independently', () {
      const state = SettingsState();
      expect(state.copyWith(fontSize: 22).fontSize, 22);
      expect(state.copyWith(fontSize: 22).viewConfig, const ViewConfig());
      expect(
          state.copyWith(viewConfig: const ViewConfig.chords()).viewConfig,
          const ViewConfig.chords());
      expect(state.copyWith(viewConfig: const ViewConfig.chords()).fontSize,
          18.0);
    });
  });

  test('persisted settings are re-read by a fresh container', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    final first = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ]);
    await first.read(settingsProvider.notifier).setFontSize(26.0);
    await first
        .read(settingsProvider.notifier)
        .setViewConfig(const ViewConfig.chords());
    first.dispose();

    final second = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ]);
    addTearDown(second.dispose);
    final state = second.read(settingsProvider);
    expect(state.fontSize, 26.0);
    expect(state.viewConfig, const ViewConfig.chords());
  });
}
