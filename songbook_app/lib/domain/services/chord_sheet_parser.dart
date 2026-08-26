import '../../core/utils/chord_transposer.dart';
import '../../data/models/chord_position.dart';
import '../../data/models/lyric_line.dart';
import '../../data/models/verse.dart';
import 'import_notice.dart';

/// Which lines a person has overruled the parser about.
///
/// [ChordSheetParser.isChordLine] is right about almost every row, and where it
/// is wrong it is usually because a glyph was misread — `Csus2` coming back as
/// `5US2` leaves the row one unrecognised token over the tolerance, so the whole
/// thing reads as lyrics. The fix for that is to correct the token, after which
/// the parser agrees by itself and nothing here is needed.
///
/// This is for the residue: a row the reader cannot be talked into classifying
/// correctly, which a person holding the page can see plainly. The import screen
/// offers it per line.
///
/// **Sparse on purpose.** An entry exists only where somebody disagreed with the
/// parser, so an empty [LineKinds] means "the parser decides everything" — which
/// is the behaviour that shipped before this existed, to the character. Nothing
/// is recorded that the parser can work out for itself, so there is no second
/// opinion to keep in step with the first.
///
/// Indexes are into the lines of the text as split by [ChordSheetParser.parse],
/// counting blank lines and directives, and they are only meaningful against the
/// text they were made from. An index past the end is ignored rather than
/// throwing: the screen clears these whenever it re-parses, and a stale one
/// arriving anyway should not take the import down.
enum LineKind { chords, lyric }

class LineKinds {
  const LineKinds(this._byIndex);

  const LineKinds.none() : _byIndex = const {};

  final Map<int, LineKind> _byIndex;

  bool get isEmpty => _byIndex.isEmpty;

  /// What line [index] was overruled to be, or null when nobody said.
  LineKind? kindOf(int index) => _byIndex[index];

  /// Null when nobody said, so a caller can fall through to the parser's own
  /// answer with `?? isChordLine(raw)` rather than having to ask twice.
  bool? isChords(int index) => switch (_byIndex[index]) {
        LineKind.chords => true,
        LineKind.lyric => false,
        null => null,
      };

  /// Whether line [index] may serve as the lyric under a chord row. The mirror
  /// of [isChords], and separate because the parser asks the two questions of
  /// different lines.
  bool? isLyric(int index) => switch (_byIndex[index]) {
        LineKind.lyric => true,
        LineKind.chords => false,
        null => null,
      };

  /// The same overrides with [index] set to [kind].
  LineKinds withLine(int index, LineKind kind) =>
      LineKinds({..._byIndex, index: kind});

  /// The same overrides with [index] left to the parser again.
  ///
  /// What a corrected token does. The row is re-read on its merits, because the
  /// reason for the override is gone — an override that outlives its evidence
  /// keeps a row claiming to be chords long after that stopped being true.
  LineKinds withoutLine(int index) =>
      LineKinds({..._byIndex}..remove(index));
}

/// The result of parsing a pasted chord sheet.
///
/// Directives are optional in real-world pastes, so [title] and [key] are null
/// whenever the source did not declare them — callers must treat them as hints,
/// never as guaranteed data.
class ParsedChordSheet {
  /// Verses in source order, numbered from 1.
  final List<Verse> verses;

  /// Value of `{title:}` / `{t:}`, if present.
  final String? title;

  /// Value of `{key:}` / `{k:}`, if present.
  final String? key;

  /// Free text from `{c:}` / `{comment:}` directives, in source order.
  final List<String> comments;

  /// Numbers of the verses that sat inside a `{soc}` … `{eoc}` block.
  ///
  /// [Verse] has no chorus flag, so the marking is reported here rather than
  /// forcing a model change on every consumer of the song data.
  final Set<int> chorusVerseNumbers;

  /// Non-fatal problems: ambiguous lines, brackets that were not chords,
  /// directives we did not understand. Each entry names the source line.
  ///
  /// Codes rather than sentences. This parser has no `BuildContext` and the app
  /// is read in three languages, so it says what happened and the presentation
  /// layer says it in words — see [ImportNotice].
  final List<ImportNotice> warnings;

