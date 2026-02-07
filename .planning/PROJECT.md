# Songbook App

## What This Is

A cross-platform church songbook app for musicians and worship leaders. Provides song viewing with chords, sheet music notation, and transposition for Hungarian hymnals and growing song collections. Built with Flutter for Android, iOS, Windows, and Web.

## Core Value

Musicians can view any song with accurate chords and sheet music, transpose it to any key, and sing or play from the app during worship — replacing printed hymnals.

## Requirements

### Validated (shipped and working)

- **VAL-01**: Song list with scrollable index and search by number, title, or reference
- **VAL-02**: Song view with chord+lyrics display showing chords positioned above lyrics
- **VAL-03**: Custom sheet music rendering with Bravura font, staff lines, notes, beams, and lyrics
- **VAL-04**: Chord transposition up/down by semitone with key display
- **VAL-05**: Favorites system with toggle and dedicated favorites screen
- **VAL-06**: Dark and light theme support with toggle in settings
- **VAL-07**: View mode switching between chords view and sheet music view
- **VAL-08**: Settings persistence (view mode, text scale, theme) via SharedPreferences
- **VAL-09**: SVG sheet music loading with transposition key variants
- **VAL-10**: Bottom navigation with song list, favorites, search, and settings tabs

### Active (current scope — MVP for app store release)

- **REQ-01**: Fix transpose wrapping bug (asymmetric -11/+12 range) and polish transpose controls
- **REQ-02**: Center chord view layout to match sheet music canvas centering
- **REQ-03**: In-song text size controls (increase/decrease font size while viewing)
- **REQ-04**: Configurable song view overlay — user toggles notation, chords, lyrics independently; merged view shows chord symbols above staff lines
- **REQ-05**: Lyrics presentation mode — full-screen clean lyrics for projection on screens, second display control from phone/tablet, and large-text reading mode for personal use
- **REQ-06**: Song "books" organization — group songs by hymnal (Hallelujah, Reformed, Youth Worship, etc.) with book browser and selection
- **REQ-07**: App store readiness — icon, branding, metadata, screenshots, platform-specific polish

### Future (post-MVP, planned)

- **FUT-01**: Improved import pipeline — better OCR accuracy with Audiveris, reduced manual correction, possible in-app import UI
- **FUT-02**: Setlists/playlists — create ordered song lists for specific services or events
- **FUT-03**: Custom user songbooks — users create their own collections, shareable with others
- **FUT-04**: Cloud backend — user accounts, cloud sync, sharing infrastructure
- **FUT-05**: Performance optimization for 1000+ songs — lazy loading, pagination, LRU cache for notation
- **FUT-06**: Test coverage — unit tests for transposition/search, widget tests for screens, integration tests for navigation
- **FUT-07**: Tags and advanced categorization — thematic tags (praise, communion, Christmas, funeral), filtering
- **FUT-08**: Multi-platform polish — Windows desktop experience, Web PWA, platform-specific UX

### Out of Scope

- **Real-time collaboration** — No live co-editing of songs or setlists. Sharing is async (export/import). Reason: complexity far exceeds MVP value.
- **MIDI/audio playback** — No playing back songs as audio. This is a visual/text tool. Reason: different product category entirely.
- **Guitar tablature** — No chord diagrams or tab notation. Chord symbols only. Reason: target audience reads standard notation + chord symbols.
- **Custom backend for v1** — Local-first architecture. No server, no accounts for MVP. Reason: ship fast, add cloud later with architecture that supports it.
- **Song editing in-app** — Songs are imported via external pipeline (Audiveris + OCR + Claude AI). No in-app editing for v1. Reason: import pipeline is developer workflow for now.

## Context

### Technical Environment
- Flutter/Dart with Riverpod state management, GoRouter navigation
- Clean architecture: data/ (models, repos) -> domain/ (services) -> presentation/ (screens, providers, widgets)
- Custom sheet music rendering system (Bravura font, SVG notation, custom Canvas painting)
- ~50 Dart files, single developer
- Songs bundled as JSON asset (~50 songs currently, 1000+ target)
- Import pipeline: physical hymnal scan -> Audiveris (notation OCR) -> convert_hymn.py -> songs.json

### Prior Work
- App is functional with core features (song list, search, favorites, chord view, sheet music, transposition)
- Floating controls menu and transpose controls recently added
- Codebase mapped with GSD map-codebase (see .planning/codebase/)

### Known Issues
- Transpose wrapping logic is asymmetric (-11 to +12 range)
- SVG asset fallback gives misleading "not available" message when original key asset is missing
- No test coverage (only placeholder widget test)
- Chord line width estimation uses hardcoded multiplier instead of actual font metrics
- StateNotifier pattern (deprecated in Riverpod 3.x) used throughout
- Sheet music painter is monolithic (952 lines)

### User Feedback
- Transpose state sometimes persists incorrectly between songs
- Need better visual feedback for current transposition amount
- Want to see chords and notation together, not just one or the other

## Constraints

| Type | Constraint | Rationale |
|------|-----------|-----------|
| Stack | Flutter/Dart, Riverpod, GoRouter | Existing codebase, cross-platform requirement |
| Architecture | Local-first, no backend for v1 | Ship MVP fast, add cloud later |
| Platform | Android + iOS minimum for store, Windows + Web as stretch | Store release is primary goal |
| Data | JSON bundled assets, SharedPreferences for settings | Simple, no server dependency |
| Content | Hungarian hymnals as primary source | Target audience is Hungarian-speaking churches |
| Import | External pipeline (Audiveris + Python + AI) | Not in-app for v1, developer workflow |
| Scale | Must handle 1000+ songs eventually | Architecture decisions should not block scaling |
| Solo dev | Single developer, AI-assisted | Keep scope realistic, prefer simple solutions |

## Key Decisions

| Decision | Date | Rationale | Outcome |
|----------|------|-----------|---------|
| Flutter for cross-platform | Pre-project | Single codebase for Android, iOS, Windows, Web | -- Good |
| Riverpod over Provider/Bloc | Pre-project | Compile-time safety, testability, less boilerplate | -- Good |
| JSON bundled assets over SQLite | Pre-project | Simple for small collection, easy to update | -- Revisit at 500+ songs |
| Custom sheet music renderer over MusicXML lib | Pre-project | Full control over rendering, Hungarian text support | -- Good but complex |
| Local-first for MVP | 2026-02-07 | Ship fast, add cloud when there's user base | -- Pending |
| Books as primary organization | 2026-02-07 | Matches how hymnals are organized in real life | -- Pending |
| Configurable overlay over separate views | 2026-02-07 | More flexible, one view to maintain | -- Pending |

## Last Updated

2026-02-07 — Initial PROJECT.md creation for GSD framework setup
