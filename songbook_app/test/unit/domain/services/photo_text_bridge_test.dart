import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/photo_text_bridge.dart';

/// The Dart port of the OCR -> ChordPro bridge.
///
/// An OCR engine returns each word with a bounding box; `ChordPosition.position`
/// is a character column into the lyric. Everything here is the arithmetic
/// between those two, and it is where a chord ends up over the wrong syllable.
///
/// Ported because the reading moved into the browser: Tesseract reads a real
/// photograph in about two seconds where the server engine took forty. Every
/// case below pins something that was found by measuring a real page, not by
/// imagining one.
void main() {
  const bridge = PhotoTextBridge();

  String render(List<OcrWord> words) => bridge.read(words).chordPro;

  List<OcrWord> row(double y, double height,
          List<(String, double, double)> tokens) =>
      [
        for (final (text, x0, x1) in tokens)
          OcrWord(text: text, x0: x0, y0: y, x1: x1, y1: y + height),
      ];

  // A plain couplet on a 10px monospace-ish grid, used wherever the test is
  // about placement rather than language.
  const lyrics = [
    ('Amazing', 0.0, 70.0),
    ('grace', 80.0, 130.0),
    ('how', 140.0, 170.0),
    ('sweet', 180.0, 230.0),
  ];

  List<OcrWord> tilt(List<OcrWord> words, double degrees) {
    final radians = degrees * math.pi / 180;
    final sin = math.sin(radians), cos = math.cos(radians);
    return [
      for (final w in words)
        () {
          final cx = (w.x0 + w.x1) / 2, cy = (w.y0 + w.y1) / 2;
          final nx = cx * cos - cy * sin, ny = cx * sin + cy * cos;
          final halfW = (w.x1 - w.x0) / 2, halfH = (w.y1 - w.y0) / 2;
          return OcrWord(
              text: w.text,
              x0: nx - halfW,
              y0: ny - halfH,
              x1: nx + halfW,
              y1: ny + halfH);
        }(),
    ];
  }

  group('placement', () {
    test('lyrics alone come back as a plain line', () {
      expect(render(row(100, 20, lyrics)), 'Amazing grace how sweet');
    });

    test('a chord lands over the syllable it sits above', () {
      final lines = render(row(70, 16, [('G', 0, 10), ('C', 180, 190)]) +
              row(100, 20, lyrics))
          .split('\n');
      expect(lines[0].indexOf('G'), lines[1].indexOf('Amazing'));
      expect(lines[0].indexOf('C'), lines[1].indexOf('sweet'));
    });

    test('a chord between two words lands inside the nearer one', () {
      // Two chords, because a row holding one bare root reads as lyrics.
      final lines = render(row(70, 16, [('G', 0, 10), ('D', 100, 110)]) +
              row(100, 20, lyrics))
          .split('\n');
      expect(lines[1][lines[0].indexOf('D')], 'a');
    });

    test('two chords wanting the same column do not merge', () {
      final chords = render(row(70, 16, [('G', 0, 10), ('C', 2, 12)]) +
              row(100, 20, lyrics))
          .split('\n')
          .first;
      expect(chords.trim().split(RegExp(r'\s+')), ['G', 'C']);
    });

    test('a chord row with nothing under it is kept', () {
      expect(render(row(70, 16, [('G', 0, 10), ('C', 100, 110)])).trim(),
          'G         C');
    });
  });

  group('rows', () {
    test('a wavy baseline stays one row', () {
      // A photographed page is never square-on; splitting on a few pixels
      // would put every word on its own line.
      final words = row(100, 20, [('Amazing', 0, 70)]) +
          row(104, 20, [('grace', 80, 130)]) +
          row(97, 20, [('how', 140, 170)]);
      expect(render(words), 'Amazing grace how');
    });

    test('one overtall region does not swallow the row above', () {
      // Measured on song 149: show-through merged into a lyric line gave a
      // 132px region for 60px letters, and the gate used to be sized from the
      // row's own height — so it widened itself and ate the chords.
      final words = row(70, 62, [('D', 0, 60), ('A', 1300, 1360)]) +
          [
            const OcrWord(
                text: 'Mondd, ki a dzsungel Királya? n bbod',
                x0: 0,
                y0: 105,
                x1: 1600,
                y1: 237)
          ];
      final lines = render(words).split('\n');
      expect(lines.length, 2);
      expect(lines.first.trim().startsWith('D'), isTrue);
    });

    test('a wide vertical gap starts a new verse', () {
      final words = row(100, 20, [('first', 0, 50)]) +
          row(130, 20, [('second', 0, 60)]) +
          row(300, 20, [('third', 0, 50)]);
      expect(render(words).split('\n'), ['first', 'second', '', 'third']);
    });

    test('a row with no letters at all is dropped', () {
      // Stave furniture: a time signature read as `4=`.
      final words = row(100, 20, [('Amazing', 0, 70)]) +
          row(140, 20, [('4=', 0, 20)]) +
          row(180, 20, [('grace', 0, 50)]);
      expect(render(words).split('\n'), ['Amazing', 'grace']);
    });
  });

  group('tilt', () {
    test('a known tilt is recovered', () {
      final page = row(70, 16, [('D', 0, 20), ('A', 80, 100)]) +
          row(100, 20, lyrics) +
          row(160, 16, [('G', 0, 20), ('C', 300, 320)]) +
          row(190, 20, [
            ('Nem', 0, 60),
            ('kell', 70, 130),
            ('már', 140, 200),
            ('félnem', 210, 330)
          ]);
      for (final degrees in [-8.0, -3.0, 0.0, 2.5, 6.5]) {
        expect(bridge.estimateSkew(tilt(page, degrees)), closeTo(degrees, 0.75),
            reason: '$degrees deg');
      }
    });

    test('a tilted page reads the same as a flat one', () {
      final page = row(70, 16, [('D', 0, 20), ('A', 80, 100)]) +
          row(100, 20, lyrics) +
          row(160, 16, [('G', 0, 20), ('C', 300, 320)]) +
          row(190, 20, [('Nem', 0, 60), ('kell', 70, 130)]);
      List<String> shape(List<OcrWord> w) =>
          render(w).split('\n').map((l) => l.trim().split(RegExp(r'\s+')).join(' ')).toList();
      expect(shape(tilt(page, 6.5)), shape(page));
    });
  });

  group('columns', () {
    List<OcrWord> twoColumns() =>
        row(100, 20, [('Az', 0, 40), ('Úr', 50, 90)]) +
        row(100, 20, [('Mondd,', 900, 1010), ('ki', 1020, 1050)]) +
        row(140, 20, [('irgalma', 0, 120)]) +
        row(140, 20, [('egész', 900, 1000)]);

    test('a gutter splits the page and the left column is read first', () {
      final text = render(twoColumns());
      expect(text.indexOf('irgalma'), lessThan(text.indexOf('Mondd,')));
    });

    test('the two songs stop sharing lines', () {
      for (final line in render(twoColumns()).split('\n')) {
        expect(line.contains('Az') && line.contains('Mondd,'), isFalse);
      }
    });

    test('a wide chord gap is not a gutter', () {
      // A chord row is nearly all whitespace; the lyric below covers the same
      // x, so the union has no hole.
      final words = row(70, 16, [('D', 0, 20), ('A', 900, 920)]) +
          row(100, 20, [('Az Úr irgalma végtelen, minden reggel', 0, 950)]);
      expect(bridge.splitColumns(words).length, 1);
    });

    test('two songs on one page are reported', () {
      expect(bridge.read(twoColumns()).warnings.join(),
          contains('side by side'));
    });
  });

  group('OCR repair', () {
    test('a one inside a word is read as i', () {
      expect(render(row(100, 20, [('m1nden', 0, 60)])), 'minden');
    });

    test('a six inside a word is read as o double acute', () {
      expect(render(row(100, 20, [('id6ben', 0, 120)])), 'időben');
    });

    test('a leading verse number survives', () {
      expect(render(row(100, 20, [('1', 0, 10), ('Amazing', 20, 90)])),
          '1 Amazing');
    });

    test('a space before a comma is closed', () {
      // The recogniser returns `vagy ,` as one region — measured on song 149.
      expect(render(row(100, 20, [('vagy ,', 0, 120)])), 'vagy,');
    });

    test('a spaced dash between syllables is left alone', () {
      expect(render(row(100, 20, [('for-mál - va', 0, 240)])), 'for-mál - va');
    });
  });

  group('the songbook page', () {
    test('the row `em A -7 D` is a chord row and lands on its lyric', () {
      // Verbatim from song 149. `em` is lowercase minor and `-7` is the book's
      // shorthand; the parser is the single source of truth for both.
      final words = row(70, 16, [
            ('em', 0, 30),
            ('A', 300, 320),
            ('-7', 600, 630),
            ('D', 900, 920)
          ]) +
          row(100, 20, [
            ('Mondd,', 0, 90),
            ('ki', 100, 130),
            ('az', 300, 330),
            ('egész', 600, 690),
            ('világ', 900, 980)
          ]);
      final lines = render(words).split('\n');
      expect(lines.length, 2);
      expect(lines.first.trim().split(RegExp(r'\s+')), ['em', 'A', '-7', 'D']);
      expect(lines[0].indexOf('em'), lines[1].indexOf('Mondd,'));
    });

    test('an H chord is reported as being stored under its English name', () {
      final words =
          row(70, 16, [('D', 0, 10), ('A', 100, 110), ('Hm', 200, 220)]) +
              row(100, 20, lyrics);
      expect(bridge.read(words).warnings.join(), contains('Hm'));
    });
  });

  group('the heading', () {
    // Found end to end in a browser, on the real photograph of song 149: this
    // book prints its heading barely larger than its lyrics, so a
    // height-only test made the heading the first line of the song. The Title
    // box stayed empty, the number was lost, and a two-verse song imported
    // with three.
    test('a first row opening with a hymn number is a title at body size',
        () async {
      final page = row(100, 20, [('149', 0, 30), ('Mondd,', 40, 100)]) +
          row(140, 20, lyrics) +
          row(180, 20, lyrics);
      expect(render(page), startsWith('{title: 149 Mondd,}'));
    });

    test('a plain opening line of the same size stays a lyric', () async {
      // The guard that keeps this from swallowing first lines: no number, no
      // extra height, no title.
      final page = row(100, 20, lyrics) +
          row(140, 20, lyrics) +
          row(180, 20, lyrics);
      expect(render(page), isNot(contains('{title:')));
    });

    test('a quantity is not a hymn number', () async {
      // `10 000 angyal` — digits followed by more digits are a count, and the
      // title has to survive intact.
      final page = row(100, 20, [('10', 0, 20), ('000', 30, 60), ('angyal', 70, 130)]) +
          row(140, 20, lyrics) +
          row(180, 20, lyrics);
      expect(render(page), isNot(contains('{title:')));
    });
  });

  group('empty and degenerate input', () {
    test('no words produce no content, with a warning', () {
      final reading = bridge.read(const []);
      expect(reading.chordPro, isEmpty);
      expect(reading.warnings, isNotEmpty);
    });

    test('too few words to judge a tilt leaves them alone', () {
      expect(render(row(100, 20, [('Amazing', 0, 70)])), 'Amazing');
    });
  });
}
