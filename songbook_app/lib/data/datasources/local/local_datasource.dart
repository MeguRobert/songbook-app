import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/song.dart';
import '../../models/favorite.dart';
import '../../models/setlist.dart';

/// Local data source for songs and favorites
class LocalDataSource {
  static const _favoritesKey = 'favorites';
  static const _setlistsKey = 'setlists';
  static const _tagOverridesKey = 'song_tag_overrides';
  static const _settingsPrefix = 'settings_';

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

  // --- Favorites ---

  /// Gets all favorites
  List<Favorite> getFavorites() {
    final jsonString = _prefs.getString(_favoritesKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Favorite.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves favorites
  Future<bool> saveFavorites(List<Favorite> favorites) async {
    final jsonString = json.encode(favorites.map((f) => f.toJson()).toList());
    return _prefs.setString(_favoritesKey, jsonString);
  }

  /// Adds a song to favorites
  Future<bool> addFavorite(int songNumber) async {
    final favorites = getFavorites();
    if (favorites.any((f) => f.songNumber == songNumber)) {
      return true; // Already a favorite
    }

    final maxSortOrder = favorites.isEmpty
        ? 0
        : favorites.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b);

    favorites.add(Favorite(
      songNumber: songNumber,
      addedAt: DateTime.now(),
      sortOrder: maxSortOrder + 1,
    ));

    return saveFavorites(favorites);
  }

  /// Removes a song from favorites
  Future<bool> removeFavorite(int songNumber) async {
    final favorites = getFavorites();
    favorites.removeWhere((f) => f.songNumber == songNumber);
    return saveFavorites(favorites);
  }

  /// Checks if a song is a favorite
  bool isFavorite(int songNumber) {
    return getFavorites().any((f) => f.songNumber == songNumber);
  }

  // --- Setlists ---

  /// Gets all setlists (empty list if none stored or on decode error)
  List<Setlist> getSetlists() {
    final jsonString = _prefs.getString(_setlistsKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Setlist.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves all setlists
  Future<bool> saveSetlists(List<Setlist> setlists) async {
    final jsonString = json.encode(setlists.map((s) => s.toJson()).toList());
    return _prefs.setString(_setlistsKey, jsonString);
  }

  // --- Tag Overrides ---

  /// Gets per-song tag overrides keyed by song number.
  ///
  /// An override REPLACES the bundled tags for that song (uniformly handles
  /// add and remove). Returns an empty map if none stored or on decode error.
  Map<int, List<String>> getTagOverrides() {
    final jsonString = _prefs.getString(_tagOverridesKey);
    if (jsonString == null) return {};

    try {
      final Map<String, dynamic> decoded = json.decode(jsonString);
      final result = <int, List<String>>{};
      decoded.forEach((key, value) {
        final number = int.tryParse(key);
        if (number == null || value is! List) return;
        result[number] = value.map((e) => e.toString()).toList();
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Saves all per-song tag overrides as a single JSON blob.
  Future<bool> saveTagOverrides(Map<int, List<String>> overrides) async {
    final encodable =
        overrides.map((key, value) => MapEntry(key.toString(), value));
    return _prefs.setString(_tagOverridesKey, json.encode(encodable));
  }

  /// Sets the tag override for a single song.
  Future<bool> setSongTags(int songNumber, List<String> tags) async {
    final overrides = getTagOverrides();
    overrides[songNumber] = tags;
    return saveTagOverrides(overrides);
  }

  /// Clears the tag override for a single song (reverting to bundled tags).
  Future<bool> clearSongTags(int songNumber) async {
    final overrides = getTagOverrides();
    overrides.remove(songNumber);
    return saveTagOverrides(overrides);
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
