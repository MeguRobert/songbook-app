import 'dart:math' as math;

import 'chord_sheet_parser.dart';
import 'import_notice.dart';

/// One word as an OCR engine reports it: the text, and where it sat.
class OcrWord {
  final String text;
  final double x0;
  final double y0;
  final double x1;
  final double y1;

  /// The glyphs inside this word, where the engine reported them.
  ///
  /// Only ever read to undo a merge. Tesseract returns `D G  D` as the single
  /// word `DGD` when the gaps are narrow, and `G - C - D - ( C )` as
  /// `G-C-D-(C)`. Neither is a chord symbol, so the all-or-nothing rule threw
  /// the whole row away as lyrics. Measured on the corpus, that alone took
  /// `185-jezus-krisztusom` to *zero* chords found and cost
  /// `app-jezus-szivedbe-lat` more than half of its.
  ///
  /// There is no whitespace to split on, so the split has to come from where
  /// the glyphs actually are. Empty when the engine does not report symbols, in
  /// which case nothing changes.
  final List<OcrWord> symbols;

  const OcrWord({
    required this.text,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    this.symbols = const [],
  });

  double get centreX => (x0 + x1) / 2;
  double get centreY => (y0 + y1) / 2;
  double get height => y1 - y0;
  double get width => x1 - x0;

  /// The same word with its centre at ([centreX], [centreY]), glyph boxes and
  /// all.
  ///
  /// The glyphs are *translated* by however far the centre moved, not rotated
  /// about it. They are only ever read for the gaps between them inside one
  /// word, and a translation leaves those exactly as they were; rotating each
  /// glyph about the page's centre would change them by fractions of a pixel and
  /// pretend to a precision the boxes do not have.
  ///
  /// They used to be dropped here, and that is why the second, gateless split
  /// attempt could not exist: [deskew] rebuilds every word through this, so by
  /// the time rows were grouped there were no glyph boxes left to cut a merged
  /// chord run on. See [asChordRow].
  OcrWord movedTo(double centreX, double centreY) {
    final dx = centreX - this.centreX;
    final dy = centreY - this.centreY;
    return OcrWord(
      text: text,
      x0: x0 + dx,
      y0: y0 + dy,
      x1: x1 + dx,
      y1: y1 + dy,
      symbols: [
        for (final glyph in symbols)
          OcrWord(
            text: glyph.text,
            x0: glyph.x0 + dx,
            y0: glyph.y0 + dy,
            x1: glyph.x1 + dx,
            y1: glyph.y1 + dy,
          ),
      ],
    );
  }

  OcrWord saying(String replacement) => OcrWord(
      text: replacement, x0: x0, y0: y0, x1: x1, y1: y1);

  /// The same word [dx] pixels to the right, glyph boxes and all.
  ///
  /// For a box read out of a crop of the page: the recogniser reads each column
  /// as its own image, and everything downstream compares words with one
  /// another, so the crops have to be put back into one coordinate system. The
  /// glyphs move with it because [PhotoTextBridge.splitMergedChords] is the next
  /// thing to read them.
  OcrWord shiftedBy(double dx) => OcrWord(
        text: text,
        x0: x0 + dx,
        y0: y0,
        x1: x1 + dx,
        y1: y1,
        symbols: [for (final symbol in symbols) symbol.shiftedBy(dx)],
      );
}

/// A page turned back into chords-over-lyrics text.
class PhotoReading {
  final String chordPro;

  /// Things worth telling the person reviewing: a page holding two songs, a
  /// chord renamed on the way in, nothing legible at all.
  ///
  /// Codes rather than sentences. This is pure domain code with no
  /// `BuildContext`, so a sentence written here is English on a Hungarian
  /// screen - which is what these four were until they became codes. The prose
  /// lives in `AppLocalizations.importNoticeText` and nowhere else.
  final List<ImportNotice> notices;

  const PhotoReading({required this.chordPro, this.notices = const []});
}

/// Turns a bag of OCR words back into chords-over-lyrics text.
///
/// An OCR engine gives each word a bounding box in *pixels*;
/// `ChordPosition.position` is a *character column* into the lyric. This is the
/// arithmetic between the two, and it is the whole feature: get it wrong and
/// every chord sits over the wrong syllable.
///
/// It lives in Dart because the reading now happens in the browser — Tesseract
/// reads a real photograph in about two seconds where the server engine took
/// forty, and gets Hungarian accents right that the server engine did not. The
/// Python original in tools/photo_import_worker.py remains for the local
/// worker, and its test suite is the specification this was ported against.
///
/// Whether a token is a chord is asked of [ChordSheetParser] rather than
/// decided here. The app re-parses whatever this emits, so a second opinion
/// about what a chord is would be a bug waiting to happen — the Python port
/// has to keep the two in step by hand, and this does not.
class PhotoTextBridge {
  const PhotoTextBridge({this.parser = const ChordSheetParser()});

  final ChordSheetParser parser;

  /// Two words are on the same line when their centres are within this
  /// fraction of the PAGE's typical glyph height.
  ///
  /// Of the page's, not the row's: a region can arrive far taller than the text
  /// in it — show-through merged into a real line gave 132px for 60px letters —
  /// and sizing the gate from the row let such a box widen its own gate and
  /// swallow the chord row above it.
  ///
  /// **A centre is not a baseline**, and that is why the gate has to be this
  /// wide. A word's box is only as tall as the ink in it: `öröm` is all
  /// x-height, `Szívemben` carries a capital and an accent, `nyugalom` has
  /// descenders. On `098-szivemben-orom-dalol` the boxes run 22 to 59 px against
  /// a median of 34, so two words on one flat baseline differ by up to half that
  /// spread — about 0.5 of the median — before any tilt is added. At 0.6 the
  /// last line of that page split in two and reordered, its `Szívemben` landing
  /// 21.9 px from the row's running mean against a gate of 20.1: **short by 1.8
  /// pixels**.
  ///
  /// 0.75 is the middle of a measured plateau, not a fitted value. Swept over
  /// the corpus:
  ///
  /// | gate | mean | `098` | `125` |
  /// |---|---|---|---|
  /// | 0.60 | 0.947 | 0.940 | 0.849 |
  /// | 0.62 – 0.64 | 0.950 | 0.960 | 0.849 |
  /// | 0.66 – 0.80 | 0.950 | 0.960 | 0.846 |
  /// | 1.00 | 0.943 | 0.927 | 0.828 |
  /// | 1.40 | 0.721 | 0.858 | 0.746 |
  ///
  /// 0.62 to 0.64 is very slightly better and is a notch two steps wide, which
  /// is fitting to this corpus rather than reading it; 0.66 to 0.80 is flat and
  /// wide, and the middle of it costs `125-nincs-mas-isten` 0.007 of lyric
  /// character error — one or two characters — for 0.020 on `098`. Past 1.0 a
  /// word from the next line starts joining this one, which is the failure this
  /// gate exists to prevent, and 1.4 takes the whole corpus down by a quarter.
  ///
  /// **The Python arm keeps 0.6 and must.** EasyOCR returns regions that already
  /// span a whole line rather than words, so there is no typography spread to
  /// allow for and a wider gate simply merges adjacent lines: measured at 0.75
  /// it takes that arm from 0.633 to 0.490, with `151-zengjed-a-dalt` falling
  /// 0.993 to 0.272.
  static const _sameRow = 0.75;

