# Handoff — photo import (add a song by photographing it)

_Updated 2026-08-01. Uncommitted by design._
_Scope: the photo-import feature and its backend. The wider platform/hosting question is
`HANDOFF-platform.md` in the main checkout; general V1 work is `HANDOFF-v1-pwa.md`._

## Where we are

Songbook can add songs by pasting a chord sheet or opening a MusicXML file. This stream adds a
third source: photograph a song, get lyrics and chords. The app side is **built, tested and
verified working end to end**. The backend now has a **free, offline, no-API-key mode that
works** — `--easyocr` — measured against ground truth rather than assumed.

- **Worktree:** `C:\Users\rober\source\repos\songbook-app-worktrees\v1-polish` (branch
  `claude/v1-polish`)
- **Main checkout:** `C:\Users\rober\source\repos\songbook-app` (branch `master`, at `0a2d46b`)
- **Rebased onto `0a2d46b` and green.** The branch is now 10 commits on top of
  current master, and the only thing left uncommitted is this document.
- **Suite:** **935** Flutter tests green (was 886), `flutter analyze` **0 issues, exit 0**.
  **132** Python tests in `tools/`, of which 56 are new.
- **Safety net:** `backup/pre-rebase-v1-polish` and `backup/pre-rebase2-v1-polish` are the branch
  tips before each rebase, kept until the work is merged. Delete both after.

## Done — 10 commits on `claude/v1-polish`, NOT pushed, NOT merged

Nothing is left uncommitted but this document. Listed by subject, not SHA: this branch has been
rebased twice already and every SHA changed both times. `git log --oneline master..HEAD` is the
authority.

- **take the analyze baseline to zero** — the last 8 findings were deprecated Radio API use,
  converted to `ListTile` + tick. Also fixed a latent bug: the middle default-view row ignored its
  own `value` and relied on position.
- **define the photo-import contract** — posts multipart (`image`), reads
  `{"kind": "chordpro" | "musicxml", "content": "…", "warnings": [...]}`. `chordpro` feeds
  `ChordSheetParser`, `musicxml` feeds `MusicXmlImporter` — **both consumers already ship, so
  "photograph a score, get engraved notation" is a backend change, not an app release.**
- **make the photo-import endpoint configurable** — endpoint + optional token as user settings,
  validated on read.
- **import a song from a photo** — the UI, translated in all three languages as it was written
  (13 keys × en/hu/ro). Post-rebase the Photo button lives in the "More ways to add" expander.
- **a local stand-in for the photo-import backend** — `tools/photo_import_worker.py`, stdlib only.
- **let a photo endpoint be set up without typing it** — the `?photoEndpoint=…` link, applied
  before `runApp` (it must sit **before** the fragment — routing is hash-based and `Uri.base`
  cannot see query params after a `#`), plus a build-time default via `String.fromEnvironment`. A
  stored value always wins, so a LAN IP cannot leak into the public deployment.
- **read H as B natural** — see its own section below.
- **read a photographed song with EasyOCR** — the whole `--easyocr` mode, plus
  `tools/test_photo_import_worker.py`: tests driving the bridge with hand-built boxes, importing
  no EasyOCR, so they run on a bare interpreter in milliseconds.
- **close the space the recogniser puts before a comma**.
- **stop the MusicXML hint speaking for the Photo button**.

## `--easyocr`: what it does and what it measured

`python tools/photo_import_worker.py --easyocr` — free, offline, no key, no account.

EasyOCR returns each token with a bounding box; `ChordPosition.position` is a character column. The
bridge groups boxes into rows by y, classifies each row with a **verbatim port of
`ChordSheetParser`'s chord rules** (the two must agree — the app re-parses whatever the worker
emits), lays lyrics out by chaining columns off the previous token, then interpolates each chord's
pixel x onto the columns the lyrics actually landed on.

**Measured, not assumed:**

| what | result |
|---|---|
| Hymn scan, 800px binarised (`zsolt-090`) vs `songs.json` song 90 v1 | **97.8%** char similarity |
| Rendered Hungarian chord sheet, 2400px, 14 chords | **14/14 over the right syllable** |
| Same sheet at 4032px (phone resolution) | **no slower than 2400px** |
| Simulated photo: 2° tilt, soft lighting, blur, JPEG 85 | 13/14 (one `D` read as `0`) |
| Simulated photo: **6.5° tilt + keystone**, hard lighting, blur, JPEG 72 | **14/14** |
| Curled page, realistic bend (11% drop, 9% foreshortening) | 13/14 |
| Curled **and** tilted 4° | **14/14** |
| Curled to 36% drop — far past anything a real page does | 13/14, structure intact |

