# Architecture

**Analysis Date:** 2026-02-05

## Pattern Overview

**Overall:** Clean Architecture with Riverpod State Management

**Key Characteristics:**
- Strict separation of concerns: data → domain → presentation layers
- Riverpod providers for dependency injection and state management
- GoRouter for navigation with shell routing for bottom navigation
- Async-first data access via FutureProvider and StateNotifierProvider
- Custom sheet music rendering system with SVG and structured notation support

## Layers

**Data Layer:**
- Purpose: Handles all data access, persistence, and repository pattern
- Location: `songbook_app/lib/data/`
- Contains: Models (with code generation), repositories, datasources
- Depends on: Shared Preferences for persistence, Flutter for asset loading
- Used by: Domain services and presentation providers

**Domain Layer:**
- Purpose: Business logic and domain services independent of UI/framework
- Location: `songbook_app/lib/domain/`
- Contains: Services (TranspositionService, SearchService), entities
- Depends on: Data models only, no presentation dependencies
- Used by: Presentation providers and screens

**Presentation Layer:**
- Purpose: UI widgets, screens, and state management
- Location: `songbook_app/lib/presentation/`
- Contains: Screens, providers (state/UI), widgets, custom renderers
- Depends on: Domain services, data models, Riverpod, Flutter, GoRouter
- Used by: App entry point

**Core Layer:**
- Purpose: Shared utilities, constants, extensions, and theme
- Location: `songbook_app/lib/core/`
- Contains: Constants, extensions, utils, theme definitions
- Depends on: Flutter only
- Used by: All other layers

## Data Flow

**Song Loading Flow:**

1. `main.dart` initializes SharedPreferences and ProviderScope
2. `SongListScreen` watches `songsProvider` (FutureProvider)
3. `songsProvider` calls `songRepositoryProvider.getAllSongs()`
4. `SongRepository` delegates to `LocalDataSource.loadSongs()`
5. `LocalDataSource` loads cached JSON from `assets/data/songs.json` via `rootBundle`
6. Songs cached in-memory and returned through provider chain
7. UI renders ListView of songs via `SongListTile` widgets

**Song View with Transposition:**

1. User taps song in list → navigates to `/song/:id` via GoRouter
2. `SongViewScreen` receives `songNumber` and opens `songViewProvider`
3. `SongViewScreen` watches:
   - `songByNumberProvider(number)` - loads song data
   - `transposeProvider` - current transposition amount
   - `viewModeProvider` - chords vs sheet music mode
   - `isFavoriteProvider(number)` - favorite status
4. User adjusts transpose via `FloatingControlsMenu`
5. `songViewProvider.notifier.transposeUp/Down()` updates state
6. UI re-renders with transposed chords via `ChordView`

**Search Flow:**

1. User enters query in search field
2. `SearchNotifier.search()` called with query string
3. Retrieves all songs via `songsProvider.future`
4. Calls `SearchService.search()` to filter by title/tags
5. Updates `searchProvider` state with results
6. `SearchScreen` watches `searchResultsProvider` and renders results

**Favorites Management:**

1. User toggles favorite button in `SongViewScreen`
2. Calls `favoritesProvider.notifier.toggleFavorite(songNumber)`
3. `FavoritesNotifier` updates local state and calls repository
4. `FavoritesRepository` persists via `LocalDataSource` → SharedPreferences
5. `isFavoriteProvider` reflects change (watched by screens)
6. `FavoritesScreen` watches `favoriteSongsProvider` to display favorites

**State Management:**

- **App State:** Riverpod providers (immutable, reactive)
- **Song Loading:** FutureProvider with in-memory cache in LocalDataSource
- **UI State:** StateNotifierProvider (SongViewNotifier, SettingsNotifier, SearchNotifier, FavoritesNotifier)
- **Derived State:** Provider (computed from watched state)
- **Persistence:** SharedPreferences via LocalDataSource

## Key Abstractions

