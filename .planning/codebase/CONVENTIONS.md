# Coding Conventions

**Analysis Date:** 2026-02-05

## Naming Patterns

**Files:**
- Dart files: `snake_case.dart` (e.g., `song_provider.dart`, `app_router.dart`, `chord_transposer.dart`)
- Directory names: `snake_case` (e.g., `lib/presentation/screens/song_view/`, `lib/data/models/`)
- Generated files: `.g.dart` suffix for code generation (e.g., `song.g.dart` from json_serializable)

**Classes:**
- `PascalCase` for all classes, including state classes and exceptions
- Examples: `Song`, `SongViewState`, `ChordTransposer`, `LocalDataSource`, `FavoritesNotifier`
- Utility classes with private constructor: `class MusicConstants { MusicConstants._(); }`

**Functions/Methods:**
- `camelCase` for all functions and methods
- Private methods prefixed with underscore: `_calculateLayout()`, `_transposePitch()`, `_keyToIndex()`
- Getters for computed properties: `get displayText`, `get firstVerse`, `get isFavorite(int)`

**Variables:**
- `camelCase` for local variables and parameters
- Constant values: `camelCase` in classes (not UPPER_SNAKE_CASE)
  - Example: `static const _favoritesKey = 'favorites'` (private constants)
  - Example: `static const String home = '/'` (public constants)

**Types & Generics:**
- Standard Dart naming: `Future<Song>`, `List<String>`, `Set<int>`
- Record types: `(String, String)?` for tuples from parseChord

## Code Style

**Formatting:**
- Uses Flutter's standard Dart formatting (2-space indentation)
- Applied via `flutter format` or IDE auto-formatting
- Line length: no explicit limit enforced, but code reads cleanly at 80-100 chars

**Linting:**
- Enabled: `package:flutter_lints/flutter.yaml` (included in analysis_options.yaml)
- Config: `C:\Users\rober\source\repos\songbook-app\songbook_app\analysis_options.yaml`
- Default rules from flutter_lints applied without overrides
- No additional custom lint rules configured

**Constants:**
- All constants defined in dedicated files: `C:\Users\rober\source\repos\songbook-app\songbook_app\lib\core\constants\`
- MusicConstants: `C:\Users\rober\source\repos\songbook-app\songbook_app\lib\core\constants\music_constants.dart`
- AppColors: `C:\Users\rober\source\repos\songbook-app\songbook_app\lib\core\constants\app_colors.dart`
- EngineeringConstants: `C:\Users\rober\source\repos\songbook-app\songbook_app\lib\core\constants\engraving_constants.dart`

## Import Organization

**Order:**
1. Dart imports: `import 'dart:convert';`
2. Flutter/package imports: `import 'package:flutter/material.dart';`
3. Relative imports: `import '../../data/models/song.dart';`

**Examples:**
```dart
// song.dart
import 'package:json_annotation/json_annotation.dart';
import 'notation.dart';
import 'verse.dart';

part 'song.g.dart';
```

```dart
// app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/theme_provider.dart';
import 'router/app_router.dart';
```

**Path Aliases:**
- Not currently used; relative imports from lib root preferred

**Barrel Exports:**
- Central provider file: `C:\Users\rober\source\repos\songbook-app\songbook_app\lib\presentation\providers\providers.dart`
- Contains all root-level provider definitions and injections

## Documentation

**Comments:**
- Triple-slash `///` for public API documentation
- Double-slash `//` for inline implementation notes
- Used consistently for classes, public methods, and state classes

**Documentation Style:**
```dart
/// Provider for all songs
final songsProvider = FutureProvider<List<Song>>((ref) async {
  final repository = ref.watch(songRepositoryProvider);
  return repository.getAllSongs();
});

/// Transposes a single chord by the given number of semitones
///
/// [chord] - The chord to transpose (e.g., "Gm7", "Bb", "F#dim")
/// [semitones] - Number of semitones to transpose (positive = up, negative = down)
/// [useFlats] - Whether to use flat notation for the result
static String transposeChord(String chord, int semitones, {bool useFlats = false}) {
```

**No TODOs/FIXMEs:**
- Codebase has zero TODO/FIXME comments indicating active development without technical debt tracking in code

## Error Handling

**Pattern: Silent Fallback**
- Try-catch blocks with fallback return values (empty lists or null)
- Example from LocalDataSource:
```dart
Future<List<Song>> loadSongs() async {
  if (_cachedSongs != null) return _cachedSongs!;

  try {
    final jsonString = await rootBundle.loadString('assets/data/songs.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    _cachedSongs = jsonList.map((json) => Song.fromJson(json)).toList();
    _cachedSongs!.sort((a, b) => a.number.compareTo(b.number));
    return _cachedSongs!;
  } catch (e) {
    // Return empty list if file doesn't exist or is invalid
    _cachedSongs = [];
    return _cachedSongs!;
  }
}
```

