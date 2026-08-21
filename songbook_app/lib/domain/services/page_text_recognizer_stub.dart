import 'dart:typed_data';

import 'page_text_recognizer.dart';
import 'photo_import_service.dart';

/// The recognizer on a platform that has no browser to run one in.
///
/// Reachable only if something offers the feature without asking
/// [PageTextRecognizer.isSupported] first, so it throws the same exception the
/// import screen already knows how to display rather than crashing.
PageTextRecognizer createPageTextRecognizer() =>
    const _UnsupportedPageTextRecognizer();

class _UnsupportedPageTextRecognizer implements PageTextRecognizer {
  const _UnsupportedPageTextRecognizer();

  @override
  bool get isSupported => false;

  @override
  Future<PageWords> recognize(
    Uint8List imageBytes, {
    String language = PageTextRecognizer.hungarian,
  }) async {
    throw const PhotoImportException(
      'This version of Songbook cannot read a photo by itself. '
      'Open the app in a browser, or set up a service in Settings.',
    );
  }
}