  const ParsedChordSheet({
    this.verses = const [],
    this.title,
    this.key,
    this.comments = const [],
    this.chorusVerseNumbers = const {},
    this.warnings = const [],
  });

  /// True when nothing parseable was found.
  bool get isEmpty => verses.isEmpty;

  @override
  String toString() => 'ParsedChordSheet(verses: ${verses.length}, '
      'title: $title, key: $key, warnings: ${warnings.length})';
}

/// Parses pasted chord-sheet text into [Verse]s.
///
/// Three input shapes are accepted, and they may be mixed in one paste:
///
/// 1. Inline / ChordPro brackets — `[G]Amazing [C]grace`
/// 2. Chords on the line above the lyrics:
///    ```
///    G       C
///    Amazing grace
///    ```
/// 3. Plain lyrics with no chords at all.
///
/// Both chorded shapes collapse to the same output because
/// [ChordPosition.position] is a character index into [LyricLine.text]: a
/// bracket's position is the length of the text stripped so far, and a chord
/// token's position in shape 2 is its column in the line above. Neither shape
/// loses information.
///
/// A blank line ends a verse. Verses are numbered from 1 and carry
/// `hasNotation: false` — engraved notation comes from a different source.
class ChordSheetParser {
  const ChordSheetParser();

  /// Strict chord token, used only to DECIDE WHETHER a token is a chord.
  ///
  /// This must never be merged with `ChordTransposer`'s `^([A-GH][#b]?)(.*)$`.
  /// There, quality is `.*` — correct for transposing a token already known to
  /// be a chord, and catastrophic as a detector, because every word starting
  /// with A–H "matches". Hungarian lyrics are full of them: `Csak Egy Az`
  /// reads as C+"sak", E+"gy", A+"z", so the whole line would be classified as
  /// chords and its words silently destroyed. Hence the quality whitelist.
  /// (`ChordTransposer` is imported here only to rename `H`, never to detect.)
  ///
  /// `H` is B natural in Hungarian, German and Polish notation, so it is a root
  /// like any other; [ChordTransposer.toEnglishNotation] renames it on the way
  /// into storage. Admitting it costs one collision: `Hadd` is a Hungarian word
  /// that parses as H+add. [isChordLine] contains it: a line needs every token
  /// but at most one to be chord-shaped, and `hadd` introduces a clause, so it
  /// arrives with two or three ordinary words beside it. Only a line consisting
  /// of that single word is misread, which no real song produces.
  ///
  /// Extensions may carry their own accidental (`Em7b5`, `C7#9`) — that `b` is
  /// part of a numbered extension, which is why it is only allowed in front of
  /// digits and not as a bare trailing letter (`Bbb` is not a chord here).
  /// A lowercase root means minor in Central European notation — `em` is E
  /// minor — and Hungarian songbooks print it that way throughout. Admitting it
  /// is what stopped every row carrying an `em` from importing as lyrics.
  /// [ChordTransposer.toEnglishNotation] raises the case and marks the chord
  /// minor on the way into storage.
  ///
  /// An accidental may also be **spelled out**, which is how Hungarian and
  /// German print it: `isz`/`is` is a sharp (`fiszm` is F sharp minor, `Fis` is
  /// F sharp) and `esz`/`sz` is a flat (`Esz` is E flat, `Desz` is D flat).
  /// Measured: `fiszm` alone cost `166-tekozlo-fiu` three of its ten chord rows,
  /// because the all-or-nothing rule threw every chord on those rows away with
  /// it. A bare `s` is deliberately NOT a flat, German short forms
  /// notwithstanding — it would read `Gsus2` as G flat and `us2`.
  ///
  /// Chords joined by hyphens are one token, because that is how the book prints
  /// two chords played in succession over one syllable: `Amaj7-A7`,
  /// `Cadd9-Csus2`, `G5-Gsus2`, `D-E`. Every part has to be a chord on its own,
  /// which is what keeps `ici-picit` a word. [chordsIn] separates them again on
  /// the way into storage, so nothing ever transposes a symbol naming two
  /// pitches.
  static const _accidental = r'(?:#|b|isz|is|esz|sz)';
  static const _oneChord = '[A-GHa-gh]$_accidental?'
      r'(?:maj|min|m|dim|aug|sus|add|\+|°|[#b]?\d+)*'
      '(?:/[A-GHa-gh]$_accidental?)?';
  static final RegExp _chordToken = RegExp('^(?:$_oneChord)(?:-(?:$_oneChord))*\$');

