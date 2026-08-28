import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'import_notice.dart';
import 'page_preprocessor.dart';
import 'page_text_recognizer.dart';
import 'photo_import_service.dart';
import 'photo_text_bridge.dart';

/// Tesseract, in the browser, reading the page the user just photographed.
///
/// This is the only part of the text path that is not plain Dart, and it exists
/// because the measurement said so: on a real photograph of song 149 this
/// engine found 4 of 4 chord rows in about two seconds and read `Ő` correctly,
/// where the server engine it replaced found 3 of 4 in forty seconds and
/// returned `Ó`. Nothing is uploaded and nothing is hosted.
PageTextRecognizer createPageTextRecognizer() =>
    const TesseractPageTextRecognizer();

/// Tesseract.js, loaded on demand from a public CDN.
///
/// **On demand, not from `index.html`.** The engine and its Hungarian model are
/// several megabytes; almost every visit to Songbook opens a song rather than
/// photographs one, so paying for this at startup would slow the app for
/// everybody to speed it up for nobody. Bundling the files into `web/` would be
/// worse: Flutter's service worker pre-caches what it finds there, which would
/// put those megabytes into the install of a user who never takes a photo.
///
/// The cost is that the *first* photo on a device needs a network, and that
/// "offline afterwards" is a likelihood rather than a promise: the script, the
/// worker and the WebAssembly core sit in the ordinary HTTP cache, which the
/// browser may evict and which the app's own service worker does not manage
/// (it passes cross-origin requests straight through). Only the language model
/// gets durable storage, from Tesseract itself. Against a server path that
/// needed a network every single time, this is still strictly better.
const _tesseractScript =
    'https://unpkg.com/tesseract.js@7.0.0/dist/tesseract.min.js';

/// The hash the fetched script must match, or the browser refuses to run it.
///
/// Pinning the version says which bytes are wanted; this says the bytes
/// arriving are those. Without it, anyone able to answer for that URL — a CDN
/// compromise, not a hypothetical for a free public CDN — runs their own code
/// inside this app's origin, where the Supabase session is stored and readable
/// by any script. Recompute when the version moves:
///
/// ```
/// curl -sL <the URL above> | openssl dgst -sha384 -binary | openssl base64 -A
/// ```
///
/// This covers the script this file injects. The worker and WebAssembly core
/// that Tesseract then fetches for itself are not covered — they are chosen
/// inside the script and land in a Web Worker, which has no DOM and no access
/// to the session, so the page-level script is the part worth hashing.
const _tesseractIntegrity =
    'sha384-2BQ3U3OdKOb0Uczxqr41I9UvZkzr4V9Hv8uSzMMZAlmhsFClvdZX5wi5fDCzG+tM';

/// How long each stage may take before the person is told it did not work.
///
/// Nothing here can fail on its own. A stalled connection fires no `error`
/// event — the request simply never finishes — so before these the observable
/// behaviour of bad Wi-Fi was a spinner that span until the page was reloaded,
/// with no way back. The wire path has had a 90-second bound since it was
/// written; this is the same idea for the path that replaced it as the default.
///
/// The engine gets the longest budget because the first read on a device pulls
/// roughly ten megabytes — the worker, the WebAssembly core and the Hungarian
/// model — before it can start.
const _scriptBudget = Duration(seconds: 30);
const _engineBudget = Duration(seconds: 120);
const _readBudget = Duration(seconds: 60);

/// What the user is told when a stage runs out of time.
///
/// One sentence for all three, because from the outside they are one situation:
/// it did not load. **[stage] is the same three told apart**, and it goes only
/// into the diagnostic record — see [PhotoImportException.stage].
///
/// The three collapsing into one message is right for the screen and was wrong
/// for the log. `engine` blowing its 120 seconds means ten megabytes did not
/// arrive, which is a connection; `read` blowing its 60 means the engine started
/// and then could not finish a page, which is a device too slow or an image too
/// large; `script` blowing its 30 means the CDN never answered at all, which is
/// most likely a filter rather than a network. Same sentence, three different
/// things to go and look at.
Never _tooSlow(String stage) => throw PhotoImportException(
      'Reading the photo took too long. Check your connection and try again.',
      stage: stage,
    );

