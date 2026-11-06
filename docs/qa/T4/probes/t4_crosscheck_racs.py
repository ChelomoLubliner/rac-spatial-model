"""Per-RAC cross-check of the NEW contour with the 2023 processing (T4
probe; the per-shoe table is `python -m contour_algorithm.qa_snake
--crosscheck`). For every RAC of data/new_shoes/locations_new_snake_2023.csv
(COL, ROW 1-based; INSIDE_SNAKE; DIST_SNAKE and HORIZ_DIST_SNAKE in pixels):
inside the new contour's row-span fill, the distance to the nearest new
contour pixel and the horizontal distance to the nearest contour pixel in
the same row; prints the agreement. Reads only.

usage (repo root): python -B docs/qa/T4/probes/t4_crosscheck_racs.py
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.io_shoes import read_shoes  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

p = load_profile('new')
old = pd.read_csv(p.cross_check)
rec = read_shoes(p.contour_out, p.W, p.H, len(p.analysis_shoes()))
rows = []
for s, g in old.groupby('shoe'):
    c = rec[p.record_of_shoe(int(s))]
    fill = q.row_span_fill(c)
    pts = np.argwhere(c)
    for r in g.itertuples(index=False):
        rr, cc = int(r.ROW) - 1, int(r.COL) - 1
        d = np.hypot(pts[:, 0] - rr, pts[:, 1] - cc).min()
        same = pts[pts[:, 0] == rr]
        h = np.abs(same[:, 1] - cc).min() if len(same) else np.nan
        rows.append((bool(fill[rr, cc]), d, h, r.INSIDE_SNAKE, r.DIST_SNAKE,
                     r.HORIZ_DIST_SNAKE))
t = pd.DataFrame(rows, columns=['in_new', 'd_new', 'h_new', 'in_2023',
                                'd_2023', 'h_2023'])
print(pd.crosstab(t.in_new, t.in_2023, margins=True))
both = t[t.in_new & (t.in_2023 == True)]  # noqa: E712
print('RACs inside both:', len(both))
for a, b in (('d_new', 'd_2023'), ('h_new', 'h_2023')):
    ok = both[[a, b]].dropna()
    dd = ok[a] - ok[b]
    print(f'{a} vs {b}: corr {ok[a].corr(ok[b]):.4f} | diff median '
          f'{dd.median():.3f} mean {dd.mean():.3f} p5 {dd.quantile(.05):.3f}'
          f' p95 {dd.quantile(.95):.3f} | |diff| <= 1: '
          f'{(dd.abs() <= 1).mean():.4f}, <= 2: {(dd.abs() <= 2).mean():.4f}')
