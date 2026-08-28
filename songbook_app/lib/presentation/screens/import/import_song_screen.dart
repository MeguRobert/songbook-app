import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/notation.dart';
import '../../../data/models/song.dart';
import '../../../data/models/song_id.dart';
import '../../../data/models/verse.dart';
import '../../../domain/services/chord_carry.dart';
import '../../../domain/services/chord_sheet_exporter.dart';
import '../../../domain/services/chord_sheet_parser.dart';
import '../../../domain/services/import_notice.dart';
import '../../../domain/services/musicxml_importer.dart';
import '../../../domain/services/photo_import_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../l10n/import_notice_text.dart';
import '../../providers/book_provider.dart';
import '../../providers/providers.dart';
import '../../providers/song_provider.dart';
import '../../../router/app_router.dart';
import '../../widgets/content_pane.dart';
import '../../widgets/import/line_list.dart';
import '../../widgets/import/photo_pane.dart';
import '../../widgets/import/review_panes.dart';
import '../song_view/widgets/chord_view.dart';
import '../song_view/widgets/sheet_music_view.dart';

/// Where a pending import came from.
///
/// A kind rather than a ready-made label, because the label has to be in the
/// language the screen is being read in *now*. Resolving it at import time
/// would freeze whichever language happened to be active when Parse was
/// pressed, and `initState` is the wrong place to reach for an inherited widget
/// anyway.
enum _ImportSource { savedSong, pastedText, photo }

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

  /// What the importer or parser found, as codes. Turned into words at the point
  /// of display, so they come out in the language the screen is being read in
  /// now — the same reason [source] is a kind rather than a ready-made label.
  final List<ImportNotice> warnings;

  /// Shown so it is obvious which source produced what is on screen.
  final _ImportSource source;

  /// The picked photograph's name, when [source] is [_ImportSource.photo].
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

  /// A copy carrying [verses] instead, everything else unchanged.
  _PendingImport withVerses(List<Verse> verses) => _PendingImport(
        verses: verses,
        source: source,
        fileName: fileName,
        notation: notation,
        title: title,
        key: key,
        timeSignature: timeSignature,
        warnings: warnings,
      );

  String sourceLabel(AppLocalizations l10n) => switch (source) {
        _ImportSource.savedSong => l10n.importSourceSaved,
        _ImportSource.pastedText => l10n.importSourcePasted,
        // A file name is the same in every language; the fallback only fires
        // if the picker ever returns a file with no name.
        _ImportSource.photo => fileName ?? l10n.importSourcePhoto,
      };
}

