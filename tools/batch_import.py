#!/usr/bin/env python3
"""
Batch importer for the Songbook app.

Drives convert_hymn.py over many songs listed in a manifest (JSON or CSV), so a
whole hymnal section can be imported in one run. Manifest/command logic is pure
and unit-tested; the actual OMR/OCR work is done by convert_hymn.py (which needs
the EXTERNAL Audiveris + EasyOCR tools — see IMPORT-PIPELINE.md).

Manifest row fields:
    song        (required, int)   — song number to update in songs.json
    image       (str)             — sheet-music image path  } one of these
    from_xml    (str)             — MusicXML/.mxl path       } is required
    book        (str, optional)   — hymnal/book name
    systems     (int, optional)   — number of staff systems (for OCR)
    ocr_lyrics  (bool, optional)  — run OCR lyric extraction
    no_validate (bool, optional)  — pass --no-validate through (discouraged)

Usage:
    python batch_import.py manifest.json [--dry-run] [--continue-on-error]
    python batch_import.py manifest.csv  --dry-run
    python batch_import.py --validate-only
"""

import argparse
import csv
import json
import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONVERT_SCRIPT = os.path.join(SCRIPT_DIR, "convert_hymn.py")

_TRUE = {"1", "true", "yes", "y", "on"}


def _to_bool(value):
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in _TRUE


def _to_int(value, field):
    try:
        return int(value)
    except (TypeError, ValueError):
        raise ValueError(f"row field '{field}' must be an integer, got {value!r}")


def _normalize_row(raw):
    """Validate + coerce a single manifest row to typed values."""
    row = dict(raw)
    if "song" not in row or row.get("song") in (None, ""):
        raise ValueError("manifest row missing required 'song'")
    row["song"] = _to_int(row["song"], "song")

    image = (row.get("image") or "").strip()
    from_xml = (row.get("from_xml") or "").strip()
    if not image and not from_xml:
        raise ValueError(
            f"row for song {row['song']} needs either 'image' or 'from_xml'")
    row["image"] = image or None
    row["from_xml"] = from_xml or None

    if row.get("systems") not in (None, ""):
        row["systems"] = _to_int(row["systems"], "systems")
    else:
        row["systems"] = None

    book = (row.get("book") or "").strip()
    row["book"] = book or None
    row["ocr_lyrics"] = _to_bool(row.get("ocr_lyrics"))
    row["no_validate"] = _to_bool(row.get("no_validate"))
    return row


def load_manifest(path):
    """Load a JSON (list of objects) or CSV (header row) manifest into typed rows."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"manifest not found: {path}")

    if p.suffix.lower() == ".json":
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, list):
            raise ValueError("JSON manifest must be a list of row objects")
        raw_rows = data
    elif p.suffix.lower() == ".csv":
        with open(p, "r", encoding="utf-8", newline="") as f:
            raw_rows = list(csv.DictReader(f))
    else:
        raise ValueError(f"unsupported manifest type: {p.suffix} (use .json or .csv)")

    return [_normalize_row(r) for r in raw_rows]


def build_command(row, python=None, script=CONVERT_SCRIPT):
    """Assemble the convert_hymn.py argv for one normalized row."""
    python = python or sys.executable
    cmd = [python, script]
    if row.get("from_xml"):
        cmd += ["--from-xml", row["from_xml"]]
        if row.get("image"):
            cmd.append(row["image"])  # image still useful for OCR lyrics
    elif row.get("image"):
        cmd.append(row["image"])

    cmd += ["--song", str(row["song"])]
    if row.get("book"):
        cmd += ["--book", row["book"]]
    if row.get("ocr_lyrics"):
        cmd.append("--ocr-lyrics")
    if row.get("systems") is not None:
        cmd += ["--num-systems", str(row["systems"])]
    if row.get("no_validate"):
        cmd.append("--no-validate")
    return cmd


def run_batch(rows, dry_run=False, continue_on_error=True, runner=subprocess.run):
    """Run each row through convert_hymn. Returns a list of per-row result dicts.

    ``runner`` is injectable (defaults to subprocess.run) so tests never spawn a
    process. In dry_run mode the runner is never called.
    """
    results = []
    for row in rows:
        cmd = build_command(row)
        cmd_str = " ".join(cmd)
        if dry_run:
            results.append({"song": row["song"], "command": cmd_str,
                            "returncode": "dry-run", "ok": True})
            continue
        completed = runner(cmd)
        rc = getattr(completed, "returncode", completed)
        ok = (rc == 0)
        results.append({"song": row["song"], "command": cmd_str,
                        "returncode": rc, "ok": ok})
        if not ok and not continue_on_error:
            break
    return results


def main(argv=None):
    parser = argparse.ArgumentParser(description="Batch-import songs via convert_hymn.py")
    parser.add_argument("manifest", nargs="?", help="JSON or CSV manifest of songs to import")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print planned commands without executing")
    parser.add_argument("--continue-on-error", action="store_true",
                        help="Keep going after a failed row (default stops)")
    parser.add_argument("--validate-only", action="store_true",
                        help="Skip conversion; just validate songs.json")
    args = parser.parse_args(argv)

    if args.validate_only:
        try:
            import song_validator
        except ImportError:
            print("song_validator.py not found.")
            return 2
        return song_validator.main([])

    if not args.manifest:
        parser.error("a manifest is required (or use --validate-only)")

    try:
        rows = load_manifest(args.manifest)
    except (ValueError, FileNotFoundError) as e:
        print(f"Manifest error: {e}")
        return 2

    print(f"Loaded {len(rows)} row(s) from {args.manifest}"
          + (" (dry run)" if args.dry_run else ""))
    results = run_batch(rows, dry_run=args.dry_run,
                        continue_on_error=args.continue_on_error)

    failed = 0
    for r in results:
        status = "DRY-RUN" if r["returncode"] == "dry-run" else ("OK" if r["ok"] else "FAIL")
        print(f"  [{status}] song {r['song']}: {r['command']}")
        if not r["ok"]:
            failed += 1

    print(f"Batch complete: {len(results)} processed, {failed} failed.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
