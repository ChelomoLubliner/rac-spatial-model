"""T0 review-fix probe: draw the overlap candidates found only by the
two-half statistic of t0_review.py (section R8), with RACs marked as
matched under the per-half shifts (green) or not (red).

Fix of 2026-11-06 (second T0 review, engineer finding 1): the OLD tile
label and the printed image r and rank now belong to the drawn two-half
partner (old2h). Before, they came from the CSV columns sym, r and
img_rank of the rigid partner (old), which differs for NEW 92 (rigid OLD
63, two-half OLD 103). The image correlation is recomputed here exactly
as in t0_review.py (blur 2 px, subsample 2, unit norm, all 387 OLD
images, OLD cropped to the NEW frame).

Reads the committed data and docs/qa/T0/compare/
overlap_screen_t0_old_vs_new.csv (written by t0_review.py); writes PNGs
to <out_dir>/compare/overlap_pairs/:

    VENV/bin/python -I -B t0_review_pairs.py <repo_root> <out_dir>
"""
import sys

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw
from scipy import ndimage

REPO, OUT = sys.argv[1], sys.argv[2]


def load(path, w, h, n):
    raw = np.frombuffer(open(path, 'rb').read(), dtype=np.uint8)
    stride = w * h + 2
    recs = np.stack([raw[i * stride:i * stride + w * h] for i in range(n)])
    return (recs.reshape(n, h, w) - 48).astype(bool)


OLD = load(f'{REPO}/data/contacts_data.txt', 307, 395, 387)
OLD = OLD[:, 14:381, 26:281]  # aligned with the NEW frame
NEW = load(f'{REPO}/data/new_shoes/contacts_data_new.txt', 255, 367, 631)
LOC = {'old': pd.read_csv(f'{REPO}/data/locations_data.csv')}
_raw = pd.read_csv(f'{REPO}/data/new_shoes/locations_data_new_raw.txt',
                   sep=r'\s+', header=None,
                   names=['shoe', 'rac', 'x', 'y', 'type'])
LOC['new'] = pd.DataFrame({'shoe': _raw.shoe, 'x': _raw.x / 2,
                           'y': _raw.y / 2})
PTS = {ds: {s: np.c_[g.x, g.y].astype(float) * 300
            for s, g in LOC[ds].groupby('shoe')} for ds in ('old', 'new')}


def feats(a):
    """Image features of t0_review.py section R5."""
    f = np.stack([ndimage.gaussian_filter(x.astype(np.float32), 2.0)[::2, ::2]
                  for x in a]).reshape(len(a), -1)
    f -= f.mean(1, keepdims=True)
    f /= np.linalg.norm(f, axis=1, keepdims=True)
    return f


C_NO = feats(NEW) @ feats(OLD).T


def sym_match(a, b, box=8.0, tol=1.0):
    """Same definition as t0_review.py."""
    d = a[:, None, :] - b[None, :, :]
    keep = (np.abs(d[..., 0]) <= box) & (np.abs(d[..., 1]) <= box)
    cand = d[keep]
    if len(cand) == 0:
        return 0.0, np.array([np.nan, np.nan]), 0
    near = ((cand[:, None, :] - cand[None, :, :]) ** 2).sum(-1) <= tol ** 2
    k = int(np.argmax(near.sum(1)))
    best = (-1.0, None, 0)
    for s in (cand[k], cand[near[k]].mean(0)):
        e = np.sqrt(((d - s) ** 2).sum(-1)) <= tol
        sym = min(e.any(1).mean(), e.any(0).mean())
        if sym > best[0]:
            best = (float(sym), s, int(e.any(1).sum()))
    return best


