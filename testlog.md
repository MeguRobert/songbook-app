# Testlog

Done-but-unvalidated queue. Write each entry as a **checkable claim** — "X works because Y" —
so validation is fast. On validation, **delete the entry**; this file should only ever show
what's still pending review.

## Pending validation

<!-- - [ ] <claim>: X works because Y (commit <sha>) -->

## Test-suite bootstrap (2026-07-02, autonomous run)

Cluster 1 — pure logic — VALIDATED (`flutter test` green, 137 tests):
- [x] ChordTransposer covers all 12 semitones, sharp/flat spellings, -6..+5 range, wrap-around both ends, invalid-input pass-through — because test/unit/core/utils/chord_transposer_test.dart asserts each case and the suite is green.
- [x] semitonesBetween('C','F#') returns +6 (tritone is not folded to -6) — asserted as actual behavior.
- [x] TranspositionService preserves chord positions/text, returns identical instances for 0-semitone/no-chord inputs, respects targetKey flat/sharp spelling — transposition_service_test.dart.
- [x] SearchService exact-number short-circuit, prefix>contains ranking, diacritic/case-insensitive matching, tie-break by number, filterByTag, getAllTags — search_service_test.dart.
- [x] ViewConfig 4 states, presets, "notation:chords" round-trip, invalid-input fallback — view_config_test.dart.
- [x] StringExtensions + TextUtils all public helpers — string_extensions_test.dart, text_utils_test.dart.

Cluster 2 — models — VALIDATED (`flutter test` green, 209 tests):
- [x] All 6 model files (song incl. Origin/Tune/SheetMusic, verse, lyric_line, chord_position, favorite, notation) round-trip fromJson/toJson, honor @JsonKey defaults, computed properties — test/unit/data/models/*.

Cluster 3 — datasource + repositories — VALIDATED (`flutter test` green, 265 tests):
- [x] LocalDataSource loads/caches/sorts bundled songs.json, favorites CRUD with sortOrder, corrupt-JSON fallback, settings_ namespacing — local_datasource_test.dart (real SharedPreferences mock + real asset bundle).
- [x] Favorites/Settings/Song repositories delegate correctly incl. reorderFavorites re-assignment and getFavoriteSongs ordering — mocktail over LocalDataSource.

Cluster 4 — providers — VALIDATED (`flutter test` green, 341 tests):
- [x] theme/settings/favorites/search/song providers: initial load from prefs, state transitions, persistence, wrap +5→-6/-6→+5, clamps, lazy-notifier refresh, dispose-safety — test/unit/presentation/providers/*.
- [x] KNOWN QUIRK (documented in song_provider_test.dart): clearViewConfigForSong removes the persisted key but does NOT null the in-memory activeViewConfig (SongViewState.copyWith ?? swallows null); fresh openSong reflects the cleared state.

Cluster 5 — widget smoke tests — VALIDATED (final `flutter test`: 368 tests, all green; `flutter analyze test`: no issues):
- [x] App shell boots, bottom nav switches Songs/Favorites/Settings — widget_test.dart (songsProvider overridden: rootBundle loads don't complete under the widget-test fake-async zone).
- [x] song_list / song_view (chord view + favorite toggle + not-found) / settings (dialogs, font +) / search (typing drives provider) / favorites (empty + populated) / presentation (auto-hide timer flushed) — test/widget/*.
- [x] Custom Canvas sheet-music renderer + transposed re-render + no-sheet-music fallback render without exceptions — sheet_music_view_test.dart.
- [x] SongControlsSheet opens from FAB; transpose + and Lyrics preset drive the provider — song_controls_sheet_test.dart.

Coverage (flutter test --coverage, lcov line coverage): TOTAL 2261/2795 = 80.9%.
Core files: chord_transposer 35/36, transposition_service 28/28, search_service 37/38,
view_config 28/28, string_extensions 9/9, text_utils 20/21, models 95-100%,
datasource 51/53, repositories 100%, providers 94-100%.
No lib/ source files were modified.
