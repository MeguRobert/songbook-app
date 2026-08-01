import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/remote/supabase_config.dart';
import '../models/song.dart';
import '../models/submission.dart';

/// Submitting songs to the shared catalogue, and moderating what arrives.
///
/// **Almost nothing here enforces anything.** Every rule that matters —
/// who may read an unapproved song, who may approve one, that a rejection needs
/// a reason, that a contributor cannot promote their own submission — lives in
/// the database, in RLS policies and a status trigger
/// (`supabase/migrations/20260728120100_songs_rls.sql`). This class asks; the
/// server decides.
///
/// That division is the whole point. The old Songbook app put approval in the
/// client and shipped every unapproved song to every device. Here, a client
/// asking for pending songs it may not see gets an empty list, and a client
/// trying to approve its own song gets an error from Postgres.
class SubmissionRepository {
  final SupabaseClient _client;

  SubmissionRepository(this._client);

  /// Columns needed to render a submission. `payload` carries the song itself.
  static const _columns =
      'id, status, rejection_reason, submitted_at, number, title, payload';

  /// Whether the signed-in user may moderate.
  ///
  /// Calls the `is_admin()` function rather than reading a roles table, because
  /// there is deliberately no client-readable roles table — `user_roles` grants
  /// nothing to `anon` or `authenticated`. The function is `security definer`, so
  /// it can answer without exposing who else is an admin.
  ///
  /// This is for *showing or hiding UI only*. It is not a security check: an
  /// attacker who forces it true still cannot approve anything, because the
  /// server re-checks on every write.
  Future<bool> isAdmin() async {
    try {
      final result = await _client
          .rpc('is_admin')
          .timeout(SupabaseConfig.fetchTimeout);
      return result == true;
    } catch (_) {
      // Offline, or signed out. Hiding moderation UI is the safe default.
      return false;
    }
  }

  /// Offers a song to the shared catalogue.
  ///
  /// Inserted as `pending`, owned by the caller. The insert policy will not
  /// accept any other combination — a row claiming to be already approved, or
  /// owned by someone else, or canonical hymnal content, is refused server-side.
  Future<void> submit(Song song) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('cannot submit a song while signed out');
    }

    final payload = song.toJson()
      // The server assigns identity; a client-chosen id would let two people
      // claim the same one.
      ..remove('id');

    await _client.from('songs').insert({
      'owner_id': user.id,
      'source': 'user',
      'status': 'pending',
      'number': song.number,
      'title': song.title,
      'book': song.book,
      'tags': song.tags,
      'payload': payload,
    });
  }

  /// Songs the signed-in user has submitted, newest first.
  ///
  /// No `owner_id` filter is needed or wanted: RLS already restricts this to the
  /// caller's own rows plus anything approved. Adding a client-side filter would
  /// imply the server was not already doing it.
  Future<List<Submission>> mySubmissions() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final rows = await _client
        .from('songs')
        .select(_columns)
        .eq('owner_id', user.id)
        .order('submitted_at', ascending: false)
        .timeout(SupabaseConfig.fetchTimeout);

    return _parse(rows);
  }

  /// The moderation queue: everything awaiting a decision, oldest first so the
  /// longest-waiting contributor is served first.
  ///
  /// A non-admin calling this gets their own pending songs and nothing else,
  /// because that is what RLS permits them to see. It is not an error.
  Future<List<Submission>> pendingQueue() async {
    final rows = await _client
        .from('songs')
        .select(_columns)
        .eq('status', 'pending')
        .order('submitted_at', ascending: true)
        .timeout(SupabaseConfig.fetchTimeout);

    return _parse(rows);
  }

  /// Accepts a submission into the shared catalogue.
  ///
  /// `reviewed_at` and `reviewed_by` are set by the trigger, not sent from here:
  /// a client-supplied reviewer identity would be a claim rather than a fact.
  Future<void> approve(String submissionId) async {
    await _client
        .from('songs')
        .update({'status': 'approved'}).eq('id', submissionId);
  }

  /// Turns a submission down, with a reason the contributor will see.
  ///
  /// The reason is required by a database check, so an empty one fails server-side
  /// too — but rejecting it here gives an immediate, localizable error instead of
  /// a Postgres exception.
  Future<void> reject(String submissionId, String reason) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('a rejection needs a reason the contributor can act on');
    }
    await _client.from('songs').update({
      'status': 'rejected',
      'rejection_reason': reason.trim(),
    }).eq('id', submissionId);
  }

  /// Withdraws a submission that has not been decided yet.
  Future<void> withdraw(String submissionId) async {
    await _client.from('songs').delete().eq('id', submissionId);
  }

  List<Submission> _parse(List<Map<String, dynamic>> rows) {
    final result = <Submission>[];
    for (final row in rows) {
      final submission = Submission.tryFromRow(row);
      if (submission != null) result.add(submission);
    }
    return result;
  }
}
