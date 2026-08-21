# Measuring and improving photo recognition

_Designed and built 2026-08-21. Supersedes nothing; extends the corpus that
`tools/fixtures/build.py` and `score.py` cover with real photographs._

## The problem this solves

`tools/fixtures/score.py` says it in its own docstring: "a real photograph has
no machine-checkable answer, so it prints the reading for a human to judge."
Every real photograph in this project has therefore been assessed by reading the
output in a terminal once. There was no way to tell whether a change to
`photo_import_worker.py` or `photo_text_bridge.dart` made recognition better or
worse, and no way to find out which stage of the pipeline caused a given error.

## What was proposed, and what changed

The original idea was a round trip: render a song the app already has encoded,
screenshot it, read the screenshot back, and compare with the stored JSON. Kept,
but demoted — it is a regression canary, not an improvement signal, for three
reasons.

1. **It measures the wrong distribution.** A rendered page is one known font,
   perfect contrast, no skew, no show-through, no handwriting. Recognition
   saturates on it quickly and the number then stops moving while real
   photographs still fail. A saturated metric cannot say whether a change
   helped.
2. **It is circular.** The screenshot is derived from the stored JSON by this
   project's own renderer, so any assumption the renderer and the reader share
   cancels out, and a wrong rule round-trips perfectly.
3. **Exact equality is not reachable.** Storage holds a chord as a character
   offset into a lyric string; the renderer turns that into pixels in a
   proportional font; reading it back gives pixels that map to a character
   offset only approximately. Tuning for equality means tuning the comparison.

What drives iteration instead is eleven real photographs with hand-transcribed
answers committed beside them. Labelling was always the bottleneck, and that is
where a vision model earns its place — as the labeller and the error analyst,
never as the shipped engine. The recorded decision in `HANDOFF-photo-import.md`
("Not Anthropic": no plan this project can build on) is about the runtime and
still holds. Nothing here calls an API; the vision arm is text on disk.

## The pieces

```
tools/fixtures/photos/       11 photographs, gitignored; manifest + checksums committed
tools/fixtures/gold/         the answer each page is scored against
tools/fixtures/vision/       a vision model's unreviewed first read, for the ceiling
tools/ocr_harness/
  reading.py                 the model: one Reading, parsed out of ChordPro text
  metrics.py                 what a Reading scores against a gold Reading
  engines.py                 adapters: easyocr (the real path), vision (from disk)
  geometry.py                measured pixel spans, for writing gold by hand
  gold.py                    loading, and whether a gold file is honest evidence
  report.py                  the table, and what counts as a regression
  baseline.json              the last accepted score per page per metric
```

### The model is ChordPro text, not a tree

A gold answer has to be checkable by eye against a photograph, and correcting it
has to be editing a line. A monospaced chord row makes a chord's character
column its position, which is what makes placement machine-checkable from plain
text — the same trick `tools/fixtures/score.py` already uses. Everything else is
derived: title, number, lyric lines, chord placements, block count.

### The metrics, and why there is more than one

| Metric | What it catches |
|---|---|
| `lyric_cer` | the letters, accent-sensitive — the headline text number |
| `lyric_cer_folded` | the same with diacritics stripped; the gap between the two *is* the `ő`/`ű` problem, which is fixed on the phone rather than in this repo |
| `chord_recall` / `chord_precision` / `chord_f1` | whether the right chords were found at all |
| `placement` | exact word each chord sits over |
| `placement_near` | the same allowing one word of slack — the number the headline uses |
| `number_exact`, `title_cer` | the two fields the catalogue searches on |
| `warnings_ok` | a warning that stops firing, or starts firing unasked |

`placement_near` exists because on a real page the chords are set at fixed
horizontal positions and do not track the words beneath them: on
`app-jezus-szivedbe-lat` the same `D` of the same phrase sits over `lát!` in one
verse and over the end of `szemedbe` in the next. Demanding the exact word would
mark a reading down for picking the other reasonable answer to a question the
page does not settle. Two words out is still a real error and still scores as
one.

