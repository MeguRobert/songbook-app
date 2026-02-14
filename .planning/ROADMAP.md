# Roadmap: Songbook App

## Milestones

- 🚧 **v1.0 MVP Store Release** - Phases 1-6 (in progress)
- 📋 **v1.1 Content & Organization** - Phases 7-9 (planned)
- 📋 **v2.0 Platform & Sharing** - Phases 10-12 (planned)

## Overview

Ship a polished, store-ready songbook app by building on the existing functional core. Phase 1 fixes known bugs and polishes the existing UI. Phase 2 introduces the configurable merged view (the core UX differentiator). Phase 3 adds text controls and presentation mode for church projection use. Phase 4 redesigns the controls UI (bottom sheet, pinch-to-zoom, decluttered). Phase 5 adds song books organization. Phase 6 prepares for app store submission. Post-MVP milestones add content scaling, cloud backend, and sharing.

## Phases

### 🚧 v1.0 MVP Store Release

- [x] **Phase 1: Bug Fixes & Core Polish** - Fix known bugs and polish existing UI for reliability
- [x] **Phase 2: Configurable Song View** - Merged notation+chords+lyrics with toggle controls
- [x] **Phase 3: Presentation Mode** - Full-screen lyrics display for projection and personal use
- [ ] **Phase 4: Controls UI Redesign** - Bottom sheet controls, pinch-to-zoom, decluttered UX
- [ ] **Phase 5: Song Books** - Organize songs by hymnal/book with book browser
- [ ] **Phase 6: Store Release Prep** - Branding, metadata, platform polish, submission

### 📋 v1.1 Content & Organization

- [ ] **Phase 7: Import Pipeline** - Improved OCR workflow with less manual correction
- [ ] **Phase 8: Setlists & Playlists** - Ordered song lists for services and events
- [ ] **Phase 9: Tags & Search** - Thematic tags, advanced filtering, search improvements

### 📋 v2.0 Platform & Sharing

- [ ] **Phase 10: Cloud Backend** - User accounts, cloud storage architecture
- [ ] **Phase 11: Custom Songbooks & Sharing** - User-created collections, export/import/share
- [ ] **Phase 12: Scale & Quality** - Performance for 1000+ songs, test coverage, Riverpod migration

## Phase Details

### Phase 1: Bug Fixes & Core Polish
**Goal**: Make the existing app reliable and visually polished — fix all known bugs, center layouts, refine controls
**Depends on**: Nothing (first phase)
**Requirements**: [REQ-01, REQ-02, REQ-03]
**Success Criteria** (what must be TRUE):
  1. Transpose wrapping is symmetric and intuitive (e.g., -6 to +5 or -11 to +11)
  2. Chord view content is horizontally centered like sheet music canvas
  3. Text size can be increased/decreased while viewing a song
  4. Transpose state resets correctly when navigating between songs
  5. SVG fallback shows clear message distinguishing "transposed key missing" from "no sheet music"
**Plans**: 2 plans in 2 waves

Plans:
- [x] 01-01-PLAN.md — Fix transpose wrapping (-6 to +5), state reset on navigation, SVG fallback messages
- [x] 01-02-PLAN.md — Center chord view layout, verify text size controls wiring

### Phase 2: Configurable Song View
**Goal**: Replace separate chord/sheet views with a unified configurable view where users toggle notation, chords, and lyrics independently
**Depends on**: Phase 1
**Requirements**: [REQ-04]
**Success Criteria** (what must be TRUE):
  1. User can toggle chord symbols on/off above the staff in sheet music view
  2. Lyrics are always visible in all view modes (base layer, not toggled)
  3. User can view chords+lyrics without notation (current chord view behavior preserved)
  4. Toggle controls are accessible and discoverable in the floating menu
  5. View configuration persists across song navigation and app restart
**Plans**: 2 plans in 2 waves

