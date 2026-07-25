import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/models/song.dart';
import '../../domain/services/book_service.dart';
import 'providers.dart';
import 'song_provider.dart';

/// Provider for the stateless book grouping/filtering service.
final bookServiceProvider = Provider<BookService>((ref) {
  return const BookService();
});

/// Provider for the list of books derived from all songs (with song counts).
final booksProvider = FutureProvider<List<Book>>((ref) async {
  final songs = await ref.watch(songsProvider.future);
  return ref.watch(bookServiceProvider).booksFromSongs(songs);
});

/// Notifier for the currently selected book (null = "All Songs").
///
/// The selection is persisted via [SettingsRepository] so it survives restarts.
class SelectedBookNotifier extends StateNotifier<String?> {
  final Ref _ref;

  SelectedBookNotifier(this._ref)
      : super(_ref.read(settingsRepositoryProvider).getSelectedBook());

  /// Selects a book and persists the choice.
  Future<void> select(String bookName) async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.setSelectedBook(bookName);
    state = bookName;
  }

  /// Clears the selection, returning to the "All Songs" view.
  Future<void> clear() async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.clearSelectedBook();
    state = null;
  }
}

/// Provider for the currently selected book name (null = All Songs).
final selectedBookProvider =
    StateNotifierProvider<SelectedBookNotifier, String?>((ref) {
  return SelectedBookNotifier(ref);
});

/// Provider for the songs filtered by the currently selected book.
///
/// When no book is selected, this yields all songs (the "All Songs" view).
final filteredSongsProvider = FutureProvider<List<Song>>((ref) async {
  final songs = await ref.watch(songsProvider.future);
  final selected = ref.watch(selectedBookProvider);
  return ref.watch(bookServiceProvider).filterByBook(songs, selected);
});
