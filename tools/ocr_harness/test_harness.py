"""The measurement loop itself.

A harness that scores wrongly is worse than no harness, because it produces a
number people then trust. Everything here is about the scoring being right, not
about any page reading well.
"""
import unittest

from . import metrics, reading, report


class Parsing(unittest.TestCase):

    def test_a_chord_row_pairs_with_the_lyric_under_it(self):
        page = reading.parse("G       D\nAmazing grace")
        self.assertEqual(('Amazing grace',), page.lyrics)
        self.assertEqual(1, page.chord_rows)
        self.assertEqual(('G', 'D'), page.chords)

    def test_a_chord_lands_on_the_word_it_sits_over(self):
        page = reading.parse("G       D\nAmazing grace")
        self.assertEqual([('G', 'Amazing'), ('D', 'grace')],
                         [(p.chord, p.word) for p in page.placements])

    def test_a_chord_one_space_past_a_word_still_belongs_to_it(self):
        # How a typesetter keeps a chord off the letter below it. Scoring this
        # as a miss would mark most of the corpus wrong.
        page = reading.parse("       G7  Am\nAmazing grace")
        self.assertEqual('Amazing', page.placements[0].word)

    def test_a_chord_past_the_end_is_recorded_as_such(self):
        page = reading.parse("G7                  Am\nAmazing grace")
        self.assertEqual(reading.PAST_END, page.placements[-1].word)
        self.assertEqual(-1, page.placements[-1].word_index)

    def test_a_row_holding_one_uppercase_root_is_chords(self):
        # A row holding nothing but one letter is not a plausible line of words.
        # Asserted here because the harness has to agree with the worker, or
        # every gold file is written against a different rule than the one being
        # measured.
        page = reading.parse("       G\nAmazing grace")
        self.assertEqual(1, page.chord_rows)
        self.assertEqual(('Amazing grace',), page.lyrics)
        self.assertEqual([('G', 'Amazing')],
                         [(p.chord, p.word) for p in page.placements])

    def test_a_row_holding_one_lowercase_root_is_also_chords(self):
        # No hymnal line is one character long, so the letter's case is not
        # evidence either way. The rare misread is a moderator's job rather than
        # a parser's, and reading these as words cost four real chords.
        page = reading.parse("       a\nAmazing grace")
        self.assertEqual(1, page.chord_rows)
        self.assertEqual(('Amazing grace',), page.lyrics)

    def test_chords_with_nothing_underneath_survive(self):
        # An intro or a turnaround. The app stores these past the end of an
        # empty lyric, so losing them here would score a correct reading down.
        page = reading.parse("Em7 Cadd9 G5\n\nG       D\nAmazing grace")
        self.assertEqual(2, page.chord_rows)
        self.assertIn('Em7', page.chords)
        self.assertEqual(('Amazing grace',), page.lyrics)

    def test_two_chord_rows_in_a_row_do_not_swallow_each_other(self):
        page = reading.parse("G   D\nC   G\nAmazing grace")
        self.assertEqual(2, page.chord_rows)
        self.assertEqual(('Amazing grace',), page.lyrics)

    def test_a_number_is_split_out_of_the_title(self):
        for text, want in (('{title: 147. Isten fenye}', (147, 'Isten fenye')),
                           ('{title: 98 . Szivemben}', (98, 'Szivemben')),
                           ('{title: 151 Zengjed a dalt}',
                            (151, 'Zengjed a dalt'))):
            with self.subTest(text=text):
                page = reading.parse(text)
                self.assertEqual(want, (page.number, page.title))

    def test_a_title_with_no_number_keeps_all_of_itself(self):
        page = reading.parse('{title: Jezus szivedbe lat}')
        self.assertIsNone(page.number)
        self.assertEqual('Jezus szivedbe lat', page.title)

    def test_blank_lines_delimit_blocks(self):
        page = reading.parse("one\n\ntwo\n\n\nthree")
        self.assertEqual(3, page.blocks)

    def test_lyric_text_joins_lines_so_a_wrong_break_costs_one_character(self):
        page = reading.parse("Amazing\ngrace")
        self.assertEqual('Amazing\ngrace', page.lyric_text)


class Warnings(unittest.TestCase):

    def test_prose_maps_to_a_stable_slug(self):
        self.assertEqual(
            ('german-chords',),
            reading.slugs_for(['H7 will be stored under the English name '
                               '(H is B natural).']))

    def test_unrecognised_prose_is_kept_rather_than_dropped(self):
        got = reading.slugs_for(['something new'])
        self.assertTrue(got[0].startswith('unmapped:'))

    def test_every_slug_the_worker_can_emit_is_mapped(self):
        # The prose is localised and three of these are named as known debt in
        # the app's own no-hardcoded-strings test. Matching on wording would
        # break the day that debt is paid; this is the reminder to add the slug
        # rather than to rewrite the match.
        self.assertEqual(6, len(reading.WARNING_SLUGS))


