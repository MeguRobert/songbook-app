# Integration Decisions — 2026-07-25 (autonomous run)

Every decision I made without asking, so you can overrule any of them. Ordered by
significance. Each says **what** I decided, **why**, and **how to undo**.

Context: Phases 5–9 existed as a stacked chain of unattended overnight branches
(`claude/phase-5…9`), all branched off `master` *before* Phase 4's gap closure, and
none of it was merged. I integrated them into `master` one phase at a time.

---

## A. Decisions that changed shipped behaviour

### A1. Restored the same-query short-circuit in search (a real regression fix)
- **Decided:** Re-added `if (query == state.query) return;` to `SearchNotifier.search`.
- **Why:** Phase 9's refactor to a shared `_recompute()` dropped it, so repeating an
  identical query re-ran the whole search and built a new state object. This broke the
  existing test `'repeating the same query is a no-op'` (search_provider_test.dart:90) —
  the merge surfaced a genuine regression, not a stale test. Tag filters don't need that
  path: `toggleTag`/`setTags`/`clearTags` recompute on their own.
- **Alternative I rejected:** deleting the test's identity assertion to match the new
  behaviour. That would have silently accepted redundant work on every keystroke.
- **Undo:** revert commit `0d2262b`.

### A2. Combined Phase 6's a11y label with Phase 4's zoom in the sheet-music renderer
- **Decided:** Kept **both** — the canvas is wrapped in Phase 6's
  `Semantics(label: 'Sheet music notation for …', image: true)` **and** keeps Phase 4's
  `textScale`-scaled `SizedBox` + `canvas.scale`.
- **Why:** Phase 6 (accessibility) and Phase 4 (smooth zoom) edited the same lines for
  unrelated reasons; taking either side alone would have silently dropped a shipped
  feature (screen-reader support, or smooth notation zoom).
- **Verified:** Ctrl+wheel zoom still scales without re-wrapping, header stays centred.
- **Undo:** see `sheet_music_renderer.dart` in commit `c131199`.

### A3. Phase 4's verified UI wins over the overnight branches' version of it
- **Decided:** Where the phase branches carried their own older copy of Phase-4-era code,
  master's post-gap-closure version won.
- **Why:** The overnight branches independently removed the Custom view chip too
  (convergent change), but master's version additionally has the transpose
  `Visibility(maintainSize:)` fix and the smooth-zoom renderer — all of which you
  verified by hand. Master was a strict superset.
- **Undo:** nothing to undo unless you want the older variants back.

### A4. Kept master's `04-VERIFICATION.md`, discarded the branches' copy
- **Decided:** Kept the 2026-07-21 post-gap-closure report over the 2026-02-14 one.
- **Why:** The newer report explicitly documents the 4 UAT gaps and supersedes the older
  one, which was the pre-gap-closure verification.

---

## B. Repo / infrastructure decisions

### B1. Committed the 25 untracked test files
- **Decided:** Committed them (3,339 lines, `1c0cf1f`) rather than leaving them on disk.
- **Why:** 336 of 364 tests were untracked — a fresh clone and the new CI saw almost
  none of the suite, and one `git clean` would have destroyed it.
- **Note:** this means my earlier "364 tests pass" claims rested partly on files that
  weren't in version control.

### B2. Gitignored ad-hoc screenshots, `nul`, and `__pycache__`
- **Decided:** Added `/*.png` (root only), `/nul`, `__pycache__/`, `*.pyc`.
- **Why:** 66 stray PNGs plus a `nul` artifact were drowning `git status`. Root-only
  pattern, so `songbook_app/assets/` art is unaffected.
- **Undo:** remove those lines from `.gitignore`.

### B3. Fixed the CI Flutter version (deploy was broken)
- **Decided:** Pinned the Pages workflow to Flutter `3.35.2` (was `3.32.0`).
- **Why:** `3.32.0` bundles Dart 3.8.0 but `pubspec.yaml` requires `^3.9.0`, so
  `flutter pub get` failed version-solving. The workflow had never run on master, so this
  was latent; my first push exposed it. 3.35.2 matches the local env the suite is verified against.

