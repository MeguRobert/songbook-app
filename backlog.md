# Backlog

Todo / intent queue for this repo. Each entry is a well-scoped task you (or an agent) can pick up.
For overnight runs, keep entries **self-contained** so an agent doesn't stall mid-task.

## Now

- [x] ~~**Bootstrap the test suite (pulled forward from Phase 12).**~~ **DONE** — the suite is
  683 tests as of build 165, covering pure logic, model round-trips, repositories, providers and
  screen smoke tests. The description below is kept only for the value-order rationale; the
  "zero coverage" premise is long stale.
  <details><summary>original entry</summary>
  The repo has zero real test coverage — the only file is the default
  `test/widget_test.dart` counter template. Every
  autonomous run here has no safety net. Establish `flutter test` as the validation loop and
  build coverage in value order:
  1. **Pure logic first** (highest payoff, easiest): `core/utils/chord_transposer.dart`,
     `domain/services/transposition_service.dart` (transpose is THE core feature — symmetric
     -6..+5 range per decision 01-01), `domain/services/search_service.dart`,
     `data/models/view_config.dart` (two-toggle model + colon-delimited `notation:chords`
     serialization, decisions 02-01), `core/extensions/string_extensions.dart`,
     `core/utils/text_utils.dart`.
  2. **Model (de)serialization**: `data/models/*.dart` json round-trips (song, verse, lyric_line,
     notation, chord_position, favorite).
  3. **Repositories** with `mocktail` (already a dev-dep): favorites/settings/song repos over a
     mocked SharedPreferences / local datasource.
  4. **Providers** (StateNotifier): song, settings, favorites, search, theme.
  5. **Smoke widget tests** for the main screens (song_list, song_view, presentation, settings).
  - **Constraints:** every test written must pass (`flutter test` green) and the app must still
    build — a red suite is worse than none. Don't refactor to Riverpod (that's Phase 12 proper).
    Touch `lib/` only where a genuine testability seam requires it, keep such edits minimal, and
    note each one. Fix/replace the stale default `widget_test.dart`. Target: comprehensive
    coverage of the pure-logic + model layers, meaningful repo/provider tests, screen smoke tests.
    Report the `flutter test --coverage` lcov summary. Log done-but-unvalidated claims in
    `testlog.md`; leave git commits to Robert.
  </details>

## Next

- [ ] **B3a — notation correction editor.** Tap a `NotatedBeat`, change pitch / duration /
  syllable / tie / dot. Seven fields on a flat list, so this is closer to editing a table than
  driving a score editor — and it targets where OMR actually fails. Unblocked: the notation
  classes already carry value equality (`da0b1cf`), so an edited beat compares unequal and
  actually propagates. Deliberately NOT a blank-page score writer; see
  `docs/plans/2026-07-27-song-import-and-editor-design.md`.

## Someday

