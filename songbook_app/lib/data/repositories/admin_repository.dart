import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/remote/supabase_config.dart';
import '../models/app_role.dart';
import '../models/app_settings.dart';
import '../models/managed_user.dart';

/// Why an administrative action failed, in terms the UI can localize.
enum AdminFailureCode {
  /// The server does not consider this caller an administrator. Not a bug to
  /// route around: the panel should not have been reachable.
  forbidden,

  /// Refused because it was aimed at the caller's own account.
  cannotActOnSelf,

  /// Refused because it would have left the project with no administrator.
  lastAdministrator,

  /// The address is already registered.
  emailAlreadyRegistered,

  /// Never reached the server.
  network,

  unknown,
}

class AdminFailure implements Exception {
  final AdminFailureCode code;

  /// For logs only.
  final String? debugMessage;

  const AdminFailure(this.code, [this.debugMessage]);

  @override
  String toString() =>
      'AdminFailure($code)${debugMessage == null ? '' : ': $debugMessage'}';
}

/// Managing accounts and the project's shared settings.
///
/// **Nothing here enforces anything**, in the same way and for the same reason as
/// [SubmissionRepository]. Account listing, creation and deletion go through the
/// `admin-users` Edge Function, which re-checks `is_administrator()` as the
/// caller before it does anything at all; settings go through RLS. This class
/// asks, and the server decides.
///
/// The division matters most here, because this is the class whose methods would
/// be catastrophic if the client were trusted: an attacker who forced
/// [currentRole] to administrator gets a 403 from the function and a policy
/// violation from Postgres.
class AdminRepository {
  final SupabaseClient _client;

  AdminRepository(this._client);

  static const _functionName = 'admin-users';

  /// The signed-in user's role.
  ///
  /// Reads it through `role_rank`, not by selecting from `user_roles` — that
  /// table grants nothing to any client, precisely so nobody can enumerate who
  /// holds what. Signed out is [AppRole.member], which is also the fallback for
  /// any failure: showing fewer buttons than earned is recoverable, showing more
  /// is not.
  Future<AppRole> currentRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return AppRole.member;
    try {
      final rank = await _client
          .rpc('role_rank', params: {'uid': user.id})
          .timeout(SupabaseConfig.fetchTimeout);
      final value = (rank as num?)?.toInt() ?? 0;
      // Highest role whose rank the caller meets. Reading the rank rather than
      // the name is what lets a tier be added server-side without this returning
      // nonsense: an unrecognised rank resolves to the nearest tier below it.
      AppRole resolved = AppRole.member;
      for (final role in AppRole.values) {
        if (value >= role.rank) resolved = role;
      }
      return resolved;
    } catch (_) {
      return AppRole.member;
    }
  }

  /// Every account, newest sign-in first.
  Future<List<ManagedUser>> listUsers() async {
    final data = await _invoke({'action': 'list'});
    final users = data['users'];
    if (users is! List) return const [];

    final parsed = <ManagedUser>[];
    for (final entry in users) {
      final user = ManagedUser.tryFromJson(entry);
      if (user != null) parsed.add(user);
    }

    // Sorted here rather than server-side: the function returns whatever the
    // admin API's pagination order is, and "who was here recently" is the
    // question this list is usually asked.
    parsed.sort((a, b) {
      final left = a.lastSignInAt, right = b.lastSignInAt;
      if (left == null && right == null) return a.label.compareTo(b.label);
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return parsed;
  }

  Future<void> invite(String email, {AppRole role = AppRole.member}) =>
      _invoke({
        'action': 'invite',
        'email': email.trim(),
        'role': role.wireName,
      });

  Future<void> setRole(String userId, AppRole role) => _invoke({
        'action': 'set_role',
        'userId': userId,
        'role': role.wireName,
      });

  /// Deletes an account for good.
  ///
  /// Their approved songs stay in the catalogue, orphaned and still carrying the
  /// name recorded when they submitted — see migration
  /// `20260822120300_orphan_songs_on_account_delete.sql`. Anything of theirs that
  /// was never approved goes with them.
  Future<void> deleteUser(String userId) =>
      _invoke({'action': 'delete', 'userId': userId});

  // --- Settings ---

  Future<AppSettings> settings() async {
    final row = await _client
        .from('app_settings')
        .select()
        .eq('id', 1)
        .single()
        .timeout(SupabaseConfig.fetchTimeout);
    return AppSettings.fromRow(row);
  }

  /// Writes the settings. Refused by RLS for anyone but an administrator.
  Future<void> saveSettings(AppSettings settings) async {
    try {
      await _client
          .from('app_settings')
          .update(settings.toUpdate())
          .eq('id', 1)
          .timeout(SupabaseConfig.fetchTimeout);
    } on PostgrestException catch (error) {
      // A policy refusal on an UPDATE is reported as zero rows affected rather
      // than an error, so this catches the coarser failures only. The panel is
      // administrator-gated and the write is re-checked server-side either way.
      throw AdminFailure(AdminFailureCode.forbidden, error.message);
    } catch (error) {
      throw AdminFailure(AdminFailureCode.network, error.toString());
    }
  }

  /// Records that this user has accepted the contribution guidelines.
  ///
  /// Self-service by design: the claim "I have read this" is only ever the user's
  /// own to make, so `profiles_write_own` is the right level of trust and no
  /// privileged path is needed.
  Future<void> acceptGuidelines() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AdminFailure(AdminFailureCode.forbidden, 'signed out');
    }
    await _client.from('profiles').update({
      'guidelines_accepted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', user.id);
  }

  /// Sets the name a submission will be credited to.
  Future<void> setDisplayName(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AdminFailure(AdminFailureCode.forbidden, 'signed out');
    }
    await _client
        .from('profiles')
        .update({'display_name': name.trim()})
        .eq('id', user.id);
  }

  /// Calls the Edge Function and turns its error strings into [AdminFailure].
  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions
          .invoke(_functionName, body: body)
          .timeout(SupabaseConfig.fetchTimeout);

      final data = response.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

      // `invoke` throws FunctionException on a non-2xx, so reaching here with an
      // `error` key means the function answered 200 with a problem — which it
      // does not currently do. Handled anyway rather than silently succeeding.
      final error = map['error'];
      if (error is String) throw AdminFailure(_classify(error), error);

      return map;
    } on AdminFailure {
      rethrow;
    } on FunctionException catch (error) {
      throw AdminFailure(_classify(_errorTextOf(error)), error.toString());
    } catch (error) {
      throw AdminFailure(AdminFailureCode.network, error.toString());
    }
  }

  /// Digs the function's `{"error": "..."}` token out of a [FunctionException].
  static String _errorTextOf(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return details?.toString() ?? '';
  }

  /// Maps the function's tokens onto the closed set above.
  ///
  /// Substring matching, because the token may arrive wrapped in the SDK's own
  /// description of the failure. Anything unrecognised is [unknown] rather than
  /// shown raw.
  static AdminFailureCode _classify(String message) {
    if (message.contains('cannot_delete_self') ||
        message.contains('cannot_change_own_role')) {
      return AdminFailureCode.cannotActOnSelf;
    }
    if (message.contains('last_administrator')) {
      return AdminFailureCode.lastAdministrator;
    }
    if (message.contains('forbidden')) return AdminFailureCode.forbidden;
    if (message.contains('already been registered') ||
        message.contains('already registered') ||
        message.contains('email_exists')) {
      return AdminFailureCode.emailAlreadyRegistered;
    }
    return AdminFailureCode.unknown;
  }
}
