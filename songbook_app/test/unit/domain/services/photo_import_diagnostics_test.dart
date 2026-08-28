import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/crash_reporter.dart';
import 'package:songbook_app/domain/services/diagnostic_photo_import_recorder.dart';
import 'package:songbook_app/domain/services/image_format.dart';
import 'package:songbook_app/domain/services/import_notice.dart';
import 'package:songbook_app/domain/services/photo_import_diagnostics.dart';

/// What the transport was asked to send.
class _RecordingSink extends CrashReporter {
  final List<CrashReport> received = [];

  @override
  Future<void> report(CrashReport report) async => received.add(report);
}

void main() {
  /// The trace a real two-column read produces, in the order the recogniser
  /// appends it. Copied from the `trace?.add` calls in
  /// `page_text_recognizer_web.dart` rather than invented, because the point of
  /// these tests is that the numbers the reader already measured arrive intact.
  List<Map<String, Object?>> traceOf({int columns = 1}) => [
        {
          'stage': 'image',
          'width': 2048,
          'height': 1532,
          'bytes': 286123,
          'bytesPerPixel': 0.09123456789,
          'scale': 1.0,
          'canvasWidth': 2048,
          'canvasHeight': 1532,
        },
        {'stage': 'clean', 'paleFraction': 0.0139482, 'suppressed': true},
        {
          'stage': 'read',
          'words': 41,
          'columnCuts': [for (var i = 1; i < columns; i++) i * 500],
        },
        for (var i = 0; i < columns; i++)
          {'stage': 'column', 'x0': i * 500, 'x1': (i + 1) * 500, 'words': 20},
        if (columns > 1) {'stage': 'columns', 'words': 47},
      ];

  group('PhotoImportRecord.toDetails', () {
    test('carries the numbers the reader measured and then threw away', () {
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.ok,
        elapsed: const Duration(milliseconds: 2140),
        trace: traceOf(),
      ).toDetails();

      expect(details['outcome'], 'ok');
      expect(details['ms'], 2140);
      expect(details['width'], 2048);
      expect(details['height'], 1532);
      expect(details['bytes'], 286123);
      expect(details['words'], 41);
      expect(details['suppressed'], true);

      // Rounded, because six decimal places of a ratio is noise and the gate it
      // is compared against (_minBytesPerPixel, 0.08) has two.
      expect(details['bytesPerPixel'], 0.0912);
      expect(details['paleFraction'], 0.0139);
    });

    test('what the page was actually read at is on the record', () {
      // The source dimensions alone were unreadable evidence: 1080x12000 says
      // nothing about whether the engine was handed a page or a 184-pixel
      // stripe, and that difference was the whole fault.
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.ok,
        elapsed: const Duration(milliseconds: 2140),
        trace: [
          {
            'stage': 'image',
            'width': 1080,
            'height': 12000,
            'bytes': 1977062,
            'bytesPerPixel': 0.1525,
            'scale': 0.49266,
            'canvasWidth': 532,
            'canvasHeight': 5912,
          },
        ],
      ).toDetails();

      expect(details['width'], 1080);
      expect(details['height'], 12000);
      expect(details['scale'], 0.4927, reason: 'rounded like every other ratio');
    });

    test('the format and the size survive a decode that measured nothing', () {
      // The row the live app actually produced: 107ms, a reason, and nothing
      // else at all, because the throw happened before the recogniser appended
      // its first entry. These two are what a caller can supply from bytes it
      // already holds, and they are the pair that tells a HEIC from an image
      // too large for the phone to open.
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.failed,
        elapsed: const Duration(milliseconds: 107),
        bytes: 4112118,
        format: ImageFormat.heic,
        stage: 'decode',
        reason: 'InvalidStateError: The source image could not be decoded.',
      ).toDetails();

      expect(details['format'], 'heic');
      expect(details['bytes'], 4112118);
      expect(details['stage'], 'decode');
      expect(details.containsKey('width'), isFalse,
          reason: 'nothing measured it, and a zero would read as a decode');
    });

    test('a HEIC the app opened itself says so, and says what it cost', () {
      // The rescue is invisible from every other column. `format: heic` says
      // the phone wrote one; only this pair says whether the browser opened it
      // or libheif did, and how long the second attempt took - which is the
      // number that decides whether a megabyte of WebAssembly on a phone is
      // worth what it buys.
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.ok,
        elapsed: const Duration(milliseconds: 3120),
        bytes: 4112118,
        format: ImageFormat.heic,
        trace: [
          {'stage': 'heif', 'decoded': true, 'ms': 412},
          ...traceOf(),
        ],
      ).toDetails();

      expect(details['heifDecoded'], true);
      expect(details['heifMs'], 412);
      expect(details.containsKey('heifStage'), isFalse,
          reason: 'nothing failed, so there is no stage to name');
      // Ahead of everything the decode measured, for the same reason `format`
      // is: on the failure below there is nothing else at all.
      final keys = details.keys.toList();
      expect(keys.indexOf('heifDecoded'), lessThan(keys.indexOf('width')));
    });

    test('a rescue that failed names its stage and measures nothing else', () {
      // What the live row would now look like for the Redmi that started this:
      // 107ms of native decode, then a library that could not be reached.
      // `heifStage` is what separates a phone with no network from a deploy
      // that did not carry web/libheif/ from a file libheif itself refused.
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.failed,
        elapsed: const Duration(milliseconds: 30119),
        bytes: 4112118,
        format: ImageFormat.heic,
        stage: 'decode',
        reason: 'InvalidStateError: The source image could not be decoded.',
        trace: const [
          {
            'stage': 'heif',
            'decoded': false,
            'ms': 30012,
            'why': 'heif:timeout',
          },
        ],
      ).toDetails();

      expect(details['heifDecoded'], false);
      expect(details['heifMs'], 30012);
      expect(details['heifStage'], 'heif:timeout');
      expect(details.containsKey('width'), isFalse,
          reason: 'no pixels were ever read, on either attempt');
    });

    test('an import that never touched libheif records nothing about it', () {
      // A JPEG, which is every photograph in the measurement corpus and almost
      // every photograph a user takes. No sniff, no script, no keys.
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.ok,
        elapsed: const Duration(milliseconds: 2140),
        format: ImageFormat.jpeg,
        trace: traceOf(),
      ).toDetails();

      expect(details.keys.where((key) => key.startsWith('heif')), isEmpty);
    });

    test('the stage token is a token, not the library talking', () {
      // libheif prints its own diagnosis - "Invalid input: Unexpected end of
      // file: Extent in iloc..." - to the console, and that string names a byte
      // offset in the user's photograph. `details` takes this file's own token
      // instead: a fixed vocabulary plus, for one of them, an HTTP status.
      for (final why in const [
        'heif:timeout',
        'heif:error',
        'heif:blocked',
        'heif:start',
        'heif:missing',
        'heif:empty',
        'heif:pixels',
        'heif:size',
        'heif:wasm:404',
      ]) {
        final details = PhotoImportRecord(
          outcome: PhotoImportOutcome.failed,
          elapsed: Duration.zero,
          trace: [
            {'stage': 'heif', 'decoded': false, 'ms': 12, 'why': why},
          ],
        ).toDetails();
        expect(details['heifStage'], matches(RegExp(r'^[a-z:0-9]+$')));
      }
    });

    test('the format is an enum name and never anything a user typed', () {
      // `details` holds measurements. Every value here is a number, a boolean
      // or the name of an enum this repo defines - which is what makes the
      // table safe for a moderator to read and an anonymous client to write.
      for (final format in ImageFormat.values) {
        final details = PhotoImportRecord(
          outcome: PhotoImportOutcome.failed,
          elapsed: Duration.zero,
          format: format,
        ).toDetails();
        expect(details['format'], format.name);
        expect(details['format'], matches(RegExp(r'^[a-zA-Z]+$')));
      }
    });

    test('a caller that says the size wins over the trace saying it again', () {
      // Same number from both places - the upload's length - so the head is
      // where it belongs: the clamp eats from the end, and the trace-derived
      // copy is the one that can be dropped.
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.ok,
        elapsed: Duration.zero,
        bytes: 286123,
        trace: traceOf(),
      ).toDetails();

      expect(details['bytes'], 286123);
      expect(details.keys.toList().indexOf('bytes'),
          lessThan(details.keys.toList().indexOf('width')));
    });

    test('the outcome comes first, because the clamp eats from the end', () {
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.failed,
        elapsed: const Duration(milliseconds: 31000),
        stage: 'script:timeout',
        reason: 'PhotoImportException: The reader could not be downloaded.',
        trace: traceOf(),
      ).toDetails();

      // Order is load-bearing rather than cosmetic: CrashReport clamps by
      // dropping trailing keys, so the first entry is the one that survives a
      // details object that has grown too big.
      expect(details.keys.first, 'outcome');
      expect(details.keys.elementAt(1), 'ms');
      expect(details.keys.last, 'reason',
          reason: 'the only prose in here is the right thing to lose first');
    });

    test('a multi-column page is counted, not enumerated', () {
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.ok,
        elapsed: Duration.zero,
        trace: traceOf(columns: 3),
      ).toDetails();

      // Two cuts make three columns. The per-column entries are deliberately not
      // lifted: the count is the diagnostic value, and one entry per column is
      // the part of the trace that grows without a bound.
      expect(details['columns'], 3);
      expect(details['columnWords'], 47);
    });

    test('the same notice raised once per column is recorded once', () {
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.ok,
        elapsed: Duration.zero,
        notices: const [
          ImportNotice(ImportNoticeCode.photoGermanNoteNames, text: 'H'),
          ImportNotice(ImportNoticeCode.photoGermanNoteNames, text: 'B'),
          ImportNotice(ImportNoticeCode.photoLowResolution,
              text: '1532×2047', count: 106),
        ],
      ).toDetails();

      expect(details['notices'],
          ['photoGermanNoteNames', 'photoLowResolution']);
    });

    test('records no content, whatever the notices were carrying', () {
      // The notice codes go in; the text they carry does not. A notice's `text`
      // is the offending source — a chord token, a page size, a parser's own
      // words — and one of those is a fragment of the song.
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.illegible,
        elapsed: Duration.zero,
        notices: const [
          ImportNotice(ImportNoticeCode.bracketNotAChord,
              line: 4, text: 'Áldott legyen az Úr'),
        ],
      ).toDetails();

      expect(details.toString(), isNot(contains('Áldott')));
    });

    test('a reason longer than the field is cut, not dropped', () {
      final details = PhotoImportRecord(
        outcome: PhotoImportOutcome.failed,
        elapsed: Duration.zero,
        reason: 'TypeError: ${'x' * 900}',
      ).toDetails();

      expect((details['reason'] as String).length, 300);
    });

    test('names the stage in the summary, since the console prints only that',
        () {
      expect(
        const PhotoImportRecord(
          outcome: PhotoImportOutcome.failed,
          elapsed: Duration.zero,
          stage: 'script:blocked',
        ).summary,
        'photo import: failed at script:blocked',
      );
      expect(
        const PhotoImportRecord(
          outcome: PhotoImportOutcome.ok,
          elapsed: Duration.zero,
        ).summary,
        'photo import: ok',
      );
    });
  });

  group('DiagnosticPhotoImportRecorder', () {
    test('writes a photo_import row carrying the build the app is running', () {
      final sink = _RecordingSink();
      final reporter = ThrottledCrashReporter(sinks: [sink]);
      reporter.context
        ..route = '/import'
        ..appVersion = '1.1.0'
        ..buildNumber = '143'
        ..locale = 'hu';

      DiagnosticPhotoImportRecorder(reporter).record(PhotoImportRecord(
        outcome: PhotoImportOutcome.ok,
        elapsed: const Duration(milliseconds: 2140),
        trace: traceOf(),
      ));

      expect(sink.received, hasLength(1));
      final report = sink.received.single;
      expect(report.event, DiagnosticEvent.photoImport);
      // Item 1 of the logging handoff, and the reason it came first: a row that
      // cannot be tied to a build cannot be tied to a release, and then every
      // report is about an unknown version.
      expect(report.buildNumber, '143');
      expect(report.appVersion, '1.1.0');
      expect(report.route, '/import');
      expect(report.locale, 'hu');
      expect(report.details['ms'], 2140);
      expect(report.stack, isNull, reason: 'nothing threw, so there is no stack');
    });

    test('an evening of importing is all recorded, where a crash storm would '
        'have been throttled', () {
      // Five successful imports share one fingerprint, and under the crash
      // ceiling — two per fingerprint per ten minutes — three of them would have
      // vanished and the table would have under-reported the feature it exists
      // to measure. This is why the event throttle is a separate, looser one.
      final sink = _RecordingSink();
      final reporter = ThrottledCrashReporter(sinks: [sink]);
      final recorder = DiagnosticPhotoImportRecorder(reporter);

      for (var i = 0; i < 5; i++) {
        recorder.record(PhotoImportRecord(
          outcome: PhotoImportOutcome.ok,
          elapsed: Duration(milliseconds: 2000 + i),
        ));
      }

      expect(sink.received, hasLength(5));
    });

    test('but it is still a ceiling, not an open tap', () {
      final sink = _RecordingSink();
      final reporter = ThrottledCrashReporter(sinks: [sink]);
      final recorder = DiagnosticPhotoImportRecorder(reporter);

      for (var i = 0; i < 40; i++) {
        recorder.record(const PhotoImportRecord(
          outcome: PhotoImportOutcome.failed,
          elapsed: Duration.zero,
        ));
      }

      // Six per fingerprint. A script hammering the import button cannot fill
      // the table, and the server's own 60-an-hour cap is behind this anyway.
      // The 34 suppressed attempts are tallied rather than forgotten — they ride
      // on the next admitted report of that fingerprint, which is next window.
      expect(sink.received, hasLength(6));
    });
  });
}
