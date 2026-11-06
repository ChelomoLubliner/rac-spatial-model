"""Per-shoe fallbacks on a few NEW shoes (scratch): data-driven init
ellipse and/or another closing radius. Prints metrics, saves a review
sheet. usage: fallback.py OUT.png SHOE [SHOE ...]"""
import dataclasses
import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
os.environ.setdefault('MPLBACKEND', 'Agg')
from contour_algorithm import active_contour_snake as acs  # noqa
from contour_algorithm import qa_snake as q  # noqa
from contour_algorithm.profiles import load_profile  # noqa

assert acs.numpy_blas_threads() == 1
p = load_profile('new')
run = q.load_run(p)
out_png, shoes = Path(sys.argv[1]), [int(s) for s in sys.argv[2:]]


def bbox_ellipse(shoe, margin):
    m = run['matrices'][shoe - 1] & run['mask']
    rr = np.flatnonzero(m.any(1))
    cc = np.flatnonzero(m.any(0))
    c = ((rr[0] + rr[-1]) / 2, (cc[0] + cc[-1]) / 2)
    # an ellipse through the bbox corners has radii half-extent * sqrt(2);
    # use the bbox half extents plus a margin (the corners of a sole are
    # rounded), as the profile ellipse does for the superposition
    return c, ((rr[-1] - rr[0]) / 2 + margin, (cc[-1] - cc[0]) / 2 + margin)


rows, tiles, labels, colours = [], [], [], []
VARIANTS = (('profile', {}), ('close16', {'first_closing_radius': 16}),
            ('close24', {'first_closing_radius': 24}))
for shoe in shoes:
    for name, kw in VARIANTS:
        kw = dict(kw)
        margin = kw.pop('_bbox', None)
        sp = dataclasses.replace(p.snake, **kw)
        if margin is not None:
            c, r = bbox_ellipse(shoe, margin)
            sp = dataclasses.replace(sp, center_rc=c, radii_rc=r)
        qp = dataclasses.replace(p, snake=sp)
        rec = {}
        arr = acs.active_contour_shoe(qp, None, False, False, shoe - 1,
                                      record=rec)
        k = shoe - 1
        rr = dict(run)
        rr['records'] = run['records'].copy()
        rr['records'][k] = arr
        for key in ('init', 'first', 'second'):
            rr[key] = run[key].copy()
            rr[key][k] = rec[key]
        cleaned = run['matrices'][k] & run['mask']
        rac = run['racs'].get(shoe, np.zeros((0, 2), int))
        m = q.snake_metrics(cleaned, arr, run['mask'], rec['second'], rac)
        m['qa_flags'] = q.flag_shoe(m)
        rows.append({'shoe': shoe, 'variant': name, **{
            c: m[c] for c in ('coverage', 'tightness', 'rac_coverage',
                              'self_intersections', 'turning',
                              'max_turn_deg', 'n_contour_px', 'qa_flags')}})
        tiles.append(q.review_tile(rr, shoe))
        labels.append(f'{shoe} {name} cov={m["coverage"]:.3f} '
                      f't={m["tightness"]:.2f} {m["qa_flags"]}')
        colours.append(q.YELLOW if m['qa_flags'] else q.WHITE)
pd.set_option('display.width', 200)
print(pd.DataFrame(rows).round(4).to_string(index=False))
q.contact_sheet(tiles, labels, colours, 3, out_png)
print('wrote', out_png)
