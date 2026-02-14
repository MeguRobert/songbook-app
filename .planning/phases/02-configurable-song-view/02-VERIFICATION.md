---
phase: 02-configurable-song-view
verified: 2026-02-14T17:00:46Z
status: passed
score: 10/10 must-haves verified
---

# Phase 2: Configurable Song View Verification Report

**Phase Goal:** Replace separate chord/sheet views with a unified configurable view where users toggle notation, chords, and lyrics independently

**Verified:** 2026-02-14T17:00:46Z
**Status:** PASSED
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can toggle chord symbols on/off above the staff in sheet music view | ✓ VERIFIED | Floating menu has notation/chords toggles (lines 118, 126). SheetMusicPainter conditionally renders chords (line 98). |
| 2 | Lyrics are always visible in all view modes (base layer, not toggled) | ✓ VERIFIED | ViewConfig has only showNotation and showChords fields - lyrics not configurable. SheetMusicPainter always calls _drawLyrics (line 99). ChordView always renders lyrics. |
| 3 | User can view chords+lyrics without notation (current chord view behavior preserved) | ✓ VERIFIED | SongViewScreen conditionally renders ChordView when \!viewConfig.showNotation && viewConfig.showChords (lines 80-86). |
| 4 | Toggle controls are accessible and discoverable in the floating menu | ✓ VERIFIED | FloatingControlsMenu contains notation toggle (music_note icon, line 116-121) and chords toggle (C7 label, line 123-129). |
| 5 | View configuration persists across song navigation and app restart | ✓ VERIFIED | Global config persisted via SettingsRepository using SharedPreferences. Per-song overrides stored via setSongViewConfig/getSongViewConfig. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| view_config.dart | ViewConfig immutable model with showNotation, showChords, copyWith, preset factories | ✓ VERIFIED | 98 lines. Contains 2 boolean fields, 3 preset factories, 4 preset check getters, copyWith, storage serialization, equality. |
| settings_repository.dart | Global ViewConfig persistence + per-song override storage | ✓ VERIFIED | Contains getViewConfig/setViewConfig (lines 70-83), getSongViewConfig/setSongViewConfig/clearSongViewConfig (lines 87-102). |
| settings_provider.dart | SettingsState with ViewConfig instead of SongViewMode, SettingsNotifier methods for toggles | ✓ VERIFIED | SettingsState has viewConfig field (line 9). Notifier has toggleNotation/toggleChords/setPreset methods (lines 60-76). |
| song_provider.dart | SongViewState with activeViewConfig, methods for temporary toggle changes and save override | ✓ VERIFIED | SongViewState has nullable activeViewConfig field (line 31). SongViewNotifier has toggle/preset/save/clear methods (lines 129-186). |
| song_view_screen.dart | Unified view that renders based on effectiveViewConfigProvider instead of binary viewMode | ✓ VERIFIED | Watches effectiveViewConfigProvider (line 39). Conditionally renders SheetMusicView or ChordView based on ViewConfig state (lines 74-93). |
| floating_controls_menu.dart | View toggle buttons (notation, chords) and 3 preset buttons in the expanded menu | ✓ VERIFIED | Contains notation toggle (Icons.music_note, line 116), chords toggle (C7, line 124), and 3 preset buttons (lines 134, 142, 151). |
| sheet_music_painter.dart | Conditional rendering of chords and lyrics based on showChords/showLyrics flags | ✓ VERIFIED | Has showChords field (line 16). Conditionally calls _drawChords() only when showChords is true (line 98). |
| settings_screen.dart | Global default view config setting with preset selection replacing old view mode dialog | ✓ VERIFIED | ListTile for Default View shows current config label (line 61). Dialog shows 3 preset RadioListTiles (lines 137-170). |

**Score:** 8/8 artifacts verified (all exist, substantive, wired)

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| song_view_screen.dart | effectiveViewConfigProvider | watches provider to decide which view widget to show | ✓ WIRED | Line 39: ref.watch(effectiveViewConfigProvider). Used in conditionals at lines 74, 80. |
| floating_controls_menu.dart | songViewNotifier | calls toggleNotation/toggleChords/setPreset | ✓ WIRED | Lines 118, 126: calls toggle methods. Lines 136, 144, 152: calls setPreset. |
| sheet_music_painter.dart | SheetMusicPainter constructor | receives showChords flag to conditionally skip _drawChords | ✓ WIRED | Constructor accepts showChords parameter (line 31). Used in conditional at line 98. |
| settings_screen.dart | settingsNotifier | reads viewConfigProvider, writes via setPreset | ✓ WIRED | Line 16: watches settingsProvider. Lines 149, 159, 169: calls settingsNotifier.setPreset. |
| settings_provider.dart | settings_repository.dart | SettingsNotifier reads/writes ViewConfig through repository | ✓ WIRED | Line 43: calls repository.getViewConfig(). Lines 54-58: setViewConfig calls repository.setViewConfig. |
| song_provider.dart | settings_provider.dart | SongViewNotifier.openSong resolves active config from global default + per-song override | ✓ WIRED | Line 63: reads settingsRepositoryProvider. Line 64: calls repository.getSongViewConfig(). |
| settings_repository.dart | local_datasource.dart | SharedPreferences via LocalDataSource get/set methods | ✓ WIRED | Lines 71, 79: calls _localDataSource get/setStringSetting. Line 101: calls removeStringSetting. |

