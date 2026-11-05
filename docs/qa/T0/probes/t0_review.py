"""T0 review-fix probes (Python): evidence for the T0 review findings.

Independent re-checks of the statistician's and the engineer's findings on
the T0 plan, written from scratch (not the reviewers' scripts). Reads the
committed data only. Writes evidence PNGs and one CSV under <out_dir>
(docs/qa/T0), in a 'new' folder (NEW only) or a 'compare' folder (built
from both datasets):

    VENV/bin/python -I -B t0_review.py <repo_root> <out_dir>

Sections:
  R1 exact R aspix mapping (division form) vs the multiply form
  R2 calibration criterion: flatness in scale, sharper distance criterion
  R3 per-shoe RAC on-contact rates, flip and shift diagnostics
  R4 concentration of RACs in heavy shoes
  R5 overlap screen: RAC match of every NEW shoe with every OLD shoe
  R6 NEW-NEW and OLD-OLD screens (within-dataset duplicates, shoe pairs)
  R7 evidence images
  R8 non-rigid prints: separate shifts for the front and back halves
"""
import os
import sys

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw
from scipy import ndimage

REPO, OUT = sys.argv[1], sys.argv[2]
DIMS = {'old': (307, 395, 387), 'new': (255, 367, 631)}


def section(title):
    print('\n=== ' + title, flush=True)


def load(path, w, h, n):
    """Fixed-stride reader: n records of w*h '0'/'1' chars + CRLF."""
    raw = np.frombuffer(open(path, 'rb').read(), dtype=np.uint8)
    stride = w * h + 2
    recs = np.stack([raw[i * stride:i * stride + w * h] for i in range(n)])
    return (recs.reshape(n, h, w) - 48).astype(bool)


def r_aspix(x, y, w, h):
    """R aspix_x/aspix_y of dataCC_1.Rmd:40-64 (1-based col, row)."""
    delx = (2 * 0.25) / 150
    dely = (2 * 0.5) / 300
    col = w - (np.floor((x + 0.25) / delx) + np.ceil((w - 150) / 2))
    row = h - (np.floor((y + 0.5) / dely) + np.ceil((h - 300) / 2))
    return col.astype(int), row.astype(int)


def mult_aspix(x, y, w, h):
    """The multiply form used by t0_probe.py section D before the fix."""
    col = w - (np.floor((x + 0.25) * 300) + np.ceil((w - 150) / 2))
    row = h - (np.floor((y + 0.5) * 300) + np.ceil((h - 300) / 2))
    return col.astype(int), row.astype(int)


OLD = load(f'{REPO}/data/contacts_data.txt', *DIMS['old'])
NEW = load(f'{REPO}/data/new_shoes/contacts_data_new.txt', *DIMS['new'])
LOC = {'old': pd.read_csv(f'{REPO}/data/locations_data.csv')}
_raw = pd.read_csv(f'{REPO}/data/new_shoes/locations_data_new_raw.txt',
                   sep=r'\s+', header=None,
                   names=['shoe', 'rac', 'x', 'y', 'type'])
LOC['new'] = pd.DataFrame({'shoe': _raw.shoe, 'x': _raw.x / 2,
                           'y': _raw.y / 2})
IMG = {'old': OLD, 'new': NEW}

section('R1. exact R aspix (division form) vs multiply form')
for ds in ('old', 'new'):
    w, h, _ = DIMS[ds]
    loc = LOC[ds]
    c, r = r_aspix(loc.x.values, loc.y.values, w, h)
    cm, rm = mult_aspix(loc.x.values, loc.y.values, w, h)
    diff = np.flatnonzero((c != cm) | (r != rm))
    on = IMG[ds][loc.shoe.values - 1, r - 1, c - 1]
    onm = IMG[ds][loc.shoe.values - 1, rm - 1, cm - 1]
    print(f'{ds}: RACs={len(loc)} on contact: R division form='
          f'{on.mean():.6f} multiply form={onm.mean():.6f}; RACs mapped '
          f'differently: {len(diff)}')
    for k in diff:
        print(f'  shoe {loc.shoe[k]} x={loc.x[k]!r} y={loc.y[k]!r}: '
              f'R (col, row)=({c[k]}, {r[k]}) multiply=({cm[k]}, {rm[k]}) '
              f'on contact R={bool(on[k])} multiply={bool(onm[k])}')
