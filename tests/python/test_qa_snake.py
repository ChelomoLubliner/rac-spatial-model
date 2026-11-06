"""Snake QA of T4 (plan T4; decisions A-091 to A-102).

Geometry and metrics on synthetic shapes (a disk-shaped "print" and snakes
that enclose it, cut into it, hang loose or cross themselves; a RAC and a
speck far outside: the absolute triggers of A-099), the flag bands, the
Python port of the R stamp mask against the committed OLD
data/all_cont.csv, the erase list (format, application, the committed NEW
list), the review file (format, classes, A-101), the command-line refusals
(OLD has no sheets folder and no 2023 file; --jobs needs fork, refused
before step 0 reads its profile), the pruning of stale flagged figures,
the BLAS guard (thread count and kernel, A-108) on every code path that
runs a snake and the kernel getter, forked snakes equal to serial ones
(on the sentinel fixture, in a subprocess with one BLAS thread, as the
NEW profile runs: self-contained, T4 review), and the committed NEW QA
outputs (metrics table, its task copy, the contact sheets, one flagged
figure per flagged shoe, every flagged shoe resolved, 'override' exactly
for the shoes with an override row). Reads only; temporary files go to a
tempfile folder.
"""

import dataclasses
import json
import math
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

from contour_algorithm import active_contour_snake as acs
from contour_algorithm import qa_snake as q
from contour_algorithm import stickers
from contour_algorithm.io_shoes import read_shoes
from contour_algorithm.profiles import load_profile

REPO = Path(__file__).resolve().parents[2]
SHAPE = (120, 90)
FULL = int(np.iinfo(np.uint8).max)


def disk(shape, center, radius):
    rr, cc = np.mgrid[0:shape[0], 0:shape[1]]
    return (rr - center[0]) ** 2 + (cc - center[1]) ** 2 <= radius ** 2


def circle(center, radius, n=400, closed=True):
    """(n, 2) points (row, col) of a circle; closed: the last point repeats
    the first, as the snake's initial ellipse does."""
    s = np.linspace(0, 2 * np.pi, n, endpoint=closed)
    return np.stack([center[0] + radius * np.sin(s),
                     center[1] + radius * np.cos(s)], axis=1)


def contour_of(points, shape):
    """The record a snake gives (drawn polyline, extreme pixels), via the
    step-0 functions with a stand-in profile of that frame."""
    class P:
        W, H = shape[1], shape[0]
    img = np.array(acs.get_snake_image(P, points), dtype=bool)
    out = np.zeros(shape, dtype=bool)
    out[tuple(zip(*acs.get_contour(img)))] = True
    return out


class Geometry(unittest.TestCase):

    def test_polygon_mask_square(self):
        sq = np.array([[10, 10], [10, 29], [29, 29], [29, 10]], float)
        m = q.polygon_mask(sq, SHAPE)
        self.assertEqual(int(m.sum()), 20 * 20)
        self.assertTrue(m[10, 10] and m[29, 29] and not m[30, 20])

    def test_row_span_fill(self):
        c = np.zeros((5, 6), bool)
        c[1, [1, 4]] = True
        c[3, 2] = True
        f = q.row_span_fill(c)
        self.assertEqual(f[1].tolist(), [0, 1, 1, 1, 1, 0])
        self.assertEqual(int(f[3].sum()), 1)
        self.assertEqual(int(f[[0, 2, 4]].sum()), 0)

    def test_convex_hull_area(self):
        L = np.zeros((40, 40), bool)
        L[5:35, 5:12] = True
        L[28:35, 5:35] = True
        hull = q.convex_hull_area(L)
        self.assertGreater(hull, L.sum())
        self.assertLessEqual(hull, 30 * 30 + 4 * 30)
        self.assertEqual(q.convex_hull_area(np.zeros((5, 5), bool)), 0)

    def test_self_intersections(self):
        self.assertEqual(q.self_intersections(circle((60, 45), 30)), 0)
        t = np.linspace(0, 2 * np.pi, 200, endpoint=False)
        eight = np.stack([60 + 30 * np.sin(2 * t), 45 + 30 * np.sin(t)], 1)
        self.assertEqual(q.self_intersections(eight), 1)
        # a loop: the snake doubles back across itself twice
        loop = np.array([[0, 0], [0, 10], [10, 10], [10, 4], [-3, 4],
                         [-3, 0]], float)
        self.assertEqual(q.self_intersections(loop), 1)

    def test_turning(self):
        tot, mx = q.turning(circle((60, 45), 30))
        self.assertAlmostEqual(tot, 1.0, places=6)
        self.assertLess(mx, 1.5)
        sq = np.array([[0, 0], [0, 10], [10, 10], [10, 0]], float)
        tot, mx = q.turning(sq)
        self.assertAlmostEqual(tot, 1.0)
        self.assertAlmostEqual(mx, 90.0)
        zig = circle((60, 45), 30, n=200, closed=False)
        zig[::2] *= 1.02
        self.assertGreater(q.turning(zig)[0], 2.0)