/// The longest edge the photo is scaled to before it is read.
///
/// 2048 because that is the size all of this was measured at — the real
/// photograph of song 149 is 2048x1532 — so a phone handing over twelve
/// megapixels is read at a resolution already known to be enough, in a time
/// already known to be about two seconds, rather than four times that.
const _longestEdge = 2048;

/// The most pixels the canvas may hold, and the second half of the rule.
///
/// **Why a longest-edge cap alone was wrong.** It assumes the page is roughly
/// as wide as it is tall, which a photograph of a hymnal is and a *scrolled
/// screenshot* is not. A 1080x12000 screenshot — eleven phone screens of one
/// song, stitched by the phone itself — came out of that rule at **184x2048**,
/// and 184 pixels is not a page, it is a stripe. Measured on the corpus page
/// 185 rendered at a range of widths, with everything else held still:
///
/// | rendered width | 184 | 260 | 320 | 400 | 480 | 640 | 768 | 1532 |
/// |---|---|---|---|---|---|---|---|---|
/// | score | *refused* | 0.564 | 0.422 | 0.825 | 0.901 | 0.867 | 0.909 | 0.911 |
///
/// The page is worth full marks from about 480 pixels wide and worth nothing at
/// all below 260. The old rule put a real screenshot at 184.
///
/// **Why this number and not another.** 2048x1536 is the area of the
/// photograph the whole reader was calibrated on, and it is the *only* value
/// that leaves an ordinary photograph untouched: for any 4:3 image, in either
/// orientation, `sqrt(2048*1536 / (w*h))` and `2048 / max(w, h)` are the same
/// number — 3L²/4 pixels against a long edge L makes the two agree exactly at
/// 3·2048²/4. Every phone camera defaults to 4:3 and every page in the
/// measurement corpus is between 1.33 and 1.34, so the corpus reads at the
/// identical scale it did before, and the score is unchanged to the digit.
///
/// The two rules are combined with `max`, not `min`, so **no image is ever
/// rendered smaller than it was before this existed** — which is what makes a
/// reading regression impossible by construction rather than by measurement.
/// The cost is bounded on the other side too: for anything more elongated than
/// 4:3 the area rule wins, and it holds the canvas at the same pixel count a
/// 4:3 photograph has always cost. A tall screenshot is therefore no more
/// expensive to read than a photograph, which matters on the phones this
/// happens on — every buffer below is a multiple of this number.
const _maxPixels = 2048 * 1536;

/// What a page of text needs to keep its accents, as the Python worker measures
/// it in `resolution_note` — the two have to agree, because a photograph read on
/// one side of the wire and then on the other must get the same answer.
///
/// A Hungarian `ő` differs from `ó` by two hairline strokes, and they are the
/// first thing a hard JPEG throws away: measured on a real upload, 2048x1532 at
/// 0.026 bytes per pixel came back reading `erót` for `erőt` and `-7` as `27`.
///
/// Both halves matter and either alone is enough to lose the accents, so the
/// test is an OR. Pixels alone would pass a 4000px image squeezed into 90KB;
/// bytes alone would fail a lightly compressed small scan that is genuinely
/// legible. Measured against the *upload*, not the canvas below: scaling to
/// [_longestEdge] is this file's own doing and says nothing about what the
/// camera handed over.
const _minLongEdge = 1200;
const _minBytesPerPixel = 0.08;

class TesseractPageTextRecognizer implements PageTextRecognizer {
  const TesseractPageTextRecognizer({
    this.preprocessor = const PagePreprocessor(),
    this.bridge = const PhotoTextBridge(),
  });

  final PagePreprocessor preprocessor;

  /// Asked where the columns are, and nothing else.
  ///
  /// The rule belongs beside the one that lays the words back out — they have to
  /// agree about what a column is — and it is measured in Dart against boxes, so
  /// it stays testable on the VM where there is no engine to run.
  final PhotoTextBridge bridge;

  @override
  bool get isSupported => true;

