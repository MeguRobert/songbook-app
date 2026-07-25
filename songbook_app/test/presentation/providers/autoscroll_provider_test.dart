import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/repositories/settings_repository.dart';
import 'package:songbook_app/presentation/providers/autoscroll_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';

Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AutoScrollNotifier', () {
    test('starts paused at the default speed', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final state = container.read(autoScrollProvider);
      expect(state.isPlaying, isFalse);
      expect(state.speed, 40.0);
    });

    test('toggle / play / pause flip the playing flag', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(autoScrollProvider.notifier);

      notifier.toggle();
      expect(container.read(autoScrollProvider).isPlaying, isTrue);
      notifier.pause();
      expect(container.read(autoScrollProvider).isPlaying, isFalse);
      notifier.play();
      expect(container.read(autoScrollProvider).isPlaying, isTrue);
    });

    test('setSpeed clamps to the allowed range', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(autoScrollProvider.notifier);
      notifier.init(1);

      notifier.setSpeed(9999);
      expect(container.read(autoScrollProvider).speed, AutoScrollState.maxSpeed);
      notifier.setSpeed(-5);
      expect(container.read(autoScrollProvider).speed, AutoScrollState.minSpeed);
    });

    test('speed is persisted per song and restored on init', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(autoScrollProvider.notifier);

      notifier.init(42);
      // setSpeed only updates live state (it runs on every slider frame);
      // commitSpeed is what writes to SharedPreferences, on drag end.
      notifier.setSpeed(90);
      expect(container.read(autoScrollProvider).speed, 90.0);
      notifier.commitSpeed();

      // A fresh notifier (same prefs) restores the persisted speed for song 42
      // but keeps the default for an untouched song.
      final repo = container.read(settingsRepositoryProvider);
      expect(repo.getAutoScrollSpeed(42), 90);
      expect(repo.getAutoScrollSpeed(7),
          SettingsRepository.defaultAutoScrollSpeed);

      notifier.init(7);
      expect(container.read(autoScrollProvider).speed,
          SettingsRepository.defaultAutoScrollSpeed.toDouble());
      notifier.init(42);
      expect(container.read(autoScrollProvider).speed, 90.0);
    });

    test('init resets playing to paused', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(autoScrollProvider.notifier);

      notifier.play();
      notifier.init(3);
      expect(container.read(autoScrollProvider).isPlaying, isFalse);
    });
  });
}
