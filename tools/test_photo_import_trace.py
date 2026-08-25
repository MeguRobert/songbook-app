"""The stage trace, and the confidence that now rides along with a box.

Kept apart from test_photo_import_worker.py because it tests an observation
seam rather than a reading rule: nothing here may change what is read, and
several of these tests exist only to say so.
"""
import math
import unittest

import photo_import_worker as worker
from photo_import_worker import Box


def row(y, height, *tokens):
    """Boxes on one baseline: (text, x0, x1) triples at [y]..[y]+[height]."""
    return [Box(text=t, x0=x0, y0=y, x1=x1, y1=y + height)
            for t, x0, x1 in tokens]


PAGE = (row(0, 10, ('G', 0, 10), ('D', 80, 90))
        + row(20, 10, ('Amazing', 0, 70), ('grace', 80, 130))
        + row(40, 10, ('C', 0, 10), ('G', 80, 90))
        + row(60, 10, ('how', 0, 30), ('sweet', 80, 130)))


def stages(trace, name):
    return [r for r in trace if r["stage"] == name]


class TracingChangesNothing(unittest.TestCase):
    """The trace is an observation. It may not alter a reading."""

    def test_same_content_traced_and_untraced(self):
        plain, plain_warnings = worker.chordpro_from_boxes(PAGE)
        traced, traced_warnings = worker.chordpro_from_boxes(PAGE, trace=[])
        self.assertEqual(plain, traced)
        self.assertEqual(plain_warnings, traced_warnings)

    def test_an_empty_page_still_warns_rather_than_raising(self):
        # A comprehension passed unguarded as a _log argument used to raise
        # here, on the one input where there is nothing to summarise.
        content, warnings = worker.chordpro_from_boxes([], trace=[])
        self.assertEqual("", content)
        self.assertEqual(1, len(warnings))

    def test_no_trace_means_no_records_anywhere(self):
        # Passing None must reach every nested call, or a stage silently
        # allocates on the request path.
        worker.chordpro_from_boxes(PAGE, trace=None)


class RowReasons(unittest.TestCase):
    """Why a row was classified the way it was."""

    def test_reason_never_disagrees_with_the_boolean(self):
        rows = (['G', 'D', 'em'], ['Amazing', 'grace'], ['A'], ['-'],
                ['(C)'], ['D', 'G', 'D'], ['G', 'D', 'em', 'HX'],
                ['H7'], ['-7'], ['C', '-7'], [], ['x2'], ['fiszm'])
        for texts in rows:
            with self.subTest(texts=texts):
                self.assertEqual(worker.is_chord_row(texts),
                                 worker.chord_row_reason(texts)[0])

    def test_an_ordinary_word_is_named(self):
        ok, why = worker.chord_row_reason(['G', 'Amazing'])
        self.assertFalse(ok)
        self.assertIn('Amazing', why)

    def test_a_lone_root_is_accepted_in_either_case(self):
        # A row holding nothing but one letter is not a line of words. The rule
        # that used to reject these cost four real chords across two pages.
        for root in ('A', 'a', 'D', 'd', 'H'):
            with self.subTest(root=root):
                ok, why = worker.chord_row_reason([root])
                self.assertTrue(ok)
                self.assertIn(root, why)

    def test_separators_alone_are_not_a_chord_row(self):
        ok, why = worker.chord_row_reason(['-', '|'])
        self.assertFalse(ok)
        self.assertIn('no chord symbol', why)

    def test_an_accepted_row_lists_its_chords(self):
        ok, why = worker.chord_row_reason(['G', 'D', 'em'])
        self.assertTrue(ok)
        self.assertIn('G D em', why)

    def test_one_unreadable_token_is_tolerated_and_named(self):
        # It used to cost the row: a struck-through 7 read as X discarded G, D
        # and em with it. Three recognised chords is enough to read the stray
        # token as a misread rather than as a word, and the reason still names
        # it - the chord that reaches storage is wrong, and saying which one
        # is what makes that fixable rather than mysterious.
        ok, why = worker.chord_row_reason(['G', 'D', 'em', 'HX'])
        self.assertTrue(ok)
        self.assertIn('HX', why)

    def test_two_unreadable_tokens_still_cost_the_row(self):
        # Two is a line of words, not a chord row with a spelling problem.
        ok, why = worker.chord_row_reason(['G', 'D', 'em', 'HX', 'YZ'])
        self.assertFalse(ok)
        self.assertIn('HX', why)

    def test_one_lowercase_word_beside_two_chords_still_costs_the_row(self):
        # `A szivemben` is the line this floor exists to protect, and a
        # lowercase word is its shape.
        ok, why = worker.chord_row_reason(['A', 'G', 'szivemben'])
        self.assertFalse(ok)
        self.assertIn('szivemben', why)