**Score:** 7/7 key links verified

### Requirements Coverage

Phase 2 maps to [REQ-04] from REQUIREMENTS.md: Configurable merged view

| Requirement | Status | Evidence |
|-------------|--------|----------|
| REQ-04: Users can toggle notation/chords visibility independently | ✓ SATISFIED | All truths verified. ViewConfig model supports 4 valid states via 2 toggles. UI provides toggle buttons in floating menu. |

**Score:** 1/1 requirement satisfied

### Anti-Patterns Found

**Scan of modified files (9 files from SUMMARYs):**

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| settings_screen.dart | 124,125,147,148,157,158,167,168 | RadioListTile deprecated API | Info | Flutter 3.32+ deprecation warnings. No functional impact. Future migration to RadioGroup needed. |

**Summary:**
- 0 Blockers
- 0 Warnings
- 8 Info items (deprecation warnings, no functional impact)

### Human Verification Required

Since this is a Flutter UI feature with complex visual states, the following aspects cannot be fully verified programmatically and require human testing:

#### 1. Visual Toggle State Feedback

**Test:** Open a song, expand floating menu, tap notation toggle and chords toggle buttons.
**Expected:** Active toggles should be visually highlighted (different background color/elevation). Tapping should immediately change the view rendering.
**Why human:** Visual appearance and immediate responsiveness cannot be verified by code inspection alone.

#### 2. Four View State Rendering

**Test:** Use toggles/presets to cycle through all 4 view combinations: Sheet Music preset (notation + chords + lyrics), Chords preset (chords + lyrics, no notation), Lyrics preset (lyrics only), Custom (notation + lyrics, no chords).
**Expected:** Each state renders correctly with appropriate layout. Lyrics are always visible. No empty or broken views.
**Why human:** Visual layout correctness and absence of rendering bugs require human inspection.

#### 3. Per-Song Override Persistence

**Test:** (1) Open song #42, change view config (2) Navigate to home, then back to song #42 (3) Verify view reverts to global default (4) Change view config again, explicitly save it (5) Navigate away and back - verify saved config persists.
**Expected:** Temporary changes revert on navigation. Explicitly saved configs persist across sessions.
**Why human:** Requires multi-step user flow and navigation testing.

#### 4. Settings Screen Global Default

**Test:** (1) Open Settings > Default View (2) Select a preset (e.g., Chords) (3) Go back to song list, open a new song (4) Verify song opens with the new default preset.
**Expected:** Global default applies to songs without per-song overrides.
**Why human:** Requires UI interaction flow and state propagation across screens.

#### 5. Floating Menu Scrollability

**Test:** Open song on a small device (or simulate viewport 360x640). Expand floating menu.
**Expected:** Menu should be scrollable if it exceeds viewport height. No overflow warnings.
**Why human:** Viewport-specific behavior. The fix was added in commit b634a92, but needs confirmation on actual small devices.

#### 6. Chord Rendering Above Staff

**Test:** Open a song with notation, ensure Sheet Music preset is active (notation + chords).
**Expected:** Chord symbols appear above the staff, aligned with beat positions. Lyrics appear below the staff. No visual overlap or misalignment.
**Why human:** Spatial positioning and visual alignment cannot be verified by code alone.

## Gaps Summary

**No gaps found.** All must-haves verified. Phase goal achieved.

## Next Steps

1. **Human verification recommended** for the 6 items listed above. Estimated time: 10-15 minutes of manual testing.
2. **Optional follow-ups** (not blocking):
   - Add unit tests for ViewConfig serialization round-trip
   - Add widget tests for floating menu toggle interactions
   - Migrate settings_screen.dart RadioListTile to RadioGroup (Flutter 3.32+ API)
   - Consider migration path for existing users old view_mode setting

---

_Verified: 2026-02-14T17:00:46Z_
_Verifier: Claude (gsd-verifier)_
