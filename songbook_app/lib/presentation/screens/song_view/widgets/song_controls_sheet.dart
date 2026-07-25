import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/view_config.dart';
import '../../../../domain/services/capo_service.dart';
import '../../../providers/providers.dart';
import '../../../providers/song_provider.dart';

/// Bottom sheet widget containing all song control sections.
///
/// Organized into three labeled sections:
/// - View: Preset chips (Sheet Music, Chords, Lyrics)
/// - Transpose: +/- buttons with key display and reset
/// - Text Size: A-/A+ buttons with scale percentage
class SongControlsSheet extends ConsumerStatefulWidget {
  final String originalKey;

  const SongControlsSheet({
    required this.originalKey,
    super.key,
  });

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
    final transpositionService = ref.read(transpositionServiceProvider);
    final capoService = ref.read(capoServiceProvider);
    final songViewNotifier = ref.read(songViewProvider.notifier);

    final targetKey = transpositionService.calculateTargetKey(
      widget.originalKey,
      transpose,
    );
    final hasTranspose = transpose != 0;
    final capoSuggestions = capoService.suggestionsFor(targetKey);

    return Container(
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
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Section
                _SectionHeader(text: 'VIEW', theme: theme),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.piano, size: 18),
                          SizedBox(width: 6),
                          Text('Sheet Music'),
                        ],
                      ),
                      selected: viewConfig.isSheetMusicPreset,
                      onSelected: (_) {
                        songViewNotifier.setPreset(const ViewConfig.sheetMusic());
                      },
                    ),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note, size: 18),
                          SizedBox(width: 6),
                          Text('Chords'),
                        ],
                      ),
                      selected: viewConfig.isChordsPreset,
                      onSelected: (_) {
                        songViewNotifier.setPreset(const ViewConfig.chords());
                      },
                    ),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.text_snippet, size: 18),
                          SizedBox(width: 6),
                          Text('Lyrics'),
                        ],
                      ),
                      selected: viewConfig.isLyricsOnlyPreset,
                      onSelected: (_) {
                        songViewNotifier.setPreset(const ViewConfig.lyricsOnly());
                      },
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Transpose Section
                _SectionHeader(text: 'TRANSPOSE', theme: theme),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: songViewNotifier.transposeDown,
                      tooltip: 'Transpose down',
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            targetKey,
                            style: theme.textTheme.titleMedium?.copyWith(
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: songViewNotifier.transposeUp,
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
                      onPressed: songViewNotifier.resetTranspose,
                      child: Text('Reset to ${widget.originalKey}'),
                    ),
                  ),
                ),

                const Divider(height: 32),

                // Capo Section
                _SectionHeader(text: 'CAPO', theme: theme),
                const SizedBox(height: 12),
                _CapoSection(
                  soundingKey: targetKey,
                  suggestions: capoSuggestions,
                  theme: theme,
                ),

                const Divider(height: 32),

                // Text Size Section
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

                // Bottom padding for safe area
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
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
                          : 'Play ${recommended.shapeKey} shapes (sounds $soundingKey)',
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

  const _SectionHeader({
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
