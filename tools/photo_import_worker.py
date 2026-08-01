#!/usr/bin/env python3
"""Local stand-in for the photo-import backend.

Implements the contract the app already speaks, so the whole import flow can be
exercised on this machine before committing to any hosting:

    POST /extract   multipart/form-data, image under `image`
    -> 200 {"kind": "chordpro" | "musicxml", "content": "...", "warnings": [...]}

Run it, then paste the URL into Settings -> Photo import.

    python tools/photo_import_worker.py                # stub, no key needed
    python tools/photo_import_worker.py --easyocr      # real, offline, no key
    ANTHROPIC_API_KEY=sk-... python tools/photo_import_worker.py --live

Three modes, in increasing order of what they cost you:

  stub      a fixed song. Makes the whole app flow testable with no key, no
            network and no models — and names itself, so it can never be
            mistaken for a successful read.
  easyocr   EasyOCR on this machine. Free, offline, no key, no account. On a
            2400px Hungarian chord sheet it recovered all 14 chords over the
            right syllable, and 97.5% of the characters of a ground-truth hymn
            scan. Costs no more at phone resolution. See the OCR section below
            for why the detector thresholds are not the defaults.
  live      a vision model over the network. Needs a key, reads a page far
            better than OCR does, and costs a fraction of a cent per photo.

This is deliberately the same shape as the Cloudflare Worker it stands in for —
read the multipart body, work out what the page says, answer with the JSON
above. Porting it means replacing the http.server plumbing, not the logic.
(`--easyocr` is the exception: torch does not fit in a Worker. That mode is for
running here.)

Why the stdlib carries the default: this has to run on a machine that has
Python and nothing else installed, and adding a dependency to try an experiment
is how experiments stop getting tried. EasyOCR is imported inside the function
that needs it, so `--stub` still runs on a bare interpreter.
"""

import argparse
import base64
import collections
import json
import math
import os
import pathlib
import re
import statistics
import sys
from email.parser import BytesParser
from email.policy import default as default_policy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Returned by the stub. Deliberately contains the two things most likely to be
# got wrong downstream: accented Hungarian, and a line whose words start with
# note letters ("Csak Egy Az" must survive as lyrics, not become C, E and A).
def stub_chordpro(filename: str, size: int) -> str:
    """A response that cannot be mistaken for a real transcription.

    The first stub was a plausible-looking Hungarian hymn, which read as a
    successful extraction — the only hint it was fake sat in a warning below
    the fold. A stub indistinguishable from success is worse than no stub: it
    teaches you the wrong thing. This one names itself in the title, which is
    the first thing the app shows, and echoes the file it was given so it is
    obvious the image arrived and was ignored on purpose.

    It still exercises what matters: accented Hungarian, and a line whose words
    start with note letters ("Csak Egy Az" must stay lyrics, not become C, E
    and A).
    """
    return f"""{{title: STUB — no model, {filename}}}
{{key: G}}
[G]This is not your [C]photo
[G]The worker is in stub [D]mode

Csak Egy Az — {size} bytes arrived and were ignored
[Em]Restart it with [C]--live to read it for [G]real
"""

MODEL_PROMPT = (
    "This is a photograph of a song — lyrics with guitar chords, or a hymn "
    "page. Transcribe it as ChordPro. Put each chord in square brackets "
    "immediately before the syllable it falls on. Separate verses with a blank "
    "line. Include {title: ...} if a title is visible and {key: ...} if you can "
    "tell the key. Output only the ChordPro, no commentary, no code fences. "
    "Preserve the original language and its accents exactly."
)


# Checked when the env var is absent. A file rather than a flag so the key is
# never typed into a command line, never lands in shell history, and never has
# to be pasted into a conversation. Gitignored.
KEY_FILE = pathlib.Path(__file__).with_name(".anthropic_key")


