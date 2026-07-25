# Songbook — POC Ideas & Build Report (2026-06-13, overnight, unattended)

> Robert: this is an exploration + 3 built POCs for you to evaluate and cherry-pick. Nothing was
> pushed; everything is local commits on isolated `claude/poc-*` branches. **You decide what ships.**
> Walk the **Decisions for the morning** section ONE AT A TIME (don't peek at the count).
>
> _This report is kept in-repo at the root. The requested copy to `~/.claude/overnight/` was blocked
> by the sandbox (writes outside the repo are denied in unattended runs) — same as prior overnight
> sessions. The root copy is canonical. It's untracked, so it shows up on whatever branch you have
> checked out._

---

## How this was produced

I read the `lib/` tree (models → repos → services → providers → screens → widgets), the `.planning/`
roadmap/decisions, and the bundled `assets/data/songs.json` (8 songs currently, all 4/4, every song
has `originalKey` + `timeSignature`). I respected the architecture decisions in PROJECT.md
(local-first, Riverpod, GoRouter, SharedPreferences/JSON; clean data→domain→presentation layering)
and the out-of-scope list.

**Note on branch base.** The hard rule said to branch each POC off `claude/phase-8-setlists`. Since
then Phase 9 (Tags & Search) was completed on `claude/phase-9-tags-search`. I honored the rule
literally and branched all three POCs off **`claude/phase-8-setlists`** — this also keeps them cleanly
independent of the tags/search work so you can cherry-pick without entanglement. None of the three
POCs touch tags/search code, so they rebase onto Phase 9 trivially if you prefer.

---

## Phase 1 — Ranked idea list

Ranked by **value-to-effort** for a local-first worship songbook. Effort: S ≈ <½ day, M ≈ 1–2 days,
L ≈ 3+ days to *finish* (POCs here are vertical slices, not finished features).

### 1. Auto-scroll / hands-free scrolling during performance — **BUILT (POC 1)**
- **Value (HIGH):** The #1 live-performance pain. A musician with both hands on a guitar/keyboard
  can't swipe. Smooth auto-scroll with a speed control + play/pause lets them get through a long
  song hands-free. This is the marquee "worship app" feature.
- **Effort:** M. Requires lifting a `ScrollController` out of `ChordView`'s internal
  `SingleChildScrollView`, a small scroll-driver (Ticker/animation), a Riverpod state object, and a
  speed slider in the controls sheet. Per-song speed memory via SharedPreferences.
- **Files:** `chord_view.dart` (accept external controller), `song_view_screen.dart`,
  new `autoscroll_provider.dart`, `song_controls_sheet.dart`, `settings_repository.dart` (per-song speed).
- **Risk:** Medium — `InteractiveViewer` + external `ScrollController` interaction; sheet-music view
  is a separate widget so v1 scopes to chord/lyrics view. Mitigated by scoping cleanly.

### 2. Recently-viewed + "continue where you left off" — **BUILT (POC 2)**
- **Value (HIGH):** Tiny feature, daily payoff. Jump straight back to the song you were on; a
  "Recent" rail on Home removes re-searching. Worship leaders revisit the same ~20 songs constantly.
- **Effort:** S. A timestamped recents list in SharedPreferences, recorded on `openSong`, surfaced as
  a horizontal rail on the song list + a "Continue" affordance.
- **Files:** `local_datasource.dart` (recents blob), new `recents_repository.dart` +
  `recents_provider.dart`, hook in `song_view_screen.dart`, rail in `song_list_screen.dart`.
- **Risk:** Low. Pure additive persistence; mirrors the existing favorites pattern exactly.

### 3. Capo helper ("play with capo N in shape X") — **BUILT (POC 3)**
- **Value (HIGH for the guitar half of the room):** Guitarists think in *shapes*, not absolute keys.
  Given the song's sounding key, the app suggests "Capo 3 → play G shapes" etc. Complements the
  existing transposition rather than competing with it. Big delight, pure logic.
- **Effort:** S. New pure method on a service over `ChordTransposer` (semitone math already exists),
  a small expandable card in the controls sheet. No new deps, no persistence required.
- **Files:** new `capo_service.dart` (or extend `TranspositionService`), `song_controls_sheet.dart`.
- **Risk:** Low. Pure function, fully unit-testable. *Note:* PROJECT.md lists "guitar tablature /
  chord diagrams" as out of scope — a capo *helper* is text-only key/shape math, NOT diagrams, so it
  stays inside scope. Flagged so you can confirm.

### 4. Full-text lyric search + first-line matching + highlighting — *not built*
- **Value (HIGH):** Search today matches number/title/reference only. Worship leaders search by a
  remembered lyric line ("...mert hű az Úr..."). First-line indexing + body search + match highlight
  is high value.
- **Effort:** M. Extend `SearchService` to scan verse text (diacritic-normalized already exists),
  return match snippets, highlight in `search_screen.dart`. Watch performance at 1000+ songs.
- **Files:** `search_service.dart`, `search_provider.dart`, `search_screen.dart`.
- **Risk:** Medium — perf at scale; needs snippet/highlight UI. Strong #4; cut only because the top 3
  are higher value-to-effort and more demo-able.

### 5. Metronome / tap-tempo + per-song tempo memory — *not built*
- **Value (MEDIUM):** Count-in / tempo reference is useful, but worship bands often have a drummer.
  Visual metronome (no audio dep) + tap-tempo + per-song BPM memory is a judgeable slice.
- **Effort:** M. `Ticker`-based visual beat, tap-tempo averaging, BPM persistence. Audio click would
  add a dependency (risk to offline/build) — visual-only keeps it dependency-free.
- **Files:** new `metronome_service.dart`/provider, `song_controls_sheet.dart`, `settings_repository.dart`.
- **Risk:** Medium — Ticker lifecycle; audio later is a dependency decision.

### 6. Quick-jump verse/section chips — *not built*
- **Value (MEDIUM):** Chips (V1 V2 Chorus) that scroll-to-section help in long songs. Pairs naturally
  with POC 1 (shares the `ScrollController` + section offsets).
- **Effort:** S–M. Needs `GlobalKey`/offset per verse and section labels in the data (verses are
  numbered today; "chorus" labeling would need a data field).
- **Files:** `chord_view.dart`, `song_view_screen.dart`, possibly `verse.dart` (section label).
- **Risk:** Low–Medium. Best shipped *with* auto-scroll.

### 7. Setlist export / share as plain text (and print) — *not built*
- **Value (MEDIUM):** Setlists exist (Phase 8). Export/share a service order as text (or copy to
  clipboard) so it lands in a band chat. Print/PDF is the bigger version.
- **Effort:** S (clipboard/text share) → M (PDF). `share_plus` is a new dependency; clipboard copy is
  dependency-free and keeps it offline-safe.
- **Files:** `setlist_detail_screen.dart`, small formatter util.
- **Risk:** Low for text/clipboard; Medium if PDF/`share_plus` is added.

### 8. Stage-lighting font/contrast presets — *not built*
- **Value (MEDIUM):** One-tap "Stage" preset (max contrast + large text) for dark-stage readability,
  alongside Day/Night. Builds on existing text-scale + theme.
- **Effort:** S. Preset bundle applied to theme + text scale.
- **Files:** `app_theme.dart`/theme files, `settings_screen.dart`, `settings_repository.dart`.
- **Risk:** Low.

### 9. Multi-select + batch add-to-setlist from the song list — *not built*
- **Value (MEDIUM):** Building a service order is faster with multi-select than opening each song.
- **Effort:** M. Selection mode on `song_list_screen.dart` + batch op on `SetlistRepository`.
- **Files:** `song_list_screen.dart`, `setlist_provider.dart`, `setlist_repository.dart`.
- **Risk:** Medium — selection-mode UX state.

### 10. Chord diagram popovers (guitar/piano) — *not built (OUT OF SCOPE)*
- **Value (HIGH) but explicitly excluded:** PROJECT.md "Out of Scope" says no chord diagrams / tab
  ("target audience reads standard notation + chord symbols"). Listed for completeness — would need a
  scope decision before building. The capo helper (POC 3) captures much of the guitarist value while
  staying in scope.

---

## Phase 2 — The 3 built POCs

Picked the three highest value-to-effort ideas that are **diverse** (performance UX / navigation+
persistence / music-theory helper), **independently judgeable**, and **low-conflict** (each touches
different files). Details below are filled after building.

### POC 1 — Auto-scroll  (branch `claude/poc-autoscroll`, see `POC-autoscroll.md`)
- **What works:** App-bar ▶/⏸ play/pause starts smooth, continuous hands-free scrolling of the
  chord/lyrics view; a speed slider (12–120 px/s) lives in the controls-sheet AUTO-SCROLL section;
  speed is **persisted per song**; scrolling **auto-stops** at the song's end.
- **What's stubbed:** sheet-music view and presentation mode aren't wired to auto-scroll yet (the play
  control is hidden in sheet-music mode); speed units are raw px/s; no BPM-derived "smart speed."
- **Verification:** `flutter analyze` clean; 5 new unit tests (state, clamp, per-song persistence);
  full suite 58 passing. Scroll-frame math is widget-level, not unit-tested.
- **Evaluate by:** Open song #1, tap the ▶ play-circle in the app bar → watch it scroll; open the tune
  FAB → AUTO-SCROLL → drag the speed slider; reopen the song to confirm the speed is remembered.

### POC 2 — Recently-viewed + Continue  (branch `claude/poc-recent-songs`, see `POC-recent-songs.md`)
- **What works:** Opening any song records it (dedup, most-recent-first, capped at 20). A **Recently
  viewed** rail sits atop the Home list; the first card is highlighted as **Continue · #N**. A Clear
  button empties it. Persists across restarts.
- **What's stubbed:** no relative-time labels ("2h ago"); Home-only (no History screen / disable
  toggle); the number→Song resolution provider isn't unit-tested (asset not loaded in test harness),
  though ordering/dedup/cap is.
