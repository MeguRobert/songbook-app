import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/photo_text_bridge.dart';

/// Which words are on one line, when their boxes are not the same height.
///
/// A word's box is only as tall as the ink in it. `öröm` is all x-height,
/// `Szívemben` carries a capital and an accent, `nyugalom` has descenders — so
/// on one flat baseline their box *centres* are far apart, and the difference is
/// typography rather than tilt. On `098-szivemben-orom-dalol` the boxes run 22
/// to 59 px against a median of 34.
///
/// That page's last line used to split in two and come back reordered:
/// `béke, hála, öröm dalol.` and then `Szívemben`, whose centre sat 21.9 px from
/// the row's running mean against a gate of 20.1 — short by 1.8 pixels. See
/// `PhotoTextBridge._sameRow` for the sweep that set the gate at 0.75, and for
/// why the Python arm keeps 0.6.
void main() {
  const bridge = PhotoTextBridge();

  OcrWord box(String text,
          {required double x,
          required double y0,
          required double y1,
          double width = 200}) =>
      OcrWord(text: text, x0: x, y0: y0, x1: x + width, y1: y1);

  group('a line whose boxes are different heights', () {
    test('the real last line of 098 stays one line', () {
      // Every box below is what the engine actually returned, to the pixel.
      final words = [
        box('Szívemben', x: 86, y0: 1637, y1: 1678, width: 210),
        box('hála,', x: 312, y0: 1632, y1: 1671, width: 86),
        box('hála..', x: 414, y0: 1630, y1: 1664, width: 96),
        box('Szívemben', x: 86, y0: 1691, y1: 1733, width: 210),
        box('béke,', x: 312, y0: 1685, y1: 1722, width: 96),
        box('béke..', x: 424, y0: 1682, y1: 1714, width: 105),
        box('Szívemben', x: 86, y0: 1744, y1: 1786, width: 209),
        box('nyugalom', x: 311, y0: 1734, y1: 1793, width: 182),
        box('van..', x: 509, y0: 1742, y1: 1792, width: 85),
        box('Szívemben', x: 85, y0: 1796, y1: 1841, width: 210),
        box('béke,', x: 312, y0: 1788, y1: 1825, width: 95),
        box('hála,', x: 422, y0: 1784, y1: 1822, width: 86),
        box('öröm', x: 522, y0: 1793, y1: 1815, width: 93),
        box('dalol.', x: 631, y0: 1784, y1: 1819, width: 99),
      ];
      final rows = bridge.groupRows(words);
      expect(rows, hasLength(4), reason: 'four printed lines, four rows');
      expect(rows.last.map((w) => w.text),
          ['Szívemben', 'béke,', 'hála,', 'öröm', 'dalol.']);
    });

    test('the reading keeps them in the order the page prints them', () {
      // The visible symptom: the row split and the halves sorted, so
      // `Szívemben` came out *after* the words it is printed in front of.
      final words = [
        box('Szívemben', x: 86, y0: 1637, y1: 1678, width: 210),
        box('hála,', x: 312, y0: 1632, y1: 1671, width: 86),
        box('Szívemben', x: 86, y0: 1691, y1: 1733, width: 210),
        box('béke,', x: 312, y0: 1685, y1: 1722, width: 96),
        box('Szívemben', x: 85, y0: 1796, y1: 1841, width: 210),
        box('béke,', x: 312, y0: 1788, y1: 1825, width: 95),
        box('hála,', x: 422, y0: 1784, y1: 1822, width: 86),
        box('öröm', x: 522, y0: 1793, y1: 1815, width: 93),
        box('dalol.', x: 631, y0: 1784, y1: 1819, width: 99),
      ];
      final lines = bridge.read(words).chordPro.split('\n');
      expect(lines.last, startsWith('Szívemben'));
      expect(lines.last, contains('dalol.'));
    });
  });

  group('and it still knows where a line ends', () {
    test('two printed lines do not become one', () {
      // 53 px apart, which is what this page sets its lines at, against boxes of
      // 34. The gate is 25.5 and has to stay well under the line pitch.
      final rows = bridge.groupRows([
        box('Szívemben', x: 86, y0: 1637, y1: 1671, width: 210),
        box('hála,', x: 312, y0: 1637, y1: 1671, width: 86),
        box('Szívemben', x: 86, y0: 1690, y1: 1724, width: 210),
        box('béke,', x: 312, y0: 1690, y1: 1724, width: 96),
        box('Szívemben', x: 86, y0: 1743, y1: 1777, width: 210),
        box('van..', x: 312, y0: 1743, y1: 1777, width: 85),
      ]);
      expect(rows, hasLength(3));
    });

    test('a chord row is not swallowed by the lyric under it', () {
      // The failure the gate exists to prevent, and the reason it cannot simply
      // be widened until everything joins. 185-jezus-krisztusom sets its chords
      // about 90 px above the words.
      final rows = bridge.groupRows([
        box('G', x: 462, y0: 371, y1: 428, width: 52),
        box('D', x: 709, y0: 369, y1: 425, width: 53),
        box('em', x: 1098, y0: 382, y1: 423, width: 93),
        box('Jézus', x: 259, y0: 469, y1: 526, width: 170),
        box('Krisztusom,', x: 458, y0: 462, y1: 531, width: 394),
        box('mentő', x: 879, y0: 461, y1: 518, width: 198),
      ]);
      expect(rows, hasLength(2));
      expect(rows.first.map((w) => w.text), ['G', 'D', 'em']);
    });
  });
}
