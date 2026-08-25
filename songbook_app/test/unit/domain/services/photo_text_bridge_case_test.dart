import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/import_notice.dart';
import 'package:songbook_app/domain/services/photo_text_bridge.dart';

/// A lowercase `c` on a photographed chord row.
///
/// `C` and `c` are the same shape at two sizes, and no other note letter is:
/// `a`, `b`, `d`, `e`, `f`, `g` and `h` all change form between cases. So an
/// engine returning a lowercase `c` has told you nothing, and a songbook that
/// writes its minors as `em`, `am`, `gm`, `dm`, `hm` and `fiszm` — every
/// lowercase chord in the measurement corpus and in the whole shipped
/// catalogue, eleven of them, and not one a bare root — does not print a bare
/// `c` for C minor.
///
/// Measured: `084-van-egy-ut` prints italic capital `C` twelve times and the
/// engine returned `c` for six of them, which was the whole of that page's
/// 0.583 chord recall. `125-nincs-mas-isten` does it three times. Every one
/// reached storage as `Cm` — silently wrong music, which is worse than music
/// that is missing.
///
/// The page cannot prove which was meant, so the reading says what it did and
/// the review box is where it is settled.
void main() {
  const bridge = PhotoTextBridge();

  OcrWord word(String text, {required double x, required double y}) => OcrWord(
        text: text,
        x0: x,
        y0: y,
        x1: x + text.length * 20,
        y1: y + 30,
      );

  /// The shape of `084-van-egy-ut`: a chord row over a lyric, twice.
  List<OcrWord> page(List<String> chords) => [
        for (var i = 0; i < chords.length; i++)
          word(chords[i], x: 100 + i * 200, y: 100),
        word('Igaz,', x: 100, y: 160),
        word('hogy', x: 220, y: 160),
        word('nem', x: 340, y: 160),
        word('szeles', x: 460, y: 160),
        word('Ez', x: 100, y: 260),
        word('az', x: 180, y: 260),
        word('ut', x: 260, y: 260),
        word('egy', x: 340, y: 260),
      ];

  group('a lowercase c is raised', () {
    test('it reaches the reading as C, not c', () {
      final reading = bridge.read(page(['F', 'c', 'G']));
      expect(reading.chordPro, contains('C'));
      expect(reading.chordPro, isNot(contains('c ')));
    });

    test('the reading says how many it raised', () {
      final reading = bridge.read(page(['F', 'c', 'G', 'c']));
      final notice = reading.notices
          .where((n) => n.code == ImportNoticeCode.photoLowercaseCRaised);
      expect(notice, hasLength(1));
      expect(notice.single.count, 2);
    });

    test('a page with no lowercase c says nothing about one', () {
      final reading = bridge.read(page(['F', 'C', 'G']));
      expect(
          reading.notices.map((n) => n.code),
          isNot(contains(ImportNoticeCode.photoLowercaseCRaised)));
    });
  });

  group('what it must not touch', () {
    test('a spelled-out minor keeps its case', () {
      // `em`, `am`, `gm`, `dm`, `hm`, `fiszm` — the songbook's own minors, and
      // every lowercase chord that actually appears in the corpus.
      for (final minor in ['em', 'am', 'gm', 'dm', 'hm', 'fiszm', 'cm']) {
        final reading = bridge.read(page(['F', minor, 'G']));
        expect(reading.chordPro, contains(minor),
            reason: '$minor must survive as written');
      }
    });

    test('a lowercase root that is not c keeps its case', () {
      // Those letters change shape between cases, so the engine reporting one
      // in lowercase is evidence and is believed.
      for (final root in ['a', 'd', 'e', 'g', 'h']) {
        final reading = bridge.read(page(['F', root, 'G']));
        expect(reading.chordPro, contains(root),
            reason: '$root must survive as written');
      }
    });

    test('a c with a quality on it keeps its case', () {
      // `csus4` is neither major nor minor and `c7` states its own quality.
      // Only a BARE c is the ambiguous one.
      for (final chord in ['csus4', 'c7', 'cmaj7']) {
        final reading = bridge.read(page(['F', chord, 'G']));
        expect(reading.chordPro, contains(chord), reason: chord);
      }
    });

    test('a c in the words is left alone', () {
      // The repair is on chord rows only. A `c` standing as a word on a lyric
      // row is a letter of Hungarian.
      final reading = bridge.read([
        word('F', x: 100, y: 100),
        word('G', x: 300, y: 100),
        word('c', x: 100, y: 160),
        word('meg', x: 180, y: 160),
        word('nem', x: 300, y: 160),
        word('szeles', x: 420, y: 160),
        word('Ez', x: 100, y: 260),
        word('az', x: 180, y: 260),
        word('ut', x: 260, y: 260),
      ]);
      expect(reading.chordPro.split(RegExp(r'\n')),
          contains(matches(RegExp(r'^c\s+meg$'))));
    });
  });
}
