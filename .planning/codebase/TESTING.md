# Testing Patterns

**Analysis Date:** 2026-02-05

## Test Framework

**Runner:**
- `flutter_test` (built-in Flutter testing framework)
- Config: `C:\Users\rober\source\repos\songbook-app\songbook_app\test\`
- Integrated with Flutter SDK (no separate test config file)

**Assertion Library:**
- Flutter's built-in `expect()` and matchers
- No separate assertion library dependency

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --watch           # Watch mode (re-run on changes)
flutter test --coverage        # Generate coverage report
flutter test path/to/test.dart # Run specific test file
```

## Test File Organization

**Location:**
- Separate test directory: `C:\Users\rober\source\repos\songbook-app\songbook_app\test/`
- Not co-located with source files

**Naming:**
- Pattern: `*_test.dart`
- Example: Only `widget_test.dart` currently exists

**Current Test Structure:**
```
test/
└── widget_test.dart
```

## Mocking Framework

**Framework:**
- `mocktail` v1.0.4 (dependency in pubspec.yaml)
- Config: Added to dev_dependencies but no configuration file needed

**Not Yet Implemented:**
- Codebase contains no mock implementations currently
- Test file contains placeholder widget test only

## Test Fixtures and Factories

**Not Yet Implemented:**
- No test fixtures or test data factories exist
- Data setup would be needed for:
  - Song objects for testing repositories
  - Verse and LyricLine test data
  - Mock preferences for LocalDataSource testing

## Coverage

**Requirements:**
- No coverage requirements enforced
- No target coverage threshold configured

**View Coverage:**
```bash
flutter test --coverage
# Generates coverage data in coverage/lcov.info
# View with: genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

## Current Testing Status

**Existing Test:**
- File: `C:\Users\rober\source\repos\songbook-app\songbook_app\test\widget_test.dart`
- Type: Widget test placeholder
- Status: Placeholder only (no real assertions)

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    // Placeholder test - requires SharedPreferences mock setup
    // Full widget tests will be added in a future iteration
    expect(true, isTrue);
  });
}
```

**Issues with Current Test:**
- SharedPreferences requires mocking for widget tests to run
- No actual test coverage of application functionality
- Requires setup before running: `flutter test` will likely fail without mocking

## Test Types - Recommended Patterns

### Unit Tests

**Scope:**
- Test individual functions and classes
- No widget or framework dependencies

**Approach - Utility Classes:**
Example test for `ChordTransposer`:
```dart
void main() {
  group('ChordTransposer', () {
    test('transposeChord transposes C to D', () {
      final result = ChordTransposer.transposeChord('C', 2);
      expect(result, equals('D'));
    });

    test('transposeChord handles sharps', () {
      final result = ChordTransposer.transposeChord('C#', 1);
      expect(result, equals('D'));
    });

    test('parseChord extracts root and quality', () {
      final result = ChordTransposer.parseChord('Gm7');
      expect(result, equals(('G', 'm7')));
    });
  });
}
```

**Approach - Repository Tests:**
Example test for `SongRepository`:
```dart
void main() {
  late MockLocalDataSource mockDataSource;
  late SongRepository repository;

  setUp(() {
    mockDataSource = MockLocalDataSource();
    repository = SongRepository(mockDataSource);
  });

  group('SongRepository', () {
    test('getAllSongs returns song list', () async {
      final mockSongs = [
        Song(number: 1, title: 'Song 1', verses: []),
        Song(number: 2, title: 'Song 2', verses: []),
      ];
      when(() => mockDataSource.loadSongs())
          .thenAnswer((_) async => mockSongs);

      final result = await repository.getAllSongs();

      expect(result, equals(mockSongs));
      verify(() => mockDataSource.loadSongs()).called(1);
    });
  });
}
```

