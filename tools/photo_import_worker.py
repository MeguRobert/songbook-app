#!/usr/bin/env python3
"""Local stand-in for the photo-import backend.

Implements the contract the app already speaks, so the whole import flow can be
exercised on this machine before committing to any hosting:

    POST /extract   multipart/form-data, image under `image`
    -> 200 {"kind": "chordpro" | "musicxml", "content": "...", "warnings": [...]}

Run it, then paste the URL into Settings -> Photo import.

    python tools/photo_import_worker.py                # stub, no key needed
    python tools/photo_import_worker.py --easyocr      # real, offline, no key
    ANTHROPIC_API_KEY=sk-... python tools/photo_import_worker.py --live

Three modes, in increasing order of what they cost you:

  stub      a fixed song. Makes the whole app flow testable with no key, no
            network and no models — and names itself, so it can never be
            mistaken for a successful read.
  easyocr   EasyOCR on this machine. Free, offline, no key, no account. On a
            2400px Hungarian chord sheet it recovered all 14 chords over the
            right syllable, and 97.5% of the characters of a ground-truth hymn
            scan. Costs no more at phone resolution. See the OCR section below
            for why the detector thresholds are not the defaults.
  live      a vision model over the network. Needs a key, reads a page far
            better than OCR does, and costs a fraction of a cent per photo.

This is deliberately the same shape as the Cloudflare Worker it stands in for —
read the multipart body, work out what the page says, answer with the JSON
above. Porting it means replacing the http.server plumbing, not the logic.
(`--easyocr` is the exception: torch does not fit in a Worker. That mode is for
running here.)

Why the stdlib carries the default: this has to run on a machine that has
Python and nothing else installed, and adding a dependency to try an experiment
is how experiments stop getting tried. EasyOCR is imported inside the function
that needs it, so `--stub` still runs on a bare interpreter.
"""

import argparse
import base64
import collections
import json
import math
import os
import pathlib
import re
import statistics
import sys
from email.parser import BytesParser
from email.policy import default as default_policy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Returned by the stub. Deliberately contains the two things most likely to be
# got wrong downstream: accented Hungarian, and a line whose words start with
# note letters ("Csak Egy Az" must survive as lyrics, not become C, E and A).
def stub_chordpro(filename: str, size: int) -> str:
    """A response that cannot be mistaken for a real transcription.

    The first stub was a plausible-looking Hungarian hymn, which read as a
    successful extraction — the only hint it was fake sat in a warning below
    the fold. A stub indistinguishable from success is worse than no stub: it
    teaches you the wrong thing. This one names itself in the title, which is
    the first thing the app shows, and echoes the file it was given so it is
    obvious the image arrived and was ignored on purpose.

    It still exercises what matters: accented Hungarian, and a line whose words
    start with note letters ("Csak Egy Az" must stay lyrics, not become C, E
    and A).
    """
    return f"""{{title: STUB — no model, {filename}}}
{{key: G}}
[G]This is not your [C]photo
[G]The worker is in stub [D]mode

Csak Egy Az — {size} bytes arrived and were ignored
[Em]Restart it with [C]--live to read it for [G]real
"""

MODEL_PROMPT = (
    "This is a photograph of a song — lyrics with guitar chords, or a hymn "
    "page. Transcribe it as ChordPro. Put each chord in square brackets "
    "immediately before the syllable it falls on. Separate verses with a blank "
    "line. Include {title: ...} if a title is visible and {key: ...} if you can "
    "tell the key. Output only the ChordPro, no commentary, no code fences. "
    "Preserve the original language and its accents exactly."
)


# Checked when the env var is absent. A file rather than a flag so the key is
# never typed into a command line, never lands in shell history, and never has
# to be pasted into a conversation. Gitignored.
KEY_FILE = pathlib.Path(__file__).with_name(".anthropic_key")


def read_api_key() -> str:
    """The key from the environment, else from [KEY_FILE], else empty."""
    from_env = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if from_env:
        return from_env
    if KEY_FILE.exists():
        # Tolerates a trailing newline and a stray `ANTHROPIC_API_KEY=` prefix,
        # since both are what a copy-paste tends to produce.
        raw = KEY_FILE.read_text(encoding="utf-8").strip()
        return raw.split("=", 1)[1].strip() if raw.startswith("ANTHROPIC_API_KEY=") else raw
    return ""


def extract_with_model(image_bytes: bytes, media_type: str) -> tuple[str, list]:
    """Ask a vision model for ChordPro. Returns (content, warnings)."""
    import urllib.request

    api_key = read_api_key()
    if not api_key:
        raise RuntimeError(
            "No API key. Put one in tools/.anthropic_key or set "
            "ANTHROPIC_API_KEY in the environment.")

    payload = {
        "model": "claude-sonnet-5",
        "max_tokens": 4096,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image", "source": {
                    "type": "base64",
                    "media_type": media_type,
                    "data": base64.b64encode(image_bytes).decode("ascii"),
                }},
                {"type": "text", "text": MODEL_PROMPT},
            ],
        }],
    }
    request = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "content-type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        body = json.load(response)

    text = "".join(
        block.get("text", "") for block in body.get("content", [])
    ).strip()
    # Models wrap output in fences despite being asked not to; the app would
    # otherwise treat ``` as a lyric line.
    text = re.sub(r"^```[a-zA-Z]*\n|\n```$", "", text).strip()

    warnings = []
    if body.get("stop_reason") == "max_tokens":
        warnings.append("The page was long; the end may be missing.")
    return text, warnings


# ---------------------------------------------------------------------------
# OCR -> ChordPro
#
# The free, offline, key-free path. EasyOCR returns each token with a bounding
# box; `ChordPosition.position` on the app side is a character column into the
# lyric. Everything below is the bridge between those two, and it is ordinary
# arithmetic — no model, no network, and (apart from the reader itself) no
# dependency, so it is unit-tested in tools/test_photo_import_worker.py without
# EasyOCR installed at all.
#
# The classification rules are a deliberate port of ChordSheetParser's, not an
# approximation of them. The app re-parses whatever we emit, so if the two
# disagree about what a chord is, we hand it text it reads back differently
# than we wrote it.
# ---------------------------------------------------------------------------

# `confidence` is what the recogniser scored this region, carried through rather
# than dropped at this boundary. Nothing in the layout reads it; it exists so a
# reading can be explained afterwards. A chord that came back at 0.24 and a
# chord that came back at 0.96 produce the same missing chord downstream, and
# only the score says which one to go and fix.
#
# Defaulted, and every rebuild below goes through `_replace`, so the tests that
# construct a Box positionally keep working and no field-by-field rebuild can
# silently drop it — the failure mode this repo has already paid for three times.
Box = collections.namedtuple("Box", "text x0 y0 x1 y1 confidence",
                             defaults=(None,))

