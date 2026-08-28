import 'dart:typed_data';

import 'image_format.dart';
import 'import_notice.dart';
import 'page_text_recognizer.dart';
import 'photo_import_diagnostics.dart';
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
///
/// **This is also where every import is measured.** Not because measuring
/// belongs here, but because this is the one place that sees a whole attempt: the
/// recogniser knows the pixels, the bridge knows the layout, and only this method
/// knows how it ended and how long it took. See [PhotoImportRecorder].
class BrowserPhotoImportService implements PhotoImportService {
  const BrowserPhotoImportService({
    required this.recognizer,
    this.bridge = const PhotoTextBridge(),
    this.recorder,
  });

  final PageTextRecognizer recognizer;
  final PhotoTextBridge bridge;

  /// Where the measurements go, or null for nowhere.
  ///
  /// Optional, and off by default. A widget test, the measurement harness in
  /// `tool/browser_reader_harness.dart` and any build with no backend all want a
  /// reader that reads and records nothing, and none of them should have to
  /// supply a stub to get one.
  final PhotoImportRecorder? recorder;

  @override
  Future<PhotoImportPayload> extract(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    // Started before the first refusal, so even a rejected empty file is timed.
    // The number is near zero there, and its presence still matters: a row with
    // no `ms` at all would read as a row from a build before this existed.
    final clock = Stopwatch()..start();

    // The argument that was already threaded the whole way through
    // `PageTextRecognizer.recognize` and never once passed. Every stage of the
    // reader appends what it measured; with no list to append to, all of it was
    // computed and dropped.
    final trace = <Map<String, Object?>>[];

    // Read here rather than in the recogniser, and that placement is the whole
    // point of it. A container the browser cannot open throws inside
    // `createImageBitmap` before the recogniser appends anything at all, so a
    // measurement taken down there is exactly the measurement that goes
    // missing on the failure it was added to explain. Up here it is taken from
    // bytes already in hand, cannot fail, and is filed on every path.
    final format = sniffImageFormat(imageBytes);

    if (imageBytes.isEmpty) {
      _record(PhotoImportOutcome.refused, clock, trace,
          bytes: imageBytes.length, format: format);
      throw const PhotoImportException('That image is empty.');
    }

    final PageWords read;
    try {
      read = await recognizer.recognize(imageBytes, trace: trace);
    } on PhotoImportException catch (error) {
      // Already a sentence meant for the person holding the phone. It also
      // carries `stage`, which is the only thing separating a CDN that would not
      // answer from an engine that would not start — one sentence covers both for
      // the user, and they are different mornings' work for whoever fixes it.
      _record(PhotoImportOutcome.failed, clock, trace,
          bytes: imageBytes.length,
          format: format,
          stage: error.stage,
          reason: error.message);
      rethrow;
    } catch (error) {
      // A missing engine, a blocked download, an image the browser refused to
      // decode. One situation from the user's side: it did not read.
      //
      // The cause is deliberately not appended to the sentence. These arrive as
      // JavaScript objects, and interpolating one put "[object Object]" — or a
      // raw TypeError — in front of somebody holding a phone.
      //
      // It IS recorded, and that is what this line adds. The catch that is right
      // for the display was until now also the catch that threw away the only
      // description of what actually happened.
      _record(PhotoImportOutcome.failed, clock, trace,
          bytes: imageBytes.length, format: format, reason: error.toString());
      throw const PhotoImportException(
        'That photo could not be read. Try again, or type the words in.',
      );
    }

    final reading = bridge.read(read.words);
    final notices = [...read.notices, ...reading.notices];

    if (reading.chordPro.trim().isEmpty) {
      // The bridge names an unreadable page better than this can - it knows
      // whether it saw nothing at all or nothing it could lay out. The code is
      // carried alongside the sentence so the screen can say it in the language
      // it is being read in; the sentence stays as the fallback for a caller
      // that has no localisations, which the measurement harness does not.
      _record(PhotoImportOutcome.illegible, clock, trace,
          bytes: imageBytes.length, format: format, notices: notices);
      throw PhotoImportException(
        'Nothing could be read from that photo.',
        notice: reading.notices.isNotEmpty ? reading.notices.first : null,
      );
    }

    _record(PhotoImportOutcome.ok, clock, trace,
        bytes: imageBytes.length, format: format, notices: notices);

    // The image's own notices first: "that photo is too compressed" explains
    // the wrong letters below it, and reads oddly after them.
    return ChordProPayload(reading.chordPro, notices: notices);
  }

