import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/favorite.dart';

Future<LocalDataSource> makeDataSource(
    [Map<String, Object> initialValues = const {}]) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return LocalDataSource(prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadSongs', () {
    test('loads the bundled songs.json, sorted by number', () async {
      final ds = await makeDataSource();
      final songs = await ds.loadSongs();
      expect(songs, isNotEmpty);
      expect(songs.map((s) => s.number).isSorted((a, b) => a.compareTo(b)),
          isTrue);
    });

    test('caches the loaded list (same instance on second call)', () async {
      final ds = await makeDataSource();
      final first = await ds.loadSongs();
      final second = await ds.loadSongs();
      expect(identical(first, second), isTrue);
    });

    test('clearSongCache forces a reload', () async {
      final ds = await makeDataSource();
      final first = await ds.loadSongs();
      ds.clearSongCache();
      final second = await ds.loadSongs();
      expect(identical(first, second), isFalse);
      expect(second.map((s) => s.number), first.map((s) => s.number));
    });
  });

  group('getSongByNumber', () {
    test('returns the matching song', () async {
      final ds = await makeDataSource();
      final songs = await ds.loadSongs();
      final target = songs.first;
      final found = await ds.getSongByNumber(target.number);
      expect(found, target);
    });

    test('returns null for an unknown number', () async {
      final ds = await makeDataSource();
      expect(await ds.getSongByNumber(999999), isNull);
    });
  });

  group('favorites', () {
    test('getFavorites returns empty list when nothing stored', () async {
      final ds = await makeDataSource();
      expect(ds.getFavorites(), isEmpty);
    });

    test('getFavorites returns empty list for corrupt JSON', () async {
      final ds = await makeDataSource({'favorites': 'not json'});
      expect(ds.getFavorites(), isEmpty);
    });

    test('addFavorite persists and getFavorites reads it back', () async {
      final ds = await makeDataSource();
      expect(await ds.addFavorite(42), isTrue);
      final favorites = ds.getFavorites();
      expect(favorites.map((f) => f.songNumber), [42]);
      expect(ds.isFavorite(42), isTrue);
      expect(ds.isFavorite(43), isFalse);
    });

    test('addFavorite is a no-op for an existing favorite', () async {
      final ds = await makeDataSource();
      await ds.addFavorite(42);
      expect(await ds.addFavorite(42), isTrue);
      expect(ds.getFavorites(), hasLength(1));
    });

    test('addFavorite assigns increasing sortOrder', () async {
      final ds = await makeDataSource();
      await ds.addFavorite(1);
      await ds.addFavorite(2);
      await ds.addFavorite(3);
      final orders = ds.getFavorites().map((f) => f.sortOrder).toList();
      expect(orders, [1, 2, 3]);
    });

    test('removeFavorite deletes only the given song', () async {
      final ds = await makeDataSource();
      await ds.addFavorite(1);
      await ds.addFavorite(2);
      await ds.removeFavorite(1);
      expect(ds.getFavorites().map((f) => f.songNumber), [2]);
      expect(ds.isFavorite(1), isFalse);
    });

    test('removeFavorite on a non-favorite leaves the list intact', () async {
      final ds = await makeDataSource();
      await ds.addFavorite(1);
      await ds.removeFavorite(99);
      expect(ds.getFavorites().map((f) => f.songNumber), [1]);
    });

    test('saveFavorites overwrites the stored list', () async {
      final ds = await makeDataSource();
      await ds.addFavorite(1);
      await ds.saveFavorites([
        Favorite(songNumber: 7, addedAt: DateTime(2026), sortOrder: 0),
      ]);
      expect(ds.getFavorites().map((f) => f.songNumber), [7]);
    });

    test('favorites survive as JSON in shared preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ds = LocalDataSource(prefs);
      await ds.addFavorite(5);

      final raw = prefs.getString('favorites');
      expect(raw, isNotNull);
      final decoded = json.decode(raw!) as List<dynamic>;
      expect(decoded.single['songNumber'], 5);
    });
  });

  // Audit finding S14. A single unreadable record must not take the whole
  // collection with it: the previous `catch (_) { return []; }` wrapped the
  // entire `map`, so one bad entry silently presented as "you have no
  // favourites / no setlists / no history" and the next write erased the rest.
  group('partial corruption', () {
    test('getFavorites keeps the readable entries and skips the bad one',
        () async {
      final ds = await makeDataSource({
        'favorites': json.encode([
          {
            'songNumber': 1,
            'addedAt': '2026-01-01T00:00:00.000',
            'sortOrder': 0,
          },
          {'songNumber': 'not-a-number', 'addedAt': 'not-a-date'},
          {
            'songNumber': 3,
            'addedAt': '2026-01-03T00:00:00.000',
            'sortOrder': 2,
          },
        ]),
      });

      expect(ds.getFavorites().map((f) => f.songNumber), [1, 3]);
    });

    test('getFavorites skips an entry that is not an object at all', () async {
      final ds = await makeDataSource({
        'favorites': json.encode([
          'garbage',
          {
            'songNumber': 9,
            'addedAt': '2026-01-01T00:00:00.000',
            'sortOrder': 0,
          },
        ]),
      });

      expect(ds.getFavorites().map((f) => f.songNumber), [9]);
    });

    test('getSetlists keeps the readable entries and skips the bad one',
        () async {
      Map<String, Object?> setlist(String id, String name) => {
            'id': id,
            'name': name,
            'songNumbers': [1, 2],
            'createdAt': '2026-01-01T00:00:00.000',
            'updatedAt': '2026-01-01T00:00:00.000',
          };

      final ds = await makeDataSource({
        'setlists': json.encode([
          setlist('a', 'Sunday'),
          {'id': 'broken'}, // missing required name/createdAt/updatedAt
          setlist('c', 'Evening'),
        ]),
      });

      expect(ds.getSetlists().map((s) => s.id), ['a', 'c']);
    });

    test('getRecentSongs keeps the readable entries and skips the bad one',
        () async {
      final ds = await makeDataSource({
        'recent_songs': json.encode([
          {'n': 1, 't': 1000},
          {'n': 'oops'},
          {'n': 3, 't': 3000},
        ]),
      });

      expect(ds.getRecentSongs().map((r) => r.songNumber), [1, 3]);
    });

    test('a wholly unreadable blob still yields an empty collection', () async {
      final ds = await makeDataSource({
        'favorites': 'not json',
        'setlists': 'not json',
        'recent_songs': 'not json',
      });

      expect(ds.getFavorites(), isEmpty);
      expect(ds.getSetlists(), isEmpty);
      expect(ds.getRecentSongs(), isEmpty);
    });
  });

  group('settings', () {
    test('string settings round-trip and are namespaced', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ds = LocalDataSource(prefs);

      expect(ds.getStringSetting('theme'), isNull);
      await ds.setStringSetting('theme', 'dark');
      expect(ds.getStringSetting('theme'), 'dark');
      expect(prefs.getString('settings_theme'), 'dark');
    });

    test('removeStringSetting deletes the key', () async {
      final ds = await makeDataSource();
      await ds.setStringSetting('k', 'v');
      await ds.removeStringSetting('k');
      expect(ds.getStringSetting('k'), isNull);
    });

    test('int settings round-trip, absent key is null', () async {
      final ds = await makeDataSource();
      expect(ds.getIntSetting('transpose'), isNull);
      await ds.setIntSetting('transpose', -3);
      expect(ds.getIntSetting('transpose'), -3);
    });

    test('bool settings round-trip, absent key is null', () async {
      final ds = await makeDataSource();
      expect(ds.getBoolSetting('chords'), isNull);
      await ds.setBoolSetting('chords', false);
      expect(ds.getBoolSetting('chords'), isFalse);
    });
  });
}
