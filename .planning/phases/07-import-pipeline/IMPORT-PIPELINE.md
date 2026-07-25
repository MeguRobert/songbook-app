# Song Import Pipeline

How a hymnal page becomes a song in `songbook_app/assets/data/songs.json`. All tooling lives in
`tools/` and is plain Python 3.

```
sheet-music image ──▶ Audiveris (OMR) ──▶ MusicXML ──▶ convert_hymn.py ──▶ songs.json
                 └──▶ EasyOCR (lyrics) ──────────────────┘     │
                                                    song_validator.py (gate)
```

## Prerequisites (EXTERNAL — not bundled, must be installed by a human)

| Tool | Used for | Install | Status |
|------|----------|---------|--------|
| Python 3.9+ | all scripts | system | ✅ available |
| Audiveris | OMR (notation → MusicXML) | `C:\Program Files\Audiveris\Audiveris.exe` | ⛔ external |
| EasyOCR (+ Pillow, numpy) | Hungarian lyric OCR | `pip install easyocr Pillow numpy` | ⛔ external, large models |
| oemer (optional) | alternative OMR engine | `pip install oemer` | ⛔ external |

`song_validator.py` and `batch_import.py` are **pure standard library** — no install needed.

## 1. Single-song import

```bash
cd tools
python convert_hymn.py "<image>.jpg" --song <number> --ocr-lyrics --num-systems <count> --book "<Book>"
# or from an existing MusicXML / .mxl, skipping OMR:
python convert_hymn.py --from-xml output/song.xml --song <number> --book "<Book>"
```

This runs OMR + (optional) OCR, builds the app notation JSON, and updates the matching song in
`songs.json`. `--book` assigns the hymnal/book (Phase 5). `--output <file>` also dumps the notation.

## 2. Validation gate (Phase 7)

Before writing, `convert_hymn.py` validates the updated song with `song_validator.py`:
- **Errors** (missing/empty required field, wrong type, bad chord position, etc.) **abort the write** —
  fix the source and re-run. Override with `--no-validate` (discouraged).
- **Warnings** (unrecognized key, chord past end of line, hasNotation-without-lines) are printed but
  do not block.

Validate the whole file any time (e.g. in CI or pre-commit):

```bash
python tools/song_validator.py                     # exits non-zero on errors
python tools/song_validator.py --warnings-as-errors
```

## 3. Batch import (Phase 7)

Import many songs from one manifest (`.json` list or `.csv` with a header). See
`tools/sample_import_manifest.json`.

Row fields: `song` (required int), `image` **or** `from_xml` (one required), `book`, `systems`,
`ocr_lyrics`, `no_validate`.

```bash
python tools/batch_import.py tools/sample_import_manifest.json --dry-run        # preview commands
python tools/batch_import.py tools/sample_import_manifest.json --continue-on-error
python tools/batch_import.py --validate-only                                    # just check songs.json
```

CSV form:

```csv
song,image,book,systems,ocr_lyrics
42,C:/scans/zsolt-042.jpg,Zsoltárok,6,true
90,C:/scans/zsolt-090.jpg,Zsoltárok,6,true
```

`--dry-run` prints the exact `convert_hymn.py` command for each row without executing it; the runner
is only invoked for real runs. Exit code is non-zero if any row fails.

## 4. Manual-correction loop

OMR/OCR are imperfect. After import:
1. Open the song in the app (or read its entry in `songs.json`).
2. Fix wrong pitches/durations, syllable splits, line breaks (≈2 measures/line for hymns), and the key.
3. Re-run `python tools/song_validator.py` until clean.

## What is NOT automated (human / external / model work)

- **OMR/OCR accuracy** (criterion #1 "fewer manual corrections"): improving this needs better source
  scans and Audiveris/EasyOCR tuning — not codeable here. The validation gate *catches* errors but
  does not *prevent* them.
- **AI lyric cleanup** requiring API keys: not wired (no keys in the sandbox).
- **On-device visual verification** of rendering: requires a running app.

## Tests

```bash
python tools/test_song_validator.py     # 24 cases
python tools/test_batch_import.py        # 13 cases
```
