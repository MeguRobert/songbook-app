import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/photo_text_bridge.dart';

/// The printed lines of a page, told apart from its letters.
///
/// A songbook page is not only type. It carries a box around the text, a rule
/// between its columns, a letterbox edge where the photograph stops, and the
/// status bar of the phone that took it — and Tesseract returns every one of
/// them as a word, because a word is what it is asked for. Measured in a real
/// browser over `tools/fixtures/photos/`:
///
/// | page | what the engine returned | box |
/// |---|---|---|
/// | `125-nincs-mas-isten` | `!` `;` `,` `)` `]` `i` `I`, 22 of them | 1–5 px wide, 8–80 tall |
/// | `125-nincs-mas-isten` | `TT` | 575 x 30 |
/// | `151-zengjed-a-dalt` | `A`, twice | 944 x 25 |
/// | `app-jezus-szivedbe-lat` | `s` | 922 x 13 |
/// | `166-tekozlo-fiu` | `,` | 4 x 3 |
///
/// The 22 on `125` are the box's left border, its centre rule and its right
/// border, sliced by the engine's own line finding; the page is tilted, so they
/// track across the page as y grows (x 69 at the top, x 146 at the foot). They
/// were most of that page's lyric error: 48 lyric lines against 33 expected, a
/// character error rate of 0.559 where every other reviewed page is under 0.21.
///
/// Neither dimension finds them alone, which is the whole reason there are two
/// rules here and why both numbers are what they are. See
/// `PhotoTextBridge.withoutFurniture`.
void main() {
  const bridge = PhotoTextBridge();

  /// A word of [text] whose box is [width] x [height] at ([x], [y]).
  OcrWord word(String text,
          {required double x,
          required double y,
          required double width,
          required double height}) =>
      OcrWord(text: text, x0: x, y0: y, x1: x + width, y1: y + height);

  /// A page of ordinary type: 19 px to the glyph, 30 px tall, which is what
  /// `125-nincs-mas-isten` measures.
  List<OcrWord> typePage() => [
        for (var row = 0; row < 6; row++)
          for (var column = 0; column < 4; column++)
            word('Isten',
                x: 200 + column * 120,
                y: 200 + row * 60,
                width: 95,
                height: 30),
      ];

  List<String> textsOf(List<OcrWord> words) =>
      words.map((w) => w.text).toList();

  group('a stroke is not a letter', () {
    test('the sliced border of a printed box is dropped', () {
      // Every one of these is a real box from 125-nincs-mas-isten.
      final page = typePage()
        ..addAll([
          word('!', x: 69, y: 272, width: 1, height: 16),
          word(',', x: 91, y: 660, width: 3, height: 21),
          word(';', x: 144, y: 1592, width: 2, height: 37),
          word('i', x: 144, y: 1631, width: 2, height: 17),
          word('!', x: 826, y: 240, width: 3, height: 80),
          word(')', x: 74, y: 356, width: 2, height: 34),
          word(']', x: 91, y: 648, width: 2, height: 10),
          word('I', x: 1524, y: 432, width: 1, height: 16),
        ]);
      expect(textsOf(bridge.withoutFurniture(page)), everyElement('Isten'));
    });

    test('a speck of dirt on the page is dropped', () {
      // 166-tekozlo-fiu returned this comma at 4x3 with confidence 0.
      final page = typePage()..add(word(',', x: 700, y: 900, width: 4, height: 3));
      expect(textsOf(bridge.withoutFurniture(page)), everyElement('Isten'));
    });

    test('a real narrow letter survives', () {
      // 109-tart-meg-a-kegyelem prints the Hungarian article `a` at 9 px on a
      // page whose glyphs measure 26 - 0.35 of the median, and the narrowest
      // real thing in the corpus. It is the reason the gate is not 0.4.
      final page = [
        for (var row = 0; row < 8; row++)
          word('kegyelem',
              x: 200, y: 200 + row * 60, width: 208, height: 40),
        word('a', x: 150, y: 300, width: 9, height: 28),
      ];
      expect(textsOf(bridge.withoutFurniture(page)), contains('a'));
    });

    test('a full stop and a dotted leader survive', () {
      // 098 returns `.` at 9x8 and 185 returns `....` at 70x8. Both are the
      // page's own punctuation and both are narrower per glyph than its type.
      final page = typePage()
        ..add(word('.', x: 700, y: 300, width: 9, height: 8))
        ..add(word('....', x: 700, y: 400, width: 70, height: 8));
      final kept = textsOf(bridge.withoutFurniture(page));
      expect(kept, contains('.'));
      expect(kept, contains('....'));
    });
  });

  group('a rule is not a letter', () {
    test('the top border of a printed box is dropped', () {
      // 125-nincs-mas-isten, read as `TT` across 575 px.
      final page = typePage()
        ..add(word('TT', x: 780, y: 138, width: 575, height: 30));
      expect(textsOf(bridge.withoutFurniture(page)), everyElement('Isten'));
    });

    test('a letterbox edge is dropped', () {
      // 151-zengjed-a-dalt returned this twice, as `A`.
      final page = typePage()
        ..add(word('A', x: 40, y: 100, width: 944, height: 25));
      expect(textsOf(bridge.withoutFurniture(page)), everyElement('Isten'));
    });

    test('the status bar of the phone that took the photo is dropped', () {
      // app-jezus-szivedbe-lat is a screenshot, and its status bar rule came
      // back as `s` across 922 px.
      final page = typePage()
        ..add(word('s', x: 30, y: 20, width: 922, height: 13));
      expect(textsOf(bridge.withoutFurniture(page)), everyElement('Isten'));
    });

    test('a real em dash survives', () {
      // app-jezus-szivedbe-lat prints `->` and the engine returns `—` at
      // 93x24. Wide and flat and real, which is why the gate is 5 and not 4.
      final page = typePage()
        ..add(word('—', x: 700, y: 300, width: 93, height: 24));
      expect(textsOf(bridge.withoutFurniture(page)), contains('—'));
    });

    test('a merged pair of chords survives', () {
      // 185-jezus-krisztusom returns `DG` at 237x62 - two chords the engine
      // joined, which splitMergedChords is there to pull apart.
      final page = [
        for (var row = 0; row < 8; row++)
          word('Krisztusom',
              x: 200, y: 200 + row * 90, width: 386, height: 60),
        word('DG', x: 200, y: 100, width: 237, height: 62),
      ];
      expect(textsOf(bridge.withoutFurniture(page)), contains('DG'));
    });

    test('a large handwritten digit survives', () {
      // 105-kosz-jol-vagyok is written over in marker; its `2` measures 98x85
      // on a page of 21 px type, the widest real glyph in the corpus.
      final page = [
        for (var row = 0; row < 8; row++)
          word('vagyok', x: 200, y: 200 + row * 60, width: 127, height: 34),
        word('2', x: 600, y: 100, width: 98, height: 85),
      ];
      expect(textsOf(bridge.withoutFurniture(page)), contains('2'));
    });
  });

  group('the rule cannot run away with the page', () {
    test('a page too small to measure is left alone', () {
      // Three words is not a distribution. Nothing here is furniture, and a
      // median taken over this would be an opinion rather than a measurement.
      final page = [
        word('!', x: 10, y: 10, width: 1, height: 30),
        word('Isten', x: 40, y: 10, width: 95, height: 30),
      ];
      expect(bridge.withoutFurniture(page), hasLength(2));
    });

    test('filtering an already filtered page changes nothing', () {
      final page = typePage()
        ..add(word('!', x: 69, y: 272, width: 1, height: 16))
        ..add(word('TT', x: 780, y: 138, width: 575, height: 30));
      final once = bridge.withoutFurniture(page);
      expect(bridge.withoutFurniture(once), hasLength(once.length));
    });

    test('a page of nothing but rules reads as nothing legible', () {
      final page = [
        for (var row = 0; row < 8; row++)
          word('!', x: 69, y: 100 + row * 60, width: 2, height: 30),
      ];
      // Everything is furniture by its own page's measure - the median glyph
      // width is 2 px, so nothing is narrow relative to it. The point of this
      // test is that the rule cannot empty a page it has no evidence about.
      expect(bridge.withoutFurniture(page), hasLength(8));
    });
  });

  group('what the page reads as', () {
    test('a border slice does not reach a chord row', () {
      // The `!` in front of `Em C G` on 125-nincs-mas-isten. The row survives
      // as chords because one stray token is tolerated, and the stray is then
      // stored as a chord in the column the border was printed in.
      final words = [
        word('!', x: 100, y: 200, width: 2, height: 30),
        word('Em', x: 152, y: 200, width: 53, height: 26),
        word('C', x: 400, y: 200, width: 22, height: 26),
        word('G', x: 600, y: 200, width: 25, height: 26),
        word('Nincs', x: 152, y: 260, width: 95, height: 30),
        word('mas', x: 260, y: 260, width: 76, height: 30),
        word('Isten', x: 350, y: 260, width: 95, height: 30),
        word('Nincsen', x: 152, y: 320, width: 133, height: 30),
        word('mas', x: 300, y: 320, width: 76, height: 30),
      ];
      expect(bridge.read(words).chordPro, isNot(contains('!')));
    });

    test('a border slice does not become a lyric line of its own', () {
      final words = [
        word('Refren', x: 152, y: 200, width: 114, height: 30),
        word(';', x: 144, y: 260, width: 2, height: 37),
        word('Hegyeket', x: 152, y: 320, width: 152, height: 30),
        word('mozdit', x: 320, y: 320, width: 114, height: 30),
        word('Beteget', x: 152, y: 380, width: 133, height: 30),
        word('gyogyit', x: 300, y: 380, width: 133, height: 30),
        word('Az', x: 152, y: 440, width: 38, height: 30),
        word('Ur', x: 200, y: 440, width: 38, height: 30),
      ];
      final lines = bridge.read(words).chordPro.split('\n');
      expect(lines, isNot(contains(';')));
    });
  });
}
