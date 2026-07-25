import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/view_config.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';

Song song(int number) =>
    Song(number: number, title: 'Song $number', originalKey: 'C', verses: const []);

Future<ProviderContainer> makeContainer({
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('open/close song', () {
    test('initial state is null (no song open)', () async {
      final container = await makeContainer();
      expect(container.read(songViewProvider), isNull);
    });

    test('openSong initializes state with defaults', () async {
      final container = await makeContainer();
      container.read(songViewProvider.notifier).openSong(42);

      final state = container.read(songViewProvider);
      expect(state, isNotNull);
      expect(state!.songNumber, 42);
      expect(state.transposeAmount, 0);
      expect(state.textScale, 1.0);
      expect(state.activeViewConfig, isNull);
    });

    test('openSong picks up a persisted per-song view config override',
        () async {
      final container = await makeContainer(
          prefs: {'settings_song_view_config_42': 'false:true'});
      container.read(songViewProvider.notifier).openSong(42);

      expect(container.read(songViewProvider)!.activeViewConfig,
          const ViewConfig.chords());
    });

    test('closeSong resets state to null', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(42);
      notifier.closeSong();
      expect(container.read(songViewProvider), isNull);
    });
  });

  group('transpose', () {
    test('setTranspose sets the amount', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.setTranspose(3);
      expect(container.read(songViewProvider)!.transposeAmount, 3);
      expect(container.read(transposeProvider), 3);
    });

    test('transposeUp increments by one', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.transposeUp();
      notifier.transposeUp();
      expect(container.read(songViewProvider)!.transposeAmount, 2);
    });

    test('transposeUp wraps from +5 to -6', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.setTranspose(5);
      notifier.transposeUp();
      expect(container.read(songViewProvider)!.transposeAmount, -6);
    });

    test('transposeDown decrements by one', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.transposeDown();
      expect(container.read(songViewProvider)!.transposeAmount, -1);
    });

    test('transposeDown wraps from -6 to +5', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.setTranspose(-6);
      notifier.transposeDown();
      expect(container.read(songViewProvider)!.transposeAmount, 5);
    });

    test('a full 12-step up cycle returns to the starting amount', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      for (var i = 0; i < 12; i++) {
        notifier.transposeUp();
      }
      expect(container.read(songViewProvider)!.transposeAmount, 0);
    });

    test('resetTranspose returns to 0', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.setTranspose(-4);
      notifier.resetTranspose();
      expect(container.read(songViewProvider)!.transposeAmount, 0);
    });

    test('transpose operations without an open song are safe no-ops',
        () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      expect(() {
        notifier.setTranspose(3);
        notifier.transposeUp();
        notifier.transposeDown();
        notifier.resetTranspose();
      }, returnsNormally);
      expect(container.read(songViewProvider), isNull);
      expect(container.read(transposeProvider), 0);
    });
  });

  group('text scale', () {
    test('increase and decrease step by 0.1', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);

      notifier.increaseTextScale();
      expect(container.read(songViewProvider)!.textScale, closeTo(1.1, 1e-9));
      expect(container.read(textScaleProvider), closeTo(1.1, 1e-9));

      notifier.decreaseTextScale();
      expect(container.read(songViewProvider)!.textScale, closeTo(1.0, 1e-9));
    });

    test('clamps at the 2.0 upper bound', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.setTextScale(2.0);
      notifier.increaseTextScale();
      expect(container.read(songViewProvider)!.textScale, 2.0);
    });

    test('clamps at the 0.5 lower bound', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.setTextScale(0.5);
      notifier.decreaseTextScale();
      expect(container.read(songViewProvider)!.textScale, 0.5);
    });

    test('setTextScale clamps arbitrary values into 0.5..2.0', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.setTextScale(9.9);
      expect(container.read(songViewProvider)!.textScale, 2.0);
      notifier.setTextScale(0.01);
      expect(container.read(songViewProvider)!.textScale, 0.5);
    });

    test('resetTextScale returns to 1.0', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);
      notifier.setTextScale(1.7);
      notifier.resetTextScale();
      expect(container.read(songViewProvider)!.textScale, 1.0);
    });
  });

  group('view config', () {
    test('getEffectiveConfig falls back to the global setting', () async {
      final container =
          await makeContainer(prefs: {'settings_view_config': 'false:true'});
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);

      expect(notifier.getEffectiveConfig(), const ViewConfig.chords());
      expect(container.read(effectiveViewConfigProvider),
          const ViewConfig.chords());
    });

    test('per-song override wins over the global setting', () async {
      final container = await makeContainer(prefs: {
        'settings_view_config': 'false:true',
        'settings_song_view_config_1': 'true:false',
      });
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);

      // The per-song entry is notation-without-chords ('true:false'), which is
      // preserved verbatim now that the "Chords above staff" switch can produce
      // it; it still beats the global 'false:true' (chords) default.
      const notationWithoutChords =
          ViewConfig(showNotation: true, showChords: false);
      expect(notifier.getEffectiveConfig(), notationWithoutChords);
      expect(container.read(effectiveViewConfigProvider), notationWithoutChords);
    });

    test('setPreset applies a temporary override', () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(1);

      notifier.setPreset(const ViewConfig.lyricsOnly());
      expect(container.read(songViewProvider)!.activeViewConfig,
          const ViewConfig.lyricsOnly());
    });

    test('saveViewConfigForSong persists the active override per song',
        () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(7);
      notifier.setPreset(const ViewConfig.chords());

      await notifier.saveViewConfigForSong();

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('settings_song_view_config_7'), 'false:true');
    });

    test('saveViewConfigForSong without an override persists nothing',
        () async {
      final container = await makeContainer();
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(7);

      await notifier.saveViewConfigForSong();

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('settings_song_view_config_7'), isNull);
    });

    test('clearViewConfigForSong removes the persisted override', () async {
      final container = await makeContainer(
          prefs: {'settings_song_view_config_7': 'false:true'});
      final notifier = container.read(songViewProvider.notifier);
      notifier.openSong(7);

      await notifier.clearViewConfigForSong();

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('settings_song_view_config_7'), isNull);
      // NOTE: the in-memory activeViewConfig is NOT cleared, because
      // SongViewState.copyWith(activeViewConfig: null) keeps the previous
      // value (?? fallback). A fresh openSong reflects the cleared state.
      // If in-place reset is intended, copyWith needs a sentinel for null.
      notifier.openSong(7);
      expect(container.read(songViewProvider)!.activeViewConfig, isNull);
    });
  });

  group('derived providers without an open song', () {
    test('transpose and textScale fall back to defaults', () async {
      final container = await makeContainer();
      expect(container.read(transposeProvider), 0);
      expect(container.read(textScaleProvider), 1.0);
    });

    test('effectiveViewConfigProvider falls back to the global config',
        () async {
      final container =
          await makeContainer(prefs: {'settings_view_config': 'false:false'});
      expect(container.read(effectiveViewConfigProvider),
          const ViewConfig.lyricsOnly());
    });
  });

  group('song data providers', () {
    test('songsProvider override is honored and songCountProvider derives',
        () async {
      final container = await makeContainer(overrides: [
        songsProvider.overrideWith((ref) async => [song(1), song(2)]),
      ]);
      final songs = await container.read(songsProvider.future);
      expect(songs, hasLength(2));
      expect(await container.read(songCountProvider.future), 2);
    });
  });

  group('SongViewState.copyWith', () {
    test('overrides fields independently', () {
      const state = SongViewState(songNumber: 1);
      expect(state.copyWith(transposeAmount: 4).transposeAmount, 4);
      expect(state.copyWith(transposeAmount: 4).songNumber, 1);
      expect(state.copyWith(textScale: 1.5).textScale, 1.5);
      expect(
          state
              .copyWith(activeViewConfig: const ViewConfig.chords())
              .activeViewConfig,
          const ViewConfig.chords());
    });
  });
}
