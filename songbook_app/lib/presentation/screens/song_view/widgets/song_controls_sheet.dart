import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/view_config.dart';
import '../../../../domain/services/capo_service.dart';
import '../../../providers/autoscroll_provider.dart';
import '../../../providers/providers.dart';
import '../../../providers/song_provider.dart';

/// Bottom sheet containing every song control.
///
/// **Section order and presence are fixed.** Sections that do not apply to the
/// current view are disabled, never removed: the sheet is anchored to the
/// bottom of the screen, so dropping a section shortens it and slides every
/// remaining control — including the preset chips you are about to tap again —
/// to a new position. Switching Chords → Lyrics → Sheet Music has to be
/// repeatable without re-aiming, so the layout must not move.
///
/// Order, top to bottom:
///   1. VIEW        — always applies
///   2. TEXT SIZE   — always applies
///   3. TRANSPOSE   — inert in Lyrics (no chords, no staff to re-spell)
///   4. CAPO        — derived from the transposed key, so inert wherever
///                    TRANSPOSE is
///   5. AUTO-SCROLL — inert in Sheet Music (it drives the chord/lyrics
///                    scroller, which is not mounted there)
///
/// The two universally-applicable sections sit at the top so the controls
/// reached most often are always in the same place.
class SongControlsSheet extends ConsumerStatefulWidget {
  final String originalKey;

  /// Whether this song has anything to engrave — structured notation or a legacy
  /// SVG. When it does not, the Sheet Music preset is shown disabled rather than
  /// removed: a section that changes shape per song makes the sheet a different
  /// object every time it opens.
  final bool canShowSheetMusic;

  const SongControlsSheet({
    required this.originalKey,
    this.canShowSheetMusic = true,
    super.key,
  });

  /// Names the auto-scroll speed instead of quoting it.
  ///
  /// The slider used to report `40 px/s` — the unit the ticker happens to count
  /// in, which tells a singer nothing: the pixels a hymn takes depend on the
  /// text size, the phone and whether chords are showing. What the control is
  /// actually for is "a bit faster than that", so the label says only that, and
  /// the two ends are pinned so the extremes are recognisable.
  ///
  /// Named rather than shown as a percentage for the same reason: 63% of a range
  /// nobody can see is still a number standing in for a feeling.
  static String speedLabel(double speed) {
    const names = ['Slowest', 'Slow', 'Gentle', 'Steady', 'Brisk', 'Fast',
        'Fastest'];
    const min = AutoScrollState.minSpeed;
    const max = AutoScrollState.maxSpeed;
    final fraction = ((speed - min) / (max - min)).clamp(0.0, 1.0);
    final index = (fraction * (names.length - 1)).round();
    return names[index];
  }

  @override
  ConsumerState<SongControlsSheet> createState() => _SongControlsSheetState();
}

