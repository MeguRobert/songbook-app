import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/photo_text_bridge.dart';

/// The heading of the *next* song, caught by the bottom of the frame.
///
/// A hymnal prints one song after another down the page, so a photograph framed
/// on song 98 catches the head of song 99 at its foot. On
/// `098-szivemben-orom-dalol` — the page the corpus named
/// `chords-next-song-header` and then waited two sessions for someone to read —
/// the engine returns `99. Több erőt  a-t.` as the last row, clipped by the edge
/// of the image, and it became a lyric line of song 98.
///
/// The signal is that it is a numbered heading standing as the **last** row.
/// Every page of this songbook opens with a number and no lyric does, which is
/// the same rule the title at the top of the page is found by; and a song's own
/// heading is never the last thing on the page.
///
/// Height was the other candidate and it does not separate: `99. Több erőt` is
/// 43–45 px against a body of 34, which is 1.3, and `1. Versszak` on
/// `125-nincs-mas-isten` is 35 against 29, which is 1.2. `_titleHeight` is 1.25
/// and sits between them, which is luck rather than a rule. Being last is not
/// luck — `1. Versszak` has twenty rows under it.
void main() {
  const bridge = PhotoTextBridge();

  OcrWord word(String text,
          {required double x, required double y, double height = 34}) =>
      OcrWord(
        text: text,
        x0: x,
        y0: y,
        x1: x + text.length * 23,
        y1: y + height,
      );

  /// Song 98's shape: a title, three lyric rows, and whatever is passed as the
  /// tail.
  /// One column: the heading overlaps the body's own x range, as it does on the
  /// real page, so nothing here reads as two columns.
  List<OcrWord> page(List<OcrWord> tail) => [
        word('98.', x: 200, y: 720, height: 44),
        word('Szívemben', x: 310, y: 720, height: 44),
        word('Szívemben', x: 90, y: 1637),
        word('hála,', x: 312, y: 1637),
        word('Szívemben', x: 90, y: 1691),
        word('béke,', x: 312, y: 1691),
        word('Szívemben', x: 90, y: 1744),
        word('van..', x: 312, y: 1744),
        ...tail,
      ];

  List<String> linesOf(PhotoReading reading) => reading.chordPro.split('\n');

  group('the next song’s heading', () {
    test('a numbered heading in the last row is dropped', () {
      // The real boxes from 098: y 1991-2047, where 2047 is the page edge.
      final reading = bridge.read(page([
        word('99.', x: 200, y: 1991, height: 43),
        word('Több', x: 310, y: 1991, height: 45),
        word('erőt', x: 460, y: 1991, height: 35),
      ]));
      expect(reading.chordPro, isNot(contains('99.')));
      expect(reading.chordPro, isNot(contains('Több')));
    });

    test('the song it was printed under is untouched', () {
      final withTail = bridge.read(page([
        word('99.', x: 200, y: 1991, height: 43),
        word('Több', x: 310, y: 1991, height: 45),
      ]));
      final without = bridge.read(page(const []));
      expect(withTail.chordPro, without.chordPro);
    });
  });

  group('what it must not take', () {
    test('a numbered section label mid-page stays a lyric', () {
      // `1. Versszak` and `2. Versszak` on 125-nincs-mas-isten. They are
      // numbered headings by the same pattern, and they are not last.
      // Set in the middle, with the page's real heading above it and lyrics
      // below, so the title rule cannot be what saves it.
      final reading = bridge.read([
        word('125.', x: 90, y: 60, height: 44),
        word('Nincs', x: 200, y: 60, height: 44),
        word('más', x: 340, y: 60, height: 44),
        word('Nálad', x: 90, y: 183),
        word('lett', x: 230, y: 183),
        word('2.', x: 90, y: 300, height: 35),
        word('Versszak', x: 130, y: 300, height: 35),
        word('Holtakat', x: 90, y: 360),
        word('életre', x: 290, y: 360),
        word('Nincs', x: 90, y: 420),
        word('más', x: 230, y: 420),
      ]);
      expect(reading.chordPro, contains('Versszak'));
    });

    test('a numbered heading that is the last row of a one-row page stays', () {
      // Nothing to be the next song *after*: with no song above it, this is the
      // page's own heading and the title rule owns it.
      final reading = bridge.read([
        word('98.', x: 90, y: 100, height: 44),
        word('Szívemben', x: 200, y: 100, height: 44),
        word('öröm', x: 480, y: 100, height: 44),
        word('dalol', x: 620, y: 100, height: 44),
      ]);
      expect(reading.chordPro, contains('Szívemben'));
    });

    test('an ordinary last lyric line is kept', () {
      final reading = bridge.read(page([
        word('Szívemben', x: 90, y: 1796),
        word('béke,', x: 312, y: 1796),
        word('dalol.', x: 460, y: 1796),
      ]));
      expect(linesOf(reading).last, contains('dalol.'));
    });

    test('a last row that opens with a number but is a lyric is kept', () {
      // `10 000 angyal` is the case the numbered-heading pattern was written to
      // exclude, and it has to stay excluded here too: what follows the number
      // must not itself be a digit.
      final reading = bridge.read(page([
        word('10', x: 90, y: 1796),
        word('000', x: 150, y: 1796),
        word('angyal', x: 240, y: 1796),
      ]));
      expect(reading.chordPro, contains('angyal'));
    });
  });
}
