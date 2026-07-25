---
audit: requirements-coverage
scope: v1.0 (phases 1-6) + v1.1 (phases 7-9)
date: 2026-07-25
branch: master
method: goal-backward verification against actual code (SUMMARY/VERIFICATION claims not trusted)
criteria_total: 42
met: 30
partial: 7
not_met: 5
gates:
  flutter_analyze: clean (8 pre-existing RadioListTile deprecation infos)
  flutter_test: 464/464 pass
  python_tests: 37/37 pass (tools/, unittest)
blockers:
  - "P4-2 REGRESSION: dispose() body mis-spliced into _animateZoomTo (song_view_screen.dart:88-90)"
  - "P9-4 STALE READ: song view + tag editor read un-merged songByNumberProvider; saved tag edits invisible/revertable"
  - "P2-5 DEAD PATH: per-song view config write (saveViewConfigForSong) has zero callers in lib/"
human_only_outstanding:
  - "P6-1 branding art + icon/splash regeneration"
  - "P6-2 store listing literals + screenshots"
  - "P6-3 on-device release-build crash/perf testing; signing; submission"
  - "P7-1 raw OMR/OCR accuracy (external tooling / AI key quality)"
---

# Requirements Coverage Audit — v1.0 (Phases 1-6) & v1.1 (Phases 7-9)

**Status: 30/42 success criteria MET, 7 PARTIAL, 5 NOT MET.**
Of the 5 NOT MET, **4 are the known human-only / external-tooling blockers** (P6-1, P6-2, P6-3, P7-1) and **1 is a criterion deliberately superseded by your Phase-4 UAT decision** (P2-1). No requirement is unaccounted for.

**But three code defects are hiding behind green gates.** `flutter analyze` is clean and all 464 Dart tests pass, yet:

1. **Phase 4 criterion 2 has regressed since it was verified.** The auto-scroll POC merge (`30cc0e2`) spliced the `dispose()` body into the *middle of the Ctrl+wheel zoom handler*. Zooming with a mouse wheel now disposes the auto-scroll `Ticker`, disposes the `ScrollController` that the on-screen chord view is actively using, and calls `super.dispose()` on a live, mounted `State`. Same merge left the real `dispose()` releasing neither the `Ticker` nor the `ScrollController`.
2. **Phase 9 criterion 4 is half-wired.** Tag edits persist and are visible in the song list / search / tag browser, but the song view (and therefore its own tag editor) reads a provider that never applies the overrides. Reopening the editor shows the *pre-edit* tags; pressing Save again silently reverts the user's edit.
3. **Phase 2's per-song view-config persistence is dead code.** `saveViewConfigForSong` — cited as evidence for criterion 5 in `02-VERIFICATION.md` — has no caller anywhere in `lib/`. `getSongViewConfig` therefore always returns `null`.

This is the same failure mode you already caught by hand twice (setlist `==`, decorative drag handle): structurally present, referenced by a passing test, unreachable or broken in the running app.

---

## Method

- Read every file in `songbook_app/lib/` relevant to a criterion; grepped for callers to distinguish *exists* from *reachable*.
- Verified the bundled data (`assets/data/songs.json`, `assets/sheet_music/`) rather than assuming the model implies content.
- Ran `flutter analyze` (clean), `flutter test` (464 pass), `python -m unittest` in `tools/` (37 pass).
- Cross-read `Ticker`, `ScrollController` and `State.dispose` contracts in the local Flutter SDK (`C:\Users\rober\tools\flutter\packages\flutter\lib\src\...`) instead of asserting lifecycle behaviour from memory.
- **No REQUIREMENTS.md exists** in `.planning/`; requirement IDs were traced from `ROADMAP.md` "Requirements:" lines back to `PROJECT.md`. The `02-VERIFICATION.md` reference to "REQ-04 from REQUIREMENTS.md" points at a file that has never existed.

