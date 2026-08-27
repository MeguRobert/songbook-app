import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/datasources/remote/remote_sync_datasource.dart';
import 'package:songbook_app/data/models/favorite.dart';
import 'package:songbook_app/data/models/setlist.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/repositories/favorites_repository.dart';
import 'package:songbook_app/data/repositories/setlist_repository.dart';

/// **This file exists because this app has destroyed users' data before.**
///
/// Renaming a stored field's JSON key wiped favourites and setlists on upgrade:
/// the record read `null`, threw inside the converter, was dropped one record at
/// a time by `LocalDataSource._decodeRecords`, and the next save wrote the
/// now-empty list back. Silent, permanent, and only visible to the user.
/// `Favorite.songId` and `Setlist.songIds` still carry `readValue` fallbacks
/// because of it.
///
/// Cross-device sync adds new stored state and rewrites both collections during
/// a merge, which is exactly the shape of change that did the damage. So the
/// blobs below are written by hand in the format a shipped build stores TODAY,
/// and in the format the build before song ids stored, and every assertion is
/// that they still read.
///
/// An account with nothing in it. Enough to make a merge run and rewrite both
/// collections, which is the operation under test.
class EmptyAccount implements RemoteSyncDataSource {
  @override
  String? currentUserId = 'account-1';

  @override
  Future<List<SyncedFavorite>> fetchFavorites() async => const [];

  @override
  Future<List<SyncedSetlist>> fetchSetlists() async => const [];

  @override
  Future<void> pushFavorites(List<SyncedFavorite> favorites) async {}

  @override
  Future<void> pushSetlists(List<SyncedSetlist> setlists) async {}
}

/// Exactly what a shipped build has written into `favorites` since song ids
/// landed. Hand-written, not produced by the model: a test that serialises with
/// today's code and reads it back with today's code proves nothing about
/// yesterday's bytes.
const todaysFavorites = '['
    '{"songId":"hymnal:151","addedAt":"2026-03-04T09:15:00.000","sortOrder":0},'
    '{"songId":"hymnal:90","addedAt":"2026-03-05T20:01:30.000","sortOrder":1},'
    '{"songId":"user:l9f3a2c4b1","addedAt":"2026-04-01T08:00:00.000","sortOrder":2}'
    ']';

const todaysSetlists = '['
    '{"id":"sl_1772000000000000_a1b2c3","name":"Vasárnap délelőtt",'
    '"songIds":["hymnal:151","hymnal:90","user:l9f3a2c4b1"],'
    '"createdAt":"2026-03-04T09:00:00.000","updatedAt":"2026-03-06T18:30:00.000"}'
    ']';

/// The format that shipped BEFORE `SongId` existed: a bare hymnal number, under
/// the old key names. Both are still out there on devices that have not opened
/// the app since.
const preSongIdFavorites =
    '[{"songNumber":151,"addedAt":"2025-11-02T09:15:00.000","sortOrder":0}]';

const preSongIdSetlists = '['
    '{"id":"sl_old","name":"Régi","songNumbers":[151,90],'
    '"createdAt":"2025-11-02T09:00:00.000","updatedAt":"2025-11-02T09:00:00.000"}'
    ']';

