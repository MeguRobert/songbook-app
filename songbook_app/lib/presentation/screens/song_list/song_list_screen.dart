import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../providers/book_provider.dart';
import '../../providers/song_provider.dart';
import 'widgets/song_list_tile.dart';

/// Main screen showing the list of songs, filtered by the selected book.
class SongListScreen extends ConsumerWidget {
  const SongListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(filteredSongsProvider);
    final selectedBook = ref.watch(selectedBookProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedBook ?? 'Songbook'),
        actions: [
          IconButton(
            icon: Icon(
              selectedBook != null
                  ? Icons.menu_book
                  : Icons.menu_book_outlined,
            ),
            onPressed: () => context.push(AppRoutes.books),
            tooltip: 'Books',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.search),
            tooltip: 'Search',
          ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return _EmptyState(selectedBook: selectedBook);
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return SongListTile(
                song: song,
                onTap: () => context.push(AppRoutes.songPath(song.number)),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading songs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.invalidate(songsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state shown when no songs are available, with book-aware messaging.
class _EmptyState extends ConsumerWidget {
  final String? selectedBook;

  const _EmptyState({required this.selectedBook});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedBook != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No songs in "$selectedBook"',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(selectedBookProvider.notifier).clear(),
              child: const Text('Show all songs'),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No songs available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Add songs to assets/data/songs.json',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
