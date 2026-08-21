# Handoff — Songbook: audit closed, navigation rebuilt, branded, deployed

_Written 2026-07-27. Uncommitted by design._

## Where we are

All work is on **`master`** in `C:\Users\rober\source\repos\songbook-app`, pushed and
deployed. This session closed the last of the integration audit, then rebuilt navigation
around the song list, added lyrics search, replaced the stock Flutter branding, and fixed
four things Robert found by using the installed web app on his phone.

Milestones v1.0 (phases 1–6) and v1.1 (phases 7–9) remain **code-complete**. Nothing is
queued code-side. What is left for an actual store release is human/device work only.

Live: https://megurobert.github.io/songbook-app/ — currently **build 148**.

## Done (committed + pushed to `origin/master`)

Repo: `C:\Users\rober\source\repos\songbook-app`, branch `master`, in sync with origin.
Every commit below deployed green via the Pages workflow.

**`0f10dfe` — closed the remaining audit findings (S9, S11–S14, S17, S20)**
- **S9 was still open** and the previous handoff's list had missed it: search results were
  a snapshot from a one-shot `read` of `songsProvider`, so a tag edit never reached an open
  search. Fixed by listening for catalog changes. Two latent races surfaced and were fixed
  with it — `_recompute` did not re-check `isFiltering` after its await, so clearing the
  filter mid-load published the **entire catalog** as results.
- **S11's premise in the audit was wrong.** The ticker does *not* keep running under
  presentation mode: `Overlay` marks the covered entry `tickerEnabled:false` and
  `TickerMode` mutes it. The damage was `Ticker` preserving its start time while muted, so
  the first tick back carried the whole absence as one `dt` — measured 448 px for 10 s away.
  Fixed with a 250 ms clamp on `dt`.
- S12 transpose/capo inert in Lyrics; S13 first-frame state bleed; S14 per-record decoding;
  S17 dead code deleted; S20 `autoDispose`.
- `.planning/AUDIT-v1.0-v1.1-INTEGRATION.md` is updated: **all 20 findings closed**, plus a
  section recording what S17 deliberately did *not* delete and why.

**`7da3732` — navigation rebuild + lyrics search + branding**
- Books, Tags and Search were destinations pushed *outside* the shell. They are filters over
  one list, so they now live on it: Books and Tags are **sheets**, Search **expands in the
  app bar** (leftmost trailing action), and a book filter puts a **one-tap back arrow** in
  the bar. Setlists promoted to a bottom-nav tab (Songs / Setlists / Favorites / Settings).
- Three screens deleted (`search_screen.dart`, `book_browser_screen.dart`,
  `tag_browser_screen.dart`); coverage moved to `song_list_search_test.dart` and
  `song_list_filters_test.dart`. `/search`, `/books`, `/tags` now redirect; `?tag=` still
  seeds the filter.
- Lyrics full-text search as a **fallback only** — running it always would let a common word
  bury real title matches. Hits carry the matching line as a snippet.
- Controls sheet: all five sections always present in fixed order, inapplicable ones
  disabled with a reason. Fixes Robert's complaint that preset chips moved between views.
