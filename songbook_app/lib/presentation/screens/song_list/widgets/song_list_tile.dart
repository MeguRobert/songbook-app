import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/song.dart';
import '../../../providers/favorites_provider.dart';

/// A list tile for displaying a song in the song list
class SongListTile extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;

  const SongListTile({
    required this.song,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(song.number));
    final theme = Theme.of(context);

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
