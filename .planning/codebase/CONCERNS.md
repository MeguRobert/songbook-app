# Codebase Concerns

**Analysis Date:** 2026-02-05

## Tech Debt

**Error Handling Gaps:**
- Issue: Silent error catching with `catch (_)` throughout codebase ignores actual error details
- Files: `songbook_app/lib/data/datasources/local/local_datasource.dart` (lines 27, 39, 59), `songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart` (lines 341-346)
- Impact: Bugs in JSON parsing, asset loading, or storage operations fail silently. Users see "not found" messages without knowing why (invalid JSON, missing file, corrupted data). Makes debugging difficult.
- Fix approach: Log errors with `debugPrint()` or proper logging framework before swallowing exceptions. Distinguish between "asset missing" vs "corrupt data" vs "parsing error" and handle each case specifically.

**Comprehensive Test Coverage Absence:**
- Issue: Only placeholder widget test exists; no unit, integration, or meaningful test coverage
- Files: `songbook_app/test/widget_test.dart` (9 lines, placeholder only)
- Impact: Refactoring complex components like `SheetMusicPainter` (952 lines), `SheetMusicLayout` (638 lines), `TransposeControls` (657 lines), or `ChordTransposer` is risky. Transposition bugs go undetected. No safety net for dependency updates.
- Fix approach: Add unit tests for `ChordTransposer`, `TranspositionService`, `SearchService`. Add widget tests for major screens. Use `mocktail` (already in pubspec) to mock `SharedPreferences` and repositories.

**Missing Provider Initialization Documentation:**
- Issue: `sharedPreferencesProvider` throws `UnimplementedError` if accessed before `main()` initializes it
- Files: `songbook_app/lib/presentation/providers/providers.dart` (lines 14-16)
- Impact: New developers might accidentally use this provider elsewhere without realizing it requires initialization. Could cause runtime crashes if code is added in wrong place.
- Fix approach: Add clear comment documenting the initialization contract. Consider using a safer pattern like `AsyncValue` or lazy initialization.

## Known Bugs

**Transposition Wrapping Logic Symmetry Issue:**
- Symptoms: Transposition wraps at +12 to -11 for up, but -11 to +12 for down. Asymmetric range (-11 to +12 covers 24 semitones, inconsistent cycle).
- Files: `songbook_app/lib/presentation/providers/song_provider.dart` (lines 70-82)
- Trigger: Use transpose controls repeatedly. The wrapping happens at odd boundaries.
- Current behavior: Works but confusing. User expects symmetric wrapping like -6 to +6 or -12 to +12.
- Workaround: None—users accept the current behavior
- Fix approach: Change to symmetric range: either -6 to +5 (12 semitones), -11 to +11 (23 semitones), or -12 to +12 (24 semitones). Update both `transposeUp()` and `transposeDown()` methods to match.

**SVG Asset Loading Fallback Fragile:**
- Symptoms: Sheet music view tries transposed key, falls back to original. But if original is also missing, shows "Sheet music not available". User thinks transposition failed when really asset is missing.
- Files: `songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart` (lines 200-209, 340-346)
- Trigger: Add notation to song but forget to export SVG for original key
- Current behavior: Falls back silently to plain text
- Workaround: User switches to chord view
- Fix approach: Distinguish between "transposed key missing" (OK, show original) vs "original key also missing" (error). Log which paths were attempted. Show debug info in development.

## Performance Bottlenecks

**Large JSON Asset Loaded Into Memory:**
- Problem: `LocalDataSource.loadSongs()` loads entire `songs.json` into memory and caches it indefinitely
- Files: `songbook_app/lib/data/datasources/local/local_datasource.dart` (lines 18-31)
- Cause: `_cachedSongs` field holds full list. No pagination or lazy loading. If songs.json grows to 1000+ songs with full notation data, memory grows linearly.
- Current capacity: Works fine for ~50-100 songs. Breaks around 500+ songs (estimated).
- Impact: Slow app startup, memory churn on older devices, GC pauses
- Improvement path: Implement pagination or lazy loading. Load song count only for list view, load full song only when user selects it. Use `FutureProvider.family` with caching for individual songs.

**Sheet Music Renderer Recalculates Layout on Every Transpose:**
- Problem: `SheetMusicRenderer._calculateLayout()` is called on `transpose` change in `didUpdateWidget()`, triggering full re-layout
- Files: `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_renderer.dart` (lines 52-57)
- Cause: No memoization or incremental update. Re-positions every note, syllable, chord on every semitone change.
- Impact: Visible lag when using transpose controls, especially on large sheets with 500+ notes. Animation feels jerky.
- Improvement path: Cache layout for original key. For transposition, only update transposed pitches and chords, not positions. Separate data from layout.