  /// One chord symbol, with hyphen runs excluded — see [isSingleChord].
  static final RegExp _oneChordToken = RegExp('^$_oneChord\$');

  /// How many recognised chords a row needs before ONE unrecognised token is
  /// tolerated instead of making the whole row lyrics. See [isChordLine] for
  /// what these cost and what they bought.
  static const _tolerateAfter = 3;
  static const _tolerateAfterOddToken = 2;

  /// What a Hungarian word looks like and a misread chord does not: plain
  /// lowercase letters, no capital, no digit, no symbol.
  static final RegExp _lowercaseWord = RegExp(r'^[a-záéíóöőúüű]+$');

  /// `-7`, `-m` — the chord before this one, with something added.
  ///
  /// The songbook writes `A  -7  D` where `-7` is the same A carrying a
  /// seventh, which saves reprinting the letter. It names no pitch by itself,
  /// so it is not a chord token: without the chord to its left it means nothing
  /// and is dropped rather than guessed at.
  static final RegExp _continuation = RegExp(r'^[-–—](.+)$');

  // A line whose only chord is a bare root — `A`, `d`, `A -` — used to be
  // resolved towards lyrics by a `_bareRoot` regex here. The argument was that
  // `A` is the Hungarian definite article and losing a chord is recoverable
  // where losing a line of words is not.
  //
  // The rule is gone, because that argument does not survive the corpus. The
  // ambiguity only arises when a root letter stands *among words*, and
  // [isChordLine] already keeps such a line as lyrics: one chord and one
  // unrecognised token is under the tolerance floor, which is exactly where
  // `A szívemben` sits. A line holding nothing but one letter is not a lyric —
  // not in a hymnal.
  //
  // What it cost, measured: `084-van-egy-ut` prints `C` over one line and `G`
  // over the next, `151-zengjed-a-dalt` prints `D` and `A`. Four real chords on
  // two pages, every one of them stored as a word.
  //
  // The residual risk is a recogniser isolating a genuine one-letter word onto
  // a line of its own. Accepted deliberately: it is rare, and the moderation
  // queue exists to catch it. [ImportNoticeCode.ambiguousBareRoot] is kept and
  // still formats, but nothing emits it any more.

  /// Punctuation a chord row may carry that is not itself a chord.
  ///
  /// Real chord sheets are punctuated — `C - D`, `| C | G |`, `|: C G :|`,
  /// `C G x2` — and requiring *every* token to be a chord classified all of
  /// those as lyrics. The consequence was not cosmetic: the chords were stored
  /// as words, so the imported song had no chords to transpose at all.
  ///
  /// Deliberately excludes `/`. A lone slash means "another beat of the same
  /// chord" in real charts (`C / / /`), and treating it as filler would make a
  /// row of slashes indistinguishable from punctuation.
  ///
  /// A lone bracket or quote is included, and has to be. Songbooks write an
  /// optional chord with spaces inside the brackets — `G  ( C )` — and a
  /// recogniser sometimes returns a stray apostrophe where a chord's glyph was.
  /// Either one is a token that names no pitch and is not a word, and without
  /// this the whole row read as lyrics. `(C)` written closed still goes through
  /// [_parenthesised], where the brackets are the evidence that it is a chord.
  ///
  /// This must stay in step with `_SEPARATOR` in `tools/photo_import_worker.py`.
  /// The worker emits laid-out text and this parser reads it back, so a token
  /// one side treats as punctuation and the other as a word turns a whole row
  /// of chords into a line of lyrics on the way into storage.
  /// Triple-quoted because the character class holds both quote marks, and a
  /// raw string cannot escape its own delimiter.
  static final RegExp _separator = RegExp(
    r'''^(?:[-–—]+|\|+|:\||\|:|\|\||[xX]\d+|\d+[xX]|[()\[\]'‘’"]+)$''',
  );

  /// A chord wrapped in brackets — `(Em)` — which real sheets use for a passing
  /// or optional chord. The stored symbol is the chord itself: the transposer is
  /// handed a root plus quality, and `(Em)` is neither.
  static final RegExp _parenthesised = RegExp(r'^\((.+)\)$');

