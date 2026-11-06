"""Sentinel profile: each profile value reaches the outputs of step 0
(decisions A-035, A-050; plan T2 step 1).

A grep cannot prove that a value is used, so this runs the real step 0
(contour_algorithm.main.run) on the tiny fixture of
tests/fixtures/make_sentinel.py (6 shoes of 40 x 60 px, dataset `new` of
its own profile file) in a temporary root and checks that the sentinel
values, which differ from both real datasets, shape the outputs: the
superposition threshold 2, the Python flip list [2], the snake ellipse
(30, 20) / (25, 15) with 50 points, the coordinates at 20 px per unit, the
skip list (shoe 4 without RACs, shoe 5 excluded: 4 contour records of
stride 40 * 60 + 2) and the namespaced output names. Nothing is written
outside the temporary root.
"""

import shutil
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

from contour_algorithm import main as step0
from contour_algorithm.active_contour_snake import init_snake
from contour_algorithm.io_shoes import read_shoes
from contour_algorithm.profiles import load_profile
from tests.fixtures import make_sentinel

REPO = Path(__file__).resolve().parents[2]
FIXTURE = REPO / 'tests' / 'fixtures' / 'sentinel'


class Fixture(unittest.TestCase):

    def test_committed_fixture_is_the_generator_output(self):
        """The committed fixture equals a fresh run of make_sentinel.py
        (text files by bytes, PNGs by pixels: A-054)."""
        from PIL import Image
        with tempfile.TemporaryDirectory() as tmp:
            make_sentinel.main(tmp)
            fresh = sorted(p.relative_to(tmp) for p in Path(tmp).rglob('*')
                           if p.is_file())
            have = sorted(p.relative_to(FIXTURE) for p in FIXTURE.rglob('*')
                          if p.is_file())
            self.assertEqual(fresh, have)
            for rel in fresh:
                a, b = Path(tmp) / rel, FIXTURE / rel
                with self.subTest(file=str(rel)):
                    if rel.suffix == '.png':
                        self.assertTrue(np.array_equal(
                            np.array(Image.open(a)), np.array(Image.open(b))))
                    else:
                        self.assertEqual(a.read_bytes(), b.read_bytes())


class Sentinel(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix='sentinel_py_')
        cls.root = Path(cls.tmp.name)
        shutil.copytree(FIXTURE / 'data', cls.root / 'data')
        cls.inputs = {p.relative_to(cls.root)
                      for p in cls.root.rglob('*') if p.is_file()}
        cls.profile = load_profile(
            'new', file=FIXTURE / make_sentinel.PROFILE, root=cls.root)
        cls.seconds = step0.run(cls.profile, log=lambda *a: None)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_profile_is_the_sentinel(self):
        p = self.profile
        self.assertEqual((p.W, p.H, p.num_shoe), (40, 60, 6))
        self.assertEqual(p.analysis_shoes(), (1, 2, 3, 6))
        self.assertEqual(set(self.seconds),
                         {'create', 'contour', 'snake', 'distance'})

    def test_values_reach_outputs(self):
        p = self.profile
        raw = read_shoes(p.contacts, 40, 60, 6)
        matrices = np.load(p.saved_path('list_matrices', 'npy'))
        # python.contact_flip_shoes = [2]: only shoe 2 is mirrored
        want = raw.copy()
        want[1] = np.fliplr(raw[1])
        self.assertTrue(np.array_equal(matrices, want))
        self.assertFalse(np.array_equal(matrices[1], raw[1]))
        # python.superpose_threshold = 2, in the mask and in its file name
        sup = np.load(p.saved_path('superposed_min_2', 'npy'))
        self.assertTrue(np.array_equal(sup, want.sum(axis=0) >= 2))
        self.assertTrue(p.saved_path('freq_min_2', 'npy').is_file())
        # python.snake: center (30, 20), radii (25, 15), 50 points
        s = np.linspace(0, 2 * np.pi, 50)
        ellipse = np.array([30 + 25 * np.sin(s), 20 + 15 * np.cos(s)]).T
        self.assertTrue(np.array_equal(init_snake(p), ellipse))
        # the contour file: 6 - 2 records of stride 40 * 60 + 2, CRLF
        data = p.contour_out.read_bytes()
        stride = 40 * 60 + 2
        self.assertEqual(len(data), 4 * stride)
        for k in range(4):
            self.assertEqual(data[(k + 1) * stride - 2:(k + 1) * stride],
                             b'\r\n')
        snakes = np.load(p.saved_path('active-contour_all', 'npy'))
        self.assertEqual(snakes.shape, (6, 60, 40))
        self.assertTrue(np.array_equal(read_shoes(p.contour_out, 40, 60, 4),
                                       snakes[[0, 1, 2, 5]]))

    def test_coordinates_follow_the_profile(self):
        """COL/ROW of every RAC = the pixel the fixture placed it on (20 px
        per unit, x mirrored), so the coords block is used (A-050)."""
        p = self.profile
        locs = pd.read_csv(p.saved_path('locations_pixels', 'csv'))
        want = [(shoe - 1, col, row)
                for shoe, pix in make_sentinel.RACS.items()
                for row, col in pix]
        got = list(zip(locs['shoe'], locs['COL'], locs['ROW']))
        self.assertEqual(got, want)

    def test_outputs_are_namespaced(self):
        written = {q.relative_to(self.root) for q in self.root.rglob('*')
                   if q.is_file()} - self.inputs
        self.assertGreater(len(written), 30)
        for rel in written:
            with self.subTest(file=str(rel)):
                self.assertIn(rel.parts[0], ('images_new', 'data'))
                if rel.parts[0] == 'data':
                    self.assertEqual(rel.parts[1], 'new_shoes')
                self.assertTrue(rel.stem.endswith('_new'), rel)
        self.assertTrue((self.root / 'images_new/shoes/im5_new.png')
                        .is_file())


if __name__ == '__main__':
    unittest.main()