class RowRecords(unittest.TestCase):
    """What the per-row records carry."""

    def test_every_kept_row_is_recorded_once(self):
        # Including the lyric half of each pair, which the loop consumes
        # without coming round again.
        trace = []
        worker.chordpro_from_boxes(PAGE, trace=trace)
        records = stages(trace, 'row')
        self.assertEqual(4, len(records))
        self.assertEqual([0, 1, 2, 3], [r['row'] for r in records])
        self.assertEqual(['chord', 'lyric', 'chord', 'lyric'],
                         [r['classified'] for r in records])

    def test_a_repaired_lyric_records_what_changed(self):
        trace = []
        worker.chordpro_from_boxes(
            row(0, 10, ('G', 0, 10), ('D', 80, 90))
            + row(20, 10, ('v1z', 0, 70), ('grace', 80, 130)), trace=trace)
        lyric = [r for r in stages(trace, 'row')
                 if r['classified'] == 'lyric'][0]
        self.assertEqual(['v1z', 'grace'], lyric['texts'])
        self.assertEqual(['viz', 'grace'], lyric['repaired'])

    def test_an_untouched_lyric_records_no_repair(self):
        trace = []
        worker.chordpro_from_boxes(PAGE, trace=trace)
        lyric = [r for r in stages(trace, 'row')
                 if r['classified'] == 'lyric'][0]
        self.assertIsNone(lyric['repaired'])

    def test_a_chord_row_records_its_pairing(self):
        trace = []
        worker.chordpro_from_boxes(PAGE, trace=trace)
        pairings = stages(trace, 'pairing')
        self.assertEqual(2, len(pairings))
        self.assertEqual([1, 3], [p['paired_with'] for p in pairings])

    def test_an_unpaired_chord_row_says_why(self):
        trace = []
        worker.chordpro_from_boxes(
            row(0, 10, ('G', 0, 10), ('D', 80, 90))
            + row(20, 10, ('C', 0, 10), ('G', 80, 90)), trace=trace)
        reasons = [p['reason'] for p in stages(trace, 'pairing')]
        self.assertIn('the row below is chords too', reasons)
        self.assertIn('last row in the column', reasons)

    def test_noise_rows_are_named_not_just_counted(self):
        trace = []
        worker.chordpro_from_boxes(PAGE + row(80, 10, ('4=', 0, 20)),
                                   trace=trace)
        column = stages(trace, 'column')[0]
        self.assertEqual([['4=']], column['dropped_as_noise'])

    def test_the_title_decision_records_the_measurement_behind_it(self):
        trace = []
        worker.chordpro_from_boxes(
            row(0, 30, ('Amazing', 0, 200))
            + row(60, 10, ('G', 0, 10), ('D', 80, 90))
            + row(80, 10, ('how', 0, 30), ('sweet', 80, 130)), trace=trace)
        title = stages(trace, 'title')[0]
        self.assertTrue(title['taken'])
        self.assertGreaterEqual(title['first_row_height'], title['needs'])

    def test_a_rejected_title_records_the_measurement_too(self):
        trace = []
        worker.chordpro_from_boxes(PAGE, trace=trace)
        title = stages(trace, 'title')[0]
        self.assertFalse(title['taken'])
        self.assertLess(title['first_row_height'], title['needs'])


class ColumnRecords(unittest.TestCase):

    def test_two_columns_are_recorded_with_their_spans(self):
        far = [b._replace(x0=b.x0 + 2000, x1=b.x1 + 2000) for b in PAGE]
        trace = []
        worker.chordpro_from_boxes(PAGE + far, trace=trace)
        columns = stages(trace, 'columns')[0]
        self.assertEqual(2, columns['count'])
        self.assertEqual(2, len(columns['spans']))
        self.assertLess(columns['spans'][0]['x1'], columns['spans'][1]['x0'])

    def test_the_span_record_names_the_one_song_per_column_assumption(self):
        # Two columns are read as two songs. True of a hymnal printed two songs
        # to a page, false of one song set in two columns - and the corpus has
        # both. The record is what lets a score say which.
        trace = []
        worker.chordpro_from_boxes(PAGE, trace=trace)
        self.assertEqual('one song per column',
                         stages(trace, 'columns')[0]['read_as'])


