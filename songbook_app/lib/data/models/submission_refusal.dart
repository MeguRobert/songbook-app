/// Why the server would not accept a submission.
///
/// The gate lives in `public.assert_may_submit`
/// (`supabase/migrations/20260822120500_app_settings_and_submission_gate.sql`)
/// and raises bare snake_case tokens rather than sentences. This maps them to a
/// closed set the UI can localise.
///
/// Same reasoning as [AuthFailureCode] in `auth_repository.dart`, and for the
/// same reason: the app is trilingual, so a server-generated English sentence is
/// unusable, and matching on prose is unstable. The one difference is that these
/// tokens are ours — they are chosen in a migration in this repo, not by GoTrue —
/// so the mapping is a constant table and there is no message-text fallback to
/// maintain.
enum SubmissionRefusal {
  /// An administrator has closed submissions entirely.
  submissionsClosed,

  /// The account exists but has never confirmed its email address.
  emailNotConfirmed,

  /// The contribution guidelines have not been accepted yet.
  guidelinesNotAccepted,

  /// No display name, so there would be nothing to credit the song to.
  displayNameRequired,

  /// This account has already submitted as many songs today as the cap allows.
  dailyLimitReached,

  /// Another approved song in the same book already carries this hymn number.
  ///
  /// Not one of the gate's tokens — this one is a unique-index name, and it is
  /// here because auto-publication moved the collision forward in time. Before
  /// `20260829120000_moderators_publish_their_own_songs.sql` a moderator's
  /// submission waited in the queue and the clash surfaced when they pressed
  /// Approve; now it surfaces as they share, where the only message available
  /// was "check your connection and try again". The failure is not new, the
  /// place it lands is.
  numberTaken,

  /// Reached the server and was refused for a reason not worth its own message.
  unknown,
}

/// The token each refusal is raised as. Kept next to the enum so the pair cannot
/// drift, and matched as a substring because a `PostgrestException` may wrap the
/// token in its own prose.
const _tokens = <String, SubmissionRefusal>{
  'submissions_closed': SubmissionRefusal.submissionsClosed,
  'email_not_confirmed': SubmissionRefusal.emailNotConfirmed,
  'guidelines_not_accepted': SubmissionRefusal.guidelinesNotAccepted,
  'display_name_required': SubmissionRefusal.displayNameRequired,
  'daily_limit_reached': SubmissionRefusal.dailyLimitReached,
  // The constraint's own name, from
  // `20260728120000_songs_and_roles.sql`. Postgres puts it in the message of
  // every 23505 it raises for that index, and it is ours rather than GoTrue's,
  // so it is as stable as the snake_case tokens above.
  'songs_approved_number_unique': SubmissionRefusal.numberTaken,
};

extension SubmissionRefusalParsing on SubmissionRefusal {
  /// Recognises a refusal in a server error message.
  ///
  /// Substring matching rather than equality: Postgres exceptions arrive wrapped
  /// in context ("new row violates ..."), and the token is what is stable inside
  /// it. Anything unrecognised becomes [SubmissionRefusal.unknown] rather than
  /// being shown raw — a Postgres exception is never a user-facing sentence.
  static SubmissionRefusal fromServerMessage(String? message) {
    if (message == null) return SubmissionRefusal.unknown;
    for (final entry in _tokens.entries) {
      if (message.contains(entry.key)) return entry.value;
    }
    return SubmissionRefusal.unknown;
  }
}

/// A submission the server refused, carrying a localisable [reason].
class SubmissionRefused implements Exception {
  final SubmissionRefusal reason;

  /// For logs only. Showing it would defeat the point of the mapping.
  final String? debugMessage;

  const SubmissionRefused(this.reason, [this.debugMessage]);

  @override
  String toString() =>
      'SubmissionRefused($reason)${debugMessage == null ? '' : ': $debugMessage'}';
}
