#!/usr/bin/env python3
"""
Song validator for the Songbook app.

Catches common import errors BEFORE a song lands in songs.json: missing/empty
required fields, wrong types, invalid keys, duplicate song numbers, and
malformed verses / lyric lines / chord positions.

Pure standard library — no third-party dependencies — so it runs anywhere
Python runs (CI, pre-commit, the import pipeline) without `pip install`.

Library API:
    validate_song(song, index=None) -> list[ValidationIssue]
    validate_songs(songs)           -> list[ValidationIssue]
    load_and_validate(path)         -> list[ValidationIssue]
    has_errors(issues)              -> bool

CLI:
    python song_validator.py [songs_json_path] [--warnings-as-errors] [--quiet]
"""

import argparse
import json
import re
import sys
from collections import Counter, namedtuple
from pathlib import Path

# Severity levels.
ERROR = "error"
WARNING = "warning"

# A single validation finding.
#   severity: ERROR | WARNING
#   song:     song number (or None / index label) for grouping
#   field:    dotted path to the offending field (e.g. "verses[0].lines[1].text")
#   message:  human-readable description
ValidationIssue = namedtuple("ValidationIssue", ["severity", "song", "field", "message"])

# Note name with optional accidental and optional minor 'm' (e.g. C, Bb, F#, Am).
KEY_PATTERN = re.compile(r"^[A-G][#b]?m?$")


def _song_id(song, index):
    """Best-effort identifier for messages/grouping."""
    if isinstance(song, dict) and isinstance(song.get("number"), int):
        return song["number"]
    if index is not None:
        return f"index {index}"
    return "?"


def validate_song(song, index=None):
    """Validate a single song dict. Returns a list of ValidationIssue."""
    issues = []
    sid = _song_id(song, index)

    def err(field, msg):
        issues.append(ValidationIssue(ERROR, sid, field, msg))

    def warn(field, msg):
        issues.append(ValidationIssue(WARNING, sid, field, msg))

    if not isinstance(song, dict):
        err("(root)", f"song must be an object, got {type(song).__name__}")
        return issues

    # number
    number = song.get("number")
    if "number" not in song:
        err("number", "missing required field 'number'")
    elif not isinstance(number, int) or isinstance(number, bool):
        err("number", f"'number' must be an integer, got {type(number).__name__}")
    elif number <= 0:
        err("number", f"'number' must be positive, got {number}")

    # title
    title = song.get("title")
    if "title" not in song:
        err("title", "missing required field 'title'")
    elif not isinstance(title, str):
        err("title", f"'title' must be a string, got {type(title).__name__}")
    elif not title.strip():
        err("title", "'title' must not be empty")

    # originalKey
    key = song.get("originalKey")
    if "originalKey" not in song:
        err("originalKey", "missing required field 'originalKey'")
    elif not isinstance(key, str) or not key.strip():
        err("originalKey", "'originalKey' must be a non-empty string")
    elif not KEY_PATTERN.match(key):
        # OCR can yield odd values; warn rather than hard-fail the whole file.
        warn("originalKey", f"unrecognized key '{key}' (expected like C, Bb, F#, Am)")

    # verses
    verses = song.get("verses")
    if "verses" not in song:
        err("verses", "missing required field 'verses'")
    elif not isinstance(verses, list):
        err("verses", f"'verses' must be a list, got {type(verses).__name__}")
    elif not verses:
        err("verses", "'verses' must not be empty")
    else:
        for vi, verse in enumerate(verses):
            issues.extend(_validate_verse(verse, vi, sid))

    # book (optional)
    if "book" in song:
        book = song["book"]
        if not isinstance(book, str) or not book.strip():
            warn("book", "'book' is present but empty / not a string")

    # tags (optional)
    if "tags" in song:
        tags = song["tags"]
        if not isinstance(tags, list) or not all(isinstance(t, str) for t in tags):
            warn("tags", "'tags' should be a list of strings")

    return issues


