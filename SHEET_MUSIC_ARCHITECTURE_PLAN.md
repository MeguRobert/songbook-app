# Sheet Music Architecture Plan

## Problem Analysis

Current implementation issues:
1. **Static SVG approach** - Hand-crafted SVGs are fragile, hard to maintain, and don't scale
2. **Syllable misalignment** - Manual positioning doesn't guarantee syllables align under notes
3. **Font rendering issues** - Unicode musical symbols don't render reliably across platforms
4. **No transposition support** - SVGs would need to be regenerated for each key
5. **Maintenance burden** - Creating SVGs for 500+ songs is impractical

## Available Approaches

### Option 1: Native Flutter Package (simple_sheet_music)

**Pros:**
- Pure Dart/Flutter - no WebView overhead
- Direct integration with Flutter widgets
- Supports basic notation elements

**Cons:**
- Limited feature set (no lyrics support yet)
- Relatively new, less battle-tested
- May require significant extension for lyrics alignment

**Verdict:** Not mature enough for production use with lyrics.

---

### Option 2: WebView + VexFlow/OSMD

**Pros:**
- VexFlow is the industry standard for web music notation
- OpenSheetMusicDisplay handles MusicXML parsing + VexFlow rendering
- Rich feature set including lyrics, dynamics, articulations
- Active community and maintenance
- Supports transposition programmatically

**Cons:**
- WebView adds complexity and overhead
- JavaScript↔Flutter communication needed
- May have performance issues with many songs
- Larger app size

**Verdict:** Powerful but adds significant complexity.

---

### Option 3: LilyPond Pre-rendering Pipeline

**Pros:**
- Highest quality music engraving (publication quality)
- Perfect syllable alignment (built-in lyric support)
- Supports all musical notation features
- Can generate SVG, PNG, PDF
- Text-based source format (version controllable)

**Cons:**
- Requires build-time processing (LilyPond tool)
- Transposition requires regenerating files
- External dependency for content creation

**Verdict:** Best quality, ideal for a build pipeline.

---

### Option 4: Hybrid Custom Renderer (RECOMMENDED)

Build a custom Flutter widget that:
- Parses a structured data format (JSON/YAML)
- Uses CustomPainter to draw notation
- Handles lyrics alignment algorithmically
- Supports real-time transposition

**Pros:**
- Full control over rendering
- Native performance
- Data-driven (easy to maintain songs as data)
- Real-time transposition without regenerating assets
- Proper syllable-to-note alignment guaranteed

**Cons:**
- More development effort upfront
- Need to implement music notation rules

**Verdict:** Best balance of control, performance, and maintainability.

---

## Recommended Architecture: Option 4 (Hybrid Custom Renderer)

### Data Model

```dart
// Song data structure with notation
class SongNotation {
  final int number;
  final String title;
  final String originalKey;
  final String timeSignature;
  final List<NotatedVerse> verses;
}

class NotatedVerse {
  final int number;
  final List<NotatedMeasure> measures;
}

class NotatedMeasure {
  final List<NotatedBeat> beats;
}

class NotatedBeat {
  final String pitch;      // e.g., "C4", "D#5", "Bb3"
  final Duration duration; // quarter, eighth, etc.
  final String? syllable;  // The lyric syllable for this note
  final String? chord;     // Chord symbol above (optional)
  final bool tieStart;
  final bool tieEnd;
}
```

### JSON Song Format

```json
{
  "number": 151,
  "title": "Hatalmas Isten, nagy haragodban",
  "originalKey": "Bb",
  "timeSignature": "4/4",
  "verses": [
    {
      "number": 1,
      "measures": [
        {
          "beats": [
            {"pitch": "Bb4", "duration": "quarter", "syllable": "Ha-", "chord": "Bb"},
            {"pitch": "C5", "duration": "quarter", "syllable": "tal-"},
            {"pitch": "D5", "duration": "quarter", "syllable": "mas"},
            {"pitch": "C5", "duration": "quarter", "syllable": "Is-"}
          ]
        },
        {
          "beats": [
            {"pitch": "Bb4", "duration": "quarter", "syllable": "ten,", "chord": "F"},
            {"pitch": "A4", "duration": "quarter", "syllable": "nagy"},
            {"pitch": "Bb4", "duration": "quarter", "syllable": "ha-"},
            {"pitch": "C5", "duration": "quarter", "syllable": "ra-"}
          ]
        }
      ]
    }
  ]
}
```

### Rendering Engine Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SheetMusicWidget                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              SheetMusicController                         │  │
│  │  - currentKey (transposed)                                │  │
│  │  - zoomLevel                                              │  │
│  │  - scrollPosition                                         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              SheetMusicLayoutEngine                       │  │
│  │  - calculateNotePositions()                               │  │
│  │  - alignSyllablesToNotes()  ← KEY: Algorithmic alignment  │  │
│  │  - calculateStaffLines()                                  │  │
│  │  - handleLineBreaks()                                     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              SheetMusicPainter (CustomPainter)            │  │
│  │  - drawStaffLines()                                       │  │
│  │  - drawClef()                                             │  │
│  │  - drawKeySignature()                                     │  │
│  │  - drawTimeSignature()                                    │  │
│  │  - drawNotes()                                            │  │
│  │  - drawLyrics()  ← Positioned from layout engine          │  │
│  │  - drawChords()                                           │  │
│  │  - drawBarLines()                                         │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

