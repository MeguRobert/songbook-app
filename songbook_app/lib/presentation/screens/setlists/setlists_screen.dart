import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/setlist.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../providers/setlist_provider.dart';
import '../../widgets/content_pane.dart';

/// Screen listing all setlists, with create / rename / delete.
class SetlistsScreen extends ConsumerWidget {
  const SetlistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final setlists = ref.watch(setlistsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSetlists)),
      body: setlists.isEmpty
          ? _EmptyState(onCreate: () => _showCreateDialog(context, ref))
          : ContentPane.list(
              child: ListView.builder(
                itemCount: setlists.length,
                itemBuilder: (context, index) {
                  final setlist = setlists[index];
                  return ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(setlist.name),
                    subtitle: Text(l10n.setlistSongCount(setlist.length)),
                    onTap: () =>
                        context.push(AppRoutes.setlistDetailPath(setlist.id)),
                    trailing: PopupMenuButton<String>(
                      tooltip: l10n.setlistOptions,
                      onSelected: (value) {
                        if (value == 'rename') {
                          _showRenameDialog(context, ref, setlist);
                        } else if (value == 'delete') {
                          _showDeleteDialog(context, ref, setlist);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'rename', child: Text(l10n.actionRename)),
                        PopupMenuItem(
                            value: 'delete', child: Text(l10n.actionDelete)),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        tooltip: l10n.setlistNew,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(
      context,
      title: AppLocalizations.of(context).setlistNew,
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(setlistsProvider.notifier).create(name.trim());
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final name = await _promptForName(
      context,
      title: AppLocalizations.of(context).setlistRenameTitle,
      initialValue: setlist.name,
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(setlistsProvider.notifier).rename(setlist.id, name.trim());
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.setlistDeleteTitle),
        content: Text(l10n.setlistDeleteBody(setlist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(setlistsProvider.notifier).delete(setlist.id);
    }
  }

  /// Shows a single-field dialog and returns the entered text (or null if
  /// cancelled).
  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
    String initialValue = '',
  }) {
    // The controller lives inside _NamePromptDialog so it is disposed by that
    // widget's own State. Disposing it when showDialog's future completes is
    // too early: the future resolves on pop() while the dialog is still
    // animating out and rebuilding its TextField.
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _NamePromptDialog(title: title, initialValue: initialValue),
    );
  }
}

/// Empty state shown when there are no setlists yet.
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            l10n.setlistsEmpty,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setlistsEmptyHint,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(l10n.setlistNew),
          ),
        ],
      ),
    );
  }
}

/// Single-text-field dialog that owns its [TextEditingController].
///
/// Stateful so the controller is disposed by this widget's State, after the
/// dialog route is gone. Creating it in the caller and disposing on the
/// showDialog future is a use-after-dispose: the future completes at pop()
/// while the dialog is still animating out and rebuilding the TextField.
class _NamePromptDialog extends StatefulWidget {
  final String title;
  final String initialValue;

  const _NamePromptDialog({required this.title, required this.initialValue});

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.setlistNameHint,
          labelText: l10n.setlistNameLabel,
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
