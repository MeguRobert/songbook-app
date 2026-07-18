---
status: diagnosed
trigger: "Custom button does nothing useful. I think we can get rid of that"
created: 2026-07-18T00:00:00Z
updated: 2026-07-18T00:20:00Z
---

## Current Focus

hypothesis: CONFIRMED — Custom is architecturally redundant (state space of 4, presets cover 3) AND its entry logic is broken from 2 of 3 preset states
test: Enumerated ViewConfig state machine; traced Custom chip onSelected -> toggleNotation() transitions
expecting: n/a
next_action: Return diagnosis (goal: find_root_cause_only)

## Symptoms

expected: Selecting "Custom" expands two SwitchListTiles (Show Notation, Show Chords) adding value beyond the three presets
actual: "Custom button does nothing useful. I think we can get rid of that" — presets already cover useful combinations
errors: None
reproduction: UAT Test 3 — open song, tap FAB (tune icon), View section of bottom sheet
started: Phase 4 UAT (Controls UI Redesign)

## Eliminated

- hypothesis: Custom toggles are wired incorrectly (call wrong provider methods)
  evidence: song_controls_sheet.dart:146-163 correctly call songViewNotifier.toggleNotation()/toggleChords(); song_provider.dart:150-165 correctly flip flags via copyWith. Wiring is fine; the design is the problem.
  timestamp: 2026-07-18

## Evidence

- timestamp: 2026-07-18
  checked: lib/data/models/view_config.dart
  found: ViewConfig = 2 bools (showNotation, showChords) = exactly 4 states. Presets: sheetMusic (T,T), chords (F,T), lyricsOnly (F,F). Only unique "custom" state is (T,F) = isNotationWithoutChords (line 43).
  implication: Custom mode's entire value proposition is one state: notation without chords. It is a disguised 4th preset, not a customization surface.

- timestamp: 2026-07-18
  checked: song_controls_sheet.dart:42-45, 126-136 (Custom chip entry logic)
  found: isCustomSelected = "not any preset". Tapping Custom calls toggleNotation(). Transitions: from Sheet Music (T,T) -> (F,T) = Chords preset (Custom never engages); from Chords (F,T) -> (T,T) = Sheet Music preset (Custom never engages); only from Lyrics (F,F) -> (T,F) does Custom actually select and show toggles.
  implication: In 2 of 3 entry cases, tapping Custom silently swaps between Sheet Music and Chords presets and the toggles never appear — literally "does nothing useful" as reported.

- timestamp: 2026-07-18
  checked: song_controls_sheet.dart:139-167 (AnimatedSize toggle section)
  found: Toggles only render while isCustomSelected. From the single custom state (T,F), flipping EITHER switch lands on a preset state, which collapses the section immediately.
  implication: The toggles can only ever exit custom mode; they cannot compose anything. Custom mode is a one-state dead end.

- timestamp: 2026-07-18
  checked: Usage graph of custom-only code (grep toggleNotation|toggleChords|isNotationWithoutChords across lib/ and test/)
  found: song_provider.toggleNotation/toggleChords called ONLY from song_controls_sheet.dart. settings_provider.toggleNotation/toggleChords (settings_provider.dart:60-67) called from NOWHERE in lib/ (only tests). isNotationWithoutChords used only in settings_screen.dart:111 label fallback and view_config_test.dart. No widget test exists for song_controls_sheet.
  implication: Removal is contained; several methods become dead code.

- timestamp: 2026-07-18
  checked: Persistence (view_config.dart:60-79 toStorageString/fromStorageString)
  found: Storage format "notation:chords" can encode "true:false"; fromStorageString will happily reconstruct the (T,F) state from previously persisted overrides/defaults.
  implication: After UI removal, (T,F) becomes unreachable via UI but still loadable from old persisted data. Settings label fallback (settings_screen.dart:111-112, 182) should remain or state should be normalized on load.

## Resolution

root_cause: The Custom view option is a design-level dead end, not a wiring bug. (1) ViewConfig's state space is only 4 combinations and the 3 presets cover 3 of them, so Custom's sole unique state is showNotation=true/showChords=false. (2) The Custom chip's entry logic (song_controls_sheet.dart:129-135, tap -> toggleNotation) only reaches that state from the Lyrics preset; from Sheet Music or Chords it just swaps to the other preset and the toggles never appear. (3) Even when engaged, flipping either toggle exits custom mode and collapses the section. Custom therefore adds clutter and confusing behavior with no composable value.
fix: (direction only — find_root_cause_only) Remove Custom chip + AnimatedSize toggle block from song_controls_sheet.dart (lines 42-45, 123-167); delete now-dead toggleNotation/toggleChords in song_provider.dart (150-165) and settings_provider.dart (60-67) plus their unit tests; optionally remove ViewConfig.isNotationWithoutChords or keep it for the settings label fallback that guards old persisted "true:false" values.
verification:
files_changed: []
