import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/recents_provider.dart';

Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RecentsNotifier', () {
    test('record updates state most-recent first', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recentsProvider.notifier);

      await notifier.record(1, now: DateTime(2026, 1, 1));
      await notifier.record(42, now: DateTime(2026, 1, 2));

      expect(container.read(recentsProvider), equals([42, 1]));
      expect(container.read(lastViewedSongProvider), 42);
    });

    test('clear empties state and lastViewed becomes null', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recentsProvider.notifier);

      await notifier.record(5);
      await notifier.clear();

      expect(container.read(recentsProvider), isEmpty);
      expect(container.read(lastViewedSongProvider), isNull);
    });
  });
}
