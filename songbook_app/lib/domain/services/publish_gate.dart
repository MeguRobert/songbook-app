import '../../data/models/app_settings.dart';

/// What is stopping this person offering a song to the shared catalogue.
///
/// Ordered by how it is best to ask, not by how the checks happen to be written.
enum PublishStop {
  /// An administrator has closed submissions. Nothing the contributor can do.
  submissionsClosed,

  /// Not signed in. This is the login gate.
  signIn,

  /// Signed in, but the address was never confirmed. Requires leaving the app.
  confirmEmail,

  /// No display name, so there would be nothing to credit the song to.
  displayName,

  /// The contribution guidelines have not been accepted yet.
  guidelines,
}

/// Everything the gate needs to know, gathered by the caller.
///
/// A plain value object so the decision is a pure function and can be tested
/// without a widget tree, a Supabase client or a signed-in session.
class PublishReadiness {
  final bool isSignedIn;
  final bool isEmailConfirmed;
  final String? displayName;
  final bool hasAcceptedGuidelines;
  final AppSettings settings;

  const PublishReadiness({
    required this.isSignedIn,
    required this.isEmailConfirmed,
    required this.displayName,
    required this.hasAcceptedGuidelines,
    required this.settings,
  });
}

/// The first thing standing in the way, or null if nothing is.
///
/// **The order is the design.** Two rules produced it:
///
/// 1. Anything the contributor cannot fix comes first. Making somebody sign in,
///    confirm an email and read the guidelines, and only then telling them the
///    door was shut the whole time, is how a contribution flow gets abandoned.
///    [PublishStop.submissionsClosed] is therefore checked before the login gate
///    even though it is the rarer case.
/// 2. Among the rest, whatever forces them to leave the app comes before
///    whatever they can finish inline. Confirming an address means going to an
///    email client; a name and a tick take seconds. Collecting the quick things
///    first would mean collecting them from somebody who is then blocked anyway.
///
/// **Not checked here: the daily cap.** The client does not reliably know how
/// many songs this account has already submitted today, and asking would be a
/// round trip for a case that is nearly always fine. It is enforced by
/// `assert_may_submit` and arrives as a [SubmissionRefusal.dailyLimitReached] on
/// the attempt. That asymmetry is deliberate: this function exists to give good
/// prompts, not to be the gate. The gate is in Postgres.
PublishStop? firstUnmetStop(PublishReadiness state) {
  if (!state.settings.submissionsOpen) return PublishStop.submissionsClosed;

  if (!state.isSignedIn) return PublishStop.signIn;

  if (state.settings.requireConfirmedEmail && !state.isEmailConfirmed) {
    return PublishStop.confirmEmail;
  }

  final name = state.displayName?.trim() ?? '';
  if (name.isEmpty) return PublishStop.displayName;

  if (!state.hasAcceptedGuidelines) return PublishStop.guidelines;

  return null;
}
