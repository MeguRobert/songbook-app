import 'dart:async';

import 'crash_reporter.dart';
import 'import_notice.dart';

/// One row per photo import, and why that is the highest-value row in the app.
///
/// Reading a photographed hymnal page is the only thing this app does that can
/// half-work. A song either loads or it does not; a photo comes back with three
/// of four chord rows, or with `erót` where the page says `erőt`, or with nothing
/// at all — and which of those happened depends on the photograph, not on the
/// code. So "it didn't read my page" is unanswerable without knowing what the
/// page was.
///
/// **The numbers already existed.** `page_text_recognizer_web.dart` measures the
/// image's dimensions and its bytes-per-pixel, the pale fraction and whether
/// show-through suppression fired, the word count of the whole-page read and of
/// each column — and threads all of it through a `trace` argument that
/// `browser_photo_import_service.dart` never passed. Every measurement was
/// computed and dropped on the floor. This is the sink that argument was written
/// for.
///
/// **What is deliberately not here.** No image, no bytes of one, no words read
/// off the page, no lyrics, no ChordPro, no file name. A photograph of a hymnal
/// page is not sensitive, but a photograph of the wrong thing is, and the only
/// safe rule for a table an administrator reads is that content never enters it.
/// `deploy/omr/server.py` has followed exactly this rule since it was written:
/// it logs the note count and the elapsed time and never the score.

/// How a photo import ended.
///
/// Four states, not two, because "it failed" spans three situations with three
/// different answers: the reader never ran, the reader ran and the page was
/// blank to it, or the reader ran and read a page it could not lay out. Telling
/// somebody "take the photo again" is right for one of those and useless for the
/// others.
enum PhotoImportOutcome {
  /// Words were read and laid out. A song came back.
  ok,

  /// The engine answered, and nothing on the page could be turned into a song.
  /// The photograph is the problem: too dark, too skewed, not a chord sheet.
  illegible,

  /// Nothing was handed in — an empty file, a failed pick. The reader never ran.
  refused,

  /// The reader itself did not work: the script would not download, the engine
  /// would not start, a stage ran out of time, the browser refused the image.
  /// The photograph is almost certainly innocent.
  failed,
}

/// What one import attempt measured, ready to become a row.
class PhotoImportRecord {
  const PhotoImportRecord({
    required this.outcome,
    required this.elapsed,
    this.trace = const <Map<String, Object?>>[],
    this.notices = const <ImportNotice>[],
    this.stage,
    this.reason,
  });

  final PhotoImportOutcome outcome;

  /// Wall-clock for the whole attempt, the download of the engine included.
  ///
  /// The first import on a device pulls roughly ten megabytes before it can
  /// start, so a slow *first* read and a slow *every* read are different faults,
  /// and only this number separates them.
  final Duration elapsed;

  /// The recogniser's own trace: one entry per stage, `stage` naming which.
  final List<Map<String, Object?>> trace;

  /// What the reader and the bridge wanted the user told. Recorded as codes
  /// only — the prose lives in the ARB files and is not this table's business.
  final List<ImportNotice> notices;

  /// Which stage gave up, for the failures that have one. See
  /// [PhotoImportException.stage].
  final String? stage;

  /// The underlying error's own `toString()`, for [PhotoImportOutcome.failed].
  ///
  /// **This is the field the friendly sentence was hiding.** The catch in
  /// `BrowserPhotoImportService` replaces whatever arrived with "That photo
  /// could not be read", which is right for the person holding the phone and
  /// leaves nothing at all for the person fixing it — and what arrives here is
  /// routinely a JavaScript object whose interpolation reads `[object Object]`,
  /// which is exactly why it must not be shown and exactly why it must be kept.
  final String? reason;