p_miss = np.prod([(13287 - 500 - i) / (13287 - i) for i in range(2)])
print(f'P(a random 500-RAC OLD sample misses both differing RACs) = '
      f'{p_miss:.4f}')

section('R2. calibration criterion vs scale (NEW and OLD)')
CENTER = {'old': (152.5, 196.5), 'new': (126.5, 182.5)}  # 0-based optimum
DIST = {ds: np.stack([ndimage.distance_transform_edt(~im)
                      for im in IMG[ds]]).astype(np.float32)
        for ds in ('old', 'new')}


def criteria(ds, sx, sy, dc, dr):
    """On-contact rate (floor mapping) and mean distance to contact."""
    w, h, _ = DIMS[ds]
    loc = LOC[ds]
    cx, cy = CENTER[ds]
    colf = cx + dc - loc.x.values * sx
    rowf = cy + dr - loc.y.values * sy
    s = loc.shoe.values - 1
    col, row = np.floor(colf).astype(int), np.floor(rowf).astype(int)
    ok = (col >= 0) & (col < w) & (row >= 0) & (row < h)
    rate = np.zeros(len(loc))
    rate[ok] = IMG[ds][s[ok], row[ok], col[ok]]
    # bilinear interpolation of the distance map at the continuous point
    u = np.clip(colf - 0.5, 0, w - 1.001)
    v = np.clip(rowf - 0.5, 0, h - 1.001)
    u0, v0 = np.floor(u).astype(int), np.floor(v).astype(int)
    fu, fv = u - u0, v - v0
    dmap = DIST[ds]
    dist = ((1 - fu) * (1 - fv) * dmap[s, v0, u0]
            + fu * (1 - fv) * dmap[s, v0, u0 + 1]
            + (1 - fu) * fv * dmap[s, v0 + 1, u0]
            + fu * fv * dmap[s, v0 + 1, u0 + 1])
    return rate.mean(), dist.mean()


OFFS = np.arange(-1.5, 1.51, 0.25)
for ds in ('old', 'new'):
    for axis in ('x', 'y'):
        rows = []
        for sc in range(290, 311, 2):
            sx, sy = (sc, 300) if axis == 'x' else (300, sc)
            res = [criteria(ds, sx, sy, a, b) for a in OFFS for b in OFFS]
            rows.append((sc, max(v[0] for v in res), min(v[1] for v in res)))
        top_r = max(r[1] for r in rows)
        top_d = min(r[2] for r in rows)
        print(f'{ds} scale on {axis} (other axis 300; best offset within '
              f'+-1.5 px for each scale):')
        for sc, br, bd in rows:
            print(f'  {axis} scale {sc}: on-contact {br:.4f} '
                  f'(drop {top_r - br:.4f}) | mean distance to contact '
                  f'{bd:.4f} px (rise {bd - top_d:.4f})')

