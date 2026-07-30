import '../../../../data/models/song_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/tag_provider.dart';

/// Bottom sheet for editing a song's tags (add / remove), persisted via
/// [tagOverridesProvider]. Opened from the song view.
///
/// Keeps a local working copy for snappy editing; commits on "Save".
class TagEditorSheet extends ConsumerStatefulWidget {
  final SongId songId;
  final List<String> currentTags;

  const TagEditorSheet({
    required this.songId,
    required this.currentTags,
    super.key,
  });

  @override
  ConsumerState<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends ConsumerState<TagEditorSheet> {
  late List<String> _tags;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = List<String>.from(widget.currentTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final exists = _tags.any((t) => t.toLowerCase() == trimmed.toLowerCase());
    if (!exists) {
      setState(() => _tags.add(trimmed));
    }
    _controller.clear();
  }

  void _removeTag(String tag) {
    setState(() =>
        _tags.removeWhere((t) => t.toLowerCase() == tag.toLowerCase()));
  }

  Future<void> _save() async {
    await ref
        .read(tagOverridesProvider.notifier)
        .setTags(widget.songId, _tags);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _resetToDefault() async {
    await ref
        .read(tagOverridesProvider.notifier)
        .clearOverride(widget.songId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Suggestions: existing tags across the library not already applied.
    final allTags = ref.watch(tagsProvider).maybeWhen(
          data: (tags) => tags.map((t) => t.name).toList(),
          orElse: () => const <String>[],
        );
    final suggestions = allTags
        .where((t) => !_tags.any((s) => s.toLowerCase() == t.toLowerCase()))
        .take(12)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sell),
              const SizedBox(width: 8),
              Text(l10n.menuEditTags, style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          if (_tags.isEmpty)
            Text(
              l10n.tagsNoneYetAddOne,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _tags
                  .map((tag) => InputChip(
                        label: Text(tag),
                        onDeleted: () => _removeTag(tag),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.tagAddLabel,
              hintText: l10n.tagAddHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.tagAddTooltip,
                onPressed: () => _addTag(_controller.text),
              ),
            ),
            onSubmitted: _addTag,
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.tagSuggestions, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: suggestions
                  .map((tag) => ActionChip(
                        label: Text(tag),
                        avatar: const Icon(Icons.add, size: 18),
                        onPressed: () => _addTag(tag),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: _resetToDefault,
                child: Text(l10n.tagResetToDefault),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(l10n.actionSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
