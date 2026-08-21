import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/browser_photo_import_service.dart';
import 'package:songbook_app/domain/services/import_notice.dart';
import 'package:songbook_app/domain/services/page_text_recognizer.dart';
import 'package:songbook_app/domain/services/photo_import_service.dart';
import 'package:songbook_app/domain/services/photo_text_bridge.dart';

/// Reading a photographed chord sheet without a server.
///
/// The recognizer itself is the browser's — Tesseract in a web worker, which no
/// VM test can run — so it is faked here and everything around it is real: the
/// same [PhotoTextBridge] the app uses, the same [PhotoImportPayload] the
/// screen consumes. What these pin is the wiring, which is the part that was
/// missing while both halves already worked.
class _FakeRecognizer implements PageTextRecognizer {
  _FakeRecognizer(this.words, {this.error, this.notices = const []});

  final List<OcrWord> words;
  final Object? error;

  /// What the real recognizer reports about the image rather than the words -
  /// a photograph too compressed to hold its accents, show-through erased.
  final List<ImportNotice> notices;

  int calls = 0;
  Uint8List? sawBytes;
  String? sawLanguage;

  @override
  bool get isSupported => true;

  @override
  Future<PageWords> recognize(Uint8List imageBytes,
      {String language = PageTextRecognizer.hungarian}) async {
    calls++;
    sawBytes = imageBytes;
    sawLanguage = language;
    if (error != null) throw error!;
    return PageWords(words, notices: notices);
  }
}

void main() {
  /// One OCR row, on the 10px grid the bridge's own tests use.
  List<OcrWord> row(double y, double height,
          List<(String, double, double)> tokens) =>
      [
        for (final (text, x0, x1) in tokens)
          OcrWord(text: text, x0: x0, y0: y, x1: x1, y1: y + height),
      ];

  final page = row(70, 16, [('G', 0, 10), ('C', 180, 190)]) +
      row(100, 20, [
        ('Az', 0.0, 20.0),
        ('Úrra', 30.0, 70.0),
        ('bízom', 80.0, 130.0),
        ('életem', 180.0, 240.0),
      ]);

  final bytes = Uint8List.fromList(const [1, 2, 3]);

  test('a read page comes back as ChordPro the app can already parse',
      () async {
    final recognizer = _FakeRecognizer(page);
    final service = BrowserPhotoImportService(recognizer: recognizer);

    final payload = await service.extract(bytes, fileName: 'song.jpg');

    expect(recognizer.calls, 1);
    expect(recognizer.sawBytes, same(bytes));
    // Hungarian, and it matters more than it looks: the songbook is Hungarian,
    // and the wrong model reads `ő` as `6` and `ű` as `ii` — a page of
    // mangled words rather than a visible failure.
    expect(recognizer.sawLanguage, 'hun');
    expect(payload, isA<ChordProPayload>());
    final lines = (payload as ChordProPayload).text.split('\n');
    // The chords row over the lyric row, each chord above its own word.
    expect(lines.first.contains('G'), isTrue);
    expect(lines.first.indexOf('G'), lines.last.indexOf('Az'));
    expect(lines.first.indexOf('C'), lines.last.indexOf('életem'));
  });

  test('the bridge\'s warnings travel with the text', () async {
    // A German H is renamed to B on the way in — the songbook prints H for B
    // natural — and the reviewer is told, because it is a change to what the
    // page said.
    final service = BrowserPhotoImportService(
      recognizer: _FakeRecognizer(
        row(70, 16, [('H', 0, 10), ('C', 180, 190)]) +
            row(100, 20, [
              ('Az', 0.0, 20.0),
              ('Úrra', 30.0, 70.0),
              ('bízom', 80.0, 130.0),
              ('életem', 180.0, 240.0),
            ]),
      ),
    );

    final payload = await service.extract(bytes);

    expect(payload.notices, isNotEmpty);
  });

  test('an empty image is refused before the engine is started', () async {
    final recognizer = _FakeRecognizer(page);
    final service = BrowserPhotoImportService(recognizer: recognizer);

    await expectLater(
      () => service.extract(Uint8List(0)),
      throwsA(isA<PhotoImportException>()),
    );
    expect(recognizer.calls, 0);
  });

  test('a page with nothing legible on it says so, rather than saving an '
      'empty song', () async {
    final service =
        BrowserPhotoImportService(recognizer: _FakeRecognizer(const []));

    await expectLater(
      () => service.extract(bytes),
      throwsA(isA<PhotoImportException>().having(
        (e) => e.notice?.code,
        'notice',
        // Carried as a code, not only as a sentence: this one is shown to the
        // user, and the screen has to be able to say it in Hungarian.
        ImportNoticeCode.photoNothingLegible,
      )),
    );
  });

  test("what the recognizer says about the image reaches the review screen",
      () async {
    // The two the app measured and then threw away. `low-resolution` is the
    // single biggest lever on accuracy and the fix is on the phone rather than
    // in this app, so it is worth a sentence; show-through removal costs stroke
    // sharpness, so a chord missing from a page that raised it is worth a
    // second photograph rather than a bug report.
    const fromImage = [
      ImportNotice(ImportNoticeCode.photoLowResolution,
          text: '1532×2047', count: 106),
      ImportNotice(ImportNoticeCode.photoShowThroughRemoved),
    ];
    final service = BrowserPhotoImportService(
      recognizer: _FakeRecognizer(page, notices: fromImage),
    );

    final payload = await service.extract(bytes);

    // First, and in this order: "that photo is too compressed" explains the
    // wrong letters under it and reads oddly after them.
    expect(payload.notices.take(2), fromImage);
  });

  test('an engine that will not start reads as a failed import, not a crash',
      () async {
    final service = BrowserPhotoImportService(
      recognizer: _FakeRecognizer(const [], error: StateError('no wasm')),
    );

    await expectLater(
      () => service.extract(bytes),
      throwsA(isA<PhotoImportException>()),
    );
  });

  test('a recognizer that already speaks the contract is not re-wrapped',
      () async {
    const said = 'Reading photos needs the web version of Songbook.';
    final service = BrowserPhotoImportService(
      recognizer:
          _FakeRecognizer(const [], error: const PhotoImportException(said)),
    );

    await expectLater(
      () => service.extract(bytes),
      throwsA(isA<PhotoImportException>()
          .having((e) => e.message, 'message', said)),
    );
  });
}