Tier C is scored and shown but excluded from the headline. Both tier-C pages
carry a handwritten chord written over a printed one — a product question, not an
OCR setting.

### Circularity is enforced, not just warned about

`draft` writes an engine's own reading into a gold file as a starting point.
Scoring that engine against that file returns a perfect mark and proves nothing —
the same defect as the screenshot round trip. So each gold file records
`drafted_from`, and `run` refuses to score an engine against a file drafted from
it unless `--include-unreviewed` is passed. `reviewed_by` outranks that: once a
human has compared the file with the page, it is evidence for every engine.

### The trace lives in the worker, not the harness

`extract_with_easyocr(image_bytes, trace=None)` takes a list and every stage
appends what it decided and why. The first draft built the trace in the harness
by re-running the recogniser purely to observe it; the two passes disagreed
about one word on the first page tried, which is the whole argument for the seam
belonging in the worker.

The record that matters is per-row: **a chord that was never recognised and a
chord that was recognised and then thrown away by the row classifier produce the
identical missing chord downstream, and they are fixed in different files.**
`chord_row_reason` now returns the reason alongside the verdict, so the trace
names the token that cost a row. `Box` also carries the recogniser's confidence,
which it previously discarded at that boundary.

## What the corpus found immediately

Three bugs, all fixed here, all found on the *cleanest* pages:

1. **The recogniser returns regions, not words.** A widely spaced chord row
   comes back as `G` and `C   D - C` — two regions holding four chords — and
   every classification rule is written about one token, so the second region
   read as an ordinary word and the all-or-nothing test emitted the whole row as
   lyrics. On `app-jezus-szivedbe-lat`, ten of eleven chord rows were being lost
   this way. `split_regions` / `as_chord_row` fix it, positioning each sub-box by
   character offset on the region's own average character width.
2. **A lone bracket or apostrophe killed a row.** The songbook writes an
   optional chord as `( C )`, spaces inside, and the recogniser sometimes returns
   a stray apostrophe where a chord's glyph was. Neither is a chord or a
   separator, so the row became lyrics. Both are separators now.
3. **The lyric half of a chord/lyric pair had no trace record**, because the
   loop consumes it without coming round again — and it is the row whose
   confidence explains a wrong word.

And one decision the corpus overturned:

**The one-bare-root rule is gone.** A line whose only chord was a bare root —
`A`, `d`, `A -` — used to resolve to lyrics in both parsers, on the grounds that
`A` is the Hungarian definite article and losing a chord is recoverable where
losing a line of words is not. The corpus priced that argument: `084-van-egy-ut`
prints `C` over one line and `G` over the next, `151-zengjed-a-dalt` prints `D`
and `A`. Four real chords on two pages, every one stored as a word.

The argument does not survive the counter-example. The ambiguity only arises
when a root letter stands *among* words, and the all-or-nothing rule already
keeps such a line as lyrics — `A szívemben` was never at risk. A line holding
nothing but one letter is not a lyric, not in a hymnal. Robert's call, and the
right one.

Removed from `chord_sheet_parser.dart` and `photo_import_worker.py` together,
along with the harness code that existed only to count what it cost.
`ImportNoticeCode.ambiguousBareRoot` and its three translations are kept — a
moderator-facing notice is cheap to hold and expensive to re-translate — but
nothing emits it any more.

The residual risk is not what it looks like. It is not that a stray one-letter
word stays a lyric; it is that a stray lowercase `a` becomes **A minor**, since
a lowercase root means minor and storage keeps one spelling per chord. A
moderator then sees a chord that is not on the page, which is the visible kind of
wrong — and the moderation queue is where that gets caught.

What it bought on `084-van-egy-ut`: headline 0.591 → 0.642, lyric error rate
0.152 → 0.075, chord recall 0.300 → 0.333. Strict `placement` fell 0.154 →
0.125 and the gate flagged it, correctly: two more chords now enter the
comparison and both land one word off the exact target. `placement_near` rose,
which is the honest reading of a mixed result — more chords found, their exact
column not yet right.

