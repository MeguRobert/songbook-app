import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/setlist_provider.dart';

Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SetlistsNotifier', () {
    test('create adds a setlist to state', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container.read(setlistsProvider.notifier).create('Sunday');

      final setlists = container.read(setlistsProvider);
      expect(setlists.length, 1);
      expect(setlists.first.name, 'Sunday');
    });

    test('addSong / removeSong / reorder reflect in state', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(setlistsProvider.notifier);
      final created = await notifier.create('S');
      await notifier.addSong(created.id, const SongId.hymnal(1));
      await notifier.addSong(created.id, const SongId.hymnal(42));
      await notifier.addSong(created.id, const SongId.hymnal(151));
      await notifier.reorder(
        created.id,
        const [SongId.hymnal(151), SongId.hymnal(1), SongId.hymnal(42)],
      );
      await notifier.removeSong(created.id, const SongId.hymnal(1));

      final setlist = container.read(setlistByIdProvider(created.id));
      expect(setlist!.songIds,
          equals(const [SongId.hymnal(151), SongId.hymnal(42)]));
    });

    test('delete removes the setlist; setlistByIdProvider returns null',
        () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(setlistsProvider.notifier);
      final created = await notifier.create('S');
      await notifier.delete(created.id);

      expect(container.read(setlistsProvider), isEmpty);
      expect(container.read(setlistByIdProvider(created.id)), isNull);
    });
  });

  group('persistence end-to-end', () {
    test('a fresh container over the same prefs reads setlists back', () async {
      final prefs = await SharedPreferences.getInstance();

      final c1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      final created = await c1.read(setlistsProvider.notifier).create('Service');
      await c1
          .read(setlistsProvider.notifier)
          .addSong(created.id, const SongId.hymnal(42));
      await c1
          .read(setlistsProvider.notifier)
          .addSong(created.id, const SongId.hymnal(1));
      c1.dispose();

      // New container = simulated restart; same backing prefs.
      final c2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c2.dispose);

      final restored = c2.read(setlistsProvider);
      expect(restored.length, 1);
      expect(restored.first.name, 'Service');
      expect(restored.first.songIds,
          equals(const [SongId.hymnal(42), SongId.hymnal(1)]));
    });
  });
}
