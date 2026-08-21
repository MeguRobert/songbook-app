"""The run-against-baseline table, and what counts as a regression.

The baseline is committed. That is the whole discipline: a change either moves a
number in the table or it does not, and nothing gets called an improvement
because the output looked better in a terminal once.
"""
from __future__ import annotations

import json
import pathlib

from . import metrics

HERE = pathlib.Path(__file__).resolve().parent
BASELINE = HERE / "baseline.json"

# Printed in this order, with these headings. lyric_cer and its accent-blind
# twin sit next to each other because the gap between them IS the diacritic
# problem, and that problem is fixed on the phone rather than in this repo.
COLUMNS = (
    ("headline", "score"),
    ("lyric_cer", "lyrCER"),
    ("lyric_cer_folded", "folded"),
    ("chord_recall", "chRec"),
    ("chord_precision", "chPrc"),
    ("chord_f1", "chF1"),
    ("placement", "place"),
    ("placement_near", "near"),
    ("warnings_ok", "warn"),
)

# What a regression is judged on. Wider than what is printed, and deliberately
# a separate list: chord_f1 fed the headline while being neither shown nor
# gated, so a run could lose half its chords and still pass. Printing and
# gating are different jobs and were wrong to share one list.
#
# Counts are excluded - lyric_lines_gold and its siblings cannot move unless
# the gold file moved, and then the baseline is meant to move with it.
GATED = ("headline", "number_exact", "title_cer", "lyric_cer",
         "lyric_cer_folded", "chord_recall", "chord_precision", "chord_f1",
         "placement", "placement_near", "warnings_ok")

# Tier C pages are handwritten-over-printed: which chord set the importer should
# keep is a product decision, so they are scored and shown but kept out of the
# headline average, where they would make every real improvement look flat.
HEADLINE_TIERS = ("A", "B")


def load_baseline() -> dict:
    if not BASELINE.exists():
        return {"accepted": None, "engines": {}}
    return json.loads(BASELINE.read_text(encoding="utf-8"))


def save_baseline(scores, accepted: str) -> None:
    """Promote [scores] to the committed baseline."""
    data = load_baseline()
    data["accepted"] = accepted
    for score in scores:
        engine = data["engines"].setdefault(score.engine, {})
        engine[score.page] = {
            key: round(score.values[key], 4) for key in GATED
            if key != "headline" and score.values.get(key) is not None
        }
        engine[score.page]["headline"] = round(score.headline, 4)
    BASELINE.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                        encoding="utf-8")


def _arrow(key: str, now: float, before: float | None) -> str:
    """How [now] compares with the baseline, as three characters."""
    if before is None:
        return "new"
    delta = now - before
    if abs(delta) < metrics.TOLERANCE:
        return "   "
    better = delta < 0 if key in metrics.LOWER_IS_BETTER else delta > 0
    return ("+" if better else "-") + f"{abs(delta):.2f}"[1:]


def regressions(scores, baseline: dict) -> list[str]:
    """Every metric that moved the wrong way beyond tolerance."""
    out = []
    for score in scores:
        before = baseline.get("engines", {}).get(score.engine, {}).get(score.page)
        if not before:
            continue
        for key in GATED:
            was = before.get(key)
            now = score.headline if key == "headline" else score.values.get(key)
            if was is None or now is None:
                continue
            delta = now - was
            if abs(delta) < metrics.TOLERANCE:
                continue
            worse = delta > 0 if key in metrics.LOWER_IS_BETTER else delta < 0
            if worse:
                out.append(f"{score.page} [{score.engine}] {key}: "
                           f"{was:.3f} -> {now:.3f}")
    return out


def render(scores, baseline: dict, *, unreviewed=()) -> str:
    """The table, as text."""
    lines: list[str] = []
    if baseline.get("accepted"):
        lines.append(f"baseline accepted {baseline['accepted']}")
    else:
        lines.append("no baseline yet - every number below is new")
    lines.append("")

    width = max((len(s.page) for s in scores), default = 20)
    header = f"{'page':<{width}} tier  " + "  ".join(
        f"{title:>6}" for _, title in COLUMNS)
    lines.append(header)
    lines.append("-" * len(header))

    for score in sorted(scores, key=lambda s: (s.engine, s.page)):
        before = (baseline.get("engines", {})
                  .get(score.engine, {}).get(score.page, {}))
        cells = []
        for key, _ in COLUMNS:
            now = score.headline if key == "headline" else score.values.get(key)
            cells.append("     -" if now is None else f"{now:6.3f}")
        lines.append(f"{score.page:<{width}} {score.tier:^4}  "
                     + "  ".join(cells))
        marks = []
        for key, title in COLUMNS:
            now = score.headline if key == "headline" else score.values.get(key)
            if now is None:
                continue
            arrow = _arrow(key, now, before.get(key))
            if arrow.strip() and arrow != "new":
                marks.append(f"{title} {arrow}")
        if marks:
            lines.append(f"{'':<{width}} {'':^4}  " + "  ".join(marks))
        for note in score.notes:
            lines.append(f"{'':<{width}} {'':^4}  . {note}")

    counted = [s for s in scores if s.tier in HEADLINE_TIERS]
    lines.append("")
    for engine in sorted({s.engine for s in scores}):
        mine = [s for s in counted if s.engine == engine]
        if mine:
            mean = sum(s.headline for s in mine) / len(mine)
            lines.append(f"{engine}: {mean:.3f} over {len(mine)} tier-A/B pages "
                         f"({len(scores) - len(counted)} tier-C shown, not counted)")

    if unreviewed:
        lines.append("")
        lines.append("GOLD NOT YET REVIEWED BY A HUMAN:")
        for page in sorted(unreviewed):
            lines.append(f"  {page}")
        lines.append("  These were transcribed from the photographs by "
                     "something other than the engine scored above, so the "
                     "comparison is not circular and the numbers do mean "
                     "something.")
        lines.append("  What is unverified is the transcription itself. A "
                     "misread word in a gold file becomes a permanent error "
                     "the engine can never score against, so read each one "
                     "beside its photograph and set reviewed_by.")
    return "\n".join(lines)