def read_api_key() -> str:
    """The key from the environment, else from [KEY_FILE], else empty."""
    from_env = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if from_env:
        return from_env
    if KEY_FILE.exists():
        # Tolerates a trailing newline and a stray `ANTHROPIC_API_KEY=` prefix,
        # since both are what a copy-paste tends to produce.
        raw = KEY_FILE.read_text(encoding="utf-8").strip()
        return raw.split("=", 1)[1].strip() if raw.startswith("ANTHROPIC_API_KEY=") else raw
    return ""


def extract_with_model(image_bytes: bytes, media_type: str) -> tuple[str, list]:
    """Ask a vision model for ChordPro. Returns (content, warnings)."""
    import urllib.request

    api_key = read_api_key()
    if not api_key:
        raise RuntimeError(
            "No API key. Put one in tools/.anthropic_key or set "
            "ANTHROPIC_API_KEY in the environment.")

    payload = {
        "model": "claude-sonnet-5",
        "max_tokens": 4096,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image", "source": {
                    "type": "base64",
                    "media_type": media_type,
                    "data": base64.b64encode(image_bytes).decode("ascii"),
                }},
                {"type": "text", "text": MODEL_PROMPT},
            ],
        }],
    }
    request = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "content-type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        body = json.load(response)

    text = "".join(
        block.get("text", "") for block in body.get("content", [])
    ).strip()
    # Models wrap output in fences despite being asked not to; the app would
    # otherwise treat ``` as a lyric line.
    text = re.sub(r"^```[a-zA-Z]*\n|\n```$", "", text).strip()

    warnings = []
    if body.get("stop_reason") == "max_tokens":
        warnings.append("The page was long; the end may be missing.")
    return text, warnings


# ---------------------------------------------------------------------------
# OCR -> ChordPro
#
# The free, offline, key-free path. EasyOCR returns each token with a bounding
# box; `ChordPosition.position` on the app side is a character column into the
# lyric. Everything below is the bridge between those two, and it is ordinary
# arithmetic — no model, no network, and (apart from the reader itself) no
# dependency, so it is unit-tested in tools/test_photo_import_worker.py without
# EasyOCR installed at all.
#
# The classification rules are a deliberate port of ChordSheetParser's, not an
# approximation of them. The app re-parses whatever we emit, so if the two
# disagree about what a chord is, we hand it text it reads back differently
# than we wrote it.
# ---------------------------------------------------------------------------

Box = collections.namedtuple("Box", "text x0 y0 x1 y1")

# Ported verbatim from ChordSheetParser (chord_sheet_parser.dart). The quality
# whitelist is the whole point: with a `.*` quality every Hungarian word
# starting with A-H "matches", and `Csak Egy Az` reads as three chords and no
# words. See that file's comment for the full argument.
#
# `H` is B natural in Hungarian notation. The worker emits it as written and
# the app renames it to `B` on the way into storage, so a photographed page
# stays a faithful transcription and one side owns the spelling.
_CHORD_TOKEN = re.compile(
    r"^[A-GH][#b]?(?:maj|min|m|dim|aug|sus|add|\+|°|[#b]?\d+)*"
    r"(?:/[A-GH][#b]?)?$")
_BARE_ROOT = re.compile(r"^[A-GH]$")
_SEPARATOR = re.compile(r"^(?:[-–—]+|\|+|:\||\|:|\|\||[xX]\d+|\d+[xX])$")
_PARENTHESISED = re.compile(r"^\((.+)\)$")

# Two boxes are on the same line when their centres are within this fraction of
# a glyph height. A photographed page is never square-on, so a line's baseline
# wanders by a few pixels; splitting on that would put every word on its own
# line.
_SAME_ROW = 0.6

# A verse break has to clear both bars: taller than one blank line, AND well
# above the page's usual line spacing. The first alone turns a loosely set page
# into one verse per line; the second alone cannot tell two verses from two
# lines when the page has only a couple of gaps to compare.
_BREAK_VS_HEIGHT = 1.0
_BREAK_VS_GAP = 1.6

# How much taller than the body text the first line must be to be a title.
_TITLE_HEIGHT = 1.25

# EasyOCR scores every read. Below this the token is far likelier to be a stave
# line or a slur than a word, and a wrong word costs more than a missing one.
_MIN_CONFIDENCE = 0.2

