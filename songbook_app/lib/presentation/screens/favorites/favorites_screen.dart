import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../providers/favorites_provider.dart';
import '../song_list/widgets/song_list_tile.dart';

/// Screen showing favorite songs
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
                    l10n.favoritesEmpty,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.favoritesEmptyHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.home),
                    icon: const Icon(Icons.library_music),
                    label: Text(l10n.favoritesBrowse),
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
              final songIds = songs.map((s) => s.id).toList();
              songIds.insert(newIndex, songIds.removeAt(oldIndex));
              ref.read(favoritesProvider.notifier).reorder(songIds);
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
                      onTap: () => context.push(AppRoutes.songPath(song.id)),
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
