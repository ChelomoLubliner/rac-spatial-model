"""Figures of the NEW heel-front band (T5 review fixes; the statistics
reviewer's major finding 1; decision A-114).

The contact surface S of every analysis shoe, built as step 1 builds it
(raw record, erase list, flips, the R stamp mask all_cont, plus the RAC
pixels), and its RAC pixels, for both datasets. NEW group A = ids 1-343 and
442-490 (found post hoc from the O/E per block of 49 ids,
docs/qa/T5/probes/t5_gof.R section E), group B = the other NEW shoes. The
band is y in (-0.18, -0.10] (y = (H/2 - row) / 300, step 1's frame).

Writes
  <compare>/heel_front_band_old_vs_new.png
      top: the share of shoes with contact at each pixel, NEW group A,
      NEW group B, OLD (each in its own frame, the band between two cyan
      lines); middle: RAC pixels per contact pixel in 6 x 6 px blocks (one
      colour scale; blocks with fewer than 200 contact px blank); bottom:
      RAC pixels per contact pixel by 6-row bin of y for NEW A, NEW B, OLD
      and the OLD prints of the 50 group-A same_shoe reprints (T0), and the
      contact share per bin, the band shaded
  <new>/heel_front_band_shoes_new.png
      per block of 49 NEW ids (one row each, 13 rows), the 7 shoes with the
      most contact in the band, cropped to rows 150-300 (y 0.112 to
      -0.388): S white, RAC pixels green (3 x 3), the band rows between cyan
      lines; label: id, group, contact px in the band, RAC px in the band

Usage (repo root, thesis venv python; reads committed files only):
  PYTHONPATH=. python -B docs/qa/T5/probes/t5_band_figure.py \
      COMPARE_DIR NEW_DIR
"""
import sys
from pathlib import Path

import matplotlib
import numpy as np
import pandas as pd
from PIL import Image

from contour_algorithm.calibrate_pixels import legacy_pixel
from contour_algorithm.io_shoes import read_shoes
from contour_algorithm.locations import read_locations
from contour_algorithm.profiles import load_profile
from contour_algorithm.qa_sheets import contact_sheet
from contour_algorithm.stickers import apply_sticker_masks, read_sticker_masks

matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402

U8 = np.uint8
LO, HI = -0.18, -0.10
A_C, B_C, OLD_C, REP_C = '#eb6834', '#2a9d5c', '#2a78d6', '#7a4fc2'
CROP = (150, 300)


def is_a(ids):
    ids = np.asarray(ids)
    return (ids <= 343) | ((ids >= 442) & (ids <= 490))


def row_y(p):
    """y of each image row (1-based row r: y = (H/2 - r) / scale)."""
    scale = p.coords.rel_col_shoe / p.coords.rel_Y_cord
    return (p.H / 2 - np.arange(1, p.H + 1)) / scale


def surfaces(p):
    """{shoe id: (S, rac)} of every analysis shoe, step 1's construction;
    checked against the step-1 pixel counts."""
    shoes = list(p.analysis_shoes())
    stored = read_shoes(p.contacts, p.W, p.H, p.num_shoe)
    raw, _ = apply_sticker_masks(stored, read_sticker_masks(p))
    for s in p.r['contact_flip_shoes']:
        raw[int(s) - 1] = raw[int(s) - 1][:, ::-1]
    mask = pd.read_csv(p.r_path('all_cont')).to_numpy() != 0
    loc = read_locations(p)
    col, row = legacy_pixel(loc.x.to_numpy(), loc.y.to_numpy(), p.coords,
                            p.W, p.H)
    counts = pd.read_csv(p.r_path('pixel_counts'))
    assert list(counts.shoe) == shoes
    out = {}
    for s, n in zip(shoes, counts.pixel_count):
        rac = np.zeros((p.H, p.W), bool)
        sel = loc.shoe.to_numpy() == s
        rac[row[sel] - 1, col[sel] - 1] = True
        S = (raw[s - 1].astype(bool) & mask) | rac
        assert S.sum() == n, (s, S.sum(), n)
        out[s] = (S, rac)
    return out


