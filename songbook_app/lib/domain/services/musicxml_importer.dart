import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

import '../../data/models/chord_position.dart';
import '../../data/models/lyric_line.dart';
import '../../data/models/notation.dart';
import '../../data/models/verse.dart';

/// Thrown when the input is not usable MusicXML at all.
///
/// Anything that is merely *lossy* — an unsupported note value, a voice the app
/// cannot render — is reported through [MusicXmlImportResult.warnings] instead,
/// so a partially understood score still imports.
class MusicXmlImportException implements Exception {
  final String message;

  const MusicXmlImportException(this.message);

  @override
  String toString() => 'MusicXmlImportException: $message';
}

/// What one measure's `<barline>` elements said, beyond the notes.
///
/// Kept per part-relative measure ordinal alongside the streams, the same way
/// system breaks and `implicit="yes"` already are: repeats belong to the bar,
/// not to a voice, and only the melody part's answer is rendered.
class _Barlines {
  bool repeatStart = false;
  bool repeatEnd = false;

  /// `<ending type="start">`'s number, when this measure opens a volta bracket.
  int? endingStart;

  /// True when this measure closes one, whether by `stop` or `discontinue`.
  bool endingStops = false;
}

/// One monophonic note stream recovered from the source file.
///
/// A stream is identified by the MusicXML triple (part, staff, voice). SATB
/// hymnals encode the four voices either as four `<part>`s or as one part with
/// two staves carrying two `<voice>`s each; both shapes come out as four
/// [ImportedVoice]s here.
class ImportedVoice {
  /// `id` attribute of the `<part>` this stream came from (e.g. `P1`).
  final String partId;

  /// Zero-based position of the part in the score, used for ordering.
  final int partIndex;

  /// `<part-name>` from `<part-list>`, when the file names the part.
  final String? partName;

  /// 1-based staff number within the part (1 when the part has a single staff).
  final int staff;

  /// `<voice>` value, `"1"` when the notes carry no explicit voice.
  ///
  /// Notes stacked as a `<chord>` on top of another note get a synthetic id of
  /// the form `1#2`, `1#3`, … — see [isChordMember].
  final String voiceId;

  /// True when this stream was split out of a `<chord>` rather than being a
  /// voice the file declared.
  final bool isChordMember;

  /// The stream's measures, aligned index-for-index with every other stream of
  /// the same part.
  final List<NotatedMeasure> measures;

  const ImportedVoice({
    required this.partId,
    required this.partIndex,
    required this.partName,
    required this.staff,
    required this.voiceId,
    required this.isChordMember,
    required this.measures,
  });

  /// Short human-readable identifier, e.g. `P1 staff 2 voice 6`.
  String get label {
    final name = partName == null ? partId : '$partId ($partName)';
    return '$name staff $staff voice $voiceId';
  }

  @override
  String toString() => 'ImportedVoice($label, ${measures.length} measures)';
}

/// Everything an importer run recovered from one MusicXML document.
class MusicXmlImportResult {
  /// The rendered notation: the melody voice only (see [MusicXmlImporter]).
  final SongNotation notation;

  /// Lyrics rebuilt from `<lyric>` elements, one [Verse] per lyric line
  /// number. Empty when the file carries no lyrics.
  final List<Verse> verses;

  /// `<work-title>` / `<movement-title>` / first `<credit-words>`, if any.
  final String? title;

  /// Key derived from `<key>`, or null when the file declares none.
  /// [notation] falls back to `C` in that case.
  final String? key;

  /// Time signature from `<time>`, or null when the file declares none.
  /// [notation] falls back to `4/4` in that case.
  final String? timeSignature;

  /// The stream that became [notation], or null for a score with no notes.
  final ImportedVoice? melody;

  /// Every other stream in the file, in (part, staff, voice) order.
  ///
  /// Nothing renders these yet — they are kept so that adding choral support
  /// later does not mean re-importing every file.
  final List<ImportedVoice> additionalVoices;

  /// Non-fatal problems: dropped grace notes, approximated note values,
  /// unrendered voices. Meant to be surfaced to whoever ran the import.
  final List<String> warnings;

  const MusicXmlImportResult({
    required this.notation,
    required this.verses,
    required this.title,
    required this.key,
    required this.timeSignature,
    required this.melody,
    required this.additionalVoices,
    required this.warnings,
  });
}

/// Turns MusicXML into the app's [SongNotation] model.
///
/// Ported from `tools/convert_hymn.py` (`parse_musicxml`, `add_line_breaks`,
/// `convert_to_app_format`), which is the proven path for the Audiveris OMR
/// output this app is fed.
///
/// ## Melody reduction rule
///
/// [SongNotation] is monophonic — one [NotatedBeat] stream per verse — while
/// hymnal MusicXML is usually four-voice SATB. The rendered notation is
/// therefore a reduction, chosen as:
///
/// > the **first `<part>` in the score**, its **lowest-numbered `<staff>`**,
/// > its **lowest-numbered `<voice>`** on that staff — i.e. the top line of the
/// > top staff of the first part, which is where the melody lives in both the
/// > four-parts-one-voice and the one-part-two-staves SATB encodings.
///
/// Notes stacked with `<chord>` are reduced to the highest-sounding note of the
/// stack, which is the same rule applied vertically.
///
/// Every stream the rule did *not* pick is still returned, in
/// [MusicXmlImportResult.additionalVoices]. The Python discarded them; that is
/// the one place this port deliberately does more, because choral rendering is
/// a planned feature and a discarded voice means re-importing the source file.
///
/// This class is pure: strings and bytes in, models out. No file access.
class MusicXmlImporter {
  const MusicXmlImporter();