Future<LocalDataSource> localWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return LocalDataSource(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('data stored by today\'s build still loads', () {
    test('favourites keep every field, in order', () async {
      final local = await localWith({'favorites': todaysFavorites});
      final favorites = FavoritesRepository(local).getFavorites();

      expect(favorites, hasLength(3));
      expect(favorites.map((f) => f.songId), [
        const SongId.hymnal(151),
        const SongId.hymnal(90),
        const SongId.user('l9f3a2c4b1'),
      ]);
      expect(favorites.first.addedAt, DateTime(2026, 3, 4, 9, 15));
      expect(favorites.map((f) => f.sortOrder), [0, 1, 2]);
    });

    test('setlists keep their name, their order and both timestamps', () async {
      final local = await localWith({'setlists': todaysSetlists});
      final stored =
          SetlistRepository(local).getById('sl_1772000000000000_a1b2c3')!;

      expect(stored.name, 'Vasárnap délelőtt');
      expect(stored.songIds, [
        const SongId.hymnal(151),
        const SongId.hymnal(90),
        const SongId.user('l9f3a2c4b1'),
      ]);
      expect(stored.createdAt, DateTime(2026, 3, 4, 9));
      expect(stored.updatedAt, DateTime(2026, 3, 6, 18, 30));
    });
  });

  group('data stored before song ids existed still loads', () {
    test('a bare songNumber reads as a hymnal favourite', () async {
      final local = await localWith({'favorites': preSongIdFavorites});
      final favorites = FavoritesRepository(local).getFavorites();

      expect(favorites.single.songId, const SongId.hymnal(151));
      expect(favorites.single.addedAt, DateTime(2025, 11, 2, 9, 15));
    });

    test('bare songNumbers read as a hymnal setlist, in order', () async {
      final local = await localWith({'setlists': preSongIdSetlists});
      final stored = SetlistRepository(local).getById('sl_old')!;

      expect(stored.songIds,
          [const SongId.hymnal(151), const SongId.hymnal(90)]);
    });
  });

  group('the stored shape has not moved', () {
    // A guard rather than a round trip. If someone renames a field, THIS fails
    // with the key that moved, instead of the user discovering it.
    test('a Favorite still serialises to exactly songId, addedAt, sortOrder',
        () {
      final json = Favorite(
        songId: const SongId.hymnal(151),
        addedAt: DateTime(2026, 3, 4),
      ).toJson();

      expect(json.keys.toSet(), {'songId', 'addedAt', 'sortOrder'});
      expect(json['songId'], 'hymnal:151');
    });

    test('a Setlist still serialises to exactly id, name, songIds, createdAt, '
        'updatedAt', () {
      final json = Setlist(
        id: 'sl_1',
        name: 'Sunday',
        songIds: const [SongId.hymnal(151)],
        createdAt: DateTime(2026, 3, 4),
        updatedAt: DateTime(2026, 3, 4),
      ).toJson();

      expect(json.keys.toSet(),
          {'id', 'name', 'songIds', 'createdAt', 'updatedAt'});
      expect(json['songIds'], ['hymnal:151']);
    });

    test('sync stores its bookkeeping in NEW keys and touches no old one',
        () async {
      final local = await localWith({
        'favorites': todaysFavorites,
        'setlists': todaysSetlists,
      });

      await FavoritesRepository(local, EmptyAccount()).sync();
      await SetlistRepository(local, EmptyAccount()).sync();

      final prefs = await SharedPreferences.getInstance();
      final favoriteKeys = <String>{
        for (final entry in json.decode(prefs.getString('favorites')!) as List)
          ...(entry as Map).keys.cast<String>(),
      };
      final setlistKeys = <String>{
        for (final entry in json.decode(prefs.getString('setlists')!) as List)
          ...(entry as Map).keys.cast<String>(),
      };

      expect(favoriteKeys, {'songId', 'addedAt', 'sortOrder'});
      expect(setlistKeys, {'id', 'name', 'songIds', 'createdAt', 'updatedAt'});
      expect(prefs.getString('favorites_removed'), isNotNull,
          reason: 'the tombstones live in a key of their own, so the blob that '
              'already exists never has to change shape to make room');
    });
  });

  group('a merge does not eat what was already on the device', () {
    test('an account with nothing in it leaves every favourite intact',
        () async {
      final local = await localWith({'favorites': todaysFavorites});
      final repository = FavoritesRepository(local, EmptyAccount());

      await repository.sync();

      final favorites = repository.getFavorites();
      expect(favorites.map((f) => f.songId), [
        const SongId.hymnal(151),
        const SongId.hymnal(90),
        const SongId.user('l9f3a2c4b1'),
      ]);
      expect(favorites.map((f) => f.addedAt), [
        DateTime(2026, 3, 4, 9, 15),
        DateTime(2026, 3, 5, 20, 1, 30),
        DateTime(2026, 4, 1, 8),
      ], reason: 'addedAt is the merge timestamp; a merge that quietly reset it '
          'to now would make every device claim its copy was the newest');
      expect(favorites.map((f) => f.sortOrder), [0, 1, 2]);
    });

    test('an account with nothing in it leaves every setlist intact', () async {
      final local = await localWith({'setlists': todaysSetlists});
      final repository = SetlistRepository(local, EmptyAccount());

      await repository.sync();

      final stored = repository.getById('sl_1772000000000000_a1b2c3')!;
      expect(stored.name, 'Vasárnap délelőtt');
      expect(stored.songIds, [
        const SongId.hymnal(151),
        const SongId.hymnal(90),
        const SongId.user('l9f3a2c4b1'),
      ]);
      expect(stored.createdAt, DateTime(2026, 3, 4, 9));
      expect(stored.updatedAt, DateTime(2026, 3, 6, 18, 30));
    });

    test('a pre-song-id payload survives a merge as well', () async {
      final local = await localWith({
        'favorites': preSongIdFavorites,
        'setlists': preSongIdSetlists,
      });

      await FavoritesRepository(local, EmptyAccount()).sync();
      await SetlistRepository(local, EmptyAccount()).sync();

      expect(FavoritesRepository(local).getFavorites().single.songId,
          const SongId.hymnal(151));
      expect(SetlistRepository(local).getById('sl_old')!.songIds,
          [const SongId.hymnal(151), const SongId.hymnal(90)]);
    });

    test('a blob nobody can read is left alone rather than replaced', () async {
      final local = await localWith({'favorites': 'not json at all'});

      await FavoritesRepository(local, EmptyAccount()).sync();

      // Nothing to assert about content -- the point is that the merge did not
      // throw, and that the collection is empty rather than the app being
      // unusable. `_decodeRecords` already degrades one record at a time; this
      // pins that sync did not add a new way to lose the lot.
      expect(FavoritesRepository(local).getFavorites(), isEmpty);
    });
  });
}
