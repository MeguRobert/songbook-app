---
phase: 04-controls-ui-redesign
verified: 2026-07-21T00:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification:
  previous_status: passed (initial, pre-gap-closure — see 04-UAT.md for the gaps found afterward)
  previous_score: 5/5 (initial 04-01/04-02 verification; superseded — UAT then found 4 issues)
  gaps_closed:
    - "Custom view option expands to reveal notation/chords toggles that usefully control the view — RESOLVED by removal: Custom chip/toggles deleted entirely per user decision (04-03)"
    - "Transpose controls stay in fixed positions so repeated +/- taps work like a carousel without the Reset button shifting the layout (04-03)"
    - "Text size controls also scale the sheet music notation, not only text/chord views (04-04)"
    - "Pinch-to-zoom adjusts the text-size setting and works in all views including Sheet Music (04-05)"
  gaps_remaining: []
  regressions: []
---

# Phase 4: Controls UI Redesign Verification Report

**Phase Goal:** Replace the overloaded floating controls column with a clean bottom sheet pattern, add pinch-to-zoom, and move presentation mode to the app bar — reducing visual clutter while preserving all functionality.

**Verified:** 2026-07-21
**Status:** PASSED
**Re-verification:** Yes — after gap closure (plans 04-03, 04-04, 04-05, following 04-UAT.md findings)

## Goal Achievement

### Observable Truths (updated acceptance criteria post-UAT)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Floating column replaced by FAB that opens a Material bottom sheet with labeled sections | ✓ VERIFIED | `song_view_screen.dart:150-154` FAB with `Icons.tune`; `_showControlsSheet` (lines 40-46) calls `showModalBottomSheet` with `isScrollControlled: true`; `song_controls_sheet.dart` has VIEW (68-117), TRANSPOSE (121-176), TEXT SIZE (181-214) sections with `_SectionHeader` labels |
| 2 | Pinch-to-zoom gesture works for text scaling (A+/A- buttons also available inside sheet) | ✓ VERIFIED | `song_view_screen.dart:99-107` `Listener.onPointerSignal` handles `PointerScaleEvent` → `setTextScale` (the decisive web fix, commit a6bb140); `GestureDetector.onScaleUpdate` (108-118) retained for mobile touch; A-/A+ `TextButton`s at `song_controls_sheet.dart:185-212` call `decreaseTextScale`/`increaseTextScale` |
| 3 | Three view presets (Sheet Music, Chords, Lyrics) are primary; Custom option intentionally removed per UAT | ✓ VERIFIED | `song_controls_sheet.dart:74-116` — exactly 3 `ChoiceChip`s (Sheet Music/Chords/Lyrics), each calling `setPreset`; no Custom chip, no `AnimatedSize` toggle block, no `isCustomSelected` anywhere in the file or in `lib/` |
| 4 | Presentation mode button is in the app bar (not buried in controls) | ✓ VERIFIED | `song_view_screen.dart:70-76` `IconButton(Icons.fullscreen)` in `AppBar.actions`, before the favorite button, calls `context.push(AppRoutes.presentationPath(...))` |
| 5 | Transpose controls are clearly labeled with key display in the bottom sheet, and stay fixed-position (no UAT layout-shift regression) | ✓ VERIFIED | `song_controls_sheet.dart:120-176` "TRANSPOSE" header, +/- `IconButton`s, `targetKey` display; offset label (140-153) and Reset button (166-176) both wrapped in `Visibility(visible: hasTranspose, maintainSize: true, maintainAnimation: true, maintainState: true)` so hidden state still reserves layout space |

**Score:** 5/5 truths verified

### Gap-Closure Plan Verification (must_haves vs. actual code)

| Plan | Claim | Verified in code? |
|------|-------|--------------------|
| 04-03 | Custom UI removed, transpose layout-shift fixed via `Visibility(maintainSize)` | ✓ Confirmed — see truths 3 & 5 above; grep for `toggleNotation\|toggleChords\|isCustomSelected\|isNotationWithoutChords` across `lib/` returns zero matches |
| 04-04 | Sheet music notation honors `textScale` via `canvas.scale()` | ✓ Confirmed — `sheet_music_renderer.dart:27,36,65,142,162,176-188` threads `textScale` into layout (`constraints.maxWidth / textScale`), box sizing (`totalWidth/Height * textScale`), and into `SheetMusicPainter`; `sheet_music_painter.dart:17,33,81,965` stores `textScale`, calls `canvas.scale(textScale)` in `paint()`, and includes it in `shouldRepaint` |
| 04-05 | Pinch-to-zoom fix — `Listener.onPointerSignal` handling `PointerScaleEvent`, no `InteractiveViewer` remaining | ✓ Confirmed — handler exists at `song_view_screen.dart:99-107` exactly as described; `grep -rn "InteractiveViewer" lib/` returns zero matches (confirmed removed from both `chord_view.dart` and `sheet_music_view.dart`, replaced with `SingleChildScrollView`); viewport meta tag present at `web/index.html:22` (`user-scalable=no`) |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `song_controls_sheet.dart` | 3-chip View section, fixed-position Transpose, Text Size section | ✓ VERIFIED | EXISTS (249 lines), SUBSTANTIVE, WIRED into `song_view_screen.dart` |
| `song_view_screen.dart` | FAB, app-bar fullscreen button, `Listener` + `GestureDetector` pinch handling | ✓ VERIFIED | EXISTS (177 lines), SUBSTANTIVE, WIRED |
| `chord_view.dart` | No `InteractiveViewer`, accepts `textScale` | ✓ VERIFIED | `SingleChildScrollView` only; `textScale` field used to compute `fontSize` (line 30) |
| `sheet_music_view.dart` | Legacy SVG path uses scrollable (not `InteractiveViewer`), threads `textScale` to custom renderer | ✓ VERIFIED | `_buildLegacyView` uses `SingleChildScrollView`; `_buildCustomRenderer` passes `textScale` into `SheetMusicRenderer` (line 54) |
| `sheet_music_renderer.dart` / `sheet_music_painter.dart` | `textScale` param scales canvas | ✓ VERIFIED | `canvas.scale(textScale)` at painter.dart:81; layout divides by scale, box multiplies by scale |
| `web/index.html` | Viewport meta tag suppressing native pinch-zoom | ✓ VERIFIED | Line 22: `user-scalable=no`, `maximum-scale=1.0` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `song_view_screen.dart` FAB | `song_controls_sheet.dart` | `showModalBottomSheet` | ✓ WIRED | Confirmed |
| `song_view_screen.dart` `Listener.onPointerSignal` | `songViewProvider` | `setTextScale(current * event.scale)` | ✓ WIRED | Confirmed — this is the fix for desktop/web pinch (trackpad/ctrl+wheel delivered as `PointerScaleEvent`, bypasses `GestureDetector`) |
| `song_view_screen.dart` `GestureDetector.onScaleUpdate` | `songViewProvider` | `setTextScale` | ✓ WIRED | Retained for mobile multi-touch pinch |
| `song_view_screen.dart` | `SheetMusicView`/`ChordView` | `textScale:` prop | ✓ WIRED | Line 130, 136, 143 — `textScale` passed to all three view branches |
| `song_view_screen.dart` app bar | presentation route | `context.push(AppRoutes.presentationPath)` | ✓ WIRED | Confirmed |

