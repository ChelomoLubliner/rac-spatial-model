"""T0 review-fix pass 2 probe: order-free RAC match statistics for every
NEW-OLD, NEW-NEW and OLD-OLD shoe pair, and n-calibrated overlap rules.

Answers the second T0 review: sym_match of t0_review.py depends on the
argument order (Hough-vote ties), and sym = min(share) with a fixed 0.30
threshold is not calibrated by the number of RACs, so heavy reprints (a
shoe printed again after more wear, with 3-4 times the RACs) are missed.

Mode 'compute' (heavy, run in the background) writes a cache of pair
statistics; mode 'analyze' reads it, prints the evidence, writes the CSVs
and the evidence PNGs (a 'compare' folder for images built from both
datasets, 'new' with '_new' names for NEW-only images):

    VENV/bin/python -I -B t0_review2_overlap.py compute <repo> <cache.npz> \
        <workers>
    VENV/bin/python -I -B t0_review2_overlap.py analyze <repo> <out_dir> \
        <cache.npz>

Points are RAC coordinates x 300 (px), as in t0_review.py. Statistics of a
pair (a, b), all with the 1 px tolerance and shifts within +-8 px:
  t0_sym     t0_review.py sym_match in the (a, b) order (reproduction)
  t0_sym2h   t0_review.py sym_two_halves in the (a, b) order
  sym_rev    the T0 algorithm in the (b, a) order
  sym, k     order-free rigid: the T0 shifts of both argument orders (the
             first top-vote displacement of each enumeration order and its
             inlier mean, exactly rounded sums), sym = max over these
             shifts of min(share of a matched, share of b matched), k =
             max over them of min(matched in a, matched in b)
  sym2h, k2h order-free two halves (y > 0 and y <= 0 separately): the same
             shifts per half, every combination of a front and a back
             shift; sym2h and k2h are the maxima over the combinations
Both order-free statistics are exactly symmetric in (a, b).
"""
import math
import sys
from multiprocessing import Pool

import numpy as np
import pandas as pd

BOX, TOL = 8.0, 1.0
FIELDS = ['t0_sym', 'sym_rev', 'sym', 'k', 'ka', 'kb', 't0_sym2h', 'sym2h',
          'k2h', 'ka2h', 'kb2h']
PTS = {}


def load_points(repo):
    old = pd.read_csv(f'{repo}/data/locations_data.csv')
    raw = pd.read_csv(f'{repo}/data/new_shoes/locations_data_new_raw.txt',
                      sep=r'\s+', header=None,
                      names=['shoe', 'rac', 'x', 'y', 'type'])
    new = pd.DataFrame({'shoe': raw.shoe, 'x': raw.x / 2, 'y': raw.y / 2})
    return {ds: {s: np.c_[g.x, g.y].astype(float) * 300
                 for s, g in loc.groupby('shoe')}
            for ds, loc in (('old', old), ('new', new))}


def shifts_of(a, b):
    """Displacements d = a_i - b_j, T0's two shifts and the order-free four.

    T0 takes the first top-vote displacement in the (a, b) enumeration
    (row-major in (i, j)) and its inlier mean. Running T0 in the (b, a)
    order takes the first top-vote displacement in (j, i) order instead;
    its shift, in the (a - b) convention, is that same displacement.
    """
    d = a[:, None, :] - b[None, :, :]
    keep = (np.abs(d[..., 0]) <= BOX) & (np.abs(d[..., 1]) <= BOX)
    ii, jj = np.nonzero(keep)
    if len(ii) == 0:
        return d, [], []
    cand = d[ii, jj]
    near = ((cand[:, None, :] - cand[None, :, :]) ** 2).sum(-1) <= TOL ** 2
    votes = near.sum(1)
    ties = np.flatnonzero(votes == votes.max())
    k_fwd = int(ties[0])
    k_rev = int(ties[np.lexsort((ii[ties], jj[ties]))[0]])

    def exact_mean(k):
        v = cand[near[k]]
        return np.array([math.fsum(v[:, 0]), math.fsum(v[:, 1])]) / len(v)

    t0 = [cand[k_fwd], cand[near[k_fwd]].mean(0)]
    four = [cand[k_fwd], exact_mean(k_fwd), cand[k_rev], exact_mean(k_rev)]
    return d, t0, four


