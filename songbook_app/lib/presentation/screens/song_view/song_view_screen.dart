import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/song_provider.dart';
import 'widgets/chord_view.dart';
import 'widgets/sheet_music_view.dart';
import 'widgets/transpose_controls.dart';

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
    // Open the song in the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(songViewProvider.notifier).openSong(widget.songNumber);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songByNumberProvider(widget.songNumber));
    final isFavorite = ref.watch(isFavoriteProvider(widget.songNumber));
    final viewMode = ref.watch(viewModeProvider);
    final transpose = ref.watch(transposeProvider);

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
              // Toggle view mode
              IconButton(
                icon: Icon(
                  viewMode == SongViewMode.chords
                      ? Icons.music_note
                      : Icons.text_fields,
                ),
                onPressed: () {
                  ref.read(settingsProvider.notifier).toggleViewMode();
                },
                tooltip: viewMode == SongViewMode.chords
                    ? 'Show sheet music'
                    : 'Show chords',
              ),
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
          body: Column(
            children: [
              // Transpose controls
              TransposeControls(
                currentTranspose: transpose,
                originalKey: song.originalKey,
                onTransposeUp: () {
                  ref.read(songViewProvider.notifier).transposeUp();
                },
                onTransposeDown: () {
                  ref.read(songViewProvider.notifier).transposeDown();
                },
                onReset: () {
                  ref.read(songViewProvider.notifier).resetTranspose();
                },
              ),
              // Song content
              Expanded(
                child: viewMode == SongViewMode.chords
                    ? ChordView(song: song, transpose: transpose)
                    : SheetMusicView(song: song, transpose: transpose),
              ),
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
