# Codebase Structure

**Analysis Date:** 2026-02-05

## Directory Layout

```
songbook_app/
├── lib/                                    # Application source code
│   ├── main.dart                          # Entry point, ProviderScope setup
│   ├── app.dart                           # MaterialApp.router root widget
│   ├── core/                              # Shared utilities, constants, theme
│   │   ├── constants/                     # Constant values
│   │   │   ├── app_colors.dart
│   │   │   ├── app_typography.dart
│   │   │   ├── music_constants.dart       # Semitone, key, chord quality constants
│   │   │   └── engraving_constants.dart
│   │   ├── extensions/                    # Dart extensions
│   │   │   └── string_extensions.dart
│   │   ├── theme/                         # Theme definitions
│   │   │   ├── app_theme.dart
│   │   │   ├── light_theme.dart
│   │   │   └── dark_theme.dart
│   │   └── utils/                         # Utility functions
│   │       ├── chord_transposer.dart      # Music theory transposition
│   │       └── text_utils.dart
│   ├── data/                              # Data layer (models, repos, datasources)
│   │   ├── datasources/
│   │   │   └── local/
│   │   │       └── local_datasource.dart  # Shared prefs + asset loading
│   │   ├── models/                        # Data classes with JSON serialization
│   │   │   ├── song.dart                  # Main song entity
│   │   │   ├── song.g.dart                # Generated JSON code
│   │   │   ├── verse.dart                 # Song verse structure
│   │   │   ├── lyric_line.dart            # Line with lyrics + chords
│   │   │   ├── chord_position.dart        # Chord + string position
│   │   │   ├── notation.dart              # Structured sheet music data
│   │   │   ├── favorite.dart              # Favorite record
│   │   │   ├── [*.g.dart]                 # Generated JSON serializers
│   │   └── repositories/
│   │       ├── song_repository.dart       # Song data access
│   │       ├── favorites_repository.dart  # Favorites persistence
│   │       └── settings_repository.dart   # App settings persistence
│   ├── domain/                            # Business logic layer
│   │   ├── entities/                      # Domain entities (currently empty)
│   │   └── services/
│   │       ├── transposition_service.dart # Chord transposition business logic
│   │       └── search_service.dart        # Full-text search across songs
│   ├── presentation/                      # UI layer
│   │   ├── providers/
│   │   │   ├── providers.dart             # Core dependency injection (shared)
│   │   │   ├── song_provider.dart         # Song loading & view state
│   │   │   ├── search_provider.dart       # Search state management
│   │   │   ├── favorites_provider.dart    # Favorites state management
│   │   │   ├── settings_provider.dart     # App settings state
│   │   │   └── theme_provider.dart        # Theme mode state
│   │   ├── screens/
│   │   │   ├── song_list/
│   │   │   │   ├── song_list_screen.dart  # List all songs
│   │   │   │   └── widgets/
│   │   │   │       └── song_list_tile.dart # Individual song list item
│   │   │   ├── song_view/
│   │   │   │   ├── song_view_screen.dart  # Single song display (main UI)
│   │   │   │   └── widgets/
│   │   │   │       ├── chord_view.dart    # Chord/lyric layout view
│   │   │   │       ├── sheet_music_view.dart # Sheet music layout view
│   │   │   │       ├── transpose_controls.dart # Transpose UI controls
│   │   │   │       └── floating_controls_menu.dart # Floating action menu
│   │   │   ├── search/
│   │   │   │   └── search_screen.dart     # Search & filtering
│   │   │   ├── favorites/
│   │   │   │   └── favorites_screen.dart  # Display favorite songs
│   │   │   └── settings/
│   │   │       └── settings_screen.dart   # App settings UI
│   │   ├── widgets/
│   │   │   ├── scaffold_with_nav_bar.dart # Shell with bottom nav
│   │   │   └── sheet_music/               # Custom rendering widgets
│   │   │       ├── sheet_music.dart       # Barrel file
│   │   │       ├── sheet_music_renderer.dart # Main renderer widget
│   │   │       ├── sheet_music_painter.dart  # Custom Canvas painter
│   │   │       └── sheet_music_layout.dart   # Layout calculation
│   └── router/
│       └── app_router.dart                # GoRouter configuration
├── assets/
│   ├── data/
│   │   └── songs.json                    # Song database (JSON)
│   ├── sheet_music/                      # SVG sheet music files
│   ├── fonts/
│   │   └── Bravura.otf                   # Music notation font
│   └── icons/                            # SVG icon assets
├── pubspec.yaml                          # Package manifest
└── [.dart_tool/]                         # Build artifacts (git-ignored)
```

