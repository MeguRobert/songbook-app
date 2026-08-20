import 'dart:typed_data';

import 'photo_text_bridge.dart';

/// Reads the words off a photographed page.
///
/// An interface with one real implementation, because that implementation
/// cannot exist everywhere: the engine is Tesseract compiled to WebAssembly,
/// running in a web worker the browser owns. On any other platform there is
/// nothing here to run, and a test on the Dart VM must be able to say what the
/// engine returned without starting one.
///
/// Boxes come back in the pixels of whatever image was actually read, which may
/// be a scaled copy of what was handed in. That is harmless: [PhotoTextBridge]
/// only ever compares words with one another.
abstract class PageTextRecognizer {
  /// The songbook is Hungarian, so this is the language that matters. Passing
  /// the wrong one is not a small penalty — `ő` and `ű` come back as `6` and
  /// `ii` without the Hungarian model.
  static const hungarian = 'hun';

  /// Whether this build can read a photo locally at all.
  ///
  /// Asked before the feature is offered, so a platform without an engine says
  /// so instead of failing on tap.
  bool get isSupported;

  /// The words in [imageBytes], with their boxes in image pixels.
  Future<List<OcrWord>> recognize(
    Uint8List imageBytes, {
    String language = hungarian,
  });
}
