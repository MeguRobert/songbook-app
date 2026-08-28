import 'dart:async';

import 'crash_reporter.dart';
import 'photo_import_diagnostics.dart';

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
///
/// **Its own file, and that is load-bearing.** [PhotoImportRecorder] and
/// [PhotoImportRecord] sit in the reading path, which
/// `tool/browser_reader_harness.dart` compiles with plain `dart compile js` so
/// the measurement corpus scores the engine that actually ships. `dart2js` has
/// no `dart:ui`, so a single import of `package:flutter/foundation.dart`
/// anywhere in that graph makes the whole harness refuse to build — which is
/// exactly what happened when this class lived beside the record it writes and
/// dragged [CrashReporter] in behind it. The corpus went unmeasurable for two
/// commits before anyone tried to run it.
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