**Approach - Service Tests:**
Example test for `TranspositionService`:
```dart
void main() {
  const service = TranspositionService();

  group('TranspositionService', () {
    test('transposeChord transposes correctly', () {
      final result = service.transposeChord('C', 2);
      expect(result, equals('D'));
    });

    test('transposeLine updates all chords', () {
      final line = LyricLine(
        text: 'Hallelujah',
        chords: [
          ChordPosition(chord: 'C', position: 0),
          ChordPosition(chord: 'G', position: 5),
        ],
      );

      final transposed = service.transposeLine(line, 2);

      expect(transposed.chords[0].chord, equals('D'));
      expect(transposed.chords[1].chord, equals('A'));
    });
  });
}
```

### Widget Tests

**Scope:**
- Test individual widgets and screens
- Use WidgetTester for UI interaction
- Requires mocking dependencies (Riverpod, SharedPreferences)

**Approach - Provider Setup:**
```dart
void main() {
  testWidgets('SongListScreen displays songs', (WidgetTester tester) async {
    final mockSongs = [
      Song(number: 1, title: 'Test Song', verses: []),
    ];

    await tester.pumpWidget(
      ProviderContainer(
        overrides: [
          songsProvider.overrideWith((ref) async => mockSongs),
        ],
        child: const MaterialApp(home: SongListScreen()),
      ).widgets.first as Widget,
    );

    expect(find.text('Test Song'), findsOneWidget);
  });
}
```

**Approach - Interaction Testing:**
```dart
void main() {
  testWidgets('Song favorite button toggles', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderContainer(
        overrides: [
          favoritesProvider.overrideWith((ref) {
            return FavoritesNotifier(ref)..state = FavoritesState();
          }),
        ],
        child: const MaterialApp(home: SongViewScreen(songNumber: 1)),
      ).widgets.first as Widget,
    );

    final favoriteButton = find.byIcon(Icons.favorite_border);
    expect(favoriteButton, findsOneWidget);

    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
}
```

### Integration Tests

**Status:**
- Not currently used
- Would test full user flows (navigation, data loading, transposition)

**Recommended Location:**
- `C:\Users\rober\source\repos\songbook-app\songbook_app\integration_test\`

**Example Pattern:**
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete song viewing flow', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Tap song in list
    await tester.tap(find.text('Song 1'));
    await tester.pumpAndSettle();

    // Verify song details displayed
    expect(find.text('1. Test Song'), findsOneWidget);

    // Transpose and verify
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('+1 semitone'), findsOneWidget);
  });
}
```

## Mocking Patterns

### Using Mocktail

**Setup:**
```dart
import 'package:mocktail/mocktail.dart';

class MockLocalDataSource extends Mock implements LocalDataSource {}
class MockSongRepository extends Mock implements SongRepository {}
```

**Mocking Futures:**
```dart
when(() => mockRepository.getAllSongs())
    .thenAnswer((_) async => [song1, song2]);
```

**Mocking State Changes:**
```dart
when(() => mockNotifier.toggleFavorite(any()))
    .thenAnswer((_) async => null);
```

**Verifying Calls:**
```dart
verify(() => mockRepository.getAllSongs()).called(1);
verify(() => mockRepository.getSongByNumber(1)).called(1);
```

### Mocking SharedPreferences

**Pattern:**
```dart
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'favorites': jsonEncode([]),
      'settings_viewMode': 'chords',
    });
  });
}
```

### Mocking Riverpod Providers

**Pattern:**
```dart
test('Song loading from provider', () async {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(mockPrefs),
      songRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );

  final result = await container.read(songsProvider.future);
  expect(result, equals(expectedSongs));
});
```

## What to Mock

**Should Mock:**
- External data sources: `LocalDataSource`, repositories
- Platform-specific APIs: `SharedPreferences`, `rootBundle`
- Riverpod dependencies when testing components in isolation

**Should NOT Mock:**
- Business logic utilities: `ChordTransposer`, `TranspositionService`
- Data models: Test with real Song/Verse objects
- Core Flutter functionality: Widgets, Material components

## Testing Async Code

**Pattern - Futures:**
```dart
test('getSongByNumber returns song', () async {
  when(() => mockDataSource.getSongByNumber(1))
      .thenAnswer((_) async => testSong);

  final result = await repository.getSongByNumber(1);

  expect(result, equals(testSong));
});
```

