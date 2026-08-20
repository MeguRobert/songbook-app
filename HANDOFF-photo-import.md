# Handoff — photo import (add a song by photographing it)

_Updated 2026-08-20._
_Scope: photo import and its backends. Wider platform questions are
`HANDOFF-platform.md` in the main checkout; general V1 work is `HANDOFF-v1-pwa.md`._

## Where we are

Photo import is **wired end to end and measured in a real browser**. Anyone signed in can
photograph a song page; musician-moderators correct and approve it.

**Two engines on one photo**, because neither does the other's job:

```
chord sheet (the common case, the default)
  photo → canvas → PagePreprocessor → Tesseract.js → PhotoTextBridge → ChordPro → Song
          all in the browser: ~1s, free, offline, no server, no account

sheet music (opt-in, "this page has sheet music")
  photo → Cloud Run → Audiveris → MusicXML → MusicXmlImporter → Song
          ~10-40s, scale-to-zero, Supabase-authenticated
```

Both are reachable from the Photo button in "More ways to add". The checkbox under it chooses
the engine, and ticking it shows the instruction that decides whether notation reading works
at all: **press the book flat**.

- **Worktree:** `C:\Users\rober\source\repos\songbook-app-worktrees\v1-polish` (branch `claude/v1-polish`)
- **Main checkout:** `C:\Users\rober\source\repos\songbook-app` (branch `master`)
- **Branch state: ahead of master, and master is MERGED IN — nothing behind.**
  `git rev-list --count master..HEAD` is the count; chasing it in prose only ever
  produces an off-by-one. Master was merged rather than rebased, because its
  ContentPane reflow touches the same two screens and a rebase would replay six
  commits through one conflict. Master still fast-forwards to this. Master moved and its history was
  rewritten — the merge-base is `0a2d46b` and master carries 7 commits on top of it (CI
  gating, Supabase keep-awake, RLS test fixes, Google sign-in mark, PWA start_url).
  **Rebase before merging.** There are also four other `claude/*` worktrees on this repo;
  master moves under you.
- **Suite:** 1020 Flutter tests, 159 Python tests in `tools/`, 14 in `deploy/omr/`,
  `flutter analyze` 0 issues, `flutter build web --release --no-web-resources-cdn`
  succeeds and the release build boots in a headless browser with no
  Content-Security-Policy violations.

## What the browser path actually does, measured

Driven headless against `149-raw.png`, the real 2048x1532 photograph of song 149, through the
app's own `BrowserPhotoImportService` compiled to JavaScript:

| | |
|---|---|
| Chord rows recognised | **4 of 4** |
| `Ő` | read correctly |
| Time, engine already loaded | **1.0 s** |
| Time, first photo on a device | 1.5 s to 7.3 s, depending on how fast the CDN answers |
| Warnings raised | none — one column, chords found, no German note names |

The ChordPro it produced:

```
149  Mondd, ki a dzsungel királya

D                                              A
Mondd, ki a dzsungel Királya? Ki az Ur a tengeren?
em                   A              -7               D
Monda, ki az egész világ Királya, s ki a Királyom nekem?

A         D                                  A
Megmondom: J-É-Z-U-S! JEZUS! Ő az Ur a tengeren!
em           A               -)              D
Ő az egész világ királya, és Ő a királyom nekem!
```

Every chord is over the right syllable. The remaining errors are all OCR reading the letters
(`Monda` for `Mondd`, `Ur` for `Úr`, `-)` for `-7`, missing accents on `JEZUS`) and they are
exactly what the review screen exists to fix — the ChordPro is written into the paste box, not
just the preview, so a wrong word is one tap away from being right.

For comparison, the server engine this replaces: 3 of 4 chord rows, ~40 seconds, `Ó` for `Ő`.

## The review round, and what it found

Four independent reviews were run over this branch before it was considered
deployable: the browser reading path, the app wiring and token trust model, the
deploy plan and trilingual copy, and a whole-system security pass over the app,
Supabase, Cloud Run and CI. Everything below was found by them and is fixed on
this branch, except where it says otherwise.

**The one that mattered.** `?photoEndpoint=` accepted any host and stored it
silently and permanently, and the notation request attached the signed-in user's
Supabase access token to whatever was stored. A link to the *real* app, on the
real origin, with nothing visibly different about it, could therefore point the
app at any server and hand it a bearer credential for that person's whole
account the next time they photographed a page of music — enough for GoTrue's
`PUT /auth/v1/user` to change their password. Two reviewers found it
independently. The token now goes only to the service the build was compiled
with, compared by origin; the setup link only accepts a private or loopback
address, which is all it was ever for.

