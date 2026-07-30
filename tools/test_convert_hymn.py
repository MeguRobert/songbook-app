#!/usr/bin/env python3
"""Tests for convert_hymn.parse_musicxml.

Phase 7's remaining criterion is import accuracy — fewer manual corrections per
song. The largest single source of corrections was not the OMR at all: it was
this parser. It walked `.//note` in document order and appended every one to a
single flat beat list, so an SATB page — which is what Audiveris produces from a
hymnal — came out as all four voices interleaved. Every bar then had four times
its beats, none of the lines was readable, and fixing one song by hand in the
notation editor meant deleting three notes in four.

The Dart importer (lib/domain/services/musicxml_importer.dart) already reduces a
score to one voice by a documented rule. These tests pin the Python to the same
rule, so the two import paths agree about what a given file means.
"""

import unittest

import convert_hymn


def score(body: str, header: str = '') -> str:
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  {header}
  <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
  {body}
</score-partwise>
'''


def attributes(fifths: int = 0, mode: str = '', beats: int = 4,
               beat_type: int = 4, divisions: int = 1) -> str:
    mode_xml = f'<mode>{mode}</mode>' if mode else ''
    return f'''<attributes>
        <divisions>{divisions}</divisions>
        <key><fifths>{fifths}</fifths>{mode_xml}</key>
        <time><beats>{beats}</beats><beat-type>{beat_type}</beat-type></time>
      </attributes>'''


def note(step: str, octave: int, type_: str = 'quarter', chord: bool = False,
         voice: str = None, staff: int = None, lyric: str = None,
         grace: bool = False, tie: str = None, duration: int = 1) -> str:
    return f'''<note>
        {'<grace/>' if grace else ''}
        {'<chord/>' if chord else ''}
        <pitch><step>{step}</step><octave>{octave}</octave></pitch>
        <duration>{duration}</duration>
        {f'<tie type="{tie}"/>' if tie else ''}
        {f'<voice>{voice}</voice>' if voice else ''}
        <type>{type_}</type>
        {f'<staff>{staff}</staff>' if staff else ''}
        {f'<lyric><text>{lyric}</text></lyric>' if lyric else ''}
      </note>'''


def barline(location: str = None, repeat: str = None,
            ending_number: str = None, ending_type: str = None) -> str:
    loc = f' location="{location}"' if location else ''
    ending = (f'<ending number="{ending_number or "1"}" type="{ending_type}"/>'
              if ending_type else '')
    rep = f'<repeat direction="{repeat}"/>' if repeat else ''
    return f'<barline{loc}>{ending}{rep}</barline>'


def parse(xml: str) -> dict:
    """parse_musicxml takes a path; these fixtures are strings."""
    return convert_hymn.parse_musicxml_string(xml)


class TestMelodyReduction(unittest.TestCase):
    """The reduction rule, matching the Dart importer.

    The top line of the top staff of the first part, and the highest note of any
    <chord> stack.
    """

    def test_a_chord_stack_keeps_only_its_top_note(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('C', 5)}
      {note('G', 4, chord=True)}
      {note('E', 4, chord=True)}
      {note('C', 4, chord=True)}
    </measure>
  </part>'''))

        beats = notation['measures'][0]['beats']
        self.assertEqual([b['pitch'] for b in beats], ['C5'])

    def test_the_top_note_wins_whatever_order_the_file_lists_them_in(self):
        # Audiveris does not guarantee the stack is written top-down.
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('C', 4)}
      {note('C', 5, chord=True)}
    </measure>
  </part>'''))

        self.assertEqual(
            [b['pitch'] for b in notation['measures'][0]['beats']], ['C5'])

    def test_a_second_voice_is_dropped_not_interleaved(self):
        # The bug this file exists for: two voices came out as one bar of four
        # notes in document order.
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('C', 5, voice='1')}
      {note('D', 5, voice='1')}
      <backup><duration>2</duration></backup>
      {note('E', 4, voice='2')}
      {note('F', 4, voice='2')}
    </measure>
  </part>'''))

        self.assertEqual(
            [b['pitch'] for b in notation['measures'][0]['beats']],
            ['C5', 'D5'])

    def test_the_lowest_numbered_staff_wins(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('C', 5, voice='1', staff=1)}
      {note('C', 3, voice='5', staff=2)}
    </measure>
  </part>'''))

        self.assertEqual(
            [b['pitch'] for b in notation['measures'][0]['beats']], ['C5'])

    def test_only_the_first_part_is_kept(self):
        notation = parse(score('''
  <part id="P1">
    <measure number="1">
      ''' + attributes() + note('C', 5) + '''
    </measure>
  </part>
  <part id="P2">
    <measure number="1">
      ''' + note('C', 3) + '''
    </measure>
  </part>'''))

        self.assertEqual(len(notation['measures']), 1)
        self.assertEqual(
            [b['pitch'] for b in notation['measures'][0]['beats']], ['C5'])


class TestFidelity(unittest.TestCase):
    def test_grace_notes_are_skipped(self):
        # The app's model has no grace-note beat, so a kept grace note is a full
        # beat that breaks the bar's arithmetic — and the notation editor then
        # flags the bar red for a note the engraver never intended.
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('F', 4, grace=True)}
      {note('G', 4)}
    </measure>
  </part>'''))

        self.assertEqual(
            [b['pitch'] for b in notation['measures'][0]['beats']], ['G4'])

    def test_an_empty_measure_is_kept_so_bar_numbers_stay_right(self):
        # `if beats:` dropped silent bars, which renumbered every bar after them
        # — so a correction aimed at bar 12 landed on bar 11.
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('G', 4)}
    </measure>
    <measure number="2">
    </measure>
    <measure number="3">
      {note('A', 4)}
    </measure>
  </part>'''))

        self.assertEqual(len(notation['measures']), 3)
        self.assertEqual(notation['measures'][1]['beats'], [])

    def test_ties_are_carried(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('G', 4, tie='start')}
      {note('G', 4, tie='stop')}
    </measure>
  </part>'''))

        beats = notation['measures'][0]['beats']
        self.assertTrue(beats[0].get('tieStart'))
        self.assertTrue(beats[1].get('tieEnd'))

    def test_a_minor_key_resolves_to_the_relative_minor_name(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes(fifths=-1, mode='minor')}
      {note('D', 4)}
    </measure>
  </part>'''))

        self.assertEqual(notation['originalKey'], 'Dm')

    def test_a_major_key_is_unaffected_by_the_minor_support(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes(fifths=-1)}
      {note('F', 4)}
    </measure>
  </part>'''))

        self.assertEqual(notation['originalKey'], 'F')

    def test_an_implicit_measure_is_flagged_as_a_pickup(self):
        # The file saying "this bar is deliberately short". Without it the
        # notation editor flags every upbeat hymn as damaged.
        notation = parse(score(f'''
  <part id="P1">
    <measure number="0" implicit="yes">
      {attributes()}
      {note('G', 4)}
    </measure>
    <measure number="1">
      {note('A', 4)}
    </measure>
  </part>'''))

        self.assertTrue(notation['measures'][0].get('isPickup'))
        self.assertNotIn('isPickup', notation['measures'][1])


