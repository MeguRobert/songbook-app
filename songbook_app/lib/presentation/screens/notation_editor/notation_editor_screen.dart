import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/notation.dart';
import '../../../data/models/song.dart';
import '../../../data/models/song_id.dart';
import '../../../domain/services/notation_editor.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../providers/song_provider.dart';
import '../../widgets/content_pane.dart';
import '../../widgets/sheet_music/sheet_music_renderer.dart';

/// What a beat row's overflow menu offers.
enum _BeatAction { edit, insertAfter, delete }

/// The note value as a word in the current language.
///
/// A switch rather than a map keyed on the enum, so adding a [NoteDuration] is a
/// compile error here instead of a silently missing label.
String _durationName(AppLocalizations l10n, NoteDuration duration) =>
    switch (duration) {
      NoteDuration.whole => l10n.durationWhole,
      NoteDuration.half => l10n.durationHalf,
      NoteDuration.quarter => l10n.durationQuarter,
      NoteDuration.eighth => l10n.durationEighth,
      NoteDuration.sixteenth => l10n.durationSixteenth,
    };

/// Corrects the notation of a song the user imported.
///
/// Every path into the app's notation is a transcription: OMR guesses a pitch,
/// mis-reads a duration, drops a note, invents one. Those four failures are the
/// whole brief — so this is a flat row per beat with its pitch, duration and
/// syllable, closer to editing a table than to driving a score editor.
///
/// It is explicitly **not** a blank-page score writer. Note entry from scratch,
/// beaming, multiple voices, articulations and dynamics are an order of
/// magnitude more work, for material that is always being transcribed rather
/// than composed.
///
/// Two things earn their place next to the list:
///
///   - **the engraved result, above it.** A correction is judged against the
///     paper it came from, so the answer to "is this right?" has to be visible
///     without leaving the screen. The renderer relays on any notation change
///     because [SongNotation] carries value equality over all its fields.
///   - **each measure's arithmetic.** A dropped or invented note is exactly what
///     makes a bar stop adding up against the time signature, and that is
///     invisible on the staff — the bar just looks a little narrow.
class NotationEditorScreen extends ConsumerStatefulWidget {
  final SongId songId;

  const NotationEditorScreen({required this.songId, super.key});

  @override
  ConsumerState<NotationEditorScreen> createState() =>
      _NotationEditorScreenState();
}

class _NotationEditorScreenState extends ConsumerState<NotationEditorScreen> {
  static const _editor = NotationEditor();

  /// How much of the screen the live preview gets. Enough for two systems at
  /// the default scale; the renderer scrolls inside it for anything longer.
  static const _previewHeight = 190.0;

  Song? _song;

  /// The notation as stored, kept to answer "has anything changed?" — which is
  /// what makes the discard prompt honest rather than unconditional.
  SongNotation? _original;

  SongNotation? _notation;

  @override
  void initState() {
    super.initState();
    // Synchronous: user songs live in local storage, so the list is complete on
    // the first frame instead of flashing empty.
    final song = ref.read(userSongRepositoryProvider).getById(widget.songId);
    final notation = song?.notation;
    if (song == null || notation == null) return;
    _song = song;
    _original = notation;
    _notation = notation;
  }

  bool get _dirty => _notation != _original;

  Future<void> _save() async {
    final song = _song;
    final notation = _notation;
    if (song == null || notation == null) return;
    // copyWith, not a fresh Song: everything else about this song — its words,
    // its tags, its id — is not what this screen edits.
    await ref
        .read(userSongsProvider.notifier)
        .update(song.copyWith(notation: notation));
    if (!mounted) return;
    context.pop();
  }

