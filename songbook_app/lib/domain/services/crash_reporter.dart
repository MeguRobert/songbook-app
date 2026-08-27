import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Getting a failure on somebody else's phone back to the person who can fix it.
///
/// Until this existed the app had no error handling at all — no
/// `FlutterError.onError`, no `runZonedGuarded`, nothing. A red screen on a
/// device the owner does not have was simply never known about, which is a poor
/// position to be in the week a congregation starts using the thing.
///
/// **Three rules govern everything here, and they are all the same rule.**
///
/// 1. Reporting a crash must never cause one. Every path below swallows its own
///    failure. A reporter that throws turns one broken screen into a broken app,
///    and it would do it inside the handler that exists to catch broken screens.
/// 2. It must work with no backend. Supabase is optional in this project by
///    design — signed-out and offline are normal states — so the console sink is
///    always present and the Supabase sink is simply absent when there is no
///    client. "No reporting configured" is a configuration, not a fault.
/// 3. It must be cheap when things are very wrong. A layout error inside a build
///    loop fires sixty times a second; without the throttle that is thousands of
///    rows a minute in a table anyone on the internet may write to.
///
/// The sink that writes to Postgres lives in
/// `lib/data/datasources/remote/supabase_crash_reporter.dart` rather than here,
/// because it is the only part that needs a `SupabaseClient` and this file is
/// deliberately reachable from a plain `flutter test` with no backend in sight.

/// Ambient facts about where the app was standing when it fell over.
///
/// Mutable and long-lived: one instance is created in `main` before anything can
/// fail, handed to the reporter, and updated as the user moves around. A crash
/// report assembled from it therefore describes the moment, not the launch.
class CrashContext {
  /// The router location, e.g. `/song/91` or `/admin/queue`.
  ///
  /// Set by `createAppRouter`'s `onNavigate` hook. Far and away the most useful
  /// single field: "it crashes" is unactionable, "it crashes on /import" is a
  /// morning's work.
  String? route;

  /// `1.1.0`, from the built artifact rather than a constant.
  String? appVersion;

  /// The commit count CI stamps in, which identifies the deploy exactly.
  String? buildNumber;

  /// See [describePlatform].
  String? platform;

  String? _locale;

  /// The interface language on screen, as a language code.
  ///
  /// Falls back to the device's when the user has expressed no preference,
  /// because that is what the app is actually showing them in that case.
  /// Layout faults are routinely language-specific here — Hungarian and
  /// Romanian strings run longer than the English they were laid out against.
  String? get locale {
    if (_locale != null) return _locale;
    try {
      return PlatformDispatcher.instance.locale.languageCode;
    } catch (_) {
      return null;
    }
  }

  set locale(String? value) => _locale = value;

  /// Records the location the app just navigated to.
  ///
  /// A method rather than a bare field write so the router can pass it as a
  /// tear-off and stay ignorant of what it is feeding.
  void noteRoute(String location) => route = location;
}

/// A coarse description of the machine: `web/android 412x915 dpr2.6`.
///
/// Deliberately not the raw user-agent string. The bucket is the entire
/// diagnostic value — "only on iPhones", "only when narrow" — and a full UA adds
/// a fingerprinting surface for nothing. The logical size is included because
/// the commonest class of report a hymn app will ever get is a layout fault at
/// a width the developer never opened.
String describePlatform() {
  final buffer = StringBuffer(kIsWeb ? 'web/' : 'native/');
  buffer.write(defaultTargetPlatform.name);
  try {
    final view = PlatformDispatcher.instance.implicitView;
    if (view != null && view.devicePixelRatio > 0) {
      final width = view.physicalSize.width / view.devicePixelRatio;
      final height = view.physicalSize.height / view.devicePixelRatio;
      buffer.write(' ${width.round()}x${height.round()}');
      buffer.write(' dpr${view.devicePixelRatio.toStringAsFixed(1)}');
    }
  } catch (_) {
    // A headless test binding has no view. The platform name alone is still
    // worth having, and this is not a place to be fussy.
  }
  return buffer.toString();
}

