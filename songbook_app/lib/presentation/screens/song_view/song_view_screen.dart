import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/favorites_provider.dart';
import '../../providers/song_provider.dart';
import 'widgets/chord_view.dart';
import 'widgets/floating_controls_menu.dart';
import 'widgets/sheet_music_view.dart';

/// Screen for viewing a single song
class SongViewScreen extends ConsumerStatefulWidget {
  final int songNumber;

  const SongViewScreen({
    required this.songNumber,
    super.key,
  });

  @override
  ConsumerState<SongViewScreen> createState() => _SongViewScreenState();
}

class _SongViewScreenState extends ConsumerState<SongViewScreen> {
  @override
  void initState() {
    super.initState();
    // Open the song in the provider — openSong() resets transpose and textScale
    // No closeSong() in dispose needed: openSong() always creates fresh state,
    // and modifying provider state in dispose is forbidden by Riverpod.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(songViewProvider.notifier).openSong(widget.songNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songByNumberProvider(widget.songNumber));
    final isFavorite = ref.watch(isFavoriteProvider(widget.songNumber));
    final viewConfig = ref.watch(effectiveViewConfigProvider);
    final transpose = ref.watch(transposeProvider);
    final textScale = ref.watch(textScaleProvider);

    return songAsync.when(
      data: (song) {
        if (song == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Song not found')),
            body: const Center(child: Text('Song not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${song.number}. ${song.title}'),
            actions: [
              // Favorite button
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                onPressed: () {
                  ref
                      .read(favoritesProvider.notifier)
                      .toggleFavorite(widget.songNumber);
                },
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              ),
            ],
          ),
          body: Stack(
            children: [
              // Main content - render based on ViewConfig
              if (viewConfig.showNotation)
                SheetMusicView(
                  song: song,
                  transpose: transpose,
                  showChords: viewConfig.showChords,
                )
              else if (viewConfig.showChords)
                ChordView(
                  song: song,
                  transpose: transpose,
                  textScale: textScale,
                  showChords: true,
                )
              else
                ChordView(
                  song: song,
                  transpose: transpose,
                  textScale: textScale,
                  showChords: false,
                ),
              // Floating controls menu
              FloatingControlsMenu(originalKey: song.originalKey),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }
}
