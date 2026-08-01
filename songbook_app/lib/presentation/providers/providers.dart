import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, User;

import '../../data/datasources/local/local_datasource.dart';
import '../../data/datasources/remote/remote_song_datasource.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/setlist_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/user_song_repository.dart';
import '../../domain/services/transposition_service.dart';
import '../../domain/services/search_service.dart';
import '../../domain/services/capo_service.dart';

// --- Core Providers ---

/// SharedPreferences provider - must be overridden in main
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before use');
});

/// Local data source provider
final localDataSourceProvider = Provider<LocalDataSource>((ref) {
  return LocalDataSource(ref.watch(sharedPreferencesProvider));
});

// --- Repository Providers ---

/// Remote song data source.
///
/// Null when Supabase failed to initialise — the app must still run, just with
/// the bundled catalogue only. Overridden with null in tests so nothing reaches
/// for a network.
final remoteSongDataSourceProvider = Provider<RemoteSongDataSource?>((ref) {
  return null;
});

// --- Auth ---
//
// Accounts are strictly additive. There are deliberately no route guards and no
// redirect-to-sign-in anywhere in the app: Songbook works signed-out, and that
// is a hard requirement rather than a default. Every provider below therefore
// tolerates a null repository, which is what a build with no backend, or a
// failed Supabase init, produces.

/// Auth repository, or null when there is no backend available.
/// Overridden in main; null here so tests and offline builds need no network.
final authRepositoryProvider = Provider<AuthRepository?>((ref) => null);

/// Whether accounts are available at all in this build.
final authAvailableProvider = Provider<bool>((ref) {
  return ref.watch(authRepositoryProvider) != null;
});

/// Auth state as a stream, so the UI reacts to sign-in and sign-out.
///
/// When there is no backend this never emits rather than erroring — "no
/// accounts" is a normal configuration, not a fault.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  if (repository == null) return const Stream<AuthState>.empty();
  return repository.authStateChanges;
});

/// The signed-in user, or null.
///
/// Reads the synchronous `currentUser` but watches the stream, so it recomputes
/// on every auth transition. The SDK restores a persisted session during
/// initialize, so this is already correct on the first frame.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider)?.currentUser;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Whether the signed-in account has confirmed its email address.
///
/// Separate from [isSignedInProvider] because possessing a session is not proof
/// of verification: contributing a song should require a confirmed address,
/// reading the catalogue should not.
final isEmailConfirmedProvider = Provider<bool>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider)?.isEmailConfirmed ?? false;
});

/// Song repository provider
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository(
    ref.watch(localDataSourceProvider),
    ref.watch(remoteSongDataSourceProvider),
  );
});

/// Favorites repository provider
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(localDataSourceProvider));
});

/// Settings repository provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(localDataSourceProvider));
});

/// Setlist repository provider
final setlistRepositoryProvider = Provider<SetlistRepository>((ref) {
  return SetlistRepository(ref.watch(localDataSourceProvider));
});

/// Tag repository provider (per-song tag overrides)
final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(localDataSourceProvider));
});

/// Songs the user added themselves. Merged into the catalogue by
/// `songsProvider`; see [userSongsProvider] for the reactive view.
final userSongRepositoryProvider = Provider<UserSongRepository>((ref) {
  return UserSongRepository(
    ref.watch(localDataSourceProvider),
    ref.watch(settingsRepositoryProvider),
  );
});

// --- Service Providers ---

/// Transposition service provider
final transpositionServiceProvider = Provider<TranspositionService>((ref) {
  return const TranspositionService();
});

/// Search service provider
final searchServiceProvider = Provider<SearchService>((ref) {
  return const SearchService();
});

/// Capo helper service provider
final capoServiceProvider = Provider<CapoService>((ref) {
  return const CapoService();
});
