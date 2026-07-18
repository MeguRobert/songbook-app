---
status: diagnosed
trigger: "With text size increase it would be nice that the musical sheet could be sized as well, not only the text and chord modes"
created: 2026-07-18T00:00:00Z
updated: 2026-07-18T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED - textScale is never passed to the sheet music path; notation dimensions derive from a compile-time constant (staffLineSpacing = 10.0)
test: Traced textScale from controls -> provider -> views; traced sheet music sizing from renderer -> layout engine -> EngravingConstants
expecting: n/a (root cause confirmed)
next_action: Return diagnosis (goal: find_root_cause_only)

## Symptoms

expected: Increasing text size via A+ (or pinch-to-zoom) also scales the rendered sheet music notation, so the whole song view grows/shrinks together.
actual: Text/chord views scale, sheet music notation does not.
errors: None
reproduction: Test 5 in UAT - open song with sheet music, Sheet Music view, FAB, A+ - notation size unchanged.
started: Discovered during Phase 4 UAT (Controls UI Redesign)

## Eliminated

- hypothesis: A-/A+ modifies persistent settings fontSize (settingsProvider) which sheet music could read
  evidence: song_controls_sheet.dart:226,244 call songViewNotifier.decreaseTextScale/increaseTextScale, which mutate per-song textScale in song_provider.dart:108-128 (clamped 0.5-2.0), NOT settings fontSize. fontSizeProvider is a separate persistent base size used only by chord_view (line 29-30) and legacy plain verses.
  timestamp: 2026-07-18

## Evidence

- timestamp: 2026-07-18
  checked: song_provider.dart:108-128, 208-210
  found: textScale lives on per-song SongViewState; increaseTextScale/decreaseTextScale/setTextScale (pinch) all update it; exposed via textScaleProvider
  implication: The scale value exists and updates correctly - the bug is in consumption, not production

- timestamp: 2026-07-18
  checked: song_view_screen.dart:105-127
  found: ChordView receives textScale (lines 118, 125); SheetMusicView (lines 108-113) receives only song/transpose/showChords - no textScale. Pinch gesture (lines 91-104) also just sets textScale, which sheet music ignores.
  implication: Scale factor never enters the sheet music widget tree

- timestamp: 2026-07-18
  checked: sheet_music_view.dart (SheetMusicViewWidget)
  found: Widget has no textScale field. Watches fontSizeProvider but only applies it to legacy plain-text verses (line 307). Custom render path builds SheetMusicRenderer(song, notation, transpose, showChords) - no size parameter exists on SheetMusicRenderer at all. Custom path also has NO InteractiveViewer (only legacy SVG path does, line 96), so pinch-zoom of notation is unavailable too.
  implication: Both the provider value and any pinch affordance are absent from the custom Canvas render path

- timestamp: 2026-07-18
  checked: sheet_music_renderer.dart:134-186
  found: LayoutBuilder passes constraints.maxWidth as availableWidth to SheetMusicLayoutEngine; canvas is SizedBox(width: layout.totalWidth, height: layout.totalHeight) with CustomPaint. availableWidth only controls line wrapping (measures per system), not glyph size.
  implication: Notation view is fixed-size content in a SingleChildScrollView, sized by layout output

- timestamp: 2026-07-18
  checked: engraving_constants.dart:15, sheet_music_layout.dart:156-249
  found: ALL notation dimensions (staff height, note heads, stems, clef font, chord/lyric font sizes, margins, spacing) derive from `static const double staffLineSpacing = 10.0` via static getters on EngravingConstants. No instance state, no scale parameter anywhere in the engraving/layout/painter chain.
  implication: Notation renders at one absolute size baked in at compile time; there is no plumbing for any scale factor

## Resolution

root_cause: The per-song textScale (set by A-/A+ and pinch, stored in songViewProvider) is consumed only by ChordView. The sheet music path ignores it at every level: (1) song_view_screen.dart does not pass textScale to SheetMusicView; (2) SheetMusicViewWidget/SheetMusicRenderer have no scale parameter; (3) all notation geometry derives from the compile-time constant EngravingConstants.staffLineSpacing = 10.0 via static getters, so the layout engine and painter cannot scale even if given the value. Additionally, the custom Canvas path lacks the InteractiveViewer that the legacy SVG path has, so pinch-zoom does not work there either.
fix: (not applied - diagnose-only) Suggested: thread textScale into SheetMusicRenderer; simplest robust approach is to lay out at availableWidth / textScale and apply canvas.scale(textScale) in SheetMusicPainter (sizing the CustomPaint SizedBox by layout.totalWidth * textScale / totalHeight * textScale). This preserves correct line wrapping and stays vector-crisp. Alternative deeper refactor: make EngravingConstants instance-based with staffSpace = 10.0 * scale.
verification:
files_changed: []