  /// The numbers, flattened, **most valuable first**.
  ///
  /// Order is load-bearing: [CrashReport.maxDetailsLength] is enforced by
  /// dropping trailing keys, and the trace is the part that grows — one entry
  /// per column on a multi-column page. Losing the tail costs a column's word
  /// count. Losing the head would cost the outcome.
  Map<String, Object?> toDetails() {
    final details = <String, Object?>{
      'outcome': outcome.name,
      'ms': elapsed.inMilliseconds,
      if (stage != null) 'stage': stage,
    };

    // Lifted out of the trace by name rather than by position: the recogniser
    // adds stages as it learns to measure more, and a reader of this table
    // should not have to know the order they were appended in.
    final image = _stage('image');
    if (image != null) {
      details['width'] = image['width'];
      details['height'] = image['height'];
      details['bytes'] = image['bytes'];
      // Rounded, because six decimal places of a ratio is noise and the gate it
      // is compared against (0.08) has two.
      details['bytesPerPixel'] = _round(image['bytesPerPixel']);
    }

    final read = _stage('read');
    if (read != null) {
      details['words'] = read['words'];
      final cuts = read['columnCuts'];
      if (cuts is List) details['columns'] = cuts.length + 1;
    }

    final columns = _stage('columns');
    if (columns != null) details['columnWords'] = columns['words'];

    final clean = _stage('clean');
    if (clean != null) {
      details['paleFraction'] = _round(clean['paleFraction']);
      details['suppressed'] = clean['suppressed'];
    }

    if (notices.isNotEmpty) {
      // Codes, deduplicated, in a stable order. The same notice can be raised
      // once per column, and three copies of `photoGermanNoteNames` says nothing
      // the first one did not.
      final codes = <String>{for (final notice in notices) notice.code.name};
      details['notices'] = codes.toList()..sort();
    }

    // Last on purpose. It is the longest field and the only one that is prose,
    // so it is the right thing for the clamp to eat first.
    if (reason != null && reason!.isNotEmpty) {
      details['reason'] =
          reason!.length <= 300 ? reason : reason!.substring(0, 300);
    }

    return details;
  }

  /// A one-line summary, greppable in the console and readable in the table.
  ///
  /// The stage is in here as well as in `details` because the console sink prints
  /// the message and, outside debug, not the details.
  String get summary => stage == null
      ? 'photo import: ${outcome.name}'
      : 'photo import: ${outcome.name} at $stage';

  Map<String, Object?>? _stage(String name) {
    for (final entry in trace) {
      if (entry['stage'] == name) return entry;
    }
    return null;
  }

  static Object? _round(Object? value) =>
      value is num ? double.parse(value.toStringAsFixed(4)) : value;
}

/// Where a [PhotoImportRecord] goes.
///
/// An interface with one real implementation, so `BrowserPhotoImportService`
/// stays a domain object that knows nothing about Supabase, and so the tests can
/// assert on what would have been written without a backend anywhere in sight.
/// Null is the third implementation: no recorder means no recording, which is
/// what every widget test and the measurement harness want.
abstract class PhotoImportRecorder {
  const PhotoImportRecorder();

  void record(PhotoImportRecord record);
}

/// Writes the record as a `photo_import` row through the crash reporter's
/// transport.
///
/// Reusing that transport is the point, and it is not laziness: it already
/// throttles, already swallows its own failures, already carries the route, the
/// locale, the platform and — the reason item 1 came first — the build number.
/// A second pipeline would have had to reimplement four things correctly to end
/// up in the same table.
///
/// Typed against [ThrottledCrashReporter] rather than the [CrashReporter]
/// interface because the guarantee needed here is the composite's, not a sink's:
/// a sink is allowed to throw, and [ThrottledCrashReporter.note] is the one door
/// that promises never to.
class DiagnosticPhotoImportRecorder extends PhotoImportRecorder {
  const DiagnosticPhotoImportRecorder(this._reporter);

  final ThrottledCrashReporter _reporter;

  @override
  void record(PhotoImportRecord record) {
    // Unawaited, and the import must not wait on it. A network insert on a
    // sleeping free-tier project takes seconds, and the person is looking at
    // their song by then. `note` never throws and never rejects, so an
    // unawaited call cannot resurface as an unhandled error later.
    unawaited(_reporter.note(
      DiagnosticEvent.photoImport,
      record.summary,
      details: record.toDetails(),
    ));
  }
}
