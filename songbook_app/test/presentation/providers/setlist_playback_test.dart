import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/setlist.dart';
import 'package:songbook_app/presentation/providers/setlist_provider.dart';

Setlist setlist({List<int> songNumbers = const [1, 42, 151]}) {
  final t = DateTime.utc(2026, 1, 1);
  return Setlist(
    id: 'sl_1',
    name: 'Service',
    songNumbers: songNumbers,
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  late SetlistPlaybackNotifier notifier;

  setUp(() => notifier = SetlistPlaybackNotifier());

  group('start', () {
    test('begins at index 0 on the first song', () {
      notifier.start(setlist());

      expect(notifier.state, isNotNull);
      expect(notifier.state!.currentIndex, 0);
      expect(notifier.state!.currentSongNumber, 1);
      expect(notifier.state!.position, 1);
      expect(notifier.state!.total, 3);
      expect(notifier.state!.hasPrevious, isFalse);
      expect(notifier.state!.hasNext, isTrue);
    });

    test('ignores an empty setlist (stays not playing)', () {
      notifier.start(setlist(songNumbers: const []));

      expect(notifier.state, isNull);
    });

    test('clamps an out-of-range start index', () {
      notifier.start(setlist(), index: 99);

      expect(notifier.state!.currentIndex, 2);
      expect(notifier.state!.currentSongNumber, 151);
    });
  });

  group('next / previous', () {
    test('next walks forward and returns the new song number', () {
      notifier.start(setlist());

      expect(notifier.next(), 42);
      expect(notifier.next(), 151);
      expect(notifier.state!.hasNext, isFalse);
      expect(notifier.next(), isNull); // no wrap at the end
      expect(notifier.state!.currentIndex, 2);
    });

    test('previous walks back and returns null at the start', () {
      notifier.start(setlist(), index: 2);

      expect(notifier.previous(), 42);
      expect(notifier.previous(), 1);
      expect(notifier.state!.hasPrevious, isFalse);
      expect(notifier.previous(), isNull);
      expect(notifier.state!.currentIndex, 0);
    });
  });

  group('jumpTo / stop', () {
    test('jumpTo moves to the given index (clamped)', () {
      notifier.start(setlist());

      notifier.jumpTo(2);
      expect(notifier.state!.currentSongNumber, 151);

      notifier.jumpTo(99);
      expect(notifier.state!.currentIndex, 2);
    });

    test('jumpTo is a no-op when not playing', () {
      notifier.jumpTo(1);
      expect(notifier.state, isNull);
    });

    test('stop clears playback', () {
      notifier.start(setlist());
      notifier.stop();
      expect(notifier.state, isNull);
    });
  });
}