  /// A verse break has to clear both bars: taller than one blank line, and well
  /// above the page's usual line spacing. The first alone turns a loosely set
  /// page into one verse per line; the second alone cannot tell two verses from
  /// two lines when there are only a couple of gaps to compare.
  static const _breakVersusHeight = 1.0;
  static const _breakVersusGap = 1.6;

  /// How much taller than the body the first line must be to be a title.
  static const _titleHeight = 1.25;

  /// A first row that opens with a hymn number is a heading at any size.
  ///
  /// Height alone was the only signal, and on a real photograph of song 149 it
  /// was not enough: that book prints its heading barely larger than its
  /// lyrics, so `149 Mondd, ki a dzsungel királya` came through as a line of
  /// the song. The number is the stronger signal anyway — every page of this
  /// songbook opens with one, and no lyric does.
  ///
  /// A separator is optional because the recogniser drops the printed full stop
  /// often enough to matter, but what follows the number must not itself be a
  /// digit: that is what keeps `10 000 angyal` a title rather than song 10.
  static final _numberedHeading = RegExp(r'^\s*\d{1,4}\s*[.):]?\s+\D');

  /// How far off square a handheld photo is worth correcting, and how finely to
  /// look. Beyond this the page is not a photograph of a song.
  static const _maxSkew = 12.0;
  static const _skewStep = 0.25;
  static const _skewFloor = 0.4;
  static const _minWordsForSkew = 6;

  /// How wide a gap between two glyphs has to be, as a multiple of the word's
  /// own median glyph width, before it is read as a space the engine swallowed.
  ///
  /// Letters inside a word sit almost touching; chords set a couple of spaces
  /// apart are a clear step wider. 0.6 sits between the two with room either
  /// side, and the all-or-nothing chord check behind it means an over-eager cut
  /// still cannot turn prose into chords.
  static const _symbolGap = 0.6;

  /// A gutter must be this many typical glyph widths across, and a column needs
  /// this many words and this many rows of its own to be a column rather than a
  /// speck.
  ///
  /// The row count is what keeps a single-column page from splitting. Past the
  /// end of its shortest line a band of whitespace does open, but only the one
  /// or two longest lines reach into it — so it holds fewer rows than a column
  /// would, and reads as the ragged right margin it is.
  static const _gutterWidth = 4.0;
  static const _minColumnWords = 3;
  static const _minColumnRows = 3;

  /// What share of the page's rows may cross a gutter and leave it a gutter.
  ///
  /// Not zero, which is what the old union-of-extents test demanded, and what
  /// cost both two-column pages in the measurement corpus their columns: a
  /// hymnal sets the song's heading *across* the columns, so one word of it lies
  /// over the gutter. `125-nincs-mas-isten` has 127 clear pixels between its
  /// columns and lost them to the word `Nincs`; `166-tekozlo-fiu` has 158 and
  /// lost them to `Tékozló`. Both pages then read as one column, which
  /// interleaves a line of the left column with an unrelated line of the right.
  ///
  /// A share of the rows rather than a constant, because that is the difference
  /// between a heading and a page: a heading is one row out of however many,
  /// while on a single-column page *every* row crosses every interior x.
  static const _gutterStraddle = 0.2;

  /// Reads [words] into chords-over-lyrics text.
  PhotoReading read(List<OcrWord> words) {
    if (words.isEmpty) {
      return const PhotoReading(chordPro: '', notices: [
        ImportNotice(ImportNoticeCode.photoNothingLegible),
      ]);
    }

    // The page's own printed lines dropped before anything measures anything,
    // because every rule below is a proportion taken over the words: a border
    // slice widens the gutter search, joins the heading row, and stands as a
    // lyric line of its own.
    final furnished = withoutFurniture(words);
    if (furnished.isEmpty) {
      return const PhotoReading(chordPro: '', notices: [
        ImportNotice(ImportNoticeCode.photoNothingLegible),
      ]);
    }

    // Merged chord runs pulled apart first, so everything below — grouping,
    // classification, layout — sees the chords the page prints rather than one
    // nonsense symbol standing for three.
    final split = splitMergedChords(furnished);

    // Straightened before anything else looks at it, because grouping is what
    // tilt breaks, and columns are found on x once the page is square.
    final straight = deskew(split, estimateSkew(split));
    final columns = splitColumns(straight);

    final lines = <String>[];
    final german = <String>{};
    var chordRows = 0;
    var raisedC = 0;

    for (var index = 0; index < columns.length; index++) {
      final block = _layOutColumn(columns[index], titled: index == 0);
      if (block.lines.isEmpty) continue;
      if (lines.isNotEmpty) lines.add('');
      lines.addAll(block.lines);
      german.addAll(block.german);
      chordRows += block.chordRows;
      raisedC += block.raisedC;
    }

    if (lines.isEmpty) {
      return const PhotoReading(chordPro: '', notices: [
        ImportNotice(ImportNoticeCode.photoNothingLegible),
      ]);
    }

    final notices = <ImportNotice>[];
    if (columns.length > 1 && !spansColumns(straight)) {
      // Honest rather than clever: a page holding two songs cannot become one
      // song, and the review box is where the unwanted half gets deleted.
      //
      // More than one column is not by itself more than one song, though, and
      // saying so was wrong on both two-column pages in the corpus: a heading
      // set across the columns means one song continuing from the foot of one
      // into the head of the next, which is what the columns were read in
      // order for. Two songs to a page each carry their own heading, inside
      // their own column.
      notices.add(
          ImportNotice(ImportNoticeCode.photoTwoSongs, count: columns.length));
    }
    if (chordRows == 0) {
      notices.add(const ImportNotice(ImportNoticeCode.photoNoChords));
    }
    if (german.isNotEmpty) {
      final names = german.toList()..sort();
      notices.add(ImportNotice(ImportNoticeCode.photoGermanNoteNames,
          text: names.join(', ')));
    }
    if (raisedC > 0) {
      // Said rather than decided in silence. No photograph can prove whether
      // the page meant C major or C minor, and the review box is where the
      // person holding the page settles it.
      notices.add(ImportNotice(ImportNoticeCode.photoLowercaseCRaised,
          count: raisedC));
    }
    return PhotoReading(chordPro: lines.join('\n'), notices: notices);
  }