class Metrics(unittest.TestCase):

    def setUp(self):
        self.print_ = disk(SHAPE, (60, 45), 25)
        self.mask = disk(SHAPE, (60, 45), 40)

    def metrics(self, snake, racs=()):
        return q.snake_metrics(self.print_, contour_of(snake, SHAPE),
                               self.mask, snake, racs)

    def test_enclosing_snake_passes_coverage(self):
        m = self.metrics(circle((60, 45), 27), racs=[(60, 45), (40, 45)])
        self.assertEqual(m['coverage'], 1.0)
        self.assertEqual(m['coverage_fill'], 1.0)
        self.assertEqual(m['rac_coverage'], 1.0)
        self.assertEqual(m['self_intersections'], 0)
        self.assertEqual(m['touches_border'], 0)
        self.assertAlmostEqual(m['tightness'], (27 / 25) ** 2, delta=0.05)
        self.assertLess(m['gap_max_px'], 3.5)
        self.assertEqual(m['cut_max_px'], 0.0)

    def test_cutting_snake_loses_coverage(self):
        m = self.metrics(circle((60, 45), 18), racs=[(60, 45), (36, 45)])
        self.assertLess(m['coverage'], 0.6)
        self.assertGreater(m['cut_max_px'], 5)
        self.assertEqual(m['rac_coverage'], 0.5)
        self.assertIn('coverage', q.flag_shoe(m))

    def test_loose_snake_is_not_tight(self):
        m = self.metrics(circle((60, 45), 33))
        self.assertGreater(m['tightness'], 1.15)
        self.assertGreater(m['gap_mean_px'], 7)
        self.assertIn('tightness', q.flag_shoe(m))

    def test_border_and_mask(self):
        m = self.metrics(circle((60, 45), 44.6))
        self.assertEqual(m['touches_border'], 1)
        self.assertEqual(m['outside_mask_frac'], 1.0)

    def test_absolute_triggers(self):
        """A RAC 3 px or more outside the record fill, or contact more than
        8 px outside it, flags the shoe although the share bands pass
        (A-099; the review's case: one RAC of a RAC-rich shoe). The small
        synthetic contour breaks the contour-length band, so only the
        bands named here are read."""
        def flags(m):
            return set(q.flag_shoe(m).split(';')) & {
                'rac_out_max_px', 'contact_out_max_px', 'rac_coverage',
                'coverage'}
        snake = circle((60, 45), 27)
        fill = q.row_span_fill(contour_of(snake, SHAPE))
        top = int(np.flatnonzero(fill[:, 45]).min())  # middle column
        inside = [(60 + dr, 45 + dc) for dr in range(-10, 11, 2)
                  for dc in range(-10, 11, 5)]  # 55 RACs inside
        m = self.metrics(snake, racs=inside + [(top - 2, 45)])
        self.assertEqual(m['rac_out_max_px'], 2.0)
        self.assertEqual(flags(m), set())
        m = self.metrics(snake, racs=inside + [(top - 3, 45)])
        self.assertEqual(m['rac_out_max_px'], 3.0)
        self.assertGreater(m['rac_coverage'], 0.9696)
        self.assertEqual(flags(m), {'rac_out_max_px'})
        # an isolated contact speck 9 px above the fill
        speck = self.print_.copy()
        speck[top - 9, 45] = True
        m = q.snake_metrics(speck, contour_of(snake, SHAPE), self.mask,
                            snake, inside)
        self.assertEqual(m['contact_out_max_px'], 9.0)
        self.assertGreater(m['coverage'], 0.99)
        self.assertEqual(flags(m), {'contact_out_max_px'})
        # no RAC: undefined, not a flag
        m = self.metrics(snake)
        self.assertTrue(math.isnan(m['rac_out_max_px']))
        self.assertEqual(m['contact_out_max_px'], 0.0)
        self.assertEqual(flags(m), set())


