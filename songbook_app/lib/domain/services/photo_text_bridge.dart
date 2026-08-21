import 'dart:math' as math;

import 'chord_sheet_parser.dart';

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

  OcrWord movedTo(double centreX, double centreY) => OcrWord(
        text: text,
        x0: centreX - width / 2,
        y0: centreY - height / 2,
        x1: centreX + width / 2,
        y1: centreY + height / 2,
      );

  OcrWord saying(String replacement) => OcrWord(
      text: replacement, x0: x0, y0: y0, x1: x1, y1: y1);
}

/// A page turned back into chords-over-lyrics text.
class PhotoReading {
  final String chordPro;

  /// Things worth telling the person reviewing: a page holding two songs, a
  /// chord renamed on the way in, nothing legible at all.
  final List<String> warnings;

  const PhotoReading({required this.chordPro, this.warnings = const []});
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
  static const _sameRow = 0.6;

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
  /// this many words to be a column rather than a speck.
  static const _gutterWidth = 4.0;
  static const _minColumnWords = 3;

  /// Reads [words] into chords-over-lyrics text.
  PhotoReading read(List<OcrWord> words) {
    if (words.isEmpty) {
      return const PhotoReading(
          chordPro: '', warnings: ['Nothing legible was found in that photo.']);
    }

    // Merged chord runs pulled apart first, so everything below — grouping,
    // classification, layout — sees the chords the page prints rather than one
    // nonsense symbol standing for three.
    final split = splitMergedChords(words);

    // Straightened before anything else looks at it, because grouping is what
    // tilt breaks, and columns are found on x once the page is square.
    final straight = deskew(split, estimateSkew(split));
    final columns = splitColumns(straight);

    final lines = <String>[];
    final german = <String>{};
    var chordRows = 0;

    for (var index = 0; index < columns.length; index++) {
      final block = _layOutColumn(columns[index], titled: index == 0);
      if (block.lines.isEmpty) continue;
      if (lines.isNotEmpty) lines.add('');
      lines.addAll(block.lines);
      german.addAll(block.german);
      chordRows += block.chordRows;
    }

    if (lines.isEmpty) {
      return const PhotoReading(
          chordPro: '', warnings: ['Nothing legible was found in that photo.']);
    }

    final warnings = <String>[];
    if (columns.length > 1) {
      // Honest rather than clever: a page holding two songs cannot become one
      // song, and the review box is where the unwanted half gets deleted.
      warnings.add('That page holds ${columns.length} songs side by side. '
          'Both were read, in reading order — delete the one you did not want.');
    }
    if (chordRows == 0) {
      warnings.add(
          'No chords were recognised — the words were imported on their own.');
    }
    if (german.isNotEmpty) {
      final names = german.toList()..sort();
      warnings.add('${names.join(', ')} will be stored under the English name '
          '(H is B natural). The app keeps one spelling per pitch so '
          'transposing stays exact.');
    }
    return PhotoReading(chordPro: lines.join('\n'), warnings: warnings);
  }

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

  /// [words] split into columns, left to right, on the gutters between them.
  ///
  /// A hymnal sets two songs side by side, and rows are clustered by y — so
  /// without this a line in the left column and an unrelated line at the same
  /// height in the right one become one row, and the songs interleave.
  ///
  /// The gutter is a vertical band that NO word crosses anywhere on the page.
  /// Taking the union of every word's extent is what makes it safe: a chord row
  /// is mostly whitespace and full of wide gaps of its own, but some lyric line
  /// below always covers them.
  List<List<OcrWord>> splitColumns(List<OcrWord> words) {
    if (words.length < 2 * _minColumnWords) return [words];
    final gutter = _gutterWidth *
        _median(words.where((w) => w.text.isNotEmpty).map(
            (w) => w.width / w.text.length));

    final spans = words.map((w) => (w.x0, w.x1)).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final edges = <double>[];
    var reach = spans.first.$2;
    for (final (start, end) in spans.skip(1)) {
      if (start - reach > gutter) edges.add((reach + start) / 2);
      reach = math.max(reach, end);
    }
    if (edges.isEmpty) return [words];

    final bounds = [double.negativeInfinity, ...edges, double.infinity];
    final columns = <List<OcrWord>>[];
    for (var i = 0; i < bounds.length - 1; i++) {
      final column = words
          .where((w) => w.centreX >= bounds[i] && w.centreX < bounds[i + 1])
          .toList();
      if (column.length >= _minColumnWords) {
        columns.add(column);
      } else if (columns.isNotEmpty) {
        // A speck in the margin is not a column; fold it back rather than let
        // it become a song of its own.
        columns.last.addAll(column);
      } else if (column.isNotEmpty) {
        columns.add(column);
      }
    }
    return columns.isEmpty ? [words] : columns;
  }

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
        .toList();
    if (rows.isEmpty) return const _Block([], {}, 0);

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

    final breaks = _verseBreaks(rows);
    final german = <String>{};
    var chordRows = 0;

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
      german.addAll(row
          .map((w) => w.text)
          .where((t) => t.startsWith('H') && parser.isChordToken(t)));

      final below = index + 1 < rows.length ? rows[index + 1] : null;
      final pairs = below != null &&
          !breaks[index + 1] &&
          !parser.isChordLine(below.map((w) => w.text).join(' '));
      if (!pairs) {
        // An intro or turnaround with nothing underneath. Kept: the app stores
        // chords with positions past the end of an empty lyric.
        lines.add(_layOut(row).line);
        index++;
        continue;
      }

      final lyrics = _layOut(_repairOcr(below));
      lines.add(_layOutChords(row, lyrics.anchors, _charWidth(below)));
      lines.add(lyrics.line);
      index += 2;
    }
    return _Block(lines, german, chordRows);
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
    if (symbols.length < 2 || parser.isChordToken(word.text)) return [word];

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
      final text = run.map((s) => s.text).join().trim();
      if (text.isEmpty) continue;
      pieces.add(OcrWord(
        text: text,
        x0: run.first.x0,
        y0: word.y0,
        x1: run.last.x1,
        y1: word.y1,
      ));
    }
    if (pieces.length < 2) return [word];
    // The guard that protects prose: all or nothing.
    for (final piece in pieces) {
      if (!parser.isChordToken(piece.text) &&
          !parser.isContinuation(piece.text) &&
          !_isChordPunctuation(piece.text)) {
        return [word];
      }
    }
    return pieces;
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
  const _Block(this.lines, this.german, this.chordRows);
}

extension on String {
  /// The last character, or empty when there is none.
  String get lastCharacter => isEmpty ? '' : substring(length - 1);
}