def counts(d, s):
    e = np.sqrt(((d - s) ** 2).sum(-1)) <= TOL
    return int(e.any(1).sum()), int(e.any(0).sum())


def best_t0(d, shifts, na, nb):
    """T0 choice: the first shift with the highest min share."""
    best = (-1.0, (0, 0))
    for s in shifts:
        ka, kb = counts(d, s)
        m = min(ka / na, kb / nb)
        if m > best[0]:
            best = (m, (ka, kb))
    return best


def pair_stats(a, b):
    na, nb = len(a), len(b)
    out = dict.fromkeys(FIELDS, 0.0)
    d, t0, four = shifts_of(a, b)
    if four:
        out['t0_sym'] = best_t0(d, t0, na, nb)[0]
        out['sym_rev'] = best_t0(d, four[2:], na, nb)[0]
        cs = [counts(d, s) for s in four]
        out['sym'] = max(min(ka / na, kb / nb) for ka, kb in cs)
        top = max(cs, key=lambda c: (min(c), sum(c)))
        out['k'], out['ka'], out['kb'] = min(top), top[0], top[1]
    # two halves: T0 version and order-free version
    t0_marks = [0, 0]
    per_half = []
    for front in (True, False):
        ia = (a[:, 1] > 0) == front
        ib = (b[:, 1] > 0) == front
        if not ia.any() or not ib.any():
            per_half.append([(0, 0)])
            continue
        dh, t0h, fourh = shifts_of(a[ia], b[ib])
        if not fourh:
            per_half.append([(0, 0)])
            continue
        _, (ka, kb) = best_t0(dh, t0h, int(ia.sum()), int(ib.sum()))
        t0_marks[0] += ka
        t0_marks[1] += kb
        per_half.append([counts(dh, s) for s in fourh])
    out['t0_sym2h'] = min(t0_marks[0] / na, t0_marks[1] / nb)
    combos = [(f[0] + g[0], f[1] + g[1])
              for f in per_half[0] for g in per_half[1]]
    out['sym2h'] = max(min(ka / na, kb / nb) for ka, kb in combos)
    top = max(combos, key=lambda c: (min(c), sum(c)))
    out['k2h'], out['ka2h'], out['kb2h'] = min(top), top[0], top[1]
    return [out[f] for f in FIELDS]


def task(job):
    kind, sa = job
    if kind == 'new_old':
        a = PTS['new'][sa]
        rows = [pair_stats(a, PTS['old'][sb]) for sb in sorted(PTS['old'])]
    else:
        ds = kind.split('_')[0]
        a = PTS[ds][sa]
        rows = [pair_stats(a, PTS[ds][sb]) for sb in sorted(PTS[ds])
                if sb > sa]
    return kind, sa, np.array(rows, dtype=float).reshape(-1, len(FIELDS))


def compute(repo, cache, workers):
    PTS.update(load_points(repo))
    jobs = ([('new_old', s) for s in sorted(PTS['new'])]
            + [('new_new', s) for s in sorted(PTS['new'])]
            + [('old_old', s) for s in sorted(PTS['old'])])
    res = {'new_old': {}, 'new_new': {}, 'old_old': {}}
    with Pool(workers) as pool:
        for i, (kind, sa, arr) in enumerate(pool.imap(task, jobs, 4)):
            res[kind][sa] = arr
            if (i + 1) % 200 == 0:
                print(f'  ... {i + 1} of {len(jobs)} jobs', flush=True)
    new_ids, old_ids = sorted(PTS['new']), sorted(PTS['old'])
    no = np.stack([res['new_old'][s] for s in new_ids])
    out = {'new_ids': new_ids, 'old_ids': old_ids, 'NO': no,
           'n_new': [len(PTS['new'][s]) for s in new_ids],
           'n_old': [len(PTS['old'][s]) for s in old_ids]}
    for kind, ids in (('new_new', new_ids), ('old_old', old_ids)):
        m = np.zeros((len(ids), len(ids), len(FIELDS)))
        for i, s in enumerate(ids):
            m[i, i + 1:] = res[kind][s]
        # mirror the upper triangle (pairs computed once, in id order, as
        # T0 did for its nulls); the per-side counts swap sides
        low = m.transpose(1, 0, 2).copy()
        for f, g in (('ka', 'kb'), ('ka2h', 'kb2h')):
            fi, gi = FIELDS.index(f), FIELDS.index(g)
            low[..., [fi, gi]] = low[..., [gi, fi]]
        out[kind.upper()] = m + low
    np.savez_compressed(cache, fields=FIELDS, **out)
    print(f'saved {cache}: NEW-OLD {no.shape[0] * no.shape[1]} pairs, '
          f'NEW-NEW {len(new_ids) * (len(new_ids) - 1) // 2}, '
          f'OLD-OLD {len(old_ids) * (len(old_ids) - 1) // 2}')