/// Adds a song by pasting a chord sheet or photographing a page — or corrects
/// one that was already saved, when [editingId] names it.
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

  /// Still needed, though the file picker is gone: the sheet-music photo path
  /// comes back as MusicXML from the engraving service, and this is what reads
  /// it. Only the *upload* button was removed - the notation editor imports
  /// files, this screen photographs pages.
  static const _musicXml = MusicXmlImporter();
  static const _chordCarry = ChordCarry();

  final _sheetController = TextEditingController();
  final _titleController = TextEditingController();
  final _numberController = TextEditingController();
  final _bookController = TextEditingController();

  _PendingImport? _pending;
  String? _key;
  bool _saving = false;
  bool _picking = false;

  /// Whether the photo about to be taken is of engraved notation.
  ///
  /// A question rather than a guess, because the two engines answer completely
  /// different things and only the person holding the camera can see which kind
  /// of page it is. Off by default: a hymnal page is words with chord names
  /// above them far more often than it is a printed score.
  bool _photoHasSheetMusic = false;

  /// Whether a photo is being read right now, as opposed to a file being
  /// picked. Both disable the buttons; only this one has something to say while
  /// it waits, and the wait can be a minute.
  bool _readingPhoto = false;

  String? _fileError;

  /// The photograph that was read, kept so it can be shown beside the preview.
  ///
  /// It used to be dropped the moment the reader had finished with it, which
  /// left the review surface with nothing to check the reading against - the one
  /// thing the gold editor does that this screen did not. Held in memory only:
  /// nothing about a photograph is stored, and it goes when the screen does.
  Uint8List? _photoBytes;
  String? _photoName;

  /// Which lines the person reviewing overruled the parser about.
  ///
  /// Sparse: an entry exists only where somebody disagreed, so empty means the
  /// parser decides everything - the behaviour that shipped before the line list
  /// existed. Cleared on every Parse, because an override belongs to the text it
  /// was made against and line 7 is a different line after a re-read.
  LineKinds _kinds = const LineKinds.none();

  /// The song being corrected, read once when the screen opens. Null when
  /// adding, and also when [ImportSongScreen.editingId] names a song that is no
  /// longer stored (deleted from another route since the link was made).
  Song? _editing;

  /// [_editing]'s content as an import result, so the shared review surface
  /// below needs no special case for "already saved".
  _PendingImport? _savedPending;

  /// The exact text [_pending] was parsed from.
  ///
  /// The box and the draft can disagree, because typing does not re-parse — and
  /// when they disagree it is the box that the person is looking at. Saving
  /// compares the two and re-reads if they have drifted apart, which is what
  /// makes Save mean "save what is on screen".
  ///
  /// Seeded in [initState] when editing, so an edit screen that has been opened
  /// and not touched is not treated as dirty and re-parsed for nothing.
  String _parsedText = '';

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
    _parsedText = _sheetController.text;
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _titleController.dispose();
    _numberController.dispose();
    _bookController.dispose();
    super.dispose();
  }

  /// A songbook number worn at the front of a title — `147. Isten fénye`.
  ///
  /// A photographed page carries it because the page prints it that way, and
  /// other sources tend to as well. Left alone it became part of the title, so
  /// the song sorted under its first letter and the number box stayed empty.
  ///
  /// The separator is optional, because a recogniser reading a photographed
  /// page drops the printed full stop often enough to matter — `149 Mondd, ki a
  /// dzsungel királya` has to split as surely as `149. Isten fénye` does. What
  /// follows the number must not be another digit, which is what keeps
  /// `10 000 angyal` intact: a run of digits followed by more digits is a
  /// quantity, not a hymn number.
  static final _numberedTitle =
      RegExp(r'^\s*(\d{1,4})\s*(?:[.):]\s*|\s+)(\D.*)$');

  void _accept(_PendingImport pending) {
    setState(() {
      // Every import lands here, and only imports do — a song opened for
      // editing is assigned straight to _pending in initState, so nothing
      // below can rewrite what is already stored.
      _pending = pending.withVerses(_chordCarry.carry(pending.verses));
      _fileError = null;
      _key = pending.key ?? _firstChord(pending.verses);

      var title = pending.title ?? '';
      final numbered = _numberedTitle.firstMatch(title);
      if (numbered != null) {
        title = numbered.group(2)!.trim();
        // Only into an empty box: a number already typed is the user's answer,
        // and a guess read off the page must not overwrite it.
        if (_numberController.text.trim().isEmpty) {
          _numberController.text = numbered.group(1)!;
        }
      }
      if (!_titleEdited && title.isNotEmpty) {
        _titleController.text = title;
      }
    });
  }

  void _parsePasted() {
    // A fresh read of fresh text: whatever was overruled was overruled about
    // the old lines.
    _kinds = const LineKinds.none();
    _reparse();
  }

  /// Re-reads the box with the current overrides and replaces the draft.
  ///
  /// One parse, feeding both the line list and the preview, so the badge on a
  /// row and the chords under it can never disagree about that row - the same
  /// discipline `_preview` and `_draft` already keep.
  void _reparse() {
    _parsedText = _sheetController.text;
    final result = _parser.parse(_sheetController.text, kinds: _kinds);
    _accept(_PendingImport(
      verses: result.verses,
      title: result.title,
      key: result.key,
      warnings: result.warnings,
      source: _ImportSource.pastedText,
    ));
  }

  /// Sets or clears one line's kind, and re-reads.
  void _setLineKind(int index, LineKind? kind) {
    _kinds = kind == null
        ? _kinds.withoutLine(index)
        : _kinds.withLine(index, kind);
    _reparse();
  }

  /// Replaces one token in one line, keeping every other column where it was.
  ///
  /// A chord's column IS its position, so only this row may move: the
  /// replacement is spliced at the token's own offset and the rest of the line
  /// follows it, which shifts the chords to its right by the difference in
  /// length and leaves every other line alone.
  ///
  /// The override on this line is CLEARED. Correcting the token is what makes
  /// the parser agree by itself, and an override that outlives its reason keeps
  /// a row claiming to be chords long after that stopped being true.
  void _replaceToken(int index, int column, String was, String now) {
    final lines = _sheetController.text.split(RegExp(r'\r\n|\r|\n'));
    if (index < 0 || index >= lines.length) return;
    final line = lines[index];
    if (column < 0 || column + was.length > line.length) return;
    if (line.substring(column, column + was.length) != was) return;
    lines[index] =
        line.replaceRange(column, column + was.length, now);
    _sheetController.text = lines.join('\n');
    _kinds = _kinds.withoutLine(index);
    _reparse();
  }

  /// Asks for a corrected spelling of [token], then applies it.
  Future<void> _editToken(int index, int column, String token) async {
    final replacement = await showDialog<String>(
      context: context,
      builder: (context) => _TokenDialog(token: token),
    );
    // An empty answer is a cancel: deleting a chord is what the words box is
    // for, and doing it from here would silently shorten the row.
    final trimmed = replacement?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == token) return;
    if (!mounted) return;
    _replaceToken(index, column, token, trimmed);
  }

  /// Photographs a song and treats the answer as any other import.
  ///
  /// Which engine reads it is [_photoHasSheetMusic]'s doing, because the two
  /// answer different questions: words with chord names above them are read
  /// here on the device in about two seconds and cost nothing, while engraved
  /// notation needs music recognition on a server, takes up to a minute, and
  /// returns no lyrics at all. Neither can stand in for the other, so the
  /// person holding the camera is asked which kind of page it is.
  ///
  /// The returned ChordPro is also written into the paste box, not just the
  /// preview. Extraction is a transcription like every other source here, so it
  /// is wrong somewhere — and the box is where a wrong word gets fixed. Leaving
  /// it empty would have made a photo the one import you could see but not
  /// correct.
  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context);
    // Read once, so a toggle flipped while the picker is open cannot send the
    // photo to an engine the user did not choose for it.
    final sheetMusic = _photoHasSheetMusic;
    final service = sheetMusic
        ? ref.read(photoNotationImportServiceProvider)
        : ref.read(photoTextImportServiceProvider);
    if (service == null) {
      // Neither case is an error. Sheet music needs a service address, which is
      // a setup step; the words path needs a browser, which some platforms are
      // not. Saying which beats a dead button.
      setState(() => _fileError = sheetMusic
          ? l10n.importPhotoNotConfigured
          : l10n.importPhotoNoReader);
      return;
    }

    setState(() {
      _picking = true;
      _fileError = null;
    });
    try {
      // `image/*`, which gives Android its photo grid — the picker someone
      // reaching for a photo expects.
      //
      // This was briefly changed to an extension list, on the theory that
      // `image/*` routes to a gallery that hands back a scaled copy. The
      // evidence for that turned out to be a red herring: the degraded uploads
      // (2048px, EXIF stripped, 0.026 bytes per pixel) had been through a
      // messenger before they were ever picked. An extension list swaps the
      // photo grid for a file browser, which is worse to use, so it is not
      // worth keeping without evidence this device actually needs it — and
      // `resolutionNote` in the worker now says so out loud if it does.
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return; // cancelled
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          setState(() => _fileError = l10n.importErrorUnreadable(file.name));
        }
        return;
      }
      // Held before the read rather than after it: a page that reads badly is
      // exactly the one worth looking at, and a refusal further down would
      // otherwise leave the reviewer with nothing on screen to look at.
      if (mounted) {
        setState(() {
          _photoBytes = bytes;
          _photoName = file.name;
        });
      }

      // Only now: until the picker closes, nothing is being read, and a
      // button claiming otherwise over an open picker would be a lie the user
      // sees the moment they cancel.
      if (mounted) setState(() => _readingPhoto = true);
      final payload = await service.extract(bytes, fileName: file.name);
      switch (payload) {
        case ChordProPayload(text: final text, notices: final notices):
          final parsed = _parser.parse(text);
          _sheetController.text = text;
          // The draft below IS this text, freshly parsed, so the box is not
          // dirty. Without this, [_save]'s re-read fires on every photographed
          // song and rebuilds the draft as if it had been pasted -- losing the
          // reader's own notices (too compressed, show-through erased, two
          // songs on the page) and the file name the DETAILS line credits it
          // to. The verses come out the same, so nothing was mis-saved; the
          // evidence about the reading was simply thrown away on the way.
          _parsedText = text;
          _accept(_PendingImport(
            verses: parsed.verses,
            title: parsed.title,
            key: parsed.key,
            // Both sets: the service reports what it could not read, the
            // parser what it could not classify. Either can be the reason a
            // line looks wrong.
            warnings: [...notices, ...parsed.warnings],
            source: _ImportSource.photo,
            fileName: file.name,
          ));
        case MusicXmlPayload(xml: final xml, notices: final notices):
          // A service that can engrave answers with this instead; the app
          // already knows how to read it.
          final result = _musicXml.importXml(xml);
          // Audiveris reads staves, not headings: it returns no work title at
          // all, so this used to arrive with Title and Number empty on a page
          // that says "151. Hozsánna" in print across the top. The engine that
          // can read that line is already on the device and takes about a
          // second, so ask it — for the heading only, since the notation is
          // what was wanted here.
          final heading = result.title == null
              ? await _headingFromPhoto(bytes)
              : null;
          _accept(_PendingImport(
            verses: result.verses,
            notation: result.notation,
            title: result.title ?? heading,
            key: result.key,
            timeSignature: result.timeSignature,
            warnings: [...notices, ...result.warnings],
            source: _ImportSource.photo,
            fileName: file.name,
          ));
      }
    } on PhotoImportException catch (e) {
      // A refused sign-in is the one failure worth re-wording: the service
      // answers in English, and this knows which language is on screen. Only
      // the project's own reader, though — see [_refusedForWantOfSignIn].
      // A refused sign-in is the one failure worth re-wording: the service
      // answers in English, and this knows which language is on screen. There
      // is only one reader and it is ours, so a 401 has only one cause.
      if (mounted) {
        setState(() => _fileError = e.statusCode == 401
            ? l10n.importPhotoSignIn
            : e.notice != null
                ? l10n.importNoticeText(e.notice!)
                : e.message);
      }
    } on MusicXmlImportException catch (e) {
      if (mounted) {
        setState(() => _fileError = l10n.importNoticeText(e.notice));
      }
    } catch (e) {
      if (mounted) setState(() => _fileError = '$e');
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
          _readingPhoto = false;
        });
      }
    }
  }

  /// The first line of a photographed page, read on the device.
  ///
  /// Used only to fill a heading the notation reader could not supply.
  /// [PhotoTextBridge] already puts the largest line of a page first and
  /// [_accept] already splits `151. Hozsánna` into a number and a title, so
  /// this hands over that first line and lets the existing path do the rest.
  ///
  /// Best-effort by design: it runs after the notation has already succeeded,
  /// so a failure here must cost nothing. Anything at all going wrong leaves
  /// the boxes empty, exactly as before.
  Future<String?> _headingFromPhoto(Uint8List bytes) async {
    final reader = ref.read(photoTextImportServiceProvider);
    if (reader == null) return null;
    try {
      final payload = await reader.extract(bytes);
      if (payload is! ChordProPayload) return null;
      for (final line in payload.text.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        // It has to look like a hymnal heading — a number, then words. Reading
        // a page of engraved music for text finds fragments of the notation
        // first, and on a real score this returned "J". One stray letter in the
        // Title box is worse than an empty one: empty is visibly unfinished and
        // Save refuses it, while "J" looks like an answer somebody gave.
        return _numberedTitle.hasMatch(trimmed) ? trimmed : null;
      }
    } catch (_) {
      // The notation is already in hand. A heading is a convenience, and a
      // convenience must never turn a successful import into a failed one.
    }
    return null;
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
  /// What Save would store, or null when it would not be allowed to.
  Song? get _draft =>
      _titleController.text.trim().isEmpty ? null : _songFromFields();

  /// What the preview shows — which is not the same question.
  ///
  /// The two used to be one getter, so a photographed page that had been read
  /// perfectly well showed "Give the song a title" and nothing else until a
  /// title was typed. That is backwards: the reason to look at the preview is
  /// to decide whether the reading is worth keeping, and being asked to name it
  /// first means naming something you have not seen. A title is needed to
  /// *save*; it is not needed to *look*.
  Song? get _preview => _songFromFields();

  Song? _songFromFields() {
    final pending = _pending;
    if (pending == null || !_hasContent(pending)) return null;
    final title = _titleController.text.trim();
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
    // A missing number used to be stored as 0, and 0 is not "no number" to
    // anything downstream — it sorts ahead of every real song and prints as a
    // number in the list. Here is the one moment someone knows the answer.
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      return [l10n.importBlockerNoNumber];
    }
    final asInt = int.tryParse(number);
    if (asInt == null || asInt <= 0) {
      return [l10n.importBlockerBadNumber];
    }
    return const [];
  }

  Future<void> _save() async {
    // Save what is on screen, not what was last parsed.
    //
    // The box does not re-parse as it is typed in, so by here the two can
    // disagree — and the person pressing Save is looking at the box. Without
    // this, an edited lyric was silently discarded and the old verses stored
    // in its place. Re-reading here rather than on every keystroke keeps the
    // parse off the typing path, where it would run once per character.
    if (_sheetController.text != _parsedText) {
      _reparse();
    }

    final draft = _draft;
    // Re-checked after the re-parse above, because it can change the answer:
    // a box emptied and saved has no verses, and must be refused rather than
    // stored as a song with nothing in it. The blocker is already on screen —
    // `_reparse` rebuilt — so this returns quietly rather than explaining
    // twice.
    if (draft == null || _blockersIn(AppLocalizations.of(context)).isNotEmpty) {
      return;
    }
    setState(() => _saving = true);

    if (_isEditing) {
      await ref.read(userSongsProvider.notifier).update(draft);
      if (!mounted) return;
      setState(() => _saving = false);
      // Back to the song being corrected. Pushing it instead would stack a
      // second copy of the same song on top of the one we came from.
      //
      // Guarded, because `optionURLReflectsImperativeAPIs` puts
      // `/song/:id/edit` in the address bar and so makes it reloadable: a reload
      // lands on it cold, as the one and only entry on the stack, and a bare
      // `context.pop()` there is answered with
      // `GoError('There is nothing to pop')`. The update has already completed,
      // so nothing is lost, but in a release build the button just looks dead.
      // The fallback is the song itself — where popping would have landed.
      // Land on the song WITHOUT leaving the editor behind in browser history.
      //
      // `optionURLReflectsImperativeAPIs` is on (app_router.dart), so every
      // imperative navigation reports a new URL and the browser records an
      // entry for it — `pop()` and `pushReplacement()` included. Both were
      // measured: history grew 3→5→6→7→8→9 across one ordinary journey, and
      // after saving a correction the system back button went straight back
      // INTO the editor. On Android that button is the back gesture, so a
      // saved song was one swipe away from the screen that had just saved it.
      //
      // `Router.neglect` performs the navigation without adding an entry, so
      // the editor's entry is overwritten rather than stacked on. What remains
      // is one redundant press — the entry beneath is the same song, opened
      // from the list — and then the list itself.
      Router.neglect(
        context,
        () => context.go(AppRoutes.songPath(draft.id)),
      );
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
    // Only the preview here. Save gates on [_blockersIn], and `_draft` is what
    // `_save` builds when it is pressed — reading it during build would be a
    // third answer to the same question.
    final preview = _preview;
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
      // The list width, not the form width: this screen's paste box wants room
      // for a chord sheet's longest line, and it carries a notation preview.
      body: ContentPane.list(
        child: ListView(
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
              // resetting to null would blank the preview and disable Save on
              // the first keystroke. So the preview keeps showing the stored
              // song until Parse is pressed.
              //
              // What this must NOT mean is that the typing is thrown away.
              // It used to: the words in the box were an "offer to replace"
              // that only Parse accepted, so editing a lyric and pressing Save
              // stored the OLD verses under the new title, reported success,
              // and said nothing. Reported from the live app as "I can edit
              // them, but no matter that I save, it doesn't get saved", and
              // reproduced in e2e/songs_crud.e2e.cjs. [_save] now re-reads the
              // box when it has drifted from [_parsedText].
              onChanged: (_) => setState(() => _pending = _savedPending),
            ),
            const SizedBox(height: 8),
            // Parse and Photo side by side, both first-class.
            //
            // Photo used to sit two taps away behind a "more ways" expander,
            // alongside a MusicXML picker that needs a score exported from
            // MuseScore first. That gave equal billing to the rarest path and
            // hid the one this app is for: the songs being added are in books,
            // and a book is photographed. The picker is gone - the notation
            // editor still imports MusicXML, but not from here.
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _picking ? null : _pickPhoto,
                  icon: _readingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera_outlined),
                  // Reading a page is seconds on the device and can be a minute
                  // on the sheet-music service, so the button says what it is
                  // doing rather than going quiet.
                  label: Text(_readingPhoto
                      ? l10n.importPhotoReading
                      : l10n.importPhoto),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed:
                      _sheetController.text.trim().isEmpty ? null : _parsePasted,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(l10n.importParse),
                ),
              ],
            ),
            // The one question the app cannot answer for itself, directly under
            // the button it changes. A checkbox rather than two buttons: it is
            // one gesture with a property, not two features.
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InkWell(
                onTap: _picking
                    ? null
                    : () => setState(
                        () => _photoHasSheetMusic = !_photoHasSheetMusic),
                // The box and its words are one control, and without this they
                // are not: the label was swept up into the surrounding group and
                // the checkbox left with no accessible name, so a screen reader
                // announced "checkbox, not checked" and nothing about what it
                // does.
                child: MergeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _photoHasSheetMusic,
                        onChanged: _picking
                            ? null
                            : (on) => setState(
                                () => _photoHasSheetMusic = on ?? false),
                      ),
                      Flexible(child: Text(l10n.importPhotoSheetMusic)),
                    ],
                  ),
                ),
              ),
            ),
            // Worth more than any code here: a curled page took the reading from
            // 63 notes to 6, because staff detection needs straight lines. Tilt
            // it survives; curl it does not.
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                _photoHasSheetMusic
                    ? l10n.importPhotoSheetMusicHint
                    : l10n.importPhotoHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
              Text(l10n.importSectionLines, style: _sectionStyle(theme)),
              const SizedBox(height: 8),
              LineList(
                text: _sheetController.text,
                kinds: _kinds,
                onKind: _setLineKind,
                onToken: _editToken,
              ),

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
              // Shown as soon as anything was read, titled or not. The real view
              // widgets, chosen the same way the song view chooses them, so this
              // is not an approximation that can drift.
              //
              // Beside the photograph when there is one and the pane is wide
              // enough to hold both, which is the whole point: a reading is
              // checked against the page it came from, not admired on its own.
              // Where they sit, and at what width, is [ReviewPanes]'s decision -
              // and its test's, because the number was wrong once and nothing
              // here could see it.
              if (preview != null)
                ReviewPanes(
                  photo: _photoBytes == null
                      ? null
                      : PhotoPane(
                          bytes: _photoBytes!,
                          name: _photoName,
                          height: 340,
                        ),
                  preview: SizedBox(
                    height: 340,
                    child: preview.hasNotation
                        ? SheetMusicView(
                            song: preview, transpose: 0, showChords: true)
                        : ChordView(song: preview, transpose: 0),
                  ),
                ),
              // And still say what Save is waiting for, underneath it.
              if (blockers.isNotEmpty)
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

/// Correcting one token of a chord row.
///
/// Its own widget because it owns a `TextEditingController`, and a controller has
/// to outlive the dialog's exit animation. Built inline first, disposed the
/// moment `showDialog` returned, and the route still had a `TextField` on it -
/// *A TextEditingController was used after being disposed*, caught by the test
/// for this before anyone tapped it.
class _TokenDialog extends StatefulWidget {
  const _TokenDialog({required this.token});

  final String token;

  @override
  State<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends State<_TokenDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.token);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.importTokenEditTitle),
      // Width-bounded: an AlertDialog gives its content no width to work with,
      // and a Column holding a TextField then asks for an infinite one.
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importTokenEditHint,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
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
  final List<ImportNotice> warnings;

  const _Warnings({required this.warnings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return _Notice(
      icon: Icons.info_outline,
      background: theme.colorScheme.secondaryContainer,
      foreground: theme.colorScheme.onSecondaryContainer,
      title: l10n.importWarningsTitle(warnings.length),
      text: warnings.map((w) => '• ${l10n.importNoticeText(w)}').join('\n'),
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