# CRAFT's defaults are tuned for prose, and they quietly drop a single letter
# sitting alone in white space — which is exactly what a chord is. On a rendered
# 2400px chord sheet the defaults found 9 of 14 chords; every miss was a lone
# `G` or `D`, and all four `A`s and both `Hm`s came through, so the loss lands
# on the sparsest glyphs rather than at random.
#
# Both values have to move: text_threshold alone got 11 of 14, low_text alone
# still 9, together 14. Lowering text_threshold *without* low_text is also
# ~4x slower (113s against 25s), because the high low_text leaves CRAFT growing
# a crowd of marginal regions that each cost a recogniser pass. Lowered
# together the run costs nothing extra.
_TEXT_THRESHOLD = 0.5
_LOW_TEXT = 0.3

# EasyOCR's two commonest Hungarian confusions. Both fire only where a digit
# touches a letter — digits do not occur inside Hungarian words, so that is
# strong evidence of a misread glyph, while a verse number, a fret number or a
# repeat count stands alone and survives. Both are length-preserving, which is
# what lets them run after layout without shifting a single chord column.
#
#   1 -> i   carried over from convert_hymn.ocr_lyrics_from_image, narrowed.
#   6 -> ő   measured here: every error in the ground-truth hymn scan was `ő`,
#            read as `ó`, `ö` or `6`. Only the `6` case is repairable — `ó` and
#            `ö` are ordinary letters, so rewriting them would break `jó` and
#            `föld` to fix `tól`.
_ONE_IN_WORD = re.compile(r"(?<=[^\W\d_])1|1(?=[^\W\d_])", re.UNICODE)
_SIX_IN_WORD = re.compile(r"(?<=[^\W\d_])6|6(?=[^\W\d_])", re.UNICODE)


def _unwrap(token: str) -> str:
    """[token] with any surrounding parentheses removed."""
    match = _PARENTHESISED.match(token)
    return match.group(1) if match else token


def is_chord_token(token: str) -> bool:
    """True when [token] is unambiguously a chord symbol."""
    return bool(_CHORD_TOKEN.match(_unwrap(token)))


def is_chord_row(texts) -> bool:
    """True when [texts] should be read as a row of chords.

    All-or-nothing: one ordinary word makes the whole row lyrics. A row whose
    only chord is a bare root reads as lyrics too — `A` is the Hungarian
    definite article, and losing a chord is recoverable where losing a line of
    words is not.
    """
    chords = []
    for text in texts:
        if _SEPARATOR.match(text):
            continue
        if not is_chord_token(text):
            return False
        chords.append(text)
    if not chords:
        return False
    # Against the token as written, not unwrapped: `(A)`'s brackets are
    # themselves the evidence that it is a chord.
    return not (len(chords) == 1 and _BARE_ROOT.match(chords[0]))


def _german_chords_in(texts):
    """The H-rooted chords among [texts].

    Only ever asked of a row already judged to be chords, so `Hogy` cannot
    reach it — that row is lyrics, and one ordinary word is enough to keep it
    that way.
    """
    return [text for text in texts
            if _unwrap(text).startswith("H") and is_chord_token(text)]


def boxes_from_easyocr(results, min_confidence: float = _MIN_CONFIDENCE):
    """EasyOCR's (quadrilateral, text, confidence) tuples as [Box]es.

    The quadrilateral is not a rectangle on a photographed page, so each one is
    reduced to its bounding box.
    """
    boxes = []
    for quad, text, confidence in results:
        text = text.strip()
        if not text or confidence < min_confidence:
            continue
        xs = [point[0] for point in quad]
        ys = [point[1] for point in quad]
        boxes.append(Box(text=text, x0=min(xs), y0=min(ys),
                         x1=max(xs), y1=max(ys)))
    return boxes


# How far off square a handheld photo is worth correcting, and how finely to
# look. Beyond about this the page is not a photograph of a song, it is a
# photograph of a table with a song on it.
_MAX_SKEW = 12.0
_SKEW_STEP = 0.25

