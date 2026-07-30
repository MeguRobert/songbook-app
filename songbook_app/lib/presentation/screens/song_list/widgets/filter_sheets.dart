import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/book_provider.dart';
import '../../../providers/search_provider.dart';
import '../../../providers/tag_provider.dart';

/// Book and tag pickers, presented as sheets over the song list.
///
/// Both used to be full screens pushed outside the navigation shell, so
/// narrowing the list meant leaving it and losing the bottom bar. Neither is a
/// destination — they only ever set a filter and come straight back — so they
/// are sheets now. The list stays visible behind them and updates the moment
/// the sheet closes.

/// Single-select book filter. Selecting closes the sheet.
Future<void> showBookFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _BookFilterSheet(),
  );
}

/// Multi-select tag filter (AND semantics). Stays open while toggling so
/// several tags can be combined, which is the whole point of AND filtering.
Future<void> showTagFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _TagFilterSheet(),
  );
}

class _BookFilterSheet extends ConsumerWidget {
  const _BookFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final selected = ref.watch(selectedBookProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          _SheetTitle(text: l10n.booksTooltip, theme: theme),
          const Divider(height: 1),
          Expanded(
            child: booksAsync.when(
              data: (books) {
                final total =
                    books.fold<int>(0, (sum, b) => sum + b.songCount);
                return ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.library_music),
                      title: Text(l10n.filterAllSongs),
                      subtitle: Text(l10n.songCount(total)),
                      trailing: selected == null
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      selected: selected == null,
                      onTap: () {
                        ref.read(selectedBookProvider.notifier).clear();
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 1),
                    ...books.map((book) {
                      final isSelected = selected == book.name;
                      return ListTile(
                        leading: const Icon(Icons.menu_book),
                        title: Text(book.name),
                        subtitle: Text(l10n.songCount(book.songCount)),
                        trailing: isSelected
                            ? Icon(Icons.check,
                                color: theme.colorScheme.primary)
                            : null,
                        selected: isSelected,
                        onTap: () {
                          ref
                              .read(selectedBookProvider.notifier)
                              .select(book.name);
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(l10n.errorLoadingBooks('$error'))),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFilterSheet extends ConsumerWidget {
  const _TagFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    final active = ref.watch(searchProvider).activeTags;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          _SheetTitle(text: l10n.filterByTags, theme: theme),
          Text(
            l10n.filterTagsAnd,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: tagsAsync.when(
              data: (tags) => tags.isEmpty
                  ? Center(child: Text(l10n.tagsEmpty))
                  : SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in tags)
                            FilterChip(
                              label: Text('${tag.name} (${tag.songCount})'),
                              selected: active.any((t) =>
                                  t.toLowerCase() == tag.name.toLowerCase()),
                              onSelected: (_) => ref
                                  .read(searchProvider.notifier)
                                  .toggleTag(tag.name),
                            ),
                        ],
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(l10n.errorLoadingTags('$error'))),
            ),
          ),
          if (active.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton(
                onPressed: () =>
                    ref.read(searchProvider.notifier).clearTags(),
                child: Text(l10n.filterClearAllTags),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _SheetTitle({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleLarge),
      ),
    );
  }
}