  /// Fallback measures-per-line when the file has no explicit system breaks.
  /// Matches `add_line_breaks()`'s default for hymns.
  static const int defaultMeasuresPerLine = 2;

  /// Imports an uncompressed MusicXML document.
  ///
  /// [measuresPerLine] is only consulted when the file contains no
  /// `<print new-system="yes">` markers; pass 0 to suppress the fallback and
  /// leave line breaking entirely to the layout engine.
  ///
  /// Throws [MusicXmlImportException] for empty or unparseable input.
  MusicXmlImportResult importXml(
    String xml, {
    int measuresPerLine = defaultMeasuresPerLine,
  }) {
    final source = _stripBom(xml).trim();
    if (source.isEmpty) {
      throw const MusicXmlImportException('The MusicXML input is empty.');
    }

    final XmlDocument document;
    try {
      document = XmlDocument.parse(source);
    } on XmlException catch (e) {
      throw MusicXmlImportException('The file is not valid XML: ${e.message}');
    }

    if (document.rootElement.localName == 'container') {
      throw const MusicXmlImportException(
        'This is an .mxl container manifest, not a score. '
        'Pass the whole .mxl file to importCompressed instead.',
      );
    }

    return _parse(document, measuresPerLine);
  }

  /// Imports compressed MusicXML (`.mxl`), which is a zip archive.
  ///
  /// The score entry is located through `META-INF/container.xml` when present —
  /// the archive can hold several XML files and only the manifest says which is
  /// the score — falling back to the first non-`META-INF` `.xml`/`.musicxml`
  /// entry, which is what `convert_hymn.py` did.
  ///
  /// Throws [MusicXmlImportException] when the bytes are not a readable archive
  /// or hold no score.
  MusicXmlImportResult importCompressed(
    List<int> mxlBytes, {
    int measuresPerLine = defaultMeasuresPerLine,
  }) {
    return importXml(
      _scoreXmlFromMxl(mxlBytes),
      measuresPerLine: measuresPerLine,
    );
  }

  // ---------------------------------------------------------------------------
  // .mxl handling
  // ---------------------------------------------------------------------------

  String _scoreXmlFromMxl(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const MusicXmlImportException('The .mxl input is empty.');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw MusicXmlImportException('Not a readable .mxl archive: $e');
    }

    final manifest = archive.files.firstWhereOrNull(
      (f) => f.isFile && f.name.replaceAll('\\', '/') == 'META-INF/container.xml',
    );
    if (manifest != null) {
      final path = _rootFilePath(_entryAsString(manifest));
      if (path != null) {
        final entry = archive.files.firstWhereOrNull(
          (f) => f.isFile && f.name.replaceAll('\\', '/') == path,
        );
        if (entry != null) return _entryAsString(entry);
      }
    }