section('R3. per-shoe RAC on-contact rate (R aspix), flip and shift')
PER = {}
for ds in ('old', 'new'):
    w, h, _ = DIMS[ds]
    loc = LOC[ds]
    c, r = r_aspix(loc.x.values, loc.y.values, w, h)
    rows = []
    for s, idx in loc.groupby('shoe').indices.items():
        img = IMG[ds][s - 1]
        rate0 = img[r[idx] - 1, c[idx] - 1].mean()
        best = {}
        for flip in (False, True):
            im = img[:, ::-1] if flip else img
            top = 0.0
            for dc in range(-4, 5):
                for dr in range(-4, 5):
                    cc, rr = c[idx] - 1 + dc, r[idx] - 1 + dr
                    ok = (cc >= 0) & (cc < w) & (rr >= 0) & (rr < h)
                    v = np.zeros(len(idx))
                    v[ok] = im[rr[ok], cc[ok]]
                    top = max(top, v.mean())
            best[flip] = top
        rows.append((s, len(idx), rate0, best[False], best[True]))
    df = pd.DataFrame(rows, columns=['shoe', 'n', 'rate', 'best_shift',
                                     'best_flip_shift'])
    PER[ds] = df
    q = np.percentile(df.rate, [5, 10, 25, 50]).round(3).tolist()
    print(f'{ds}: shoes={len(df)} per-shoe on-contact p5/p10/p25/p50={q}')
    for t in (0.5, 0.6, 0.7):
        sel = df[df.rate < t]
        print(f'  rate < {t}: {len(sel)} shoes, {int(sel.n.sum())} RACs '
              f'({sel.n.sum() / df.n.sum():.3f} of all RACs)')
    g = df[df.n >= 10]
    low = g[(g.best_shift < 0.6) & (g.best_flip_shift < 0.6)]
    print(f'  shoes with >=10 RACs: {len(g)}; below 0.6 under every flip '
          f'and shift (+-4 px): {len(low)} ({int(low.n.sum())} RACs): '
          f'{low.shoe.tolist()}')
    gain = g.best_shift - g.rate
    print(f'  shift gain > 0.2: {int((gain > 0.2).sum())} of {len(g)} '
          f'shoes; > 0.1: {int((gain > 0.1).sum())}; median gain '
          f'{gain.median():.3f}')
    flipw = g[g.best_flip_shift > g.best_shift + 0.15]
    print(f'  flip raises the best rate by > 0.15: {len(flipw)} shoes '
          f'{flipw.shoe.tolist()}')
    if ds == 'new':
        LOW_NEW = low.shoe.tolist()
        GAIN_NEW = int(g.shoe.values[int(np.argmax(gain.values))])
        print(f'  largest shift gain: shoe {GAIN_NEW} '
              f'({float(gain.max()):.3f})')
p5_old = np.percentile(PER['old'].rate, 5)
nn = PER['new']
print(f'OLD per-shoe p5 = {p5_old:.4f}; NEW shoes below it: '
      f'{int((nn.rate < p5_old).sum())} ({int(nn.n[nn.rate < p5_old].sum())}'
      f' RACs)')
print('NEW examples:')
print(nn[nn.shoe.isin([112, 177, 286, 420, 498, 599])].round(3)
      .to_string(index=False))

