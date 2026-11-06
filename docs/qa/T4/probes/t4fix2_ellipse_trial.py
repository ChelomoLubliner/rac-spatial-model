"""Rerun chosen NEW shoes' snakes from other initial ellipses (or with
another first-snake closing radius) and score each contour against the
step-0 run of the work tree (second T4 review fixes; decision A-107).
Writes only OUT.csv and, per shoe and variant, the record as
OUTDIR/rec_<shoe>_<tag>.npy (for the figures of
t4fix2_ellipse_figure.py).

Each shoe keeps its own snake parameters (the profile's, with its
override if it has one); a variant TAG=cr,cc,rr,rc replaces only the
ellipse, TAG=rN only the closing radius (N). Per run:
the QA metrics and broken bands (qa_snake.snake_metrics, flag_shoe), the
cleaned print outside the new ellipse, how many of the pixels that the
committed contour leaves outside beyond the profile ellipse ("lost") lie
inside the new fill ("recovered"), the fill pixels gained and lost against
the committed record, and the change of the per-row width (median,
largest absolute) over the rows both fills cover. Tag 'profile' reruns the
shoe's own committed parameters (it must give the committed record: a
check of the probe). Needs one OpenBLAS thread (checked).

usage (repo root):
  OPENBLAS_NUM_THREADS=1 RAC_DATASET=new python -B \\
      docs/qa/T4/probes/t4fix2_ellipse_trial.py OUT.csv OUTDIR \\
      SHOES|lost TAG=cr,cc,rr,rc|TAG=rN [...] [--jobs=N]
SHOES: comma list of 1-based shoe ids, or 'lost' (every shoe whose
cleaned print beyond its initial ellipse lies partly outside its fill).
"""
import dataclasses
import multiprocessing
import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
os.environ.setdefault('MPLBACKEND', 'Agg')
from contour_algorithm import active_contour_snake as acs  # noqa: E402
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith('--jobs')]
jobs = 14
for a in sys.argv[1:]:
    if a.startswith('--jobs='):
        jobs = int(a.split('=', 1)[1])
out_csv, out_dir, which = Path(args[0]), Path(args[1]), args[2]
ellipses = {'profile': None}
for spec in args[3:]:
    tag, vals = spec.split('=')
    if vals.startswith('r'):
        ellipses[tag] = {'first_closing_radius': int(vals[1:])}
        continue
    cr, cc, rr, rc = (float(v) for v in vals.split(','))
    ellipses[tag] = {'center_rc': (cr, cc), 'radii_rc': (rr, rc)}
out_dir.mkdir(parents=True, exist_ok=True)

p = load_profile('new')
acs.check_blas_threads(p)
run = q.load_run(p)
rec_of = {s: k for k, s in enumerate(run['shoes'])}


def lost_pixels(shoe):
    """Cleaned print outside the shoe's initial ellipse polygon and
    outside its committed fill (0-based bool image)."""
    i = shoe - 1
    cleaned = run['matrices'][i] & run['mask']
    ell = q.polygon_mask(run['init'][i], cleaned.shape)
    fill = q.row_span_fill(run['records'][rec_of[shoe]])
    return cleaned & ~ell & ~fill


if which == 'lost':
    shoes = [s for s in run['shoes'] if lost_pixels(s).any()]
else:
    shoes = [int(s) for s in which.split(',')]


def job(task):
    shoe, tag = task
    sp = acs.snake_params(p, shoe)
    if ellipses[tag] is not None:
        sp = dataclasses.replace(sp, **ellipses[tag])
    qp = dataclasses.replace(p, snake=sp, snake_overrides=None)
    rec = {}
    arr = acs.active_contour_shoe(qp, None, False, False, shoe - 1,
                                  record=rec)
    return shoe, tag, arr, rec['second'], rec['init']


tasks = [(s, t) for s in shoes for t in ellipses]
with multiprocessing.get_context('fork').Pool(jobs) as pool:
    results = pool.map(job, tasks)


def widths(fill):
    rows = np.flatnonzero(fill.any(axis=1))
    w = np.full(fill.shape[0], np.nan)
    w[rows] = fill[rows].sum(axis=1)
    return w


table = []
for shoe, tag, arr, second, init in results:
    i, k = shoe - 1, rec_of[shoe]
    cleaned = run['matrices'][i] & run['mask']
    rac = run['racs'].get(shoe, np.zeros((0, 2), int))
    r_contact = run['raw_r'][i] & run['r_mask']
    if len(rac):
        r_contact = r_contact.copy()
        r_contact[rac[:, 0], rac[:, 1]] = True
    m = q.snake_metrics(cleaned, arr, run['mask'], second, rac, r_contact)
    fill = q.row_span_fill(arr)
    old = run['records'][k]
    old_fill = q.row_span_fill(old)
    lost = lost_pixels(shoe)
    ell = q.polygon_mask(init, cleaned.shape)
    dw = widths(fill) - widths(old_fill)
    dw = dw[~np.isnan(dw)]
    np.save(out_dir / f'rec_{shoe}_{tag}.npy', arr)
    table.append(dict(
        shoe=shoe, tag=tag, same_as_committed=bool(np.array_equal(arr, old)),
        print_outside_ellipse=int((cleaned & ~ell).sum()),
        lost=int(lost.sum()), recovered=int((lost & fill).sum()),
        fill_gained=int((fill & ~old_fill).sum()),
        fill_lost=int((old_fill & ~fill).sum()),
        dwidth_median=float(np.median(dw)) if len(dw) else np.nan,
        dwidth_maxabs=float(np.abs(dw).max()) if len(dw) else np.nan,
        rows_first_last=(f'{np.flatnonzero(fill.any(axis=1))[[0, -1]]}'),
        **{key: m[key] for key in (
            'coverage', 'coverage_fill', 'tightness', 'turning',
            'max_turn_deg', 'rac_coverage', 'rac_out_max_px',
            'contact_out_max_px', 'n_contour_px', 'outside_mask_frac',
            'self_intersections')},
        flags=q.flag_shoe(m)))
t = pd.DataFrame(table).sort_values(['shoe', 'tag'], key=lambda c: c.map(
    lambda v: (list(ellipses).index(v) if v in ellipses else v)))
t.to_csv(out_csv, index=False, float_format='%.4f')
pd.set_option('display.width', 250)
pd.set_option('display.max_rows', 500)
print(t[['shoe', 'tag', 'same_as_committed', 'print_outside_ellipse', 'lost',
         'recovered', 'fill_gained', 'fill_lost', 'dwidth_median',
         'dwidth_maxabs', 'coverage', 'coverage_fill', 'tightness',
         'contact_out_max_px', 'flags']].to_string(index=False))
print('wrote', out_csv, len(t), 'rows')
