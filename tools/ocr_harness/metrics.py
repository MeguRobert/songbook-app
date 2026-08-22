"""What a Reading scores against the hand-verified answer.

Never one blended number on its own. Every headline here is printed beside its
parts, because the three things that can go wrong - the letters, which chords
were found, where those chords sit - are fixed in three different files, and a
single average tells you none of that.
"""
from __future__ import annotations

import collections
import dataclasses
import re
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import photo_import_worker as worker  # noqa: E402

from . import reading as reading_mod  # noqa: E402

# The three parts the headline averages. Equal weight, and deliberately not
# tuned: a weighting that makes one page look better is a weighting that hides
# the next regression.
HEADLINE_PARTS = ("lyric_accuracy", "chord_f1", "placement_near")

# Metrics where a smaller number is better. Everything else improves upward.
LOWER_IS_BETTER = frozenset({"lyric_cer", "lyric_cer_folded", "title_cer"})

# How far a metric may drift before the report calls it a change rather than
# noise. EasyOCR is deterministic on fixed input, so this only absorbs the
# rounding in the ratios themselves.
TOLERANCE = 0.005


def levenshtein(a: str, b: str) -> int:
    """Edit distance between [a] and [b], two rows at a time."""
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, start=1):
        current = [i]
        for j, cb in enumerate(b, start=1):
            current.append(min(previous[j] + 1,
                               current[j - 1] + 1,
                               previous[j - 1] + (ca != cb)))
        previous = current
    return previous[-1]


def cer(want: str, got: str) -> float:
    """Character error rate of [got] against [want]; 0.0 is perfect.

    Not clamped to 1.0. An engine that emitted twice the text it should have is
    worse than one that emitted nothing, and a number above 1.0 says so.
    """
    if not want:
        return 0.0 if not got else 1.0
    return levenshtein(want, got) / len(want)


def _multiset_scores(want, got) -> tuple[float, float, float]:
    """(recall, precision, f1) over two multisets."""
    want_counts = collections.Counter(want)
    got_counts = collections.Counter(got)
    hit = sum((want_counts & got_counts).values())
    recall = hit / len(list(want)) if want else (1.0 if not got else 0.0)
    precision = hit / len(list(got)) if got else (1.0 if not want else 0.0)
    if recall + precision == 0:
        return recall, precision, 0.0
    return recall, precision, 2 * recall * precision / (recall + precision)


SLACK = 1
"""How many words a chord may be out and still count as placed."""


def _near_placement(want, got) -> float:
    """F1 over placements matched by chord, within SLACK words.

    Greedy and nearest-first, so a chord matches the closest unused candidate
    rather than the first one scanned. Both sides are small - a page holds tens
    of chords - so the quadratic scan is not worth avoiding.
    """
    if not want:
        return 1.0 if not got else 0.0
    unused = list(got)
    hit = 0
    for target in want:
        best, distance = None, None
        for candidate in unused:
            if candidate.chord != target.chord:
                continue
            gap = abs(candidate.word_index - target.word_index)
            # A chord past the end of its line matches only another past the
            # end: -1 against word 0 is a one-word gap by arithmetic and a
            # different thing entirely on the page.
            if (candidate.word_index < 0) != (target.word_index < 0):
                continue
            if gap <= SLACK and (distance is None or gap < distance):
                best, distance = candidate, gap
        if best is not None:
            unused.remove(best)
            hit += 1
    recall = hit / len(want)
    precision = hit / len(got) if got else 0.0
    if recall + precision == 0:
        return 0.0
    return 2 * recall * precision / (recall + precision)


# What an unspellable chord symbol looks like, as opposed to a word.
#
# A note letter, then something no Hungarian word carries in that position: a
# figure, a slash bass, a hyphen joining two chords, or one of the Hungarian
# accidental spellings. This catches `fiszm`, `Amaj7-A7`, `Cadd9-Csus2`,
# `G5-Gsus2`, `D4/Fis` and `D-E`, and rejects `Mennybe`, `hogyha` and `fenn`.
_CHORD_SHAPED = re.compile(r"^[A-Ha-h](?:.*[\d/-]|(?:isz|is|esz|es))",
                           re.IGNORECASE)


def rows_lost_to_a_token(chordpro: str) -> list[tuple[str, str]]:
    """(row, tokens) for every row of [chordpro] that ALMOST reads as chords.

    A row of chord symbols where at least one is spelled in a way the token rule
    does not admit. The all-or-nothing rule then emits the whole row as lyrics
    and every chord on it is gone - the most expensive single thing a token rule
    can get wrong, and the one `unclassifiable` cannot see, because the row it
    happened to never contributed a chord to look at.

    A row qualifies only when EVERY token on it is already a chord, a separator,
    or chord-shaped by [_CHORD_SHAPED]. That `every` is what keeps a lyric line
    out: `A Mennybe fenn számítanak rád,` opens with a chord and its other words
    are words.
    """
    out = []
    for line in chordpro.split("\n"):
        texts = line.split()
        if not texts or reading_mod.is_chord_row(line):
            continue
        unknown = []
        for text in texts:
            if (worker._SEPARATOR.match(text) or worker.is_continuation(text)
                    or worker.is_chord_token(text)):
                continue
            if not _CHORD_SHAPED.match(text):
                unknown = []
                break
            unknown.append(text)
        if unknown:
            out.append((line, " ".join(sorted(set(unknown)))))
    return out


