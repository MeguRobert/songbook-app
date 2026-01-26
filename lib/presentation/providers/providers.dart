import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/local/local_datasource.dart';
import '../../data/repositories/song_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/services/transposition_service.dart';
import '../../domain/services/search_service.dart';

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

/// Song repository provider
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository(ref.watch(localDataSourceProvider));
});

/// Favorites repository provider
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(localDataSourceProvider));
});

/// Settings repository provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(localDataSourceProvider));
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