class ConfidenceRidesAlong(unittest.TestCase):
    """A box now carries what the recogniser scored it."""

    def test_boxes_from_easyocr_keeps_the_score(self):
        boxes = worker.boxes_from_easyocr(
            [([[0, 0], [10, 0], [10, 10], [0, 10]], 'G', 0.87)])
        self.assertEqual(0.87, boxes[0].confidence)

    def test_deskew_does_not_drop_it(self):
        # Straightening rebuilds every box. It uses _replace, which is the only
        # reason a field added to Box survives the trip.
        boxes = worker.boxes_from_easyocr([
            ([[x, x], [x + 10, x], [x + 10, x + 10], [x, x + 10]], 'G', 0.5)
            for x in range(0, 600, 60)])
        straightened = worker.deskew(boxes, 5.0)
        self.assertTrue(all(b.confidence == 0.5 for b in straightened))

    def test_repairing_a_lyric_does_not_drop_it(self):
        repaired = worker._repair_ocr(
            [Box(text='v1z', x0=0, y0=0, x1=30, y1=10, confidence=0.4)])
        self.assertEqual('viz', repaired[0].text)
        self.assertEqual(0.4, repaired[0].confidence)

    def test_a_box_built_positionally_still_works(self):
        # The older tests construct Box without a confidence. Defaulting the
        # field rather than requiring it is what keeps them passing.
        self.assertIsNone(Box('G', 0, 0, 10, 10).confidence)

    def test_a_rows_confidence_is_the_median_of_its_boxes(self):
        self.assertEqual(0.5, worker._row_confidence(
            [Box('G', 0, 0, 10, 10, 0.4), Box('D', 20, 0, 30, 10, 0.5),
             Box('em', 40, 0, 50, 10, 0.9)]))

    def test_a_row_of_unscored_boxes_has_no_confidence(self):
        self.assertIsNone(worker._row_confidence([Box('G', 0, 0, 10, 10)]))

    def test_the_row_record_carries_it(self):
        scored = [b._replace(confidence=0.75) for b in PAGE]
        trace = []
        worker.chordpro_from_boxes(scored, trace=trace)
        self.assertTrue(all(r['confidence'] == 0.75
                            for r in stages(trace, 'row')))


