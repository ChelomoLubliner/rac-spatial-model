"""Pixel calibration (plan T3; decisions A-086, A-087).

Committed results: the OLD and NEW calibration tables
(prep.pixel_calibration, prep.calibration_grid) are recomputed where it is
cheap: hits at the named settings and at sampled grid rows by direct
evaluation (which checks the vectorized grid), the 200 bootstrap draws of
Delta bit for bit, the percentile intervals, the per-dataset conditions and
the rule of A-086. The literal reading "the OLD argmax is exactly 300 on
both axes" does not hold (OLD stage F strict: sy = 301; A-087), so the OLD
test asserts what A-086 asks: the orientation, the stage-C optimum at s0,
the stage-F optimum in the band, and the recorded conditions.

Synthetic data (RACs placed on contact pixels of real NEW records with a
known mapping): the search recovers a non-legacy mapping exactly and the
rule then fails its band condition; RACs placed with the legacy scale give
a Delta upper bound below the margin (the plan's check); a non-mirrored
placement is found by stage O; two runs are identical. The synthetic tests
use a thinned-out grid (small_grids) for speed; the committed-result tests
check the pre-registered grid.
"""

import contextlib
import dataclasses
import io
import os
import unittest
from unittest import mock

import numpy as np
import pandas as pd

from contour_algorithm import calibrate_pixels as cp
from contour_algorithm.profiles import load_profile


def summary_dict(rows):
    return {(s, n): cp._value_text(v) for s, n, v in rows}


def committed(ds):
    p = load_profile(ds)
    return (p, cp.read_summary(p.prep_path('pixel_calibration')),
            pd.read_csv(p.prep_path('calibration_grid')))


def setting(summary, name):
    def get(key):
        return summary[('setting', f'{name}.{key}')]
    return cp.Setting(float(get('sx')), float(get('sy')), float(get('dc')),
                      float(get('dr')), get('mirror_x') == 'True',
                      get('flip_y') == 'True')