**Three ways the browser reader could fail silently.** No stage had a timeout,
so a stalled CDN fetch span the spinner until the page was reloaded. A script
that loaded but defined nothing — a captive portal answering 200 with HTML —
completed the shared load future *successfully*, poisoning it for the whole
session so no retry could ever re-inject. And there was no integrity hash, so
pinning the version said which bytes were wanted without checking the bytes that
arrived. All three fixed and verified in a real browser, the last one by
corrupting the hash on purpose and watching the browser block it and the second
attempt still fail cleanly.

**The instruction the feature depends on argued against itself.** Hungarian said
*szemből* and Romanian *din față* — head-on, from the front — under a sentence
telling the reader to press the book flat on a table. That wording invites
tilting the phone toward your face, which is the geometry that destroys staff
detection. Both now say from directly above, perpendicular to the page. The
Romanian imperative was also wrong (`fotografiază-o` for `fotografiaz-o`).

**Setting a Content-Security-Policy revealed a dependency nobody had noticed:**
the app was already fetching CanvasKit from `www.gstatic.com` on every visit, so
a Google CDN was executing script in this origin all along. The build now passes
`--no-web-resources-cdn` and serves the copy already in its own output.

### Not fixed here — separate work, and both worse than the handoff used to say

1. **An owner can silently rewrite their own already-approved song.**
   `songs_update_own` (`supabase/migrations/20260728120100_songs_rls.sql`) is
   `using (owner_id = auth.uid())` with no status constraint, and the trigger's
   entire guard sits inside `if new.status <> old.status` — so a content-only
   UPDATE on an approved row passes every check and republishes to the whole
   congregation with no review. The tell that this is an oversight rather than a
   decision: `songs_delete_own_undecided` *does* restrict to `draft`/`pending`.
   No test covers the case. Needs a migration and a negative RLS test.
2. **The legacy HS256 signing key is load-bearing, not retired.** The bundled
   client key decodes to header `{"alg":"HS256"}`, payload `role: anon` — so the
   project must keep HS256 verification enabled, and this document used to say
   "nothing here depends on it", which was wrong. While it stays enabled,
   anyone obtaining that one symmetric secret can mint a `service_role` token
   and bypass all RLS. Nothing in the repo leaks it (history was swept). Fix is
   to reissue the client key in the `sb_publishable_…` format, update
   `supabase_config.dart`, then disable the legacy secret in the dashboard —
   note the keep-alive workflow already *claims* the project uses that format.
3. Smaller, left deliberately: an unauthenticated caller can make the OMR
   service re-fetch the Supabase JWKS by sending junk tokens with novel `kid`s,
   which ties up both instances (cap `kid` length before the lookup); the OMR
   container runs as root (add a `USER` line); third-party GitHub Actions are
   pinned to mutable tags rather than commit SHAs; sign-up reveals whether an
   address is already registered while password reset carefully does not; and
   `_pickMusicXmlFile` has the same unguarded `setState`-after-await that
   `_pickPhoto` just had fixed.

## Live infrastructure

**Cloud Run OMR service — deployed and authenticated.**

- URL: `https://songbook-omr-541713551179.europe-central2.run.app` (POST `/extract`)
- GCP project `songbook-app-504220`, region `europe-central2` (Warsaw, nearest to Hungary)
- Config: `--memory 4Gi --cpu 2 --concurrency 1 --max-instances 2 --timeout 120`
- Env: `SUPABASE_URL=https://sjsgrxvebzsuubebbfwx.supabase.co` (public; no secret deployed)
- Redeploy: `cd deploy/omr && gcloud run deploy songbook-omr --source . --region europe-central2 --allow-unauthenticated --memory 4Gi --cpu 2 --concurrency 1 --max-instances 2 --timeout 120`
- The deployed app is pointed at it by `--dart-define=PHOTO_IMPORT_ENDPOINT=...` in
  `.github/workflows/deploy-pages.yml`, **not** by a default in code. That is deliberate: with
  a default in code every test would have an address to reach for.

`deploy/omr/app/` holds Audiveris' jars copied from the local install. **Gitignored** — not
ours to redistribute — so they exist only on this machine. A CI build would not have them.
Restage with `cp -r "/c/Program Files/Audiveris/app" deploy/omr/app`.

**Tesseract.js comes from a CDN, on demand.**
`https://unpkg.com/tesseract.js@7.0.0/dist/tesseract.min.js`, injected as a `<script>` the
first time someone photographs something, pinned to an exact version.

## Decisions made, and why

- **Text OCR in the browser, not on a server.** Measured above: faster, more accurate, free,
  offline, no infrastructure. There is no version of this worth paying to host.
