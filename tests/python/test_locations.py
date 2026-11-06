"""RAC location readers and the computed skip list (plan T2; F1, F2, F4).

read_locations gives the OLD CSV as it is and the NEW raw file divided by
2; record_skip_idx0 computes the shoes without RACs from the locations
(OLD: shoe 127; NEW: none, so no real NEW shoe is dropped, risk R6) and
refuses a profile whose shoes_without_racs disagrees. T3 adds the full
NEW checks (test_locations_new).
"""

import dataclasses
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

from contour_algorithm.locations import (read_locations, record_skip_idx0,
                                         shoes_without_racs)
from contour_algorithm.profiles import load_profile

REPO = Path(__file__).resolve().parents[2]
PROFILE_FILE = REPO / 'config' / 'datasets.json'


class Locations(unittest.TestCase):

    def test_old(self):
        p = load_profile('old', file=PROFILE_FILE)
        locs = read_locations(p)
        self.assertEqual(list(locs.columns),
                         ['shoe', 'x', 'y', 'type', 'orientation', 'grade'])
        self.assertEqual(len(locs), 13287)
        self.assertEqual(locs['shoe'].nunique(), 386)
        self.assertEqual(shoes_without_racs(p, locs), (127,))
        self.assertEqual(record_skip_idx0(p, locs), (126,))
        # read as it is (divisor 1): the CSV values themselves
        raw = pd.read_csv(p.locations)
        self.assertTrue(raw.equals(locs))

    def test_new(self):
        p = load_profile('new', file=PROFILE_FILE)
        locs = read_locations(p)
        self.assertEqual(list(locs.columns),
                         ['shoe', 'rac_num', 'x', 'y', 'type'])
        self.assertEqual(len(locs), 20013)
        self.assertEqual(sorted(locs['shoe'].unique()), list(range(1, 632)))
        self.assertEqual(shoes_without_racs(p, locs), ())
        self.assertEqual(record_skip_idx0(p, locs), ())
        ref = pd.read_csv(p.cross_check)  # 2023: coordinates / 2 (F4)
        self.assertTrue(np.array_equal(locs['x'].to_numpy(),
                                       ref['x'].to_numpy()))
        self.assertTrue(np.array_equal(locs['y'].to_numpy(),
                                       ref['y'].to_numpy()))

    def test_profile_must_match_the_data(self):
        p = load_profile('new', file=PROFILE_FILE)
        locs = read_locations(p)
        wrong = dataclasses.replace(p, shoes_without_racs=(127,))
        with self.assertRaises(ValueError):
            record_skip_idx0(wrong, locs)
        old = load_profile('old', file=PROFILE_FILE)
        with self.assertRaises(ValueError):
            record_skip_idx0(dataclasses.replace(old, shoes_without_racs=()))
        # excluded shoes are skipped too, after the shoes without RACs
        excl = dataclasses.replace(old, excluded_shoes=(5, 300))
        self.assertEqual(record_skip_idx0(excl), (4, 126, 299))


if __name__ == '__main__':
    unittest.main()