  /// A section name printed inline on a chord row: an instruction to the
  /// player, not music.
  ///
  /// `109-tart-meg-a-kegyelem` in the measurement corpus sets
  /// `B  Asus4  A  - Intro x1` and `Gm  A7  Dm  - Intro`. The dash and the `x1`
  /// were already [_separator]s, so the word was the one unrecognised token the
  /// row tolerates — kept, and stored as a chord in the column the page printed
  /// the word in. The harness said so itself: *chord symbols the token rule
  /// cannot spell: Intro*, which is a chord no reading can ever get right.
  ///
  /// The tolerance is for a MISREAD chord, and a stage direction is not one. It
  /// is skipped like punctuation instead, which also gives the row its one
  /// tolerance back for a genuine misread beside the direction.
  ///
  /// Only ever asked about a token [isChordToken] has already refused, which is
  /// what makes this unable to lose a chord: `Coda` and `Bridge` open with note
  /// letters, and a chord spelling that collided with one of these words would
  /// still be read as the chord.
  ///
  /// Capitalised, and case-sensitively so. That is how a page prints an
  /// instruction, and `intro`, `verse`, `cor`, `tag` and `solo` are ordinary
  /// words in one language or another; a lowercase one stays the row's single
  /// tolerated token, which is the behaviour that was already there. Accented
  /// and unaccented spellings both, because the recogniser drops accents.
  ///
  /// This must stay in step with `_DIRECTION` in
  /// `tools/photo_import_worker.py`, for the same reason [_separator] must:
  /// the worker emits laid-out text and this parser reads it back.
  static final RegExp _direction = RegExp(
    r'^(?:Intro|Outro|Coda|Bridge|Chorus|Verse'
    r'|Refr[eé]n|Versszak|[AÁ]tvezet[oő]'
    r'|Ism[eé]tl[eé]s|Strof[aă])[.:]?$',
  );


  /// [token] with any surrounding parentheses removed.
  static String _unwrap(String token) =>
      _parenthesised.firstMatch(token)?.group(1) ?? token;

  /// `{name}` or `{name: value}` occupying a whole line.
  static final RegExp _directive =
      RegExp(r'^\{\s*([^:}]+?)\s*(?::\s*(.*?)\s*)?\}$');

  static final RegExp _hasBracket = RegExp(r'\[[^\]]*\]');

  static final RegExp _token = RegExp(r'\S+');

  /// The tokens of [line], each with the column it starts at.
  ///
  /// Public so the import screen's line list can show a row as chips without
  /// re-inventing the split. A chip has to BE a token - the same run of
  /// non-whitespace this parser reads - or tapping one would edit something the
  /// parser never saw, and the two would drift apart the first time either
  /// changed.
  List<(String, int)> tokensIn(String line) =>
      [for (final m in _token.allMatches(line)) (m.group(0)!, m.start)];

  /// Returns true when [token] is unambiguously a chord symbol.
  ///
  /// Surrounding parentheses are tolerated, so `(Em)` is a chord.
  /// Whitespace is not: callers split lines into tokens first.
  ///
  /// A run of chords joined by hyphens counts as one token, because that is how
  /// the book prints two chords played in succession over one syllable:
  /// `Amaj7-A7`, `Cadd9-Csus2`, `G5-Gsus2`, `D-E`. Every part has to be a chord
  /// on its own, which is what keeps `ici-picit` a word. They are separated
  /// again on the way into storage — see [chordsIn] — so nothing downstream ever
  /// has to transpose a symbol naming two pitches.
  bool isChordToken(String token) => _chordToken.hasMatch(_unwrap(token));

  /// Returns true when [token] is ONE chord symbol, hyphen runs excluded.
  ///
  /// The distinction matters to [PhotoTextBridge.splitMergedChords], which pulls
  /// a merged run apart on its glyph boxes and must not stop just because the
  /// merged text now reads as a chord: `G-C-D-C` arrives from a row printed
  /// `G - C - D - ( C )` with real spaces in it, and the glyph boxes put each
  /// chord back where the page had it. Character offsets inside the merged token
  /// cannot - the run is set far wider than its letters.
  bool isSingleChord(String token) => _oneChordToken.hasMatch(_unwrap(token));