/// What kind of thing a row in `error_reports` records.
///
/// **Why one table and not two.** Everything short of a crash — a handled
/// failure, a degraded result, a silent fallback — never raises, so none of it
/// reaches the handlers `main` installs. It still needs somewhere to go, and
/// that somewhere could have been a second table with its own migration, its own
/// RLS, its own throttle and its own sink. It is not, because when somebody says
/// "it didn't work" the person reading has to look in **one** place. A
/// discriminator column costs a `where event = …`; a second pipeline costs a
/// second thing to remember, and the one that gets forgotten is the one with the
/// answer in it.
///
/// These strings are the `check` constraint in
/// `supabase/migrations/20260827130000_diagnostic_events.sql`. Adding a value
/// here means adding it there, in a migration, in the same commit — and the
/// reverse discipline matters more: `admin_audit` has carried `settings_changed`
/// in its constraint since the day it was written with nothing at all emitting
/// it, and a constraint naming an event nobody writes reads as coverage that
/// does not exist. Add the value when its writer lands, not before.
class DiagnosticEvent {
  const DiagnosticEvent._();

  /// An uncaught error. The original reason this table exists.
  static const String crash = 'crash';

  /// One photo-import attempt, succeeded or failed.
  /// See `PhotoImportRecord` in `photo_import_diagnostics.dart`.
  static const String photoImport = 'photo_import';
}

/// One fault, in the shape the sinks and the `error_reports` table expect.
@immutable
class CrashReport {
  /// These mirror the `check` constraints in
  /// `supabase/migrations/20260827120000_error_reports.sql` exactly.
  ///
  /// The server clamps too, and it is the server's clamp that is authoritative —
  /// these exist so the app does not spend a mobile connection uploading a
  /// megabyte of stack that Postgres is about to throw away.
  static const int maxMessageLength = 500;
  static const int maxStackLength = 4000;

  /// The cap on the encoded [details] object, matching
  /// `20260827130000_diagnostic_events.sql`.
  ///
  /// Small on purpose. [details] holds measurements — counts, milliseconds,
  /// fractions — and anything that will not fit in two kilobytes of JSON is
  /// something other than a measurement.
  static const int maxDetailsLength = 2000;

  /// Which of [DiagnosticEvent]'s kinds this row is.
  final String event;

  /// The numbers behind the event. Empty for a crash, whose evidence is its
  /// stack.
  ///
  /// **Never prose, never content.** A photo-import row carries the image's
  /// dimensions and how long the read took; it does not carry the image, the
  /// words read off it, or the song they became. That is the rule
  /// `deploy/omr/server.py` already follows and the reason it is the
  /// best-instrumented thing in this project: it records what it measured, never
  /// what it was given.
  final Map<String, Object?> details;

  final String message;
  final String? stack;

  /// Groups repeats of the same fault. See [fingerprintOf].
  final String fingerprint;

  /// How many times this fault fired since the last report of it was sent.
  ///
  /// Always at least 1. The throttle sets it above 1 to say "and this many more
  /// that were suppressed", which is what makes suppression honest rather than
  /// simply lossy.
  final int occurrences;

  final String? route;
  final String? locale;
  final String? appVersion;
  final String? buildNumber;
  final String? platform;

  const CrashReport({
    required this.message,
    required this.fingerprint,
    this.event = DiagnosticEvent.crash,
    this.details = const <String, Object?>{},
    this.stack,
    this.occurrences = 1,
    this.route,
    this.locale,
    this.appVersion,
    this.buildNumber,
    this.platform,
  });

  /// Builds a report from whatever the framework handed us.
  ///
  /// [error] is anything at all — Flutter's handlers are typed `Object`, and in
  /// practice a good share of what arrives is a `String` thrown by a package.
  factory CrashReport.from(
    Object error,
    StackTrace? stack, {
    CrashContext? context,
    String? library,
  }) {
    final summary = _clamp(
      library == null || library.isEmpty ? '$error' : '$library: $error',
      maxMessageLength,
    );
    final frames = _topFrames(stack);
    return CrashReport(
      message: summary.isEmpty ? 'unspecified error' : summary,
      stack: frames,
      fingerprint: fingerprintOf(summary, frames),
      route: context?.route,
      locale: context?.locale,
      appVersion: context?.appVersion,
      buildNumber: context?.buildNumber,
      platform: context?.platform,
    );
  }