    final fallback = archive.files.firstWhereOrNull((f) {
      if (!f.isFile) return false;
      final name = f.name.replaceAll('\\', '/');
      if (name.startsWith('META-INF')) return false;
      final lower = name.toLowerCase();
      return lower.endsWith('.xml') || lower.endsWith('.musicxml');
    });
    if (fallback == null) {
      throw const MusicXmlImportException(
        'The .mxl archive contains no MusicXML score entry.',
      );
    }
    return _entryAsString(fallback);
  }

  /// The `full-path` of the first `<rootfile>` in an `.mxl` container manifest.
  String? _rootFilePath(String containerXml) {
    try {
      final doc = XmlDocument.parse(containerXml);
      for (final rootfile in doc.findAllElements('rootfile', namespace: '*')) {
        final path = rootfile.getAttribute('full-path');
        if (path != null && path.isNotEmpty) return path.replaceAll('\\', '/');
      }
    } on XmlException {
      // A broken manifest is not fatal — the caller falls back to scanning.
    }
    return null;
  }

  String _entryAsString(ArchiveFile file) {
    final content = file.content;
    final bytes = content is List<int> ? content : const <int>[];
    // allowMalformed keeps a stray byte in an OMR-generated file from killing
    // an otherwise fine import; the XML parser will complain if it matters.
    return _stripBom(utf8.decode(bytes, allowMalformed: true));
  }

  String _stripBom(String s) =>
      s.startsWith('﻿') ? s.substring(1) : s;

  // ---------------------------------------------------------------------------
  // Document parsing
  // ---------------------------------------------------------------------------

  MusicXmlImportResult _parse(XmlDocument document, int measuresPerLine) {
    final root = document.rootElement;
    final warnings = <String>[];
    final notices = _Notices();

    if (root.localName == 'score-timewise') {
      warnings.add(
        'score-timewise files are not fully supported; measures may be '
        'grouped incorrectly. Convert to score-partwise for a clean import.',
      );
    }

    final title = _readTitle(root);
    final key = _readKey(root);
    final timeSignature = _readTimeSignature(root);
    final partNames = _readPartNames(root);

    var parts = root.findAllElements('part', namespace: '*').toList();
    if (parts.isEmpty) {
      // Mirrors the Python fallback: some OMR output omits <part> wrappers.
      parts = [root];
    }

    final streams = <String, _Stream>{};
    final systemBreaks = <int, Set<int>>{};
    // Measure ordinals the file declared `implicit="yes"`. Kept per part, like
    // the system breaks, because only the melody part's answer is used.
    final implicitMeasures = <int, Set<int>>{};
    // Repeat signs and volta brackets, per part, per measure ordinal.
    final barlines = <int, Map<int, _Barlines>>{};

    for (var partIndex = 0; partIndex < parts.length; partIndex++) {
      final part = parts[partIndex];
      final partId = part.getAttribute('id') ?? 'P${partIndex + 1}';
      final breaks = systemBreaks[partIndex] = <int>{};
      final implicit = implicitMeasures[partIndex] = <int>{};
      final bars = barlines[partIndex] = <int, _Barlines>{};

      var measures = part.findElements('measure', namespace: '*').toList();
      if (measures.isEmpty) {
        measures = part.findAllElements('measure', namespace: '*').toList();
      }

      var divisions = 1.0;
      for (var ordinal = 0; ordinal < measures.length; ordinal++) {
        // `implicit="yes"` is the file saying this bar is deliberately not a
        // full one — nearly always the opening anacrusis. Dropping it left a
        // short bar indistinguishable from one the transcription damaged.
        if (measures[ordinal].getAttribute('implicit') == 'yes') {
          implicit.add(ordinal);
        }
        divisions = _readMeasure(
          measure: measures[ordinal],
          ordinal: ordinal,
          partIndex: partIndex,
          partId: partId,
          partName: partNames[partId],
          divisions: divisions,
          streams: streams,
          systemBreaks: breaks,
          barlines: bars,
          notices: notices,
        );
      }
    }

    // Lyric line numbers are global: a beat's `syllables` list has to mean the
    // same thing in every stream, so the ordering is fixed once here.
    final lyricNumbers = _orderedLyricNumbers(streams.values);

    final ordered = streams.values.where((s) => s.hasBeats).toList()
      ..sort(_compareStreams);

    final melody = ordered.isEmpty ? null : ordered.first;
    final additional = ordered.skip(1).toList();

    final melodyMeasures = melody == null
        ? <NotatedMeasure>[]
        : _applyLineBreaks(
            _applyBarlines(
              _markPickups(
                melody.toMeasures(lyricNumbers),
                implicitMeasures[melody.partIndex] ?? const <int>{},
              ),
              barlines[melody.partIndex] ?? const <int, _Barlines>{},
            ),
            systemBreaks[melody.partIndex] ?? const <int>{},
            measuresPerLine,
          );

    if (melody == null) {
      warnings.add('No notes were found in the file.');
    }
    if (additional.isNotEmpty) {
      final declared = additional.where((s) => !s.isChordMember).length;
      final stacked = additional.length - declared;
      final phrases = <String>[
        if (declared > 0) '$declared additional voice${declared == 1 ? '' : 's'}',
        if (stacked > 0) '$stacked chord line${stacked == 1 ? '' : 's'}',
      ];
      warnings.add(
        'Found ${phrases.join(' and ')} beyond the melody. Only the melody is '
        'rendered; the rest are kept in additionalVoices.',
      );
    }
    warnings.addAll(notices.messages);

    final additionalVoices = [
      for (final stream in additional)
        stream.toImportedVoice(stream.toMeasures(lyricNumbers)),
    ];

    return MusicXmlImportResult(
      notation: SongNotation(
        originalKey: key ?? 'C',
        timeSignature: timeSignature ?? '4/4',
        // The hymnal sheets this app renders never print a time signature; the
        // Python hard-coded the same thing.
        showTimeSignature: false,
        verses: [NotatedVerse(number: 1, measures: melodyMeasures)],
        // Stored, not merely returned. These used to reach the caller and stop
        // there, so reading a bass line meant re-importing the source file.
        voices: _storedVoices(additionalVoices, melodyMeasures.length),
      ),
      verses: _buildVerses(melodyMeasures, lyricNumbers),
      title: title,
      key: key,
      timeSignature: timeSignature,
      melody: melody?.toImportedVoice(melodyMeasures),
      additionalVoices: additionalVoices,
      warnings: warnings,
    );
  }

  /// The non-melody voices as they are stored on the song.
  ///
  /// Null rather than empty for a single-voice score: a picker with one entry is
  /// noise, and `SongNotation.hasMultipleVoices` is what the controls key off.
  ///
  /// Measures are padded to [melodyBarCount] so every voice is aligned
  /// bar-for-bar with the engraved one. A voice that falls silent before the end
  /// would otherwise be short, and switching to it would renumber every bar
  /// after the gap.
  List<NotatedVoice>? _storedVoices(
    List<ImportedVoice> voices,
    int melodyBarCount,
  ) {
    if (voices.isEmpty) return null;
    final names = _voiceNames(voices);

    return [
      for (var i = 0; i < voices.length; i++)
        NotatedVoice(
          name: names[i],
          measures: [
            ...voices[i].measures.take(melodyBarCount),
            for (var b = voices[i].measures.length; b < melodyBarCount; b++)
              const NotatedMeasure(beats: []),
          ],
        ),
    ];
  }

  /// Names for the non-melody voices.
  ///
  /// Exactly three of them, under a melody, is a four-part hymn, and the reduction
  /// rule has already ordered the streams top-down — so they are the alto, tenor
  /// and bass, and saying so is far more use to a singer than `P1 staff 2 voice 6`.
  ///
  /// Any other count is not a convention this can lean on. Two voices could be
  /// anything, so those keep the file's own labels: a guess a singer cannot check
  /// is worse than a label that is merely ugly.
  List<String> _voiceNames(List<ImportedVoice> voices) {
    if (voices.length == 3) return const ['Alto', 'Tenor', 'Bass'];
    return [for (final voice in voices) voice.label];
  }

  /// Reads one `<measure>` into [streams], returning the divisions value in
  /// force at the end of it.
  double _readMeasure({
    required XmlElement measure,
    required int ordinal,
    required int partIndex,
    required String partId,
    required String? partName,
    required double divisions,
    required Map<String, _Stream> streams,
    required Set<int> systemBreaks,
    required Map<int, _Barlines> barlines,
    required _Notices notices,
  }) {
    var currentDivisions = divisions;

    // Stacks in document order per (staff, voice). A stack is one note plus any
    // <chord> notes hanging off it.
    final stacksByVoice = <String, List<_Stack>>{};
    _Stack? lastStack;
    String? pendingChord;

    for (final child in measure.childElements) {
      switch (child.localName) {
        case 'attributes':
          final value = double.tryParse(_textOf(child, 'divisions') ?? '');
          if (value != null && value > 0) currentDivisions = value;

        case 'print':
          if (child.getAttribute('new-system') == 'yes' ||
              child.getAttribute('new-page') == 'yes') {
            systemBreaks.add(ordinal);
          }

        case 'barline':
          _readBarline(
            child,
            barlines.putIfAbsent(ordinal, _Barlines.new),
          );

        case 'harmony':
          // <harmony> precedes the note it sits above, so it is held until the
          // next note element opens a stack.
          pendingChord = _parseHarmony(child) ?? pendingChord;

        case 'note':
          if (_childOf(child, 'grace') != null) {
            // NotatedBeat has no grace flag, so a grace note would be rendered
            // as a full beat and break the bar's arithmetic.
            notices.graceNotes++;
            continue;
          }

          final note = _parseNote(child, currentDivisions, notices);
          final isChordMember = _childOf(child, 'chord') != null;

          if (isChordMember && lastStack != null) {
            lastStack.notes.add(note);
          } else {
            final staff = int.tryParse(_textOf(child, 'staff') ?? '') ?? 1;
            final voice = _textOf(child, 'voice') ?? '1';
            final stack = _Stack(staff: staff, voice: voice, note: note);
            stack.chord = pendingChord;
            pendingChord = null;
            stacksByVoice.putIfAbsent('$staff|$voice', () => []).add(stack);
            lastStack = stack;
          }

        // <backup>/<forward> only matter for computing onsets. Voices are read
        // as independent streams here, so their note order within a voice is
        // already correct without replaying the time cursor.
      }
    }

    for (final stacks in stacksByVoice.values) {
      final first = stacks.first;
      final depth = stacks.fold<int>(0, (m, s) => s.notes.length > m ? s.notes.length : m);

      for (var level = 0; level < depth; level++) {
        final key = '$partIndex|${first.staff}|${first.voice}|$level';
        final stream = streams.putIfAbsent(
          key,
          () => _Stream(
            partIndex: partIndex,
            partId: partId,
            partName: partName,
            staff: first.staff,
            voice: first.voice,
            chordLevel: level,
          ),
        );

        stream.measures[ordinal] = [
          for (final stack in stacks) _beatAt(stack, level),
        ];
      }
      notices.chordStacks += stacks.where((s) => s.notes.length > 1).length;
    }

    return currentDivisions;
  }

  /// Folds one `<barline>` into [into].
  ///
  /// A measure can carry two of them — a forward repeat on its left and a
  /// backward one on its right — so this accumulates rather than replaces.
  /// `location` is optional in MusicXML and defaults to `right`; the direction
  /// of the `<repeat>` already says which side it belongs to, so `location` is
  /// only consulted for the ending, where it cannot be inferred.
  void _readBarline(XmlElement barline, _Barlines into) {
    final repeat = _childOf(barline, 'repeat');
    if (repeat != null) {
      switch (repeat.getAttribute('direction')) {
        case 'forward':
          into.repeatStart = true;
        case 'backward':
          into.repeatEnd = true;
      }
    }

    final ending = _childOf(barline, 'ending');
    if (ending == null) return;
    switch (ending.getAttribute('type')) {
      case 'start':
        into.endingStart = _firstEndingNumber(ending.getAttribute('number'));
      // `discontinue` is the open-ended second-time bar: no downward hook on
      // the right. It still ends the run of measures under the bracket.
      case 'stop':
      case 'discontinue':
        into.endingStops = true;
    }
  }

  /// The first number in an `<ending number>`, which may be a list (`"1, 2"`).
  ///
  /// A bracket covering two passes is one bracket, and the model holds one
  /// number, so the lowest is what gets drawn.
  int? _firstEndingNumber(String? attribute) {
    if (attribute == null) return null;
    for (final part in attribute.split(',')) {
      final value = int.tryParse(part.trim());
      if (value != null) return value;
    }
    return null;
  }

  /// The note at vertical [level] of [stack], counting down from the top.
  ///
  /// Levels below the shortest stack in a measure get a rest of the same length
  /// rather than nothing, so every retained stream stays rhythmically aligned
  /// with the melody.
  _Beat _beatAt(_Stack stack, int level) {
    final sorted = stack.sortedNotes;
    final top = sorted.first;
    if (level >= sorted.length) {
      return _Beat.rest(duration: top.duration, dotted: top.dotted);
    }

    final note = sorted[level];
    return _Beat(
      pitch: note.pitch,
      duration: note.duration,
      dotted: note.dotted,
      tieStart: note.tieStart,
      tieEnd: note.tieEnd,
      // Lyrics and chord symbols belong to the stack, not to one of its notes:
      // engravers hang the lyric off whichever notehead they like.
      lyrics: level == 0 ? stack.lyrics : const {},
      chord: level == 0 ? stack.chord : null,
    );
  }

  _Note _parseNote(XmlElement note, double divisions, _Notices notices) {
    final isRest = _childOf(note, 'rest') != null;
    final pitchElement = _childOf(note, 'pitch');

    var pitch = 'R';
    var pitchValue = -1;
    if (!isRest && pitchElement != null) {
      final step = _textOf(pitchElement, 'step');
      final octave = _textOf(pitchElement, 'octave');
      final alter = int.tryParse(_textOf(pitchElement, 'alter') ?? '') ?? 0;

      if (step != null && octave != null) {
        var accidental = '';
        if (alter > 0) accidental = '#';
        if (alter < 0) accidental = 'b';
        if (alter.abs() > 1) {
          // NotatedBeat.parsedPitch only accepts one accidental character, so a
          // double sharp/flat cannot round-trip; keep the direction and warn.
          notices.doubleAccidentals++;
        }
        pitch = '$step$accidental${octave.replaceAll(RegExp(r'[^0-9-]'), '')}';
        pitchValue = _pitchValue(step, alter, int.tryParse(octave) ?? 4);
      }
    }

    final dots = note.findElements('dot', namespace: '*').length;
    if (dots > 1) notices.multipleDots++;

    final (duration, derivedDot) = _durationOf(note, divisions, notices);

    return _Note(
      pitch: pitch,
      pitchValue: pitchValue,
      duration: duration,
      dotted: dots > 0 || derivedDot,
      tieStart: _hasTie(note, 'start'),
      tieEnd: _hasTie(note, 'stop'),
      lyrics: _parseLyrics(note),
    );
  }

  /// Resolves a note's written value, preferring `<type>` and falling back to
  /// `<duration>` divided by the part's `<divisions>`.
  ///
  /// The Python defaulted a missing `<type>` straight to a quarter note; the
  /// arithmetic fallback is free here and keeps a type-less file readable.
  (NoteDuration, bool) _durationOf(
    XmlElement note,
    double divisions,
    _Notices notices,
  ) {
    final type = _textOf(note, 'type');
    if (type != null && type.isNotEmpty) {
      final mapped = _durationTypes[type.toLowerCase()];
      if (mapped != null) return (mapped, false);
      notices.unsupportedTypes.add(type);
      // 32nd and shorter collapse onto the shortest value the model has;
      // breve/long collapse onto the longest.
      if (_longerThanWhole.contains(type.toLowerCase())) {
        return (NoteDuration.whole, false);
      }
      return (NoteDuration.sixteenth, false);
    }

    final ticks = double.tryParse(_textOf(note, 'duration') ?? '');
    if (ticks == null || ticks <= 0 || divisions <= 0) {
      return (NoteDuration.quarter, false);
    }

    final quarters = ticks / divisions;
    var best = NoteDuration.quarter;
    var bestDotted = false;
    var bestError = double.infinity;
    for (final candidate in NoteDuration.values) {
      for (final dotted in const [false, true]) {
        final value = dotted ? candidate.beats * 1.5 : candidate.beats;
        final error = (value - quarters).abs();
        if (error < bestError) {
          bestError = error;
          best = candidate;
          bestDotted = dotted;
        }
      }
    }
    return (best, bestDotted);
  }

  bool _hasTie(XmlElement note, String type) {
    for (final tie in note.findElements('tie', namespace: '*')) {
      if (tie.getAttribute('type') == type) return true;
    }
    // Ties are duplicated as <notations><tied>; some exporters write only that.
    for (final notations in note.findElements('notations', namespace: '*')) {
      for (final tied in notations.findElements('tied', namespace: '*')) {
        if (tied.getAttribute('type') == type) return true;
      }
    }
    return false;
  }

  /// Lyric syllables on a note, keyed by `<lyric number>` (`"1"` when absent).
  Map<String, String> _parseLyrics(XmlElement note) {
    final result = <String, String>{};
    for (final lyric in note.findElements('lyric', namespace: '*')) {
      final texts = lyric.findElements('text', namespace: '*');
      if (texts.isEmpty) continue;

      // Elisions ("to_a") arrive as several <text> children of one <lyric>.
      final buffer = texts.map((t) => t.innerText).join();
      if (buffer.isEmpty) continue;

      final syllabic = _textOf(lyric, 'syllabic');
      final continues = syllabic == 'begin' || syllabic == 'middle';
      final number = lyric.getAttribute('number') ?? '${result.length + 1}';
      result[number] = continues ? '$buffer-' : buffer;
    }
    return result;
  }

  /// Builds a displayable chord symbol from a `<harmony>` element.
  String? _parseHarmony(XmlElement harmony) {
    final root = _childOf(harmony, 'root');
    if (root == null) return null;

    final step = _textOf(root, 'root-step');
    if (step == null || step.isEmpty) return null;
    final alter = int.tryParse(_textOf(root, 'root-alter') ?? '') ?? 0;

    final buffer = StringBuffer(step);
    if (alter > 0) buffer.write('#');
    if (alter < 0) buffer.write('b');

    final kind = _childOf(harmony, 'kind');
    if (kind != null) {
      // MusicXML lets the exporter dictate the printed suffix; honour it,
      // because that is what the engraver chose to show.
      final printed = kind.getAttribute('text');
      if (printed != null && printed.isNotEmpty) {
        buffer.write(printed);
      } else {
        buffer.write(_chordSuffixes[kind.innerText.trim().toLowerCase()] ?? '');
      }
    }

    final bass = _childOf(harmony, 'bass');
    final bassStep = bass == null ? null : _textOf(bass, 'bass-step');
    if (bassStep != null && bassStep.isNotEmpty) {
      final bassAlter = int.tryParse(_textOf(bass!, 'bass-alter') ?? '') ?? 0;
      buffer.write('/$bassStep');
      if (bassAlter > 0) buffer.write('#');
      if (bassAlter < 0) buffer.write('b');
    }

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Score-level metadata
  // ---------------------------------------------------------------------------

  String? _readTitle(XmlElement root) {
    final work = _descendantOf(root, 'work');
    final workTitle = work == null ? null : _textOf(work, 'work-title');
    if (workTitle != null && workTitle.isNotEmpty) return workTitle;

    final movement = _descendantOf(root, 'movement-title')?.innerText.trim();
    if (movement != null && movement.isNotEmpty) return movement;

    // Engraved scores often carry the title only as free-standing credit text.
    for (final credit in root.findAllElements('credit', namespace: '*')) {
      final words = _textOf(credit, 'credit-words');
      if (words != null && words.isNotEmpty) return words;
    }
    return null;
  }

  String? _readKey(XmlElement root) {
    final key = _descendantOf(root, 'key');
    if (key == null) return null;
    final fifths = int.tryParse(_textOf(key, 'fifths') ?? '');
    if (fifths == null) return null;

    final minor = _textOf(key, 'mode')?.toLowerCase() == 'minor';
    final map = minor ? _minorKeys : _majorKeys;
    return map[fifths];
  }

  String? _readTimeSignature(XmlElement root) {
    final beats = _descendantOf(root, 'beats')?.innerText.trim();
    final beatType = _descendantOf(root, 'beat-type')?.innerText.trim();
    if (beats == null || beats.isEmpty || beatType == null || beatType.isEmpty) {
      return null;
    }
    return '$beats/$beatType';
  }

  Map<String, String> _readPartNames(XmlElement root) {
    final names = <String, String>{};
    for (final scorePart in root.findAllElements('score-part', namespace: '*')) {
      final id = scorePart.getAttribute('id');
      final name = _textOf(scorePart, 'part-name');
      if (id != null && name != null && name.isNotEmpty) names[id] = name;
    }
    return names;
  }

  // ---------------------------------------------------------------------------
  // Layout and lyrics
  // ---------------------------------------------------------------------------

  /// Flags the measures the file declared `implicit="yes"`.
  ///
  /// Carries the source's own answer rather than inferring one from the beat
  /// count. A bar short of the time signature is either a deliberate upbeat or a
  /// bar the transcription damaged, the two want opposite treatment, and only the
  /// file knows which — guessing would have made the correction editor either
  /// flag every upbeat hymn or excuse every dropped note.
  List<NotatedMeasure> _markPickups(
    List<NotatedMeasure> measures,
    Set<int> implicitOrdinals,
  ) {
    if (implicitOrdinals.isEmpty) return measures;
    return [
      for (var i = 0; i < measures.length; i++)
        if (implicitOrdinals.contains(i))
          measures[i].copyWith(isPickup: true)
        else
          measures[i],
    ];
  }

  /// Applies the repeat signs and volta brackets read from `<barline>`.
  ///
  /// The volta is the only part that needs state: MusicXML marks a bracket by
  /// its two ends, and [NotatedMeasure.volta] is carried by every measure the
  /// bracket covers, so the number is held open from `start` until the measure
  /// that stops it — inclusive, because the closing barline sits on the right of
  /// the last covered bar, not before it.
  ///
  /// A bracket the file never closes runs to the end of the piece. That is what
  /// an unterminated `<ending>` means on paper too, and guessing shorter would
  /// silently drop bars out of a repeat.
  List<NotatedMeasure> _applyBarlines(
    List<NotatedMeasure> measures,
    Map<int, _Barlines> barlines,
  ) {
    if (barlines.isEmpty) return measures;

    final result = <NotatedMeasure>[];
    int? openVolta;

    for (var i = 0; i < measures.length; i++) {
      final bars = barlines[i];
      openVolta = bars?.endingStart ?? openVolta;

      result.add(bars == null && openVolta == null
          ? measures[i]
          : measures[i].copyWith(
              repeatStart: bars?.repeatStart ?? false,
              repeatEnd: bars?.repeatEnd ?? false,
              volta: openVolta,
            ));

      if (bars?.endingStops ?? false) openVolta = null;
    }
    return result;
  }

  /// Ported from `add_line_breaks()`, with the file's own system breaks winning
  /// when it has any.
  ///
  /// The Python only knew the every-N-measures rule because Audiveris output it
  /// was fed had no reliable `<print>` markers; a hand-engraved file usually
  /// does, and its breaks match the printed page the singer knows.
  List<NotatedMeasure> _applyLineBreaks(
    List<NotatedMeasure> measures,
    Set<int> systemBreaks,
    int measuresPerLine,
  ) {
    if (measures.isEmpty) return measures;

    // A break recorded on measure i means "i starts a new system", i.e. the
    // break belongs after i-1. Index 0 is the start of the piece, not a break.
    final breakAfter = <int>{
      for (final ordinal in systemBreaks)
        if (ordinal > 0 && ordinal - 1 < measures.length) ordinal - 1,
    };

    // The fallback keys off "the file declared no systems at all", not off an
    // empty break set: a file whose only marker sits on measure 0 has still
    // told us its layout, and overlaying the arbitrary rule would fight it.
    if (systemBreaks.isEmpty) {
      if (measuresPerLine <= 0) return measures;
      for (var i = 0; i < measures.length - 1; i++) {
        if ((i + 1) % measuresPerLine == 0) breakAfter.add(i);
      }
    }

    return [
      for (var i = 0; i < measures.length; i++)
        // copyWith, not a fresh NotatedMeasure: this pass changes exactly one
        // flag, and spelling out the others made every field added to the model
        // a field this pass would silently drop. `isPickup` was lost that way.
        if (breakAfter.contains(i) && i < measures.length - 1)
          measures[i].copyWith(lineBreakAfter: true)
        else
          measures[i],
    ];
  }

  /// Rebuilds plain lyrics from the melody's syllables, one [Verse] per lyric
  /// line number.
  ///
  /// Syllables carry a trailing `-` when the word continues (from
  /// `<syllabic>begin/middle`), which is how the joiner knows "Is-" and "ten"
  /// are one word. The hyphen is a notation-side marker and is dropped from the
  /// verse text. Lines follow the notation's own line breaks, so the lyric
  /// lines match the printed systems.
  List<Verse> _buildVerses(
    List<NotatedMeasure> measures,
    List<String> lyricNumbers,
  ) {
    if (lyricNumbers.isEmpty) return const [];

    final verses = <Verse>[];
    for (var index = 0; index < lyricNumbers.length; index++) {
      final lines = <LyricLine>[];
      var buffer = StringBuffer();
      var chords = <ChordPosition>[];
      var pendingJoin = false;

      void endLine() {
        final text = buffer.toString().trim();
        if (text.isNotEmpty || chords.isNotEmpty) {
          lines.add(LyricLine(text: text, chords: chords));
        }
        buffer = StringBuffer();
        chords = <ChordPosition>[];
        pendingJoin = false;
      }

      for (final measure in measures) {
        for (final beat in measure.beats) {
          final all = beat.allSyllables;
          final syllable = index < all.length ? all[index] : '';
          final separated = syllable.isNotEmpty && buffer.isNotEmpty && !pendingJoin;

          // Chord symbols belong to the notated verse only — repeating them on
          // every lyric line would render the same chord three times. The
          // position has to land on the first character of the syllable, so it
          // accounts for the word separator that has not been written yet.
          if (index == 0 && beat.chord != null) {
            chords.add(ChordPosition(
              chord: beat.chord!,
              position: buffer.length + (separated ? 1 : 0),
            ));
          }

          if (syllable.isEmpty) continue;

          if (separated) buffer.write(' ');
          pendingJoin = syllable.endsWith('-');
          buffer.write(pendingJoin
              ? syllable.substring(0, syllable.length - 1)
              : syllable);
        }
        if (measure.lineBreakAfter) endLine();
      }
      endLine();

      if (lines.isEmpty) continue;
      verses.add(Verse(
        number: int.tryParse(lyricNumbers[index]) ?? index + 1,
        hasNotation: index == 0,
        lines: lines,
      ));
    }
    return verses;
  }

  List<String> _orderedLyricNumbers(Iterable<_Stream> streams) {
    final numbers = <String>{};
    for (final stream in streams) {
      for (final beats in stream.measures.values) {
        for (final beat in beats) {
          numbers.addAll(beat.lyrics.keys);
        }
      }
    }

    final sorted = numbers.toList()
      ..sort((a, b) {
        final left = int.tryParse(a);
        final right = int.tryParse(b);
        if (left != null && right != null) return left.compareTo(right);
        if (left != null) return -1;
        if (right != null) return 1;
        return a.compareTo(b);
      });
    return sorted;
  }

  /// Melody-first ordering: part, then staff, then voice, with chord-derived
  /// streams always sorting behind the voices the file actually declared.
  int _compareStreams(_Stream a, _Stream b) {
    var result = a.partIndex.compareTo(b.partIndex);
    if (result != 0) return result;
    result = a.staff.compareTo(b.staff);
    if (result != 0) return result;
    result = a.chordLevel.compareTo(b.chordLevel);
    if (result != 0) return result;
    result = a.voiceOrder.compareTo(b.voiceOrder);
    if (result != 0) return result;
    return a.voice.compareTo(b.voice);
  }

  // ---------------------------------------------------------------------------
  // Small helpers
  // ---------------------------------------------------------------------------

  static XmlElement? _childOf(XmlNode node, String name) =>
      node.findElements(name, namespace: '*').firstOrNull;

  static XmlElement? _descendantOf(XmlNode node, String name) =>
      node.findAllElements(name, namespace: '*').firstOrNull;

  static String? _textOf(XmlNode node, String name) =>
      _childOf(node, name)?.innerText.trim();

  static int _pitchValue(String step, int alter, int octave) {
    const semitones = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final base = semitones[step.toUpperCase()] ?? 0;
    return (octave + 1) * 12 + base + alter;
  }

  static const _durationTypes = <String, NoteDuration>{
    'whole': NoteDuration.whole,
    'half': NoteDuration.half,
    'quarter': NoteDuration.quarter,
    'eighth': NoteDuration.eighth,
    '16th': NoteDuration.sixteenth,
    'sixteenth': NoteDuration.sixteenth,
  };

  static const _longerThanWhole = {'breve', 'long', 'maxima'};

  static const _majorKeys = <int, String>{
    0: 'C', 1: 'G', 2: 'D', 3: 'A', 4: 'E', 5: 'B', 6: 'F#', 7: 'C#',
    -1: 'F', -2: 'Bb', -3: 'Eb', -4: 'Ab', -5: 'Db', -6: 'Gb', -7: 'Cb',
  };

  static const _minorKeys = <int, String>{
    0: 'Am', 1: 'Em', 2: 'Bm', 3: 'F#m', 4: 'C#m', 5: 'G#m', 6: 'D#m',
    7: 'A#m', -1: 'Dm', -2: 'Gm', -3: 'Cm', -4: 'Fm', -5: 'Bbm', -6: 'Ebm',
    -7: 'Abm',
  };

  static const _chordSuffixes = <String, String>{
    'major': '',
    'none': '',
    'minor': 'm',
    'augmented': 'aug',
    'diminished': 'dim',
    'dominant': '7',
    'major-seventh': 'maj7',
    'minor-seventh': 'm7',
    'diminished-seventh': 'dim7',
    'half-diminished': 'm7b5',
    'major-sixth': '6',
    'minor-sixth': 'm6',
    'dominant-ninth': '9',
    'major-ninth': 'maj9',
    'minor-ninth': 'm9',
    'suspended-second': 'sus2',
    'suspended-fourth': 'sus4',
    'power': '5',
  };
}

