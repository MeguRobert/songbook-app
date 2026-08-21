import 'dart:typed_data';

import 'page_text_recognizer.dart';
import 'photo_import_service.dart';
import 'photo_text_bridge.dart';

/// Reads a photographed chord sheet on the device, with no server at all.
///
/// This is the common case and the default one: a hymnal page is words with
/// chord names above them, and reading that needs text OCR, not music
/// recognition. Measured on a real photograph of song 149, the browser engine
/// found **4 of 4 chord rows in about two seconds** and got `Ő` right, where the
/// server engine it replaces managed 3 of 4 in forty seconds and returned `Ó`.
/// Faster, more accurate, free, and it works with no network — so there is no
/// version of this worth paying to host.
///
/// Everything below the recognizer is shared with the server path:
/// [PhotoTextBridge] turns boxes back into chords-over-lyrics, and the result
/// is a [ChordProPayload] like any other, so the import screen needs no idea
/// which engine answered.
class BrowserPhotoImportService implements PhotoImportService {
  const BrowserPhotoImportService({
    required this.recognizer,
    this.bridge = const PhotoTextBridge(),
  });

  final PageTextRecognizer recognizer;
  final PhotoTextBridge bridge;

  @override
  Future<PhotoImportPayload> extract(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    if (imageBytes.isEmpty) {
      throw const PhotoImportException('That image is empty.');
    }

    final PageWords read;
    try {
      read = await recognizer.recognize(imageBytes);
    } on PhotoImportException {
      // Already a sentence meant for the person holding the phone.
      rethrow;
    } catch (_) {
      // A missing engine, a blocked download, an image the browser refused to
      // decode. One situation from the user's side: it did not read.
      //
      // The cause is deliberately not appended. These arrive as JavaScript
      // objects, and interpolating one put "[object Object]" — or a raw
      // TypeError — in front of somebody holding a phone.
      throw const PhotoImportException(
        'That photo could not be read. Try again, or type the words in.',
      );
    }

    final reading = bridge.read(read.words);
    if (reading.chordPro.trim().isEmpty) {
      // The bridge names an unreadable page better than this can - it knows
      // whether it saw nothing at all or nothing it could lay out. The code is
      // carried alongside the sentence so the screen can say it in the language
      // it is being read in; the sentence stays as the fallback for a caller
      // that has no localisations, which the measurement harness does not.
      throw PhotoImportException(
        'Nothing could be read from that photo.',
        notice: reading.notices.isNotEmpty ? reading.notices.first : null,
      );
    }

    // The image's own notices first: "that photo is too compressed" explains
    // the wrong letters below it, and reads oddly after them.
    return ChordProPayload(reading.chordPro,
        notices: [...read.notices, ...reading.notices]);
  }
}
