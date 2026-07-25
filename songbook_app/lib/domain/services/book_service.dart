import '../../data/models/book.dart';
import '../../data/models/song.dart';

/// Service for grouping songs into books and filtering by book.
///
/// Pure, stateless logic (no side effects, no Flutter/provider dependencies),
/// mirroring [SearchService]. Books are derived from [Song.book]; songs without
/// a book are collected under the [ungroupedLabel] bucket.
class BookService {
  const BookService();

  /// Label for songs that have not been assigned to a book.
  static const String ungroupedLabel = 'Other';

  /// Derives the list of books present in [songs], with song counts.
  ///
  /// Ordering: by the lowest song number within each book ascending (natural
  /// hymnal order — e.g. "Zsoltárok" [1..150] before "Dicséretek" [151+]). The
  /// [ungroupedLabel] bucket always sorts last.
  List<Book> booksFromSongs(List<Song> songs) {
    final counts = <String, int>{};
    final minNumber = <String, int>{};

    for (final song in songs) {
      final name = song.hasBook ? song.book! : ungroupedLabel;
      counts[name] = (counts[name] ?? 0) + 1;
      final current = minNumber[name];
      if (current == null || song.number < current) {
        minNumber[name] = song.number;
      }
    }

    final books = counts.entries
        .map((e) => Book(name: e.key, songCount: e.value))
        .toList();

    books.sort((a, b) {
      // Ungrouped bucket always last.
      if (a.name == ungroupedLabel && b.name != ungroupedLabel) return 1;
      if (b.name == ungroupedLabel && a.name != ungroupedLabel) return -1;
      final aMin = minNumber[a.name] ?? 1 << 30;
      final bMin = minNumber[b.name] ?? 1 << 30;
      final byNumber = aMin.compareTo(bMin);
      if (byNumber != 0) return byNumber;
      return a.name.compareTo(b.name);
    });

    return books;
  }

  /// Filters [songs] by [bookName].
  ///
  /// - `null` → all songs (the "All Songs" view).
  /// - [ungroupedLabel] → only songs without a book.
  /// - any other name → only songs whose [Song.book] equals that name.
  List<Song> filterByBook(List<Song> songs, String? bookName) {
    if (bookName == null) return songs;
    if (bookName == ungroupedLabel) {
      return songs.where((s) => !s.hasBook).toList();
    }
    return songs.where((s) => s.book == bookName).toList();
  }

  /// Convenience: the ordered list of book names present in [songs].
  List<String> bookNames(List<Song> songs) =>
      booksFromSongs(songs).map((b) => b.name).toList();
}
