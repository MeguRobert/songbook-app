# Making the import screen work like the gold generator

_Design record, 2026-08-26. Decisions are Robert's; the measurements and the
reasoning are recorded so the next session does not have to re-derive them._

## The problem this solves

The measurement harness has a gold editor (`tools/ocr_harness/edit`) that is
plainly better at correcting a photographed page than the app is. It shows the
photograph beside the parsed lines, tells you which rows it reads as chords, and
lets you fix one at a time. The app's import screen shows a paste box, a
rendered preview, and no way to touch a line the reader got wrong — so the
only correction surface is retyping monospaced text in a text field.

That is backwards. The editor exists for nine photographs; the app is for every
photograph anyone ever takes.

Three things were also in the way of the photo path being found at all:

* the **MusicXML file picker** shares billing with it, and needs a score
  exported from MuseScore first;
* both live behind a **"more ways" expander**, so the photo button is two taps
  and a guess away;
* the **photograph is thrown away** the moment it is read, so there is nothing
  to compare the reading against.

## What was decided

| question | answer |
|---|---|
| the editing surface | a line list under the photo, like the gold editor |
| where the photograph goes | beside the preview on wide screens, stacked on a phone |
| tapping one token | **edit it in place**, not force it to be a chord |
| MusicXML upload | removed |
| the "more ways" expander | removed; Photo promoted beside Parse |
| the paste box | stays — it is the common path for a chord-site import |

The token decision is the load-bearing one. A token the parser cannot spell —
`5US2` where the page prints `Csus2` — cannot be *stored* as a chord:
`ChordTransposer` would have nothing to transpose, and the app would save
something that looks like music and is not. This session removed exactly that
class of defect from the reader (`c` stored as C minor where the page prints
`C`), so putting it back through the UI would be perverse. Fixing the token is
what makes the row become chords, and the parser then agrees on its own.

## Where truth lives

Today the screen holds a `String` and derives everything from it. A line has to
be able to say *"I am chords"* when the parser disagrees, so the state grows by
exactly one field:

```
_sheetController.text        the text, still the source of truth
_kinds: Map<int, LineKind>   only the lines the user overrode
```

**Sparse on purpose.** An empty map means "the parser decides everything", which
is today's behaviour to the character. Nothing is stored per line that the parser
can already work out, so there is no second opinion to keep in step.

`ChordSheetParser.parse` gains `{LineKinds? kinds}`. Inside the line loop there
are exactly two decision points, and they become:

```dart
kinds?.isChords(i) ?? isChordLine(raw)
kinds?.isLyric(i + 1) ?? _isLyricLine(next)
```

Everything downstream — verses, chord positions, `ChordView` — is untouched, so
the preview stays *exactly what will be saved* rather than becoming an
approximation that can drift from it.

### The three actions are edits to those two fields

| action | effect |
|---|---|
| line → chords | `_kinds[i] = chords` |
| line → lyric | `_kinds[i] = lyric` |
| edit a token | rewrite the token in the text, and **clear** `_kinds[i]` |

That last row matters more than it looks. Fixing `5US2` → `Csus2` makes the
parser agree by itself, so the override is dropped rather than left behind. **An
override that outlives its reason is how a wrong chord gets stored quietly** —
the row would keep claiming to be chords long after the evidence changed.

Editing a token rewrites the text in place preserving column width where it can.
A chord's column *is* its position, so a one-character-longer replacement shifts
the rest of that row and nothing else.

## The screen

```
PASTE          text box + [Parse]  +  [Photo]      <- promoted
DETAILS        title · number · book · warnings    (unchanged)
LINES          the new editable list
PHOTO ┆ PREVIEW    side by side >= 720px (was 900 - see the end), stacked below it
```

Gone: `_pickMusicXmlFile`, `_showMoreWays`, the expander, `importMusicXmlFile`,
`importMusicXmlHint`, `importMoreWays`. `musicxml_importer.dart` itself **stays** —
the notation editor and its tests use it; only the upload button goes.

`_photoHasSheetMusic` and its curl warning move up beside the Photo button. That
hint — *a curled page took the reading from 63 notes to 6* — is the single most
valuable sentence on the screen and must not end up orphaned by the expander it
lived in.

### `_LineList`

One row per non-blank line:

| part | behaviour |
|---|---|
| kind badge | `CHORDS` / `lyric`; dimmed when the parser decided, solid when you did |
| tokens | chips on a chord row, plain text on a lyric row |
| actions | `[chords] [lyric]`, current kind selected; tapping it clears the override |

A chord row's chips come from **the same `_token` regex the parser uses**, so a
chip *is* a token rather than a re-split that can drift from it. Tapping one
opens a one-field dialog seeded with its text.

### `_PhotoPane`

Holds the picked bytes — new state; today they are read and dropped — an
`Image.memory` inside an `InteractiveViewer` for pinch-zoom, and the file name.
Absent until a photo is picked, and the side-by-side collapses to just the
preview when there is none, so a pasted sheet sees no change at all. Both panes
keep the preview's existing 340px height so the row does not jump.

