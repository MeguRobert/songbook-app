import 'package:supabase_flutter/supabase_flutter.dart';

/// Why an authentication attempt failed, in terms the UI can localize.
///
/// GoTrue reports failures as English prose ("Invalid login credentials"), which
/// is unusable in a trilingual app and unstable to match on. The old Songbook app
/// solved this with an error-code to message table and it was one of the few
/// pieces of it worth keeping verbatim — see
/// `docs/plans/2026-07-27-old-songbook-migration-analysis.md`, idea 5.
///
/// Mapping to a closed set here means the presentation layer switches on an enum
/// and never sees a server string.
enum AuthFailureCode {
  invalidCredentials,
  emailNotConfirmed,
  emailAlreadyRegistered,
  weakPassword,
  invalidEmail,
  rateLimited,

  /// Reached the server, and it refused for a reason not worth its own message.
  serverRejected,

  /// Never reached the server. Distinct from [serverRejected] because the advice
  /// differs: check your connection, rather than check what you typed.
  network,

  unknown,
}

/// A failed auth attempt, carrying a localizable [code].
///
/// [debugMessage] is for logs only. Showing it to a user would defeat the point
/// of the mapping.
class AuthFailure implements Exception {
  final AuthFailureCode code;
  final String? debugMessage;

  const AuthFailure(this.code, [this.debugMessage]);

  @override
  String toString() => 'AuthFailure($code)${debugMessage == null ? '' : ': $debugMessage'}';
}

/// Accounts, on top of Supabase Auth.
///
/// Everything here is optional to the app. Songbook works signed-out — the
/// bundled hymnal needs no account and no network — so nothing in this class is
/// on a startup path and no screen gates on it.
class AuthRepository {
  final GoTrueClient _auth;

  AuthRepository(this._auth);

  /// The signed-in user, or null. Synchronous: the SDK restores a persisted
  /// session during `Supabase.initialize`, so this is already correct at startup.
  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => currentUser != null;

  /// Emits on sign-in, sign-out, token refresh and user updates.
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Whether this account has confirmed its email address.
  ///
  /// Supabase can be configured to permit unconfirmed sign-in, so possessing a
  /// session is not proof of a verified address. Contributing a song should
  /// require verification; reading should not.
  bool get isEmailConfirmed => currentUser?.emailConfirmedAt != null;

  Future<void> signUp({required String email, required String password}) async {
    await _guard(() => _auth.signUp(email: email.trim(), password: password));
  }

  Future<void> signIn({required String email, required String password}) async {
    await _guard(
      () => _auth.signInWithPassword(email: email.trim(), password: password),
    );
  }

  Future<void> signOut() async {
    await _guard(() => _auth.signOut());
  }

  /// Sends a password-reset email. Deliberately does not report whether the
  /// address exists — that would turn this into an account-enumeration oracle.
  Future<void> sendPasswordReset(String email) async {
    await _guard(() => _auth.resetPasswordForEmail(email.trim()));
  }

  /// Re-sends the confirmation email for an account that never verified.
  Future<void> resendConfirmation(String email) async {
    await _guard(
      () => _auth.resend(type: OtpType.signup, email: email.trim()),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (error) {
      throw AuthFailure(_classify(error), error.message);
    } catch (error) {
      // Socket failures, DNS, timeouts, and a paused free-tier project (HTTP
      // 540) all land here. None of them are the user's fault or the user's
      // problem to interpret.
      throw AuthFailure(AuthFailureCode.network, error.toString());
    }
  }

  /// Maps a GoTrue failure onto the closed set above.
  ///
  /// Prefers `error.code`, which is a stable machine-readable identifier, and
  /// falls back to matching the message only where no code is supplied. The
  /// fallback is why this is a function rather than a constant map: message text
  /// is a moving target and must never be the primary signal.
  AuthFailureCode _classify(AuthException error) {
    switch (error.code) {
      // Every string below except this first one appears in gotrue's own
      // ErrorCode enum (verified against gotrue 2.26.0, which mirrors Supabase's
      // errorcodes.go). `invalid_credentials` is documented by Supabase but is
      // NOT in that enum — `AuthException.code` is a raw passthrough of the
      // server's error_code, so it can carry codes the enum does not list. That
      // is precisely why the message fallback below still exists for this case
      // rather than being dead weight.
      case 'invalid_credentials':
        return AuthFailureCode.invalidCredentials;
      case 'email_not_confirmed':
        return AuthFailureCode.emailNotConfirmed;
      case 'user_already_exists':
      case 'email_exists':
        return AuthFailureCode.emailAlreadyRegistered;
      case 'weak_password':
        return AuthFailureCode.weakPassword;
      case 'validation_failed':
        return AuthFailureCode.invalidEmail;
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
      case 'over_sms_send_rate_limit':
        return AuthFailureCode.rateLimited;
      case 'request_timeout':
        return AuthFailureCode.network;
      case 'signup_disabled':
      case 'user_banned':
      case 'email_provider_disabled':
        return AuthFailureCode.serverRejected;
    }

    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return AuthFailureCode.invalidCredentials;
    }
    if (message.contains('email not confirmed')) {
      return AuthFailureCode.emailNotConfirmed;
    }
    if (message.contains('already registered')) {
      return AuthFailureCode.emailAlreadyRegistered;
    }
    if (message.contains('password should be')) {
      return AuthFailureCode.weakPassword;
    }
    if (message.contains('rate limit')) {
      return AuthFailureCode.rateLimited;
    }
    return AuthFailureCode.serverRejected;
  }
}