class TestRepeats(unittest.TestCase):
    """Parity with the Dart importer, which reads these."""

    def test_a_backward_repeat_closes_a_repeat(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('G', 4)}
      {barline(location='right', repeat='backward')}
    </measure>
  </part>'''))

        self.assertTrue(notation['measures'][0].get('repeatEnd'))

    def test_a_forward_repeat_opens_a_repeat(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('G', 4)}
    </measure>
    <measure number="2">
      {barline(location='left', repeat='forward')}
      {note('A', 4)}
    </measure>
  </part>'''))

        self.assertNotIn('repeatStart', notation['measures'][0])
        self.assertTrue(notation['measures'][1].get('repeatStart'))

    def test_an_ending_marks_every_measure_under_its_bracket(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('G', 4)}
    </measure>
    <measure number="2">
      {barline(location='left', ending_number='1', ending_type='start')}
      {note('A', 4)}
    </measure>
    <measure number="3">
      {note('B', 4)}
      {barline(location='right', ending_number='1', ending_type='stop')}
    </measure>
    <measure number="4">
      {barline(location='left', ending_number='2', ending_type='start')}
      {note('C', 5)}
    </measure>
  </part>'''))

        self.assertEqual(
            [m.get('volta') for m in notation['measures']], [None, 1, 1, 2])

    def test_a_score_with_no_barlines_declares_no_repeats(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('G', 4)}
    </measure>
  </part>'''))

        measure = notation['measures'][0]
        self.assertNotIn('repeatStart', measure)
        self.assertNotIn('repeatEnd', measure)
        self.assertNotIn('volta', measure)


