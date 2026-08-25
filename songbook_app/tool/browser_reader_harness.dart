// A page that reads a photograph with the app's own browser engine.
//
// Why this exists: `flutter test` runs on the Dart VM, which has no browser, so
// every unit test of the reading path fakes the recognizer. That makes the
// measured numbers describe `photo_import_worker.py` — EasyOCR, on a developer's
// machine — while what ships is Tesseract.js plus `PhotoTextBridge` on a phone.
// Two separate implementations, and only one of them was being scored.
//
// Nothing here is a copy of the app. It imports `BrowserPhotoImportService` and
// `createPageTextRecognizer` and calls them, so a fix in either shows up in the
// measurement without being ported.
//
// Compile and drive it through tools/ocr_harness; see `engines.Browser`.
//
//     dart compile js --packages=.dart_tool/package_config.json -O1 \
//       -o <out>/harness.js tool/browser_reader_harness.dart
//
// The page then exposes `window.readPage('<url>')`, which resolves to
// `{chordPro, warnings, words, boxes, trace, ms}` or `{error}`.
// `boxes` is every word the engine returned and the glyphs inside it;
// `trace --boxes` is what prints it. `warnings` holds
// ImportNoticeCode names, since the prose is in the app's localisations.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:songbook_app/domain/services/browser_photo_import_service.dart';
import 'package:songbook_app/domain/services/page_text_recognizer.dart';
import 'package:songbook_app/domain/services/page_text_recognizer_stub.dart'
    if (dart.library.js_interop)
        'package:songbook_app/domain/services/page_text_recognizer_web.dart';
import 'package:songbook_app/domain/services/photo_import_service.dart';

/// The real recognizer, reading each photograph exactly once.
class _Once implements PageTextRecognizer {
  _Once(this._inner);

  final PageTextRecognizer _inner;
  PageWords? answer;

  /// What every stage measured and decided, for the harness to report.
  final List<Map<String, Object?>> trace = [];

  @override
  bool get isSupported => _inner.isSupported;

  @override
  Future<PageWords> recognize(Uint8List imageBytes,
          {String language = PageTextRecognizer.hungarian,
          List<Map<String, Object?>>? trace}) async =>
      answer ??= await _inner.recognize(imageBytes,
          language: language, trace: this.trace);
}

/// Fetches [url] as bytes, the same shape a file picker hands the app.
Future<Uint8List> _fetch(String url) async {
  final response = await web.window.fetch(url.toJS).toDart;
  if (!response.ok) {
    throw StateError('fetch $url -> ${response.status}');
  }
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

// Returns a JS string, not a Dart one. `Future<String>.toJS` is not a promise
// conversion — the future's value has to be a JS type — and the mismatch showed
// up only at run time, as `window.readPage(...)` evaluating to `undefined`.
Future<JSString> _read(String url) async {
  final started = DateTime.now();
  try {
    final recognizer = createPageTextRecognizer();
    if (!recognizer.isSupported) {
      return jsonEncode({'error': 'no recognizer in this build'}).toJS;
    }
    // The word count says whether a thin reading was the recognizer's fault or
    // the bridge's, and the service does not expose it. It used to come from a
    // second `recognize` call, which doubled the cost of every page and left two
    // independent reads of the same photograph free to disagree - and it got
    // worse when the recogniser started reading each column as its own image,
    // because that is three passes rather than one. So the engine is called once
    // and the answer is held: the service still does exactly what it does.
    final bytes = await _fetch(url);
    final once = _Once(recognizer);
    final service = BrowserPhotoImportService(recognizer: once);
    final payload = await service.extract(bytes, fileName: url);
    final read = once.answer!;
    if (payload is! ChordProPayload) {
      return jsonEncode(
          {'error': 'unexpected payload ${payload.runtimeType}'}).toJS;
    }
    return jsonEncode({
      'chordPro': payload.text,
      // Code names, not sentences. The reader emits ImportNotice codes now, and
      // the prose lives in the app's localisations, which nothing here loads.
      // The harness maps these to its own slugs — see WARNING_CODES in
      // tools/ocr_harness/reading.py — which is a stabler contract than the
      // substring match on English wording it replaced.
      'warnings': [for (final notice in payload.notices) notice.code.name],
      'words': read.words.length,
      // Every word the engine returned, with the glyph boxes inside it.
      //
      // Not a measurement of the app - a window into the one input every rule
      // in `PhotoTextBridge` is a proportion over. Three of the five reading
      // defects fixed so far were invisible until someone looked at these:
      // `125-nincs-mas-isten`'s column of `!` turned out to be 1-to-5-pixel
      // slices of the printed box around the page, `151-zengjed-a-dalt`
      // returned its letterbox edge as a 944x25 `A`, and `084-van-egy-ut`
      // returned its italic capital `C` as a lowercase `c` at full cap height.
      // Each time the dump was added by hand, measured with, and deleted again.
      //
      // The glyphs matter as much as the words: `splitMergedChords` decides
      // where `DGD` comes apart from the gaps between them, so a merge that
      // did not split can only be explained by the boxes it was looking at.
      //
      // Always emitted. The harness prints them only for `trace --boxes`, and
      // one page's worth is a few hundred rows of JSON on a wire that is
      // already carrying the page's whole text.
      'boxes': [
        for (final word in read.words)
          {
            't': word.text,
            'x0': word.x0.round(),
            'y0': word.y0.round(),
            'x1': word.x1.round(),
            'y1': word.y1.round(),
            'glyphs': [
              for (final glyph in word.symbols)
                {
                  't': glyph.text,
                  'x0': glyph.x0.round(),
                  'y0': glyph.y0.round(),
                  'x1': glyph.x1.round(),
                  'y1': glyph.y1.round(),
                },
            ],
          },
      ],
      // What each stage measured, the way the Python arm has always reported
      // it. Without this the only account of why a page read the way it did
      // was of the engine that does not run on a phone.
      'trace': once.trace,
      'ms': DateTime.now().difference(started).inMilliseconds,
    }).toJS;
  } on PhotoImportException catch (error) {
    // The sentence the app would have shown the user. Kept as an outcome rather
    // than an error: "it did not read, and here is what it would have said" is
    // a measurement.
    return jsonEncode({
      'refused': error.message,
      'ms': DateTime.now().difference(started).inMilliseconds,
    }).toJS;
  } catch (error) {
    return jsonEncode({'error': '$error'}).toJS;
  }
}

void main() {
  globalContext.setProperty(
    'readPage'.toJS,
    ((JSString url) => _read(url.toDart).toJS).toJS,
  );
  web.document.title = 'browser reader harness — ready';
}
