import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/repositories/tag_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TagRepository> makeRepo() async {
    final prefs = await SharedPreferences.getInstance();
    return TagRepository(LocalDataSource(prefs));
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts with no overrides', () async {
    final repo = await makeRepo();
    expect(repo.getOverrides(), isEmpty);
    expect(repo.hasOverride(1), isFalse);
  });

  test('setTags persists and reads back', () async {
    final repo = await makeRepo();
    await repo.setTags(42, ['praise', 'advent']);

    expect(repo.getOverrides(), {
      42: ['praise', 'advent'],
    });
    expect(repo.hasOverride(42), isTrue);
  });

  test('clearOverride removes the entry', () async {
    final repo = await makeRepo();
    await repo.setTags(42, ['praise']);
    await repo.clearOverride(42);

    expect(repo.hasOverride(42), isFalse);
    expect(repo.getOverrides(), isEmpty);
  });

  test('overrides survive a fresh repository instance (round-trip)', () async {
    final repo = await makeRepo();
    await repo.setTags(7, ['communion']);

    final fresh = await makeRepo();
    expect(fresh.getOverrides(), {
      7: ['communion'],
    });
  });

  test('stored under the song_tag_overrides key', () async {
    final repo = await makeRepo();
    await repo.setTags(1, ['x']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('song_tag_overrides'), isNotNull);
  });
}
