import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'photo_import_service.dart';

/// libheif, in the browser, opening the photographs Chrome will not open.
///
/// **The failure this exists for.** A Redmi Note 15 Pro with Xiaomi's "high
/// efficiency" camera setting — on by default — writes HEIC, and no version of
/// Chrome on Android decodes HEIC. The app's own diagnostic row from the live
/// site said the whole story in one line: `{"ms": 107, "reason":
/// "InvalidStateError: The source image could not be decoded.", "outcome":
/// "failed"}`. `createImageBitmap` threw before a single pixel was read, so
/// every measurement downstream of it was missing, and the only advice the app
/// could give was to go and change a setting on the phone.
///
/// So the app reads it itself. libheif is the reference decoder for the format
/// and the only serious one compiled to WebAssembly; `web/libheif/README.md`
/// records the exact build, its size, and why it sits in the repository rather
/// than on a CDN.
///
/// **Nothing here runs unless it has to.** This file is reached only from the
/// `catch` around `createImageBitmap` in `page_text_recognizer_web.dart`, and
/// only when `sniffImageFormat` says the bytes are `heic` or `heif`. A JPEG
/// import does not sniff, does not inject a script and does not fetch a
/// WebAssembly module — it takes the path it took before this file existed,
/// instruction for instruction. That ordering also means a browser that decodes
/// HEIC natively, which Safari does, never pays for the library at all.
///
/// **Everything here degrades.** A refused script, a stalled fetch, a file
/// libheif cannot parse and an image too large for the phone's memory all end
/// the same way: [decodeHeif] throws, the caller falls back to the message it
/// showed before, and the attempt is recorded. A rescue that fails must leave
/// the user exactly where a rescue that was never attempted would have.
///
/// **None of the sentences below is ever shown, and none of them is
/// translated.** `_openHighEfficiency` swallows every exception from here and
/// re-raises the browser's own refusal with
/// `ImportNoticeCode.photoCouldNotDecode` on it, which is what the screen
/// renders. What survives from these is [PhotoImportException.stage], which is
/// the only thing separating a phone with no network from a deploy that did not
/// carry `web/libheif/` from a file libheif itself would not open. The message
/// is a required argument, not an intention to display one.

/// Where the vendored library sits, relative to the document's base href.
///
/// Relative rather than absolute because the app is served from a
/// project-page subpath on GitHub Pages, and `<base href>` is what the build
/// rewrites for it.
const _libheifScript = 'libheif/libheif.js';
const _libheifWasm = 'libheif/libheif.wasm';

/// How long the library has to arrive and start.
///
/// Same reasoning as `_scriptBudget` in `page_text_recognizer_web.dart`: a
/// stalled request fires no `error` event, so without a clock the observable
/// behaviour of a dead connection is a spinner that spins until the page is
/// reloaded. Shorter than Tesseract's 30 seconds would be wrong — this is one
/// third of a megabyte over the same phone network — and longer would be
/// pointless, because the fallback message is already correct.
const _loadBudget = Duration(seconds: 30);

/// How long the decode itself has.
///
/// **What this can and cannot catch, stated honestly.** The pixel work happens
/// inside a synchronous WebAssembly call, so a timer cannot interrupt a decode
/// that is merely slow; it will run to completion and this budget will have
/// expired around it. What it does catch is the decode that never comes back at
/// all — libheif hands its result to a callback from inside a `setTimeout`, and
/// an exception thrown in there (an allocation failure on a twelve-megapixel
/// photograph is the realistic one) escapes to the window handler and leaves the
/// callback uncalled forever. Without this, that is a hang with no way out.
const _decodeBudget = Duration(seconds: 60);

/// [bytes] decoded, or a [PhotoImportException] naming the stage that gave up.
///
/// The returned bitmap is the caller's to `close()`, exactly like the one
/// `createImageBitmap` would have produced — which is the whole point of
/// answering in that type rather than in pixels.
Future<web.ImageBitmap> decodeHeif(Uint8List bytes) async {
  final module = await _libheif();

  final decoderClass = module.getProperty<JSFunction?>('HeifDecoder'.toJS);
  if (decoderClass == null) {
    throw const PhotoImportException(
        'This browser could not open that photo.',
        stage: 'heif:missing');
  }
  final decoder = decoderClass.callAsConstructor<JSObject>();

  // Synchronous, and it does not throw: libheif answers an empty list for a
  // file it cannot parse. A HEIC truncated by a failed transfer lands here.
  final images = decoder
      .callMethod<JSArray<JSObject>>('decode'.toJS, bytes.toJS)
      .toDart;
  if (images.isEmpty) {
    throw const PhotoImportException(
        'This browser could not open that photo.',
        stage: 'heif:empty');
  }

  // The first image and no other. A HEIC may hold a burst, a depth map or a
  // thumbnail alongside the picture; the primary item is first, and a page of
  // a hymnal is one page.
  final image = images.first;
  try {
    final width = image.callMethod<JSNumber>('get_width'.toJS).toDartInt;
    final height = image.callMethod<JSNumber>('get_height'.toJS).toDartInt;
    if (width < 1 || height < 1) {
      throw const PhotoImportException(
          'This browser could not open that photo.',
          stage: 'heif:size');
    }

    // libheif writes straight into this buffer, so it is allocated at the full
    // size of the picture and not a byte more. `_prepare` scales down from the
    // bitmap immediately afterwards; doing it here would need a second buffer.
    final rgba = web.ImageData(
        Uint8ClampedList(width * height * 4).toJS, width, height.toJS);

    final painted = Completer<void>();
    image.callMethod<JSAny?>(
      'display'.toJS,
      rgba,
      ((JSAny? result) {
        if (painted.isCompleted) return;
        if (result == null) {
          // libheif's own way of saying the coded image would not decode,
          // separate from the container parsing, which already succeeded.
          painted.completeError(const PhotoImportException(
              'This browser could not open that photo.',
              stage: 'heif:pixels'));
        } else {
          painted.complete();
        }
      }).toJS,
    );
    await painted.future.timeout(_decodeBudget,
        onTimeout: () => throw const PhotoImportException(
            'Reading the photo took too long.',
            stage: 'heif:timeout'));

    return await web.window.createImageBitmap(rgba).toDart;
  } finally {
    // Every handle, not only the one that was read: `decode` allocated one per
    // top-level image, and the WebAssembly heap is the whole reason a phone
    // runs out of memory on the next photograph rather than this one.
    for (final held in images) {
      try {
        held.callMethod<JSAny?>('free'.toJS);
      } catch (_) {
        // Freeing is best effort. A failure here must not turn a photograph
        // that decoded into a photograph that did not.
      }
    }
  }
}

