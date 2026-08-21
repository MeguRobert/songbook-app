"""The hand-verified answers, and the corpus manifest they belong to.

A gold file holds the ChordPro a perfect reading would produce, monospaced so a
chord's column is its position, plus the handful of fields that are not
recoverable from the text. It is meant to be diffed against the photograph by
eye - so it stays one text field and five scalars, and never becomes a tree.

Two fields decide whether a score means anything.

`drafted_from` names what produced the text. A file drafted from an engine
cannot score that engine: it holds the engine's own reading, so the mark comes
back perfect and says nothing. A file transcribed from the photograph by
something else is independent and can score it.

`reviewed_by` outranks that. Once a human has compared the file with the page
and put their name here, it is evidence for every engine, including whatever
drafted it.
"""
from __future__ import annotations

import dataclasses
import json
import pathlib

from . import reading as reading_mod

HERE = pathlib.Path(__file__).resolve().parent
TOOLS = HERE.parent
PHOTOS = TOOLS / "fixtures" / "photos"
GOLD = TOOLS / "fixtures" / "gold"
MANIFEST = PHOTOS / "manifest.json"


@dataclasses.dataclass
class Page:
    """One corpus entry: the photograph, what it stresses, and its answer."""

    file: str
    path: pathlib.Path
    tier: str
    engine: str
    title: str | None
    book_number: int | None
    layout: str
    stresses: tuple[str, ...]
    gold: reading_mod.Reading | None
    reviewed_by: str | None
    drafted_from: str | None

    @property
    def stem(self) -> str:
        return pathlib.Path(self.file).stem

    @property
    def reviewed(self) -> bool:
        return bool(self.reviewed_by)

    def evidence_for(self, engine: str) -> bool:
        """Whether this gold file can honestly score [engine].

        An answer key has to come from the page. Two things qualify: a human
        review, or a transcription made by reading the photograph.

        Nothing an engine wrote qualifies, for any engine. The first version of
        this rule only rejected the engine that wrote the file, on the grounds
        that a different engine is at least not being marked against itself.
        That is true and still useless: `166-tekozlo-fiu` scored chord recall
        1.000 against gold drafted by EasyOCR, which meant "found everything
        EasyOCR found" - and EasyOCR had found three chords out of thirteen. The
        number read like success and described agreement with a bad reading.

        Fails closed on an absent provenance, which is what caught six files
        written before the field existed.
        """
        return self.reviewed or self.drafted_from == "vision"


def manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def gold_path(stem: str) -> pathlib.Path:
    return GOLD / f"{stem}.gold.json"


def load_gold(stem: str):
    """(Reading, who reviewed it, what drafted it) for [stem]."""
    path = gold_path(stem)
    if not path.exists():
        return None, None, None
    data = json.loads(path.read_text(encoding="utf-8"))
    parsed = reading_mod.parse(data["chordpro"],
                              tuple(data.get("warnings", ())))
    # The explicit fields win over anything a `{title:}` directive in the text
    # would say, so a gold file never has to carry a directive just to be
    # scoreable.
    return (dataclasses.replace(parsed,
                                number=data.get("number", parsed.number),
                                title=data.get("title", parsed.title)),
            data.get("reviewed_by"), data.get("drafted_from"))


def pages(only=(), engine_kind=None, with_gold=False) -> list[Page]:
    """The corpus, as Pages. [only] filters by filename substring."""
    out = []
    for entry in manifest()["pages"]:
        if only and not any(part in entry["file"] for part in only):
            continue
        if engine_kind and entry["engine"] != engine_kind:
            continue
        stem = pathlib.Path(entry["file"]).stem
        gold, reviewed_by, drafted_from = load_gold(stem)
        if with_gold and gold is None:
            continue
        out.append(Page(
            file=entry["file"], path=PHOTOS / entry["file"],
            tier=entry["tier"], engine=entry["engine"],
            title=entry.get("title"), book_number=entry.get("book_number"),
            layout=entry.get("layout", ""),
            stresses=tuple(entry.get("stresses", ())),
            gold=gold, reviewed_by=reviewed_by,
            drafted_from=drafted_from))
    return out


def write_skeleton(page: Page, chordpro: str, *, source: str,
                   source_engine: str) -> pathlib.Path:
    """Start a gold file for [page] from [chordpro], for a human to correct."""
    GOLD.mkdir(parents=True, exist_ok=True)
    path = gold_path(page.stem)
    data = {
        "file": page.file,
        "tier": page.tier,
        "engine": page.engine,
        "reviewed_by": None,
        "drafted_from": source_engine,
        "_review_checklist": [
            "Compare every line against the photograph, not against the app.",
            "Chord rows are monospaced: a chord's character column IS its "
            "position, so keep the alignment when you edit a lyric.",
            "Write chords exactly as the page prints them - em, H7, -7, fiszm. "
            "Storage spelling is the app's job, not this file's.",
            "warnings holds slugs, not prose: low-resolution, "
            "show-through-removed, two-songs, no-chords, german-chords, "
            "nothing-legible.",
            "Put your name in reviewed_by when the text matches the page. "
            "Until you do, every score against this file is circular.",
        ],
        "_stresses": list(page.stresses),
        "_drafted_from_note": source,
        "number": page.book_number,
        "title": page.title,
        "warnings": [],
        "chordpro": chordpro,
    }
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                    encoding="utf-8")
    return path
