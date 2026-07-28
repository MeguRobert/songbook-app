import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/notation.dart';
import '../../../data/models/song.dart';
import '../../../data/models/verse.dart';
import '../../../domain/services/chord_sheet_parser.dart';
import '../../../domain/services/musicxml_importer.dart';
import '../../providers/book_provider.dart';
import '../../providers/song_provider.dart';
import '../../../router/app_router.dart';
import '../song_view/widgets/chord_view.dart';
import '../song_view/widgets/sheet_music_view.dart';

/// What an importer produced, whatever the source.
///
/// Both paths converge here so the review surface below is written once. Adding
/// a third source (a photo) means producing one of these, not another screen.
class _PendingImport {
  final List<Verse> verses;

  /// Only MusicXML yields notation; a pasted chord sheet never does.
  final SongNotation? notation;

  final String? title;
  final String? key;
  final String? timeSignature;
  final List<String> warnings;

  /// Shown so it is obvious which source produced what is on screen.
  final String sourceLabel;

  const _PendingImport({
    required this.verses,
    required this.sourceLabel,
    this.notation,
    this.title,
    this.key,
    this.timeSignature,
    this.warnings = const [],
  });
}

/// Adds a song by pasting a chord sheet or opening a MusicXML file.
///
/// The songs being added are overwhelmingly ones that already exist — from a
/// chord site, a MuseScore file, or a book that was never digitised — so
/// importing is the fast path, not typing. Whatever an importer produces is
/// shown immediately, rendered with the same widgets the real song view uses
/// ([SheetMusicView] when there is notation, [ChordView] otherwise): what is
/// approved here is exactly what will be displayed later.
class ImportSongScreen extends ConsumerStatefulWidget {
  const ImportSongScreen({super.key});

  @override
  ConsumerState<ImportSongScreen> createState() => _ImportSongScreenState();
}

class _ImportSongScreenState extends ConsumerState<ImportSongScreen> {
  static const _parser = ChordSheetParser();
  static const _musicXml = MusicXmlImporter();

  final _sheetController = TextEditingController();
  final _titleController = TextEditingController();
  final _numberController = TextEditingController();
  final _bookController = TextEditingController();

  _PendingImport? _pending;
  String? _key;
  bool _saving = false;
  bool _picking = false;
  String? _fileError;

  /// Once the title has been touched, re-importing must not overwrite it: an
  /// importer's guess is a starting point, and silently reverting a correction
  /// is worse than not guessing at all.
  bool _titleEdited = false;

  @override
  void dispose() {
    _sheetController.dispose();
    _titleController.dispose();
    _numberController.dispose();
    _bookController.dispose();
    super.dispose();
  }

  void _accept(_PendingImport pending) {
    setState(() {
      _pending = pending;
      _fileError = null;
      _key = pending.key ?? _firstChord(pending.verses);
      if (!_titleEdited && (pending.title ?? '').isNotEmpty) {
        _titleController.text = pending.title!;
      }
    });
  }

  void _parsePasted() {
    final result = _parser.parse(_sheetController.text);
    _accept(_PendingImport(
      verses: result.verses,
      title: result.title,
      key: result.key,
      warnings: result.warnings,
      sourceLabel: 'pasted text',
    ));
  }

