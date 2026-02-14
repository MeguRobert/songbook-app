# Phase 2: Configurable Song View - Context

**Gathered:** 2026-02-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the current two separate views (chord view and sheet music view) with a single unified view where users toggle notation and chords independently. Lyrics are always present — this is a songbook, not a music notation app. The view supports 4 valid states through 2 toggles (notation on/off, chords on/off) plus 3 quick presets.

</domain>

<decisions>
## Implementation Decisions

### Toggle model
- Lyrics are **always visible** — not a toggle. They are the base layer of every view.
- Two toggles: **Notation** (sheet music staff on/off) and **Chords** (chord symbols on/off)
- 4 valid combinations: lyrics only, lyrics+chords, lyrics+notation, lyrics+notation+chords
- Default for new users: **all three on** (notation + chords + lyrics)
- No empty state possible — lyrics are always present

### Merged rendering
- When notation is ON: chord symbols appear **above the staff**, aligned with the beat position
- When notation is ON: lyrics adapt styling to fit notation context (can be smaller/different to work with staff spacing)
- When notation is OFF: lyrics display at normal standalone size
- When notation is OFF + chords ON: **new unified layout** (not the old chord view) — Claude has discretion on the specific chord+lyrics layout design (inline above syllables vs chord bar rows, etc.)

### Control design
- Toggles live in the **existing floating controls menu** (alongside text size, transpose)
- Toggle style: **icon buttons** that highlight when active (compact, tappable)
- 3 quick **preset modes** alongside the toggles:
  - **Sheet Music**: notation + chords ON (full view)
  - **Chords**: chords ON, notation OFF (chord sheet)
  - **Lyrics**: both OFF (clean lyrics only)
- Presets set the toggles; toggles can be adjusted independently after selecting a preset

### Persistence
- **Global default** configurable in the Settings screen (alongside theme, text size, etc.)
- **Per-song override** with explicit save — changing toggles while viewing a song is temporary unless the user explicitly saves ("Save for this song")
- Temporary changes revert to global default when navigating away
- Per-song overrides stored separately from global settings

### Claude's Discretion
- Chord+lyrics layout design when notation is off (inline chords vs chord bar rows)
- Exact icon choices for notation and chords toggle buttons
- Preset button visual design (segmented control, chips, icons)
- Per-song override reset behavior (explicit reset button vs just re-toggle)
- Lyrics styling adaptation when under notation (font size, weight, spacing)
- Transition/animation when toggling views

</decisions>

<specifics>
## Specific Ideas

- The 3 presets (Sheet Music / Chords / Lyrics) map to the most common musician workflows: reading full notation, leading worship with chord sheets, projecting lyrics for congregation
- Icon buttons should be immediately recognizable — a music note for notation, a chord symbol for chords
- The floating menu already has text size (A+/A-) and transpose controls; view toggles should feel like a natural extension

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-configurable-song-view*
*Context gathered: 2026-02-14*
