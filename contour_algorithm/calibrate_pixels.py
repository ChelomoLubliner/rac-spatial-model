"""Pixel calibration of the RAC coordinates (plan T3; decisions A-013,
A-032, A-048, A-086, A-087).

The location files give each RAC as coordinates (x, y); step 1 maps them
to the pixels of the contact images with R `aspix_x` / `aspix_y`
(`statistical_model/dataCC_1.Rmd`) and the profile's `coords`. For the NEW
images that scale was provisional. This module finds, from the data alone,
the mapping that puts the most RACs on a contact pixel, validates the
search on OLD (where the mapping is known) and applies the pre-registered
rule of A-086 that decides whether NEW keeps the generalized legacy
mapping.

Mapping family (0-based pixels, pixel j covers [j, j + 1)):

    col = floor(cx0 + dc + mx * sx * x),  mx = -1 if x is mirrored else +1
    row = floor(cy0 + dr + my * sy * y),  my = +1 if y is flipped else -1

with the legacy centres cx0, cy0 of `legacy_center` and sx, sy in pixels
per coordinate unit. At sx = sy = s0 = `px_per_unit(coords)`, dc = dr = 0,
x mirrored and y not flipped this is `legacy_pixel` (the R division form)
except for a RAC exactly on a pixel boundary. A RAC mapped outside the
image is a miss.

Criteria: the strict on-contact rate (primary); the rate on the contact
surface dilated by a 3 x 3 square (secondary, "1-pixel dilation"); the
mean pixel distance to the nearest contact pixel at named settings.
Stages (A-086): O (orientation, 4 mirror/flip combinations, coarse scales
and wide offsets), C (coarse scales 100-700 px per unit) and F (fine,
s0 +- 20 in steps of 1, offsets +-2 px in steps of 0.25; primary). The
contact images are the ones step 1 uses before its stamp mask: the raw
records, with the profile's `r.contact_flip_shoes` mirrored as in R.

Command line (RAC_DATASET selects the dataset; the NEW run reads the OLD
calibration file, so OLD runs first):

    RAC_DATASET=old python -m contour_algorithm.calibrate_pixels
    RAC_DATASET=new python -m contour_algorithm.calibrate_pixels
"""

import argparse
import math
import sys
import time
from dataclasses import dataclass

import numpy as np
import pandas as pd

from .profiles import Coords, env, load_profile

# Pre-registered constants of the rule (A-013, A-032, A-048, A-086).
BAND_HALF_WIDTH = 6        # point optimum within s0 +- 6 px per unit
MARGIN = 0.005             # upper bound of the Delta interval below this
OFFSET_TOL = 1.0           # NEW and OLD optimum offsets agree within 1 px
BOOT_B = 200
BOOT_SEED = 20261107
# The 2023 R script for the new shoes (meeting 5): rel_col_shoe 333 and
# rel_row_shoe 180, "wrong or swapped"; evaluated as negative controls.
R_SCRIPT_2023 = (333, 180)


def stage_grids(s0x, s0y):
    """{stage: (orientations, x scales, y scales, offsets)} of A-086."""
    all4 = ((True, False), (True, True), (False, False), (False, True))
    rel_o = np.arange(-60, 61, 20)
    rel_f = np.arange(-20, 21)
    coarse = np.arange(100, 701, 10)
    return {
        'O': (all4, s0x + rel_o, s0y + rel_o, np.arange(-20, 21, 2) * 1.0),
        'C': (None, coarse, coarse, np.array([-6.0, -3.0, 0.0, 3.0, 6.0])),
        'F': (None, s0x + rel_f, s0y + rel_f, np.arange(-8, 9) * 0.25),
    }


def px_per_unit(coords):
    """Pixels per coordinate unit (x, y) of a legacy coordinate scale."""
    return (coords.rel_col_shoe / (2 * coords.rel_x_cord),
            coords.rel_row_shoe / (2 * coords.rel_Y_cord))


def legacy_center(coords, width, height):
    """0-based continuous column and row where the legacy mapping puts
    x = 0 and y = 0 (pixel boundaries: floor(cx0 - s0 x) = col0)."""
    cx0 = (width - math.ceil((width - coords.rel_col_shoe) / 2)
           - coords.rel_col_shoe / 2)
    cy0 = (height - math.ceil((height - coords.rel_row_shoe) / 2)
           - coords.rel_row_shoe / 2)
    return float(cx0), float(cy0)


