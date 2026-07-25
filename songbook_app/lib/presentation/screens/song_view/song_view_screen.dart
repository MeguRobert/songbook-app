import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/favorites_provider.dart';
import '../../providers/recents_provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/setlist_provider.dart';
import '../../../router/app_router.dart';
import 'widgets/chord_view.dart';
import 'widgets/song_controls_sheet.dart';
import 'widgets/sheet_music_view.dart';
import 'widgets/setlist_nav_bar.dart';
import 'widgets/tag_editor_sheet.dart';

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

  // Smooth zoom for discrete Ctrl+wheel notches. A trackpad pinch streams many
  // tiny scale events (already continuous); a mouse wheel fires one large event
  // per notch. To make the wheel feel like the trackpad, each notch animates the
  // text scale to a target over a short duration, emitting many small steps —
  // the same per-frame work the trackpad already does smoothly.
  late final AnimationController _zoomController;
  double _zoomFrom = 1.0;
  double _zoomTo = 1.0;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..addListener(() {
        final t = Curves.easeOut.transform(_zoomController.value);
        final value = _zoomFrom + (_zoomTo - _zoomFrom) * t;
        ref.read(songViewProvider.notifier).setTextScale(value);
      });
    // Open the song in the provider — openSong() resets transpose and textScale
    // No closeSong() in dispose needed: openSong() always creates fresh state,
    // and modifying provider state in dispose is forbidden by Riverpod.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(songViewProvider.notifier).openSong(widget.songNumber);
      // Record this song as recently viewed (powers the Home "Recent" rail).
      ref.read(recentsProvider.notifier).record(widget.songNumber);
      _syncSetlistPosition();
    });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  /// Animate the text scale to [target] over a short eased duration so a
  /// discrete zoom step (mouse wheel) glides instead of snapping.
  void _animateZoomTo(double target) {
    _zoomFrom = ref.read(textScaleProvider);
    _zoomTo = target.clamp(0.5, 2.0);
    _zoomController.forward(from: 0);
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

  void _showTagEditor(BuildContext context, List<String> currentTags) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TagEditorSheet(
        songNumber: widget.songNumber,
        currentTags: currentTags,
      ),
    );
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
              // Edit tags button
              IconButton(
                icon: const Icon(Icons.label_outline),
                onPressed: () => _showTagEditor(context, song.tags),
                tooltip: 'Edit tags',
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
          // Two gesture sources feed the same text-scale setting:
          //  - Listener.onPointerSignal handles PointerScaleEvent, which is how
          //    Flutter web delivers a desktop trackpad pinch / Ctrl+mouse-wheel
          //    (Chrome sends these as ctrl+wheel). GestureDetector/ScaleGesture-
          //    Recognizer does NOT receive pointer-signal scale events, so this
          //    is required for pinch-to-zoom to work on web.
          //  - GestureDetector.onScaleUpdate handles multi-touch pinch on mobile.
          body: Listener(
            onPointerSignal: (event) {
              if (event is PointerScaleEvent) {
                final raw = event.scale;
                final current = ref.read(textScaleProvider);
                if ((raw - 1.0).abs() > 0.08) {
                  // Large factor = one discrete mouse-wheel notch. Animate to a
                  // clamped target so it glides like a trackpad pinch instead of
                  // lurching. If a burst of notches arrives, accumulate onto the
                  // in-flight target so continuous scrolling keeps gliding.
                  final base = _zoomController.isAnimating ? _zoomTo : current;
                  _animateZoomTo(base * raw.clamp(0.6, 1.6));
                } else {
                  // Small factor = trackpad pinch stream, already continuous.
                  // Apply directly (and stop any wheel animation in progress).
                  if (_zoomController.isAnimating) _zoomController.stop();
                  ref
                      .read(songViewProvider.notifier)
                      .setTextScale((current * raw).clamp(0.5, 2.0));
                }
              }
            },
            child: GestureDetector(
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
                    textScale: textScale,
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
              ],
            ),
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