# ---------------------------------------------------------------- analyze
BINS = [1, 5, 10, 20, 40, 80, 10 ** 6]
STATS = ['sym', 'sym2h', 'k', 'k2h', 'msh']
REVIEWER8 = {240: 320, 239: 321, 604: 134, 84: 26, 192: 105, 57: 177,
             99: 167, 198: 371}


def nbin(n):
    return np.searchsorted(BINS, n, side='right') - 1


def load_contacts(path, w, h, n):
    raw = np.frombuffer(open(path, 'rb').read(), dtype=np.uint8)
    stride = w * h + 2
    recs = np.stack([raw[i * stride:i * stride + w * h] for i in range(n)])
    return (recs.reshape(n, h, w) - 48).astype(bool)


def feats(a):
    """Image features of t0_review.py section R5."""
    from scipy import ndimage
    f = np.stack([ndimage.gaussian_filter(x.astype(np.float32), 2.0)[::2, ::2]
                  for x in a]).reshape(len(a), -1)
    f -= f.mean(1, keepdims=True)
    f /= np.linalg.norm(f, axis=1, keepdims=True)
    return f


def values(M, name, na, nb, f):
    if name == 'msh':       # max share at the shift of k
        return np.maximum(M[..., f['ka']] / na[:, None],
                          M[..., f['kb']] / nb[None, :])
    return M[..., f[name]]


def stratum_max(M, name, n, f):
    """Pair-level maximum of a statistic over the pairs of one dataset,
    per unordered pair of n bins."""
    v = values(M, name, n, n, f)
    iu = np.triu_indices(len(n), 1)
    a, b = nbin(n)[iu[0]], nbin(n)[iu[1]]
    lo, hi = np.minimum(a, b), np.maximum(a, b)
    t = np.full((len(BINS) - 1, len(BINS) - 1), np.inf)
    for x in range(len(BINS) - 1):
        for y in range(x, len(BINS) - 1):
            s = (lo == x) & (hi == y)
            if s.any():
                t[x, y] = t[y, x] = v[iu][s].max()
    return t


def flags(M, name, na, nb, thr, f, kmin=3):
    """Pairs strictly above the stratum maximum, with >= kmin matched."""
    kk = M[..., f['k2h' if name in ('sym2h', 'k2h') else 'k']]
    T = thr[name][nbin(na)[:, None], nbin(nb)[None, :]]
    return ((values(M, name, na, nb, f) > T) & (kk >= kmin)
            & (na[:, None] >= 5))