// -----------------------------------------------------------------------------
// Parsing scratch types (private)
// -----------------------------------------------------------------------------

/// Counters for lossy conversions, folded into warnings once per import so a
/// long score does not produce one warning per note.
class _Notices {
  int graceNotes = 0;
  int chordStacks = 0;
  int doubleAccidentals = 0;
  int multipleDots = 0;
  final Set<String> unsupportedTypes = {};

  List<String> get messages => [
        if (graceNotes > 0)
          '$graceNotes grace note${graceNotes == 1 ? '' : 's'} skipped: the '
              'notation model has no grace-note beat.',
        if (chordStacks > 0)
          '$chordStacks chord${chordStacks == 1 ? '' : 's'} reduced to the top '
              'note; the lower notes are kept in additionalVoices.',
        if (doubleAccidentals > 0)
          '$doubleAccidentals double accidental'
              '${doubleAccidentals == 1 ? '' : 's'} approximated to a single '
              'sharp/flat — the model stores one accidental character.',
        if (multipleDots > 0)
          '$multipleDots double-dotted note${multipleDots == 1 ? '' : 's'} '
              'imported as single-dotted.',
        if (unsupportedTypes.isNotEmpty)
          'Unsupported note value${unsupportedTypes.length == 1 ? '' : 's'} '
              '(${(unsupportedTypes.toList()..sort()).join(', ')}) approximated '
              'to the nearest value the app can draw.',
      ];
}

