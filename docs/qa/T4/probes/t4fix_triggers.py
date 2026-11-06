"""Absolute-distance triggers on the committed contours (T4 review fixes
probe): per shoe, how far the farthest RAC pixel and the farthest
cleaned contact pixel lie outside the contour record's row-span fill
(Euclidean distance to the nearest fill pixel, in px), NEW and OLD.

usage (repo root):
  python -B docs/qa/T4/probes/t4fix_triggers.py \\
      OUT.csv DATASET [ROOT]
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.ndimage import distance_transform_edt

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO))
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

out, dataset = sys.argv[1], sys.argv[2]
root = Path(sys.argv[3]) if len(sys.argv) > 3 else REPO
p = load_profile(dataset, root=root, file=root / 'config/datasets.json')
run = q.load_run(p)
rows = []
for k, shoe in enumerate(run['shoes']):
    i = shoe - 1
    fill = q.row_span_fill(run['records'][k])
    d = distance_transform_edt(~fill)
    cleaned = run['matrices'][i] & run['mask']
    rac = run['racs'].get(shoe, np.zeros((0, 2), int))
    rd = d[rac[:, 0], rac[:, 1]] if len(rac) else np.zeros(0)
    cd = d[cleaned]
    rows.append({'shoe': shoe, 'n_rac': len(rac),
                 'rac_out_n': int((rd > 0).sum()),
                 'rac_out_max_px': float(rd.max()) if len(rd) else 0.0,
                 'contact_out_px': int((cd > 0).sum()),
                 'contact_out_max_px': float(cd.max()) if len(cd) else 0.0,
                 'contact_out_gt8_px': int((cd > 8).sum())})
t = pd.DataFrame(rows)
t.to_csv(out, index=False)
print(f'{dataset}: {len(t)} shoes')
for thr in (2, 2.9, 4, 6):
    print(f'  RAC outside the fill by > {thr} px: '
          f'{int((t.rac_out_max_px > thr).sum())} shoes')
for thr in (4, 6, 8, 10, 12):
    print(f'  cleaned contact outside the fill by > {thr} px: '
          f'{int((t.contact_out_max_px > thr).sum())} shoes')
print('  quantiles rac_out_max_px', t.rac_out_max_px.quantile(
    [.5, .9, .95, .99]).round(2).tolist(), 'max', t.rac_out_max_px.max())
print('  quantiles contact_out_max_px', t.contact_out_max_px.quantile(
    [.5, .9, .95, .99]).round(2).tolist(), 'max', t.contact_out_max_px.max())
