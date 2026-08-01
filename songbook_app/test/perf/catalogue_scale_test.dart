import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/domain/services/search_service.dart';

/// What this app does when it holds a real hymnal.
///
/// The bundled catalogue is 8 songs and every performance property has only ever
/// been observed at that size. The import pipeline exists so the catalogue grows —
/// a Hungarian Reformed hymnal is over 500 hymns, and the old app's whole appeal
/// was that it filled up without the maintainer — so the interesting question is
/// what search costs at 1000.
///
/// **These are budgets, not benchmarks.** They are deliberately loose enough not
/// to flake on a busy machine and tight enough to fail an algorithmic regression:
/// what is being pinned is "no accidental O(n·m) with a huge constant", not a
/// millisecond count. Two caveats worth stating rather than discovering:
///
///   - a VM test is not dart2js, so the absolute numbers do not transfer to the
///     phone; the *ratios* between the cases do;
///   - search runs on every keystroke, on the UI isolate. That is why the budget
///     is expressed as a fraction of a frame rather than as "fast enough".
///
/// Every budget here failed when first written. What they are protecting, measured
/// on the machine that wrote them:
///
/// | case                   | before  | after   | units, alone | units, in suite |
/// |------------------------|---------|---------|--------------|-----------------|
/// | title search           | 9.3 ms  | 2.8 ms  | 13.3         | 9.8             |
/// | title search, no hits  | 7.4 ms  | 2.4 ms  | 11.9         | 13.2            |
/// | lyrics search          | 13.3 ms | 3.2 ms  | 17.1         | 24.9            |
/// | lyrics search, no hits | 51.9 ms | 19.6 ms | 104.8        | 102.9           |
///
/// Two changes got that, both small: `removeDiacritics` stopped allocating a
/// one-character String per character via `split('')/map/join`, and search stopped
/// joining each verse into one string only to split it back into the lines it
/// already had.
///
/// The budgets are set about 1.5× above the worse of those two columns, so they
/// fail a real regression and survive a busy machine. If one ever fails by a hair,
/// re-run this file on its own before believing it.
void main() {
  const service = SearchService();

  /// A hymn-shaped song: four verses of six lines, Hungarian text with the
  /// diacritics that make normalisation cost something, a reference and two tags.
  ///
  /// The text matters. Normalisation strips accents, so a corpus of ASCII would
  /// measure a path the real catalogue never takes.
  Song hymn(int number) {
    const lines = [
      'Áldjad én lelkem a dicsőség örök Királyát',
      'Őt magasztalja szívem és lelkem',
      'Mert csodálatos dolgokat művelt vélem',
      'Zengjen a hála örökké néki',
      'Úr Isten, ki vagy mennyekben',
      'Tebenned bíztunk eleitől fogva',
    ];
    return Song(
      number: number,
      title: 'Ének $number — ${lines[number % lines.length]}',
      reference: 'Zsolt ${number % 150 + 1}',
      originalKey: 'Bb',
      tags: ['zsoltár', number.isEven ? 'dicséret' : 'ünnepi'],
      verses: [
        for (var v = 1; v <= 4; v++)
          Verse(
            number: v,
            lines: [for (final line in lines) LyricLine(text: '$line ($v)')],
          ),
      ],
    );
  }

  final catalogue = [for (var i = 1; i <= 1000; i++) hymn(i)];

  /// Microseconds for [body], best of [runs] — the fastest run is the one least
  /// polluted by whatever else the machine is doing.
  int fastest(int runs, void Function() body) {
    var best = 1 << 30;
    for (var i = 0; i < runs; i++) {
      final watch = Stopwatch()..start();
      body();
      watch.stop();
      if (watch.elapsedMicroseconds < best) best = watch.elapsedMicroseconds;
    }
    return best;
  }

  /// A fixed unit of string work, used to express the budgets as ratios.
  ///
  /// `flutter test` runs test files concurrently, so an absolute millisecond
  /// budget measures how loaded the machine is as much as it measures the code:
  /// the first version of this file measured a title search at 3.3 ms on its own
  /// and 6.9 ms inside the full suite, and failed only in the suite. That is a
  /// flaky test, and a flaky perf test gets deleted rather than believed.
  ///
  /// So every budget below is a multiple of this instead. It is deliberately NOT
  /// the code under test — it touches no app code at all — but it is the same kind
  /// of work, so it slows down by the same factor when the cores are busy.
  int calibration() {
    const sample = 'Áldjad én lelkem a dicsőség örök Királyát 🎵 abcdefghij';
    var sink = 0;
    final micros = fastest(5, () {
      // Allocation-heavy on purpose. A tight arithmetic loop was tried first and
      // tracked badly: under contention, allocating work degrades more than
      // integer work does — GC pressure and memory bandwidth are what the other
      // isolates are competing for — so the ratio still moved 2× between running
      // alone and running in the suite. Building strings is what search does.
      // Sized so one unit lands near a millisecond on a desktop.
      for (var round = 0; round < 900; round++) {
        final buffer = StringBuffer();
        for (var i = 0; i < sample.length; i++) {
          buffer.writeCharCode(sample.codeUnitAt(i));
        }
        sink ^= buffer.toString().length;
      }
    });
    // Reads the result so the loop cannot be discarded as dead. Not an `expect`:
    // this runs while the file is being loaded, outside any test, and `expect`
    // there fails the whole file with OutsideTestException.
    if (sink == 0x7FFFFFFF) throw StateError('unreachable');
    return micros;
  }

  /// Asserts [body] costs no more than [budget] calibration units, and says what
  /// it actually cost either way.
  ///
  /// The unit is measured inside each test, immediately before the body, and that
  /// placement is the whole point. Calibrating once when the file loads was tried
  /// and did not work: the other test files had not started competing yet, so the
  /// unit came from a quieter machine than the measurement did and the ratio still
  /// moved by 2.3× between running this file alone and running the whole suite.
  /// Adjacent measurement is what makes the ratio mean something.
  void within(String what, int budget, void Function() body) {
    final unit = calibration();
    final micros = fastest(3, body);
    final ratio = micros / unit;
    // ignore: avoid_print
    print('  $what: ${(micros / 1000).toStringAsFixed(1)} ms '
        '= ${ratio.toStringAsFixed(1)} units (budget $budget)');
    expect(ratio, lessThan(budget),
        reason: '$what cost ${ratio.toStringAsFixed(1)} calibration units; '
            'one unit is ${(unit / 1000).toStringAsFixed(1)} ms here');
  }

  group('a 1000-song catalogue', () {
    setUpAll(() {
      // JIT warmup, and it matters more than it sounds. Without it the very first
      // `within` call measures its calibration cold, so the unit comes out large
      // and that one test's ratio looks artificially good — two operations of
      // near-identical cost reported 3.9 and 18.4 units purely from ordering.
      calibration();
      service.search(catalogue, 'warm');
      service.searchLyrics(catalogue, 'warm');
      service.tagsWithCounts(catalogue);
    });

    test('the fixture is the shape being claimed', () {
      expect(catalogue, hasLength(1000));
      expect(catalogue.first.verses, hasLength(4));
      expect(catalogue.first.verses.first.lines, hasLength(6));
      // 24 lines a song, so 24k lines of accented text in the corpus.
      expect(
        catalogue.fold<int>(
            0, (n, s) => n + s.verses.fold<int>(0, (m, v) => m + v.lines.length)),
        24000,
      );
    });

    test('a title search is cheap', () {
      // One keystroke of a title search: the whole catalogue scored.
      expect(service.search(catalogue, 'áldjad'), isNotEmpty,
          reason: 'measuring a search that finds nothing measures nothing');
      within('title search', 22, () => service.search(catalogue, 'áldjad'));
    });

    test('a search matching nothing costs no more than one that does', () {
      // The worst case for scoring: every song is scored and none short-circuits.
      within('title search, no hits', 22,
          () => service.search(catalogue, 'qwertyx'));
    });

    test('the lyrics fallback is affordable per keystroke', () {
      // The heaviest thing the app does per keystroke: 24k lines of accented text
      // scanned. It only runs when the title search came back empty — which is
      // exactly while the user is still typing.
      expect(service.searchLyrics(catalogue, 'csodálatos'), isNotEmpty,
          reason: 'the fixture must actually contain the word');
      within('lyrics search', 40,
          () => service.searchLyrics(catalogue, 'csodálatos'));
    });

    test('a lyrics search matching nothing scans the whole corpus', () {
      // No early exit anywhere: every line of every song is normalised. This is
      // the number that matters, because it is what a half-typed word costs.
      within('lyrics search, no hits', 160,
          () => service.searchLyrics(catalogue, 'zzzzq'));
    });

    test('deriving the tag list is cheap', () {
      // Runs whenever the tag sheet opens, over the whole catalogue.
      within('tags with counts', 5, () => service.tagsWithCounts(catalogue));
    });

    test('comparing two catalogues does not walk their verses', () {
      // Song.== is now deep equality over every field including all verses, so the
      // fear was that a provider asking "did the catalogue change?" would walk 24k
      // lyric lines. It does not: List.== is reference equality, so the deep
      // comparison is never reached. Pinned because it is not obvious, and because
      // switching a provider to a deep list comparison would make it very real.
      final copy = [for (final song in catalogue) song];
      within('list identity check', 1, () {
        // ignore: unrelated_type_equality_checks
        expect(catalogue == copy, isFalse);
      });
    });
  });
}