class TestUntrustedInput(unittest.TestCase):
    """An internal entity subset is refused rather than expanded.

    `xml.etree.ElementTree` does not resolve *external* entities, but it does
    expand internal ones, which is the billion-laughs shape. So the internal
    subset is what gets refused — not the DOCTYPE itself, which every real
    Audiveris and MuseScore file carries.
    """

    def test_a_document_declaring_its_own_entities_is_refused(self):
        bomb = '''<?xml version="1.0"?>
<!DOCTYPE score [ <!ENTITY a "aaaaaaaaaa"> ]>
<score-partwise><part id="P1"><measure number="1"/></part></score-partwise>'''

        with self.assertRaises(ValueError) as caught:
            parse(bomb)
        self.assertIn('entities', str(caught.exception))

    def test_the_standard_musicxml_doctype_is_accepted(self):
        # Refusing every DOCTYPE rejected the entire contents of
        # audiveris_output/ — the real OMR output this pipeline exists to read.
        # The external DTD is inert here because nothing fetches it.
        real = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      ''' + attributes() + note('G', 4) + '''
    </measure>
  </part>
</score-partwise>'''

        notation = parse(real)
        self.assertEqual(
            [b['pitch'] for b in notation['measures'][0]['beats']], ['G4'])

    def test_an_ordinary_score_is_unaffected(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('G', 4)}
    </measure>
  </part>'''))

        self.assertEqual(len(notation['measures']), 1)


