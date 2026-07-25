import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/song.dart';
import '../../../providers/favorites_provider.dart';

/// A list tile for displaying a song in the song list
class SongListTile extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;

  /// Matching lyric line, shown instead of the reference when this song was
  /// found by the lyrics fallback. Without it a lyrics hit looks arbitrary —
  /// nothing in the title or number explains why it is in the list.
  final String? lyricSnippet;

  const SongListTile({
    required this.song,
    required this.onTap,
    this.lyricSnippet,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(song.number));
    final theme = Theme.of(context);

    if (lyricSnippet != null) {
      return ListTile(
        leading: SizedBox(
          width: 48,
          child: Semantics(
            label: 'Song ${song.number}',
            excludeSemantics: true,
            child: Text(
              song.number.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: Icon(
                Icons.format_quote,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Text(
                lyricSnippet!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : null,
          ),
          onPressed: () {
            ref.read(favoritesProvider.notifier).toggleFavorite(song.number);
          },
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
        ),
        onTap: onTap,
      );
    }

    return ListTile(
      leading: SizedBox(
        width: 48,
        child: Semantics(
          label: 'Song ${song.number}',
          excludeSemantics: true,
          child: Text(
            song.number.toString(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: song.reference != null
          ? Text(
              song.reference!,
              style: theme.textTheme.bodySmall,
            )
          : null,
      trailing: IconButton(
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? Colors.red : null,
        ),
        onPressed: () {
          ref.read(favoritesProvider.notifier).toggleFavorite(song.number);
        },
        tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      ),
      onTap: onTap,
    );
  }
}
