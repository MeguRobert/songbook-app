import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/song.dart';
import '../../models/song_id.dart';
import '../../models/favorite.dart';
import '../../models/setlist.dart';
import '../../models/recent_song.dart';

/// Local data source for songs and favorites
class LocalDataSource {
  static const _favoritesKey = 'favorites';
  static const _setlistsKey = 'setlists';
  static const _tagOverridesKey = 'song_tag_overrides';
  static const _recentsKey = 'recent_songs';
  static const _userSongsKey = 'user_songs';
  static const _settingsPrefix = 'settings_';

  /// Maximum number of recently-viewed songs retained.
  static const recentsLimit = 20;

  final SharedPreferences _prefs;
  List<Song>? _cachedSongs;

  LocalDataSource(this._prefs);

  /// Loads songs from the bundled JSON asset
  Future<List<Song>> loadSongs() async {
    if (_cachedSongs != null) return _cachedSongs!;

    try {
      final jsonString = await rootBundle.loadString('assets/data/songs.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedSongs = jsonList.map((json) => Song.fromJson(json)).toList();
      _cachedSongs!.sort((a, b) => a.number.compareTo(b.number));
      return _cachedSongs!;
    } catch (e) {
      // Return empty list if file doesn't exist or is invalid
      _cachedSongs = [];
      return _cachedSongs!;
    }
  }

  /// Gets a song by number
  Future<Song?> getSongByNumber(int number) async {
    final songs = await loadSongs();
    try {
      return songs.firstWhere((s) => s.number == number);
    } catch (_) {
      return null;
    }
  }

  /// Clears the song cache (useful for testing or refresh)
  void clearSongCache() {
    _cachedSongs = null;
  }

  /// Decodes the JSON list stored at [key] into records, **skipping** any
  /// entry [fromJson] cannot read.
  ///
  /// Audit finding S14: the previous shape wrapped the whole `map` in one
  /// `try`, so a single malformed record made the entire collection read as
  /// empty — the user saw "no favourites" and the next write erased every
  /// intact record with it. Only a blob that will not decode as a JSON list at
  /// all is a total loss; everything else degrades one record at a time.
  List<T> _decodeRecords<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return [];

    final List<dynamic> jsonList;
    try {
      jsonList = json.decode(jsonString) as List<dynamic>;
    } catch (_) {
      return [];
    }

    final records = <T>[];
    for (final entry in jsonList) {
      try {
        records.add(fromJson(entry as Map<String, dynamic>));
      } catch (_) {
        continue; // drop just this record
      }
    }
    return records;
  }

  // --- Favorites ---

  /// Gets all favorites (unreadable records are skipped, see [_decodeRecords])
  List<Favorite> getFavorites() =>
      _decodeRecords(_favoritesKey, Favorite.fromJson);

  /// Saves favorites
  Future<bool> saveFavorites(List<Favorite> favorites) async {
    final jsonString = json.encode(favorites.map((f) => f.toJson()).toList());
    return _prefs.setString(_favoritesKey, jsonString);
  }

  /// Adds a song to favorites
  Future<bool> addFavorite(SongId songId) async {
    final favorites = getFavorites();
    if (favorites.any((f) => f.songId == songId)) {
      return true; // Already a favorite
    }

    final maxSortOrder = favorites.isEmpty
        ? 0
        : favorites.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b);

    favorites.add(Favorite(
      songId: songId,
      addedAt: DateTime.now(),
      sortOrder: maxSortOrder + 1,
    ));