Legend: **MET** = works end to end in the app. **PARTIAL** = implemented but limited, unreachable, or regressed. **NOT MET** = not delivered.

---

## Phase 1 — Bug Fixes & Core Polish  [REQ-01, REQ-02, REQ-03] — 4 MET / 1 PARTIAL

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Transpose wrapping symmetric and intuitive | **MET** | `song_provider.dart:90-97` wraps `+5 → -6`; `:99-106` wraps `-6 → +5`. `chord_transposer.dart:29-31` modulo wrap with negative correction; `:51-55` normalizes key distance to −6..+5. |
| 2 | Chord view horizontally centered like sheet music | **MET** | `chord_view.dart:42-44` — `Center(child: ConstrainedBox(maxWidth: 600))`. Notation path centers inside the painter (`sheet_music_painter.dart:124`). |
| 3 | Text size can be increased/decreased while viewing | **MET** | `song_controls_sheet.dart:214-249` A−/A+ → `song_provider.dart:114-126` (clamped 0.5–2.0) → consumed at `chord_view.dart:34-35` and threaded to notation via `sheet_music_renderer.dart:157,199` + `sheet_music_painter.dart:81` (`canvas.scale`). |
| 4 | Transpose state resets when navigating between songs | **MET** | `song_view_screen.dart:67-73` post-frame `openSong()` → `song_provider.dart:69-78` builds a **fresh** `SongViewState` (transpose 0, textScale 1.0). No `closeSong()` in `dispose` by design (`ae94575`/`7f5dfa9`). |
| 5 | SVG fallback distinguishes "transposed key missing" from "no sheet music" | **PARTIAL — correct but unreachable** | The two distinct messages exist: `sheet_music_view.dart:225-245` ("Sheet music for X not available. Showing original key (Y).") vs `:256-288` ("No sheet music available for this song"), driven by `_loadSheetMusicWithFallback` (`:338-361`). **But that branch only runs for songs with a `sheetMusic` entry, and no song has one:** all 8 songs in `assets/data/songs.json` have no `sheetMusic` field, and the single asset `assets/sheet_music/151_Bb.svg` is not referenced by song 151 (which uses the Canvas renderer). Every legacy-path song therefore falls straight to "No sheet music available". The distinction can never surface in the shipped app. |

---

## Phase 2 — Configurable Song View  [REQ-04] — 2 MET / 2 PARTIAL / 1 NOT MET

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | User can toggle chord symbols on/off **above the staff** in sheet music view | **NOT MET — superseded by your Phase-4 decision** | This requires `showNotation=true, showChords=false`. Nothing in `lib/` can produce that state: the only writers are the three preset factories (`view_config.dart:17-29`), and `ViewConfig.fromStorageString` **actively rewrites** notation-without-chords back to the Sheet Music preset (`view_config.dart:72-76`). The painter's `if (showChords)` guard (`sheet_music_painter.dart:103`) is consequently always true whenever notation is drawn. Removing "Custom" (04-03) took this capability with it. See *Stale roadmap wording* below — this is a scope decision to confirm, not a defect, but it is a **capability loss the roadmap still promises**. |
| 2 | Lyrics always visible in all modes (base layer, not toggled) | **MET** | `ViewConfig` exposes only `showNotation`/`showChords` (`view_config.dart:6-12`); painter calls `_drawLyrics` unconditionally (`sheet_music_painter.dart:104`); `chord_view.dart:155-163` still renders `line.text` when `showChords` is false. |
| 3 | User can view chords+lyrics without notation | **MET** | `song_view_screen.dart:279-286` renders `ChordView(showChords: true)` when `!showNotation && showChords`. |
| 4 | Toggle controls accessible/discoverable in the floating menu | **PARTIAL — stale wording** | The floating menu was deleted in Phase 4. Three preset `ChoiceChip`s are discoverable in the FAB bottom sheet (`song_controls_sheet.dart:82-135`), which satisfies the *intent*; the independent per-flag toggles the criterion names no longer exist. |
| 5 | View configuration persists across song navigation **and** app restart | **PARTIAL** | **Global default persists:** `settings_screen.dart:141-180` → `settings_provider.dart:54-62` → `settings_repository.dart:72-85` → SharedPreferences. **In-song selection does not persist at all:** the bottom sheet calls `songViewNotifier.setPreset` (`song_controls_sheet.dart:97,113,129`), which only mutates in-memory state (`song_provider.dart:151-162`), and every navigation rebuilds that state from scratch (`openSong`, `:69-78`). **The per-song override write path is dead:** `saveViewConfigForSong` (`song_provider.dart:165-173`) has **zero callers in `lib/`** (only `test/unit/presentation/providers/song_provider_test.dart:232-251`), so `getSongViewConfig` (`:72`) always returns `null`. `02-VERIFICATION.md:26` cites exactly this path as proof the criterion passes. Additional latent bug: `clearViewConfigForSong` (`:176-182`) cannot clear state — `copyWith` uses `activeViewConfig ?? this.activeViewConfig` (`:58`), so passing `null` is a no-op. |

