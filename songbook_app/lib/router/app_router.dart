import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/models/song_id.dart';
import '../l10n/app_localizations.dart';

import '../presentation/screens/song_list/song_list_screen.dart';
import '../presentation/screens/song_view/song_view_screen.dart';
import '../presentation/screens/favorites/favorites_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/setlists/setlists_screen.dart';
import '../presentation/screens/setlists/setlist_detail_screen.dart';
import '../presentation/screens/import/import_song_screen.dart';
import '../presentation/screens/legal/legal_screen.dart';
import '../presentation/screens/notation_editor/notation_editor_screen.dart';
import '../presentation/screens/presentation/presentation_screen.dart';
import '../presentation/screens/admin/admin_gate.dart';
import '../presentation/screens/admin/admin_overview_screen.dart';
import '../presentation/screens/admin/admin_settings_screen.dart';
import '../presentation/screens/admin/admin_user_detail_screen.dart';
import '../presentation/screens/admin/admin_users_screen.dart';
import '../presentation/screens/moderation/moderation_queue_screen.dart';
import '../presentation/screens/moderation/my_submissions_screen.dart';
import '../presentation/widgets/scaffold_with_nav_bar.dart';

/// Route paths
///
/// Only genuine destinations are routes. Books, tags and text search are
/// filters over the song list and are presented in place (sheets and an
/// in-app-bar field) rather than navigated to — routing to them meant leaving
/// the list, and losing the bottom bar, just to narrow it.
class AppRoutes {
  static const home = '/';
  static const song = '/song/:id';
  static const presentation = '/presentation/:id';
  static const favorites = '/favorites';
  static const settings = '/settings';
  static const setlists = '/setlists';
  static const importSong = '/import';

  /// Correcting a song the user added. Deliberately a separate path rather than
  /// a mode on [importSong]: it is reachable from the song itself, and the id in
  /// the URL is what makes the edit target unambiguous.
  static const editSong = '/song/:id/edit';

  /// Beat-level correction of an imported score. Separate from [editSong]
  /// because it edits a different thing — the engraving, not the words — and
  /// because it only applies to a song that has notation at all.
  static const editNotation = '/song/:id/notation';

  /// Retired: search is now part of [home]. Kept so bookmarks and the old
  /// `?tag=` deep link land somewhere sensible instead of the error page.
  static const search = '/search';

  /// Administration.
  ///
  /// Outside the bottom-bar shell for the same reason [importSong] is: a focused
  /// task area, not a congregation-facing destination competing for a tab.
  ///
  /// These are real paths rather than the bare `MaterialPageRoute` pushes the
  /// moderation screens used to get from Settings. On a web app an unrouted
  /// screen has no address at all — no bookmark, no reload, no back button — and
  /// the queue is exactly the screen somebody wants to keep open in a tab.
  static const admin = '/admin';
  static const adminQueue = '/admin/queue';
  static const adminUsers = '/admin/users';
  static const adminUser = '/admin/users/:id';
  static const adminSettings = '/admin/settings';

  /// A contributor's own submissions. Not administration, but it was pushed
  /// unrouted alongside the queue and had the same problem.
  static const mySubmissions = '/my-submissions';

  /// The privacy notice and the terms of use.
  ///
  /// Outside the shell, like [importSong]: a document you read and come back
  /// from, not a destination competing for a tab. Real paths rather than an
  /// unrouted push because both have to be *linkable* — the sign-up screen
  /// points at them, and somebody who asks what the app keeps deserves an
  /// address they can be sent rather than a screen only reachable by tapping
  /// through Settings.
  static const privacy = '/privacy';
  static const terms = '/terms';

  static String adminUserPath(String userId) => '/admin/users/$userId';

  static String songPath(SongId id) => '/song/${id.value}';
  static String editSongPath(SongId id) => '/song/${id.value}/edit';
  static String editNotationPath(SongId id) => '/song/${id.value}/notation';
  static String presentationPath(SongId id) => '/presentation/${id.value}';
  static String setlistDetailPath(String id) => '/setlists/$id';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) => createAppRouter());