**Chord Line Width Estimation Inaccurate:**
- Problem: `ChordView._buildChordLine()` uses `charWidth = fontSize * 0.55` as approximation
- Files: `songbook_app/lib/presentation/screens/song_view/widgets/chord_view.dart` (line 200)
- Cause: Hardcoded multiplier ignores actual font metrics. Works for default font, breaks with custom fonts or font size extremes.
- Impact: Chords misaligned with lyrics at text scale < 0.8 or > 1.5. Looks sloppy.
- Improvement path: Use `TextPainter` to measure actual text width instead of estimation. Cache measurements per fontSize.

## Fragile Areas

**Complex Sheet Music Painter:**
- Files: `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_painter.dart` (952 lines)
- Why fragile: Monolithic custom painter with multiple responsibilities (staff lines, notes, stems, beams, lyrics, chords, bar lines). Coordinate calculations are interdependent. Small changes to one element affect spacing of all downstream elements.
- Safe modification: Extract sub-painters for (1) staff + bar lines, (2) notes + stems + beams, (3) lyrics, (4) chords. Each can have independent coordinate system and be tested separately.
- Test coverage: No tests. High risk of regression when adding new note types or notation features.

**Layout Engine State Machine:**
- Files: `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_layout.dart` (638 lines), `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_renderer.dart` (377 lines)
- Why fragile: Layout calculation depends on ordered sequence: measure positioning → note positioning → syllable positioning → chord positioning. If measures have inconsistent widths, all downstream positions become wrong. No validation that input data matches expected constraints.
- Safe modification: Add invariant checks at each step. Test with edge cases: zero-duration notes, notes with no lyrics, multiple chord stacks, very long song names.
- Test coverage: No tests. Risk of silent layout corruption with invalid notation JSON.

**Transpose State Management:**
- Files: `songbook_app/lib/presentation/providers/song_provider.dart` (lines 67-82, 119-122), `songbook_app/lib/presentation/screens/song_view/widgets/transpose_controls.dart` (657 lines)
- Why fragile: Multiple places modify transpose state: `TransposeControls` calls `songViewProvider.notifier.transposeUp/Down()`, `FloatingControlsMenu` calls same methods, some buttons call `setTranspose()` directly. If one caller forgets to call `resetTranspose()` on screen exit, transpose state leaks to next song.
- Safe modification: Ensure transpose is tied to `songViewNotifier.openSong()` and cleared in `closeSong()`. Test navigation flow: open song A, transpose, navigate to B, back to A (should be untransposed).
- Test coverage: No tests. Users report transpose state persisting incorrectly between songs.

## Scaling Limits

**Single Song JSON File:**
- Current capacity: ~2 MB (50-100 songs with full notation, sheet music paths, lyrics)
- Limit: Hits 10+ MB around 500 songs. Parsing becomes slow (seconds on weak devices).
- Scaling path: (1) Split into multiple JSON files by range (songs 1-100, 101-200, etc.), load on demand. (2) Pre-compile to binary format (MessagePack/ProtoBuf) for faster parsing. (3) Use SQLite for songs table instead of JSON.

**Memory With Large Notation:**
- Current capacity: 50 songs with notation fits in 50 MB
- Limit: 500+ songs with notation exceeds 500 MB, causes GC thrashing
- Scaling path: Implement `LruCache` for in-memory notation. Load notation only when displaying song. Cache up to 5 songs' notation, evict least recently used.

**Sheet Music Canvas Complexity:**
- Current capacity: Up to 10 systems (6-8 measures per system) renders smoothly
- Limit: 20+ systems (20+ measures) causes frame drops and memory spikes
- Scaling path: Implement paging—render only visible systems. Use `SliverList` with lazy rendering for vertical scrolling of systems.

## Security Considerations

**No Input Validation on Song Data:**
- Risk: Malformed JSON could crash app or cause unexpected behavior. Notation JSON with null pitches, negative durations, or huge coordinate values could cause memory exhaustion or infinite loops.
- Files: `songbook_app/lib/data/datasources/local/local_datasource.dart` (line 24), model `fromJson()` methods in `songbook_app/lib/data/models/`
- Current mitigation: Dart's type system provides some safety. `json_serializable` code generation handles missing fields with defaults.
- Recommendations: (1) Add validation layer after JSON deserialization. Check pitch format (`[A-G][#b]?\d`), duration values (0-4 only), bounds. (2) Reject songs with > 10,000 notes or coordinate values > 100,000. (3) Log and skip invalid entries rather than crashing.

**Asset Loading Without Path Validation:**
- Risk: If notation JSON specifies arbitrary asset paths, could attempt to load from unexpected locations.
- Files: `songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart` (line 200)
- Current mitigation: Asset paths are hardcoded in Song model and validated before use.
- Recommendations: (1) Whitelist allowed asset directories (only `assets/sheet_music/`). (2) Reject paths with `..` or absolute paths.