/// A note as read from XML, before lyric numbering is known.
class _Note {
  final String pitch;
  final int pitchValue;
  final NoteDuration duration;
  final bool dotted;
  final bool tieStart;
  final bool tieEnd;
  final Map<String, String> lyrics;

  const _Note({
    required this.pitch,
    required this.pitchValue,
    required this.duration,
    required this.dotted,
    required this.tieStart,
    required this.tieEnd,
    required this.lyrics,
  });
}

/// One rhythmic position in a voice: a note plus any `<chord>` notes on it.
class _Stack {
  final int staff;
  final String voice;
  final List<_Note> notes;
  String? chord;

  _Stack({required this.staff, required this.voice, required _Note note})
      : notes = [note];

  /// Highest sounding note first — the melody reduction applied vertically.
  List<_Note> get sortedNotes =>
      notes.length == 1
          ? notes
          : (notes.toList()..sort((a, b) => b.pitchValue.compareTo(a.pitchValue)));

  /// Lyrics attached anywhere in the stack.
  Map<String, String> get lyrics {
    for (final note in notes) {
      if (note.lyrics.isNotEmpty) return note.lyrics;
    }
    return const {};
  }
}

/// A [NotatedBeat] whose syllables are still keyed by lyric line number.
class _Beat {
  final String pitch;
  final NoteDuration duration;
  final bool dotted;
  final bool tieStart;
  final bool tieEnd;
  final Map<String, String> lyrics;
  final String? chord;

