"""Side-by-side figure of NEW shoes' contours from other initial ellipses
(second T4 review fixes; decision A-107): one row per shoe, one tile per
ellipse tag of a t4fix2_ellipse_trial.py run, each over the cleaned shoe
(grey) with contact outside that tile's fill yellow, the committed record
blue, the tag's record orange (both: magenta), the tag's initial ellipse
red (its points) and the RAC pixels green; the label gives the tag, the
fill pixels gained and lost against the committed record, the recovered
pixels of print beyond the profile ellipse and the broken bands.

usage (repo root):
  RAC_DATASET=new python -B docs/qa/T4/probes/t4fix2_ellipse_figure.py \\
      TRIAL.csv TRIALDIR OUT.png SHOES TAGS ELLIPSES [r0 r1 c0 c1 [SCALE]]
SHOES: comma list; TAGS: comma list of the trial's tags ('profile' = the
committed parameters); ELLIPSES: 'TAG=cr,cc,rr,rc;TAG=...' as given to the
trial (the profile tag needs none); r0 r1 c0 c1: a 0-based crop.
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

trial = pd.read_csv(sys.argv[1], keep_default_na=False)
tdir, out = Path(sys.argv[2]), Path(sys.argv[3])
shoes = [int(s) for s in sys.argv[4].split(',')]
tags = sys.argv[5].split(',')
ellipses = {}
for spec in filter(None, sys.argv[6].split(';')):
    tag, vals = spec.split('=')
    ellipses[tag] = tuple(float(v) for v in vals.split(','))
p = load_profile('new')
r0, r1, c0, c1 = ((int(v) for v in sys.argv[7:11]) if len(sys.argv) >= 11
                  else (0, p.H, 0, p.W))
scale = int(sys.argv[11]) if len(sys.argv) >= 12 else 2
run = q.load_run(p)
rec_of = {s: k for k, s in enumerate(run['shoes'])}


def ellipse_points(tag, shoe):
    """The initial ellipse of a tag as (n_points, 2) (row, col)."""
    if tag == 'profile':
        return run['init'][shoe - 1]
    cr, cc, rr, rc = ellipses[tag]
    s = np.linspace(0, 2 * np.pi, p.snake.n_points)
    return np.stack([cr + rr * np.sin(s), cc + rc * np.cos(s)], axis=1)


tiles, labels, colours = [], [], []
for shoe in shoes:
    i, k = shoe - 1, rec_of[shoe]
    cleaned = run['matrices'][i] & run['mask']
    committed = run['records'][k]
    rac = run['racs'].get(shoe, np.zeros((0, 2), int))
    for tag in tags:
        rec = np.load(tdir / f'rec_{shoe}_{tag}.npy')
        fill = q.row_span_fill(rec)
        img = np.zeros(cleaned.shape + (3,), np.uint8)
        img[cleaned] = (150, 150, 150)
        img[cleaned & ~fill] = q.YELLOW
        img[rec] = q.ORANGE
        img[committed] = q.BLUE
        img[rec & committed] = q.MAGENTA
        img[rac[:, 0], rac[:, 1]] = (0, 220, 0)
        pts = np.round(ellipse_points(tag, shoe)).astype(int)
        ok = ((pts[:, 0] >= 0) & (pts[:, 0] < p.H) & (pts[:, 1] >= 0)
              & (pts[:, 1] < p.W))
        img[pts[ok, 0], pts[ok, 1]] = q.RED
        img = np.kron(img[r0:r1, c0:c1],
                      np.ones((scale, scale, 1), np.uint8))
        row = trial[(trial['shoe'] == shoe) & (trial['tag'] == tag)].iloc[0]
        tiles.append(img)
        labels.append(f'{shoe} {tag} +{row["fill_gained"]}/-'
                      f'{row["fill_lost"]} rec {row["recovered"]}/'
                      f'{row["lost"]} {row["flags"] or "ok"}')
        colours.append(q.YELLOW if row['flags'] else q.WHITE)
q.contact_sheet(tiles, labels, colours, len(tags), out, label_h=14)
print('wrote', out)
