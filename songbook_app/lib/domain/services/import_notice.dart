/// What an importer or a parser wants to tell whoever ran it.
///
/// The services that raise these — `ChordSheetParser` and `MusicXmlImporter` —
/// are pure domain code with no `BuildContext`, so they cannot build a sentence
/// in the language the app is being read in. Building one anyway is what left
/// these messages in English while every other string in the app was
/// translated: a Hungarian screen with English warnings on it.
///
/// So a notice names *what happened* and carries the facts about it, and the
/// prose lives in exactly one place — `AppLocalizations.importNoticeText` in the
/// presentation layer. Nothing here is user-visible.
enum ImportNoticeCode {
  // ---------------------------------------------------------------------------
  // ChordSheetParser
  // ---------------------------------------------------------------------------

  /// A `{directive}` the parser does not implement.
  /// Carries [ImportNotice.line] and [ImportNotice.text].
  unknownDirective,

  /// A line that could be a one-chord line or a lyric, resolved towards lyrics.
  /// Carries [ImportNotice.line] and [ImportNotice.text].
  ambiguousBareRoot,

  /// A `[…]` marker whose contents are not a chord symbol, kept as lyric text.
  /// Carries [ImportNotice.line] and [ImportNotice.text] — the token *without*
  /// its brackets, so the formatter can punctuate it per language.
  bracketNotAChord,

  // ---------------------------------------------------------------------------
  // MusicXmlImporter — lossy, but the score still imports
  // ---------------------------------------------------------------------------

  /// A `score-timewise` document, whose measures may be grouped wrongly.
  timewiseScore,

  /// The document held no notes at all.
  noNotes,

  /// Voices beyond the melody, kept on the song rather than engraved.
  /// Carries [ImportNotice.count].
  extraVoicesKept,

  /// Grace notes dropped — the notation model has no grace-note beat.
  /// Carries [ImportNotice.count].
  graceNotesSkipped,

  /// `<chord>` stacks reduced to their top note.
  /// Carries [ImportNotice.count].
  chordsReducedToTopNote,

  /// Double sharps/flats stored as a single accidental character.
  /// Carries [ImportNotice.count].
  doubleAccidentalsApproximated,

  /// Double-dotted notes imported as single-dotted.
  /// Carries [ImportNotice.count].
  doubleDotsReduced,

  /// `<type>` values the model cannot draw, approximated to the nearest it can.
  /// Carries [ImportNotice.text] — the values, already sorted and joined — and
  /// [ImportNotice.count], which only picks singular from plural.
  unsupportedNoteValues,

  // ---------------------------------------------------------------------------
  // MusicXmlImporter — fatal, thrown as a MusicXmlImportException
  // ---------------------------------------------------------------------------

  /// Nothing but whitespace was handed over as MusicXML.
  emptyXmlInput,

  /// The document is not well-formed XML.
  /// Carries [ImportNotice.text] — the XML parser's own reason.
  invalidXml,

  /// An `.mxl` container manifest was passed where a score was expected.
  containerManifestNotScore,

  /// No bytes at all were handed over as an `.mxl` archive.
  emptyMxlInput,

  /// The bytes are not a readable zip archive.
  /// Carries [ImportNotice.text] — the decoder's own reason.
  unreadableArchive,

  /// The archive holds no MusicXML entry to read.
  noScoreInArchive,
}

/// One [ImportNoticeCode] plus the typed facts that code needs.
///
/// Deliberately one class with optional fields rather than a subclass per code:
/// the set of arguments across all of them is small — a line number, a count, a
/// piece of text — and the formatter switches on the code exhaustively anyway,
/// so a sealed hierarchy would buy nothing and cost seventeen classes.
class ImportNotice {
  final ImportNoticeCode code;

  /// 1-based line in the source text, for the codes that name one.
  final int? line;

  /// How many times the thing happened, for the codes that count. Also the
  /// plural selector for those messages.
  final int? count;

  /// The offending source text, or the underlying reason for a failure.
  final String? text;

  const ImportNotice(this.code, {this.line, this.count, this.text});

  @override
  bool operator ==(Object other) =>
      other is ImportNotice &&
      other.code == code &&
      other.line == line &&
      other.count == count &&
      other.text == text;

  @override
  int get hashCode => Object.hash(code, line, count, text);

  /// Debug output. Never show this to a user — it names the enum rather than
  /// reading as a sentence, which is what makes an accidental leak obvious.
  @override
  String toString() {
    final parts = <String>[
      code.name,
      if (line != null) 'line: $line',
      if (count != null) 'count: $count',
      if (text != null) 'text: $text',
    ];
    return 'ImportNotice(${parts.join(', ')})';
  }
}
