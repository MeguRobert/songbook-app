import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';

/// The rules the remembered-search list follows.
///
/// It is shown in the space a search field has just opened into, so it has to be
/// short, in the order the user last used, and free of entries that only differ
/// by capitalisation.
Future<LocalDataSource> source([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return LocalDataSource(await SharedPreferences.getInstance());
}

void main() {
  test('most recent first', () async {
    final ds = await source();
    await ds.recordRecentSearch('szarvas');
    await ds.recordRecentSearch('isten');

    expect(ds.getRecentSearches(), ['isten', 'szarvas']);
  });

  test('re-searching moves the entry rather than duplicating it', () async {
    final ds = await source();
    await ds.recordRecentSearch('szarvas');
    await ds.recordRecentSearch('isten');
    await ds.recordRecentSearch('SZARVAS');

    // Case-insensitive: two entries differing only in capitals would look like
    // the same query listed twice.
    expect(ds.getRecentSearches(), ['SZARVAS', 'isten']);
  });

  test('caps the list', () async {
    final ds = await source();
    for (var i = 0; i < LocalDataSource.recentSearchesLimit + 5; i++) {
      await ds.recordRecentSearch('query $i');
    }

    expect(ds.getRecentSearches(),
        hasLength(LocalDataSource.recentSearchesLimit));
    expect(ds.getRecentSearches().first,
        'query ${LocalDataSource.recentSearchesLimit + 4}');
  });

  test('blank queries are not remembered', () async {
    final ds = await source();
    expect(await ds.recordRecentSearch('   '), isFalse);
    expect(ds.getRecentSearches(), isEmpty);
  });

  test('a corrupt blob reads as empty rather than throwing', () async {
    final ds = await source({'recent_searches': 'not json'});
    expect(ds.getRecentSearches(), isEmpty);
  });

  test('clear empties it', () async {
    final ds = await source();
    await ds.recordRecentSearch('szarvas');
    await ds.clearRecentSearches();

    expect(ds.getRecentSearches(), isEmpty);
  });
}