# Ported verbatim from ChordSheetParser (chord_sheet_parser.dart). The quality
# whitelist is the whole point: with a `.*` quality every Hungarian word
# starting with A-H "matches", and `Csak Egy Az` reads as three chords and no
# words. See that file's comment for the full argument.
#
# `H` is B natural in Hungarian notation. The worker emits it as written and
# the app renames it to `B` on the way into storage, so a photographed page
# stays a faithful transcription and one side owns the spelling.
# A lowercase root means minor in Central European notation — `em` is E minor,
# and Hungarian songbooks print it that way throughout. The app raises the case
# on the way into storage; the worker only has to agree that these are chords,
# because a row it does not recognise is emitted as lyrics and the chords on it
# reach the song as words.
# An accidental may be a sign or a syllable. Hungarian and German print it as
# one: `isz`/`is` is a sharp (`fiszm` is F sharp minor, `Fis` is F sharp) and
# `esz`/`sz` is a flat (`Esz` is E flat). Measured on the corpus, `fiszm` alone
# cost `166-tekozlo-fiu` three of its ten chord rows, because the row rule threw
# every chord on those rows away with it. A bare `s` is deliberately
# NOT a flat: it would read `Gsus2` as G flat carrying `us2`.
_ACCIDENTAL = r"(?:#|b|isz|is|esz|sz)"
_ONE_CHORD = (r"[A-GHa-gh]" + _ACCIDENTAL + r"?"
              r"(?:maj|min|m|dim|aug|sus|add|\+|°|[#b]?\d+)*"
              r"(?:/[A-GHa-gh]" + _ACCIDENTAL + r"?)?")
# Chords joined by hyphens are one token, because that is how the book prints two
# chords played in succession over one syllable: `Amaj7-A7`, `Cadd9-Csus2`,
# `G5-Gsus2`, `D-E`. Every part has to be a chord on its own, which is what keeps
# `ici-picit` a word. The app separates them again on the way into storage - see
# `ChordSheetParser.chordsIn` - so nothing ever transposes a symbol naming two
# pitches.
#
# In the PATTERN and not in `is_chord_token`, and that is the whole point. The
# gold editor colours rows client-side and is handed these patterns rather than a
# hand-copied JavaScript translation of them, precisely so one source of truth
# stays one. The first version of the hyphen rule lived in the function, so the
# editor went on calling `E fiszm E D-E A` a lyric row while both parsers read it
# as chords - the same drift that comment was written about.
_CHORD_TOKEN = re.compile("^(?:" + _ONE_CHORD + r")(?:-(?:" + _ONE_CHORD
                          + r"))*$")
# How many recognised chords a row needs before ONE unrecognised token is
# tolerated instead of making the whole row lyrics. See `chord_row_reason` for
# what these cost and what they bought; they are shipped to the gold editor,
# which colours rows client-side and cannot call the function.
_TOLERATE_AFTER = 3
_TOLERATE_AFTER_ODD_TOKEN = 2
# What a Hungarian word looks like and a misread chord does not: plain lowercase
# letters, no capital, no digit, no symbol.
_LOWERCASE_WORD = re.compile(r"^[a-záéíóöő"
                             r"úüű]+$")
# A row whose only chord is a bare root — `A`, `d`, `A -` — used to be resolved
# towards lyrics by a `_BARE_ROOT` regex here, on the grounds that `A` is the
# Hungarian definite article. The rule is gone: the ambiguity only arises when a
# root letter stands among words, and `chord_row_reason` already keeps such a row
# as lyrics: one chord and one unrecognised token is under the tolerance floor,
# which is exactly where `A szivemben` sits. A row holding nothing but one letter
# is not a line of words.
#
# It cost four real chords on two pages — `C` and `G` on 084-van-egy-ut, `D` and
# `A` on 151-zengjed-a-dalt — every one stored as a word. Removed to match
# `chord_sheet_parser.dart`, which no longer has the rule either.

# `-7`, `-m` — the chord before this one with something added, which is how the
# book avoids reprinting the letter. Names no pitch alone, so it is not a chord
# token; a lone dash stays plain filler.
_CONTINUATION = re.compile(r"^[-–—](.+)$")
# A bracket or a quote left standing on its own once a region is split into
# words. The songbook writes an optional chord as `( C )`, spaces inside the
# brackets, and the recogniser sometimes returns a stray apostrophe where a
# chord's glyph was — either one made the whole row read as lyrics, because a
# lone bracket is neither a chord nor a separator. It names no pitch and it is
# not a word, so it belongs here. `(C)` written closed still goes through
# _PARENTHESISED, where the brackets are the evidence that it is a chord.
_SEPARATOR = re.compile(
    r"^(?:[-–—]+|\|+|:\||\|:|\|\||[xX]\d+|\d+[xX]|[()\[\]'‘’\"]+)$")
_PARENTHESISED = re.compile(r"^\((.+)\)$")
# A section name printed inline on a chord row: an instruction to the player,
# not music. `109-tart-meg-a-kegyelem` sets `B  Asus4  A  - Intro x1` and
# `Gm  A7  Dm  - Intro`. The dash and the `x1` were already separators, so the
# word was the one unrecognised token the row tolerates - kept, and stored as a
# chord in the column the page printed the word in. `symbols` named it itself:
# *chord symbols the token rule cannot spell: Intro*.
#
# Capitalised, and case-sensitively so. That is how a page prints an
# instruction, and `intro`, `verse`, `cor`, `tag` and `solo` are ordinary words
# in one language or another; a lowercase one stays the row's single tolerated
# token, which is the behaviour that was already there. The pattern is shipped
# to the gold editor, which cannot pass flags, so IGNORECASE was not available
# either.
#
# Accented and unaccented spellings both, because the recogniser drops accents:
# `Refr[eé]n` covers what the page prints and what a hard JPEG returns.
#
# Only words this corpus attests, plus the ones a songbook prints in any
# language. Left out on purpose: `Tag`, `Solo`, `Cor`, `Ending`,
# `Instrumental` - each is an ordinary word somewhere, and none appears on any
# page here to calibrate against. NO ROMANIAN PAGE IS IN THE CORPUS, so
# `Strof[aă]` and `Refren` are the app's localisation talking, not a
# measurement.
#
# Calibrated the way the tolerance rule was: against every line of every gold
# file and of every song the app ships, 284 of them, this reclassifies none.
_DIRECTION = re.compile(
    r"^(?:Intro|Outro|Coda|Bridge|Chorus|Verse"
    r"|Refr[eé]n|Versszak|[AÁ]tvezet[oő]"
    r"|Ism[eé]tl[eé]s|Strof[aă])[.:]?$")

# Two boxes are on the same line when their centres are within this fraction of
# a glyph height. A photographed page is never square-on, so a line's baseline
# wanders by a few pixels; splitting on that would put every word on its own
# line.
_SAME_ROW = 0.6

# A verse break has to clear both bars: taller than one blank line, AND well
# above the page's usual line spacing. The first alone turns a loosely set page
# into one verse per line; the second alone cannot tell two verses from two
# lines when the page has only a couple of gaps to compare.
_BREAK_VS_HEIGHT = 1.0
_BREAK_VS_GAP = 1.6

# How much taller than the body text the first line must be to be a title.
#
# Type size alone is a weak signal on a photographed page, and on one real page
# it is the wrong sign: `151-zengjed-a-dalt` prints its title at a *smaller* row
# height than the body median (49 against 51.5), because the body carries
# accents and descenders that the short title does not. That rule could never
# fire there, and the title landed in the lyrics.
_TITLE_HEIGHT = 1.25

# The other signal, which is much stronger on a hymnal page: a title leads with
# the song number, and it is *short*. A lyric line is a sentence.
#
# Measured over the corpus, first-row length against the median body line:
#   084-van-egy-ut       `84 . Van egy út`        15 / 46 = 0.33  title
#   151-zengjed-a-dalt   `151   Zengjed a dalt`   20 / 41 = 0.49  title
#   109-tart-meg...      `1 Tart nag 0 kegyclem…` 40 / 40 = 1.00  verse 1, not a title
#
# So 0.6 separates them with room on both sides. The residual risk is a page
# with no title whose first line opens with a verse number — that line becomes
# the title. Accepted: it is visible on the review screen, it is one tap to fix,
# and the alternative is a title silently left in the words. There is no rule to
# keep in step in the app: `chord_sheet_parser.dart` reads a `{title:}`
# directive and never guesses.
_TITLE_WIDTH = 0.6
_NUMBER_LED = re.compile(r"^\s*\d{1,4}\s*\.?\s+\S")

