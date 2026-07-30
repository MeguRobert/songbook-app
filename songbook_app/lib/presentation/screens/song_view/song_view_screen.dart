import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/song.dart';
import '../../../data/models/song_id.dart';
import '../../../data/models/view_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/services/chord_sheet_exporter.dart';
import '../../providers/autoscroll_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/setlist_provider.dart';
import '../../../router/app_router.dart';
import 'widgets/chord_view.dart';
import 'widgets/song_controls_sheet.dart';
import 'widgets/sheet_music_view.dart';
import 'widgets/setlist_nav_bar.dart';
import 'widgets/tag_editor_sheet.dart';

/// Actions behind the song-view overflow menu.
///
/// The first two were app-bar icons until the Phase 0 declutter; see
/// [_buildAppBar]. The last two apply to user songs only — `songs.json` is a
/// read-only asset, so a bundled hymn has nothing to write back to.
enum _SongMenuAction {
  presentation,
  editTags,
  copyText,
  editSong,
  editNotation,
  deleteSong
}

/// Screen for viewing a single song
class SongViewScreen extends ConsumerStatefulWidget {
  final SongId songId;

  const SongViewScreen({
    required this.songId,
    super.key,
  });

  @override
  ConsumerState<SongViewScreen> createState() => _SongViewScreenState();
}

