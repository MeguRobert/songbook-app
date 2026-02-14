import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/models/view_config.dart';
import '../../../../router/app_router.dart';
import '../../../providers/providers.dart';
import '../../../providers/song_provider.dart';

/// Floating controls menu for transpose and text size adjustments
/// Displays as a vertical stack of buttons on the right side of the screen
class FloatingControlsMenu extends ConsumerStatefulWidget {
  final String originalKey;

  const FloatingControlsMenu({
    required this.originalKey,
    super.key,
  });

  @override
  ConsumerState<FloatingControlsMenu> createState() => _FloatingControlsMenuState();
}

class _FloatingControlsMenuState extends ConsumerState<FloatingControlsMenu>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transpose = ref.watch(transposeProvider);
    final transpositionService = ref.read(transpositionServiceProvider);
    final songViewNotifier = ref.read(songViewProvider.notifier);
    final songViewState = ref.watch(songViewProvider);
    final viewConfig = ref.watch(effectiveViewConfigProvider);

    final targetKey = transpositionService.calculateTargetKey(
      widget.originalKey,
      transpose,
    );
    final hasTranspose = transpose != 0;

    // Fixed height for the expanded menu (doesn't change based on reset button)
    const spacing = 4.0;
    const sectionSpacing = 8.0;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expanded menu items with fixed layout
              Flexible(
                child: SizeTransition(
                  sizeFactor: _expandAnimation,
                  axisAlignment: -1,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      // Fixed width for the menu
                      width: 48,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                    children: [
                      // Presentation mode button
                      _MenuButton(
                        icon: Icons.fullscreen,
                        onTap: () {
                          if (songViewState != null) {
                            context.push(AppRoutes.presentationPath(songViewState.songNumber));
                          }
                        },
                        theme: theme,
                        tooltip: 'Presentation mode',
                      ),
                      const SizedBox(height: sectionSpacing),

                      // Text size increase
                      _MenuButton(
                        label: 'A+',
                        onTap: songViewNotifier.increaseTextScale,
                        theme: theme,
                      ),
                      const SizedBox(height: spacing),

                      // Text size decrease
                      _MenuButton(
                        label: 'A-',
                        onTap: songViewNotifier.decreaseTextScale,
                        theme: theme,
                      ),
                      const SizedBox(height: sectionSpacing),

                      // View controls section
                      _ViewToggleButton(
                        icon: Icons.music_note,
                        isActive: viewConfig.showNotation,
                        onTap: songViewNotifier.toggleNotation,
                        theme: theme,
                        tooltip: 'Toggle notation',
                      ),
                      const SizedBox(height: spacing),
                      _ViewToggleButton(
                        label: 'C7',
                        isActive: viewConfig.showChords,
                        onTap: songViewNotifier.toggleChords,
                        theme: theme,
                        tooltip: 'Toggle chords',
                      ),
                      const SizedBox(height: spacing),

                      // Preset buttons
                      _PresetButton(
                        icon: Icons.piano,
                        isActive: viewConfig.isSheetMusicPreset,
                        onTap: () => songViewNotifier.setPreset(const ViewConfig.sheetMusic()),
                        theme: theme,
                        tooltip: 'Sheet Music',
                      ),
                      const SizedBox(height: spacing),
                      _PresetButton(
                        label: 'C',
                        isActive: viewConfig.isChordsPreset,
                        onTap: () => songViewNotifier.setPreset(const ViewConfig.chords()),
                        theme: theme,
                        tooltip: 'Chords',
                      ),
                      const SizedBox(height: spacing),
                      _PresetButton(
                        label: 'T',
                        isActive: viewConfig.isLyricsOnlyPreset,
                        onTap: () => songViewNotifier.setPreset(const ViewConfig.lyricsOnly()),
                        theme: theme,
                        tooltip: 'Lyrics',
                      ),
                      const SizedBox(height: sectionSpacing),

                      // Transpose up
                      _MenuButton(
                        label: 'T+',
                        onTap: songViewNotifier.transposeUp,
                        theme: theme,
                      ),
                      const SizedBox(height: spacing),

                      // Current key display
                      _KeyDisplay(
                        targetKey: targetKey,
                        originalKey: widget.originalKey,
                        transpose: transpose,
                        theme: theme,
                      ),
                      const SizedBox(height: spacing),

                      // Transpose down
                      _MenuButton(
                        label: 'T-',
                        onTap: songViewNotifier.transposeDown,
                        theme: theme,
                      ),
                      const SizedBox(height: sectionSpacing),

                      // Reset button - always reserve space, but only show when transposed
                      AnimatedOpacity(
                        opacity: hasTranspose ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: IgnorePointer(
                          ignoring: !hasTranspose,
                          child: _MenuButton(
                            label: widget.originalKey,
                            onTap: songViewNotifier.resetTranspose,
                            theme: theme,
                            isReset: true,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  ),
                ),
              ),

              // Toggle button (always visible)
              _ToggleButton(
                isExpanded: _isExpanded,
                onTap: _toggle,
                theme: theme,
                hasTranspose: hasTranspose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual menu button
class _MenuButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isReset;
  final String? tooltip;

  const _MenuButton({
    this.label,
    this.icon,
    required this.onTap,
    required this.theme,
    this.isReset = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: isReset
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        child: Container(
          width: 48,
          height: 40,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(
                  icon,
                  color: isReset
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.primary,
                  size: 20,
                )
              : Text(
                  label!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isReset
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.primary,
                  ),
                ),
        ),
      ),
    );

    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

/// Current key display widget
class _KeyDisplay extends StatelessWidget {
  final String targetKey;
  final String originalKey;
  final int transpose;
  final ThemeData theme;

  const _KeyDisplay({
    required this.targetKey,
    required this.originalKey,
    required this.transpose,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasTranspose = transpose != 0;

    return Material(
      color: hasTranspose
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
      elevation: 2,
      child: Container(
        width: 48,
        height: 44,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              targetKey,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: hasTranspose
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
                height: 1,
              ),
            ),
            if (hasTranspose)
              Text(
                '${transpose > 0 ? '+' : ''}$transpose',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  height: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Toggle button to expand/collapse the menu
class _ToggleButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool hasTranspose;

  const _ToggleButton({
    required this.isExpanded,
    required this.onTap,
    required this.theme,
    required this.hasTranspose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: hasTranspose
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isExpanded ? Icons.close : Icons.tune,
              color: hasTranspose
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// View toggle button (notation/chords toggle)
class _ViewToggleButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool isActive;
  final VoidCallback onTap;
  final ThemeData theme;
  final String tooltip;

  const _ViewToggleButton({
    this.icon,
    this.label,
    required this.isActive,
    required this.onTap,
    required this.theme,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
          child: Container(
            width: 48,
            height: 40,
            alignment: Alignment.center,
            child: icon != null
                ? Icon(
                    icon,
                    size: 20,
                    color: isActive
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  )
                : Text(
                    label!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Preset button (Sheet Music, Chords, Lyrics)
class _PresetButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool isActive;
  final VoidCallback onTap;
  final ThemeData theme;
  final String tooltip;

  const _PresetButton({
    this.icon,
    this.label,
    required this.isActive,
    required this.onTap,
    required this.theme,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        elevation: isActive ? 3 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
          child: Container(
            width: 48,
            height: 36,
            alignment: Alignment.center,
            child: icon != null
                ? Icon(
                    icon,
                    size: 18,
                    color: isActive
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  )
                : Text(
                    label!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
