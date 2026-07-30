import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/recent_searches_provider.dart';

/// Queries the user has searched before, offered while the search field is open
/// and empty.
///
/// Renders nothing at all when there is no history — a heading standing over an
/// empty box is worse than the blank space it replaced.
class RecentSearchesList extends ConsumerWidget {
  /// Runs [query] again.
  final ValueChanged<String> onSelected;

  const RecentSearchesList({required this.onSelected, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final searches = ref.watch(recentSearchesProvider);
    if (searches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 8),
          child: Row(
            children: [
              Text(
                l10n.searchRecent,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(recentSearchesProvider.notifier).clear(),
                child: Text(l10n.actionClear),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searches.length,
            itemBuilder: (context, index) {
              final query = searches[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 20),
                title: Text(query),
                onTap: () => onSelected(query),
              );
            },
          ),
        ),
      ],
    );
  }
}