  /// How far out of proportion with the page's own type a box has to be before
  /// it is a printed line rather than a word.
  ///
  /// Two numbers because neither dimension finds them alone, and both are the
  /// midpoint of a gap measured in a real browser over the whole corpus.
  ///
  /// [_furnitureNarrow] is a share of the page's typical glyph width. The
  /// vertical rules of `125-nincs-mas-isten` came back as 22 separate words —
  /// `!` `;` `,` `)` `]` `i` `I`, boxes 1 to 5 pixels wide against a page
  /// measuring 19 to the glyph, so 0.05 to 0.26 of it. The narrowest *real*
  /// thing on any reviewed page is the full stop of `098-szivemben-orom-dalol`
  /// at 0.39, and the dotted leader of `185-jezus-krisztusom` at 0.45. 0.32
  /// sits between 0.26 and 0.39 with the same 1.2 either side. It also keeps
  /// the 9-pixel Hungarian article `a` of `109-tart-meg-a-kegyelem`, at 0.35
  /// the narrowest real glyph anywhere in the corpus — by eight percent, which
  /// is as much room as the evidence has.
  ///
  /// [_furnitureFlat] is a multiple of the box's *own* height, because a
  /// horizontal rule is not narrow at all. `151-zengjed-a-dalt` returned its
  /// letterbox edge twice as `A`, 944 by 25; the screenshot
  /// `app-jezus-szivedbe-lat` returned the phone's status bar as `s`, 922 by
  /// 13; `125-nincs-mas-isten` returned the top of its printed box as `TT`,
  /// 575 by 30. Per glyph those are 37.8, 70.9 and 9.6 times their own height.
  /// No letter is: the widest real glyphs measured are the em dash the engine
  /// returns for the page's `->` at 3.9, the marker-drawn `2` of
  /// `105-kosz-jol-vagyok` at 1.2, and the merged chord pair `DG` of
  /// `185-jezus-krisztusom` at 1.9. 5 clears the em dash by 1.3 and the nearest
  /// rule by 1.9.
  ///
  /// Confidence was the other candidate, and it was measured and rejected. It
  /// is what the Python arm filters on, and on these boxes it does not
  /// separate: on `125-nincs-mas-isten` the border slices came back at 82, 78,
  /// 74 and 72 while the real words sat at 87 to 96, so no gate catches the
  /// rules without taking real text off the harder pages with it. Tesseract is
  /// confident about line art.
  static const _furnitureNarrow = 0.32;
  static const _furnitureFlat = 5.0;

  /// Below this there is no distribution to compare a box against, and a median
  /// taken over a handful of words is an opinion rather than a measurement.
  static const _minWordsForFurniture = 6;

  /// [words] with the page's printed lines and specks of dirt removed.
  ///
  /// A photographed songbook page is not only type. It carries a box around the
  /// text, a rule between its columns, the edge where a letterboxed photograph
  /// stops, and — when the photograph is a screenshot — the status bar of the
  /// phone. An OCR engine is asked for words and returns words, so every one of
  /// those arrives as one: the engine's own line finding slices a tilted border
  /// into a column of `!` and `;`, and a horizontal rule comes back as `A` or
  /// `s` or `TT`.
  ///
  /// They cost out of all proportion to their size. On `125-nincs-mas-isten` 22
  /// border slices were most of a lyric character error rate of 0.559, where
  /// every other reviewed page is under 0.21: each one either stood as a lyric
  /// line of its own — 48 lines against 33 expected — or attached itself to a
  /// real row, and a stray token on a chord row is stored as a chord in the
  /// column the border happened to be printed in.
  ///
  /// The test is shape, not confidence, and the numbers are on
  /// [_furnitureNarrow] and [_furnitureFlat]. It is measured against the page
  /// rather than in pixels because the same page photographed closer is the
  /// same page: `151-zengjed-a-dalt` measures 12 to the glyph and
  /// `185-jezus-krisztusom` 39, and an absolute gate would be wrong on both.
  ///
  /// A page too small to measure is returned untouched. So is a page that is
  /// *all* rules — nothing there is out of proportion with anything, which is
  /// the right answer: this may only act on evidence the page itself provides.
  List<OcrWord> withoutFurniture(List<OcrWord> words) {
    if (words.length < _minWordsForFurniture) return words;
    final measurable = [
      for (final word in words)
        if (word.text.isNotEmpty && word.width > 0 && word.height > 0) word,
    ];
    if (measurable.length < _minWordsForFurniture) return words;
    final typical = _median(measurable.map((w) => w.width / w.text.length));
    if (typical <= 0) return words;
    return [
      for (final word in words)
        if (!_isFurniture(word, typical)) word,
    ];
  }

  /// Whether [word] is shaped like a printed line rather than a letter, on a
  /// page whose glyphs measure [typical] pixels across.
  ///
  /// A box with no size to it is kept: there is nothing to compare it against.
  bool _isFurniture(OcrWord word, double typical) {
    if (word.text.isEmpty || word.width <= 0 || word.height <= 0) return false;
    final glyph = word.width / word.text.length;
    return glyph < _furnitureNarrow * typical ||
        glyph > _furnitureFlat * word.height;
  }

  /// A chord that is nothing but a lowercase `c`.
  ///
  /// `C` and `c` are the same shape at two sizes, and no other note letter is:
  /// `a`, `b`, `d`, `e`, `f`, `g` and `h` all change form between cases, so an
  /// engine that returns one of those in lowercase read a lowercase letter and
  /// is believed. `c` it cannot be believed about, and a songbook that writes
  /// its minors as `em`, `am`, `gm`, `dm`, `hm` and `fiszm` — every
  /// lowercase chord in the measurement corpus and in the whole shipped
  /// catalogue does, eleven of them, and not one is a bare root — does not
  /// print a bare `c` for C minor.
  ///
  /// Measured: `084-van-egy-ut` prints italic capital `C` twelve times and the
  /// engine returned `c` for six of them, which is the whole of that page's
  /// 0.583 chord recall. `125-nincs-mas-isten` does it three times. Every one
  /// reached storage as `Cm`, because `c` is a perfectly good chord token and
  /// nothing had cause to look twice — silently wrong music, which is
  /// worse than music that is missing.
  ///
  /// Only on a chord row, and only from a photograph. A `c` typed or pasted by
  /// hand is deliberate and keeps the Central European reading that
  /// [ChordTransposer] documents; this is a repair of a known OCR confusion,
  /// the same kind of thing as [_repairOcr] and applied at the same stage.
  static final _lowercaseC = RegExp(r'^c$');

