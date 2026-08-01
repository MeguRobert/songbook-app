import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/notation.dart';
import '../../../data/models/song.dart';
import '../../../data/models/song_id.dart';
import '../../../data/models/verse.dart';
import '../../../domain/services/chord_sheet_exporter.dart';
import '../../../domain/services/chord_sheet_parser.dart';
import '../../../domain/services/musicxml_importer.dart';
import '../../../domain/services/photo_import_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/book_provider.dart';
import '../../providers/providers.dart';
import '../../providers/song_provider.dart';
import '../../../router/app_router.dart';
import '../song_view/widgets/chord_view.dart';
import '../song_view/widgets/sheet_music_view.dart';

/// Where a pending import came from.
///
/// A kind rather than a ready-made label, because the label has to be in the
/// language the screen is being read in *now*. Resolving it at import time
/// would freeze whichever language happened to be active when Parse was
/// pressed, and `initState` is the wrong place to reach for an inherited widget
/// anyway.
enum _ImportSource { savedSong, pastedText, file, photo }

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
  final _ImportSource source;

  /// The picked file's name, when [source] is [_ImportSource.file].
  final String? fileName;

  const _PendingImport({
    required this.verses,
    required this.source,
    this.fileName,
    this.notation,
    this.title,
    this.key,
    this.timeSignature,
    this.warnings = const [],
  });

  String sourceLabel(AppLocalizations l10n) => switch (source) {
        _ImportSource.savedSong => l10n.importSourceSaved,
        _ImportSource.pastedText => l10n.importSourcePasted,
        // A file name is the same in every language; the fallback only fires if
        // the picker ever returns a file with no name.
        _ImportSource.file => fileName ?? l10n.importMusicXmlFile,
        _ImportSource.photo => fileName ?? l10n.importSourcePhoto,
      };
}

/// Adds a song by pasting a chord sheet or opening a MusicXML file — or
/// corrects one that was already saved, when [editingId] names it.
///
/// The songs being added are overwhelmingly ones that already exist — from a
/// chord site, a MuseScore file, or a book that was never digitised — so
/// importing is the fast path, not typing. Whatever an importer produces is
/// shown immediately, rendered with the same widgets the real song view uses
/// ([SheetMusicView] when there is notation, [ChordView] otherwise): what is
/// approved here is exactly what will be displayed later.
///
/// Editing is the same screen rather than a second one because it is the same
/// question — *is this right?* — asked about content that happens to be stored
/// already. Every import is a transcription and every transcription is lossy,
/// so the correction surface is where a wrong title, a mis-numbered song or a
/// chord line the parser mangled all get fixed. A separate "edit details" form
/// would have covered the first two and left the third, the one that actually
/// needs the preview, with nowhere to go.
class ImportSongScreen extends ConsumerStatefulWidget {
  /// The user song being corrected, or null when adding a new one.
  final SongId? editingId;

  const ImportSongScreen({super.key, this.editingId});

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

  /// Whether the "More ways to add" expander is open.
  ///
  /// Collapsed on open, and not remembered between visits: pasting is the path
  /// almost every import takes, and a picker left expanded would compete with
  /// the box the user is about to type into on every subsequent visit too.
  bool _showMoreWays = false;

  /// The song being corrected, read once when the screen opens. Null when
  /// adding, and also when [ImportSongScreen.editingId] names a song that is no
  /// longer stored (deleted from another route since the link was made).
  Song? _editing;

  /// [_editing]'s content as an import result, so the shared review surface
  /// below needs no special case for "already saved".
  _PendingImport? _savedPending;

  /// Once the title has been touched, re-importing must not overwrite it: an
  /// importer's guess is a starting point, and silently reverting a correction
  /// is worse than not guessing at all.
  bool _titleEdited = false;

  bool get _isEditing => widget.editingId != null;

