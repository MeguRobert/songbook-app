/// What someone is allowed to do.
///
/// Mirrors the `roles` table in
/// `supabase/migrations/20260822120000_role_ladder.sql`, including its ranks.
/// The ranks are what every permission question is answered with — never the
/// role's identity — so that inserting a tier later changes this file and
/// nothing that reads it.
///
/// **These are display roles, not security.** Every one of the capabilities
/// below is re-decided by the database on every write: RLS policies and triggers
/// call `can_moderate()` and `is_administrator()`, which read a table no client
/// has any privilege on. Forcing a value here changes which buttons are drawn
/// and nothing else.
enum AppRole {
  member('member', 10),
  moderator('moderator', 50),
  administrator('administrator', 90);

  const AppRole(this.wireName, this.rank);

  /// Explicit rather than [Enum.name], so renaming a constant cannot silently
  /// stop matching rows already in the database.
  final String wireName;

  /// Position in the ladder. Gaps are intentional — a tier can be added between
  /// two existing ones without renumbering.
  final int rank;

  /// May review submissions, and edit or remove any song.
  bool get canModerate => rank >= moderator.rank;

  /// May manage accounts and app settings.
  bool get isAdministrator => rank >= administrator.rank;

  /// Reads a role name from the server.
  ///
  /// Falls back to [member] for anything unrecognised — including a tier added
  /// to the database before this app was rebuilt. That is the safe direction:
  /// an unknown role is shown the least, never the most, and a client that has
  /// guessed too low simply sees fewer buttons than it could.
  static AppRole fromWireName(String? value) {
    for (final role in AppRole.values) {
      if (role.wireName == value) return role;
    }
    return AppRole.member;
  }
}