class _SongControlsSheetState extends ConsumerState<SongControlsSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewConfig = ref.watch(effectiveViewConfigProvider);
    final transpose = ref.watch(transposeProvider);
    final textScale = ref.watch(textScaleProvider);
    final autoScroll = ref.watch(autoScrollProvider);
    final transpositionService = ref.read(transpositionServiceProvider);
    final capoService = ref.read(capoServiceProvider);
    final songViewNotifier = ref.read(songViewProvider.notifier);
    final autoScrollNotifier = ref.read(autoScrollProvider.notifier);

    final targetKey = transpositionService.calculateTargetKey(
      widget.originalKey,
      transpose,
    );
    final hasTranspose = transpose != 0;
    final capoSuggestions = capoService.suggestionsFor(targetKey);

    // Transposition only ever repaints chord symbols or the staff. With
    // neither on screen (the Lyrics preset) it changes nothing visible.
    final canTranspose = viewConfig.showChords || viewConfig.showNotation;
    // Auto-scroll drives ChordView's ScrollController, which sheet-music view
    // does not mount.
    final canAutoScroll = !viewConfig.showNotation;

    // DraggableScrollableSheet, not a plain content-sized Column: a bare
    // SingleChildScrollView wins the vertical-drag gesture, so swiping down
    // over the controls only scrolled them and the sheet could be dismissed
    // solely by grabbing the 4px handle — near-impossible on a phone. Handing
    // the scroll controller to the scroll view makes the two share one
    // gesture: scroll while there is content above, and once at the top the
    // same downward swipe drags the sheet itself. Reaching minChildSize emits
    // a DraggableScrollableNotification that the modal route closes on
    // (shouldCloseOnMinExtent, on by default), so a swipe anywhere dismisses.
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      // Deliberately close to the initial size: the sheet closes on reaching
      // this extent, so a small min would demand a near-full-screen drag.
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Flexible + SingleChildScrollView (decision 02-02): five sections
            // overflow a short viewport, and every one is always rendered now,
            // so the content must stay scrollable.
            Flexible(
              child: SingleChildScrollView(
                controller: scrollController,
                // Always scrollable, even when the content fits: an
                // unscrollable view reports no overscroll, and the sheet drag
                // is driven by exactly that.
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---------------------------------------------- 1. VIEW
                      _SectionHeader(text: 'VIEW', theme: theme),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            // No checkmark: it appears only on the selected chip,
                            // so the row's width changed with every switch, and
                            // it cost the horizontal space that made three
                            // labelled chips wrap to two lines on a phone. The
                            // chip's own fill already says which is selected.
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // A note, not a piano: the choice is between
                                // notation and chords, not between instruments.
                                Icon(Icons.music_note, size: 18),
                                SizedBox(width: 6),
                                Text('Sheet'),
                              ],
                            ),
                            selected: viewConfig.isSheetMusicPreset,
                            onSelected: widget.canShowSheetMusic
                                ? (_) => songViewNotifier.setPreset(
                                      const ViewConfig.sheetMusic(),
                                    )
                                : null,
                          ),
                          ChoiceChip(
                            // No checkmark: it appears only on the selected chip,
                            // so the row's width changed with every switch, and
                            // it cost the horizontal space that made three
                            // labelled chips wrap to two lines on a phone. The
                            // chip's own fill already says which is selected.
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Chord letters, because that is literally what
                                // this view draws above the lyric. A guitar
                                // would read faster but promise less: these
                                // songs are played on organ and piano too, and
                                // stock Material has no guitar glyph anyway.
                                Icon(Icons.abc, size: 18),
                                SizedBox(width: 6),
                                Text('Chords'),
                              ],
                            ),
                            selected: viewConfig.isChordsPreset,
                            onSelected: (_) => songViewNotifier.setPreset(
                              const ViewConfig.chords(),
                            ),
                          ),
                          ChoiceChip(
                            // No checkmark: it appears only on the selected chip,
                            // so the row's width changed with every switch, and
                            // it cost the horizontal space that made three
                            // labelled chips wrap to two lines on a phone. The
                            // chip's own fill already says which is selected.
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.text_snippet, size: 18),
                                SizedBox(width: 6),
                                Text('Lyrics'),
                              ],
                            ),
                            selected: viewConfig.isLyricsOnlyPreset,
                            onSelected: (_) => songViewNotifier.setPreset(
                              const ViewConfig.lyricsOnly(),
                            ),
                          ),
                        ],
                      ),

                      if (!widget.canShowSheetMusic) ...[
                        const SizedBox(height: 8),
                        Text(
                          'There is no sheet music for this song, so it opens '
                          'in Chords.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      // "Chords above staff" only means anything with a staff on
                      // screen, but it must not change the sheet's height, so it
                      // keeps its slot and greys out instead.
                      _Disableable(
                        enabled: viewConfig.showNotation,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: viewConfig.showChords,
                          onChanged: viewConfig.showNotation
                              ? songViewNotifier.setShowChords
                              : null,
                          title: const Text('Chords above staff'),
                        ),
                      ),

                      const Divider(height: 32),

                      // ----------------------------------------- 2. TEXT SIZE
                      _SectionHeader(text: 'TEXT SIZE', theme: theme),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: songViewNotifier.decreaseTextScale,
                            child: Semantics(
                              label: 'Decrease text size',
                              excludeSemantics: true,
                              child: const Text(
                                'A-',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${(textScale * 100).round()}%',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: songViewNotifier.increaseTextScale,
                            child: Semantics(
                              label: 'Increase text size',
                              excludeSemantics: true,
                              child: const Text(
                                'A+',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 32),

                      // ----------------------------------------- 3. TRANSPOSE
                      _SectionHeader(
                        text: 'TRANSPOSE',
                        theme: theme,
                        enabled: canTranspose,
                        hint: canTranspose ? null : 'no chords in this view',
                      ),
                      const SizedBox(height: 12),
                      _Disableable(
                        enabled: canTranspose,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: canTranspose
                                      ? songViewNotifier.transposeDown
                                      : null,
                                  tooltip: 'Transpose down',
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        targetKey,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Visibility(
                                        visible: hasTranspose,
                                        maintainSize: true,
                                        maintainAnimation: true,
                                        maintainState: true,
                                        child: Text(
                                          hasTranspose
                                              ? '${transpose > 0 ? '+' : ''}$transpose'
                                              : '0',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: canTranspose
                                      ? songViewNotifier.transposeUp
                                      : null,
                                  tooltip: 'Transpose up',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Visibility(
                                visible: hasTranspose,
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                child: TextButton(
                                  onPressed: canTranspose
                                      ? songViewNotifier.resetTranspose
                                      : null,
                                  child: Text('Reset to ${widget.originalKey}'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 32),

                      // ---------------------------------------------- 4. CAPO
                      _SectionHeader(
                        text: 'CAPO',
                        theme: theme,
                        enabled: canTranspose,
                        hint: canTranspose ? null : 'no chords in this view',
                      ),
                      const SizedBox(height: 12),
                      _Disableable(
                        enabled: canTranspose,
                        child: _CapoSection(
                          soundingKey: targetKey,
                          suggestions: capoSuggestions,
                          theme: theme,
                        ),
                      ),

                      const Divider(height: 32),

                      // --------------------------------------- 5. AUTO-SCROLL
                      _SectionHeader(
                        text: 'AUTO-SCROLL',
                        theme: theme,
                        enabled: canAutoScroll,
                        hint: canAutoScroll ? null : 'not in sheet music view',
                      ),
                      const SizedBox(height: 12),
                      _Disableable(
                        enabled: canAutoScroll,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  icon: Icon(
                                    autoScroll.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                  onPressed: canAutoScroll
                                      ? () {
                                          final wasPlaying =
                                              autoScroll.isPlaying;
                                          autoScrollNotifier.toggle();
                                          // Starting scrolls the text this sheet
                                          // is sitting on top of, so get out of
                                          // the way. Pausing does not: that is
                                          // the moment the speed slider is most
                                          // likely wanted.
                                          if (!wasPlaying) {
                                            Navigator.of(context).maybePop();
                                          }
                                        }
                                      : null,
                                  tooltip: autoScroll.isPlaying
                                      ? 'Stop auto-scroll'
                                      : 'Start auto-scroll',
                                ),
                                const SizedBox(width: 8),
                                const _SpeedGlyph(emoji: '🐌', label: 'Slow'),
                                Expanded(
                                  child: Slider(
                                    value: autoScroll.speed,
                                    min: AutoScrollState.minSpeed,
                                    max: AutoScrollState.maxSpeed,
                                    divisions: 18,
                                    label:
                                        SongControlsSheet.speedLabel(
                                            autoScroll.speed),
                                    // Live update while dragging; persist once on
                                    // release rather than on every frame.
                                    onChanged: canAutoScroll
                                        ? autoScrollNotifier.setSpeed
                                        : null,
                                    onChangeEnd: autoScrollNotifier.commitSpeed,
                                  ),
                                ),
                                const _SpeedGlyph(emoji: '🏎️', label: 'Fast'),
                              ],
                            ),
                            Center(
                              child: Text(
                                'Speed remembered per song',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom padding for safe area
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Speed-slider end marker.
///
/// Emoji rather than Material icons because there is no snail or race car in
/// the icon set, and `directions_walk`/`directions_run` read as a person
/// moving rather than as a speed scale. [label] carries the meaning for
/// screen readers, which would otherwise announce the raw codepoint.
class _SpeedGlyph extends StatelessWidget {
  final String emoji;
  final String label;

  const _SpeedGlyph({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Text(emoji, style: const TextStyle(fontSize: 19)),
    );
  }
}

/// Greys out and blocks interaction with [child] when [enabled] is false,
/// while keeping it in the layout so the sheet's height never changes.
class _Disableable extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _Disableable({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;
    return ExcludeSemantics(
      child: IgnorePointer(child: Opacity(opacity: 0.38, child: child)),
    );
  }
}

/// Capo helper: shows the recommended capo position + open-chord shape for the
/// current sounding key, with the remaining CAGED options listed below.
class _CapoSection extends StatelessWidget {
  final String soundingKey;
  final List<CapoSuggestion> suggestions;
  final ThemeData theme;

  const _CapoSection({
    required this.soundingKey,
    required this.suggestions,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return Text(
        'No capo suggestion for $soundingKey',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final recommended = suggestions.first;
    final alternatives = suggestions.skip(1).toList();
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recommended suggestion, prominent.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.straighten, color: scheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommended.fret == 0
                          ? 'No capo needed'
                          : 'Capo ${recommended.fret}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      recommended.fret == 0
                          ? 'Play open in ${recommended.shapeKey} (sounds $soundingKey)'
                          : 'Clamp fret ${recommended.fret}, finger '
                                '${recommended.shapeKey} shapes — sounds $soundingKey',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (alternatives.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Other positions',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in alternatives)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    s.fret == 0
                        ? 'Open · ${s.shapeKey}'
                        : 'Capo ${s.fret} · ${s.shapeKey}',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Section header widget for labeled sections
class _SectionHeader extends StatelessWidget {
  final String text;
  final ThemeData theme;
  final bool enabled;

  /// Short reason shown beside the header when the section is disabled, so a
  /// greyed-out control explains itself rather than looking broken.
  final String? hint;

  const _SectionHeader({
    required this.text,
    required this.theme,
    this.enabled = true,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Semantics(
          header: true,
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '· $hint',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
