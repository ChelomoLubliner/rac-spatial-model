"""Fallback closing radii on a set of NEW shoes, side by side (T4 review
fixes, scratch; the A-097 rule).

For each shoe: the official run's contour (its configuration: the profile
radius 10, or its override) and the snake recomputed with closing radius
16 and 24, each scored with the QA bands; review sheets show the raw shoe
(white kept, red removed by the mask, magenta erased), the final snake
(blue) and the RAC pixels (green inside the record fill, magenta outside),
cropped to the print area. Needs one OpenBLAS thread (checked).

usage (repo root):
  python -B docs/qa/T4/probes/t4fix_fallback.py \\
      OUTDIR JOBS SHOE [SHOE ...]
writes OUTDIR/fallback.csv, OUTDIR/fallback.pkl (records and snakes),
OUTDIR/sheet_<kk>.png (6 shoes per sheet)
"""
import dataclasses
import multiprocessing
import os
import pickle
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
os.environ.setdefault('MPLBACKEND', 'Agg')
from contour_algorithm import active_contour_snake as acs  # noqa: E402
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

assert acs.numpy_blas_threads() == 1
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
jobs = int(sys.argv[2])
shoes = [int(s) for s in sys.argv[3:]]
p = load_profile('new')
run = q.load_run(p)
RADII = (16, 24)
CROP = (slice(14, 356), slice(54, 206))


def job(args):
    shoe, radius = args
    sp = dataclasses.replace(acs.snake_params(p, shoe),
                             first_closing_radius=radius)
    qp = dataclasses.replace(p, snake=sp, snake_overrides=None)
    rec = {}
    arr = acs.active_contour_shoe(qp, None, False, False, shoe - 1,
                                  record=rec)
    return shoe, radius, arr, rec['second']


tasks = [(s, r) for s in shoes for r in RADII]
with multiprocessing.get_context('fork').Pool(jobs) as pool:
    res = pool.map(job, tasks)
res = {(s, r): (arr, second) for s, r, arr, second in res}
rows, keep = [], {}
for shoe in shoes:
    i, k = shoe - 1, p.record_of_shoe(shoe)
    official = acs.snake_params(p, shoe).first_closing_radius
    cleaned = run['matrices'][i] & run['mask']
    rac = run['racs'].get(shoe, np.zeros((0, 2), int))
    rr = run['raw_r'][i] & run['r_mask']
    variants = [('official r%d' % official, run['records'][k],
                 run['second'][i])]
    variants += [('r%d' % r, *res[(shoe, r)]) for r in RADII]
    for name, arr, second in variants:
        m = q.snake_metrics(cleaned, arr, run['mask'], second, rac, rr)
        flags = q.flag_shoe(m)
        rows.append({'shoe': shoe, 'variant': name, 'n_flags':
                     len(flags.split(';')) if flags else 0, **{
                         c: m[c] for c in (
                             'coverage', 'coverage_fill', 'tightness',
                             'rac_coverage', 'rac_out_max_px',
                             'contact_out_max_px', 'turning',
                             'max_turn_deg', 'n_contour_px',
                             'outside_mask_frac')}, 'qa_flags': flags})
        keep[(shoe, name)] = (arr, second)
table = pd.DataFrame(rows)
table.to_csv(out / 'fallback.csv', index=False)
with open(out / 'fallback.pkl', 'wb') as f:
    pickle.dump(keep, f)
pd.set_option('display.width', 250)
pd.set_option('display.max_rows', 500)
print(table.round(4).to_string(index=False))


def tile(shoe, arr, second):
    i = shoe - 1
    raw = run['matrices'][i]
    img = q.tile_final(raw, run['mask'], second, run['erased'][i])
    fill = q.row_span_fill(arr)
    for r, c in run['racs'].get(shoe, np.zeros((0, 2), int)):
        colour = q.GREEN if fill[r, c] else q.MAGENTA
        img[max(r - 1, 0):r + 2, max(c - 1, 0):c + 2] = colour
    from PIL import Image
    crop = img[CROP]
    big = Image.fromarray(crop).resize((crop.shape[1] * 3 // 2,
                                        crop.shape[0] * 3 // 2),
                                       Image.NEAREST)
    return np.asarray(big)


per = 6
for kk in range(0, len(shoes), per):
    part = shoes[kk:kk + per]
    tiles, labels, colours = [], [], []
    for shoe in part:
        for name in [n for (s, n) in keep if s == shoe]:
            arr, second = keep[(shoe, name)]
            r = table[(table.shoe == shoe) & (table.variant == name)].iloc[0]
            tiles.append(tile(shoe, arr, second))
            labels.append(f'{shoe} {name} c{r.coverage:.3f} '
                          f'rac{r.rac_coverage:.2f} n{r.n_flags}')
            colours.append(q.YELLOW if r.qa_flags else q.WHITE)
    q.contact_sheet(tiles, labels, colours, 6,
                    out / f'sheet_{kk // per + 1:02d}.png')
print('sheets in', out)