  /// The angle, in degrees, by which the page appears to be tilted.
  ///
  /// Found by projection profile: for each candidate angle the word centres are
  /// projected across the text and binned, and the angle scoring highest on the
  /// sum of squared bin counts wins. At the true angle a line falls in one bin;
  /// at any other it smears across neighbours.
  ///
  /// An OCR engine cannot be asked for this directly — it returns axis-aligned
  /// rectangles however the text is rotated — so the tilt survives only in
  /// where the boxes sit relative to one another.
  double estimateSkew(List<OcrWord> words) {
    if (words.length < _minWordsForSkew) return 0.0;
    final span = math.max(1.0, _median(words.map((w) => w.height)) / 2);

    var bestAngle = 0.0;
    var bestScore = -1.0;
    final steps = (_maxSkew / _skewStep).round();
    for (var tick = -steps; tick <= steps; tick++) {
      final angle = tick * _skewStep;
      final radians = angle * math.pi / 180;
      final sin = math.sin(radians), cos = math.cos(radians);
      // Two grids half a bin apart: with one, a line landing on a boundary
      // splits in two and scores as though it were smeared.
      final low = <int, int>{}, high = <int, int>{};
      for (final word in words) {
        final across = word.centreY * cos - word.centreX * sin;
        low.update((across / span).floor(), (n) => n + 1, ifAbsent: () => 1);
        high.update(((across + span / 2) / span).floor(), (n) => n + 1,
            ifAbsent: () => 1);
      }
      var score = 0.0;
      for (final n in low.values) {
        score += n * n;
      }
      for (final n in high.values) {
        score += n * n;
      }
      if (score > bestScore) {
        bestScore = score;
        bestAngle = angle;
      }
    }
    return bestAngle;
  }

  /// [words] rotated back onto the horizontal by [angle] degrees.
  ///
  /// Only the centres move; each box keeps its size. The text was read
  /// correctly even on a badly tilted page — it is the grouping that fails — so
  /// this exists to make rows clusterable, not to re-read anything.
  List<OcrWord> deskew(List<OcrWord> words, double angle) {
    if (angle.abs() < _skewFloor) return words;
    final radians = angle * math.pi / 180;
    final sin = math.sin(radians), cos = math.cos(radians);
    return [
      for (final word in words)
        word.movedTo(word.centreX * cos + word.centreY * sin,
            word.centreY * cos - word.centreX * sin),
    ];
  }

  /// The gutters between the page's columns, left to right.
  ///
  /// A hymnal sets two songs side by side, and rows are clustered by y — so
  /// without this a line in the left column and an unrelated line at the same
  /// height in the right one become one row, and the two songs interleave.
  ///
  /// A gutter is a vertical band that at most [_gutterStraddle] of the page's
  /// rows cross. It is found by sweeping the word spans and counting, for each
  /// interval between two word edges, how many words *cover* it: inside the text
  /// of a single-column page that count is roughly the number of rows, and in a
  /// real gutter it is the page's heading and nothing else.
  List<({double from, double to, double cut})> columnGutters(
      List<OcrWord> rawWords) {
    // Cleaned here as well as in [read], because the recogniser asks this
    // question of the whole-page read before any of that — and a rule between
    // the columns is ink standing exactly where the gutter is looked for.
    final words = withoutFurniture(rawWords);
    if (words.length < 2 * _minColumnWords) return const [];
    final measurable =
        words.where((w) => w.text.isNotEmpty && w.width > 0).toList();
    if (measurable.isEmpty) return const [];
    final gutter =
        _gutterWidth * _median(measurable.map((w) => w.width / w.text.length));

    final rows = groupRows(words);
    final allowed = math.max(1, (rows.length * _gutterStraddle).floor());

    // The crossing count only changes at a word edge, so the intervals between
    // consecutive edges are where it is worth measuring. A sweep does it in one
    // pass: `opened - closed` is how many words cover the interval.
    final starts = words.map((w) => w.x0).toList()..sort();
    final ends = words.map((w) => w.x1).toList()..sort();
    final edges = <double>{...starts, ...ends}.toList()..sort();

    final spans = <(double, double, int)>[];
    var opened = 0, closed = 0;
    for (var i = 0; i < edges.length - 1; i++) {
      while (opened < starts.length && starts[opened] <= edges[i]) {
        opened++;
      }
      while (closed < ends.length && ends[closed] <= edges[i]) {
        closed++;
      }
      spans.add((edges[i], edges[i + 1], opened - closed));
    }

    // Maximal runs of intervals nothing much crosses. A run left open at the
    // last edge is deliberately dropped: that is the right-hand margin.
    final bands = <List<(double, double, int)>>[];
    List<(double, double, int)>? band;
    for (final span in spans) {
      if (span.$3 <= allowed) {
        (band ??= []).add(span);
      } else if (band != null) {
        bands.add(band);
        band = null;
      }
    }

    final gutters = <({double from, double to, double cut})>[];
    var from = double.negativeInfinity;
    for (final found in bands) {
      final start = found.first.$1, end = found.last.$2;
      if (end - start < gutter) continue;
      final cut = _quietestPoint(found);
      if (!_bandHolds(words, from, cut)) continue;
      gutters.add((from: start, to: end, cut: cut));
      from = cut;
    }
    // The last column has to hold up too, or the final cut only shaved a margin
    // off the page.
    if (gutters.isNotEmpty &&
        !_bandHolds(words, gutters.last.cut, double.infinity)) {
      gutters.removeLast();
    }
    return gutters;
  }

  /// Where the page should be cut into columns, left to right.
  ///
  /// Public because the recogniser crops on these. Reading each column as its
  /// own image is not the same as splitting the words of one whole-page read —
  /// Tesseract does its own layout analysis, and given a two-column page it
  /// joins a line from one column to a line from the other before this ever
  /// sees a box.
  List<double> columnCuts(List<OcrWord> words) =>
      [for (final gutter in columnGutters(words)) gutter.cut];

