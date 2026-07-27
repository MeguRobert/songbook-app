import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/domain/services/chord_sheet_parser.dart';

void main() {
  const parser = ChordSheetParser();

  group('ChordSheetParser.isChordToken', () {
    test('accepts real chord symbols', () {
      const chords = [
        'G', 'Gm', 'G7', 'Gm7', 'Gmaj7', 'Gsus4', 'G#dim', 'Bb', 'F#m7',
        'G/B', 'C/E', 'Am7', 'Bbmaj7',
      ];
      for (final chord in chords) {
        expect(parser.isChordToken(chord), isTrue, reason: chord);
      }
    });

    test('rejects Hungarian words that start with a note letter', () {
      // Every one of these "matches" ChordTransposer's loose pattern.
      const words = ['Csak', 'Egy', 'Az', 'Be', 'Dad', 'Ez', 'Fel', 'Adj',
        'Gyere'];
      for (final word in words) {
        expect(parser.isChordToken(word), isFalse, reason: word);
      }
    });

    test('accepts less common but legitimate qualities', () {
      for (final chord in ['Cdim7', 'Caug', 'C+', 'C°', 'Cmin', 'Cadd9',
        'Csus2', 'Em7b5', 'C7#9', 'Bb/D', 'D7/F#']) {
        expect(parser.isChordToken(chord), isTrue, reason: chord);
      }
    });

    test('rejects near-misses and non-chords', () {
      for (final token in ['', 'H', 'c', 'g7', '7', '#C', 'Bbb', 'Chorus',
        '2x', 'G/H', 'Amen']) {
        expect(parser.isChordToken(token), isFalse, reason: token);
      }
    });
  });

  group('ChordSheetParser.isChordLine', () {
    test('a line of nothing but chords is a chord line', () {
      expect(parser.isChordLine('G       C'), isTrue);
      expect(parser.isChordLine('  Am7  D7/F#   Bbmaj7 '), isTrue);
    });

    test('one ordinary word disqualifies the whole line', () {
      // The point of the all-tokens rule: without it the lyrics below would be
      // eaten by a single chord-looking word.
      expect(parser.isChordLine('G       C       grace'), isFalse);
      expect(parser.isChordLine('Csak Egy Az'), isFalse);
    });

    test('empty and blank lines are not chord lines', () {
      expect(parser.isChordLine(''), isFalse);
      expect(parser.isChordLine('    '), isFalse);
    });

    test('a lone bare root resolves to lyrics', () {
      expect(parser.isChordLine('A'), isFalse);
      expect(parser.isChordLine('E'), isFalse);
      // Anything that removes the ambiguity flips it back to a chord line.
      expect(parser.isChordLine('Am'), isTrue);
      expect(parser.isChordLine('Bb'), isTrue);
      expect(parser.isChordLine('A E'), isTrue);
    });
  });

  group('ChordSheetParser.parse — inline brackets', () {
    test('strips brackets and indexes chords into the stripped text', () {
      final result = parser.parse('[G]Amazing [C]grace how [G]sweet');
      final line = result.verses.single.lines.single;

      expect(line.text, 'Amazing grace how sweet');
      expect(line.chords, const [
        ChordPosition(chord: 'G', position: 0),
        ChordPosition(chord: 'C', position: 8),
        ChordPosition(chord: 'G', position: 18),
      ]);
    });

    test('handles a chord at the very end of the line', () {
      final line = parser.parse('sweet[G]').verses.single.lines.single;
      expect(line.text, 'sweet');
      expect(line.chords, const [ChordPosition(chord: 'G', position: 5)]);
    });

    test('a bracket-only line yields chords over empty text', () {
      final line = parser.parse('[G] [C]').verses.single.lines.single;
      expect(line.text, '');
      expect(line.chords, const [
        ChordPosition(chord: 'G', position: 0),
        ChordPosition(chord: 'C', position: 1),
      ]);
    });

    test('non-chord brackets stay as text and raise a warning', () {
      final result = parser.parse('[Chorus] sing [2x]');
      final line = result.verses.single.lines.single;

      expect(line.text, '[Chorus] sing [2x]');
      expect(line.chords, isEmpty);
      expect(result.warnings.length, 2);
      expect(result.warnings.first, contains('[Chorus]'));
    });

    test('an unclosed bracket is left alone', () {
      final line = parser.parse('grace [G how').verses.single.lines.single;
      expect(line.text, 'grace [G how');
      expect(line.chords, isEmpty);
    });
  });

  group('ChordSheetParser.parse — chords over lyrics', () {
    test('column of each chord token becomes its character position', () {
      final result = parser.parse('G       C\nAmazing grace');
      final line = result.verses.single.lines.single;

      expect(line.text, 'Amazing grace');
      expect(line.chords, const [
        ChordPosition(chord: 'G', position: 0),
        ChordPosition(chord: 'C', position: 8),
      ]);
    });

    test('produces the same model as the equivalent inline paste', () {
      final twoLine = parser.parse('G       C\nAmazing grace');
      final inline = parser.parse('[G]Amazing [C]grace');
      expect(twoLine.verses.single.lines, inline.verses.single.lines);
    });

    test('a chord past the end of the lyric keeps its column', () {
      // The renderer offsets chords horizontally and never indexes the text,
      // so an overhanging position is meaningful, not a crash.
      final line =
          parser.parse('G       C       D\nAmazing grace').verses.single.lines.single;
      expect(line.text, 'Amazing grace');
      expect(line.chords.last, const ChordPosition(chord: 'D', position: 16));
    });

    test('a chord line with nothing under it becomes an instrumental line', () {
      final verse = parser.parse('G  C  D').verses.single;
      expect(verse.lines.single.text, '');
      expect(verse.lines.single.chords, const [
        ChordPosition(chord: 'G', position: 0),
        ChordPosition(chord: 'C', position: 3),
        ChordPosition(chord: 'D', position: 6),
      ]);
    });

    test('two chord lines in a row do not pair with each other', () {
      final verse = parser.parse('G  C\nD  G').verses.single;
      expect(verse.lines.length, 2);
      expect(verse.lines.every((l) => l.text.isEmpty), isTrue);
    });

    test('handles several pairs and a trailing plain lyric', () {
      final verse = parser.parse(
        'G       C\nAmazing grace\nD7\nhow sweet\nthe sound',
      ).verses.single;

      expect(verse.lines.length, 3);
      expect(verse.lines[0].text, 'Amazing grace');
      expect(verse.lines[1].text, 'how sweet');
      expect(verse.lines[1].chords, const [ChordPosition(chord: 'D7', position: 0)]);
      expect(verse.lines[2].text, 'the sound');
      expect(verse.lines[2].chords, isEmpty);
    });
  });

  group('ChordSheetParser.parse — the Hungarian trap', () {
    test('"Csak Egy Az" survives as lyric text', () {
      final result = parser.parse('Csak Egy Az');
      final line = result.verses.single.lines.single;

      expect(line.text, 'Csak Egy Az');
      expect(line.chords, isEmpty);
      expect(line.text.split(' '), ['Csak', 'Egy', 'Az']);
    });

    test('chords above a Hungarian line still attach to it', () {
      final line = parser.parse('C       G\nCsak Egy Az').verses.single.lines.single;
      expect(line.text, 'Csak Egy Az');
      expect(line.chords, const [
        ChordPosition(chord: 'C', position: 0),
        ChordPosition(chord: 'G', position: 8),
      ]);
    });

    test('a lone bare root is kept as a lyric and warned about', () {
      final result = parser.parse('A\nAmazing grace');

      expect(result.verses.single.lines.length, 2);
      expect(result.verses.single.lines[0].text, 'A');
      expect(result.verses.single.lines[0].chords, isEmpty);
      expect(result.warnings.single, contains('Line 1'));
      expect(result.warnings.single, contains('"A"'));
    });
  });

  group('ChordSheetParser.parse — verses', () {
    test('a blank line breaks the verse and numbering starts at 1', () {
      final result = parser.parse('first\nsecond\n\nthird');

      expect(result.verses.length, 2);
      expect(result.verses[0].number, 1);
      expect(result.verses[0].lines.length, 2);
      expect(result.verses[1].number, 2);
      expect(result.verses[1].lines.single.text, 'third');
    });

    test('runs of blank lines and leading/trailing blanks do not add verses', () {
      final result = parser.parse('\n\nfirst\n\n\n\nsecond\n\n');
      expect(result.verses.map((v) => v.number), [1, 2]);
    });

    test('verses never claim engraved notation', () {
      final result = parser.parse('[G]one\n\ntwo');
      expect(result.verses.every((v) => !v.hasNotation), isTrue);
      expect(result.verses.every((v) => v.plainText == null), isTrue);
    });

    test('accepts CRLF and CR line endings', () {
      expect(parser.parse('first\r\n\r\nsecond').verses.length, 2);
      expect(parser.parse('first\r\rsecond').verses.length, 2);
    });

    test('empty and whitespace-only input yields no verses', () {
      expect(parser.parse('').isEmpty, isTrue);
      expect(parser.parse('   \n\n  ').verses, isEmpty);
      expect(parser.parse('').warnings, isEmpty);
    });
  });

  group('ChordSheetParser.parse — directives', () {
    test('reads title, key and comments', () {
      final result = parser.parse(
        '{title: Amazing Grace}\n{key: G}\n{c: Slowly}\n\n[G]Amazing grace',
      );

      expect(result.title, 'Amazing Grace');
      expect(result.key, 'G');
      expect(result.comments, ['Slowly']);
      expect(result.verses.single.number, 1);
      expect(result.verses.single.lines.single.text, 'Amazing grace');
    });

    test('accepts the short directive spellings', () {
      final result = parser.parse('{t:Grace}\n{k:Bb}\n{comment:Gently}\nline');
      expect(result.title, 'Grace');
      expect(result.key, 'Bb');
      expect(result.comments, ['Gently']);
    });

    test('directives are optional', () {
      final result = parser.parse('Amazing grace');
      expect(result.title, isNull);
      expect(result.key, isNull);
      expect(result.comments, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('directives do not split a verse or become lyrics', () {
      final result = parser.parse('one\n{c: quietly}\ntwo');
      expect(result.verses.single.lines.map((l) => l.text), ['one', 'two']);
      expect(result.comments, ['quietly']);
    });

    test('soc/eoc bracket a chorus and mark its verse numbers', () {
      final result = parser.parse(
        'verse one\n{soc}\nchorus line\n{eoc}\nverse two',
      );

      expect(result.verses.length, 3);
      expect(result.chorusVerseNumbers, {2});
      expect(result.verses[1].lines.single.text, 'chorus line');
    });

    test('unknown directives are ignored with a warning', () {
      final result = parser.parse('{define: G base-fret 1}\nline');
      expect(result.verses.single.lines.single.text, 'line');
      expect(result.warnings.single, contains('unknown directive'));
    });
  });

  group('ChordSheetParser.parse — a whole sheet', () {
    test('mixes both chord shapes across verses', () {
      const sheet = '''
{title: Amazing Grace}
{key: G}

G       C       G
Amazing grace how sweet the sound
That [D]saved a [G]wretch like me

{soc}
Csak Egy Az
G  C  D
{eoc}
''';

      final result = parser.parse(sheet);

      expect(result.title, 'Amazing Grace');
      expect(result.key, 'G');
      expect(result.verses.length, 2);
      expect(result.chorusVerseNumbers, {2});
      expect(result.warnings, isEmpty);

      final verse1 = result.verses[0];
      expect(verse1.lines.length, 2);
      expect(verse1.lines[0].text, 'Amazing grace how sweet the sound');
      expect(verse1.lines[0].chords, const [
        ChordPosition(chord: 'G', position: 0),
        ChordPosition(chord: 'C', position: 8),
        ChordPosition(chord: 'G', position: 16),
      ]);
      expect(verse1.lines[1].text, 'That saved a wretch like me');
      expect(verse1.lines[1].chords, const [
        ChordPosition(chord: 'D', position: 5),
        ChordPosition(chord: 'G', position: 13),
      ]);

      final verse2 = result.verses[1];
      expect(verse2.lines[0].text, 'Csak Egy Az');
      expect(verse2.lines[0].chords, isEmpty);
      expect(verse2.lines[1].text, '');
      expect(verse2.lines[1].chords.length, 3);
    });
  });
}