- **Notation on Cloud Run, opt-in per photo.** Audiveris reads pitches at 96.2% but returns
  **zero lyrics** — so it cannot replace the text path, only complement it. Rare and bursty
  usage suits scale-to-zero; a VM idling for a twice-weekly feature does not.
- **The engine is chosen by a checkbox, not guessed.** Only the person holding the camera can
  see what kind of page it is, guessing wrong wastes the slow engine, and the toggle is where
  *press the book flat* gets said.
- **Tesseract.js loaded on demand, not bundled and not in `index.html`.** The engine and the
  Hungarian model are several megabytes and almost every visit opens a song rather than
  photographs one. Putting the files in `web/` would be worse still: Flutter's service worker
  pre-caches what it finds there, so a user who never takes a photo would install them anyway.
  The cost is that the *first* photo on a device needs a network; the path this replaces needed
  one every single time.
- **The photo is scaled to 2048px on the long edge before reading.** That is the size
  everything was measured at, so a phone handing over twelve megapixels is read at a
  resolution already known to be enough, in a time already known to be about a second.
- **The endpoint setting now means the sheet-music service, and only that.** A chord sheet is
  read locally whether or not an address is stored — a stored address must not quietly take
  back a path that measured better. `settingsPhotoImportEndpointHint` says so in all three
  languages.
- **The account's token goes only to the service the build was compiled with.**
  Compared by origin, so moving the path does not quietly stop authenticating.
  This is the fix for the credential leak above, and it is why the build-time
  address is now injectable: a test build carries no `--dart-define`, so without
  a seam the trusted branch would be unreachable from a test.
- **The setup link only points somewhere local.** Private ranges and loopback,
  matched on the literal address — a name is not resolved, because a name
  anybody can register can point anywhere and checking it would be trusting DNS
  with the answer. A public service is typed into Settings, where doing it is
  visible and deliberate.
- **Token precedence: a token typed into Settings wins, otherwise the signed-in account's
  own.** Someone running their own reader has answered the question explicitly and has no
  Supabase session to offer it. Signed out with nothing typed still builds a service and sends
  no header, because blocking it in the app would break a self-hosted reader that wants no
  token — the service refuses it instead, and the app re-words that one 401 into the user's
  own language.
- **Cloud Run over Oracle Always Free.** Oracle wins on cold start (none) and 24GB free, but
  carries A1 capacity risk and account-reclamation risk — the same fragility Robert is
  avoiding elsewhere. Oracle would win *if* text OCR were also server-side (continuous load).
- **Not Anthropic.** The vision-model path is architecturally cheapest but Robert has only a
  company Team subscription, which he cannot and should not build on.
- **Not OMR in Dart.** Neither OMR engine yields lyrics, so it would remove nothing from the
  architecture, and general OMR is research-scale.
- **Auth via Supabase JWKS, fails closed.** The service is publicly reachable because a
  browser calls it, so Google IAM cannot gate it.
- **There is no hard spend cap in GCP.** A $2 budget was created but it *warns only*. The real
  cap is auth plus `max-instances 2` plus `timeout 120`.

## Done — on `claude/v1-polish`, NOT pushed, NOT merged

Listed by subject: this branch has been rebased three times and every SHA changed each time.
`git log --oneline master..HEAD` is the authority.

**App side**
- analyze baseline to zero; photo-import contract; endpoint as a setting; the Photo UI
  (translated en/hu/ro as written); `?photoEndpoint=` setup link + build-time default
- **read H as B natural** — H is B in Hungary, was rejected by tested decision. Accepted
  everywhere chords are read, renamed to B into storage. B still means B natural.
- **lowercase minor chords and the `-7` shorthand** — the songbook prints `em`, and `-7`
  meaning "the chord before me, with a seventh". Both were why chords "went missing".
- **number out of the title, and required** — `147. Isten fénye` splits; Save now needs a
  whole number above zero (a missing one used to store as 0)
- **chords carry to later verses** by line position when only verse 1 has them
- **`PagePreprocessor`** (Dart) — show-through detection and removal, 63ms + 71ms on 3.1MP
- **`PhotoTextBridge`** (Dart) — the whole OCR→ChordPro bridge, 24 tests
- **the browser reading path** — `PageTextRecognizer` (interface + web + stub) and
  `BrowserPhotoImportService`, the last unwritten piece. Verified in a real headless browser
  against the real photo, not only unit-tested.
- **the sheet-music toggle** — routes to Cloud Run instead, and says *press the book flat*
- **the signed-in account's token** goes out as `Authorization: Bearer` — without it the
  service answers 401 — and a 401 is the one failure the app re-words, because the service
  answers in English and the app knows which of three languages is on screen