  Future<void> _pickMusicXmlFile() async {
    setState(() {
      _picking = true;
      _fileError = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xml', 'musicxml', 'mxl'],
        // Required on web, and avoids a second read on mobile.
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return; // cancelled
      final file = picked.files.single;

      final name = file.name.toLowerCase();
      if (!name.endsWith('.xml') &&
          !name.endsWith('.musicxml') &&
          !name.endsWith('.mxl')) {
        setState(() => _fileError =
            '${file.name} is not a MusicXML file. Expected .xml, .musicxml '
            'or .mxl — a MuseScore .mscz has to be exported first.');
        return;
      }

      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _fileError = 'Could not read ${file.name}.');
        return;
      }

      // .mxl is zipped MusicXML rather than a separate format.
      final isCompressed = name.endsWith('.mxl');
      final result = isCompressed
          ? _musicXml.importCompressed(bytes)
          : _musicXml.importXml(utf8.decode(bytes, allowMalformed: true));

      _accept(_PendingImport(
        verses: result.verses,
        notation: result.notation,
        title: result.title,
        key: result.key,
        timeSignature: result.timeSignature,
        warnings: result.warnings,
        sourceLabel: file.name,
      ));
    } on MusicXmlImportException catch (e) {
      setState(() => _fileError = e.message);
    } catch (e) {
      // A malformed file must not take the screen down with it — the user
      // still has a pasted draft in progress they would otherwise lose.
      setState(() => _fileError = 'Could not import that file: $e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// The key, guessed from the first chord when the source declares none.
  String? _firstChord(List<Verse> verses) {
    for (final verse in verses) {
      for (final line in verse.lines) {
        if (line.chords.isNotEmpty) return line.chords.first.chord;
      }
    }
    return null;
  }

  /// Whether [pending] carries anything worth saving.
  ///
  /// Verses OR notation. An engraved score commonly has no `<lyric>` elements
  /// at all — its syllables hang off the individual beats — so requiring
  /// verses rejected exactly the files the MusicXML path exists to import.
  bool _hasContent(_PendingImport pending) =>
      pending.verses.isNotEmpty || pending.notation != null;

  /// The draft as it will be stored. No id yet — the repository assigns one.
  Song? get _draft {
    final pending = _pending;
    if (pending == null || !_hasContent(pending)) return null;
    final title = _titleController.text.trim();
    if (title.isEmpty) return null;
    final book = _bookController.text.trim();
    return Song(
      number: int.tryParse(_numberController.text.trim()) ?? 0,
      title: title,
      originalKey: _key ?? pending.notation?.originalKey ?? 'C',
      timeSignature: pending.timeSignature,
      notation: pending.notation,
      verses: pending.verses,
      book: book.isEmpty ? null : book,
    );
  }

  List<String> get _blockers {
    final pending = _pending;
    if (pending == null) {
      return const ['Paste a song or open a MusicXML file.'];
    }
    if (!_hasContent(pending)) {
      return const ['No lyrics or notation found in that source.'];
    }
    if (_titleController.text.trim().isEmpty) {
      return const ['Give the song a title.'];
    }
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
    final pending = _pending;
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
                    width: 16,
                    height: 16,
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
            onChanged: (_) => setState(() => _pending = null),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // The only path that yields real notation, and the lyrics come
              // free from <lyric> elements.
              OutlinedButton.icon(
                onPressed: _picking ? null : _pickMusicXmlFile,
                icon: _picking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.piano_outlined),
                label: const Text('MusicXML file'),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed:
                    _sheetController.text.trim().isEmpty ? null : _parsePasted,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Parse'),
              ),
            ],
          ),

          if (_fileError != null) ...[
            const SizedBox(height: 12),
            _Notice(
              text: _fileError!,
              icon: Icons.error_outline,
              background: theme.colorScheme.errorContainer,
              foreground: theme.colorScheme.onErrorContainer,
            ),
          ],

          if (pending != null) ...[
            const Divider(height: 32),
            Row(
              children: [
                Text('DETAILS', style: _sectionStyle(theme)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'from ${pending.sourceLabel}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
                Expanded(
                  child: _BookField(
                    controller: _bookController,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_key != null) ...[
              const SizedBox(height: 8),
              Text(
                pending.key != null
                    ? 'Key $_key, from the file.'
                    : 'Key guessed as $_key from the first chord.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            if (pending.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Warnings(warnings: pending.warnings),
            ],

            const Divider(height: 32),
            Row(
              children: [
                Text('PREVIEW', style: _sectionStyle(theme)),
                const SizedBox(width: 8),
                Text(
                  [
                    if (pending.verses.isNotEmpty)
                      '${pending.verses.length} verse'
                          '${pending.verses.length == 1 ? '' : 's'}',
                    if (pending.notation != null)
                      '${pending.notation!.verses.fold<int>(0, (n, v) => n + v.measures.length)} bars',
                  ].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (draft != null)
              // The real view widgets, chosen the same way the song view
              // chooses them, so this is not an approximation that can drift.
              SizedBox(
                height: 340,
                child: draft.hasNotation
                    ? SheetMusicView(
                        song: draft, transpose: 0, showChords: true)
                    : ChordView(song: draft, transpose: 0),
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

/// Importer warnings. Shown rather than swallowed: every one marks a place the
/// importer guessed or dropped something, and that is far easier to judge here
/// than after the song is saved.
class _Warnings extends StatelessWidget {
  final List<String> warnings;

  const _Warnings({required this.warnings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Notice(
      icon: Icons.info_outline,
      background: theme.colorScheme.secondaryContainer,
      foreground: theme.colorScheme.onSecondaryContainer,
      title: 'Check ${warnings.length == 1 ? 'this' : 'these'} '
          '${warnings.length == 1 ? 'line' : 'lines'}',
      text: warnings.map((w) => '• $w').join('\n'),
    );
  }
}

/// A coloured info/error block.
class _Notice extends StatelessWidget {
  final String text;
  final String? title;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _Notice({
    required this.text,
    required this.icon,
    required this.background,
    required this.foreground,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title ?? text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: 6),
            Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ],
        ],
      ),
    );
  }
}