class Accents(unittest.TestCase):

    def test_folding_removes_the_hungarian_long_umlauts(self):
        self.assertEqual('mento oltalom', reading.fold_accents('mentő oltalom'))

    def test_folding_leaves_plain_text_alone(self):
        self.assertEqual('Amazing', reading.fold_accents('Amazing'))


class ErrorRate(unittest.TestCase):

    def test_identical_text_scores_zero(self):
        self.assertEqual(0.0, metrics.cer('Amazing grace', 'Amazing grace'))

    def test_one_wrong_letter_in_ten_scores_a_tenth(self):
        self.assertAlmostEqual(0.1, metrics.cer('abcdefghij', 'abcdefghiX'))

    def test_nothing_read_scores_one(self):
        self.assertEqual(1.0, metrics.cer('abcdefghij', ''))

    def test_twice_the_text_scores_above_one(self):
        # Not clamped: an engine that doubled the page is worse than one that
        # read nothing, and the number should say so.
        self.assertGreater(metrics.cer('abc', 'abcxyzxyz'), 1.0)

    def test_an_empty_expectation_read_as_empty_is_perfect(self):
        self.assertEqual(0.0, metrics.cer('', ''))


class Multisets(unittest.TestCase):

    def test_a_repeated_chord_counts_every_time(self):
        recall, precision, _ = metrics._multiset_scores(['G', 'G', 'D'],
                                                        ['G', 'D'])
        self.assertAlmostEqual(2 / 3, recall)
        self.assertEqual(1.0, precision)

    def test_an_invented_chord_costs_precision_not_recall(self):
        recall, precision, _ = metrics._multiset_scores(['G'], ['G', 'X'])
        self.assertEqual(1.0, recall)
        self.assertAlmostEqual(0.5, precision)


class Scoring(unittest.TestCase):

    def setUp(self):
        self.gold = reading.parse("G       D\nAmazing grace how sweet",
                                  ('german-chords',))

    def test_a_perfect_reading_scores_one(self):
        score = metrics.score(self.gold, self.gold, page='p', engine='e',
                              tier='A')
        self.assertEqual(1.0, score.headline)
        self.assertEqual(0.0, score.values['lyric_cer'])
        self.assertEqual([], score.notes)

    def test_a_chord_over_the_wrong_word_is_found_but_misplaced(self):
        got = reading.parse("G             D\nAmazing grace how sweet",
                            ('german-chords',))
        score = metrics.score(self.gold, got, page='p', engine='e', tier='A')
        self.assertEqual(1.0, score.values['chord_recall'])
        self.assertLess(score.values['placement'], 1.0)

    def test_a_missing_accent_shows_only_in_the_unfolded_rate(self):
        gold = reading.parse('mentő oltalom')
        got = reading.parse('mento oltalom')
        score = metrics.score(gold, got, page='p', engine='e', tier='A')
        self.assertGreater(score.values['lyric_cer'], 0)
        self.assertEqual(0.0, score.values['lyric_cer_folded'])

    def test_a_warning_that_stopped_firing_is_a_note(self):
        got = reading.parse("G       D\nAmazing grace how sweet")
        score = metrics.score(self.gold, got, page='p', engine='e', tier='A')
        self.assertEqual(0.0, score.values['warnings_ok'])
        self.assertTrue(any('german-chords' in n for n in score.notes))

    def test_a_line_count_mismatch_is_a_note(self):
        got = reading.parse("G       D\nAmazing grace\nhow sweet")
        score = metrics.score(self.gold, got, page='p', engine='e', tier='A')
        self.assertTrue(any('lyric lines' in n for n in score.notes))

    def test_an_absent_number_is_not_scored_rather_than_scored_zero(self):
        score = metrics.score(self.gold, self.gold, page='p', engine='e',
                              tier='A')
        self.assertIsNone(score.values['number_exact'])