**Song Entity:**
- Purpose: Represents a complete song with metadata, verses, chords, and notation
- Examples: `songbook_app/lib/data/models/song.dart`, `verse.dart`, `lyric_line.dart`, `chord_position.dart`, `notation.dart`
- Pattern: Immutable data classes with `copyWith()` methods, JSON serialization via `json_annotation`, equality based on `song.number`

**Repository Pattern:**
- Purpose: Abstract data sources and provide clean data access interface
- Examples: `SongRepository`, `FavoritesRepository`, `SettingsRepository`
- Pattern: Single responsibility, delegates to `LocalDataSource`, no business logic

**Service Pattern:**
- Purpose: Encapsulate domain logic and reusable algorithms
- Examples: `TranspositionService` (chord transposition math), `SearchService` (full-text search), `ChordTransposer` (music theory)
- Pattern: Stateless, functional, pure logic (no side effects)

**Provider Pattern (Riverpod):**
- Purpose: Dependency injection and reactive state management
- Examples: `songRepositoryProvider`, `songViewProvider`, `settingsProvider`
- Pattern: Providers created in `presentation/providers/providers.dart` and feature-specific files, watched by screens for reactivity

**Sheet Music Rendering:**
- Purpose: Custom rendering system for structured notation and chord display
- Examples: `SheetMusicRenderer`, `SheetMusicPainter`, `SheetMusicLayout`
- Pattern: StatefulWidget with ScrollController, custom Canvas painting, supports transposition and zoom

## Entry Points

**Application Root:**
- Location: `songbook_app/lib/main.dart`
- Triggers: App launch
- Responsibilities: Initialize SharedPreferences, set up ProviderScope, configure Riverpod overrides

**App Configuration:**
- Location: `songbook_app/lib/app.dart`
- Triggers: Main creates SongbookApp
- Responsibilities: MaterialApp.router setup, theme switching, GoRouter configuration

**Router Entry:**
- Location: `songbook_app/lib/router/app_router.dart`
- Triggers: SongbookApp references routerProvider
- Responsibilities: Route definitions, shell routing for bottom nav, error handling

**Initial Screen:**
- Location: `songbook_app/lib/presentation/screens/song_list/song_list_screen.dart`
- Triggers: Route `/` (home)
- Responsibilities: Display paginated song list, handle navigation to song view/search

## Error Handling

**Strategy:** Async-first with AsyncValue pattern

**Patterns:**
- FutureProvider and StateNotifierProvider handle loading/error/data states
- AsyncValue.when() used in build to handle three states (data, loading, error)
- LocalDataSource catches JSON deserialization errors and returns empty lists
- Song lookup returns null if not found; screens show "Song not found" UI
- Router has errorBuilder for invalid routes
- No try-catch blocks in presentation; errors flow through provider chain

## Cross-Cutting Concerns

**Logging:** No dedicated logging framework; development via `print()` and Flutter DevTools

**Validation:**
- ChordTransposer validates chord patterns (regex `^[A-G][#b]?.*$`)
- SongRepository filters songs by number
- Settings bounds checking (font size 12-32, transpose -11 to +12)

**Authentication:** Not applicable (single-user, no backend)

**Persistence:**
- SharedPreferences via LocalDataSource
- Favorites stored as JSON array
- Settings stored with `settings_` prefix key
- Songs loaded from bundled assets (read-only)

**Theme Management:**
- `themeProvider` (Riverpod StateNotifierProvider) tracks light/dark mode
- `app_theme.dart` defines createLightTheme() and createDarkTheme()
- `SongbookApp` watches `flutterThemeModeProvider` and applies theme

**Asset Loading:**
- Songs: `assets/data/songs.json` (bundled JSON)
- Sheet Music: `assets/sheet_music/*.svg` (keyed by transposition)
- Fonts: `assets/fonts/Bravura.otf` (music notation font)
- Icons: `assets/icons/` (SVG icons, loaded via flutter_svg)

---

*Architecture analysis: 2026-02-05*