class Flags(unittest.TestCase):

    def row(self, **kw):
        base = dict(coverage=1.0, tightness=1.0, self_intersections=0,
                    turning=3.0, max_turn_deg=15.0, n_contour_px=700,
                    touches_border=0, coverage_fill=1.0, rac_coverage=1.0,
                    outside_mask_frac=0.05, rac_out_max_px=0.0,
                    contact_out_max_px=0.0)
        base.update(kw)
        return base

    def test_bands(self):
        self.assertEqual(q.flag_shoe(self.row()), '')
        self.assertEqual(q.flag_shoe(self.row(coverage=0.9899)), 'coverage')
        self.assertEqual(q.flag_shoe(self.row(tightness=1.151)), 'tightness')
        self.assertEqual(q.flag_shoe(self.row(tightness=0.904)), 'tightness')
        self.assertEqual(q.flag_shoe(self.row(tightness=0.93)), '')
        self.assertEqual(q.flag_shoe(self.row(self_intersections=1)),
                         'self_intersections')
        self.assertEqual(q.flag_shoe(self.row(n_contour_px=552,
                                              touches_border=1)),
                         'n_contour_px;touches_border')
        self.assertEqual(q.flag_shoe(self.row(coverage=float('nan'))),
                         'coverage')
        # a shoe without RACs has no RAC coverage: not a flag
        self.assertEqual(q.flag_shoe(self.row(rac_coverage=float('nan'))),
                         '')
        # the absolute triggers (A-099): >= 3 px for a RAC, > 8 px for
        # contact (EDT distances are square roots of integers)
        self.assertEqual(q.flag_shoe(self.row(rac_out_max_px=2.8284)), '')
        self.assertEqual(q.flag_shoe(self.row(rac_out_max_px=3.0)),
                         'rac_out_max_px')
        self.assertEqual(q.flag_shoe(self.row(contact_out_max_px=8.0)), '')
        self.assertEqual(q.flag_shoe(self.row(contact_out_max_px=8.0623)),
                         'contact_out_max_px')
        self.assertEqual(q.flag_shoe(self.row(rac_out_max_px=float('nan'))),
                         '')

    def test_bands_come_from_the_old_reference(self):
        """The OLD percentiles in BANDS are those of the committed OLD
        reference table (A-093)."""
        old = pd.read_csv(REPO / 'docs/qa/T4/old/snake_metrics.csv')
        bands = {name: (lo, hi) for name, lo, hi in q.BANDS}
        # the table rounds max_turn_deg to 2 decimals, the others to 4
        for name, p, side, tol in (('coverage_fill', 0.01, 0, 2e-4),
                                   ('rac_coverage', 0.01, 0, 2e-4),
                                   ('outside_mask_frac', 0.99, 1, 2e-4),
                                   ('tightness', 0.01, 0, 2e-4),
                                   ('turning', 0.99, 1, 2e-4),
                                   ('max_turn_deg', 0.99, 1, 1e-2)):
            with self.subTest(metric=name):
                self.assertAlmostEqual(bands[name][side],
                                       float(np.quantile(old[name], p)),
                                       delta=tol)


class RStampMask(unittest.TestCase):

    def test_old_equals_committed_all_cont(self):
        p = load_profile('old')
        raw = read_shoes(p.contacts, p.W, p.H, p.num_shoe)
        for shoe in p.r['contact_flip_shoes']:
            raw[shoe - 1] = raw[shoe - 1][:, ::-1]
        m = q.r_stamp_mask(raw, p.r['stamp_threshold'],
                           p.r['stamp_sweep_bound'])
        ref = np.loadtxt(REPO / 'data/all_cont.csv', delimiter=',',
                         skiprows=1) > 0
        self.assertTrue(np.array_equal(m, ref))


