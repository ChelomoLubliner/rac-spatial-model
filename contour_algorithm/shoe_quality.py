"""Per-shoe RAC contact diagnostics (plan T3 step 3c; decisions A-029,
A-089).

One row per shoe of a dataset, the shoes without RACs included (so the
table has num_shoe rows and lists them), with the RACs mapped by the
profile's pixel mapping (`calibrate_pixels.legacy_pixel`, the R `aspix`):

    shoe, n_rac, n_rac_pixels (distinct RAC pixels: step-1 cases),
    px (contact pixels of the record), n_on, rate (strict on-contact
    share), n_on_dil, rate_dil (1-pixel dilation), n_off, n_off_dil,
    n_outside (RACs mapped outside the image), best_shift_rate, best_dc,
    best_dr (the best rate over integer shifts of the RAC pixels within
    +-4 px, ties to the smallest |dc| + |dr|, then dc, then dr),
    best_flip_rate (the same over the left-right mirrored record),
    all_off, all_off_dil

The contact records are the ones step 1 reads before its stamp mask, with
the profile's `r.contact_flip_shoes` mirrored as in R (OLD shoe 9).
Command line (writes the profile's `prep.shoe_contact`):

    RAC_DATASET=old|new python -m contour_algorithm.shoe_quality
"""

import argparse
import sys

import numpy as np
import pandas as pd

from .calibrate_pixels import dilate, legacy_pixel, load_dataset, on_image
from .profiles import env, load_profile

MAX_SHIFT = 4
COLUMNS = ('shoe', 'n_rac', 'n_rac_pixels', 'px', 'n_on', 'rate',
           'n_on_dil', 'rate_dil', 'n_off', 'n_off_dil', 'n_outside',
           'best_shift_rate', 'best_dc', 'best_dr', 'best_flip_rate',
           'all_off', 'all_off_dil')


def _hits(img, col0, row0):
    h, w = img.shape
    ok = on_image(col0, row0, w, h)
    out = np.zeros(len(col0), dtype=bool)
    out[ok] = img[row0[ok], col0[ok]]
    return out


def best_shift(img, col0, row0, max_shift=MAX_SHIFT):
    """(best rate, dc, dr) over the integer shifts of the RAC pixels in
    [-max_shift, max_shift]^2; ties: smallest |dc| + |dr|, then dc, dr."""
    steps = np.arange(-max_shift, max_shift + 1)
    dc, dr = (a.ravel() for a in np.meshgrid(steps, steps, indexing='ij'))
    cc = col0[None, :] + dc[:, None]
    rr = row0[None, :] + dr[:, None]
    h, w = img.shape
    ok = (cc >= 0) & (cc < w) & (rr >= 0) & (rr < h)
    hit = np.zeros(cc.shape, dtype=bool)
    hit[ok] = img[rr[ok], cc[ok]]
    n_hit = hit.sum(axis=1)
    k = np.lexsort((dr, dc, np.abs(dc) + np.abs(dr), -n_hit))[0]
    return n_hit[k] / len(col0), int(dc[k]), int(dr[k])


def shoe_quality(contacts, shoe, col0, row0, num_shoe):
    """The per-shoe table (columns COLUMNS) for 1-based shoe ids `shoe`
    and 0-based RAC pixels `col0`, `row0`."""
    dilated = dilate(contacts)
    rows = []
    order = np.argsort(shoe, kind='stable')
    starts = np.searchsorted(shoe[order], np.arange(1, num_shoe + 2))
    for s in range(1, num_shoe + 1):
        idx = order[starts[s - 1]:starts[s]]
        img = contacts[s - 1]
        px = int(img.sum())
        n = len(idx)
        if n == 0:
            rows.append({'shoe': s, 'n_rac': 0, 'n_rac_pixels': 0, 'px': px,
                         'n_on': 0, 'rate': np.nan, 'n_on_dil': 0,
                         'rate_dil': np.nan, 'n_off': 0, 'n_off_dil': 0,
                         'n_outside': 0, 'best_shift_rate': np.nan,
                         'best_dc': 0, 'best_dr': 0,
                         'best_flip_rate': np.nan, 'all_off': False,
                         'all_off_dil': False})
            continue
        c, r = col0[idx], row0[idx]
        h, w = img.shape
        on = _hits(img, c, r)
        on_dil = _hits(dilated[s - 1], c, r)
        rate_b, dc, dr = best_shift(img, c, r)
        flip_b, _, _ = best_shift(img[:, ::-1], c, r)
        rows.append({
            'shoe': s, 'n_rac': n,
            'n_rac_pixels': len(set(zip(c.tolist(), r.tolist()))),
            'px': px, 'n_on': int(on.sum()), 'rate': on.mean(),
            'n_on_dil': int(on_dil.sum()), 'rate_dil': on_dil.mean(),
            'n_off': int(n - on.sum()), 'n_off_dil': int(n - on_dil.sum()),
            'n_outside': int((~on_image(c, r, w, h)).sum()),
            'best_shift_rate': rate_b, 'best_dc': dc, 'best_dr': dr,
            'best_flip_rate': flip_b, 'all_off': bool(not on.any()),
            'all_off_dil': bool(not on_dil.any())})
    return pd.DataFrame(rows, columns=list(COLUMNS))