## Tests

The parser override can break stored music, so it is tested first and hardest.

* `parse` with no `kinds` is **byte-identical to today** over every existing
  fixture. This is the regression guard for the whole change.
* an override makes a lyric line pair with the line under it, and its chords land
  at the right columns
* an override marking a chord row as lyric stops it being consumed as a pair
* a stale or out-of-range index is ignored rather than throwing

Then the screen: tapping `[chords]` changes the preview; editing a token clears
the override; the photo pane is absent with no photo; the layout stacks under
900px.

## Three risks

1. **A stale override after re-parsing.** Press Parse again and line 7 is a
   different line. Overrides are cleared on every Parse: an override belongs to
   the text it was made against.
2. **A token edit corrupting alignment.** Guarded by the column-preserving
   rewrite and a test that a longer replacement shifts only its own row.
3. **The line list disagreeing with the preview.** Both must read from one parse
   call, not two — the same discipline `_preview` and `_draft` already keep.

## Order

Three commits: the parser override, the screen surgery (removals and the photo
pane), then the line list.

## Not in this change

* **`Az Úr irgalma végtelen` (7570) is still not photographed.** It cannot be
  recovered from production: the text reader runs Tesseract in the browser and
  uploads nothing, the Supabase schema has no image column in any migration, and
  the only server-side path is Cloud Run for *sheet music*. It needs a fresh
  photograph — **not one routed through a messenger**, which returns 0.026 bytes
  per pixel with EXIF stripped and destroys `ő` and `ű`.
* Forcing an unspellable token to be stored as a chord. See above.

## What using it found

_Added later on 2026-08-26, after the screen above was built, opened in a real
browser (`e2e/import.e2e.cjs` against a release build, then two corpus pages by
hand) and used to correct a page. Every widget test was green throughout._

**The photograph and the preview never sat side by side.** The row above says
"side by side ≥ 900px". The screen lives in a `ContentPane.list`, which caps it
at `ContentWidths.list` = 800 and pads it 16 a side, so the `LayoutBuilder`
was never handed more than 768 and the side-by-side branch was dead code from
the day it shipped — at 1100 wide, at 1400 wide, at any width. The breakpoint is
now **720**, lives in its own widget (`ReviewPanes`) beside the arithmetic, and
its test pins it under `ContentWidths.list - 32`. Two panes of 352 and a 16
gutter: a phone's width each, which is what the song view is designed for, and
enough of the page to see which row a chord belongs to; the pane zooms for the
rest.

**The list was one utterance to a screen reader.** Flutter merges a block's
static text into the nearest node that already exists — here the `ListView`
item holding the list — so the hint, every badge and every lyric line became a
single label, and only the buttons were nodes of their own. Nothing could say
which row a button belonged to. Each row is now a `Semantics(container: true)`,
which is also what let the browser walk address a row at all. The photo pane
had the same defect with a twist: the image's own unlabelled semantics flagged
the merged item as an image, and the browser hung its label off an auxiliary
element nothing reads — *PHOTO* was on screen and nowhere in the tree. The pane
is now its own node with a labelled image inside it.

**`-7` was underlined red.** The chip colour asked only `isChordToken`, so a
continuation the parser reads perfectly well — `-7`, the chord before it with a
seventh — was marked as the token most in need of correcting, on a fixture
where the reader had it right. A chip is marked only when the parser reads it
as *nothing*: not a chord, not a continuation, not a separator, not a stage
direction. `isSeparator` and `isDirective` became public for this, so the list
asks the parser rather than re-spelling its rules.

**`{title: …}` had a row.** With a "words" badge and two kind buttons that
could do nothing, because the parser consumes a directive before it ever asks
about a line's kind. Directives are left out of the list; the index still counts
them, so nothing below is renumbered.

### Measured, and left for a decision

On `125-nincs-mas-isten` — 61 gold lines, two columns — the line list runs
**2,426 px** from `LINES` to `PREVIEW`, so the photograph the reviewer is meant
to check each row against sits two and a half screens below the rows. On `185`
it is 400 px and unremarkable. The gold editor does not have this problem
because its photograph is a **sticky 40% column beside the lines**
(`editor.html`: `grid-template-columns: minmax(320px,40%) 1fr`, `#shot
{position: sticky}`), and the preview is what sits below. The table above
records Robert's decision as "beside the preview"; the app now does that
faithfully. Whether the photograph should instead stay beside the *lines* on a
wide screen — the arrangement he was actually praising — is his call, and it
is a layout change, not a fix.

Also seen, not changed: the reading of `185` puts `195` in the number box (the
page prints 485 with 185 handwritten over it), and `HÁ`/`HSX` for the
struck-through `H7` — both the reader's, recorded in the measurement loop's
design record. The pane's file-name hint ellipsises at 352 wide.