  /// Files the attempt, and never lets filing it break the attempt.
  ///
  /// The try/catch is the rule the crash reporter's own header states: recording
  /// a failure must never cause one. It matters more on the success path, where a
  /// throwing recorder would turn a page that read perfectly into a failed
  /// import.
  void _record(
    PhotoImportOutcome outcome,
    Stopwatch clock,
    List<Map<String, Object?>> trace, {
    int? bytes,
    ImageFormat? format,
    String? stage,
    String? reason,
    List<ImportNotice> notices = const <ImportNotice>[],
  }) {
    // Said out loud BEFORE the sink is consulted, and deliberately not behind
    // `kDebugMode`.
    //
    // `print` survives a release build. Flutter's `debugPrint` is
    // `debugPrintThrottled`, which is this call plus a rate limiter — same
    // channel, same release behaviour, and its own `foundation/print.dart` says
    // so: "logs to console even in release mode". These are the only lines here
    // that reach a browser console on the deployed site.
    //
    // `print` and not `debugPrint` for a reason that is not style: `debugPrint`
    // lives in `package:flutter/foundation.dart`, which reaches `dart:ui`,
    // which plain `dart compile js` does not have — and this file is compiled
    // that way by `tool/browser_reader_harness.dart` so the measurement corpus
    // scores the engine that actually ships. Importing it here made the corpus
    // unbuildable. The throttle is no loss: it is why the trace below had to be
    // printed one line at a time, and nothing here is emitted in a loop.
    //
    // It exists because of the first failure reported from the live app: a
    // scrolled screenshot that would not read, which left no trace anywhere at
    // all. The recorder writes to Supabase, and `error_reports` held nothing —
    // so either the reporter never ran or the write failed, and no evidence
    // survived to tell those apart. A console line costs nothing and cannot
    // fail for the same reason the database write can.
    //
    // Failures only. A successful read says nothing: this is for the mornings
    // when somebody reports that it did not work, not a running commentary.
    if (outcome != PhotoImportOutcome.ok) {
      // The byte count is printed because it is the ONLY thing known before
      // the decode. An image the browser refuses to open appends nothing to the
      // trace, so without this such a failure reports its own size as unknown —
      // and size is the first thing worth knowing about a screenshot that is
      // twelve thousand pixels tall.
      _say('[photo] $outcome in ${clock.elapsedMilliseconds}ms'
          '${bytes == null ? '' : ', $bytes bytes in'}'
          '${format == null ? '' : ', ${format.name}'}'
          '${stage == null ? '' : ' at stage "$stage"'}');
      if (reason != null) _say('[photo] reason: $reason');
      if (notices.isNotEmpty) {
        _say('[photo] notices: ${notices.map((n) => n.code.name).join(', ')}');
      }
      // One line per stage rather than one line for the list: the entry that
      // explains the failure is usually the last one, and one long line is the
      // end a console truncation eats.
      for (final entry in trace) {
        _say('[photo] trace: $entry');
      }
    }

    final sink = recorder;
    if (sink == null) return;
    try {
      sink.record(PhotoImportRecord(
        outcome: outcome,
        elapsed: clock.elapsed,
        trace: trace,
        notices: notices,
        bytes: bytes,
        format: format,
        stage: stage,
        reason: reason,
      ));
    } catch (_) {
      // Nowhere for this to go, and nothing worth doing about it.
    }
  }

  /// One line to the browser console, in release as well as in debug.
  ///
  /// Wrapped so the `avoid_print` suppression is written once rather than four
  /// times, and so the reason for choosing `print` over `debugPrint` has one
  /// place to live. See the comment in [_record].
  // ignore: avoid_print
  void _say(String line) => print(line);
}