- **Verification:** `flutter analyze` clean; 8 new unit tests (repository ordering/dedup/cap/clear/
  persistence + notifier); full suite 61 passing.
- **Evaluate by:** Fresh launch → open #1, #42, #7 (back out each time) → Home now shows the rail with
  *Continue · #7* highlighted; reopen #1 → it jumps to front (no dup); relaunch → rail persists.

### POC 3 — Capo helper  (branch `claude/poc-capo-helper`, see `POC-capo-helper.md`)
- **What works:** A **CAPO** section in the controls sheet shows the recommended capo fret + open-chord
  shape for the current sounding key (e.g. *Capo 1 · play A shapes (sounds Bb)*), with alternatives as
  chips. Updates **live as you transpose**. Handles major (CAGED) and minor (Em/Am/Dm) keys.
- **What's stubbed:** text-only by design (no fretboard diagrams — see scope note below); no
  "transpose to nearest open key" shortcut; fixed shape set; shown only in the controls sheet.
- **Verification:** `flutter analyze` clean; 7 new unit tests (G/Bb/minor frets, sort, maxFret, invalid
  key, labels) — pure logic fully covered; full suite 60 passing.
- **Evaluate by:** Open a song in Bb/Eb → tune FAB → CAPO section shows the recommended low capo; tap
  Transpose ± and watch the suggestion track the new key; a song in G shows "No capo needed".