class _SongViewScreenState extends ConsumerState<SongViewScreen>
    // TickerProviderStateMixin (not SingleTicker): this state drives TWO
    // tickers — the zoom AnimationController (04-05) and the auto-scroll
    // Ticker (POC 1). SingleTickerProviderStateMixin asserts on the second.
    with TickerProviderStateMixin {
  double _baseScale = 1.0;

  // Smooth zoom for discrete Ctrl+wheel notches. A trackpad pinch streams many
  // tiny scale events (already continuous); a mouse wheel fires one large event
  // per notch. To make the wheel feel like the trackpad, each notch animates the
  // text scale to a target over a short duration, emitting many small steps —
  // the same per-frame work the trackpad already does smoothly.
  late final AnimationController _zoomController;
  double _zoomFrom = 1.0;
  double _zoomTo = 1.0;
  // --- Auto-scroll (POC) ---
  final ScrollController _scrollController = ScrollController();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// This song's persisted per-song view config, read synchronously so the
  /// very first frame can already use it. See [build] for why that matters.
  ViewConfig? _savedViewConfig;

  @override
  void initState() {
    super.initState();
    _savedViewConfig = ref
        .read(settingsRepositoryProvider)
        .getSongViewConfig(widget.songId);
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..addListener(() {
        final t = Curves.easeOut.transform(_zoomController.value);
        final value = _zoomFrom + (_zoomTo - _zoomFrom) * t;
        ref.read(songViewProvider.notifier).setTextScale(value);
      });
    _ticker = createTicker(_onAutoScrollTick);
    // Open the song in the provider — openSong() resets transpose and textScale
    // No closeSong() in dispose needed: openSong() always creates fresh state,
    // and modifying provider state in dispose is forbidden by Riverpod.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openCurrentSong();
    });
  }

  @override
  void didUpdateWidget(covariant SongViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId == widget.songId) return;
    // GoRouter keys each `/song/<id>` page separately, so today a new song always
    // gets a fresh State and this never fires. Handle in-place reuse anyway:
    // without it the State would keep serving the previous song's saved preset
    // and would never open the provider for the new number at all.
    _savedViewConfig = ref
        .read(settingsRepositoryProvider)
        .getSongViewConfig(widget.songId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openCurrentSong();
    });
  }

  /// Points every per-song provider at [SongViewScreen.songId].
  ///
  /// Must run after the frame: these all mutate provider state, which Riverpod
  /// forbids during build.
  void _openCurrentSong() {
    ref.read(songViewProvider.notifier).openSong(widget.songId);
    ref.read(autoScrollProvider.notifier).init(widget.songId);
    _syncSetlistPosition();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Animate the text scale to [target] over a short eased duration so a
  /// discrete zoom step (mouse wheel) glides instead of snapping.
  void _animateZoomTo(double target) {
    _zoomFrom = ref.read(textScaleProvider);
    _zoomTo = target.clamp(0.5, 2.0);
    _zoomController.forward(from: 0);
  }

  /// Longest gap between ticks that is treated as real elapsed time.
  ///
  /// A [Ticker] keeps its start time while muted, so any stretch where frames
  /// stop arriving — presentation mode pushed on top (TickerMode mutes us), a
  /// backgrounded browser tab, a paused debugger — comes back as one enormous
  /// `dt`. Un-clamped, ten seconds in presentation mode teleported the song
  /// 400 px on the first frame back (audit finding S11).
  ///
  /// 250 ms deliberately sits between the two cases rather than near either.
  /// Clamping at a frame or two (~33 ms) also throttles genuinely slow
  /// rendering — a headless browser measured here at 1.3 fps scrolled ~20×
  /// too slowly — because the clamp then applies every frame, not just after
  /// a gap. Nothing that is actually painting runs below 4 fps, so this only
  /// ever fires on a real stall, where it costs a 10 px step.
  static const _maxTickDelta = 0.25;

  /// Advances the scroll position by `speed * dt` each frame while playing.
  /// Stops automatically when the bottom of the song is reached.
  void _onAutoScrollTick(Duration elapsed) {
    final rawDt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    final dt = rawDt.clamp(0.0, _maxTickDelta);
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
    final index = playback.songIds.indexOf(widget.songId);
    if (index != -1) {
      ref.read(setlistPlaybackProvider.notifier).jumpTo(index);
    }
  }

  /// Whether [song] has anything to engrave.
  ///
  /// Structured notation or a legacy SVG. A pasted chord sheet has neither, and
  /// the sheet-music view for one of those used to be a placeholder telling the
  /// user to switch views by hand.
  static bool _canShowSheetMusic(Song song) =>
      song.hasNotation || song.hasSheetMusic;

  /// Guards the fall-through notice so it is shown once per song, not on every
  /// rebuild — and this screen rebuilds on every frame of a zoom gesture.
  bool _noSheetMusicNoticeShown = false;

  /// Tells the user why they are looking at chords when they asked for a staff.
  ///
  /// Swapping the view silently would leave the controls sheet and the screen
  /// disagreeing with nothing on screen to explain which one won.
  void _noticeNoSheetMusic() {
    if (_noSheetMusicNoticeShown) return;
    _noSheetMusicNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).noSheetMusicShowingChords),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _showControlsSheet(
    BuildContext context,
    String originalKey, {
    required bool canShowSheetMusic,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SongControlsSheet(
        originalKey: originalKey,
        canShowSheetMusic: canShowSheetMusic,
      ),
    );
  }

  void _showTagEditor(BuildContext context, List<String> currentTags) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TagEditorSheet(
        songId: widget.songId,
        currentTags: currentTags,
      ),
    );
  }

  /// Puts the whole song on the clipboard as ChordPro.
  ///
  /// The lines are selectable too, but dragging a selection across every verse of
  /// a hymn on a phone is not a realistic way to copy a song. ChordPro because
  /// the paste importer already reads it: what comes out can go straight back in.
  Future<void> _copySongText(Song song) async {
    final text = const ChordSheetExporter().toChordPro(song);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).songTextCopied),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Deletes this user song, after asking.
  ///
  /// Confirmed because it cannot be undone: a user song exists only in this
  /// device's local storage, with no copy in the bundled catalogue to fall back
  /// on and no server holding a second one.
  Future<void> _confirmDelete(Song song) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteSongTitle),
        content: Text(l10n.deleteSongBody(song.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(userSongsProvider.notifier).remove(widget.songId);
    if (!mounted) return;
    // Leaving is not optional: this screen now describes a song that no longer
    // exists, and staying would repaint it as "Song not found". Navigating
    // rather than popping unconditionally, because a deep link straight to the
    // song has nothing beneath it to pop to.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// The song-view app bar.
  ///
  /// This bar used to carry back + `"151. Title"` + four actions (tags,
  /// auto-scroll, presentation, favourite). On a phone that left a long
  /// Hungarian hymn title a few characters wide — the UAT complaint this
  /// rewrite answers. Three changes:
  ///
  ///   - the number moves out of the title string onto its own line, so it and
  ///     its separator stop eating title width on every song
  ///   - the title gets two lines before it ellipsizes
  ///   - only the favourite stays in the bar. Presentation and tag editing move
  ///     behind an overflow menu, and auto-scroll is dropped outright: the
  ///     controls sheet already owns it *with* a speed slider, and one piece of
  ///     state behind two affordances is how the two drift apart.
  ///
  /// [AppBar.toolbarHeight] is derived from the text scaler rather than fixed.
  /// Two lines of scaled title plus the number line does not fit
  /// [kToolbarHeight], and a fixed height overflows in yellow stripes as soon
  /// as the system font is enlarged.
  AppBar _buildAppBar(BuildContext context, Song song, bool isFavorite) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final numberStyle = theme.textTheme.labelMedium;
    final titleStyle = theme.textTheme.titleMedium;

    final numberHeight = textScaler.scale(numberStyle?.fontSize ?? 12) * 1.4;
    final titleLineHeight = textScaler.scale(titleStyle?.fontSize ?? 16) * 1.35;
    final toolbarHeight = (numberHeight + titleLineHeight * 2 + 16)
        .clamp(kToolbarHeight, 180.0)
        .toDouble();

    return AppBar(
      toolbarHeight: toolbarHeight,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref.read(bookServiceProvider).qualifiedNumber(song),
            style: numberStyle?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Flexible, not a bare Text: at extreme text scales the computed
          // height hits the clamp above, and without this the two lines
          // overflow the toolbar instead of ellipsizing into the room there is.
          Flexible(
            child: Text(
              song.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : null,
          ),
          onPressed: () => ref
              .read(favoritesProvider.notifier)
              .toggleFavorite(widget.songId),
          tooltip: isFavorite ? l10n.favoriteRemove : l10n.favoriteAdd,
        ),
        PopupMenuButton<_SongMenuAction>(
          icon: const Icon(Icons.more_vert),
          tooltip: l10n.moreActions,
          onSelected: (action) {
            switch (action) {
              case _SongMenuAction.presentation:
                context.push(AppRoutes.presentationPath(widget.songId));
              case _SongMenuAction.editTags:
                _showTagEditor(context, song.tags);
              case _SongMenuAction.copyText:
                _copySongText(song);
              case _SongMenuAction.editSong:
                context.push(AppRoutes.editSongPath(widget.songId));
              case _SongMenuAction.editNotation:
                context.push(AppRoutes.editNotationPath(widget.songId));
              case _SongMenuAction.deleteSong:
                _confirmDelete(song);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _SongMenuAction.presentation,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                // A screen with a play button says "start presenting". The
                // fullscreen arrows say "make this bigger", which is a
                // different promise than the one this action keeps.
                leading: const Icon(Icons.slideshow),
                title: Text(l10n.menuPresentation),
              ),
            ),
            PopupMenuItem(
              value: _SongMenuAction.editTags,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.label_outline),
                title: Text(l10n.menuEditTags),
              ),
            ),
            PopupMenuItem(
              value: _SongMenuAction.copyText,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.copy_outlined),
                title: Text(l10n.menuCopyText),
              ),
            ),
            // Only the user's own songs can be written back to. Offering these
            // for a bundled hymn would be a control that cannot work.
            if (song.id.isUserSong) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _SongMenuAction.editSong,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.menuEditSong),
                ),
              ),
              // Only when there is an engraving to correct. On a song with no
              // notation this would open a blank staff — which is the score
              // writer the editor is deliberately not.
              if (song.hasNotation)
                PopupMenuItem(
                  value: _SongMenuAction.editNotation,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.music_note_outlined),
                    title: Text(l10n.menuEditNotation),
                  ),
                ),
              PopupMenuItem(
                value: _SongMenuAction.deleteSong,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  title: Text(l10n.menuDeleteSong,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final songAsync = ref.watch(songByIdProvider(widget.songId));
    final isFavorite = ref.watch(isFavoriteProvider(widget.songId));
    // Deliberately NOT watching autoScrollProvider. The play control lives in
    // the controls sheet, which watches it itself; watching here rebuilt the
    // whole screen on every frame of a speed-slider drag. The ticker is driven
    // by the ref.listen below, which needs no watch.

    // openSong() cannot run before the first build (mutating a provider during
    // build is forbidden), so on that first frame songViewProvider still
    // describes the song we navigated AWAY from. Reading it unguarded painted
    // one frame of the previous song's transpose, zoom and preset — most
    // visibly a whole different view mode (audit finding S13). Until the
    // provider catches up, use this song's own saved config and neutral
    // transpose/zoom.
    final songView = ref.watch(songViewProvider);
    final globalViewConfig = ref.watch(viewConfigProvider);
    final isCurrentSong = songView?.songId == widget.songId;

    final viewConfig = isCurrentSong
        ? (songView!.activeViewConfig ?? globalViewConfig)
        : (_savedViewConfig ?? globalViewConfig);
    final transpose = isCurrentSong ? songView!.transposeAmount : 0;
    final textScale = isCurrentSong ? songView!.textScale : 1.0;

    // Start/stop the ticker as the play state changes.
    ref.listen<bool>(
      autoScrollProvider.select((s) => s.isPlaying),
      (_, playing) => _setAutoScrollRunning(playing),
    );

    // Switching to a notation view hides every auto-scroll control, so pause
    // the state too — otherwise playback stays "on" with no way to stop it, the
    // ticker keeps burning frames, and switching back resumes unexpectedly.
    ref.listen<bool>(
      effectiveViewConfigProvider.select((c) => c.showNotation),
      (_, showsNotation) {
        if (showsNotation && ref.read(autoScrollProvider).isPlaying) {
          ref.read(autoScrollProvider.notifier).pause();
        }
      },
    );

    return songAsync.when(
      data: (song) {
        if (song == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.songNotFound)),
            body: Center(child: Text(l10n.songNotFound)),
          );
        }

        // Asking for a staff a song does not have used to land on a placeholder
        // that told the user to switch views themselves — a dead end, and the one
        // piece of text on screen that ignored the text-size setting. Fall
        // through to the chords instead and say so.
        final canShowSheetMusic = _canShowSheetMusic(song);
        final showsNotation = viewConfig.showNotation && canShowSheetMusic;
        if (viewConfig.showNotation && !canShowSheetMusic) {
          _noticeNoSheetMusic();
        }

        return Scaffold(
          appBar: _buildAppBar(context, song, isFavorite),
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
                if (showsNotation)
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
          ),
          floatingActionButton: FloatingActionButton.small(
            onPressed: () => _showControlsSheet(
              context,
              song.originalKey,
              canShowSheetMusic: canShowSheetMusic,
            ),
            tooltip: l10n.songControls,
            child: const Icon(Icons.tune),
          ),
          bottomNavigationBar: SetlistNavBar(songId: widget.songId),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.loading)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(l10n.errorGeneric)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(l10n.errorDetail('$error')),
            ],
          ),
        ),
      ),
    );
  }
}