---

## Phase 3 — Presentation Mode  [REQ-05] — 5 MET

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Full-screen lyrics, minimal chrome | **MET** | `presentation_screen.dart:277-278` `Scaffold` with **no** `appBar`; `:38` `SystemUiMode.immersiveSticky`; overlay auto-hides after 3 s (`:51-59`). Route sits outside the nav-bar shell (`app_router.dart:80-88`). |
| 2 | Text scales to fill available width | **MET** | `_computeConsistentFontSize` (`:185-235`) solves width/height and area constraints across *all* verses so every slide shares one size; wrapped in `FittedBox(scaleDown)` (`:497-507`). |
| 3 | Dark background option for projection (white on black) | **MET** | `:245-251` black/white when `_projectionMode`; toggle at `:384-391`; persisted via `settings_repository.dart:108-114` and restored in `initState` (`:37`). |
| 4 | Swipe or tap to advance | **MET** | `PageView.builder` (`:282`) for swipe; tap zones left/centre/right (`:292-304`); plus keyboard arrows/space/PgUp/PgDn/Home/End/Esc and digit jump (`:120-176`). |
| 5 | Works on phone and tablet/desktop | **MET (code)** | Breakpoint-aware font clamps `screenWidth < 600` (`:475-476`), landscape padding + indicator placement (`:349-350,468,401-402`), keyboard control for desktop projection. Visual sign-off on a real second display remains a human check. |

---

