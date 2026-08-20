import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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
/// returned `Ó`. Nothing is uploaded, nothing is hosted, and it keeps working
/// offline once the browser has the model.
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
/// The cost is that the *first* photo on a device needs a network. The browser
/// caches both files afterwards, so later ones do not — and the server path
/// this replaces needed a network every single time.
const _tesseractScript =
    'https://unpkg.com/tesseract.js@7.0.0/dist/tesseract.min.js';

/// The longest edge the photo is scaled to before it is read.
///
/// 2048 because that is the size all of this was measured at — the real
/// photograph of song 149 is 2048x1532 — so a phone handing over twelve
/// megapixels is read at a resolution already known to be enough, in a time
/// already known to be about two seconds, rather than four times that.
const _longestEdge = 2048;

class TesseractPageTextRecognizer implements PageTextRecognizer {
  const TesseractPageTextRecognizer({
    this.preprocessor = const PagePreprocessor(),
  });

  final PagePreprocessor preprocessor;

  @override
  bool get isSupported => true;

  @override
  Future<List<OcrWord>> recognize(
    Uint8List imageBytes, {
    String language = PageTextRecognizer.hungarian,
  }) async {
    await _loadTesseract();

    final canvas = await _cleanedCanvas(imageBytes);
    // A worker per photo. It could be kept alive between photos, but it holds
    // the WebAssembly heap and the language model for as long as it lives, and
    // a second photo is minutes away at best — the model is cached by then, so
    // starting over costs little.
    final worker = await _createWorker(language).toDart;
    try {
      // Exactly the pair the bench measured. `text` is not read here — the
      // words and their boxes are — but asking for the same outputs as the
      // measurement keeps this from being a differently configured engine that
      // merely looks like the one the numbers came from.
      final output = JSObject()
        ..setProperty('blocks'.toJS, true.toJS)
        ..setProperty('text'.toJS, true.toJS);
      final result = await worker.recognize(canvas, JSObject(), output).toDart;
      return _wordsIn(result.data);
    } finally {
      await worker.terminate().toDart;
    }
  }

  /// The photograph as greyscale on a canvas, with the reverse page erased.
  ///
  /// Both steps matter and neither is Tesseract's job. Greyscale is what the
  /// engine works in anyway. Show-through — a hymnal is printed thin enough to
  /// read its own back page — arrives as words stuck to the real lyrics, and
  /// removing it took the measured page from 3 recognised chord rows to 4.
  Future<web.HTMLCanvasElement> _cleanedCanvas(Uint8List imageBytes) async {
    final bitmap = await web.window
        .createImageBitmap(web.Blob([imageBytes.toJS].toJS))
        .toDart;

    final scale = math.min(
      1.0,
      _longestEdge / math.max(bitmap.width, bitmap.height),
    );
    final width = math.max(1, (bitmap.width * scale).round());
    final height = math.max(1, (bitmap.height * scale).round());

    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement
          ..width = width
          ..height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) {
      throw const PhotoImportException('This browser cannot read images.');
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

    final cleaned = preprocessor.hasShowThrough(grey, width, height)
        ? preprocessor.suppressShowThrough(grey, width, height)
        : grey;

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
    return canvas;
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
      words.add(OcrWord(
        text: text,
        x0: box.x0.toDouble(),
        y0: box.y0.toDouble(),
        x1: box.x1.toDouble(),
        y1: box.y1.toDouble(),
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
    ..async = true;
  script.addEventListener(
      'load',
      ((web.Event _) {
        if (!done.isCompleted) done.complete();
      }).toJS);
  script.addEventListener(
      'error',
      ((web.Event _) {
        // Cleared so a later attempt — once there is a network again — is not
        // handed this same failed future for the rest of the session.
        _tesseractLoading = null;
        script.remove();
        if (!done.isCompleted) {
          done.completeError(const PhotoImportException(
            'The reader could not be downloaded. The first photo on a device '
            'needs a connection.',
          ));
        }
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
}

extension type _TesseractBox._(JSObject _) implements JSObject {
  external num get x0;
  external num get y0;
  external num get x1;
  external num get y1;
}