  /// Where to cut inside a gutter: the middle of its emptiest stretch.
  ///
  /// Not the middle of the gutter, which is what the first version did and what
  /// cut `125-nincs-mas-isten` straight through its intro chord row. That page's
  /// gutter is a 127-pixel band, tolerated because one word of the heading lies
  /// across its left half; the middle of the band is inside a chord row that
  /// reaches into it, and the cut then split `Cadd9-Csus2` between two crops,
  /// which read the halves twice and read neither of them right.
  ///
  /// So the emptiest stretch wins, and the widest of those when several tie.
  double _quietestPoint(List<(double, double, int)> band) {
    final quietest = band.map((span) => span.$3).reduce(math.min);
    double? bestFrom, bestTo;
    double? runFrom, runTo;
    for (final (start, end, crossing) in band) {
      if (crossing == quietest) {
        runFrom ??= start;
        runTo = end;
      } else {
        runFrom = runTo = null;
      }
      if (runFrom != null &&
          (bestFrom == null || runTo! - runFrom > bestTo! - bestFrom)) {
        bestFrom = runFrom;
        bestTo = runTo;
      }
    }
    return (bestFrom! + bestTo!) / 2;
  }

  /// Whether the band between [from] and [to] is a column rather than a margin.
  ///
  /// Rows counted *inside the band*, not rows of the page: the page's rows are
  /// clustered by y across the whole width, so on a two-column page every one of
  /// them holds words from both columns and none is ever wholly inside either.
  ///
  /// This is the test that keeps a single-column page whole. Past the end of its
  /// shortest line the crossing count falls away and a band does open — but only
  /// the one or two longest lines reach into it, so it holds fewer rows than a
  /// column has, and it reads as the ragged right margin it is.
  bool _bandHolds(List<OcrWord> words, double from, double to) {
    final inside = [
      for (final word in words)
        if (word.x0 >= from && word.x1 <= to) word,
    ];
    if (inside.length < _minColumnWords) return false;
    return groupRows(inside).length >= _minColumnRows;
  }

  /// The page's heading, when it is set across the columns rather than inside
  /// one.
  ///
  /// A hymnal sets a song's heading over both columns, which is the very thing
  /// that closes the gutter for a rule looking for a band no word crosses. It
  /// also has to survive the split: filed word by word into whichever column
  /// each one happens to fall in, `166. Tékozló fiú` becomes `166.` at the head
  /// of the first column and `Tékozló fiú` at the head of the second, and the
  /// recogniser reads both halves a second time when it crops - measured, that
  /// came back as `{title: 166. 166. . Tékozló}` with a stray `fiú`.
  ///
  /// The first row only, and only when it reads as a numbered heading. A wider
  /// rule was tried and reversed: any row *intruding into the gutter band* also
  /// catches the printed rule between the columns of `125-nincs-mas-isten`,
  /// which the engine returns as a column of one-character words sitting right
  /// where the cut falls - so most of the page became one spanning row and the
  /// two columns interleaved again, which is the failure this whole thing is
  /// here to fix.
  List<OcrWord> headingRow(List<OcrWord> rawWords) {
    // The heading is the one row the recogniser keeps from the whole-page read,
    // so a rule that joins it is a rule in the title. `125-nincs-mas-isten`
    // prints the top of its box across the head of the second column, and the
    // engine returned it as `TT`.
    final words = withoutFurniture(rawWords);
    final cuts = columnCuts(words);
    if (cuts.isEmpty) return const [];
    final rows = groupRows(words);
    if (rows.isEmpty) return const [];
    final first = rows.first;
    if (!_numberedHeading.hasMatch(first.map((w) => w.text).join(' '))) {
      return const [];
    }
    final left = first.map((w) => w.x0).reduce(math.min);
    final right = first.map((w) => w.x1).reduce(math.max);
    return cuts.any((cut) => left < cut && cut < right) ? first : const [];
  }

  List<List<OcrWord>> splitColumns(List<OcrWord> words) {
    final gutters = columnGutters(words);
    if (gutters.isEmpty) return [words];

    final heading = headingRow(words).toSet();
    final bounds = [
      double.negativeInfinity,
      for (final gutter in gutters) gutter.cut,
      double.infinity,
    ];
    final columns = [for (var i = 0; i < bounds.length - 1; i++) <OcrWord>[]];
    for (final word in words) {
      if (heading.contains(word)) {
        columns.first.add(word);
        continue;
      }
      var placed = false;
      for (var i = 0; i < bounds.length - 1; i++) {
        if (word.x0 >= bounds[i] && word.x1 <= bounds[i + 1]) {
          columns[i].add(word);
          placed = true;
          break;
        }
      }
      if (!placed) columns.first.add(word);
    }
    final kept = columns.where((column) => column.isNotEmpty).toList();
    return kept.isEmpty ? [words] : kept;
  }

  /// Whether [words] hold a heading set across the columns.
  ///
  /// The signal that a two-column page is one song rather than two. A hymnal
  /// printed two songs to a page gives each one its own heading, inside its own
  /// column; a song set in two columns has one heading above both — which is
  /// the very thing that used to close the gutter.
  bool spansColumns(List<OcrWord> words) => headingRow(words).isNotEmpty;

  /// [words] clustered into lines, top to bottom, each sorted left to right.
  List<List<OcrWord>> groupRows(List<OcrWord> words) {
    if (words.isEmpty) return [];
    final gate = _sameRow * _median(words.map((w) => w.height));

    final ordered = [...words]..sort((a, b) => a.centreY.compareTo(b.centreY));
    final rows = <List<OcrWord>>[];
    for (final word in ordered) {
      if (rows.isNotEmpty) {
        final current = rows.last;
        // A running mean, so a slowly drifting baseline — a curled or tilted
        // page — is followed rather than split.
        final meanCentre =
            current.map((w) => w.centreY).reduce((a, b) => a + b) /
                current.length;
        if ((word.centreY - meanCentre).abs() <= gate) {
          current.add(word);
          continue;
        }
      }
      rows.add([word]);
    }
    for (final row in rows) {
      row.sort((a, b) => a.x0.compareTo(b.x0));
    }
    return rows;
  }