  /// Builds a report for something that did **not** throw.
  ///
  /// A handled failure, a degraded result, or a plain success worth counting.
  /// There is no stack because there was no throw, and the diagnostic value is
  /// in [details] instead.
  ///
  /// [context] is required in spirit though not in signature, and it is what
  /// item 1 of the logging handoff is about: a row that cannot be tied to a
  /// build is a row that cannot be tied to a release, and every bug report is
  /// then about an unknown version. Passing the same long-lived [CrashContext]
  /// `main` already stamps the build onto is what makes that automatic for every
  /// event rather than a thing each caller has to remember.
  ///
  /// [details] is clamped, and clamped by **dropping trailing keys** — so put
  /// the number you would keep if you could keep only one first.
  factory CrashReport.diagnostic({
    required String event,
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
    CrashContext? context,
  }) {
    final summary = _clamp(message, maxMessageLength);
    return CrashReport(
      event: event,
      // Grouped with the event in the key, not the message alone. Two events
      // may reasonably say the same short thing — 'ok' is the commonest message
      // this will ever write — and folding them into one fingerprint would let
      // one event's ceiling silence another's.
      fingerprint: fingerprintOf('$event\n$summary', null),
      message: summary.isEmpty ? event : summary,
      details: _clampDetails(details),
      route: context?.route,
      locale: context?.locale,
      appVersion: context?.appVersion,
      buildNumber: context?.buildNumber,
      platform: context?.platform,
    );
  }

  CrashReport withOccurrences(int count) => CrashReport(
        message: message,
        fingerprint: fingerprint,
        event: event,
        details: details,
        stack: stack,
        occurrences: count,
        route: route,
        locale: locale,
        appVersion: appVersion,
        buildNumber: buildNumber,
        platform: platform,
      );

  /// The row to insert.
  ///
  /// `user_id` is conspicuously absent. The insert trigger overwrites it with
  /// `auth.uid()` regardless of what is sent, so sending it would be theatre —
  /// and the same rule `songs.reviewed_by` follows: identity is the server's to
  /// state. Null fields are omitted rather than sent as null, so the column
  /// defaults stay in charge.
  Map<String, dynamic> toRow() => <String, dynamic>{
        'event': event,
        'message': message,
        'fingerprint': fingerprint,
        'occurrences': occurrences,
        if (details.isNotEmpty) 'details': details,
        if (stack != null) 'stack': stack,
        if (route != null) 'route': route,
        if (locale != null) 'locale': locale,
        if (appVersion != null) 'app_version': appVersion,
        if (buildNumber != null) 'build_number': buildNumber,
        if (platform != null) 'platform': platform,
      };

  @override
  String toString() => 'CrashReport($event $fingerprint x$occurrences '
      'at ${route ?? '?'}: $message)';

