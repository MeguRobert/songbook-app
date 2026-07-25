import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../providers/favorites_provider.dart';
import '../song_list/widgets/song_list_tile.dart';

/// Screen showing favorite songs
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteSongsAsync = ref.watch(favoriteSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: favoriteSongsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart icon on a song to add it here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.home),
                    icon: const Icon(Icons.library_music),
                    label: const Text('Browse Songs'),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            itemCount: songs.length,
            // Same reason as the setlist list: the automatic handle is injected
            // at the trailing edge on desktop/web, on top of the tile's
            // favourite button. Supply our own leading handle instead.
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final songNumbers = songs.map((s) => s.number).toList();
              songNumbers.insert(newIndex, songNumbers.removeAt(oldIndex));
              ref.read(favoritesProvider.notifier).reorder(songNumbers);
            },
            itemBuilder: (context, index) {
              final song = songs[index];
              return Row(
                key: ValueKey(song.number),
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                  Expanded(
                    child: SongListTile(
                      song: song,
                      onTap: () => context.push(AppRoutes.songPath(song.number)),
                    ),
                  ),
                ],
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
              Text('Error loading favorites: $error'),
            ],
          ),
        ),
      ),
    );
  }
}