## Phase 4 — Controls UI Redesign  [REQ-04] — 4 MET / 1 PARTIAL

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Floating column replaced by FAB → Material bottom sheet with labeled sections | **MET** | `song_view_screen.dart:299-303` `FloatingActionButton.small(Icons.tune)` → `:132-138` `showModalBottomSheet(isScrollControlled: true)`. Sections VIEW/TRANSPOSE/CAPO/TEXT SIZE/AUTO-SCROLL via `_SectionHeader` (`song_controls_sheet.dart:80,139,199,210,259`), each `Semantics(header: true)` (`:421-431`). No floating menu widget remains in `lib/`. |
| 2 | Pinch-to-zoom works for text scaling (A+/A− also in sheet) | **PARTIAL — REGRESSED after verification** | A−/A+ work (`song_controls_sheet.dart:214-249`). Touch pinch works (`song_view_screen.dart:255-265`). **The desktop/web pointer-signal path is broken:** `Listener.onPointerSignal` (`:234-253`) routes a discrete wheel notch into `_animateZoomTo`, whose body is corrupted — `song_view_screen.dart:84-91`:<br>`_zoomFrom = …; _zoomTo = …; _zoomController.forward(from: 0);` **`_ticker.dispose(); _scrollController.dispose(); super.dispose();`**<br>Those last three lines belong to `dispose()`. Consequences, each verified against the SDK contract: (a) `Ticker.dispose()` asserts `!isActive` (`ticker.dart:348-356`) → zooming while auto-scroll plays trips a framework assertion; (b) the `ScrollController` handed to the *currently mounted* `ChordView` (`:285,293`) is disposed mid-use (`scroll_controller.dart:260-265`); (c) `super.dispose()` marks the live `State` defunct (`framework.dart:1334-1341`), so the real teardown later fails `assert(_debugLifecycleState == ready)`. **Second, independent defect from the same merge:** `dispose()` (`:76-80`) now releases only `_zoomController` — leaving the song view while auto-scroll is playing hits `TickerProviderStateMixin.dispose()`'s "*was disposed with an active Ticker*" error (`ticker_provider.dart`). Introduced by merge `30cc0e2` (auto-scroll POC), i.e. **after** `04-VERIFICATION.md` was written. Invisible to the gates: `flutter analyze` cannot see it and **no test touches `PointerScaleEvent`, `onPointerSignal`, or the widget's ticker lifecycle**. |
| 3 | Three presets primary; individual toggles via "Custom" | **MET as amended — ROADMAP WORDING STALE** | Exactly three `ChoiceChip`s, no Custom (`song_controls_sheet.dart:86-133`); grep for `isCustomSelected`/`toggleNotation`/`toggleChords` in `lib/` → zero. Per `INTEGRATION-DECISIONS.md` and `04-VERIFICATION.md:10`, Custom was **removed by your decision** after UAT; acceptance is "three presets only". `ROADMAP.md:93` still says "individual toggles accessible via Custom option" — fix the roadmap, not the code. |
| 4 | Presentation mode button in the app bar | **MET** | `song_view_screen.dart:204-210` `IconButton(Icons.fullscreen)` in `AppBar.actions` → `context.push(AppRoutes.presentationPath(...))`. |
| 5 | Transpose controls clearly labeled with key display | **MET** | `song_controls_sheet.dart:139-194`: "TRANSPOSE" header, −/+ `IconButton`s, bold `targetKey`, signed offset, and "Reset to {originalKey}". Both conditional widgets use `Visibility(maintainSize/maintainAnimation/maintainState: true)` (`:158-171`, `:184-193`) so the +/− buttons don't move — the UAT layout-shift fix is genuinely in the code. |

---

## Phase 5 — Song Books  [REQ-06] — 5 MET

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Songs grouped by book/hymnal in the data model | **MET** | `song.dart:133-134` `String? book` + `:172-173` `hasBook`; `book.dart` value object; `book_service.dart:20-49` derives books with counts, ordered by lowest song number, "Other" bucket last. Data confirmed: all 8 songs carry a book (Zsoltárok ×3, Dicséretek ×5). |
| 2 | Book browser lets users select which book to browse | **MET** | `book_browser_screen.dart:46-61` + `/books` route (`app_router.dart:99-103`), reachable from the song-list app bar (`song_list_screen.dart:29-37`). |
| 3 | Song list filters to the selected book | **MET** | `filteredSongsProvider` (`book_provider.dart:53-57`) → `BookService.filterByBook` (`book_service.dart:56-62`); consumed at `song_list_screen.dart:17`, title reflects selection (`:22`). |
| 4 | "All songs" view still available | **MET** | `book_browser_screen.dart:32-44` "All Songs" with total count → `SelectedBookNotifier.clear()` (`book_provider.dart:37-41`); `filterByBook(null)` returns everything; empty state offers "Show all songs" (`song_list_screen.dart:128-132`). Selection persists via `settings_repository.dart:119-133`. |
| 5 | New songs can be assigned to a book during import | **MET** | `tools/convert_hymn.py:610` `--book/-b`; applied at `:554-555`; echoed at `:560-561`; plumbed from `main` at `:702`. `tools/batch_import.py` forwards `book` per manifest row. |

---

## Phase 6 — Store Release Prep  [REQ-07] — 1 MET / 1 PARTIAL / 3 NOT MET (all human-only)