### Static Analysis & Test Suite

- `flutter analyze`: **clean** — only 8 pre-existing `RadioListTile`/`groupValue`/`onChanged` deprecation `info`s in `settings_screen.dart` (unrelated to Phase 4, pre-existing per 04-03/04-04 SUMMARYs). No errors, no warnings, no new issues.
- `flutter test`: **364/364 passed**, including `song_controls_sheet_test.dart` ("opens from the FAB and shows all three sections", "selecting the Lyrics preset updates the view config") and `sheet_music_view_test.dart` (Canvas renderer, transposed rendering, no-sheet-music fallback).
- Dead-code grep sweep of `lib/`: `toggleNotation`, `toggleChords`, `isCustomSelected`, `isNotationWithoutChords`, `InteractiveViewer` — **zero matches** for all five patterns.

### Anti-Patterns Found

None. No TODO/FIXME/placeholder patterns, no empty handlers, no orphaned dead code left over from the Custom-view removal.

### Requirements Coverage

REQ-04 (Configurable Song View, improved UX) — ✓ SATISFIED. All 5 truths verified; UAT-reported regressions (Custom dead-end, transpose layout shift, sheet music not scaling, pinch behaving like image zoom / not working on web) are all closed and confirmed in code, not just in SUMMARY narrative.

### Human Verification Required

Automated/code-level verification is complete and passing. Two items remain appropriately flagged for human/manual confirmation (per 04-05-SUMMARY.md, not blocking since they were already confirmed via Playwright automation for the equivalent code paths):

#### 1. Physical touch-device pinch confirmation

**Test:** On an actual mobile/tablet touch device, open a song in Sheet Music view and perform a real two-finger pinch.
**Expected:** Text/notation scales smoothly between 50%-200%, matching the A+/A- behavior.
**Why human:** 04-05-SUMMARY.md states this was confirmed via Playwright synthetic touch events and via Chrome desktop `ctrl+wheel`, but not yet on a physical touch device. Low risk — the same `GestureDetector.onScaleUpdate` handler used for the confirmed synthetic-touch path is what a real device would exercise.

#### 2. Visual/UX sign-off on final bottom sheet

**Test:** Open the FAB bottom sheet, cycle presets, transpose repeatedly through zero, and increase/decrease text size, observing spacing and animation feel.
**Expected:** No layout jump on transpose Reset button appearing/disappearing; sheet visually matches the "clean, decluttered" phase intent.
**Why human:** Visual polish and gesture feel are subjective; the structural fix (`Visibility(maintainSize)`) is code-verified above, but final aesthetic sign-off is a human judgment call.

### Gaps Summary

**No gaps found.** All 4 UAT-flagged issues (04-UAT.md) are closed and verified directly in the codebase (not just claimed in SUMMARYs):

1. ✓ Custom view removed entirely (not merely "fixed") — matches the updated acceptance criterion of "three presets only, no Custom"
2. ✓ Transpose Reset button / offset label now reserve layout space via `Visibility(maintainSize: true)` — no more carousel-disrupting shift
3. ✓ Sheet music notation now honors `textScale` end-to-end via `canvas.scale()`
4. ✓ Pinch-to-zoom works across all views including Sheet Music, on both mobile touch (`GestureDetector`) and desktop web (`Listener.onPointerSignal` for `PointerScaleEvent`) — the root cause (pointer-signal events bypassing `GestureDetector` on web) is fixed, not just papered over

`flutter analyze` is clean (only pre-existing unrelated deprecation infos) and all 364 tests pass. Dead-code grep sweep confirms no orphaned references to the removed Custom-view code paths remain anywhere in `lib/`.

---

_Verified: 2026-07-21_
_Verifier: Claude (gsd-verifier)_
