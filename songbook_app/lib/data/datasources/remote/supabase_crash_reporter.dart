import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/services/crash_reporter.dart';

/// Writes a crash report to `public.error_reports`.
///
/// Lives here rather than beside the rest of [CrashReporter] because this is the
/// only piece that needs a [SupabaseClient], and `lib/domain/services/` is meant
/// to stay runnable under a plain `flutter test` with no backend in sight. It is
/// also the layer every other Supabase call in this app already lives in.
///
/// **Why writing to Postgres from an anonymous client is safe here.** The table
/// grants `anon` INSERT and nothing else — no SELECT, no UPDATE, no DELETE — and
/// a trigger overwrites `user_id` and `created_at`, clamps every text column, and
/// caps the table's insert rate globally. All of that is in
/// `supabase/migrations/20260827120000_error_reports.sql`, with the reasoning.
/// Nothing on this side is trusted, so nothing on this side needs to be.
class SupabaseCrashReporter extends CrashReporter {
  /// The table name, in one place, so a rename is one edit and a typo is one
  /// silently-failing sink rather than several.
  static const String table = 'error_reports';

  /// A short budget, in the same spirit as `SupabaseConfig.fetchTimeout`: the
  /// app is expected to be used offline and on a free-tier project that sleeps.
  /// Waiting on a report is never worth it — the composite times out too, this
  /// is the inner bound so a stalled socket is released rather than parked.
  static const Duration writeTimeout = Duration(seconds: 4);

  SupabaseCrashReporter(SupabaseClient client)
      : _insert = ((row) => client.from(table).insert(row));

  /// Lets the tests drive the whole path — report shaping, row mapping, error
  /// swallowing — without a live project or a mock of Supabase's builder chain,
  /// which is fluent enough that mocking it would test the mock.
  @visibleForTesting
  SupabaseCrashReporter.writingWith(this._insert);

  final Future<void> Function(Map<String, dynamic> row) _insert;

  @override
  Future<void> report(CrashReport report) async {
    // The throw is left to propagate to ThrottledCrashReporter, which is where
    // the swallowing is centralised. Catching it here as well would hide a
    // misconfigured table from the tests that check the swallow actually works.
    await _insert(report.toRow()).timeout(writeTimeout);
  }
}