  /// The chords in [token], and where each sits relative to its start.
  ///
  /// One entry for an ordinary chord, and one per part for a hyphen-joined run:
  /// `Cadd9-Csus2` is two chords, and storing it as one would leave a symbol
  /// `ChordTransposer` cannot transpose — it rewrites the first root and carries
  /// the rest verbatim, so `Amaj7-A7` up a tone would come out as `Bmaj7-A7`
  /// with the second chord silently in the wrong key.
  List<(String, int)> chordsIn(String token) {
    final bare = _unwrap(token);
    if (_oneChordToken.hasMatch(bare)) return [(bare, 0)];
    final parts = bare.split('-');
    if (parts.length < 2 || !parts.every(_oneChordToken.hasMatch)) {
      return [(bare, 0)];
    }
    final out = <(String, int)>[];
    // Offsets are relative to the token as written, brackets included, because
    // the caller adds them to that token's own column.
    var offset = token.indexOf(bare);
    for (final part in parts) {
      out.add((part, offset));
      offset += part.length + 1;
    }
    return out;
  }

  /// Returns true when [token] is `-7`-style shorthand for the chord before it.
  ///
  /// A lone dash is excluded: that is filler between two chords (`C - D`) and
  /// carries nothing to add.
  bool isContinuation(String token) => _continuation.hasMatch(_unwrap(token));

  /// Returns true when [token] is a section name rather than a chord.
  ///
  /// Public so `PhotoTextBridge` and the measurement harness can ask the same
  /// question this asks. See [_direction].
  bool isDirection(String token) => _direction.hasMatch(_unwrap(token));

  /// Returns true when [line] should be read as a row of chords.
  ///
  /// All-but-one, not all-or-nothing. Every token must be a chord or
  /// bar-line/dash/repeat punctuation ([_separator]), and at least one must be a
  /// real chord — except that ONE unrecognised token is tolerated when the line
  /// carries enough recognised chords to leave no doubt what it is.
  ///
  /// It used to be all-or-nothing, and a single misread glyph cost the whole
  /// row. Measured on the photograph corpus: `185-jezus-krisztusom` prints
  /// `G D em H7` over two of its lines and the recogniser returns that `H7` as
  /// `HÁ` and `HSX`, so six chords entered the song as words and the page scored
  /// 0.200 for chord recall. `166-tekozlo-fiu` lost a row to `£` standing in for
  /// an `E`, `098-szivemben-orom-dalol` one to `en` for `em`,
  /// `125-nincs-mas-isten` one to a `!` its printed column rule left behind.
  ///
  /// Two thresholds, because one is not safe at two chords and three alone is
  /// not generous enough:
  ///
  /// * [_tolerateAfter] chords is enough for any stray token; and
  /// * [_tolerateAfterOddToken] is enough when the stray token does not look
  ///   like a word — it carries a capital, a digit or a symbol. A chord is
  ///   printed as a capital, or as a lowercase minor which is already a chord
  ///   token, so a misread one rarely comes back as plain lowercase letters —
  ///   and plain lowercase letters are exactly the shape of a Hungarian word.
  ///
  /// Calibrated, not guessed. Over every lyric line of every gold file and of
  /// every song the app ships, 171 of them, this reclassifies **none**. It does
  /// misread `a e b dal` — three bare note letters and one word, which is not a
  /// line any hymnal prints. Requiring only two chords for anything turns
  /// `A G szívemben` into a chord row, and requiring one turns `A szívemben`
  /// into one, which is the line this family of rules exists to protect. That is
  /// the floor, and it is why `Csak Egy Az` is still safe: none of its words is
  /// a chord token, so there is nothing for the tolerance to hang off.
  ///
  /// The tolerated token is kept rather than dropped. It reaches storage as a
  /// chord in the column the page printed it in — visibly wrong somewhere the
  /// moderator can fix it, where a silently missing chord is the harder thing to
  /// notice.
  ///
  /// A line whose only chord is a bare root (`A`, `d`, `A -`) is a chord line.
  /// It used not to be; see the note above [isChordToken] for why that changed.
  bool isChordLine(String line) {
    final tokens = _token.allMatches(line).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) return false;

