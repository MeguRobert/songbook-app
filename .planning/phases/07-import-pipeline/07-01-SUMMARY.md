---
phase: 07-import-pipeline
plan: 01
subsystem: import-validation
status: complete
tags: [python, tooling, validation, import-pipeline, unittest]
dependencies:
  requires: []
  provides:
    - song_validator.py (validate_song / validate_songs / load_and_validate / CLI)
    - duplicate-number + schema + nested-structure checks
  affects:
    - 07-02-import-integration-and-batch
tech-stack:
  added: []
  patterns:
    - Pure-stdlib Python validator (no pip deps) with error/warning severities
    - ValidationIssue namedtuple as a structured, testable result
key-files:
  created:
    - tools/song_validator.py
    - tools/test_song_validator.py
  modified: []
key-decisions:
  - decision: Unrecognized originalKey is a WARNING, not an ERROR
    rationale: OCR/OMR sometimes yields odd key strings; warn so the operator notices without hard-failing a whole batch
    date: 2026-06-13
  - decision: Stdlib unittest, no third-party test deps
    rationale: Runs in CI / pre-commit / the offline sandbox with zero install; matches the dependency-free import tooling
    date: 2026-06-13
metrics:
  completed: 2026-06-13
  tasks: 3
  files: 2
---

# Phase 07 Plan 01: Song Validation Module — Summary

**One-liner:** A dependency-free Python validator now catches common import errors (missing/empty
fields, wrong types, bad keys, malformed verses/chords, duplicate numbers) before a song reaches
songs.json, backed by 24 unit tests.

## What Was Built

**`tools/song_validator.py`** (stdlib only):
- `validate_song(song, index=None)` — required fields (`number` int>0, `title` non-empty,
  `originalKey` present & matching `^[A-G][#b]?m?$`), non-empty `verses`, and nested checks on each
  verse (`number` int; `hasNotation` ⇒ lines present), line (`text` str), and chord (`chord`
  non-empty str; `position` int ≥0; warns if `position` > len(text)). Optional `book`/`tags` checked
  leniently.
- `validate_songs(songs)` — runs per-song validation and adds a **duplicate `number`** cross-check
  (reported once per colliding number).
- `load_and_validate(path)` — turns file-not-found / JSON-decode failures into a single error issue.
- `has_errors(issues)` helper; `ValidationIssue(severity, song, field, message)` namedtuple.
- **CLI**: `python song_validator.py [path] [--warnings-as-errors] [--quiet]` — auto-detects
  songs.json, prints an ASCII-safe grouped summary, exits non-zero on errors (or warnings with the flag).

**`tools/test_song_validator.py`** — 24 `unittest` cases covering valid songs, each error type
(number/title/key/verses/line/chord), the unrecognized-key warning, past-end-position warning,
duplicate detection, and `load_and_validate` on missing/malformed/valid files.

## Quality Gates

- `python tools/test_song_validator.py`: **24/24 OK**.
- `python tools/song_validator.py` on bundled songs.json: **0 errors, 0 warnings, exit 0** (clean).
- Flutter gates unaffected (no Dart changes).

## Deviations from Plan

None.

## Next Plan Readiness

Ready for 07-02: wire the validator into `convert_hymn.py` (validate before writing songs.json), add
batch-import support, and document the workflow.
