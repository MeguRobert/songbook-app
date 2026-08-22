import 'song.dart';

/// Where a submitted song is in review.
///
/// Deliberately four states plus a reason, not a boolean. A boolean cannot tell
/// "not sent yet" from "turned down", and gives a contributor no way to learn
/// why — which is the difference between a queue people use and one they abandon.
/// Mirrors the `song_status` enum in
/// `supabase/migrations/20260728120000_songs_and_roles.sql`.
enum SubmissionStatus {
  draft('draft'),
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const SubmissionStatus(this.wireName);

  /// Explicit rather than [Enum.name] so renaming a constant cannot silently
  /// stop matching rows already in the database.
  final String wireName;

  static SubmissionStatus fromWireName(String value) {
    for (final status in SubmissionStatus.values) {
      if (status.wireName == value) return status;
    }
    // An unknown status is treated as pending rather than thrown away: the row
    // exists and hiding it would be worse than showing it in the wrong bucket.
    return SubmissionStatus.pending;
  }
}

/// One song someone submitted to the shared catalogue, with its review state.
class Submission {
  /// Server row id. Distinct from the song's [SongId] — this identifies the
  /// *submission*, and is what approve and reject act on.
  final String id;

  final SubmissionStatus status;

  /// Why it was turned down. Non-null only for [SubmissionStatus.rejected] —
  /// the database trigger clears it on any other state, so a stale reason
  /// cannot linger on an approved song.
  final String? rejectionReason;

  final DateTime? submittedAt;

  /// The name recorded when the song was submitted.
  ///
  /// A frozen copy, not a join to the contributor's current display name — see
  /// `supabase/migrations/20260822120200_frozen_attribution.sql`. Null only for a
  /// draft, which has not been offered to anybody yet.
  final String? submittedByName;

  /// True when the submitting account has since been deleted.
  ///
  /// The song stays in the catalogue and keeps [submittedByName]; what is gone is
  /// the account behind it. Worth distinguishing, because "submitted by Anna" and
  /// "submitted by Anna, who has since left" are different things to show.
  final bool ownerGone;

  /// The song itself, reconstructed from the row's payload.
  final Song song;

  const Submission({
    required this.id,
    required this.status,
    required this.song,
    this.rejectionReason,
    this.submittedAt,
    this.submittedByName,
    this.ownerGone = false,
  });

  bool get isPending => status == SubmissionStatus.pending;
  bool get isRejected => status == SubmissionStatus.rejected;

  /// Builds one from a `songs` row, or null if the payload cannot be read.
  ///
  /// Forgiving on purpose: one unreadable row must not empty a moderator's
  /// queue or a contributor's list.
  static Submission? tryFromRow(Map<String, dynamic> row) {
    try {
      final payload = row['payload'];
      if (payload is! Map) return null;
      final json = Map<String, dynamic>.from(payload);
      // Server rows are user submissions, so they carry an explicit id that
      // cannot collide with a hymnal number or a local song.
      json['id'] = 'user:${row['id']}';

      final submittedAt = row['submitted_at'];

      return Submission(
        id: row['id'] as String,
        status: SubmissionStatus.fromWireName((row['status'] ?? 'pending') as String),
        rejectionReason: row['rejection_reason'] as String?,
        submittedAt:
            submittedAt is String ? DateTime.tryParse(submittedAt) : null,
        submittedByName: row['submitted_by_name'] as String?,
        // `owner_id` is only absent on a user song whose account was deleted;
        // the FK is ON DELETE SET NULL rather than CASCADE precisely so the song
        // survives. A hymnal row also has no owner, but hymnal rows never come
        // through the submission queries.
        ownerGone: row.containsKey('owner_id') && row['owner_id'] == null,
        song: Song.fromJson(json),
      );
    } catch (_) {
      return null;
    }
  }
}