class Stickers(unittest.TestCase):

    def profile_with(self, text):
        tmp = tempfile.TemporaryDirectory(prefix='stickers_')
        self.addCleanup(tmp.cleanup)
        f = Path(tmp.name) / 's.csv'
        f.write_text(text)
        return dataclasses.replace(load_profile('new'), sticker_masks=f)

    def test_old_has_none(self):
        p = load_profile('old')
        self.assertIsNone(p.sticker_masks)
        self.assertEqual(len(stickers.read_sticker_masks(p)), 0)

    def test_validation(self):
        head = 'shoe,row0,row1,col0,col1,reason\n'
        p = load_profile('new')
        # one past the frame and the shoe count, from the profile
        w1, h1, n1 = p.W + 1, p.H + 1, p.num_shoe + 1
        for bad in ('1,0,5,1,5,x\n', '1,5,4,1,5,x\n', f'1,1,5,1,{w1},x\n',
                    f'{n1},1,5,1,5,x\n', '1,1,5,1,5,\n', f'1,1,{h1},1,5,x\n'):
            with self.subTest(row=bad):
                with self.assertRaises(ValueError):
                    stickers.read_sticker_masks(self.profile_with(head + bad))
        with self.assertRaises(ValueError):
            stickers.read_sticker_masks(self.profile_with(
                'shoe,r0,r1,c0,c1,reason\n1,1,5,1,5,x\n'))

    def test_apply(self):
        shoes = np.ones((3, 6, 5), bool)
        t = pd.DataFrame({'shoe': [2, 2], 'row0': [1, 6], 'row1': [2, 6],
                          'col0': [2, 1], 'col1': [3, 5],
                          'reason': ['a', 'b']})
        out, erased = stickers.apply_sticker_masks(shoes, t)
        self.assertEqual(erased, [4, 5])
        self.assertTrue(shoes.all())  # the input is not changed
        self.assertEqual(int((~out[1]).sum()), 9)
        self.assertFalse(out[1, 0, 1] or out[1, 1, 2] or out[1, 5, 4])
        self.assertTrue(out[0].all() and out[2].all())

    def test_new_list(self):
        """The committed NEW list is valid, every rectangle erases contact
        pixels, and none erases a RAC pixel (a mark that carries a RAC
        would be sole)."""
        p = load_profile('new')
        t = stickers.read_sticker_masks(p)
        self.assertGreater(len(t), 0)
        raw = read_shoes(p.contacts, p.W, p.H, p.num_shoe)
        _, erased = stickers.apply_sticker_masks(raw, t)
        self.assertTrue(all(e > 0 for e in erased), erased)
        racs = q.rac_pixels(p)
        for r in t.itertuples(index=False):
            rc = racs.get(r.shoe, np.zeros((0, 2), int))
            inside = ((rc[:, 0] >= r.row0 - 1) & (rc[:, 0] <= r.row1 - 1)
                      & (rc[:, 1] >= r.col0 - 1) & (rc[:, 1] <= r.col1 - 1))
            with self.subTest(shoe=r.shoe, rows=(r.row0, r.row1)):
                self.assertFalse(inside.any())


class Profiles(unittest.TestCase):
    """T4 values reach only the NEW profile (user rules 1 and 2)."""

    def test_old_keeps_the_legacy_snake(self):
        sp = load_profile('old').snake
        self.assertEqual((sp.first_closing_radius, sp.first_gaussian_sigma),
                         (0, None))
        p = load_profile('old')
        self.assertIsNone(p.blas_threads)
        self.assertIsNone(p.blas_kernel)
        self.assertIsNone(p.snake_overrides)
        self.assertEqual(acs.snake_overrides(p), {})
        self.assertIs(acs.snake_params(p, 9), p.snake)
        img = np.zeros((10, 10), np.uint8)
        self.assertIs(acs.first_snake_image(sp, img), img)
        self.assertEqual(acs.first_sigma(sp), sp.gaussian_sigma)

    def test_new_values(self):
        """The T4 decisions reach the NEW profile: one BLAS thread (A-092),
        closing radius 10 for the first snake (A-094), the erase list
        (A-095), the mask from >= 18 shoes (A-096), the per-shoe
        overrides (A-097, A-102, A-107), the kernel of the committed
        contour (A-108); the init ellipse stays the 2023 one (A-019)."""
        p = load_profile('new')
        self.assertEqual(p.blas_threads, 1)
        self.assertEqual(p.blas_kernel, 'Haswell')
        self.assertEqual(p.superpose_threshold, 18)
        self.assertEqual(p.snake.first_closing_radius, 10)
        self.assertIsNone(p.snake.first_gaussian_sigma)
        self.assertEqual((p.snake.center_rc, p.snake.radii_rc),
                         ((185, 128), (162, 95)))
        self.assertEqual(p.sticker_masks,
                         REPO / 'data/new_shoes/sticker_masks_new.csv')
        self.assertEqual(p.snake_overrides,
                         REPO / 'data/new_shoes/snake_overrides_new.csv')
        over = acs.snake_overrides(p)
        # closing radius 24, or 16 where 24 breaks another band (A-097,
        # A-102); one shoe starts from its own ellipse, 170, whose heel-pad
        # rim lies beyond the profile ellipse (A-107)
        radius_only = {s: v for s, v in over.items() if s != 170}
        self.assertTrue(radius_only and all(
            set(v) == {'first_closing_radius'}
            and v['first_closing_radius'] in (16, 24)
            for v in radius_only.values()))
        self.assertEqual(over[165], {'first_closing_radius': 16})
        self.assertEqual(over[170], {'center_rc': (187.0, 127.0),
                                     'radii_rc': (167.0, 98.0)})
        sp170 = acs.snake_params(p, 170)
        self.assertEqual((sp170.first_closing_radius, sp170.center_rc,
                          sp170.radii_rc), (10, (187.0, 127.0), (167.0, 98.0)))
        self.assertEqual(acs.snake_params(p, min(over)).first_closing_radius,
                         24)
        self.assertEqual(acs.snake_params(p, None), p.snake)
        self.assertEqual(p.prep_path('sheets_dir'),
                         REPO / 'docs/qa/sheets_new')

    def test_closing_merges_elements(self):
        """With a closing radius the first snake sees separate elements as
        one silhouette; its outer edge does not move."""
        img = np.zeros((60, 60), np.uint8)
        img[20:30, 10:25] = FULL
        img[20:30, 29:44] = FULL  # a 4-px gap between two pads
        sp = load_profile('new').snake
        out = acs.first_snake_image(sp, img) > 0
        self.assertTrue(out[25, 26])
        self.assertTrue(np.array_equal(out[:, :10], img[:, :10] > 0))
        self.assertFalse(out[19].any() or out[30].any())
        # near the image border too (the closing pads with background):
        # a pad 3 px from the top edge gains nothing above it
        edge = np.zeros((60, 60), np.uint8)
        edge[3:13, 20:40] = FULL
        self.assertTrue(np.array_equal(acs.first_snake_image(sp, edge) > 0,
                                       edge > 0))


