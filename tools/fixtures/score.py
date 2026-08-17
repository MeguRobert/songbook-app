#!/usr/bin/env python3
"""Measure the OCR bridge against the generated pages, and any real photos.

    python tools/fixtures/build.py
    python tools/fixtures/score.py                 # every page
    python tools/fixtures/score.py photo-hard.jpg  # just these

Scores what actually matters: whether each chord landed over the syllable it sits
above on the page, and whether the lyrics came back exactly. Anything in
tools/photo_debug/ is reported too, but only descriptively — a real photograph
has no machine-checkable answer, so it prints the reading for a human to judge.
"""
import io
import pathlib
import re
import sys
import time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import photo_import_worker as worker  # noqa: E402

HERE = pathlib.Path(__file__).parent
OUT = HERE / 'out'
PHOTOS = HERE.parent / 'photo_debug'

# The source of `chordsheet.png`, as rendered. Monospaced, so a column here is a
# column on the page: this is the ground truth for chord placement.
REFERENCE = '''D              A            Hm         G
Csak egy az út, mely hozzád visz el,
D              A                 G
és minden reggel újra kezdem el.
G        D           A         Hm
Nem kell már félnem, mert velem vagy,
G           D            A
a szíved mindig utat mutat.'''.split('\n')

# Pages built from the reference, so the scorer knows their answer.
FROM_REFERENCE = ('chordsheet.png', 'phone-res.jpg', 'photo-mild.jpg',
                  'photo-hard.jpg', 'curl-slight.jpg', 'curl-real.jpg',
                  'curl-tilted.jpg', 'curl-extreme.jpg')


def word_under(chord_line, lyric_line):
    """Which lyric word each chord sits over."""
    words = list(re.finditer(r'\S+', lyric_line))
    return [(m.group(0), next((w.group(0) for w in words
                               if w.start() <= m.start() <= w.end()),
                              '(past end)'))
            for m in re.finditer(r'\S+', chord_line)]


def score_reference(content):
    body = [line for line in content.split('\n')
            if line.strip() and not line.startswith('{')]
    if len(body) < 8:
        return None, None, f'structure broken: {len(body)} lines, expected 8'
    placed = total = 0
    for i in range(0, 8, 2):
        for want, got in zip(word_under(REFERENCE[i], REFERENCE[i + 1]),
                             word_under(body[i], body[i + 1])):
            total += 1
            placed += (want == got)
    exact = all(' '.join(body[i + 1].split()) ==
                ' '.join(REFERENCE[i + 1].split()) for i in range(0, 8, 2))
    return placed, total, ('lyrics exact' if exact else 'lyrics differ')


def main():
    wanted = set(sys.argv[1:])
    pages = [p for p in sorted(OUT.glob('*')) if p.suffix in ('.png', '.jpg')]
    photos = sorted(PHOTOS.glob('*.jpg')) + sorted(PHOTOS.glob('*.png'))
    if wanted:
        pages = [p for p in pages if p.name in wanted]
        photos = [p for p in photos if p.name in wanted]
    if not pages and not photos:
        sys.exit('nothing to score — run tools/fixtures/build.py first')

    worker.easyocr_reader()
    for path in pages:
        started = time.time()
        content, warnings = worker.extract_with_easyocr(path.read_bytes())
        elapsed = time.time() - started
        if path.name in FROM_REFERENCE:
            placed, total, note = score_reference(content)
            summary = (f'{placed}/{total} chords placed, {note}'
                       if placed is not None else note)
        else:
            rows = sum(1 for line in content.split('\n')
                       if line.split() and worker.is_chord_row(line.split()))
            summary = f'{rows} chord rows, {len(content.splitlines())} lines'
        print(f'{path.name:<20} {elapsed:5.1f}s  {summary}')
        for warning in warnings:
            print(f'{"":22}note: {warning}')

    for path in photos:
        content, warnings = worker.extract_with_easyocr(path.read_bytes())
        rows = sum(1 for line in content.split('\n')
                   if line.split() and worker.is_chord_row(line.split()))
        print(f'\n=== {path.name} (real photograph, {rows} chord rows) ===')
        print(content)
        for warning in warnings:
            print(f'  note: {warning}')


if __name__ == '__main__':
    main()