  @override
  Future<PageWords> recognize(
    Uint8List imageBytes, {
    String language = PageTextRecognizer.hungarian,
    List<Map<String, Object?>>? trace,
  }) async {
    await _loadTesseract();

    final prepared = await _prepare(imageBytes, trace);
    // A worker per photo. It could be kept alive between photos, but it holds
    // the WebAssembly heap and the language model for as long as it lives, and
    // a second photo is minutes away at best — the model is cached by then, so
    // starting over costs little.
    final worker = await _createWorker(language)
        .toDart
        .timeout(_engineBudget, onTimeout: () => _tooSlow('engine'));
    try {
      final whole = await _read(worker, prepared.canvas);
      final cuts = bridge.columnCuts(whole);
      trace?.add({
        'stage': 'read',
        'words': whole.length,
        'columnCuts': [for (final cut in cuts) cut.round()],
      });
      if (cuts.isEmpty) {
        return PageWords(whole, notices: prepared.notices);
      }
      final words = await _readColumns(worker, prepared.canvas, whole, cuts,
          trace);
      trace?.add({'stage': 'columns', 'words': words.length});
      return PageWords(words, notices: prepared.notices);
    } finally {
      await worker.terminate().toDart;
    }
  }

  /// [canvas] read once, whole.
  Future<List<OcrWord>> _read(
      _TesseractWorker worker, web.HTMLCanvasElement canvas) async {
    // Exactly the pair the bench measured. `text` is not read here — the words
    // and their boxes are — but asking for the same outputs as the measurement
    // keeps this from being a differently configured engine that merely looks
    // like the one the numbers came from.
    final output = JSObject()
      ..setProperty('blocks'.toJS, true.toJS)
      ..setProperty('text'.toJS, true.toJS)
      // Symbols, because the engine joins glyphs into a word on spacing:
      // `D G  D` set with narrow gaps arrives as the single word `DGD`, which
      // is not a chord symbol, and the row was then stored as lyrics.
      // PhotoTextBridge.splitMergedChords needs the glyph boxes to undo that.
      ..setProperty('symbols'.toJS, true.toJS);
    final result = await worker
        .recognize(canvas, JSObject(), output)
        .toDart
        .timeout(_readBudget, onTimeout: () => _tooSlow('read'));
    return _wordsIn(result.data);
  }

  /// Each column of [canvas] read again, on its own, and put back on one grid.
  ///
  /// Splitting the words of a single whole-page read is not enough, which is
  /// what the measurement corpus showed: Tesseract does its own layout analysis
  /// before it returns a box, and on a two-column page it joins a line from one
  /// column to a line from the other — so `125-nincs-mas-isten` came back with
  /// `Nálad lett borrá` and `Átvezető rész` inside one word list at one y, and
  /// no rule about boxes can take that apart again. Given one column at a time
  /// the engine sees the single-column page its default segmentation assumes.
  ///
  /// The price is one recognition pass per column on top of the whole-page pass
  /// that found them — roughly three times the work on a two-column page, and
  /// nothing at all on the single-column pages that are the common case.
  ///
  /// [whole] is not thrown away: a row lying *across* a gutter is in no column,
  /// and that row is the page's own heading. It is kept from the pass that has
  /// already been paid for rather than read a fourth time.
  Future<List<OcrWord>> _readColumns(
    _TesseractWorker worker,
    web.HTMLCanvasElement canvas,
    List<OcrWord> whole,
    List<double> cuts,
    List<Map<String, Object?>>? trace,
  ) async {
    // The bridge decides what the heading is, so the crops and the layout that
    // follows them agree about it rather than each holding its own opinion.
    final heading = bridge.headingRow(whole);
    final words = <OcrWord>[...heading];
    final skipFrom = heading.isEmpty
        ? 0.0
        : heading.map((w) => w.y0).reduce(math.min);
    final skipTo =
        heading.isEmpty ? -1.0 : heading.map((w) => w.y1).reduce(math.max);

    final bounds = [0.0, ...cuts, canvas.width.toDouble()];
    for (var index = 0; index < bounds.length - 1; index++) {
      final left = bounds[index].floor().clamp(0, canvas.width);
      final right = bounds[index + 1].ceil().clamp(0, canvas.width);
      if (right - left < 1) continue;
      final column = await _read(worker, _band(canvas, left, right));
      trace?.add({
        'stage': 'column',
        'x0': left,
        'x1': right,
        'words': column.length,
      });
      // Back onto the page's own grid, because everything downstream — row
      // grouping, the character columns a chord sits at — compares words with
      // one another across the whole reading.
      words.addAll([
        for (final word in column)
          // The heading is already in hand from the whole-page pass, and a crop
          // of half of it reads as half of it.
          if (word.centreY < skipFrom || word.centreY > skipTo)
            word.shiftedBy(left.toDouble()),
      ]);
    }
    return words;
  }

