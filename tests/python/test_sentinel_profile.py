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
records of stride 40 * 60 + 2) and the namespaced output names; and the T4
step-0 values of the NEW entry (T4 review): the first-snake closing radius
2, the per-shoe override of shoe 3 (closing radius 5, its own ellipse) and
the erase rectangle on shoe 6, each of which changes the snakes and the
contour records (each removed alone in a second run or a recomputed snake).
Nothing is written outside the temporary root.
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
from contour_algorithm.stickers import apply_sticker_masks, read_sticker_masks
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
        # inputs.sticker_masks: the fixture's rectangle on shoe 6 is erased
        # first (A-095), then python.contact_flip_shoes = [2] mirrors shoe 2
        want, _ = apply_sticker_masks(raw, read_sticker_masks(p))
        want[1] = np.fliplr(want[1])
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
            # calls 0-1: the prototype; then 2 per shoe, shoe 1 first; the
            # override of shoe 3 gives it its own ellipse (A-097)
            shoe = None if k < 2 else (k - 2) // 2 + 1
            with self.subTest(call=k):
                beta = sp.beta_first if k % 2 == 0 else sp.beta_second
                self.assertEqual((c.kwargs['alpha'], c.kwargs['beta'],
                                  c.kwargs['gamma']),
                                 (sp.alpha, beta, sp.gamma))
                self.assertTrue(np.array_equal(c.args[1],
                                               init_snake(p, shoe=shoe)))
        self.assertFalse(np.array_equal(init_snake(p, shoe=3),
                                        init_snake(p)))
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

    def test_t4_values_reach_outputs(self):
        """The T4 step-0 values of the NEW entry differ from the real ones
        and each one changes the outputs (T4 review; A-035): the
        first-snake closing radius (2; set to 0 alone, the snake of every
        shoe without an override changes), the override of shoe 3 (removed
        alone, only shoe 3's snake changes) and the erase rectangle on
        shoe 6 (its matrix is the record minus the rectangle; a second step
        0 without the list gives other matrices, snake and record for shoe
        6 only)."""
        p, real = self.profile, load_profile('new')
        self.assertEqual(p.snake.first_closing_radius,
                         make_sentinel.CLOSING_RADIUS)
        self.assertNotIn(p.snake.first_closing_radius,
                         (0, real.snake.first_closing_radius))
        over = acs.snake_overrides(p)
        self.assertEqual(set(over), {make_sentinel.OVERRIDE['shoe']})
        self.assertEqual(over[3]['first_closing_radius'],
                         make_sentinel.OVERRIDE['first_closing_radius'])
        contours = np.load(p.saved_path('list_contour', 'npy'))
        snakes = np.load(p.saved_path('active-contour_all', 'npy'))

        def snake(profile, i):
            return acs.active_contour_shoe(profile, contours, plot_img=False,
                                           save_img_bool=False, im_num=i)
        no_closing = dataclasses.replace(p, snake=dataclasses.replace(
            p.snake, first_closing_radius=0))
        changed = [i + 1 for i in range(6)
                   if not np.array_equal(snake(no_closing, i), snakes[i])]
        self.assertEqual(changed, [1, 2, 4, 5, 6])
        no_override = dataclasses.replace(p, snake_overrides=None)
        changed = [i + 1 for i in range(6)
                   if not np.array_equal(snake(no_override, i), snakes[i])]
        self.assertEqual(changed, [3])
        # the erase list: a second step 0 without it, in its own root
        raw = read_shoes(p.contacts, 40, 60, 6)
        matrices = np.load(p.saved_path('list_matrices', 'npy'))
        e = make_sentinel.ERASE
        block = (e['shoe'] - 1, slice(e['row0'] - 1, e['row1']),
                 slice(e['col0'] - 1, e['col1']))
        self.assertGreater(int(raw[block].sum()), 0)
        self.assertFalse(matrices[block].any())
        with tempfile.TemporaryDirectory(prefix='sentinel_py_') as tmp:
            root = Path(tmp)
            shutil.copytree(FIXTURE / 'data', root / 'data')
            q = dataclasses.replace(load_profile(
                'new', file=FIXTURE / make_sentinel.PROFILE, root=root),
                sticker_masks=None)
            step0.run(q, log=lambda *a: None)
            m2 = np.load(q.saved_path('list_matrices', 'npy'))
            s2 = np.load(q.saved_path('active-contour_all', 'npy'))
            r1 = read_shoes(p.contour_out, 40, 60, 4)
            r2 = read_shoes(q.contour_out, 40, 60, 4)
        self.assertEqual([i + 1 for i in range(6)
                          if not np.array_equal(m2[i], matrices[i])], [6])
        self.assertEqual([i + 1 for i in range(6)
                          if not np.array_equal(s2[i], snakes[i])], [6])
        # record 4 is shoe 6 (shoes 4 and 5 have no record)
        self.assertEqual([k + 1 for k in range(4)
                          if not np.array_equal(r2[k], r1[k])], [4])

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
