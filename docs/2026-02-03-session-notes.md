# Session Notes - 2026-02-03

## What We Did Today

### 1. Added Sheet Music from Images (OCR/OMR)
- Created `/add-song` skill for adding songs from sheet music images
- Used Audiveris for OMR (Optical Music Recognition) and EasyOCR for lyrics with Hungarian support
- Added notation for **Song 42** (Psalm 42) with stacked lyrics and repeat bars
- Added notation for **Song 256** ("Eros var a mi Istenunk") with stacked lyrics

### 2. Stacked Lyrics Support
- Added `syllables` array to notation model for multiple verse lines under same melody
- Updated layout engine to position syllables vertically (18px spacing per line)
- Fixed hyphen drawing to only connect syllables on same line index

### 3. Repeat Bar Rendering
- Added `repeatEnd` flag to measures in notation JSON
- Implemented repeat bar rendering with proper dots placement in painter

### 4. Sheet Music Layout Improvements
- Centered sheet music canvas
- Made all systems uniform width (normalized to widest system)
- Moved final bar line to right edge of each system
- Replaced drag-to-pan with proper Scrollbar + SingleChildScrollView
- Added ScrollController to fix scrollbar errors

### 5. Transpose Controls in App Bar
- Moved transpose controls from body to app bar
- Implemented 5 different styles:
  - `compact` - +/- buttons visible directly in app bar
  - `bottomSheet` - tune icon opens bottom sheet
  - `popupMenu` - tune icon opens persistent popup/sidebar
  - `keyBadge` - key pill badge opens dialog
  - `dropdown` - direct key selector dropdown

### 6. Popup Menu Improvements
- Made popup stay open after transpose actions (not auto-dismiss)
- Added real-time key update using Riverpod `transposeProvider`
- Converted to right sidebar panel with slide-in animation

## Commits Made
1. `af95670` - Add song 42 notation with stacked lyrics and repeat bars
2. `46e10a9` - Improve sheet music layout: centered, uniform width, scrollable
3. `fd0c68e` - Add song 256 notation and fix Scrollbar controller
4. `3886252` - Add transpose controls to app bar with multiple style options

---

## Next Ideas / TODOs

1. **Test transpose and adjust** - Continue testing the sidebar transpose UI and refine as needed

2. **Center chord view** - Put the chords view in the middle like the sheet music canvas

3. **Merged view for sheets and chords** - Create a combined view showing both sheet music and chords, with easily adjustable settings

4. **Text size adjuster** - Add controls for smaller/bigger text sizing

5. **Lyrics only mode** - Add a projection-friendly mode for displaying lyrics on monitors or canvases in churches

6. **Easier song import** - Add a streamlined way to import songs (possibly batch import, drag-and-drop, etc.)

7. **Song folders/grouping** - Add ability to organize songs into folders or groups (e.g., by theme, service, event)
