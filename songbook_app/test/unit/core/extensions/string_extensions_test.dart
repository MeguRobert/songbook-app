import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/core/extensions/string_extensions.dart';

void main() {
  group('capitalize', () {
    test('capitalizes the first letter', () {
      expect('hello'.capitalize(), 'Hello');
      expect('hello world'.capitalize(), 'Hello world');
    });

    test('leaves an already-capitalized string unchanged', () {
      expect('Hello'.capitalize(), 'Hello');
    });

    test('handles empty string', () {
      expect(''.capitalize(), '');
    });

    test('handles single character', () {
      expect('a'.capitalize(), 'A');
      expect('A'.capitalize(), 'A');
    });

    test('leaves non-letter first characters unchanged', () {
      expect('1abc'.capitalize(), '1abc');
      expect(' abc'.capitalize(), ' abc');
    });

    test('only touches the first character', () {
      expect('hELLO'.capitalize(), 'HELLO');
    });
  });

  group('removeDiacritics', () {
    test('maps all lowercase Hungarian vowels', () {
      expect('áéíóöőúüű'.removeDiacritics(), 'aeiooouuu');
    });

    test('maps all uppercase Hungarian vowels', () {
      expect('ÁÉÍÓÖŐÚÜŰ'.removeDiacritics(), 'AEIOOOUUU');
    });

    test('leaves plain ASCII untouched', () {
      expect('Hello World 123!'.removeDiacritics(), 'Hello World 123!');
    });

    test('handles mixed content', () {
      expect('Áldjad én lelkem'.removeDiacritics(), 'Aldjad en lelkem');
    });

    test('handles empty string', () {
      expect(''.removeDiacritics(), '');
    });

    test('leaves unmapped non-Hungarian diacritics unchanged', () {
      expect('café'.removeDiacritics(), 'cafe'); // é is mapped
      expect('çñ'.removeDiacritics(), 'çñ'); // not in the map
    });

    // The three below guard a rewrite: this used to be split('')/map/join, which
    // allocated a one-character string per character of every string it saw, on
    // every keystroke of a search. It is now a single pass over code units, and
    // that is exactly the change that can break characters wider than one unit.
    test('characters outside the BMP survive intact', () {
      // An emoji is a surrogate PAIR — two code units — so a per-code-unit pass
      // that reassembles carelessly would corrupt it or drop half.
      expect('a🎵b'.removeDiacritics(), 'a🎵b');
      expect('🎵'.removeDiacritics(), '🎵');
      expect('Áldjad 🎵 én'.removeDiacritics(), 'Aldjad 🎵 en');
    });

    test('is idempotent', () {
      const text = 'Áldjad én lelkem 🎵 café çñ';
      expect(text.removeDiacritics().removeDiacritics(),
          text.removeDiacritics());
    });

    test('a string needing no change comes back equal', () {
      for (final text in ['', 'plain ascii', '123 !?', 'çñ', '🎵🎶']) {
        expect(text.removeDiacritics(), text, reason: 'for "$text"');
      }
    });
  });

  group('normalizeForSearch', () {
    test('lowercases, strips diacritics and trims', () {
      expect('  Áldjad ÉN  '.normalizeForSearch(), 'aldjad en');
    });

    test('whitespace-only becomes empty', () {
      expect('   '.normalizeForSearch(), '');
    });

    test('empty stays empty', () {
      expect(''.normalizeForSearch(), '');
    });

    test('inner whitespace is preserved', () {
      expect('a  b'.normalizeForSearch(), 'a  b');
    });
  });

  group('containsNormalized', () {
    test('is case-insensitive', () {
      expect('Hello World'.containsNormalized('WORLD'), isTrue);
    });

    test('is diacritic-insensitive both ways', () {
      expect('Áldjad én lelkem'.containsNormalized('aldjad'), isTrue);
      expect('Aldjad en lelkem'.containsNormalized('áldjad'), isTrue);
    });

    test('trims the query', () {
      expect('Hello'.containsNormalized('  hello  '), isTrue);
    });

    test('returns false for non-matches', () {
      expect('Hello'.containsNormalized('xyz'), isFalse);
    });

    test('every string contains the empty query', () {
      expect('Hello'.containsNormalized(''), isTrue);
      expect(''.containsNormalized(''), isTrue);
    });
  });
}