class CommittedBase:
    """Checks shared by the OLD and NEW committed calibrations."""
    ds = None

    @classmethod
    def setUpClass(cls):
        cls.p, cls.s, cls.grid = committed(cls.ds)
        cls.data = cp.load_dataset(cls.p)
        cls.s0 = cp.px_per_unit(cls.p.coords)
        cls.centre = cp.legacy_center(cls.p.coords, cls.p.W, cls.p.H)

    def hits(self, setting, dilated=False):
        x, y = self.data['x'], self.data['y']
        c, r = setting.pixels(x, y, *self.centre)
        images = self.data['dilated' if dilated else 'contacts']
        return int(cp.hits_at(images, self.data['shoe'] - 1, c, r).sum())

    def test_orientation_and_coarse_stage(self):
        g = self.grid
        o = g[(g.stage == 'O') & (g.criterion == 'strict')]
        best = o.groupby(['mirror_x', 'flip_y'])['rate'].max()
        self.assertEqual(best.idxmax(), (True, False))
        others = best.drop((True, False))
        self.assertGreater(best[(True, False)] - others.max(), 0.25)
        c = g[(g.stage == 'C') & (g.criterion == 'strict')]
        top = c.iloc[0]
        self.assertEqual((top.sx, top.sy), self.s0)
        self.assertEqual((top.dc, top.dr), (0.0, 0.0))

    def test_fine_stage_in_band(self):
        for crit in ('strict', 'dilated'):
            opt = setting(self.s, f'optimum_{crit}')
            with self.subTest(criterion=crit):
                self.assertTrue(opt.mirror_x and not opt.flip_y)
                self.assertLessEqual(abs(opt.sx - self.s0[0]),
                                     cp.BAND_HALF_WIDTH)
                self.assertLessEqual(abs(opt.sy - self.s0[1]),
                                     cp.BAND_HALF_WIDTH)
                self.assertLessEqual(max(abs(opt.dc), abs(opt.dr)), 1.0)
                self.assertEqual(
                    self.s[('conditions', f'{crit}.optimum_in_band')],
                    'True')

    def test_named_settings_recomputed(self):
        n = len(self.data['x'])
        self.assertEqual(int(self.s[('meta', 'n_rac')]), n)
        for name in ('optimum_strict', 'best_s0_strict', 'optimum_dilated',
                     'best_s0_dilated', 'grid_legacy'):
            st = setting(self.s, name)
            with self.subTest(setting=name):
                self.assertEqual(self.hits(st),
                                 int(self.s[('setting', f'{name}.hits')]))
                self.assertEqual(
                    self.hits(st, dilated=True),
                    int(self.s[('setting', f'{name}.hits_dil')]))
        lc, lr = cp.legacy_pixel(self.data['x'], self.data['y'],
                                 self.p.coords, self.p.W, self.p.H)
        hits = cp.hits_at(self.data['contacts'], self.data['shoe'] - 1,
                          lc - 1, lr - 1)
        self.assertEqual(int(hits.sum()),
                         int(self.s[('setting', 'legacy_aspix.hits')]))

    def test_grid_rows_recomputed(self):
        """The vectorized grid against a direct evaluation: the best row
        of every stage and criterion and 12 random rows (seed 4)."""
        g = self.grid
        rows = [g[(g.stage == st) & (g.criterion == cr)].iloc[0]
                for st in ('O', 'C', 'F') for cr in ('strict', 'dilated')]
        pick = np.random.default_rng(4).choice(len(g), 12, replace=False)
        rows += [g.iloc[k] for k in pick]
        for row in rows:
            st = cp.setting_of(row)
            with self.subTest(row=str(st), criterion=row.criterion):
                self.assertEqual(
                    self.hits(st, dilated=row.criterion == 'dilated'),
                    int(row.hits))

    def test_bootstrap_reproduced(self):
        for crit, key in (('strict', 'contacts'), ('dilated', 'dilated')):
            sub = {'contacts': self.data[key], 'shoe': self.data['shoe']}
            pix = [setting(self.s, f'{name}_{crit}').pixels(
                self.data['x'], self.data['y'], *self.centre)
                for name in ('optimum', 'best_s0')]
            _, h_star, n = cp.per_shoe_hits(sub, *pix[0])
            _, h_0, _ = cp.per_shoe_hits(sub, *pix[1])
            draws = cp.bootstrap_delta(h_star, h_0, n)
            stored = np.array([float(self.s[('bootstrap',
                                             f'{crit}.draw_{b:03d}')])
                               for b in range(1, cp.BOOT_B + 1)])
            with self.subTest(criterion=crit):
                self.assertTrue(np.array_equal(draws, stored))
                lo, hi = np.percentile(stored, [2.5, 97.5])
                self.assertEqual(lo, float(self.s[('bootstrap',
                                                   f'{crit}.lo')]))
                self.assertEqual(hi, float(self.s[('bootstrap',
                                                   f'{crit}.hi')]))
                self.assertEqual(
                    self.s[('conditions', f'{crit}.delta_hi_below_margin')],
                    str(bool(hi < cp.MARGIN)))


class Old(CommittedBase, unittest.TestCase):
    ds = 'old'

    def test_recovers_legacy_scale(self):
        """OLD (mapping known): x mirrored, y not flipped; the stage-F
        strict optimum within 1 px per unit of s0 on both axes (300, 301)
        and the legacy offset 0 within 1 px; the literal 'exactly 300' is
        recorded as False (A-087)."""
        opt = setting(self.s, 'optimum_strict')
        self.assertLessEqual(abs(opt.sx - self.s0[0]), 1)
        self.assertLessEqual(abs(opt.sy - self.s0[1]), 1)
        self.assertEqual(self.s[('conditions',
                                 'strict.orientation_mirrored_unflipped')],
                         'True')
        self.assertEqual(self.s[('conditions', 'strict.argmax_is_s0')],
                         str(bool(opt.sx == self.s0[0]
                                  and opt.sy == self.s0[1])))


