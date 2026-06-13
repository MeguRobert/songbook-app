import '../../core/extensions/string_extensions.dart';
import '../../data/models/song.dart';
import '../../data/models/tag.dart';

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

  /// Derives the list of tags present in [songs], with song counts.
  ///
  /// Grouping is case-insensitive (trimmed + lower-cased key), but the
  /// first-seen original casing is preserved for display (so "Luther" shows as
  /// "Luther", not "luther"). Ordered by [Tag.songCount] descending, then by
  /// name ascending. Empty input or tag-less songs → empty list.
  List<Tag> tagsWithCounts(List<Song> songs) {
    final counts = <String, int>{};
    final display = <String, String>{};

    for (final song in songs) {
      for (final raw in song.tags) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;
        final key = trimmed.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
        display.putIfAbsent(key, () => trimmed);
      }
    }

    final tags = counts.entries
        .map((e) => Tag(name: display[e.key]!, songCount: e.value))
        .toList();

    tags.sort((a, b) {
      final byCount = b.songCount.compareTo(a.songCount);
      if (byCount != 0) return byCount;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return tags;
  }

  /// Filters [songs] by one or more [tags] (case-insensitive).
  ///
  /// Empty [tags] → returns [songs] unchanged. When [matchAll] is true a song
  /// must carry ALL selected tags (AND); when false it must carry ANY (OR).
  List<Song> filterByTags(
    List<Song> songs,
    Set<String> tags, {
    bool matchAll = true,
  }) {
    if (tags.isEmpty) return songs;

    final wanted = tags.map((t) => t.toLowerCase()).toSet();

    return songs.where((song) {
      final songTags = song.tags.map((t) => t.toLowerCase()).toSet();
      if (matchAll) {
        return wanted.every(songTags.contains);
      }
      return wanted.any(songTags.contains);
    }).toList();
  }

  /// Applies per-song tag [overrides] to [songs] (pure merge).
  ///
  /// For each song with an entry in [overrides], returns a copy whose tags are
  /// replaced by the override; songs without an entry are returned unchanged.
  /// An empty [overrides] map returns the SAME list reference (fast path).
  List<Song> applyTagOverrides(
    List<Song> songs,
    Map<int, List<String>> overrides,
  ) {
    if (overrides.isEmpty) return songs;

    return songs.map((song) {
      final override = overrides[song.number];
      if (override == null) return song;
      return song.copyWith(tags: override);
    }).toList();
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