def unclassifiable(chords) -> list[str]:
    """The [chords] the worker's own token rule does not accept as chords.

    Engine-independent: it asks only whether _CHORD_TOKEN can spell the symbol
    the page prints. Anything listed here is a chord no reading can ever get
    right, whatever the OCR does - which makes it the shortest actionable list
    the harness produces.
    """
    out = []
    for chord in chords:
        if worker.is_chord_token(chord) or worker.is_continuation(chord):
            continue
        out.append(chord)
    return sorted(set(out))


@dataclasses.dataclass
class Score:
    """One page's scores. Ordered as it is printed."""

    page: str
    engine: str
    tier: str
    values: dict
    notes: list[str] = dataclasses.field(default_factory=list)

    gold: str | None = None
    """Digest of the answer this was marked against - see report.gold_fingerprint.

    A number is comparable with the last one only when both were marked against
    the same answer key, and the key does move: a token rule that learns a new
    spelling turns gold lyric rows into gold chord rows.
    """

    @property
    def headline(self) -> float:
        parts = [self.values[k] for k in HEADLINE_PARTS
                 if self.values.get(k) is not None]
        return sum(parts) / len(parts) if parts else 0.0


def score(gold: reading_mod.Reading, got: reading_mod.Reading, *,
          page: str, engine: str, tier: str) -> Score:
    """[got] measured against [gold]."""
    values: dict = {}
    notes: list[str] = []

    values["number_exact"] = (None if gold.number is None
                              else float(gold.number == got.number))
    values["title_cer"] = (None if gold.title is None
                           else cer(gold.title, got.title or ""))

    values["lyric_cer"] = cer(gold.lyric_text, got.lyric_text)
    values["lyric_accuracy"] = max(0.0, 1.0 - values["lyric_cer"])
    values["lyric_cer_folded"] = cer(reading_mod.fold_accents(gold.lyric_text),
                                     reading_mod.fold_accents(got.lyric_text))

    recall, precision, f1 = _multiset_scores(gold.chords, got.chords)
    values["chord_recall"] = recall
    values["chord_precision"] = precision
    values["chord_f1"] = f1

    # Placement is judged on (chord, which word) so it is order-insensitive but
    # position-aware: a chord read correctly but hung over the wrong syllable is
    # the failure a singer notices, and it scores zero here while still counting
    # as found above.
    _, _, placement_f1 = _multiset_scores(
        [p.key() for p in gold.placements], [p.key() for p in got.placements])
    values["placement"] = placement_f1

    # And again allowing one word of slack, which is the number the headline
    # uses. On a real page the chords are set at fixed horizontal positions and
    # do not track the words underneath: the app screenshot has the same `D` of
    # the same phrase sitting over `lát!` in one verse and over the end of
    # `szemedbe` in the next. Demanding the exact word would score a reading
    # down for choosing the other reasonable answer to a question the page does
    # not settle - while a chord landing two words out is a real error, and
    # still scores as one.
    values["placement_near"] = _near_placement(gold.placements,
                                               got.placements)

    values["lyric_lines_gold"] = float(len(gold.lyrics))
    values["lyric_lines_got"] = float(len(got.lyrics))
    values["chord_rows_gold"] = float(gold.chord_rows)
    values["chord_rows_got"] = float(got.chord_rows)
    values["blocks_gold"] = float(gold.blocks)
    values["blocks_got"] = float(got.blocks)

    want_warnings = set(gold.warnings)
    got_warnings = set(got.warnings)
    missing = sorted(want_warnings - got_warnings)
    extra = sorted(got_warnings - want_warnings)
    values["warnings_ok"] = float(not missing and not extra)
    if missing:
        notes.append("warning not raised: " + ", ".join(missing))
    if extra:
        notes.append("warning raised unasked: " + ", ".join(extra))

    blocked = unclassifiable(gold.chords)
    if blocked:
        notes.append("chord symbols the token rule cannot spell: "
                     + ", ".join(blocked))

    if len(got.lyrics) != len(gold.lyrics):
        notes.append(f"{len(got.lyrics)} lyric lines against "
                     f"{len(gold.lyrics)} expected")

    return Score(page=page, engine=engine, tier=tier, values=values,
                 notes=notes, gold=reading_mod.fingerprint(gold))
