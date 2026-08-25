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

## 2026-08-22, second session: the warnings, and the two-column pages

### The app measured two things and told nobody

Every page reported *warning not raised: low-resolution*. `resolution_note` in
the Python worker tells the user their upload is too compressed to hold `ő` and
`ű` — the single biggest lever on accuracy, and the fix is on the phone rather
than in this repo. The app does the same measurement in
`page_text_recognizer_web.dart` and dropped it on the floor. Same for
show-through: `PagePreprocessor` erases it and never said so, though suppression
costs stroke sharpness and is exactly what explains a missing chord.

Raising them meant paying the debt `no_hardcoded_strings_test` had recorded with
a reason attached: `PhotoReading.warnings` was four English sentences built
inside pure domain code with no `BuildContext`, feeding both `ChordProPayload`
and `PhotoImportException`. They are `ImportNoticeCode`s now, translated three
ways, and the remote reader's prose is carried under `fromReader` — which is what
that code always existed for. `PageWords` carries the notices the *image* earns,
because the recogniser is the only stage holding pixels.

Two things the corpus said while this was being done:

- **`hm` was renamed to `Bm` in silence.** The German-note-name warning matched
  only a capital `H`, and a Hungarian songbook prints its minors in lowercase
  throughout. `166-tekozlo-fiu` is a page of them.
