import 'app_role.dart';

/// How many songs one account has in each review state.
class SongTally {
  final int approved;
  final int pending;
  final int rejected;
  final int draft;

  const SongTally({
    this.approved = 0,
    this.pending = 0,
    this.rejected = 0,
    this.draft = 0,
  });

  /// What a moderator actually wants to know before deciding: has this person
  /// contributed usefully before, or been turned down repeatedly?
  int get decided => approved + rejected;

  factory SongTally.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SongTally();
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return SongTally(
      approved: read('approved'),
      pending: read('pending'),
      rejected: read('rejected'),
      draft: read('draft'),
    );
  }
}

/// One account, as the admin panel sees it.
///
/// **The only place an email address appears in this app.** Addresses live in
/// `auth.users`, which no client may read; this object is assembled by the
/// `admin-users` Edge Function and returned only to a caller the server has
/// confirmed is an administrator. Do not surface [email] anywhere outside the
/// admin panel.
class ManagedUser {
  final String id;
  final String? email;
  final bool emailConfirmed;
  final String? displayName;
  final AppRole role;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final DateTime? guidelinesAcceptedAt;
  final SongTally songs;

  const ManagedUser({
    required this.id,
    required this.role,
    required this.songs,
    this.email,
    this.emailConfirmed = false,
    this.displayName,
    this.createdAt,
    this.lastSignInAt,
    this.guidelinesAcceptedAt,
  });

  /// Has never signed in, so an invitation was never taken up.
  bool get isDormant => lastSignInAt == null;

  bool get hasAcceptedGuidelines => guidelinesAcceptedAt != null;

  /// What to show in a list. Falls back to the address only inside the admin
  /// panel, where it is already visible, and never to a bare uuid — a row
  /// labelled with a uuid is a row nobody can act on confidently.
  String get label => (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!.trim()
      : (email ?? id);

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  /// Builds one from the Edge Function's JSON, or null if it is unreadable.
  ///
  /// Forgiving for the same reason [Submission.tryFromRow] is: one malformed row
  /// must not empty the whole user list.
  static ManagedUser? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;

    return ManagedUser(
      id: id,
      email: json['email'] as String?,
      emailConfirmed: json['emailConfirmed'] == true,
      displayName: json['displayName'] as String?,
      role: AppRole.fromWireName(json['role'] as String?),
      createdAt: _date(json['createdAt']),
      lastSignInAt: _date(json['lastSignInAt']),
      guidelinesAcceptedAt: _date(json['guidelinesAcceptedAt']),
      songs: SongTally.fromJson(
        json['songs'] is Map
            ? Map<String, dynamic>.from(json['songs'] as Map)
            : null,
      ),
    );
  }
}
