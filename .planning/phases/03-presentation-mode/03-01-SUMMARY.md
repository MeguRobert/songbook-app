---
phase: 03
plan: 01
subsystem: presentation
status: complete
tags: [ui, flutter, presentation-mode, full-screen]

requires:
  - phase: 02
    plan: all
    reason: Builds on song view infrastructure and ViewConfig patterns

provides:
  - artifact: PresentationScreen
    capability: Full-screen verse-by-verse lyrics display with auto-scaling
  - artifact: Presentation route
    capability: Deep-linkable /presentation/:id route
  - artifact: Presentation mode entry point
    capability: Launch from floating controls menu

affects:
  - phase: 03
    plan: 02-03
    note: Future plans will add chord transposition, setlist navigation, and remote control

tech-stack:
  added:
    - SystemChrome.setEnabledSystemUIMode for immersive mode
    - PageView for verse-by-verse swiping
  patterns:
    - Tap zone navigation (left/right/center thirds)
    - Auto-hide controls with Timer
    - Auto-scaling text based on character width heuristics
    - Dark projection theme toggle

key-files:
  created:
    - songbook_app/lib/presentation/screens/presentation/presentation_screen.dart
  modified:
    - songbook_app/lib/router/app_router.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/floating_controls_menu.dart

decisions:
  - id: 03-01-immersive-ui
    decision: Use SystemUiMode.immersiveSticky for full-screen presentation
    rationale: Standard Flutter approach for hiding status/nav bars during immersive experiences
    alternatives: SystemUiMode.immersive (with visible swipe indicators)

  - id: 03-01-verse-navigation
    decision: PageView for verse-by-verse display with tap zone navigation
    rationale: Native swipe support + custom tap zones for keyboard-free operation during worship
    alternatives: Manual GestureDetector only (less intuitive for swipe)

  - id: 03-01-auto-scaling
    decision: Heuristic-based font scaling (availableWidth / longestLine * 0.55) clamped 24-120px
    rationale: Simple calculation that works well for typical verse lengths, with FittedBox safety net
    alternatives: Fixed font sizes per device class, manual text size controls

  - id: 03-01-projection-theme
    decision: Local state toggle for projection mode (black bg, white text) vs app theme
    rationale: Projection needs high contrast regardless of app theme; local state avoids provider complexity
    alternatives: Add projection theme to settings provider (over-engineered for this use case)

  - id: 03-01-controls-behavior
    decision: Auto-hide controls after 3s, center tap toggles visibility
    rationale: Keeps screen clean during presentation, easy to bring back without accidental navigation
    alternatives: Always show minimal controls (visual clutter), swipe down to show (less discoverable)

metrics:
  duration: 3 minutes
  completed: 2026-02-14

---

# Phase 03 Plan 01: Presentation Mode Core Summary

**One-liner:** Full-screen immersive presentation mode with verse-by-verse navigation, auto-scaling text, and projection theme toggle

## What Was Built

Implemented core presentation mode functionality:

1. **PresentationScreen** - Full-screen immersive widget
   - SystemUiMode.immersiveSticky to hide status/nav bars
   - PageView for horizontal verse navigation
   - SafeArea wrapper for notch safety
   - Title card (song number + title) as first page
   - Each verse as subsequent page with auto-scaled text

2. **Auto-scaling text** - Fills screen width for readability at distance
   - Heuristic: `fontSize = availableWidth / (longestLineCharCount * 0.55)`
   - Clamped between 24-120px
   - FittedBox safety net prevents overflow
   - Verse number displayed above text (subtle, 40% of font size)

3. **Dark projection theme** - Toggle for high-contrast projection
   - Projection mode: black background, white text
   - Normal mode: respects app theme (light/dark)
   - Local state toggle (not persisted)
   - Sun/moon icon button in top-right

4. **Tap zone navigation**
   - Left 1/3 of screen: previous verse
   - Right 1/3 of screen: next verse
   - Center 1/3 of screen: toggle controls visibility
   - Native PageView swipe also works

5. **Auto-hide controls** - Clean screen during presentation
   - Controls fade out after 3 seconds of no interaction
   - Center tap always brings controls back
   - Exit button (top-left), projection toggle (top-right), page indicator (bottom)

6. **Routing integration**
   - `/presentation/:id` route in app_router.dart
   - `presentationPath(id)` helper method
   - Fullscreen icon button at top of floating controls menu
   - Navigates via `context.push()`

7. **Enhanced _MenuButton** - Support icons + labels
   - Optional icon or label display
   - Optional tooltip support
   - Used for presentation mode launcher

## Verification

✅ All success criteria met:

1. ✅ PresentationScreen created as ConsumerStatefulWidget with songNumber parameter
2. ✅ Watches songByNumberProvider for data
3. ✅ SystemUiMode.immersiveSticky in initState, restored in dispose
4. ✅ PageView.builder with verse-by-verse pages plus title card
5. ✅ Auto-scaling text based on longest line length (24-120px range)
6. ✅ FittedBox safety net for overflow prevention
7. ✅ Projection mode toggle (black/white) with state management
8. ✅ Tap zones for left/right/center navigation
9. ✅ Auto-hide controls after 3 seconds with AnimatedOpacity
10. ✅ Exit button, projection toggle, and page indicator in overlay
11. ✅ Route added to app_router.dart with helper method
12. ✅ Fullscreen button in floating controls menu
13. ✅ Navigation via context.push() with song number
14. ✅ Flutter analyze passes (only pre-existing RadioListTile warnings)

## Deviations from Plan

**None** - Plan executed exactly as written.

## Technical Decisions Made

