import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/datasources/remote/supabase_crash_reporter.dart';
import 'package:songbook_app/domain/services/crash_reporter.dart';

/// Records what it was asked to send, so the fan-out can be inspected.
class _RecordingReporter extends CrashReporter {
  final List<CrashReport> received = [];

  @override
  Future<void> report(CrashReport report) async => received.add(report);
}

/// Fails the way a real sink fails: a network error, mid-flight.
class _ThrowingReporter extends CrashReporter {
  int calls = 0;

  @override
  Future<void> report(CrashReport report) async {
    calls++;
    throw StateError('the server said no');
  }
}

/// Fails the other way: never answers at all.
class _HangingReporter extends CrashReporter {
  @override
  Future<void> report(CrashReport report) => Completer<void>().future;
}

void main() {
  group('CrashReport.from', () {
    test('carries the context the app was in', () {
      final context = CrashContext()
        ..route = '/song/91'
        ..appVersion = '1.1.0'
        ..buildNumber = '143'
        ..platform = 'web/android 412x915 dpr2.6'
        ..locale = 'hu';

      final report = CrashReport.from(
        StateError('boom'),
        StackTrace.fromString('#0 Something.build (package:songbook_app/x:1)'),
        context: context,
      );

      expect(report.message, contains('boom'));
      expect(report.route, '/song/91');
      expect(report.appVersion, '1.1.0');
      expect(report.buildNumber, '143');
      expect(report.locale, 'hu');
      expect(report.platform, startsWith('web/'));
    });

    test('clamps to the caps the table enforces', () {
      final frames = List.generate(
        800,
        (i) => '#$i      Something.build (package:songbook_app/a/b/c.dart:$i:9)',
      );
      final report = CrashReport.from(
        'x' * 2000,
        StackTrace.fromString(frames.join('\n')),
      );

      expect(report.message.length, CrashReport.maxMessageLength);
      expect(report.stack!.length, lessThan(frames.join('\n').length),
          reason: 'the point is that something was actually cut');
      expect(report.stack!.length, lessThanOrEqualTo(CrashReport.maxStackLength));

      // Cut on a line boundary: half a frame reads as a different symbol and
      // sends whoever is debugging to the wrong place.
      expect(report.stack!.split('\n').last,
          matches(RegExp(r'^#\d+ +Something\.build \(package:.+:\d+:\d+\)$')));
    });

    test('an error with nothing to say still produces a report', () {
      final report = CrashReport.from('   ', null);
      expect(report.message, 'unspecified error');
      expect(report.stack, isNull);
    });

    test('the row omits nulls and never sends user_id', () {
      final row = CrashReport.from(StateError('boom'), null).toRow();

      expect(row.containsKey('user_id'), isFalse,
          reason: 'the insert trigger stamps auth.uid(); sending one is theatre');
      expect(row.containsKey('route'), isFalse,
          reason: 'absent rather than null, so column defaults stay in charge');
      expect(row['message'], contains('boom'));
      expect(row['occurrences'], 1);
    });
  });

  group('describePlatform', () {
    test('answers something usable even with no view attached', () {
      // A headless test binding has no implicit view, which is the case that
      // would throw if the lookup were not guarded — and it runs at the very
      // top of main, before anything else.
      final described = describePlatform();
      expect(described, isNotEmpty);
      expect(described, contains('/'),
          reason: 'the shape is web|native / target platform');
    });
  });

  group('CrashReport.fingerprintOf', () {
    test('the same fault twice gets the same key', () {
      final one = CrashReport.from(StateError('boom'), null).fingerprint;
      final two = CrashReport.from(StateError('boom'), null).fingerprint;
      expect(one, two);
    });

    test('different faults get different keys', () {
      final one = CrashReport.from(StateError('boom'), null).fingerprint;
      final two = CrashReport.from(ArgumentError('elsewhere'), null).fingerprint;
      expect(one, isNot(two));
    });

    test('a varying number does NOT split the group', () {
      // The decision that makes de-duplication work at all. Half of Flutter's
      // messages carry an index or a length in them, and hashing those verbatim
      // would give every occurrence of one bug its own key.
      final at4 = CrashReport.fingerprintOf('Invalid value: range 0..4: 7', null);
      final at9 = CrashReport.fingerprintOf('Invalid value: range 0..9: 12', null);
      expect(at4, at9);
    });

    test('only the top frames matter', () {
      final shallow = CrashReport.fingerprintOf('boom', '#0 a\n#1 b\n#2 c');
      final deep = CrashReport.fingerprintOf('boom', '#0 a\n#1 b\n#2 c\n#3 zzz');
      expect(shallow, deep,
          reason: 'the same fault reached from a different depth is one fault');
    });
  });

  group('CrashThrottle', () {
    late DateTime now;
    CrashThrottle build({int perFingerprint = 2, int total = 12}) =>
        CrashThrottle(
          window: const Duration(minutes: 10),
          perFingerprint: perFingerprint,
          total: total,
          clock: () => now,
        );

    setUp(() => now = DateTime(2026, 8, 27, 12));

    test('the first occurrence is always admitted', () {
      expect(build().admit('abc'), 1);
    });

    test('a build loop cannot write thousands of rows', () {
      final throttle = build();
      final admitted = <int>[];
      for (var i = 0; i < 5000; i++) {
        final owed = throttle.admit('abc');
        if (owed != null) admitted.add(owed);
      }
      expect(admitted.length, 2, reason: 'perFingerprint is the ceiling');
    });

    test('suppressed occurrences are counted, not discarded', () {
      final throttle = build(perFingerprint: 1);
      expect(throttle.admit('abc'), 1);
      for (var i = 0; i < 213; i++) {
        expect(throttle.admit('abc'), isNull);
      }

      // A fresh window: the next report says how bad it actually was.
      now = now.add(const Duration(minutes: 11));
      expect(throttle.admit('abc'), 214,
          reason: '213 suppressed plus the one that reopened the window');
    });

    test('a cascade of DIFFERENT faults is capped too', () {
      // One broken widget throws several distinct errors as the tree unwinds,
      // so a purely per-fingerprint limit would still let a flood through.
      final throttle = build(total: 4);
      final admitted = <String>[];
      for (var i = 0; i < 50; i++) {
        if (throttle.admit('fault-$i') != null) admitted.add('fault-$i');
      }
      expect(admitted.length, 4);
    });

    test('the ceilings reset once the window has passed', () {
      final throttle = build(total: 2);
      expect(throttle.admit('a'), isNotNull);
      expect(throttle.admit('b'), isNotNull);
      expect(throttle.admit('c'), isNull);

      now = now.add(const Duration(minutes: 11));
      expect(throttle.admit('c'), isNotNull);
    });

    test('tracking is bounded, so a long web session cannot grow forever', () {
      final throttle = CrashThrottle(
        window: const Duration(minutes: 10),
        total: 100000,
        maxTrackedFingerprints: 8,
        clock: () => now,
      );
      for (var i = 0; i < 500; i++) {
        throttle.admit('fault-$i');
        now = now.add(const Duration(seconds: 1));
      }
      // Nothing to assert on internals; what matters is that it still answers
      // and has not fallen over after evicting hundreds of entries.
      expect(throttle.admit('fault-final'), isNotNull);
    });
  });

  group('ThrottledCrashReporter', () {
    test('fans one fault out to every sink', () async {
      final a = _RecordingReporter();
      final b = _RecordingReporter();
      final reporter = ThrottledCrashReporter(sinks: [a, b]);

      await reporter.record(StateError('boom'), StackTrace.current);

      expect(a.received, hasLength(1));
      expect(b.received, hasLength(1));
      expect(a.received.single.message, contains('boom'));
    });

    test('a sink that throws is swallowed and does not stop the others',
        () async {
      final bad = _ThrowingReporter();
      final good = _RecordingReporter();
      final reporter = ThrottledCrashReporter(sinks: [bad, good]);

      // The assertion is that this line completes at all. If the reporter let
      // its own failure escape, a broken screen would become a broken app —
      // inside the handler that exists to catch broken screens.
      await reporter.record(StateError('boom'), StackTrace.current);

      expect(bad.calls, 1);
      expect(good.received, hasLength(1),
          reason: 'one sink failing must not silence the rest');
    });

    test('a report built from an object whose toString throws is still filed',
        () async {
      final sink = _RecordingReporter();
      final reporter = ThrottledCrashReporter(sinks: [sink]);

      await reporter.record(_Unprintable(), null);

      expect(sink.received, hasLength(1));
      expect(sink.received.single.message, 'unreportable error');
    });

    test('and that last-resort report still says which build it came from',
        () async {
      // This row says nothing at all about what broke, so the build and the
      // screen it broke on are the only things it can be worth. Filing it
      // context-less was filing a row nobody could tie to a release.
      final sink = _RecordingReporter();
      final reporter = ThrottledCrashReporter(sinks: [sink]);
      reporter.context
        ..route = '/import'
        ..appVersion = '1.1.0'
        ..buildNumber = '143';

      await reporter.record(_Unprintable(), null);

      expect(sink.received.single.buildNumber, '143');
      expect(sink.received.single.route, '/import');
    });

    test('a sink that never answers does not hold the app', () async {
      final reporter = ThrottledCrashReporter(
        sinks: [_HangingReporter(), _RecordingReporter()],
        sinkTimeout: const Duration(milliseconds: 20),
      );

      await reporter
          .record(StateError('boom'), null)
          .timeout(const Duration(seconds: 2));
    });

    test('the throttle is applied to the sinks, and carries the count',
        () async {
      var now = DateTime(2026, 8, 27, 12);
      final sink = _RecordingReporter();
      final reporter = ThrottledCrashReporter(
        sinks: [sink],
        throttle: CrashThrottle(
          window: const Duration(minutes: 10),
          perFingerprint: 1,
          clock: () => now,
        ),
      );

      for (var i = 0; i < 100; i++) {
        await reporter.record(StateError('boom'), null);
      }
      expect(sink.received, hasLength(1));

      now = now.add(const Duration(minutes: 11));
      await reporter.record(StateError('boom'), null);
      expect(sink.received, hasLength(2));
      expect(sink.received.last.occurrences, 100,
          reason: 'the row has to say how many times it really happened');
    });

    test('a reporter with no sinks at all is a working reporter', () async {
      // What a build with no backend and a silenced console amounts to. It must
      // be a configuration, not a fault.
      final reporter = ThrottledCrashReporter();
      await reporter.record(StateError('boom'), StackTrace.current);
      expect(reporter.sinks, isEmpty);
    });

    test('the Supabase sink is added only once there is a client', () {
      final reporter = ThrottledCrashReporter(
        sinks: const [ConsoleCrashReporter()],
      );
      expect(reporter.sinks, hasLength(1));

      reporter.addSink(SupabaseCrashReporter.writingWith((_) async {}));
      expect(reporter.sinks, hasLength(2));
    });

    test('the console sink prints and never throws', () async {
      final printed = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = previous);

      await const ConsoleCrashReporter().report(
        CrashReport.from(StateError('boom'), null),
      );

      expect(printed.join('\n'), contains('boom'));
    });
  });

  group('SupabaseCrashReporter', () {
    test('writes the report as a row', () async {
      Map<String, dynamic>? written;
      final sink = SupabaseCrashReporter.writingWith((row) async {
        written = row;
      });

      await sink.report(CrashReport.from(
        StateError('boom'),
        StackTrace.fromString('#0 frame'),
        context: CrashContext()..route = '/import',
      ));

      expect(written, isNotNull);
      expect(written!['message'], contains('boom'));
      expect(written!['route'], '/import');
      expect(written!['stack'], '#0 frame');
      expect(written!['fingerprint'], isA<String>());
    });

    test('a refused insert never reaches the app', () async {
      // The table denies SELECT to everyone but a moderator, and drops inserts
      // past the hourly ceiling. Neither is a thing the user should ever learn
      // about, so the composite is what swallows it.
      final reporter = ThrottledCrashReporter(
        sinks: [
          SupabaseCrashReporter.writingWith(
            (_) async => throw StateError('permission denied'),
          ),
        ],
      );

      await reporter.record(StateError('boom'), null);
    });
  });

  // ---------------------------------------------------------------------------
  // The same table, for the failures that never throw
  // ---------------------------------------------------------------------------
  // A handled failure, a degraded result and a silent fallback are the majority
  // of what goes wrong in this app, and none of them reach the handlers `main`
  // installs. They share this transport rather than getting a second one,
  // because when somebody says "it didn't work" there has to be ONE place to
  // look.
  group('CrashReport.diagnostic', () {
    test('goes into the same table under its own event', () {
      final report = CrashReport.diagnostic(
        event: DiagnosticEvent.photoImport,
        message: 'photo import: ok',
        details: const {'outcome': 'ok', 'ms': 2140},
        context: CrashContext()
          ..route = '/import'
          ..appVersion = '1.1.0'
          ..buildNumber = '143',
      );

      final row = report.toRow();
      expect(row['event'], 'photo_import');
      expect(row['message'], 'photo import: ok');
      expect(row['details'], const {'outcome': 'ok', 'ms': 2140});
      expect(row['build_number'], '143');
      expect(row.containsKey('stack'), isFalse,
          reason: 'nothing threw, so there is nothing to put there');
    });

    test('a crash keeps writing what it always wrote', () {
      final row = CrashReport.from(StateError('boom'), null).toRow();

      // The column defaults to 'crash' server-side too, so a cached bundle from
      // before the migration still writes a valid row — but sending it is what
      // keeps the two sides from disagreeing.
      expect(row['event'], 'crash');
      expect(row.containsKey('details'), isFalse,
          reason: 'an empty object is the column default; sending it says nothing');
    });

    test('two events that say the same short thing are still counted apart', () {
      // 'ok' will be the commonest message this ever writes. Fingerprinting on
      // the message alone would fold two events into one key and let one
      // event's ceiling silence the other's.
      final a = CrashReport.diagnostic(event: 'crash', message: 'ok');
      final b =
          CrashReport.diagnostic(event: DiagnosticEvent.photoImport, message: 'ok');

      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('details too large to send lose their tail, never their head', () {
      final report = CrashReport.diagnostic(
        event: DiagnosticEvent.photoImport,
        message: 'photo import: ok',
        details: <String, Object?>{
          'outcome': 'ok',
          'ms': 2140,
          for (var i = 0; i < 200; i++) 'column$i': 'x' * 40,
        },
      );

      expect(json.encode(report.details).length,
          lessThanOrEqualTo(CrashReport.maxDetailsLength));
      expect(report.details['outcome'], 'ok',
          reason: 'the outcome is what the row is for');
      expect(report.details['ms'], 2140);
      expect(report.details.containsKey('column199'), isFalse);
    });

    test('a value that cannot be encoded costs the numbers, not the row', () {
      final report = CrashReport.diagnostic(
        event: DiagnosticEvent.photoImport,
        message: 'photo import: ok',
        details: {'outcome': 'ok', 'canvas': Object()},
      );

      // The event and the build number are still worth writing without them,
      // and a diagnostic path may not throw.
      expect(report.details, isEmpty);
      expect(report.message, 'photo import: ok');
    });

    test('an event is throttled on its own ceiling, not the crash one', () async {
      // Five imports in ten minutes is an ordinary evening. Under the crash
      // ceiling — two per fingerprint — three of them would vanish, and the
      // table would under-report the feature it exists to measure.
      final sink = _RecordingReporter();
      final reporter = ThrottledCrashReporter(sinks: [sink]);

      for (var i = 0; i < 5; i++) {
        await reporter.note(DiagnosticEvent.photoImport, 'photo import: ok');
      }
      expect(sink.received, hasLength(5));

      // Meanwhile the crash ceiling is untouched by all that traffic, which is
      // the point of the two being separate counters rather than one.
      for (var i = 0; i < 5; i++) {
        await reporter.record(StateError('boom'), null);
      }
      expect(sink.received.where((r) => r.event == DiagnosticEvent.crash),
          hasLength(2));
    });

    test('note never throws, whatever it is handed', () async {
      final reporter = ThrottledCrashReporter(sinks: [_ThrowingReporter()]);

      // The assertion is that these lines complete.
      await reporter.note(DiagnosticEvent.photoImport, '');
      await reporter.note(DiagnosticEvent.photoImport, 'x',
          details: {'bad': Object()});
    });
  });
}

/// An error object that cannot describe itself — rarer than it sounds, and
/// exactly the sort of thing that would otherwise take down the reporter.
class _Unprintable {
  @override
  String toString() => throw StateError('cannot even say what went wrong');
}
