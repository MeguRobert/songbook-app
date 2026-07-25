import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/setlist.dart';
import '../../../data/models/song.dart';
import '../../../router/app_router.dart';
import '../../providers/setlist_provider.dart';
import '../../providers/song_provider.dart';

/// Screen showing a single setlist's songs with reorder / add / remove / play.
class SetlistDetailScreen extends ConsumerWidget {
  final String setlistId;

  const SetlistDetailScreen({required this.setlistId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlist = ref.watch(setlistByIdProvider(setlistId));

    if (setlist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Setlist')),
        body: const Center(child: Text('Setlist not found')),
      );
    }

    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(setlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Play setlist',
            onPressed: setlist.isEmpty
                ? null
                : () => _play(context, ref, setlist),
          ),
        ],
      ),
      body: songsAsync.when(
        data: (allSongs) {
          final byNumber = {for (final s in allSongs) s.number: s};
          // Preserve setlist order; skip numbers that are not in songs.json.
          final songs = setlist.songNumbers
              .where(byNumber.containsKey)
              .map((n) => byNumber[n]!)
              .toList();

          if (songs.isEmpty) {
            return _EmptyState(
              onAdd: () => _showAddSongs(context, ref, setlist, allSongs),
            );
          }

          return ReorderableListView.builder(
            itemCount: songs.length,
            // Suppress the automatic trailing drag handle: on desktop/web it
            // is injected at the trailing edge, where it collided with the
            // Remove button. We supply our own handle as `leading` instead.
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final ordered = songs.map((s) => s.number).toList();
              final moved = ordered.removeAt(oldIndex);
              ordered.insert(newIndex, moved);
              ref.read(setlistsProvider.notifier).reorder(setlist.id, ordered);
            },
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                key: ValueKey(song.number),
                // Wrapped in a drag listener so the handle actually drags —
                // previously this was a bare Icon that looked draggable but
                // did nothing.
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Text('${song.number}. ${song.title}'),
                subtitle: song.reference != null ? Text(song.reference!) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove from setlist',
                  onPressed: () => ref
                      .read(setlistsProvider.notifier)
                      .removeSong(setlist.id, song.number),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading songs: $error'),
        ),
      ),
      floatingActionButton: songsAsync.maybeWhen(
        data: (allSongs) => FloatingActionButton(
          onPressed: () => _showAddSongs(context, ref, setlist, allSongs),
          tooltip: 'Add songs',
          child: const Icon(Icons.add),
        ),
        orElse: () => null,
      ),
    );
  }

  void _play(BuildContext context, WidgetRef ref, Setlist setlist) {
    ref.read(setlistPlaybackProvider.notifier).start(setlist);
    context.push(AppRoutes.songPath(setlist.songNumbers.first));
  }

  /// Opens a bottom sheet listing all songs; tapping toggles membership.
  void _showAddSongs(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    List<Song> allSongs,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddSongsSheet(
        setlistId: setlist.id,
        allSongs: allSongs,
      ),
    );
  }
}

/// Bottom sheet for adding/removing songs to a setlist. Watches the live
/// setlist so checkmarks update as the user toggles.
class _AddSongsSheet extends ConsumerWidget {
  final String setlistId;
  final List<Song> allSongs;

  const _AddSongsSheet({required this.setlistId, required this.allSongs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlist = ref.watch(setlistByIdProvider(setlistId));
    final included = setlist?.songNumbers.toSet() ?? <int>{};

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add songs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: allSongs.length,
                itemBuilder: (context, index) {
                  final song = allSongs[index];
                  final isIn = included.contains(song.number);
                  return CheckboxListTile(
                    value: isIn,
                    title: Text('${song.number}. ${song.title}'),
                    onChanged: (checked) {
                      final notifier = ref.read(setlistsProvider.notifier);
                      if (checked == true) {
                        notifier.addSong(setlistId, song.number);
                      } else {
                        notifier.removeSong(setlistId, song.number);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Empty state shown when a setlist has no songs.
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No songs in this setlist',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add songs'),
          ),
        ],
      ),
    );
  }
}