#### 1. Music Symbol Font
Use **Bravura** or **Leland** (open-source SMuFL fonts) for consistent music symbols:
- Clefs, noteheads, accidentals, rests
- Load as asset font in Flutter

#### 2. Layout Engine
Implements music engraving rules:
- **Note spacing**: Based on duration (longer notes = more space)
- **Syllable centering**: Each syllable centered under its note
- **Hyphen placement**: Centered between syllables of same word
- **Melisma lines**: Underscore extending through held notes
- **Line breaking**: Intelligent breaks at measure boundaries

#### 3. Transposition Service (Already Exists)
Reuse existing `TranspositionService` to:
- Transpose pitches in real-time
- Update chord symbols
- Recalculate accidentals for new key

### Syllable Alignment Algorithm

```dart
/// Aligns syllables to their corresponding notes
class SyllableAligner {
  List<PositionedSyllable> alignSyllables(
    List<PositionedNote> notes,
    TextStyle lyricStyle,
  ) {
    final result = <PositionedSyllable>[];

    for (final note in notes) {
      if (note.syllable == null) continue;

      final textPainter = TextPainter(
        text: TextSpan(text: note.syllable, style: lyricStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      // Center syllable horizontally under note
      final syllableX = note.x + (note.width / 2) - (textPainter.width / 2);
      final syllableY = note.staffBottom + LYRIC_OFFSET;

      result.add(PositionedSyllable(
        text: note.syllable!,
        x: syllableX,
        y: syllableY,
        width: textPainter.width,
        isWordEnd: !note.syllable!.endsWith('-'),
      ));
    }

    // Add hyphens between syllables of same word
    _addHyphens(result);

    return result;
  }
}
```

### Implementation Phases

#### Phase 1: Core Rendering (MVP)
- [ ] Create SMuFL font integration (Bravura)
- [ ] Implement basic CustomPainter for staff lines
- [ ] Draw clefs, time signatures
- [ ] Draw quarter/half/whole notes
- [ ] Basic syllable alignment

#### Phase 2: Full Notation
- [ ] Eighth notes with beams
- [ ] Accidentals (sharps, flats, naturals)
- [ ] Key signatures
- [ ] Ties and slurs
- [ ] Rests

#### Phase 3: Lyrics & Polish
- [ ] Hyphen placement between syllables
- [ ] Melisma/extender lines
- [ ] Chord symbols above staff
- [ ] Multi-line layout with automatic breaks
- [ ] Zoom and pan

#### Phase 4: Data Migration
- [ ] Create JSON schema for notation data
- [ ] Convert existing songs to new format
- [ ] Build validation tooling

---

## Alternative: Quick Win with LilyPond Pipeline

If custom rendering is too much effort, a pragmatic alternative:

### Build-Time Pipeline

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  songs.yaml  │ ──▶ │   LilyPond   │ ──▶ │   SVGs per   │
│  (notation   │     │   Generator  │     │   key/song   │
│   data)      │     │   Script     │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

### LilyPond Source Example

```lilypond
\version "2.24.0"

\header {
  title = "151. Hatalmas Isten, nagy haragodban"
  subtitle = "Key: Bb | Time: 4/4"
}

\relative c' {
  \key bes \major
  \time 4/4

  bes4^\markup{\bold "Bb"} c d c |
  bes4^\markup{\bold "F"} a bes c |
}

\addlyrics {
  Ha -- tal -- mas Is -- ten, nagy ha -- ra --
}
```

### Advantages
- Perfect typography (LilyPond is the gold standard)
- Automatic syllable alignment
- Can generate multiple keys programmatically
- SVGs are lightweight and crisp

### Disadvantages
- Requires LilyPond installation for building
- Pre-generated files increase app size
- Changes require rebuild

---

## Recommendation

**For maximum quality and maintainability:**

1. **Short term**: Use LilyPond pipeline to generate SVGs
   - Quick to implement
   - Produces beautiful output
   - Solves syllable alignment immediately

2. **Long term**: Build custom Flutter renderer
   - Better user experience (real-time transposition)
   - Smaller app size
   - More flexibility

**Suggested first step:** Create a small proof-of-concept with:
- 1-2 songs in LilyPond format
- Script to generate SVGs for multiple keys
- Test loading in app

This validates the approach before committing to full migration.

---

## Resources

### Fonts
- [Bravura (SMuFL)](https://github.com/steinbergmedia/bravura) - Free music notation font
- [Leland](https://github.com/MuseScoreFonts/Leland) - MuseScore's open font

### Libraries
- [simple_sheet_music](https://pub.dev/packages/simple_sheet_music) - Flutter package
- [VexFlow](https://www.vexflow.com/) - JavaScript music notation
- [OpenSheetMusicDisplay](https://opensheetmusicdisplay.org/) - MusicXML + VexFlow
- [LilyPond](https://lilypond.org/) - Music engraving system

### Standards
- [MusicXML](https://www.musicxml.com/) - Sheet music interchange format
- [SMuFL](https://www.smufl.org/) - Standard Music Font Layout
- [ABC Notation](https://abcnotation.com/) - Text-based music notation
