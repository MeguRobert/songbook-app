import '../../core/extensions/string_extensions.dart';
import '../../data/models/song.dart';

/// Service for searching songs
class SearchService {
  const SearchService();

  /// Searches songs by query string
  ///
  /// Search priority:
  /// 1. Exact song number match
  /// 2. Title match
  /// 3. Reference match
  /// 4. Tag match
  List<Song> search(List<Song> songs, String query) {
    if (query.isEmpty) return songs;

    final normalizedQuery = query.normalizeForSearch();

    // Try to parse as song number first
    final number = int.tryParse(query.trim());
    if (number != null) {
      final exactMatch = songs.where((s) => s.number == number).toList();
      if (exactMatch.isNotEmpty) return exactMatch;
    }

    // Score each song based on match quality
    final scored = songs.map((song) {
      int score = _calculateMatchScore(song, normalizedQuery);
      return (song: song, score: score);
    }).where((item) => item.score > 0).toList();

    // Sort by score (highest first), then by number
    scored.sort((a, b) {
      int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.song.number.compareTo(b.song.number);
    });

    return scored.map((item) => item.song).toList();
  }

  /// Filters songs by tag
  List<Song> filterByTag(List<Song> songs, String tag) {
    return songs.where((song) =>
      song.tags.any((t) => t.toLowerCase() == tag.toLowerCase())
    ).toList();
  }

  /// Gets all unique tags from songs
  Set<String> getAllTags(List<Song> songs) {
    return songs
        .expand((song) => song.tags)
        .map((tag) => tag.toLowerCase())
        .toSet();
  }

  /// Calculates a match score for a song against a query
  int _calculateMatchScore(Song song, String normalizedQuery) {
    int score = 0;

    // Title starts with query (highest priority)
    if (song.title.normalizeForSearch().startsWith(normalizedQuery)) {
      score += 100;
    }
    // Title contains query
    else if (song.title.containsNormalized(normalizedQuery)) {
      score += 50;
    }

    // Number contains query string
    if (song.number.toString().contains(normalizedQuery)) {
      score += 80;
    }

    // Reference match
    if (song.reference != null &&
        song.reference!.containsNormalized(normalizedQuery)) {
      score += 30;
    }

    // Tag match
    if (song.tags.any((tag) => tag.containsNormalized(normalizedQuery))) {
      score += 20;
    }

    // Tune name match
    if (song.tune?.name != null &&
        song.tune!.name!.containsNormalized(normalizedQuery)) {
      score += 10;
    }

    return score;
  }
}