  /// The slice of [canvas] between [left] and [right], full height.
  web.HTMLCanvasElement _band(
      web.HTMLCanvasElement canvas, int left, int right) {
    final band = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = right - left
      ..height = canvas.height;
    final context = band.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) {
      throw const PhotoImportException('This browser cannot read images.',
          stage: 'canvas:band');
    }
    context.drawImage(canvas, left.toDouble(), 0, (right - left).toDouble(),
        canvas.height.toDouble(), 0, 0, (right - left).toDouble(),
        canvas.height.toDouble());
    return band;
  }

  /// The photograph as greyscale on a canvas, with the reverse page erased —
  /// and what the pixels themselves are worth telling the user.
  ///
  /// Both cleaning steps matter and neither is Tesseract's job. Greyscale is
  /// what the engine works in anyway. Show-through — a hymnal is printed thin
  /// enough to read its own back page — arrives as words stuck to the real
  /// lyrics, and removing it took the measured page from 3 recognised chord
  /// rows to 4.
  ///
  /// The notices come out of here because this is the only stage holding the
  /// image. Both were already being measured and then thrown away: every page
  /// in the measurement corpus reported *warning not raised: low-resolution*
  /// against a worker that says so, and show-through was suppressed without a
  /// word even though suppression costs stroke sharpness.
  Future<_Prepared> _prepare(
      Uint8List imageBytes, List<Map<String, Object?>>? trace) async {
    final bitmap = await web.window
        .createImageBitmap(web.Blob([imageBytes.toJS].toJS))
        .toDart;

    final pixels = math.max(1, bitmap.width * bitmap.height);
    // Two ceilings, and the looser one wins: the longest edge, which is right
    // for a page-shaped photograph, and the total area, which is what stops a
    // scrolled screenshot being squeezed to a stripe. See [_maxPixels].
    final scale = math.min(
      1.0,
      math.max(
        _longestEdge / math.max(1, math.max(bitmap.width, bitmap.height)),
        math.sqrt(_maxPixels / pixels),
      ),
    );
    final width = math.max(1, (bitmap.width * scale).round());
    final height = math.max(1, (bitmap.height * scale).round());

    final notices = <ImportNotice>[];
    trace?.add({
      'stage': 'image',
      'width': bitmap.width,
      'height': bitmap.height,
      'bytes': imageBytes.length,
      'bytesPerPixel': imageBytes.length / pixels,
      // What was actually read, which is not the same thing and was the whole
      // fault here: a row saying 1080x12000 read perfectly well as a row about
      // an image that was in fact handed to the engine 184 pixels wide.
      'scale': scale,
      'canvasWidth': width,
      'canvasHeight': height,
    });
    if (math.max(bitmap.width, bitmap.height) < _minLongEdge ||
        imageBytes.length / pixels < _minBytesPerPixel) {
      notices.add(ImportNotice(
        ImportNoticeCode.photoLowResolution,
        text: '${bitmap.width}×${bitmap.height}',
        count: imageBytes.length ~/ 1024,
      ));
    }

    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement
          ..width = width
          ..height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) {
      throw const PhotoImportException('This browser cannot read images.',
          stage: 'canvas:page');
    }
    context.drawImage(bitmap, 0, 0, width, height);
    bitmap.close();

    final rgba = context.getImageData(0, 0, width, height).data.toDart;
    final grey = Uint8List(width * height);
    for (var pixel = 0; pixel < grey.length; pixel++) {
      final at = pixel * 4;
      // Rec. 601 luma in integers — the same weighting the Python worker used,
      // so a page reads the same whichever side of the wire it is read on.
      grey[pixel] =
          (rgba[at] * 299 + rgba[at + 1] * 587 + rgba[at + 2] * 114) ~/ 1000;
    }

    // Measured rather than only asked, so the trace carries the number behind
    // the verdict.
    //
    // Nothing is told to the user about it, and that is a reversal. The notice
    // went in first and the measurement then said it could not be supported:
    // under the Dart port's flattening every page in the corpus sits between
    // 0.0139 and 0.0451, so the 0.012 gate has never excluded one, and the
    // born-digital screenshot scores 0.0444 — higher than the page whose
    // reverse side is genuinely legible through the paper. A warning that fires
    // on every import and names a cause it cannot establish is noise.
    //
    // The suppression itself stays, because it is not really ghost removal: it
    // flattens the lighting and stretches the levels, and the reader needs that
    // almost everywhere. Measured over the corpus, turning it off costs 0.156
    // of the mean score - `app-jezus-szivedbe-lat` alone falls from 0.965 to
    // 0.351. Two pages would read better without it and there is no signal that
    // separates them from the rest, which is the open question here.
    final pale = preprocessor.paleFraction(grey, width, height);
    final suppress = preprocessor.showsThroughAt(pale);
    final cleaned = suppress
        ? preprocessor.suppressShowThrough(grey, width, height)
        : grey;
    trace?.add({
      'stage': 'clean',
      'paleFraction': pale,
      'suppressed': suppress,
    });

    // A fresh ImageData rather than writing through the one just read: whether
    // `toDart` hands back a view or a copy is the compiler's business, and this
    // does not need to know.
    final out = Uint8ClampedList(width * height * 4);
    for (var pixel = 0; pixel < cleaned.length; pixel++) {
      final at = pixel * 4;
      out[at] = out[at + 1] = out[at + 2] = cleaned[pixel];
      out[at + 3] = 255;
    }
    context.putImageData(web.ImageData(out.toJS, width, height.toJS), 0, 0);
    return _Prepared(canvas, notices);
  }

  /// Every word Tesseract reported, whichever shape this version reports in.
  ///
  /// Version 7 nests words under blocks, paragraphs and lines; earlier ones put
  /// a flat `words` list on the page. Both are read, because a CDN upgrade must
  /// not be able to quietly start returning nothing.
  List<OcrWord> _wordsIn(_TesseractPage page) {
    final words = <OcrWord>[];

    void take(_TesseractWord word) {
      final text = (word.text ?? '').trim();
      final box = word.bbox;
      if (text.isEmpty || box == null) return;
      // Carried, not interpreted. Whether a merge is worth undoing is a
      // question about chords, and that belongs in PhotoTextBridge.
      final glyphs = <OcrWord>[];
      for (final symbol in word.symbols?.toDart ?? const <_TesseractSymbol>[]) {
        final glyph = symbol.text;
        final glyphBox = symbol.bbox;
        if (glyph == null || glyph.isEmpty || glyphBox == null) continue;
        glyphs.add(OcrWord(
          text: glyph,
          x0: glyphBox.x0.toDouble(),
          y0: glyphBox.y0.toDouble(),
          x1: glyphBox.x1.toDouble(),
          y1: glyphBox.y1.toDouble(),
        ));
      }
      words.add(OcrWord(
        text: text,
        x0: box.x0.toDouble(),
        y0: box.y0.toDouble(),
        x1: box.x1.toDouble(),
        y1: box.y1.toDouble(),
        symbols: glyphs,
      ));
    }

    for (final word in page.words?.toDart ?? const <_TesseractWord>[]) {
      take(word);
    }
    if (words.isNotEmpty) return words;

    for (final block in page.blocks?.toDart ?? const <_TesseractBlock>[]) {
      for (final paragraph
          in block.paragraphs?.toDart ?? const <_TesseractParagraph>[]) {
        for (final line in paragraph.lines?.toDart ?? const <_TesseractLine>[]) {
          for (final word in line.words?.toDart ?? const <_TesseractWord>[]) {
            take(word);
          }
        }
      }
    }
    return words;
  }
}