    return saveFavorites(favorites);
  }

  /// Removes a song from favorites
  Future<bool> removeFavorite(SongId songId) async {
    final favorites = getFavorites();
    favorites.removeWhere((f) => f.songId == songId);
    return saveFavorites(favorites);
  }

  /// Checks if a song is a favorite
  bool isFavorite(SongId songId) {
    return getFavorites().any((f) => f.songId == songId);
  }

  // --- Setlists ---

  /// Gets all setlists (unreadable records are skipped, see [_decodeRecords])
  List<Setlist> getSetlists() =>
      _decodeRecords(_setlistsKey, Setlist.fromJson);

  /// Saves all setlists
  Future<bool> saveSetlists(List<Setlist> setlists) async {
    final jsonString = json.encode(setlists.map((s) => s.toJson()).toList());
    return _prefs.setString(_setlistsKey, jsonString);
  }

  // --- Tag Overrides ---

  /// Gets per-song tag overrides keyed by song.
  ///
  /// An override REPLACES the bundled tags for that song (uniformly handles
  /// add and remove). Returns an empty map if none stored or on decode error.
  ///
  /// Keys were bare song numbers before song ids existed. [SongId.tryParse]
  /// reads those as hymnal ids, so overrides stored by an older build survive
  /// the upgrade untouched; unparseable keys are dropped rather than failing
  /// the whole read, matching how [_decodeRecords] treats a bad record.
  Map<SongId, List<String>> getTagOverrides() {
    final jsonString = _prefs.getString(_tagOverridesKey);
    if (jsonString == null) return {};

    try {
      final Map<String, dynamic> decoded = json.decode(jsonString);
      final result = <SongId, List<String>>{};
      decoded.forEach((key, value) {
        final songId = SongId.tryParse(key);
        if (songId == null || value is! List) return;
        result[songId] = value.map((e) => e.toString()).toList();
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Saves all per-song tag overrides as a single JSON blob.
  Future<bool> saveTagOverrides(Map<SongId, List<String>> overrides) async {
    final encodable =
        overrides.map((key, value) => MapEntry(key.value, value));
    return _prefs.setString(_tagOverridesKey, json.encode(encodable));
  }

  /// Sets the tag override for a single song.
  Future<bool> setSongTags(SongId songId, List<String> tags) async {
    final overrides = getTagOverrides();
    overrides[songId] = tags;
    return saveTagOverrides(overrides);
  }

  /// Clears the tag override for a single song (reverting to bundled tags).
  Future<bool> clearSongTags(SongId songId) async {
    final overrides = getTagOverrides();
    overrides.remove(songId);
    return saveTagOverrides(overrides);
  }
  // --- Recently viewed ---

  /// Gets recently-viewed songs, most-recent first (unreadable records are
  /// skipped, see [_decodeRecords]).
  List<RecentSong> getRecentSongs() =>
      _decodeRecords(_recentsKey, RecentSong.fromJson);

  /// Records [songId] as the most recently viewed.
  ///
  /// De-duplicates (an existing entry is moved to the front with a refreshed
  /// timestamp) and caps the list at [recentsLimit]. [now] is injectable for
  /// deterministic tests.
  Future<bool> recordRecentSong(SongId songId, {DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    final recents = getRecentSongs()
      ..removeWhere((r) => r.songId == songId);
    recents.insert(0, RecentSong(songId: songId, viewedAt: timestamp));
    final capped = recents.take(recentsLimit).toList();
    final jsonString = json.encode(capped.map((r) => r.toJson()).toList());
    return _prefs.setString(_recentsKey, jsonString);
  }

  /// Clears the recently-viewed list.
  Future<bool> clearRecentSongs() => _prefs.remove(_recentsKey);

  // --- User songs ---

  /// Songs the user imported or wrote, in insertion order.
  ///
  /// These live alongside the bundled catalogue rather than inside it:
  /// `songs.json` is a read-only asset, so anything the user adds has to be
  /// stored separately and merged at read time. Unreadable records are skipped
  /// one at a time, never taking the whole collection with them
  /// (see [_decodeRecords]).
  List<Song> getUserSongs() => _decodeRecords(_userSongsKey, Song.fromJson);

  /// Replaces the whole user-song collection.
  Future<bool> saveUserSongs(List<Song> songs) {
    final jsonString = json.encode(songs.map((s) => s.toJson()).toList());
    return _prefs.setString(_userSongsKey, jsonString);
  }

  /// Inserts [song], or replaces the existing one with the same [Song.id].
  ///
  /// Keyed by id, not by number: two user songs may legitimately share a
  /// number when they sit in different songbooks.
  Future<bool> upsertUserSong(Song song) {
    final songs = getUserSongs();
    final index = songs.indexWhere((s) => s.id == song.id);
    if (index == -1) {
      songs.add(song);
    } else {
      songs[index] = song;
    }
    return saveUserSongs(songs);
  }

  /// Removes the user song with [songId]. Returns false if it was not there.
  Future<bool> deleteUserSong(SongId songId) async {
    final songs = getUserSongs();
    final before = songs.length;
    songs.removeWhere((s) => s.id == songId);
    if (songs.length == before) return false;
    return saveUserSongs(songs);
  }

  // --- Settings ---

  /// Gets a string setting
  String? getStringSetting(String key) {
    return _prefs.getString('$_settingsPrefix$key');
  }

  /// Sets a string setting
  Future<bool> setStringSetting(String key, String value) {
    return _prefs.setString('$_settingsPrefix$key', value);
  }

  /// Removes a string setting
  Future<bool> removeStringSetting(String key) {
    return _prefs.remove('$_settingsPrefix$key');
  }

  /// Gets an int setting
  int? getIntSetting(String key) {
    return _prefs.getInt('$_settingsPrefix$key');
  }

  /// Sets an int setting
  Future<bool> setIntSetting(String key, int value) {
    return _prefs.setInt('$_settingsPrefix$key', value);
  }

  /// Gets a bool setting
  bool? getBoolSetting(String key) {
    return _prefs.getBool('$_settingsPrefix$key');
  }

  /// Sets a bool setting
  Future<bool> setBoolSetting(String key, bool value) {
    return _prefs.setBool('$_settingsPrefix$key', value);
  }
}