**Worker / tooling**
- `--easyocr` mode, detector thresholds, deskew, column splitting, show-through suppression,
  `ő` repair, punctuation repair, upload capture (`--save-dir`)
- `tools/fixtures/build.py` + `score.py` — the measurement corpus, in the repo because the
  previous one lived in a temp dir and was deleted mid-session

**Deployment**
- `deploy/omr/` — Audiveris as a headless container, ES256 Supabase auth, 14 tests
- `PHOTO_IMPORT_ENDPOINT` passed by the Pages workflow

## In-flight (uncommitted)

Nothing. Working tree is clean.

## Blocked / Known issues

- **Nobody has photographed a sheet-music page through the deployed app.** Every part of that
  path is tested on its own and the service is measured at 96.2% pitch accuracy, but the
  toggle → Bearer token → Cloud Run → MusicXML → review-screen round trip has never been run
  by a person with a camera. That is the first thing to do after deploying.
- **No real photos of the two remaining songs.** Only `7568` (Mondd ki a dzsungel királya) was
  ever captured, in `tools/photo_debug/`. `7569` (Isten fénye) and `7570` (two-column, Az úr
  irgalma végtelen) are still needed. Robert may photograph them at church.
  **Take fresh photos — do not route through a messenger.** The captured ones came back via a
  chat app at 2048px / 0.026 bytes per pixel / EXIF stripped, which is what destroys `ő` and
  `ű`. The worker now says so when it sees it.
- **A curled page destroys notation reading** — 63 notes drop to 6, because staff detection
  needs straight lines. Tilt is fine (95.5% at 2°, 88.5% at 6.5°+keystone). Curl does *not*
  hurt the text path. The toggle now says this; that instruction is worth more than any code
  in the feature.
- **A native build cannot read a photo's words.** The engine is the browser's, so a non-web
  build says "Photos can only be read in the browser version of Songbook" rather than
  offering a dead button. Songbook is deployed as a PWA, so this is a stated consequence, not
  a regression — but it is the reason to keep deploying as a PWA.
- **Audiveris reports no time signature.** One field for a moderator to set.
- **`--live` has never run.** No API key, by design. The vision-model arm is unmeasured.
- **The legacy HS256 Supabase key is still listed** as a previous key. Once tokens signed with
  it have expired it can be revoked (Settings → JWT Keys). Nothing here depends on it.
- Background processes on this machine get killed periodically; run servers **detached**
  (`Start-Process -WindowStyle Hidden`), not as harness background tasks.

## Remaining work (ordered)

1. **Merge and deploy the app.** CI runs tests + analyze, deploys, tags `build-<n>`.
2. **Photograph a page of each kind through the deployed PWA** — one chord sheet, one page of
   sheet music with the book pressed flat — and confirm the round trip. This is the only part
   of the feature that has never been exercised by a human.
3. **Photograph `7569` and `7570`** and run them through, then tune per song.
4. **The two items above that this branch did not fix** — the approved-song
   edit gap and the HS256 key. Neither is caused by this work; the first gets
   worse the more contributors there are.
5. Optional: a genuine hard spend stop (budget → Pub/Sub → function that unlinks billing).
   Optional: put the OMR call behind a Supabase Edge Function if you ever want the Cloud Run
   URL private rather than merely authenticated.
   Optional: self-host `tesseract.min.js` and `hun.traineddata` on the Pages origin, if
   depending on unpkg ever looks like the wrong trade — it costs a first-photo download either
   way, and the service worker must be kept from pre-caching them.

## Files / commands reference

**App**
- `lib/domain/services/page_text_recognizer.dart` — the reading interface
- `lib/domain/services/page_text_recognizer_web.dart` — Tesseract.js, the canvas, the only
  JS interop in the app
- `lib/domain/services/page_text_recognizer_stub.dart` — the non-web half of the conditional
  import; reports itself unsupported
- `lib/domain/services/browser_photo_import_service.dart` — recognizer + bridge → ChordPro
- `lib/domain/services/photo_text_bridge.dart` — OCR words → ChordPro (the port)
- `lib/domain/services/page_preprocessor.dart` — show-through detection/removal
- `lib/domain/services/chord_sheet_parser.dart` — single source of truth for what a chord is
- `lib/domain/services/chord_carry.dart` — chords onto later verses
- `lib/domain/services/photo_import_service.dart` — the wire contract (90s client timeout)
- `lib/presentation/providers/providers.dart` — `photoTextImportServiceProvider` and
  `photoNotationImportServiceProvider`, one per engine
