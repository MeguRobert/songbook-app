# Handoff — Songbook as a platform: the infrastructure decisions

_Written 2026-07-28. Decisions 1 and 2 taken 2026-07-28. Uncommitted by design._
_Scope: architecture and hosting decisions only. The shipping local-storage PWA is a separate
stream — see `HANDOFF-v1-pwa.md`. No app feature code has been written for any of this._

## Where we are

Songbook today is a **single-user, zero-cost, offline-first PWA**: a bundled hymnal plus songs
Robert imports himself, all in `SharedPreferences`, served as static files from GitHub Pages, with
no backend, no accounts and no secrets. It works and it is live (build 165).

The question this stream existed to answer is whether — and how — it becomes a **platform**:
multiple users, accounts, server-side storage, moderated contributions, and photo→digitise via
OCR/OMR.

## Decisions taken (2026-07-28) — read this first

| # | Question | Decision |
|---|---|---|
| **2** | Single-user, or accounts + moderation? | **Multi-user platform, on Supabase.** Robert's call, deliberately against this document's earlier "honest default" of single-user. Backend revised from Firebase to Supabase on 2026-07-28 after review — see Decision 2. **Schema, RLS and a passing test are now built.** |
| **1** | Where does the photo pipeline run? | **Split by audience.** User-facing photo→lyrics+chords on an auth-gated Supabase Edge Function holding the vision key. Maintainer-only photo→notation on GitHub Actions *if* an OMR engine survives Decision 0. **Robert's own PC is out of the architecture.** |
| **0** | Is a self-hosted OMR engine needed at all? | **Still open, and it is the only thing still blocking.** Lyrics from a photo are proven; notation is untested at real resolution. Blocked on Robert supplying one full-resolution hymn page. |

Decision 0 was raised after Decisions 1 and 2 were framed, and it can still *delete* part of
Decision 1 — if a vision model reads pitches well enough at phone-photo resolution, no OMR engine
is hosted anywhere and the photo path is one HTTP call. Decision 2 stands regardless.

The three sections below record each in full. Everything else in this document is supporting
evidence.

## What is already established (do not re-litigate)

These conclusions are grounded in code that exists in this repo:

- **The app-side work for photo import is nearly done.** `file_picker` is already a dependency and
  proven working on web (B2 shipped with it). `_PendingImport` in
  `songbook_app/lib/presentation/screens/import/import_song_screen.dart` is a deliberate
  convergence point: a new import source only has to produce one of those. Picking a gallery image →
  POST → parse response → `_PendingImport` is small. Re-verified 2026-07-28: `_PendingImport` is
  declared at :23, with a single `_accept(_PendingImport)` at :92 and two existing producers (paste
  at :105, MusicXML at :151) — a photo source is a third producer. **Note the app lives under
  `songbook_app/`, not the repo root**; paths elsewhere in this doc that omit it are shorthand.
- **Prefer gallery upload over live camera capture.** No camera permission, no new plugin,
  identical on web and mobile, retakeable, and phone scanner apps already do perspective
  correction and contrast. Strictly better input for strictly less work.
- **Photo → engraved notation cannot run in the app.** Audiveris is a JVM desktop application.
  `tools/convert_hymn.py` already does this well (Audiveris or oemer → MusicXML → app JSON,
  EasyOCR with Hungarian for lyrics, validation gate). **Do not rebuild it** — the job is to host
  it, and its MusicXML output re-enters the app through the importer that already exists.
- **Photo → lyrics + chords is the 80% case** and is much cheaper than notation. A vision model
  reads a chord sheet or lyrics page well, and its text output feeds the chord-sheet parser that
  already ships.
- **A *shipped* secret cannot live in the app.** It is a static PWA on GitHub Pages, so a key in the
  bundle is public. Anything needing a key needs a proxy. **Corrected 2026-07-28:** this does *not*
  extend to a secret the user types in at runtime and that is stored in local persistence — that is
  never in the bundle. It mattered only for the single-user design (paste a tunnel URL + token into
  Settings); the chosen multi-user architecture uses Supabase Auth as the gate instead. Recorded so
  the constraint is not over-applied later.
- **Identity is already platform-ready.** `SongId` is `source:ref` (`hymnal:151` / `user:abc`), so
  a server-assigned id is a third source, not a migration. Persisted formats already carry
  versioned upgrade paths. This was the point of Phase A.
- **The old `Songbook` repo is a working reference for accounts + moderation**, and its mistakes
  are documented — chiefly that approval was enforced *only in the UI* while the repository
  streamed every unapproved song to every client. See
  `docs/plans/2026-07-27-old-songbook-migration-analysis.md`.

## Blocked / Known issues

