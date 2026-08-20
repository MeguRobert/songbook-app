import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, User;

import '../../data/datasources/local/local_datasource.dart';
import '../../data/datasources/remote/remote_song_datasource.dart';
import '../../data/models/submission.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../../data/repositories/submission_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/setlist_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/user_song_repository.dart';
import '../../domain/services/browser_photo_import_service.dart';
// The recognizer is Tesseract in a web worker, so there is nothing to import
// on a platform without a browser. The stub half exists to keep this file
// compiling there, and reports itself unsupported rather than pretending.
import '../../domain/services/page_text_recognizer_stub.dart'
    if (dart.library.js_interop) '../../domain/services/page_text_recognizer_web.dart';
import '../../domain/services/photo_import_service.dart';
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

// --- Submissions and moderation ---

/// Submission repository, or null with no backend. Overridden in main.
final submissionRepositoryProvider =
    Provider<SubmissionRepository?>((ref) => null);

/// Whether to show moderation UI.
///
/// **For visibility only.** Forcing this true grants nothing: approving a song
/// is an UPDATE that RLS and the status trigger re-check server-side, so a
/// non-admin who reaches the queue screen still cannot decide anything.
///
/// Recomputed on every auth transition, so signing out hides the queue.
final isAdminProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateChangesProvider);
  if (!ref.watch(isSignedInProvider)) return false;
  final repository = ref.watch(submissionRepositoryProvider);
  if (repository == null) return false;
  return repository.isAdmin();
});

/// The signed-in user's own submissions and their review state.
final mySubmissionsProvider = FutureProvider<List<Submission>>((ref) async {
  ref.watch(authStateChangesProvider);
  final repository = ref.watch(submissionRepositoryProvider);
  if (repository == null) return const [];
  return repository.mySubmissions();
});

/// The moderation queue. Empty for a non-admin, because that is all RLS shows
/// them — not because this filtered it.
final moderationQueueProvider = FutureProvider<List<Submission>>((ref) async {
  ref.watch(authStateChangesProvider);
  final repository = ref.watch(submissionRepositoryProvider);
  if (repository == null) return const [];
  return repository.pendingQueue();
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
// --- Photo import: two engines, because neither does the other's job ---
//
// A photographed hymnal page is words with chord names above them, and reading
// that is text OCR, which the browser can do in about two seconds for free.
// Engraved notation is music recognition, which needs Audiveris — a container,
// not a phone — and which returns no lyrics at all. So the page is read by one
// or the other, and the person holding the camera is the only one who knows
// which kind of page it is. Hence the toggle on the import screen.

/// Reading a photographed chord sheet. The common case, and the default.
///
/// No endpoint, no account and no network: the engine, the page cleaning and
/// the chords-over-lyrics arithmetic are all on the device. A service address
/// saved in Settings is deliberately *not* consulted here — it belongs to the
/// sheet-music reader below — because the local path measured faster and more
/// accurate than the server one it replaced.
///
/// Null only where there is no browser to run the engine in, which the import
/// screen explains rather than failing on tap.
final photoTextImportServiceProvider = Provider<PhotoImportService?>((ref) {
  final recognizer = createPageTextRecognizer();
  if (!recognizer.isSupported) return null;
  return BrowserPhotoImportService(recognizer: recognizer);
});

/// Reading engraved notation off a photographed page. Opt-in, and a server.
///
/// Null when no address has been configured, rather than a throwing stub, so
/// the UI can offer the feature honestly: "point this at a service" is a setup
/// step, not an error.
///
/// [authStateChangesProvider] is watched for the token, not for the user: the
/// deployed service verifies a Supabase access token, those expire, and the SDK
/// replaces them on that stream. Watching it means the next import carries the
/// live token instead of the one that happened to be current when this screen
/// was first built — which the service would answer with a 401.
final photoNotationImportServiceProvider =
    Provider<PhotoImportService?>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  final endpoint = settings.getPhotoImportEndpoint();
  if (endpoint == null) return null;
  ref.watch(authStateChangesProvider);
  return HttpPhotoImportService(
    endpoint: endpoint,
    // A token typed into Settings wins: it is an explicit answer about this
    // particular service, and someone running their own has no Supabase
    // session to offer it. Otherwise the signed-in user's own token, which is
    // what the project's service checks.
    token: settings.getPhotoImportToken() ??
        ref.watch(authRepositoryProvider)?.accessToken,
  );
});

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