## Dependencies at Risk

**flutter_riverpod 2.6.1:**
- Risk: StateNotifier is deprecated in favor of Notifier. Future major version may remove it.
- Impact: Code uses StateNotifier extensively (SongViewNotifier, SettingsNotifier, FavoritesNotifier, SearchNotifier). Upgrade to Riverpod 3.x would require rewriting all notifiers.
- Files: `songbook_app/lib/presentation/providers/*.dart`
- Migration plan: Plan migration in phases. Start new providers with Notifier pattern. Convert high-traffic providers (songViewProvider, settingsProvider) first. Use codemods to automate conversion.

**json_serializable 6.9.4:**
- Risk: Build runner dependency. If Dart SDK constraints become mismatched, builds fail cryptically.
- Impact: Can't add new JSON models without running `build_runner`. Slow build times.
- Current state: Works fine, but build warnings may appear with SDK updates.
- Mitigation: Keep `build_runner` in sync with `json_serializable`. Monitor for deprecation warnings.

## Test Coverage Gaps

**ChordTransposer Algorithm:**
- What's not tested: Core transposition logic—semitone wrapping, flat vs sharp selection, minor key handling
- Files: `songbook_app/lib/core/utils/chord_transposer.dart`
- Risk: Transposition bugs produce wrong chords (G to G# gives wrong result, Bb to B wraps wrong, Cm transposition breaks)
- Priority: **High** — Transposition is core feature. Users rely on it.
- Test plan: Add unit tests for `transposeChord()`: test all 12 notes × 12 semitones, test sharp/flat selection, test minor keys, test boundary cases (+11, -11).

**SearchService Matching:**
- What's not tested: Search algorithm—number matching, title matching, reference matching, partial matches
- Files: `songbook_app/lib/domain/services/search_service.dart`
- Risk: Search doesn't find songs (query "psalm" finds nothing), or returns wrong results
- Priority: **High** — Search is main navigation method.
- Test plan: Add unit tests with sample song data. Test exact match, partial match, case-insensitive, number prefix.

**Sheet Music Rendering Edge Cases:**
- What's not tested: Layout with edge-case notation: single-note songs, songs with rests only, very high/low notes, overlapping syllables, long chord names
- Files: `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_painter.dart`, `sheet_music_layout.dart`
- Risk: App crashes or renders garbage on unusual notation
- Priority: **Medium** — Rare but critical when they occur.
- Test plan: Create test notation fixtures for edge cases. Add golden file tests for visual regression.

**Navigation State:**
- What's not tested: Navigation between screens doesn't corrupt state (transpose, favorites, scroll position)
- Files: `songbook_app/lib/router/app_router.dart`, screen files
- Risk: Users report inconsistent state, favorites disappearing, transpose sticking
- Priority: **Medium** — Affects user experience but not core functionality.
- Test plan: Add integration tests navigating: List → Song → Transpose → List → Favorites → Song (check transpose is reset). Use `WidgetTester` to verify state.

**Settings Persistence:**
- What's not tested: Settings saved to SharedPreferences survive app restart
- Files: `songbook_app/lib/presentation/providers/settings_provider.dart`, `songbook_app/lib/data/datasources/local/local_datasource.dart`
- Risk: Font size, view mode, or other settings reset on app restart
- Priority: **Medium** — User convenience.
- Test plan: Unit test that reads/writes each setting type. Integration test that sets value, simulates restart, verifies persistence.

## Missing Critical Features

**Error Boundary / User-Facing Error Screens:**
- Problem: If JSON parsing fails, songs.json is missing, or SharedPreferences fails, users see blank screens or generic errors. No recovery path.
- Blocks: Can't handle corrupted data gracefully. Can't debug user issues.
- Impact: Users confused by blank app. Developers can't help without logs.
- Fix: Implement error boundary at app root. Show user-friendly error screen with "Try Again" button. Log errors with stack traces (locally, not remotely for privacy).

**Offline Indicator / Data Loading States:**
- Problem: App loads all data at startup (synchronous). If songs.json is slow to parse, app freezes.
- Blocks: Can't show progress. Can't lazy-load additional data.
- Impact: On older devices, users think app is frozen.
- Fix: Implement async loading with progress indicator. Show skeleton loaders while loading.

**Undo / History for Transposition:**
- Problem: Once you transpose, can't easily go back to original key. Must use reset button (which resets to 0, not to "where you started").
- Blocks: Users do multi-step transpose, get lost, start over.
- Impact: Workflow friction.
- Fix: Add history stack. Allow "undo" transpose to previous setting.

---

*Concerns audit: 2026-02-05*