- ~~Everything here is blocked on Robert's decision~~ — **Decisions 1 and 2 are made** (see above).
- **The one remaining blocker is an input only Robert can supply: a full-resolution photo or scan of
  a hymn page**, to finish Decision 0's spike 2. Until then, whether any OMR engine is hosted at all
  is unresolved. Nothing else waits on it — Decision 2's Supabase work is entirely independent.
- ~~Free tiers and prices were not verified~~ — **verified 2026-07-28**, see *Cost, verified* below.
- ~~Unverified technical risk: Audiveris may need `xvfb`~~ — **RESOLVED by running it**, see
  *The Audiveris headless spike* below. It does not need xvfb. This no longer gates any host.
- **User-generated content brings store obligations, and this now applies.** Apple's App Review
  Guidelines cover UGC (§1.2) and require content filtering, a report mechanism, the ability to
  block abusive users, and published contact info; Google Play has an equivalent policy. Confirm
  current text, but treat it as real scope, not paperwork. **Decision 2 chose multi-user, so this is
  live scope, not a hypothetical.**

## Decision 0 — is Audiveris (and the broad stack) needed at all?

Raised by Robert, and it reframes Decision 1. Three runtimes — Flutter, Python, a JVM — is a lot
for one deferred feature. Two facts narrow it, and one option removes it.

**What each tool is actually for.** Audiveris does **OMR**: reads printed staves (noteheads,
rhythms, clefs) into MusicXML. EasyOCR does **text OCR**: the lyrics under the staves. Different
jobs, hence two tools.

**Python's conversion role is already obsolete.** `parse_musicxml()` was ported to Dart this
session (`lib/domain/services/musicxml_importer.dart`), so the app reads MusicXML/`.mxl`
natively. Python is no longer needed to convert anything for the app — only to *run* an OMR
engine and EasyOCR. Its remaining job is desktop maintainer tooling (`song_validator`,
`batch_import`), which is fine to keep.

**`oemer` is already wired in.** `convert_hymn.py` has `run_oemer()` and `--engine
oemer|audiveris`. oemer is **pure Python** deep-learning OMR: pip-installable, no JVM,
containerises easily, far friendlier on ARM. Picking it drops three runtimes to two and makes
the Raspberry Pi / headless-`xvfb` problems disappear. Accuracy is generally below Audiveris on
clean scans — but the code path already exists, so trying it is nearly free.

**Other OMR engines:** `homr` (newer Python, transformer-based, pip-installable); Soundslice has
a commercial sheet-scanning API (paid); PhotoScore / SmartScore / capella-scan are commercial
desktop apps with no API, so irrelevant here. Audiveris keeps the best open-source accuracy;
oemer the best deployability.

**The option worth spiking first: drop OMR entirely.** The stated 80% case is lyrics + chords,
not engraved notation. A vision model reading a gallery photo and returning ChordPro text would:

- replace EasyOCR outright;
- possibly replace Audiveris for a **single-line hymn melody** — these are monophonic staves, not
  orchestral scores, so it may well be adequate. Untested;
- reduce the whole photo path to **one HTTP call and zero self-hosted runtimes**;
- remove the need for a server at all beyond a ~20-line key-holding proxy — which makes the
  Pi-vs-miniPC, always-on-power and `xvfb` questions moot.

That would collapse the platform stack to **Flutter + one API call**, with Python and Java
demoted to desktop maintainer tools.

### Spike 1 result (run 2026-07-28) — lyrics PROVEN, notation inconclusive

Test setup, which is unusually strong: `tools/audiveris_output/zsolt-090.width-800.omr` is a zip
containing `sheet#1/BINARY.png`, Audiveris's own binarised copy of the page. So the page image is
recoverable from the repo, and **ground truth already exists** — `tools/audiveris_output.json` for
the notes, `songs.json` song 90 verse 1 for the lyrics.

A vision model read that image with no access to either reference:

| Target | Score |
|---|---|
| Lyrics | **99.8%** char similarity, **5/6** lines exact |
| Key signature | Bb — correct |
| Structure (6 systems) | correct |
| Hungarian diacritics (í ő é á ö ű) | all correct |
| Exact pitches (68 beats) | **not attempted with confidence** |

The one lyric "miss" is `Te benned` vs `Tebenned`: the engraving prints `Te - ben - ned` with
syllable hyphens, so that is a word-boundary ambiguity, not a misread character.

