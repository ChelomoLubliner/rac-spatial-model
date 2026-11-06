"""Pixel mapping of the RACs (plan T3 step 1; decisions A-086, A-087, F5,
F6).

calibrate_pixels.legacy_pixel must equal the R aspix_x / aspix_y of step 1
(evaluated from dataCC_1.Rmd itself by tests/lib/aspix_dump.R) for every
OLD and NEW RAC, and the 2023 COL / ROW for every NEW RAC; the two OLD
RACs where the multiply form differs (F6) are checked explicitly. The
mapping family of the calibration reduces to legacy_pixel at the legacy
setting except for RACs exactly on a pixel boundary. R's number parser is
not correctly rounded (1 ulp on a few values, T3 results); the test reports
how many doubles differ between R and Python and requires the pixels to be
identical anyway.
"""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

from contour_algorithm.calibrate_pixels import (Setting, legacy_center,
                                                legacy_pixel, px_per_unit)
from contour_algorithm.locations import read_locations
from contour_algorithm.profiles import load_profile

REPO = Path(__file__).resolve().parents[2]
# F6: (shoe, x, y) -> R (col, row); the multiply form gives row 137 for
# the first and col 174 for the second
F6_RACS = {(46, 0.09425, 0.2): (125, 138), (239, -0.07, -0.47346): (175, 340)}


def mapped(p, locs=None):
    locs = read_locations(p) if locs is None else locs
    return locs, legacy_pixel(locs['x'].to_numpy(), locs['y'].to_numpy(),
                              p.coords, p.W, p.H)


class Mapping(unittest.TestCase):

    def test_new_equals_2023_colrow(self):
        p = load_profile('new')
        locs, (col, row) = mapped(p)
        ref = pd.read_csv(p.cross_check)
        self.assertEqual(len(col), len(ref))
        self.assertTrue(np.array_equal(col, ref['COL'].to_numpy()))
        self.assertTrue(np.array_equal(row, ref['ROW'].to_numpy()))

    def test_f6_racs(self):
        p = load_profile('old')
        locs, (col, row) = mapped(p)
        for (shoe, x, y), want in F6_RACS.items():
            k = np.flatnonzero((locs['shoe'] == shoe) & (locs['x'] == x)
                               & (locs['y'] == y))
            self.assertEqual(len(k), 1, (shoe, x, y))
            self.assertEqual((int(col[k[0]]), int(row[k[0]])), want)

    @unittest.skipIf(shutil.which('Rscript') is None, 'Rscript not found')
    def test_matches_r_aspix(self):
        with tempfile.TemporaryDirectory() as tmp:
            for ds in ('old', 'new'):
                out = Path(tmp) / f'aspix_{ds}.csv'
                r = subprocess.run(
                    ['Rscript', str(REPO / 'tests/lib/aspix_dump.R'), ds,
                     str(out)], capture_output=True, text=True, timeout=600)
                self.assertEqual(r.returncode, 0, r.stderr)
                rr = pd.read_csv(out, dtype={'x': str, 'y': str})
                p = load_profile(ds)
                locs, (col, row) = mapped(p)
                with self.subTest(dataset=ds):
                    self.assertEqual(len(rr), len(locs))
                    self.assertTrue(np.array_equal(rr['shoe'], locs['shoe']))
                    self.assertTrue(np.array_equal(rr['col'], col))
                    self.assertTrue(np.array_equal(rr['row'], row))
                    n_diff = {}
                    for c in ('x', 'y'):
                        a = np.array([float(v) for v in rr[c]])
                        b = locs[c].to_numpy()
                        ulps = np.abs(a - b) / np.spacing(np.abs(b))
                        self.assertLessEqual(float(ulps.max()), 1.0, c)
                        n_diff[c] = int((a != b).sum())
                    print(f'\n{ds}: {len(rr)} RACs, R and Python pixels '
                          f'identical; doubles that differ by 1 ulp (R '
                          f'parser): x {n_diff["x"]}, y {n_diff["y"]}')

    def test_legacy_setting_of_the_family(self):
        """Setting(s0, s0, 0, 0) of the calibration family equals the
        legacy mapping except for RACs exactly on a pixel boundary."""
        for ds in ('old', 'new'):
            p = load_profile(ds)
            locs, (col, row) = mapped(p)
            s0 = px_per_unit(p.coords)
            x, y = locs['x'].to_numpy(), locs['y'].to_numpy()
            c0, r0 = Setting(s0[0], s0[1], 0.0, 0.0).pixels(
                x, y, *legacy_center(p.coords, p.W, p.H))
            diff = np.flatnonzero((c0 != col - 1) | (r0 != row - 1))
            with self.subTest(dataset=ds):
                self.assertLessEqual(len(diff), 2)
                for k in diff:
                    on_edge = [abs(s * v - round(s * v)) < 1e-9
                               for s, v in ((s0[0], x[k]), (s0[1], y[k]))]
                    self.assertTrue(any(on_edge), (ds, k, x[k], y[k]))

    def test_legacy_center(self):
        """x = 0 and y = 0 sit on the pixel edge cx0, cy0: RACs just on
        either side map to the two pixels around it (0-based)."""
        for ds in ('old', 'new'):
            p = load_profile(ds)
            cx0, cy0 = legacy_center(p.coords, p.W, p.H)
            eps = 1e-7
            col, row = legacy_pixel(np.array([-eps, eps]),
                                    np.array([-eps, eps]), p.coords, p.W,
                                    p.H)
            with self.subTest(dataset=ds):
                self.assertEqual((col - 1).tolist(), [cx0, cx0 - 1])
                self.assertEqual((row - 1).tolist(), [cy0, cy0 - 1])


if __name__ == '__main__':
    unittest.main()