  _Block _layOutColumn(List<OcrWord> words, {required bool titled}) {
    // Noise dropped before anything reads the rows, so verse spacing is
    // measured between real lines rather than across a stray time signature.
    final rows = groupRows(words)
        .where((row) => !_isNoiseRow(row))
        // Merged chord runs the first pass could not open, cut here, once,
        // before anything measures the rows: verse breaks are found on y and
        // are unaffected, but every later question - is this chords, does the
        // row below pair with it, where does each chord sit - has to be asked
        // of the same boxes. See [asChordRow].
        .map(asChordRow)
        .toList();
    if (rows.isEmpty) return const _Block([], {}, 0, 0);

    final lines = <String>[];
    // Either signal will do: set larger than the body, or opening with a hymn
    // number. Height alone let a heading printed at body size become a lyric,
    // and a page that merely opens with a long line still stays a lyric because
    // neither test passes for it.
    final firstRow = rows.first.map((w) => w.text).join(' ');
    if (titled &&
        rows.length > 1 &&
        !parser.isChordLine(firstRow) &&
        (_numberedHeading.hasMatch(firstRow) ||
            _rowHeight(rows.first) >=
                _titleHeight * _median(rows.skip(1).map(_rowHeight)))) {
      lines.add('{title: $firstRow}');
      lines.add('');
      rows.removeAt(0);
    }

    // The heading of the NEXT song, caught by the bottom of the frame.
    //
    // A hymnal prints one song after another down the page, so a photograph
    // framed on song 98 catches the head of song 99 at its foot.
    // `098-szivemben-orom-dalol` returns `99. Tobb erot  a-t.` as its last row,
    // clipped by the edge of the image, and it was becoming a lyric line of
    // song 98 - the page the corpus named `chords-next-song-header` and then
    // waited two sessions for someone to read.
    //
    // The signal is the same one the title at the top is found by: every page
    // of this songbook opens with a number and no lyric does. What makes it the
    // *next* song rather than this one is that it stands last - a song's own
    // heading is never the final thing on the page.
    //
    // Height was the other candidate and it does not separate. `99. Tobb erot`
    // is 43-45 px against a body of 34, which is 1.3; `1. Versszak` on
    // `125-nincs-mas-isten` is 35 against 29, which is 1.2. [_titleHeight] is
    // 1.25 and sits between them, which is luck rather than a rule. Being last
    // is not luck: `1. Versszak` has twenty rows under it.
    //
    // Dropped rather than kept and warned about.
    // [ImportNoticeCode.photoTwoSongs] says the page holds songs *side by side*
    // and that all of them were read, which would be untrue here: what is on
    // the page is one song and the top edge of the next, with no verse of it to
    // import. Gold agrees - `098`'s answer is ten lyric lines and no extra
    // warning.
    if (rows.length > 1) {
      final lastRow = rows.last.map((w) => w.text).join(' ');
      if (!parser.isChordLine(lastRow) &&
          _numberedHeading.hasMatch(lastRow)) {
        rows.removeLast();
      }
    }

    final breaks = _verseBreaks(rows);
    final german = <String>{};
    var chordRows = 0;
    var raisedC = 0;

    var index = 0;
    while (index < rows.length) {
      if (breaks[index] && lines.isNotEmpty && lines.last.isNotEmpty) {
        lines.add('');
      }
      final row = rows[index];
      if (!parser.isChordLine(row.map((w) => w.text).join(' '))) {
        lines.add(_layOut(_repairOcr(row)).line);
        index++;
        continue;
      }

      chordRows++;
      // Before anything reads the row's symbols, so the German check, the
      // layout and the stored chord all see the same token.
      final cased = _raiseLowercaseC(row);
      final chordRow = cased.row;
      raisedC += cased.raised;
      // Case-insensitive, because a Hungarian songbook prints its minors in
      // lowercase throughout: `hm` is B minor and is renamed on the way into
      // storage exactly as `Hm` is. Matching only the capital meant a page
      // spelling its minors the Hungarian way had its chords renamed without a
      // word to the person reviewing it - measured on `166-tekozlo-fiu`, which
      // prints `hm` and raised nothing.
      german.addAll(chordRow.map((w) => w.text).where((t) =>
          (t.startsWith('H') || t.startsWith('h')) &&
          parser.isChordToken(t)));

      final below = index + 1 < rows.length ? rows[index + 1] : null;
      final pairs = below != null &&
          !breaks[index + 1] &&
          !parser.isChordLine(below.map((w) => w.text).join(' '));
      if (!pairs) {
        // An intro or turnaround with nothing underneath. Kept: the app stores
        // chords with positions past the end of an empty lyric.
        lines.add(_layOut(chordRow).line);
        index++;
        continue;
      }

      final lyrics = _layOut(_repairOcr(below));
      lines.add(_layOutChords(chordRow, lyrics.anchors, _charWidth(below)));
      lines.add(lyrics.line);
      index += 2;
    }
    return _Block(lines, german, chordRows, raisedC);
  }

  /// Render [row] as text, recording where each word landed.
  ///
  /// Columns are chained off the previous word rather than computed from x, so
  /// the words stay readable however the boxes drift. The anchors — pixel x
  /// against character column, at both edges of every word — are what a chord
  /// row above is interpolated onto, so a chord follows the text wherever the
  /// text actually landed.
  _Laid _layOut(List<OcrWord> row) {
    final charWidth = _charWidth(row);
    final anchors = <(double, int)>[];
    var line = '';
    OcrWord? previous;
    for (final word in row) {
      final int column = previous == null
          ? 0
          : line.length +
              math.max<int>(1, ((word.x0 - previous.x1) / charWidth).round());
      line = line.padRight(column) + word.text;
      anchors.add((word.x0, column));
      anchors.add((word.x1, column + word.text.length));
      previous = word;
    }
    return _Laid(line, anchors);
  }

  /// Render chord [row] against the columns of the lyric row beneath it.
  String _layOutChords(
      List<OcrWord> row, List<(double, int)> anchors, double charWidth) {
    var line = '';
    for (final word in row) {
      var column = _columnFor(word.x0, anchors, charWidth);
      // Two chords over one syllable would otherwise fuse into a nonsense
      // symbol — `G` and `C` becoming `GC`, which the app then stores.
      if (line.isNotEmpty) column = math.max(column, line.length + 1);
      line = line.padRight(column) + word.text;
    }
    return line;
  }

