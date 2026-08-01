import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/app_localizations.dart';

/// Turns an [AuthFailure] into something a person can read, in their language.
///
/// This is the whole reason [AuthFailureCode] exists. GoTrue reports failures as
/// English prose, and the app ships in Hungarian, Romanian and English — so the
/// server's message can never be shown directly. The old Songbook app solved the
/// same problem with an error-code table and it was one of the few pieces worth
/// keeping (migration analysis, idea 5).
///
/// Exhaustive by construction: [AuthFailureCode] is an enum and this switch has
/// no default, so adding a code without a message is a compile error rather than
/// a string that silently reads "Something went wrong" in production.
String authFailureMessage(AppLocalizations l10n, AuthFailure failure) {
  switch (failure.code) {
    case AuthFailureCode.invalidCredentials:
      return l10n.authErrorInvalidCredentials;
    case AuthFailureCode.emailNotConfirmed:
      return l10n.authErrorEmailNotConfirmed;
    case AuthFailureCode.emailAlreadyRegistered:
      return l10n.authErrorEmailAlreadyRegistered;
    case AuthFailureCode.weakPassword:
      return l10n.authErrorWeakPassword;
    case AuthFailureCode.invalidEmail:
      return l10n.authErrorInvalidEmail;
    case AuthFailureCode.rateLimited:
      return l10n.authErrorRateLimited;
    case AuthFailureCode.serverRejected:
      return l10n.authErrorServerRejected;
    case AuthFailureCode.network:
      return l10n.authErrorNetwork;
    case AuthFailureCode.unknown:
      return l10n.authErrorUnknown;
  }
}
