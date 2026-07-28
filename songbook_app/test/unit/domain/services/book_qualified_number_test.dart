import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/domain/services/book_service.dart';

/// A user's own songbook starts at 1 exactly as a hymnal does, so a bare
/// number stops identifying a song the moment more than one book is in play.
/// Qualifying the display by book is what keeps them apart — without inventing
/// fake numbers for songs that were never numbered by a publisher.
Song songIn(String? book, int number) =>
    Song(number: number, title: 't', originalKey: 'C', verses: const [], book: book);

void main() {
  const service = BookService();

  group('abbreviate', () {
    test('uses the hand-picked short form for the bundled books', () {
      expect(service.abbreviate('Zsoltárok'), 'Zsolt');
      expect(service.abbreviate('Dicséretek'), 'Dics');
    });

    test('is case- and whitespace-insensitive', () {
      expect(service.abbreviate('  dicséretek '), 'Dics');
    });

    test('derives initials for a multi-word book', () {
      expect(service.abbreviate('Ifjúsági Énekek'), 'IÉ');
      expect(service.abbreviate('Saját Énekes Könyv'), 'SÉK');
    });

    test('derives a prefix for an unknown single-word book', () {
      expect(service.abbreviate('Halleluja'), 'Hall');
      // Shorter than the cut-off is returned whole, not padded or truncated.
      expect(service.abbreviate('Új'), 'Új');
    });

    test('handles an empty name without throwing', () {
      expect(service.abbreviate(''), '');
      expect(service.abbreviate('   '), '');
    });
  });

  group('qualifiedNumber', () {
    test('joins abbreviation and number with the separator', () {
      expect(service.qualifiedNumber(songIn('Dicséretek', 151)), 'Dics-151');
      expect(service.qualifiedNumber(songIn('Zsoltárok', 1)), 'Zsolt-1');
    });

    test('keeps a bare number when the song has no book', () {
      // Nothing to qualify by; a bare number is the honest answer.
      expect(service.qualifiedNumber(songIn(null, 42)), '42');
      expect(service.qualifiedNumber(songIn('', 42)), '42');
    });

    test('two books can both hold number 1 and stay distinguishable', () {
      // The whole point. Previously both rendered as "1".
      final hymnal = service.qualifiedNumber(songIn('Zsoltárok', 1));
      final mine = service.qualifiedNumber(songIn('Saját énekek', 1));
      expect(hymnal, isNot(mine));
      expect(hymnal, 'Zsolt-1');
      // Two words, so initials rather than a prefix — and the lower-case
      // second word is still upper-cased.
      expect(mine, 'SÉ-1');
    });
  });
}