Plans:
- [x] 02-01-PLAN.md — ViewConfig state model, persistence layer (global + per-song), provider migration from SongViewMode
- [x] 02-02-PLAN.md — Unified song view rendering, floating menu toggle/preset controls, settings screen update

### Phase 3: Presentation Mode
**Goal**: Add a projection-friendly lyrics display mode for church services, supporting large screens, second displays, and personal large-text reading
**Depends on**: Phase 2
**Requirements**: [REQ-05]
**Success Criteria** (what must be TRUE):
  1. Full-screen lyrics mode with minimal chrome (no app bar, no navigation)
  2. Text scales to fill available screen width for readability at distance
  3. Dark background option for projection (white text on black)
  4. Swipe or tap to advance between verses
  5. Works well on both phone (personal reading) and tablet/desktop (projection)
**Plans**: 2 plans in 2 waves

Plans:
- [x] 03-01-PLAN.md — Full-screen presentation screen with verse-by-verse navigation, auto-scaling text, projection theme, route + entry point
- [x] 03-02-PLAN.md — Persistent projection preference, responsive layout polish for phone/tablet/desktop, landscape support

### Phase 4: Controls UI Redesign
**Goal**: Replace the overloaded floating controls column with a clean bottom sheet pattern, add pinch-to-zoom, and move presentation mode to the app bar — reducing visual clutter while preserving all functionality
**Depends on**: Phase 3 (redesigns controls built in Phases 1-3)
**Requirements**: [REQ-04] (UX improvement to existing controls)
**Success Criteria** (what must be TRUE):
  1. Floating column replaced by FAB that opens a Material bottom sheet with labeled sections
  2. Pinch-to-zoom gesture works for text scaling (A+/A- buttons also available inside sheet)
  3. Three view presets (Sheet Music, Chords, Lyrics) are primary; individual toggles accessible via "Custom" option
  4. Presentation mode button is in the app bar (not buried in controls)
  5. Transpose controls are clearly labeled with key display in the bottom sheet
**Plans**: 2 plans in 2 waves

Plans:
- [ ] 04-01-PLAN.md — Bottom sheet controls widget, FAB trigger, pinch-to-zoom gesture
- [ ] 04-02-PLAN.md — App bar presentation button, Custom view option, cleanup old floating menu

### Phase 5: Song Books
**Goal**: Organize songs by hymnal/book (Hallelujah, Reformed, Youth Worship, etc.) with a book browser for navigating large collections
**Depends on**: Phase 1 (does not depend on Phase 2/3/4 — can be parallelized)
**Requirements**: [REQ-06]
**Success Criteria** (what must be TRUE):
  1. Songs are grouped by book/hymnal in the data model
  2. Book browser lets users select which book to browse
  3. Song list filters to show songs from selected book
  4. "All songs" view still available across all books
  5. New songs can be assigned to a book during import
**Plans**: TBD

Plans:
- [ ] 05-01: Design book data model and extend song JSON schema
- [ ] 05-02: Build book browser UI and integrate with song list

### Phase 6: Store Release Prep
**Goal**: Prepare the app for public release on Google Play and Apple App Store with proper branding, metadata, and platform-specific polish
**Depends on**: Phase 1, Phase 2, Phase 4, Phase 5
**Requirements**: [REQ-07]
**Success Criteria** (what must be TRUE):
  1. App icon and splash screen are professional and on-brand
  2. Store listing metadata (title, description, screenshots) is complete
  3. App runs smoothly on Android and iOS without crashes
  4. Basic accessibility (text scaling, screen reader labels) works
  5. App passes store review requirements (no placeholder content, proper permissions)
**Plans**: TBD

Plans:
- [ ] 06-01: Create branding assets and configure platform manifests
- [ ] 06-02: Platform testing and store submission

