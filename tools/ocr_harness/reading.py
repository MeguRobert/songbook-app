"""The model: one page of recognised song, however it was recognised.

A Reading is parsed out of the ChordPro text an engine produced, so every engine
lands in the same shape and the gold answer is a file a human can read. Nothing
here does any recognising.
"""
from __future__ import annotations

import dataclasses
import hashlib
import pathlib
import re
import sys
import unicodedata

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import photo_import_worker as worker  # noqa: E402

# `{title: ...}` and `{number: ...}` - the only directives the worker emits, and
# the only ones the app's paste box reads back.
_DIRECTIVE = re.compile(r"^\{\s*(\w+)\s*:\s*(.*?)\s*\}$")

# A leading song number, as the app splits it: `147. Isten fenye`, `98 . Cim`,
# `151 Zengjed a dalt`. Kept here rather than imported because the app owns the
# storage-side rule in Dart and this side only has to agree about the shape.
_NUMBER_IN_TITLE = re.compile(r"^\s*(\d{1,4})\s*\.?\s+(.*\S)\s*$")

# The app's ImportNoticeCode names, and the stable slug each is scored as.
#
# The shipped reader emits codes rather than sentences - its prose lives in
# `AppLocalizations.importNoticeText`, translated three ways - so the browser arm
# reports `notice.code.name` and this is the whole mapping. A code name is a far
# stabler contract than the English wording below: rewording a warning used to
# unmap it silently, which is exactly what the debt note here used to warn about.
WARNING_CODES = {
    "photoLowResolution": "low-resolution",
    "photoShowThroughRemoved": "show-through-removed",
    "photoNothingLegible": "nothing-legible",
    "photoTwoSongs": "two-songs",
    "photoNoChords": "no-chords",
    "photoGermanNoteNames": "german-chords",
}

# The prose `photo_import_worker.py` emits, and the same slugs. Kept because the
# worker answers over the wire in its own words - which is what
# `ImportNoticeCode.fromReader` exists to carry - so there is no code to read on
# that side. Substrings, in the order it can emit them.
WARNING_SLUGS = (
    ("too compressed to hold the fine strokes", "low-resolution"),
    ("reverse side of the page showed through", "show-through-removed"),
    ("Nothing legible", "nothing-legible"),
    ("songs side by side", "two-songs"),
    ("No chords were recognised", "no-chords"),
    ("stored under the English name", "german-chords"),
)

PAST_END = "(past end)"


def slugs_for(warnings) -> tuple[str, ...]:
    """[warnings] as stable slugs. Anything unrecognised is kept verbatim."""
    out = []
    for warning in warnings:
        if warning in WARNING_CODES:
            out.append(WARNING_CODES[warning])
            continue
        for needle, slug in WARNING_SLUGS:
            if needle in warning:
                out.append(slug)
                break
        else:
            out.append("unmapped:" + warning[:40])
    return tuple(out)


def fold_accents(text: str) -> str:
    """[text] with every diacritic removed.

    Used for the accent-blind twin of the lyric error rate. The Hungarian long
    umlauts are the corpus's single commonest error and they are destroyed by
    JPEG compression rather than by anything in the pipeline, so a number that
    cannot see them is the one that says whether the *parsing* improved.
    """
    return "".join(c for c in unicodedata.normalize("NFD", text)
                   if not unicodedata.combining(c))


@dataclasses.dataclass(frozen=True)
class Placement:
    """One chord, and the lyric word it sits over."""

    chord: str
    """As written on the page: `em`, `H7`, `-7`, `(C)`."""

    column: int
    """Character column of the chord's first glyph in its row."""

    word: str
    """The lyric word underneath, or PAST_END when the row ran out."""

    word_index: int
    """Index of that word in its lyric line; -1 for PAST_END."""

    separator: bool = False
    """True for the page's own punctuation - a bare `-`, `|`, `(`, `)`.

    Only ever set when a caller asked `placements_in` to keep separators, which
    is the editor and nothing that scores. It exists so the editor can put the
    punctuation back exactly where the page printed it.
    """

    def key(self):
        """What placement equality is judged on.

        The word's *text* is deliberately not in here. It used to be, and that
        made a misread comma cost a placement: `151-zengjed-a-dalt` had `D`
        sitting on exactly the right word, but the recogniser read that word as
        `dalt;` instead of `dalt,` and the chord scored as misplaced. The letters
        are what `lyric_cer` measures; a metric that charges for them twice
        cannot be read.
        """
        return (self.chord, self.word_index)


@dataclasses.dataclass(frozen=True)
class Reading:
    """One recognised page, normalised."""

    chordpro: str
    number: int | None
    title: str | None
    lyrics: tuple[str, ...]
    placements: tuple[Placement, ...]
    chord_rows: int
    blocks: int
    warnings: tuple[str, ...]

    @property
    def lyric_text(self) -> str:
        """Every lyric line, newline-joined.

        The error rate is taken over this single string rather than line by
        line, so a line the engine merged or split costs one character instead
        of throwing every later line out of alignment.
        """
        return "\n".join(self.lyrics)

    @property
    def chords(self) -> tuple[str, ...]:
        return tuple(p.chord for p in self.placements)

    def to_json(self) -> dict:
        return {
            "number": self.number,
            "title": self.title,
            "chord_rows": self.chord_rows,
            "blocks": self.blocks,
            "warnings": list(self.warnings),
            "chordpro": self.chordpro,
        }


