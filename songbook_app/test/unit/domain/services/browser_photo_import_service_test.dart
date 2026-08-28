import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/browser_photo_import_service.dart';
import 'package:songbook_app/domain/services/image_format.dart';
import 'package:songbook_app/domain/services/import_notice.dart';
import 'package:songbook_app/domain/services/page_text_recognizer.dart';
import 'package:songbook_app/domain/services/photo_import_diagnostics.dart';
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
  _FakeRecognizer(this.words,
      {this.error, this.notices = const [], this.measurements = const []});

  final List<OcrWord> words;
  final Object? error;

  /// What the real recognizer reports about the image rather than the words -
  /// a photograph too compressed to hold its accents, show-through erased.
  final List<ImportNotice> notices;

  /// What the real recognizer appends to `trace` as it goes. Until the service
  /// passed the argument, every one of these numbers was computed and dropped.
  final List<Map<String, Object?>> measurements;

  int calls = 0;
  Uint8List? sawBytes;
  String? sawLanguage;

  /// Whether a sink to measure into was handed over at all. Null here was the
  /// bug: every stage of the reader checks `trace?.add` and does nothing when
  /// there is nothing to add to.
  List<Map<String, Object?>>? sawTrace;

  @override
  bool get isSupported => true;

  @override
  Future<PageWords> recognize(Uint8List imageBytes,
      {String language = PageTextRecognizer.hungarian,
      List<Map<String, Object?>>? trace}) async {
    calls++;
    sawBytes = imageBytes;
    sawLanguage = language;
    sawTrace = trace;
    // Appended before any failure, exactly as the real one does: the image's
    // dimensions are known long before the engine gives up on it.
    for (final entry in measurements) {
      trace?.add(entry);
    }
    if (error != null) throw error!;
    return PageWords(words, notices: notices);
  }
}

/// Collects what would have been written, so the whole path can be asserted on
/// with no reporter, no Supabase and no network anywhere near it.
class _RecordingRecorder extends PhotoImportRecorder {
  final List<PhotoImportRecord> records = [];

  @override
  void record(PhotoImportRecord record) => records.add(record);
}

/// Fails the way a misconfigured sink would.
class _ThrowingRecorder extends PhotoImportRecorder {
  @override
  void record(PhotoImportRecord record) => throw StateError('no sink');
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
    // `low-resolution` is the single biggest lever on accuracy and the fix is
    // on the phone rather than in this app, so it is worth a sentence. The
    // recogniser is the only stage that can raise it, because it is the only
    // one holding the image.
    const fromImage = [
      ImportNotice(ImportNoticeCode.photoLowResolution,
          text: '1532×2047', count: 106),
    ];
    final service = BrowserPhotoImportService(
      recognizer: _FakeRecognizer(page, notices: fromImage),
    );

    final payload = await service.extract(bytes);

    // First: "that photo is too compressed" explains the wrong letters under it
    // and reads oddly after them.
    expect(payload.notices.take(1), fromImage);
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

  // ---------------------------------------------------------------------------
  // One row per attempt
  // ---------------------------------------------------------------------------
  // `page_text_recognizer_web.dart` measures the image's dimensions and
  // bytes-per-pixel, the pale fraction and whether show-through suppression
  // fired, the whole-page word count and each column's — and threads every one
  // of them through a `trace` argument this service never passed. So the app's
  // account of why a page read the way it did was of the Python engine that does
  // not run on a phone.
  group('the record of an attempt', () {
    /// A slice of what the real reader appends.
    const measured = [
      {
        'stage': 'image',
        'width': 2048,
        'height': 1532,
        'bytes': 286123,
        'bytesPerPixel': 0.0912,
      },
      {'stage': 'clean', 'paleFraction': 0.0139, 'suppressed': true},
      {'stage': 'read', 'words': 41, 'columnCuts': <int>[]},
    ];

    test('the trace argument is actually passed, and what it collects is kept',
        () async {
      final recognizer = _FakeRecognizer(page, measurements: measured);
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: recognizer,
        recorder: recorder,
      );

      await service.extract(bytes);

      // The one-line fix this group exists for.
      expect(recognizer.sawTrace, isNotNull,
          reason: 'without a list to append to, every stage measures into null');
      expect(recorder.records, hasLength(1));

      final details = recorder.records.single.toDetails();
      expect(details['outcome'], 'ok');
      expect(details['width'], 2048);
      expect(details['bytesPerPixel'], 0.0912);
      expect(details['words'], 41);
      expect(details['suppressed'], true);
      expect(details['ms'], isA<int>());
    });

    test('a page nothing could be laid out from is not the same failure as a '
        'reader that never ran', () async {
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(const [], measurements: measured),
        recorder: recorder,
      );

      await expectLater(
          () => service.extract(bytes), throwsA(isA<PhotoImportException>()));

      // `illegible`, not `failed`: the engine answered. The photograph is the
      // problem, and "take it again" is the right thing to say — which it is not
      // when the reader itself never loaded.
      expect(recorder.records.single.outcome, PhotoImportOutcome.illegible);
      // And the image's own numbers are still there, which is what makes the
      // advice checkable: a page that measured 900px was always going to fail.
      expect(recorder.records.single.toDetails()['width'], 2048);
    });

