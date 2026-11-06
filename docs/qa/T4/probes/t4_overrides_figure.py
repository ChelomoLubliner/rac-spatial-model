"""Before/after figure of the per-shoe snake overrides (T4 probe; decision
A-097; plan T4 step 6 asks for the before/after images of every override).

For each shoe of the profile's snake overrides: the final snake with the
profile's parameters alone (before; recomputed here) and with the override
(after; the official step-0 run), each drawn on the raw shoe with the RAC
pixels (green inside the contour's row-span fill, magenta outside); the
labels name the closing radius of each (the profile's 10; the override's
24, or 16 where 24 breaks another band, A-102) and 'ell' where the
override gives the shoe its own initial ellipse (170, A-107). Needs the
NEW step-0 outputs with --qa and one OpenBLAS thread (checked).

usage (repo root):
  OPENBLAS_NUM_THREADS=1 RAC_DATASET=new python -B \\
      docs/qa/T4/probes/t4_overrides_figure.py
writes <snake_qa_dir>/overrides_before_after_new.png
"""
import dataclasses
import os
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
os.environ.setdefault('MPLBACKEND', 'Agg')
from contour_algorithm import active_contour_snake as acs  # noqa: E402
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

p = load_profile('new')
assert acs.numpy_blas_threads() == p.blas_threads
run = q.load_run(p)
before = dataclasses.replace(p, snake_overrides=None)
table = []
tiles, labels, colours = [], [], []
for shoe in sorted(acs.snake_overrides(p)):
    k = p.record_of_shoe(shoe)
    rec = {}
    arr = acs.active_contour_shoe(before, None, False, False, shoe - 1,
                                  record=rec)
    cleaned = run['matrices'][shoe - 1] & run['mask']
    racs = run['racs'].get(shoe, np.zeros((0, 2), int))
    r_before = before.snake.first_closing_radius
    sp_after = acs.snake_params(p, shoe)
    r_after = sp_after.first_closing_radius
    own_ellipse = ((sp_after.center_rc, sp_after.radii_rc)
                   != (p.snake.center_rc, p.snake.radii_rc))
    after_tag = f'after r{r_after}' + (' ell' if own_ellipse else '')
    for tag, record, second in ((f'before r{r_before}', arr, rec['second']),
                                (after_tag, run['records'][k],
                                 run['second'][shoe - 1])):
        r = dict(run)
        r['records'] = run['records'].copy()
        r['records'][k] = record
        r['second'] = run['second'].copy()
        r['second'][shoe - 1] = second
        m = q.snake_metrics(cleaned, record, run['mask'], second, racs)
        flags = q.flag_shoe(m)
        tiles.append(q.review_tile(r, shoe)[:, cleaned.shape[1] + 3:])
        labels.append(f'{shoe} {tag} cov={m["coverage"]:.3f} '
                      f't={m["tightness"]:.2f} rac={m["rac_coverage"]:.2f}')
        colours.append(q.YELLOW if flags else q.WHITE)
        table.append((shoe, tag, m['coverage'], m['tightness'],
                      m['rac_coverage'], flags))
out = q.snake_qa_path(p, 'overrides_before_after', 'png')
q.contact_sheet(tiles, labels, colours, 6, out)
for row in table:
    print(f'{row[0]:4d} {row[1]:10s} coverage {row[2]:.4f} tightness '
          f'{row[3]:.3f} rac {row[4]:.3f} flags {row[5] or "none"}')
print(f'wrote {out}')