class New(CommittedBase, unittest.TestCase):
    ds = 'new'

    def test_scale_band(self):
        opt = setting(self.s, 'optimum_strict')
        self.assertLessEqual(abs(opt.sx - self.s0[0]), cp.BAND_HALF_WIDTH)
        self.assertLessEqual(abs(opt.sy - self.s0[1]), cp.BAND_HALF_WIDTH)

    def test_cols_rows_2023(self):
        s = self.s
        self.assertEqual(s[('setting', 'cols_rows_2023.n_diff_legacy')], '0')
        self.assertEqual(s[('setting', 'cols_rows_2023.hits')],
                         s[('setting', 'legacy_aspix.hits')])

    def test_rate_difference_interval(self):
        """The rule of A-086 read back from the two committed tables:
        every condition and the decision equal a recomputation."""
        old = committed('old')[1]
        for crit in ('strict', 'dilated'):
            rule = cp.rule_decision(old, self.s, crit)
            for k, v in rule.items():
                with self.subTest(criterion=crit, part=k):
                    self.assertEqual(self.s[('rule', f'{crit}.{k}')],
                                     str(v))
        # the recorded outcome (A-087): strict fails (i) and (ii) on the
        # margin, (iii) holds; dilated passes all three
        self.assertEqual(cp.rule_decision(old, self.s, 'strict'),
                         {'i': False, 'ii': False, 'iii': True,
                          'keep_legacy': False})
        self.assertEqual(cp.rule_decision(old, self.s, 'dilated'),
                         {'i': True, 'ii': True, 'iii': True,
                          'keep_legacy': True})


def synthetic(p, contacts, setting, n_shoes=60, per_shoe=20, jitter=0.0,
              seed=1):
    """RACs placed on contact pixels of n_shoes real records (seed) so that
    `setting` maps each one back to its pixel (+ Gaussian jitter in px)."""
    rng = np.random.default_rng(seed)
    shoes = np.sort(rng.choice(len(contacts), n_shoes, replace=False))
    imgs = contacts[shoes]
    cx0, cy0 = cp.legacy_center(p.coords, p.W, p.H)
    mx = -1.0 if setting.mirror_x else 1.0
    my = 1.0 if setting.flip_y else -1.0
    sh, xs, ys = [], [], []
    for k, img in enumerate(imgs):
        rr, cc = np.nonzero(img)
        pick = rng.choice(len(rr), per_shoe, replace=False)
        # spread over the whole pixel (2% margins against rounding), so that
        # any other setting moves some RACs off their pixel
        u = (rng.uniform(0.02, 0.98, per_shoe)
             + rng.normal(0, jitter, per_shoe))
        v = (rng.uniform(0.02, 0.98, per_shoe)
             + rng.normal(0, jitter, per_shoe))
        xs.append((cc[pick] + u - cx0 - setting.dc) / (mx * setting.sx))
        ys.append((rr[pick] + v - cy0 - setting.dr) / (my * setting.sy))
        sh.append(np.full(per_shoe, k + 1))
    return {'contacts': imgs, 'dilated': cp.dilate(imgs),
            'shoe': np.concatenate(sh), 'x': np.concatenate(xs),
            'y': np.concatenate(ys)}


def small_grids(s0):
    """Stages O, C and F of A-086 thinned out for speed: O unchanged, C at
    every 20 px per unit from 200 to 400 with offsets -3, 0, 3, F at
    s0 +- 12 (offsets unchanged); the synthetic settings lie inside."""
    full = cp.stage_grids(*s0)
    coarse = np.arange(200, 401, 20)
    return {'O': full['O'],
            'C': (None, coarse, coarse, np.array([-3.0, 0.0, 3.0])),
            'F': (None, s0[0] + np.arange(-12, 13), s0[1] + np.arange(-12, 13),
                  full['F'][3])}


def quiet_calibrate(p, data):
    with contextlib.redirect_stdout(io.StringIO()):
        return cp.calibrate(p, data=data, log=lambda *a: None,
                            grids=small_grids(cp.px_per_unit(p.coords)))