  /// A stable grouping key for "the same thing going wrong again".
  ///
  /// **Digits are stripped first, and that is the interesting decision.** Half
  /// the messages Flutter produces carry a varying number in them — `Invalid
  /// value: Not in inclusive range 0..4: 7`, `/song/91` in a frame — so hashing
  /// them verbatim would give every occurrence its own key and the de-duplication
  /// would do nothing at exactly the moment it is needed. Grouping is coarser
  /// than identity on purpose: the job is to stop a loop writing a thousand
  /// rows, not to tell two indices apart.
  ///
  /// FNV-1a rather than anything from `dart:convert` or a crypto package,
  /// because `String.hashCode` is not guaranteed stable across runs or
  /// platforms and this key has to mean the same thing on two devices.
  static String fingerprintOf(String message, String? stack) {
    final head = (stack ?? '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(3)
        .join('\n');
    final normalised = '$message\n$head'.replaceAll(RegExp(r'\d+'), '#');

    var hash = 0x811c9dc5;
    for (final unit in normalised.codeUnits) {
      hash = ((hash ^ (unit & 0xff)) * 0x01000193) & 0xffffffff;
      hash = ((hash ^ ((unit >> 8) & 0xff)) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _clamp(String value, int limit) {
    final text = value.trim();
    return text.length <= limit ? text : text.substring(0, limit);
  }

  /// Cuts [details] down to something the column will hold, and something the
  /// caller can afford to send over a mobile connection.
  ///
  /// **Trailing keys go first**, which is the whole contract: the recogniser's
  /// trace is one entry per column read and a two-column page has three of them,
  /// so the part that grows without a bound is the part at the end. Losing the
  /// tail of a trace costs a column's word count; losing the head would cost the
  /// outcome.
  ///
  /// A value that will not encode at all — a live object handed in by mistake —
  /// drops the whole map rather than the row. The event is still worth writing
  /// without its numbers, and this is a diagnostic path, so it may not throw.
  static Map<String, Object?> _clampDetails(Map<String, Object?> details) {
    if (details.isEmpty) return const <String, Object?>{};
    try {
      final kept = Map<String, Object?>.of(details);
      while (kept.isNotEmpty && json.encode(kept).length > maxDetailsLength) {
        kept.remove(kept.keys.last);
      }
      return Map<String, Object?>.unmodifiable(kept);
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  /// The top of the stack, cut on a line boundary rather than mid-frame.
  ///
  /// A half-frame is worse than one frame fewer: it reads as a different symbol
  /// and sends whoever is debugging to the wrong place.
  static String? _topFrames(StackTrace? stack) {
    if (stack == null) return null;
    final text = stack.toString();
    if (text.trim().isEmpty) return null;

    final kept = StringBuffer();
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) continue;
      if (kept.length + line.length + 1 > maxStackLength) break;
      if (kept.isNotEmpty) kept.write('\n');
      kept.write(line);
    }
    final result = kept.toString();
    return result.isEmpty ? null : result;
  }
}

/// Somewhere a [CrashReport] can be sent.
///
/// Implementations must not throw. [ThrottledCrashReporter] catches anyway —
/// belt and braces, because this is the one abstraction in the app where a
/// leaked exception makes the original problem worse.
abstract class CrashReporter {
  const CrashReporter();

  Future<void> report(CrashReport report);
}

/// Prints the fault where a developer, or a user reading you the console over
/// the phone, can see it.
///
/// Always installed, including in release. It is the only sink that exists when
/// Supabase is unreachable, and on the web the browser console survives the
/// reload that a crash usually prompts.
class ConsoleCrashReporter extends CrashReporter {
  const ConsoleCrashReporter();

  @override
  Future<void> report(CrashReport report) async {
    final repeats = report.occurrences > 1 ? ' (+${report.occurrences - 1} more)' : '';
    // The build number joins the version here, and that is deliberate: on the
    // web a service worker will happily hand somebody a months-old bundle, so
    // '1.1.0' alone does not say which deploy is on the screen in front of them.
    final tag = '[${report.event}]';
    debugPrint('$tag ${report.fingerprint}$repeats '
        '${report.route ?? '?'} ${report.appVersion ?? '?'}'
        '${report.buildNumber == null ? '' : '+${report.buildNumber}'} '
        '${report.platform ?? '?'}');
    debugPrint('$tag ${report.message}');
    // Only in debug: this is the one line that could get long, and the details
    // are on the row for whoever reads the table.
    if (report.details.isNotEmpty && kDebugMode) {
      debugPrint('$tag ${report.details}');
    }
    final stack = report.stack;
    if (stack != null && kDebugMode) debugPrint(stack);
  }
}

/// Decides whether a fault has earned another row.
///
/// Two ceilings, because one is not enough:
///
/// * [perFingerprint] stops the same fault repeating. This is the build-loop
///   case — a layout assertion fires on every frame, and without this it would
///   write sixty rows a second.
/// * [total] stops *different* faults flooding. One broken widget typically
///   throws several distinct errors as the tree unwinds, so a purely
///   per-fingerprint limit would still let a cascade through.
///
/// Suppressed occurrences are counted, not discarded: the next admitted report
/// of that fingerprint carries them in `occurrences`, so the row says "this
/// happened 214 times" instead of the table implying it happened twice.
///
/// [clock] is injectable so the tests can move time without waiting.
class CrashThrottle {
  CrashThrottle({
    this.window = const Duration(minutes: 10),
    this.perFingerprint = 2,
    this.total = 12,
    this.maxTrackedFingerprints = 64,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration window;
  final int perFingerprint;
  final int total;

  /// A bound on memory. Without it, a fault whose message varies in a way the
  /// digit-stripping in [CrashReport.fingerprintOf] does not catch would grow
  /// this map without limit — in a long-lived web session, indefinitely.
  final int maxTrackedFingerprints;

  final DateTime Function() _clock;
  final Map<String, _Tally> _tallies = <String, _Tally>{};
  final List<DateTime> _sent = <DateTime>[];

  /// How many occurrences to report now, or null to stay silent.
  ///
  /// Every call counts as one occurrence of [fingerprint], admitted or not.
  int? admit(String fingerprint) {
    final now = _clock();
    _sent.removeWhere((at) => now.difference(at) >= window);

    var tally = _tallies[fingerprint];
    if (tally == null) {
      _evictIfCrowded(now);
      tally = _Tally(now);
      _tallies[fingerprint] = tally;
    }

    tally.lastSeen = now;
    tally.pending++;

    if (now.difference(tally.windowStart) >= window) {
      tally.windowStart = now;
      tally.sent = 0;
    }

    if (tally.sent >= perFingerprint) return null;
    if (_sent.length >= total) return null;

    tally.sent++;
    _sent.add(now);
    final owed = tally.pending;
    tally.pending = 0;
    return owed;
  }

  /// Drops whatever has been quiet longest once the map is full.
  ///
  /// Least-recently-seen rather than oldest-created: a fault that is still
  /// firing is the one worth remembering the ceiling for.
  void _evictIfCrowded(DateTime now) {
    _tallies.removeWhere((_, tally) => now.difference(tally.lastSeen) >= window);
    if (_tallies.length < maxTrackedFingerprints) return;

    final byAge = _tallies.keys.toList()
      ..sort((a, b) => _tallies[a]!.lastSeen.compareTo(_tallies[b]!.lastSeen));
    final surplus = _tallies.length - maxTrackedFingerprints + 1;
    for (final key in byAge.take(surplus)) {
      _tallies.remove(key);
    }
  }
}

class _Tally {
  _Tally(DateTime now)
      : windowStart = now,
        lastSeen = now;

  DateTime windowStart;
  DateTime lastSeen;

  /// Reports admitted inside the current window.
  int sent = 0;

  /// Occurrences seen since the last admitted report.
  int pending = 0;
}

/// The front door: throttles, fans out to every sink, and swallows everything.
///
/// This is what `main` installs into `FlutterError.onError`,
/// `PlatformDispatcher.instance.onError` and `runZonedGuarded`. It is also a
/// [CrashReporter] itself, so a sink and a composite of sinks are the same kind
/// of thing and nothing has to know which it is holding.
class ThrottledCrashReporter extends CrashReporter {
  ThrottledCrashReporter({
    List<CrashReporter> sinks = const [],
    CrashContext? context,
    CrashThrottle? throttle,
    CrashThrottle? eventThrottle,
    this.sinkTimeout = const Duration(seconds: 5),
  })  : _sinks = List<CrashReporter>.of(sinks),
        context = context ?? CrashContext(),
        _throttle = throttle ?? CrashThrottle(),
        _eventThrottle = eventThrottle ??
            CrashThrottle(perFingerprint: 6, total: 20);

  final CrashContext context;
  final CrashThrottle _throttle;

  /// A looser ceiling for everything that is not a crash, and it has to be
  /// looser or the feature it is measuring stops being measured.
  ///
  /// A crash fingerprint repeats because a build loop is firing it sixty times a
  /// second, so two per ten minutes is generous. A photo-import fingerprint
  /// repeats because somebody is importing songs, which is the thing this exists
  /// to count — five successful imports in ten minutes is an ordinary evening's
  /// work, and under the crash ceiling three of them would vanish and the table
  /// would quietly under-report the feature. Six per fingerprint and twenty
  /// overall is still a ceiling, and the server's own 60-an-hour cap is still the
  /// one that actually bounds the table.
  final CrashThrottle _eventThrottle;
  final List<CrashReporter> _sinks;

  /// A hung network call must not keep a report — or its zone — alive forever.
  final Duration sinkTimeout;

  List<CrashReporter> get sinks => List<CrashReporter>.unmodifiable(_sinks);

  /// Adds a sink after construction.
  ///
  /// Exists because the Supabase sink cannot be built until `Supabase.initialize`
  /// has succeeded, and the reporter has to be installed before that runs — a
  /// failure during startup is precisely the kind nobody currently hears about.
  void addSink(CrashReporter sink) => _sinks.add(sink);

  /// Builds a report from a raw error and files it. Never throws.
  Future<void> record(Object error, StackTrace? stack, {String? library}) {
    CrashReport built;
    try {
      built = CrashReport.from(error, stack, context: context, library: library);
    } catch (_) {
      // Even assembling the report failed — a `toString()` that throws, most
      // likely. Report what little is certain rather than nothing.
      //
      // The context is still attached, and that is not tidiness. This row says
      // nothing about *what* broke, so the only thing it can be worth is the
      // build and the screen it broke on; sending it without them was sending a
      // row that could never be tied to a release.
      built = CrashReport(
        message: 'unreportable error',
        fingerprint: 'unreportable',
        route: context.route,
        locale: context.locale,
        appVersion: context.appVersion,
        buildNumber: context.buildNumber,
        platform: context.platform,
      );
    }
    return report(built);
  }

  /// Files something that did not throw. Never throws.
  ///
  /// The counterpart to [record] for the failures the crash handlers cannot see,
  /// and the reason the context lives on this object: every event gets the build
  /// number, the route and the locale without its caller knowing they exist.
  Future<void> note(
    String event,
    String message, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    CrashReport built;
    try {
      built = CrashReport.diagnostic(
        event: event,
        message: message,
        details: details,
        context: context,
      );
    } catch (_) {
      return Future<void>.value();
    }
    return report(built);
  }

  /// Never throws, never rejects — the returned future always completes
  /// normally, so an unawaited call cannot surface later as an unhandled error.
  ///
  /// There is deliberately no "already reporting" flag. A sink that throws is
  /// caught below, so it never reaches `FlutterError.onError` and cannot recurse
  /// into here; and a flag held across the `await` on a slow network insert
  /// would silently drop every *other* fault for the duration, which is the
  /// opposite of the point. What bounds a loop is the throttle, which is a
  /// ceiling rather than a mute.
  @override
  Future<void> report(CrashReport report) async {
    try {
      final throttle = report.event == DiagnosticEvent.crash
          ? _throttle
          : _eventThrottle;
      final occurrences = throttle.admit(report.fingerprint);
      if (occurrences == null) return;
      final outgoing = occurrences == report.occurrences
          ? report
          : report.withOccurrences(occurrences);

      for (final sink in _sinks) {
        try {
          await sink.report(outgoing).timeout(sinkTimeout);
        } catch (_) {
          // One sink failing must not stop the others. There is deliberately
          // nowhere for this to go: reporting a reporting failure is how a loop
          // starts, and the console sink has already printed the original.
        }
      }
    } catch (_) {
      // The throttle, or something else in here, misbehaved. Swallowed for the
      // same reason: rule 1 at the top of this file.
    }
  }
}
