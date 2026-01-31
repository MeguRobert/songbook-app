import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';

/// Widget for transposition controls
class TransposeControls extends ConsumerWidget {
  final int currentTranspose;
  final String originalKey;
  final VoidCallback onTransposeUp;
  final VoidCallback onTransposeDown;
  final VoidCallback onReset;

  const TransposeControls({
    required this.currentTranspose,
    required this.originalKey,
    required this.onTransposeUp,
    required this.onTransposeDown,
    required this.onReset,
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

  String _getTransposeLabel() {
    if (currentTranspose == 0) return '';
    if (currentTranspose > 0) return '+$currentTranspose';
    return currentTranspose.toString();
  }
}