  const _Beat({
    required this.pitch,
    required this.duration,
    required this.dotted,
    required this.tieStart,
    required this.tieEnd,
    required this.lyrics,
    required this.chord,
  });

  const _Beat.rest({required this.duration, required this.dotted})
      : pitch = 'R',
        tieStart = false,
        tieEnd = false,
        lyrics = const {},
        chord = null;

  NotatedBeat toNotatedBeat(List<String> lyricNumbers) {
    String? syllable;
    List<String>? syllables;

    if (lyrics.isNotEmpty) {
      syllable = lyrics[lyricNumbers.first] ?? lyrics.values.first;
      if (lyricNumbers.length > 1) {
        syllables = [for (final n in lyricNumbers) lyrics[n] ?? ''];
      }
    }

    return NotatedBeat(
      pitch: pitch,
      duration: duration,
      syllable: syllable,
      syllables: syllables,
      chord: chord,
      tieStart: tieStart,
      tieEnd: tieEnd,
      dotted: dotted,
    );
  }
}

/// One (part, staff, voice, chord level) note stream under construction.
class _Stream {
  final int partIndex;
  final String partId;
  final String? partName;
  final int staff;
  final String voice;

  /// 0 for the voice's own notes, 1+ for notes split out of a `<chord>`.
  final int chordLevel;