def _validate_verse(verse, vi, sid):
    issues = []
    prefix = f"verses[{vi}]"

    def err(field, msg):
        issues.append(ValidationIssue(ERROR, sid, field, msg))

    def warn(field, msg):
        issues.append(ValidationIssue(WARNING, sid, field, msg))

    if not isinstance(verse, dict):
        err(prefix, f"verse must be an object, got {type(verse).__name__}")
        return issues

    vnum = verse.get("number")
    if not isinstance(vnum, int) or isinstance(vnum, bool):
        err(f"{prefix}.number", "verse 'number' must be an integer")

    has_notation = bool(verse.get("hasNotation"))
    lines = verse.get("lines", [])
    plain = verse.get("plainText")

    if not isinstance(lines, list):
        err(f"{prefix}.lines", "'lines' must be a list")
        lines = []

    if has_notation and not lines:
        warn(f"{prefix}.lines", "verse marked hasNotation but has no lines")

    # A verse should carry content one way or another.
    if not lines and not (isinstance(plain, str) and plain.strip()):
        warn(prefix, "verse has neither lines nor plainText")

    for li, line in enumerate(lines):
        lprefix = f"{prefix}.lines[{li}]"
        if not isinstance(line, dict):
            err(lprefix, "line must be an object")
            continue
        text = line.get("text")
        if not isinstance(text, str):
            err(f"{lprefix}.text", "line 'text' must be a string")
            text = ""
        chords = line.get("chords", [])
        if not isinstance(chords, list):
            err(f"{lprefix}.chords", "'chords' must be a list")
            chords = []
        for ci, chord in enumerate(chords):
            cprefix = f"{lprefix}.chords[{ci}]"
            if not isinstance(chord, dict):
                err(cprefix, "chord must be an object")
                continue
            csym = chord.get("chord")
            if not isinstance(csym, str) or not csym.strip():
                err(f"{cprefix}.chord", "'chord' must be a non-empty string")
            pos = chord.get("position")
            if not isinstance(pos, int) or isinstance(pos, bool):
                err(f"{cprefix}.position", "'position' must be an integer")
            elif pos < 0:
                err(f"{cprefix}.position", f"'position' must be >= 0, got {pos}")
            elif pos > len(text):
                warn(f"{cprefix}.position",
                     f"'position' {pos} is past end of text (len {len(text)})")

    return issues


def validate_songs(songs):
    """Validate a list of songs, including cross-song duplicate-number checks."""
    issues = []
    if not isinstance(songs, list):
        return [ValidationIssue(ERROR, "?", "(root)",
                                f"songs.json must be a list, got {type(songs).__name__}")]

    for i, song in enumerate(songs):
        issues.extend(validate_song(song, index=i))

    # Duplicate song numbers (report once per colliding number).
    numbers = [s["number"] for s in songs
               if isinstance(s, dict) and isinstance(s.get("number"), int)
               and not isinstance(s.get("number"), bool)]
    for num, count in Counter(numbers).items():
        if count > 1:
            issues.append(ValidationIssue(
                ERROR, num, "number",
                f"duplicate song number {num} appears {count} times"))

    return issues


def has_errors(issues):
    """True if any issue is an error."""
    return any(i.severity == ERROR for i in issues)


def load_and_validate(path):
    """Load JSON from path and validate. File/JSON problems become a single error issue."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return [ValidationIssue(ERROR, "?", "(file)", f"songs file not found: {path}")]
    except json.JSONDecodeError as e:
        return [ValidationIssue(ERROR, "?", "(file)", f"invalid JSON in {path}: {e}")]
    return validate_songs(data)


def _autodetect_songs_json():
    script_dir = Path(__file__).parent
    candidates = [
        script_dir.parent / "songbook_app" / "assets" / "data" / "songs.json",
        Path("songbook_app/assets/data/songs.json"),
    ]
    for c in candidates:
        if c.exists():
            return str(c.resolve())
    return None


def _format(issue):
    return f"  [{issue.severity}] song {issue.song} :: {issue.field}: {issue.message}"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Validate Songbook songs.json")
    parser.add_argument("path", nargs="?", default=None,
                        help="Path to songs.json (auto-detected if omitted)")
    parser.add_argument("--warnings-as-errors", action="store_true",
                        help="Exit non-zero if there are warnings too")
    parser.add_argument("--quiet", action="store_true",
                        help="Only print the summary line")
    args = parser.parse_args(argv)

    path = args.path or _autodetect_songs_json()
    if not path:
        print("Error: could not find songs.json (pass a path).")
        return 2

    issues = load_and_validate(path)
    errors = [i for i in issues if i.severity == ERROR]
    warnings = [i for i in issues if i.severity == WARNING]

    if not args.quiet:
        if errors:
            print(f"Errors ({len(errors)}):")
            for i in errors:
                print(_format(i).encode("ascii", "replace").decode())
        if warnings:
            print(f"Warnings ({len(warnings)}):")
            for i in warnings:
                print(_format(i).encode("ascii", "replace").decode())

    print(f"Validated {path}: {len(errors)} error(s), {len(warnings)} warning(s).")

    if errors or (args.warnings_as_errors and warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