- `lib/presentation/screens/import/import_song_screen.dart` — `_pickPhoto`, `_accept`,
  `_blockersIn`; the Photo button and the sheet-music checkbox live in the "More ways to add"
  expander
- `tool/preprocess_page.dart` — runs the preprocessor over a raw greyscale file

**Worker / measurement**
- `tools/photo_import_worker.py` — stub / `--easyocr` / `--live`, `--save-dir`
- `tools/fixtures/build.py` — regenerates all ten test pages deterministically
- `tools/fixtures/score.py` — scores the bridge against them and prints real photos
- `tools/photo_debug/` — real uploads land here (`--save-dir`)

**Deployment**
- `deploy/omr/Dockerfile` — Java 25 + Linux JavaCPP natives + PyJWT. Both are non-obvious:
  Audiveris ships class file 69, and it calls `TesseractOCR.identify()` at startup so the
  wrong natives kill it before it looks at the image.
- `deploy/omr/server.py`, `deploy/omr/test_server.py`
- `.github/workflows/deploy-pages.yml` — carries `PHOTO_IMPORT_ENDPOINT`

**Verify**
```bash
cd songbook_app && flutter test        # expect 1020
cd songbook_app && flutter analyze     # expect 0 issues, exit 0
cd tools && python -m unittest discover -p "test_*.py"   # expect 159
cd deploy/omr && python -m unittest discover             # expect 14
python tools/fixtures/build.py && python tools/fixtures/score.py

# The only check that compiles the JS interop. --no-web-resources-cdn is not
# optional: web/index.html sets a Content-Security-Policy that blocks the
# CanvasKit CDN, so a build without it produces an app that does not start.
cd songbook_app && flutter build web --release --no-web-resources-cdn
```

CI runs `flutter analyze --no-fatal-infos`, which downgrades **infos only** — a warning still
fails the deploy.

**Verifying the browser path against a real photo**

Unit tests fake the recognizer, so they cannot catch a broken JS interop. To exercise the real
one, compile a tiny entry point that calls `BrowserPhotoImportService` with
`createPageTextRecognizer()`, serve it beside a photograph, and drive it with Playwright
(installed globally; `NODE_PATH=C:/Users/rober/AppData/Roaming/npm/node_modules`):

```bash
dart compile js --packages=.dart_tool/package_config.json -O1 -o harness.js harness.dart
python -m http.server 8901 --bind 127.0.0.1
node drive.cjs      # page.evaluate(() => window.runOcr('149-raw.png'))
```

The harness used for the numbers above is in the session scratchpad under
`ocrharness/`. Rebuilding it is a ten-minute job and worth it before touching
`page_text_recognizer_web.dart`. Give its page the same
`Content-Security-Policy` meta tag the app uses, or it will prove the OCR works
under a policy the app does not have. Two things it is uniquely good for: a
deliberately wrong integrity hash (the browser must block the script and the
*second* attempt must still fail cleanly), and confirming the language model is
Hungarian.

The release build itself is worth loading headless too — `flutter build web
--release --no-web-resources-cdn`, serve `build/web`, and assert on
`securitypolicyviolation` events plus console errors. That is what caught the
CanvasKit CDN.

## Resume prompt

"""
Continue photo import for Songbook.

Repo: C:\Users\rober\source\repos\songbook-app-worktrees\v1-polish  (branch claude/v1-polish)
Read the full handoff first: <worktree>\HANDOFF-photo-import.md

Done: both engines built, wired, measured, reviewed and hardened. A photographed
chord sheet is read entirely in the browser — Dart preprocessing, Tesseract.js,
Dart bridge — verified headless against the real photo of song 149 at 4/4 chord
rows in about a second. The notation path is live on Cloud Run behind Supabase
ES256 auth, reached by a "this page has sheet music" checkbox that tells the
user to press the book flat and shoot from directly above. Four independent
reviews found a credential leak (a crafted ?photoEndpoint= link could be handed
the user's Supabase access token), three silent failure modes in the browser
reader, and a wrong camera axis in two languages — all fixed here. Master is
merged in. 1020 Flutter tests, 159 Python, 14 deploy, analyze 0, release build
boots with no CSP violations.

Next: (1) fast-forward master and deploy — CI gates the branch first, and the
build must keep --no-web-resources-cdn or the CSP stops the app starting. (2)
Then the thing no test covers: photograph a chord sheet and a flattened
sheet-music page through the deployed PWA and confirm both round trips. (3) Two
pre-existing holes this branch did not touch, both documented in the handoff: an
owner can silently rewrite their own already-approved song, and the legacy HS256
Supabase key is still load-bearing.
"""