  Future<void> _editBeat(BeatAddress address, NotatedBeat beat) async {
    final edited = await showModalBottomSheet<NotatedBeat>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BeatFieldsSheet(beat: beat),
    );
    if (edited == null || !mounted) return;
    setState(
        () => _notation = _editor.replaceBeat(_notation!, address, edited));
  }

  void _onBeatAction(
      _BeatAction action, BeatAddress address, NotatedBeat beat) {
    switch (action) {
      case _BeatAction.edit:
        _editBeat(address, beat);
      case _BeatAction.insertAfter:
        setState(() => _notation = _editor.insertBeatAfter(_notation!, address));
      case _BeatAction.delete:
        setState(() => _notation = _editor.deleteBeat(_notation!, address));
    }
  }

  /// Whether to leave with corrections unsaved. Null/false means stay.
  Future<bool> _askDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.discardTitle),
        content: Text(l10n.discardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.discardKeepEditing),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final song = _song;
    final notation = _notation;

    if (song == null || notation == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.menuEditNotation)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.notationNoneStored,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return PopScope(
      // Only intercept when there is something to lose. Prompting on every exit
      // trains the answer, which is how a real prompt gets dismissed too.
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _askDiscard();
        if (!discard) return;
        // `context.mounted`, not the State's `mounted`: this closure's `context`
        // shadows `this.context`, and the analyzer can only tie the guard to the
        // context it can see. Same check, spelled so it is checkable.
        if (!context.mounted) return;
        context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.menuEditNotation),
          actions: [
            TextButton(
              onPressed: _dirty ? _save : null,
              child: Text(l10n.actionSave),
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: _previewHeight,
              child: SheetMusicRenderer(
                song: song,
                notation: notation,
                showChords: true,
              ),
            ),
            const Divider(height: 1),
            if (notation.pickup?.isNotEmpty ?? false)
              _PickupNotice(count: notation.pickup!.length),
            // The preview above stays full width — the renderer scales music to
            // fit — but a beat row is table-shaped, so on a desktop window its
            // syllable column would balloon and push the overflow menu a metre
            // away from the pitch it edits.
            Expanded(
              child: ContentPane.list(
                child: ListView(children: _rows(notation)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The beat list: a measure header, then one row per beat.
  ///
  /// Measures are numbered continuously across notated verses rather than
  /// restarting, so a bar number on screen names exactly one bar.
  List<Widget> _rows(SongNotation notation) {
    final rows = <Widget>[];
    final expected = notation.beatsPerMeasure;
    var measureNumber = 1;

    for (var v = 0; v < notation.verses.length; v++) {
      final verse = notation.verses[v];
      if (notation.verses.length > 1) {
        rows.add(_VerseHeader(number: verse.number));
      }
      for (var m = 0; m < verse.measures.length; m++) {
        final measure = verse.measures[m];
        rows.add(_MeasureHeader(
          // An anacrusis is not counted, the way a printed score does not count
          // it: the first FULL bar is bar 1.
          number: measure.isPickup ? null : measureNumber++,
          total: measure.totalBeats,
          expected: expected,
          isPickup: measure.isPickup,
        ));
        for (var b = 0; b < measure.beats.length; b++) {
          final address = BeatAddress(verse: v, measure: m, beat: b);
          rows.add(_BeatRow(
            address: address,
            beat: measure.beats[b],
            onAction: _onBeatAction,
          ));
        }
        if (measure.beats.isEmpty) rows.add(const _EmptyMeasureRow());
      }
    }
    return rows;
  }
}

/// Header for a notated verse, shown only when there is more than one.
class _VerseHeader extends StatelessWidget {
  final int number;

  const _VerseHeader({required this.number});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        AppLocalizations.of(context).notationVerse(number),
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
      ),
    );
  }
}

/// Measure number and what its beats add up to against the time signature.
class _MeasureHeader extends StatelessWidget {
  /// Null for a pickup bar, which a score does not number.
  final int? number;
  final double total;
  final int expected;

  /// A bar the source declared deliberately short. It gets neither the
  /// arithmetic nor the warning: it is *supposed* not to add up, and flagging it
  /// would train the warning away on exactly the hymns that open on an upbeat.
  final bool isPickup;

