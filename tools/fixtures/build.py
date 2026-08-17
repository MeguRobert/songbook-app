#!/usr/bin/env python3
"""Build every test page `--easyocr` is measured against.

These lived in a session temp directory and were deleted out from under the
work, taking the whole regression corpus with them. They are generators rather
than checked-in images: deterministic, a few KB of source, and no binaries in
git.

    python tools/fixtures/build.py          # writes tools/fixtures/out/
    python tools/fixtures/score.py          # measures the bridge against them

The one page that cannot be generated is a real photograph. Those arrive through
`--save-dir` and live in tools/photo_debug/.
"""
import pathlib
import sys
import zipfile

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

try:
    import numpy
except ImportError:
    sys.exit('needs numpy: python -m pip install numpy')

OUT = pathlib.Path(__file__).parent / 'out'

# The reference page. Monospaced body text, so a column in this string IS a
# column on the page and the correct chord placement is known exactly.
SHEET = """\
Csak Egy Az Út

D              A            Hm         G
Csak egy az út, mely hozzád visz el,
D              A                 G
és minden reggel újra kezdem el.

G        D           A         Hm
Nem kell már félnem, mert velem vagy,
G           D            A
a szíved mindig utat mutat.
"""

# Two songs side by side, the way a hymnal sets them.
LEFT = """\
148 Az Úr irgalma végtelen

D            A          G
Az Úr irgalma végtelen,
D            A       G
minden reggel új nekem.
"""
RIGHT = """\
149 Mondd, ki a dzsungel

em        A        -7      D
Mondd, ki az egész világ,
em        A        -7      D
s ki a Királyom nekem?
"""

TITLE_FONT = 'C:/Windows/Fonts/arial.ttf'
BOLD_FONT = 'C:/Windows/Fonts/arialbd.ttf'
BODY_FONT = 'C:/Windows/Fonts/consola.ttf'
PAPER = (246, 244, 240)


def chordsheet(scale=3, width=2400):
    """The clean reference render."""
    lines = SHEET.rstrip('\n').split('\n')
    title = ImageFont.truetype(TITLE_FONT, 34 * scale)
    body = ImageFont.truetype(BODY_FONT, 20 * scale)
    image = Image.new('RGB', (width, 60 + 34 * scale + len(lines) * 30 * scale),
                      'white')
    draw = ImageDraw.Draw(image)
    y = 40
    draw.text((60, y), lines[0], font=title, fill='black')
    y += 34 * scale + 30
    for line in lines[1:]:
        if line.strip():
            draw.text((60, y), line.rstrip(), font=body, fill='black')
        y += 30 * scale
    return image


def twocolumn(scale=3, width=2400):
    """Two songs side by side, with a clear gutter."""
    title = ImageFont.truetype(BOLD_FONT, 22 * scale)
    body = ImageFont.truetype(BODY_FONT, 15 * scale)
    image = Image.new('RGB', (width, 1000), 'white')
    draw = ImageDraw.Draw(image)
    for column_x, block in ((70, LEFT), (1290, RIGHT)):
        y = 60
        for index, line in enumerate(block.rstrip('\n').split('\n')):
            if index == 0:
                draw.text((column_x, y), line, font=title, fill='black')
                y += 30 * scale
            else:
                if line.strip():
                    draw.text((column_x, y), line.rstrip(), font=body,
                              fill='black')
                y += 22 * scale
    return image


def _padded(image):
    """The page on a table rather than filling the frame."""
    pad = int(image.width * 0.06)
    canvas = Image.new('RGB', (image.width + pad * 2, image.height + pad * 2),
                       PAPER)
    canvas.paste(image, (pad, pad))
    return canvas