class Overrides(unittest.TestCase):

    def profile_with(self, text):
        tmp = tempfile.TemporaryDirectory(prefix='overrides_')
        self.addCleanup(tmp.cleanup)
        f = Path(tmp.name) / 'o.csv'
        f.write_text(text)
        return dataclasses.replace(load_profile('new'), snake_overrides=f)

    def test_values_and_validation(self):
        head = ','.join(acs.OVERRIDE_COLUMNS) + '\n'
        p = self.profile_with(head + '3,12,,,,,a\n5,,180,120,140,90,b\n')
        self.assertEqual(acs.snake_overrides(p), {
            3: {'first_closing_radius': 12},
            5: {'center_rc': (180.0, 120.0), 'radii_rc': (140.0, 90.0)}})
        init = acs.init_snake(p, shoe=5)
        self.assertAlmostEqual(init[:, 0].min(), 40.0, places=2)
        self.assertTrue(np.array_equal(acs.init_snake(p, shoe=3),
                                       acs.init_snake(p)))
        for bad in ('3,12,,,,,\n', '3,-1,,,,,a\n', '3,1.5,,,,,a\n',
                    '3,,180,120,,,a\n', '3,,,,,,a\n',
                    '3,2,,,,,a\n3,4,,,,,b\n', '999,2,,,,,a\n'):
            with self.subTest(row=bad):
                with self.assertRaises(ValueError):
                    acs.snake_overrides(self.profile_with(head + bad))


