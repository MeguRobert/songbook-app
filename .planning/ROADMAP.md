# Roadmap: Songbook App

## Milestones

- 🚧 **v1.0 MVP Store Release** - Phases 1-5 (in progress)
- 📋 **v1.1 Content & Organization** - Phases 6-8 (planned)
- 📋 **v2.0 Platform & Sharing** - Phases 9-11 (planned)

## Overview

Ship a polished, store-ready songbook app by building on the existing functional core. Phase 1 fixes known bugs and polishes the existing UI. Phase 2 introduces the configurable merged view (the core UX differentiator). Phase 3 adds text controls and presentation mode for church projection use. Phase 4 adds song books organization. Phase 5 prepares for app store submission. Post-MVP milestones add content scaling, cloud backend, and sharing.

## Phases

### 🚧 v1.0 MVP Store Release

- [ ] **Phase 1: Bug Fixes & Core Polish** - Fix known bugs and polish existing UI for reliability
- [ ] **Phase 2: Configurable Song View** - Merged notation+chords+lyrics with toggle controls
- [ ] **Phase 3: Presentation Mode** - Full-screen lyrics display for projection and personal use
- [ ] **Phase 4: Song Books** - Organize songs by hymnal/book with book browser
- [ ] **Phase 5: Store Release Prep** - Branding, metadata, platform polish, submission

### 📋 v1.1 Content & Organization

- [ ] **Phase 6: Import Pipeline** - Improved OCR workflow with less manual correction
- [ ] **Phase 7: Setlists & Playlists** - Ordered song lists for services and events
- [ ] **Phase 8: Tags & Search** - Thematic tags, advanced filtering, search improvements

### 📋 v2.0 Platform & Sharing

- [ ] **Phase 9: Cloud Backend** - User accounts, cloud storage architecture
- [ ] **Phase 10: Custom Songbooks & Sharing** - User-created collections, export/import/share
- [ ] **Phase 11: Scale & Quality** - Performance for 1000+ songs, test coverage, Riverpod migration

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
- [ ] 01-01-PLAN.md — Fix transpose wrapping (-6 to +5), state reset on navigation, SVG fallback messages
- [ ] 01-02-PLAN.md — Center chord view layout, verify text size controls wiring

### Phase 2: Configurable Song View
**Goal**: Replace separate chord/sheet views with a unified configurable view where users toggle notation, chords, and lyrics independently
**Depends on**: Phase 1
**Requirements**: [REQ-04]
**Success Criteria** (what must be TRUE):
  1. User can toggle chord symbols on/off above the staff in sheet music view
  2. User can toggle lyrics on/off below the staff
  3. User can view chords+lyrics without notation (current chord view behavior preserved)
  4. Toggle controls are accessible and discoverable in the floating menu
  5. View configuration persists across song navigation and app restart
**Plans**: TBD

Plans:
- [ ] 02-01: Design and implement configurable view architecture
- [ ] 02-02: Build toggle controls UI and integrate with settings persistence

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
**Plans**: TBD

Plans:
- [ ] 03-01: Design presentation mode UI and navigation
- [ ] 03-02: Implement full-screen lyrics renderer with projection styling

### Phase 4: Song Books
**Goal**: Organize songs by hymnal/book (Hallelujah, Reformed, Youth Worship, etc.) with a book browser for navigating large collections
**Depends on**: Phase 1 (does not depend on Phase 2/3 — can be parallelized)
**Requirements**: [REQ-06]
**Success Criteria** (what must be TRUE):
  1. Songs are grouped by book/hymnal in the data model
  2. Book browser lets users select which book to browse
  3. Song list filters to show songs from selected book
  4. "All songs" view still available across all books
  5. New songs can be assigned to a book during import
**Plans**: TBD

Plans:
- [ ] 04-01: Design book data model and extend song JSON schema
- [ ] 04-02: Build book browser UI and integrate with song list

### Phase 5: Store Release Prep
**Goal**: Prepare the app for public release on Google Play and Apple App Store with proper branding, metadata, and platform-specific polish
**Depends on**: Phase 1, Phase 2, Phase 4
**Requirements**: [REQ-07]
**Success Criteria** (what must be TRUE):
  1. App icon and splash screen are professional and on-brand
  2. Store listing metadata (title, description, screenshots) is complete
  3. App runs smoothly on Android and iOS without crashes
  4. Basic accessibility (text scaling, screen reader labels) works
  5. App passes store review requirements (no placeholder content, proper permissions)
