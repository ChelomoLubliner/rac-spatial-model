"""QA images of T3 (decisions A-087, A-089; user rule 10: the agent who
made them looked at every one, described in the results document).

rac_tile draws a hollow square per RAC, green on contact and red off;
contact_sheet lays tiles out with labels; the committed raw sheets (all
NEW shoes, 32 per sheet) and off-contact sheets equal a fresh drawing pixel
for pixel (PNG bytes may differ between Pillow builds, A-054).
"""

import math
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image

from contour_algorithm import qa_sheets
from contour_algorithm.calibrate_pixels import load_dataset
from contour_algorithm.profiles import load_profile


def pixels(path):
    return np.asarray(Image.open(path).convert('RGB'))


class Drawing(unittest.TestCase):

    def test_rac_tile(self):
        contact = np.zeros((20, 20), dtype=bool)
        contact[5:10, 5:10] = True
        tile = qa_sheets.rac_tile(contact, np.array([7, 15]),
                                  np.array([7, 15]), np.array([True, False]))
        self.assertEqual(tile.shape, (20, 20, 3))
        self.assertEqual(tuple(tile[5, 5]), qa_sheets.GREEN)   # ring corner
        self.assertEqual(tuple(tile[7, 9]), qa_sheets.GREEN)   # ring side
        self.assertEqual(tuple(tile[7, 7]), (qa_sheets.WHITE,) * 3)  # kept
        self.assertEqual(tuple(tile[13, 17]), qa_sheets.RED)
        self.assertEqual(tuple(tile[15, 15]), (0, 0, 0))       # off contact
        self.assertEqual(tuple(tile[0, 0]), (0, 0, 0))

    def test_contact_sheet(self):
        tiles = [np.zeros((10, 8, 3), dtype=np.uint8) for _ in range(5)]
        with tempfile.TemporaryDirectory() as tmp:
            out = qa_sheets.contact_sheet(tiles, ['a'] * 5, 2,
                                          Path(tmp) / 'sub' / 's_new.png',
                                          label_h=6, gap=1)
            img = pixels(out)
        self.assertEqual(img.shape, (3 * (10 + 6 + 1), 2 * (8 + 1), 3))


class Committed(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.data = {}
        for ds in ('old', 'new'):
            p = load_profile(ds)
            cls.data[ds] = (p, load_dataset(p),
                            pd.read_csv(p.prep_path('shoe_contact')))

    def test_raw_sheets(self):
        p, data, _ = self.data['new']
        n = math.ceil(p.num_shoe / qa_sheets.PER_SHEET)
        found = sorted(p.prep_path('qa_dir').glob('raw_sheet_*_new.png'))
        self.assertEqual([f.name for f in found],
                         [f'raw_sheet_{k:02d}_new.png'
                          for k in range(1, n + 1)])
        for k in (1, n):
            first = (k - 1) * qa_sheets.PER_SHEET + 1
            shoes = range(first, min(first + qa_sheets.PER_SHEET,
                                     p.num_shoe + 1))
            tiles, labels = qa_sheets.shoe_tiles(p, data, shoes)
            with tempfile.TemporaryDirectory() as tmp:
                out = qa_sheets.contact_sheet(tiles, labels,
                                              qa_sheets.SHEET_COLUMNS,
                                              Path(tmp) / 'x.png')
                with self.subTest(sheet=k):
                    self.assertTrue(np.array_equal(
                        pixels(out),
                        pixels(p.qa_path(f'raw_sheet_{k:02d}', 'png'))))

    def test_offcontact_sheets(self):
        for ds, (p, data, table) in self.data.items():
            committed = pixels(p.qa_path('offcontact_shoes', 'png'))
            with tempfile.TemporaryDirectory() as tmp:
                out = qa_sheets.offcontact_shoes(p, data, table,
                                                 Path(tmp) / 'x.png')
                with self.subTest(dataset=ds):
                    self.assertTrue(np.array_equal(pixels(out), committed))
            self.assertTrue(p.qa_path('calibration_curves', 'png').stat()
                            .st_size > 0)


if __name__ == '__main__':
    unittest.main()