And two findings that are **not** defects:

- **Two warnings fire falsely.** `show-through-removed` fires on the app
  screenshot and on the opaque photocopy `185-jezus-krisztusom`, neither of
  which has a reverse page showing through; `low-resolution` fires on the
  screenshot, which is born-digital and perfectly legible. Recorded in gold as
  *not* expected, so they show up as failures rather than as noise.

## First baseline, 2026-08-21

Three pages transcribed by hand, scored against the EasyOCR path:

| page | score | lyric CER | chord recall | placement (±1) |
|---|---|---|---|---|
| `app-jezus-szivedbe-lat` | 0.911 | 0.025 | 0.812 | 0.862 |
| `185-jezus-krisztusom` | 0.776 | 0.173 | 0.600 | 0.750 |
| `084-van-egy-ut` | 0.591 | 0.152 | 0.300 | 0.462 |

0.759 mean over the three. `084` is lowest because two of its chord rows are the
bare-root case above, and because its title row is not detected as a title
(`title_cer` 1.0, `number_exact` 0.0) — the next thing to look at.

## The engine being measured was not the engine that ships

Found on 2026-08-22, and it invalidated every number above.

`photo_import_worker.py` is EasyOCR on a developer's machine.
What ships is **Tesseract.js in the browser plus `photo_text_bridge.dart`** on a
phone. Two separate implementations of the same idea, and only the one that does
not ship was being scored.

`tools/ocr_harness/browser.py` closes that. It compiles
`songbook_app/tool/browser_reader_harness.dart` - which imports
`BrowserPhotoImportService` and `createPageTextRecognizer` and calls them - serves
it beside the photographs, and drives it with `browser_driver.cjs` under the app's
own Content-Security-Policy, read out of `web/index.html` rather than
approximated. Nothing is reimplemented: a fix in the app moves these numbers
without being ported.

    python -m tools.ocr_harness run --engine browser

Three things it got right immediately: zero CSP violations, zero console errors,
and 5.8-14.1 seconds per page on desktop Chromium at 2048px.

### What it found, and what the app was doing wrong

Two of the pages were catastrophic - `185-jezus-krisztusom` found **zero** chords
and raised "no chords were recognised"; `app-jezus-szivedbe-lat`, the cleanest
page in the corpus, found 39% of them and had a lyric error rate of 0.396 against
EasyOCR's 0.025.

One bug behind both. **Tesseract joins glyphs into a word on horizontal spacing**,
so a chord row printed `D G  D` with narrow gaps arrives as the single word
`DGD`, and `G - C - D - ( C )` as `G-C-D-(C)`. Neither is a chord symbol, so the
all-or-nothing rule in `isChordLine` read the whole row as lyrics and the chords
were stored as words. There is no whitespace to split on, which is why the
region-splitting fix that worked for EasyOCR could not help here.

`PhotoTextBridge.splitMergedChords` undoes it from the glyph boxes, which the
recogniser now asks Tesseract for (`symbols: true`) and carries on `OcrWord`.
Two guards keep it off prose, and both must hold: the cut must fall on a gap at
least 0.6 of the word's own median glyph width, **and** every resulting piece
must be a chord or chord punctuation. That second guard is what protects
`szívemben` (its pieces are not chords), `Am` (`m` names no pitch) and `Em7`
(already a chord, so never touched).

| page | before | after |
|---|---|---|
| `app-jezus-szivedbe-lat` | 0.542 | **0.965** |
| `185-jezus-krisztusom` | 0.216 | **0.453** |
| `151-zengjed-a-dalt` | 0.913 | 0.913 |
| `098-szivemben-orom-dalol` | 0.799 | 0.799 |
| `084-van-egy-ut` | 0.715 | 0.715 |
| **mean, 5 reviewed pages** | **0.637** | **0.769** |

`app-jezus-szivedbe-lat` chord recall went 0.391 to 0.984, its lyric error rate
0.396 to 0.012.