class Unspellable(unittest.TestCase):
    """Chord symbols no reading can ever get right."""

    def test_the_hungarian_f_sharp_minor_spelling_is_not_spellable(self):
        self.assertEqual(['fiszm'], metrics.unclassifiable(['G', 'em', 'fiszm']))

    def test_a_hungarian_bass_note_is_not_spellable(self):
        self.assertEqual(['D4/Fis'], metrics.unclassifiable(['D4/Fis']))

    def test_lowercase_minor_and_german_h_are_fine(self):
        self.assertEqual([], metrics.unclassifiable(['em', 'dm', 'hm', 'H7']))

    def test_the_continuation_shorthand_is_fine(self):
        self.assertEqual([], metrics.unclassifiable(['-7']))


class Regressions(unittest.TestCase):

    def _score(self, **values):
        full = {'lyric_accuracy': 1.0, 'chord_f1': 1.0, 'placement': 1.0,
                'lyric_cer': 0.0}
        full.update(values)
        return metrics.Score(page='p', engine='easyocr', tier='A', values=full)

    def test_a_drop_beyond_tolerance_is_a_regression(self):
        baseline = {'engines': {'easyocr': {'p': {'chord_f1': 1.0}}}}
        found = report.regressions([self._score(chord_f1=0.5)], baseline)
        self.assertEqual(1, len(found))
        self.assertIn('chord_f1', found[0])

    def test_a_rise_is_not_a_regression(self):
        baseline = {'engines': {'easyocr': {'p': {'chord_f1': 0.5}}}}
        self.assertEqual([], report.regressions([self._score(chord_f1=1.0)],
                                                baseline))

    def test_a_rising_error_rate_is_a_regression(self):
        # lyric_cer improves downward. Getting this backwards would let the
        # text quietly get worse forever.
        baseline = {'engines': {'easyocr': {'p': {'lyric_cer': 0.1}}}}
        found = report.regressions([self._score(lyric_cer=0.4)], baseline)
        self.assertEqual(1, len(found))

    def test_a_falling_error_rate_is_not(self):
        baseline = {'engines': {'easyocr': {'p': {'lyric_cer': 0.4}}}}
        self.assertEqual([], report.regressions([self._score(lyric_cer=0.1)],
                                                baseline))

    def test_movement_within_tolerance_is_not_reported(self):
        baseline = {'engines': {'easyocr': {'p': {'chord_f1': 1.0}}}}
        self.assertEqual([], report.regressions(
            [self._score(chord_f1=1.0 - metrics.TOLERANCE / 2)], baseline))

    def test_a_page_with_no_baseline_cannot_regress(self):
        self.assertEqual([], report.regressions([self._score(chord_f1=0.0)],
                                                {'engines': {}}))


if __name__ == '__main__':
    unittest.main()


class NearPlacement(unittest.TestCase):
    """Placement with one word of slack - the number the headline uses."""

    def _at(self, chord, index):
        return reading.Placement(chord=chord, column=0, word='w',
                                 word_index=index)

    def test_the_exact_word_matches(self):
        self.assertEqual(1.0, metrics._near_placement([self._at('G', 3)],
                                                      [self._at('G', 3)]))

    def test_one_word_out_still_matches(self):
        self.assertEqual(1.0, metrics._near_placement([self._at('G', 3)],
                                                      [self._at('G', 4)]))

    def test_two_words_out_does_not(self):
        self.assertEqual(0.0, metrics._near_placement([self._at('G', 3)],
                                                      [self._at('G', 5)]))

    def test_the_wrong_chord_never_matches(self):
        self.assertEqual(0.0, metrics._near_placement([self._at('G', 3)],
                                                      [self._at('C', 3)]))

    def test_past_the_end_matches_only_past_the_end(self):
        # -1 against word 0 is a one-word gap by arithmetic and a different
        # place on the page. A trailing turnaround must not satisfy a chord
        # that belongs over the first syllable.
        self.assertEqual(0.0, metrics._near_placement([self._at('G', 0)],
                                                      [self._at('G', -1)]))
        self.assertEqual(1.0, metrics._near_placement([self._at('G', -1)],
                                                      [self._at('G', -1)]))

    def test_each_candidate_is_used_once(self):
        # Two golds one word apart must not both match the same reading.
        got = metrics._near_placement(
            [self._at('G', 2), self._at('G', 3)], [self._at('G', 3)])
        self.assertGreater(got, 0.0)
        self.assertLess(got, 1.0)

    def test_the_nearest_candidate_wins(self):
        self.assertEqual(1.0, metrics._near_placement(
            [self._at('G', 2), self._at('G', 4)],
            [self._at('G', 4), self._at('G', 2)]))

    def test_inventing_chords_costs_precision(self):
        self.assertLess(metrics._near_placement(
            [self._at('G', 0)], [self._at('G', 0), self._at('G', 9)]), 1.0)

    def test_nothing_expected_and_nothing_found_is_perfect(self):
        self.assertEqual(1.0, metrics._near_placement([], []))

    def test_nothing_expected_but_something_found_is_not(self):
        self.assertEqual(0.0, metrics._near_placement([], [self._at('G', 0)]))


