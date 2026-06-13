import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/capo_service.dart';

void main() {
  const service = CapoService();

  // Helper: capo fret chosen for a given shape key in the suggestion list.
  int? fretFor(List<CapoSuggestion> list, String shape) {
    for (final s in list) {
      if (s.shapeKey == shape) return s.fret;
    }
    return null;
  }

  group('CapoService.suggestionsFor', () {
    test('G major: G shape is open (capo 0) and is recommended', () {
      final list = service.suggestionsFor('G');
      expect(fretFor(list, 'G'), 0);
      // E shape capo 3 sounds G; D shape capo 5; C shape capo 7.
      expect(fretFor(list, 'E'), 3);
      expect(fretFor(list, 'D'), 5);
      expect(fretFor(list, 'C'), 7);
      // A shape (capo 10) exceeds the default maxFret 9 → excluded.
      expect(fretFor(list, 'A'), isNull);
      // Sorted lowest first; recommended is the open G shape.
      expect(list.first, const CapoSuggestion(fret: 0, shapeKey: 'G'));
      expect(service.recommendedFor('G'),
          const CapoSuggestion(fret: 0, shapeKey: 'G'));
    });

    test('Bb major: A shape capo 1 is the recommended low position', () {
      final list = service.suggestionsFor('Bb');
      expect(fretFor(list, 'A'), 1);
      expect(fretFor(list, 'G'), 3);
      expect(fretFor(list, 'E'), 6);
      expect(fretFor(list, 'D'), 8);
      expect(service.recommendedFor('Bb'),
          const CapoSuggestion(fret: 1, shapeKey: 'A'));
    });

    test('minor key uses minor shapes (Em/Am/Dm)', () {
      final list = service.suggestionsFor('Am');
      expect(list.every((s) => CapoService.minorShapeKeys.contains(s.shapeKey)),
          isTrue);
      expect(fretFor(list, 'Am'), 0); // open A minor
      expect(fretFor(list, 'Em'), 5); // Em shape capo 5 sounds Am
      expect(service.recommendedFor('Am'),
          const CapoSuggestion(fret: 0, shapeKey: 'Am'));
    });

    test('results are sorted by fret ascending', () {
      final list = service.suggestionsFor('D');
      for (var i = 1; i < list.length; i++) {
        expect(list[i].fret >= list[i - 1].fret, isTrue);
      }
    });

    test('maxFret filters out high positions', () {
      final all = service.suggestionsFor('G', maxFret: 11);
      final capped = service.suggestionsFor('G', maxFret: 4);
      expect(all.length, greaterThan(capped.length));
      expect(capped.every((s) => s.fret <= 4), isTrue);
    });

    test('invalid / empty key returns no suggestions', () {
      expect(service.suggestionsFor(''), isEmpty);
      expect(service.suggestionsFor('H'), isEmpty);
      expect(service.recommendedFor('xyz'), isNull);
    });

    test('label reads naturally', () {
      expect(const CapoSuggestion(fret: 0, shapeKey: 'G').label,
          'No capo · play in G');
      expect(const CapoSuggestion(fret: 2, shapeKey: 'A').label,
          'Capo 2 · play A shapes');
    });
  });
}
