import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../../../providers/song_provider.dart';

/// Style options for transpose controls in app bar
enum TransposeStyle {
  /// Full controls with +/- buttons (original style)
  compact,
  /// Settings icon that opens a bottom sheet
  bottomSheet,
  /// Settings icon that opens a popup menu
  popupMenu,
  /// Just a key badge that opens a dialog on tap
  keyBadge,
  /// Dropdown to select target key directly
  dropdown,
}

/// Widget for transposition controls
class TransposeControls extends ConsumerWidget {
  final int currentTranspose;
  final String originalKey;
  final VoidCallback onTransposeUp;
  final VoidCallback onTransposeDown;
  final VoidCallback onReset;
  final bool compact;
  final TransposeStyle style;

  const TransposeControls({
    required this.currentTranspose,
    required this.originalKey,
    required this.onTransposeUp,
    required this.onTransposeDown,
    required this.onReset,
    this.compact = false,
    this.style = TransposeStyle.bottomSheet,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transpositionService = ref.read(transpositionServiceProvider);
    final targetKey = transpositionService.calculateTargetKey(
      originalKey,
      currentTranspose,
    );
    final theme = Theme.of(context);

    // If not compact, use full style
    if (!compact) {
      return _buildFull(context, theme, targetKey);
    }

    // Compact styles for app bar
    switch (style) {
      case TransposeStyle.compact:
        return _buildCompact(context, theme, targetKey);
      case TransposeStyle.bottomSheet:
        return _buildBottomSheetTrigger(context, theme, targetKey);
      case TransposeStyle.popupMenu:
        return _buildPopupMenuTrigger(context, theme, targetKey);
      case TransposeStyle.keyBadge:
        return _buildKeyBadge(context, theme, targetKey);
      case TransposeStyle.dropdown:
        return _buildDropdown(context, theme, targetKey, transpositionService);
    }
  }

  Widget _buildCompact(BuildContext context, ThemeData theme, String targetKey) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Transpose down button
        IconButton(
          onPressed: onTransposeDown,
          icon: const Icon(Icons.remove, size: 20),
          tooltip: 'Transpose down',
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),

        // Key display
        GestureDetector(
          onTap: currentTranspose != 0 ? onReset : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: currentTranspose != 0
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentTranspose != 0
                  ? '$targetKey (${_getTransposeLabel()})'
                  : targetKey,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: currentTranspose != 0
                    ? theme.colorScheme.onPrimaryContainer
                    : null,
              ),
            ),
          ),
        ),

        // Transpose up button
        IconButton(
          onPressed: onTransposeUp,
          icon: const Icon(Icons.add, size: 20),
          tooltip: 'Transpose up',
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildFull(BuildContext context, ThemeData theme, String targetKey) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Transpose down button
          IconButton(
            onPressed: onTransposeDown,
            icon: const Icon(Icons.remove),
            tooltip: 'Transpose down',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),

          const SizedBox(width: 8),

          // Key display
          GestureDetector(
            onTap: currentTranspose != 0 ? onReset : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: currentTranspose != 0
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Key: $targetKey',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: currentTranspose != 0
                          ? theme.colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  if (currentTranspose != 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      _getTransposeLabel(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.replay,
                      size: 14,
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Transpose up button
          IconButton(
            onPressed: onTransposeUp,
            icon: const Icon(Icons.add),
            tooltip: 'Transpose up',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  // Style 2: Bottom sheet trigger
  Widget _buildBottomSheetTrigger(BuildContext context, ThemeData theme, String targetKey) {
    final hasTranspose = currentTranspose != 0;

    return IconButton(
      onPressed: () => _showBottomSheet(context, theme, targetKey),
      icon: Badge(
        isLabelVisible: hasTranspose,
        label: Text(_getTransposeLabel()),
        child: const Icon(Icons.tune),
      ),
      tooltip: 'Transpose: $targetKey',
    );
  }

  void _showBottomSheet(BuildContext context, ThemeData theme, String targetKey) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Transpose',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    onTransposeDown();
                    Navigator.pop(context);
                    _showBottomSheet(context, theme, targetKey);
                  },
                  icon: const Icon(Icons.remove),
                  label: const Text('Down'),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: currentTranspose != 0
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        targetKey,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (currentTranspose != 0)
                        Text(
                          _getTransposeLabel(),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.tonalIcon(
                  onPressed: () {
                    onTransposeUp();
                    Navigator.pop(context);
                    _showBottomSheet(context, theme, targetKey);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Up'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentTranspose != 0)
              TextButton.icon(
                onPressed: () {
                  onReset();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.replay),
                label: Text('Reset to $originalKey'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Style 3: Popup menu trigger - opens persistent popup dialog
  Widget _buildPopupMenuTrigger(BuildContext context, ThemeData theme, String targetKey) {
    final hasTranspose = currentTranspose != 0;

    return IconButton(
      tooltip: 'Transpose: $targetKey',
      icon: Badge(
        isLabelVisible: hasTranspose,
        label: Text(_getTransposeLabel()),
        child: const Icon(Icons.tune),
      ),
      onPressed: () => _showTransposePopup(context),
    );
  }

  void _showTransposePopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Transpose',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: _TransposeSidePanel(
            originalKey: originalKey,
            currentTranspose: currentTranspose,
            onTransposeUp: onTransposeUp,
            onTransposeDown: onTransposeDown,
            onReset: onReset,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  // Style 4: Key badge only
  Widget _buildKeyBadge(BuildContext context, ThemeData theme, String targetKey) {
    final hasTranspose = currentTranspose != 0;

    return GestureDetector(
      onTap: () => _showTransposeDialog(context, theme, targetKey),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasTranspose
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note,
              size: 16,
              color: hasTranspose
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
            Text(
              hasTranspose ? '$targetKey (${_getTransposeLabel()})' : targetKey,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: hasTranspose
                    ? theme.colorScheme.onPrimaryContainer
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransposeDialog(BuildContext context, ThemeData theme, String targetKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transpose'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              targetKey,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (currentTranspose != 0)
              Text('(${_getTransposeLabel()} from $originalKey)'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filled(
                  onPressed: () {
                    onTransposeDown();
                    Navigator.pop(context);
                    _showTransposeDialog(context, theme, targetKey);
                  },
                  icon: const Icon(Icons.remove),
                ),
                IconButton.filled(
                  onPressed: () {
                    onTransposeUp();
                    Navigator.pop(context);
                    _showTransposeDialog(context, theme, targetKey);
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (currentTranspose != 0)
            TextButton(
              onPressed: () {
                onReset();
                Navigator.pop(context);
              },
              child: const Text('Reset'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Style 5: Dropdown selector
  Widget _buildDropdown(BuildContext context, ThemeData theme, String targetKey, dynamic transpositionService) {
    final keys = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];

    return DropdownButton<String>(
      value: targetKey,
      underline: const SizedBox(),
      icon: const Icon(Icons.arrow_drop_down),
      items: keys.map((key) {
        return DropdownMenuItem(
          value: key,
          child: Text(key),
        );
      }).toList(),
      onChanged: (newKey) {
        if (newKey != null) {
          final semitones = _getSemitonesToKey(newKey);
          // Apply the transposition by calling up/down multiple times
          // or reset and apply
          onReset();
          for (int i = 0; i < semitones.abs(); i++) {
            if (semitones > 0) {
              onTransposeUp();
            } else {
              onTransposeDown();
            }
          }
        }
      },
    );
  }

  int _getSemitonesForKey(String key) {
    const keyMap = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11};
    return keyMap[key] ?? 0;
  }

  int _getSemitonesToKey(String targetKey) {
    final originalSemitones = _getSemitonesForKey(originalKey);
    final targetSemitones = _getSemitonesForKey(targetKey);
    var diff = targetSemitones - originalSemitones;
    if (diff > 6) diff -= 12;
    if (diff < -6) diff += 12;
    return diff;
  }

  String _getTransposeLabel() {
    if (currentTranspose == 0) return '';
    if (currentTranspose > 0) return '+$currentTranspose';
    return currentTranspose.toString();
  }
}

/// Right sidebar panel for transpose controls that stays open
/// and updates the key display in real-time
class _TransposeSidePanel extends ConsumerWidget {
  final String originalKey;
  final int currentTranspose;
  final VoidCallback onTransposeUp;
  final VoidCallback onTransposeDown;
  final VoidCallback onReset;

  const _TransposeSidePanel({
    required this.originalKey,
    required this.currentTranspose,
    required this.onTransposeUp,
    required this.onTransposeDown,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Watch the current transpose value to update in real-time
    final transpose = ref.watch(transposeProvider);
    final transpositionService = ref.read(transpositionServiceProvider);
    final targetKey = transpositionService.calculateTargetKey(originalKey, transpose);
    final hasTranspose = transpose != 0;

    return Material(
      elevation: 16,
      child: Container(
        width: 280,
        height: double.infinity,
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transpose',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Key display - large and prominent
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      targetKey,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (hasTranspose)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${transpose > 0 ? '+' : ''}$transpose from $originalKey',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Transpose buttons - large and easy to tap
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onTransposeDown,
                        icon: const Icon(Icons.remove),
                        label: const Text('Down'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onTransposeUp,
                        icon: const Icon(Icons.add),
                        label: const Text('Up'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Reset button (only shown if transposed)
              if (hasTranspose)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.replay),
                    label: Text('Reset to $originalKey'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

              const Spacer(),

              // Footer hint
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Tap outside or press X to close',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
