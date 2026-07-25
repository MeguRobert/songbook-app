import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/app_router.dart';
import '../../../providers/setlist_provider.dart';

/// Bottom bar shown only while a setlist is being played during a service.
///
/// Self-hides (returns an empty box) when no setlist is active, so it can be
/// dropped into the song view's [Scaffold.bottomNavigationBar] unconditionally.
class SetlistNavBar extends ConsumerWidget {
  const SetlistNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(setlistPlaybackProvider);
    if (playback == null) return const SizedBox.shrink();

    final notifier = ref.read(setlistPlaybackProvider.notifier);

    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            tooltip: 'Previous song',
            onPressed: playback.hasPrevious
                ? () {
                    final n = notifier.previous();
                    if (n != null) {
                      context.pushReplacement(AppRoutes.songPath(n));
                    }
                  }
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  playback.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${playback.position} / ${playback.total}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            tooltip: 'Next song',
            onPressed: playback.hasNext
                ? () {
                    final n = notifier.next();
                    if (n != null) {
                      context.pushReplacement(AppRoutes.songPath(n));
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Stop playing setlist',
            onPressed: () => notifier.stop(),
          ),
        ],
      ),
    );
  }
}
