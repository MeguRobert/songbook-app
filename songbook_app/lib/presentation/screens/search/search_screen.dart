import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../providers/search_provider.dart';
import '../song_list/widgets/song_list_tile.dart';

/// Search screen for finding songs
class SearchScreen extends ConsumerStatefulWidget {
  /// Optional tag to pre-seed the tag filter (from the tag browser / deep link).
  final String? initialTag;

  const SearchScreen({this.initialTag, super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tag = widget.initialTag;
      if (tag != null && tag.isNotEmpty) {
        // Seed the tag filter; keep focus off the field so results show.
        ref.read(searchProvider.notifier).setTags({tag});
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search by number, title, or reference...',
            border: InputBorder.none,
            suffixIcon: searchState.hasQuery
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchProvider.notifier).clear();
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            ref.read(searchProvider.notifier).search(value);
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              ref.read(searchProvider.notifier).addToRecentSearches(value);
            }
          },
          textInputAction: TextInputAction.search,
        ),
      ),
      body: Column(
        children: [
          if (searchState.hasTags) _buildTagChips(context, searchState, theme),
          Expanded(child: _buildBody(context, searchState, theme)),
        ],
      ),
    );
  }

  /// Active tag filters shown as removable chips above the results.
  Widget _buildTagChips(
    BuildContext context,
    SearchState searchState,
    ThemeData theme,
  ) {
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
          ...searchState.activeTags.map(
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

  Widget _buildBody(
    BuildContext context,
    SearchState searchState,
    ThemeData theme,
  ) {
    // Show loading
    if (searchState.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show results if there's a query or an active tag filter
    if (searchState.isFiltering) {
      if (searchState.results.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No songs found',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                searchState.hasTags
                    ? 'No songs match the selected tags and query'
                    : 'Try searching by number, title, or reference',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: searchState.results.length,
        itemBuilder: (context, index) {
          final song = searchState.results[index];
          return SongListTile(
            song: song,
            onTap: () {
              ref
                  .read(searchProvider.notifier)
                  .addToRecentSearches(_searchController.text);
              context.push(AppRoutes.songPath(song.number));
            },
          );
        },
      );
    }

    // Show recent searches or hint
    return _buildEmptyState(context, searchState, theme);
  }

  Widget _buildEmptyState(
    BuildContext context,
    SearchState searchState,
    ThemeData theme,
  ) {
    if (searchState.recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search for songs',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a song number, title, or reference',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(searchProvider.notifier).clearRecentSearches();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchState.recentSearches.length,
            itemBuilder: (context, index) {
              final query = searchState.recentSearches[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(query),
                onTap: () {
                  _searchController.text = query;
                  ref.read(searchProvider.notifier).search(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
