"""Per-shoe RAC contact table (plan T3 step 3c, task item 3; decisions
A-029, A-089).

Synthetic: the strict and dilated rates, the best shift (a shoe whose RACs
were shifted by (3, -2) px gets the best shift (-3, 2) and rate 1), the
flip rate, the row of a shoe without RACs. Committed: the OLD and NEW
tables (prep.shoe_contact) equal a fresh computation byte for byte, and
the lists that A-089 decides on: the shoes without RACs (OLD 127, NEW
none), the shoes with every RAC off contact (OLD 9, 268; NEW 69, 515, 629;
with a 1-pixel dilation only NEW 629) and the step-1 case pixels (OLD
13,249, NEW 19,990).
"""

import unittest

import numpy as np
import pandas as pd

from contour_algorithm.calibrate_pixels import load_dataset
from contour_algorithm.profiles import load_profile
from contour_algorithm.shoe_quality import (COLUMNS, best_shift,
                                            old_quality_threshold,
                                            profile_table, shoe_quality)


def synthetic_records():
    """3 records of 30 x 40 px: two blocks in record 1, an empty record 2,
    a block in record 3."""
    c = np.zeros((3, 40, 30), dtype=bool)
    c[0, 5:12, 4:10] = True
    c[0, 20:30, 15:25] = True
    c[2, 10:20, 10:20] = True
    return c


class Quality(unittest.TestCase):

    def test_best_shift_recovers_a_shift(self):
        """Isolated contact pixels 10 px apart, so that only the exact
        shift puts every RAC back on contact."""
        img = np.zeros((60, 50), dtype=bool)
        img[5:56:10, 5:46:10] = True
        rr, cc = np.nonzero(img)
        col0, row0 = cc + 3, rr - 2  # RACs moved by (3, -2)
        rate, dc, dr = best_shift(img, col0, row0)
        self.assertEqual((float(rate), dc, dr), (1.0, -3, 2))
        # on contact already: no shift (ties go to the smallest shift)
        self.assertEqual(best_shift(img, cc, rr), (1.0, 0, 0))
        # a block wider than the shift: every shift that keeps the RACs
        # on it ties, and the smallest one wins
        c = synthetic_records()
        rate, dc, dr = best_shift(c[0], np.array([9]), np.array([6]))
        self.assertEqual((float(rate), dc, dr), (1.0, 0, 0))

    def test_table(self):
        c = synthetic_records()
        # shoe 1: 2 on, 1 next to a block (dilated on), 1 far off;
        # shoe 2 has no RAC; shoe 3: 1 RAC, off even with dilation
        shoe = np.array([1, 1, 1, 1, 3])
        col0 = np.array([5, 16, 10, 0, 25])
        row0 = np.array([6, 22, 6, 39, 30])
        t = shoe_quality(c, shoe, col0, row0, num_shoe=3)
        self.assertEqual(list(t.columns), list(COLUMNS))
        self.assertEqual(t['shoe'].tolist(), [1, 2, 3])
        r1, r2, r3 = (t.iloc[k] for k in range(3))
        self.assertEqual((r1.n_rac, r1.n_on, r1.n_on_dil, r1.n_off,
                          r1.n_off_dil), (4, 2, 3, 2, 1))
        self.assertEqual((r1.rate, r1.rate_dil), (0.5, 0.75))
        self.assertEqual(r1.px, int(c[0].sum()))
        self.assertFalse(r1.all_off)
        self.assertEqual((r2.n_rac, r2.px), (0, 0))
        self.assertTrue(np.isnan(r2.rate) and np.isnan(r2.best_shift_rate))
        self.assertTrue(r3.all_off and r3.all_off_dil)
        self.assertEqual(r3.n_outside, 0)
        # the left-right mirrored record: shoe 3's block is centred, so
        # mirroring moves the RAC from column 25 to 4: still off
        self.assertEqual(r3.best_flip_rate, 0.0)

    def test_threshold(self):
        t = pd.DataFrame({'n_rac': [10, 12, 9, 30, 15],
                          'best_shift_rate': [0.9, 0.5, 0.1, 1.0, 0.8]})
        want = float(np.percentile([0.9, 0.5, 1.0, 0.8], 5))
        self.assertEqual(old_quality_threshold(t), want)


class Committed(unittest.TestCase):
    """The committed tables and the lists A-089 decides on."""

    @classmethod
    def setUpClass(cls):
        cls.tables = {}
        for ds in ('old', 'new'):
            p = load_profile(ds)
            data = load_dataset(p)
            cls.tables[ds] = (p, profile_table(p, data), data)

    def test_tables_regenerate(self):
        for ds, (p, t, _) in self.tables.items():
            with self.subTest(dataset=ds):
                fresh = t.to_csv(index=False, lineterminator='\n').encode()
                self.assertEqual(p.prep_path('shoe_contact').read_bytes(),
                                 fresh)
                self.assertEqual(len(t), p.num_shoe)

    def test_lists(self):
        want = {'old': ([127], [9, 268], [], 13249),
                'new': ([], [69, 515, 629], [629], 19990)}
        for ds, (p, t, data) in self.tables.items():
            no_racs, all_off, all_off_dil, cases = want[ds]
            with self.subTest(dataset=ds):
                self.assertEqual(t.loc[t.n_rac == 0, 'shoe'].tolist(),
                                 no_racs)
                self.assertEqual(list(p.shoes_without_racs), no_racs)
                self.assertEqual(t.loc[t.all_off, 'shoe'].tolist(), all_off)
                self.assertEqual(t.loc[t.all_off_dil, 'shoe'].tolist(),
                                 all_off_dil)
                self.assertEqual(int(t.n_rac_pixels.sum()), cases)
                self.assertEqual(int(t.n_rac.sum()), len(data['x']))
                self.assertEqual(int(t.n_outside.sum()), 0)
                # no shoe is better explained by a left-right flip (F17)
                g = t[t.n_rac >= 10]
                self.assertFalse(
                    (g.best_flip_rate > g.best_shift_rate + 0.15).any())


if __name__ == '__main__':
    unittest.main()