- **⚠ Scope flag:** PROJECT.md lists guitar *diagrams/tab* as out of scope. This is text key/shape math
  only (no diagrams), so it stays inside scope — but please confirm that reading before shipping.

---

## Decisions for the morning

Walk these **one at a time** — read a block, decide ship / iterate / drop, then move to the next. Each
POC is on its own branch off Phase 8 and is independent of the others and of Phase 9 (tags/search).

> **First, the same setup for each:** `git switch <branch>`, then `cd songbook_app && flutter run`
> (Windows desktop or Chrome is fine). Each branch already passes `flutter analyze` and its tests.

---

### Decision 1

**Try this first (don't read ahead):** `git switch claude/poc-autoscroll`, run the app, open song #1,
and tap the **▶ play-circle** in the app bar. Watch it scroll hands-free. Then open the **tune** FAB →
**AUTO-SCROLL** → drag the speed slider. Back out and reopen the song to confirm the speed stuck.

- **What you're judging:** is smooth hands-free scrolling at a remembered per-song speed worth having
  during performance? Is the app-bar toggle the right entry point, or should it be a bigger on-screen
  control / a foot-pedal-friendly target?
- **Ship** → finish: wire it into **presentation mode** (the real performance surface) and the
  sheet-music view; calibrate speed to "lines/min." (~1–1.5 days)
- **Iterate** → tell me what felt wrong (speed range? control placement? acceleration curve?).
- **Drop** → delete the branch; it touches only the song view + a new provider, nothing else depends
  on it.

---

### Decision 2

**Try this first:** `git switch claude/poc-recent-songs`, run the app, open a few songs (#1, #42, #7)
backing out each time, then look at the **top of the Home list**. Tap the highlighted **Continue**
card. Reopen one you've already seen and watch it jump to the front.

- **What you're judging:** does the Recently-viewed rail + Continue save real taps for how you actually
  use the app on a Sunday? Is the rail the right size/position, or would a single "Continue" banner be
  enough?
- **Ship** → finish: relative-time labels, optional History screen, a "disable tracking" setting.
  (~½ day)
- **Iterate** → e.g. fewer cards, different placement, or fold "Continue" into the app bar.
- **Drop** → delete the branch; purely additive (new model/repo/provider + a Home rail).

---

### Decision 3

**Try this first:** `git switch claude/poc-capo-helper`, run the app, open a song in **Bb** (or
transpose any song until the key is awkward), open the **tune** FAB, and read the **CAPO** section. Then
tap Transpose **±** and watch the capo suggestion update.

- **What you're judging:** is the capo/shape suggestion genuinely useful to the guitarists in your
  congregation, and is the controls-sheet the right home for it? **Also decide the scope question:** are
  you comfortable that a *text-only* capo helper (no fretboard diagrams) is inside PROJECT.md's "no
  guitar diagrams" line, or does even this cross it?
- **Ship** → finish: add a "transpose to nearest open key" shortcut and maybe a small capo badge in the
  app bar. (~½ day)
- **Iterate** → e.g. let the user pick which shapes they're comfortable with, or change the
  recommendation rule.
- **Drop** → delete the branch; it's a self-contained pure service + one controls-sheet section.

---

*Branches (local only, never pushed):* `claude/poc-autoscroll`, `claude/poc-recent-songs`,
`claude/poc-capo-helper` — each off `claude/phase-8-setlists`. Per-POC detail in `POC-autoscroll.md`,
`POC-recent-songs.md`, `POC-capo-helper.md` on their respective branches.
