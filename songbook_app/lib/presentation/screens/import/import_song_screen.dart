import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/song.dart';
import '../../../domain/services/chord_sheet_parser.dart';
import '../../providers/book_provider.dart';
import '../../providers/song_provider.dart';
import '../../../router/app_router.dart';
import '../song_view/widgets/chord_view.dart';

/// Adds a song by pasting a chord sheet.
///
/// The songs being added are overwhelmingly ones that already exist — from a
/// chord site, or a book that was never digitised — so pasting is the fast
/// path, not typing. What the parser produces is shown immediately, rendered
/// with [ChordView], the same widget the real song view uses: what is approved
/// here is exactly what will be displayed later, rather than an approximation
/// that can drift from it.
class ImportSongScreen extends ConsumerStatefulWidget {
  const ImportSongScreen({super.key});

  @override
  ConsumerState<ImportSongScreen> createState() => _ImportSongScreenState();
}

class _ImportSongScreenState extends ConsumerState<ImportSongScreen> {
  static const _parser = ChordSheetParser();

  final _sheetController = TextEditingController();
  final _titleController = TextEditingController();
  final _numberController = TextEditingController();
  final _bookController = TextEditingController();

  ParsedChordSheet? _parsed;
  String? _key;
  bool _saving = false;

  /// Whether the title/number/book fields have been touched. Once they have,
  /// re-parsing must not overwrite them: the parser's guesses are a starting
  /// point, and silently reverting a correction is worse than not guessing.
  bool _titleEdited = false;

  @override
  void dispose() {
    _sheetController.dispose();
    _titleController.dispose();
    _numberController.dispose();
    _bookController.dispose();
    super.dispose();
  }

  void _parse() {
    final result = _parser.parse(_sheetController.text);
    setState(() {
      _parsed = result;
      _key = result.key ?? _firstChord(result);
      if (!_titleEdited && (result.title ?? '').isNotEmpty) {
        _titleController.text = result.title!;
      }
    });
  }

  /// The song's key, guessed from the first chord when no `{key:}` directive
  /// says otherwise. A guess, and labelled as one in the UI.
  String? _firstChord(ParsedChordSheet sheet) {
    for (final verse in sheet.verses) {
      for (final line in verse.lines) {
        if (line.chords.isNotEmpty) return line.chords.first.chord;
      }
    }
    return null;
  }

  /// The draft as it will be stored. No id yet — the repository assigns one.
  Song? get _draft {
    final parsed = _parsed;
    if (parsed == null || parsed.verses.isEmpty) return null;
    final title = _titleController.text.trim();
    if (title.isEmpty) return null;
    final book = _bookController.text.trim();
    return Song(
      number: int.tryParse(_numberController.text.trim()) ?? 0,
      title: title,
      originalKey: _key ?? 'C',
      verses: parsed.verses,
      book: book.isEmpty ? null : book,
    );
  }

  /// Reasons the draft cannot be saved yet, in the order they should be fixed.
  List<String> get _blockers {
    final parsed = _parsed;
    if (parsed == null) return const ['Paste a song, then tap Parse.'];
    if (parsed.verses.isEmpty) return const ['No verses found in that text.'];
    if (_titleController.text.trim().isEmpty) return const ['Give the song a title.'];
    return const [];
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    final stored = await ref.read(userSongsProvider.notifier).add(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    // Straight into the song it just created: the point of importing is to
    // use it, and this also proves the round-trip worked. By id, so it opens
    // THIS song even when a hymnal song shares its number.
    context.pushReplacement(AppRoutes.songPath(stored.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parsed;
    final draft = _draft;
    final blockers = _blockers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a song'),
        actions: [
          TextButton(
            onPressed: blockers.isEmpty && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('PASTE THE SONG', style: _sectionStyle(theme)),
          const SizedBox(height: 8),
          TextField(
            controller: _sheetController,
            maxLines: 8,
            minLines: 4,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              hintText: 'G       C\n'
                  'Az Úrra bízom életem\n'
                  '\n'
                  'or [G]Az Úrra [C]bízom életem',
            ),
            // Always setState, not just when clearing a previous parse: the
            // Parse button's enabled state depends on this field being
            // non-empty, so skipping the rebuild left it greyed out after the
            // very first paste.
            onChanged: (_) => setState(() => _parsed = null),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed:
                  _sheetController.text.trim().isEmpty ? null : _parse,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Parse'),
            ),
          ),

          if (parsed != null) ...[
            const Divider(height: 32),
            Text('DETAILS', style: _sectionStyle(theme)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _titleEdited = true),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _numberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Number',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _BookField(controller: _bookController,
                    onChanged: () => setState(() {}))),
              ],
            ),
            if (_key != null) ...[
              const SizedBox(height: 8),
              Text(
                'Key guessed as $_key from the first chord.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            if (parsed.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Warnings(warnings: parsed.warnings),
            ],

            const Divider(height: 32),
            Row(
              children: [
                Text('PREVIEW', style: _sectionStyle(theme)),
                const SizedBox(width: 8),
                Text(
                  '${parsed.verses.length} verse'
                  '${parsed.verses.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (draft != null)
              // Rendered with the real ChordView so this is not an
              // approximation of the song view — it IS the song view.
              SizedBox(
                height: 320,
                child: ChordView(song: draft, transpose: 0),
              )
            else
              Text(
                blockers.first,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  TextStyle? _sectionStyle(ThemeData theme) =>
      theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      );
}

/// Book name with completions from the books already in the catalogue, so a
/// second song lands in the same songbook as the first instead of creating a
/// near-duplicate that differs by a character.
class _BookField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _BookField({required this.controller, required this.onChanged});

  @override
  ConsumerState<_BookField> createState() => _BookFieldState();
}

class _BookFieldState extends ConsumerState<_BookField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider).maybeWhen(
          data: (list) => list.map((b) => b.name).toList(),
          orElse: () => const <String>[],
        );

    // RawAutocomplete, so the caller's controller IS the field's controller.
    // The plain Autocomplete owns its own, which forced mirroring the two —
    // and the only hook for that is fieldViewBuilder, which runs on every
    // build. That attached a fresh listener per rebuild, each calling
    // setState, so the next rebuild called setState *during* build and threw.
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return books;
        return books.where((b) => b.toLowerCase().contains(query));
      },
      onSelected: (_) => widget.onChanged(),
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Songbook',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => widget.onChanged(),
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 260),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final option in options)
                    ListTile(
                      dense: true,
                      title: Text(option),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Parser warnings. Shown rather than swallowed: every one of them marks a
/// place the parser guessed, and the guess is easier to correct here than
/// after the song is saved.
class _Warnings extends StatelessWidget {
  final List<String> warnings;

  const _Warnings({required this.warnings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Text(
                'Check these ${warnings.length == 1 ? 'line' : 'lines'}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• $warning',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