*Per the audit brief, Phase 6 is a codeable slice; the items below are outstanding **human/online work**, not code defects.*

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | App icon and splash are professional and on-brand | **NOT MET — human blocker** | `assets/icons/` contains only `.gitkeep` + `README.md` — **no source art**. `flutter_launcher_icons.yaml` / `flutter_native_splash.yaml` exist but are self-labelled "⚠️ NEEDS FINAL ART", reference non-existent `assets/icons/app_icon.png`, and carry an unconfirmed brand colour (`#1A237E` «confirm»). Neither generator is declared in `pubspec.yaml` `dev_dependencies`. `android/app/src/main/res/mipmap-*/ic_launcher.png` are still the **stock Flutter icons**. |
| 2 | Store listing metadata (title, description, screenshots) complete | **NOT MET — human blocker** | `STORE-LISTING.md` is a good draft but has ~12 unresolved «guillemet» fields (developer name, support email, privacy URL, bundle id, categories, keyword trim) and no screenshots (needs a device). |
| 3 | Runs smoothly on Android and iOS without crashes | **NOT MET — human blocker, and now at elevated risk** | No on-device release-build testing has occurred. Note the two lifecycle defects in Phase 4 criterion 2 are exactly the class that manifests as a device-only crash/red screen; they should be fixed **before** the on-device pass so it isn't wasted. |
| 4 | Basic accessibility (text scaling, screen reader labels) | **MET (code); device UAT outstanding** | `test/accessibility/accessibility_test.dart` exercises `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, "Song N" semantic labels, and a 2.5× `TextScaler` smoke test — all passing. 7 explicit `Semantics` sites across `song_list_tile`, `settings_screen`, `song_controls_sheet` (A−/A+ labels), `presentation_screen` (title header), `sheet_music_renderer` (canvas image label). Real TalkBack/VoiceOver + system font-slider UAT still pending. Gap worth noting: the Phase 5/8/9 screens (books, setlists, tags, search) added no explicit semantics and aren't covered by the guideline tests — they rely on stock `ListTile`/`IconButton` tooltips, which is usually sufficient but unverified. |
| 5 | Passes store review (no placeholder content, proper permissions) | **PARTIAL** | Permissions posture is genuinely clean: `AndroidManifest.xml:8` `android:label="Songbook"`, **zero** `<uses-permission>` (documented in-file), iOS `CFBundleDisplayName = Songbook` (`Info.plist:11-12`) with no privacy-usage strings. Debug-only UI is `kDebugMode`-gated (`sheet_music_view.dart:35,58,133`). Blocked on criterion 1 (placeholder launcher icon = placeholder content). Cosmetic: `CFBundleName` is still `songbook_app` (`Info.plist:19-20`). |

---

## Phase 7 — Import Pipeline  [FUT-01] — 3 MET / 1 NOT MET (external)

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Import accuracy improved (fewer manual corrections) | **NOT MET — external tooling goal, not code** | Depends on Audiveris/OCR/AI-key quality; no measurement harness exists. The validation gate below partially serves it by catching errors early. Correctly recorded as a blocker in `07-VERIFICATION.md`. |
| 2 | Batch import support | **MET** | `tools/batch_import.py` (194 lines): JSON/CSV manifest loader (`:81`), `build_command` (`:102`), `run_batch` with `--dry-run` / `--continue-on-error` / `--validate-only` (`:149-156`). `tools/sample_import_manifest.json` provided. |
| 3 | Validation step catches OCR errors before they enter songs.json | **MET** | `tools/song_validator.py` (282 lines): per-song and per-verse error/warning checks, duplicate detection, `has_errors`, CLI `main`. Wired as a real gate: `convert_hymn.py:29-33` guarded import, `:569-579` validates the updated song and **aborts the write** on errors, with a `--no-validate` override (`:612`). |
| 4 | Clear documentation of import workflow | **MET** | `.planning/phases/07-import-pipeline/IMPORT-PIPELINE.md`. |

**Gate:** 37/37 Python tests pass (`python -m unittest discover` in `tools/`). Note `pytest` is not installed locally; use `unittest` (or add pytest) so this suite stays runnable.

---

## Phase 8 — Setlists & Playlists  [FUT-02] — 4 MET

*Both bugs you found by hand are genuinely fixed in code, not just in prose.*

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | User can create a named setlist and add songs | **MET** | Create: `setlists_screen.dart:50-63` FAB → `_promptForName` → `SetlistsNotifier.create` (`setlist_provider.dart:25-30`) → `SetlistRepository.createSetlist` (`setlist_repository.dart:30-43`). Add: `setlist_detail_screen.dart:136-189` `_AddSongsSheet` watches the live setlist (`:144`) so checkmarks track state. Rename/delete also present (`:65-105`). |
| 2 | Songs in a setlist can be reordered | **MET — UAT fixes confirmed** | `ReorderableListView.builder` (`setlist_detail_screen.dart:58`) with `buildDefaultDragHandles: false` (`:63`) and a **functional** leading handle wrapped in `ReorderableDragStartListener` (`:78-81`) — the decorative-handle/Remove-button collision is really gone. Reorder persists via `reorderSongs` (`setlist_repository.dart:78-83`). The provider actually rebuilds because `Setlist.operator ==` now compares **all** fields including `songNumbers` element-wise (`setlist.dart:71-92`, with the root cause documented at `:64-70`). |
| 3 | Setlist provides "next song" navigation during a service | **MET** | `SetlistPlaybackNotifier.start/next/previous/jumpTo/stop` (`setlist_provider.dart:121-170`); `SetlistNavBar` self-hides when idle and drives `pushReplacement` (`setlist_nav_bar.dart:18,26-71`); mounted unconditionally at `song_view_screen.dart:304`; cursor resynced on direct navigation (`:123-130`). Playback cursor is intentionally in-memory (lost on restart) — not required by any criterion. |
| 4 | Setlists persist across app restarts | **MET** | `local_datasource.dart:110-128` JSON-encodes the list into SharedPreferences; `Setlist` is `@JsonSerializable` (`setlist.dart:11-40`); every mutator reloads from the repository (`setlist_provider.dart:20-57`). |

---

## Phase 9 — Tags & Search  [FUT-07] — 2 MET / 2 PARTIAL

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Songs can have multiple tags | **MET** | `song.dart:130` `List<String> tags`. Bundled data confirmed: all 8 songs carry 2–3 tags (`zsoltár`, `dicsőítés`, `karácsony`, `reformáció`, …). |
| 2 | Search supports filtering by tag | **PARTIAL** | Single-tag filtering works end to end: tag browser → `AppRoutes.searchWithTag` (`app_router.dart:32-33`) → `SearchScreen(initialTag:)` → `setTags({tag})` (`search_screen.dart:27-35`) → `_recompute` → `SearchService.filterByTags` (`search_service.dart:96-112`), with removable chips (`search_screen.dart:107-118`). **Multi-tag AND is unreachable from the UI:** the AND semantics and `toggleTag` exist and are unit-tested, but the only entry point (`setTags`) **replaces** the set, and inside search `toggleTag` is wired *only* to `InputChip.onDeleted` (`:110-111`). A user can never hold two tags at once. Needs a tag picker in search (or multi-select in the browser) for the "chips/AND" behaviour plan 09-02 claims. |
| 3 | Tag browser shows all available tags with song counts | **MET** | `tag_browser_screen.dart:48-62` → `tagsProvider` (`tag_provider.dart:74-77`) → `SearchService.tagsWithCounts` (`search_service.dart:65-90`, case-insensitive grouping, first-seen casing preserved, count-desc ordering). `/tags` route + app-bar entry (`song_list_screen.dart:38-42`). |
| 4 | Tags are editable (add/remove from songs) | **PARTIAL — edits are invisible to, and revertable by, the editor itself** | Editing and persistence work: `tag_editor_sheet.dart` (chips + add field + suggestions + Save + Reset) → `TagOverridesNotifier.setTags` (`tag_provider.dart:19-27`) → `TagRepository` → `local_datasource.dart:137-173`; the song list, search and tag browser all see edits because `songsProvider` merges overrides (`song_provider.dart:14-20` + `search_service.dart:119-130`). **But the song view does not:** it reads `songByNumberProvider` (`song_provider.dart:23-26`), which calls the repository directly (`song_repository.dart:16-18`) with **no override merge and no dependency on `tagOverridesProvider`**. Since the editor is seeded from that same object (`song_view_screen.dart:153,186` → `_showTagEditor(context, song.tags)`), reopening it after a save shows the **bundled** tags — a removed tag reappears, and pressing Save again re-persists it, silently undoing the user's edit. Fix is small: give `songByNumberProvider` the same override merge, or seed the editor from `songsProvider`. |

---

## Requirements → Phase → Status Rollup

| Req | Description | Phase(s) | Status |
|-----|-------------|----------|--------|
| REQ-01 | Fix transpose wrapping + polish transpose controls | 1, 4 | **SATISFIED** |
| REQ-02 | Center chord view layout | 1 | **SATISFIED** |
| REQ-03 | In-song text size controls | 1, 4 | **SATISFIED** (web/desktop zoom entry point regressed — see P4-2) |
| REQ-04 | Configurable song view; chords above staff; UX redesign | 2, 4 | **PARTIAL** — presets + merged view ship; independent notation/chords toggle removed by decision; in-song selection doesn't persist |
| REQ-05 | Lyrics presentation mode | 3 | **SATISFIED** |
| REQ-06 | Song "books" organization | 5 | **SATISFIED** |
| REQ-07 | App store readiness | 6 | **PARTIAL** — code slice done; art/listing/signing/submission outstanding (human) |
| FUT-01 | Improved import pipeline | 7 | **PARTIAL** — tooling + validation + docs done; accuracy is external |
| FUT-02 | Setlists/playlists | 8 | **SATISFIED** |
| FUT-07 | Tags and advanced categorization | 9 | **PARTIAL** — multi-tag AND unreachable; song-view tag staleness |

---

## Claimed-complete but missing, dead, or unreachable

| Item | Location | Verdict |
|---|---|---|
| Per-song view config save | `song_provider.dart:165-173` `saveViewConfigForSong` | **DEAD** — zero callers in `lib/`; only `song_provider_test.dart:232-251`. `setSongViewConfig` is therefore never invoked and `getSongViewConfig` (`:72`) always returns null. Cited as passing evidence in `02-VERIFICATION.md:26,35`. |
| Per-song view config clear | `song_provider.dart:176-182` `clearViewConfigForSong` | **DEAD + BROKEN** — no caller; and `copyWith(activeViewConfig: null)` cannot clear because of `?? this.activeViewConfig` (`:58`). |
| Notation-without-chords state | `sheet_music_painter.dart:103` `if (showChords)` | **UNREACHABLE** — no writer can produce it; `view_config.dart:74-76` normalizes it away. |
| "Transposed key missing" fallback banner | `sheet_music_view.dart:225-245,338-361` | **UNREACHABLE with shipped data** — no song declares `sheetMusic`. |
| Multi-tag AND filtering | `search_service.dart:96-112`, `search_provider.dart:66-77` | **UNREACHABLE from UI** — no way to accumulate a second tag. |
| Tag overrides in song view | `song_provider.dart:23-26` | **NOT WIRED** — `songByNumberProvider` bypasses the override merge. |
| Legacy `showChords` setting | `settings_repository.dart:51-57` | **DEAD** — superseded by `ViewConfig`; no `lib/` caller. |
| `resetTextScale`, `TranspositionService.transposeVerse`, `getSemitonesBetweenKeys`, `getAvailableKeys`, `getTranspositionDisplayName`, `allTagsProvider`, `SearchService.getAllTags`, `songCountProvider`, `SetlistRepository.getById`, `TagRepository.hasOverride`, `LocalDataSource.clearRecentSongs` | various | **DEAD in app** (declaration + tests only). Harmless, but they inflate apparent coverage: tests assert on API no screen uses. |

---

## Stale roadmap wording (fix the doc, not the code)

1. `ROADMAP.md:93` — Phase 4 criterion 3 still says *"individual toggles accessible via 'Custom' option"*. Custom was **deliberately removed** after UAT (your decision; `INTEGRATION-DECISIONS.md` §A3, `04-VERIFICATION.md:10`). Acceptance is **three presets only, no Custom**. **Not a gap.**
2. `ROADMAP.md:55,58,62` — Phase 2's goal and criteria 1/4 still describe independent notation/chords toggles in a "floating menu". Both were removed by the same Phase-4 decision. Reword — but note this is the one place where the decision **removed a capability the roadmap promised** (chords off, staff on). If you ever want "clean staff, no chord symbols" back, it needs a new criterion, not a doc edit.
3. `02-VERIFICATION.md:61` references `REQUIREMENTS.md`, which does not exist in `.planning/`. Either create the traceability table or drop the reference.
4. `ROADMAP.md:6,27,28` say phases 8/9 are "visual UAT pending"; UAT has since happened (`INTEGRATION-DECISIONS.md` §D). Update.

---

## Beyond-roadmap additions (noted, not requirements)

Three shipped POCs, all reachable and covered by tests — no roadmap criterion claims them:

| Addition | Files | Wiring |
|---|---|---|
| Capo helper | `domain/services/capo_service.dart` (87 lines) | CAPO section in the controls sheet (`song_controls_sheet.dart:199-205,314-410`); `capo_service_test.dart` |
| Auto-scroll | `presentation/providers/autoscroll_provider.dart` (76) + per-song speed in `settings_repository.dart:135-151` | App-bar play/pause + sheet slider; **its merge introduced the P4-2 dispose defect** |
| Recently viewed | `data/models/recent_song.dart`, `data/repositories/recents_repository.dart`, `presentation/providers/recents_provider.dart`, `screens/song_list/widgets/recent_songs_rail.dart` (146) | Rail on the song list (`song_list_screen.dart:58`); recorded at `song_view_screen.dart:70` |

---

## Recommended fix order

1. **`song_view_screen.dart:84-91`** — move `_ticker.dispose(); _scrollController.dispose(); super.dispose();` out of `_animateZoomTo` and into `dispose()` (after `_zoomController.dispose()`), stopping the ticker first. Add a widget test that dispatches a `PointerScaleEvent` and then unmounts, so the gates catch this class again.
2. **`song_provider.dart:23-26`** — make `songByNumberProvider` override-aware (watch `tagOverridesProvider` / derive from `songsProvider`), or seed the tag editor from the merged list. Then re-check the save→reopen→save round trip by hand.
3. **Decide** whether Phase 2's per-song view config ships (wire a "remember for this song" action and fix `copyWith`) or is cut — and reword criterion 5 accordingly. Today it is neither.
4. **Decide** whether multi-tag AND ships (add a tag picker to search) or criterion 9-2 is narrowed to single-tag.
5. **Reword** the stale roadmap lines above.
6. **Then** run the on-device pass and the Phase 6 human blockers (art → regen → signing → screenshots → submission) per `RELEASE-CHECKLIST.md`.
7. Optional: gate CI on `flutter test` (`INTEGRATION-DECISIONS.md` §C5) — the suite is tracked now, and two of the three defects above landed in merges that no gate inspected.

---

*Audited 2026-07-25 against `master` by reading `songbook_app/lib/`, `tools/`, `assets/data/songs.json`, platform config, and the Flutter SDK lifecycle contracts. No code was modified.*