class SkewRecord(unittest.TestCase):

    def test_corrected_agrees_with_the_angle_and_the_floor(self):
        # Not an assertion about how level this synthetic page is - eight boxes
        # give the estimator little to work with. The record just has to be
        # self-consistent, so `corrected: false` never sits beside an angle
        # large enough to have been corrected.
        trace = []
        worker.chordpro_from_boxes(PAGE, trace=trace)
        skew = stages(trace, 'skew')[0]
        self.assertEqual(abs(skew['degrees']) >= worker._SKEW_FLOOR,
                         skew['corrected'])

    def test_a_real_tilt_is_recorded_as_corrected(self):
        radians = math.radians(6.0)
        sin, cos = math.sin(radians), math.cos(radians)
        tilted = []
        for b in PAGE:
            cx, cy = (b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2
            nx, ny = cx * cos - cy * sin, cx * sin + cy * cos
            half_w, half_h = (b.x1 - b.x0) / 2, (b.y1 - b.y0) / 2
            tilted.append(b._replace(x0=nx - half_w, y0=ny - half_h,
                                     x1=nx + half_w, y1=ny + half_h))
        trace = []
        worker.chordpro_from_boxes(tilted, trace=trace)
        self.assertTrue(stages(trace, 'skew')[0]['corrected'])


if __name__ == '__main__':
    unittest.main()


class TitleDetection(unittest.TestCase):
    """Two signals, either enough: larger type, or number-led and short."""

    def _page(self, first, *body):
        """[first] as row 0, [body] as the rest, all at the same row height."""
        rows = []
        for index, text in enumerate((first,) + body):
            rows += row(index * 20, 10, (text, 0, 8 * len(text)))
        return rows

    def taken(self, boxes):
        trace = []
        worker.chordpro_from_boxes(boxes, trace=trace)
        return stages(trace, 'title')[0]

    def test_a_short_number_led_heading_is_a_title_at_body_height(self):
        # 151-zengjed-a-dalt: the heading is set no larger than the body, and on
        # the real page it measures *smaller*, because the body carries accents
        # the title does not. Height alone could never find it.
        record = self.taken(self._page(
            '151 Zengjed a dalt',
            'Zengjed a dalt, dalt, dalt, kialtsd a szot, szot, szot,',
            'Az aranykapun at latod eleted Urat, es a szived',
            'zengjed a dalt, kialtsd a szot: El az Ur, El az Ur'))
        self.assertTrue(record['taken'])
        self.assertTrue(record['by_number'])
        self.assertFalse(record['by_height'])

    def test_a_first_line_that_merely_opens_with_a_verse_number_is_not(self):
        # 109-tart-meg-a-kegyelem opens `1 Tart meg a kegyelem, es a szivem
        # orul,` — number-led, but as long as the body. That is verse 1.
        record = self.taken(self._page(
            '1 Tart meg a kegyelem, es a szivem orul,',
            'Jezus eljott hozzam, rajtam megkonyorult.',
            'Kinyujtotta karjat, szeliden felemelt,',
            'Amig elek, azt a percet nem feledem.'))
        self.assertFalse(record['taken'])
        self.assertFalse(record['by_number'])

    def test_larger_type_is_still_enough_on_its_own(self):
        # 185-jezus-krisztusom: found by height before any of this, and it has
        # to stay found.
        boxes = (row(0, 30, ('Jezus Krisztusom, mento oltalom', 0, 900))
                 + row(60, 10, ('vagy Te minden utamon es minden napon', 0, 700))
                 + row(80, 10, ('Elottem Te mesz, mogottem Te lepsz, kerlek', 0, 700)))
        record = self.taken(boxes)
        self.assertTrue(record['taken'])
        self.assertTrue(record['by_height'])

    def test_a_long_heading_at_body_height_is_left_as_a_lyric(self):
        record = self.taken(self._page(
            '84 . Van egy ut, ami egy ici-picit gorongyos es szuk',
            'Ez az ut egy kicsiket szuk, de vezet',
            'De ne legyen a te szivednek kozombos ma'))
        self.assertFalse(record['taken'])

    def test_a_chord_row_is_never_the_title(self):
        # app-jezus-szivedbe-lat opens on a chord row, and its title is not on
        # the page at all.
        record = self.taken(row(0, 10, ('G', 0, 20), ('C', 100, 120))
                            + row(20, 10, ('Jezus szivedbe lat', 0, 200))
                            + row(40, 10, ('Mi az, mit ott talal', 0, 200)))
        self.assertFalse(record['taken'])

    def test_the_record_carries_both_measurements(self):
        record = self.taken(self._page('151 Zengjed a dalt',
                                       'Zengjed a dalt, dalt, dalt, kialtsd',
                                       'Az aranykapun at latod eleted Urat'))
        for field in ('by_height', 'by_number', 'first_row_height',
                      'body_height', 'needs', 'first_row_width', 'body_width',
                      'width_allowed'):
            self.assertIn(field, record)

    def test_chord_rows_do_not_count_towards_the_body_measure(self):
        # 151-zengjed-a-dalt missed the width test by four characters because
        # its chord rows — `D`, `A`, and a sparse `D -7 G gm` — were averaged in
        # with the lyric lines and halved the median.
        with_chords = self.taken(
            row(0, 10, ('151 Zengjed a dalt', 0, 150))
            + row(20, 10, ('D', 40, 48))
            + row(40, 10, ('Zengjed a dalt, dalt, dalt, kialtsd a szot', 0, 340))
            + row(60, 10, ('A', 60, 68))
            + row(80, 10, ('Az aranykapun at latod eleted Urat, es tovabb', 0, 360)))
        self.assertTrue(with_chords['taken'])
        self.assertTrue(with_chords['by_number'])
        # The measure is over the two lyric lines, not over all four rows.
        self.assertGreater(with_chords['body_width'], 40)

    def test_a_page_of_nothing_but_chords_still_measures_something(self):
        # The fallback: with no lyric line to measure, every row counts rather
        # than the median being taken over an empty list.
        record = self.taken(row(0, 10, ('151 Zengjed a dalt', 0, 150))
                            + row(20, 10, ('D', 0, 8), ('G', 40, 48))
                            + row(40, 10, ('C', 0, 8), ('A', 40, 48)))
        self.assertGreater(record['body_width'], 0)
