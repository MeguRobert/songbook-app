# Song import & editor — design

_2026-07-27. Companion to `2026-07-27-old-songbook-migration-analysis.md`, which covers what the old
Songbook repo contributed and why none of its code is being reused._

## Scope

Local song authoring only. No accounts, no cloud, no moderation — those stay deferred (analysis doc,
phases C/D/E). Everything here works offline and keeps the app a free static PWA.

## The reframe

Songs come from paper hymnals, chord sites, and MusicXML files — never from composing. Every source
is **transcription**, and every one is lossy: OCR misreads, OMR guesses, pasted sheets have ragged
spacing, MusicXML carries structure the model doesn't hold.

So this is not an editor. It is an **import hub with a shared review surface**:

```
  paste text  ─┐
  MusicXML    ─┼──→  SongDraft  ──→  Review & Correct  ──→  save (local)
  photo       ─┘                          ▲
                                    built once, shared
```

Importers are small and independent. The review screen is the product. Importer #2 and #3 are cheap
because #1 pays for the screen.

---

## Phase 0 — Declutter the mobile UI

Robert's UAT finding, and a prerequisite: import adds *edit* and *save* affordances, and the app bar
has no room.

`song_view_screen.dart:257` renders back · `"151. Title"` · tags · auto-scroll · presentation ·
favourite. Five targets crowd the title on a phone, which is why the full title is unreadable.

- Song number moves onto its own line above the title; the title takes the full width and wraps to
  two lines before ellipsizing
- Only the favourite stays in the bar. Presentation mode and tag editing move to an overflow menu
- Auto-scroll is removed outright: `song_controls_sheet.dart` section 5 already has play/pause
  **and** a speed slider, so the bar button was a second, poorer affordance over the same state

**Done — `claude/phase-0-declutter`.** Verified at 390 px against the live build:

| | app bar |
|---|---|
| before (build 148) | `151. Hatalmas Isten, n…` + 3 actions |
| after | `151` / `Hatalmas Isten, nagy haragodban` + favourite + ⋮ |

**The song list bar was left alone, deliberately.** `song_list_screen.dart:75` carries three actions
(search, books, tags) under a short title — "Songbook", or a book name. Nothing truncates at 390 px,
and folding Books and Tags into one filter menu would add a tap to the two most common actions to
solve a problem that isn't there.

*No dependencies. Small.*

---

## Phase A — Song identity

Prerequisite for every phase below. Two defects in the same family, both dormant only because
nothing currently mutates a song.

**1. `int` is the only song key in the system.** `Song.number` (`song.dart:99`),
`Favorite.songNumber` (`favorite.dart:9`), `RecentSong.songNumber` (`recent_song.dart:6`),
`Setlist.songNumbers` → `List<int>` (`setlist.dart:21`), tag overrides → `Map<int, List<String>>`
(`local_datasource.dart:152`), route `/song/:number`.

Hymnal numbers are authoritative and shared; imported songs have none. Sequential max+1 does not fix
this — it moves the collision to the boundary between bundled and user content.

Introduce a `SongId` value type: source + reference, e.g. `hymnal:151` / `user:9f3a2c`. Four persisted
formats change, so it needs a versioned reader that upgrades existing `int` payloads in place. No
user-visible change; fully testable offline.

**2. Value equality skips the mutable fields.**

- `Song.==` (`song.dart:209`) compares `number` only — already flagged in `HANDOFF.md`
- `Verse.==` (`verse.dart:60`) compares `number`, `hasNotation`, `plainText` — **not `lines`**, and
  `hashCode` omits `lines` too

The second is the dangerous one for this work. `verse.copyWith(lines: …)` returns a verse that
compares **equal** to the original, so any widget or provider diffing verses will not see an edit.
An editor mutates verses constantly. Fix both before writing anything against them.

*Depends on: nothing. Medium.*

---

## Phase B1 — Paste importer

### Accepted input

| Shape | Example |
|---|---|
| Inline / ChordPro | `[G]Amazing [C]grace how [G]sweet` |
| Two-line (chords over lyrics) | chord line, then lyric line |
| Verse break | blank line |
| Directives | `{title: …}`, `{key: …}`, `{c: Refrén}` — used when present, never required |

### Why the existing format needs no conversion

`ChordPosition.position` is a **character index into the lyric text** (`chord_position.dart:11`).
That makes the storage model isomorphic to both input shapes:

- ChordPro: `[G]` at index 12 ≡ `{chord: "G", position: 12}`
- Two-line: a chord token's **column** ≡ that same character index

ChordPro is the paste and export format. The existing JSON stays the storage format. Nothing is lost
in either direction, and no new format gets invented.

### Two regexes, two jobs — do not merge them

`ChordTransposer._chordPattern` is `^([A-G][#b]?)(.*)$` (`chord_transposer.dart:7`). Quality is `.*`
— anything goes. Correct for transposing a chord already known to be a chord. **Fatal for deciding
whether a token is a chord**, and specifically fatal in Hungarian:

