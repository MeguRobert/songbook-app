import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/book.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/domain/services/book_service.dart';

/// Builds a minimal Song fixture for book grouping/filtering tests.
Song song(int number, {String? book}) => Song(
      number: number,
      title: 'Song $number',
      originalKey: 'C',
      verses: const [],
      book: book,
    );

void main() {
  const service = BookService();

  group('BookService.booksFromSongs', () {
    test('returns empty list for empty input', () {
      expect(service.booksFromSongs([]), isEmpty);
    });

    test('groups songs by book with correct counts', () {
      final songs = [
        song(1, book: 'Zsoltárok'),
        song(42, book: 'Zsoltárok'),
        song(151, book: 'Dicséretek'),
      ];

      final books = service.booksFromSongs(songs);

      expect(books, hasLength(2));
      expect(
        books.firstWhere((b) => b.name == 'Zsoltárok').songCount,
        equals(2),
      );
      expect(
        books.firstWhere((b) => b.name == 'Dicséretek').songCount,
        equals(1),
      );
    });

    test('orders books by lowest song number ascending', () {
      // Dicséretek (151+) appears first in the list but should sort after
      // Zsoltárok (1..150) because of the lower minimum song number.
      final songs = [
        song(200, book: 'Dicséretek'),
        song(1, book: 'Zsoltárok'),
        song(151, book: 'Dicséretek'),
        song(90, book: 'Zsoltárok'),
      ];

      final names = service.booksFromSongs(songs).map((b) => b.name).toList();

      expect(names, equals(['Zsoltárok', 'Dicséretek']));
    });

    test('ungrouped bucket sorts last even with low song numbers', () {
      final songs = [
        song(1), // no book -> Other, lowest number
        song(50, book: 'Zsoltárok'),
        song(300, book: 'Dicséretek'),
      ];

      final names = service.booksFromSongs(songs).map((b) => b.name).toList();

      expect(names.last, equals(BookService.ungroupedLabel));
      expect(names, equals(['Zsoltárok', 'Dicséretek', 'Other']));
    });

    test('null book and empty-string book both fall into the Other bucket', () {
      final songs = [
        song(1, book: null),
        song(2, book: ''),
        song(3, book: 'Zsoltárok'),
      ];

      final books = service.booksFromSongs(songs);
      final other = books.firstWhere((b) => b.name == BookService.ungroupedLabel);

      expect(other.songCount, equals(2));
    });

    test('single-book corpus yields one book', () {
      final songs = [
        song(1, book: 'Zsoltárok'),
        song(2, book: 'Zsoltárok'),
      ];

      expect(
        service.booksFromSongs(songs),
        equals(const [Book(name: 'Zsoltárok', songCount: 2)]),
      );
    });
  });

  group('BookService.filterByBook', () {
    final songs = [
      song(1, book: 'Zsoltárok'),
      song(42, book: 'Zsoltárok'),
      song(151, book: 'Dicséretek'),
      song(999), // no book -> Other
    ];

    test('null returns all songs unchanged', () {
      expect(service.filterByBook(songs, null), equals(songs));
    });

    test('specific book returns only that book\'s songs', () {
      final result = service.filterByBook(songs, 'Zsoltárok');
      expect(result.map((s) => s.number), equals([1, 42]));
    });

    test('ungrouped label returns only songs without a book', () {
      final result = service.filterByBook(songs, BookService.ungroupedLabel);
      expect(result.map((s) => s.number), equals([999]));
    });

    test('unknown book returns empty list', () {
      expect(service.filterByBook(songs, 'Nonexistent'), isEmpty);
    });
  });

  group('BookService.bookNames', () {
    test('returns ordered book names', () {
      final songs = [
        song(151, book: 'Dicséretek'),
        song(1, book: 'Zsoltárok'),
      ];
      expect(service.bookNames(songs), equals(['Zsoltárok', 'Dicséretek']));
    });
  });
}