    final chords = <String>[];
    final unknown = <String>[];
    for (final token in tokens) {
      if (_separator.hasMatch(token)) continue;
      // Tolerated like punctuation. An orphan one — CRAFT drops lone glyphs, so
      // the `A` before a `-7` really can go missing — is dropped downstream
      // rather than costing the row its real chords. The "at least one chord"
      // rule below still keeps a lyric line of dashes out.
      if (isContinuation(token)) continue;
      if (isChordToken(token)) {
        chords.add(token);
      } else if (isDirection(token)) {
        // Asked after the chord test, never before: see [_direction]. A stage
        // direction is not a misread chord, so it does not spend the row's one
        // tolerance.
        continue;
      } else {
        unknown.add(token);
      }
    }

    // Punctuation on its own is a rule drawn under a heading, not music.
    if (chords.isEmpty) return false;
    if (unknown.length > 1) return false;
    if (unknown.isEmpty) return true;
    return toleratesOneUnknown(chords.length, unknown.single);
  }

  /// Whether [chordCount] recognised chords are enough to read [unknown] as a
  /// misread chord rather than as a word.
  ///
  /// Public so `PhotoTextBridge` and the measurement harness can ask the same
  /// question this asks, instead of each counting for itself.
  bool toleratesOneUnknown(int chordCount, String unknown) {
    if (chordCount >= _tolerateAfter) return true;
    return chordCount >= _tolerateAfterOddToken &&
        !_lowercaseWord.hasMatch(_unwrap(unknown));
  }

  /// Parses [input] into verses plus whatever metadata it carried.
  ///
  /// [kinds] overrules [isChordLine] on the lines it names and nothing else. It
  /// exists for the import screen's line list, where somebody looking at the
  /// photograph can see a row the reader classified wrongly. Omitted - which is
  /// every caller but that one - the parse is what it always was.
  ParsedChordSheet parse(String input, {LineKinds? kinds}) {
    final lines = input.split(RegExp(r'\r\n|\r|\n'));

    final verses = <Verse>[];
    final comments = <String>[];
    final chorusVerses = <int>{};
    final warnings = <ImportNotice>[];
    var pending = <LyricLine>[];
    String? title;
    String? key;
    var inChorus = false;
    var verseNumber = 1;

    void flush() {
      if (pending.isEmpty) return;
      verses.add(Verse(
        number: verseNumber,
        hasNotation: false,
        lines: List.of(pending),
      ));
      if (inChorus) chorusVerses.add(verseNumber);
      verseNumber++;
      pending = <LyricLine>[];
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final trimmed = raw.trim();
      final lineNo = i + 1;

      if (trimmed.isEmpty) {
        flush();
        continue;
      }

      final directive = _directive.firstMatch(trimmed);
      if (directive != null) {
        final name = directive.group(1)!.toLowerCase();
        final value = directive.group(2) ?? '';
        switch (name) {
          case 't':
          case 'title':
            title = value.isEmpty ? title : value;
          case 'k':
          case 'key':
            key = value.isEmpty ? key : value;
          case 'c':
          case 'ci':
          case 'comment':
          case 'comment_italic':
            comments.add(value);
          case 'soc':
          case 'start_of_chorus':
            // A chorus is its own block, so it always starts a fresh verse.
            flush();
            inChorus = true;
          case 'eoc':
          case 'end_of_chorus':
            flush();
            inChorus = false;
          default:
            warnings.add(ImportNotice(ImportNoticeCode.unknownDirective,
                line: lineNo, text: trimmed));
        }
        continue;
      }

      // Explicit brackets win: the author already marked the chords.
      if (_hasBracket.hasMatch(raw)) {
        pending.add(_parseInline(raw, lineNo, warnings));
        continue;
      }

      // The person holding the page overrules the rule, where they said so.
      // Null when they did not, which is every line unless the import screen
      // put something in - see [LineKinds].
      if (kinds?.isChords(i) ?? isChordLine(raw)) {
        final next = i + 1 < lines.length ? lines[i + 1] : null;
        if (next != null && (kinds?.isLyric(i + 1) ?? _isLyricLine(next))) {
          pending.add(_parseChordsOverLyrics(raw, next, lineNo, warnings));
          i++; // the lyric line was consumed as part of this pair
        } else {
          // Instrumental / intro run with nothing underneath. Positions past
          // the end of an empty text are fine: the renderer uses them for
          // horizontal offset only, it never indexes into the text.
          pending.add(_parseChordsOverLyrics(raw, '', lineNo, warnings));
        }
        continue;
      }

      pending.add(LyricLine(text: raw.trimRight()));
    }

    flush();

    return ParsedChordSheet(
      verses: verses,
      title: title,
      key: key,
      comments: comments,
      chorusVerseNumbers: chorusVerses,
      warnings: warnings,
    );
  }

  /// True when [line] can serve as the lyrics under a chord line.
  bool _isLyricLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (_directive.hasMatch(trimmed)) return false;
    if (_hasBracket.hasMatch(line)) return false;
    return !isChordLine(line);
  }

  /// Strips `[…]` markers, recording each one at the length of the text
  /// emitted so far — which is exactly its index in the finished lyric.
  LyricLine _parseInline(String raw, int lineNo, List<ImportNotice> warnings) {
    final text = StringBuffer();
    final chords = <ChordPosition>[];

    var i = 0;
    while (i < raw.length) {
      final char = raw[i];
      if (char == '[') {
        final close = raw.indexOf(']', i + 1);
        if (close != -1) {
          final token = raw.substring(i + 1, close).trim();
          if (isChordToken(token)) {
            // A hyphen-joined run is two chords over one syllable, and a
            // bracket carries no horizontal information to separate them by, so
            // they share the position the marker names.
            for (final (part, _) in chordsIn(token)) {
              chords.add(ChordPosition(
                chord: ChordTransposer.toEnglishNotation(part),
                position: text.length,
              ));
            }
            i = close + 1;
            continue;
          }
          // Section markers and repeat counts (`[Chorus]`, `[2x]`) are not
          // chords; keeping them as visible text beats inventing a chord.
          //
          // The token goes over without its brackets: they belong to the
          // sentence, and each language quotes it its own way.
          warnings.add(ImportNotice(ImportNoticeCode.bracketNotAChord,
              line: lineNo, text: token));
        }
      }
      text.write(char);
      i++;
    }

    return LyricLine(text: text.toString().trimRight(), chords: chords);
  }

  /// Maps each chord token's column in [chordLine] onto the text of
  /// [lyricLine]. Leading whitespace is preserved on both so the columns stay
  /// aligned; only trailing whitespace is dropped.
  /// Punctuation is dropped rather than stored: a bar line is not a chord, and
  /// `ChordView` would print it above the lyric as if it were one. The columns
  /// of the chords around it are untouched, because each chord's position is its
  /// own match offset and never a running total.
  LyricLine _parseChordsOverLyrics(String chordLine, String lyricLine,
      [int lineNo = 0, List<ImportNotice>? warnings]) {
    final chords = <ChordPosition>[];
    for (final match in _token.allMatches(chordLine)) {
      final token = match.group(0)!;
      if (_separator.hasMatch(token)) continue;
      // `Intro` on a chord row is an instruction, and `ChordView` would print
      // it over the lyric as if it were a chord. Dropped the way a bar line is,
      // and after the separator test for the same reason.
      if (!isChordToken(token) && isDirection(token)) continue;

      // `-7` after an `A` is that A carrying a seventh. Built from the whole
      // previous chord rather than its root, so `Em` followed by `-7` gives
      // `Em7` and not `E7` — the book is adding to the chord, not respelling it.
      final continued = _continuation.firstMatch(_unwrap(token));
      if (continued != null) {
        if (chords.isEmpty) {
          warnings?.add(ImportNotice(
              ImportNoticeCode.continuationWithoutChord,
              line: lineNo,
              text: token));
          continue;
        }
        chords.add(ChordPosition(
          chord: chords.last.chord + continued.group(1)!,
          position: match.start,
        ));
        continue;
      }

      for (final (part, offset) in chordsIn(token)) {
        chords.add(ChordPosition(
          chord: ChordTransposer.toEnglishNotation(part),
          position: match.start + offset,
        ));
      }
    }
    return LyricLine(text: lyricLine.trimRight(), chords: chords);
  }
}