  const _MeasureHeader({
    required this.number,
    required this.total,
    required this.expected,
    this.isPickup = false,
  });

  /// `4`, not `4.0`; `3.5` where it matters.
  static String format(double beats) {
    final rounded = beats.round();
    return (beats - rounded).abs() < 0.001
        ? '$rounded'
        : beats.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final short = (total - expected).abs() > 0.001;
    final colour =
        short ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(isPickup ? l10n.notationPickup : l10n.notationMeasure(number ?? 0),
              style: theme.textTheme.labelLarge),
          const Spacer(),
          if (isPickup)
            Text(
              // `format(total)` is already display-ready ("3", "3.5"); the count
              // only picks singular from plural, so it is the exact-one test and
              // not a rounding of the beat count — 0.5 must not read "1 beat".
              l10n.notationPickupBeats(total == 1 ? 1 : 2, format(total)),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else ...[
            if (short) ...[
              Icon(Icons.warning_amber_rounded, size: 16, color: colour),
              const SizedBox(width: 4),
            ],
            Text(
              l10n.notationMeasureBeats(format(total), expected),
              style: theme.textTheme.labelMedium?.copyWith(color: colour),
            ),
          ],
        ],
      ),
    );
  }
}

/// A measure with nothing in it.
///
/// Deleting a measure's last beat leaves the measure behind on purpose — it is
/// the unit the layout engine breaks systems on, and the MusicXML importer keeps
/// empty ones so the voices it retained stay aligned. Saying so beats an
/// unexplained gap in the list.
class _EmptyMeasureRow extends StatelessWidget {
  const _EmptyMeasureRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        AppLocalizations.of(context).notationNoBeats,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Beats sitting in the superseded `SongNotation.pickup` list.
///
/// An anacrusis does not need that field: a pickup bar *is* a measure with fewer
/// beats, the layout engine spaces measures from their content so it already
/// engraves narrow, and `NotatedMeasure.isPickup` carries the "deliberately
/// short" answer. `SongNotation.pickup` is written by no importer and read by no
/// renderer, so anything in it is invisible — which is worth saying out loud on
/// a screen whose whole job is "is this right?".
class _PickupNotice extends StatelessWidget {
  final int count;

  const _PickupNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).notationStalePickupNotice(count),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// One beat: pitch, duration, chord, syllable, tie markers, and its menu.
class _BeatRow extends StatelessWidget {
  final BeatAddress address;
  final NotatedBeat beat;
  final void Function(_BeatAction, BeatAddress, NotatedBeat) onAction;

  const _BeatRow({
    required this.address,
    required this.beat,
    required this.onAction,
  });

