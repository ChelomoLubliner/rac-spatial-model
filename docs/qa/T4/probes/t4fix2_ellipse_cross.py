"""Where the cleaned print lies outside each shoe's initial ellipse, and
how much of it the final contour leaves outside (second T4 review fixes;
decision A-107; the vision reviewer's finding 1).

The ellipse is the one the shoe's snakes started from (saved/snake_points
of the step-0 run with --qa: the profile's, or the shoe's own override),
as the closed polygon of its n_points. Per shoe with print outside it:
pixels outside, by part of the sole (toe: rows < 120, heel: rows > 250,
side: between; 0-based rows), how many of them lie outside the record's
row-span fill (the contour that step 2 uses: not recovered by the snakes),
and the rows they span. Also the same count for the analytic ellipse
(rho > 1), which the T4 review fixes used (A-105).

usage (repo root, after NEW step 0 with --qa):
  RAC_DATASET=new python -B docs/qa/T4/probes/t4fix2_ellipse_cross.py
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.active_contour_snake import snake_params  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

TOE_ROWS, HEEL_ROWS = 120, 250
p = load_profile()
run = q.load_run(p)
R, C = np.mgrid[0:p.H, 0:p.W]
rows = []
n_analytic = 0
for k, shoe in enumerate(run['shoes']):
    i = shoe - 1
    cleaned = run['matrices'][i] & run['mask']
    ell = q.polygon_mask(run['init'][i], cleaned.shape)
    sp = snake_params(p, shoe)
    (cr, cc), (rr, rc) = sp.center_rc, sp.radii_rc
    rho = np.sqrt(((R - cr) / rr) ** 2 + ((C - cc) / rc) ** 2)
    n_analytic += bool((cleaned & (rho > 1)).any())
    out = cleaned & ~ell
    if not out.any():
        continue
    fill = q.row_span_fill(run['records'][k])
    rr_, _ = np.nonzero(out)
    toe = rr_ < TOE_ROWS
    heel = rr_ > HEEL_ROWS
    lost = out & ~fill
    lr, _ = np.nonzero(lost)
    rows.append(dict(
        shoe=shoe, out=int(out.sum()), toe=int(toe.sum()),
        side=int((~toe & ~heel).sum()), heel=int(heel.sum()),
        lost=int(lost.sum()), lost_toe=int((lr < TOE_ROWS).sum()),
        lost_heel=int((lr > HEEL_ROWS).sum()), rmin=int(rr_.min()),
        rmax=int(rr_.max())))
rows.sort(key=lambda d: (-d['lost'], -d['out']))
print('shoe out toe side heel lost lost_toe lost_heel rmin rmax')
for d in rows:
    print(*d.values())
toe = [d['shoe'] for d in rows if d['toe']]
heel = [d['shoe'] for d in rows if d['heel']]
side = [d['shoe'] for d in rows if d['side']]
print(f'{p.dataset}: {len(rows)} shoes with cleaned print outside the '
      f'initial ellipse polygon ({n_analytic} by the analytic ellipse); '
      f'{sum(d["out"] for d in rows)} px, of them '
      f'{sum(d["lost"] for d in rows)} outside the record fill')
print(f'  at the toe: {len(toe)} shoes, {sum(d["toe"] for d in rows)} px, '
      f'{sum(d["lost_toe"] for d in rows)} outside the fill')
print(f'  at the heel: {len(heel)} shoes, {sum(d["heel"] for d in rows)} '
      f'px, {sum(d["lost_heel"] for d in rows)} outside the fill: '
      f'{sorted(heel)}')
print(f'  at the sides: {len(side)} shoes; at toe and heel: '
      f'{sorted(set(toe) & set(heel))}')
print('  shoes with print beyond the ellipse outside the fill:',
      sorted(d['shoe'] for d in rows if d['lost']))