/// The load already in flight, so two quick taps fetch the library once.
Future<JSObject>? _loading;

Future<JSObject> _libheif() => _loading ??= _load();

Future<JSObject> _load() async {
  try {
    return await _start(await _wasm());
  } catch (_) {
    // Cleared so a later attempt — once there is a network again, or once the
    // service worker has caught up with the deploy — is not handed this same
    // failed future for the rest of the session.
    _loading = null;
    rethrow;
  }
}

/// The WebAssembly module's bytes, fetched by this file rather than by the glue.
///
/// **Not how Emscripten normally does it, and not a preference.** This build
/// instantiates synchronously — `new WebAssembly.Module` on bytes it expects to
/// already hold — and its only way of getting them itself is a *synchronous*
/// XMLHttpRequest, which exists in a worker and not on a page. Called without
/// `Module.wasmBinary` it throws, verbatim: "sync fetching of the wasm failed:
/// you can preload it to Module["wasmBinary"] manually". So the page preloads
/// it manually, which is what that message asks for.
///
/// It is also the better shape here: the fetch is the one part of this that can
/// stall on a phone, and doing it in Dart is what gives it a clock and a status
/// code worth recording.
Future<JSArrayBuffer> _wasm() async {
  final url = web.URL(_libheifWasm, web.document.baseURI).href;
  final response = await web.window
      .fetch(url.toJS)
      .toDart
      .timeout(_loadBudget, onTimeout: _tooSlow);
  if (!response.ok) {
    // The status is worth keeping: 404 is a deploy that did not carry
    // `web/libheif/`, 403 is a proxy answering for it, and they are different
    // mornings' work.
    throw PhotoImportException('This browser could not open that photo.',
        stage: 'heif:wasm:${response.status}');
  }
  return await response.arrayBuffer().toDart.timeout(_loadBudget,
      onTimeout: _tooSlow);
}

Never _tooSlow() => throw const PhotoImportException(
    'Reading the photo took too long.',
    stage: 'heif:timeout');

/// Injects the glue and hands back the module its WebAssembly is running in.
///
/// With [wasm] already in hand the whole start-up is synchronous — Emscripten
/// compiles and instantiates inside the factory call and fires
/// `onRuntimeInitialized` before it returns — so in practice the completer here
/// is complete before the next line runs. The timer stays anyway: `load` firing
/// is a promise about the script, not about anything the script then does.
Future<JSObject> _start(JSArrayBuffer wasm) {
  final done = Completer<JSObject>();
  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..src = _libheifScript
    ..async = true;

  /// [why] separates the ways this load fails, for the record only.
  ///
  /// The same three Tesseract's loader learned to tell apart, for the same
  /// reasons — `error` is a refusal or a 404, `timeout` is a stalled request
  /// that fires no event at all, `blocked` is a *successful* response that
  /// defines no `libheif`, which is what a captive portal's sign-in page is.
  /// Self-hosting makes all three much less likely and none of them impossible:
  /// a service worker serving a stale build, a proxy rewriting the response, an
  /// extension refusing WebAssembly.
  void fail(String why) {
    if (done.isCompleted) return;
    script.remove();
    done.completeError(PhotoImportException(
      'This browser could not open that photo.',
      stage: 'heif:$why',
    ));
  }

  final giveUp = Timer(_loadBudget, () => fail('timeout'));

  // The Module object Emscripten is configured with, and — because this build
  // is MODULARIZE'd — the same object the factory hands back. Completing with
  // it from inside `onRuntimeInitialized` avoids having to hold the factory's
  // return value in a variable the callback would reach before it is assigned,
  // which with a synchronous start-up is every time.
  final module = JSObject();
  module.setProperty('wasmBinary'.toJS, wasm);
  module.setProperty(
      'onRuntimeInitialized'.toJS,
      (() {
        giveUp.cancel();
        if (!done.isCompleted) done.complete(module);
      }).toJS);

  script.addEventListener(
      'load',
      ((web.Event _) {
        final factory = globalContext.getProperty<JSFunction?>('libheif'.toJS);
        if (factory == null) {
          giveUp.cancel();
          fail('blocked');
          return;
        }
        try {
          factory.callAsFunction(null, module);
        } catch (_) {
          giveUp.cancel();
          fail('start');
        }
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
