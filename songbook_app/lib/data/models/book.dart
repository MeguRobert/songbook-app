/// A book/hymnal grouping of songs.
///
/// This is a derived value object: books are computed from the songs that
/// reference them (via [Song.book]) rather than stored as a separate registry.
/// It carries just enough for the book browser UI — the display [name] and the
/// number of songs in the book.
class Book {
  /// Display name of the book (e.g., "Zsoltárok", "Dicséretek").
  final String name;

  /// Number of songs assigned to this book.
  final int songCount;

  const Book({
    required this.name,
    required this.songCount,
  });

  Book copyWith({
    String? name,
    int? songCount,
  }) {
    return Book(
      name: name ?? this.name,
      songCount: songCount ?? this.songCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          songCount == other.songCount;

  @override
  int get hashCode => name.hashCode ^ songCount.hashCode;

  @override
  String toString() => 'Book(name: $name, songCount: $songCount)';
}