- **The show-through message says what was done, not what caused it.**
  `hasShowThrough` was calibrated on one page whose reverse side is legible
  through the paper, and it fires on three corpus pages that have none — uneven
  light across a photographed page leaves the same pale band. The advice ("a
  photo in flatter light will read better") is right either way; a claim about
  the cause would not be. Calibrating the gate is still open work, and now
  visible: `warn` is 0.000 on four pages for this reason.

The harness reads notice **codes** now (`WARNING_CODES` in `reading.py`) rather
than substring-matching English prose, which its own comment said would break the
day this debt was paid.

### Two-column pages: read one column at a time

Both two-column pages read as one interleaved column — a line of the left column
and an unrelated line of the right, at the same height, arriving as one row.
`125-nincs-mas-isten` scored 0.348, `166-tekozlo-fiu` 0.392.

**Cause one: the gutter was never found.** `splitColumns` looked for a vertical
band that *no* word crosses, and a hymnal sets the song's heading across the
columns — so one word of it lies over the gutter. `125` has 127 clear pixels
between its columns and lost them to `Nincs`; `166` has 158 and lost them to
`Tékozló`. The test now tolerates a share of the page's rows crossing the band,
which is precisely the difference between a heading and a page: a heading is one
row out of however many, while on a single-column page *every* row crosses every
interior x. What keeps a single-column page whole is the row count inside each
band — past the end of its shortest line a band does open, but only the longest
line or two reaches into it, so it holds fewer rows than a column does.

**Cause two: splitting the words afterwards was never going to be enough.**
Tesseract does its own layout analysis before it returns a box, and given a
two-column page it joins a line from one column to a line from the other. `125`
came back with `Nálad lett borrá` and `Átvezető rész` inside one word list at one
y, and no rule about boxes takes that apart again. So the recogniser crops each
column and reads it on its own — the single-column page its default segmentation
assumes. Robert's call, and the corpus agreed with it:

| page | before | after |
|---|---|---|
| `125-nincs-mas-isten` | 0.348 | **0.555** |
| `166-tekozlo-fiu` | 0.392 | **0.895** |

Lyric error rate on `166` went 0.823 → 0.080 and chord recall 0.368 → 0.789. On
desktop Chromium a single-column page still takes 1.8–4.9 seconds and a
two-column page about 12 — one whole-page pass to find the columns, then one per
column.

Two refinements the measurement forced, both after a worse first attempt:

- **The cut goes in the emptiest part of the gutter, not the middle of it.** The
  middle of `125`'s band is inside a chord row reaching into it, and the cut
  split `Cadd9-Csus2` across two crops, which read the halves twice and read
  neither right.
- **The heading goes into the first column whole.** Filed word by word it splits
  at the cut, and each crop then reads its own half again: `166. Tékozló fiú`
  came back as `{title: 166. 166. . Tékozló}` with a stray `fiú` heading the
  second column. A wider rule — *any* row intruding into the gutter band — was
  tried and reversed, because it also catches the printed rule between `125`'s
  columns, which the engine returns as a column of one-character words sitting
  right where the cut falls. Most of the page then became one spanning row and
  the columns interleaved again.

**And a heading across the columns is the signal that the page is one song.**
`photoTwoSongs` told the user to delete the half they did not want, on both
pages, wrongly. Two songs to a page each carry their own heading, inside their
own column.

### Two harness bugs, without which none of it was visible

- `compile_harness` decided staleness from the **entry point alone**, which never
  changes. Every run after a fix in `photo_text_bridge.dart` quietly re-measured
  the previous build and reported the old score to the digit — the exact opposite
  of this harness's one claim.
- The harness read each photograph **twice**, once for the word count and once
  through the service. Two independent reads of the same page were free to
  disagree, and with column crops it doubled a three-pass page.

### Gold for the two-column pages

Transcribed from the photographs, which is the assistant's job. The text was read
off crops of the originals; the chord columns come from measured ink spans — row
bands and word spans by projection, no OCR involved — mapped onto character
columns with `PhotoTextBridge`'s own interpolation rule, so a gold file says what
a *perfect reading* would say rather than what some other convention would. Both
are `drafted_from: "vision"` and both still need Robert's review.

`125` records `low-resolution`; `166` records `low-resolution` and
`german-chords`. Neither records `two-songs`, because neither page holds two
songs. Neither records `show-through-removed`, because neither page has a reverse
side showing through — which is what makes the gate's over-firing show up as a
failure rather than as noise.

### What the corpus says is next

1. **Calibrate `hasShowThrough`.** It fires on four of seven pages and only one
   of them has show-through. User-visible now, so the noise has a cost.
2. **`low-resolution` on a born-digital screenshot.** Bytes per pixel is the
   wrong proxy for a screenshot: the app screenshot is perfectly legible and
   trips the gate.
3. **The chord symbols no rule can spell.** `fiszm`, `Amaj7-A7`, `D-E`,
   `Cadd9-Csus2`, `G5-Gsus2`, `D4/Fis`. Three of `166`'s ten chord rows and the
   whole of `125`'s intro line read as lyrics for this reason alone — in gold as
   well as in the reading, so the comparison stays fair and the chords are simply
   uncountable. `_CHORD_TOKEN` and `isChordToken` have to move together.
4. **`125`'s printed rule between the columns** comes back as a column of
   one-character words (`!`, `;`, `i`, `S`), which is most of the 50 lyric lines
   it reports against 34 expected.
5. **`125`'s intro chord row is heavily tilted** and splits across two rows.
6. **`185-jezus-krisztusom` at 0.453** — still the worst reviewed page.

## 2026-08-22, third session: the spelled-out accidentals, and a warning withdrawn

### The chord symbols no rule could spell

`fiszm` is F sharp minor and `D4/Fis` names a sharp bass, but the token rule knew
only `#` and `b`. Those rows failed the all-or-nothing test and every chord on
them was stored as a word: three of `166-tekozlo-fiu`'s ten chord rows and the
whole of `125-nincs-mas-isten`'s intro line.

Sharps are `isz`/`is`, flats are `esz`/`sz`. A bare `s` is deliberately not a
flat, German short forms notwithstanding — it would read `Gsus2` as G flat
carrying `us2`. `ChordTransposer` learned the same spellings, because admitting a
chord it cannot transpose is worse than not reading it: `fiszm` came out of
`toEnglishNotation` as `Fmiszm`.

Chords joined by a hyphen are one token and two chords — `Amaj7-A7`,
`Cadd9-Csus2`, `G5-Gsus2`, `D-E`. Every part has to be a chord on its own, which
is what keeps `ici-picit` a word, and `ChordSheetParser.chordsIn` separates them
again on the way into storage so nothing ever transposes a symbol naming two
pitches. `splitMergedChords` asks the new `isSingleChord` rather than
`isChordToken`, so a `G-C-D-C` merged out of a row printed `G - C - D - ( C )` is
still pulled apart on its glyph boxes, which know where the page put each chord.

**What it bought, in chords the user actually gets:** `166-tekozlo-fiu` 21 → 27,
`125-nincs-mas-isten` 22 → 24.

**And both pages' scores fell.** That is the honest reading rather than a
regression: those rows are in gold's *chords* now instead of gold's lyrics, so
the answer key grew from 28 chords to 36 on `166`, and the same reading scores a
lower recall against a fuller answer.

### Which the harness was calling a regression, so two fixes there

- **`symbols` could not see the case that matters.** It listed unspellable
  symbols out of `Reading.chords`, which holds only chords from rows that already
  classified AS chords — so a symbol expensive enough to cost its whole row never
  appeared. It printed "every gold chord symbol is spellable" while `fiszm` was
  taking three rows down. `metrics.rows_lost_to_a_token` names the row and the
  token, and a row qualifies only when *every* token on it is already a chord, a
  separator, or chord-shaped, which is what keeps a lyric line out.
- **The baseline fingerprints the answer it was marked against.**
  `reading.fingerprint` digests the gold text and its warnings;
  `report.regraded` reports a page whose answer moved instead of gating it. A
  metric that drops because the answer key got more complete is not an
  instruction to undo the change.

### The show-through warning: raised, measured, withdrawn

The previous session raised `show-through-removed` because the app was erasing
show-through and never saying so. Measuring it settled the question the other
way, and the notice is gone again.

To measure it at all, the browser arm got the trace the Python arm has always
had — `recognize(bytes, trace: [...])`, a sink every stage appends to. Until now
the only account of *why* a page read the way it did described the engine that
does not run on a phone.

What the trace says, across the corpus:

| page | bytes/px | pale fraction | suppressed |
|---|---|---|---|
| `084-van-egy-ut` | 0.0272 | 0.0422 | yes |
| `098-szivemben-orom-dalol` | 0.0225 | 0.0169 | yes |
| `125-nincs-mas-isten` | 0.0347 | 0.0311 | yes |
| `151-zengjed-a-dalt` | 0.0213 | 0.0139 | yes |
| `166-tekozlo-fiu` | 0.0373 | 0.0319 | yes |
| `185-jezus-krisztusom` | 0.0500 | 0.0451 | yes |
| `app-jezus-szivedbe-lat` | 0.0370 | 0.0444 | yes |

The gate is `0.012`. **Every page clears it**, and the highest score belongs to
the born-digital screenshot — which has no paper and no reverse side — above the
one page whose reverse side genuinely is legible through it. The
`0.00%–0.60% across seven clean scans` calibration behind `_paleFraction` was
measured on renders and simulated photographs, and never re-measured after the
Python median-blur flattening was replaced by the Dart port's box-blur of a local
maximum. The Python arm over-fires on the same corpus for the same reason.

So the sentence named a cause it could not establish, on every single import. It
is withdrawn from both arms, the three gold files that expected it no longer do,
and a test in `test_harness.py` says so — the slug stays mapped, because a gold
file has to be able to say it if the detection is ever calibrated.

**The suppression itself stays on, and has to.** It is not really ghost removal:
it flattens the lighting and stretches the levels, and the reader needs that
almost everywhere. Turning it off, measured:

| page | with | without |
|---|---|---|
| `app-jezus-szivedbe-lat` | 0.965 | **0.351** |
| `185-jezus-krisztusom` | 0.453 | **0.142** |
| `166-tekozlo-fiu` | 0.881 | 0.784 |
| `084-van-egy-ut` | 0.715 | 0.564 |
| `098-szivemben-orom-dalol` | 0.799 | 0.733 |
| `125-nincs-mas-isten` | 0.513 | **0.571** |
| `151-zengjed-a-dalt` | 0.913 | **0.996** |
| **mean** | **0.748** | **0.592** |

Two pages would read better without it, and nothing in the pale fraction
separates them from the five that would read worse — `151` has the *lowest*
fraction and prefers it off, `098` the second lowest and prefers it on. So the
open question is not the threshold, it is that there is no signal here to
threshold. Until there is, the cleaning runs on every page.

### Where that leaves the warnings

`warn` is 1.000 on five of seven pages now. What remains:

- `185-jezus-krisztusom` does not raise `german-chords`, because its `H7` is
  misread — a reading failure, not a notice failure.
- `app-jezus-szivedbe-lat` raises `low-resolution` unasked. Bytes per pixel is
  the wrong proxy for a born-digital image: the screenshot is perfectly legible
  at 0.0370. Kept as a failure rather than papered over, because the metric is
  the only thing that will remember.

## 2026-08-22, fourth session: one unreadable token no longer costs the row

Robert's call: tolerate it. **0.748 → 0.827 mean over seven pages**, and the
worst page in the corpus moved more than any single change has moved anything.

| page | before | after |
|---|---|---|
| `185-jezus-krisztusom` | 0.453 | **0.778** |
| `166-tekozlo-fiu` | 0.881 | **0.957** |
| `098-szivemben-orom-dalol` | 0.799 | **0.880** |
| `125-nincs-mas-isten` | 0.513 | **0.581** |
| **mean** | **0.748** | **0.827** |

### The rule, and why it has two thresholds

`185-jezus-krisztusom` prints `G D em H7` over two of its lines. The 7 is struck
through in pen, so the recogniser returns `HÁ` on one row and `HSX` on the other,
and the all-or-nothing rule threw `G`, `D` and `em` away with it — twice on one
page. Chord recall 0.200.

One unrecognised token is now tolerated when the row carries enough recognised
chords:

- **three chords** is enough for any stray token;
- **two** is enough when the stray token does not look like a word — it carries a
  capital, a digit or a symbol. A chord is printed as a capital, or as a
  lowercase minor which is already a chord token, so a misread one rarely comes
  back as plain lowercase letters — and plain lowercase letters are exactly the
  shape of a Hungarian word.

Calibrated rather than guessed, and the calibration is the whole reason there are
two numbers. Candidates measured against every lyric line of every gold file and
of every song the app ships — 171 real lines:

| rule | recovers | breaks (real) | breaks (adversarial) |
|---|---|---|---|
| one unknown, ≥1 chord | 13 | 0 | `A szívemben` |
| one unknown, ≥2 chords | 7 | 0 | `A G szívemben`, `a e dal`, … |
| one unknown, ≥3 chords | 6 | 0 | `a e b dal` |
| **≥3, or ≥2 when the stray token is not a lowercase word** | **7** | **0** | `a e b dal` |

`≥1` is out on the spot: it turns `A szívemben` into a chord row, which is the
line this whole family of rules exists to protect. `≥2` for anything turns
`A G szívemben` into one. The composite recovers everything `≥2` does with the
safety of `≥3`, and the one thing it still misreads is `a e b dal` — three bare
note letters and one word, which is not a line any hymnal prints.

Two things worth noticing in that table. My own first guess — *tolerate only when
the stray token starts with a note letter* — recovered **one** of the seven,
because `!`, `£` and `5US2` do not start with note letters and those are exactly
the misreads that happen. And the 13 that `≥1` recovers are almost all garbage:
`; Em`, `. Em`, `C DGD`. Recovering more is not the goal.

What the seven actually are, all six on real pages plus the intro line:

| page | stray token | the row |
|---|---|---|
| `185` | `HÁ` | `G D em HÁ` |
| `185` | `HSX` | `G D em HSX` |
| `166` | `£` | `D E A £` — an `E` |
| `166` | `fiszmn` | `A E fiszmn E D` — a `fiszm` |
| `098` | `en` | `G D en G` — an `em` |
| `125` | `!` | `! Em C G` — the printed column rule |
| `125` | `5US2` | `5US2 G5-Gsus2 D4/Fis` — a `Csus2` |

### The cost, and it is a real one

Chord **precision** fell on three pages — `098` 0.923 → 0.882, `125` 0.917 →
0.871, `166` 1.000 → 0.944 — because the tolerated token is *kept* rather than
dropped. `HÁ` reaches storage as a chord, in the column the page printed it in.

Kept on purpose. It is visibly wrong somewhere a moderator can fix it, and a
silently missing chord is the harder thing to notice — the same reasoning that
keeps a lowercase `a` becoming A minor rather than being dropped. F1 rose on
every page, which is the trade being favourable: on `185`, precision 1.000 →
0.818 against recall 0.200 → 0.600.

The gate flagged the precision drops, correctly. They are the price, not a
mistake.

### And the third place the rule has to live

`chord_row_reason` counts, and a count is not a regex — so `editor.rules()` could
not ship it the way it ships the patterns. The two thresholds and the
lowercase-word pattern now travel beside the patterns as `thresholds()`, and the
preview does the counting from them. A literal `3` written into `editor.html`
would be a second copy of the rule, which is the failure that module exists to
prevent — and which had just happened, one commit earlier, to the hyphen-joined
chord run.

## Verify

```bash
python -m unittest discover -s tools -p "test_*.py"       # expect 326
python -m tools.ocr_harness run                           # the Python arm
python -m tools.ocr_harness run --engine browser          # what actually ships
cd songbook_app && flutter analyze --no-fatal-infos       # expect exit 0, 0 issues
cd songbook_app && flutter test                           # expect 1217
cd songbook_app && flutter build web --release --no-web-resources-cdn
```
