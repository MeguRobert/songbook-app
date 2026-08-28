import 'image_format.dart';
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
    this.bytes,
    this.format,
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

  /// The size of the upload, or null when the caller did not say.
  ///
  /// Recorded from the argument rather than lifted out of the `image` trace
  /// entry, because the entry is not there on the failure that most needs the
  /// number: a container the browser will not open throws before the recogniser
  /// measures anything, and that row used to report its own size as unknown.
  final int? bytes;

  /// What the leading bytes said the upload was. See [sniffImageFormat].
  ///
  /// **The discriminator this table was missing.** A decode that throws in
  /// 107ms is either a HEIC — which no Chrome opens — or an image too large for
  /// a phone's decoder, and the advice differs. Nothing else in the row can
  /// separate them, because the decode is where everything else would have been
  /// measured.
  final ImageFormat? format;

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
      // Ahead of everything the decode measures, because these two are the only
      // facts a failed decode leaves behind. An enum name and an integer: no
      // file name, and nothing that identifies the picture or the person.
      if (format != null) 'format': format!.name,
      if (bytes != null) 'bytes': bytes,
      if (stage != null) 'stage': stage,
    };

    // Immediately after the head, and ahead of everything the decode measures,
    // for the same reason `format` is: a HEIC the library also could not open
    // appends nothing else at all, and this is then the only evidence that a
    // second attempt was even made. Three keys, all measurements — a boolean,
    // a millisecond count, and one of this file's own stage tokens.
    //
    // Absent entirely on the ordinary path. No entry means the bytes were not
    // HEIC or HEIF, or the browser opened them itself and libheif was never
    // reached; `heifDecoded: false` means it was reached and could not do it.
    final heif = _stage('heif');
    if (heif != null) {
      details['heifDecoded'] = heif['decoded'];
      details['heifMs'] = heif['ms'];
      if (heif['why'] != null) details['heifStage'] = heif['why'];
    }

    // Lifted out of the trace by name rather than by position: the recogniser
    // adds stages as it learns to measure more, and a reader of this table
    // should not have to know the order they were appended in.
    final image = _stage('image');
    if (image != null) {
      details['width'] = image['width'];
      details['height'] = image['height'];
      // Only if the caller did not already say. Same number either way — both
      // are the upload's length — and the head is where it survives the clamp.
      details['bytes'] ??= image['bytes'];
      // Rounded, because six decimal places of a ratio is noise and the gate it
      // is compared against (0.08) has two.
      details['bytesPerPixel'] = _round(image['bytesPerPixel']);
      // What the page was read at, not what was handed over. The canvas size is
      // recoverable from this and the two above, and one number costs less of
      // the clamp than two. A row is unreadable without it: 1080x12000 says
      // nothing about whether the engine saw a page or a stripe.
      final rendered = image['scale'];
      if (rendered != null) details['scale'] = _round(rendered);
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

// The one that ships is `DiagnosticPhotoImportRecorder`, and it lives in its
// own file rather than here. Nothing in this file may import
// `package:flutter/foundation.dart`, directly or through anything else: the
// measurement corpus compiles this reading path with plain `dart compile js`
// - see `tool/browser_reader_harness.dart` - and `dart2js` has no `dart:ui`, so
// one such import anywhere in the graph makes the whole harness refuse to
// build. That is exactly what a `crash_reporter.dart` import here did, and the
// corpus was unmeasurable for two commits before anyone tried to run it.