section('R4. concentration of RACs in heavy shoes')
for ds in ('old', 'new'):
    n = np.sort(LOC[ds].groupby('shoe').size().values)[::-1]
    top = n[:len(n) // 10].sum() / n.sum()
    print(f'{ds}: shoes={len(n)} RACs={n.sum()} share of RACs in the top '
          f'10% of shoes ({len(n) // 10}) = {top:.3f}; max per shoe '
          f'{n[0]}')

section('R5. overlap screen: every NEW shoe against every OLD shoe')
# Image similarity (as in the statistician's screen, so that ranks are
# comparable): Gaussian blur sigma 2 px, subsample 2, centered, unit norm;
# OLD cropped to the NEW frame (OLD pixel (r+14, c+26) == NEW (r, c):
# both use 300 px per unit and are centered on the image center).
OLDC = OLD[:, 14:381, 26:281]


def feats(a):
    f = np.stack([ndimage.gaussian_filter(x.astype(np.float32), 2.0)[::2, ::2]
                  for x in a]).reshape(len(a), -1)
    f -= f.mean(1, keepdims=True)
    f /= np.linalg.norm(f, axis=1, keepdims=True)
    return f


FN, FO = feats(NEW), feats(OLDC)
C_NO = FN @ FO.T
C_NN = FN @ FN.T
np.fill_diagonal(C_NN, -1)
C_OO = FO @ FO.T
np.fill_diagonal(C_OO, -1)
PTS = {ds: {s: np.c_[g.x, g.y].astype(float) * 300
            for s, g in LOC[ds].groupby('shoe')} for ds in ('old', 'new')}


def sym_match(a, b, box=8.0, tol=1.0):
    """Best rigid shift by Hough voting, then the symmetric match.

    Candidate shifts are the displacement vectors a_i - b_j with both
    coordinates within +-box px; each candidate gets one vote per
    displacement within tol of it; the top candidate and its inlier mean
    are tried. sym = min(share of a matched, share of b matched), a point
    being matched when the other set has a point within tol after the
    shift. Returns (sym, shift, number matched in a).
    """
    d = a[:, None, :] - b[None, :, :]
    keep = (np.abs(d[..., 0]) <= box) & (np.abs(d[..., 1]) <= box)
    cand = d[keep]
    if len(cand) == 0:
        return 0.0, (np.nan, np.nan), 0
    near = ((cand[:, None, :] - cand[None, :, :]) ** 2).sum(-1) <= tol ** 2
    k = int(np.argmax(near.sum(1)))
    best = (-1.0, None, 0)
    for s in (cand[k], cand[near[k]].mean(0)):
        e = np.sqrt(((d - s) ** 2).sum(-1)) <= tol
        sym = min(e.any(1).mean(), e.any(0).mean())
        if sym > best[0]:
            best = (float(sym), s, int(e.any(1).sum()))
    return best


old_ids = sorted(PTS['old'])
rows = []
for i in range(631):
    sn = i + 1
    a = PTS['new'][sn]
    res = [(sym_match(a, PTS['old'][so]), so) for so in old_ids]
    syms = np.array([m[0] for m, _ in res])
    order = np.argsort(-syms)
    (m1, sh1, k1), so1 = res[order[0]]
    img_rank = np.argsort(-C_NO[i])
    rank_of = int(np.flatnonzero(img_rank == so1 - 1)[0]) + 1
    ib = int(img_rank[0]) + 1
    sym_imgbest = np.nan
    if ib in PTS['old']:
        sym_imgbest = sym_match(a, PTS['old'][ib])[0]
    null10 = [sym_match(a, PTS['old'][o + 1])[0] for o in img_rank[1:11]
              if o + 1 in PTS['old']]
    rows.append(dict(new=sn, n_new=len(a), old=so1,
                     n_old=len(PTS['old'][so1]), sym=round(m1, 3),
                     matched=k1, dx=round(float(sh1[0]), 2),
                     dy=round(float(sh1[1]), 2),
                     sym2=round(float(syms[order[1]]), 3),
                     sym_med=round(float(np.median(syms)), 3),
                     r=round(float(C_NO[i, so1 - 1]), 3), img_rank=rank_of,
                     img_best=ib, sym_img_best=round(float(sym_imgbest), 3),
                     null10_max=round(float(max(null10)), 3)))
    if sn % 100 == 0:
        print(f'  ... {sn} NEW shoes screened', flush=True)
OV = pd.DataFrame(rows)
os.makedirs(f'{OUT}/compare', exist_ok=True)
OV.to_csv(f'{OUT}/compare/overlap_screen_t0_old_vs_new.csv', index=False)
print(f'wrote {OUT}/compare/overlap_screen_t0_old_vs_new.csv '
      f'({len(OV)} rows)')
print('best sym over all OLD shoes, quantiles p50/p90/p95/p99/max:',
      OV.sym.quantile([.5, .9, .95, .99, 1]).round(3).tolist())
print('second-best sym, quantiles p50/p90/p99/max:',
      OV.sym2.quantile([.5, .9, .99, 1]).round(3).tolist())
FLAG = OV[(OV.n_new >= 5) & (OV.sym >= 0.30) & (OV.sym - OV.sym2 >= 0.15)]
print(f'flagged (n_new >= 5, sym >= 0.30, sym - second best >= 0.15): '
      f'{len(FLAG)} NEW shoes, {int(FLAG.n_new.sum())} NEW RACs; image '
      f'rank of the matched OLD shoe: {sorted(FLAG.img_rank.tolist())}')
print(FLAG.sort_values('sym', ascending=False).to_string(index=False))
rev = OV[(OV.n_new >= 5) & (OV.sym_img_best >= 0.30)
         & (OV.sym_img_best > OV.null10_max + 0.15)]
print(f"statistician's rule with this code (image-best OLD shoe, sym >= "
      f"0.30 and > max over the next 10 image-similar + 0.15): {len(rev)} "
      f"shoes: {sorted(rev.new.tolist())}")
dup = FLAG.old.value_counts()
print('OLD shoes matched by more than one flagged NEW shoe:',
      dup[dup > 1].to_dict())

section('R6. within-dataset screens (NEW-NEW, OLD-OLD)')
for ds, cmat in (('new', C_NN), ('old', C_OO)):
    ids = sorted(PTS[ds])
    best = {}
    for ai, sa in enumerate(ids):
        for sb in ids[ai + 1:]:
            m = sym_match(PTS[ds][sa], PTS[ds][sb])[0]
            for p, q in ((sa, sb), (sb, sa)):
                if m > best.get(p, (-1, 0))[0]:
                    best[p] = (m, q)
    v = np.array([best[s][0] for s in ids if len(PTS[ds][s]) >= 5])
    print(f'{ds}-{ds}: best sym per shoe (>= 5 RACs) quantiles '
          f'p50/p90/p99/max: '
          f'{np.round(np.percentile(v, [50, 90, 99, 100]), 3).tolist()}')
    top = sorted(((best[s][0], s, best[s][1]) for s in ids
                  if len(PTS[ds][s]) >= 5), reverse=True)[:6]
    print('  top (sym, shoe, partner):',
          [(round(t[0], 3), t[1], t[2]) for t in top])
    if ds == 'new':
        part = cmat.argmax(1)
        hi = [i for i in range(631) if cmat[i, part[i]] >= 0.95]
        consec = [i for i in hi if abs(part[i] - i) == 1]
        syms = [sym_match(PTS[ds][i + 1], PTS[ds][part[i] + 1])[0]
                for i in hi]
        print(f'  NEW shoes with an image partner at r >= 0.95: {len(hi)}; '
              f'partner has a consecutive id: {len(consec)}; RAC sym with '
              f'the partner max={max(syms):.3f}')
        print('  pairs (shoe, partner, r, sym):',
              [(i + 1, int(part[i]) + 1, round(float(cmat[i, part[i]]), 3),
                round(s, 3)) for i, s in zip(hi, syms)])

section('R7. evidence images')


def tile(ds, shoe, pts_match, label):
    """Contact image (NEW frame; OLD cropped) with RACs drawn."""
    img = NEW[shoe - 1] if ds == 'new' else OLDC[shoe - 1]
    im = Image.fromarray((img * 255).astype(np.uint8)).convert('RGB')
    d = ImageDraw.Draw(im)
    loc = LOC[ds][LOC[ds].shoe == shoe]
    cols = np.floor(126.5 - 300 * loc.x.values).astype(int)
    rows_ = np.floor(182.5 - 300 * loc.y.values).astype(int)
    for c, r, ok in zip(cols, rows_, pts_match):
        d.rectangle([c - 2, r - 2, c + 2, r + 2],
                    outline=(0, 200, 0) if ok else (255, 0, 0))
    d.text((3, 3), label, fill=(0, 160, 255))
    return np.array(im)


def save_pair(sn, so, path):
    a, b = PTS['new'][sn], PTS['old'][so]
    m, s, _ = sym_match(a, b)
    e = np.sqrt(((a[:, None, :] - b[None, :, :] - s) ** 2).sum(-1)) <= 1.0
    t1 = tile('new', sn, e.any(1), f'NEW {sn} n={len(a)} sym={m:.3f}')
    t2 = tile('old', so, e.any(0),
              f'OLD {so} n={len(b)} r={C_NO[sn - 1, so - 1]:.3f}')
    both = np.hstack([t1, np.full((367, 4, 3), 128, np.uint8), t2])
    Image.fromarray(both).resize((both.shape[1] * 2, both.shape[0] * 2),
                                 Image.NEAREST).save(path)
    print(f'{path} NEW {sn} vs OLD {so}: sym={m:.3f} shift=({s[0]:.2f}, '
          f'{s[1]:.2f}) px')


os.makedirs(f'{OUT}/compare/overlap_pairs', exist_ok=True)
for _, f in FLAG.sort_values('sym', ascending=False).iterrows():
    save_pair(int(f.new), int(f.old), f'{OUT}/compare/overlap_pairs/pair_'
              f'{int(f.new)}_{int(f.old)}_old_vs_new.png')
# controls: the two NEW shoes with the highest image correlation to an OLD
# shoe whose RAC match is low (same design, different shoe)
ctrl = OV[(OV.n_new >= 20)].copy()
ctrl['rbest'] = C_NO.max(1)[ctrl.new.values - 1]
ctrl = ctrl[ctrl.sym_img_best < 0.1].sort_values('rbest', ascending=False)
for _, f in ctrl.head(2).iterrows():
    save_pair(int(f.new), int(f.img_best), f'{OUT}/compare/overlap_pairs/'
              f'control_{int(f.new)}_{int(f.img_best)}_old_vs_new.png')
os.makedirs(f'{OUT}/new', exist_ok=True)
show = (LOW_NEW + [GAIN_NEW])[:6]
for s_ in nn[nn.n >= 10].sort_values('rate').shoe:
    if len(show) >= 6:
        break
    if s_ not in show:
        show.append(int(s_))
tiles = []
for s in show:
    loc = LOC['new'][LOC['new'].shoe == s]
    w, h, _ = DIMS['new']
    c, r = r_aspix(loc.x.values, loc.y.values, w, h)
    on = NEW[s - 1, r - 1, c - 1]
    row = nn[nn.shoe == s].iloc[0]
    tiles.append(tile('new', s, on, f'NEW {s} n={len(loc)} on={row.rate:.2f}'
                      f' best={row.best_shift:.2f}'))
sep = np.full((367, 4, 3), 128, np.uint8)
grid = np.vstack([np.hstack([tiles[0], sep, tiles[1], sep, tiles[2]]),
                  np.full((4, 255 * 3 + 8, 3), 128, np.uint8),
                  np.hstack([tiles[3], sep, tiles[4], sep, tiles[5]])])
path = f'{OUT}/new/low_contact_shoes_new.png'
Image.fromarray(grid).resize((grid.shape[1] * 2, grid.shape[0] * 2),
                             Image.NEAREST).save(path)
print(f'{path} shoes {show} (green = RAC on contact under the R mapping, '
      f'red = off contact)')

section('R8. non-rigid prints: separate shifts for the front and back halves')


def sym_two_halves(a, b, tol=1.0):
    """Symmetric match with one best shift for y > 0 and one for y <= 0."""
    ma = np.zeros(len(a), bool)
    mb = np.zeros(len(b), bool)
    for front in (True, False):
        ia = np.flatnonzero((a[:, 1] > 0) == front)
        ib = np.flatnonzero((b[:, 1] > 0) == front)
        if len(ia) == 0 or len(ib) == 0:
            continue
        _, s, _ = sym_match(a[ia], b[ib])
        if np.isnan(s[0]):
            continue
        e = np.sqrt(((a[ia][:, None, :] - b[ib][None, :, :] - s) ** 2)
                    .sum(-1)) <= tol
        ma[ia[e.any(1)]] = True
        mb[ib[e.any(0)]] = True
    return float(min(ma.mean(), mb.mean()))


null2h = []
ids_new = sorted(PTS['new'])
best2h = {}
for ai, sa in enumerate(ids_new):
    for sb in ids_new[ai + 1:]:
        m = sym_two_halves(PTS['new'][sa], PTS['new'][sb])
        for p, q in ((sa, sb), (sb, sa)):
            if m > best2h.get(p, (-1, 0))[0]:
                best2h[p] = (m, q)
v2h = np.array([best2h[s][0] for s in ids_new if len(PTS['new'][s]) >= 5])
print(f'NEW-NEW null, two-half sym, best per shoe (>= 5 RACs) quantiles '
      f'p50/p90/p99/max: '
      f'{np.round(np.percentile(v2h, [50, 90, 99, 100]), 3).tolist()}')
rows2 = []
for i in range(631):
    sn = i + 1
    a = PTS['new'][sn]
    syms = np.array([sym_two_halves(a, PTS['old'][so]) for so in old_ids])
    order = np.argsort(-syms)
    rows2.append(dict(new=sn, n_new=len(a), old2h=old_ids[order[0]],
                      sym2h=round(float(syms[order[0]]), 3),
                      sym2h_2nd=round(float(syms[order[1]]), 3)))
    if sn % 100 == 0:
        print(f'  ... {sn} NEW shoes screened', flush=True)
OV2 = OV.merge(pd.DataFrame(rows2), on=['new', 'n_new'])
OV2.to_csv(f'{OUT}/compare/overlap_screen_t0_old_vs_new.csv', index=False)
print(f'rewrote {OUT}/compare/overlap_screen_t0_old_vs_new.csv with the '
      f'two-half columns')
thr = max(0.30, float(v2h.max()))
F2 = OV2[(OV2.n_new >= 5) & (OV2.sym2h >= thr)
         & (OV2.sym2h - OV2.sym2h_2nd >= 0.15)]
print(f'two-half rule (n_new >= 5, sym2h >= max(0.30, NEW-NEW null max) = '
      f'{thr:.3f}, margin >= 0.15): {len(F2)} NEW shoes, '
      f'{int(F2.n_new.sum())} NEW RACs')
both = set(F2.new) & set(FLAG.new)
print(f'  also flagged by the rigid rule: {len(both)}; two-half only: '
      f'{sorted(set(F2.new) - set(FLAG.new))}; rigid only: '
      f'{sorted(set(FLAG.new) - set(F2.new))}')
same = F2[F2.new.isin(list(both))]
print(f'  same OLD partner under both rules: '
      f'{int((same.old == same.old2h).sum())} of {len(same)}')
print(F2.sort_values('sym2h', ascending=False)[
    ['new', 'n_new', 'old', 'old2h', 'sym', 'sym2h', 'sym2h_2nd', 'r',
     'img_rank']].to_string(index=False))
os.makedirs(f'{OUT}/old', exist_ok=True)
for sa, sb in ((236, 277), (237, 278)):
    a, b = PTS['old'][sa], PTS['old'][sb]
    m, s, _ = sym_match(a, b)
    e = np.sqrt(((a[:, None, :] - b[None, :, :] - s) ** 2).sum(-1)) <= 1.0
    t1 = tile('old', sa, e.any(1), f'OLD {sa} n={len(a)} sym={m:.3f}')
    t2 = tile('old', sb, e.any(0),
              f'OLD {sb} n={len(b)} r={C_OO[sa - 1, sb - 1]:.3f}')
    pair = np.hstack([t1, np.full((367, 4, 3), 128, np.uint8), t2])
    path = f'{OUT}/old/pair_old_{sa}_{sb}.png'
    Image.fromarray(pair).resize((pair.shape[1] * 2, pair.shape[0] * 2),
                                 Image.NEAREST).save(path)
    print(f'{path} OLD {sa} vs OLD {sb}: sym={m:.3f} two-half '
          f'{sym_two_halves(a, b):.3f}')