### B4. Switched GitHub Pages source to "GitHub Actions" *(you approved this one)*
- Live site now serves the current master build; it had been stale since 2026-03-23.

### B5. Allowed `master` to deploy to the `github-pages` environment
- **Decided:** Added `master` to the environment's deployment-branch policy.
- **Why:** The environment only permitted `gh-pages`, so the deploy job failed instantly
  with "Branch master is not allowed to deploy".
- **⚠️ Related thing you should look at:** the repo's **default branch on GitHub is
  `gh-pages`**, not `master` — so clones and PRs default to the built-site branch. That
  looks unintended. I did **not** change it (it affects PR targets and everyone cloning).

### B6. Merge commits, not rebase
- **Decided:** `git merge --no-ff` per phase, sequentially (5 → 6 → 7 → 8 → 9).
- **Why:** Preserves the overnight history and each phase's provenance, and lets the merge
  base advance so the same Phase-4 conflicts don't re-fight on every subsequent phase.
  Rebasing 44 commits would have rewritten authorship dates and risked repeated conflicts.

### B7. STATE.md conflict handling
- **Decided:** For phases 7–9 I took the incoming branch's position/session lines during
  the merge, then rewrote the position section authoritatively at the end.
- **Why:** The same three regions conflicted on every merge with no new information;
  hand-merging them five times would have been churn. Decisions lists are additive and
  auto-merged cleanly, so nothing was lost.

---

## C. Things I deliberately did NOT do (yours to decide)

### C1. The 3 POCs — NOT shipped
`POC-IDEAS-REPORT-2026-06-13.md` says explicitly *"You decide what ships"*, so I left all
three on their branches. They're pushed and intact. Mergeability onto current master:

| POC | Branch | Merges onto master? |
|---|---|---|
| Capo helper | `claude/poc-capo-helper` | ✅ clean, 0 conflicts |
| Auto-scroll | `claude/poc-autoscroll` | ⚠️ 2 conflicts (`song_view_screen.dart`, `chord_view.dart`) |
| Recently-viewed | `claude/poc-recent-songs` | ⚠️ 2 conflicts (`local_datasource.dart`, `providers.dart`) |

The two conflicting ones collide with Phase 8/9 work that landed after they were branched.
Say the word and I'll integrate any subset.

### C2. Default branch left as `gh-pages` (see B5)

### C3. Untracked docs left alone
`POC-IDEAS-REPORT-2026-06-13.md`, `backlog.md`, `testlog.md` are still untracked. They're
your notes — I didn't commit or ignore them.

### C4. No hands-on UAT
Phases 5, 6, 8, 9 have never been exercised by hand. I smoke-tested the merged app in a
browser (song list, books, setlists, song view, notation zoom) but that is not UAT.
**Phase 4 passed its automated verifier 5/5 and still needed 4 gap fixes once you clicked
through it** — so treat these as provisional.

### C5. `flutter test` still not a CI gate
The workflow builds and deploys but doesn't run tests. Now that the suite is tracked this
is worth adding; it's a policy call (should a failing test block the deploy?), so I left it.

---

## Verification status at end of run

- **444 Dart tests** pass (was 364 before Phase 5; +80 from phases 5–9).
- **37 Python tests** pass (import-pipeline tooling, `tools/`).
- `flutter analyze`: clean — only the 8 pre-existing `RadioListTile` deprecation infos.
- Merged app smoke-tested in browser: song list with all 4 app-bar entry points, book
  browser (All Songs 8 / Zsoltárok 3 / Dicséretek 5), setlists empty state, song view with
  notation, and Ctrl+wheel zoom still smooth and non-re-wrapping.
- All merges pushed to `origin/master`; Pages deploy green and live.
