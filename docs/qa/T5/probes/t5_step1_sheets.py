"""Step-1 QA of the NEW contact surfaces (T5; user rule 10: every NEW shoe
looked at, no sticker in the contact surface).

For every analysis shoe of a profile: the contact surface S of step 1 (the
raw record with the erase list applied, times the R stamp mask
`all_cont`, plus every RAC pixel), what the R mask removed, the snake
contour (its row-span fill is what step 2 sees), the RAC pixels and the
controls that step 1 sampled (dataCC). Writes

  <out>/s_sheet_<kk>_<suffix>.png   7 x 7 tiles per sheet, 1 px = 1 px:
      white  = S (the pixels step 1 may sample as controls, and the RACs)
      red    = raw contact removed by the R stamp mask
      magenta= raw contact erased by the erase list (frame artefacts)
      blue   = the snake contour of the shoe
      green  = RAC pixels (cases), yellow 3 x 3 = the sampled controls
      label  = shoe, S px, removed px, RACs, controls outside the fill
  <out>/s_outside_contour<suffix>.csv  per shoe: S px, S px outside the
      contour's row-span fill and the largest distance (px) of S from it,
      raw contact removed by the mask inside / outside the fill, cases
      and controls outside the fill, controls on S (must be all)

Usage (repo root, thesis venv python, RAC_DATASET=new|old):
  PYTHONPATH=. python -B docs/qa/T5/probes/t5_step1_sheets.py OUT_DIR
"""
import math
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import ndimage

from contour_algorithm.calibrate_pixels import legacy_pixel
from contour_algorithm.io_shoes import read_shoes
from contour_algorithm.locations import read_locations
from contour_algorithm.profiles import load_profile
from contour_algorithm.qa_sheets import contact_sheet
from contour_algorithm.stickers import apply_sticker_masks, read_sticker_masks

U8 = np.uint8
PER_SHEET = 49
NCOLS = 7


def rowfill(c):
    f = np.zeros(c.shape, bool)
    for i in range(c.shape[0]):
        j = np.flatnonzero(c[i])
        if j.size:
            f[i, j.min():j.max() + 1] = True
    return f


def pixel_of(x, y, p):
    """1-based (col, row) of the data-frame coordinates of step 1:
    x = (c - W/2) / scale, y = -(r - H/2) / scale (scale = rel_col_shoe /
    rel_Y_cord, 300 px per unit)."""
    scale = p.coords.rel_col_shoe / p.coords.rel_Y_cord
    c = np.rint(np.asarray(x) * scale + p.W / 2).astype(int)
    r = np.rint(p.H / 2 - np.asarray(y) * scale).astype(int)
    return c, r