**Pattern - FutureProviders:**
```dart
test('songsProvider provides songs', () async {
  final container = ProviderContainer(
    overrides: [
      songRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );

  final future = container.read(songsProvider.future);
  final songs = await future;

  expect(songs, isNotEmpty);
});
```

**Pattern - Widget Async:**
```dart
testWidgets('Widget updates after async load', (WidgetTester tester) async {
  await tester.pumpWidget(testApp);

  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  await tester.pumpAndSettle(); // Wait for all animations/futures

  expect(find.byType(SongListTile), findsWidgets);
});
```

## Testing Error Cases

**Pattern - Null Returns:**
```dart
test('getSongByNumber returns null for missing song', () async {
  when(() => mockDataSource.getSongByNumber(999))
      .thenAnswer((_) async => null);

  final result = await repository.getSongByNumber(999);

  expect(result, isNull);
});
```

**Pattern - Empty Collections:**
```dart
test('loadSongs returns empty list on missing file', () async {
  when(() => mockDataSource.loadSongs())
      .thenAnswer((_) async => []);

  final result = await repository.getAllSongs();

  expect(result, isEmpty);
});
```

**Pattern - Widget Error Display:**
```dart
testWidgets('Shows error message when loading fails', (WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderContainer(
      overrides: [
        songsProvider.overrideWithValue(AsyncValue.error('Load failed', StackTrace.current)),
      ],
      child: const MaterialApp(home: SongListScreen()),
    ).widgets.first as Widget,
  );

  expect(find.text('Failed to load songs'), findsOneWidget);
});
```

## Testing Provider State

**Pattern - StateNotifier:**
```dart
test('SongViewNotifier opens and closes song', () {
  final notifier = SongViewNotifier();

  notifier.openSong(1);
  expect(notifier.state?.songNumber, equals(1));

  notifier.closeSong();
  expect(notifier.state, isNull);
});
```

**Pattern - State Updates:**
```dart
test('FavoritesNotifier toggles favorite', () async {
  final container = ProviderContainer();
  final notifier = container.read(favoritesProvider.notifier);

  notifier.addFavorite(1);
  expect(container.read(favoritesProvider).isFavorite(1), isTrue);

  notifier.removeFavorite(1);
  expect(container.read(favoritesProvider).isFavorite(1), isFalse);
});
```

## Common Test Patterns

### Test Group Organization

```dart
void main() {
  group('SongRepository', () {
    late MockLocalDataSource mockDataSource;
    late SongRepository repository;

    setUp(() {
      mockDataSource = MockLocalDataSource();
      repository = SongRepository(mockDataSource);
    });

    group('getAllSongs', () {
      test('returns all songs', () async { ... });
      test('returns empty list when no songs', () async { ... });
    });

    group('getSongByNumber', () {
      test('returns song by number', () async { ... });
      test('returns null for missing song', () async { ... });
    });
  });
}
```

### setUp/tearDown

```dart
void main() {
  late MockLocalDataSource mockDataSource;
  late SongRepository repository;

  setUp(() {
    mockDataSource = MockLocalDataSource();
    repository = SongRepository(mockDataSource);
  });

  tearDown(() {
    // Cleanup if needed
    reset(mockDataSource);
  });
}
```

### Parameterized Tests

```dart
void main() {
  const testChords = [
    ('C', 1, 'C#'),
    ('C#', 1, 'D'),
    ('B', 1, 'C'),
  ];

  for (final (input, semitones, expected) in testChords) {
    test('transposes $input by $semitones to $expected', () {
      final result = ChordTransposer.transposeChord(input, semitones);
      expect(result, equals(expected));
    });
  }
}
```

## Dependencies for Testing

**Configured in pubspec.yaml:**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
  flutter_lints: ^5.0.0
```

**Not Configured (but recommended to add):**
- `integration_test`: For E2E testing
- `coverage`: For coverage reporting (if generating reports)

---

*Testing analysis: 2026-02-05*
