"""Side-by-side zooms of fallback variants around the part that triggers
the flag (T4 review fixes probe).

usage (repo root):
  python -B docs/qa/T4/probes/t4fix_focus.py \\
      FBDIR OUT.png SCALE SHOE [SHOE ...]
Window: 110 rows x 90 cols around the farthest cleaned-contact or RAC
pixel outside the official record's fill (the shoe's centre if none),
clipped to the image. One row per shoe, one tile per variant: white
cleaned contact, red removed by the mask, magenta erased, dark blue the
record fill, blue the record, RAC pixels green inside / magenta outside
(3 x 3).
"""
import pickle
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

fb, out, scale = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
p = load_profile('new')
run = q.load_run(p)
with open(fb / 'fallback.pkl', 'rb') as f:
    keep = pickle.load(f)
tiles, labels = [], []
H, W = p.H, p.W
for shoe in (int(s) for s in sys.argv[4:]):
    i = shoe - 1
    raw = run['matrices'][i]
    clean = raw & run['mask']
    names = [n for (s, n) in keep if s == shoe]
    fill0 = q.row_span_fill(keep[(shoe, names[0])][0])
    d = ndi.distance_transform_edt(~fill0)
    cand = np.where(clean, d, -1.0)
    for r, c in run['racs'].get(shoe, np.zeros((0, 2), int)):
        cand[r, c] = max(cand[r, c], d[r, c] + 0.01)
    if cand.max() > 0:
        r, c = np.unravel_index(np.argmax(cand), cand.shape)
    else:
        r, c = H // 2, W // 2
    r0 = int(np.clip(r - 55, 0, H - 110))
    c0 = int(np.clip(c - 45, 0, W - 90))
    for name in names:
        arr = keep[(shoe, name)][0]
        fill = q.row_span_fill(arr)
        img = np.zeros(raw.shape + (3,), np.uint8)
        img[fill] = (20, 30, 70)
        img[clean] = (235, 235, 235)
        img[raw & ~run['mask']] = (230, 30, 30)
        img[run['erased'][i]] = (255, 60, 255)
        img[arr] = (40, 110, 255)
        for rr, cc in run['racs'].get(shoe, np.zeros((0, 2), int)):
            img[max(rr - 1, 0):rr + 2, max(cc - 1, 0):cc + 2] = (
                (0, 220, 0) if fill[rr, cc] else (255, 0, 255))
        crop = img[r0:r0 + 110, c0:c0 + 90]
        tiles.append(np.asarray(Image.fromarray(crop).resize(
            (crop.shape[1] * scale, crop.shape[0] * scale), Image.NEAREST)))
        labels.append(f'{shoe} {name} r{r0 + 1}-{r0 + 110} '
                      f'c{c0 + 1}-{c0 + 90}')
q.contact_sheet(tiles, labels, [q.WHITE] * len(tiles), 3, out)
print('wrote', out)
