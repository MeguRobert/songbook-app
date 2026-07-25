# Backlog

Todo / intent queue for this repo. Each entry is a well-scoped task you (or an agent) can pick up.
For overnight runs, keep entries **self-contained** so an agent doesn't stall mid-task.

## Now

- [ ] **Bootstrap the test suite (pulled forward from Phase 12).** The repo has zero real test
  coverage — the only file is the default `test/widget_test.dart` counter template. Every
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

## Next

## Someday
