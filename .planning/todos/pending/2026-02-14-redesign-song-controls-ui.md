---
created: 2026-02-14T21:30
title: Redesign song controls UI
area: ui
files:
  - lib/presentation/widgets/floating_controls_menu.dart
  - lib/presentation/screens/song_view_screen.dart
  - lib/presentation/screens/settings_screen.dart
---

## Problem

The floating controls menu has grown to 12 interactive elements in a 48px-wide vertical column,
making it overwhelming on phone screens. Controls grew organically across Phases 1-3 with
redundancy between presets and individual toggles, and cryptic single-letter labels (C, T, C7).

## Solution

Replace the vertical sidebar with a **bottom sheet** pattern:

**Key decisions (user-confirmed):**
1. **Bottom Sheet**: FAB (tune icon) opens a Material bottom sheet with labeled, grouped sections
2. **Pinch-to-zoom + A+/A-**: Add pinch-to-zoom gesture for text scaling, keep A+/A- inside sheet
3. **Custom view option**: Remove individual notation/chords toggles from main view, keep accessible
   behind a "Custom" option for power users (3 presets remain primary)
4. **Presentation mode → app bar**: Move fullscreen button to app bar (alongside favorite heart)

**Bottom sheet layout concept:**
- View section: 3 preset chips (Sheet Music | Chords | Lyrics) + Custom option
- Transpose section: +/- buttons with key display and reset
- Text section: A+/A- with current scale display
- Clean labels, not just icons

**Result:** Visible controls drop from 12 to a single FAB + 1 app bar icon. Sheet opens on demand
with clear, labeled, grouped controls.
