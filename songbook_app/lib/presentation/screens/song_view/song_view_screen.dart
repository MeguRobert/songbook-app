import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/autoscroll_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/setlist_provider.dart';
import '../../../router/app_router.dart';
import 'widgets/chord_view.dart';
import 'widgets/song_controls_sheet.dart';
import 'widgets/sheet_music_view.dart';
import 'widgets/setlist_nav_bar.dart';

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

class _SongViewScreenState extends ConsumerState<SongViewScreen>
    with SingleTickerProviderStateMixin {
  double _baseScale = 1.0;

  // --- Auto-scroll (POC) ---
  final ScrollController _scrollController = ScrollController();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onAutoScrollTick);
    // Open the song in the provider — openSong() resets transpose and textScale
    // No closeSong() in dispose needed: openSong() always creates fresh state,
    // and modifying provider state in dispose is forbidden by Riverpod.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(songViewProvider.notifier).openSong(widget.songNumber);
      ref.read(autoScrollProvider.notifier).init(widget.songNumber);
      _syncSetlistPosition();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Advances the scroll position by `speed * dt` each frame while playing.
  /// Stops automatically when the bottom of the song is reached.
  void _onAutoScrollTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (!_scrollController.hasClients) return;

    final speed = ref.read(autoScrollProvider).speed;
    final position = _scrollController.position;
    final next = _scrollController.offset + speed * dt;
    if (next >= position.maxScrollExtent) {
      _scrollController.jumpTo(position.maxScrollExtent);
      ref.read(autoScrollProvider.notifier).pause(); // reached the end
    } else {
      _scrollController.jumpTo(next);
    }
  }

  void _setAutoScrollRunning(bool running) {
    if (running && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!running && _ticker.isActive) {
      _ticker.stop();
    }
  }

  /// Keeps the setlist playback cursor aligned with the song being shown, so
  /// the nav bar's position label stays correct when navigating via Next/
  /// Previous (which use pushReplacement, not a new playback start).
  void _syncSetlistPosition() {
    final playback = ref.read(setlistPlaybackProvider);
    if (playback == null) return;
    final index = playback.songNumbers.indexOf(widget.songNumber);
    if (index != -1) {
      ref.read(setlistPlaybackProvider.notifier).jumpTo(index);
    }
  }

  void _showControlsSheet(BuildContext context, String originalKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SongControlsSheet(originalKey: originalKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songByNumberProvider(widget.songNumber));
    final isFavorite = ref.watch(isFavoriteProvider(widget.songNumber));
    final viewConfig = ref.watch(effectiveViewConfigProvider);
    final transpose = ref.watch(transposeProvider);
    final textScale = ref.watch(textScaleProvider);
    final autoScroll = ref.watch(autoScrollProvider);

    // Start/stop the ticker as the play state changes.
    ref.listen<bool>(
      autoScrollProvider.select((s) => s.isPlaying),
      (_, playing) => _setAutoScrollRunning(playing),
    );

    // Auto-scroll only drives the chord/lyrics view (sheet music is a separate
    // widget); the play control is hidden in sheet-music mode.
    final canAutoScroll = !viewConfig.showNotation;

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
              // Auto-scroll play/pause (chord/lyrics view only)
              if (canAutoScroll)
                IconButton(
                  icon: Icon(
                    autoScroll.isPlaying
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                  onPressed: () =>
                      ref.read(autoScrollProvider.notifier).toggle(),
                  tooltip: autoScroll.isPlaying
                      ? 'Stop auto-scroll'
                      : 'Start auto-scroll',
                ),
              // Presentation mode button
              IconButton(
                icon: const Icon(Icons.fullscreen),
                onPressed: () {
                  context.push(AppRoutes.presentationPath(widget.songNumber));
                },
                tooltip: 'Presentation mode',
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
          body: GestureDetector(
            onScaleStart: (details) {
              _baseScale = textScale;
            },
            onScaleUpdate: (details) {
              // Only apply when it's a pinch gesture (not single-finger drag)
              if ((details.scale - 1.0).abs() > 0.01) {
                final newScale = _baseScale * details.scale;
                ref.read(songViewProvider.notifier).setTextScale(newScale);
              }
            },
            onScaleEnd: (details) {
              // Scale gesture complete
            },
            child: Stack(
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
                    scrollController: _scrollController,
                  )
                else
                  ChordView(
                    song: song,
                    transpose: transpose,
                    textScale: textScale,
                    showChords: false,
                    scrollController: _scrollController,
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.small(
            onPressed: () => _showControlsSheet(context, song.originalKey),
            tooltip: 'Song controls',
            child: const Icon(Icons.tune),
          ),
          bottomNavigationBar: const SetlistNavBar(),
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
