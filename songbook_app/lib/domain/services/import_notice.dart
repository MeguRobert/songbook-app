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

  /// A `-7`-style continuation token with no chord in front of it to extend, so
  /// it was dropped. Carries [ImportNotice.line] and [ImportNotice.text].
  continuationWithoutChord,

  /// Prose from the photo-reading backend, passed through verbatim.
  ///
  /// The one code whose text is NOT translated, and deliberately so: it is
  /// written by a remote service that does not know what language the app is
  /// being read in, so the honest thing is to quote it rather than to pretend it
  /// is ours. Carries [ImportNotice.text].
  fromReader,

  /// A `[…]` marker whose contents are not a chord symbol, kept as lyric text.
  /// Carries [ImportNotice.line] and [ImportNotice.text] — the token *without*
  /// its brackets, so the formatter can punctuate it per language.
  bracketNotAChord,

  // ---------------------------------------------------------------------------
  // The photo reader — PageTextRecognizer and PhotoTextBridge
  // ---------------------------------------------------------------------------
  //
  // Four of these used to be English sentences built inside
  // `photo_text_bridge.dart` and handed up the pipeline as plain strings, which
  // is why they were the last untranslated text a user could see. Two more were
  // measured and never raised at all: the Python worker told the user their
  // photo was too compressed to hold `ő`, and the app — which does the same
  // measurement — said nothing. One of those two was then withdrawn again on the
  // evidence; see [photoShowThroughRemoved].

  /// The photograph is too compressed to hold the fine strokes.
  ///
  /// The single biggest lever on accuracy, and the fix is on the phone rather
  /// than in this app: a gallery hands over a re-encoded copy, and no amount of
  /// parsing recovers a diacritic the compression deleted. Carries
  /// [ImportNotice.text] — the pixel size, as `1532×2047` — and
  /// [ImportNotice.count], the file's size in kilobytes.
  photoLowResolution,

  /// A second, paler population of ink was found and erased before reading.
  ///
  /// **Nothing emits this.** Kept, with its three translations, because a
  /// notice is cheap to hold and expensive to re-translate — the same reason
  /// [ambiguousBareRoot] is still here.
  ///
  /// It was raised for one release and then withdrawn on the measurement.
  /// `PagePreprocessor.hasShowThrough` was calibrated against the Python
  /// original's flattening and never against the Dart port's: under the port
  /// every page in the corpus sits between 0.0139 and 0.0451 against a 0.012
  /// gate, so the gate has never excluded a page, and the born-digital
  /// screenshot scores higher than the page whose reverse side really is
  /// legible through the paper. A warning that fires on every import and names
  /// a cause it cannot establish tells the user nothing.
  ///
  /// The cleaning it described stays on, because it is not really ghost removal
  /// — it flattens the lighting and stretches the levels, and the reader needs
  /// that almost everywhere. Turning it off costs 0.156 of the corpus mean.
  photoShowThroughRemoved,

  /// The page holds more than one song, side by side, and all were read.
  /// Carries [ImportNotice.count] — how many.
  photoTwoSongs,

  /// Words were read but no chord row was recognised anywhere on the page.
  photoNoChords,

  /// Nothing on the page could be read at all.
  photoNothingLegible,

  /// The browser refused to decode the file, so no pixels were ever read.
  ///
  /// A different failure from [photoNothingLegible] and it needs different
  /// advice, which is the whole reason it exists. "Nothing legible" means the
  /// engine looked at the page and found no words — taking the photograph again
  /// is the answer. This means the image never opened: `createImageBitmap`
  /// threw, before a single pixel was read, and taking the same photograph
  /// again produces the same file and the same refusal.
  ///
  /// Two causes fit, and the sentence names both because the app cannot tell
  /// them apart and the user can. Some phones store photographs as HEIC —
  /// Xiaomi's "high efficiency" setting, on by default — which no Chrome
  /// decodes. And a scrolled screenshot tens of thousands of pixels tall can
  /// simply be beyond what a phone's decoder will allocate. Re-saving as JPEG
  /// or PNG answers the first; capturing in shorter pieces answers the second.
  ///
  /// [ImageFormat] in the diagnostic row is what tells the two apart
  /// afterwards — see `sniffImageFormat`. It is deliberately not in the
  /// sentence: naming a container to somebody holding a phone explains nothing,
  /// and the advice is the same either way.
  photoCouldNotDecode,

  /// German note names were read and will be stored under their English
  /// spelling. Carries [ImportNotice.text] — the names, sorted and joined.
  photoGermanNoteNames,

  /// A bare lowercase `c` on a chord row was stored as `C` major rather than as
  /// C minor. Carries [ImportNotice.count] — how many.
  ///
  /// `C` and `c` are the same shape at two sizes, and no other note letter is:
  /// `a`, `b`, `d`, `e`, `f`, `g` and `h` all change form between cases, so an
  /// engine returning one of those in lowercase read a lowercase letter. A
  /// small `c` on a photographed chord row is almost always a capital the
  /// reader mis-sized — measured on `084-van-egy-ut`, which prints italic
  /// capital `C` twelve times and gave back `c` six times, and on
  /// `125-nincs-mas-isten`, three times.
  ///
  /// Central European songbooks really do write case for quality, though, and
  /// no photograph can prove which was meant. So this says what it did rather
  /// than deciding in silence: the review box is editable ChordPro, and `Cm` is
  /// two keystrokes.
  photoLowercaseCRaised,

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
