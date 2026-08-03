#!/usr/bin/env python3
"""Tests for the show-through suppression in photo_import_worker.

Kept out of test_photo_import_worker.py on purpose: these need numpy and cv2,
and that file's whole point is that it runs on a bare interpreter with no OCR
stack installed.

A hymnal is printed thin enough to read the reverse page through it, and the
recogniser returns that ghost as words — `n bbod`, `$`, `drnisdl ,Edtt` stuck to
the real lyrics of song 149, and worse, merged into the real regions, which
destroyed a whole chord row. The ghost is always PALER than the print, which is
the entire basis of both the detector and the fix.
"""

import unittest

import photo_import_worker as worker

try:
    import cv2  # noqa: F401
    import numpy
    HAVE_CV2 = True
except ImportError:  # pragma: no cover - depends on the machine
    HAVE_CV2 = False


def strokes(image, top, height, value, width=4, pitch=24):
    """Draw a band of thin vertical bars — ink, rather than a solid block.

    Solid blocks are not text: the background estimate is a median over a wide
    window, so a full-width block reads AS the background and flattens to white.
    Thin strokes on white behave the way print does.
    """
    for x in range(0, image.shape[1], pitch):
        image[top:top + height, x:x + width, :] = value
    return image


def page(dark_band=0, pale_band=0, size=400, pale=200):
    """A white page carrying [dark_band] rows of print and [pale_band] of ghost."""
    image = numpy.full((size, size, 3), 255, dtype=numpy.uint8)
    if dark_band:
        strokes(image, 10, dark_band, 20)
    if pale_band:
        strokes(image, size - 10 - pale_band, pale_band, pale)
    return image


@unittest.skipUnless(HAVE_CV2, 'needs cv2 and numpy')
class DetectShowThroughTests(unittest.TestCase):

    def test_a_page_of_print_alone_is_not_flagged(self):
        self.assertFalse(worker.has_show_through(page(dark_band=120)))

    def test_a_blank_page_is_not_flagged(self):
        self.assertFalse(worker.has_show_through(page()))

    def test_pale_ink_alongside_the_print_is_flagged(self):
        # The signature of a thin page: a second, lighter population of ink.
        self.assertTrue(
            worker.has_show_through(page(dark_band=60, pale_band=120)))

    def test_a_trace_of_pale_is_not_enough(self):
        # Antialiasing along the edge of black print is pale too, and every
        # photograph has some. Only a real population counts.
        self.assertFalse(
            worker.has_show_through(page(dark_band=120, pale_band=4)))


@unittest.skipUnless(HAVE_CV2, 'needs cv2 and numpy')
class SuppressShowThroughTests(unittest.TestCase):

    def test_pale_ink_is_erased_and_print_is_kept(self):
        # Sampled ON a stroke: the bars sit at x = 0, 24, 48 ... so x=25 is ink
        # and x=200 is the white gap between two of them.
        cleaned = worker.suppress_show_through(page(dark_band=120,
                                                   pale_band=120))
        print_ink = int(cleaned[60, 25, 0])   # inside the dark band, on a bar
        ghost_ink = int(cleaned[330, 25, 0])  # inside the pale band, on a bar
        self.assertLess(print_ink, 100, 'print should stay dark')
        self.assertGreater(ghost_ink, 200, 'ghost should be gone')

    def test_the_shape_survives(self):
        source = page(dark_band=90, pale_band=90, size=300)
        self.assertEqual(worker.suppress_show_through(source).shape,
                         source.shape)

    def test_an_image_smaller_than_the_background_window_is_fine(self):
        # medianBlur refuses a kernel wider than the image, and a cropped or
        # thumbnail upload would otherwise crash the import.
        small = page(dark_band=6, pale_band=6, size=21)
        self.assertEqual(worker.suppress_show_through(small).shape, small.shape)
        self.assertIsNotNone(worker.has_show_through(small))


if __name__ == '__main__':
    unittest.main()
