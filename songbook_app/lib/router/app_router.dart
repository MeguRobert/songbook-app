import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/song_list/song_list_screen.dart';
import '../presentation/screens/song_view/song_view_screen.dart';
import '../presentation/screens/favorites/favorites_screen.dart';
import '../presentation/screens/search/search_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/books/book_browser_screen.dart';
import '../presentation/screens/setlists/setlists_screen.dart';
import '../presentation/screens/setlists/setlist_detail_screen.dart';
import '../presentation/screens/presentation/presentation_screen.dart';
import '../presentation/widgets/scaffold_with_nav_bar.dart';

/// Route paths
class AppRoutes {
  static const home = '/';
  static const song = '/song/:id';
  static const presentation = '/presentation/:id';
  static const favorites = '/favorites';
  static const search = '/search';
  static const settings = '/settings';
  static const books = '/books';
  static const setlists = '/setlists';

  static String songPath(int id) => '/song/$id';
  static String presentationPath(int id) => '/presentation/$id';
  static String setlistDetailPath(String id) => '/setlists/$id';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      // Shell route for bottom navigation
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SongListScreen(),
            ),
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
      // Song view route (outside shell for full-screen)
      GoRoute(
        path: AppRoutes.song,
        name: 'song',
        builder: (context, state) {
          final idParam = state.pathParameters['id'];
          final id = int.tryParse(idParam ?? '') ?? 1;
          return SongViewScreen(songNumber: id);
        },
      ),
      // Presentation mode route (outside shell for full-screen)
      GoRoute(
        path: AppRoutes.presentation,
        name: 'presentation',
        builder: (context, state) {
          final idParam = state.pathParameters['id'];
          final id = int.tryParse(idParam ?? '') ?? 1;
          return PresentationScreen(songNumber: id);
        },
      ),
      // Search route (outside shell for full-screen)
      GoRoute(
        path: AppRoutes.search,
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      // Book browser route (outside shell for full-screen)
      GoRoute(
        path: AppRoutes.books,
        name: 'books',
        builder: (context, state) => const BookBrowserScreen(),
      ),
      // Setlists routes (outside shell for full-screen)
      GoRoute(
        path: AppRoutes.setlists,
        name: 'setlists',
        builder: (context, state) => const SetlistsScreen(),
      ),
      GoRoute(
        path: '/setlists/:id',
        name: 'setlistDetail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SetlistDetailScreen(setlistId: id);
        },
      ),
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
