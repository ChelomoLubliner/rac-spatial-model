"""Figures of the R stamp mask (plan T3 step 4, carried into T5; A-110).

Reads the masks and superposition counts that t5_stamp_mask.R wrote to a
scratch folder, the step-0 cleaning masks (images/saved/freq_min_18.png is
data/freq_min_18.png for OLD; images_new/saved/freq_min_18_new.png for NEW),
the raw records (erase list applied, as step 1 reads them) and the RAC
pixels, and writes:

  <new>/stamp_mask_new.png      NEW: the mask of threshold 13 and of 8,
                                same colours as docs/qa/T0/old_rmask_stamps
                                .png (white = R mask, red = >= t but removed
                                by the sweep, blue = step-0 cleaning mask
                                outside the R mask, grey = contact on any
                                shoe outside both), orange = in the t = 8
                                mask but not in the t = 13 one; the OLD
                                committed mask (t = 8) beside them
  <new>/stamp_worst_new.png     the 12 NEW shoes that lose the largest
                                share of their contact to the t = 13 mask:
                                raw contact kept (white), removed by t = 13
                                only (orange), removed by both (red), RAC
                                pixels (green), the t = 13 mask outline
                                (blue)

Usage (repo root, thesis venv python), in this order (T5 review fixes:
the probe does not run from a clean clone without its prerequisites):
  1. NEW step 0 must have run in this tree, for the gitignored
     images_new/saved/freq_min_18_new.png (RAC_DATASET=new
     python -m contour_algorithm.main --jobs 14; on this machine it
     rewrites the committed NEW contour with the same bytes), or run 2 and
     3 from the repo/ folder of a `tests/rebuild_new.sh --keep` run;
  2. Rscript docs/qa/T5/probes/t5_stamp_mask.R NEW_DIR COMPARE_DIR SCRATCH
     (writes the masks and counts to SCRATCH and stamp_shoes_new.csv to
     NEW_DIR);
  3. PYTHONPATH=. python -B docs/qa/T5/probes/t5_stamp_figure.py \
         NEW_DIR SCRATCH        (the same NEW_DIR and SCRATCH as in 2)
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw
from scipy import ndimage

from contour_algorithm.io_shoes import read_shoes
from contour_algorithm.calibrate_pixels import legacy_pixel
from contour_algorithm.locations import read_locations
from contour_algorithm.profiles import load_profile
from contour_algorithm.stickers import apply_sticker_masks, read_sticker_masks

U8 = np.uint8


def load_mask(scr, name):
    return pd.read_csv(scr / name).to_numpy() != 0


def overlay(mask, sum_raw, t, proto, extra=None):
    img = np.zeros(mask.shape + (3,), U8)
    img[sum_raw >= 1] = (90, 90, 90)
    img[proto & ~mask] = (0, 0, 255)
    img[mask] = (255, 255, 255)
    img[(sum_raw >= t) & ~mask] = (255, 0, 0)
    if extra is not None:
        img[extra] = (255, 150, 0)
    return img


def up(arr, k=2):
    return np.kron(arr, np.ones((k, k, 1), U8))


def pad_to(arr, h):
    out = np.zeros((h, arr.shape[1], 3), U8)
    out[:arr.shape[0]] = arr
    return out


def main(new_dir, scr):
    repo = Path.cwd()
    new_dir, scr = Path(new_dir), Path(scr)
    p_new, p_old = load_profile('new'), load_profile('old')
    s_new = pd.read_csv(scr / 'new_sum.csv').to_numpy()
    s_old = pd.read_csv(scr / 'old_sum.csv').to_numpy()
    m8 = load_mask(scr, 'new_t8_mask.csv')
    m13 = load_mask(scr, 'new_t13_mask.csv')
    mo = load_mask(scr, 'old_t8_mask.csv')
    proto_new = np.array(Image.open(
        repo / 'images_new/saved/freq_min_18_new.png')) > 0
    proto_old = np.array(Image.open(repo / 'data/freq_min_18.png')) > 0
    a = overlay(m13, s_new, 13, proto_new, extra=m8 & ~m13)
    b = overlay(m8, s_new, 8, proto_new)
    c = overlay(mo, s_old, 8, proto_old)
    h = max(a.shape[0], c.shape[0])
    sep = np.full((h, 8, 3), 128, U8)
    fig = np.hstack([pad_to(a, h), sep, pad_to(b, h), sep, pad_to(c, h)])
    out = new_dir / 'stamp_mask_new.png'
    Image.fromarray(up(fig)).save(out)
    print(out, fig.shape, 'x2')
    for name, m in (('t8', m8), ('t13', m13), ('old t8', mo)):
        lab, n = ndimage.label(m)
        sizes = np.bincount(lab.ravel())[1:]
        stray = [(int(sizes[k]), [int(v) + 1 for v in
                                  np.argwhere(lab == k + 1)[0]])
                 for k in np.argsort(sizes)[:-1]]
        n4 = ndimage.label(m, np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))[1]
        print(f'{name}: {m.sum()} px, {n} components (4-connectivity: '
              f'{n4}); components other than the main one (size, first '
              f'1-based row/col): {stray}')
    ring = m8 & ~m13
    rows = np.flatnonzero(ring.any(1))
    print(f'ring t8 minus t13: {ring.sum()} px, rows {rows.min() + 1}-'
          f'{rows.max() + 1}; inside the step-0 mask: '
          f'{(ring & proto_new).sum()} px')

    # the shoes that lose the most to the t = 13 mask
    shoes = pd.read_csv(new_dir / 'stamp_shoes_new.csv')
    t13 = shoes[shoes.threshold == 13].set_index('shoe')
    worst = t13.kept_share.sort_values().index[:12].tolist()
    raw = read_shoes(p_new.contacts, p_new.W, p_new.H, p_new.num_shoe)
    raw, _ = apply_sticker_masks(raw, read_sticker_masks(p_new))
    loc = read_locations(p_new)
    col, row = legacy_pixel(loc.x.to_numpy(), loc.y.to_numpy(), p_new.coords,
                            p_new.W, p_new.H)
    edge13 = m13 & ~ndimage.binary_erosion(m13)
    tiles = []
    for s in worst:
        r = raw[s - 1].astype(bool)
        t = np.zeros(r.shape + (3,), U8)
        t[r & m13] = (255, 255, 255)
        t[r & m8 & ~m13] = (255, 150, 0)
        t[r & ~m8] = (255, 0, 0)
        t[edge13 & ~r] = (0, 90, 255)
        sel = loc.shoe.to_numpy() == s
        t[row[sel] - 1, col[sel] - 1] = (0, 220, 0)
        im = Image.fromarray(up(t, 2))
        d = ImageDraw.Draw(im)
        k8 = shoes[(shoes.threshold == 8) & (shoes.shoe == s)]
        d.text((4, 4), f'{s}: kept {t13.kept_share[s]:.3f} (t13) '
               f'{k8.kept_share.iloc[0]:.3f} (t8)', fill=(255, 255, 0))
        tiles.append(np.array(im))
    rows_img = [np.hstack(tiles[i:i + 6]) for i in range(0, 12, 6)]
    out2 = new_dir / 'stamp_worst_new.png'
    Image.fromarray(np.vstack(rows_img)).save(out2)
    print(out2, 'shoes', worst)
    print(t13.loc[worst, ['contact_px', 'kept_px', 'kept_share', 'rac_px',
                          'rac_px_off_mask']].to_string())
    print('OLD reference kept share (t = 8) lowest:')
    old = pd.read_csv(scr / 'old_stamp_shoes.csv').sort_values('kept_share')
    print(old.head(8)[['shoe', 'contact_px', 'kept_px',
                       'kept_share']].to_string(index=False))
    print('p_old shoes', p_old.num_shoe)


if __name__ == '__main__':
    main(*sys.argv[1:])
