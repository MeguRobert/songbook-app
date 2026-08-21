import 'dart:typed_data';

import 'import_notice.dart';
import 'photo_text_bridge.dart';

/// What a recogniser saw: the words, and anything worth saying about the
/// photograph itself.
///
/// The notices are here rather than in [PhotoTextBridge] because only this
/// stage has the pixels. Whether the upload is too compressed to hold an `ő`,
/// and whether the reverse side of the page had to be erased before reading,
/// are facts about the image — and both were measured here and then silently
/// dropped, which is why the app never warned about either while the Python
/// worker did.
class PageWords {
  final List<OcrWord> words;
  final List<ImportNotice> notices;

  const PageWords(this.words, {this.notices = const []});
}

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
  Future<PageWords> recognize(
    Uint8List imageBytes, {
    String language = hungarian,
  });
}