def fingerprint(page) -> str:
    """A short digest of the answer a score was marked against.

    Stored beside the numbers, because a number is only comparable with the last
    one when both were marked against the same answer key. Teaching the token
    rule that `fiszm` is F sharp minor moved four rows of `166-tekozlo-fiu` out
    of gold's lyrics and into its chords: the reading found six more chords than
    before and its recall FELL, because the answer key had grown. Called a
    regression, that reads as an instruction to undo an improvement.
    """
    material = chr(0).join((page.chordpro,) + tuple(page.warnings))
    return hashlib.sha256(material.encode("utf-8")).hexdigest()[:12]


def words_in(line: str):
    """(text, start, end) for every whitespace-delimited run in [line]."""
    return [(m.group(0), m.start(), m.end())
            for m in re.finditer(r"\S+", line)]


def placements_in(chord_row: str, lyric_row: str,
                  keep_separators: bool = False) -> list[Placement]:
    """Which lyric word each chord in [chord_row] sits over.

    A chord belongs to the word whose span contains its first column. `end`
    rather than `end - 1` is deliberate and matches tools/fixtures/score.py: a
    chord set one space past a word still belongs to that word, because that is
    how a typesetter avoids a chord colliding with the letter below it.
    """
    words = words_in(lyric_row)
    out = []
    for chord, start, _ in words_in(chord_row):
        # A bare `-`, `|` or `:|` is punctuation a chord row carries, not a
        # chord. Scoring it would inflate every count on a page that writes its
        # turnarounds as `G - C - D - C`, and an engine that dropped the dashes
        # while reading every chord would look worse than one that kept them.
        # `-7` is different and stays: it names the chord before it.
        #
        # [keep_separators] is for the editor, which has to be able to put the
        # page's own punctuation back where it found it. Nothing that scores
        # ever passes it: the gold text is a transcription, and a transcription
        # that quietly dropped `G - C - D - ( C )` down to `G C D C` would stop
        # matching the page a reviewer is holding it against.
        separator = (worker._SEPARATOR.match(chord)
                     and not worker.is_continuation(chord))
        # A section name is punctuation of the same kind: `109-tart-meg-a-kegyelem`
        # writes `Gm  A7  Dm  - Intro`, and scoring `Intro` as a chord asked
        # every engine for a symbol the token rule cannot even spell. Held to
        # the same [keep_separators] rule, so the editor still shows the
        # reviewer the word the page prints.
        if not separator and worker.is_direction(chord):
            separator = True
        if separator and not keep_separators:
            continue
        index, word = -1, PAST_END
        for i, (text, w_start, w_end) in enumerate(words):
            if w_start <= start <= w_end:
                index, word = i, text
                break
        out.append(Placement(chord=chord, column=start, word=word,
                             word_index=index, separator=bool(separator)))
    return out


def is_chord_row(line: str) -> bool:
    """True when [line] should be read as chords, by the worker's own rule."""
    return bool(line.split()) and worker.is_chord_row(line.split())


def parse(chordpro: str, warnings=()) -> Reading:
    """A [chordpro] page as a Reading.

    Blank lines delimit blocks. A chord row is paired with the line under it
    when that line is lyrics; otherwise it stands alone, which is how an intro
    or a turnaround survives.
    """
    number = title = None
    lyrics: list[str] = []
    placements: list[Placement] = []
    chord_rows = 0
    blocks = 0
    in_block = False

    body: list[str] = []
    for raw in chordpro.split("\n"):
        directive = _DIRECTIVE.match(raw.strip())
        if directive:
            field, value = directive.group(1).lower(), directive.group(2)
            if field == "title":
                match = _NUMBER_IN_TITLE.match(value)
                if match:
                    number, title = int(match.group(1)), match.group(2)
                else:
                    title = value
            elif field == "number" and value.strip().isdigit():
                number = int(value.strip())
            continue
        body.append(raw)

    index = 0
    while index < len(body):
        line = body[index]
        if not line.strip():
            in_block = False
            index += 1
            continue
        if not in_block:
            blocks += 1
            in_block = True

        if not is_chord_row(line):
            lyrics.append(line.rstrip())
            index += 1
            continue

        chord_rows += 1
        below = body[index + 1] if index + 1 < len(body) else ""
        if below.strip() and not is_chord_row(below):
            placements.extend(placements_in(line, below))
            lyrics.append(below.rstrip())
            index += 2
        else:
            # Chords with nothing underneath: an intro, a turnaround, or a
            # section's chord summary. Scored as placements past the end of an
            # empty lyric, which is how the app stores them.
            placements.extend(placements_in(line, ""))
            index += 1

    return Reading(chordpro=chordpro, number=number, title=title,
                   lyrics=tuple(lyrics), placements=tuple(placements),
                   chord_rows=chord_rows, blocks=blocks,
                   warnings=tuple(warnings))