def match_masks(a, b):
    """Masks of a and b matched at the rigid shift of k (green) and, in
    addition, under the per-half shifts of k2h (orange)."""
    d, _, four = shifts_of(a, b)
    cs = [(counts(d, s), s) for s in four]
    (_, s_rig) = max(cs, key=lambda t: (min(t[0]), sum(t[0])))
    e = np.sqrt(((d - s_rig) ** 2).sum(-1)) <= TOL
    rig_a, rig_b = e.any(1), e.any(0)
    halves = []
    for front in (True, False):
        ia = np.flatnonzero((a[:, 1] > 0) == front)
        ib = np.flatnonzero((b[:, 1] > 0) == front)
        opts = [(np.zeros(len(a), bool), np.zeros(len(b), bool))]
        if len(ia) and len(ib):
            dh, _, fourh = shifts_of(a[ia], b[ib])
            for s in fourh:
                eh = np.sqrt(((dh - s) ** 2).sum(-1)) <= TOL
                ma, mb = np.zeros(len(a), bool), np.zeros(len(b), bool)
                ma[ia[eh.any(1)]] = True
                mb[ib[eh.any(0)]] = True
                opts.append((ma, mb))
        halves.append(opts)
    best2 = max(((fa | ga, fb | gb) for fa, fb in halves[0]
                 for ga, gb in halves[1]),
                key=lambda m: (min(m[0].sum(), m[1].sum()),
                               m[0].sum() + m[1].sum()))
    return rig_a, rig_b, best2[0] & ~rig_a, best2[1] & ~rig_b


def tile(img, pts, green, orange, label):
    from PIL import Image, ImageDraw
    im = Image.fromarray((img * 255).astype(np.uint8)).convert('RGB')
    dr = ImageDraw.Draw(im)
    cols = np.floor(126.5 - pts[:, 0]).astype(int)   # pts = coords x 300
    rows = np.floor(182.5 - pts[:, 1]).astype(int)
    for c, r, g, o in zip(cols, rows, green, orange):
        colour = (0, 200, 0) if g else (255, 150, 0) if o else (255, 0, 0)
        dr.rectangle([c - 2, r - 2, c + 2, r + 2], outline=colour)
    dr.text((3, 3), label, fill=(0, 160, 255))
    return np.array(im)


def save_pair(img_a, img_b, a, b, lab_a, lab_b, path):
    from PIL import Image
    ga, gb, oa, ob = match_masks(a, b)
    both = np.hstack([tile(img_a, a, ga, oa, lab_a),
                      np.full((367, 4, 3), 128, np.uint8),
                      tile(img_b, b, gb, ob, lab_b)])
    Image.fromarray(both).resize((both.shape[1] * 2, both.shape[0] * 2),
                                 Image.NEAREST).save(path)
    return int(ga.sum()), int(gb.sum()), int((ga | oa).sum()), int(
        (gb | ob).sum())


