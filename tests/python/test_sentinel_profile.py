"""Sentinel profile: each profile value reaches the outputs of step 0
(decisions A-035, A-050; plan T2 step 1).

A grep cannot prove that a value is used, so this runs the real step 0
(contour_algorithm.main.run) on the tiny fixture of
tests/fixtures/make_sentinel.py (6 shoes of 40 x 60 px, dataset `new` of
its own profile file) in a temporary root and checks that the sentinel
values, which differ from both real datasets, shape the outputs: the
superposition threshold 2, the Python flip list [2], the snake ellipse
(30, 20) / (25, 15) with 50 points, the snake parameters (Gaussian sigma
2.5, alpha 0.012, beta 12 and 0.12, gamma 0.0015: every call of the snake
and of the blur receives them, and each one set alone to the real value
changes the snakes; T2 review), the coordinates at 20 px per unit with
rel_x_cord 0.3 and rel_Y_cord 0.6 (a leftover 0.25 or 0.5 moves the RAC
pixels), the skip list (shoe 4 without RACs, shoe 5 excluded: 4 contour
records of stride 40 * 60 + 2) and the namespaced output names. Nothing is
written outside the temporary root.
"""

import dataclasses
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import numpy as np
import pandas as pd

from contour_algorithm import active_contour_snake as acs
from contour_algorithm import distance_extremities
from contour_algorithm import main as step0
from contour_algorithm.active_contour_snake import init_snake
from contour_algorithm.io_shoes import read_shoes
from contour_algorithm.profiles import load_profile
from tests.fixtures import make_sentinel

SNAKE_PARAMS = ('gaussian_sigma', 'alpha', 'beta_first', 'beta_second',
                'gamma')

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
        # every call of the snake and of the blur, recorded on the way
        with mock.patch.object(acs, 'active_contour',
                               wraps=acs.active_contour) as snake_spy, \
                mock.patch.object(acs, 'gaussian',
                                  wraps=acs.gaussian) as blur_spy:
            cls.seconds = step0.run(cls.profile, log=lambda *a: None)
        cls.snake_calls = snake_spy.call_args_list
        cls.blur_calls = blur_spy.call_args_list

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

    def test_snake_parameters_reach_every_call(self):
        """Each snake parameter of the fixture differs from the real one
        and reaches every call: 2 snakes for the prototype and 2 for each
        of the 6 shoes, the first with beta_first, the second with
        beta_second, every blur with gaussian_sigma (T2 review: with the
        real values in the fixture, hard-coded copies went unnoticed)."""
        p, real = self.profile, load_profile('old').snake
        for name in SNAKE_PARAMS:
            self.assertNotEqual(getattr(p.snake, name), getattr(real, name))
        sp = p.snake
        self.assertEqual(len(self.snake_calls), 2 * (1 + 6))
        self.assertEqual(len(self.blur_calls), 2 * (1 + 6))
        for k, c in enumerate(self.snake_calls):
            with self.subTest(call=k):
                beta = sp.beta_first if k % 2 == 0 else sp.beta_second
                self.assertEqual((c.kwargs['alpha'], c.kwargs['beta'],
                                  c.kwargs['gamma']),
                                 (sp.alpha, beta, sp.gamma))
                self.assertTrue(np.array_equal(c.args[1], init_snake(p)))
        for k, c in enumerate(self.blur_calls):
            with self.subTest(blur=k):
                self.assertEqual(c.args[1], sp.gaussian_sigma)

    def test_snake_parameters_shape_the_snakes(self):
        """The snakes of the run are those of the fixture values, and each
        value set alone to the real one changes the snake of every shoe:
        an output that only these values produce."""
        p, real = self.profile, load_profile('old').snake
        contours = np.load(p.saved_path('list_contour', 'npy'))
        snakes = np.load(p.saved_path('active-contour_all', 'npy'))

        def snake(profile, i):
            return acs.active_contour_shoe(profile, contours, plot_img=False,
                                           save_img_bool=False, im_num=i)
        for i in range(6):
            self.assertTrue(np.array_equal(snake(p, i), snakes[i]))
        for name in SNAKE_PARAMS:
            q = dataclasses.replace(p, snake=dataclasses.replace(
                p.snake, **{name: getattr(real, name)}))
            with self.subTest(param=name):
                same = [i + 1 for i in range(6)
                        if np.array_equal(snake(q, i), snakes[i])]
                self.assertEqual(same, [])

    def test_coordinates_follow_the_profile(self):
        """COL/ROW of every RAC = the pixel the fixture placed it on (20 px
        per unit, x mirrored), so the coords block is used (A-050); with a
        leftover 0.25 or 0.5 in place of the fixture's rel_x_cord 0.3 or
        rel_Y_cord 0.6 RAC pixels move (10 and 14 of the 19 RACs; T2
        review)."""
        p = self.profile
        locs = pd.read_csv(p.saved_path('locations_pixels', 'csv'))
        want = [(shoe - 1, col, row)
                for shoe, pix in make_sentinel.RACS.items()
                for row, col in pix]
        got = list(zip(locs['shoe'], locs['COL'], locs['ROW']))
        self.assertEqual(got, want)
        real = load_profile('old').coords
        self.assertNotEqual((p.coords.rel_x_cord, p.coords.rel_Y_cord),
                            (real.rel_x_cord, real.rel_Y_cord))
        for name in ('rel_x_cord', 'rel_Y_cord'):
            q = dataclasses.replace(p, coords=dataclasses.replace(
                p.coords, **{name: getattr(real, name)}))
            moved = (distance_extremities.aspix_x(q, locs['x'])
                     != locs['COL']) | (
                distance_extremities.aspix_y(q, locs['y']) != locs['ROW'])
            with self.subTest(coord=name):  # any move breaks `got == want`
                self.assertTrue(moved.any(), f'{name}: no RAC pixel moved')

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
