import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'browser_name.dart';

/// The browser and its major version, as `chrome/131` — and nothing else.
///
/// **Why this is worth a field.** `describePlatform` already said
/// `web/android 412x915 dpr2.6`, which names the operating system and not the
/// thing that decides whether anything works. The photo reader is the clearest
/// case: whether an upload decodes at all is a property of the browser's image
/// support, and "android" is equally true of the browser that opens a HEIC and
/// of the one that refuses. The first real photo-import failure from the live
/// app arrived with that field reading `web/android` and nothing else to go on.
///
/// **Why not the user-agent string.** `error_reports` is written by an
/// anonymous client and read by moderators. A full UA carries the device model,
/// the Android build and the WebView version — a fingerprint, in a table with
/// no use for one. The bucket is the entire diagnostic value: "only on Firefox",
/// "only before 120". A major version delivers that; a minor version and a
/// device model deliver a person.
///
/// `navigator.userAgentData` is preferred because it is the browser answering a
/// question about itself, rather than this code parsing a string that was
/// designed to lie. It exists only on Chromium and only in a secure context, so
/// [browserFromUserAgent] stays as the fallback — the one place a UA string is
/// touched at all, and nothing but a name and a run of digits ever leaves it.
String? describeBrowser() {
  try {
    final navigator = web.window.navigator as JSObject;
    final fromHints = _brands(navigator);
    if (fromHints != null) {
      final named = browserFromBrands(fromHints);
      if (named != null) return named;
    }
    final agent =
        navigator.getProperty<JSString?>('userAgent'.toJS)?.toDart ?? '';
    return browserFromUserAgent(agent);
  } catch (_) {
    // A locked-down embedding, a `navigator` shape nobody predicted. Naming the
    // browser is not worth failing a crash report over — and this runs inside
    // the reporter, where the first rule is that reporting must never throw.
    return null;
  }
}

/// `navigator.userAgentData.brands` as plain Dart pairs, or null where the API
/// is not there — Firefox, Safari, and any Chromium on an insecure origin.
///
/// Deliberately the only thing in this file that touches JavaScript. Everything
/// that could be *wrong* about the answer is in [browserFromBrands], on the
/// other side of a list of records, where a VM test can reach it.
List<(String, String)>? _brands(JSObject navigator) {
  final data = navigator.getProperty<JSObject?>('userAgentData'.toJS);
  if (data == null) return null;
  final brands = data.getProperty<JSArray<JSObject>?>('brands'.toJS);
  if (brands == null) return null;
  return [
    for (final entry in brands.toDart)
      (
        entry.getProperty<JSString?>('brand'.toJS)?.toDart ?? '',
        entry.getProperty<JSString?>('version'.toJS)?.toDart ?? '',
      ),
  ];
}