def two_halves(a, b, tol=1.0):
    """As sym_two_halves of t0_review.py, also returning the masks."""
    ma = np.zeros(len(a), bool)
    mb = np.zeros(len(b), bool)
    shifts = {}
    for front in (True, False):
        ia = np.flatnonzero((a[:, 1] > 0) == front)
        ib = np.flatnonzero((b[:, 1] > 0) == front)
        if len(ia) == 0 or len(ib) == 0:
            continue
        _, s, _ = sym_match(a[ia], b[ib])
        if np.isnan(s[0]):
            continue
        shifts['front' if front else 'back'] = s
        e = np.sqrt(((a[ia][:, None, :] - b[ib][None, :, :] - s) ** 2)
                    .sum(-1)) <= tol
        ma[ia[e.any(1)]] = True
        mb[ib[e.any(0)]] = True
    return float(min(ma.mean(), mb.mean())), ma, mb, shifts


def tile(img, loc, ok, label):
    im = Image.fromarray((img * 255).astype(np.uint8)).convert('RGB')
    d = ImageDraw.Draw(im)
    cols = np.floor(126.5 - 300 * loc.x.values).astype(int)
    rows = np.floor(182.5 - 300 * loc.y.values).astype(int)
    for c, r, m in zip(cols, rows, ok):
        d.rectangle([c - 2, r - 2, c + 2, r + 2],
                    outline=(0, 200, 0) if m else (255, 0, 0))
    d.text((3, 3), label, fill=(0, 160, 255))
    return np.array(im)


ov = pd.read_csv(f'{OUT}/compare/overlap_screen_t0_old_vs_new.csv')
rigid = ov[(ov.n_new >= 5) & (ov.sym >= 0.30) & (ov.sym - ov.sym2 >= 0.15)]
two = ov[(ov.n_new >= 5) & (ov.sym2h >= 0.40)
         & (ov.sym2h - ov.sym2h_2nd >= 0.15)]
only = two[~two.new.isin(rigid.new)].sort_values('sym2h', ascending=False)
union = set(rigid.new) | set(two.new)
n_union = int(ov[ov.new.isin(union)].n_new.sum())
print(f'rigid rule: {len(rigid)} shoes; two-half rule: {len(two)}; union: '
      f'{len(union)} NEW shoes, {n_union} RACs '
      f'({n_union / ov.n_new.sum():.3f} of all NEW RACs)')
for _, f in only.iterrows():
    sn, so = int(f.new), int(f.old2h)
    a, b = PTS['new'][sn], PTS['old'][so]
    m, ma, mb, sh = two_halves(a, b)
    r2h = float(C_NO[sn - 1, so - 1])
    rank2h = int(np.flatnonzero(np.argsort(-C_NO[sn - 1]) == so - 1)[0]) + 1
    rig = sym_match(a, b)[0]
    t1 = tile(NEW[sn - 1], LOC['new'][LOC['new'].shoe == sn], ma,
              f'NEW {sn} n={len(a)} two-half sym={m:.3f}')
    t2 = tile(OLD[so - 1], LOC['old'][LOC['old'].shoe == so], mb,
              f'OLD {so} n={len(b)} r={r2h:.3f} rank={rank2h}')
    pair = np.hstack([t1, np.full((367, 4, 3), 128, np.uint8), t2])
    path = (f'{OUT}/compare/overlap_pairs/pair2h_{sn}_{so}_old_vs_new.png')
    Image.fromarray(pair).resize((pair.shape[1] * 2, pair.shape[0] * 2),
                                 Image.NEAREST).save(path)
    desc = ', '.join(f'{k} ({v[0]:.2f}, {v[1]:.2f})' for k, v in sh.items())
    other = ''
    if int(f.old) != so:
        other = (f' | rigid partner OLD {int(f.old)}: rigid sym='
                 f'{f.sym:.3f}, image r={f.r:.3f} rank={int(f.img_rank)}')
    print(f'{path} NEW {sn} vs OLD {so}: two-half sym={m:.3f} '
          f'shifts {desc}; rigid sym of this pair={rig:.3f}; image '
          f'r={r2h:.3f} rank={rank2h}{other}')