def main(out_dir):
    p = load_profile()
    out_dir = Path(out_dir)
    shoes = list(p.analysis_shoes())
    stored = read_shoes(p.contacts, p.W, p.H, p.num_shoe)
    raw, _ = apply_sticker_masks(stored, read_sticker_masks(p))
    for s in p.r['contact_flip_shoes']:
        raw[int(s) - 1] = raw[int(s) - 1][:, ::-1]
        stored[int(s) - 1] = stored[int(s) - 1][:, ::-1]
    mask = pd.read_csv(p.r_path('all_cont')).to_numpy() != 0
    assert mask.shape == (p.H, p.W)
    cont = read_shoes(p.contour_out, p.W, p.H, len(shoes))
    loc = read_locations(p)
    col, row = legacy_pixel(loc.x.to_numpy(), loc.y.to_numpy(), p.coords,
                            p.W, p.H)
    cc = pd.read_csv(p.r_path('dataCC'))
    codes = pd.read_csv(p.r_path('shoe_codes'))
    assert list(codes.shoe) == shoes
    cc['shoe_id'] = codes.shoe.to_numpy()[cc.shoe.to_numpy() - 1]
    cc['col'], cc['row'] = pixel_of(cc.x, cc.y, p)
    rows, tiles, labels = [], [], []
    for k, s in enumerate(shoes):
        r = raw[s - 1]
        rac = np.zeros(r.shape, bool)
        sel = loc.shoe.to_numpy() == s
        rac[row[sel] - 1, col[sel] - 1] = True
        S = (r & mask) | rac
        fill = rowfill(cont[k])
        dist = ndimage.distance_transform_edt(~fill)
        out_s = S & ~fill
        removed = r & ~mask
        c_s = cc[cc.shoe_id == s]
        ctrl = c_s[c_s.n_Acc == 0]
        case = c_s[c_s.n_Acc > 0]
        cr, ccol = ctrl.row.to_numpy() - 1, ctrl.col.to_numpy() - 1
        kr, kcol = case.row.to_numpy() - 1, case.col.to_numpy() - 1
        rows.append(dict(
            shoe=s, s_px=int(S.sum()), s_out_fill_px=int(out_s.sum()),
            s_out_fill_max_px=round(float(dist[out_s].max()), 3)
            if out_s.any() else 0.0,
            removed_px=int(removed.sum()),
            removed_in_fill_px=int((removed & fill).sum()),
            removed_out_fill_px=int((removed & ~fill).sum()),
            erased_px=int((stored[s - 1] & ~r).sum()),
            n_cases=len(case), n_controls=len(ctrl),
            cases_out_fill=int((~fill[kr, kcol]).sum()),
            controls_out_fill=int((~fill[cr, ccol]).sum()),
            controls_on_s=int(S[cr, ccol].sum()),
            cases_are_rac=int(rac[kr, kcol].sum())))
        t = np.zeros(r.shape + (3,), U8)
        t[S] = (255, 255, 255)
        t[removed] = (230, 0, 0)
        t[stored[s - 1] & ~r] = (255, 0, 255)
        t[cont[k].astype(bool)] = (40, 120, 255)
        t[rac] = (0, 220, 0)
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                rr = np.clip(cr + dr, 0, p.H - 1)
                c2 = np.clip(ccol + dc, 0, p.W - 1)
                t[rr, c2] = (255, 230, 0)
        tiles.append(t)
        labels.append(f'{s}: S {S.sum()} rm {removed.sum()} rac '
                      f'{rac.sum()} co {rows[-1]["controls_out_fill"]}')
    table = pd.DataFrame(rows)
    out_csv = out_dir / f's_outside_contour{p.suffix}.csv'
    table.to_csv(out_csv, index=False, lineterminator='\n')
    print(out_csv)
    for j in range(math.ceil(len(tiles) / PER_SHEET)):
        sl = slice(j * PER_SHEET, (j + 1) * PER_SHEET)
        f = out_dir / f's_sheet_{j + 1:02d}{p.suffix}.png'
        contact_sheet(tiles[sl], labels[sl], NCOLS, f)
        print(f)
    print('controls on S:', int(table.controls_on_s.sum()), 'of',
          int(table.n_controls.sum()))
    print('cases that are RAC pixels:', int(table.cases_are_rac.sum()), 'of',
          int(table.n_cases.sum()))
    print('S px outside the contour fill: total',
          int(table.s_out_fill_px.sum()), 'on',
          int((table.s_out_fill_px > 0).sum()), 'shoes; largest distance',
          float(table.s_out_fill_max_px.max()))
    print('controls outside the fill:', int(table.controls_out_fill.sum()),
          'on', int((table.controls_out_fill > 0).sum()), 'shoes; cases '
          'outside:', int(table.cases_out_fill.sum()))
    print('raw contact removed by the mask: inside the fill',
          int(table.removed_in_fill_px.sum()), 'outside',
          int(table.removed_out_fill_px.sum()))
    worst = table.sort_values('s_out_fill_max_px', ascending=False).head(15)
    print(worst.to_string(index=False))


if __name__ == '__main__':
    main(*sys.argv[1:])
