/// Settings that govern contribution, held on the server and shared by everyone.
///
/// Distinct from the device-local settings in `settings_repository.dart` (theme,
/// font size, default view), which are one person's preferences. These are the
/// project's rules, editable only by an administrator, and readable by everyone
/// including signed-out visitors — a contributor has to be able to read the
/// guidelines and see whether the door is open before they sign in.
///
/// Mirrors `public.app_settings`
/// (`supabase/migrations/20260822120500_app_settings_and_submission_gate.sql`).
class AppSettings {
  /// Master switch. When false, nothing new is accepted for review.
  final bool submissionsOpen;

  /// Whether an unverified address may submit.
  final bool requireConfirmedEmail;

  /// How many songs one account may submit per day. Zero means none, which
  /// [submissionsOpen] says more clearly.
  final int dailySubmissionCap;

  /// The rules a contributor accepts before their first submission, per language.
  final Map<String, String> guidelines;

  final DateTime? updatedAt;

  const AppSettings({
    this.submissionsOpen = true,
    this.requireConfirmedEmail = true,
    this.dailySubmissionCap = 5,
    this.guidelines = const {},
    this.updatedAt,
  });

  /// The guidelines in [languageCode], falling back to English.
  ///
  /// English is the fallback rather than the empty string because an empty
  /// guidelines box makes the acceptance tick meaningless, and a rule in the
  /// wrong language is still a rule.
  String guidelinesFor(String languageCode) {
    final text = guidelines[languageCode];
    if (text != null && text.trim().isNotEmpty) return text;
    return guidelines['en'] ?? '';
  }

  factory AppSettings.fromRow(Map<String, dynamic> row) {
    final updatedAt = row['updated_at'];
    return AppSettings(
      submissionsOpen: row['submissions_open'] != false,
      requireConfirmedEmail: row['require_confirmed_email'] != false,
      dailySubmissionCap: (row['daily_submission_cap'] as num?)?.toInt() ?? 5,
      guidelines: {
        'en': (row['guidelines_en'] as String?) ?? '',
        'hu': (row['guidelines_hu'] as String?) ?? '',
        'ro': (row['guidelines_ro'] as String?) ?? '',
      },
      updatedAt:
          updatedAt is String ? DateTime.tryParse(updatedAt)?.toLocal() : null,
    );
  }

  /// Only the columns an administrator may change. `updated_at` and `updated_by`
  /// are the database's to set, not ours to claim.
  Map<String, dynamic> toUpdate() => {
        'submissions_open': submissionsOpen,
        'require_confirmed_email': requireConfirmedEmail,
        'daily_submission_cap': dailySubmissionCap,
        'guidelines_en': guidelines['en'] ?? '',
        'guidelines_hu': guidelines['hu'] ?? '',
        'guidelines_ro': guidelines['ro'] ?? '',
      };

  AppSettings copyWith({
    bool? submissionsOpen,
    bool? requireConfirmedEmail,
    int? dailySubmissionCap,
    Map<String, String>? guidelines,
  }) =>
      AppSettings(
        submissionsOpen: submissionsOpen ?? this.submissionsOpen,
        requireConfirmedEmail: requireConfirmedEmail ?? this.requireConfirmedEmail,
        dailySubmissionCap: dailySubmissionCap ?? this.dailySubmissionCap,
        guidelines: guidelines ?? this.guidelines,
        updatedAt: updatedAt,
      );
}
