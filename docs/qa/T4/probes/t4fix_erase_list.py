"""The additions of the T4 review fixes to the NEW erase list (probe;
decision A-100).

Starts from the T4 list (the first 25 rows of
data/new_shoes/sticker_masks_new.csv, as committed at 1a69e26), adds the
23 rectangles of the review fixes, prints each added row with the contact
pixels it erases (all, inside the mask) and whether a RAC pixel lies in it,
checks that the 580 rectangles erase exactly the contact outside the
same-design heel envelope and that the 105 rectangles hold exactly its
debris blob, writes OUT.csv and says whether it equals the committed list.
The mask is the one of the work tree's step-0 run (images_new); the
proposal was made on the T4 run (mask 35,156 px).

usage (repo root):
  python -B docs/qa/T4/probes/t4fix_erase_list.py OUT.csv
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import ndimage as ndi

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO))
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.io_shoes import read_shoes  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402
from contour_algorithm.stickers import (apply_sticker_masks,  # noqa: E402
                                        read_sticker_masks)

p = load_profile('new')
raw = read_shoes(p.contacts, p.W, p.H, p.num_shoe)
committed = read_sticker_masks(p).iloc[:25].reset_index(drop=True)
assert len(committed) == 25 and set(committed['shoe']) == {
    148, 149, 186, 580, 582, 585, 586, 589}, 'not the T4 list'
mats, _ = apply_sticker_masks(raw, committed)
mask = np.load(p.saved_path(p.stem('prototype_mask'), 'npy'))
racs = q.rac_pixels(p)
rows = []


def runs(shoe, pix, reason):
    """1-row rectangles covering exactly the pixels (0-based (r, c))."""
    pix = sorted(set(map(tuple, pix)))
    by_row = {}
    for r, c in pix:
        by_row.setdefault(r, []).append(c)
    for r, cs in sorted(by_row.items()):
        start = prev = cs[0]
        for c in cs[1:] + [None]:
            if c is not None and c == prev + 1:
                prev = c
                continue
            rows.append((shoe, r + 1, r + 1, start + 1, prev + 1, reason))
            if c is not None:
                start = prev = c


def component_at(shoe, r0, r1, c0, c1):
    """0-based pixels of the 8-connected contact component of the kept
    record with the most pixels in the 1-based box rows r0-r1, cols
    c0-c1."""
    lab, _ = ndi.label(mats[shoe - 1], structure=np.ones((3, 3)))
    box = lab[r0 - 1:r1, c0 - 1:c1]
    ks, n = np.unique(box[box > 0], return_counts=True)
    assert len(ks), (shoe, r0, r1, c0, c1)
    return np.argwhere(lab == ks[np.argmax(n)])


# 584: straight frame line on row 334 under the heel
rows.append((584, 334, 334, 85, 185,
             'straight 1-px frame line under the heel (row 334, cols 89-180;'
             ' the heel ends on row 333 at cols 120-138; same batch as the '
             'erased lines of 580 and 585; T4 review)'))
# 586: the solid band remnant over the toe tip
rows.append((586, 37, 42, 105, 141,
             'solid band remnant over the toe tip (rows 37-42 hold 31-37 '
             'contact px per row in cols 105-141 against 0-5 on the '
             'same-design 587 aligned on the forefoot, shift +4 rows -1 col;'
             ' the real toe starts near row 41, so about 9 px of real toe '
             'tip go with it; T4 review)'))
# 580: the bar outside the heel envelope of the same design (583, 584):
# derived by heel_envelope() below and written out as rectangles
why580 = ('bar below the heel merged with the heel bottom: erased outside '
          'the heel envelope of the same-design 583 and 584 (aligned on the '
          'heel, shift -1 row +1 col, 1 px margin), so the heel keeps a '
          'rounded bottom ending on row 332; T4 review')
for r0, r1, c0, c1 in ((325, 325, 154, 167), (326, 326, 153, 167),
                       (327, 327, 151, 158), (328, 328, 150, 157),
                       (329, 329, 110, 112), (329, 329, 148, 158),
                       (330, 330, 109, 115), (330, 330, 147, 158),
                       (331, 331, 110, 116), (331, 331, 144, 158),
                       (332, 332, 110, 117), (332, 332, 141, 158),
                       (333, 334, 109, 158)):
    rows.append((580, r0, r1, c0, c1, why580))
r584 = raw[583].copy()
r584[333, :] = False  # 584 without its own frame line


def sh(img, dr, dc):
    return np.roll(np.roll(img, dr, axis=0), dc, axis=1)


env = sh(raw[582], -1, 1) | sh(r584, -1, 1)
pix = set()
for r in range(325, 335):
    c = np.flatnonzero(env[r - 1, 90:180]) + 91
    lo, hi = (c.min() - 1, c.max() + 1) if len(c) else (10 ** 6, -1)
    for cc in np.flatnonzero(mats[579, r - 1, 99:170]) + 100:
        if (cc < lo or cc > hi) and mask[r - 1, cc - 1]:
            pix.add((r, cc))
got = set()
for _, r0, r1, c0, c1, _ in [x for x in rows if x[0] == 580]:
    for r in range(r0, r1 + 1):
        for cc in range(c0, c1 + 1):
            if mats[579, r - 1, cc - 1]:
                got.add((r, cc))
print('580 rectangles erase exactly the contact outside the envelope:',
      got == pix, len(got))
# 148: the left end of the top frame line (3 px kept inside the mask)
rows.append((148, 30, 30, 87, 100,
             'left end of the top frame line on row 30 (3 px were kept '
             'inside the mask; T4 review)'))
# 186: frame-line remnants
rows.append((186, 31, 37, 157, 210,
             'right ends of the top double frame line beyond the toe (one '
             'pixel was kept inside the mask; T4 review)'))
rows.append((186, 33, 33, 95, 105,
             'left end of the top frame lines on row 33 (1 px inside the '
             'mask; T4 review)'))
rows.append((186, 212, 216, 187, 190,
             'piece of the vertical frame line right of the print (one pixel '
             'inside the mask; T4 review)'))
rows.append((186, 260, 263, 182, 184,
             'piece of the vertical frame line right of the print (one pixel '
             'inside the mask; T4 review)'))
# 105: the debris blob right of the toe (11 px inside the mask); two
# rectangles that hold the whole blob and no pixel of the toe
why105 = ('debris blob right of the toe tip, separate from the sole (96 px, '
          '11 of them inside the mask; T4 review)')
rows.append((105, 28, 37, 156, 169, why105))
rows.append((105, 38, 41, 159, 169, why105))
lab, _ = ndi.label(mats[104], structure=np.ones((3, 3)))
blob = set(map(tuple, np.argwhere(lab == lab[29, 157]) + 1))
inbox = set()
for _, r0, r1, c0, c1, _ in [x for x in rows if x[0] == 105]:
    for r in range(r0, r1 + 1):
        for cc in range(c0, c1 + 1):
            if mats[104, r - 1, cc - 1]:
                inbox.add((r, cc))
print('105 rectangles hold exactly the blob:', inbox == blob, len(blob))
# 481: a 6-px dash under the heel
rows.append((481, 335, 335, 80, 92,
             'isolated 6-px straight dash 2 rows below the heel, far left of '
             'it (frame-line fragment; T4 review)'))

new = pd.DataFrame(rows, columns=list(committed.columns))
table = pd.concat([committed, new], ignore_index=True)
out, erased = apply_sticker_masks(raw, table)
_, inside = apply_sticker_masks(raw & mask, table)
for k in range(len(committed), len(table)):
    r = table.iloc[k]
    rc = racs.get(int(r.shoe), np.zeros((0, 2), int))
    hit = ((rc[:, 0] >= r.row0 - 1) & (rc[:, 0] <= r.row1 - 1)
           & (rc[:, 1] >= r.col0 - 1) & (rc[:, 1] <= r.col1 - 1)).any()
    print(f'{r.shoe},{r.row0},{r.row1},{r.col0},{r.col1}: erased '
          f'{erased[k]} (in mask {inside[k]}){" RAC!" if hit else ""}')
print('total new erased', sum(erased[len(committed):]), 'in mask',
      sum(inside[len(committed):]), '; zero rows:',
      [k for k in range(len(table)) if erased[k] == 0])
table.to_csv(sys.argv[1], index=False, lineterminator='\n')
print('wrote', sys.argv[1], len(table), 'rows; equal to the committed list:',
      Path(sys.argv[1]).read_bytes() == p.sticker_masks.read_bytes())