- [ ] **B3b — photo import (NICE TO HAVE).** Digitise a hymn by photographing it. It is the only
  part of the import work that cannot be done in the app alone. **It no longer decides whether this
  stays a zero-cost static site — that was settled separately on 2026-07-28, when Songbook was
  decided to become a multi-user platform with accounts + moderation on Supabase** (see
  `HANDOFF-platform.md`; the backend schema, RLS policies and a passing 15-assertion security test
  are already built under `supabase/`). Photo import is now one feature of that platform rather than
  the thing forcing the question.

  **The app side is nearly free already.** `file_picker` is in the app and proven (B2), so
  picking a JPEG from the gallery needs no new plugin and no camera permission, and behaves the
  same on web and mobile. Prefer gallery over live capture: retakeable, and phone scanner apps
  already do perspective correction. `_PendingImport` in `import_song_screen.dart` is the
  convergence point — a photo source only has to produce one of those.

  **What is missing is compute**, and it splits in two:

  - *Photo → lyrics + chords.* Achievable, and **proven 2026-07-28**: a vision model read a hymn
    page at 99.8% character similarity with Hungarian diacritics correct, which replaces EasyOCR.
    A ~20-line serverless proxy holds the API key and forwards the image. **Decided: an auth-gated
    Supabase Edge Function**, on the same Supabase project as accounts — Supabase Auth is the gate,
    so only signed-in users can spend the API budget. Verified cost per photo: ~$0.007 on
    Haiku 4.5, ~$0.03 on Sonnet 5 (which also has high-res 2576px vision), ~$0.05 on Opus 5 — at 20
    photos/month, $0.14–$1.08. The key cannot live in the bundle: this is a static PWA on GitHub
    Pages, so a *shipped* key is public (a key the user types in and that is stored locally is not —
    that distinction was previously stated too broadly).
  - *Photo → engraved notation.* Needs an OMR engine. `tools/convert_hymn.py` already does this
    well; do not rebuild it. **Decided 2026-07-28: GitHub Actions `workflow_dispatch`** — free on
    this public repo, latency in minutes, which is fine for a one-off digitisation. It is a
    *maintainer* path, not an in-app button: `workflow_dispatch` cannot be triggered anonymously
    (needs `repo` scope even on a public repo), so the flow is run-workflow → download the `.mxl`
    artifact → open it with the in-app MusicXML importer. Zero new app code. Robert's own PC was
    rejected once Songbook went multi-user: a home box is a single point of failure that degrades a
    feature for *other* users.
    *Verified 2026-07-28 (was "unverified: may need xvfb"):* **Audiveris 5.11 `-batch -export` runs
    fully headless — no X server, no xvfb.** The one landmine is a JNA `libgtk-3.so` load from a
    static initializer, throwing `UnsatisfiedLinkError` (an `Error`, so Audiveris's own
    `catch (Exception)` misses it). Fix with `apt install libgtk-3-0` **or** `-Dsun.java2d.uiScale=1`
    (which short-circuits the guard and needs no GTK at all — better for CI). Official
    `ubuntu22.04`/`ubuntu24.04` x86_64 `.deb` builds exist as of 5.11.0. Audiveris requests the
    *legacy* Tesseract engine, so its in-score OCR no-ops against Ubuntu's LSTM-only traineddata;
    notation export is unaffected.
    *Still open:* whether an OMR engine is needed at all — a vision model may read pitches directly
    at full photo resolution. See Decision 0 in `HANDOFF-platform.md`; blocked on a full-resolution
    hymn page. If an engine is kept, prefer `oemer` (pure Python, no JVM, ARM-friendly, already
    wired as `--engine oemer`) and choose on accuracy alone, since headless deployment is now solved.

  **Where it could run, costed.** Money is NOT the blocker — an earlier note in this repo said
  it was, wrongly. Lambda and Azure Functions both have perpetual free tiers of ~1M invocations
  + 400,000 GB-s/month, which a few photos a week never approaches; Lambda even supports 10 GB
  container images, so PyTorch + a JVM fit, and the only charge is ECR storage at ~$0.10/GB/mo
  (~$0.30/mo for a 3 GB image). The real costs are **cold start** (10–30 s for a large image)
  and **maintaining a Docker build pipeline**.

  | Option | Monthly | Notes |
  |---|---|---|
  | Robert's old always-on x86 PC | ~€1 electricity (10 W × 24 h) | **Rejected 2026-07-28** once multi-user was chosen — a home box degrades a feature for other users, and the paste-a-token-into-Settings trick works for one operator only. Was the right answer while single-user |
  | Oracle Cloud Always Free (4 ARM cores, 24 GB) | $0 | A real always-on box, but ARM — see the Pi caveat. Capacity is famously hard to obtain |
  | Hugging Face Spaces, free CPU (2 vCPU, 16 GB) | $0 | Docker Spaces allow Java. Sleeps when idle. Best zero-cost cloud option |
  | GitHub Actions `workflow_dispatch` | $0 | Free for this public repo; minutes of latency, fine for one-off digitisation |
  | Hetzner CX22 (2 vCPU, 4 GB) | ~€4 | Cheapest paid always-on |
  | AWS t4g.micro / Azure B1s | ~$6 / ~$8–10 | No advantage over the above |

  **Raspberry Pi is the wrong host**, despite looking ideal. Audiveris is Java, so it seems
  portable, but it drives native Tesseract through JNI and official builds are x86-first —
  expect to build from source on ARM64. EasyOCR runs on ARM but slowly (~30–60 s/page, 2 GB+
  RAM). A Pi is fine for the tiny vision proxy; an old i5 with 8 GB is a better pipeline host.

  **Power/network is a real single point of failure, and that is acceptable.** With the server
  down, photo OCR is unavailable and *everything else still works* — this is a PWA with local
  storage, so catalogue, favourites, setlists, paste import and MusicXML import are fully
  offline. Only this one feature degrades.

  **Hosting guesses answered:** GitHub **Pages** cannot do this at all (static files, no
  execution, no secrets) — but GitHub **Actions** can, and is free here. **Supabase** Edge
  Functions are Deno/TypeScript: ideal for the key-holding vision proxy (~500 K invocations/mo
  free), useless for Audiveris or PyTorch. **Firebase** Functions 2nd-gen is Cloud Run
  underneath, so a large Python container is possible with a generous free tier, same cold-start
  tax as Lambda.

  *Free tiers and prices shift — reconfirm before committing.*

  **Rejected:** putting the Python pipeline itself in Azure Functions / Lambda. EasyOCR pulls
  PyTorch (~500 MB with models) and Audiveris needs a JVM, so both exceed Lambda's 250 MB
  unzipped limit and force container images — a Docker build pipeline to maintain, slow cold
  starts and a bill, for something run a handful of times a week. Hugging Face Spaces free tier
  is the better cloud option if one is wanted at all.
