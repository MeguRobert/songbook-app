"""The workflow.

    python -m tools.ocr_harness list                       what is in the corpus
    python -m tools.ocr_harness edit                        the gold editor
    python -m tools.ocr_harness draft 185                   gold skeleton to correct
    python -m tools.ocr_harness run                         read, score, table
    python -m tools.ocr_harness run --engine vision         the ceiling
    python -m tools.ocr_harness trace 185                   why each row went where
    python -m tools.ocr_harness symbols                     chords no rule can spell
    python -m tools.ocr_harness accept                      promote to baseline

`run` exits non-zero when any metric moved the wrong way against the committed
baseline, so it can gate a commit.
"""
from __future__ import annotations

import argparse
import io
import json
import pathlib
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

from . import engines, gold, metrics, report  # noqa: E402

RUNS = gold.TOOLS / "fixtures" / "runs"


def cmd_list(args) -> int:
    for page in gold.pages(args.pages):
        state = ("reviewed by " + page.reviewed_by if page.reviewed
                 else "gold UNREVIEWED" if page.gold else "no gold yet")
        print(f"{page.tier}  {page.engine:<8} {page.file}")
        print(f"      {page.layout}")
        print(f"      {state}")
        if args.verbose:
            for stress in page.stresses:
                print(f"        - {stress}")
    return 0


def cmd_draft(args) -> int:
    engine = engines.engine(args.engine)
    for page in gold.pages(args.pages):
        if gold.gold_path(page.stem).exists() and not args.force:
            print(f"skipped {page.file}: gold exists (use --force)")
            continue
        result = engine.read(page.path)
        path = gold.write_skeleton(page, result.reading.chordpro,
                                   source=f"{engine.name} reading, uncorrected",
                                   source_engine=engine.name)
        print(f"wrote {path}")
        print("  correct it against the photograph, then set reviewed_by")
    return 0