/// A canvas ready to read, and what the image itself was worth saying.
class _Prepared {
  final web.HTMLCanvasElement canvas;
  final List<ImportNotice> notices;

  const _Prepared(this.canvas, this.notices);
}

/// The load already in flight, so two quick taps fetch the script once.
Future<void>? _tesseractLoading;

Future<void> _loadTesseract() {
  if (globalContext.has('Tesseract')) return Future<void>.value();
  return _tesseractLoading ??= _injectTesseract();
}

Future<void> _injectTesseract() {
  final done = Completer<void>();
  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..src = _tesseractScript
    ..integrity = _tesseractIntegrity
    // Required for `integrity` to be checked at all on a cross-origin script:
    // without it the response is opaque and there is nothing to hash.
    ..crossOrigin = 'anonymous'
    ..async = true;

  /// [why] separates the three ways this download fails, for the record only.
  ///
  /// One sentence covers all of them for the user, and it collapsed the three
  /// things worth knowing:
  ///
  /// * `script:error` — the request was refused or 404'd. An ad-blocker, a DNS
  ///   filter, a corporate proxy, or a CSP that does not allow the origin. This
  ///   is the case that will actually bite in public.
  /// * `script:timeout` — nothing answered inside 30 seconds. A stalled
  ///   connection, which fires no `error` event at all.
  /// * `script:blocked` — a *successful* response that defines no `Tesseract`. A
  ///   captive portal's sign-in page or a proxy's block page, both of which are
  ///   HTML and neither of which fires `error`. Found and fixed once already, and
  ///   indistinguishable from the others in the log until now.
  void fail(String why) {
    // Cleared so a later attempt — once there is a network again — is not
    // handed this same failed future for the rest of the session.
    _tesseractLoading = null;
    script.remove();
    if (!done.isCompleted) {
      done.completeError(PhotoImportException(
        'The reader could not be downloaded. The first photo on a device '
        'needs a connection.',
        stage: 'script:$why',
      ));
    }
  }

  // A stalled request fires neither `load` nor `error`, so a clock is the only
  // way out of one.
  final giveUp = Timer(_scriptBudget, () => fail('timeout'));

  script.addEventListener(
      'load',
      ((web.Event _) {
        giveUp.cancel();
        // `load` fires for any successful response, and a captive portal's
        // sign-in page or a proxy's block page is a successful response. Both
        // arrive as HTML that defines no `Tesseract`, and a script that fails
        // to parse does not fire `error` either. Completing here without
        // checking left a *successfully completed* future in the singleton
        // below, which every later attempt was then handed — so one airport
        // Wi-Fi broke the feature until the page was reloaded.
        if (!globalContext.has('Tesseract')) {
          fail('blocked');
          return;
        }
        if (!done.isCompleted) done.complete();
      }).toJS);
  script.addEventListener(
      'error',
      ((web.Event _) {
        giveUp.cancel();
        fail('error');
      }).toJS);
  web.document.head!.append(script);
  return done.future;
}

