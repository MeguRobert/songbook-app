import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/crash_reporter.dart';

/// Where the app currently is, for whatever breaks next.
///
/// `main` overrides this with the instance it also handed to the crash reporter,
/// so the router writing a location into it is what puts `/import` on the report
/// the owner reads later. Unoverridden — in every widget test, and in any build
/// with no reporting installed — it is a plain object nobody reads, which is why
/// the router can depend on it unconditionally.
final crashContextProvider = Provider<CrashContext>((ref) => CrashContext());

/// The reporter itself, for the parts of the app that file events rather than
/// crash.
///
/// **Null by default, and the null is the design.** `main` overrides this with
/// the one reporter it built; nothing else may construct one, because a second
/// reporter would carry a second throttle and the ceiling that bounds this table
/// would stop being a ceiling. Everywhere else — every widget test, every unit
/// test, the measurement harness, any build with no backend — it stays null and
/// the feature that would have recorded simply does not, which is the same
/// "reporting is a configuration, not a requirement" rule
/// [ThrottledCrashReporter] itself is built around.
///
/// Typed as the concrete [ThrottledCrashReporter] rather than the [CrashReporter]
/// interface: what a caller needs from this is the composite's promise never to
/// throw, and a bare sink does not make it.
final crashReporterProvider = Provider<ThrottledCrashReporter?>((ref) => null);
