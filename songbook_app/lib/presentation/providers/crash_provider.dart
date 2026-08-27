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