**Plans**: TBD

Plans:
- [ ] 05-01: Create branding assets and configure platform manifests
- [ ] 05-02: Platform testing and store submission

### Phase 6: Import Pipeline
**Goal**: Improve the Audiveris + OCR + AI import workflow for faster, more accurate song importing with less manual correction
**Depends on**: Phase 5 (post-MVP)
**Requirements**: [FUT-01]
**Success Criteria** (what must be TRUE):
  1. Import accuracy improved (fewer manual corrections needed per song)
  2. Batch import support for processing multiple songs
  3. Validation step catches common OCR errors before they enter songs.json
  4. Clear documentation of import workflow for repeatability
**Plans**: TBD

### Phase 7: Setlists & Playlists
**Goal**: Allow users to create ordered song lists for specific services or events
**Depends on**: Phase 4 (books must exist first)
**Requirements**: [FUT-02]
**Success Criteria** (what must be TRUE):
  1. User can create a named setlist and add songs to it
  2. Songs in setlist can be reordered
  3. Setlist provides "next song" navigation during a service
  4. Setlists persist across app restarts
**Plans**: TBD

### Phase 8: Tags & Search
**Goal**: Add thematic tagging and advanced filtering to help users find songs by theme, season, or occasion
**Depends on**: Phase 4
**Requirements**: [FUT-07]
**Success Criteria** (what must be TRUE):
  1. Songs can have multiple tags (praise, communion, Christmas, etc.)
  2. Search supports filtering by tag
  3. Tag browser shows all available tags with song counts
  4. Tags are editable (add/remove from songs)
**Plans**: TBD

### Phase 9: Cloud Backend
**Goal**: Add user accounts and cloud storage to enable data sync and future sharing features
**Depends on**: Phase 5 (needs shipped app)
**Requirements**: [FUT-04]
**Success Criteria** (what must be TRUE):
  1. User can create account and sign in
  2. Favorites and setlists sync across devices
  3. App works offline and syncs when connection returns
  4. Data migration from local-only to cloud is seamless
**Plans**: TBD

### Phase 10: Custom Songbooks & Sharing
**Goal**: Allow users to create custom songbook collections and share them with others
**Depends on**: Phase 9 (needs cloud backend)
**Requirements**: [FUT-03]
**Success Criteria** (what must be TRUE):
  1. User can create a custom songbook with selected songs
  2. Songbooks can be exported and shared via link or file
  3. Recipient can import a shared songbook into their app
  4. Shared songbooks appear in book browser alongside hymnals
**Plans**: TBD

### Phase 11: Scale & Quality
**Goal**: Optimize for 1000+ songs, add comprehensive test coverage, and migrate to modern Riverpod patterns
**Depends on**: Phase 9
**Requirements**: [FUT-05, FUT-06]
**Success Criteria** (what must be TRUE):
  1. App loads and searches 1000+ songs without perceptible delay
  2. Unit test coverage for core logic (transposition, search) above 80%
  3. Widget tests for all major screens
  4. StateNotifier migrated to Notifier pattern (Riverpod 3.x ready)
**Plans**: TBD

## Progress

**Execution Order:**
Phases 1 → 2 → 3 in sequence. Phase 4 can run parallel to 2/3. Phase 5 after 1+2+4.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Bug Fixes & Core Polish | v1.0 | 0/2 | Not started | - |
| 2. Configurable Song View | v1.0 | 0/2 | Not started | - |
| 3. Presentation Mode | v1.0 | 0/2 | Not started | - |
| 4. Song Books | v1.0 | 0/2 | Not started | - |
| 5. Store Release Prep | v1.0 | 0/2 | Not started | - |
| 6. Import Pipeline | v1.1 | 0/? | Not started | - |
| 7. Setlists & Playlists | v1.1 | 0/? | Not started | - |
| 8. Tags & Search | v1.1 | 0/? | Not started | - |
| 9. Cloud Backend | v2.0 | 0/? | Not started | - |
| 10. Custom Songbooks & Sharing | v2.0 | 0/? | Not started | - |
| 11. Scale & Quality | v2.0 | 0/? | Not started | - |
