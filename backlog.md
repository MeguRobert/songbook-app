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

- [ ] **B3b — photo import (NICE TO HAVE).** Digitise a hymn by photographing it. Deferred
  because it is the only part of the import work that cannot be done in the app alone, and it
  decides whether this stays a zero-cost static site.

  **The app side is nearly free already.** `file_picker` is in the app and proven (B2), so
  picking a JPEG from the gallery needs no new plugin and no camera permission, and behaves the
  same on web and mobile. Prefer gallery over live capture: retakeable, and phone scanner apps
  already do perspective correction. `_PendingImport` in `import_song_screen.dart` is the
  convergence point — a photo source only has to produce one of those.

  **What is missing is compute**, and it splits in two:

  - *Photo → lyrics + chords.* Achievable. Cheapest route is a ~20-line serverless proxy whose
    only job is holding an API key and forwarding the image to a vision model. Fast cold start,
    pennies at this volume. The key cannot live in the bundle: this is a static PWA on GitHub
    Pages, so a shipped key is public.
  - *Photo → engraved notation.* Needs Audiveris, a JVM desktop app that cannot run in Flutter
    on web or mobile. `tools/convert_hymn.py` already does this well; do not rebuild it.
    Either (a) run it on a **GitHub Actions** `workflow_dispatch` — free, since this repo is
    public, latency in minutes, which is fine for a one-off digitisation — or (b) wrap it in
    ~30 lines of FastAPI on Robert's own PC behind a Cloudflare Tunnel / Tailscale.
    *Unverified:* Audiveris has a `-batch` mode but is a JVM GUI app; a headless runner may
    need `xvfb`. Spike that before committing to (a).

  **Rejected:** putting the Python pipeline itself in Azure Functions / Lambda. EasyOCR pulls
  PyTorch (~500 MB with models) and Audiveris needs a JVM, so both exceed Lambda's 250 MB
  unzipped limit and force container images — a Docker build pipeline to maintain, slow cold
  starts and a bill, for something run a handful of times a week. Hugging Face Spaces free tier
  is the better cloud option if one is wanted at all.
