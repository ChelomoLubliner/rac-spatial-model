"""Align a same-design NEW shoe onto an artefact shoe (T4 review fixes
probe): the integer shift (dr, dc) of the template record that best
matches the target record over a reference region (Jaccard of the raw
contact), searched over +-12 px.

usage (repo root):
  python -B docs/qa/T4/probes/t4fix_align.py \\
      TARGET TEMPLATE R0 R1 C0 C1    (1-based inclusive region)
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm.io_shoes import read_shoes  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

p = load_profile('new')
raw = read_shoes(p.contacts, p.W, p.H, p.num_shoe)
t, s, r0, r1, c0, c1 = (int(a) for a in sys.argv[1:7])
A = raw[t - 1, r0 - 1:r1, c0 - 1:c1]
best = []
for dr in range(-12, 13):
    for dc in range(-12, 13):
        B = np.roll(np.roll(raw[s - 1], dr, axis=0), dc, axis=1)
        B = B[r0 - 1:r1, c0 - 1:c1]
        inter = (A & B).sum()
        union = (A | B).sum()
        best.append((inter / union, dr, dc, int(inter), int(A.sum()),
                     int(B.sum())))
best.sort(reverse=True)
print(f'target {t} template {s} region rows {r0}-{r1} cols {c0}-{c1}')
for j, dr, dc, inter, na, nb in best[:6]:
    print(f'  shift dr {dr:+d} dc {dc:+d}: jaccard {j:.3f} (overlap {inter},'
          f' target {na}, template {nb})')
