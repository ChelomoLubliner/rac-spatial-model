"""NEW RAC locations (plan T3 step 1; decisions A-088, F2, F4).

read_locations(new) divides the raw coordinates by 2; the derived CSV
data/new_shoes/locations_data_new.csv (shoe, x, y, type, rac_num) holds the
exact decimal halves. Both must equal the 2023 file's x and y for all
20,013 RACs (exactly, and so within the task's tolerance 1e-6), with the
same shoe ids and RAC counts; the committed CSV must equal a fresh build
byte for byte and parse to the same doubles as read_locations (the sign of
zero included).
"""

import contextlib
import dataclasses
import io
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import numpy as np
import pandas as pd

from contour_algorithm import locations
from contour_algorithm.locations import (CSV_COLUMNS, derived_csv_bytes,
                                         read_locations, write_derived_csv)
from contour_algorithm.profiles import load_profile

N_RAC = 20013
TOL = 1e-6


def clean_env(**extra):
    env = {k: v for k, v in os.environ.items() if not k.startswith('RAC_')}
    env.update(extra)
    return env


class New(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.p = load_profile('new')
        cls.locs = read_locations(cls.p)
        cls.ref = pd.read_csv(cls.p.cross_check)
        cls.csv_path = cls.p.prep_path('locations_csv')
        cls.csv = pd.read_csv(cls.csv_path)

    def test_matches_2023(self):
        locs, ref = self.locs, self.ref
        self.assertEqual(len(locs), N_RAC)
        self.assertEqual(len(ref), N_RAC)
        shoes = locs['shoe'].to_numpy()
        self.assertTrue(np.all(np.diff(shoes) >= 0), 'not sorted by shoe')
        self.assertEqual(sorted(set(shoes)),
                         list(range(1, self.p.num_shoe + 1)))
        for col in ('shoe', 'rac_num', 'type'):
            self.assertTrue(np.array_equal(locs[col], ref[col]), col)
        # rac_num runs 1..n inside every shoe
        for s, g in locs.groupby('shoe'):
            self.assertTrue(np.array_equal(g['rac_num'],
                                           np.arange(1, len(g) + 1)), s)
        counts = locs.groupby('shoe').size()
        self.assertTrue(counts.equals(ref.groupby('shoe').size()))
        self.assertEqual(int(counts.min()), 1)
        for c in ('x', 'y'):
            a, b = locs[c].to_numpy(), ref[c].to_numpy()
            self.assertTrue(np.array_equal(a, b), c)
            self.assertLessEqual(float(np.max(np.abs(a - b))), TOL)

    def test_derived_csv_committed(self):
        self.assertEqual(self.csv_path.read_bytes(),
                         derived_csv_bytes(self.p))

    def test_derived_csv_format(self):
        data = self.csv_path.read_bytes()
        self.assertNotIn(b'\r', data)
        self.assertTrue(data.endswith(b'\n'))
        lines = data.decode('ascii').splitlines()
        self.assertEqual(lines[0], ','.join(CSV_COLUMNS))
        self.assertEqual(len(lines), N_RAC + 1)
        # the first four columns are those of the OLD locations file
        old = pd.read_csv(load_profile('old').locations, nrows=1)
        self.assertEqual(list(old.columns[:4]), list(CSV_COLUMNS[:4]))
        # x and y with 7 decimals (the raw file has 6), no exponent
        for line in lines[1:]:
            fields = line.split(',')
            for v in fields[1:3]:
                self.assertEqual(len(v.split('.')[1]), 7, line)
                self.assertNotIn('e', v.lower())

    def test_derived_csv_values(self):
        csv, locs, ref = self.csv, self.locs, self.ref
        self.assertEqual(list(csv.columns), list(CSV_COLUMNS))
        for col in ('shoe', 'rac_num', 'type'):
            self.assertTrue(np.array_equal(csv[col], locs[col]), col)
        for c in ('x', 'y'):
            a = csv[c].to_numpy()
            # bit for bit (the sign of zero too: one RAC has x = -0)
            self.assertTrue(np.array_equal(a.view(np.int64),
                                           locs[c].to_numpy().view(np.int64)))
            self.assertTrue(np.array_equal(a, ref[c].to_numpy()))
            self.assertLessEqual(float(np.max(np.abs(a - ref[c]))), TOL)
        self.assertEqual(int(np.signbit(csv['x'][csv['x'] == 0]).sum()), 1)

    def test_exact_halving(self):
        """Exact decimal halves of a small raw file, and a bad line."""
        with tempfile.TemporaryDirectory() as tmp:
            raw = Path(tmp) / 'raw.txt'
            raw.write_bytes(b' 1 1 -0.409554 0.102131 6 \r\n'
                            b' 1 2 0.000001 -0.000000 1\r\n'
                            b' 2 1 0.100000 -0.999999 7\r\n')
            p = dataclasses.replace(self.p, locations=raw)
            self.assertEqual(derived_csv_bytes(p).decode().splitlines(), [
                'shoe,x,y,type,rac_num',
                '1,-0.2047770,0.0510655,6,1',
                '1,0.0000005,-0.0000000,1,2',
                '2,0.0500000,-0.4999995,7,1'])
            out = write_derived_csv(p, Path(tmp) / 'sub' / 'x_new.csv')
            self.assertEqual(out.read_bytes(), derived_csv_bytes(p))
            raw.write_bytes(b' 1 1 -0.409554 6\r\n')
            with self.assertRaises(ValueError):
                derived_csv_bytes(p)
        with self.assertRaises(ValueError):
            derived_csv_bytes(load_profile('old'))


class Cli(unittest.TestCase):
    """The command line, run in-process (main() reads RAC_* itself)."""

    def run_main(self, argv, **env):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, clean_env(**env), clear=True), \
                contextlib.redirect_stdout(out), \
                contextlib.redirect_stderr(err):
            code = locations.main(argv)
        return code, out.getvalue(), err.getvalue()

    def test_check_and_refusals(self):
        code, out, err = self.run_main(['--check'], RAC_DATASET='new')
        self.assertEqual(code, 0, err)
        self.assertIn('identical to a fresh build', out)
        code, out, err = self.run_main(['--check'], RAC_DATASET='old')
        self.assertEqual(code, 2)
        self.assertIn('no derived locations CSV', err)
        code, out, err = self.run_main(
            ['--check'], RAC_DATASET='new',
            RAC_PROFILE_FILE='config/datasets.json')
        self.assertEqual(code, 2)
        self.assertIn('RAC_PROFILE_FILE', err)


if __name__ == '__main__':
    unittest.main()