class Synthetic(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.p = dataclasses.replace(load_profile('new'), cross_check=None)
        cls.s0 = cp.px_per_unit(cls.p.coords)
        cls.contacts = cp.load_dataset(cls.p)['contacts']

    def test_recovers_known_mapping(self):
        true = cp.Setting(self.s0[0] - 9, self.s0[1] + 7, 0.75, -1.25)
        data = synthetic(self.p, self.contacts, true)
        grid, summary, _ = quiet_calibrate(self.p, data)
        s = summary_dict(summary)
        found = setting(s, 'optimum_strict')
        self.assertEqual(found, true)
        self.assertEqual(s[('setting', 'optimum_strict.rate')], '1.0')
        # 9 px per unit off s0: the band condition and so the rule fail
        self.assertEqual(s[('conditions', 'strict.optimum_in_band')],
                         'False')
        self.assertEqual(s[('conditions', 'strict.all')], 'False')

    def test_legacy_placement_interval(self):
        """Placed with the legacy mapping and 0.3 px jitter: the Delta
        upper bound is below the margin (plan T3, rate interval)."""
        true = cp.Setting(self.s0[0], self.s0[1], 0.0, 0.0)
        data = synthetic(self.p, self.contacts, true, n_shoes=100,
                         per_shoe=40, jitter=0.3, seed=2)
        grid, summary, _ = quiet_calibrate(self.p, data)
        s = summary_dict(summary)
        self.assertLess(float(s[('bootstrap', 'strict.hi')]), cp.MARGIN)
        self.assertEqual(s[('conditions', 'strict.all')], 'True')

    def test_deterministic(self):
        true = cp.Setting(self.s0[0] + 3, self.s0[1] - 2, -0.5, 0.25)
        data = synthetic(self.p, self.contacts, true, n_shoes=30,
                         jitter=0.2, seed=5)
        grid, summary, _ = quiet_calibrate(self.p, data)
        grid2, summary2, _ = quiet_calibrate(self.p, data)
        pd.testing.assert_frame_equal(grid, grid2)
        self.assertEqual(summary_dict(summary2), summary_dict(summary))

    def test_orientation_found(self):
        true = cp.Setting(self.s0[0], self.s0[1], 0.0, 0.0, mirror_x=False)
        data = synthetic(self.p, self.contacts, true, seed=3)
        grid, summary, _ = quiet_calibrate(self.p, data)
        s = summary_dict(summary)
        self.assertEqual(s[('conditions',
                            'strict.orientation_mirrored_unflipped')],
                         'False')
        self.assertEqual(setting(s, 'optimum_strict'), true)


class Units(unittest.TestCase):

    def test_bootstrap_definition(self):
        h_star = np.array([5, 3, 0, 7])
        h0 = np.array([4, 3, 1, 6])
        n = np.array([6, 4, 2, 9])
        got = cp.bootstrap_delta(h_star, h0, n, B=3, seed=cp.BOOT_SEED)
        rng = np.random.default_rng(cp.BOOT_SEED)
        for b in range(3):
            idx = rng.integers(0, 4, 4)
            want = (h_star[idx].sum() - h0[idx].sum()) / n[idx].sum()
            self.assertEqual(got[b], want)

    def test_dilate(self):
        img = np.zeros((1, 5, 6), dtype=bool)
        img[0, 2, 3] = True
        d = cp.dilate(img)
        self.assertEqual(int(d.sum()), 9)
        self.assertTrue(d[0, 1:4, 2:5].all())

    def test_best_order_tie_break(self):
        base = 290.0
        hits = np.array([10, 10, 10, 9])
        sx = base + np.array([2.0, 0.0, 2.0, 1.0])
        sy = np.full(4, base)
        dc = np.array([0.5, -0.5, 0.0, 0.0])
        dr = np.zeros(4)
        order = cp.best_order(hits, sx, sy, dc, dr, base, base)
        # equal hits: the closest scale first, then the smallest offset
        self.assertEqual(order.tolist(), [1, 2, 0, 3])

    def test_cli_refuses_profile_file(self):
        env = {k: v for k, v in os.environ.items()
               if not k.startswith('RAC_')}
        env['RAC_PROFILE_FILE'] = 'config/datasets.json'
        err = io.StringIO()
        with mock.patch.dict(os.environ, env, clear=True), \
                contextlib.redirect_stderr(err):
            self.assertEqual(cp.main([]), 2)
        self.assertIn('RAC_PROFILE_FILE', err.getvalue())


if __name__ == '__main__':
    unittest.main()
