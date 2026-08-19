import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/page_preprocessor.dart';

/// A hymnal is printed thin enough to read the reverse page through it, and an
/// OCR engine returns that ghost as words. Measured on a real photograph of
/// song 149: `n bbod`, `$`, `drnisdl ,Edtt` stuck to the real lyrics, and the
/// ghost merged into the real regions badly enough to destroy a whole chord
/// row. The ghost is always PALER than the print, which is what both the
/// detector and the fix rest on.
///
/// This is the Dart port of the Python original — the reading now happens in
/// the browser, so the cleaning has to as well.
void main() {
  const preprocessor = PagePreprocessor();
  const size = 400;

  /// A white page with bands of thin vertical strokes — ink, not solid blocks.
  ///
  /// Solid blocks are not text: the background estimate is taken over a wide
  /// window, so a full-width block reads AS the background and flattens to
  /// white. Thin strokes on white behave the way print does.
  Uint8List page({int darkBand = 0, int paleBand = 0, int pale = 200}) {
    final pixels = Uint8List(size * size)..fillRange(0, size * size, 255);
    void strokes(int top, int height, int value) {
      for (var y = top; y < top + height && y < size; y++) {
        for (var x = 0; x < size; x += 24) {
          for (var d = 0; d < 4 && x + d < size; d++) {
            pixels[y * size + x + d] = value;
          }
        }
      }
    }

    if (darkBand > 0) strokes(10, darkBand, 20);
    if (paleBand > 0) strokes(size - 10 - paleBand, paleBand, pale);
    return pixels;
  }

  group('PagePreprocessor.hasShowThrough', () {
    test('a page of print alone is not flagged', () {
      expect(preprocessor.hasShowThrough(page(darkBand: 120), size, size),
          isFalse);
    });

    test('a blank page is not flagged', () {
      expect(preprocessor.hasShowThrough(page(), size, size), isFalse);
    });

    test('pale ink alongside the print is flagged', () {
      // The signature of a thin page: a second, lighter population of ink.
      expect(
          preprocessor.hasShowThrough(
              page(darkBand: 60, paleBand: 120), size, size),
          isTrue);
    });

    test('a trace of pale is not enough', () {
      // Antialiasing along the edge of black print is pale too, and every
      // photograph has some. Only a real population counts.
      expect(
          preprocessor.hasShowThrough(
              page(darkBand: 120, paleBand: 4), size, size),
          isFalse);
    });
  });

  group('PagePreprocessor.suppressShowThrough', () {
    test('pale ink is erased and print is kept', () {
      // Sampled ON a stroke: bars sit at x = 0, 24, 48 … so x=25 is ink.
      final cleaned = preprocessor.suppressShowThrough(
          page(darkBand: 120, paleBand: 120), size, size);
      expect(cleaned[60 * size + 25], lessThan(100), reason: 'print stays dark');
      expect(cleaned[330 * size + 25], greaterThan(200),
          reason: 'ghost is gone');
    });

    test('the length survives', () {
      final source = page(darkBand: 90, paleBand: 90);
      expect(preprocessor.suppressShowThrough(source, size, size).length,
          source.length);
    });

    test('an image smaller than the background window is fine', () {
      // A cropped or thumbnail upload would otherwise divide by nothing.
      final tiny = Uint8List(21 * 21)..fillRange(0, 21 * 21, 255);
      expect(preprocessor.suppressShowThrough(tiny, 21, 21).length, 21 * 21);
      expect(preprocessor.hasShowThrough(tiny, 21, 21), isFalse);
    });

    test('an empty image is handled rather than dividing by zero', () {
      expect(preprocessor.suppressShowThrough(Uint8List(0), 0, 0), isEmpty);
      expect(preprocessor.hasShowThrough(Uint8List(0), 0, 0), isFalse);
    });
  });
}
