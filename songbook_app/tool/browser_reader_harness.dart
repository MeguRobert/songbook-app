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
// `{chordPro, warnings, words, ms}` or `{error}`. `warnings` holds
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

  @override
  bool get isSupported => _inner.isSupported;

  @override
  Future<PageWords> recognize(Uint8List imageBytes,
          {String language = PageTextRecognizer.hungarian}) async =>
      answer ??= await _inner.recognize(imageBytes, language: language);
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
