"""T0 read-only probes (part 2): provenance, frames, geometry.

Evidence for docs/plans/2026-11-05-new-shoes-pipeline.md. Reads the repo
data and the thesis repo's 2025-11-13 run outputs (images/saved/*.npy);
writes nothing. Run with the thesis venv python:

    VENV/bin/python -I -B t0_facts.py <repo_root> <thesis_repo_root>
"""
import sys

import cv2
import numpy as np
import pandas as pd
from PIL import Image

REPO, THESIS = sys.argv[1], sys.argv[2]


def load(path, w, h, n):
    """Fixed-stride reader: n records of w*h chars + CRLF, as bool."""
    raw = np.frombuffer(open(path, 'rb').read(), dtype=np.uint8)
    s = w * h + 2
    recs = np.stack([raw[i * s:i * s + w * h] for i in range(n)])
    return (recs.reshape(n, h, w) - 48).astype(bool)


def legacy_pixel(x, y, w, h):
    """1-indexed (col, row) exactly as R aspix_x / aspix_y with W, H."""
    c = w - (np.floor((x + 0.25) / (0.5 / 150)) + np.ceil((w - 150) / 2))
    r = h - (np.floor((y + 0.5) / (1.0 / 300)) + np.ceil((h - 300) / 2))
    return c.astype(int), r.astype(int)


def box(m):
    rows, cols = np.nonzero(m)
    return (f'rows {rows.min()}-{rows.max()} cols {cols.min()}-{cols.max()}'
            f' centroid (r={rows.mean():.1f}, c={cols.mean():.1f})'
            f' px={int(m.sum())}')


def section(title):
    print('\n=== ' + title)


OLD = load(f'{REPO}/data/contacts_data.txt', 307, 395, 387)
NEW = load(f'{REPO}/data/new_shoes/contacts_data_new.txt', 255, 367, 631)
CONT = load(f'{REPO}/data/contour_Active_Contour.txt', 307, 395, 386)

section('J. provenance of the committed OLD contour')
snakes = np.load(f'{THESIS}/images/saved/active-contour_all.npy')
keep = [i for i in range(snakes.shape[0]) if i != 126]
same = sum(bool(np.array_equal(snakes[i], CONT[k]))
           for k, i in enumerate(keep))
print('thesis images/saved/active-contour_all.npy shape', snakes.shape)
print(f'committed contour records equal to that npy (skip 0-idx 126): '
      f'{same} of {len(keep)}')
mats = np.load(f'{THESIS}/images/saved/list_matrices.npy')
print('thesis list_matrices[8] == raw shoe 9 unflipped:',
      bool(np.array_equal(mats[8], OLD[8])), '| == flipped:',
      bool(np.array_equal(mats[8], OLD[8][:, ::-1])))
fm_npy = np.load(f'{THESIS}/images/saved/freq_min_18.npy')
fm_png = np.array(Image.open(f'{REPO}/data/freq_min_18.png')).astype(bool)
ofm = np.load(f'{THESIS}/images/saved/old_freq_min_18.npy')
print('thesis freq_min_18.npy == repo data/freq_min_18.png:',
      bool(np.array_equal(fm_npy, fm_png)), '| px', int(fm_npy.sum()),
      '| old_freq_min_18.npy (superposition >=18) px', int(ofm.sum()))

section('K. coordinate frames, shoe 9, duplicates, 2023 mapping')
loc = pd.read_csv(f'{REPO}/data/locations_data.csv')
c, r = legacy_pixel(loc.x.values, loc.y.values, 307, 395)
x_frame = (c - 307 / 2) * 0.5 / 150
print('old corr(x in locations_data.csv, x of the RAC pixel in the R '
      'dataCC frame) =',
      round(float(np.corrcoef(loc.x.values, x_frame)[0, 1]), 6))
m9 = loc.shoe.values == 9
print('old shoe 9: RACs', int(m9.sum()), '| on contact unflipped',
      round(float(OLD[8][r[m9] - 1, c[m9] - 1].mean()), 3), '| flipped',
      round(float(OLD[8][:, ::-1][r[m9] - 1, c[m9] - 1].mean()), 3))