def analyze(repo, out, cache):
    import os
    z = np.load(cache)
    f = {k: i for i, k in enumerate(z['fields'])}
    NO, NN, OO = z['NO'], z['NEW_NEW'], z['OLD_OLD']
    nn, no = np.array(z['n_new']), np.array(z['n_old'])
    new_ids, old_ids = np.array(z['new_ids']), np.array(z['old_ids'])
    pts = load_points(repo)
    old_img = load_contacts(f'{repo}/data/contacts_data.txt', 307, 395,
                            387)[:, 14:381, 26:281]
    new_img = load_contacts(f'{repo}/data/new_shoes/contacts_data_new.txt',
                            255, 367, 631)
    fn, fo = feats(new_img), feats(old_img)
    c_no, c_nn, c_oo = fn @ fo.T, fn @ fn.T, fo @ fo.T  # OLD index = id - 1
    ov = pd.read_csv(f'{out}/compare/overlap_screen_t0_old_vs_new.csv')
    t0_rig = set(ov[(ov.n_new >= 5) & (ov.sym >= 0.30)
                    & (ov.sym - ov.sym2 >= 0.15)].new)
    t0_2h = set(ov[(ov.n_new >= 5) & (ov.sym2h >= 0.40)
                   & (ov.sym2h - ov.sym2h_2nd >= 0.15)].new)
    t0c = t0_rig | t0_2h
    py_round = np.vectorize(lambda x: round(float(x), 3))

    print('\n=== A. reproduction of the T0 screen (t0_review.py R5, R8)')
    srt = np.sort(NO[..., f['t0_sym']], 1)
    srt2 = np.sort(NO[..., f['t0_sym2h']], 1)
    for lab, mine, col in (('best rigid sym', srt[:, -1], ov.sym),
                           ('second-best rigid sym', srt[:, -2], ov.sym2),
                           ('best two-half sym', srt2[:, -1], ov.sym2h),
                           ('second-best two-half', srt2[:, -2],
                            ov.sym2h_2nd)):
        print(f'{lab}: equal to the T0 CSV for all 631 NEW shoes (Python '
              f'round to 3 dp, as T0): '
              f'{np.array_equal(py_round(mine), col.values)}')
    asym = int((NO[..., f['t0_sym']] != NO[..., f['sym_rev']]).sum())
    print(f'NEW-OLD pairs whose T0 value depends on the argument order: '
          f'{asym} of {NO.shape[0] * NO.shape[1]}; order-free sym > T0 sym: '
          f'{int((NO[..., f["sym"]] > NO[..., f["t0_sym"]]).sum())} pairs; '
          f'order-free sym2h > T0 sym2h: '
          f'{int((NO[..., f["sym2h"]] > NO[..., f["t0_sym2h"]]).sum())}')

    def t0_rule(name, thr):
        v = NO[..., f[name]]
        o = np.argsort(-v, 1, kind='stable')
        b1 = np.take_along_axis(v, o[:, :1], 1)[:, 0]
        b2 = np.take_along_axis(v, o[:, 1:2], 1)[:, 0]
        ok = (nn >= 5) & (b1 >= thr) & (b1 - b2 >= 0.15)
        return {int(new_ids[i]): int(old_ids[o[i, 0]])
                for i in np.flatnonzero(ok)}
    for name, t0name, thr in (('sym', 't0_sym', 0.30),
                              ('sym2h', 't0_sym2h', 0.40)):
        a, b = t0_rule(t0name, thr), t0_rule(name, thr)
        print(f'T0 rule on {t0name} vs on the order-free {name} (same '
              f'threshold {thr}, margin 0.15): {len(a)} vs {len(b)} NEW '
              f'shoes; same shoes {set(a) == set(b)}; same partners '
              f'{all(a[k] == b.get(k) for k in a)}')

    print('\n=== B. within-dataset nulls, order-free statistics')
    for ds, M, n in (('NEW-NEW', NN, nn), ('OLD-OLD', OO, no)):
        for name in ('sym', 'sym2h'):
            v = M[..., f[name]].copy()
            np.fill_diagonal(v, -1)
            best = v.max(1)
            row = []
            for b in range(1, len(BINS) - 1):
                s = nbin(n) == b
                row.append(f'[{BINS[b]}, {BINS[b + 1]}): '
                           f'{best[s].max():.3f}' if s.any() else '')
            print(f'{ds} best {name} per shoe, max by n bin: '
                  + '; '.join(row))
    v = NN[..., f['k']].copy()
    np.fill_diagonal(v, -1)
    iu = np.triu_indices(len(nn), 1)
    top = np.argsort(-v[iu])[:5]
    print('NEW-NEW pairs with the most RACs matched (rigid k): '
          + '; '.join(f'{new_ids[iu[0][t]]}-{new_ids[iu[1][t]]} k='
                      f'{int(v[iu][t])} (n {nn[iu[0][t]]}, {nn[iu[1][t]]};'
                      f' image r {c_nn[iu[0][t], iu[1][t]]:.3f})'
                      for t in top))

    print('\n=== C. is the NEW-NEW null representative of NEW-OLD pairs?')
    rng = np.random.default_rng(20261106)
    cno = c_no[:, old_ids - 1]
    for name in ('sym', 'k'):
        for b in range(1, len(BINS) - 1):
            idx = np.flatnonzero(nbin(nn) == b)
            vo, vn = [], []
            for i in idx:
                w = NO[i, :, f[name]].copy()
                w[cno[i] >= 0.80] = -1
                vo.append(w.max())
                pick = rng.choice(np.setdiff1d(np.arange(len(nn)), [i]),
                                  len(old_ids), replace=False)
                w = NN[i, pick, f[name]].copy()
                w[c_nn[i, pick] >= 0.80] = -1
                vn.append(w.max())
            print(f'{name}, NEW n in [{BINS[b]}, {BINS[b + 1]}) '
                  f'({len(idx)} shoes), best partner among pairs with image '
                  f'r < 0.80, 386 partners each: vs OLD p50/p90 '
                  f'{np.median(vo):.3f}/{np.percentile(vo, 90):.3f}; vs NEW '
                  f'p50/p90 {np.median(vn):.3f}/{np.percentile(vn, 90):.3f}')

    print('\n=== D. n-calibrated rules: pair-level NEW-NEW maxima per '
          'stratum of (n bin, n bin), strict >, >= 3 matched')
    thr = {name: stratum_max(NN, name, nn, f) for name in STATS}
    FL = {name: flags(NO, name, nn, no, thr, f) for name in STATS}
    for name in STATS:
        fo_ = flags(OO, name, no, no, thr, f)
        fo_ = np.triu(fo_ | fo_.T, 1)
        pr = [(int(old_ids[i]), int(old_ids[j])) for i, j in
              zip(*np.nonzero(fo_))]
        ids = set(new_ids[np.flatnonzero(FL[name].any(1))].tolist())
        print(f'{name:5s}: NEW shoes flagged {len(ids)} (T0 candidates '
              f'among them {len(ids & t0c)} of {len(t0c)}; reviewer 8: '
              f'{len(ids & set(REVIEWER8))}) | OLD-OLD pairs flagged by '
              f'the same thresholds: {len(pr)} {pr}')
    nstat = sum(FL[name].astype(int) for name in STATS)   # per pair
    best_n = nstat.max(1)
    rows = []
    for i in range(len(nn)):
        sn = int(new_ids[i])
        if best_n[i] == 0 and sn not in t0c and sn not in REVIEWER8:
            continue
        cand = np.flatnonzero(nstat[i] == best_n[i]) if best_n[i] else []
        if sn in REVIEWER8 and best_n[i] == 0:
            cand = [int(np.flatnonzero(old_ids == REVIEWER8[sn])[0])]
        if not len(cand):
            row = ov[ov.new == sn].iloc[0]
            so = int(row.old2h if sn in t0_2h - t0_rig else row.old)
            cand = [int(np.flatnonzero(old_ids == so)[0])]
        j = max(cand, key=lambda jj: (NO[i, jj, f['k']], NO[i, jj, f['sym']]))
        so = int(old_ids[j])
        others = sorted(int(old_ids[jj]) for jj in np.flatnonzero(nstat[i])
                        if jj != j)
        rank = int(np.flatnonzero(np.argsort(-c_no[i]) == so - 1)[0]) + 1
        by = [name for name in STATS if FL[name][i, j]]
        rows.append(dict(
            new=sn, n_new=int(nn[i]), old=so, n_old=int(no[j]),
            n_stats=len(by), stats='+'.join(by),
            other_flagged_old=' '.join(map(str, others)),
            t0_rigid=sn in t0_rig, t0_two_half=sn in t0_2h,
            reviewer8=sn in REVIEWER8,
            sym=round(float(NO[i, j, f['sym']]), 3),
            k=int(NO[i, j, f['k']]),
            sym2h=round(float(NO[i, j, f['sym2h']]), 3),
            k2h=int(NO[i, j, f['k2h']]),
            msh=round(float(values(NO[i:i + 1, j:j + 1], 'msh', nn[i:i + 1],
                                   no[j:j + 1], f)[0, 0]), 3),
            t0_sym=round(float(NO[i, j, f['t0_sym']]), 3),
            t0_sym2h=round(float(NO[i, j, f['t0_sym2h']]), 3),
            r=round(float(c_no[i, so - 1]), 3), img_rank=rank))
    cand = pd.DataFrame(rows)
    vpath = f'{out}/compare/overlap_verdicts_t0_old_vs_new.csv'
    if os.path.exists(vpath):
        ver = pd.read_csv(vpath)
        cand = cand.merge(ver, on=['new', 'old'], how='left')
    cand = cand.sort_values(['n_stats', 'k'], ascending=False)
    cpath = f'{out}/compare/overlap_candidates_t0_old_vs_new.csv'
    cand.to_csv(cpath, index=False)
    tiers = cand.n_stats.value_counts().sort_index(ascending=False)
    print(f'wrote {cpath}: {len(cand)} NEW shoes (any n-calibrated flag, '
          f'the T0 candidates and the reviewer 8); by number of '
          f'statistics flagging the pair: {tiers.to_dict()}')
    new_c = cand[~cand.new.isin(t0c)]
    for lo_, lab in ((4, '4-5'), (2, '2-3'), (1, '1')):
        sel = new_c[(new_c.n_stats >= lo_)
                    & (new_c.n_stats <= {4: 5, 2: 3, 1: 1}[lo_])]
        print(f'  not T0 candidates, flagged by {lab} statistics: '
              f'{len(sel)} shoes, {int(sel.n_new.sum())} NEW RACs; image '
              f'rank <= 3: {int((sel.img_rank <= 3).sum())}')
    t0_miss = sorted(t0c - set(cand[cand.n_stats > 0].new))
    print(f'T0 candidates not flagged by any n-calibrated statistic: '
          f'{t0_miss}')
    pd.set_option('display.width', 250)
    print(cand.drop(columns=['t0_sym', 't0_sym2h', 'reviewed', 'note'],
                    errors='ignore').to_string(index=False))

    print('\n=== E. evidence images (green: matched at the rigid shift of '
          'k; orange: matched in addition with one shift per half, k2h; '
          'red: not matched)')
    os.makedirs(f'{out}/compare/overlap_pairs2', exist_ok=True)
    # not T0 candidates: the reviewer 8, every pair flagged by >= 2
    # statistics, and a spot check of the single-statistic tier (partner
    # among the 3 most similar OLD images)
    draw = cand[(~cand.new.isin(t0c))
                & ((cand.n_stats >= 2) | cand.reviewer8
                   | ((cand.n_stats == 1) & (cand.img_rank <= 3)))]
    for _, row in draw.iterrows():
        sn, so = int(row.new), int(row.old)
        a, b = pts['new'][sn], pts['old'][so]
        path = (f'{out}/compare/overlap_pairs2/pair_{sn}_{so}'
                f'_old_vs_new.png')
        m = save_pair(new_img[sn - 1], old_img[so - 1], a, b,
                      f'NEW {sn} n={len(a)} k={row.k} k2h={row.k2h} '
                      f'stats={row.n_stats}',
                      f'OLD {so} n={len(b)} r={row.r:.3f} '
                      f'rank={row.img_rank}', path)
        print(f'{path}: matched at the rigid shift {m[0]}/{len(a)} NEW, '
              f'{m[1]}/{len(b)} OLD; at the rigid or a per-half shift '
              f'{m[2]}, {m[3]}')
    extra = [('new', 72, 73), ('new', 60, 61), ('old', 38, 299),
             ('old', 103, 315)]
    for ds, sa, sb in extra:
        imgs = new_img if ds == 'new' else old_img
        cmat = c_nn if ds == 'new' else c_oo
        a, b = pts[ds][sa], pts[ds][sb]
        stats_ = pair_stats(a, b)
        st = dict(zip(FIELDS, stats_))
        sfx = '_new' if ds == 'new' else ''
        path = f'{out}/{ds}/pair_{ds}_{sa}_{sb}{sfx}.png'
        m = save_pair(imgs[sa - 1], imgs[sb - 1], a, b,
                      f'{ds.upper()} {sa} n={len(a)} k={int(st["k"])} '
                      f'k2h={int(st["k2h"])}',
                      f'{ds.upper()} {sb} n={len(b)} r='
                      f'{cmat[sa - 1, sb - 1]:.3f}', path)
        print(f'{path}: sym {st["sym"]:.3f} k {int(st["k"])} sym2h '
              f'{st["sym2h"]:.3f} k2h {int(st["k2h"])}; matched at the '
              f'rigid shift {m[0]}, {m[1]}; at the rigid or a per-half '
              f'shift {m[2]}, {m[3]}')


if __name__ == '__main__':
    if sys.argv[1] == 'compute':
        compute(sys.argv[2], sys.argv[3], int(sys.argv[4]))
    elif sys.argv[1] == 'analyze':
        analyze(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        sys.exit(f'unknown mode {sys.argv[1]!r}')