def cmd_run(args) -> int:
    engine = engines.engine(args.engine)
    scores, artefacts, unreviewed, waiting = [], {}, [], []
    candidates = [
        page for page in gold.pages(args.pages, engine_kind=args.kind,
                                    with_gold=True)
        if page.evidence_for(engine.name) or args.include_unreviewed]
    # A batched engine reads everything in one session: starting a browser and
    # downloading the OCR model costs far more than reading a page.
    if hasattr(engine, "prepare"):
        engine.prepare(candidates)
    for page in gold.pages(args.pages, engine_kind=args.kind, with_gold=True):
        # A gold file `draft` wrote holds the engine's own reading. Scoring an
        # engine against it returns 1.000 for everything and means nothing -
        # the same circularity as reading back a page the app itself rendered.
        # So an unreviewed file is not evidence and is not scored, unless
        # someone asks for it in as many words.
        if not page.evidence_for(engine.name) and not args.include_unreviewed:
            waiting.append(page.file)
            continue
        result = engine.read(page.path)
        scores.append(metrics.score(page.gold, result.reading, page=page.file,
                                    engine=engine.name, tier=page.tier))
        artefacts[page.file] = {
            "engine": engine.name,
            "seconds": round(result.seconds, 2),
            "reading": result.reading.to_json(),
            "trace": result.trace,
        }
        if not page.reviewed:
            unreviewed.append(page.file)

    if not scores:
        print("nothing to score.")
        if waiting:
            print(f"{len(waiting)} pages have a gold file that nobody has "
                  "reviewed yet:")
            for page_name in waiting:
                print("  " + page_name)
            print("\nEach one holds an engine's own reading, so scoring "
                  "against it would return a perfect mark and prove nothing.\n"
                  "Correct it against the photograph and set reviewed_by, or "
                  "pass --include-unreviewed to see the circular number "
                  "anyway.")
        else:
            print("No page has a gold file. Start with: "
                  "python -m tools.ocr_harness draft")
        return 1

    baseline = report.load_baseline()
    print(report.render(scores, baseline, unreviewed=unreviewed))
    if waiting:
        print(f"\n{len(waiting)} pages not scored, gold unreviewed: "
              + ", ".join(waiting))

    RUNS.mkdir(parents=True, exist_ok=True)
    out = RUNS / f"{engine.name}-latest.json"
    out.write_text(json.dumps({
        "engine": engine.name,
        "scores": [{"page": s.page, "tier": s.tier, "headline": s.headline,
                    "values": s.values, "notes": s.notes} for s in scores],
        "pages": artefacts,
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\nrun written to {out}")

    if args.accept:
        report.save_baseline(scores, accepted=args.accept)
        print(f"baseline updated, accepted {args.accept}")
        return 0

    worse = report.regressions(scores, baseline)
    if worse:
        print("\nREGRESSION:")
        for line in worse:
            print("  " + line)
        return 1
    return 0


def cmd_trace(args) -> int:
    engine = engines.engine(args.engine)
    pages = gold.pages(args.pages)
    if hasattr(engine, "prepare"):
        engine.prepare(pages)
    for page in pages:
        result = engine.read(page.path)
        print(f"=== {page.file} [{engine.name}] {result.seconds:.1f}s ===")
        for record in result.trace:
            stage = record.pop("stage")
            if stage == "row":
                mark = "C" if record["classified"] == "chord" else " "
                print(f"  row {record['row']:>2} col {record['column']} {mark} "
                      f"h{record['height']:>5} "
                      f"conf {record['confidence']} "
                      f"{'BREAK ' if record['verse_break_before'] else '      '}"
                      f"{record['reason']}")
                print(f"         {' '.join(record['texts'])}")
            elif stage == "pairing":
                print(f"  pair    col {record['column']} row "
                      f"{record['chord_row']} -> {record['paired_with']}"
                      f"  ({record['reason']})")
            else:
                print(f"  {stage}: " + json.dumps(record, ensure_ascii=False))
        print()
        print(result.reading.chordpro)
        print()
    return 0


def cmd_align(args) -> int:
    """Measured geometry, for writing a gold answer by hand.

    The draft a reading produces has its chords on the wrong words: `_lay_out`
    packs the lyric onto a computed character width and then interpolates the
    chord row onto that grid, so any error in the width slides every chord
    along. What the recogniser is reliably good at is where things are on the
    page, even when it is wrong about what they say.

    So this prints pixel spans, and for each chord the lyric word whose span
    contains it - the division of labour the corpus is built on: the recogniser
    supplies the geometry, a human supplies the words.
    """
    from . import geometry

    for page in gold.pages(args.pages):
        print(f"=== {page.file} ===")
        for line in geometry.describe(page.path):
            print(line)
        print()
    return 0


def cmd_edit(args) -> int:
    """Serve the gold editor. Edits are written straight into the gold files."""
    from . import editor

    editor.serve(port=args.port, open_browser=not args.no_open)
    return 0


def cmd_review(args) -> int:
    """Build the page for checking each gold answer against its photograph."""
    from . import review

    path = review.build()
    print(f"wrote {path}")
    if not args.no_open:
        import webbrowser

        webbrowser.open(path.as_uri())
    return 0


def cmd_symbols(args) -> int:
    """Every chord symbol in the gold answers that no rule can spell.

    Two lists, because the expensive case hides from the cheap one.

    `Reading.chords` only holds chords from rows that already classified AS
    chords, so a symbol so unspellable that it costs its whole row never reaches
    it. This command reported "every gold chord symbol is spellable" while
    `fiszm` was taking two of `166-tekozlo-fiu`'s chord rows down to lyrics -
    which is the worse failure of the two and the one worth naming first.
    """
    blocked: dict[str, list[str]] = {}
    lost: dict[str, list[tuple[str, str]]] = {}
    for page in gold.pages(args.pages, with_gold=True):
        for chord in metrics.unclassifiable(page.gold.chords):
            blocked.setdefault(chord, []).append(page.file)
        for row, token in metrics.rows_lost_to_a_token(page.gold.chordpro):
            lost.setdefault(token, []).append((page.file, row))

    if lost:
        print("chord rows the token rule reads as LYRICS, and the one token that")
        print("costs each of them every chord it carries:")
        print()
        for token, where in sorted(lost.items()):
            print(f"  {token}")
            for file, row in sorted(set(where)):
                print(f"      {file}")
                print(f"      {row.strip()}")
        print()

    if blocked:
        print("chord symbols inside rows that DO classify, which the token rule")
        print("still cannot spell - a reading can never get these right:")
        print()
        for chord, pages_ in sorted(blocked.items()):
            print(f"  {chord:<16} {', '.join(sorted(set(pages_)))}")
        print()

    if not blocked and not lost:
        print("every gold chord symbol is spellable by the current token rule")
        return 0

    print("_CHORD_TOKEN in tools/photo_import_worker.py, and its port in")
    print("songbook_app/lib/domain/services/chord_sheet_parser.dart, both have")
    print("to agree - the app re-parses whatever the worker emits.")
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="tools.ocr_harness",
                                     description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def add_pages(p):
        p.add_argument("pages", nargs="*", default=(),
                       help="filename substrings; omit for the whole corpus")

    p = sub.add_parser("list", help="what is in the corpus")
    add_pages(p)
    p.add_argument("-v", "--verbose", action="store_true",
                   help="also print what each page stresses")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("draft", help="write a gold skeleton to correct by hand")
    add_pages(p)
    p.add_argument("--engine", default="easyocr", choices=engines.names())
    p.add_argument("--force", action="store_true", help="overwrite existing gold")
    p.set_defaults(func=cmd_draft)

    p = sub.add_parser("run", help="read the corpus, score it, print the table")
    add_pages(p)
    p.add_argument("--engine", default="easyocr", choices=engines.names())
    p.add_argument("--kind", choices=("text", "notation"),
                   help="only pages meant for this path")
    p.add_argument("--accept", metavar="DATE",
                   help="promote this run to the baseline, stamped with DATE")
    p.add_argument("--include-unreviewed", action="store_true",
                   help="score against gold nobody has checked (circular)")
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("trace", help="every stage decision for a page")
    add_pages(p)
    p.add_argument("--engine", default="easyocr", choices=engines.names())
    p.set_defaults(func=cmd_trace)

    p = sub.add_parser("align", help="measured geometry, for writing gold by hand")
    add_pages(p)
    p.set_defaults(func=cmd_align)

    p = sub.add_parser("edit", help="open the gold editor (writes to disk)")
    p.add_argument("--port", type=int, default=8799)
    p.add_argument("--no-open", action="store_true",
                   help="serve without opening a browser")
    p.set_defaults(func=cmd_edit)

    p = sub.add_parser("review",
                       help="build and open the gold-vs-photograph page")
    p.add_argument("--no-open", action="store_true",
                   help="write the file without opening a browser")
    p.set_defaults(func=cmd_review)

    p = sub.add_parser("symbols", help="gold chords no token rule can spell")
    add_pages(p)
    p.set_defaults(func=cmd_symbols)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