def pooled(surf, ids):
    S = sum(surf[s][0].astype(np.int32) for s in ids)
    R = sum(surf[s][1].astype(np.int32) for s in ids)
    return S, R


def block_ratio(S, R, k=6, min_s=200):
    h, w = S.shape
    hh, ww = h // k * k, w // k * k
    s = S[:hh, :ww].reshape(hh // k, k, ww // k, k).sum(axis=(1, 3))
    r = R[:hh, :ww].reshape(hh // k, k, ww // k, k).sum(axis=(1, 3))
    out = np.full(s.shape, np.nan)
    ok = s >= min_s
    out[ok] = r[ok] / s[ok]
    return out


def profile(S, R, y, width=6):
    """RAC px per contact px and the contact share by bins of `width` rows
    (from the bottom row up)."""
    n = len(y)
    edges = np.arange(n, 0, -width)
    ys, ratio, share = [], [], []
    for e in edges:
        b = slice(max(0, e - width), e)
        s, r = S[b].sum(), R[b].sum()
        ys.append(y[b].mean())
        ratio.append(r / s if s >= 500 else np.nan)
        share.append(s)
    share = np.array(share, float)
    return np.array(ys), np.array(ratio), share / share.sum()


def band_lines(ax, p, color='#00c8ff'):
    y = row_y(p)
    rows = np.flatnonzero((y > LO) & (y <= HI))
    for r in (rows.min() - 0.5, rows.max() + 0.5):
        ax.axhline(r, color=color, lw=0.8)


def main(cmp_dir, new_dir):
    cmp_dir, new_dir = Path(cmp_dir), Path(new_dir)
    p_new, p_old = load_profile('new'), load_profile('old')
    s_new, s_old = surfaces(p_new), surfaces(p_old)
    ids_new = np.array(sorted(s_new))
    grp_a = ids_new[is_a(ids_new)]
    grp_b = ids_new[~is_a(ids_new)]
    v = pd.read_csv('docs/qa/T0/compare/overlap_verdicts_t0_old_vs_new.csv')
    v = v[(v.verdict == 'same_shoe') & is_a(v.new)]
    rep_old = sorted(v.old)
    sets = [('NEW group A', p_new, s_new, grp_a, A_C),
            ('NEW group B', p_new, s_new, grp_b, B_C),
            ('OLD', p_old, s_old, sorted(s_old), OLD_C)]
    fig = plt.figure(figsize=(15, 15), dpi=110, layout='constrained')
    gs = fig.add_gridspec(3, 3, height_ratios=[1.25, 1.25, 1])
    ratios = []
    for j, (name, p, surf, ids, _) in enumerate(sets):
        S, R = pooled(surf, ids)
        ax = fig.add_subplot(gs[0, j])
        ax.imshow(S / len(ids), cmap='gray', vmin=0, vmax=1)
        band_lines(ax, p)
        ax.set_title(f'{name} ({len(ids)} shoes): share with contact',
                     fontsize=10)
        ax.set_xticks([])
        ax.set_ylabel('image row')
        ratios.append(block_ratio(S, R))
    vmax = np.nanpercentile(np.concatenate([r[np.isfinite(r)].ravel()
                                            for r in ratios]), 99)
    for j, (name, p, surf, ids, _) in enumerate(sets):
        ax = fig.add_subplot(gs[1, j])
        im = ax.imshow(ratios[j], cmap='magma', vmin=0, vmax=vmax,
                       extent=(-0.5, ratios[j].shape[1] * 6 - 0.5,
                               ratios[j].shape[0] * 6 - 0.5, -0.5))
        ax.set_xlim(-0.5, p.W - 0.5)
        ax.set_ylim(p.H - 0.5, -0.5)
        band_lines(ax, p)
        ax.set_title(f'{name}: RAC px per contact px', fontsize=10)
        ax.set_xticks([])
        ax.set_ylabel('image row')
    fig.colorbar(im, ax=fig.axes[3:6], shrink=0.6,
                 label='RAC px per contact px (6 x 6 px blocks)')
    ax = fig.add_subplot(gs[2, :2])
    ax2 = fig.add_subplot(gs[2, 2])
    prof_sets = sets + [('OLD prints of the 50 group-A reprints', p_old,
                         s_old, rep_old, REP_C)]
    for name, p, surf, ids, c in prof_sets:
        S, R = pooled(surf, ids)
        y, ratio, share = profile(S.sum(axis=1), R.sum(axis=1), row_y(p))
        ax.plot(y, ratio, color=c, lw=1.6, label=name,
                ls='--' if name.startswith('OLD prints') else '-')
        ax2.plot(y, share, color=c, lw=1.4,
                 ls='--' if name.startswith('OLD prints') else '-')
    for a in (ax, ax2):
        a.axvspan(LO, HI, color='#00c8ff', alpha=0.18, lw=0)
        a.set_xlabel('y (heel left, toe right)')
        a.grid(alpha=0.3)
    ax.set_ylabel('RAC px per contact px (6-row bins)')
    ax.legend(fontsize=9, loc='upper left')
    ax.set_title('RAC density along the shoe; the band y (-0.18, -0.10] '
                 'shaded', fontsize=10)
    ax2.set_ylabel('share of the contact px')
    ax2.set_title('contact share per 6-row bin', fontsize=10)
    fig.suptitle('NEW heel-front band: contact without RACs on group A '
                 '(t5_band_figure.py)', fontsize=12)
    out = cmp_dir / 'heel_front_band_old_vs_new.png'
    fig.savefig(out, facecolor='white')
    plt.close(fig)
    print(out)
    # the per-shoe crops
    y = row_y(p_new)
    band = (y > LO) & (y <= HI)
    rows = np.flatnonzero(band)
    tiles, labels = [], []
    summary = []
    for k in range(13):
        blk = ids_new[(ids_new - 1) // 49 == k]
        sb = np.array([s_new[s][0][band].sum() for s in blk])
        rb = np.array([s_new[s][1][band].sum() for s in blk])
        summary.append((k + 1, blk.min(), blk.max(), int(is_a(blk).all()),
                        int((sb >= 50).sum()), int((rb > 0).sum()),
                        int(sb.sum()), int(rb.sum())))
        for i in np.argsort(-sb, kind='stable')[:7]:
            s = blk[i]
            S, R = s_new[s]
            t = np.zeros((p_new.H, p_new.W, 3), U8)
            t[S] = (255, 255, 255)
            rr, cc = np.nonzero(R)
            for dr in (-1, 0, 1):
                for dc in (-1, 0, 1):
                    t[np.clip(rr + dr, 0, p_new.H - 1),
                      np.clip(cc + dc, 0, p_new.W - 1)] = (0, 220, 0)
            t[rows.min() - 1, :] = (0, 200, 255)
            t[rows.max() + 1, :] = (0, 200, 255)
            tiles.append(t[CROP[0] - 1:CROP[1]])
            labels.append(f'{s} {"A" if is_a([s])[0] else "B"} S{sb[i]} '
                          f'R{rb[i]}')
    out2 = new_dir / 'heel_front_band_shoes_new.png'
    contact_sheet(tiles, labels, 7, out2)
    print(out2, Image.open(out2).size)
    print('block ids      all_A  shoes_S>=50  shoes_RAC  S_band  RAC_band')
    for b in summary:
        print(f'{b[0]:5d} {b[1]:3d}-{b[2]:<3d}  {b[3]:5d}  {b[4]:11d}  '
              f'{b[5]:9d}  {b[6]:6d}  {b[7]:8d}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
