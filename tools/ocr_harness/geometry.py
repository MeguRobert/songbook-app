"""Where things are on the page, for writing a gold answer by hand.

Separate from engines.py because it deliberately ignores what was read and
keeps only where it was. A recogniser that returns `cgoropaBen` for
`borombeb` still puts that box in the right place, and a chord's position is
the one thing a human cannot reconstruct from a photograph without measuring.
"""
from __future__ import annotations

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import photo_import_worker as worker  # noqa: E402


def word_under(x: float, below) -> tuple[str, int, str]:
    """Which box in [below] the chord starting at [x] belongs to.

    Returns (text, index, how). `how` is `in` when the chord sits inside the
    word's span and `near` when it falls in the gap between two - a typesetter
    sets a chord a little left or right of the letter to keep the glyphs apart,
    so the gap case is ordinary rather than an error.
    """
    for index, box in enumerate(below):
        if box.x0 <= x <= box.x1:
            return box.text, index, "in"
    if not below:
        return "(nothing below)", -1, "none"
    nearest = min(range(len(below)),
                  key=lambda i: min(abs(below[i].x0 - x), abs(below[i].x1 - x)))
    return below[nearest].text, nearest, "near"


def describe(path: pathlib.Path) -> list[str]:
    """The page's rows, their spans, and where each chord lands."""
    content, _ = worker.extract_with_easyocr(path.read_bytes())
    del content

    # Read again from the boxes rather than the text, because the text has
    # already been laid out onto a character grid and that is the step being
    # worked around.
    import io

    import numpy
    from PIL import Image, ImageOps

    image = ImageOps.exif_transpose(Image.open(io.BytesIO(path.read_bytes())))
    if image.mode != "RGB":
        image = image.convert("RGB")
    pixels = numpy.array(image)
    if worker.has_show_through(pixels):
        pixels = worker.suppress_show_through(pixels)
    boxes = worker.boxes_from_easyocr(worker.easyocr_reader().readtext(
        pixels, paragraph=False, text_threshold=worker._TEXT_THRESHOLD,
        low_text=worker._LOW_TEXT))
    boxes = worker.deskew(boxes, worker.estimate_skew(boxes))

    out: list[str] = []
    for column_index, column in enumerate(worker.split_columns(boxes)):
        rows = [worker.as_chord_row(row) for row in worker.group_rows(column)]
        rows = [row for row in rows
                if not worker._is_noise_row([b.text for b in row])]
        out.append(f"-- column {column_index}: {len(rows)} rows, "
                   f"x {round(min(b.x0 for b in column))}"
                   f"-{round(max(b.x1 for b in column))}")
        for index, row in enumerate(rows):
            texts = [b.text for b in row]
            chords, _ = worker.chord_row_reason(texts)
            kind = "CHORD" if chords else "lyric"
            out.append(f"  [{index:>2}] {kind} y{round(row[0].y0):>5} "
                       + "  ".join(f"{b.text!r}@{round(b.x0)}-{round(b.x1)}"
                                   for b in row))
            if not chords:
                continue
            below = rows[index + 1] if index + 1 < len(rows) else []
            if below and worker.chord_row_reason([b.text for b in below])[0]:
                below = []
            # Split into words for measurement only. A lyric line usually comes
            # back as ONE region, so without this every chord maps to word 0 and
            # the output says nothing. The sub-spans are estimated on the
            # region's own average character width - the same estimate the
            # layout makes, so this reports what the reading will actually do.
            words = worker.split_regions(below) if below else []
            for box in row:
                text, position, how = word_under(box.x0, words)
                out.append(f"        {box.text!r:>12} -> word {position:>2} "
                           f"{text!r} ({how})")
    return out
