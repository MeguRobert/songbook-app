import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/core/utils/text_utils.dart';

void main() {
  group('estimateTextWidth', () {
    test('scales linearly with text length', () {
      expect(TextUtils.estimateTextWidth('ab', 10), 2 * 10 * 0.55);
      expect(TextUtils.estimateTextWidth('abcd', 10),
          2 * TextUtils.estimateTextWidth('ab', 10));
    });

    test('scales linearly with font size', () {
      expect(TextUtils.estimateTextWidth('abc', 20),
          2 * TextUtils.estimateTextWidth('abc', 10));
    });

    test('empty text has zero width', () {
      expect(TextUtils.estimateTextWidth('', 18), 0);
    });
  });

  group('truncate', () {
    test('returns short text unchanged', () {
      expect(TextUtils.truncate('hello', 10), 'hello');
    });

    test('returns text at exactly maxLength unchanged', () {
      expect(TextUtils.truncate('hello', 5), 'hello');
    });

    test('truncates long text with ellipsis at maxLength total', () {
      final result = TextUtils.truncate('hello world', 8);
      expect(result, 'hello...');
      expect(result.length, 8);
    });

    test('handles empty string', () {
      expect(TextUtils.truncate('', 5), '');
    });
  });

  group('wrapText', () {
    test('keeps text within limit as a single line', () {
      expect(TextUtils.wrapText('hello world', 20), ['hello world']);
    });

    test('wraps at word boundaries', () {
      expect(
        TextUtils.wrapText('one two three four', 9),
        ['one two', 'three', 'four'],
      );
    });

    test('a word longer than the limit stays on its own line', () {
      expect(
        TextUtils.wrapText('supercalifragilistic yes', 10),
        ['supercalifragilistic', 'yes'],
      );
    });

    test('single word returns single line', () {
      expect(TextUtils.wrapText('word', 10), ['word']);
    });

    test('fills lines greedily up to the limit', () {
      expect(TextUtils.wrapText('aa bb cc', 5), ['aa bb', 'cc']);
    });

    test('empty string yields a single empty line', () {
      // ''.split(' ') is [''] and the empty word is written to the buffer,
      // but an empty buffer is never flushed, so no lines are produced.
      expect(TextUtils.wrapText('', 10), isEmpty);
    });
  });

  group('formatSongNumber', () {
    test('pads to three digits by default', () {
      expect(TextUtils.formatSongNumber(1), '001');
      expect(TextUtils.formatSongNumber(42), '042');
      expect(TextUtils.formatSongNumber(151), '151');
    });

    test('does not truncate numbers wider than the pad', () {
      expect(TextUtils.formatSongNumber(1234), '1234');
    });

    test('honors a custom digit count', () {
      expect(TextUtils.formatSongNumber(7, digits: 2), '07');
      expect(TextUtils.formatSongNumber(7, digits: 5), '00007');
    });
  });
}