dup_old = loc.assign(c=c, r=r).duplicated(['shoe', 'c', 'r']).sum()
print('old RACs', len(loc), '| duplicate RAC pixels', int(dup_old),
      '| RAC pixels', len(loc) - int(dup_old))
raw = pd.read_csv(f'{REPO}/data/new_shoes/locations_data_new_raw.txt',
                  sep=r'\s+', header=None,
                  names=['shoe', 'rac', 'x', 'y', 'type'])
print('new raw sorted by shoe:', bool(raw.shoe.is_monotonic_increasing),
      '| rac_num consecutive from 1 in every shoe:',
      bool(raw.groupby('shoe').rac.apply(
          lambda s: list(s) == list(range(1, len(s) + 1))).all()))
print('new type values:', raw['type'].value_counts().sort_index().to_dict())
cn, rn = legacy_pixel(raw.x.values / 2, raw.y.values / 2, 255, 367)
inb = (cn >= 1) & (cn <= 255) & (rn >= 1) & (rn <= 367)
dup_new = raw.assign(c=cn, r=rn).duplicated(['shoe', 'c', 'r']).sum()
print('new legacy-generalized pixels in bounds:', int(inb.sum()), 'of',
      len(raw), '| duplicate RAC pixels', int(dup_new), '| RAC pixels',
      len(raw) - int(dup_new))
on = NEW[raw.shoe.values - 1, rn - 1, cn - 1].mean()
print(f'new legacy-generalized mapping: RACs on raw contact = {on:.4f}')
s23 = pd.read_csv(f'{REPO}/data/new_shoes/locations_new_snake_2023.csv')
print('2023 columns:', list(s23.columns))
print('2023 COL == legacy-generalized col:', bool((s23.COL == cn).all()),
      '| ROW == legacy-generalized row:', bool((s23.ROW == rn).all()))

section('L. prototype extents vs legacy init ellipses (0-indexed px)')
print('old data/freq_min_18.png (snake-filled):', box(fm_png))
print('old superposition >=18 (no flip, as in the Python run):',
      box(OLD.sum(0) >= 18))
for t in (18, 29):
    print(f'new superposition >={t}:', box(NEW.sum(0) >= t))
s = np.linspace(0, 2 * np.pi, 400)
for name, cy, cx, ry, rx in [('old', 200, 155, 162, 90),
                             ('new', 185, 128, 162, 95)]:
    rows, cols = cy + ry * np.sin(s), cx + rx * np.cos(s)
    print(f'{name} init ellipse: rows {rows.min():.0f}-{rows.max():.0f} '
          f'cols {cols.min():.0f}-{cols.max():.0f} (center {cy},{cx} '
          f'radii {ry},{rx})')
for name, recs in [('old', OLD), ('new', NEW)]:
    q = np.percentile(recs.sum((1, 2)), [5, 50, 95]).astype(int).tolist()
    print(f'{name} contact px/shoe p5/p50/p95: {q}')

section('M. legacy get_snake_image orientation for non-square images')
for w, h in [(307, 395), (255, 367)]:
    snake = np.array([[50.0, 20.0], [50.0, 21.0], [300.0, 200.0]])
    out = np.zeros((w, h))
    cv2.polylines(out, [np.int32(snake)], False, (255, 0, 0), thickness=1)
    png = cv2.imencode('.png', out)[1].tobytes()  # float64, as legacy
    img = cv2.transpose(cv2.imdecode(np.frombuffer(png, np.uint8),
                                     cv2.IMREAD_UNCHANGED))
    arr = np.array(Image.fromarray(img.astype(bool)), dtype=bool)
    print(f'W,H={w},{h}: shape {arr.shape} | (row 50, col 20) set '
          f'{bool(arr[50, 20])} | (row 300, col 200) set '
          f'{bool(arr[300, 200])} | swapped (row 20, col 50) set '
          f'{bool(arr[20, 50])}')