# Below this there is nothing to gain and the rotation only adds rounding.
_SKEW_FLOOR = 0.4

# A skew estimate needs several lines to be evidence rather than noise.
_MIN_BOXES_FOR_SKEW = 6


def estimate_skew(boxes, limit: float = _MAX_SKEW,
                  step: float = _SKEW_STEP) -> float:
    """The angle, in degrees, by which the page appears to be tilted.

    Found by projection profile: for each candidate angle the box centres are
    projected onto the axis across the text and binned, and the angle scoring
    highest on the sum of squared bin counts wins. At the true angle every
    token of a line falls in one bin, so the counts are few and large; at any
    other angle they smear across neighbours and the sum drops.

    EasyOCR cannot answer this directly — it returns axis-aligned rectangles
    however the text is rotated, so the tilt survives only in where the boxes
    sit relative to each other, not in their shape.
    """
    if len(boxes) < _MIN_BOXES_FOR_SKEW:
        return 0.0
    height = statistics.median(b.y1 - b.y0 for b in boxes)
    span = max(1.0, height / 2)
    centres = [((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2) for b in boxes]

    best_angle, best_score = 0.0, -1.0
    for tick in range(-int(limit / step), int(limit / step) + 1):
        angle = tick * step
        radians = math.radians(angle)
        sin, cos = math.sin(radians), math.cos(radians)
        # Two grids half a bin apart: with one, a line landing on a boundary
        # splits in two and scores as though it were smeared.
        low, high = collections.Counter(), collections.Counter()
        for x, y in centres:
            across = y * cos - x * sin
            low[int(across // span)] += 1
            high[int((across + span / 2) // span)] += 1
        score = (sum(n * n for n in low.values())
                 + sum(n * n for n in high.values()))
        if score > best_score:
            best_score, best_angle = score, angle
    return best_angle


def deskew(boxes, angle: float):
    """[boxes] rotated back onto the horizontal by [angle] degrees.

    Only the centres move; each box keeps its width and height. The text was
    read correctly even on a badly tilted page — it is the grouping that
    fails — so this exists to make rows clusterable, not to re-read anything.
    """
    if abs(angle) < _SKEW_FLOOR:
        return boxes
    radians = math.radians(angle)
    sin, cos = math.sin(radians), math.cos(radians)
    straightened = []
    for box in boxes:
        centre_x = (box.x0 + box.x1) / 2
        centre_y = (box.y0 + box.y1) / 2
        moved_x = centre_x * cos + centre_y * sin
        moved_y = centre_y * cos - centre_x * sin
        half_w = (box.x1 - box.x0) / 2
        half_h = (box.y1 - box.y0) / 2
        straightened.append(box._replace(
            x0=moved_x - half_w, y0=moved_y - half_h,
            x1=moved_x + half_w, y1=moved_y + half_h))
    return straightened


def _is_noise_row(texts) -> bool:
    """True when [texts] holds no letter anywhere.

    Photographing a hymnal page puts clefs, time signatures and slurs in front
    of the recogniser, which dutifully returns things like `4=`. Nothing made
    only of digits and punctuation is a lyric, and a chord always carries its
    root letter, so a row with no letter at all is furniture.
    """
    return not any(character.isalpha() for text in texts for character in text)


def group_rows(boxes):
    """[boxes] clustered into lines, top to bottom, each sorted left to right."""
    rows = []
    for box in sorted(boxes, key=lambda b: (b.y0 + b.y1) / 2):
        centre = (box.y0 + box.y1) / 2
        height = box.y1 - box.y0
        if rows:
            current = rows[-1]
            mean_centre = sum((b.y0 + b.y1) / 2 for b in current) / len(current)
            mean_height = sum(b.y1 - b.y0 for b in current) / len(current)
            if abs(centre - mean_centre) <= _SAME_ROW * max(mean_height, height):
                current.append(box)
                continue
        rows.append([box])
    for row in rows:
        row.sort(key=lambda b: b.x0)
    return rows


def _char_width(row) -> float:
    """The row's typical glyph width, in pixels."""
    widths = [(b.x1 - b.x0) / len(b.text) for b in row if b.text]
    return statistics.median(widths) if widths else 1.0


def _lay_out(row):
    """Render [row] as text. Returns (line, anchors).

    Columns are chained off the previous token rather than computed from x
    directly, so the words stay readable however the OCR boxes drift. The
    anchors — (pixel x, character column) at both edges of every token — are
    what a chord row above is then interpolated onto, so the chord follows the
    text wherever the text actually landed.
    """
    char_width = _char_width(row)
    line = ""
    anchors = []
    previous = None
    for box in row:
        if previous is None:
            column = 0
        else:
            gap = max(1, round((box.x0 - previous.x1) / char_width))
            column = len(line) + gap
        line = line.ljust(column) + box.text
        anchors.append((box.x0, column))
        anchors.append((box.x1, column + len(box.text)))
        previous = box
    return line, anchors


def _column_for(x: float, anchors, char_width: float) -> int:
    """The character column at pixel [x], interpolated between [anchors]."""
    if not anchors:
        return max(0, round(x / char_width))
    if x <= anchors[0][0]:
        return max(0, anchors[0][1] - round((anchors[0][0] - x) / char_width))
    if x >= anchors[-1][0]:
        return anchors[-1][1] + round((x - anchors[-1][0]) / char_width)
    for (x_a, col_a), (x_b, col_b) in zip(anchors, anchors[1:]):
        if x_a <= x <= x_b:
            if x_b == x_a:
                return col_a
            return round(col_a + (x - x_a) * (col_b - col_a) / (x_b - x_a))
    return anchors[-1][1]


def _lay_out_chords(row, anchors, char_width: float) -> str:
    """Render chord [row] against the columns of the lyric row beneath it."""
    line = ""
    for box in row:
        column = _column_for(box.x0, anchors, char_width)
        # Two chords over one syllable would otherwise fuse into a nonsense
        # symbol — `G` and `C` becoming `GC`, which the app then stores.
        if line:
            column = max(column, len(line) + 1)
        line = line.ljust(column) + box.text
    return line


def _repair_hungarian(row):
    """[row] with EasyOCR's `1`/`i` confusion undone. Length-preserving."""
    repaired = []
    for index, box in enumerate(row):
        text = _ONE_IN_WORD.sub("i", box.text)
        text = _SIX_IN_WORD.sub("ő", text)
        # A lone `1` between words is the same confusion with the spaces left
        # in. At the start of a row it is a verse number, so it stays.
        if text == "1" and index > 0 and row[index - 1].text[-1].isalpha():
            text = "i"
        repaired.append(box._replace(text=text))
    return repaired


def _verse_breaks(rows):
    """Which of [rows] a blank line should precede."""
    breaks = [False] * len(rows)
    if len(rows) < 3:
        return breaks
    gaps = [min(b.y0 for b in rows[i]) - max(b.y1 for b in rows[i - 1])
            for i in range(1, len(rows))]
    typical_gap = statistics.median(gaps)
    typical_height = statistics.median(
        statistics.median(b.y1 - b.y0 for b in row) for row in rows)
    for index, gap in enumerate(gaps, start=1):
        breaks[index] = (gap > _BREAK_VS_HEIGHT * typical_height
                         and gap > _BREAK_VS_GAP * typical_gap)
    return breaks


def _row_height(row) -> float:
    return statistics.median(b.y1 - b.y0 for b in row)


def chordpro_from_boxes(boxes) -> tuple[str, list]:
    """ChordPro for a page of OCR [boxes]. Returns (content, warnings)."""
    # Straightened before grouping, because grouping is what tilt breaks.
    boxes = deskew(boxes, estimate_skew(boxes))
    # Noise dropped before anything else reads the rows, so verse spacing is
    # measured between real lines rather than across a stray time signature.
    rows = [row for row in group_rows(boxes)
            if not _is_noise_row([b.text for b in row])]
    if not rows:
        return "", ["Nothing legible was found in that photo."]

    lines = []
    # A title is set larger than the body, which is the only signal available
    # here — so a page that merely opens with a long line is left as a lyric.
    if len(rows) > 1 and not is_chord_row([b.text for b in rows[0]]) \
            and _row_height(rows[0]) >= _TITLE_HEIGHT * statistics.median(
                _row_height(row) for row in rows[1:]):
        lines.append("{title: %s}" % " ".join(b.text for b in rows[0]))
        lines.append("")
        rows = rows[1:]

    breaks = _verse_breaks(rows)
    chord_rows = 0
    german = []
    index = 0
    while index < len(rows):
        if breaks[index] and lines and lines[-1] != "":
            lines.append("")
        row = rows[index]
        if not is_chord_row([b.text for b in row]):
            lines.append(_lay_out(_repair_hungarian(row))[0])
            index += 1
            continue

        chord_rows += 1
        german.extend(_german_chords_in([b.text for b in row]))
        below = rows[index + 1] if index + 1 < len(rows) else None
        pairs = (below is not None
                 and not breaks[index + 1]
                 and not is_chord_row([b.text for b in below]))
        if not pairs:
            # An intro or turnaround with nothing underneath. Kept: the app
            # stores chords with positions past the end of an empty lyric.
            lines.append(_lay_out(row)[0])
            index += 1
            continue

        lyrics, anchors = _lay_out(_repair_hungarian(below))
        lines.append(_lay_out_chords(row, anchors, _char_width(below)))
        lines.append(lyrics)
        index += 2

    warnings = []
    if not chord_rows:
        warnings.append(
            "No chords were recognised — the words were imported on their own.")
    if german:
        # Not a failure — the app understands these. Said out loud anyway,
        # because someone who photographed `Hm` and is shown `Bm` should be
        # told why rather than left to wonder whether the import went wrong.
        names = ", ".join(sorted(set(german)))
        warnings.append(
            f"{names} will be stored under the English name (H is B natural). "
            "The app keeps one spelling per pitch so transposing stays exact.")
    return "\n".join(lines), warnings


# Building the reader loads torch and the language models, which takes seconds
# and megabytes. Once per process, not once per photo.
_reader = None


def easyocr_reader():
    """The shared EasyOCR reader, built on first use."""
    global _reader
    if _reader is None:
        import easyocr
        _reader = easyocr.Reader(["hu", "en"], verbose=False)
    return _reader


def extract_with_easyocr(image_bytes: bytes) -> tuple[str, list]:
    """Read a photo with EasyOCR. Returns (content, warnings)."""
    import io

    import numpy
    from PIL import Image, ImageOps

    image = Image.open(io.BytesIO(image_bytes))
    # A phone holds rotation in EXIF rather than in the pixels, so a photo
    # taken in portrait arrives sideways and OCRs to nothing at all.
    image = ImageOps.exif_transpose(image)
    if image.mode != "RGB":
        image = image.convert("RGB")
    results = easyocr_reader().readtext(
        numpy.array(image), paragraph=False,
        text_threshold=_TEXT_THRESHOLD, low_text=_LOW_TEXT)
    return chordpro_from_boxes(boxes_from_easyocr(results))


def parse_multipart(body: bytes, content_type: str):
    """Returns (field_name -> bytes, field_name -> filename)."""
    headers = b"Content-Type: " + content_type.encode("latin-1") + b"\r\n\r\n"
    message = BytesParser(policy=default_policy).parsebytes(headers + body)
    files, names = {}, {}
    if not message.is_multipart():
        return files, names
    for part in message.iter_parts():
        name = part.get_param("name", header="content-disposition")
        if name:
            files[name] = part.get_payload(decode=True)
            names[name] = part.get_filename()
    return files, names


class Handler(BaseHTTPRequestHandler):
    mode = "stub"  # "stub" | "easyocr" | "live"

    def _cors(self):
        # The app is served from a different origin (a local file server, or
        # GitHub Pages), so every response needs these or the browser discards
        # a perfectly good reply. This is the failure that looks like "the
        # server never answered" in the app while the server logs a 200.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers",
                         "Authorization, Content-Type")
        self.send_header("Access-Control-Max-Age", "86400")

    def _json(self, status: int, payload: dict):
        encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self._cors()
        self.end_headers()
        self.wfile.write(encoded)

    def do_OPTIONS(self):  # noqa: N802 - BaseHTTPRequestHandler naming
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):  # noqa: N802
        # A browser pointed at the URL should say something useful rather than
        # 501, since the first thing anyone does is open it.
        self._json(200, {
            "service": "photo-import-worker",
            "mode": self.mode,
            "post": "/extract  multipart/form-data, image under `image`",
        })

    def do_POST(self):  # noqa: N802
        if self.path.rstrip("/") not in ("/extract", ""):
            self._json(404, {"error": "POST /extract"})
            return

        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        content_type = self.headers.get("Content-Type", "")
        files, names = parse_multipart(body, content_type)
        image = files.get("image")

        if not image:
            self._json(400, {"error": "no `image` part in the request"})
            return

        filename = names.get("image") or "photo.jpg"
        sys.stderr.write(
            f"[worker] {filename}: {len(image)} bytes, {self.mode}\n")

        if self.mode == "stub":
            self._json(200, {
                "kind": "chordpro",
                "content": stub_chordpro(filename, len(image)),
                "warnings": [
                    "STUB MODE — your photo was NOT read. Restart the worker "
                    "with --easyocr (free, offline) or --live to transcribe "
                    "for real.",
                ],
            })
            return

        try:
            if self.mode == "easyocr":
                content, warnings = extract_with_easyocr(image)
            else:
                media_type = "image/png" if filename.lower().endswith(".png") \
                    else "image/jpeg"
                content, warnings = extract_with_model(image, media_type)
        except Exception as exc:  # noqa: BLE001 - reported, not swallowed
            sys.stderr.write(f"[worker] {self.mode} read failed: {exc}\n")
            # 502 for the model because the failure is upstream; 500 for
            # EasyOCR because it is this process that broke.
            self._json(502 if self.mode == "live" else 500, {"error": str(exc)})
            return

        if not content.strip():
            # The app turns an empty content into "Nothing could be read from
            # that photo", which is the honest message for a blank page.
            self._json(200, {"kind": "chordpro", "content": "", "warnings": []})
            return

        self._json(200, {
            "kind": "chordpro",
            "content": content,
            "warnings": warnings,
        })

    def log_message(self, fmt, *args):
        sys.stderr.write("[worker] " + (fmt % args) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8790)
    parser.add_argument(
        "--host", default="127.0.0.1",
        help="0.0.0.0 to accept connections from other devices on the LAN. "
             "Note there is no authentication: the Authorization header is "
             "accepted and not checked, so anyone who can reach the port can "
             "spend your API key.")
    how = parser.add_mutually_exclusive_group()
    how.add_argument("--live", action="store_true",
                     help="call a vision model instead of returning the stub")
    how.add_argument("--easyocr", action="store_true",
                     help="read the photo with EasyOCR on this machine — free, "
                          "offline, no API key")
    args = parser.parse_args()

    if args.live and not read_api_key():
        sys.exit(
            "--live needs an API key. Put it in tools/.anthropic_key "
            "(one line, nothing else) or set ANTHROPIC_API_KEY.")

    Handler.mode = "live" if args.live else "easyocr" if args.easyocr else "stub"
    banner = {
        "live": "LIVE (calls a model)",
        "easyocr": "EASYOCR (offline, no key)",
        "stub": "STUB (fixed response)",
    }[Handler.mode]

    if args.easyocr:
        # Loading torch and the language models takes seconds. Doing it now
        # rather than on the first photo keeps that delay out of a request the
        # app is timing at 90 seconds.
        print("loading EasyOCR models (first run downloads them)...")
        easyocr_reader()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"photo-import worker on http://{args.host}:{args.port}/extract  [{banner}]")
    if args.host != "127.0.0.1":
        print("  reachable from the LAN, and UNAUTHENTICATED — see --host help")
    print("Paste that URL into Settings -> Photo import.")
    server.serve_forever()


if __name__ == "__main__":
    main()