  /// Measure ordinal within the part -> beats. Sparse: a voice that is silent
  /// for a bar simply has no entry, and the gap is filled in at output time so
  /// ordinals stay aligned across streams.
  final Map<int, List<_Beat>> measures = {};

  _Stream({
    required this.partIndex,
    required this.partId,
    required this.partName,
    required this.staff,
    required this.voice,
    required this.chordLevel,
  });

  bool get isChordMember => chordLevel > 0;

  /// Numeric `<voice>` for sorting; unparseable voices sort last.
  int get voiceOrder => int.tryParse(voice) ?? 1 << 20;

  bool get hasBeats => measures.values.any((beats) => beats.isNotEmpty);

  String get voiceId => chordLevel == 0 ? voice : '$voice#${chordLevel + 1}';

  List<NotatedMeasure> toMeasures(List<String> lyricNumbers) {
    if (measures.isEmpty) return const [];
    final last = measures.keys.reduce((a, b) => a > b ? a : b);
    return [
      for (var ordinal = 0; ordinal <= last; ordinal++)
        NotatedMeasure(
          beats: [
            for (final beat in measures[ordinal] ?? const <_Beat>[])
              beat.toNotatedBeat(lyricNumbers),
          ],
        ),
    ];
  }

  ImportedVoice toImportedVoice(List<NotatedMeasure> measures) => ImportedVoice(
        partId: partId,
        partIndex: partIndex,
        partName: partName,
        staff: staff,
        voiceId: voiceId,
        isChordMember: isChordMember,
        measures: measures,
      );
}
