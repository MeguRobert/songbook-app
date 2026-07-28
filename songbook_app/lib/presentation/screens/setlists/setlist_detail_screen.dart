import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/setlist.dart';
import '../../../data/models/song.dart';
import '../../../data/models/song_id.dart';
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
          final byId = {for (final s in allSongs) s.id: s};
          // Preserve setlist order; skip songs that are not in songs.json.
          final songs = setlist.songIds
              .where(byId.containsKey)
              .map((id) => byId[id]!)
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

              // Reorder the VISIBLE rows, then write the change back into the
              // full stored list. Writing `songs` directly would persist only
              // the catalog-filtered subset, permanently deleting any setlist
              // entry whose song is missing from songs.json.
              final visible = songs.map((s) => s.id).toList();
              final reordered = [...visible];
              reordered.insert(newIndex, reordered.removeAt(oldIndex));

              final visibleIds = visible.toSet();
              var next = 0;
              final full = setlist.songIds
                  .map((n) => visibleIds.contains(n) ? reordered[next++] : n)
                  .toList();

              ref.read(setlistsProvider.notifier).reorder(setlist.id, full);
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
                      .removeSong(setlist.id, song.id),
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
    // Routes still carry a hymnal number; nothing user-authored can be in
    // a setlist yet, so there is no id here without one.
    final first = setlist.songIds.first.hymnalNumber;
    if (first != null) context.push(AppRoutes.songPath(first));
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
    // Explicitly Set<SongId>. A `<int>{}` fallback widened this to Set<Object>,
    // which made the `contains` below compile while never matching — the
    // checkbox would silently never show as ticked.
    final included = setlist?.songIds.toSet() ?? <SongId>{};

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
                  final isIn = included.contains(song.id);
                  return CheckboxListTile(
                    value: isIn,
                    title: Text('${song.number}. ${song.title}'),
                    onChanged: (checked) {
                      final notifier = ref.read(setlistsProvider.notifier);
                      if (checked == true) {
                        notifier.addSong(setlistId, song.id);
                      } else {
                        notifier.removeSong(setlistId, song.id);
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