- Cross-over-staff icon at every platform size; stock strings (`songbook_app`, "A new
  Flutter project.", Flutter blue) cleared. Name stayed **Songbook** by Robert's choice.

**`9572439` — versioning**
- CI derives the build number from `git rev-list --count HEAD` and passes it to
  `flutter build web --build-number`. No manual bump, no commit-back loop. Needed
  `fetch-depth: 0` on checkout or every deploy reports build 1.
- Settings displayed a **hardcoded `'1.0.0'`**; now reads the artifact via
  `package_info_plus` → `1.1.0 (build 148)`. pubspec bumped 1.0.0 → 1.1.0.

**`6c006cf` — phone fixes**
- Controls sheet was dismissable only by grabbing the 4 px handle: the scroll view won the
  vertical-drag gesture. Now a `DraggableScrollableSheet` sharing its scroll controller, so
  a swipe anywhere dismisses.
- PWA manifest declared `orientation: portrait-primary`, locking the installed app to
  portrait — backwards for a projection app. Now `any`.

**`6819968` — dark-theme notation**
- Notes/stems already followed the theme; lyrics, chords, time signature and the key/time
  header used baked-in light-theme colours and stayed near-black on a dark surface. All five
  ink colours now come from `NotationPalette` (one per theme).

## In-flight (uncommitted)

**None.** Working tree is clean; `master` is in sync with `origin/master`. `HANDOFF.md`
(this file) is the only untracked file.

## Blocked / Known issues

- **v1.0 store release is blocked on human/device work only** — store listing text and
  screenshots, on-device release testing, TalkBack/VoiceOver pass, signing, submission.
  Itemised in `.planning/phases/06-store-prep/RELEASE-CHECKLIST.md`. The app icon is no
  longer a blocker (shipped in `7da3732`).
- **Phase 7's OCR/OMR accuracy goal** needs Audiveris/EasyOCR + real scans — external.
- **The test suite still does not cover integration seams.** Every serious bug this session
  and last was found by driving a browser, never by the suite.
- **`Song.==` compares only `number`** (`song.dart:209`) — the identity-only-equality trap
  that caused the headline setlist bug. Currently masked because Dart's `List.==` is
  reference-based, so a rebuilt list always differs. Not broken; live ammunition.
- **Robert must re-add the home-screen shortcut** for the orientation fix to take effect —
  a PWA manifest is captured at install time.
- **Playwright hung twice** on the song-view page late in the session (had to `TaskStop`
  two `browser_run_code_unsafe` tasks). Screenshots taken afterwards were fine. No
  explanation found; if it recurs, prefer `browser_navigate` + `browser_take_screenshot`
  over long scripted `browser_run_code_unsafe` blocks.

## Remaining work (ordered)

1. **Robert's UAT of the deployed build** — he was mid-testing on his phone when the session
   ended. Expect more findings; nothing else is queued.
2. **Requirements-audit leftover** (`.planning/AUDIT-v1.0-v1.1-REQUIREMENTS.md`): Phase 1
   criterion 5 — the "transposed key missing" SVG message is unreachable because no song
   declares a `sheetMusic` entry. Content gap, not code.
3. **Stale wording**: Phase 4's ROADMAP criterion 3 still mentions the removed "Custom"
   view option.
4. **Milestone close-out** — `/gsd:complete-milestone` for v1.0/v1.1 once the human release
   steps land.
5. **Phases 10–12** (cloud backend, sharing, scale/quality) — not started; 10 depends on
   shipping first.

## Files / commands reference

**Repo:** `C:\Users\rober\source\repos\songbook-app` (Flutter app in `songbook_app/`,
Python import tooling in `tools/`)

```bash
# verify (from songbook_app/)
flutter analyze            # expect 8 pre-existing RadioListTile deprecation infos
flutter test               # expect 526 passing
cd ../tools && python -m unittest test_song_validator test_batch_import   # 37 passing

# serve a release build locally (survives the session; matches production perf)
cd songbook_app && flutter build web --release
powershell -c "Start-Process python -ArgumentList '-m','http.server','8765','--directory','<abs>/songbook_app/build/web' -WindowStyle Hidden"

# gh as MeguRobert (global gh is the binhatch account)
export GH_CONFIG_DIR="$HOME/.config/gh-meguRobert"
gh run list --limit 1
curl -s https://megurobert.github.io/songbook-app/version.json
```

**Browser verification — read this before trusting a UI check**
- Flutter's **service worker** caches aggressively; a `?cachebust=` query is *not* enough.
  Unregister workers and delete caches, then reload:
  `for (const r of await navigator.serviceWorker.getRegistrations()) await r.unregister();`
  `for (const k of await caches.keys()) await caches.delete(k);`
- **Mouse drags cannot test scrollables.** Flutter excludes `PointerDeviceKind.mouse` from a
  scrollable's drag devices on web, so a mouse-drag test passes against broken code. Use CDP
  `Input.dispatchTouchEvent` after `Emulation.setTouchEmulationEnabled`.
- The headless browser renders at ~1.3 fps. Useful for catching first-frame bugs; misleading
  for anything timing-based (it made a `1/30 s` dt clamp look like a 20× slowdown).

**Key docs**
- `.planning/AUDIT-v1.0-v1.1-INTEGRATION.md` — 20 findings, all closed, with the S17 and S11
  rationale written up
- `.planning/AUDIT-v1.0-v1.1-REQUIREMENTS.md` — 42 criteria
- `.planning/INTEGRATION-DECISIONS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md`
- `.planning/phases/06-store-prep/RELEASE-CHECKLIST.md` — the human release steps

**Branches:** `master` is authoritative and deploys on push. `claude/phase-5..9` and
`claude/poc-*` are merged and deletable. `gh-pages` is the built site (produced by Actions).

**Recurring gotcha:** several models originally used identity-only `==`. `Setlist`,
`Favorite` and `RecentSong` are fixed; `Song` is not (see Blocked). Check any NEW model's
`==` covers its mutable fields.

## Resume prompt

```
Continue the Songbook app. Repo: C:\Users\rober\source\repos\songbook-app (branch master, clean, in sync).

Read the full handoff first: C:\Users\rober\source\repos\songbook-app\HANDOFF.md

Done: all 20 integration-audit findings closed; navigation rebuilt around the song list
(books/tags as sheets, search in the app bar, Setlists a nav tab); lyrics fallback search;
cross app icon + branding; auto-versioning per deploy; dark-theme notation fixed.
526 Dart + 37 Python tests green. Live at https://megurobert.github.io/songbook-app/ (build 148).

Next: Robert was mid-UAT on his phone — expect findings. Nothing else is queued code-side.

Caveat: the suite does NOT cover integration seams; every real bug was caught in a browser.
Flutter's service worker defeats ?cachebust — unregister workers + delete caches. And a
mouse drag cannot test a scrollable on web (Flutter ignores mouse for scroll drags), so use
CDP touch events or you will "verify" broken code.
```
