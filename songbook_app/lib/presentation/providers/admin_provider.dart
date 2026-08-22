import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_role.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/managed_user.dart';
import '../../data/repositories/admin_repository.dart';
import 'providers.dart';

/// Admin repository, or null with no backend. Overridden in main.
final adminRepositoryProvider = Provider<AdminRepository?>((ref) => null);

/// The signed-in user's role, resolved from the server.
///
/// **Async on purpose, and the asynchrony is load-bearing.** There are three
/// states, not two: known-permitted, known-denied, and not-yet-known. A route
/// guard that collapses the third into the second bounces an administrator to
/// the home screen every time they open a bookmarked `/admin` URL, because on a
/// cold load the rank has not arrived yet. See [adminAccessProvider].
///
/// Recomputed on every auth transition, so signing out demotes immediately.
final currentRoleProvider = FutureProvider<AppRole>((ref) async {
  ref.watch(authStateChangesProvider);
  if (!ref.watch(isSignedInProvider)) return AppRole.member;
  final repository = ref.watch(adminRepositoryProvider);
  if (repository == null) return AppRole.member;
  return repository.currentRole();
});

/// What the admin routes are allowed to do while the answer is still arriving.
enum AdminAccess {
  /// The rank has not come back yet. Wait — do not redirect.
  checking,

  /// Signed in and ranked high enough.
  granted,

  /// Resolved, and not high enough. Now a redirect is correct.
  denied,
}

/// Synchronous access decision for the router, derived from [currentRoleProvider].
///
/// The router's `redirect` cannot await, so it needs a value it can read on the
/// spot. This turns the AsyncValue into the three-state answer above rather than
/// a bool, which is the whole point.
final adminAccessProvider = Provider.family<AdminAccess, bool>((ref, needsAdmin) {
  final role = ref.watch(currentRoleProvider);
  return role.when(
    loading: () => AdminAccess.checking,
    // An error is treated as denied rather than as still-checking: a permanently
    // failing check would otherwise hang the route forever behind a spinner.
    error: (_, __) => AdminAccess.denied,
    data: (value) {
      final allowed = needsAdmin ? value.isAdministrator : value.canModerate;
      return allowed ? AdminAccess.granted : AdminAccess.denied;
    },
  );
});

/// The signed-in user's own profile: the name they are credited as, and whether
/// they have accepted the guidelines.
///
/// Read by the publish gate to decide what to ask for. Recomputed on every auth
/// transition so signing in as somebody else does not carry the old name.
final myProfileProvider =
    FutureProvider<({String? displayName, DateTime? guidelinesAcceptedAt})>(
        (ref) async {
  ref.watch(authStateChangesProvider);
  final repository = ref.watch(adminRepositoryProvider);
  if (repository == null) {
    return (displayName: null, guidelinesAcceptedAt: null);
  }
  return repository.myProfile();
});

/// Every account. Administrator only — a member's call is refused server-side.
final managedUsersProvider = FutureProvider<List<ManagedUser>>((ref) async {
  ref.watch(authStateChangesProvider);
  final repository = ref.watch(adminRepositoryProvider);
  if (repository == null) return const [];
  return repository.listUsers();
});

/// The project's shared settings.
///
/// Readable by everyone, including signed out: the Add-song screen needs to know
/// whether submissions are open, and the guidelines have to be readable before
/// anyone signs in to accept them.
final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final repository = ref.watch(adminRepositoryProvider);
  if (repository == null) return const AppSettings();
  try {
    return await repository.settings();
  } catch (_) {
    // Offline, or no backend. Defaulting to open is right: the local
    // save-to-device path must keep working, and a real submission is gated by
    // the database regardless of what this returns.
    return const AppSettings();
  }
});