@JS('Tesseract.createWorker')
external JSPromise<_TesseractWorker> _createWorker(String language);

extension type _TesseractWorker._(JSObject _) implements JSObject {
  external JSPromise<_TesseractResult> recognize(
      JSAny image, JSAny? options, JSAny? output);

  external JSPromise<JSAny?> terminate();
}

extension type _TesseractResult._(JSObject _) implements JSObject {
  external _TesseractPage get data;
}

extension type _TesseractPage._(JSObject _) implements JSObject {
  external JSArray<_TesseractWord>? get words;
  external JSArray<_TesseractBlock>? get blocks;
}

extension type _TesseractBlock._(JSObject _) implements JSObject {
  external JSArray<_TesseractParagraph>? get paragraphs;
}

extension type _TesseractParagraph._(JSObject _) implements JSObject {
  external JSArray<_TesseractLine>? get lines;
}

extension type _TesseractLine._(JSObject _) implements JSObject {
  external JSArray<_TesseractWord>? get words;
}

extension type _TesseractWord._(JSObject _) implements JSObject {
  external String? get text;
  external _TesseractBox? get bbox;
  external JSArray<_TesseractSymbol>? get symbols;
}

extension type _TesseractSymbol._(JSObject _) implements JSObject {
  external String? get text;
  external _TesseractBox? get bbox;
}

extension type _TesseractBox._(JSObject _) implements JSObject {
  external num get x0;
  external num get y0;
  external num get x1;
  external num get y1;
}
