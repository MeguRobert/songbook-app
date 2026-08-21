"""ChordPro text <-> an editable structure, both ways.

The editor works on `(which word, which chord)` rather than on character
columns, because a column is a consequence and not a decision: type one letter
into a lyric and every chord after it means something different. This module is
what makes that safe - it takes the monospaced text apart into words and chords,
and puts it back together with each chord over the word it was attached to.

Round-tripping preserves *placements*, not columns. Two chords over one long
word come back set one space apart rather than where the page happened to print
them, which is deliberate: the score compares which word a chord sits over, and
a pixel measurement that no metric reads is a detail nobody can maintain.
"""
from __future__ import annotations

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import photo_import_worker as worker  # noqa: E402

from . import reading as reading_mod  # noqa: E402

# A line's kind, as the editor shows it.
LYRIC = "lyric"
"""Words, with any number of chords attached to them."""

CHORDS = "chords"
"""A chord row with nothing under it: an intro, a turnaround, a section's
summary. The app stores these past the end of an empty lyric."""

BLANK = "blank"
"""A verse break. Blank lines are what delimit blocks."""


def to_lines(chordpro: str) -> list[dict]:
    """[chordpro] as editable lines.

    A chord row is folded into the lyric line beneath it, because that is the
    unit a person edits: the words and the chords over them are one thing.
    """
    # The parser's own directive rule, not a looser one. `startswith("{")` also
    # matched `{ad 'nsber, 25` - a real line of OCR garbage on
    # 105-kosz-jol-vagyok - and dropped it, so the editor would have silently
    # deleted a line of the answer the first time anyone saved that page.
    raw = [line for line in chordpro.split("\n")
           if not reading_mod._DIRECTIVE.match(line.strip())]
    # Trailing blanks carry no meaning and would come back as stray breaks.
    while raw and not raw[-1].strip():
        raw.pop()

    lines: list[dict] = []
    index = 0
    while index < len(raw):
        line = raw[index]
        if not line.strip():
            # Runs of blank lines are one break: two would add an empty block.
            if lines and lines[-1]["kind"] != BLANK:
                lines.append({"kind": BLANK})
            index += 1
            continue

        if not reading_mod.is_chord_row(line):
            lines.append({"kind": LYRIC, "text": line.rstrip(),
                          "chords": [], "after": []})
            index += 1
            continue

        below = raw[index + 1] if index + 1 < len(raw) else ""
        if not below.strip() or reading_mod.is_chord_row(below):
            lines.append({"kind": CHORDS,
                          "chords": _chord_tokens(line)})
            index += 1
            continue

        placements = reading_mod.placements_in(line, below, keep_separators=True)
        lines.append({
            "kind": LYRIC,
            "text": below.rstrip(),
            # `col` is where the page actually printed the chord. The editor
            # never shows it, and it is honoured on the way back out only while
            # it still lands on the same word - so opening a file and saving it
            # untouched is a no-op, and a measured column survives until someone
            # edits the words under it. Without this, the first save flattened
            # every chord onto its word's first letter and threw away the
            # alignment a reviewer compares against the photograph.
            # `sep` marks the page's own punctuation. Kept so a save puts
            # `G - C - D - ( C )` back as it was printed rather than flattening
            # it to `G C D C`; the editor shows these dimmed, and nothing that
            # scores counts them.
            "chords": [{"chord": p.chord, "word": p.word_index,
                        "col": p.column, "sep": p.separator}
                       for p in placements if p.word_index >= 0],
            # Past the end of the line: a turnaround printed after the last
            # word. The app stores these, so they cannot be dropped here, and
            # they carry their column for the same reason the others do.
            "after": [{"chord": p.chord, "col": p.column,
                       "sep": p.separator}
                      for p in placements if p.word_index < 0],
        })
        index += 2

    while lines and lines[-1]["kind"] == BLANK:
        lines.pop()
    return lines


def _chord_tokens(line: str) -> list[str]:
    """The chords on [line], dropping bare punctuation."""
    return [token for token in line.split()
            if not worker._SEPARATOR.match(token)
            or worker.is_continuation(token)]


def to_chordpro(lines) -> str:
    """Editable [lines] back to monospaced ChordPro.

    Each chord is set at the start column of the word it belongs to. Several
    chords on one word are spread rightwards a space at a time, and a chord that
    cannot fit before the next word's chord is pushed along rather than
    overwriting it - so the text stays readable and every chord keeps its word.
    """
    out: list[str] = []
    for line in lines:
        kind = line.get("kind", LYRIC)
        if kind == BLANK:
            out.append("")
            continue
        if kind == CHORDS:
            row = "  ".join(str(c) for c in line.get("chords", ()) if str(c).strip())
            if row:
                out.append(row)
            continue

        text = (line.get("text") or "").rstrip()
        chord_row = _lay_out_chords(text, line.get("chords", ()),
                                    line.get("after", ()))
        if chord_row:
            out.append(chord_row)
        out.append(text)

    while out and not out[-1].strip():
        out.pop()
    return "\n".join(out)


def _lay_out_chords(text: str, chords, after) -> str:
    """A chord row for [text], each chord over the word it is attached to."""
    words = reading_mod.words_in(text)
    wanted: list[tuple[int, str]] = []
    for entry in chords:
        chord = str(entry.get("chord", "")).strip()
        if not chord:
            continue
        index = entry.get("word", -1)
        if not isinstance(index, int) or not 0 <= index < len(words):
            continue
        _, start, end = words[index]
        remembered = entry.get("col")
        # Honoured only while it still points at the same word, by the same
        # containment rule the parser reads it back with. Edit the words and it
        # stops applying, which is the moment it would start lying.
        if isinstance(remembered, int) and start <= remembered <= end:
            wanted.append((remembered, chord))
        else:
            wanted.append((start, chord))

    # One space past the last word, so a trailing turnaround is unambiguously
    # past the end rather than sitting on the final syllable. A remembered
    # column is honoured while it is still past the end - which keeps the page's
    # own spacing in `G - C - D - ( C )` instead of packing it tight.
    #
    # Plain strings are accepted as well as {chord, col}: a gold file written by
    # hand, or by an older version of this module, has no columns to remember.
    column = len(text) + 1
    for entry in after:
        if isinstance(entry, dict):
            chord = str(entry.get("chord", "")).strip()
            remembered = entry.get("col")
        else:
            chord, remembered = str(entry).strip(), None
        if not chord:
            continue
        if isinstance(remembered, int) and remembered >= len(text):
            wanted.append((remembered, chord))
        else:
            wanted.append((column, chord))
            column += len(chord) + 1

    wanted.sort(key=lambda pair: pair[0])
    row = ""
    for start, chord in wanted:
        # Never overwrite the chord already placed: push right instead. Losing a
        # chord to a collision would silently change what the file asserts.
        start = max(start, len(row) + 1 if row else 0)
        row += " " * (start - len(row)) + chord
    return row.rstrip()
