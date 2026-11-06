"""Dataset profiles (plan T2 step 1; decisions A-003, A-033, A-049).

OLD must give exactly the legacy constants and the committed paths; every
NEW output must be namespaced (a `new` folder component and the `_new`
suffix) and must not collide with an OLD output, an OLD output folder or a
tracked file (user rule 1). Reads only; temporary profile files go to a
tempfile folder.
"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path, PurePosixPath
from unittest import mock

from contour_algorithm import profiles
from contour_algorithm.profiles import env, load_profile

REPO = Path(__file__).resolve().parents[2]
PROFILE_FILE = REPO / 'config' / 'datasets.json'
NEW_FOLDERS = {'new', 'new_shoes', 'images_new'}
# The models and figures of the R steps are <models_dir>/<feature><suffix>
# .rds and <images_dir>/<stem><suffix>.pdf (statistical_model/R/profile.R).
R_MODELS = ('NEW_X_NS_XY', 'CML_MODEL')
R_FIGURES = ('NEW_X_NS_XY_SHOE', 'CML_MODEL_SHOE', 'CI_shoe_cuts',
             'CI_cut_110', 'CI_cut_190', 'CI_cut_250', 'pixel_inten_JASAup',
             'difference_random_cml')
# OLD outputs added by T2 (not committed before T2).
OLD_T2_FILES = {'processed_data/shoe_codes.csv',
                'processed_data/wald_test.csv'}
RAC_VARS = ('RAC_DATASET', 'RAC_PROFILE_FILE', 'RAC_MODEL_FEATURE',
            'RAC_DISTANCE_IMPL')


def rel(p, root=REPO):
    return PurePosixPath(Path(p).relative_to(root).as_posix())


def tracked_files():
    out = subprocess.run(['git', '-C', str(REPO), 'ls-files'], check=True,
                         capture_output=True, text=True).stdout
    return {PurePosixPath(x) for x in out.splitlines()}


def all_outputs(p):
    """{name: relative path} of every output file of profile p."""
    out = {k: rel(v, p.root) for k, v in p.output_files().items()}
    models = Path(p.r_path('models_dir'))
    figures = Path(p.r_path('images_dir'))
    for f in R_MODELS:
        out[f'model:{f}'] = rel(models / f'{f}{p.suffix}.rds', p.root)
    for s in R_FIGURES:
        out[f'figure:{s}'] = rel(figures / f'{s}{p.suffix}.pdf', p.root)
    return out


def clean_env():
    """Patch os.environ without any RAC_* variable."""
    keep = {k: v for k, v in os.environ.items() if not k.startswith('RAC_')}
    return mock.patch.dict(os.environ, keep, clear=True)


class Old(unittest.TestCase):

    def setUp(self):
        self.p = load_profile('old')

    def test_matches_legacy_constants(self):
        p, root = self.p, REPO
        self.assertEqual((p.W, p.H, p.num_shoe), (307, 395, 387))
        self.assertEqual((p.col_shoe, p.row_shoe), (307, 395))
        self.assertEqual(p.shoes_without_racs, (127,))
        self.assertEqual(p.excluded_shoes, ())
        self.assertEqual(p.contour_out,
                         root / 'data/contour_Active_Contour.txt')
        self.assertEqual(p.images_dir, root / 'images')
        self.assertEqual(p.contacts, root / 'data/contacts_data.txt')
        self.assertEqual(p.locations, root / 'data/locations_data.csv')
        self.assertEqual(p.locations_format, 'csv')
        s = p.snake
        self.assertEqual((s.center_rc, s.radii_rc), ((200, 155), (162, 90)))
        self.assertEqual(s.n_points, 400)
        self.assertEqual(s.gaussian_sigma, 3)
        self.assertEqual((s.alpha, s.beta_first, s.beta_second, s.gamma),
                         (0.015, 10, 0.10, 0.001))
        # the legacy literals were ints where they are ints
        for v in (s.center_rc + s.radii_rc + (s.n_points, s.gaussian_sigma,
                                              s.beta_first)):
            self.assertIs(type(v), int)
        self.assertEqual(p.superpose_threshold, 18)
        self.assertEqual(p.contact_flip_shoes, ())
        self.assertFalse(p.write_html)
        c = p.coords
        self.assertEqual((c.rel_col_shoe, c.rel_row_shoe, c.rel_x_cord,
                          c.rel_Y_cord, c.divisor), (150, 300, 0.25, 0.5, 1))
        self.assertEqual(p.suffix, '')

    def test_legacy_file_names(self):
        p = self.p
        names = {k: str(v) for k, v in all_outputs(p).items()}
        self.assertEqual(names['saved:superposed.npy'],
                         'images/saved/old_freq_min_18.npy')
        self.assertEqual(names['saved:prototype_mask.png'],
                         'images/saved/freq_min_18.png')
        self.assertEqual(names['saved:locations_pixels'],
                         'images/saved/locations_new.csv')
        self.assertEqual(names['image:shoes'], 'images/shoes/im0.png')
        self.assertEqual(names['image:cleaned_shoes'],
                         'images/cleaned_shoes/im_0.png')
        self.assertEqual(str(rel(p.image_path('active-contour', 386))),
                         'images/active-contour/im_386.png')
        self.assertEqual(names['model:NEW_X_NS_XY'],
                         'saved_models/NEW_X_NS_XY.rds')
        self.assertEqual(names['figure:CI_cut_110'],
                         'model_images/CI_cut_110.pdf')

    def test_old_outputs_are_the_committed_files(self):
        tracked = tracked_files()
        r_files = {v for k, v in all_outputs(self.p).items()
                   if k.startswith(('r.paths.', 'model:', 'figure:'))}
        r_files.add(rel(self.p.contour_out))
        self.assertEqual(r_files - tracked, {PurePosixPath(x)
                                             for x in OLD_T2_FILES})

    def test_prototype_frame(self):
        p = self.p
        self.assertEqual((p.prototype_col_shoe, p.prototype_row_shoe),
                         (307, 395))
        self.assertEqual(p.prototype_contour,
                         REPO / 'data/contour_prototype.png')
        self.assertEqual(p.prototype_mask, REPO / 'data/freq_min_18.png')

    def test_records(self):
        p = self.p
        shoes = p.analysis_shoes()
        self.assertEqual(len(shoes), 386)
        self.assertNotIn(127, shoes)
        self.assertEqual(p.skip_idx0(), (126,))
        self.assertEqual(p.record_of_shoe(126), 125)
        self.assertEqual(p.record_of_shoe(128), 126)
        self.assertEqual(p.shoe_of_record(385), 387)
        with self.assertRaises(ValueError):
            p.record_of_shoe(127)


class New(unittest.TestCase):

    def setUp(self):
        self.p = load_profile('new')

    def test_values(self):
        p = self.p
        self.assertEqual((p.W, p.H, p.num_shoe), (255, 367, 631))
        self.assertEqual(p.shoes_without_racs, ())
        self.assertEqual(len(p.analysis_shoes()), 631)
        self.assertEqual(p.skip_idx0(), ())
        self.assertEqual(p.coords.divisor, 2)
        self.assertEqual(p.locations_format, 'space_no_header')
        self.assertEqual((p.prototype_col_shoe, p.prototype_row_shoe),
                         (307, 395))
        self.assertEqual(p.prototype_contour, load_profile('old')
                         .prototype_contour)
        self.assertEqual(p.suffix, '_new')

    def test_outputs_namespaced(self):
        p = self.p
        for name, path in all_outputs(p).items():
            with self.subTest(output=name):
                self.assertTrue(set(path.parts[:-1]) & NEW_FOLDERS,
                                f'{path} has no new folder')
                self.assertTrue(path.stem.endswith('_new'),
                                f'{path} has no _new suffix')
        for name, path in p.output_dirs().items():
            with self.subTest(folder=name):
                self.assertTrue(set(rel(path).parts) & NEW_FOLDERS, path)

    def test_no_collision(self):
        old, new = load_profile('old'), self.p
        old_files = set(all_outputs(old).values())
        new_files = set(all_outputs(new).values())
        self.assertEqual(old_files & new_files, set())
        self.assertEqual(new_files & tracked_files(), set())
        # no NEW output equals or lies inside an OLD output file or an OLD
        # output folder (images/, statistical_model/, logs/old/, ...);
        # saved_models/ and model_images/ hold both, NEW in new/
        old_dirs = {rel(v) for k, v in old.output_dirs().items()
                    if k not in ('r.models_dir', 'r.images_dir')}
        for path in new_files | {rel(v) for v in new.output_dirs().values()}:
            for o in old_files | old_dirs:
                with self.subTest(new=str(path), old=str(o)):
                    self.assertFalse(path == o or o in path.parents)
        for d in new.output_dirs().values():
            self.assertNotIn(rel(d), {rel(v) for v in
                                      old.output_dirs().values()})

    def test_inputs_are_raw_committed_files(self):
        tracked = tracked_files()
        for path in (self.p.contacts, self.p.locations, self.p.cross_check):
            self.assertIn(rel(path), tracked)


class Env(unittest.TestCase):

    def test_selection(self):
        with clean_env():
            self.assertEqual(load_profile().dataset, 'old')
            os.environ['RAC_DATASET'] = ''
            self.assertEqual(load_profile().dataset, 'old')
            self.assertEqual(load_profile('').dataset, 'old')
            os.environ['RAC_DATASET'] = 'new'
            self.assertEqual(load_profile().dataset, 'new')
            self.assertEqual(load_profile('old').dataset, 'old')
            os.environ['RAC_DATASET'] = 'foo'
            with self.assertRaises(ValueError):
                load_profile()
            with self.assertRaises(ValueError):
                load_profile('OLD')

    def test_env_maps_unset_and_empty_to_default(self):
        for name in RAC_VARS:
            with self.subTest(var=name), clean_env():
                self.assertEqual(env(name, 'dflt'), 'dflt')
                os.environ[name] = ''
                self.assertEqual(env(name, 'dflt'), 'dflt')
                self.assertIsNone(env(name, None))
                os.environ[name] = 'x'
                self.assertEqual(env(name, 'dflt'), 'x')

    def test_profile_file_variable(self):
        cfg = json.loads(PROFILE_FILE.read_text())
        cfg['datasets']['old']['num_shoe'] = 388
        with tempfile.TemporaryDirectory() as tmp, clean_env():
            alt = Path(tmp) / 'alt.json'
            alt.write_text(json.dumps(cfg))
            os.environ['RAC_PROFILE_FILE'] = str(alt)
            self.assertEqual(load_profile('old').num_shoe, 388)
            self.assertEqual(load_profile('old').file, alt)
            os.environ['RAC_PROFILE_FILE'] = ''
            self.assertEqual(load_profile('old').num_shoe, 387)
            self.assertEqual(load_profile('old').file, PROFILE_FILE)


class Validation(unittest.TestCase):
    """A malformed profile is an error, not a silent default."""

    def broken(self, edit):
        cfg = json.loads(PROFILE_FILE.read_text())
        edit(cfg['datasets'])
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / 'bad.json'
        path.write_text(json.dumps(cfg))
        return path

    def test_rejects(self):
        cases = {
            'suffix': lambda d: d['new'].update(suffix='new'),
            'dataset name': lambda d: d['new'].update(dataset='old'),
            'unsorted skip list': lambda d: d['old'].update(
                shoes_without_racs=[127, 5]),
            'skip id out of range': lambda d: d['old'].update(
                shoes_without_racs=[388]),
            'skip and excluded': lambda d: d['old'].update(
                excluded_shoes=[127]),
            'absolute path': lambda d: d['new']['python'].update(
                contour_out='/tmp/x.txt'),
            'parent path': lambda d: d['new']['r']['paths'].update(
                dataCC='processed_data/../x_new.csv'),
            'locations format': lambda d: d['new']['inputs'].update(
                locations_format='tsv'),
            'snake center': lambda d: d['new']['python']['snake'].update(
                center_rc=[185]),
        }
        for name, edit in cases.items():
            path = self.broken(edit)
            ds = 'old' if name in ('unsorted skip list',
                                   'skip id out of range',
                                   'skip and excluded') else 'new'
            with self.subTest(case=name):
                with self.assertRaises(ValueError):
                    load_profile(ds, file=path)

    def test_comments_are_ignored(self):
        p = load_profile('new')
        self.assertFalse(any(k.startswith('_') for k in p.r))

    def test_image_path_checks(self):
        p = load_profile('old')
        with self.assertRaises(ValueError):
            p.image_path('shoes', 387)
        with self.assertRaises(ValueError):
            p.image_path('unknown', 0)
        self.assertEqual(profiles.IMAGE_KINDS['shoes'], ('shoes', 'im{i}'))


if __name__ == '__main__':
    unittest.main()
