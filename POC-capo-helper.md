# POC — Capo helper

**Branch:** `claude/poc-capo-helper` (off `claude/phase-8-setlists`)

## What it does

Tells a guitarist where to put the capo and which open-chord shapes to play to sound in the song's
current key. Guitarists think in *shapes* (CAGED), not absolute keys — this bridges the existing
transposition feature to how they actually play.

- In the song controls sheet (the `tune` FAB) a new **CAPO** section shows:
  - a highlighted **recommended** position — e.g. *"Capo 1 — Play A shapes (sounds Bb)"*, or
    *"No capo needed — Play open in G"* when the key is already guitar-friendly;
  - **Other positions** as chips (e.g. `Capo 3 · G`, `Capo 6 · E`).
- It reacts to **transposition**: as you transpose the song, the sounding key changes and the capo
  suggestions update live — so capo + transpose work together.
- Minor keys use minor open shapes (Em/Am/Dm); major keys use the full CAGED set (C/A/G/E/D).

## How to try it

1. `git switch claude/poc-capo-helper` and run the app (`flutter run` from `songbook_app/`).
2. Open a song whose key isn't open-friendly (e.g. one in **Bb** or **Eb**).
3. Tap the **tune** FAB → scroll to the **CAPO** section. You'll see the recommended low capo
   position (e.g. *Capo 1 · play A shapes*) plus alternative chips.
4. In the same sheet, tap Transpose **+1 / −1** a few times → the capo recommendation updates to match
   the new sounding key.
5. Try a song in **G** → it shows *"No capo needed — play open in G"*.

## How it's built (fits existing architecture)

- `lib/domain/services/capo_service.dart` — pure `CapoService` + `CapoSuggestion` model. Reuses the
  existing `ChordTransposer.semitonesBetween` for pitch math (no duplicated music theory). For each
  CAGED shape key it computes `capo = (soundingKey − shapeKey) mod 12`, filters by `maxFret`
  (default 9), sorts lowest-fret-first; `recommendedFor` returns the lowest.
- `providers.dart` — `capoServiceProvider` (const service, mirrors `transpositionServiceProvider`).
- `song_controls_sheet.dart` — new CAPO section + `_CapoSection` widget; reads the already-computed
  `targetKey` (sounding key after transposition) so it stays in sync with the Transpose controls.

## Scope note (important)

PROJECT.md lists "guitar tablature / chord **diagrams**" as out of scope. This POC deliberately stays
inside that line: it shows **text key/shape math only** (capo fret + shape key name), no fretboard
diagrams or tab. It complements transposition rather than competing with it. Confirm you're happy with
that interpretation before shipping.

## What's stubbed / not done

- **No fretboard diagrams** (intentional — see scope note).
- **No "apply" action:** suggestions are advisory; there's no button that, say, auto-transposes to the
  easiest open key. Could add a "transpose to nearest open key" shortcut.
- **Shape set is fixed** to standard CAGED / Em-Am-Dm. No per-user preference for which shapes they're
  comfortable with, and no 7th/sus voicings.
- **Display only in the controls sheet** — not surfaced in presentation mode or on the song list.
- **No persistence** (it's a pure derived view of the current key; nothing to store).

## Tests

`test/domain/services/capo_service_test.dart` (7 tests): G major (open G recommended, E/D/C frets,
A excluded past maxFret), Bb major (A-shape capo 1 recommended), minor-key shapes, ascending sort,
maxFret filtering, invalid/empty key → empty, and label formatting. Pure logic, fully covered.

`flutter analyze`: clean (only the 8 pre-existing RadioListTile infos). Full suite: 60 passing.

## Effort to finish

~½ day: a "transpose to easiest open key" shortcut, optional user shape preferences, and surfacing the
recommendation outside the controls sheet (e.g. a small capo badge in the app bar).