**Conclusion — lyrics: settled.** This replaces EasyOCR. It got Hungarian orthography and
hyphenation right, which is the part EasyOCR needs post-processing for (see
`convert_hymn.py`'s "fix common OCR confusions" block).

**Conclusion — notation: NOT yet answered.** Rhythm (half vs quarter), the F# accidental, rests
and melodic contour were all readable; exact pitch naming was not confident. **But the test image
is `width-800` — the whole page downscaled to 800px**, roughly 4× less than a phone photo
(3000–4000px). Staff-line position needs ~4px discrimination, so this was tested below the
resolution the real use case would provide. Treat pitch reading as **untested**, not failed.

**To finish spike 2, one thing is needed from Robert: a full-resolution photo or scan of a hymn
page** (phone camera or scanner, no downscaling). Then re-run the same comparison against
`audiveris_output.json`. If pitch accuracy is high, Audiveris AND oemer both become unnecessary
and the photo path is one HTTP call. If not, keep oemer for notes and use the vision model for
lyrics — still dropping the JVM.

**Remaining spikes:**
1. ~~Lyrics from a photo~~ — **done, passed** (above).
2. **Blocked on Robert: supply a full-resolution hymn page.** Then ask for the melody as note
   names / ABC / MusicXML and score against `audiveris_output.json`. A chord-symbol page would
   also be worth testing, since this hymnal page has none — but chord symbols are large text, the
   same class of task as lyrics, so expect them to pass.
3. Only if that disappoints: run `convert_hymn.py --engine oemer` and compare against
   `--engine audiveris` on the same image. Prefer oemer unless the accuracy gap is decisive.

## The Audiveris headless spike (run 2026-07-28) — RESOLVED, xvfb is NOT needed

This was listed above as an unverified risk gating every Linux host. It is now settled by running
it, not by reading docs: three rounds in a bare `ubuntu:24.04` container with no X server, no xvfb,
and `DISPLAY` empty.

**Result: `Audiveris 5.11.0 -batch -export` runs fully headless and exports a valid `.mxl`**
(4381 bytes from the project's own `data/examples/allegretto.png`).

**How this bears on Decision 0.** It removes the *deployability* argument for dropping Audiveris.
Decision 0 favours `oemer` partly because Audiveris is a JVM app with a suspected headless problem —
that problem does not exist. What remains in oemer's favour is genuine but narrower: **two runtimes
instead of three, and ARM support.** The Audiveris-vs-oemer choice is now purely accuracy vs runtime
count, not deployment pain.

**The one Linux landmine, with root cause.** `WellKnowns.enableHiDpiScaling()` JNA-loads
`libgtk-3.so` from a *static initializer* (`WellKnowns.<clinit>` via `Main.<clinit>`), so it fires
before `-batch` is ever parsed. It throws `UnsatisfiedLinkError` — an `Error`, not an `Exception` —
so the surrounding `catch (Exception)` does **not** catch it. Hard crash on a GTK-less box, with a
stack trace that reads like a display problem and is not one. Two independently verified one-line
fixes:

- `apt-get install -y libgtk-3-0` — GTK is needed as a *library* (one HiDPI scale query), never as a
  display; **or**
- set `-Dsun.java2d.uiScale=1`, which hits the guard
  `if (!LINUX || System.getProperty("sun.java2d.uiScale") != null) return;` and skips the GTK load
  entirely. **Preferred for containers and CI** — zero extra packages.

**Two further findings worth keeping:**

- **Official x86 Linux `.deb` builds now exist** — `Audiveris-5.11.0-ubuntu22.04-x86_64.deb` and
  `-ubuntu24.04-x86_64.deb`, released 2026-07-11. The "official builds are x86-first, expect to build
  from source" caveat no longer applies to **x86** Linux. It still applies to **ARM**, so the
  Raspberry Pi / Oracle-ARM verdict below is unchanged — and that remains a real argument for oemer.
- **Audiveris requests the *legacy* Tesseract engine.** Ubuntu's `tesseract-ocr-eng` ships LSTM-only
  traineddata, so Audiveris's in-score text OCR silently no-ops with `No OCR'd lines`
  (`Tesseract (legacy) engine requested, but components are not present`). **Notation export is
  unaffected.** This matters less than it looks, because Decision 0's spike 1 already replaced
  EasyOCR *and* Audiveris text OCR with the vision model for lyrics.
- Minor: the `.deb` postinst exits non-zero in a bare container (desktop/icon-cache trigger) though
  the install is functional — use `|| true` in a Dockerfile.

Repro scripts: `audiveris-headless-spike{,2,3}.sh` in this session's scratchpad.

## Decision 1 — where the photo pipeline runs (DECIDED, with one part contingent on Decision 0)

**Decided: split by audience.** The two photo paths have different audiences and therefore different
availability requirements — that is the insight that resolves this, and it was not in the original
framing.

| Path | Audience | Host | Why |
|---|---|---|---|
| Photo → **lyrics + chords** (the 80% case, and Decision 0's spike 1 proved it works) | **Every signed-in user** | **Supabase Edge Function**, holding the vision-model key | Must be always-on and multi-tenant. Auth-gated by Supabase Auth, which also caps abuse of the API budget: only signed-in users can spend it. Deno/TypeScript is ample for a thin proxy. Output feeds the `ChordSheetParser` that already ships. |
| Photo → **engraved notation** | **Maintainer only (Robert)** | **GitHub Actions `workflow_dispatch`** — *contingent on Decision 0 keeping an OMR engine at all* | $0 forever on a public repo. Availability genuinely does not matter, because only the maintainer digitises engraved hymns. Output `.mxl` opens with the in-app MusicXML importer that already ships, so this needs **zero new app code**. |

**Robert's always-on PC is out of the architecture.** It was the right answer for single-user and is
the wrong answer now, for two reasons: for a multi-user platform it is a single point of failure that
degrades a feature **for other people**, not just for Robert (the "only this one feature degrades"
argument held with one user and does not hold with strangers); and the paste-a-URL-and-token trick
works for exactly one operator and does not generalise to arbitrary users.

**GitHub Actions is an operator path, not an in-app button.**
`POST /repos/{owner}/{repo}/actions/workflows/{id}/dispatches` **cannot be triggered anonymously** —
it needs `repo` scope, even on a public repository (verified against the GitHub REST docs,
2026-07-28). The table below originally listed Actions and the own-PC option as if interchangeable
in-app options; they are not. The Actions flow is: Robert runs the workflow with a photo → downloads
the `.mxl` artifact → opens it in the app. That limitation costs nothing, because this is a
maintainer task by design. Note also that the repo has exactly **one** workflow today,
`.github/workflows/deploy-pages.yml`, so an OMR workflow is a new file — the earlier claim that it
"reuses CI that already exists" was generous.

### Cost, verified (2026-07-28)

Money is **not** the differentiator; an earlier note in this repo said it was and that was wrong.
Now checked against live pricing rather than recalled:

- **GitHub Actions: free and unmetered** on standard runners for public repos — still true after the
  Jan 2026 price cut and the Mar 2026 $0.002/min self-hosted platform charge, from which public repos
  are exempt.
- **Vision proxy, one chord sheet + short prompt:** ~**$0.007/photo** on Haiku 4.5
  (`claude-haiku-4-5`, $1/$5 per MTok); ~**$0.03** on Sonnet 5 (`claude-sonnet-5`, $3/$15, intro
  $2/$10 through 2026-08-31) which also has high-resolution 2576px vision — directly relevant to
  Decision 0's resolution problem; ~$0.05 on Opus 5. At 20 photos/month that is **$0.14–$1.08**.
  Start on Sonnet 5 for Hungarian lyrics and for the pitch spike; Haiku 4.5 is the cheap fallback but
  is standard-resolution only.
- **Hugging Face Spaces** `cpu-basic` (2 vCPU / 16 GB) still free, sleeps after 48h idle — the
  fallback if Firebase is ever rejected.
- **Cloudflare Tunnel** still free, unlimited tunnels, Access free to 50 users, 100 MB request-body
  cap. Not needed by the chosen architecture; kept for the record.

Lambda and Azure Functions both have perpetual free tiers of ~1M invocations + 400,000 GB-s/month,
which a few photos a week never approaches. Lambda supports 10 GB container images, so PyTorch +
a JVM fit, and the only charge is ECR storage at ~$0.10/GB/month (~$0.30/month for a 3 GB image).

The real costs are **cold start** (10–30 s for a large image) and **maintaining a Docker build
pipeline**.

| Option | Monthly | Verdict |
|---|---|---|
| **Robert's old always-on x86 PC** | ~€1 electricity (10 W × 24 h × €0.15/kWh) | **Recommended.** x86 means the Audiveris installer and native Tesseract just work. Wrap `convert_hymn.py` in ~30 lines of FastAPI behind a Cloudflare Tunnel or Tailscale |
| **GitHub Actions `workflow_dispatch`** | $0 | **Recommended fallback.** Free — this repo is public. Minutes of latency, irrelevant for one-off digitisation. Reuses CI that already exists |
| **Hugging Face Spaces** free CPU (2 vCPU, 16 GB) | $0 | Best zero-cost *cloud* option. Docker Spaces permit Java. Sleeps when idle |
| **Oracle Cloud Always Free** (4 ARM cores, 24 GB) | $0 | A genuinely capable always-on box for nothing — but ARM (see below), and capacity is famously hard to obtain |
| **Supabase Edge Functions** | $0 (~500 K inv/mo) | Deno/TypeScript. **Ideal as the key-holding vision proxy**; cannot run Audiveris or PyTorch |
| **Firebase Functions 2nd-gen / Cloud Run** | Generous free tier | Cloud Run underneath, so a large Python container works. Same cold-start tax |
| Hetzner CX22 (2 vCPU, 4 GB) | ~€4 | Cheapest paid always-on |
| AWS t4g.micro / Azure B1s | ~$6 / ~$8–10 | No advantage over the above |
| Lambda / Azure Functions with the ML container | ~$0.30 storage | **Rejected** — cost is fine, complexity is not |

**GitHub Pages cannot do this at all** — static files, no execution, no secrets. GitHub *Actions*
is the right GitHub answer.

**Raspberry Pi is the wrong host**, despite appearing ideal. Audiveris is Java so it looks
portable, but it drives native Tesseract through JNI and official builds are x86-first — expect
to build from source on ARM64. EasyOCR runs on ARM but slowly (~30–60 s/page, 2 GB+ RAM). A Pi is
fine for the tiny vision proxy; **an old i5 with 8 GB is the better pipeline host.**

**The power/network single point of failure is acceptable.** With the server down, photo OCR is
unavailable and *everything else still works* — the PWA is offline-first, so catalogue,
favourites, setlists, paste import and MusicXML import all keep functioning. Only this one
feature degrades. A €50–80 UPS covers outages if desired.

**Superseded:** the earlier "suggested split" put notation on the own PC. The decided split above
puts the proxy on Supabase Edge Functions — the same project as accounts — and notation on GitHub
Actions, so the platform has one vendor rather than two.

## Decision 2 — does this become multi-user at all? (DECIDED: yes)

**Chosen: accounts + moderation, on Supabase.** This document's earlier default was single-user;
Robert chose otherwise and reaffirmed it. Rationale: the goal is a genuinely usable product, and the
old `Songbook` app's real win was that the catalogue grew *without the maintainer* — users upload,
admins approve. Eight bundled songs does not make a hymnal.

**The one cost that is easy to under-price, stated once and then accepted:** moderation is ongoing
human labour, and a queue only works if someone works it. Today there is exactly one contributor
(Robert), so expect the queue to sit empty for a while — the accounts work buys *future*
contribution, not present value. If in six months nobody but Robert has submitted a song, the queue
was scaffolding for a need that did not materialise. That is a deliberate bet, not a hidden cost.

**Backend: Supabase.** Revised from an initial Firebase recommendation on 2026-07-28 after Robert
asked for the reasoning to be laid out properly. The original case for Firebase rested on the
planning docs already assuming it — that is *path dependency*, which is a weak basis for a
foundational choice, since docs are cheap to rewrite and the schema thinking transfers. On the
merits:

1. **Approval enforcement — the deciding factor.** Firestore security rules are **not filters**:
   Firestore evaluates a query against the set of documents it *could* return and fails the
   **entire query** if any would be unreadable. So every client query must mirror the rule
   (`where('status','==','approved')`) forever, in lockstep. Postgres RLS **filters**:
   `select * from songs` simply returns permitted rows. Forgetting a client-side filter
   under-fetches; it cannot leak. On the single most important non-negotiable — the exact defect
   that sank the old app — Supabase is structurally safe rather than dependent on sustained
   discipline.
2. **Hungarian lyric search, verified.** Firestore has no full-text search; it needs Algolia or
   Typesense, a third vendor and a sync pipeline. Postgres does it natively, and `hungarian` was
   confirmed present in `pg_ts_config` on the actual Supabase Postgres image, with working
   stemming (`patak` matches `patakra`). For a hymnal this is a core feature.
3. **Portability.** "Decide once, do not churn" was the stated goal. Supabase is plain Postgres:
   portable, self-hostable, standard SQL. Firestore is proprietary and leaving means a rewrite.
4. **Data shape.** The song payload is deeply nested (verses → measures → beats) and the moderation
   queue wants joins. `jsonb` handles both; Firestore has a 1 MB document cap and no joins.

**What choosing Supabase costs, honestly.** Firestore's offline persistence is genuinely excellent
and free, and Supabase has no equivalent — user-contributed songs need caching into the local layer
the app already has. This is the one real loss, blunted by the app being offline-first already with
a bundled hymnal, so signed-out browsing needs no backend at all. Also: **free Supabase projects
pause after ~1 week of inactivity** (HTTP 540, data retained, manual resume); a few requests a day
prevents it, so this bites before launch, not after. Firebase's counterpart gotcha — Cloud Functions
cannot deploy on the free Spark plan and require a billing card — no longer applies.

The old app's *reference value* is unaffected by this change: what it teaches is "do not enforce
approval in the UI" and "do not put roles in a client-readable document", both platform-neutral.

The sequencing is already designed in
`docs/plans/2026-07-27-old-songbook-migration-analysis.md` (phases C/D/E) and the non-negotiables
are known:

- **Enforce approval server-side, in security rules.** The old app streamed every unapproved song
  to every client and merely hid rows in the UI. This is the single most likely mistake to repeat.
- **Roles in custom claims, not a client-readable document.** The old app let any client read
  `isAdmin`.
- **Submission state is `draft | pending | approved | rejected` + a rejection reason** — not a
  boolean.
- **Signed-out must stay fully functional.** The app works with no account today; that must not
  regress.
- **Moderation is ongoing human labour.** A queue only works if someone works it — accepted above as
  a deliberate bet rather than a blocker.
- **Do not construct one backend read per visible row, per rebuild.** The old app built a
  `FutureBuilder(future: _auth.isAdmin)` *inside* `ListView.builder` (`song_list.dart:68`) — one
  Firestore read per row per rebuild. On Supabase the equivalent mistake is calling `is_admin()`
  per row instead of resolving the role once per session.

~~Backend candidates, if chosen~~ — **decided: Supabase**, for the reasons above. Firebase was the
initial recommendation and was revised; its remaining genuine advantage is Firestore's offline
persistence, noted as the honest cost of this choice. A self-hosted API on the always-on PC is
rejected outright, for the same single-point-of-failure reason that removed that PC from Decision 1.

## Remaining work (ordered)

Decisions 1 and 2 are done, so this is now a build order rather than a decision queue. Items 1 and 2
are independent and can go in either order.

1. **Finish Decision 0's spike 2 — blocked on Robert supplying one full-resolution hymn photo or
   scan.** Ask for the melody as note names / ABC / MusicXML and score it against
   `tools/audiveris_output.json`. Use Sonnet 5 (high-res 2576px vision) — the earlier inconclusive
   result was at `width-800`, ~4× below phone-photo resolution, so pitch reading is untested rather
   than failed. Outcome decides whether **any** OMR engine is hosted:
   - **Pitches read well** → no Audiveris, no oemer, no notation host. The photo path is one HTTP
     call and item 5 disappears.
   - **Pitches read poorly** → keep an engine. Prefer **oemer** (pure Python, no JVM, ARM-friendly,
     already wired as `--engine oemer`); Audiveris only if the accuracy gap is decisive, and note its
     headless deployment is now a solved problem, so choose on accuracy alone.
2. ~~Schema + policies before client code~~ — **DONE 2026-07-28, and passing.** See *Backend state*
   below. This was deliberately built first, because the old app's headline defect was enforcing
   approval only in the UI.
3. ~~Supabase Auth~~ — **DONE 2026-08-01, deployed as build 201.** Sign in, register, password reset,
   email-confirmation notice with resend, and an Account section in Settings. No route guards and no
   redirect-to-sign-in anywhere: accounts are additive, and the section renders nothing when no
   backend is configured. Server errors are mapped to a closed `AuthFailureCode` enum and localized
   in hu/ro/en — `authFailureMessage` has no `default` case, so an unmapped code is a compile error
   rather than a production string reading "Something went wrong". 19 tests.
   Two SDK findings worth keeping: `AuthException.code` is a raw passthrough of the server's
   `error_code` and can carry codes absent from gotrue's own `ErrorCode` enum (`invalid_credentials`
   is one), so the message-text fallback is load-bearing rather than defensive; and holding a session
   is **not** proof of a confirmed address, since Supabase can permit unconfirmed sign-in — reading
   needs no verification, contributing will, so the two are tracked separately.
   **The hu/ro translations were written by Claude and want a native review.**
4. **Smallest end-to-end photo slice, deliberately lyrics + chords only:** gallery image →
   auth-gated Supabase Edge Function → vision model → the existing `ChordSheetParser` →
   `_PendingImport` → the existing review screen. No notation, no moderation queue yet. Validates
   the whole chain on the path already proven by spike 1.
5. **Moderation queue + admin role**, then the submission lifecycle
   (`draft | pending | approved | rejected` + rejection reason).
6. **Notation-from-photo — only if item 1 says an engine is needed.** A new GitHub Actions workflow:
   install the Ubuntu `.deb` plus either `libgtk-3-0` or `-Dsun.java2d.uiScale=1` (or just
   `pip install oemer`, if oemer wins), run `convert_hymn.py`, upload the `.mxl` as an artifact.
   Independent of everything above.

## Backend state — built and passing (2026-07-28)

**The cloud project is live**: `songbook-app`, ref `sjsgrxvebzsuubebbfwx`, `eu-central-1`,
Postgres 17.6. All migrations are pushed and the bundled hymnal is seeded and searchable through
the public API. The Flutter client is **not yet bound to it** — see *What is left* below.

```
package.json                                    supabase CLI 2.111.0 pinned as a devDependency
supabase/config.toml                            created by `supabase init`
supabase/migrations/20260728120000_songs_and_roles.sql   schema, roles, search vector
supabase/migrations/20260728120100_songs_rls.sql         policies + status trigger + grants
supabase/migrations/20260728120200_explicit_privileges.sql  pins the privilege matrix (see below)
supabase/migrations/20260728120300_canonical_hymnal_songs.sql  ownerless hymnal rows + source enum
supabase/migrations/20260728120400_seed_hymnal.sql       the 8 bundled songs, generated
supabase/tests/songs_rls_test.sql               21 assertions, all passing
```

Verified against the live project as `anon`: the 8 canonical songs are readable,
`?search=fts(hungarian).patak` returns song 42, and `user_roles` returns
`401 / 42501 permission denied`. That 401 matters — an empty `200 []` would have been
indistinguishable from a table that simply had no rows.

**A local/cloud asymmetry that cost an hour and will catch the next person.** A freshly provisioned
cloud project carries `ALTER DEFAULT PRIVILEGES` for schema `public`, so every new table is granted
to `anon`/`authenticated` automatically. The local CLI stack does **not**. So `user_roles`, which was
protected locally by having no grant at all, was granted in production and protected only by
RLS-with-zero-policies. Nothing leaked, but one layer was missing and the deployment was
unverifiable. Migration `…120200` now revokes everything and grants back explicitly, and also flips
the schema default so the *next* table added is unreachable until its access is declared on purpose.

Commands (Docker must be running):

```
npx supabase start          # boots local stack, applies migrations
npx supabase db reset       # re-applies migrations from scratch
npx supabase test db        # runs the RLS test  -> currently 21/21 PASS
npx supabase stop           # frees the containers
```

**Schema shape.** The song payload is `jsonb`, not normalised — the Dart models in
`songbook_app/lib/data/models/` stay the schema of record. Columns are promoted out of the payload
only where RLS or a query needs them: `owner_id`, `status`, `title`, `number`, `book`, `tags`, and a
generated `search` tsvector. `status` is the four-state enum plus `rejection_reason`, never a boolean.

**Three findings that only surfaced by running it** — all fixed, all worth not rediscovering:

1. **RLS and `GRANT` are independent layers and both are required.** The first version enabled RLS
   but issued no grants, and every query failed with `permission denied for table songs`. The
   inverse is the dangerous one: `GRANT` without RLS reads every row. `user_roles` deliberately has
   *neither* — no grant at all, reachable only through the `security definer` `is_admin()`.
2. **RLS cannot express the status state machine.** A policy cannot compare OLD to NEW — `using`
   sees the existing row, `with check` sees the proposed one, neither sees both — so a policy can
   never say "the owner may edit this song but may not set it to approved". A `before update`
   trigger does that half. This is the mechanism that actually prevents self-approval.
3. **A generated column needs an `IMMUTABLE` expression**, and `array_to_string` is `STABLE`, which
   fails with `SQLSTATE 42P17`. Use `array_to_tsvector`. Also, `to_tsvector('hungarian', payload)`
   over the whole document indexes note pitches and durations as noise, so the vector is built from
   targeted jsonpaths (`$.**.text`, `$.**.syllable`) instead.

## What is left, and the one design decision inside it

The client is still reading only `assets/data/songs.json`. Binding it to the API is the next task,
and it carries a decision that must not be made by accident:

**Do not delete the bundled asset.** Robert asked to "migrate all the data from embedded in the
client side", and taken literally that regresses a hard requirement — the bundle is *why* the app
works offline and signed-out with no backend, and a free-tier project pauses after a week idle. A
songbook that needs signal in a church is worse than one that does not. The intended shape is
therefore **additive**:

- `LocalDataSource.loadSongs()` (reads the asset) stays as the offline baseline.
- A new remote datasource fetches approved songs from Supabase.
- `SongRepository.getAllSongs()` merges them, server winning on conflicts by `SongId`, and falls
  back silently to the bundle when the network or the project is unavailable.

`SongRepository` is already the right seam — it is a thin wrapper over `LocalDataSource`, and
`UserSongRepository` separately handles local user songs, so nothing else needs to change.

**What only Robert can do:**

1. Grant the first admin, since `user_roles` is deliberately not client-writable. A user must exist
   first (dashboard → Authentication → Add user), then in the SQL editor:
   `insert into public.user_roles (user_id, role) values ('<your-auth-uid>', 'admin');`
2. Decide whether signed-out visitors should read the approved catalogue. The policy currently
   **allows** it, on the grounds that a public hymnal has nothing to hide and "signed-out stays
   functional" is a hard requirement. Say so if you want it restricted to signed-in users.
3. Confirm the bundled asset stays (recommended) or is deleted (regresses offline use).

## Files / commands reference

- `backlog.md` → *Someday → B3b* holds the same costing in-repo, so it survives without this file
- `docs/plans/2026-07-27-song-import-and-editor-design.md` — why photo splits in two, and the
  MusicXML SATB reduction rule (non-melody voices are retained, so choral support later does not
  mean re-importing)
- `docs/plans/2026-07-27-old-songbook-migration-analysis.md` — accounts/moderation design, and the
  old app's defects not to repeat
- `tools/convert_hymn.py` — the pipeline to host, **not** to rewrite. Note the hardcoded
  `C:/Program Files/Audiveris/Audiveris.exe` in `run_audiveris()`, and that its `songs.json`
  auto-detection expects `songbook_app/assets/data/songs.json`. A service wrapper wants
  `--no-update --output`, since the script otherwise writes the bundled asset and prints prose to
  stdout.
- `tools/audiveris_output/zsolt-090.width-800.mxl` — real fixture; the in-app importer reproduces
  `tools/audiveris_output.json` from it exactly. The sibling `.omr` is a zip containing
  `sheet#1/BINARY.png`, which is how spike 1 recovered a page image from the repo.
- `songbook_app/lib/presentation/screens/import/import_song_screen.dart` — `_PendingImport` (:23),
  `_accept()` (:92), the integration point
- `songbook_app/lib/domain/services/musicxml_importer.dart` — the Dart MusicXML/`.mxl` reader that
  made Python's conversion role obsolete
- Repo: `C:\Users\rober\source\repos\songbook-app`, branch `master`

## Resume prompt

```
Songbook platform build-out. The infrastructure decisions are MADE — read
C:\Users\rober\source\repos\songbook-app\HANDOFF-platform.md and do not re-open them.
Do not touch the V1 PWA stream (that is HANDOFF-v1-pwa.md).

Repo: C:\Users\rober\source\repos\songbook-app (branch master). The Flutter app is under
songbook_app/, not the repo root.

DECIDED 2026-07-28:
- Songbook becomes multi-user with accounts + moderation, on SUPABASE (Postgres + RLS + Auth).
  Chosen deliberately against the doc's earlier single-user default. Backend was briefly recorded as
  Firebase and then revised: Firestore rules are NOT filters (a query that could return an
  unreadable doc fails entirely, so client queries must mirror the rules forever), whereas Postgres
  RLS filters and cannot leak. Plus native Hungarian full-text search and no lock-in. UGC store
  obligations (Apple 1.2 / Play equivalent) are now live scope.
- The photo pipeline splits by audience: photo -> lyrics+chords is user-facing on an auth-gated
  Supabase Edge Function holding the vision key (~$0.03/photo on Sonnet 5); photo -> engraved
  notation is maintainer-only on GitHub Actions workflow_dispatch, whose .mxl artifact opens with
  the in-app MusicXML importer that already ships. Robert's own PC is deliberately NOT in the
  architecture (single point of failure affecting other users once it is multi-user).

ALREADY BUILT AND PASSING: supabase/migrations/ (songs + user_roles + profiles, RLS policies, and a
status state-machine trigger) and supabase/tests/songs_rls_test.sql, 15/15 green via
`npx supabase test db`. Read the "Backend state" section before touching any of it — especially the
three gotchas: RLS and GRANT are separate layers and both are needed; RLS cannot express the status
state machine so a trigger does it; generated columns need IMMUTABLE expressions.
- GitHub Actions cannot be triggered from the app: workflow_dispatch needs repo scope, there is no
  anonymous trigger even on a public repo. That is fine — it is an operator path by design.

RESOLVED: the Audiveris headless question, by actually running it. `-batch -export` works with no X
server and no xvfb. The only landmine is a JNA libgtk-3.so load from a static initializer that throws
UnsatisfiedLinkError (an Error, so the catch(Exception) misses it); fix with either
`apt install libgtk-3-0` or `-Dsun.java2d.uiScale=1`. Official Ubuntu 22.04/24.04 x86_64 .debs exist
as of 5.11.0. Audiveris wants LEGACY tesseract traineddata, so its in-score OCR no-ops on Ubuntu's
LSTM-only package — notation is unaffected, and lyrics come from the vision model anyway.

STILL OPEN — Decision 0, and it is blocked on an input only Robert can give: one full-resolution
hymn photo or scan. Lyrics from a photo are PROVEN (99.8% char similarity, Hungarian diacritics
correct). Pitch reading is UNTESTED, not failed — the earlier test image was width-800, ~4x below
phone-photo resolution. If pitches read well at full resolution, no OMR engine is hosted anywhere and
the notation host question disappears; if not, prefer oemer (pure Python, no JVM, already wired as
--engine oemer) over Audiveris, choosing on accuracy alone now that headless deployment is solved.

NEXT: either finish that spike (if Robert supplies the photo), or build item 3 — Supabase Auth
(email/password, verification gate, password reset, the old app's error-code -> localized-message
mapping), with signed-out staying fully functional. The RLS policy already lets anon read the
approved catalogue, so nothing in the backend blocks that. Robert must create the cloud project and
`supabase link` before anything can be pushed; the local stack works without it.
```