def profile_table(profile, data=None):
    """The per-shoe table of a profile with its own pixel mapping."""
    if data is None:
        data = load_dataset(profile)
    col1, row1 = legacy_pixel(data['x'], data['y'], profile.coords,
                              profile.W, profile.H)
    return shoe_quality(data['contacts'], data['shoe'], col1 - 1, row1 - 1,
                        profile.num_shoe)


def old_quality_threshold(old_table, min_rac=10):
    """A-029: the 5th percentile of best_shift_rate over the OLD shoes
    with at least `min_rac` RACs (numpy's linear interpolation)."""
    g = old_table[old_table['n_rac'] >= min_rac]
    return float(np.percentile(g['best_shift_rate'], 5))


def summary_lines(t):
    """Readable lists of the table (printed by the command line)."""
    with_racs = t[t['n_rac'] > 0]
    out = [f'shoes {len(t)}, with RACs {len(with_racs)}, RACs '
           f'{int(t["n_rac"].sum())}',
           f'shoes without RACs: {t.loc[t["n_rac"] == 0, "shoe"].tolist()}',
           f'RACs off contact: strict {int(t["n_off"].sum())} '
           f'({t["n_off"].sum() / t["n_rac"].sum():.4f}), dilated '
           f'{int(t["n_off_dil"].sum())} '
           f'({t["n_off_dil"].sum() / t["n_rac"].sum():.4f}), outside the '
           f'image {int(t["n_outside"].sum())}',
           f'shoes with at least one RAC off contact: strict '
           f'{int((with_racs["n_off"] > 0).sum())}, dilated '
           f'{int((with_racs["n_off_dil"] > 0).sum())}',
           f'shoes with every RAC off contact: strict '
           f'{with_racs.loc[with_racs["all_off"], "shoe"].tolist()}, '
           f'dilated '
           f'{with_racs.loc[with_racs["all_off_dil"], "shoe"].tolist()}']
    for thr in (0.5, 0.6, 0.7):
        sel = with_racs[with_racs['rate'] < thr]
        out.append(f'rate < {thr}: {len(sel)} shoes, '
                   f'{int(sel["n_rac"].sum())} RACs')
    return out


def main(argv=None):
    if env('RAC_PROFILE_FILE', None) is not None:
        print('contour_algorithm.shoe_quality: RAC_PROFILE_FILE is set; it '
              'is a test hook and a real run refuses it (decision A-049)',
              file=sys.stderr)
        return 2
    parser = argparse.ArgumentParser(
        prog='python -m contour_algorithm.shoe_quality',
        description='Per-shoe RAC contact table of the RAC_DATASET profile.')
    parser.parse_args(argv)
    try:
        profile = load_profile()
        path = profile.prep_path('shoe_contact')
    except ValueError as e:
        print(f'contour_algorithm.shoe_quality: {e}', file=sys.stderr)
        return 2
    t = profile_table(profile)
    path.parent.mkdir(parents=True, exist_ok=True)
    t.to_csv(path, index=False, lineterminator='\n')
    for line in summary_lines(t):
        print(line)
    print(f'wrote {path} ({len(t)} rows)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
