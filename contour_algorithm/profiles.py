"""Dataset profiles for the contour code (plan section 4, decision A-003).

Every dimension, count, skip list, threshold and path of the Python step 0
comes from one entry of ``config/datasets.json``, selected by
``RAC_DATASET=old|new`` (default ``old``). The same file drives the R steps
(``statistical_model/R/profile.R``). OLD keeps the committed values and
paths; every NEW output sits in a ``new`` folder (``images_new``,
``new_shoes``, ...) and carries the suffix ``_new`` (user rule 1).

Environment (decisions A-033, A-049): every ``RAC_*`` variable is read
through :func:`env`, which treats an unset and an empty variable alike
(``os.environ.get(name, default)`` returns ``""`` for a set-but-empty
variable). ``RAC_PROFILE_FILE`` (tests only) names another profile file of
the same schema; production entry points refuse it.

User rule 1 is also checked at run time (T2 review; decision A-083):
:func:`load_profile` refuses a non-OLD profile in which an output file or
folder lies in no NEW folder (:data:`NAMESPACE_FOLDERS`), an output file
lacks the suffix, or an output file is an input of any dataset of the file
or an output of another dataset, so an edited path can never make a NEW
run overwrite an OLD output or a raw input.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from types import MappingProxyType
from typing import Mapping

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROFILE_FILE = 'config/datasets.json'
DATASETS = ('old', 'new')
LOCATION_FORMATS = ('csv', 'space_no_header')
# The folders that hold only NEW files (user rule 1): every output of a
# non-OLD profile lies below one of them, and its file stem ends with the
# profile's suffix.
NAMESPACE_FOLDERS = frozenset({'new', 'new_shoes', 'images_new'})
# Per-shoe image folders and their legacy file-name patterns (A-018: the
# index is the 0-based image index, im0 is shoe 1).
IMAGE_KINDS = MappingProxyType({
    'shoes': ('shoes', 'im{i}'),
    'shoe_on_prototype': ('shoe_on_prototype', 'im_{i}'),
    'cleaned_shoes': ('cleaned_shoes', 'im_{i}'),
    'active-contour': ('active-contour', 'im_{i}'),
    'qa_snake': ('qa_snake', 'im_{i}'),
    'extreme_values': ('extreme_values', 'plot_cont_{i}'),
    'snake_rac_html': ('snake_rac_html', 'plot_cont_{i}'),
})


def env(name: str, default: str | None) -> str | None:
    """Value of the environment variable `name`; `default` if it is unset
    or empty (A-049)."""
    value = os.environ.get(name)
    if value is None or value == '':
        return default
    return value


def _strip_comments(obj):
    """Drop the keys that start with '_' (comments), recursively."""
    if isinstance(obj, dict):
        return {k: _strip_comments(v) for k, v in obj.items()
                if not k.startswith('_')}
    if isinstance(obj, list):
        return [_strip_comments(v) for v in obj]
    return obj


def _freeze(obj):
    if isinstance(obj, dict):
        return MappingProxyType({k: _freeze(v) for k, v in obj.items()})
    if isinstance(obj, list):
        return tuple(_freeze(v) for v in obj)
    return obj


def _rel(value: str, what: str) -> PurePosixPath:
    """A profile path: relative, '/'-separated, no '..' or '.' parts."""
    if not isinstance(value, str) or not value:
        raise ValueError(f'profile: {what} must be a non-empty path string')
    p = PurePosixPath(value)
    if p.is_absolute() or '\\' in value or any(
            part in ('..', '.') for part in value.split('/')):
        raise ValueError(f'profile: {what} must be a relative path without '
                         f"'.' or '..' parts: {value!r}")
    return p


def _shoe_list(values, num_shoe: int, what: str) -> tuple[int, ...]:
    if any(isinstance(v, bool) or not isinstance(v, (int, float))
           or not float(v).is_integer() for v in values):
        raise ValueError(f'profile: {what} must hold integer shoe ids')
    out = tuple(int(v) for v in values)
    if list(out) != sorted(set(out)):
        raise ValueError(f'profile: {what} must be sorted and unique')
    if any(not 1 <= v <= num_shoe for v in out):
        raise ValueError(f'profile: {what} must be shoe ids in 1..{num_shoe}')
    return out


@dataclass(frozen=True)
class Coords:
    """Coordinate scale of a pixel grid (legacy aspix parameters)."""
    rel_col_shoe: float
    rel_row_shoe: float
    rel_x_cord: float
    rel_Y_cord: float
    divisor: float = 1


@dataclass(frozen=True)
class SnakeParams:
    """Initial ellipse and active-contour parameters of step 0."""
    center_rc: tuple
    radii_rc: tuple
    n_points: int
    gaussian_sigma: float
    alpha: float
    beta_first: float
    beta_second: float
    gamma: float


@dataclass(frozen=True)
class Profile:
    """One dataset entry of the profile file, with absolute paths."""
    dataset: str
    suffix: str
    root: Path
    file: Path
    col_shoe: int
    row_shoe: int
    num_shoe: int
    shoes_without_racs: tuple
    excluded_shoes: tuple
    coords: Coords
    contacts: Path
    locations: Path
    locations_format: str
    cross_check: Path | None
    sticker_masks: Path | None
    prototype_col_shoe: int
    prototype_row_shoe: int
    prototype_coords: Coords
    prototype_contour: Path
    prototype_mask: Path
    images_dir: Path
    contact_flip_shoes: tuple
    superpose_threshold: int
    snake: SnakeParams
    write_html: bool
    contour_out: Path
    stems: Mapping = field(repr=False)
    r: Mapping = field(repr=False)

    # --- dimensions -----------------------------------------------------
    @property
    def W(self) -> int:
        """Columns (legacy name)."""
        return self.col_shoe

    @property
    def H(self) -> int:
        """Rows (legacy name)."""
        return self.row_shoe

    # --- shoes and contour records (A-031) -------------------------------
    def analysis_shoes(self) -> tuple:
        """1-based ids of the shoes with a contour record, ascending."""
        drop = set(self.shoes_without_racs) | set(self.excluded_shoes)
        return tuple(s for s in range(1, self.num_shoe + 1) if s not in drop)

    def skip_idx0(self) -> tuple:
        """0-based image indices of the shoes without a contour record."""
        return tuple(sorted(s - 1 for s in set(self.shoes_without_racs)
                            | set(self.excluded_shoes)))

    def record_of_shoe(self, shoe: int) -> int:
        """0-based contour record of the 1-based shoe id."""
        shoes = self.analysis_shoes()
        if shoe not in shoes:
            raise ValueError(f'shoe {shoe} has no contour record in the '
                             f'{self.dataset} profile')
        return shoes.index(shoe)

    def shoe_of_record(self, k: int) -> int:
        """1-based shoe id of the 0-based contour record k."""
        shoes = self.analysis_shoes()
        if not 0 <= k < len(shoes):
            raise ValueError(f'record {k} is not a contour record of the '
                             f'{self.dataset} profile')
        return shoes[k]

    # --- paths ------------------------------------------------------------
    def path(self, rel: str) -> Path:
        """Absolute path of a profile-relative path."""
        return self.root / _rel(rel, 'path')

    def _named(self, stem: str, ext: str) -> str:
        return f'{stem}{self.suffix}.{ext}'

    def image_path(self, kind: str, idx0: int, ext: str = 'png') -> Path:
        """Per-shoe image of step 0: images/<kind>/<legacy name>.<ext>,
        or images_new/<kind>/<legacy name>_new.<ext> (A-018)."""
        if kind not in IMAGE_KINDS:
            raise ValueError(f'unknown image kind {kind!r}')
        if not 0 <= idx0 < self.num_shoe:
            raise ValueError(f'image index {idx0} outside 0..'
                             f'{self.num_shoe - 1}')
        folder, pattern = IMAGE_KINDS[kind]
        return self.images_dir / folder / self._named(
            pattern.format(i=idx0), ext)

    def saved_path(self, stem: str, ext: str) -> Path:
        """images/saved/<stem>.<ext> or images_new/saved/<stem>_new.<ext>."""
        if not stem or '/' in stem or '.' in stem:
            raise ValueError(f'bad stem {stem!r}')
        return self.images_dir / 'saved' / self._named(stem, ext)

    def stem(self, name: str) -> str:
        """A step-0 file stem of the profile, with the threshold filled in
        ('superposed', 'prototype_mask', 'locations_pixels')."""
        return self.stems[name].format(t=self.superpose_threshold)

    def r_path(self, key: str) -> Path:
        """An R output of the profile (`r.paths`), absolute."""
        return self.path(self.r['paths'][key])

    def output_dirs(self) -> dict:
        """Every output folder of this profile, by name (the folders that
        hold only this dataset's outputs; used by the namespacing and
        collision tests)."""
        return {
            'python.images_dir': self.images_dir,
            'r.knit_dir': self.path(self.r['knit_dir']),
            'r.log_dir': self.path(self.r['log_dir']),
            'r.models_dir': self.r_path('models_dir'),
            'r.images_dir': self.r_path('images_dir'),
        }

    def output_files(self) -> dict:
        """Every output file named by this profile, by name (per-shoe
        images by their first file, R models and figures not included:
        they are built from r.paths.models_dir and images_dir)."""
        out = {'python.contour_out': self.contour_out}
        for stem in ('list_matrices', 'list_contour', 'active-contour_all'):
            out[f'saved:{stem}'] = self.saved_path(stem, 'npy')
        out['saved:all_shoes_superposed'] = self.saved_path(
            'all_shoes_superposed', 'png')
        for name in ('superposed', 'prototype_mask'):
            for ext in ('npy', 'png'):
                out[f'saved:{name}.{ext}'] = self.saved_path(
                    self.stem(name), ext)
        out['saved:locations_pixels'] = self.saved_path(
            self.stem('locations_pixels'), 'csv')
        for kind in IMAGE_KINDS:
            ext = 'html' if kind in ('extreme_values',
                                     'snake_rac_html') else 'png'
            out[f'image:{kind}'] = self.image_path(kind, 0, ext)
        for key, rel in self.r['paths'].items():
            if not key.endswith('_dir'):
                out[f'r.paths.{key}'] = self.path(rel)
        return out


def _output_paths(d: Mapping) -> tuple[dict, dict]:
    """({name: path} of the output files, {name: path} of the output
    folders) named by the profile entry d (relative, normalized)."""
    files = {'python.contour_out': d['python']['contour_out']}
    folders = {'python.images_dir': d['python']['images_dir'],
               'r.knit_dir': d['r']['knit_dir'],
               'r.log_dir': d['r']['log_dir']}
    for key, value in d['r']['paths'].items():
        (folders if key.endswith('_dir') else files)[f'r.paths.{key}'] = value
    return ({k: PurePosixPath(v) for k, v in files.items()},
            {k: PurePosixPath(v) for k, v in folders.items()})


def _input_paths(d: Mapping) -> set:
    """The input files named by the profile entry d (relative)."""
    values = [d['inputs'].get(k) for k in ('contacts', 'locations',
                                           'cross_check', 'sticker_masks')]
    values += [d['prototype']['contour'], d['prototype']['mask']]
    return {PurePosixPath(v) for v in values if v is not None}


def _check_namespace(dataset: str, d: Mapping, entries: Mapping) -> None:
    """User rule 1 at run time, for a non-OLD profile entry d: every output
    folder lies below a NEW folder; every output file lies below a NEW
    folder and its stem ends with the suffix; no output file is an input of
    any entry of the file or an output file of another entry; no output
    lies in a work folder of another entry (its python.images_dir,
    r.knit_dir, r.log_dir; the shared parents saved_models/ and
    model_images/ are not work folders). Raises ValueError naming every
    offending path."""
    suffix = d['suffix']
    files, folders = _output_paths(d)
    bad = []
    for what, p in folders.items():
        if not set(p.parts) & NAMESPACE_FOLDERS:
            bad.append(f"{what} '{p}' lies in no NEW folder")
    for what, p in files.items():
        if not set(p.parts[:-1]) & NAMESPACE_FOLDERS:
            bad.append(f"{what} '{p}' lies in no NEW folder")
        elif not p.stem.endswith(suffix):
            bad.append(f"{what} '{p}' lacks the suffix '{suffix}'")
    protected = {}
    for name, e in entries.items():
        for p in _input_paths(e):
            protected.setdefault(p, f'an input of the {name} profile')
        if name == dataset:
            continue
        for p in _output_paths(e)[0].values():
            protected.setdefault(p, f'an output of the {name} profile')
        work = {PurePosixPath(e['python']['images_dir']),
                PurePosixPath(e['r']['knit_dir']),
                PurePosixPath(e['r']['log_dir'])}
        for what, p in {**files, **folders}.items():
            for w in sorted(work):
                if p == w or w in p.parents:
                    bad.append(f"{what} '{p}' lies in '{w}', a work folder "
                               f'of the {name} profile')
    for what, p in files.items():
        if p in protected:
            bad.append(f"{what} '{p}' is {protected[p]}")
    if bad:
        raise ValueError(
            f'profile {dataset!r} breaks the NEW namespace (user rule 1: '
            f'every NEW output lies in a folder named one of '
            f'{sorted(NAMESPACE_FOLDERS)}, ends with {suffix!r} and is '
            f'never an input or another dataset\'s output): '
            + '; '.join(bad))


def _coords(c: Mapping, what: str) -> Coords:
    try:
        return Coords(rel_col_shoe=c['rel_col_shoe'],
                      rel_row_shoe=c['rel_row_shoe'],
                      rel_x_cord=c['rel_x_cord'], rel_Y_cord=c['rel_Y_cord'],
                      divisor=c.get('divisor', 1))
    except KeyError as e:
        raise ValueError(f'profile: {what} lacks {e}') from None


def load_profile(dataset: str | None = None, file: Path | str | None = None,
                 root: Path | str | None = None) -> Profile:
    """The profile of `dataset` from the profile file.

    dataset: 'old' or 'new'; None or '' means env('RAC_DATASET', 'old').
    file: the profile file; None means env('RAC_PROFILE_FILE',
      'config/datasets.json'); a relative path is taken from `root`.
    root: the repository root the profile paths are relative to (default:
      the folder that holds this package).
    Raises ValueError for an unknown dataset or an invalid profile.
    """
    if dataset is None or dataset == '':
        dataset = env('RAC_DATASET', 'old')
    if dataset not in DATASETS:
        raise ValueError(f"RAC_DATASET must be one of {DATASETS}, "
                         f"not {dataset!r}")
    root = Path(root) if root is not None else REPO_ROOT
    if file is None or file == '':
        file = env('RAC_PROFILE_FILE', DEFAULT_PROFILE_FILE)
    file = Path(file)
    if not file.is_absolute():
        file = root / file
    with open(file, encoding='utf-8') as f:
        cfg = _strip_comments(json.load(f))
    try:
        d = cfg['datasets'][dataset]
    except KeyError:
        raise ValueError(f'profile file {file} has no dataset '
                         f'{dataset!r}') from None
    if d.get('dataset') != dataset:
        raise ValueError(f'profile entry {dataset!r} names dataset '
                         f'{d.get("dataset")!r}')
    suffix = d['suffix']
    if suffix != ('' if dataset == 'old' else f'_{dataset}'):
        raise ValueError(f'profile {dataset!r}: suffix {suffix!r}')
    num_shoe = int(d['num_shoe'])
    py, inputs, proto = d['python'], d['inputs'], d['prototype']
    if inputs['locations_format'] not in LOCATION_FORMATS:
        raise ValueError(f"profile {dataset!r}: locations_format "
                         f"{inputs['locations_format']!r}")
    no_racs = _shoe_list(d['shoes_without_racs'], num_shoe,
                         'shoes_without_racs')
    excluded = _shoe_list(d['excluded_shoes'], num_shoe, 'excluded_shoes')
    if set(no_racs) & set(excluded):
        raise ValueError(f'profile {dataset!r}: a shoe is both without '
                         'RACs and excluded')

    def p(value, what):
        return root / _rel(value, what)

    def p_opt(value, what):
        return None if value is None else p(value, what)

    s = py['snake']
    snake = SnakeParams(
        center_rc=tuple(s['center_rc']), radii_rc=tuple(s['radii_rc']),
        n_points=s['n_points'], gaussian_sigma=s['gaussian_sigma'],
        alpha=s['alpha'], beta_first=s['beta_first'],
        beta_second=s['beta_second'], gamma=s['gamma'])
    if len(snake.center_rc) != 2 or len(snake.radii_rc) != 2:
        raise ValueError(f'profile {dataset!r}: snake center_rc and '
                         'radii_rc need 2 values (row, col)')
    for key, rel in d['r']['paths'].items():
        _rel(rel, f'r.paths.{key}')
    for key in ('knit_dir', 'log_dir'):
        _rel(d['r'][key], f'r.{key}')
    _rel(py['images_dir'], 'python.images_dir')
    _rel(py['contour_out'], 'python.contour_out')
    if dataset != 'old':
        _check_namespace(dataset, d, cfg['datasets'])
    return Profile(
        dataset=dataset, suffix=suffix, root=root, file=file,
        col_shoe=int(d['col_shoe']), row_shoe=int(d['row_shoe']),
        num_shoe=num_shoe, shoes_without_racs=no_racs,
        excluded_shoes=excluded,
        coords=_coords(d['coords'], 'coords'),
        contacts=p(inputs['contacts'], 'inputs.contacts'),
        locations=p(inputs['locations'], 'inputs.locations'),
        locations_format=inputs['locations_format'],
        cross_check=p_opt(inputs.get('cross_check'), 'inputs.cross_check'),
        sticker_masks=p_opt(inputs.get('sticker_masks'),
                            'inputs.sticker_masks'),
        prototype_col_shoe=int(proto['col_shoe']),
        prototype_row_shoe=int(proto['row_shoe']),
        prototype_coords=_coords(proto['coords'], 'prototype.coords'),
        prototype_contour=p(proto['contour'], 'prototype.contour'),
        prototype_mask=p(proto['mask'], 'prototype.mask'),
        images_dir=p(py['images_dir'], 'python.images_dir'),
        contact_flip_shoes=_shoe_list(py['contact_flip_shoes'], num_shoe,
                                      'python.contact_flip_shoes'),
        superpose_threshold=int(py['superpose_threshold']),
        snake=snake, write_html=bool(py['write_html']),
        contour_out=p(py['contour_out'], 'python.contour_out'),
        stems=_freeze(py['stems']), r=_freeze(d['r']))