### Phase 7: Import Pipeline
**Goal**: Improve the Audiveris + OCR + AI import workflow for faster, more accurate song importing with less manual correction
**Depends on**: Phase 6 (post-MVP)
**Requirements**: [FUT-01]
**Success Criteria** (what must be TRUE):
  1. Import accuracy improved (fewer manual corrections needed per song)
  2. Batch import support for processing multiple songs
  3. Validation step catches common OCR errors before they enter songs.json
  4. Clear documentation of import workflow for repeatability
**Plans**: TBD

### Phase 8: Setlists & Playlists
**Goal**: Allow users to create ordered song lists for specific services or events
**Depends on**: Phase 5 (books must exist first)
**Requirements**: [FUT-02]
**Success Criteria** (what must be TRUE):
  1. User can create a named setlist and add songs to it
  2. Songs in setlist can be reordered
  3. Setlist provides "next song" navigation during a service
  4. Setlists persist across app restarts
**Plans**: TBD

### Phase 9: Tags & Search
**Goal**: Add thematic tagging and advanced filtering to help users find songs by theme, season, or occasion
**Depends on**: Phase 5
**Requirements**: [FUT-07]
**Success Criteria** (what must be TRUE):
  1. Songs can have multiple tags (praise, communion, Christmas, etc.)
  2. Search supports filtering by tag
  3. Tag browser shows all available tags with song counts
  4. Tags are editable (add/remove from songs)
**Plans**: TBD

### Phase 10: Cloud Backend
**Goal**: Add user accounts and cloud storage to enable data sync and future sharing features
**Depends on**: Phase 6 (needs shipped app)
**Requirements**: [FUT-04]
**Success Criteria** (what must be TRUE):
  1. User can create account and sign in
  2. Favorites and setlists sync across devices
  3. App works offline and syncs when connection returns
  4. Data migration from local-only to cloud is seamless
**Plans**: TBD

### Phase 11: Custom Songbooks & Sharing
**Goal**: Allow users to create custom songbook collections and share them with others
**Depends on**: Phase 10 (needs cloud backend)
**Requirements**: [FUT-03]
**Success Criteria** (what must be TRUE):
  1. User can create a custom songbook with selected songs
  2. Songbooks can be exported and shared via link or file
  3. Recipient can import a shared songbook into their app
  4. Shared songbooks appear in book browser alongside hymnals
**Plans**: TBD

### Phase 12: Scale & Quality
**Goal**: Optimize for 1000+ songs, add comprehensive test coverage, and migrate to modern Riverpod patterns
**Depends on**: Phase 10
**Requirements**: [FUT-05, FUT-06]
**Success Criteria** (what must be TRUE):
  1. App loads and searches 1000+ songs without perceptible delay
  2. Unit test coverage for core logic (transposition, search) above 80%
  3. Widget tests for all major screens
  4. StateNotifier migrated to Notifier pattern (Riverpod 3.x ready)
**Plans**: TBD

## Progress

**Execution Order:**
Phases 1 → 2 → 3 → 4 in sequence. Phase 5 can run parallel to 2/3/4. Phase 6 after 1+2+4+5.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Bug Fixes & Core Polish | v1.0 | 2/2 | Complete | 2026-02-10 |
| 2. Configurable Song View | v1.0 | 2/2 | Complete | 2026-02-14 |
| 3. Presentation Mode | v1.0 | 2/2 | Complete | 2026-02-14 |
| 4. Controls UI Redesign | v1.0 | 0/2 | Not started | - |
| 5. Song Books | v1.0 | 0/2 | Not started | - |
| 6. Store Release Prep | v1.0 | 0/2 | Not started | - |
| 7. Import Pipeline | v1.1 | 0/? | Not started | - |
| 8. Setlists & Playlists | v1.1 | 0/? | Not started | - |
| 9. Tags & Search | v1.1 | 0/? | Not started | - |
| 10. Cloud Backend | v2.0 | 0/? | Not started | - |
| 11. Custom Songbooks & Sharing | v2.0 | 0/? | Not started | - |
| 12. Scale & Quality | v2.0 | 0/? | Not started | - |