def _keystone(image, strength):
    """Camera not square-on to the page."""
    w, h = image.size
    dx, dy = int(w * strength), int(h * strength * 0.4)
    # Image.QUAD wants upper-left, LOWER-left, lower-right, upper-right — not
    # clockwise. Clockwise turns the page upside down.
    source = [(dx, dy), (0, h - dy), (w, h), (w - dx // 2, 0)]
    return image.transform((w, h), Image.QUAD,
                           [c for point in source for c in point],
                           resample=Image.BICUBIC, fillcolor='white')


def _lighting(image, strength):
    """A brightness ramp across the page, plus a corner shadow."""
    w, h = image.size
    across = numpy.linspace(1.0 + strength, 1.0 - strength, w)
    down = numpy.linspace(1.0 + strength * 0.4, 1.0 - strength * 0.6, h)
    ramp = numpy.outer(down, across)[:, :, None]
    lit = numpy.clip(numpy.asarray(image, dtype=numpy.float32) * ramp, 0, 255)
    return Image.fromarray(lit.astype(numpy.uint8))


def _curl(image, drop, squeeze, strips=60):
    """Bend the page towards its right edge, the way an open book does.

    A vertical displacement growing quadratically towards the far edge, plus the
    horizontal foreshortening that goes with it — text near the spine both falls
    and crowds together.
    """
    w, h = image.size
    mesh = []
    for i in range(strips):
        x0, x1 = w * i / strips, w * (i + 1) / strips
        source_x = lambda x: min(w, x + squeeze * w * (x / w) ** 2)  # noqa: E731
        fall = lambda x: drop * h * (x / w) ** 2  # noqa: E731
        sx0, sx1 = source_x(x0), source_x(x1)
        mesh.append(((int(x0), 0, int(x1), h),
                     (sx0, -fall(x0), sx0, h - fall(x0),
                      sx1, h - fall(x1), sx1, -fall(x1))))
    return image.transform((w, h), Image.MESH, mesh,
                           resample=Image.BICUBIC, fillcolor=PAPER)


def photograph(source, *, angle=0.0, warp=0.0, drop=0.0, squeeze=0.0,
               light=0.0, blur=0.0, width=3000, quality=85):
    """[source] as a phone would deliver it."""
    canvas = _padded(source)
    if drop or squeeze:
        canvas = _curl(canvas, drop, squeeze)
    if warp:
        canvas = _keystone(canvas, warp)
    if angle:
        canvas = canvas.rotate(angle, expand=True, fillcolor=PAPER,
                               resample=Image.BICUBIC)
    if light:
        canvas = _lighting(canvas, light)
        canvas = ImageEnhance.Contrast(canvas).enhance(0.92)
    if blur:
        canvas = canvas.filter(ImageFilter.GaussianBlur(blur))
    scale = width / canvas.width
    return canvas.resize((width, int(canvas.height * scale)), Image.LANCZOS), \
        quality


def hymn_scan():
    """The binarised hymn page, whose lyrics songs.json song 90 pins exactly."""
    for root in ('C:/Users/rober/source/repos/songbook-app',
                 str(pathlib.Path(__file__).resolve().parents[2])):
        omr = pathlib.Path(root) / 'tools/audiveris_output/zsolt-090.width-800.omr'
        if omr.exists():
            with zipfile.ZipFile(omr) as archive:
                return Image.open(__import__('io').BytesIO(
                    archive.read('sheet#1/BINARY.png'))).convert('RGB')
    return None


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = chordsheet()

    written = []

    def save(name, image, quality=None):
        path = OUT / name
        image.save(path, **({'quality': quality} if quality else {}))
        written.append((name, image.size, path.stat().st_size // 1024))

    save('chordsheet.png', sheet)
    save('twocol.png', twocolumn())

    # Phone resolution: EasyOCR caps detection at 2560, so this checks that a
    # bigger upload costs nothing rather than that it reads better.
    big = sheet.resize((4032, int(sheet.height * 4032 / sheet.width)),
                       Image.LANCZOS)
    save('phone-res.jpg', big, 88)

    image, quality = photograph(sheet, angle=2.0, light=0.10, blur=0.6,
                                quality=85)
    save('photo-mild.jpg', image, quality)
    image, quality = photograph(sheet, angle=6.5, warp=0.035, light=0.22,
                                blur=1.1, quality=72)
    save('photo-hard.jpg', image, quality)

    for name, drop, squeeze, angle in (('curl-slight', 0.05, 0.04, 0.0),
                                       ('curl-real', 0.11, 0.09, 0.0),
                                       ('curl-tilted', 0.11, 0.09, 4.0),
                                       ('curl-extreme', 0.36, 0.28, 0.0)):
        image, quality = photograph(sheet, drop=drop, squeeze=squeeze,
                                    angle=angle, blur=0.8, quality=82)
        save(f'{name}.jpg', image, quality)

    hymn = hymn_scan()
    if hymn is not None:
        save('hymn-scan.png', hymn)
    else:
        print('  (hymn scan skipped: zsolt-090.width-800.omr not found)')

    for name, size, kilobytes in written:
        print(f'  {name:<18} {size[0]}x{size[1]:<6} {kilobytes} KB')
    print(f'{len(written)} pages in {OUT}')


if __name__ == '__main__':
    main()
