"""Is the ring that the NEW stamp threshold 13 removes beyond 8 real sole?
(T5, decision A-110.)

Reads the NEW masks of thresholds 8 and 13 that t5_stamp_mask.R wrote to a
scratch folder, the raw NEW records (erase list applied, as step 1 reads
them) and the committed NEW contour, and prints how many contact pixels of
the ring (t = 8 mask minus t = 13 mask) lie inside each shoe's own contour
row-span fill, and the same split for what the t = 8 mask removes.

Usage (repo root, thesis venv python):
  PYTHONPATH=. python -B docs/qa/T5/probes/t5_stamp_ring.py SCRATCH
"""
import sys

import numpy as np
import pandas as pd

from contour_algorithm.io_shoes import read_shoes
from contour_algorithm.profiles import load_profile
from contour_algorithm.stickers import apply_sticker_masks, read_sticker_masks


def rowfill(c):
    f = np.zeros(c.shape, bool)
    for i in range(c.shape[0]):
        j = np.flatnonzero(c[i])
        if j.size:
            f[i, j.min():j.max() + 1] = True
    return f


def main(scr):
    p = load_profile('new')
    raw = read_shoes(p.contacts, p.W, p.H, p.num_shoe)
    raw, _ = apply_sticker_masks(raw, read_sticker_masks(p))
    cont = read_shoes(p.contour_out, p.W, p.H, len(p.analysis_shoes()))
    m8 = pd.read_csv(f'{scr}/new_t8_mask.csv').to_numpy() != 0
    m13 = pd.read_csv(f'{scr}/new_t13_mask.csv').to_numpy() != 0
    ring = m8 & ~m13
    tot_in = tot_out = both_in = both_out = 0
    out_shoes = {}
    for k in range(p.num_shoe):
        fill = rowfill(cont[k])
        r = raw[k] & ring
        tot_in += int((r & fill).sum())
        o = int((r & ~fill).sum())
        tot_out += o
        if o:
            out_shoes[k + 1] = o
        rb = raw[k] & ~m8
        both_in += int((rb & fill).sum())
        both_out += int((rb & ~fill).sum())
    top = sorted(out_shoes.items(), key=lambda kv: -kv[1])[:10]
    print(f'contact in the ring (t8 mask minus t13 mask): {tot_in + tot_out} '
          f'px; inside the shoe\'s own contour fill {tot_in}, outside '
          f'{tot_out} on {len(out_shoes)} shoes {top}')
    print(f'contact removed by the t8 mask itself: inside the contour fill '
          f'{both_in}, outside {both_out}')


if __name__ == '__main__':
    main(*sys.argv[1:])