  /// [words] with any merged run of chord symbols pulled back apart.
  ///
  /// Tesseract joins glyphs into a word on horizontal spacing, so `D G  D` set
  /// with narrow gaps arrives as `DGD`, and `G - C - D - ( C )` as
  /// `G-C-D-(C)`. Neither is a chord symbol, so the all-or-nothing rule in
  /// [ChordSheetParser.isChordLine] read the whole row as lyrics and the chords
  /// were stored as words. On the measurement corpus that one merge took
  /// `185-jezus-krisztusom` to zero chords found.
  ///
  /// Two guards keep this from cutting up lyrics, and both must hold:
  ///
  /// * the split has to fall on a **real gap** — [_symbolGap] times the word's
  ///   own median glyph width — so ordinary letter spacing is never a cut; and
  /// * **every** resulting piece has to be a chord or chord punctuation. That is
  ///   what protects prose: `szívemben` cuts into pieces like `sz` and `ívem`,
  ///   which are not chords, so the word is left whole. `Am` is safe for the
  ///   same reason — `m` alone names no pitch.
  ///
  /// A word the engine reported no symbols for is returned untouched, so an
  /// engine that does not report them loses nothing.
  List<OcrWord> splitMergedChords(List<OcrWord> words) {
    final out = <OcrWord>[];
    for (final word in words) {
      out.addAll(_splitOne(word));
    }
    return out;
  }

  List<OcrWord> _splitOne(OcrWord word) {
    final symbols = word.symbols;
    // Nothing to go on, or nothing worth splitting: one glyph cannot be a
    // merge, and a word already readable as a chord must not be touched —
    // `Em7`'s glyphs are as tightly spaced as `DGD`'s.
    if (symbols.length < 2 || parser.isSingleChord(word.text)) return [word];

    final widths = symbols.map((s) => s.width).where((w) => w > 0).toList();
    if (widths.isEmpty) return [word];
    final gate = _symbolGap * _median(widths);

    final runs = <List<OcrWord>>[[symbols.first]];
    for (var i = 1; i < symbols.length; i++) {
      final gap = symbols[i].x0 - symbols[i - 1].x1;
      if (gap >= gate) {
        runs.add([symbols[i]]);
      } else {
        runs.last.add(symbols[i]);
      }
    }
    if (runs.length < 2) return [word];

    final pieces = <OcrWord>[];
    for (final run in runs) {
      // All or nothing, and the run is asked rather than told: a piece that does
      // not read as a chord is cut once more at its own widest gap. See
      // [_chordPieces].
      final split = _chordPieces(word, run);
      if (split == null) return [word];
      pieces.addAll(split);
    }
    if (pieces.length < 2) return [word];
    return pieces;
  }

  /// [glyphs] as pieces that are every one a chord, or null when no cut of them
  /// is.
  ///
  /// The gate above decides which words are *candidates*; this decides where
  /// inside one the chords actually are. Separating the two is what recovers
  /// `185-jezus-krisztusom`'s `DGD`: 52-pixel glyphs with gaps of 46 and 30
  /// against a gate of 31.2, so the first gap cut and the second missed **by 1.2
  /// pixels**. That left `D` and `GD`, `GD` is not a chord symbol, and the
  /// whole split was thrown away — the row read as a lyric line, which was both
  /// that page's extra line and most of its 0.600 chord recall.
  ///
  /// The gate could not simply be lowered. Measured over every multi-glyph word
  /// on all nine pages of the corpus: the Hungarian `ha` of
  /// `151-zengjed-a-dalt` carries a gap of 0.38 of its glyph width, `De` on
  /// `084-van-egy-ut` 0.15, `be` and `de` less than nothing — and
  /// `125-nincs-mas-isten`'s `CGD` needs 0.42 cut. Any gate between 0.38 and
  /// 0.42 would be luck, and every one of those words partitions into bare note
  /// letters, so the chord check alone would not save them. `De` becoming
  /// `D e` in the middle of a lyric is a worse bug than a lost chord row.
  ///
  /// So the gate stays at [_symbolGap] and keeps prose from ever being a
  /// candidate, and this runs only inside a word the gate already opened. It
  /// recovers `DGD` and changes nothing else in the corpus: `bőrömbe` cuts to
  /// `bő` and `römbe`, `bő` cuts again to a perfectly good `b` and an `ő` that
  /// is not a chord, and the split is abandoned exactly as before.
  ///
  /// `125-nincs-mas-isten`'s `CGD`, `CDG` and `109`'s `GA` are still lost. Their
  /// gaps never open the gate at all, and telling them from `ha` needs to know
  /// the row is chords — which this cannot ask, because it has to run before
  /// [deskew], and [OcrWord.movedTo] does not carry glyph boxes.
  List<OcrWord>? _chordPieces(OcrWord word, List<OcrWord> glyphs) {
    final text = glyphs.map((g) => g.text).join().trim();
    if (text.isEmpty) return const [];
    if (parser.isChordToken(text) ||
        parser.isContinuation(text) ||
        _isChordPunctuation(text)) {
      return [
        OcrWord(
          text: text,
          x0: glyphs.first.x0,
          y0: word.y0,
          x1: glyphs.last.x1,
          y1: word.y1,
        ),
      ];
    }
    // One glyph that is not a chord is the end of it, which is also what bounds
    // the recursion: every call is strictly shorter than the one above it.
    if (glyphs.length < 2) return null;

    var at = 1;
    var widest = glyphs[1].x0 - glyphs[0].x1;
    for (var i = 2; i < glyphs.length; i++) {
      final gap = glyphs[i].x0 - glyphs[i - 1].x1;
      if (gap > widest) {
        widest = gap;
        at = i;
      }
    }
    final left = _chordPieces(word, glyphs.sublist(0, at));
    if (left == null) return null;
    final right = _chordPieces(word, glyphs.sublist(at));
    if (right == null) return null;
    return [...left, ...right];
  }

  /// [row] cut into per-chord boxes when that is what it turns out to be.
  ///
  /// A second attempt, made with **no gate at all**, and kept only when it
  /// changes the verdict: a row that did not read as chords and now does. The
  /// gate in [splitMergedChords] is a proportion of a word's own glyphs and it
  /// cannot be lowered far enough to help here. Measured over the corpus,
  /// `125-nincs-mas-isten`'s `CGD` has gaps of 13 and 11 px on 26 px glyphs
  /// — 0.42 and 0.50 — and Hungarian `ha` on `151-zengjed-a-dalt` carries 0.38.
  /// A threshold in a factor of 1.1 would be luck, and both words cut into bare
  /// note letters, so the all-chords check would not tell them apart either.
  ///
  /// What tells them apart is the row. `ha` and `de` and `be` do cut into
  /// chords; the lines they stand in have words in them, so the verdict does not
  /// flip and the cut is thrown away. Calibrated against every line of every
  /// gold file and of every song the app ships — 284 of them — this reclassifies
  /// **none**.
  ///
  /// Only when splitting changes the verdict, for the same reason the Python
  /// arm's `as_chord_row` says so: a lyric row split into pieces would reach
  /// [_layOut] as many boxes rather than one, and its spacing is measured from
  /// the boxes. Leaving lyrics alone is not tidiness, it is required.
  List<OcrWord> asChordRow(List<OcrWord> row) {
    if (row.isEmpty) return row;
    if (parser.isChordLine(row.map((w) => w.text).join(' '))) return row;

    final split = <OcrWord>[];
    var changed = false;
    for (final word in row) {
      if (word.symbols.length < 2 || parser.isSingleChord(word.text)) {
        split.add(word);
        continue;
      }
      final pieces = _chordPieces(word, word.symbols);
      if (pieces == null || pieces.length < 2) {
        split.add(word);
        continue;
      }
      split.addAll(pieces);
      changed = true;
    }
    if (!changed) return row;
    return parser.isChordLine(split.map((w) => w.text).join(' '))
        ? split
        : row;
  }