class Blas(unittest.TestCase):

    def test_guard(self):
        threads = acs.numpy_blas_threads()
        self.assertIsInstance(threads, int)
        old, new = load_profile('old'), load_profile('new')
        self.assertEqual(acs.check_blas_threads(old), threads)
        if threads == new.blas_threads:
            self.assertEqual(acs.check_blas_threads(new), threads)
        else:
            with self.assertRaises(RuntimeError):
                acs.check_blas_threads(new)

    def test_corename(self):
        """The OpenBLAS kernel numpy chose (logged by step 0, A-092): a
        non-empty name, or None where the getter is missing."""
        name = acs.numpy_blas_corename()
        self.assertTrue(name is None or (isinstance(name, str) and name))

    def test_kernel_guard(self):
        """A profile that fixes a kernel (python.blas_kernel, A-108) is
        refused under another one, with the reason; NEW fixes the kernel
        of its committed contour, OLD none (its gate checks the
        baselines' kernel)."""
        new, old = load_profile('new'), load_profile('old')
        self.assertIsNone(old.blas_kernel)
        self.assertEqual(new.blas_kernel, 'Haswell')
        threads = acs.numpy_blas_threads()
        loose = dataclasses.replace(new, blas_threads=None)
        name = acs.numpy_blas_corename()
        if name is not None:
            self.assertEqual(acs.check_blas_threads(
                dataclasses.replace(loose, blas_kernel=name)), threads)
        with self.assertRaisesRegex(RuntimeError, 'kernel'):
            acs.check_blas_threads(dataclasses.replace(
                loose, blas_kernel='NoSuchKernel'))

    def test_every_snake_path_is_checked(self):
        """The prototype snake (step 0a, the threshold study), the shoe
        snake and step 0's run() check the profile's thread count before
        a snake runs or anything is written (second T4 review: the
        prototype snake of step 0a ran unchecked)."""
        from unittest import mock
        from contour_algorithm import main as step0
        wrong = dataclasses.replace(load_profile('new'), blas_threads=999)
        with mock.patch.object(acs, 'active_contour',
                               side_effect=AssertionError('a snake ran')):
            with self.assertRaisesRegex(RuntimeError, '999'):
                acs.prototype_mask_from(
                    wrong, np.zeros((wrong.H, wrong.W), np.uint8))
            with self.assertRaisesRegex(RuntimeError, '999'):
                acs.active_contour_shoe(wrong, None, False, False, 0)
            with tempfile.TemporaryDirectory(prefix='blas_') as tmp:
                p = dataclasses.replace(
                    wrong, root=Path(tmp), images_dir=Path(tmp) / 'img_new',
                    contour_out=Path(tmp) / 'out_new' / 'c_new.txt')
                with self.assertRaisesRegex(RuntimeError, '999'):
                    step0.run(p, log=lambda *a: None)
                self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_cli_refuses_another_kernel(self):
        """python -m contour_algorithm.main refuses (exit 2, the reason on
        stderr) to run snake steps under a kernel that the profile does
        not fix, before step 0 starts (A-108)."""
        import contextlib
        import io
        from unittest import mock
        from contour_algorithm import main as step0
        other = dataclasses.replace(load_profile('new'), blas_threads=None,
                                    blas_kernel='NoSuchKernel')
        err = io.StringIO()
        with mock.patch.dict(os.environ, {'RAC_DATASET': 'new'}), \
                mock.patch.object(step0, 'load_profile',
                                  return_value=other), \
                mock.patch.object(step0, 'run', side_effect=AssertionError(
                    'step 0 must not start')), \
                contextlib.redirect_stderr(err):
            os.environ.pop('RAC_PROFILE_FILE', None)
            self.assertEqual(step0.main(['--steps', 'snake']), 2)
        self.assertIn('NoSuchKernel', err.getvalue())

    def test_jobs_identical(self):
        """Forked snakes equal serial ones bit for bit, on the sentinel
        fixture (step 0a-0b in a temporary root, then the 6 shoe snakes
        with jobs 1 and 3), with one BLAS thread as the NEW profile runs;
        a subprocess, because the thread count is fixed when numpy loads.
        Self-contained: it needs no step-0 output of the work tree (T4
        review; it used to skip in a fresh checkout)."""
        code = (
            'import json, sys, shutil\n'
            'from pathlib import Path\n'
            'import numpy as np\n'
            'from contour_algorithm import active_contour_snake as m\n'
            'from contour_algorithm import main as step0\n'
            'from contour_algorithm.profiles import load_profile\n'
            'fixture, root = Path(sys.argv[1]), Path(sys.argv[2])\n'
            'shutil.copytree(fixture / "data", root / "data")\n'
            'p = load_profile("new", file=fixture / "sentinel_profile.json",'
            ' root=root)\n'
            'step0.run(p, steps=("create", "contour"), log=lambda *a: None)\n'
            'm.save_img = lambda *a, **k: None\n'
            'lc = np.load(p.saved_path("list_contour", "npy"))\n'
            'a = m.run_snakes(p, lc, jobs=1, qa=True)\n'
            'b = m.run_snakes(p, lc, jobs=3, qa=True)\n'
            'same = all(np.array_equal(x, y) for x, y in zip(a[0], b[0]))\n'
            'same = same and all(np.array_equal(x[k], y[k]) for x, y in '
            'zip(a[1], b[1]) for k in ("init", "first", "second"))\n'
            'print(json.dumps({"same": bool(same), "n": len(a[0]), '
            '"threads": m.numpy_blas_threads()}))\n')
        env = {**os.environ, 'OPENBLAS_NUM_THREADS': '1',
               'MPLBACKEND': 'Agg', 'PYTHONDONTWRITEBYTECODE': '1',
               'TQDM_DISABLE': '1'}
        env.pop('RAC_PROFILE_FILE', None)
        with tempfile.TemporaryDirectory(prefix='jobs_') as tmp:
            out = subprocess.run(
                [sys.executable, '-B', '-c', code,
                 str(REPO / 'tests/fixtures/sentinel'), tmp], cwd=REPO,
                env=env, capture_output=True, text=True, timeout=600,
                check=True).stdout
        got = json.loads(out.strip().splitlines()[-1])
        self.assertEqual(got, {'same': True, 'n': 6, 'threads': 1})


