import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/song_id.dart';
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
    expect(repo.hasOverride(const SongId.hymnal(1)), isFalse);
  });

  test('setTags persists and reads back', () async {
    final repo = await makeRepo();
    await repo.setTags(const SongId.hymnal(42), ['praise', 'advent']);

    expect(repo.getOverrides(), {
      const SongId.hymnal(42): ['praise', 'advent'],
    });
    expect(repo.hasOverride(const SongId.hymnal(42)), isTrue);
  });

  test('clearOverride removes the entry', () async {
    final repo = await makeRepo();
    await repo.setTags(const SongId.hymnal(42), ['praise']);
    await repo.clearOverride(const SongId.hymnal(42));

    expect(repo.hasOverride(const SongId.hymnal(42)), isFalse);
    expect(repo.getOverrides(), isEmpty);
  });

  test('overrides survive a fresh repository instance (round-trip)', () async {
    final repo = await makeRepo();
    await repo.setTags(const SongId.hymnal(7), ['communion']);

    final fresh = await makeRepo();
    expect(fresh.getOverrides(), {
      const SongId.hymnal(7): ['communion'],
    });
  });

  test('stored under the song_tag_overrides key', () async {
    final repo = await makeRepo();
    await repo.setTags(const SongId.hymnal(1), ['x']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('song_tag_overrides'), isNotNull);
  });
}