  /// Brackets and dashes a chord row carries, as their own pieces.
  ///
  /// [ChordSheetParser] tolerates these inside a row; here they have to be
  /// recognised one piece at a time, because a split can land either side of
  /// one.
  bool _isChordPunctuation(String text) =>
      RegExp(r'''^[-–—|:()\[\]'‘’"]+$''').hasMatch(text);

  /// The character column at pixel [x], interpolated between [anchors].
  int _columnFor(double x, List<(double, int)> anchors, double charWidth) {
    if (anchors.isEmpty) return math.max(0, (x / charWidth).round());
    if (x <= anchors.first.$1) {
      return math.max(
          0, anchors.first.$2 - ((anchors.first.$1 - x) / charWidth).round());
    }
    if (x >= anchors.last.$1) {
      return anchors.last.$2 + ((x - anchors.last.$1) / charWidth).round();
    }
    for (var i = 0; i < anchors.length - 1; i++) {
      final (xa, ca) = anchors[i];
      final (xb, cb) = anchors[i + 1];
      if (x >= xa && x <= xb) {
        if (xb == xa) return ca;
        return (ca + (x - xa) * (cb - ca) / (xb - xa)).round();
      }
    }
    return anchors.last.$2;
  }

  /// [row] with a lowercase `c` raised to `C`. See [_lowercaseC] for why.
  ///
  /// Returns the row unchanged, and an empty count, when there is nothing to
  /// raise — which is every row of every other page in the corpus.
  ({List<OcrWord> row, int raised}) _raiseLowercaseC(List<OcrWord> row) {
    var raised = 0;
    final out = <OcrWord>[];
    for (final word in row) {
      if (_lowercaseC.hasMatch(word.text)) {
        raised++;
        out.add(word.saying('C'));
      } else {
        out.add(word);
      }
    }
    return (row: raised == 0 ? row : out, raised: raised);
  }

  /// `1`/`i` and `6`/`ő` confusions undone, and the space an engine puts before
  /// its own punctuation closed.
  ///
  /// Applied to lyric rows only — a chord row has neither problem, and `x1` is
  /// a repeat marker rather than a misread `xi`. Runs before layout, so a
  /// length change here is free.
  List<OcrWord> _repairOcr(List<OcrWord> row) {
    final repaired = <OcrWord>[];
    for (var index = 0; index < row.length; index++) {
      var text = row[index]
          .text
          .replaceAllMapped(_oneInWord, (m) => m[0]!.replaceAll('1', 'i'))
          .replaceAllMapped(_sixInWord, (m) => m[0]!.replaceAll('6', 'ő'))
          .replaceAllMapped(_spaceBeforePunctuation, (m) => m[1]!);
      // A lone `1` between words is the same confusion with the spaces left in.
      // At the start of a row it is a verse number, so it stays.
      if (text == '1' &&
          index > 0 &&
          _letter.hasMatch(row[index - 1].text.lastCharacter)) {
        text = 'i';
      }
      repaired.add(row[index].saying(text));
    }
    return repaired;
  }

  /// A row holding no letter at all — stave furniture such as a time signature
  /// read as `4=`. Not a lyric, and a chord always carries its root letter.
  bool _isNoiseRow(List<OcrWord> row) =>
      !row.any((w) => _letter.hasMatch(w.text));

  /// Which of [rows] a blank line should precede.
  List<bool> _verseBreaks(List<List<OcrWord>> rows) {
    final breaks = List<bool>.filled(rows.length, false);
    if (rows.length < 3) return breaks;
    final gaps = <double>[];
    for (var i = 1; i < rows.length; i++) {
      final top = rows[i].map((w) => w.y0).reduce(math.min);
      final bottom = rows[i - 1].map((w) => w.y1).reduce(math.max);
      gaps.add(top - bottom);
    }
    final typicalGap = _median(gaps);
    final typicalHeight = _median(rows.map(_rowHeight));
    for (var i = 0; i < gaps.length; i++) {
      breaks[i + 1] = gaps[i] > _breakVersusHeight * typicalHeight &&
          gaps[i] > _breakVersusGap * typicalGap;
    }
    return breaks;
  }

  double _rowHeight(List<OcrWord> row) => _median(row.map((w) => w.height));

  double _charWidth(List<OcrWord> row) {
    final widths = row
        .where((w) => w.text.isNotEmpty)
        .map((w) => w.width / w.text.length);
    return widths.isEmpty ? 1.0 : _median(widths);
  }

  static double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 1.0;
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _oneInWord =
      RegExp(r'(?<=\p{L})1|1(?=\p{L})', unicode: true);
  static final _sixInWord =
      RegExp(r'(?<=\p{L})6|6(?=\p{L})', unicode: true);

  /// A space an engine inserted before its own punctuation — measured: a region
  /// came back as `vagy ,`. A dash is deliberately absent: ` - ` separates
  /// syllables all over a hymnal page and is not stray spacing.
  static final _spaceBeforePunctuation = RegExp(r'\s+([,.;:!?])');
}

class _Laid {
  final String line;
  final List<(double, int)> anchors;
  const _Laid(this.line, this.anchors);
}

class _Block {
  final List<String> lines;
  final Set<String> german;
  final int chordRows;

  /// How many lowercase `c` chords were raised to `C`. See
  /// `PhotoTextBridge._lowercaseC`.
  final int raisedC;
  const _Block(this.lines, this.german, this.chordRows, this.raisedC);
}

extension on String {
  /// The last character, or empty when there is none.
  String get lastCharacter => isEmpty ? '' : substring(length - 1);
}
