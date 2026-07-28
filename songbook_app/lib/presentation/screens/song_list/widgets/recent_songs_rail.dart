import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/app_router.dart';
import '../../../providers/recents_provider.dart';

/// Horizontal "Recently viewed" rail shown at the top of the song list.
///
/// Renders nothing when there is no history. The first card is highlighted as
/// the "Continue" entry so a user can jump straight back to where they were.
class RecentSongsRail extends ConsumerWidget {
  const RecentSongsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentsAsync = ref.watch(recentSongsProvider);

    return recentsAsync.maybeWhen(
      data: (songs) {
        if (songs.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.history,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Recently viewed',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        ref.read(recentsProvider.notifier).clear(),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: songs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final song = songs[index];
                  final isContinue = index == 0;
                  return _RecentCard(
                    number: song.number,
                    title: song.title,
                    isContinue: isContinue,
                    onTap: () =>
                        context.push(AppRoutes.songPath(song.id)),
                  );
                },
              ),
            ),
            const Divider(height: 16),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _RecentCard extends StatelessWidget {
  final int number;
  final String title;
  final bool isContinue;
  final VoidCallback onTap;

  const _RecentCard({
    required this.number,
    required this.title,
    required this.isContinue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        color: isContinue ? scheme.primaryContainer : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isContinue) ...[
                      Icon(Icons.play_arrow,
                          size: 16, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      isContinue ? 'Continue · #$number' : '#$number',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isContinue
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isContinue ? scheme.onPrimaryContainer : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