def legacy_pixel(x, y, coords, width, height):
    """1-based (col, row) of R aspix_x / aspix_y (dataCC_1.Rmd), in the R
    division form and the same order of operations."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    delx = (2 * coords.rel_x_cord) / coords.rel_col_shoe
    dely = (2 * coords.rel_Y_cord) / coords.rel_row_shoe
    not_rel_col = math.ceil((width - coords.rel_col_shoe) / 2)
    not_rel_row = math.ceil((height - coords.rel_row_shoe) / 2)
    col = width - (np.floor((x + coords.rel_x_cord) / delx) + not_rel_col)
    row = height - (np.floor((y + coords.rel_Y_cord) / dely) + not_rel_row)
    return col.astype(np.int64), row.astype(np.int64)


def axis_pixels(coord, center, offset, sign, scale):
    """floor(center + offset + sign * scale * coord), the one expression
    that both the grid and a single setting use (same rounding)."""
    return np.floor(center + offset + sign * scale * coord).astype(np.int64)


@dataclass(frozen=True)
class Setting:
    """One mapping of the family (scales in px per unit, offsets in px)."""
    sx: float
    sy: float
    dc: float
    dr: float
    mirror_x: bool = True
    flip_y: bool = False

    def pixels(self, x, y, cx0, cy0):
        """0-based (col, row) of every RAC."""
        mx = -1.0 if self.mirror_x else 1.0
        my = 1.0 if self.flip_y else -1.0
        return (axis_pixels(x, cx0, self.dc, mx, self.sx),
                axis_pixels(y, cy0, self.dr, my, self.sy))


def on_image(col, row, width, height):
    return (col >= 0) & (col < width) & (row >= 0) & (row < height)


def hits_at(images, shoe0, col, row):
    """Per RAC: True if its pixel is set in its shoe's image (0-based shoe
    index, 0-based pixel); a pixel outside the image is a miss."""
    n, h, w = images.shape
    ok = on_image(col, row, w, h)
    out = np.zeros(len(col), dtype=bool)
    out[ok] = images[shoe0[ok], row[ok], col[ok]]
    return out


def on_contact_rate(contacts, shoe0, col0, row0):
    """Share of the RACs whose 0-based pixel is a contact pixel."""
    return float(hits_at(contacts, shoe0, col0, row0).mean())


def dilate(contacts):
    """The contact images dilated by a 3 x 3 square (8 neighbours)."""
    out = contacts.copy()
    out[:, 1:, :] |= contacts[:, :-1, :]
    out[:, :-1, :] |= contacts[:, 1:, :]
    tmp = out.copy()
    out[:, :, 1:] |= tmp[:, :, :-1]
    out[:, :, :-1] |= tmp[:, :, 1:]
    return out


def hit_matrix(images, shoe0, x, y, cx0, cy0, mirror_x, flip_y,
               col_settings, row_settings):
    """hits[l, k] = RACs on a set pixel at row setting l = (sy, dr) and
    column setting k = (sx, dc)."""
    mx = -1.0 if mirror_x else 1.0
    my = 1.0 if flip_y else -1.0
    cols = np.stack([axis_pixels(x, cx0, dc, mx, sx)
                     for sx, dc in col_settings])
    rows = np.stack([axis_pixels(y, cy0, dr, my, sy)
                     for sy, dr in row_settings])
    n, h, w = images.shape
    pc = int(max(0, -cols.min(), cols.max() - (w - 1)))
    pr = int(max(0, -rows.min(), rows.max() - (h - 1)))
    padded = np.zeros((n, h + 2 * pr, w + 2 * pc), dtype=np.uint8)
    padded[:, pr:pr + h, pc:pc + w] = images
    wp = w + 2 * pc
    idx = np.arange(len(x), dtype=np.int64)[None, :] * wp + cols + pc
    hits = np.empty((len(row_settings), len(col_settings)), dtype=np.int64)
    for k in range(len(row_settings)):
        band = padded[shoe0, rows[k] + pr, :].reshape(-1)
        hits[k] = band[idx].sum(axis=1)
    return hits


def best_order(hits, sx, sy, dc, dr, s0x, s0y):
    """Indices from best to worst (A-086): most hits, then the smallest
    |sx - s0| + |sy - s0|, then the smallest |dc| + |dr|, then the
    smallest (sx, sy, dc, dr)."""
    return np.lexsort((dr, dc, sy, sx, np.abs(dc) + np.abs(dr),
                       np.abs(sx - s0x) + np.abs(sy - s0y), -hits))


def run_stage(images, shoe0, x, y, centre, s0, orientations, xscales,
              yscales, offsets):
    """Every setting of one stage and criterion: a DataFrame with one row
    per (orientation, sx, sy) at its best offsets, best first within each
    orientation, and the full-grid optimum of each orientation."""
    cx0, cy0 = centre
    col_settings = [(float(sx), float(dc)) for sx in xscales
                    for dc in offsets]
    row_settings = [(float(sy), float(dr)) for sy in yscales
                    for dr in offsets]
    n_off = len(offsets)
    out = []
    for mirror_x, flip_y in orientations:
        hits = hit_matrix(images, shoe0, x, y, cx0, cy0, mirror_x, flip_y,
                          col_settings, row_settings)
        # hits[(sy, dr), (sx, dc)] -> flat arrays of every setting
        isy, idr, isx, idc = np.meshgrid(
            np.arange(len(yscales)), np.arange(n_off),
            np.arange(len(xscales)), np.arange(n_off), indexing='ij')
        flat = hits.reshape(len(yscales), n_off, len(xscales), n_off)
        h = flat.reshape(-1)
        sx = np.asarray(xscales, dtype=float)[isx.reshape(-1)]
        sy = np.asarray(yscales, dtype=float)[isy.reshape(-1)]
        dc = np.asarray(offsets)[idc.reshape(-1)]
        dr = np.asarray(offsets)[idr.reshape(-1)]
        order = best_order(h, sx, sy, dc, dr, *s0)
        pair = (isx.reshape(-1) * len(yscales) + isy.reshape(-1))[order]
        _, first = np.unique(pair, return_index=True)
        pick = order[np.sort(first)]
        out.append(pd.DataFrame({
            'mirror_x': mirror_x, 'flip_y': flip_y,
            'sx': sx[pick].astype(np.int64), 'sy': sy[pick].astype(np.int64),
            'dc': dc[pick], 'dr': dr[pick], 'hits': h[pick]}))
    return pd.concat(out, ignore_index=True)


def load_dataset(profile):
    """Contact images (with the R flips), their dilation, the per-shoe
    distance maps (lazily) and the RAC arrays of a profile."""
    from .io_shoes import read_shoes
    from .locations import read_locations
    contacts = read_shoes(profile.contacts, profile.W, profile.H,
                          profile.num_shoe)
    for shoe in profile.r['contact_flip_shoes']:
        contacts[int(shoe) - 1] = contacts[int(shoe) - 1][:, ::-1]
    locs = read_locations(profile)
    return {
        'contacts': contacts, 'dilated': dilate(contacts),
        'shoe': locs['shoe'].to_numpy(dtype=np.int64),
        'x': locs['x'].to_numpy(dtype=float),
        'y': locs['y'].to_numpy(dtype=float),
    }


def distance_maps(contacts):
    """Per shoe: the distance of every pixel to the nearest contact pixel
    (0 on contact; inf for an empty image)."""
    from scipy import ndimage
    out = np.empty(contacts.shape, dtype=np.float32)
    for i, img in enumerate(contacts):
        out[i] = (ndimage.distance_transform_edt(~img) if img.any()
                  else np.inf)
    return out


def evaluate(data, dist, col0, row0):
    """Strict and dilated hits, rates and the mean distance at one set of
    0-based pixels."""
    shoe0 = data['shoe'] - 1
    contacts = data['contacts']
    n, h, w = contacts.shape
    ok = on_image(col0, row0, w, h)
    strict = hits_at(contacts, shoe0, col0, row0)
    dil = hits_at(data['dilated'], shoe0, col0, row0)
    d = dist[shoe0[ok], row0[ok], col0[ok]]
    return {'hits': int(strict.sum()), 'rate': float(strict.mean()),
            'hits_dil': int(dil.sum()), 'rate_dil': float(dil.mean()),
            'mean_dist': float(np.mean(d)) if d.size else float('nan'),
            'n_outside': int((~ok).sum())}


def per_shoe_hits(data, col0, row0):
    """(shoes, hits per shoe, RACs per shoe) at one set of pixels."""
    shoe0 = data['shoe'] - 1
    hit = hits_at(data['contacts'], shoe0, col0, row0)
    shoes, inv = np.unique(data['shoe'], return_inverse=True)
    return (shoes, np.bincount(inv, weights=hit).astype(np.int64),
            np.bincount(inv).astype(np.int64))


def bootstrap_delta(h_star, h0, n, B=BOOT_B, seed=BOOT_SEED):
    """Delta_b = (sum h* - sum h0) / sum n over B shoe resamples (A-086)."""
    rng = np.random.default_rng(seed)
    k = len(n)
    out = np.empty(B)
    for b in range(B):
        idx = rng.integers(0, k, k)
        out[b] = (h_star[idx].sum() - h0[idx].sum()) / n[idx].sum()
    return out


def stage_optimum(table, s0):
    """The best row of a stage table over all its orientations."""
    order = best_order(table['hits'].to_numpy(), table['sx'].to_numpy(float),
                       table['sy'].to_numpy(float), table['dc'].to_numpy(),
                       table['dr'].to_numpy(), *s0)
    return table.iloc[order[0]]


def setting_of(row):
    return Setting(float(row['sx']), float(row['sy']), float(row['dc']),
                   float(row['dr']), bool(row['mirror_x']),
                   bool(row['flip_y']))


def calibrate(profile, data=None, log=print, grids=None):
    """Run stages O, C and F with both criteria on one dataset; return
    (grid table, summary rows, per-setting details). `grids` replaces the
    pre-registered stage_grids() (tests only: smaller grids that still
    contain the setting a synthetic dataset was built with)."""
    if data is None:
        data = load_dataset(profile)
    s0 = px_per_unit(profile.coords)
    centre = legacy_center(profile.coords, profile.W, profile.H)
    grids = stage_grids(*s0) if grids is None else grids
    shoe0 = data['shoe'] - 1
    x, y = data['x'], data['y']
    n_rac = len(x)
    tables = []
    best = {}
    for criterion, images in (('strict', data['contacts']),
                              ('dilated', data['dilated'])):
        orient = grids['O'][0]
        for stage in ('O', 'C', 'F'):
            start = time.monotonic()
            _, xs, ys, offs = grids[stage]
            if stage != 'O':
                orient = ((best[('O', 'strict')].mirror_x,
                           best[('O', 'strict')].flip_y),)
            t = run_stage(images, shoe0, x, y, centre, s0, orient, xs, ys,
                          offs)
            t.insert(0, 'criterion', criterion)
            t.insert(0, 'stage', stage)
            t['n_rac'] = n_rac
            t['rate'] = t['hits'] / n_rac
            best[(stage, criterion)] = setting_of(stage_optimum(t, s0))
            tables.append(t)
            log(f'{profile.dataset} stage {stage} {criterion}: '
                f'{len(t)} rows, best {best[(stage, criterion)]}, '
                f'{time.monotonic() - start:.1f} s')
    grid = pd.concat(tables, ignore_index=True)

    # named settings
    dist = distance_maps(data['contacts'])
    named = {}
    lc, lr = legacy_pixel(x, y, profile.coords, profile.W, profile.H)
    named['legacy_aspix'] = (None, lc - 1, lr - 1)
    grid_legacy = Setting(s0[0], s0[1], 0.0, 0.0)
    for crit in ('strict', 'dilated'):
        f = grid[(grid.stage == 'F') & (grid.criterion == crit)]
        at_s0 = f[(f.sx == s0[0]) & (f.sy == s0[1])].iloc[0]
        named[f'best_s0_{crit}'] = (setting_of(at_s0), None, None)
        named[f'optimum_{crit}'] = (best[('F', crit)], None, None)
    named['grid_legacy'] = (grid_legacy, None, None)
    o = grid[(grid.stage == 'O') & (grid.criterion == 'strict')]
    for (mx, fy), g in o.groupby(['mirror_x', 'flip_y'], sort=False):
        named[f'orientation_mirror{int(mx)}_flip{int(fy)}'] = (
            setting_of(stage_optimum(g, s0)), None, None)
    for name, (rc, rr) in (('r_script_2023', R_SCRIPT_2023),
                           ('r_script_2023_swapped', R_SCRIPT_2023[::-1])):
        c = Coords(rel_col_shoe=rc, rel_row_shoe=rr,
                   rel_x_cord=profile.coords.rel_x_cord,
                   rel_Y_cord=profile.coords.rel_Y_cord)
        cc, rr1 = legacy_pixel(x, y, c, profile.W, profile.H)
        named[name] = (None, cc - 1, rr1 - 1)
    if profile.cross_check is not None:
        ref = pd.read_csv(profile.cross_check)
        named['cols_rows_2023'] = (None, ref['COL'].to_numpy() - 1,
                                   ref['ROW'].to_numpy() - 1)
    details = {}
    for name, (setting, c0, r0) in named.items():
        if setting is not None:
            c0, r0 = setting.pixels(x, y, *centre)
        ev = evaluate(data, dist, c0, r0)
        ev['setting'] = setting
        ev['n_diff_legacy'] = int(((c0 != lc - 1) | (r0 != lr - 1)).sum())
        details[name] = (ev, c0, r0)

    # bootstrap of Delta for both criteria (strict decides, A-086)
    summary = [('meta', 'dataset', profile.dataset),
               ('meta', 'n_shoes_with_racs', len(np.unique(data['shoe']))),
               ('meta', 'n_rac', n_rac), ('meta', 's0_x', s0[0]),
               ('meta', 's0_y', s0[1]), ('meta', 'cx0', centre[0]),
               ('meta', 'cy0', centre[1]), ('meta', 'boot_B', BOOT_B),
               ('meta', 'boot_seed', BOOT_SEED),
               ('meta', 'band_half_width', BAND_HALF_WIDTH),
               ('meta', 'margin', MARGIN), ('meta', 'offset_tol', OFFSET_TOL)]
    for name, (ev, _, _) in details.items():
        st = ev['setting']
        if st is not None:
            for k in ('sx', 'sy', 'dc', 'dr', 'mirror_x', 'flip_y'):
                summary.append(('setting', f'{name}.{k}', getattr(st, k)))
        for k in ('hits', 'rate', 'hits_dil', 'rate_dil', 'mean_dist',
                  'n_outside', 'n_diff_legacy'):
            summary.append(('setting', f'{name}.{k}', ev[k]))
    boot = {}
    for crit in ('strict', 'dilated'):
        key = 'contacts' if crit == 'strict' else 'dilated'
        sub = {'contacts': data[key], 'shoe': data['shoe']}
        _, c_star, r_star = details[f'optimum_{crit}']
        _, c_s0, r_s0 = details[f'best_s0_{crit}']
        _, h_star, n = per_shoe_hits(sub, c_star, r_star)
        _, h_0, _ = per_shoe_hits(sub, c_s0, r_s0)
        draws = bootstrap_delta(h_star, h_0, n)
        lo, hi = np.percentile(draws, [2.5, 97.5])
        full = (h_star.sum() - h_0.sum()) / n.sum()
        boot[crit] = (full, lo, hi, draws)
        summary += [('bootstrap', f'{crit}.delta_full', float(full)),
                    ('bootstrap', f'{crit}.lo', float(lo)),
                    ('bootstrap', f'{crit}.hi', float(hi))]
        summary += [('bootstrap', f'{crit}.draw_{b + 1:03d}', float(v))
                    for b, v in enumerate(draws)]
    for crit in ('strict', 'dilated'):
        for k, v in dataset_conditions(best[('O', crit)], best[('F', crit)],
                                       boot[crit][2], s0).items():
            summary.append(('conditions', f'{crit}.{k}', v))
    return grid, summary, details


def dataset_conditions(best_o, best_f, hi, s0):
    """The three per-dataset conditions of A-086 (rule (i) on OLD, rule
    (ii) on NEW) and the literal reading of (i)."""
    orient = bool(best_o.mirror_x) and not bool(best_o.flip_y)
    band = (abs(best_f.sx - s0[0]) <= BAND_HALF_WIDTH
            and abs(best_f.sy - s0[1]) <= BAND_HALF_WIDTH)
    delta = bool(hi < MARGIN)
    return {'orientation_mirrored_unflipped': orient,
            'optimum_in_band': bool(band), 'delta_hi_below_margin': delta,
            'all': bool(orient and band and delta),
            'argmax_is_s0': bool(best_f.sx == s0[0] and best_f.sy == s0[1])}


def _value_text(v):
    if isinstance(v, (bool, np.bool_)):
        return 'True' if v else 'False'
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    if isinstance(v, (float, np.floating)):
        return repr(float(v))
    return str(v)


def summary_frame(rows):
    return pd.DataFrame({'section': [r[0] for r in rows],
                         'name': [r[1] for r in rows],
                         'value': [_value_text(r[2]) for r in rows]})


def read_summary(path):
    """{(section, name): text value} of a written calibration summary."""
    t = pd.read_csv(path, dtype=str, keep_default_na=False)
    return {(s, n): v for s, n, v in zip(t['section'], t['name'], t['value'])}


def rule_decision(old, new, criterion='strict'):
    """Rule of A-086 from the two summaries: (i) the OLD conditions, (ii)
    the NEW conditions, (iii) the optimum offsets agree within
    OFFSET_TOL; keep the generalized legacy mapping if all hold."""
    def flag(s, k):
        return s[('conditions', f'{criterion}.{k}')] == 'True'

    def num(s, k):
        return float(s[('setting', f'optimum_{criterion}.{k}')])
    rule_i = flag(old, 'all')
    rule_ii = flag(new, 'all')
    rule_iii = (abs(num(new, 'dc') - num(old, 'dc')) <= OFFSET_TOL
                and abs(num(new, 'dr') - num(old, 'dr')) <= OFFSET_TOL)
    return {'i': rule_i, 'ii': rule_ii, 'iii': bool(rule_iii),
            'keep_legacy': bool(rule_i and rule_ii and rule_iii)}


def write_outputs(profile, grid, summary, grid_path=None, summary_path=None):
    """Write the grid and summary CSVs (LF; default: the profile's
    prep.calibration_grid and prep.pixel_calibration)."""
    grid_path = grid_path or profile.prep_path('calibration_grid')
    summary_path = summary_path or profile.prep_path('pixel_calibration')
    for path in (grid_path, summary_path):
        path.parent.mkdir(parents=True, exist_ok=True)
    grid.to_csv(grid_path, index=False, lineterminator='\n')
    summary_frame(summary).to_csv(summary_path, index=False,
                                  lineterminator='\n')
    return grid_path, summary_path


def main(argv=None):
    if env('RAC_PROFILE_FILE', None) is not None:
        print('contour_algorithm.calibrate_pixels: RAC_PROFILE_FILE is set; '
              'it is a test hook and a real run refuses it (decision A-049)',
              file=sys.stderr)
        return 2
    parser = argparse.ArgumentParser(
        prog='python -m contour_algorithm.calibrate_pixels',
        description='Pixel calibration of the RAC_DATASET profile (A-086).')
    parser.parse_args(argv)
    try:
        profile = load_profile()
        old_summary = None
        if profile.dataset != 'old':
            old_path = load_profile('old').prep_path('pixel_calibration')
            if not old_path.exists():
                raise ValueError(f'{old_path} is missing: run the OLD '
                                 'calibration first (rule (i), A-086)')
            old_summary = read_summary(old_path)
    except ValueError as e:
        print(f'contour_algorithm.calibrate_pixels: {e}', file=sys.stderr)
        return 2
    start = time.monotonic()
    grid, summary, details = calibrate(profile)
    if old_summary is not None:
        new_summary = {(s, n): _value_text(v) for s, n, v in summary}
        for crit in ('strict', 'dilated'):
            for k, v in rule_decision(old_summary, new_summary,
                                      crit).items():
                summary.append(('rule', f'{crit}.{k}', v))
    paths = write_outputs(profile, grid, summary)
    for name, (ev, _, _) in details.items():
        print(f'{name:32s} hits {ev["hits"]:6d} rate {ev["rate"]:.6f} '
              f'dilated {ev["rate_dil"]:.6f} mean_dist '
              f'{ev["mean_dist"]:.4f} outside {ev["n_outside"]} '
              f'diff_legacy {ev["n_diff_legacy"]} {ev["setting"]}')
    for s, n, v in summary:
        if s in ('conditions', 'rule') or (
                s == 'bootstrap' and '.draw_' not in n):
            print(f'{s}.{n} = {_value_text(v)}')
    print(f'wrote {paths[0]} and {paths[1]} '
          f'({time.monotonic() - start:.1f} s)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