  /// The duration as words rather than a glyph: a glyph in the Bravura font is
  /// what the preview above is for, and words are what the dropdown in the edit
  /// sheet offers, so the two agree.
  String _duration(AppLocalizations l10n) {
    final name = _durationName(l10n, beat.duration);
    return beat.dotted ? l10n.durationDotted(name) : name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final syllables = beat.allSyllables.join(' / ');

    return ListTile(
      dense: true,
      onTap: () => onAction(_BeatAction.edit, address, beat),
      title: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              beat.isRest ? l10n.beatRestShort : beat.pitch,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [],
                color: beat.isRest ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          SizedBox(
            width: 116,
            child: Text(
              _duration(l10n),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (beat.chord != null) ...[
            Text(
              beat.chord!,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(syllables, overflow: TextOverflow.ellipsis),
          ),
          if (beat.tieEnd)
            Icon(Icons.subdirectory_arrow_left,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
          if (beat.tieStart)
            Icon(Icons.subdirectory_arrow_right,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
      trailing: PopupMenuButton<_BeatAction>(
        // Addressed rather than positional, so a test — and a screen reader —
        // names the beat it means.
        key: Key('beat-menu-${address.verse}-${address.measure}-'
            '${address.beat}'),
        icon: const Icon(Icons.more_vert, size: 18),
        tooltip: l10n.beatActions,
        onSelected: (action) => onAction(action, address, beat),
        itemBuilder: (context) => [
          PopupMenuItem(value: _BeatAction.edit, child: Text(l10n.actionEdit)),
          PopupMenuItem(
              value: _BeatAction.insertAfter,
              child: Text(l10n.beatInsertAfter)),
          PopupMenuItem(
              value: _BeatAction.delete, child: Text(l10n.actionDelete)),
        ],
      ),
    );
  }
}

/// The seven fields of a [NotatedBeat], as controls that cannot express a wrong
/// value.
///
/// Pitch is a letter, an accidental and an octave rather than a text field. The
/// stored form is scientific notation (`Bb3`, `F#4`) and a typo in it does not
/// fail loudly — `parsedPitch` just returns null and the note quietly vanishes
/// from the staff. Since pitch is the single most common OMR error, the control
/// that fixes it is the one that most needs to be un-mistypeable.
class _BeatFieldsSheet extends StatefulWidget {
  final NotatedBeat beat;

  const _BeatFieldsSheet({required this.beat});

  @override
  State<_BeatFieldsSheet> createState() => _BeatFieldsSheetState();
}

class _BeatFieldsSheetState extends State<_BeatFieldsSheet> {
  static const _letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  /// The stored accidentals, in the order the dropdown offers them. The stored
  /// form is what MusicXML and the transposer already use.
  ///
  /// Named rather than shown as ♮/♯/♭. In the release build in a browser, ♮
  /// rendered as an unreadable mark sitting below the baseline in Roboto, which
  /// left the selected accidental indistinguishable from the other two — on the
  /// one control here that most needs to be unambiguous, since a wrong
  /// accidental is both a common OMR error and invisible once saved.
  static const _accidentals = ['', '#', 'b'];

  /// The name of a stored accidental in the current language.
  static String _accidentalName(AppLocalizations l10n, String stored) =>
      switch (stored) {
        '#' => l10n.accidentalSharp,
        'b' => l10n.accidentalFlat,
        _ => l10n.accidentalNatural,
      };

  late bool _isRest;
  late String _letter;
  late String _accidental;
  late int _octave;
  late NoteDuration _duration;
  late bool _dotted;
  late bool _tieStart;
  late bool _tieEnd;
  late final TextEditingController _syllable;
  late final TextEditingController _chord;

  /// Lyric lines after the first, kept verbatim. A MusicXML score can carry a
  /// syllable per verse on the same note; this sheet edits the first line, and
  /// rebuilding the beat without the rest would delete the other verses' words.
  late final List<String> _extraSyllableLines;

  @override
  void initState() {
    super.initState();
    final beat = widget.beat;
    _isRest = beat.isRest;
    // parsedPitch uppercases the letter and keeps the accidental as stored. A
    // pitch it cannot read (a bad import, or an older hand-edited payload) falls
    // back to C4 rather than throwing — the point of this screen is to fix it.
    final parsed = beat.parsedPitch;
    final note = parsed?.$1 ?? 'C';
    _letter = _letters.contains(note[0]) ? note[0] : 'C';
    _accidental =
        note.length > 1 && _accidentals.contains(note[1]) ? note[1] : '';
    _octave = parsed?.$2 ?? 4;
    _duration = beat.duration;
    _dotted = beat.dotted;
    _tieStart = beat.tieStart;
    _tieEnd = beat.tieEnd;

    final lines = beat.allSyllables;
    _syllable = TextEditingController(text: lines.isEmpty ? '' : lines.first);
    _extraSyllableLines = lines.length > 1 ? lines.sublist(1) : const [];
    _chord = TextEditingController(text: beat.chord ?? '');
  }

  @override
  void dispose() {
    _syllable.dispose();
    _chord.dispose();
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void _apply() {
    final first = _trimmedOrNull(_syllable);
    // Only one of the two syllable shapes is ever populated: `syllables` wins in
    // `allSyllables`, so writing both would make the single one unreachable and
    // the next open of this sheet would show a value that is not in use.
    final hasStack = _extraSyllableLines.isNotEmpty;

    Navigator.of(context).pop(NotatedBeat(
      pitch: _isRest ? 'R' : '$_letter$_accidental$_octave',
      duration: _duration,
      syllable: hasStack ? null : first,
      syllables: hasStack ? [first ?? '', ..._extraSyllableLines] : null,
      chord: _trimmedOrNull(_chord),
      tieStart: _tieStart,
      tieEnd: _tieEnd,
      dotted: _dotted,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.beatEditTitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  )),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('beat-rest'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.beatRest),
                value: _isRest,
                onChanged: (value) => setState(() => _isRest = value),
              ),
              if (!_isRest)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('beat-note'),
                        initialValue: _letter,
                        decoration:
                            InputDecoration(labelText: l10n.beatNote),
                        items: [
                          for (final letter in _letters)
                            DropdownMenuItem(
                                value: letter, child: Text(letter)),
                        ],
                        onChanged: (value) =>
                            setState(() => _letter = value ?? _letter),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('beat-accidental'),
                        initialValue: _accidental,
                        decoration:
                            InputDecoration(labelText: l10n.beatAccidental),
                        items: [
                          for (final stored in _accidentals)
                            DropdownMenuItem(
                              value: stored,
                              child: Text(_accidentalName(l10n, stored)),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _accidental = value ?? ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _OctaveStepper(
                      value: _octave,
                      onChanged: (value) => setState(() => _octave = value),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<NoteDuration>(
                key: const Key('beat-duration'),
                initialValue: _duration,
                decoration: InputDecoration(labelText: l10n.beatDuration),
                items: [
                  for (final duration in NoteDuration.values)
                    DropdownMenuItem(
                      value: duration,
                      child: Text(_durationName(l10n, duration)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _duration = value ?? _duration),
              ),
              SwitchListTile(
                key: const Key('beat-dotted'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.beatDotted),
                subtitle: Text(l10n.beatDottedHint),
                value: _dotted,
                onChanged: (value) => setState(() => _dotted = value),
              ),
              SwitchListTile(
                key: const Key('beat-tie-end'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.beatTieEnd),
                value: _tieEnd,
                onChanged: (value) => setState(() => _tieEnd = value),
              ),
              SwitchListTile(
                key: const Key('beat-tie-start'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.beatTieStart),
                value: _tieStart,
                onChanged: (value) => setState(() => _tieStart = value),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('beat-syllable'),
                controller: _syllable,
                decoration: InputDecoration(
                  labelText: l10n.beatSyllable,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_extraSyllableLines.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.beatExtraLyricLines(
                    _extraSyllableLines.length,
                    _extraSyllableLines.join(', '),
                  ),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('beat-chord'),
                controller: _chord,
                decoration: InputDecoration(
                  labelText: l10n.beatChord,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.actionCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _apply, child: Text(l10n.actionApply)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Octave as a stepper rather than a field: the useful range for a hymn melody
/// is about three octaves, and a stepper cannot produce a value the renderer
/// has no staff position for.
class _OctaveStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  static const _min = 1;
  static const _max = 7;

  const _OctaveStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.beatOctave, style: theme.textTheme.bodySmall),
        Row(
          children: [
            IconButton(
              key: const Key('beat-octave-down'),
              visualDensity: VisualDensity.compact,
              onPressed: value > _min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
              tooltip: l10n.octaveLower,
            ),
            Text('$value', style: theme.textTheme.titleMedium),
            IconButton(
              key: const Key('beat-octave-up'),
              visualDensity: VisualDensity.compact,
              onPressed: value < _max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
              tooltip: l10n.octaveHigher,
            ),
          ],
        ),
      ],
    );
  }
}