class TestRebar(unittest.TestCase):
    """Splitting over-long measures at the time-signature boundary.

    Audiveris misses barlines on a photographed page. On the real SÉ-90 output it
    misses nearly all of them: six `<measure>` elements come back holding 18 beats
    each in 4/4, so each one is really four and a half bars. Nothing downstream
    can use that — the staff engraves six enormous bars, and correcting it by hand
    means splitting every one in the notation editor, which cannot even add a
    measure.

    Re-barring is arithmetic on a beat list, so it cannot invent or lose a note:
    the notes come out in the same order, just distributed into bars that add up.
    Opt-in, because a score whose barlines WERE detected must not be touched.
    """

    def test_an_over_long_measure_is_split_into_full_bars(self):
        notation = {
            'timeSignature': '4/4',
            'measures': [{'beats': [
                {'pitch': 'G4', 'duration': 'quarter'} for _ in range(8)
            ]}],
        }

        result = convert_hymn.rebar_measures(notation)

        self.assertEqual(len(result['measures']), 2)
        self.assertEqual(len(result['measures'][0]['beats']), 4)
        self.assertEqual(len(result['measures'][1]['beats']), 4)

    def test_no_note_is_invented_or_lost(self):
        beats = [{'pitch': f'G{i % 5 + 1}', 'duration': 'quarter'}
                 for i in range(18)]
        notation = {'timeSignature': '4/4', 'measures': [{'beats': list(beats)}]}

        result = convert_hymn.rebar_measures(notation)

        flattened = [b for m in result['measures'] for b in m['beats']]
        self.assertEqual(flattened, beats)

    def test_a_remainder_becomes_a_short_final_bar(self):
        notation = {
            'timeSignature': '4/4',
            'measures': [{'beats': [
                {'pitch': 'G4', 'duration': 'quarter'} for _ in range(6)
            ]}],
        }

        result = convert_hymn.rebar_measures(notation)

        self.assertEqual([len(m['beats']) for m in result['measures']], [4, 2])

    def test_a_measure_that_already_adds_up_is_untouched(self):
        measure = {'beats': [{'pitch': 'G4', 'duration': 'whole'}],
                   'repeatEnd': True}
        notation = {'timeSignature': '4/4', 'measures': [measure]}

        result = convert_hymn.rebar_measures(notation)

        self.assertEqual(len(result['measures']), 1)
        self.assertTrue(result['measures'][0]['repeatEnd'])

    def test_a_pickup_is_left_alone(self):
        # Deliberately short, and splitting it would be splitting nothing.
        notation = {
            'timeSignature': '4/4',
            'measures': [{'beats': [{'pitch': 'G4', 'duration': 'quarter'}],
                          'isPickup': True}],
        }

        result = convert_hymn.rebar_measures(notation)

        self.assertEqual(len(result['measures']), 1)
        self.assertTrue(result['measures'][0]['isPickup'])

    def test_a_short_measure_is_not_padded(self):
        # A bar Audiveris read as too SHORT is a dropped note, not a barline
        # error. Padding it with a rest would hide the loss.
        notation = {
            'timeSignature': '4/4',
            'measures': [{'beats': [{'pitch': 'G4', 'duration': 'quarter'}]}],
        }

        result = convert_hymn.rebar_measures(notation)

        self.assertEqual(len(result['measures']), 1)
        self.assertEqual(len(result['measures'][0]['beats']), 1)

    def test_measure_flags_land_on_the_right_piece(self):
        # A closing repeat belongs at the END of the run; an opening repeat and a
        # pickup flag belong at its start. Copying every flag onto every piece
        # would put a repeat sign in the middle of a phrase.
        notation = {
            'timeSignature': '4/4',
            'measures': [{
                'beats': [{'pitch': 'G4', 'duration': 'quarter'}
                          for _ in range(8)],
                'repeatStart': True,
                'repeatEnd': True,
                'volta': 2,
            }],
        }

        result = convert_hymn.rebar_measures(notation)
        first, last = result['measures'][0], result['measures'][-1]

        self.assertTrue(first.get('repeatStart'))
        self.assertNotIn('repeatEnd', first)
        self.assertTrue(last.get('repeatEnd'))
        self.assertNotIn('repeatStart', last)
        # A volta covers every bar of the run.
        self.assertEqual([m.get('volta') for m in result['measures']], [2, 2])

    def test_dotted_notes_count_as_one_and_a_half(self):
        # 4/4 as a dotted half plus a half is 2 bars' worth: 3 + 2 = 5 quarters.
        notation = {
            'timeSignature': '4/4',
            'measures': [{'beats': [
                {'pitch': 'G4', 'duration': 'half', 'dotted': True},
                {'pitch': 'A4', 'duration': 'quarter'},
                {'pitch': 'B4', 'duration': 'whole'},
            ]}],
        }

        result = convert_hymn.rebar_measures(notation)

        self.assertEqual([len(m['beats']) for m in result['measures']], [2, 1])

    def test_a_note_longer_than_a_bar_is_left_in_its_own_bar(self):
        # 3/4 with a whole note: it cannot fit, and splitting a single note is not
        # something re-barring can do. Its own bar, and the validator will say so.
        notation = {
            'timeSignature': '3/4',
            'measures': [{'beats': [{'pitch': 'G4', 'duration': 'whole'}]}],
        }

        result = convert_hymn.rebar_measures(notation)

        self.assertEqual(len(result['measures']), 1)

    def test_an_unparseable_time_signature_changes_nothing(self):
        notation = {
            'timeSignature': 'common',
            'measures': [{'beats': [{'pitch': 'G4', 'duration': 'quarter'}
                                    for _ in range(8)]}],
        }

        result = convert_hymn.rebar_measures(notation)

        self.assertEqual(len(result['measures']), 1)


class TestLyrics(unittest.TestCase):
    def test_a_syllable_on_the_melody_note_is_kept(self):
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('C', 5, lyric='Mint')}
    </measure>
  </part>'''))

        self.assertEqual(
            notation['measures'][0]['beats'][0]['syllable'], 'Mint')

    def test_a_syllable_hanging_off_a_lower_chord_note_is_still_found(self):
        # Engravers attach the lyric to whichever notehead they like, and the
        # reduction keeps the top note — so a naive reduction loses the word.
        notation = parse(score(f'''
  <part id="P1">
    <measure number="1">
      {attributes()}
      {note('C', 5)}
      {note('C', 4, chord=True, lyric='Mint')}
    </measure>
  </part>'''))

        beat = notation['measures'][0]['beats'][0]
        self.assertEqual(beat['pitch'], 'C5')
        self.assertEqual(beat['syllable'], 'Mint')


if __name__ == '__main__':
    unittest.main()
