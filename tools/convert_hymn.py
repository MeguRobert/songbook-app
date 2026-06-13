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


def parse_musicxml(mxl_path: str) -> dict:
    """Parse MusicXML file and extract notation data."""
    print(f"Parsing MusicXML: {mxl_path}")

    tree = ET.parse(mxl_path)
    root = tree.getroot()

    # Handle namespace if present
    ns = {}
    if root.tag.startswith('{'):
        ns_end = root.tag.find('}')
        ns['m'] = root.tag[1:ns_end]

    def find(element, path):
        if ns:
            # Convert path to namespaced version
            parts = path.split('/')
            ns_path = '/'.join(f"m:{p}" if p and not p.startswith('@') else p for p in parts)
            return element.find(ns_path, ns)
        return element.find(path)

    def findall(element, path):
        if ns:
            parts = path.split('/')
            ns_path = '/'.join(f"m:{p}" if p and not p.startswith('@') else p for p in parts)
            return element.findall(ns_path, ns)
        return element.findall(path)

    # Extract key signature
    key_fifths = 0
    key_elem = find(root, './/key/fifths')
    if key_elem is not None:
        key_fifths = int(key_elem.text)

    key_map = {
        0: 'C', 1: 'G', 2: 'D', 3: 'A', 4: 'E', 5: 'B', 6: 'F#', 7: 'C#',
        -1: 'F', -2: 'Bb', -3: 'Eb', -4: 'Ab', -5: 'Db', -6: 'Gb', -7: 'Cb'
    }
    original_key = key_map.get(key_fifths, 'C')

    # Extract time signature
    time_beats = '4'
    time_type = '4'
    beats_elem = find(root, './/time/beats')
    beat_type_elem = find(root, './/time/beat-type')
    if beats_elem is not None:
        time_beats = beats_elem.text
    if beat_type_elem is not None:
        time_type = beat_type_elem.text
    time_signature = f"{time_beats}/{time_type}"

    # Extract measures and notes
    measures = []
    parts = findall(root, './/part')

    if not parts:
        parts = [root]  # Try root if no parts found

    for part in parts:
        for measure in findall(part, './/measure') or findall(part, 'measure'):
            beats = []

            for note in findall(measure, './/note') or findall(measure, 'note'):
                # Check if it's a rest
                rest_elem = find(note, 'rest')
                is_rest = rest_elem is not None

                # Get pitch
                pitch = 'R'
                if not is_rest:
                    pitch_elem = find(note, 'pitch')
                    if pitch_elem is not None:
                        step = find(pitch_elem, 'step')
                        octave = find(pitch_elem, 'octave')
                        alter = find(pitch_elem, 'alter')

                        if step is not None and octave is not None:
                            note_name = step.text
                            if alter is not None:
                                alter_val = int(alter.text)
                                if alter_val == 1:
                                    note_name += '#'
                                elif alter_val == -1:
                                    note_name += 'b'
                            pitch = f"{note_name}{octave.text}"

                # Get duration type
                type_elem = find(note, 'type')
                duration_map = {
                    'whole': 'whole',
                    'half': 'half',
                    'quarter': 'quarter',
                    'eighth': 'eighth',
                    '16th': 'sixteenth',
                    'sixteenth': 'sixteenth'
                }
                duration = 'quarter'
                if type_elem is not None:
                    duration = duration_map.get(type_elem.text, 'quarter')

                # Check for dotted
                dot_elem = find(note, 'dot')
                dotted = dot_elem is not None

                # Get lyric (from MusicXML if present)
                syllable = None
                lyric_elem = find(note, 'lyric')
                if lyric_elem is not None:
                    text_elem = find(lyric_elem, 'text')
                    syllabic_elem = find(lyric_elem, 'syllabic')
                    if text_elem is not None:
                        syllable = text_elem.text or ''
                        # Add hyphen if syllable continues
                        if syllabic_elem is not None and syllabic_elem.text in ('begin', 'middle'):
                            syllable += '-'

                beat = {
                    'pitch': pitch,
                    'duration': duration
                }
                if syllable:
                    beat['syllable'] = syllable
                if dotted:
                    beat['dotted'] = True

                beats.append(beat)

            if beats:
                measures.append({'beats': beats})

    return {
        'originalKey': original_key,
        'timeSignature': time_signature,
        'showTimeSignature': False,
        'measures': measures
    }


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


def update_songs_json(songs_json_path: str, song_number: int, notation: dict, book: str = None):
    """Update the songs.json file with the new notation.

    If ``book`` is provided, the song is also assigned to that book/hymnal.
    """
    print(f"Updating songs.json for song {song_number}...")

    with open(songs_json_path, 'r', encoding='utf-8') as f:
        songs = json.load(f)

    # Find the song
    song_found = False
    for song in songs:
        if song.get('number') == song_number:
            song['notation'] = notation
            song['originalKey'] = notation['originalKey']
            if book:
                song['book'] = book
            song_found = True
            title = song.get('title', 'Unknown')
            print(f"Updated song {song_number}: {title.encode('ascii', 'replace').decode()}")
            if book:
                print(f"  Book: {book.encode('ascii', 'replace').decode()}")
            break

    if not song_found:
        print(f"Warning: Song {song_number} not found in songs.json")
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
            update_songs_json(songs_json_path, args.song, app_notation, book=args.book)
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
