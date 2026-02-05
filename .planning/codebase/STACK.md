# Technology Stack

**Analysis Date:** 2026-02-05

## Languages

**Primary:**
- Dart 3.9.0+ - All application code, Flutter framework

**Secondary:**
- Swift/Kotlin - Platform-specific code (auto-generated, iOS/Android native layers)

## Runtime

**Environment:**
- Flutter SDK (3.x) - Cross-platform mobile/web runtime
- Dart VM - Execution runtime for Dart code

**Package Manager:**
- pub (Dart Package Manager) - Bundled with Flutter SDK
- Lockfile: `pubspec.lock` (present)

## Frameworks

**Core:**
- Flutter 3.x - UI framework for iOS, Android, web, desktop
- Material Design 3 - UI design system (configured via `uses-material-design: true`)

**State Management:**
- flutter_riverpod 2.6.1 - Provider-based state management with compile-time safety
  - Location: `lib/presentation/providers/`
  - Pattern: Providers (immutable), StateNotifierProviders (mutable)
  - Key providers: `sharedPreferencesProvider`, `songRepositoryProvider`, `favoritesRepositoryProvider`, `settingsRepositoryProvider`

**Routing:**
- go_router 14.8.1 - Declarative routing with named routes
  - Location: `lib/router/app_router.dart`
  - Routes: home (`/`), song (`/song/:id`), favorites (`/favorites`), search (`/search`), settings (`/settings`)
  - Navigation pattern: ShellRoute for bottom navigation, GoRoute for individual screens

**Testing:**
- flutter_test - Flutter testing framework (SDK test runner)
- mocktail 1.0.4 - Mocking library for unit/widget tests
- Test structure: `test/` directory with `unit/`, `widget/`, `integration/` subdirectories

**Build/Code Generation:**
- build_runner 2.4.15 - Code generator orchestrator
- json_serializable 6.9.4 - JSON serialization/deserialization code generator
  - Generates `.g.dart` files for models (Song, Notation, Verse, LyricLine, ChordPosition, Favorite)

**UI Components:**
- flutter_svg 2.0.17 - SVG rendering for sheet music notation
  - Used in: `lib/presentation/widgets/sheet_music/`
  - Purpose: Custom musical notation rendering using Bravura font engraving

**Utilities:**
- shared_preferences 2.3.5 - Local persistent key-value storage
  - Purpose: Theme mode, settings, favorites metadata
  - Initialized in `main()` and provided via Riverpod
  - Keys stored with prefixes: `settings_` for app settings, `favorites` for favorite songs list

- path_provider 2.1.5 - Platform-specific directory paths
  - Purpose: Access to app documents, cache, temporary directories (if needed)

- json_annotation 4.9.0 - JSON serialization annotations
  - Paired with json_serializable for code generation

- collection 1.19.1 - Dart collection utilities
  - Purpose: Enhanced list, set, map operations

- cupertino_icons 1.0.8 - iOS-style icons
  - Purpose: Platform-aware icon set

## Configuration

**Linting & Analysis:**
- flutter_lints 5.0.0 - Official Dart/Flutter lint rules
  - Config: `analysis_options.yaml` (uses `package:flutter_lints/flutter.yaml`)
  - Enforces: Null safety, consistency, best practices

**Environment:**
- Dart SDK version constraint: `^3.9.0`
- App version: `1.0.0+1` (semantic version + build number)
- No environment variables required for core functionality (configuration is embedded in code and SharedPreferences)

**Build Targets:**
- Android: API 21+ (default Flutter configuration)
- iOS: iOS 11.0+ (default Flutter configuration)
- Web: Chrome, Firefox, Safari (Dart transpilation to JavaScript)
- Desktop: Windows, macOS, Linux (if enabled)

## Assets

**Bundled Content:**
- `assets/sheet_music/` - SVG notation files for each song in each transposition key
  - Naming: `{song_number}_{key}.svg` (e.g., `151_C.svg`, `151_F.svg`)
- `assets/data/` - `songs.json` bundled song database (root bundle loaded at startup)
- `assets/icons/` - Custom app icons
- `assets/fonts/` - Bravura.otf music engraving font for sheet music notation

## Data Model

**Serialization:**
- Format: JSON (json_serializable with freezed-like code generation)
- Models in `lib/data/models/`:
  - `Song` - Complete song metadata and content
  - `Notation` - Sheet music SVG file references
  - `Verse` - Song section (lyrics + chord positions)
  - `LyricLine` - Individual lyric line with attached chords
  - `ChordPosition` - Chord placement coordinates within a line
  - `Favorite` - Metadata for favorited songs (timestamp, sort order)
  - `Origin` - Tune origin information (place, year)
  - `Tune` - Tune metadata (name, origin)
  - `SheetMusic` - Sheet music file configuration (type, basePath, transposition keys)

## Platform Requirements

**Development:**
- Dart SDK 3.9.0+
- Flutter SDK (stable channel)
- IDE: Android Studio / VS Code with Dart/Flutter extensions
- For iOS: macOS, Xcode 12+
- For Android: Android Studio or SDK tools

**Production:**
- **Mobile:** iOS 11.0+ / Android API 21+
- **Web:** Standard web browsers (Chrome, Firefox, Safari, Edge)
- **Deployment:** Platform app stores (Apple App Store, Google Play) or web hosting

## Key Dependencies

**Critical:**
- `flutter_riverpod` - All state management depends on this; core to provider pattern
- `go_router` - All navigation; breaking changes would affect routing throughout app
- `shared_preferences` - Persistent storage of favorites and settings; no offline data without this
- `flutter_svg` - Sheet music rendering; app purpose depends on SVG notation display

**Infrastructure:**
- `json_serializable` - Code generation; build-time dependency for model serialization
- `build_runner` - Code generation orchestration; must be run before JSON serialization works
- `flutter_lints` - Code quality; enforces consistency across codebase

## Architecture Notes

**Dependency Injection:**
- Riverpod providers in `lib/presentation/providers/providers.dart` create dependency graph
- Pattern: Repositories → Services → UI (Screens/Providers)
- No service locator; all dependencies resolved through provider graph

**Data Flow:**
- UI screens call providers that depend on repositories
- Repositories wrap local data sources (currently `LocalDataSource` only)
- `LocalDataSource` handles SharedPreferences + asset loading
- No remote API clients; all data is bundled

**Code Generation:**
- Run `flutter pub run build_runner build` to generate `.g.dart` files
- Generated files: Model serialization, enum/union support
- No code generation for providers or routing (both use annotations-based but built into libraries)

---

*Stack analysis: 2026-02-05*