## Directory Purposes

**lib/:**
- Purpose: All application source code
- Contains: Dart files organized by architecture layers
- Key files: `main.dart`, `app.dart`

**lib/core/**
- Purpose: Shared utilities and configuration used across all layers
- Contains: Constants (color, typography, music theory), theme definitions, utility functions
- Key files: `music_constants.dart` (chord/key constants), `chord_transposer.dart` (transposition logic)

**lib/data/**
- Purpose: Data access layer with repositories and persistence
- Contains: Models with JSON serialization, repositories, datasources
- Key files: `local_datasource.dart` (SharedPreferences + asset loading), `song.dart` (main entity)

**lib/domain/**
- Purpose: Pure business logic and domain services
- Contains: Services independent of framework/UI concerns
- Key files: `transposition_service.dart` (chord transposition), `search_service.dart` (search)

**lib/presentation/**
- Purpose: User interface and state management
- Contains: Screens, widgets, Riverpod providers
- Key files: Screens in `screens/`, state managers in `providers/`, custom widgets in `widgets/`

**lib/presentation/providers/**
- Purpose: Riverpod dependency injection and state management
- Contains: FutureProvider for data loading, StateNotifierProvider for mutable state
- Key files: `providers.dart` (core DI), `song_provider.dart`, `favorites_provider.dart`

**lib/presentation/screens/**
- Purpose: Top-level screen widgets for each route
- Contains: ConsumerWidget/ConsumerStatefulWidget implementations
- Key files: `song_list_screen.dart`, `song_view_screen.dart`, `search_screen.dart`, `favorites_screen.dart`

**lib/presentation/widgets/**
- Purpose: Reusable widget components
- Contains: Bottom navigation scaffold, custom sheet music renderer
- Key files: `scaffold_with_nav_bar.dart`, `sheet_music/sheet_music_renderer.dart`

**lib/router/**
- Purpose: Navigation routing configuration
- Contains: GoRouter definitions, route paths
- Key files: `app_router.dart` (all routes, shell routing, error handling)

**assets/data/**
- Purpose: Application data files
- Contains: `songs.json` (bundled song database)
- Key files: `songs.json` (required; loaded by LocalDataSource)

**assets/sheet_music/**
- Purpose: Pre-generated sheet music files
- Contains: SVG files keyed by transposition (e.g., `151_Bb.svg`, `151_G.svg`)
- Generation: External tool; not committed for all keys

**assets/fonts/**
- Purpose: Custom fonts for music notation
- Contains: `Bravura.otf` (professional music engraving font)

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App initialization, ProviderScope setup
- `lib/app.dart`: MaterialApp.router root widget
- `lib/router/app_router.dart`: All route definitions

**Configuration:**
- `pubspec.yaml`: Dependencies, assets, fonts, version
- `lib/core/constants/music_constants.dart`: Chord/key note constants
- `lib/core/theme/app_theme.dart`: Theme creation functions

**Core Logic:**
- `lib/core/utils/chord_transposer.dart`: Semitone transposition algorithms
- `lib/domain/services/transposition_service.dart`: Transpose API (wraps ChordTransposer)
- `lib/domain/services/search_service.dart`: Full-text search implementation

**Data Access:**
- `lib/data/datasources/local/local_datasource.dart`: SharedPreferences + asset loading
- `lib/data/repositories/song_repository.dart`: Song data access
- `lib/data/repositories/favorites_repository.dart`: Favorites persistence
- `lib/data/repositories/settings_repository.dart`: Settings persistence

**State Management:**
- `lib/presentation/providers/providers.dart`: Core dependency injection
- `lib/presentation/providers/song_provider.dart`: Song loading & view state
- `lib/presentation/providers/search_provider.dart`: Search state
- `lib/presentation/providers/favorites_provider.dart`: Favorites state

**Screens:**
- `lib/presentation/screens/song_list/song_list_screen.dart`: Main song list
- `lib/presentation/screens/song_view/song_view_screen.dart`: Single song view
- `lib/presentation/screens/search/search_screen.dart`: Search interface
- `lib/presentation/screens/favorites/favorites_screen.dart`: Favorite songs
- `lib/presentation/screens/settings/settings_screen.dart`: App settings

**Custom Widgets:**
- `lib/presentation/widgets/scaffold_with_nav_bar.dart`: Bottom navigation wrapper
- `lib/presentation/widgets/sheet_music/sheet_music_renderer.dart`: Sheet music display
- `lib/presentation/screens/song_view/widgets/chord_view.dart`: Chord/lyric display
- `lib/presentation/screens/song_view/widgets/floating_controls_menu.dart`: Transpose controls

**Testing:**
- Not found; Flutter test structure not present

## Naming Conventions

**Files:**
- `snake_case.dart` for all Dart source files
- Pattern: `[feature_name].dart` for screens/widgets
- Pattern: `[service_name]_service.dart` for domain services
- Pattern: `[entity_name]_provider.dart` for Riverpod state files
- Generated files: `*.g.dart` (JSON serialization via build_runner)

**Directories:**
- `snake_case/` for all directories
- Feature directories: `screens/[feature_name]/`
- Each screen gets `widgets/` subdirectory for local components
- Shared components: `presentation/widgets/` (top-level)

**Classes:**
- `PascalCase` for all classes (widgets, services, models, providers)
- Pattern: `[Name]Screen` for screen widgets
- Pattern: `[Name]Widget` for custom widgets
- Pattern: `[Name]Service` for domain services
- Pattern: `[Name]Repository` for data repositories
- Pattern: `[Name]Notifier` for StateNotifier classes
- Pattern: `[Name]Provider` for Riverpod providers (in comments/exports only)

**Functions & Variables:**
- `camelCase` for all functions, methods, and variables
- Pattern: `[verb][Noun]()` for action functions (e.g., `toggleFavorite()`, `transposeUp()`)
- Pattern: `[noun]Provider` for Riverpod provider references
- Private members: `_leadingUnderscore` for class-private

**Constants:**
- `SCREAMING_SNAKE_CASE` in `core/constants/` files
- Example: `MusicConstants.sharpNotes`, `MusicConstants.flatKeys`

## Where to Add New Code

**New Feature (e.g., new screen):**
- Primary code: `lib/presentation/screens/[feature_name]/[feature_name]_screen.dart`
- Screen state provider: `lib/presentation/providers/[feature_name]_provider.dart` (if complex state needed)
- Local widgets: `lib/presentation/screens/[feature_name]/widgets/[widget_name].dart`
- Tests: `test/presentation/screens/[feature_name]_screen_test.dart`

**New Component/Widget (reusable):**
- Implementation: `lib/presentation/widgets/[component_name].dart` or `lib/presentation/widgets/[category]/[component_name].dart`
- Export from barrel: `lib/presentation/widgets/[category]/[category].dart` (if in category)
- Tests: `test/presentation/widgets/[component_name]_test.dart`

**Business Logic/Service:**
- New domain service: `lib/domain/services/[service_name]_service.dart`
- Core utility: `lib/core/utils/[utility_name].dart`
- Expose via provider: Add to `lib/presentation/providers/providers.dart` if needed at presentation layer

**Data Model:**
- New model class: `lib/data/models/[entity_name].dart`
- Add JSON serialization with `@JsonSerializable()` and `part '[entity_name].g.dart'`
- Use with existing repository or create new: `lib/data/repositories/[entity_name]_repository.dart`

**Repository:**
- New repository: `lib/data/repositories/[entity_name]_repository.dart`
- Delegate to `LocalDataSource` for persistence
- Add provider to `lib/presentation/providers/providers.dart`

**Utilities & Constants:**
- Shared constants: `lib/core/constants/[category]_constants.dart`
- Shared utilities: `lib/core/utils/[utility_name].dart`
- Extensions: `lib/core/extensions/[type_name]_extensions.dart`

## Special Directories

**lib/.dart_tool/**
- Purpose: Build artifacts and analysis cache
- Generated: Yes
- Committed: No (in .gitignore)
- Note: Contains Riverpod code generation outputs and build caches

**assets/data/**
- Purpose: Bundled application data
- Generated: No (songs.json manually created/updated)
- Committed: Yes (core data file)
- Note: Song format documented in `data/models/song.dart`

**assets/sheet_music/**
- Purpose: Pre-generated or pre-created sheet music files
- Generated: Likely external tool (not in repo currently)
- Committed: Selective (may be gitignored for space)
- Note: Files keyed by song number and transposition key (e.g., `151_Bb.svg`)

---

*Structure analysis: 2026-02-05*