Lyrics come back **exact on seven of those nine images**, including both simulated photographs.

The chord rows come back byte-identical to the source, and survive a badly taken photo. Getting
there took three fixes, all below: the detector thresholds, `H`, and deskewing. Curl was
predicted to be a fourth and turned out not to be one.

**Timing is dominated by machine load, not by the image.** Four consecutive runs on a quiet
machine: 27.5, 27.5, 28.6, 26.3s — but the same file took 110.8s during a burst of unrelated
load, and the photos took 41-44s. The app's client timeout is **90s**
(`photo_import_service.dart:92`), which is comfortable normally and *can* be exceeded on a busy
machine. If `--easyocr` ever becomes the real backend rather than a local experiment, either raise
that timeout or give the worker a machine of its own.

- **Almost every hymn error was the Hungarian `ő`**, read as `ó`, `ö` or `6`. The `6` case is now
  repaired (`6`→`ő` where a digit touches a letter, beside the older `1`→`i`), which is what took
  the scan from 97.5% to 97.8% and made the last line exact. `ó` and `ö` are **not** repairable
  the same way — they are ordinary letters, and rewriting them would break `jó` and `föld` to fix
  `tól`. What remains is that residue.
- **Resolution costs nothing.** EasyOCR caps its detection canvas at `canvas_size` (2560), so a
  4032px phone photo is no more work than a 2400px one. No downscaling needed.
- **Stave furniture is dropped.** A row containing no letter at all (`4=`, read off a time
  signature) is discarded before grouping — not a lyric, and a chord always carries its root
  letter.

### The detector thresholds are the whole ballgame

At EasyOCR's defaults the chord sheet gave **9 of 14** chords. Every miss was a lone `G` or `D`;
all four `A`s and both `Hm`s came through. CRAFT is tuned for prose and drops a single letter
sitting alone in white space — which is exactly what a chord is.

`text_threshold=0.5, low_text=0.3` gives **14 of 14**. Both must move: 11/14 and 9/14 alone.
Lowering `text_threshold` *without* `low_text` is also **4.5× slower** (113s vs 25s) — a high
`low_text` leaves CRAFT growing a crowd of marginal regions that each cost a recogniser pass.
Lowered together it costs nothing. `mag_ratio` and `width_ths` changed nothing.

### Tilt had to be corrected before grouping

`group_rows` clusters by y centre, so tilt is the one distortion that destroys it: at 6.5° across a
2000px line the left end sits ~228px — four line-heights — above the right, and a line arrives as
several rows with its chords shuffled into the lyrics below. Simulated photos put the boundary
between harmless and unreadable at somewhere under 6.5°; 2° was fine.

**EasyOCR cannot be asked for the angle** — it returns axis-aligned rectangles however the text is
rotated (every top-edge angle came back exactly 0.00° on a 6.5° page), so the tilt survives only in
where the boxes sit relative to one another.

`estimate_skew` recovers it by projection profile: project the box centres across the text for each
candidate angle, bin them, and take the angle scoring highest on the sum of squared bin counts —
at the true angle a line falls in one bin, at any other it smears. Two grids half a bin apart, so a
line landing on a boundary is not read as smeared. It found −6.50° on the hard photo, exactly. Then
`deskew` rotates the box centres back; the text itself was read correctly all along, so nothing is
re-recognised. `--easyocr` never re-runs OCR, and the correction costs nothing measurable.

### Curl was predicted to break it, and does not

The previous version of this document called page curl the untested risk, on the reasoning that
`estimate_skew` fits **one** angle to the whole page while curl bends a line into a curve. That was
**wrong, and the measurement says so** — a curled page reads 13/14, and curled-and-tilted reads
14/14. Even a 36% drop, far past anything paper does, keeps the structure whole: title, verse
break, and all eight lines correctly paired.

Two things carry it, and both are worth knowing before anyone "improves" them:

- A quadratic bend is well approximated by a straight tilt across a page, so the projection profile
  absorbs most of it as an average slope (+2.25° on the realistic curl) and only the residual
  curvature is left.
