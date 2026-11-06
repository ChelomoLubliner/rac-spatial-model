"""Screen the cleaned NEW shoes for marks that are not sole (scratch).

For each shoe: (1) extent loss under a 3x3 opening (thin lines at the
toe or heel vanish; how many rows/cols the extent shrinks at each side);
(2) fragments detached from the print body after a 4-px dilation (the
largest component = the body); (3) long thin horizontal runs (vertical
thickness <= 2) of >= 20 px in the outer 15 rows of the print.
"""
import sys
from pathlib import Path

import numpy as np
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm.profiles import load_profile  # noqa

p = load_profile('new')
mat = np.load(p.saved_path('list_matrices', 'npy'))
mask = np.load(p.saved_path(p.stem('prototype_mask'), 'npy'))
rows = []
st3 = np.ones((3, 3), bool)
for i in range(len(mat)):
    c = mat[i] & mask
    rr = np.flatnonzero(c.any(1))
    cc = np.flatnonzero(c.any(0))
    o = ndi.binary_opening(c, st3)
    orr = np.flatnonzero(o.any(1))
    occ = np.flatnonzero(o.any(0))
    loss = (orr[0] - rr[0], rr[-1] - orr[-1], occ[0] - cc[0], cc[-1] - occ[-1])
    d = ndi.binary_dilation(c, iterations=4)
    lab, n = ndi.label(d, np.ones((3, 3)))
    sizes = ndi.sum(c, lab, range(1, n + 1))
    body = int(np.argmax(sizes)) + 1
    frag = [(int(s)) for k, s in enumerate(sizes, 1) if k != body and s > 0]
    # thin horizontal runs in the outer 15 rows (top and bottom)
    thick = np.zeros_like(c, dtype=np.int16)
    for col in range(c.shape[1]):
        lab1, n1 = ndi.label(c[:, col])
        if n1:
            ln = ndi.sum(c[:, col], lab1, range(1, n1 + 1))
            thick[:, col] = np.where(lab1 > 0, ln[np.maximum(lab1 - 1, 0)], 0)
    thin = c & (thick <= 2)
    best = 0
    for r in list(range(rr[0], min(rr[0] + 15, rr[-1]))) + list(
            range(max(rr[-1] - 15, rr[0]), rr[-1] + 1)):
        lab2, n2 = ndi.label(thin[r])
        if n2:
            best = max(best, int(ndi.sum(thin[r], lab2,
                                         range(1, n2 + 1)).max()))
    rows.append((i + 1, *map(int, loss), len(frag), int(sum(frag)),
                 max(frag) if frag else 0, best))
import pandas as pd  # noqa
t = pd.DataFrame(rows, columns=['shoe', 'loss_top', 'loss_bottom',
                                'loss_left', 'loss_right', 'n_frag',
                                'frag_px', 'frag_max', 'thin_run'])
t.to_csv(sys.argv[1], index=False)
pd.set_option('display.width', 200)
print(t.describe(percentiles=[.5, .9, .95, .99]).T)
cand = t[(t[['loss_top', 'loss_bottom', 'loss_left', 'loss_right']].max(1)
          >= 3) | (t.frag_max >= 15) | (t.thin_run >= 20)]
print(len(cand), 'candidates')
print(cand.to_string())