### 1. Immersive UI Mode
**Decision:** Use `SystemUiMode.immersiveSticky` for presentation mode

**Context:** Need to hide status bar and navigation bar for distraction-free worship display

**Chosen approach:**
- Set `SystemUiMode.immersiveSticky` in initState
- Restore `SystemUiMode.edgeToEdge` in dispose
- SafeArea wrapper for notch/status bar safety

**Rationale:**
- Standard Flutter pattern for immersive experiences
- `.immersiveSticky` keeps bars hidden even after swipe gestures
- Automatic restoration on screen exit prevents system UI confusion

**Alternatives considered:**
- `SystemUiMode.immersive` - shows swipe indicators, less clean
- No system UI changes - status bar visible, distracting during worship

### 2. Verse Navigation Pattern
**Decision:** PageView with tap zone overlay for keyboard-free operation

**Context:** Need swipe and tap navigation for use during live worship (hands may not be fully free)

**Chosen approach:**
- PageView.builder for native horizontal swipe
- GestureDetector overlay with 3 tap zones (left/right/center thirds)
- Animated page transitions (300ms, easeInOut)

**Rationale:**
- PageView gives expected swipe behavior for free
- Tap zones enable one-handed operation (thumb navigation)
- Center tap for controls avoids accidental page changes
- Standard mobile UX pattern (similar to ebook readers)

**Alternatives considered:**
- GestureDetector only (no swipe, less intuitive)
- Edge swipe only (harder to trigger during live use)
- Hardware button mapping (platform-specific, complex)

### 3. Auto-scaling Heuristic
**Decision:** `fontSize = availableWidth / (longestLineCharCount * 0.55)` clamped 24-120

**Context:** Lyrics must be readable from 10-20 feet away on projectors/large screens

**Chosen approach:**
- Calculate longest line in verse (character count)
- Divide available width by `longestLine * 0.55` (character width estimate)
- Clamp between 24px (minimum legibility) and 120px (maximum screen usage)
- FittedBox with `fit: BoxFit.scaleDown` as safety net

**Rationale:**
- Simple calculation, no complex text measurement
- Works well for typical verse lengths (4-8 lines, 20-60 chars/line)
- 0.55 coefficient accounts for average character width in proportional fonts
- Clamps prevent edge cases (1-word verses, paragraph-length verses)
- FittedBox prevents overflow if heuristic fails

**Alternatives considered:**
- Fixed font sizes per device class (doesn't adapt to verse length)
- TextPainter measurement (more accurate but complex, performance cost)
- Manual text size controls (requires user adjustment per verse)

### 4. Projection Theme Design
**Decision:** Local state toggle (black/white) vs app theme

**Context:** Projection environments need high contrast regardless of user's app theme preference

**Chosen approach:**
- Local state: `bool _projectionMode = false`
- When ON: force black background + white text
- When OFF: respect app's theme (light or dark)
- Not persisted (resets per session)

**Rationale:**
- Projection needs predictable contrast (can't rely on device theme)
- Local state simpler than adding to settings provider
- Per-session toggle appropriate (projection setups change per service)
- Sun/moon icon clear affordance

**Alternatives considered:**
- Add projection mode to settings provider (over-engineered, adds persistence complexity)
- Always use black/white (ignores app theme for non-projection use)
- Detect ambient light sensor (hardware-dependent, unreliable)

### 5. Controls Auto-Hide Behavior
**Decision:** Fade out after 3s of no interaction, center tap to toggle

**Context:** Need clean screen during presentation but easy access to controls when needed

**Chosen approach:**
- Timer starts on any interaction
- After 3 seconds, AnimatedOpacity fades controls to 0
- Center tap always toggles visibility
- Overlay with IgnorePointer when hidden (prevents ghost taps)

**Rationale:**
- 3 seconds gives time to read controls before they disappear
- Center tap safe from accidental navigation (not in left/right tap zones)
- AnimatedOpacity smooth and performant
- Standard pattern (video players, presentation apps)

**Alternatives considered:**
- Always show minimal controls (visual clutter during worship)
- Swipe down from top to show (less discoverable, conflicts with system gestures)
- Double-tap center (slower, less intuitive)
- Never hide (distracting during presentation)

## Known Issues

None.

## Next Phase Readiness

**Phase 03 Plan 02 (Chord Transposition in Presentation)** is ready to proceed.

**Current state:**
- ✅ Presentation mode established with verse display
- ✅ Route and navigation integration complete
- ✅ Auto-scaling text working for lyrics

**Requirements for next plan:**
- Chord rendering in presentation mode (extend auto-scaling to chord+lyric layout)
- Transpose state propagation from song view to presentation
- Chord display toggle in presentation controls

**Potential blockers:** None identified

## Files Changed

**Created:**
- `songbook_app/lib/presentation/screens/presentation/presentation_screen.dart` (367 lines)

**Modified:**
- `songbook_app/lib/router/app_router.dart` (+15 lines)
  - Added `/presentation/:id` route
  - Added `presentationPath(id)` helper
  - Imported PresentationScreen

- `songbook_app/lib/presentation/screens/song_view/widgets/floating_controls_menu.dart` (+43 lines)
  - Added presentation mode button at top of expanded menu
  - Enhanced _MenuButton to support icons + tooltips
  - Imported go_router and app_router

## Commits

- `012d44f` - feat(03-01): create presentation screen with verse navigation and auto-scaling
- `5a6eb8c` - feat(03-01): add presentation route and floating menu entry point

---

**Duration:** 3 minutes
**Tasks completed:** 2/2
**Status:** ✅ Complete