- `group_rows` chains boxes against a **running mean** of the row so far, not against a fixed line,
  so it tracks a slowly drifting baseline on its own. On the curled-and-tilted page, grouping was
  wrong before deskew (10 rows) and right after (9).

So the remaining unknown is smaller than it looked. What a real photograph still adds over the
simulation is paper texture, a crease, and a shadow cast by the phone itself — none of which is
geometry, which is the part that was in doubt.

### `H` — the app now speaks Hungarian notation

`H` is B natural across Hungary, Germany, Poland, the Balkans and Scandinavia — a medieval
scribal accident, where the square `b` meaning B natural was written in a hand later readers took
for an `h`. It is not a Hungarian quirk; the A–G world is arguably the minority.

The app used to reject it, **deliberately and pinned by tests** (`chord_transposer_test.dart:31`
asserted `parseChord('H')` was null). Consequence: a row reading `D A Hm G` was **not a chord
row**, so it was emitted as a lyric line and every chord on it entered the song as a word. That,
and only that, is why 4 of 14 chords looked misplaced — the interpolation had them at exactly the
source columns all along.

**Shipped (Robert's call):** `H` is accepted everywhere chords are read — photographed, pasted or
typed — and renamed to `B` on the way into storage.

- `chord_transposer.dart` — `[A-GH]`, plus `toEnglishNotation`, applied in `parseChord` and
  `_keyToIndex` so transposition and capo read `H` too.
- `chord_sheet_parser.dart` — `[A-GH]` in `_chordToken` and `_bareRoot`; stores the renamed symbol.
- **`B` deliberately still means B natural.** Strict German notation reads it as B flat, but every
  stored song assumes B natural, and redefining it would silently re-tune the library. `H` only
  ever adds information — unlike `B`, it names the same pitch in every system that uses it.
- One collision accepted and pinned: `Hadd` is a Hungarian word that parses as H+add. The
  all-or-nothing row rule contains it, so only a line consisting of that single word is misread.
- The worker emits `Hm` as written and lets the app own the rename, so the transcription stays
  faithful to the page. It says so in a warning, so nobody who photographs `Hm` and is shown `Bm`
  has to wonder whether the import broke.

**Still open, and now the interesting one:** whether B natural should ever be *displayed* as `H`.
Storage is canonical, so this is purely a display concern — a note-name setting would show `H` to
whoever wants it, for all songs rather than just imported ones, with no migration. It needs new
strings in all seven `l10n/` files, which is exactly where `master` already conflicts, so it is
better done after the rebase. The same mechanism would later serve Romanian fixed-do (Do Re Mi),
which is how Romanian musicians actually name pitches.

## Blocked / Known issues

- **No API key on this machine.** `--live` refuses to start, so **stub vs easyocr vs live was
  never a three-way comparison** — only stub vs easyocr. The vision-model arm is still unmeasured.
- **Recognition, not layout, is what is left.** Every remaining chord miss across the nine test
  images is EasyOCR reading the glyph wrong in the right place — a lone `D` coming back as `0` or
  `i` — plus one column of drift at the extreme right edge of a heavily curled page. Nothing in the
  bridge can fix a misread letter; that ceiling is EasyOCR's, and it is the argument for `--live`
  if the accuracy ever needs to be higher.
- **A score is the wrong input for `--easyocr`.** The hymn scan produced one junk line (`4=`) from
  stave furniture. Scores should go through `oemer` to MusicXML, not through OCR; the contract
  already carries `kind: musicxml` for exactly that.
- **The Playwright MCP is down**, with every other MCP server. Global `playwright` v1.59.1 works
  from a script: `NODE_PATH="$(npm root -g)" node script.js`.
- **First-tap timing flake.** One run failed with "no file chooser"; an identical retry passed. The
  Photo button can be tapped before the canvas is interactive. Not diagnosed.
- **Not verified on a real phone:** the setup link and the build-time default (desktop Chrome only),
  and `--easyocr` end to end from the phone.

## The rebases (done, twice)

**`master` moves often — check where it is before trusting anything here.** It had moved *three*
commits when this branch was first rebased, not the one the previous handoff recorded: the
file-picker demotion (`a3bde65`), a **Supabase-backed catalogue** (`9bc106b`) and **optional
accounts** (`89a8428`). It then moved again *during the same session* — **moderation queue,
submission lifecycle and Google sign-in** (`0a2d46b`) — so the branch was rebased a second time.
Master SHAs are stable; every branch SHA changed both times.

What needed a decision:

- **`import_song_screen.dart`** — the real one. `a3bde65` *moved* the MusicXML button out of the
  Parse row into a "More ways to add" expander; this branch had added the Photo button beside it in
  the row that no longer exists. Resolved master's way: Parse stays alone, and **Photo now lives in
  the expander next to MusicXML**. Master's own comment had already called that spot "the landing
  point for a photo pipeline later". Three tests in `import_photo_test.dart` tapped a button that
  is now behind a disclosure; they open the expander first, and the first one now also pins that
  Photo is hidden until it is opened. That fix was folded back into the UI commit with
  `--fixup` + `--autosquash`, so no commit is left red for `git bisect`.
- **Seven `l10n/` files, both times** — both sides only ever appended keys. The three `.arb`
  sources were merged and then *parsed* to prove the JSON, which earned its keep: a hunk from each
  side ended mid-object, so the join had to close master's dangling descriptor, and a comma alone
  produced invalid JSON. All three files came out with **matching key counts** (270, then 286), so
  no locale lost a string. The four `app_localizations*.dart` are generated — regenerated with
  `flutter gen-l10n`, never hand-merged. `resolve_arb.py` in the scratchpad does the whole thing
  and is worth keeping for the next one.
- **`pubspec.yaml`** — `supabase_flutter` and `http` both wanted; kept both and re-locked.
- **`main.dart`** — Supabase init and the `?photoEndpoint=` setup link are independent; kept both.

## Remaining work (ordered)

1. **Photograph a genuinely real page.** Tilt, keystone, curl, lighting, blur and JPEG damage were
   all *simulated* (`make_photo.py` and `make_curl.py` in the scratchpad) and all survived, so the
   **geometry is no longer the worry** — see the curl section. What a real camera still adds is
   paper texture, a crease, and the shadow of the phone over the page. Lower risk than it looked,
   but still the only thing standing between this and calling it done.
2. **The note-name display setting** (see the `H` section) — the one open product decision.
   Storage is canonical now, so showing `H` is purely a display concern, and the same mechanism
   later serves Romanian fixed-do, which is how Romanian musicians actually name pitches. Needs
   seven `l10n/` files.
3. **Answer whether a model can read *notation* at real resolution.** Still open, still needs a key.
   Robert's earlier test upload was 87 KB, which suggests the browser downscaled it — check that
   before drawing conclusions.
4. **Merge and deploy.** The branch is rebased and green, so this is now just the merge. Safe with
   no endpoint configured — the Photo button explains where to set one up. CI runs tests + analyze,
   deploys, tags `build-<n>`. Not done here: merging and deploying are Robert's call.
5. Only if a hosted backend is wanted: port to a Cloudflare Worker. **Copy the CORS handling
   verbatim** — without it the browser discards a valid 200 and the app reports the service never
   answered while the server logs success. Note `--easyocr` cannot go: torch does not fit.

## Files / commands reference

**Key source**
- `songbook_app/lib/domain/services/photo_import_service.dart` — contract + HTTP client (90s timeout)
- `songbook_app/lib/domain/services/chord_sheet_parser.dart` — the rules the worker ports
- `songbook_app/lib/presentation/screens/import/import_song_screen.dart` — `_PendingImport` is the
  convergence point; a new source produces one of those, not another screen
- `tools/photo_import_worker.py` — the backend stand-in, all three modes
- `tools/convert_hymn.py` — the existing OMR/OCR pipeline (`run_oemer`, `ocr_lyrics_from_image`)

**Run it**
```bash
cd C:/Users/rober/source/repos/songbook-app-worktrees/v1-polish
python tools/photo_import_worker.py --port 8790 --host 0.0.0.0             # stub
python tools/photo_import_worker.py --port 8790 --host 0.0.0.0 --easyocr   # free, offline
python tools/photo_import_worker.py --port 8790 --host 0.0.0.0 --live      # needs a key

cd songbook_app
flutter build web --release --dart-define=PHOTO_IMPORT_ENDPOINT=http://192.168.0.102:8790/extract
powershell -c "Start-Process python -ArgumentList '-m','http.server','8791','--directory','<abs>/build/web' -WindowStyle Hidden"
```
Phone: `http://192.168.0.102:8791/` — arrives pre-configured via the dart-define. Must be the
**HTTP** LAN app, never the deployed HTTPS one: mixed content blocks an HTTPS page from calling an
HTTP endpoint, with no override.

**Verify**
```bash
cd tools && python -m unittest discover -p "test_*.py"   # expect 132
cd songbook_app && flutter test                          # expect 935
cd songbook_app && flutter analyze                       # expect 0 issues, exit 0
```
CI runs `flutter analyze --no-fatal-infos`, which downgrades **infos only** — a warning (an unused
import) still fails the deploy. Check `$?` directly; piping to `tail` masks it.

**Browser automation without the MCP**
```bash
NODE_PATH="$(npm root -g)" node your-script.js
```
Flutter renders to canvas, so there is no DOM: click by coordinate, and **re-screenshot first**,
because the layout shifts with content. Flutter's service worker defeats `?cachebust` — unregister
workers *and* delete caches.

**Test assets**
- `tools/audiveris_output/zsolt-090.width-800.omr` (in the **main checkout** — gitignored, not in
  the worktree) is a zip containing `sheet#1/BINARY.png`, an 800px binarised hymn page.
  `songs.json` song 90 verse 1 is ground truth for its lyrics.
- The rendered Hungarian chord sheet, its phone-resolution version, and the comparison scripts are
  in this session's scratchpad:
  `C:\Users\rober\AppData\Local\Temp\claude\C--Users-rober-source-repos-songbook-app\6effe764-8592-43f4-bfd2-0592e99b6dcc\scratchpad`
  (`make_chordsheet.py` regenerates the sheet from a string; `sweep.py` re-runs the threshold
  comparison; `http_check.py` round-trips all three modes over real HTTP).

## Resume prompt

```
Continue photo import for Songbook.

Worktree: C:\Users\rober\source\repos\songbook-app-worktrees\v1-polish  (branch claude/v1-polish)
Main checkout: C:\Users\rober\source\repos\songbook-app  (branch master)
Read the full handoff first: <worktree>\HANDOFF-photo-import.md

--easyocr is built, measured and REBASED ONTO CURRENT MASTER (0a2d46b), all green: 935 Flutter
tests, 132 Python tests, analyze 0 issues. 14/14 chords over the right syllable on a rendered
Hungarian chord sheet, and still 14/14 on a simulated photo at 6.5 degrees with keystone, hard
lighting and JPEG damage. 97.8% char similarity on the ground-truth hymn scan.

Three fixes got it there, all landed and all measured, not guessed: EasyOCR's CRAFT thresholds
drop lone glyphs (text_threshold=0.5 + low_text=0.3 — both, or it does not work); H, which is B
natural in Hungary and which the app rejected by tested decision, is now accepted everywhere
chords are read and renamed to B on the way into storage (B still means B natural — redefining it
would re-tune every stored song); and tilt, which broke row grouping until the skew was recovered
by projection profile over the box centres.

The rebase is done — master had moved THREE commits (file-picker demotion, Supabase catalogue,
optional accounts), not the one the old handoff recorded. The Photo button now lives in the
"More ways to add" expander beside MusicXML. Rebased TWICE — master moved again mid-session (moderation queue,
submissions, Google sign-in). backup/pre-rebase-v1-polish and -pre-rebase2- are the old tips;
delete both once merged. Master moves often: re-check before assuming this is current.

Page curl was predicted to break the row grouping and DOES NOT — a curled page reads 13/14 and
curled-and-tilted reads 14/14, because a quadratic bend is well approximated by a straight tilt
(so the projection profile absorbs most of it) and group_rows chains against a running mean that
tracks the residual drift. Don't "simplify" either mechanism without re-running make_curl.py.

Next, in order: (1) photograph a REAL page. Geometry is no longer the worry — tilt, keystone and
curl are all simulated and all survive — so what is left is paper texture, a crease, and the
phone's own shadow. (2) the note-name display setting: the ONE open product decision, and the only
item needing Robert. Storage is canonical, so showing H is purely display, and the same mechanism
later serves Romanian fixed-do. Seven l10n files. (3) merge and deploy — Robert's call,
deliberately not done here.

Everything still failing is EasyOCR misreading a glyph in the RIGHT place (a lone D coming back as
0 or i). No change to the bridge fixes that; it is the argument for --live.

Caveat: still NO API key, so --live has never run and the comparison is stub-vs-easyocr only.
The Playwright MCP is down; use NODE_PATH="$(npm root -g)" node.
```