```
Csak  Egy  Az   →   C+"sak"   E+"gy"   A+"z"   ← all three "match"
```

The whole line is classified as chords and the lyrics are silently destroyed.

Detection therefore needs a **quality whitelist**, not `.*`:

- root `[A-G]` + optional `#`/`b`
- optional quality from `m`, `maj`, `min`, `dim`, `aug`, `sus`, `add`, `+`, `°`
- optional extension digits
- optional `/` + bass note

Must match: `G` `Gm` `G7` `Gm7` `Gmaj7` `Gsus4` `G#dim` `Bb` `F#m7` `G/B` `C/E`
Must **not** match: `Csak` `Egy` `Az` `Be` `Dad` `Ez` `Fel`

**Line rule:** a line is a chord line **iff every whitespace-separated token matches the strict
pattern**. Whole line, no exceptions.

**Ambiguous case:** a single-token line that is a bare root letter with no accidental and no quality
(`A`, `E`) — plausibly a one-chord line, plausibly a lyric. Default to lyrics and flag it in review.

Add a comment at both regexes explaining why they differ, or they will get "simplified" back together.

### Slash chords are broken today

`parseChord("G/B")` → root `G`, quality `/B`; transposing +2 yields `A/B`. The bass note is never
transposed, and there is no `/` handling anywhere in `chord_transposer.dart`,
`transposition_service.dart` or `music_constants.dart`.

Correct behaviour: split on `/`, transpose both sides independently, respect `useFlats` for both.
`G/B` +2 → `A/C#`. Dormant against the 8 hand-curated songs; unavoidable the moment real chord sheets
are pasted, so it lands with the parser.

### Review screen

Renders the parsed draft **with the same widgets the song view uses**, so what is approved is what
ships. Parser uncertainty is flagged inline, never silently guessed.

Form for what cannot be inferred: song number, book, tags. Title and key are offered as prefilled
guesses when derivable (`{title:}`, or key from the first / most common chord) — offered, not assumed.

Validation, in the spirit of the old app (`song_repository.dart:86`): title required, at least one
verse, whitespace-only rejected, duplicate title warned.

*Depends on: A. Large.*

---

## Phase B2 — MusicXML importer

Port `parse_musicxml` (139 lines, `convert_hymn.py:360`) and `convert_to_app_format` (16 lines) to
Dart. File picker for `.xml` / `.mxl`; `.mxl` is a zip and needs an archive step.

This is the only path that produces real `SongNotation`, and lyrics come free from `<lyric>` elements
— it skips the OCR-and-distribute machinery entirely. Cleanest of the three importers.

### The SATB decision

`SongNotation` is monophonic: one `NotatedBeat` stream, where a beat is
`{pitch, duration, syllable, chord, tieStart, tieEnd, dotted}` (`notation.dart:55`). Hymnal MusicXML
is typically **four-voice SATB**.

The importer must choose a reduction rule (melody / top staff / voice 1) and will otherwise be
**discarding three voices on every import**. Choral/4-voice support is already a recorded future
idea — that feature's data arrives at this exact line of code. Even while only the melody renders,
retain the other voices in the imported draft rather than dropping them, or every file has to be
re-imported when choral support lands.

*Depends on: B1 (review screen). Medium.*

---

## Phase B3 — Photo import & notation correction

### Photo splits into two features

**Photo → lyrics + chords.** A vision model or on-device OCR emits text, which feeds the **same
parser as B1**. Nearly free once paste exists, and it covers the paper-hymnal case for everything
except the staff.

**Photo → engraved notation.** Requires Audiveris, a JVM desktop application that cannot run inside
Flutter on mobile or web. `tools/convert_hymn.py` already does this well (Audiveris or oemer →
MusicXML → app JSON, EasyOCR with Hungarian for lyrics, lyric-to-note distribution, validation gate).
Keep it on the desktop. The app's role is at most handing a photo off to it, and the resulting
MusicXML re-enters through B2.

### Notation correction

Tap a `NotatedBeat`, change pitch / duration / syllable / tie / dot. Seven fields, flat list —
closer to editing a table than to driving a score editor. This targets where OMR actually fails.

**This is the entire sheet-editing scope.** No blank-page score writer: note entry, beaming,
multi-voice, articulations and dynamics are an order of magnitude more work, for material that is
always being transcribed rather than composed.

*Depends on: B1, B2. Medium.*

---

## Not doing

- A from-scratch notation editor
- `flutter_quill` or any rich-text song body — it would break transposition, capo, chord-above-staff
  rendering, presentation mode and lyrics search, which all read the structured model
- A new interchange format — ChordPro in, existing JSON stored
- Running Audiveris on-device
- Sequential integer IDs for imported songs

## Open decisions

- MusicXML reduction rule: melody, top staff, or voice 1 — and the shape used to retain the
  discarded voices for future choral support
- Photo → text: on-device OCR versus a vision-model call (the latter needs network and a key)
- Whether imported songs get numbers in a separate display range, or show no number at all