/// Builds the app's router.
///
/// [initialLocation] exists for tests: on web the browser's URL always wins, so
/// this is the only way to exercise "somebody pasted that link into a fresh
/// tab" against the real route table.
GoRouter createAppRouter({String initialLocation = AppRoutes.home}) {
  // Make an imperative `push` show up in the address bar.
  //
  // Every destination that is not a bottom-bar tab is reached with `push`
  // rather than `go`, because a song has to be poppable back to the list it was
  // opened from. go_router excludes imperative navigation from the reported
  // location by default, so the URL sat on `/` for the entire life of the app
  // while `#/settings` — a `go` from the nav bar — worked fine. That mismatch is
  // the whole of the "URLs never change" bug; no URL *strategy* was involved.
  //
  // go_router advises against this flag because the top-most route's URL is not
  // always deep-linkable. Here it always is: every pushed location is a
  // registered path that resolves from a cold load, which the tests in
  // `router_urls_test.dart` pin one by one.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    routes: [
      // Shell route for bottom navigation. Every top-level destination lives
      // in here, so the bottom bar is reachable from all of them — Setlists
      // used to be pushed outside the shell, which meant backing out of it
      // before you could switch tabs.
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => NoTransitionPage(
              child: SongListScreen(
                initialTag: state.uri.queryParameters['tag'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.setlists,
            name: 'setlists',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SetlistsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                name: 'setlistDetail',
                builder: (context, state) => SetlistDetailScreen(
                  setlistId: state.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.favorites,
            name: 'favorites',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FavoritesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      // Import lives outside the shell: it is a focused task with its own
      // Save action, not a destination to switch tabs away from mid-edit.
      GoRoute(
        path: AppRoutes.importSong,
        name: 'importSong',
        builder: (context, state) => const ImportSongScreen(),
      ),
      // Administration. Every screen is wrapped in AdminGate, which is a widget
      // rather than a `redirect` on purpose — see admin_gate.dart. The short
      // version: the rank arrives asynchronously, go_router does not re-run
      // `redirect` when a provider settles, and a guard that reads
      // not-yet-known as denied bounces an administrator off their own
      // bookmarked /admin on every cold load.
      GoRoute(
        path: AppRoutes.admin,
        name: 'admin',
        builder: (context, state) =>
            const AdminGate(child: AdminOverviewScreen()),
        routes: [
          GoRoute(
            path: 'queue',
            name: 'adminQueue',
            // needsAdmin: false — reviewing is a moderator's job, and the queue
            // is the one screen in here they are meant to reach.
            builder: (context, state) => const AdminGate(
              needsAdmin: false,
              child: ModerationQueueScreen(),
            ),
          ),
          GoRoute(
            path: 'users',
            name: 'adminUsers',
            builder: (context, state) =>
                const AdminGate(child: AdminUsersScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'adminUser',
                builder: (context, state) => AdminGate(
                  child: AdminUserDetailScreen(
                    userId: state.pathParameters['id'] ?? '',
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'settings',
            name: 'adminSettings',
            builder: (context, state) =>
                const AdminGate(child: AdminSettingsScreen()),
          ),
        ],
      ),
      // A contributor's own submissions. Ungated: it shows only your own rows,
      // which is what RLS permits you to see anyway.
      GoRoute(
        path: AppRoutes.mySubmissions,
        name: 'mySubmissions',
        builder: (context, state) => const MySubmissionsScreen(),
      ),
      // The privacy notice and the terms. Top-level rather than nested under
      // Settings, so a link to one of them resolves from a cold load — which is
      // what a link in the sign-up footer has to do.
      GoRoute(
        path: AppRoutes.privacy,
        name: 'privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        name: 'terms',
        builder: (context, state) => const TermsScreen(),
      ),
      // Song view route (outside shell for full-screen)
      GoRoute(
        path: AppRoutes.song,
        name: 'song',
        builder: (context, state) {
          // tryParse accepts a bare number as a hymnal id, so links and
          // bookmarks written when routes carried numbers still resolve.
          final id = SongId.tryParse(state.pathParameters['id'] ?? '');
          return SongViewScreen(songId: id ?? const SongId.hymnal(1));
        },
      ),
      // Correcting a saved user song. Three segments, so it cannot collide with
      // the two-segment song route above.
      GoRoute(
        path: AppRoutes.editSong,
        name: 'editSong',
        builder: (context, state) => ImportSongScreen(
          editingId: SongId.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.editNotation,
        name: 'editNotation',
        builder: (context, state) => NotationEditorScreen(
          songId: SongId.tryParse(state.pathParameters['id'] ?? '') ??
              const SongId.hymnal(1),
        ),
      ),
      // Presentation mode route (outside shell for full-screen)
      GoRoute(
        path: AppRoutes.presentation,
        name: 'presentation',
        builder: (context, state) {
          final id = SongId.tryParse(state.pathParameters['id'] ?? '');
          return PresentationScreen(songId: id ?? const SongId.hymnal(1));
        },
      ),
      // Legacy search/browse locations. Search and the tag browser were merged
      // into the song list; redirect rather than 404 so old bookmarks work.
      // A `?tag=` deep link keeps working: the song list reads it and seeds
      // the tag filter.
      GoRoute(
        path: AppRoutes.search,
        redirect: (context, state) {
          final tag = state.uri.queryParameters['tag'];
          if (tag == null || tag.isEmpty) return AppRoutes.home;
          return '${AppRoutes.home}?tag=${Uri.encodeComponent(tag)}';
        },
      ),
      GoRoute(path: '/books', redirect: (_, __) => AppRoutes.home),
      GoRoute(path: '/tags', redirect: (_, __) => AppRoutes.home),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).routeNotFound,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(AppLocalizations.of(context).routeGoHome),
            ),
          ],
        ),
      ),
    ),
  );
}
