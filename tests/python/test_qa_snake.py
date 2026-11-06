"""Snake QA of T4 (plan T4; decisions A-091 to A-096).

Geometry and metrics on synthetic shapes (a disk-shaped "print" and snakes
that enclose it, cut into it, hang loose or cross themselves), the flag
bands, the Python port of the R stamp mask against the committed OLD
data/all_cont.csv, the erase list (format, application, the committed NEW
list), the BLAS-thread guard, forked snakes equal to serial ones (in a
subprocess with one BLAS thread, as the NEW profile runs), and the
committed NEW QA outputs (metrics table, its task copy, the contact sheets,
every flagged shoe resolved). Reads only; temporary files go to a tempfile
folder.
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


class Flags(unittest.TestCase):

    def row(self, **kw):
        base = dict(coverage=1.0, tightness=1.0, self_intersections=0,
                    turning=3.0, max_turn_deg=15.0, n_contour_px=700,
                    touches_border=0, coverage_fill=1.0, rac_coverage=1.0,
                    outside_mask_frac=0.05)
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
        for bad in ('1,0,5,1,5,x\n', '1,5,4,1,5,x\n', '1,1,5,1,256,x\n',
                    '632,1,5,1,5,x\n', '1,1,5,1,5,\n', '1,1,368,1,5,x\n'):
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
        overrides (A-097); the init ellipse stays the 2023 one (A-019)."""
        p = load_profile('new')
        self.assertEqual(p.blas_threads, 1)
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
        self.assertTrue(over and all(v == {'first_closing_radius': 24}
                                     for v in over.values()))
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

    def test_jobs_identical(self):
        """Forked snakes equal serial ones bit for bit (8 NEW shoes, one
        BLAS thread, as the NEW profile runs; a subprocess, because the
        thread count is fixed when numpy loads)."""
        p = load_profile('new')
        if not p.image_path('cleaned_shoes', 0).is_file():
            self.skipTest('no NEW step-0 images (run step 0 first)')
        code = (
            'import json, sys, numpy as np\n'
            'from contour_algorithm import active_contour_snake as acs\n'
            'from contour_algorithm.profiles import load_profile\n'
            'p = load_profile("new")\n'
            'idx = [0, 79, 157, 236, 315, 394, 473, 552]\n'
            'import contour_algorithm.active_contour_snake as m\n'
            'def run(jobs):\n'
            '    m._JOB.update(profile=p, list_contour=None, qa=True)\n'
            '    if jobs == 1:\n'
            '        res = [m._shoe_job(i) for i in idx]\n'
            '    else:\n'
            '        import multiprocessing as mp\n'
            '        with mp.get_context("fork").Pool(jobs) as pool:\n'
            '            res = pool.map(m._shoe_job, idx)\n'
            '    m._JOB.clear()\n'
            '    return res\n'
            'm.save_img = lambda *a, **k: None\n'
            'a, b = run(1), run(4)\n'
            'same = all(np.array_equal(x[0], y[0]) and all(np.array_equal('
            'x[1][k], y[1][k]) for k in ("init", "first", "second"))'
            ' for x, y in zip(a, b))\n'
            'print(json.dumps({"same": bool(same), "threads": '
            'acs.numpy_blas_threads()}))\n')
        env = {**os.environ, 'OPENBLAS_NUM_THREADS': '1',
               'MPLBACKEND': 'Agg', 'PYTHONDONTWRITEBYTECODE': '1'}
        env.pop('RAC_PROFILE_FILE', None)
        out = subprocess.run([sys.executable, '-B', '-c', code], cwd=REPO,
                             env=env, capture_output=True, text=True,
                             timeout=600, check=True).stdout
        got = json.loads(out.strip().splitlines()[-1])
        self.assertEqual(got, {'same': True, 'threads': 1})


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
        task_copy = REPO / 'docs/qa/snake_qa_new.csv'
        self.assertEqual(task_copy.read_bytes(),
                         self.p.prep_path('snake_qa').read_bytes())
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


if __name__ == '__main__':
    unittest.main()
