import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/models/song_id.dart';

import '../presentation/screens/song_list/song_list_screen.dart';
import '../presentation/screens/song_view/song_view_screen.dart';
import '../presentation/screens/favorites/favorites_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/setlists/setlists_screen.dart';
import '../presentation/screens/setlists/setlist_detail_screen.dart';
import '../presentation/screens/import/import_song_screen.dart';
import '../presentation/screens/presentation/presentation_screen.dart';
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

  /// Retired: search is now part of [home]. Kept so bookmarks and the old
  /// `?tag=` deep link land somewhere sensible instead of the error page.
  static const search = '/search';

  static String songPath(SongId id) => '/song/${id.value}';
  static String editSongPath(SongId id) => '/song/${id.value}/edit';
  static String presentationPath(SongId id) => '/presentation/${id.value}';
  static String setlistDetailPath(String id) => '/setlists/$id';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
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
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