### And it corrected two beliefs about the two arms

**Region splitting was never an app problem.** Tesseract returns words; EasyOCR
returns regions. `'C   D - C'` arriving as one token with spaces inside it is an
EasyOCR defect that does not exist on a phone.

**The app was already ahead on titles.** `photo_text_bridge.dart` had the
numbered-heading rule before this session started, and its version is better -
it also keeps `10 000 angyal` from parsing as song 10. The Python change was
Python catching up.

### The provenance rule had to be tightened too

`evidence_for` used to accept gold drafted by a *different* engine, on the
grounds that it is at least not marking an engine against itself. True, and
useless: `166-tekozlo-fiu` scored chord recall 1.000 against gold EasyOCR had
written, which meant "found everything EasyOCR found" - and EasyOCR had found
three chords out of thirteen. A number that reads like success and describes
agreement with a bad reading is worse than no number. Only a human review or a
transcription made from the photograph counts now, which is why four pages
dropped out of the scored set until they are transcribed.

## Next, in order

1. **Transcribe the remaining six text pages** and set `reviewed_by` on all
   nine. Until then the corpus is three pages wide. `align` prints the measured
   geometry that makes this tractable.
2. **Why `084`'s title row is not a title.** The rule is a height ratio against
   the median body row; the trace records the measurement it made.
3. **The two-column pages.** `split_columns` calls more than one column more
   than one *song* — right for a hymnal printed two songs to a page, wrong for
   `125-nincs-mas-isten` and `166-tekozlo-fiu`, which are one song in two
   columns. The trace records the assumption as `read_as`.
4. **The unspellable chord symbols.** `python -m tools.ocr_harness symbols`
   lists them; `fiszm` and `D4/Fis` are already known. Both `_CHORD_TOKEN` and
   its port in `chord_sheet_parser.dart` have to move together.
5. **The vision ceiling.** Fill `tools/fixtures/vision/` with a first read per
   page and run `--engine vision` to find out how much headroom the shipped
   engine has. Below about a five-point gap, stop tuning.
6. **Notation, second.** The same harness over `011-a-mennyben-fenn` and
   `151-hozsanna` against Audiveris. Its gold needs a different shape — pitches,
   bars, chords, no lyrics — and each run is a 10–40s Cloud Run round trip, so
   it wants the text loop finished first.
7. **The round-trip canary.** Render an encoded song, screenshot it, read it
   back, compare with `songs.json`. Cheap, fully automatic, no labelling, and it
   catches "someone broke the bridge" in seconds. Just do not expect it to point
   at the next improvement.

## The one change that had to be made in two languages

Adding brackets and quotes to the separator rule desynced the two parsers, and
that desync is not cosmetic. The worker emits laid-out text and
`chord_sheet_parser.dart` reads it back, so a token the worker treats as
punctuation and the app treats as a word turns a whole row of chords into a line
of lyrics on the way into storage — the failure the file's own comment warns
about. `_separator` in `chord_sheet_parser.dart` now carries the same
alternative and the same reasoning, with tests for `G - C - D - ( C )`, for a
stray apostrophe standing in for a chord, and for `/ / /` still *not* being
punctuation.

`_CHORD_TOKEN` and `isChordToken` are untouched: none of this changed what
counts as a chord symbol, only how a row is split into symbols before they are
asked.

## Verify

```bash
python -m unittest discover -s tools -p "test_*.py"       # expect 310
python -m tools.ocr_harness run                           # the Python arm
python -m tools.ocr_harness run --engine browser          # what actually ships
cd songbook_app && flutter analyze --no-fatal-infos       # expect exit 0, 0 issues
cd songbook_app && flutter test                           # expect 1190
cd songbook_app && flutter build web --release --no-web-resources-cdn
```

`run` exits non-zero when a gated metric moved the wrong way against the
committed baseline. The browser engine needs `dart` on PATH, `node` with
playwright, and a network for the Tesseract model.