**Pattern: firstWhere with Fallback**
```dart
Future<Song?> getSongByNumber(int number) async {
  final songs = await loadSongs();
  try {
    return songs.firstWhere((s) => s.number == number);
  } catch (_) {
    return null;
  }
}
```

**Pattern: Validation Before Action**
```dart
Future<void> toggleFavorite(int songNumber) async {
  if (state.isFavorite(songNumber)) {
    // Already favorite, remove it
  } else {
    // Not favorite, add it
  }
}
```

**No Exceptions Thrown:**
- Application returns null/empty collections rather than throwing exceptions
- Defensive design for UI stability

## Async/Await Patterns

**Async Methods:**
- Marked with `async` keyword when using `await`
- Return `Future<T>` or `Future<void>`
- Examples: Repository methods, LocalDataSource operations

**Provider Async:**
- FutureProvider for async data: `FutureProvider<List<Song>>((ref) async { ... })`
- StateNotifier with async operations: `Future<void> toggleFavorite(int songNumber) async { ... }`

**Widget Async:**
- WidgetsBinding callbacks for post-frame initialization:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(songViewProvider.notifier).openSong(widget.songNumber);
  });
}
```

## Function Design

**Size Guidelines:**
- Functions typically 5-30 lines
- Large operations delegated to separate utility classes
- Example: `ChordTransposer` static methods for music operations

**Parameters:**
- Required parameters first, then optional/named parameters
- Named parameters with defaults preferred for optional values
```dart
SheetMusicRenderer({
  super.key,
  required this.song,
  required this.notation,
  this.transpose = 0,
  this.fallback,
})
```

**Return Values:**
- Nullable returns use `?` operator: `Song?`, `String?`
- Collections default to non-null empty: `List<Song>` defaults to `[]`
- Use `??` operator for null coalescing

## Null Safety

**Strict Null Safety:**
- All properties explicitly marked as nullable with `?` or non-null
- `!` operator used only after null checks or when certainty established
- Late keyword not used (rare in codebase)

**Example Pattern:**
```dart
final Verse? get firstVerse => verses.isNotEmpty ? verses.first : null;

String? get displayString {
  if (place == null && year == null) return null;
  if (place != null && year != null) return '$place, $year';
  return place ?? year?.toString();
}
```

## Data Classes

**Pattern: Model Class with Serialization**
- JSON serializable with `json_annotation` package
- Includes `copyWith()` method for immutable updates
- Implements `==` and `hashCode` for equality
- Includes `toString()` for debugging

```dart
@JsonSerializable()
class Song {
  final int number;
  final String title;
  final List<Verse> verses;

  const Song({
    required this.number,
    required this.title,
    required this.verses,
  });

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
  Map<String, dynamic> toJson() => _$SongToJson(this);

  Song copyWith({
    int? number,
    String? title,
    List<Verse>? verses,
  }) {
    return Song(
      number: number ?? this.number,
      title: title ?? this.title,
      verses: verses ?? this.verses,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          number == other.number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'Song(number: $number, title: $title)';
}
```

## State Management

**Provider Pattern:**
- Simple values: `Provider<T>((ref) { ... })`
- Async data: `FutureProvider<T>((ref) async { ... })`
- Parametrized: `FutureProvider.family<T, Param>((ref, param) async { ... })`
- State with notifier: `StateNotifierProvider<Notifier, State>((ref) { ... })`

**State Classes:**
- Immutable state classes with `const` constructor
- Include `copyWith()` for updates
- State pattern used in: `SongViewState`, `FavoritesState`

**Notifier Pattern:**
```dart
class SongViewNotifier extends StateNotifier<SongViewState?> {
  SongViewNotifier() : super(null);

  void openSong(int songNumber) {
    state = SongViewState(songNumber: songNumber);
  }

  void setTranspose(int semitones) {
    if (state != null) {
      state = state!.copyWith(transposeAmount: semitones);
    }
  }
}
```

## Widget Conventions

**ConsumerWidget for Reading Providers:**
```dart
class SongListScreen extends ConsumerWidget {
  const SongListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);
    // ...
  }
}
```

**ConsumerStatefulWidget for Lifecycle:**
```dart
class SongViewScreen extends ConsumerStatefulWidget {
  final int songNumber;

  const SongViewScreen({
    required this.songNumber,
    super.key,
  });

  @override
  ConsumerState<SongViewScreen> createState() => _SongViewScreenState();
}

class _SongViewScreenState extends ConsumerState<SongViewScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize after build
  }

  @override
  void dispose() {
    // Cleanup
    super.dispose();
  }
}
```

## Extension Methods

**Pattern: String Extensions**
- File: `C:\Users\rober\source\repos\songbook-app\songbook_app\lib\core\extensions\string_extensions.dart`
- Used for domain-specific operations (Hungarian diacritics, search normalization)

```dart
extension StringExtensions on String {
  /// Capitalizes the first letter
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Removes Hungarian diacritics for search
  String removeDiacritics() { ... }

  /// Normalized search comparison
  bool containsNormalized(String query) { ... }
}
```

---

*Convention analysis: 2026-02-05*