# EasyOCR scores every read. Below this the token is far likelier to be a stave
# line or a slur than a word, and a wrong word costs more than a missing one.
_MIN_CONFIDENCE = 0.2

# CRAFT's defaults are tuned for prose, and they quietly drop a single letter
# sitting alone in white space — which is exactly what a chord is. On a rendered
# 2400px chord sheet the defaults found 9 of 14 chords; every miss was a lone
# `G` or `D`, and all four `A`s and both `Hm`s came through, so the loss lands
# on the sparsest glyphs rather than at random.
#
# Both values have to move: text_threshold alone got 11 of 14, low_text alone
# still 9, together 14. Lowering text_threshold *without* low_text is also
# ~4x slower (113s against 25s), because the high low_text leaves CRAFT growing
# a crowd of marginal regions that each cost a recogniser pass. Lowered
# together the run costs nothing extra.
_TEXT_THRESHOLD = 0.5
_LOW_TEXT = 0.3

# EasyOCR's two commonest Hungarian confusions. Both fire only where a digit
# touches a letter — digits do not occur inside Hungarian words, so that is
# strong evidence of a misread glyph, while a verse number, a fret number or a
# repeat count stands alone and survives. Both are length-preserving, which is
# what lets them run after layout without shifting a single chord column.
#
#   1 -> i   carried over from convert_hymn.ocr_lyrics_from_image, narrowed.
#   6 -> ő   measured here: every error in the ground-truth hymn scan was `ő`,
#            read as `ó`, `ö` or `6`. Only the `6` case is repairable — `ó` and
#            `ö` are ordinary letters, so rewriting them would break `jó` and
#            `föld` to fix `tól`.
_ONE_IN_WORD = re.compile(r"(?<=[^\W\d_])1|1(?=[^\W\d_])", re.UNICODE)
_SIX_IN_WORD = re.compile(r"(?<=[^\W\d_])6|6(?=[^\W\d_])", re.UNICODE)


def _unwrap(token: str) -> str:
    """[token] with any surrounding parentheses removed."""
    match = _PARENTHESISED.match(token)
    return match.group(1) if match else token


def is_chord_token(token: str) -> bool:
    """True when [token] is unambiguously a chord symbol.

    A hyphen-joined run of chords counts as one; the reasoning is at
    [_CHORD_TOKEN], and so is the rule, because the gold editor is handed the
    pattern rather than a copy of this function.
    """
    return bool(_CHORD_TOKEN.match(_unwrap(token)))


def is_continuation(token: str) -> bool:
    """True when [token] is `-7`-style shorthand for the chord before it."""
    return bool(_CONTINUATION.match(_unwrap(token)))


def is_direction(token: str) -> bool:
    """True when [token] is a section name rather than a chord.

    Only ever asked about a token [is_chord_token] has already refused, which is
    what makes this rule unable to lose a chord: `Coda` and `Bridge` open with
    note letters, and a chord spelling that collided with one of these words
    would still be read as the chord.
    """
    return bool(_DIRECTION.match(_unwrap(token)))


def chord_row_reason(texts) -> tuple[bool, str]:
    """Whether [texts] is a row of chords, and why.

    All-but-one, not all-or-nothing. Every token has to be a chord symbol or
    punctuation, except that ONE unrecognised token is tolerated when the row
    carries enough recognised chords to make it obvious what the row is.

    It used to be all-or-nothing, and that cost whole rows to a single misread
    glyph. Measured on the corpus: `185-jezus-krisztusom` prints `G D em H7` over
    two of its lines and the recogniser returns the `H7` as `HÁ` and `HSX`, so
    six chords went into the song as words and the page scored 0.200 for chord
    recall. `166-tekozlo-fiu` lost a row to `£` standing in for an `E` and
    another to `fiszmn` for `fiszm`; `098-szivemben-orom-dalol` lost one to `en`
    for `em`; `125-nincs-mas-isten` lost one to a `!` the printed column rule
    left behind.

    Two thresholds, because one is not safe at two chords and three is not
    generous enough:

    * [_TOLERATE_AFTER] chords is enough for any stray token; and
    * [_TOLERATE_AFTER_ODD_TOKEN] is enough when the stray token does not look
      like a word - it carries a capital, a digit or a symbol. A chord is
      printed as a capital (or as a lowercase minor, which is already a chord
      token), so a misread one rarely comes back as plain lowercase letters,
      and plain lowercase letters are exactly the shape of a Hungarian word.

    Calibrated, not guessed. Against every lyric line of every gold file and of
    every song the app ships - 171 of them - this rule reclassifies **none**.
    What it does misread is `a e b dal`: three bare note letters and one word,
    which is not a line any hymnal prints. The weaker `>= 2 chords for anything`
    version turns `A G szívemben` into a chord row, and `>= 1` turns
    `A szívemben` into one - which is the line this whole family of rules exists
    to protect, so that is the floor.

    The tolerated token is kept rather than dropped. It reaches storage as a
    chord in the column the page printed it in, which is visibly wrong in a
    place the moderator can fix; a silently missing chord is the harder thing to
    notice.

    The tolerance is for a MISREAD chord, though, and a stage direction is not
    one - `109-tart-meg-a-kegyelem` was spending its one tolerance on `Intro`,
    a word the engine read perfectly. A small vocabulary of section names is
    skipped like punctuation instead; see [_DIRECTION] for which words, and for
    why the test is case-sensitive.

    The reason exists because the two ways to lose a chord are indistinguishable
    downstream and are fixed in different places: the recogniser never returned
    the symbol, or it returned it and this rule then threw the whole row away.
    A reading that comes out short is the same reading either way.
    """
    chords, unknown = [], []
    for text in texts:
        if _SEPARATOR.match(text) or is_continuation(text):
            continue
        if is_chord_token(text):
            chords.append(text)
        elif is_direction(text):
            # Asked after the chord test, never before: see [is_direction].
            continue
        else:
            unknown.append(text)
    if not chords:
        return False, "separators only, no chord symbol"
    if len(unknown) > 1:
        return False, "not chord symbols: " + " ".join(repr(u) for u in unknown)
    if unknown:
        if not tolerates_one_unknown(chords, unknown[0]):
            return False, f"not a chord symbol: {unknown[0]!r}"
        return True, ("chords: " + " ".join(chords)
                      + f" (tolerating {unknown[0]!r})")
    return True, "chords: " + " ".join(chords)


def tolerates_one_unknown(chords, unknown: str) -> bool:
    """Whether [chords] are enough to read one [unknown] token as a misread.

    The gold editor colours rows as you type and cannot call this, so it is
    handed the two thresholds and the word pattern instead - see
    `editor.rules()`. Keep the shape simple enough to say twice.
    """
    if len(chords) >= _TOLERATE_AFTER:
        return True
    return (len(chords) >= _TOLERATE_AFTER_ODD_TOKEN
            and not _LOWERCASE_WORD.match(unknown))


def is_chord_row(texts) -> bool:
    """True when [texts] should be read as a row of chords."""
    return chord_row_reason(texts)[0]


