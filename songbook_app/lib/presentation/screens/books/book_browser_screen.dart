import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/book_provider.dart';

/// Screen for browsing and selecting a book/hymnal to filter the song list.
///
/// Lists an "All Songs" entry followed by every book (with song counts). The
/// currently active selection is marked with a check. Selecting an entry
/// updates [selectedBookProvider] and returns to the song list.
class BookBrowserScreen extends ConsumerWidget {
  const BookBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final selected = ref.watch(selectedBookProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Books'),
      ),
      body: booksAsync.when(
        data: (books) {
          final totalSongs =
              books.fold<int>(0, (sum, book) => sum + book.songCount);

          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.library_music),
                title: const Text('All Songs'),
                subtitle: Text('$totalSongs songs'),
                trailing: selected == null
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                selected: selected == null,
                onTap: () {
                  ref.read(selectedBookProvider.notifier).clear();
                  context.pop();
                },
              ),
              const Divider(height: 1),
              ...books.map((book) {
                final isSelected = selected == book.name;
                return ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: Text(book.name),
                  subtitle: Text('${book.songCount} songs'),
                  trailing: isSelected
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  selected: isSelected,
                  onTap: () {
                    ref.read(selectedBookProvider.notifier).select(book.name);
                    context.pop();
                  },
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading books',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