class Review(unittest.TestCase):
    """The review file (read_review, A-101)."""

    def profile_with(self, text):
        tmp = tempfile.TemporaryDirectory(prefix='review_')
        self.addCleanup(tmp.cleanup)
        (Path(tmp.name) / 'qa').mkdir()
        (Path(tmp.name) / 'qa' / 'snake_review_new.csv').write_text(text)
        p = load_profile('new')
        prep = dict(p.prep)
        prep['snake_qa_dir'] = 'qa'
        return dataclasses.replace(p, root=Path(tmp.name), prep=prep)

    def test_valid_and_invalid(self):
        head = 'shoe,resolution,review_class,note\n'
        ok = self.profile_with(head + '3,ok_after_review,,a note here\n'
                               '5,,partial_print,another note\n')
        review = q.read_review(ok)
        self.assertEqual(list(review.index), [3, 5])
        table = pd.DataFrame({'shoe': [3, 4, 5], 'qa_flags': ['x', '', '']})
        merged = q.with_review(ok, table)
        self.assertEqual(merged['resolution'].tolist(),
                         ['ok_after_review', '', ''])
        self.assertEqual(merged['review_class'].tolist(),
                         ['', '', 'partial_print'])
        for bad in (head + '3,maybe,,a note\n',          # resolution
                    head + '3,,blurry,a note\n',         # class
                    head + '3,,,a note\n',               # neither
                    head + '3,ok_after_review,,\n',      # no note
                    head + '3,ok_after_review,,a\n3,,spike,b\n',
                    'shoe,resolution,note\n3,ok_after_review,a\n'):
            with self.subTest(text=bad):
                with self.assertRaises(ValueError):
                    q.read_review(self.profile_with(bad))


class CommandLine(unittest.TestCase):
    """The refusals of qa_snake.main (T4 review)."""

    def args(self, **kw):
        import argparse
        base = dict(sheets=False, thresholds=None, crosscheck=False, jobs=1)
        base.update(kw)
        return argparse.Namespace(**base)

    def test_old_has_no_sheets_folder(self):
        old = load_profile('old')
        self.assertIsNone(old.prep_path('sheets_dir'))
        self.assertIsNone(q.task_copy_path(old))
        self.assertIn('--sheets needs',
                      q.refusal(old, self.args(sheets=True)))
        self.assertIn('--thresholds needs',
                      q.refusal(old, self.args(thresholds='18,29')))
        self.assertIn('--sheets and --thresholds need ', q.refusal(
            old, self.args(sheets=True, thresholds='18')))
        self.assertEqual(q.refusal(old, self.args()), '')
        new = load_profile('new')
        self.assertEqual(q.refusal(new, self.args(sheets=True,
                                                  thresholds='18')), '')
        self.assertEqual(q.task_copy_path(new),
                         REPO / 'docs/qa/sheets_new/snake_qa_new.csv')

    def test_crosscheck_needs_the_2023_file(self):
        """--crosscheck is refused before anything is written when the
        profile has no 2023 file (OLD), not after --metrics wrote (second
        T4 review)."""
        old, new = load_profile('old'), load_profile('new')
        self.assertIsNone(old.cross_check)
        self.assertIn('--crosscheck needs',
                      q.refusal(old, self.args(crosscheck=True)))
        self.assertEqual(q.refusal(new, self.args(crosscheck=True)), '')

    def test_jobs_need_fork(self):
        """--jobs > 1 is refused where fork is missing. step 0's main must
        refuse before it reads the profile or runs anything: both are
        mocked to fail, so a missing guard fails here and writes nothing
        (second T4 review: it used to run NEW step 0a-0b in the work
        tree)."""
        import contextlib
        import io
        import multiprocessing
        from unittest import mock
        new = load_profile('new')
        with mock.patch.object(multiprocessing, 'get_all_start_methods',
                               return_value=['spawn']):
            self.assertIn('fork', q.refusal(new, self.args(jobs=2)))
            self.assertEqual(q.refusal(new, self.args(jobs=1)), '')
            with self.assertRaises(RuntimeError):
                acs.run_snakes(new, [None, None], jobs=2)
            from contour_algorithm import main as step0
            err = io.StringIO()
            with mock.patch.dict(os.environ, {'RAC_DATASET': 'new'}), \
                    mock.patch.object(step0, 'load_profile',
                                      side_effect=AssertionError(
                                          'the profile must not be read')), \
                    mock.patch.object(step0, 'run', side_effect=AssertionError(
                        'step 0 must not run')), \
                    contextlib.redirect_stderr(err):
                os.environ.pop('RAC_PROFILE_FILE', None)
                self.assertEqual(step0.main(['--jobs', '2']), 2)
            self.assertIn('fork', err.getvalue())

    def test_prune_flagged(self):
        """--flagged removes the figures of shoes that are no longer
        flagged, and only files named like a per-shoe image of the
        dataset."""
        with tempfile.TemporaryDirectory(prefix='flagged_') as tmp:
            folder = Path(tmp)
            for name in ('im_7_new.png', 'im_163_new.png', 'im_9.png',
                         'notes.txt', 'im_x_new.png'):
                (folder / name).write_bytes(b'x')
            self.assertEqual(q.prune_flagged(folder, ['im_7_new.png'],
                                             '_new'), ['im_163_new.png'])
            self.assertEqual(sorted(f.name for f in folder.iterdir()),
                             ['im_7_new.png', 'im_9.png', 'im_x_new.png',
                              'notes.txt'])
            self.assertEqual(q.prune_flagged(folder / 'none', [], '_new'),
                             [])