def split_regions(row):
    """[row] with every multi-word region split into one box per word.

    The recogniser returns *regions*, not words, and a chord row is mostly white
    space — so a widely spaced row comes back as `G` and `C   D - C`: two
    regions holding four chords. Every rule above is written about one token, so
    that second region reads as an ordinary word and the row test
    then emits the whole row as lyrics. That is how a page of large, clean,
    well-separated chords loses every one of them, and it was doing so on the
    cleanest page in the corpus.

    Sub-boxes are positioned by character offset on the region's own average
    character width. Approximate on purpose: a chord only has to land over the
    right word, and the alternative is re-reading the pixels.
    """
    split = []
    for box in row:
        parts = list(re.finditer(r"\S+", box.text))
        if len(parts) < 2:
            split.append(box)
            continue
        width = (box.x1 - box.x0) / max(1, len(box.text))
        split.extend(box._replace(text=part.group(0),
                                  x0=box.x0 + part.start() * width,
                                  x1=box.x0 + part.end() * width)
                     for part in parts)
    return split


def as_chord_row(row):
    """[row] split into per-chord boxes when that is what it turns out to be.

    Only when splitting changes the verdict. A lyric row split into words would
    reach `_lay_out` as many boxes rather than one, and its spacing is measured
    from the boxes — so leaving lyrics alone is not tidiness, it is required.
    """
    if is_chord_row([b.text for b in row]):
        return row
    split = split_regions(row)
    if len(split) != len(row) and is_chord_row([b.text for b in split]):
        return split
    return row


def _german_chords_in(texts):
    """The H-rooted chords among [texts].

    Only ever asked of a row already judged to be chords, so `Hogy` cannot
    reach it — that row is lyrics, and one ordinary word is enough to keep it
    that way.
    """
    return [text for text in texts
            if _unwrap(text).startswith("H") and is_chord_token(text)]


def boxes_from_easyocr(results, min_confidence: float = _MIN_CONFIDENCE):
    """EasyOCR's (quadrilateral, text, confidence) tuples as [Box]es.

    The quadrilateral is not a rectangle on a photographed page, so each one is
    reduced to its bounding box.
    """
    boxes = []
    for quad, text, confidence in results:
        text = text.strip()
        if not text or confidence < min_confidence:
            continue
        xs = [point[0] for point in quad]
        ys = [point[1] for point in quad]
        boxes.append(Box(text=text, x0=min(xs), y0=min(ys),
                         x1=max(xs), y1=max(ys),
                         confidence=float(confidence)))
    return boxes


# How far off square a handheld photo is worth correcting, and how finely to
# look. Beyond about this the page is not a photograph of a song, it is a
# photograph of a table with a song on it.
_MAX_SKEW = 12.0
_SKEW_STEP = 0.25

# Below this there is nothing to gain and the rotation only adds rounding.
_SKEW_FLOOR = 0.4

# A skew estimate needs several lines to be evidence rather than noise.
_MIN_BOXES_FOR_SKEW = 6

# A space the recogniser inserted before its own punctuation. Measured: a
# region came back as `vagy ,` at 0.60 confidence, which imported the lyric as
# `mert velem vagy ,`. It is one region and not two, so no amount of layout
# reaches it — the recognised text itself is what is wrong.
#
# A dash is deliberately absent: ` - ` separates syllables all over a hymnal
# page and is not stray spacing.
_SPACE_BEFORE_PUNCTUATION = re.compile(r"\s+([,.;:!?])")