    test('an empty file is recorded as refused, before the engine is started',
        () async {
      final recognizer = _FakeRecognizer(page);
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: recognizer,
        recorder: recorder,
      );

      await expectLater(() => service.extract(Uint8List(0)),
          throwsA(isA<PhotoImportException>()));

      expect(recognizer.calls, 0);
      expect(recorder.records.single.outcome, PhotoImportOutcome.refused);
    });

    test('the raw cause is kept even though the user is shown a sentence',
        () async {
      // The catch that substitutes the friendly sentence was also the catch that
      // threw away the only description of what happened. Both are now true at
      // once: the user gets prose, the record gets the TypeError.
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(const [],
            error: StateError('TypeError: t.recognize is not a function'),
            measurements: measured),
        recorder: recorder,
      );

      await expectLater(
        () => service.extract(bytes),
        throwsA(isA<PhotoImportException>().having((e) => e.message, 'message',
            contains('could not be read'))),
      );

      final record = recorder.records.single;
      expect(record.outcome, PhotoImportOutcome.failed);
      expect(record.reason, isNotNull);
      expect(record.toDetails()['reason'], isNotEmpty);
    });

    test('which stage timed out survives the one sentence all three share',
        () async {
      // The script budget (30s), the engine budget (120s) and the read budget
      // (60s) all collapse into "Reading the photo took too long", which is
      // right for the screen. `stage` is the same three told apart, and a
      // download blocked by a DNS filter is a different morning's work from an
      // engine that would not start.
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(const [],
            error: const PhotoImportException(
              'The reader could not be downloaded.',
              stage: 'script:blocked',
            )),
        recorder: recorder,
      );

      await expectLater(
          () => service.extract(bytes), throwsA(isA<PhotoImportException>()));

      final record = recorder.records.single;
      expect(record.stage, 'script:blocked');
      expect(record.summary, contains('script:blocked'));
    });

    test('the notices the reviewer was shown are on the record too', () async {
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(page,
            notices: const [
              ImportNotice(ImportNoticeCode.photoLowResolution,
                  text: '1532×2047', count: 106),
            ],
            measurements: measured),
        recorder: recorder,
      );

      await service.extract(bytes);

      // Codes only. The prose lives in the ARB files, and the text a notice
      // carries can be a fragment of the song.
      expect(recorder.records.single.toDetails()['notices'],
          contains('photoLowResolution'));
    });

    test('no recorder means no recording, and no behaviour change', () async {
      // The default, and what every widget test and the measurement harness get.
      final recognizer = _FakeRecognizer(page, measurements: measured);
      final service = BrowserPhotoImportService(recognizer: recognizer);

      final payload = await service.extract(bytes);

      expect(payload, isA<ChordProPayload>());
      // The trace is still passed and still filled; it simply goes nowhere. Not
      // worth branching on: the list costs one allocation and the alternative is
      // a reader that behaves differently depending on whether it is watched.
      expect(recognizer.sawTrace, isNotNull);
    });

    test('a recorder that throws does not fail an import that worked',
        () async {
      // The rule from the crash reporter's own header: recording a failure must
      // never cause one. It matters most here, on the success path, where a page
      // that read perfectly would otherwise come back as a failed import.
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(page),
        recorder: _ThrowingRecorder(),
      );

      expect(await service.extract(bytes), isA<ChordProPayload>());
    });
  });

  group('what the upload was', () {
    /// The same trace a real single-column read appends, so a success path here
    /// records exactly what one does in the group above.
    const measured = [
      {
        'stage': 'image',
        'width': 2048,
        'height': 1532,
        'bytes': 286123,
        'bytesPerPixel': 0.0912,
        'scale': 1.0,
        'canvasWidth': 2048,
        'canvasHeight': 1532,
      },
      {'stage': 'clean', 'paleFraction': 0.0139, 'suppressed': true},
      {'stage': 'read', 'words': 41, 'columnCuts': <int>[]},
    ];

    /// A HEIC header, the way a phone with "high efficiency" storage on writes
    /// one. Twelve bytes is all the sniff reads.
    final heic = Uint8List.fromList([
      0x00, 0x00, 0x00, 0x18, // box length
      0x66, 0x74, 0x79, 0x70, // 'ftyp'
      0x68, 0x65, 0x69, 0x63, // 'heic'
      ...List.filled(32, 0),
    ]);

    test('the format is on the record even when the decode never ran',
        () async {
      // The whole reason it is sniffed in the service and not in the
      // recogniser. A container the browser will not open throws inside
      // `createImageBitmap`, so the recogniser appends nothing at all - and the
      // one measurement that says which of two very different faults this was
      // would go missing on exactly the failure it exists to explain.
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(const [],
            error: const PhotoImportException(
              'InvalidStateError: The source image could not be decoded.',
              stage: 'decode',
              notice: ImportNotice(ImportNoticeCode.photoCouldNotDecode),
            )),
        recorder: recorder,
      );

      await expectLater(
          () => service.extract(heic), throwsA(isA<PhotoImportException>()));

      final record = recorder.records.single;
      expect(record.format, ImageFormat.heic);
      expect(record.stage, 'decode');
      expect(record.bytes, heic.length);
      final details = record.toDetails();
      expect(details['format'], 'heic');
      expect(details['bytes'], heic.length);
      // No width, no height, no bytesPerPixel: nothing measured them, and an
      // invented zero would read as a decoded image of no size.
      expect(details.containsKey('width'), isFalse);
    });

    test('a HEIC that libheif opened reads like any other photograph',
        () async {
      // The point of the whole change, asserted at the layer that files the
      // row: a phone with "high efficiency" storage on now produces an `ok`
      // import, and the record still says the file was a HEIC and that the
      // second decoder is what opened it.
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(page, measurements: [
          {'stage': 'heif', 'decoded': true, 'ms': 412},
          ...measured,
        ]),
        recorder: recorder,
      );

      final payload = await service.extract(heic);

      expect(payload, isA<ChordProPayload>());
      final record = recorder.records.single;
      expect(record.outcome, PhotoImportOutcome.ok);
      expect(record.format, ImageFormat.heic);
      final details = record.toDetails();
      expect(details['heifDecoded'], true);
      expect(details['heifMs'], 412);
    });

    test('a HEIC libheif could not open ends where it ended before', () async {
      // Degrade, never regress. A rescue that fails has to leave the user on
      // the path they were already on - the same notice, the same sentence -
      // and leave behind the one fact that says a rescue was tried at all.
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(
          const [],
          measurements: const [
            {
              'stage': 'heif',
              'decoded': false,
              'ms': 88,
              'why': 'heif:pixels',
            },
          ],
          error: const PhotoImportException(
            'InvalidStateError: The source image could not be decoded.',
            stage: 'decode',
            notice: ImportNotice(ImportNoticeCode.photoCouldNotDecode),
          ),
        ),
        recorder: recorder,
      );

      await expectLater(
        () => service.extract(heic),
        throwsA(isA<PhotoImportException>().having((e) => e.notice?.code,
            'notice', ImportNoticeCode.photoCouldNotDecode)),
      );

      final details = recorder.records.single.toDetails();
      expect(details['outcome'], 'failed');
      expect(details['format'], 'heic');
      expect(details['heifDecoded'], false);
      expect(details['heifStage'], 'heif:pixels');
    });

    test('a decode failure is a different sentence from an unreadable page',
        () async {
      // "Try again" is the advice for a page nothing could be read from, and it
      // is the one thing that cannot work here: the file never opened, so the
      // same photograph produces the same refusal for ever. The screen renders
      // the notice in place of the message - see ImportNoticeText.
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(const [],
            error: const PhotoImportException(
              'InvalidStateError: The source image could not be decoded.',
              stage: 'decode',
              notice: ImportNotice(ImportNoticeCode.photoCouldNotDecode),
            )),
      );

      await expectLater(
        () => service.extract(heic),
        throwsA(isA<PhotoImportException>().having(
            (e) => e.notice?.code, 'notice', ImportNoticeCode.photoCouldNotDecode)),
      );
    });

    test('every outcome carries it, not only the failures', () async {
      // A row that only says `jpeg` when something went wrong cannot answer
      // "does this ever work on that phone?" - which is the question a format
      // column is for.
      final recorder = _RecordingRecorder();
      final jpeg = Uint8List.fromList(
          [0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(32, 0)]);
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(page, measurements: measured),
        recorder: recorder,
      );

      await service.extract(jpeg);

      final record = recorder.records.single;
      expect(record.outcome, PhotoImportOutcome.ok);
      expect(record.format, ImageFormat.jpeg);
      expect(record.bytes, jpeg.length);
    });

    test('an empty file is recorded with a format too', () async {
      // The refusal happens after the sniff, so the row still says what it was
      // handed - `unknown`, which is the true answer for no bytes.
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(page),
        recorder: recorder,
      );

      await expectLater(() => service.extract(Uint8List(0)),
          throwsA(isA<PhotoImportException>()));

      expect(recorder.records.single.format, ImageFormat.unknown);
    });

    test('nothing about the file name reaches the record', () async {
      // The rule for this table: measurements only. A name is content, and a
      // photograph of the wrong thing is named after it.
      final recorder = _RecordingRecorder();
      final service = BrowserPhotoImportService(
        recognizer: _FakeRecognizer(page, measurements: measured),
        recorder: recorder,
      );

      await service.extract(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, ...List.filled(32, 0)]),
          fileName: 'private-holiday-photo.jpg');

      final encoded = recorder.records.single.toDetails().toString();
      expect(encoded, isNot(contains('private')));
      expect(encoded, isNot(contains('.jpg')));
    });
  });
}