  @override
  void initState() {
    super.initState();
    final id = widget.editingId;
    if (id == null) return;
    // Synchronous on purpose: user songs live in local storage, so the whole
    // form can be prefilled on the first frame instead of flashing empty.
    final existing = ref.read(userSongRepositoryProvider).getById(id);
    if (existing == null) return; // reported by _blockers
    _editing = existing;
    _savedPending = _PendingImport(
      verses: existing.verses,
      notation: existing.notation,
      title: existing.title,
      key: existing.originalKey,
      timeSignature: existing.timeSignature,
      source: _ImportSource.savedSong,
    );
    _pending = _savedPending;
    _key = existing.originalKey;
    _titleController.text = existing.title;
    // The saved title is the user's, not a guess, so a later re-parse must not
    // overwrite it.
    _titleEdited = true;
    _numberController.text = existing.number == 0 ? '' : '${existing.number}';
    _bookController.text = existing.book ?? '';
    // The words and chords, as editable text.
    //
    // This box used to open empty when editing, so correcting a lyric meant
    // selecting the song out of the preview below and pasting it back — which
    // arrives as one unbroken line, because a cross-widget selection carries no
    // line breaks. ChordPro is what the parser below already reads, so the round
    // trip is exact: change a word, press Parse, and the preview updates.
    _sheetController.text = const ChordSheetExporter().toChordPro(existing);
  }

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
      source: _ImportSource.pastedText,
    ));
  }

  /// Photographs a song, sends it to the configured service, and treats the
  /// answer as any other import.
  ///
  /// The returned ChordPro is also written into the paste box, not just the
  /// preview. Extraction is a transcription like every other source here, so it
  /// is wrong somewhere — and the box is where a wrong word gets fixed. Leaving
  /// it empty would have made a photo the one import you could see but not
  /// correct.
  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(photoImportServiceProvider);
    if (service == null) {
      // Not an error: pointing the app at a service is a setup step, and
      // saying where to do it beats a dead button.
      setState(() => _fileError = l10n.importPhotoNotConfigured);
      return;
    }

    setState(() {
      _picking = true;
      _fileError = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return; // cancelled
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _fileError = l10n.importErrorUnreadable(file.name));
        return;
      }

      final payload = await service.extract(bytes, fileName: file.name);
      switch (payload) {
        case ChordProPayload(text: final text, warnings: final warnings):
          final parsed = _parser.parse(text);
          _sheetController.text = text;
          _accept(_PendingImport(
            verses: parsed.verses,
            title: parsed.title,
            key: parsed.key,
            // Both sets: the service reports what it could not read, the
            // parser what it could not classify. Either can be the reason a
            // line looks wrong.
            warnings: [...warnings, ...parsed.warnings],
            source: _ImportSource.photo,
            fileName: file.name,
          ));
        case MusicXmlPayload(xml: final xml, warnings: final warnings):
          // A service that can engrave answers with this instead; the app
          // already knows how to read it.
          final result = _musicXml.importXml(xml);
          _accept(_PendingImport(
            verses: result.verses,
            notation: result.notation,
            title: result.title,
            key: result.key,
            timeSignature: result.timeSignature,
            warnings: [...warnings, ...result.warnings],
            source: _ImportSource.photo,
            fileName: file.name,
          ));
      }
    } on PhotoImportException catch (e) {
      setState(() => _fileError = e.message);
    } on MusicXmlImportException catch (e) {
      setState(() => _fileError = e.message);
    } catch (e) {
      setState(() => _fileError = '$e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickMusicXmlFile() async {
    final l10n = AppLocalizations.of(context);
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
        setState(
            () => _fileError = l10n.importErrorNotMusicXml(file.name));
        return;
      }

      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _fileError = l10n.importErrorUnreadable(file.name));
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
        source: _ImportSource.file,
        fileName: file.name,
      ));
    } on MusicXmlImportException catch (e) {
      // Still English: the importer is a pure domain service and builds its own
      // messages. Giving it translations means structured codes rather than
      // prose, which is a bigger change than this pass. See the handoff.
      setState(() => _fileError = e.message);
    } catch (e) {
      // A malformed file must not take the screen down with it — the user
      // still has a pasted draft in progress they would otherwise lose.
      setState(() => _fileError = l10n.importErrorFailed('$e'));
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

  /// The draft as it will be stored. When adding there is no id yet — the
  /// repository assigns one.
  ///
  /// Built afresh from the form rather than `_editing.copyWith(...)`, because
  /// `copyWith` cannot express *clearing* a field: `book: null` falls through
  /// the `??` and keeps the old value, so emptying the songbook box would
  /// silently do nothing. The cost of building afresh is that anything the form
  /// does not show has to be carried over explicitly — see below.
  Song? get _draft {
    final pending = _pending;
    if (pending == null || !_hasContent(pending)) return null;
    final title = _titleController.text.trim();
    if (title.isEmpty) return null;
    final book = _bookController.text.trim();
    final editing = _editing;
    return Song(
      number: int.tryParse(_numberController.text.trim()) ?? 0,
      title: title,
      originalKey: _key ?? pending.notation?.originalKey ?? 'C',
      timeSignature: pending.timeSignature,
      notation: pending.notation,
      verses: pending.verses,
      book: book.isEmpty ? null : book,
      // Carried over, not re-derived. The id above all: reassigning it would
      // orphan every favourite, setlist entry, tag override and per-song
      // setting pointing at this song. Tags are edited in the song view's tag
      // sheet and have no field here, so rebuilding without them would wipe
      // them on every correction.
      explicitId: editing?.explicitId,
      tags: editing?.tags ?? const [],
      reference: editing?.reference,
      origin: editing?.origin,
      tune: editing?.tune,
      sheetMusic: editing?.sheetMusic,
    );
  }

  List<String> _blockersIn(AppLocalizations l10n) {
    if (_isEditing && _editing == null) {
      return [l10n.importBlockerDeleted];
    }
    final pending = _pending;
    if (pending == null) {
      return [l10n.importBlockerNothing];
    }
    if (!_hasContent(pending)) {
      return [l10n.importBlockerEmpty];
    }
    if (_titleController.text.trim().isEmpty) {
      return [l10n.importBlockerNoTitle];
    }
    return const [];
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);

    if (_isEditing) {
      await ref.read(userSongsProvider.notifier).update(draft);
      if (!mounted) return;
      setState(() => _saving = false);
      // Back to the song being corrected. Pushing it instead would stack a
      // second copy of the same song on top of the one we came from.
      context.pop();
      return;
    }

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
    final l10n = AppLocalizations.of(context);
    final pending = _pending;
    final draft = _draft;
    final blockers = _blockersIn(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.menuEditSong : l10n.addSong),
        actions: [
          TextButton(
            onPressed: blockers.isEmpty && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.actionSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
              _isEditing
                  ? l10n.importSectionReplace
                  : l10n.importSectionPaste,
              style: _sectionStyle(theme)),
          const SizedBox(height: 8),
          TextField(
            controller: _sheetController,
            maxLines: 8,
            minLines: 4,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
              hintText: l10n.importPasteHint,
            ),
            // Always setState, not just when clearing a previous parse: the
            // Parse button's enabled state depends on this field being
            // non-empty, so skipping the rebuild left it greyed out after the
            // very first paste.
            //
            // Falls back to the saved content when editing, not to nothing:
            // typing here is an *offer* to replace, and until Parse is pressed
            // the song still has its stored words. Resetting to null would have
            // blanked the preview and disabled Save on the first keystroke.
            onChanged: (_) => setState(() => _pending = _savedPending),
          ),
          const SizedBox(height: 8),
          // Parse alone on its row. It used to share the row with the file
          // picker, which gave equal billing to a path that needs a score
          // exported from MuseScore first — while pasting a chord sheet is what
          // actually happens most of the time.
          Row(
            children: [
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed:
                    _sheetController.text.trim().isEmpty ? null : _parsePasted,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(l10n.importParse),
              ),
            ],
          ),

          // The file path, demoted but not hidden: it is the only one that
          // produces engraved notation, and the landing point for a photo
          // pipeline later, so the expander says what it is for rather than
          // just tucking it away.
          //
          // A failed pick needs no special case — the button is inside here, so
          // this is necessarily open when the error appears below.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _showMoreWays = !_showMoreWays),
              icon: Icon(_showMoreWays
                  ? Icons.expand_less
                  : Icons.expand_more),
              label: Text(l10n.importMoreWays),
            ),
          ),
          // Each path with its own explanation directly under it, rather than
          // one line of prose over both. `importMusicXmlHint` says "export
          // from MuseScore first", which was written when the file picker was
          // alone in here — read as a heading over the Photo button too, it
          // claims a requirement that photos do not have.
          if (_showMoreWays) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The only path that yields real notation, and the lyrics
                    // come free from <lyric> elements.
                    OutlinedButton.icon(
                      onPressed: _picking ? null : _pickMusicXmlFile,
                      icon: _picking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.piano_outlined),
                      label: Text(l10n.importMusicXmlFile),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: Text(
                        l10n.importMusicXmlHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _picking ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l10n.importPhoto),
                    ),
                  ],
                ),
              ),
            ),
          ],

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
                Text(l10n.importSectionDetails, style: _sectionStyle(theme)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.importFromSource(pending.sourceLabel(l10n)),
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
              decoration: InputDecoration(
                labelText: l10n.importTitleField,
                border: const OutlineInputBorder(),
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
                    decoration: InputDecoration(
                      labelText: l10n.importNumberField,
                      border: const OutlineInputBorder(),
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
                    ? l10n.importKeyFromFile(_key!)
                    : l10n.importKeyGuessed(_key!),
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
                Text(l10n.importSectionPreview, style: _sectionStyle(theme)),
                const SizedBox(width: 8),
                Text(
                  [
                    if (pending.verses.isNotEmpty)
                      l10n.importVerseCount(pending.verses.length),
                    if (pending.notation != null)
                      l10n.importBarCount(pending.notation!.verses
                          .fold<int>(0, (n, v) => n + v.measures.length)),
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
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).importBookField,
            border: const OutlineInputBorder(),
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
      title: AppLocalizations.of(context).importWarningsTitle(warnings.length),
      // The warnings themselves are still English: they are built by the pure
      // parser/importer services, which have no access to a BuildContext.
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
