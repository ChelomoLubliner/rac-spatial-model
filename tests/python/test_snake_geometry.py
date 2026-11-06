"""Snake geometry (plan T2 step 1; plan F15, risk R5).

get_snake_image draws on a (W, H) array with cv2's (x, y) = the snake's
(row, col) and transposes back: a double swap that is correct for the
non-square frames of both datasets. Locked here so that a "fix" cannot
silently transpose the contour. init_snake must give the profile's
ellipse (OLD: rows 38-362, cols 65-245; NEW: the 2023 values).
"""

import unittest
from pathlib import Path

import cv2
import numpy as np

from contour_algorithm.active_contour_snake import get_snake_image, init_snake
from contour_algorithm.profiles import load_profile

REPO = Path(__file__).resolve().parents[2]
PROFILE_FILE = REPO / 'config' / 'datasets.json'


def dilate1(mask):
    """3 x 3 dilation of a bool image."""
    m = np.pad(mask, 1)
    out = np.zeros_like(mask)
    for dr in (0, 1, 2):
        for dc in (0, 1, 2):
            out |= m[dr:dr + mask.shape[0], dc:dc + mask.shape[1]]
    return out


class Orientation(unittest.TestCase):

    def test_get_snake_image(self):
        snake = np.array([[50.0, 20.0], [300.0, 200.0]])  # (row, col)
        for dataset in ('old', 'new'):
            p = load_profile(dataset, file=PROFILE_FILE)
            with self.subTest(dataset=dataset):
                img = np.array(get_snake_image(p, snake), dtype=bool)
                self.assertEqual(img.shape, (p.H, p.W))
                self.assertTrue(img[50, 20] and img[300, 200])
                self.assertFalse(img[20, 50])
                # the same polyline drawn directly in the (H, W) frame with
                # cv2's (x, y) = (col, row): contained in the image, which
                # adds a fringe of at most 1 px (the thick-line raster of
                # cv2 is not symmetric under transposition: 1,625 vs 1,445
                # px here)
                ref = np.zeros((p.H, p.W), dtype=np.uint8)
                cv2.polylines(ref, [np.int32(snake[:, ::-1])], False, 255,
                              thickness=3)
                ref = ref > 0
                self.assertTrue(np.all(img[ref]))
                self.assertTrue(np.all(dilate1(ref)[img]))
                # a transposed drawing (the bug the double swap avoids)
                # does not touch the image
                bug = np.zeros((p.H, p.W), dtype=np.uint8)
                cv2.polylines(bug, [np.int32(snake)], False, 255,
                              thickness=3)
                self.assertFalse(np.any(img & (bug > 0)))
                # every pixel within 3 px (thickness 3, rounded caps, the
                # 1-px fringe) of the segment from (50, 20) to (300, 200)
                rows, cols = np.nonzero(img)
                a, b = np.array([50.0, 20.0]), np.array([300.0, 200.0])
                pts = np.stack([rows, cols], axis=1) - a
                t = np.clip(pts @ (b - a) / ((b - a) @ (b - a)), 0, 1)
                dist = np.hypot(*(pts - t[:, None] * (b - a)).T)
                self.assertLessEqual(dist.max(), 3.0)


class InitSnake(unittest.TestCase):

    def test_old_values(self):
        init = init_snake(load_profile('old', file=PROFILE_FILE))
        self.assertEqual(init.shape, (400, 2))
        self.assertEqual((round(init[:, 0].min()), round(init[:, 0].max())),
                         (38, 362))
        self.assertEqual((round(init[:, 1].min()), round(init[:, 1].max())),
                         (65, 245))
        # the legacy expression, bit for bit
        s = np.linspace(0, 2 * np.pi, 400)
        legacy = np.array([200 + 162 * np.sin(s), 155 + 90 * np.cos(s)]).T
        self.assertTrue(np.array_equal(init, legacy))

    def test_new_values(self):
        init = init_snake(load_profile('new', file=PROFILE_FILE))
        s = np.linspace(0, 2 * np.pi, 400)
        legacy = np.array([185 + 162 * np.sin(s), 128 + 95 * np.cos(s)]).T
        self.assertTrue(np.array_equal(init, legacy))
        self.assertEqual((round(init[:, 0].min()), round(init[:, 0].max())),
                         (23, 347))
        self.assertEqual((round(init[:, 1].min()), round(init[:, 1].max())),
                         (33, 223))


if __name__ == '__main__':
    unittest.main()