class Files(unittest.TestCase):
    """The committed NEW QA outputs."""

    def setUp(self):
        self.p = load_profile('new')
        self.table = pd.read_csv(self.p.prep_path('snake_qa'),
                                 keep_default_na=False)

    def test_complete(self):
        t = self.table
        self.assertEqual(t['shoe'].tolist(), list(self.p.analysis_shoes()))
        self.assertEqual(t['record'].tolist(),
                         list(range(1, len(t) + 1)))
        # the task's name, in the NEW sheets folder (user rule 1), written
        # by qa_snake --metrics (A-104)
        task_copy = q.task_copy_path(self.p)
        self.assertEqual(task_copy.parent, self.p.prep_path('sheets_dir'))
        self.assertEqual(task_copy.read_bytes(),
                         self.p.prep_path('snake_qa').read_bytes())
        self.assertFalse((REPO / 'docs/qa/snake_qa_new.csv').exists())
        per = q.SHEET_COLUMNS * q.SHEET_ROWS
        n_sheets = math.ceil(len(t) / per)
        folder = self.p.prep_path('sheets_dir')
        for kind in q.SHEET_KINDS:
            with self.subTest(kind=kind):
                names = sorted(f.name for f in (folder / kind).glob(
                    f'{kind}_sheet_*_new.png'))
                self.assertEqual(names, [
                    f'{kind}_sheet_{k:02d}_new.png'
                    for k in range(1, n_sheets + 1)])

    def test_flagged_figures(self):
        """The flagged folder holds exactly one figure per flagged shoe,
        im_<shoe - 1>_new.png (--flagged prunes the figures of shoes that
        are no longer flagged; second T4 review)."""
        folder = self.p.prep_path('snake_qa_dir') / 'flagged'
        flagged = self.table.loc[self.table['qa_flags'] != '', 'shoe']
        want = sorted(self.p.image_path('qa_snake', int(s) - 1).name
                      for s in flagged)
        self.assertTrue(want)
        self.assertEqual(sorted(f.name for f in folder.iterdir()), want)

    def test_flags_match_the_bands(self):
        """qa_flags is what flag_shoe gives on the stored (rounded)
        metrics (rounding to 4 decimals cannot cross a band here)."""
        for row in self.table.to_dict('records'):
            with self.subTest(shoe=row['shoe']):
                self.assertEqual(row['qa_flags'], q.flag_shoe(row))

    def test_crosscheck_reproduces(self):
        """The committed 2023 cross-check table is what crosscheck_2023
        gives on the committed contour (needs no step-0 images)."""
        p = self.p
        run = {'shoes': p.analysis_shoes(),
               'records': read_shoes(p.contour_out, p.W, p.H,
                                     len(p.analysis_shoes()))}
        got = q.crosscheck_2023(p, run).round(3)
        want = pd.read_csv(q.snake_qa_path(p, 'crosscheck_2023', 'csv'))
        pd.testing.assert_frame_equal(got.reset_index(drop=True), want,
                                      check_dtype=False)
        self.assertEqual(int(got['n_rac'].sum()), 20013)

    def test_all_flags_resolved(self):
        """Every flagged shoe has a resolution in RESOLUTIONS and a note
        (plan T4 test_qa_snake.Flags.test_all_flags_resolved)."""
        t = self.table
        flagged = t[t['qa_flags'] != '']
        for row in flagged.to_dict('records'):
            with self.subTest(shoe=row['shoe']):
                self.assertIn(row['resolution'], q.RESOLUTIONS[1:])
                self.assertGreater(len(str(row['note']).strip()), 10)
        passed = t[t['qa_flags'] == '']
        self.assertTrue((passed['resolution'] == '').all())
        # a flagged shoe is resolved as 'override' exactly when it has a
        # row in the override file (second T4 review)
        over = set(acs.snake_overrides(self.p))
        for row in flagged.to_dict('records'):
            with self.subTest(shoe=row['shoe'], check='override row'):
                self.assertEqual(row['resolution'] == 'override',
                                 row['shoe'] in over)
        # every listed shoe is a NEW shoe; the classes are known (A-101)
        review = q.read_review(self.p)
        self.assertTrue(set(review.index) <= set(self.p.analysis_shoes()))
        self.assertTrue(set(t['review_class']) <= set(q.REVIEW_CLASSES))


if __name__ == '__main__':
    unittest.main()