class Separators(unittest.TestCase):
    """Punctuation a chord row carries is not a chord."""

    def test_a_bare_dash_is_not_scored_as_a_chord(self):
        page = reading.parse("G7 - Am\nAmazing grace how")
        self.assertEqual(('G7', 'Am'), page.chords)

    def test_the_continuation_shorthand_is_scored(self):
        page = reading.parse("G7  -7   Am\nAmazing grace how")
        self.assertEqual(('G7', '-7', 'Am'), page.chords)

    def test_a_turnaround_written_with_dashes_counts_its_chords_only(self):
        page = reading.parse("G7 - C - D - C\nAmazing grace how sweet the")
        self.assertEqual(('G7', 'C', 'D', 'C'), page.chords)

    def test_brackets_around_a_chord_are_not_chords(self):
        page = reading.parse("G7   ( C )\nAmazing grace how")
        self.assertEqual(('G7', 'C'), page.chords)


class Provenance(unittest.TestCase):
    """Which gold files may honestly score which engine."""

    def _page(self, **kw):
        from . import gold as gold_mod
        import pathlib
        base = dict(file='p.jpg', path=pathlib.Path('p.jpg'), tier='A',
                    engine='text', title=None, book_number=None, layout='',
                    stresses=(), gold=None, reviewed_by=None,
                    drafted_from=None)
        base.update(kw)
        return gold_mod.Page(**base)

    def test_a_file_drafted_from_an_engine_cannot_score_that_engine(self):
        page = self._page(drafted_from='easyocr')
        self.assertFalse(page.evidence_for('easyocr'))

    def test_nor_can_it_score_any_other_engine(self):
        # An engine's output is not an answer key. Scoring the browser against
        # EasyOCR's reading of 166-tekozlo-fiu returned chord recall 1.000,
        # which meant "found everything EasyOCR found" - and EasyOCR had found
        # three chords out of thirteen.
        page = self._page(drafted_from='easyocr')
        self.assertFalse(page.evidence_for('browser'))
        self.assertFalse(page.evidence_for('vision'))

    def test_a_transcription_from_the_photograph_can_score_anything(self):
        page = self._page(drafted_from='vision')
        for engine in ('easyocr', 'browser', 'vision'):
            self.assertTrue(page.evidence_for(engine), engine)

    def test_a_review_makes_it_evidence_for_everything(self):
        page = self._page(drafted_from='easyocr', reviewed_by='Robert')
        for engine in ('easyocr', 'browser', 'vision'):
            self.assertTrue(page.evidence_for(engine), engine)

    def test_unknown_provenance_is_not_evidence_for_anything(self):
        # Fails closed. Treating an absent value as trustworthy is what let six
        # files written before the field existed read as independent.
        page = self._page(drafted_from=None)
        self.assertFalse(page.evidence_for('easyocr'))
        self.assertFalse(page.evidence_for('vision'))

    def test_every_gold_file_on_disk_declares_where_it_came_from(self):
        from . import gold as gold_mod
        missing = [p.file for p in gold_mod.pages(with_gold=True)
                   if p.drafted_from is None and not p.reviewed]
        self.assertEqual([], missing)


class PlacementMeasuresPlacementOnly(unittest.TestCase):
    """A misread word must not also count as a misplaced chord."""

    def test_a_misread_word_under_a_correct_chord_costs_nothing_here(self):
        # Real case from 151-zengjed-a-dalt: `D` on exactly the right word, and
        # the recogniser read that word as `dalt;` instead of `dalt,`. The
        # letters are lyric_cer's business.
        want = reading.parse("      D\nZengjed dalt, kiáltsd")
        got = reading.parse("      D\nZengjed dalt; kiáltsd")
        score = metrics.score(want, got, page='p', engine='e', tier='A')
        self.assertEqual(1.0, score.values['placement'])
        self.assertEqual(1.0, score.values['placement_near'])
        self.assertGreater(score.values['lyric_cer'], 0.0)

    def test_a_chord_on_the_wrong_word_still_costs(self):
        want = reading.parse("      D\nZengjed dalt, kiáltsd")
        got = reading.parse("                    D\nZengjed dalt, kiáltsd")
        score = metrics.score(want, got, page='p', engine='e', tier='A')
        self.assertEqual(0.0, score.values['placement'])
