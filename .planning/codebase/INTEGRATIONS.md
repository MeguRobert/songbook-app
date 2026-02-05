# External Integrations

**Analysis Date:** 2026-02-05

## APIs & External Services

**None Detected** - This application has zero external API integrations. All content is bundled and stored locally.

## Data Storage

**Bundled Asset Database:**
- Location: `assets/data/songs.json`
- Type: Static JSON file bundled with app
- Loaded at: Startup, cached in memory via `LocalDataSource._cachedSongs`
- Access pattern: `rootBundle.loadString('assets/data/songs.json')` in `lib/data/datasources/local/local_datasource.dart`
- Failover: Empty list if file missing or invalid (line 28-30 of `local_datasource.dart`)

**Local Persistent Storage:**
- Provider: `shared_preferences` 2.3.5 (platform-native key-value store)
  - iOS: NSUserDefaults
  - Android: SharedPreferences
  - Web: localStorage
- Contents:
  - Favorites list (JSON serialized): key = `favorites`
  - Settings: key prefix = `settings_`
    - `settings_theme_mode` - Theme preference (light/dark/system)
    - `settings_default_transpose` - Default transposition semitones
    - `settings_show_chords` - Chord display toggle
    - `settings_font_size` - Font size preference
    - `settings_view_mode` - View mode selection (chords or sheet)
- Implementation: `lib/data/datasources/local/local_datasource.dart`
- Access layer: `lib/data/repositories/` (SongRepository, FavoritesRepository, SettingsRepository)

**File Storage:**
- **Sheet Music Assets**: Bundled SVG files
  - Location: `assets/sheet_music/`
  - Pattern: `{song_number}_{musical_key}.svg` (e.g., `151_C.svg` for song 151 in C major)
  - Font: Bravura.otf (standard music engraving font)
  - Access: `lib/data/models/song.dart` SheetMusic class, rendered via `lib/presentation/widgets/sheet_music/sheet_music_renderer.dart`
  - No external downloads; all notation shipped with app

- **Custom Fonts**: Bundled
  - Bravura.otf in `assets/fonts/`
  - Specified in `pubspec.yaml`

**Caching:**
- Application caching: In-memory
  - `LocalDataSource._cachedSongs` holds all songs after first load
  - No explicit cache invalidation except via `clearSongCache()`
- No third-party caching service

## Authentication & Identity

**None** - No user authentication or identity provider.

- App is single-user, offline-first
- No login/signup required
- No session management
- Settings and favorites stored locally on device only

## Monitoring & Observability

**Error Tracking:**
- None - No error reporting service integrated (Firebase Crashlytics, Sentry, etc.)

**Logs:**
- Console logging only via `print()` statements (not visible in production)
- No centralized logging service
- Analysis can use debugLogDiagnostics in GoRouter (`lib/router/app_router.dart` line 27)

## CI/CD & Deployment

**Hosting:**
- Not applicable - This is a mobile/desktop app, not web service
- Target deployment: iOS App Store, Google Play Store, or standalone builds

**CI Pipeline:**
- None configured - No GitHub Actions, CircleCI, Fastlane, etc. detected
- Manual build/deployment process likely

**Build Outputs:**
- iOS: `.ipa` or `.xcarchive` (for App Store) via Xcode/Fastlane
- Android: `.apk` or `.aab` (Google Play) via Gradle
- Web: HTML/CSS/JS transpiled via Dart-to-JS compiler

## Environment Configuration

**Required Environment Variables:**
- None - Application is self-contained with no external API keys or secrets

**Required Configuration:**
- None - All configuration is embedded in code or stored in SharedPreferences after first run

**Secrets Location:**
- N/A - No API keys, tokens, or credentials required
- All sensitive data handled locally on device

## Webhooks & Callbacks

**Incoming:**
- None - App does not expose any HTTP endpoints or webhooks

**Outgoing:**
- None - App makes no external HTTP requests or webhook calls

## Data Synchronization

**Cloud Sync:**
- None - No cloud storage or synchronization
- Favorites and settings stay on local device
- If user uninstalls app, all preferences and favorites are lost

**Backup:**
- Device-dependent
  - iOS: Automatically includes SharedPreferences in iCloud/iTunes backup (if enabled by user)
  - Android: Device-dependent backup service; may or may not include app data

## Platform-Specific Integrations

**iOS:**
- Native APIs used: UIKit, CoreText (via Flutter framework)
- No explicit iOS-specific integrations in app code
- Cupertino icons for iOS aesthetic

**Android:**
- Native APIs used: Android Framework libraries (via Flutter framework)
- No explicit Android-specific integrations in app code
- Material Design 3 for Android aesthetic

**Web (if enabled):**
- localStorage for persistent storage (SharedPreferences fallback)
- Dart-to-JavaScript transpilation via dart2js
- No special web APIs integrated (no IndexedDB, Service Workers, etc.)

## Third-Party Content

**SMUFL Music Standard Reference:**
- Reference documentation: https://w3c.github.io/smufl/latest/specification/engravingdefaults.html
- Located in: `lib/core/constants/engraving_constants.dart` comments
- Purpose: Music notation engraving constants and standards compliance

---

*Integration audit: 2026-02-05*

**Summary:** This is a zero-integration offline application. All content is bundled, all data stored locally. No external APIs, cloud services, or third-party platforms required.
