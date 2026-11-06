"""Zoom on the NEW shoes whose contact surface S or sampled controls lie
outside the contour's row-span fill (T5 step-1 QA; reads
s_outside_contour_new.csv written by t5_step1_sheets.py).

Writes <out>/s_outside_zoom_new.png: for every shoe with a control outside
the fill and the 6 shoes with the largest distance of S from the fill, the
whole shoe at 2x: S white, S outside the fill orange, the contour blue, the
fill boundary implied by the contour (the row ends) as drawn, RAC pixels
green, controls yellow (controls outside the fill: red 5 x 5 squares).

Usage (repo root, thesis venv python), after t5_step1_sheets.py has
written s_outside_contour_new.csv into the same OUT_DIR (T5 review fixes;
docs/qa/T5/new holds the committed copy):
  RAC_DATASET=new PYTHONPATH=. python -B \
      docs/qa/T5/probes/t5_step1_sheets.py OUT_DIR
  RAC_DATASET=new PYTHONPATH=. python -B \
      docs/qa/T5/probes/t5_step1_zoom.py OUT_DIR
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw

from contour_algorithm.calibrate_pixels import legacy_pixel
from contour_algorithm.io_shoes import read_shoes
from contour_algorithm.locations import read_locations
from contour_algorithm.profiles import load_profile
from contour_algorithm.stickers import apply_sticker_masks, read_sticker_masks

sys.path.insert(0, str(Path(__file__).parent))
from t5_step1_sheets import pixel_of, rowfill  # noqa: E402

U8 = np.uint8


def main(out_dir):
    p = load_profile()
    out_dir = Path(out_dir)
    tab = pd.read_csv(out_dir / f's_outside_contour{p.suffix}.csv')
    pick = tab[tab.controls_out_fill > 0].shoe.tolist()
    for s in tab.sort_values('s_out_fill_max_px', ascending=False).shoe:
        if len(pick) >= len(tab[tab.controls_out_fill > 0]) + 6:
            break
        if s not in pick:
            pick.append(int(s))
    shoes = list(p.analysis_shoes())
    raw, _ = apply_sticker_masks(read_shoes(p.contacts, p.W, p.H,
                                            p.num_shoe),
                                 read_sticker_masks(p))
    mask = pd.read_csv(p.r_path('all_cont')).to_numpy() != 0
    cont = read_shoes(p.contour_out, p.W, p.H, len(shoes))
    loc = read_locations(p)
    col, row = legacy_pixel(loc.x.to_numpy(), loc.y.to_numpy(), p.coords,
                            p.W, p.H)
    cc = pd.read_csv(p.r_path('dataCC'))
    cc['col'], cc['row'] = pixel_of(cc.x, cc.y, p)
    tiles = []
    for s in pick:
        k = shoes.index(s)
        rac = np.zeros((p.H, p.W), bool)
        sel = loc.shoe.to_numpy() == s
        rac[row[sel] - 1, col[sel] - 1] = True
        S = (raw[s - 1] & mask) | rac
        fill = rowfill(cont[k])
        t = np.zeros((p.H, p.W, 3), U8)
        t[S] = (255, 255, 255)
        t[S & ~fill] = (255, 140, 0)
        t[cont[k].astype(bool)] = (40, 120, 255)
        t[rac] = (0, 220, 0)
        ctrl = cc[(cc.shoe == k + 1) & (cc.n_Acc == 0)]
        big = np.kron(t, np.ones((2, 2, 1), U8))
        im = Image.fromarray(big)
        d = ImageDraw.Draw(im)
        for c1, r1 in zip(ctrl.col, ctrl.row):
            out = not fill[r1 - 1, c1 - 1]
            x, y = 2 * (c1 - 1), 2 * (r1 - 1)
            d.rectangle([x - 4, y - 4, x + 5, y + 5] if out else
                        [x - 1, y - 1, x + 2, y + 2],
                        outline=(255, 0, 0) if out else (255, 230, 0),
                        width=2 if out else 1)
        r = tab[tab.shoe == s].iloc[0]
        d.text((4, 4), f'{s}: S out {r.s_out_fill_px} px, max '
               f'{r.s_out_fill_max_px} px; controls out '
               f'{r.controls_out_fill}', fill=(255, 255, 0))
        tiles.append(np.array(im))
    w = max(t.shape[1] for t in tiles)
    rows = [np.hstack(tiles[i:i + 6] + [np.zeros_like(tiles[0])] *
                      (6 - len(tiles[i:i + 6])))
            for i in range(0, len(tiles), 6)]
    out = out_dir / f's_outside_zoom{p.suffix}.png'
    Image.fromarray(np.vstack(rows)).save(out)
    print(out, 'shoes', pick, 'tile width', w)


if __name__ == '__main__':
    main(*sys.argv[1:])
