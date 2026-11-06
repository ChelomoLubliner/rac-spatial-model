"""Margin between the initial ellipse and the cleaned print, per shoe (T4
review fixes, scratch): cleaned pixels outside the ellipse and the
smallest margin min(1 - rho) * radius_r over the print (rho = normalized
ellipse radius; negative = print outside), for an ellipse given as
center_r center_c radius_r radius_c (default: the profile's).

usage (repo root):
  python -B docs/qa/T4/probes/t4fix_ellipse_margin.py \\
      DATASET ROOT [CR CC RR RC]
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm.profiles import load_profile  # noqa: E402

dataset, root = sys.argv[1], Path(sys.argv[2])
p = load_profile(dataset, root=root, file=root / 'config/datasets.json')
if len(sys.argv) > 3:
    cr, cc, rr, rc = (float(v) for v in sys.argv[3:7])
else:
    (cr, cc), (rr, rc) = p.snake.center_rc, p.snake.radii_rc
m = np.load(p.saved_path('list_matrices', 'npy'))
mask = np.load(p.saved_path(p.stem('prototype_mask'), 'npy'))
R, C = np.mgrid[0:p.H, 0:p.W]
rho = np.sqrt(((R - cr) / rr) ** 2 + ((C - cc) / rc) ** 2)
out, margin = [], []
for i in p.analysis_shoes():
    clean = m[i - 1] & mask
    out.append(int((clean & (rho > 1)).sum()))
    margin.append(float(((1 - rho[clean]) * rr).min()))
out, margin = np.array(out), np.array(margin)
shoes = np.array(p.analysis_shoes())
print(f'{dataset} ellipse ({cr}, {cc}) / ({rr}, {rc}): shoes with print '
      f'outside {int((out > 0).sum())} of {len(out)}; margin p1 '
      f'{np.quantile(margin, .01):.2f} p5 {np.quantile(margin, .05):.2f} '
      f'median {np.median(margin):.2f} px')
idx = np.argsort(-out)[:8]
print('  most print outside:', [(int(shoes[k]), int(out[k])) for k in idx])
