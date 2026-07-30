#!/usr/bin/env python3
"""
Hymnal Sheet Music to JSON Converter

Converts sheet music images to JSON notation format for the Songbook app.
Uses Audiveris for OMR (Optical Music Recognition) and converts to app's JSON format.

Usage:
    python convert_hymn.py <image_path> --song <song_number> [--output <output_path>]
    python convert_hymn.py --from-xml <xml_path> --song <song_number>

Examples:
    python convert_hymn.py zsolt-090.jpg --song 90
    python convert_hymn.py zsolt-090.jpg --song 90 --output notation.json
    python convert_hymn.py --from-xml output/zsolt-090.xml --song 90
    python convert_hymn.py zsolt-090.jpg --song 90 --ocr-lyrics
"""

import argparse
import json
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

# Optional: validate songs before writing them into songs.json. Guarded so the
# converter still runs if song_validator.py is absent.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import song_validator as sv
except ImportError:  # pragma: no cover - defensive
    sv = None


def run_audiveris(image_path: str, output_dir: str) -> str:
    """Run Audiveris OMR on the image and return path to MusicXML output."""
    import subprocess

    print(f"Running Audiveris OMR on: {image_path}")

    # Audiveris CLI: audiveris -batch -export -output <dir> <image>
    result = subprocess.run(
        ["C:/Program Files/Audiveris/Audiveris.exe",
         "-batch", "-export", "-output", output_dir, image_path],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print(f"Audiveris stderr: {result.stderr}")
        print(f"Audiveris stdout: {result.stdout}")
        raise RuntimeError(f"Audiveris failed: {result.stderr}")

    # Find the MusicXML output (.mxl is compressed MusicXML)
    output_path = Path(output_dir)
    mxl_files = list(output_path.glob("*.mxl"))
    xml_files = list(output_path.glob("*.xml"))

    if mxl_files:
        # Extract .mxl (it's a zip file)
        mxl_path = mxl_files[0]
        with zipfile.ZipFile(mxl_path, 'r') as z:
            # Find the main XML file inside
            for name in z.namelist():
                if name.endswith('.xml') and not name.startswith('META-INF'):
                    z.extract(name, output_dir)
                    return str(output_path / name)

    if xml_files:
        return str(xml_files[0])

    raise RuntimeError(f"No MusicXML output found in {output_dir}")


def run_oemer(image_path: str, output_dir: str) -> str:
    """Run oemer OMR on the image and return path to MusicXML output."""
    import subprocess

    print(f"Running oemer OMR on: {image_path}")

    # oemer syntax: oemer img_path -o output_path
    result = subprocess.run(
        ["oemer", image_path, "-o", output_dir],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print(f"oemer stderr: {result.stderr}")
        raise RuntimeError(f"oemer failed: {result.stderr}")

    # Find the MusicXML output
    output_path = Path(output_dir)
    mxl_files = list(output_path.glob("*.musicxml")) + list(output_path.glob("*.xml"))

    if not mxl_files:
        # oemer might create a subdirectory
        for subdir in output_path.iterdir():
            if subdir.is_dir():
                mxl_files = list(subdir.glob("*.musicxml")) + list(subdir.glob("*.xml"))
                if mxl_files:
                    break

    if not mxl_files:
        raise RuntimeError(f"No MusicXML output found in {output_dir}")

    return str(mxl_files[0])


def extract_xml_from_mxl(mxl_path: str, output_dir: str) -> str:
    """Extract MusicXML from compressed .mxl file."""
    with zipfile.ZipFile(mxl_path, 'r') as z:
        for name in z.namelist():
            if name.endswith('.xml') and not name.startswith('META-INF'):
                z.extract(name, output_dir)
                return str(Path(output_dir) / name)
    raise RuntimeError(f"No XML found in {mxl_path}")


def ocr_lyrics_from_image(image_path: str, num_systems: int = 6) -> list:
    """
    Extract lyrics from sheet music image using OCR.
    Returns a list of lyric lines (one per system).
    Uses EasyOCR which has built-in Hungarian support.

    Strategy: Scan the whole image, detect all text, cluster by Y position
    using gap detection, then sort each cluster left-to-right.
    """
    try:
        import easyocr
        from PIL import Image, ImageOps, ImageFilter
        import numpy as np
    except ImportError:
        print("Warning: easyocr or PIL not installed. Install with:")
        print("  pip install easyocr Pillow numpy")
        return []

    print(f"Running OCR on image to extract lyrics...")
    print("  (First run downloads language models, may take a moment)")

    # Initialize EasyOCR reader with Hungarian and English
    reader = easyocr.Reader(['hu', 'en'], verbose=False)

    img = Image.open(image_path)
    width, height = img.size

    # Convert to RGB if needed (EasyOCR prefers RGB)
    if img.mode != 'RGB':
        img = img.convert('RGB')

    # Use original image - EasyOCR handles preprocessing internally
    img_processed = np.array(img)

    # Run OCR on the entire image - let EasyOCR find all text
    print("  Scanning full image for text...")

    # Don't use allowlist - let EasyOCR use its full character set
    results = reader.readtext(img_processed, paragraph=False)

    # Debug: show all detected text with confidence
    print(f"  Raw OCR found {len(results)} text regions")

    if not results:
        print("  No text detected")
        return [""] * num_systems

    # Filter results: keep only text that looks like lyrics (alphabetic, hyphens)
    # and filter out things that look like music notation
    filtered_results = []
    for bbox, text, confidence in results:
        # Skip very short single chars (except verse numbers and single letters like "e")
        if len(text) < 1:
            continue
        # Keep single letters if they're alphabetic (might be syllables like "e-", "i-")
        if len(text) == 1 and not (text.isalpha() or text.isdigit()):
            continue
        # Lower confidence threshold to catch edge text
        if confidence < 0.1:
            continue
        # Skip if it looks like music notation (mostly numbers, special chars)
        # But allow verse numbers like "1."
        if not (len(text) <= 2 and text[0].isdigit()):
            alpha_ratio = sum(1 for c in text if c.isalpha() or c in '-,;:.!? ') / len(text)
            if alpha_ratio < 0.5:
                continue

        # Get the Y position - use bottom of bbox since lyrics hang below baseline
        y_bottom = bbox[2][1]
        x_left = bbox[0][0]
        x_right = bbox[2][0]
        filtered_results.append({
            'y': y_bottom,
            'x_left': x_left,
            'x_right': x_right,
            'text': text,
            'confidence': confidence,
            'bbox': bbox
        })

    if not filtered_results:
        print("  No lyrics text detected")
        return [""] * num_systems

    # Sort by Y position (bottom of text)
    filtered_results.sort(key=lambda x: x['y'])

    # Cluster by Y position using gap detection
    # If gap between consecutive items > threshold, start new cluster
    min_gap = height / (num_systems * 2)  # Minimum gap to split clusters

    clusters = []
    current_cluster = [filtered_results[0]]

    for i in range(1, len(filtered_results)):
        prev_y = filtered_results[i-1]['y']
        curr_y = filtered_results[i]['y']

        if curr_y - prev_y > min_gap:
            # Large gap - start new cluster
            clusters.append(current_cluster)
            current_cluster = [filtered_results[i]]
        else:
            # Same cluster
            current_cluster.append(filtered_results[i])

    # Don't forget the last cluster
    if current_cluster:
        clusters.append(current_cluster)

    print(f"  Found {len(clusters)} text lines")

    # If we have more clusters than systems, merge closest ones
    while len(clusters) > num_systems:
        # Find the two closest clusters (by Y gap)
        min_gap_idx = 0
        min_gap_val = float('inf')
        for i in range(len(clusters) - 1):
            # Gap between cluster i's max Y and cluster i+1's min Y
            c1_max_y = max(item['y'] for item in clusters[i])
            c2_min_y = min(item['y'] for item in clusters[i+1])
            gap = c2_min_y - c1_max_y
            if gap < min_gap_val:
                min_gap_val = gap
                min_gap_idx = i
        # Merge clusters[min_gap_idx] and clusters[min_gap_idx + 1]
        clusters[min_gap_idx].extend(clusters[min_gap_idx + 1])
        del clusters[min_gap_idx + 1]

    # If we have fewer clusters than systems, pad with empty
    while len(clusters) < num_systems:
        clusters.append([])

    # Sort each cluster left-to-right and join text
    lyrics_by_system = []
    for system_idx, cluster in enumerate(clusters):
        if cluster:
            # Sort by X position (left edge)
            cluster.sort(key=lambda x: x['x_left'])
            text = ' '.join(item['text'] for item in cluster)
            # Clean up
            text = re.sub(r'\s+', ' ', text).strip()

            # Post-processing: fix common OCR confusions
            # 1. Replace "1" with "i" when surrounded by letters (not at start of line)
            #    e.g., "le 1 től" -> "le i től", but keep "1." at start
            text = re.sub(r'(?<=[a-záéíóöőúüű\s])1(?=[\s-])', 'i', text, flags=re.IGNORECASE)

            # 2. Fix common Hungarian word patterns that OCR often misses
            # "dő ben" or similar -> "i-dő-ben" (időben - common word meaning "in time")
            words = text.split()
            if len(words) >= 2:
                last_word = words[-1].rstrip('_.,')  # Remove trailing punctuation
                prev_word = words[-2]
                if last_word == 'ben' and prev_word and prev_word[0].lower() == 'd' and len(prev_word) <= 3:
                    # This is likely "dő ben" -> "i-dő-ben"
                    words = words[:-2]
                    words.append('i-dő-ben.')
                    text = ' '.join(words)

            # 3. Fix "Es" or "es" at start of line -> "És" (common conjunction)
            text = re.sub(r'^Es\s', 'És ', text)
            text = re.sub(r'^es\s', 'és ', text)

            # 4. Clean up trailing underscores and fix spacing around hyphens
            text = text.rstrip('_')
            text = re.sub(r'\s*-\s*', '-', text)  # Remove spaces around hyphens

            lyrics_by_system.append(text)
            # Use ASCII-safe printing for Windows console compatibility
            try:
                print(f"  System {system_idx + 1}: {text}")
            except UnicodeEncodeError:
                print(f"  System {system_idx + 1}: {text.encode('ascii', 'replace').decode()}")
        else:
            lyrics_by_system.append("")
            print(f"  System {system_idx + 1}: (no text detected)")

    return lyrics_by_system


def distribute_lyrics_to_notes(notation: dict, lyrics_by_system: list) -> dict:
    """
    Distribute OCR'd lyrics to notes in the notation.
    Each system's lyrics are split and assigned to non-rest notes.
    """
    if not lyrics_by_system:
        return notation

    measures = notation.get('measures', [])

    for system_idx, lyrics_text in enumerate(lyrics_by_system):
        if system_idx >= len(measures):
            break

        if not lyrics_text:
            continue

        # Remove verse numbers like "1.", "2." etc. from the start of first system
        if system_idx == 0:
            lyrics_text = re.sub(r'^\d+\.\s*', '', lyrics_text)

        # Split lyrics into syllables (by space and hyphen)
        # Keep track of hyphens for word continuation
        syllables = []
        words = lyrics_text.split()

        for word in words:
            # Check if word has internal hyphens (syllable breaks)
            if '-' in word:
                parts = word.split('-')
                for i, part in enumerate(parts):
                    if part:
                        # Add hyphen to non-final syllables
                        if i < len(parts) - 1:
                            syllables.append(part + '-')
                        else:
                            syllables.append(part)
            else:
                syllables.append(word)

        # Debug: show syllable count vs note count
        measure = measures[system_idx]
        beats = measure.get('beats', [])
        non_rest_notes = [b for b in beats if b.get('pitch', 'R') != 'R']
        print(f"    System {system_idx + 1}: {len(syllables)} syllables, {len(non_rest_notes)} notes")

        # Assign syllables to non-rest notes
        note_idx = 0
        for beat in beats:
            if beat.get('pitch', 'R') != 'R' and note_idx < len(syllables):
                beat['syllable'] = syllables[note_idx]
                note_idx += 1

    return notation


MAJOR_KEYS = {
    0: 'C', 1: 'G', 2: 'D', 3: 'A', 4: 'E', 5: 'B', 6: 'F#', 7: 'C#',
    -1: 'F', -2: 'Bb', -3: 'Eb', -4: 'Ab', -5: 'Db', -6: 'Gb', -7: 'Cb',
}

MINOR_KEYS = {
    0: 'Am', 1: 'Em', 2: 'Bm', 3: 'F#m', 4: 'C#m', 5: 'G#m', 6: 'D#m',
    7: 'A#m', -1: 'Dm', -2: 'Gm', -3: 'Cm', -4: 'Fm', -5: 'Bbm', -6: 'Ebm',
    -7: 'Abm',
}

DURATION_TYPES = {
    'whole': 'whole',
    'half': 'half',
    'quarter': 'quarter',
    'eighth': 'eighth',
    '16th': 'sixteenth',
    'sixteenth': 'sixteenth',
}

# Beats a note is worth, relative to a quarter. Mirrors NoteDuration in
# lib/data/models/notation.dart, which is the set the renderer can draw.
DURATION_TYPES_BEATS = {
    'whole': 4.0,
    'half': 2.0,
    'quarter': 1.0,
    'eighth': 0.5,
    'sixteenth': 0.25,
}

# Semitones above C, for picking the top note of a <chord> stack.
_STEP_SEMITONES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def _local(tag: str) -> str:
    """Element tag without its namespace."""
    return tag.split('}')[-1] if '}' in tag else tag


def _children(element, name: str):
    return [c for c in element if _local(c.tag) == name]


def _child(element, name: str):
    for c in element:
        if _local(c.tag) == name:
            return c
    return None


def _text(element, name: str):
    child = _child(element, name)
    if child is None or child.text is None:
        return None
    return child.text.strip()


def _descendants(root, name: str):
    return [e for e in root.iter() if _local(e.tag) == name]


def _pitch_value(step: str, alter: int, octave: int) -> int:
    return (octave + 1) * 12 + _STEP_SEMITONES.get(step.upper(), 0) + alter


def _read_note(note_elem):
    """One <note> as a dict, or None for a grace note.

    Grace notes are dropped: the app's model has no grace-note beat, so a kept
    one becomes a full beat that breaks the bar's arithmetic, and the notation
    editor then flags the bar red for a note the engraver never intended.
    """
    if _child(note_elem, 'grace') is not None:
        return None

    is_rest = _child(note_elem, 'rest') is not None
    pitch = 'R'
    pitch_value = -1

    pitch_elem = _child(note_elem, 'pitch')
    if not is_rest and pitch_elem is not None:
        step = _text(pitch_elem, 'step')
        octave = _text(pitch_elem, 'octave')
        alter_text = _text(pitch_elem, 'alter')
        alter = int(alter_text) if alter_text else 0
        if step and octave:
            accidental = ''
            if alter > 0:
                accidental = '#'
            elif alter < 0:
                accidental = 'b'
            pitch = step + accidental + octave
            try:
                pitch_value = _pitch_value(step, alter, int(octave))
            except ValueError:
                pitch_value = -1

    type_text = _text(note_elem, 'type')
    duration = DURATION_TYPES.get(type_text, 'quarter') if type_text else 'quarter'

    # Ties are written as <tie> and duplicated as <notations><tied>; some
    # exporters write only the second.
    tie_types = set(t.get('type') for t in _children(note_elem, 'tie'))
    for notations in _children(note_elem, 'notations'):
        tie_types |= set(t.get('type') for t in _children(notations, 'tied'))

    syllable = None
    lyric_elem = _child(note_elem, 'lyric')
    if lyric_elem is not None:
        text_elem = _child(lyric_elem, 'text')
        if text_elem is not None and text_elem.text:
            syllable = text_elem.text
            syllabic = _text(lyric_elem, 'syllabic')
            if syllabic in ('begin', 'middle'):
                syllable += '-'

    staff_text = _text(note_elem, 'staff')
    return {
        'pitch': pitch,
        'pitchValue': pitch_value,
        'duration': duration,
        'dotted': _child(note_elem, 'dot') is not None,
        'tieStart': 'start' in tie_types,
        'tieEnd': 'stop' in tie_types,
        'syllable': syllable,
        'staff': int(staff_text) if staff_text and staff_text.isdigit() else 1,
        'voice': _text(note_elem, 'voice') or '1',
        'isChordMember': _child(note_elem, 'chord') is not None,
    }


def _read_barline(barline_elem, into: dict):
    """Folds one <barline> into a per-measure dict of repeat/ending state.

    A measure can carry two - a forward repeat on its left and a backward one on
    its right - so this accumulates rather than replaces.
    """
    repeat = _child(barline_elem, 'repeat')
    if repeat is not None:
        direction = repeat.get('direction')
        if direction == 'forward':
            into['repeatStart'] = True
        elif direction == 'backward':
            into['repeatEnd'] = True

    ending = _child(barline_elem, 'ending')
    if ending is None:
        return
    ending_type = ending.get('type')
    if ending_type == 'start':
        # "1, 2" is legal and means the bracket covers both passes. The app model
        # holds one number, so the lowest is what gets drawn.
        for part in (ending.get('number') or '').split(','):
            part = part.strip()
            if part.isdigit():
                into['endingStart'] = int(part)
                break
    elif ending_type in ('stop', 'discontinue'):
        into['endingStops'] = True


def _melody_beats(notes: list) -> list:
    """The melody line of one measure, by the documented reduction rule.

    The first <part> in the score, its lowest-numbered <staff>, its
    lowest-numbered <voice> on that staff - the top line of the top staff of the
    first part, which is where the melody lives in both the
    four-parts-one-voice and the one-part-two-staves SATB encodings. A <chord>
    stack reduces to its highest-sounding note, the same rule applied vertically.

    This replaces walking `.//note` and appending every one, which interleaved
    all four voices of an SATB page into a single bar - so every bar had four
    times its beats and fixing one song by hand meant deleting three notes in
    four. Matches lib/domain/services/musicxml_importer.dart, so the two import
    paths agree about what a given file means.
    """
    if not notes:
        return []

    # Group into stacks: one note plus any <chord> notes hanging off it.
    stacks = []
    for note in notes:
        if note['isChordMember'] and stacks:
            stacks[-1].append(note)
        else:
            stacks.append([note])

    # The melody's (staff, voice) is the lowest of each, taken from the stack
    # heads - a chord member carries no voice of its own.
    def sort_key(stack):
        head = stack[0]
        voice = head['voice']
        return (head['staff'], int(voice) if voice.isdigit() else 1 << 20, voice)

    best = min(sort_key(stack) for stack in stacks)

    beats = []
    for stack in stacks:
        if sort_key(stack) != best:
            continue
        # Highest sounding note of the stack.
        top = max(stack, key=lambda n: n['pitchValue'])
        # The lyric belongs to the stack, not to one of its notes: engravers hang
        # the syllable off whichever notehead they like, so a reduction that only
        # looked at the top note dropped the word.
        syllable = None
        for candidate in stack:
            if candidate['syllable']:
                syllable = candidate['syllable']
                break

        beat = {'pitch': top['pitch'], 'duration': top['duration']}
        if syllable:
            beat['syllable'] = syllable
        if top['dotted']:
            beat['dotted'] = True
        if top['tieStart']:
            beat['tieStart'] = True
        if top['tieEnd']:
            beat['tieEnd'] = True
        beats.append(beat)

    return beats


def parse_musicxml_string(xml: str) -> dict:
    """Parse a MusicXML document held in a string.

    Split out from parse_musicxml so the parsing is testable without a file on
    disk. The reduction rule above is the part that most needed pinning down, and
    it had no tests at all.

    Raises ValueError for a DOCTYPE with an internal entity subset.

    `xml.etree` does not resolve *external* entities, but it does expand internal
    ones, which is the billion-laughs shape. So the internal subset is what gets
    refused - not the DOCTYPE itself. Audiveris and MuseScore both emit the
    standard external one:

        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0
          Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">

    which is inert here because nothing fetches it. Refusing every DOCTYPE
    rejected the entire contents of audiveris_output/ - the real OMR output this
    pipeline exists to read - which is how this was caught.

    Precise rather than a pip dependency on defusedxml: this tooling is
    deliberately pure-stdlib so it runs on a machine with nothing installed.
    """
    # Checked before parsing, not after: the point is not to hand the entity
    # expander anything in the first place.
    if re.search(r'<!DOCTYPE[^>\[]*\[', xml, re.IGNORECASE):
        raise ValueError(
            'This file declares its own XML entities (a DOCTYPE with an '
            'internal subset). A MusicXML score has no use for that, and '
            'expanding them can exhaust memory, so it will not be parsed. '
            'Re-export the score from MuseScore.')

    root = ET.fromstring(xml)

    key_elems = _descendants(root, 'key')
    key_fifths = 0
    key_minor = False
    if key_elems:
        key_elem = key_elems[0]
        fifths = _text(key_elem, 'fifths')
        if fifths:
            try:
                key_fifths = int(fifths)
            except ValueError:
                key_fifths = 0
        key_minor = (_text(key_elem, 'mode') or '').lower() == 'minor'
    key_map = MINOR_KEYS if key_minor else MAJOR_KEYS
    original_key = key_map.get(key_fifths, 'Am' if key_minor else 'C')

    beats_elems = _descendants(root, 'beats')
    beat_type_elems = _descendants(root, 'beat-type')
    time_beats = (beats_elems[0].text or '4').strip() if beats_elems else '4'
    time_type = (beat_type_elems[0].text or '4').strip() if beat_type_elems else '4'
    time_signature = time_beats + '/' + time_type

    parts = _descendants(root, 'part')
    # Only the first part. The Python used to walk every one of them into a
    # single measure list, so a four-parts-one-voice SATB file produced four
    # copies of the piece end to end.
    part = parts[0] if parts else root

    measure_elems = _children(part, 'measure') or _descendants(part, 'measure')

    measures = []
    open_volta = None
    for measure_elem in measure_elems:
        notes = []
        bars = {}
        for child in measure_elem:
            tag = _local(child.tag)
            if tag == 'note':
                note = _read_note(child)
                if note is not None:
                    notes.append(note)
            elif tag == 'barline':
                _read_barline(child, bars)

        # Kept even when empty. `if beats:` dropped silent bars, which renumbered
        # every bar after them - so a correction aimed at bar 12 landed on 11.
        measure = {'beats': _melody_beats(notes)}

        if measure_elem.get('implicit') == 'yes':
            measure['isPickup'] = True
        if bars.get('repeatStart'):
            measure['repeatStart'] = True
        if bars.get('repeatEnd'):
            measure['repeatEnd'] = True

        open_volta = bars.get('endingStart', open_volta)
        if open_volta is not None:
            measure['volta'] = open_volta
        if bars.get('endingStops'):
            open_volta = None

        measures.append(measure)

    return {
        'originalKey': original_key,
        'timeSignature': time_signature,
        'showTimeSignature': False,
        'measures': measures,
    }


def parse_musicxml(mxl_path: str) -> dict:
    """Parse a MusicXML file and extract notation data."""
    print("Parsing MusicXML: " + str(mxl_path))
    with open(mxl_path, 'r', encoding='utf-8', errors='replace') as handle:
        return parse_musicxml_string(handle.read())


def rebar_measures(notation: dict) -> dict:
    """Split measures that hold more beats than the time signature allows.

    Audiveris misses barlines on a photographed page. On the real SE-90 output it
    misses nearly all of them: six <measure> elements come back holding 18 beats
    each in 4/4, so each one is really four and a half bars. Nothing downstream
    can use that - the staff engraves six enormous bars, the notation editor flags
    every one red, and correcting it by hand means splitting each of them, which
    the editor cannot do (it edits beats within a measure, not measures).

    This is arithmetic on a beat list, so it cannot invent or lose a note: the
    notes come out in the same order, redistributed into bars that add up.

    What it deliberately does NOT do:

      - pad a SHORT bar. A bar under the signature is a dropped note, not a
        barline error, and a rest inserted to make the sum work would hide the
        loss. The validator reports those instead.
      - touch a declared pickup. It is supposed to be short.
      - split a single note longer than a bar. That is a mis-read duration, and
        re-barring cannot fix it; it gets its own bar and the validator says so.

    Opt-in via --rebar, because a score whose barlines WERE detected must not be
    second-guessed.
    """
    signature = notation.get('timeSignature')
    expected = None
    if isinstance(signature, str) and '/' in signature:
        beats, _, beat_type = signature.partition('/')
        try:
            # Beats per bar expressed in quarters: 6/8 is three quarters' worth.
            expected = int(beats) * 4.0 / int(beat_type)
        except (ValueError, ZeroDivisionError):
            expected = None
    if not expected or expected <= 0:
        return notation

    rebarred = []
    for measure in notation.get('measures', []):
        rebarred.extend(_split_measure(measure, expected))
    notation['measures'] = rebarred
    return notation


def _beat_value(beat: dict) -> float:
    value = DURATION_TYPES_BEATS.get(beat.get('duration'), 1.0)
    return value * 1.5 if beat.get('dotted') else value


def _split_measure(measure: dict, expected: float) -> list:
    """One measure as a list of bars that each add up to [expected]."""
    beats = measure.get('beats') or []
    if not beats or measure.get('isPickup'):
        return [measure]

    total = sum(_beat_value(b) for b in beats)
    # Only over-long bars. A short one is a dropped note; see the docstring.
    if total <= expected + 0.001:
        return [measure]

    groups = []
    current = []
    running = 0.0
    for beat in beats:
        value = _beat_value(beat)
        # Close the bar BEFORE a note that would overflow it, so a bar never
        # exceeds the signature. A note longer than a whole bar cannot be placed
        # without exceeding it, so it lands alone and is reported instead.
        if current and running + value > expected + 0.001:
            groups.append(current)
            current = []
            running = 0.0
        current.append(beat)
        running += value
    if current:
        groups.append(current)

    if len(groups) < 2:
        return [measure]

    # Flags belong to the ends of the run, not to every piece of it: an opening
    # repeat at the start, a closing repeat and the line break at the end.
    # Copying them all onto all of them would print a repeat sign mid-phrase.
    result = []
    for index, group in enumerate(groups):
        bar = {'beats': group}
        if index == 0 and measure.get('repeatStart'):
            bar['repeatStart'] = True
        if index == len(groups) - 1:
            if measure.get('repeatEnd'):
                bar['repeatEnd'] = True
            if measure.get('lineBreakAfter'):
                bar['lineBreakAfter'] = True
        # A volta bracket covers every bar of the run it was read from.
        if measure.get('volta') is not None:
            bar['volta'] = measure['volta']
        result.append(bar)
    return result


def add_line_breaks(notation: dict, measures_per_line: int = None) -> dict:
    """Add lineBreakAfter markers to measures based on visual grouping."""
    measures = notation.get('measures', [])

    if not measures:
        return notation

    # If not specified, try to detect natural line breaks
    # For hymns, typically 2-4 measures per line
    if measures_per_line is None:
        measures_per_line = 2  # Default for hymns

    for i, measure in enumerate(measures):
        if (i + 1) % measures_per_line == 0 and i < len(measures) - 1:
            measure['lineBreakAfter'] = True

    return notation


def convert_to_app_format(notation: dict, verse_number: int = 1) -> dict:
    """Convert parsed notation to the app's JSON format."""
    return {
        'originalKey': notation['originalKey'],
        'timeSignature': notation['timeSignature'],
        'showTimeSignature': notation.get('showTimeSignature', False),
        'verses': [
            {
                'number': verse_number,
                'measures': notation['measures']
            }
        ]
    }


def update_songs_json(songs_json_path: str, song_number: int, notation: dict,
                      book: str = None, validate: bool = True):
    """Update the songs.json file with the new notation.

    If ``book`` is provided, the song is also assigned to that book/hymnal.

    When ``validate`` is True and song_validator is available, the updated song
    is validated before writing: errors abort the write (return False) so the
    operator can fix the source; warnings are printed but do not block.
    """
    print(f"Updating songs.json for song {song_number}...")

    with open(songs_json_path, 'r', encoding='utf-8') as f:
        songs = json.load(f)

    # Find the song
    song_found = False
    updated_song = None
    for song in songs:
        if song.get('number') == song_number:
            song['notation'] = notation
            song['originalKey'] = notation['originalKey']
            if book:
                song['book'] = book
            song_found = True
            updated_song = song
            title = song.get('title', 'Unknown')
            print(f"Updated song {song_number}: {title.encode('ascii', 'replace').decode()}")
            if book:
                print(f"  Book: {book.encode('ascii', 'replace').decode()}")
            break

    if not song_found:
        print(f"Warning: Song {song_number} not found in songs.json")
        return False

    # Validate before writing.
    if validate and sv is not None and updated_song is not None:
        issues = sv.validate_song(updated_song)
        errors = [i for i in issues if i.severity == sv.ERROR]
        warnings = [i for i in issues if i.severity == sv.WARNING]
        for w in warnings:
            print(f"  [warning] {w.field}: {w.message}".encode('ascii', 'replace').decode())
        if errors:
            print(f"Validation FAILED for song {song_number}; not writing songs.json:")
            for e in errors:
                print(f"  [error] {e.field}: {e.message}".encode('ascii', 'replace').decode())
            print("Fix the source (or re-run with --no-validate to override).")
            return False

    with open(songs_json_path, 'w', encoding='utf-8') as f:
        json.dump(songs, f, ensure_ascii=False, indent=2)

    return True


def main():
    parser = argparse.ArgumentParser(
        description='Convert sheet music image to JSON notation'
    )
    parser.add_argument('image', nargs='?', help='Path to the sheet music image')
    parser.add_argument('--song', '-s', type=int, required=True,
                        help='Song number to update in songs.json')
    parser.add_argument('--output', '-o', help='Output JSON file (optional)')
    parser.add_argument('--measures-per-line', '-m', type=int, default=1,
                        help='Measures per line for line breaks (default: 1 for Audiveris)')
    parser.add_argument('--songs-json', default=None,
                        help='Path to songs.json (auto-detected if not specified)')
    parser.add_argument('--no-update', action='store_true',
                        help="Don't update songs.json, only output notation")
    parser.add_argument('--engine', '-e', choices=['audiveris', 'oemer'], default='audiveris',
                        help='OMR engine to use (default: audiveris)')
    parser.add_argument('--from-xml', '-x', metavar='XML_PATH',
                        help='Convert directly from MusicXML file (skip OMR)')
    parser.add_argument('--ocr-lyrics', action='store_true',
                        help='Use OCR to extract lyrics from the image')
    parser.add_argument('--num-systems', type=int, default=6,
                        help='Number of systems/lines in the image for OCR (default: 6)')
    parser.add_argument('--book', '-b', default=None,
                        help='Book/hymnal name to assign to the song (e.g. "Zsoltárok", "Dicséretek")')
    parser.add_argument('--rebar', action='store_true',
                        help='Split measures holding more beats than the '
                             'time signature allows. Audiveris misses '
                             'barlines on a photographed page - on real '
                             'output it can return one measure per SYSTEM '
                             '- and re-barring turns that into bars that '
                             'add up. Off by default: a score whose '
                             'barlines WERE detected must not be '
                             'second-guessed.')
    parser.add_argument('--no-validate', action='store_true',
                        help='Skip song validation before writing songs.json (not recommended)')

    args = parser.parse_args()

    # Validate input
    if not args.from_xml and not args.image:
        parser.error("Either image path or --from-xml is required")

    if args.from_xml:
        # Direct XML conversion
        xml_path = args.from_xml

        # Handle .mxl (compressed) files
        if xml_path.endswith('.mxl'):
            with tempfile.TemporaryDirectory() as temp_dir:
                xml_path = extract_xml_from_mxl(args.from_xml, temp_dir)
                notation = parse_musicxml(xml_path)
        else:
            if not os.path.exists(xml_path):
                print(f"Error: XML file not found: {xml_path}")
                sys.exit(1)
            notation = parse_musicxml(xml_path)

        # Add line breaks
        if args.rebar:
            notation = rebar_measures(notation)
        notation = add_line_breaks(notation, args.measures_per_line)

        # OCR lyrics if requested and image is available
        if args.ocr_lyrics and args.image and os.path.exists(args.image):
            lyrics = ocr_lyrics_from_image(args.image, args.num_systems)
            notation = distribute_lyrics_to_notes(notation, lyrics)

    else:
        # Validate image exists
        if not os.path.exists(args.image):
            print(f"Error: Image not found: {args.image}")
            sys.exit(1)

        # Create temp directory for OMR output
        with tempfile.TemporaryDirectory() as temp_dir:
            try:
                # Run OMR
                if args.engine == 'audiveris':
                    mxl_path = run_audiveris(args.image, temp_dir)
                else:
                    mxl_path = run_oemer(args.image, temp_dir)

                # Parse MusicXML
                notation = parse_musicxml(mxl_path)

                # Add line breaks
                if args.rebar:
                    notation = rebar_measures(notation)
                notation = add_line_breaks(notation, args.measures_per_line)

                # OCR lyrics if requested
                if args.ocr_lyrics:
                    lyrics = ocr_lyrics_from_image(args.image, args.num_systems)
                    notation = distribute_lyrics_to_notes(notation, lyrics)

            except Exception as e:
                print(f"Error: {e}")
                import traceback
                traceback.print_exc()
                sys.exit(1)

    # Convert to app format
    app_notation = convert_to_app_format(notation)

    # Output JSON if requested
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            json.dump(app_notation, f, ensure_ascii=False, indent=2)
        print(f"Notation saved to: {args.output}")

    # Update songs.json
    if not args.no_update:
        songs_json_path = args.songs_json
        if not songs_json_path:
            # Try to find songs.json
            script_dir = Path(__file__).parent
            candidates = [
                script_dir.parent / 'songbook_app' / 'assets' / 'data' / 'songs.json',
                script_dir / '..' / 'songbook_app' / 'assets' / 'data' / 'songs.json',
                Path('songbook_app/assets/data/songs.json'),
            ]
            for candidate in candidates:
                if candidate.exists():
                    songs_json_path = str(candidate.resolve())
                    break

        if songs_json_path and os.path.exists(songs_json_path):
            update_songs_json(songs_json_path, args.song, app_notation, book=args.book,
                              validate=not args.no_validate)
        else:
            print("Warning: songs.json not found. Use --songs-json to specify path.")
            print("Notation JSON:")
            # Use ensure_ascii=True for Windows console compatibility
            print(json.dumps(app_notation, ensure_ascii=True, indent=2))
    else:
        print("Notation JSON:")
        # Use ensure_ascii=True for Windows console compatibility
        print(json.dumps(app_notation, ensure_ascii=True, indent=2))

    print("\nConversion complete!")
    print(f"Key: {app_notation['originalKey']}")
    print(f"Time: {app_notation['timeSignature']}")
    print(f"Measures: {len(notation['measures'])}")


if __name__ == '__main__':
    main()