def estimate_skew(boxes, limit: float = _MAX_SKEW,
                  step: float = _SKEW_STEP) -> float:
    """The angle, in degrees, by which the page appears to be tilted.

    Found by projection profile: for each candidate angle the box centres are
    projected onto the axis across the text and binned, and the angle scoring
    highest on the sum of squared bin counts wins. At the true angle every
    token of a line falls in one bin, so the counts are few and large; at any
    other angle they smear across neighbours and the sum drops.

    EasyOCR cannot answer this directly — it returns axis-aligned rectangles
    however the text is rotated, so the tilt survives only in where the boxes
    sit relative to each other, not in their shape.
    """
    if len(boxes) < _MIN_BOXES_FOR_SKEW:
        return 0.0
    height = statistics.median(b.y1 - b.y0 for b in boxes)
    span = max(1.0, height / 2)
    centres = [((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2) for b in boxes]

    best_angle, best_score = 0.0, -1.0
    for tick in range(-int(limit / step), int(limit / step) + 1):
        angle = tick * step
        radians = math.radians(angle)
        sin, cos = math.sin(radians), math.cos(radians)
        # Two grids half a bin apart: with one, a line landing on a boundary
        # splits in two and scores as though it were smeared.
        low, high = collections.Counter(), collections.Counter()
        for x, y in centres:
            across = y * cos - x * sin
            low[int(across // span)] += 1
            high[int((across + span / 2) // span)] += 1
        score = (sum(n * n for n in low.values())
                 + sum(n * n for n in high.values()))
        if score > best_score:
            best_score, best_angle = score, angle
    return best_angle


def deskew(boxes, angle: float):
    """[boxes] rotated back onto the horizontal by [angle] degrees.

    Only the centres move; each box keeps its width and height. The text was
    read correctly even on a badly tilted page — it is the grouping that
    fails — so this exists to make rows clusterable, not to re-read anything.
    """
    if abs(angle) < _SKEW_FLOOR:
        return boxes
    radians = math.radians(angle)
    sin, cos = math.sin(radians), math.cos(radians)
    straightened = []
    for box in boxes:
        centre_x = (box.x0 + box.x1) / 2
        centre_y = (box.y0 + box.y1) / 2
        moved_x = centre_x * cos + centre_y * sin
        moved_y = centre_y * cos - centre_x * sin
        half_w = (box.x1 - box.x0) / 2
        half_h = (box.y1 - box.y0) / 2
        straightened.append(box._replace(
            x0=moved_x - half_w, y0=moved_y - half_h,
            x1=moved_x + half_w, y1=moved_y + half_h))
    return straightened


def _is_noise_row(texts) -> bool:
    """True when [texts] holds no letter anywhere.

    Photographing a hymnal page puts clefs, time signatures and slurs in front
    of the recogniser, which dutifully returns things like `4=`. Nothing made
    only of digits and punctuation is a lyric, and a chord always carries its
    root letter, so a row with no letter at all is furniture.
    """
    return not any(character.isalpha() for text in texts for character in text)


def group_rows(boxes):
    """[boxes] clustered into lines, top to bottom, each sorted left to right."""
    if not boxes:
        return []
    # The gate is a fraction of the PAGE's typical glyph height, not of the
    # row's own. A region can arrive far taller than its letters — on a thin
    # page the reverse side shows through and CRAFT merges it into the real
    # line, giving a 132px region for 60px text. Sized from the row, such a box
    # widened its own gate and pulled the chord row above it in, which is how a
    # whole line of chords ended up in the song as words.
    gate = _SAME_ROW * statistics.median(b.y1 - b.y0 for b in boxes)

    rows = []
    for box in sorted(boxes, key=lambda b: (b.y0 + b.y1) / 2):
        centre = (box.y0 + box.y1) / 2
        if rows:
            current = rows[-1]
            # Still a running mean, so a slowly drifting baseline — a curled or
            # tilted page — is followed rather than split.
            mean_centre = sum((b.y0 + b.y1) / 2 for b in current) / len(current)
            if abs(centre - mean_centre) <= gate:
                current.append(box)
                continue
        rows.append([box])
    for row in rows:
        row.sort(key=lambda b: b.x0)
    return rows


# A gutter has to be this many typical glyph widths across, and each column
# needs at least this many boxes to count as a column rather than a stray mark.
_GUTTER_WIDTH = 4.0
_MIN_COLUMN_BOXES = 3


def split_columns(boxes):
    """[boxes] split into columns, left to right, on the gutters between them.

    A hymnal sets two songs side by side, and rows are clustered by y — so
    without this a line in the left column and an unrelated line at the same
    height in the right one become one row, and the two songs interleave.

    The gutter is a vertical band that NO box crosses anywhere on the page.
    Taking the union of every box's x-extent is what makes this safe: a chord
    row is mostly whitespace and full of wide gaps of its own, but some lyric
    line below always covers them, so only a genuine column break survives.
    """
    if len(boxes) < 2 * _MIN_COLUMN_BOXES:
        return [list(boxes)]

    widths = [(b.x1 - b.x0) / len(b.text) for b in boxes if b.text]
    gutter = _GUTTER_WIDTH * (statistics.median(widths) if widths else 1.0)

    # Walk the x-extents in order, closing each run of overlap as it ends.
    spans = sorted((b.x0, b.x1) for b in boxes)
    edges = []
    reach = spans[0][1]
    for start, end in spans[1:]:
        if start - reach > gutter:
            edges.append((reach + start) / 2)
        reach = max(reach, end)

    if not edges:
        return [list(boxes)]

    columns = []
    for lower, upper in zip([float("-inf")] + edges, edges + [float("inf")]):
        column = [b for b in boxes if lower <= (b.x0 + b.x1) / 2 < upper]
        # A stray speck in the margin is not a column; fold it back rather than
        # letting it become a song of its own.
        if len(column) >= _MIN_COLUMN_BOXES:
            columns.append(column)
        elif columns:
            columns[-1].extend(column)
        elif column:
            columns.append(column)
    return columns or [list(boxes)]


def _char_width(row) -> float:
    """The row's typical glyph width, in pixels."""
    widths = [(b.x1 - b.x0) / len(b.text) for b in row if b.text]
    return statistics.median(widths) if widths else 1.0


def _lay_out(row):
    """Render [row] as text. Returns (line, anchors).

    Columns are chained off the previous token rather than computed from x
    directly, so the words stay readable however the OCR boxes drift. The
    anchors — (pixel x, character column) at both edges of every token — are
    what a chord row above is then interpolated onto, so the chord follows the
    text wherever the text actually landed.
    """
    char_width = _char_width(row)
    line = ""
    anchors = []
    previous = None
    for box in row:
        if previous is None:
            column = 0
        else:
            gap = max(1, round((box.x0 - previous.x1) / char_width))
            column = len(line) + gap
        line = line.ljust(column) + box.text
        anchors.append((box.x0, column))
        anchors.append((box.x1, column + len(box.text)))
        previous = box
    return line, anchors


def _column_for(x: float, anchors, char_width: float) -> int:
    """The character column at pixel [x], interpolated between [anchors]."""
    if not anchors:
        return max(0, round(x / char_width))
    if x <= anchors[0][0]:
        return max(0, anchors[0][1] - round((anchors[0][0] - x) / char_width))
    if x >= anchors[-1][0]:
        return anchors[-1][1] + round((x - anchors[-1][0]) / char_width)
    for (x_a, col_a), (x_b, col_b) in zip(anchors, anchors[1:]):
        if x_a <= x <= x_b:
            if x_b == x_a:
                return col_a
            return round(col_a + (x - x_a) * (col_b - col_a) / (x_b - x_a))
    return anchors[-1][1]


def _lay_out_chords(row, anchors, char_width: float) -> str:
    """Render chord [row] against the columns of the lyric row beneath it."""
    line = ""
    for box in row:
        column = _column_for(box.x0, anchors, char_width)
        # Two chords over one syllable would otherwise fuse into a nonsense
        # symbol — `G` and `C` becoming `GC`, which the app then stores.
        if line:
            column = max(column, len(line) + 1)
        line = line.ljust(column) + box.text
    return line


def _repair_ocr(row):
    """[row] with the recogniser's known slips undone.

    Two kinds: Hungarian letters read as digits, and a space inserted before
    the recogniser's own punctuation. Applied to lyric rows only — a chord row
    has neither problem, and `x1` is a repeat marker rather than a misread `xi`.

    Runs before layout, so a length change here is free; the chord row above is
    interpolated onto the columns this produces, not onto raw pixels.
    """
    repaired = []
    for index, box in enumerate(row):
        text = _ONE_IN_WORD.sub("i", box.text)
        text = _SIX_IN_WORD.sub("ő", text)
        text = _SPACE_BEFORE_PUNCTUATION.sub(r"\1", text)
        # A lone `1` between words is the same confusion with the spaces left
        # in. At the start of a row it is a verse number, so it stays.
        if text == "1" and index > 0 and row[index - 1].text[-1].isalpha():
            text = "i"
        repaired.append(box._replace(text=text))
    return repaired


def _verse_breaks(rows):
    """Which of [rows] a blank line should precede."""
    breaks = [False] * len(rows)
    if len(rows) < 3:
        return breaks
    gaps = [min(b.y0 for b in rows[i]) - max(b.y1 for b in rows[i - 1])
            for i in range(1, len(rows))]
    typical_gap = statistics.median(gaps)
    typical_height = statistics.median(
        statistics.median(b.y1 - b.y0 for b in row) for row in rows)
    for index, gap in enumerate(gaps, start=1):
        breaks[index] = (gap > _BREAK_VS_HEIGHT * typical_height
                         and gap > _BREAK_VS_GAP * typical_gap)
    return breaks


def _row_height(row) -> float:
    return statistics.median(b.y1 - b.y0 for b in row)


def _row_confidence(row):
    """Median recogniser score over [row], or None when the boxes carry none."""
    scores = [b.confidence for b in row if b.confidence is not None]
    return round(statistics.median(scores), 3) if scores else None


def _log(trace, stage, **fields) -> None:
    """Append one stage record to [trace], when a caller asked for one.

    The records exist for the measurement loop in tools/ocr_harness, where a
    reading that came out wrong has to be attributed to a stage rather than
    guessed at.

    Arguments are evaluated by the caller, so anything that costs more than a
    `round` — a comprehension over the boxes, say — belongs inside an explicit
    `if trace is not None` at the call site rather than in an argument here.
    Passing one such comprehension unguarded is what made a page with nothing
    legible on it raise instead of returning its warning.
    """
    if trace is not None:
        trace.append({"stage": stage, **fields})


def chordpro_from_boxes(boxes, trace=None) -> tuple[str, list]:
    """ChordPro for a page of OCR [boxes]. Returns (content, warnings)."""
    # Straightened before anything reads it, because grouping is what tilt
    # breaks, and columns are found on x once the page is square.
    skew = estimate_skew(boxes)
    _log(trace, "skew", degrees=round(skew, 3), corrected=abs(skew) >= _SKEW_FLOOR)
    boxes = deskew(boxes, skew)
    columns = split_columns(boxes)
    if trace is not None:
        _log(trace, "columns", count=len(columns),
             spans=[{"x0": round(min(b.x0 for b in c)),
                     "x1": round(max(b.x1 for b in c)),
                     "boxes": len(c)} for c in columns if c],
             # More than one column is read as more than one *song*, which is
             # right for a hymnal printed two songs to a page and wrong for one
             # song set in two columns. Logged so a corpus can say which this
             # page was.
             read_as="one song per column")

    lines, german, chord_rows = [], [], 0
    for index, column in enumerate(columns):
        # Only the first column may name the song: two `{title:}` directives in
        # one paste would leave the parser keeping whichever came last.
        block, block_german, block_chords = _lay_out_column(
            column, titled=(index == 0), trace=trace, column_index=index)
        if not block:
            continue
        if lines:
            lines.append("")
        lines.extend(block)
        german.extend(block_german)
        chord_rows += block_chords

    warnings = []
    if not lines:
        return "", ["Nothing legible was found in that photo."]
    if len(columns) > 1:
        # Honest rather than clever: a page holding two songs cannot become one
        # song, and the review box is where the unwanted half gets deleted.
        warnings.append(
            f"That page holds {len(columns)} songs side by side. Both were read, "
            "in reading order — delete the one you did not want.")
    if not chord_rows:
        warnings.append(
            "No chords were recognised — the words were imported on their own.")
    if german:
        # Not a failure — the app understands these. Said out loud anyway,
        # because someone who photographed `Hm` and is shown `Bm` should be
        # told why rather than left to wonder whether the import went wrong.
        names = ", ".join(sorted(set(german)))
        warnings.append(
            f"{names} will be stored under the English name (H is B natural). "
            "The app keeps one spelling per pitch so transposing stays exact.")
    return "\n".join(lines), warnings


def _lay_out_column(boxes, titled: bool, trace=None,
                    column_index: int = 0) -> tuple[list, list, int]:
    """One column as ChordPro lines. Returns (lines, german chords, chord rows)."""
    # Noise dropped before anything else reads the rows, so verse spacing is
    # measured between real lines rather than across a stray time signature.
    grouped = group_rows(boxes)
    # Regions become per-chord boxes here, once, before anything measures the
    # rows: verse breaks are found on y and are unaffected, but every later
    # question - is this chords, does the row below pair with it, where does
    # each chord sit - has to be asked of the same boxes.
    grouped = [as_chord_row(row) for row in grouped]
    rows = [row for row in grouped
            if not _is_noise_row([b.text for b in row])]
    if trace is not None:
        _log(trace, "column", column=column_index, rows=len(grouped),
             kept=len(rows),
             dropped_as_noise=[[b.text for b in row] for row in grouped
                               if _is_noise_row([b.text for b in row])])
    if not rows:
        return [], [], 0

    lines = []
    # Two independent signals, either of which is enough. Larger type catches a
    # page that prints its heading big; number-led-and-short catches one that
    # does not, which on this corpus is most of them.
    first_text = " ".join(b.text for b in rows[0])

    # The two tests need different denominators, and conflating them cost a
    # working title.
    #
    # Width: lyric lines only. A chord row is mostly white space and a couple of
    # letters, so counting them halved the median and 151-zengjed-a-dalt missed
    # by four characters — its body came out at 27 against a true 38.
    #
    # Height: every row. A chord row's box is *shorter* than a lyric's at the
    # same type size, because `G` has no accent and no descender. Excluding them
    # therefore raises the median and makes the test stricter — which is what
    # dropped 185-jezus-krisztusom's title, a title that had been found
    # correctly for weeks, from a ratio of 1.36 to 1.08. The 1.25 threshold is
    # calibrated against a median that includes them, so it stays that way.
    height_rows = rows[1:]
    width_rows = [row for row in rows[1:]
                  if not is_chord_row([b.text for b in row])] or rows[1:]
    body_height = (statistics.median(_row_height(row) for row in height_rows)
                   if height_rows else 0.0)
    body_width = (statistics.median(
        len(" ".join(b.text for b in row)) for row in width_rows)
        if width_rows else 0.0)
    body_rows = height_rows
    by_height = _row_height(rows[0]) >= _TITLE_HEIGHT * body_height
    by_number = bool(_NUMBER_LED.match(first_text)) and bool(body_width) and \
        len(first_text) <= _TITLE_WIDTH * body_width
    is_title = bool(
        titled and body_rows and not is_chord_row([b.text for b in rows[0]])
        and (by_height or by_number))
    _log(trace, "title", column=column_index, taken=is_title,
         first_row=[b.text for b in rows[0]],
         by_height=bool(by_height), by_number=bool(by_number),
         first_row_height=round(_row_height(rows[0]), 1),
         body_height=round(body_height, 1),
         needs=round(_TITLE_HEIGHT * body_height, 1),
         first_row_width=len(first_text),
         body_width=round(body_width, 1),
         width_allowed=round(_TITLE_WIDTH * body_width, 1))
    if is_title:
        lines.append("{title: %s}" % " ".join(b.text for b in rows[0]))
        lines.append("")
        rows = rows[1:]

    breaks = _verse_breaks(rows)
    chord_rows = 0
    german = []
    index = 0
    while index < len(rows):
        if breaks[index] and lines and lines[-1] != "":
            lines.append("")
        row = rows[index]
        texts = [b.text for b in row]
        chords_here, why = chord_row_reason(texts)
        _log(trace, "row", column=column_index, row=index, texts=texts,
             classified="chord" if chords_here else "lyric", reason=why,
             verse_break_before=bool(breaks[index]),
             height=round(_row_height(row), 1),
             confidence=_row_confidence(row))
        if not chords_here:
            lines.append(_lay_out(_repair_ocr(row))[0])
            index += 1
            continue

        chord_rows += 1
        german.extend(_german_chords_in(texts))
        below = rows[index + 1] if index + 1 < len(rows) else None
        pairs = (below is not None
                 and not breaks[index + 1]
                 and not is_chord_row([b.text for b in below]))
        _log(trace, "pairing", column=column_index, chord_row=index,
             paired_with=index + 1 if pairs else None,
             reason=("paired" if pairs
                     else "last row in the column" if below is None
                     else "a verse break separates them" if breaks[index + 1]
                     else "the row below is chords too"))
        if not pairs:
            # An intro or turnaround with nothing underneath. Kept: the app
            # stores chords with positions past the end of an empty lyric.
            lines.append(_lay_out(row)[0])
            index += 1
            continue

        repaired = _repair_ocr(below)
        # The lyric half of a pair is consumed here rather than coming round
        # the loop, so without this it would be the one row in the column with
        # no record of its own — and it is the row whose confidence explains a
        # wrong word.
        if trace is not None:
            after = [b.text for b in repaired]
            _log(trace, "row", column=column_index, row=index + 1,
                 texts=[b.text for b in below],
                 classified="lyric", reason="paired under the chords above",
                 verse_break_before=False,
                 height=round(_row_height(below), 1),
                 confidence=_row_confidence(below),
                 repaired=after if after != [b.text for b in below] else None)
        lyrics, anchors = _lay_out(repaired)
        lines.append(_lay_out_chords(row, anchors, _char_width(below)))
        lines.append(lyrics)
        index += 2

    return lines, german, chord_rows


# Building the reader loads torch and the language models, which takes seconds
# and megabytes. Once per process, not once per photo.
_reader = None


def easyocr_reader():
    """The shared EasyOCR reader, built on first use."""
    global _reader
    if _reader is None:
        import easyocr
        _reader = easyocr.Reader(["hu", "en"], verbose=False)
    return _reader


# Show-through suppression. A hymnal is printed on thin paper, so the reverse
# page reads through it — and the recogniser dutifully returns that mirrored text
# as words. Measured on song 149: it came back as `n bbod`, `$`, `drnisdl ,Edtt`
# stuck to the real lyrics, and worse, CRAFT merged it into the real regions,
# which both inflated their boxes and destroyed a whole chord row.
#
# The ghost is always LIGHTER than the print, so it can be erased on brightness
# alone once uneven lighting is out of the way. `_BACKGROUND_RADIUS` estimates
# the local paper colour to divide out; the levels window then sends anything
# above it to white. A median blur rather than a Gaussian: it does not bleed the
# letters into their own background estimate.
_BACKGROUND_RADIUS = 51
_GHOST_LEVELS = (110, 190)

# What counts as a page with show-through, and how much of it there has to be.
#
# Measured after flattening: the ghosted page of song 149 has 2.17% of its
# pixels in this band, against 0.00%-0.60% for seven clean scans, renders and
# simulated photographs. The threshold sits between the two with margin either
# side. Antialiasing along the edge of real print lands in the same band, which
# is why a fraction rather than a presence test.
#
# Calibrated on one ghosted page, so err towards not firing: a page that misses
# the gate is read exactly as it was before this existed, while a clean page
# that trips it loses a chord or two to eroded strokes.
_PALE_BAND = (170, 235)
_PALE_FRACTION = 0.012


# What a page of text needs to keep its accents. A Hungarian `ő` differs from
# `ó` by two hairline strokes, and they are the first thing a hard JPEG throws
# away — measured on a real upload: 2048x1532 at 0.026 bytes per pixel came back
# reading `erót` for `erőt`, and `-7` as `27`.
#
# Both halves matter. Pixels alone are not enough (a 4000px image squeezed to
# 90KB has lost the same detail) and bytes alone are not either, so the test is
# bytes per pixel with a floor on the long edge.
# A page smaller than this cannot hold legible text at all, whatever its
# compression; below the density, the pixels are there but the fine strokes have
# been quantised away. Either alone is enough to lose the accents, so the test is
# an OR — and a lightly compressed 2048px scan passes both, because it genuinely
# has the detail.
_MIN_LONG_EDGE = 1200
_MIN_BYTES_PER_PIXEL = 0.08


def resolution_note(width: int, height: int, size: int):
    """A sentence about the upload's own quality, or None when it is fine.

    The single biggest lever on accuracy is not in this file: a phone gallery
    hands over a re-encoded copy, and no amount of parsing recovers a diacritic
    the compression deleted. Worth saying so, because the fix is on the phone.
    """
    pixels = max(1, width * height)
    density = size / pixels
    if max(width, height) >= _MIN_LONG_EDGE and density >= _MIN_BYTES_PER_PIXEL:
        return None
    return (f"That photo arrived at {width}x{height} in {size // 1024} KB — "
            "too compressed to hold the fine strokes. Accents like ő and ű are "
            "the first thing to go, so expect a few wrong letters. A phone "
            "gallery hands over a shrunken copy; picking the same photo through "
            "Files usually gives the full-quality original.")


def _flatten(grey):
    """[grey] divided by its own local background, so lighting stops mattering.

    Without this, one global brightness window either keeps the ghost in the
    bright half of a photographed page or eats the real print in the shadowed
    half. A median rather than a Gaussian: it does not bleed the letters into
    their own background estimate.
    """
    import cv2

    shortest = min(grey.shape[:2])
    radius = min(_BACKGROUND_RADIUS, shortest if shortest % 2 else shortest - 1)
    if radius < 3:
        return grey
    return cv2.divide(grey, cv2.medianBlur(grey, radius), scale=255)


def has_show_through(rgb) -> bool:
    """True when [rgb] carries a second, paler population of ink.

    Suppression costs sharpness, and on a page that does not need it that shows
    up as dropped chords — so it is asked for rather than always applied.
    """
    import cv2

    flattened = _flatten(cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY))
    low, high = _PALE_BAND
    pale = ((flattened >= low) & (flattened <= high)).sum()
    return bool(pale / flattened.size >= _PALE_FRACTION)


def suppress_show_through(rgb):
    """[rgb] with the reverse page's bleed-through erased.

    Returns a 3-channel array, since that is what the reader expects.
    """
    import cv2
    import numpy

    flattened = _flatten(cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY))
    low, high = _GHOST_LEVELS
    stretched = (flattened.astype(numpy.float32) - low) * (255.0 / (high - low))
    cleaned = numpy.clip(stretched, 0, 255).astype(numpy.uint8)
    return cv2.cvtColor(cleaned, cv2.COLOR_GRAY2RGB)


def extract_with_easyocr(image_bytes: bytes, trace=None) -> tuple[str, list]:
    """Read a photo with EasyOCR. Returns (content, warnings).

    Pass a list as [trace] to have every stage append what it decided and why.
    Costs nothing when it is None, which is every request the service serves.
    """
    import io

    import numpy
    from PIL import Image, ImageOps

    original = Image.open(io.BytesIO(image_bytes))
    # A phone holds rotation in EXIF rather than in the pixels, so a photo
    # taken in portrait arrives sideways and OCRs to nothing at all.
    image = ImageOps.exif_transpose(original)
    _log(trace, "decode", width=image.width, height=image.height,
         bytes=len(image_bytes), mode=original.mode,
         exif_rotated=image.size != original.size)
    if image.mode != "RGB":
        image = image.convert("RGB")
    pixels = numpy.array(image)
    quality = resolution_note(image.width, image.height, len(image_bytes))
    _log(trace, "quality", long_edge=max(image.width, image.height),
         bytes_per_pixel=round(len(image_bytes) / (image.width * image.height), 4),
         floor_long_edge=_MIN_LONG_EDGE,
         floor_bytes_per_pixel=_MIN_BYTES_PER_PIXEL,
         warned=quality is not None)
    ghosted = has_show_through(pixels)
    _log(trace, "show_through", detected=bool(ghosted), suppressed=bool(ghosted))
    if ghosted:
        pixels = suppress_show_through(pixels)
    results = easyocr_reader().readtext(
        pixels, paragraph=False,
        text_threshold=_TEXT_THRESHOLD, low_text=_LOW_TEXT)
    boxes = boxes_from_easyocr(results)
    if trace is not None:
        scores = sorted(round(float(c), 3) for _, _, c in results)
        _log(trace, "ocr", regions=len(results), kept=len(boxes),
             dropped_below_confidence=len(results) - len(boxes),
             min_confidence=_MIN_CONFIDENCE,
             median_confidence=scores[len(scores) // 2] if scores else None,
             lowest_kept=[{"text": b.text, "confidence": round(b.confidence, 3)}
                          for b in sorted(
                              boxes, key=lambda b: b.confidence or 1.0)[:5]])
    content, warnings = chordpro_from_boxes(boxes, trace=trace)
    # Suppression is NOT reported, and used to be. It said the reverse side of
    # the page had showed through, and `has_show_through` cannot support that:
    # measured across the eleven-page corpus it fires on every single page,
    # including the born-digital app screenshot, which has no reverse side and
    # no paper. The `0.00%-0.60% across seven clean scans` calibration behind
    # `_PALE_FRACTION` was measured on renders and simulated photographs, not on
    # real ones. A warning that fires on every import and names a cause it
    # cannot establish tells the user nothing.
    #
    # The suppression itself stays, because it is not really ghost removal: it
    # flattens the lighting and stretches the levels, and both readers need that
    # almost everywhere. Measured on the shipped path, turning it off costs 0.156
    # of the corpus mean - the app screenshot alone falls from 0.965 to 0.351.
    #
    # Withdrawn from `photo_text_bridge.dart` at the same time and for the same
    # reason: what the user is told has to be the same on both sides of the wire.
    if quality:
        # First, because it is the one problem the person holding the phone can
        # actually fix, and it caps how good anything below it can be.
        warnings.insert(0, quality)
    _log(trace, "warnings", count=len(warnings), prose=list(warnings))
    return content, warnings


def save_upload(directory, filename: str, image_bytes: bytes,
                content: str, warnings) -> pathlib.Path:
    """Keep an upload beside what was read from it. Returns the image's path.

    A photo posted from a phone exists only for the length of the request, so
    a report of "it read this song badly" leaves nothing to reproduce with.
    Both halves together turn that report into a test case.
    """
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)

    # Only the base name, and only its safe characters: this arrives off the
    # wire, so `../../etc/passwd` must land in the directory like anything else.
    stem = pathlib.PurePosixPath(filename.replace("\\", "/")).name
    stem = re.sub(r"[^A-Za-z0-9._-]", "_", stem) or "photo"
    suffix = pathlib.Path(stem).suffix or ".jpg"
    stem = pathlib.Path(stem).stem

    # A phone sends the same name again and again, so number them rather than
    # let the second reading erase the first.
    number = 1 + sum(1 for _ in directory.glob("[0-9][0-9][0-9]-*" + suffix))
    base = f"{number:03d}-{stem}"

    image_path = directory / (base + suffix)
    image_path.write_bytes(image_bytes)
    reading = content if not warnings else (
        content + "\n\n--- warnings ---\n" + "\n".join(warnings))
    (directory / (base + ".txt")).write_text(reading, encoding="utf-8")
    return image_path


def parse_multipart(body: bytes, content_type: str):
    """Returns (field_name -> bytes, field_name -> filename)."""
    headers = b"Content-Type: " + content_type.encode("latin-1") + b"\r\n\r\n"
    message = BytesParser(policy=default_policy).parsebytes(headers + body)
    files, names = {}, {}
    if not message.is_multipart():
        return files, names
    for part in message.iter_parts():
        name = part.get_param("name", header="content-disposition")
        if name:
            files[name] = part.get_payload(decode=True)
            names[name] = part.get_filename()
    return files, names


class Handler(BaseHTTPRequestHandler):
    mode = "stub"  # "stub" | "easyocr" | "live"
    save_dir = None  # set by --save-dir; keeps every upload for debugging

    def _cors(self):
        # The app is served from a different origin (a local file server, or
        # GitHub Pages), so every response needs these or the browser discards
        # a perfectly good reply. This is the failure that looks like "the
        # server never answered" in the app while the server logs a 200.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers",
                         "Authorization, Content-Type")
        self.send_header("Access-Control-Max-Age", "86400")

    def _json(self, status: int, payload: dict):
        encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self._cors()
        self.end_headers()
        self.wfile.write(encoded)

    def do_OPTIONS(self):  # noqa: N802 - BaseHTTPRequestHandler naming
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):  # noqa: N802
        # A browser pointed at the URL should say something useful rather than
        # 501, since the first thing anyone does is open it.
        self._json(200, {
            "service": "photo-import-worker",
            "mode": self.mode,
            "post": "/extract  multipart/form-data, image under `image`",
        })

    def do_POST(self):  # noqa: N802
        if self.path.rstrip("/") not in ("/extract", ""):
            self._json(404, {"error": "POST /extract"})
            return

        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        content_type = self.headers.get("Content-Type", "")
        files, names = parse_multipart(body, content_type)
        image = files.get("image")

        if not image:
            self._json(400, {"error": "no `image` part in the request"})
            return

        filename = names.get("image") or "photo.jpg"
        sys.stderr.write(
            f"[worker] {filename}: {len(image)} bytes, {self.mode}\n")

        if self.mode == "stub":
            self._json(200, {
                "kind": "chordpro",
                "content": stub_chordpro(filename, len(image)),
                "warnings": [
                    "STUB MODE — your photo was NOT read. Restart the worker "
                    "with --easyocr (free, offline) or --live to transcribe "
                    "for real.",
                ],
            })
            return

        try:
            if self.mode == "easyocr":
                content, warnings = extract_with_easyocr(image)
            else:
                media_type = "image/png" if filename.lower().endswith(".png") \
                    else "image/jpeg"
                content, warnings = extract_with_model(image, media_type)
        except Exception as exc:  # noqa: BLE001 - reported, not swallowed
            sys.stderr.write(f"[worker] {self.mode} read failed: {exc}\n")
            # 502 for the model because the failure is upstream; 500 for
            # EasyOCR because it is this process that broke.
            self._json(502 if self.mode == "live" else 500, {"error": str(exc)})
            return

        if not content.strip():
            # The app turns an empty content into "Nothing could be read from
            # that photo", which is the honest message for a blank page.
            self._json(200, {"kind": "chordpro", "content": "", "warnings": []})
            return

        if self.save_dir:
            try:
                kept = save_upload(self.save_dir, filename, image,
                                   content, warnings)
                sys.stderr.write(f"[worker] kept {kept}\n")
            except OSError as exc:  # noqa: BLE001 - never fail the import
                # A debugging aid must not be able to break the feature it is
                # there to debug.
                sys.stderr.write(f"[worker] could not keep upload: {exc}\n")

        self._json(200, {
            "kind": "chordpro",
            "content": content,
            "warnings": warnings,
        })

    def log_message(self, fmt, *args):
        sys.stderr.write("[worker] " + (fmt % args) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8790)
    parser.add_argument(
        "--host", default="127.0.0.1",
        help="0.0.0.0 to accept connections from other devices on the LAN. "
             "Note there is no authentication: the Authorization header is "
             "accepted and not checked, so anyone who can reach the port can "
             "spend your API key.")
    how = parser.add_mutually_exclusive_group()
    how.add_argument("--live", action="store_true",
                     help="call a vision model instead of returning the stub")
    how.add_argument("--easyocr", action="store_true",
                     help="read the photo with EasyOCR on this machine — free, "
                          "offline, no API key")
    parser.add_argument(
        "--save-dir",
        help="keep every uploaded photo here, beside the ChordPro it produced. "
             "A photo posted from a phone is gone the moment the request ends, "
             "so without this a bad reading cannot be reproduced.")
    args = parser.parse_args()

    if args.live and not read_api_key():
        sys.exit(
            "--live needs an API key. Put it in tools/.anthropic_key "
            "(one line, nothing else) or set ANTHROPIC_API_KEY.")

    Handler.mode = "live" if args.live else "easyocr" if args.easyocr else "stub"
    Handler.save_dir = args.save_dir
    banner = {
        "live": "LIVE (calls a model)",
        "easyocr": "EASYOCR (offline, no key)",
        "stub": "STUB (fixed response)",
    }[Handler.mode]

    if args.easyocr:
        # Loading torch and the language models takes seconds. Doing it now
        # rather than on the first photo keeps that delay out of a request the
        # app is timing at 90 seconds.
        print("loading EasyOCR models (first run downloads them)...")
        easyocr_reader()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"photo-import worker on http://{args.host}:{args.port}/extract  [{banner}]")
    if args.save_dir:
        print(f"  keeping every upload in {args.save_dir}")
    if args.host != "127.0.0.1":
        print("  reachable from the LAN, and UNAUTHENTICATED — see --host help")
    print("Paste that URL into Settings -> Photo import.")
    server.serve_forever()


if __name__ == "__main__":
    main()
