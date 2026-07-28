import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../providers/book_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/song_provider.dart';
import 'widgets/filter_sheets.dart';
import 'widgets/recent_songs_rail.dart';
import 'widgets/searchable_app_bar.dart';
import 'widgets/song_list_tile.dart';

/// The one place songs are found.
///
/// Book, tags and text search were previously three separate destinations —
/// two of them pushed outside the navigation shell — so narrowing a list meant
/// leaving it. They are all filters over the same list, so they all live here
/// now: book in the app bar title, tags as chips beneath it, text search in
/// the app bar itself.
///
/// Every active filter has a visible affordance. That is a rule, not a
/// preference: an invisible query silently narrowing results was a real bug
/// (audit S8), so collapsing the search bar clears the query and the tag row
/// stays on screen for as long as any tag is applied.
class SongListScreen extends ConsumerStatefulWidget {
  /// Tag to pre-apply, from a `?tag=` deep link.
  final String? initialTag;

  const SongListScreen({this.initialTag, super.key});

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  final _appBarKey = GlobalKey<SearchableAppBarState>();

  @override
  void initState() {
    super.initState();
    final tag = widget.initialTag;
    if (tag != null && tag.isNotEmpty) {
      // Deep link (`/?tag=…`, or the retired `/search?tag=…` after redirect).
      // Post-frame: seeding runs through a provider, which cannot be mutated
      // during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(searchProvider.notifier).setTags({tag});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedBook = ref.watch(selectedBookProvider);
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: SearchableAppBar(
        key: _appBarKey,
        title: selectedBook ?? 'Songbook',
        query: searchState.query,
        onQueryChanged: (q) => ref.read(searchProvider.notifier).search(q),
        onSearchClosed: () => ref.read(searchProvider.notifier).search(''),
        // One tap out of a book filter, from anywhere in the list. Reaching
        // "All Songs" used to mean opening the Books screen and picking it.
        leading: selectedBook != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    ref.read(selectedBookProvider.notifier).clear(),
                tooltip: 'Back to all songs',
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              selectedBook != null ? Icons.menu_book : Icons.menu_book_outlined,
            ),
            onPressed: () => showBookFilterSheet(context),
            tooltip: 'Books',
          ),
          IconButton(
            icon: Icon(
              searchState.hasTags ? Icons.sell : Icons.sell_outlined,
            ),
            onPressed: () => showTagFilterSheet(context),
            tooltip: 'Tags',
          ),
        ],
      ),
      // A FAB rather than another app-bar action: the bar is already at its
      // limit (Phase 0), and adding a song is a create action, which is what
      // a FAB is for.
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.importSong),
        tooltip: 'Add a song',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (searchState.hasTags) const _ActiveTagChips(),
          Expanded(
            child: searchState.isFiltering
                ? _SearchResults(state: searchState)
                : const _BrowseList(),
          ),
        ],
      ),
    );
  }
}

/// Removable chips for the tags currently narrowing the list.
///
/// Only rendered while at least one tag is active, so it costs nothing in the
/// normal browsing case — but while it is showing, no tag filter can be in
/// effect without the user seeing it.
class _ActiveTagChips extends ConsumerWidget {
  const _ActiveTagChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tags = ref.watch(searchProvider).activeTags;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.sell, size: 18),
          ),
          ...tags.map(
            (tag) => InputChip(
              label: Text(tag),
              onDeleted: () =>
                  ref.read(searchProvider.notifier).toggleTag(tag),
              deleteIconBoxConstraints: const BoxConstraints(),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(searchProvider.notifier).clearTags(),
            child: const Text('Clear tags'),
          ),
        ],
      ),
    );
  }
}

/// The full song list for the selected book, with the recents rail on top.
class _BrowseList extends ConsumerWidget {
  const _BrowseList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(filteredSongsProvider);
    final selectedBook = ref.watch(selectedBookProvider);

    return songsAsync.when(
      data: (songs) {
        if (songs.isEmpty) return _EmptyState(selectedBook: selectedBook);

        return Column(
          children: [
            const RecentSongsRail(),
            Expanded(
              child: ListView.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) => SongListTile(
                  song: songs[index],
                  onTap: () => context.push(
                    AppRoutes.songPath(songs[index].number),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _ErrorState(
        message: 'Error loading songs',
        error: error,
        onRetry: () => ref.invalidate(songsProvider),
      ),
    );
  }
}

/// Results for the active query and/or tags.
class _SearchResults extends ConsumerWidget {
  final SearchState state;

  const _SearchResults({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (state.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No songs found',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              state.hasTags
                  ? 'No songs match the selected tags and query'
                  : 'Searched titles, numbers, references and lyrics',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final resultCount = state.results.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Says why these results are here. Without it, a lyrics fallback looks
        // like the title search simply returned the wrong songs.
        if (state.matchedLyricsOnly)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            child: Row(
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No title match — found in the lyrics of $resultCount '
                    '${resultCount == 1 ? 'song' : 'songs'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: resultCount,
            itemBuilder: (context, index) {
              final song = state.results[index];
              return SongListTile(
                song: song,
                lyricSnippet: state.lyricSnippets[song.number],
                onTap: () => context.push(AppRoutes.songPath(song.number)),
              );
            },
          ),
        ),
      ],
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
              onPressed: () => ref.read(selectedBookProvider.notifier).clear(),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
