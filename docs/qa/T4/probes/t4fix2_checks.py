"""Checks of the second T4 review fixes (decisions A-107 to A-109), on the
NEW step-0 run of the work tree (images_new, the contour file).

usage (repo root):
  RAC_DATASET=new python -B docs/qa/T4/probes/t4fix2_checks.py records OTHER
      records (and saved snakes) that differ from the contour file OTHER
      (e.g. the HEAD blob written to a file), with the differing pixels;
      SNAKES=<npz of another run's saved/snake_points> also compares the
      saved ellipses and snakes
  ... parts
      the cleaned print beyond each shoe's initial ellipse and outside its
      fill, split into pieces of printed parts the contour otherwise
      encloses ('sole': the 8-connected component has pixels inside the
      fill, or 50 px or more) and isolated specks or debris ('speck')
  ... toes SHOE [SHOE ...]
      the top printed row, the contour's top row and the fill widths of the
      first rows (the toe peaks of 518, 527 and 9)
  ... outside SHOE
      the cleaned contact pixels outside the shoe's fill (1-based rows and
      columns)
  ... edges SHOE REFERENCE.npy
      per-row shift of the left and right edge of the committed record's
      fill against the fill of REFERENCE.npy (e.g. the record before a
      change), by row band; positive = the committed record lies further
      out (170's own ellipse)
  ... speck328
      328's specks below its contour against the heel outline of the
      same-design 327 (shift 0 rows, 0 and +1 col)
"""
import os
import sys
from pathlib import Path

import numpy as np
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.io_shoes import read_shoes  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

p = load_profile('new')
what = sys.argv[1]
run = q.load_run(p)
rec_of = {s: k for k, s in enumerate(run['shoes'])}


def cleaned(shoe):
    return run['matrices'][shoe - 1] & run['mask']


def fill_of(shoe):
    return q.row_span_fill(run['records'][rec_of[shoe]])


if what == 'records':
    n = len(run['shoes'])
    other = read_shoes(Path(sys.argv[2]), p.W, p.H, n)
    diff = [(int(s), int((other[k] != run['records'][k]).sum()))
            for k, s in enumerate(run['shoes'])
            if not np.array_equal(other[k], run['records'][k])]
    print(f'records that differ (shoe, px): {diff}; the other '
          f'{n - len(diff)} are byte-identical')
    if os.environ.get('SNAKES'):
        pts = np.load(os.environ['SNAKES'])
        for key in ('init', 'first', 'second'):
            d = [i + 1 for i in range(len(pts[key]))
                 if not np.array_equal(pts[key][i], run[key][i])]
            print(f'saved {key} differs for shoes {d}')
elif what == 'parts':
    total = {'sole': 0, 'speck': 0}
    for k, shoe in enumerate(run['shoes']):
        c = cleaned(shoe)
        ell = q.polygon_mask(run['init'][shoe - 1], c.shape)
        fill = fill_of(shoe)
        lost = c & ~ell & ~fill
        if not lost.any():
            continue
        lab, n = ndi.label(c, structure=np.ones((3, 3)))
        sizes = ndi.sum(np.ones_like(c), lab, np.arange(1, n + 1))
        parts = []
        for j in np.unique(lab[lost]):
            m = lost & (lab == j)
            size = int(sizes[j - 1])
            in_fill = int(((lab == j) & fill).sum())
            kind = 'sole' if in_fill > 0 or size >= 50 else 'speck'
            total[kind] += int(m.sum())
            rr, cc = np.nonzero(m)
            parts.append(f'{int(m.sum())} px of a {size}-px piece ({in_fill} '
                         f'in the fill) rows {rr.min() + 1}-{rr.max() + 1} '
                         f'-> {kind}')
        print(shoe, int(lost.sum()), '; '.join(parts))
    print('total:', total)
elif what == 'toes':
    for shoe in (int(s) for s in sys.argv[2:]):
        c = cleaned(shoe)
        rec = run['records'][rec_of[shoe]]
        fill = q.row_span_fill(rec)
        top_print = int(np.flatnonzero(c.any(axis=1))[0])
        top_rec = int(np.flatnonzero(rec.any(axis=1))[0])
        widths = [int(fill[r].sum()) for r in range(top_rec, top_rec + 8)]
        print(f'{shoe}: top printed row {top_print + 1}, contour top row '
              f'{top_rec + 1} (1-based); fill widths from the top {widths}')
elif what == 'outside':
    shoe = int(sys.argv[2])
    out = cleaned(shoe) & ~fill_of(shoe)
    rr, cc = np.nonzero(out)
    print(f'{shoe}: {len(rr)} cleaned px outside the fill at (row, col), '
          '1-based:', sorted(zip((rr + 1).tolist(), (cc + 1).tolist())))
elif what == 'edges':
    shoe = int(sys.argv[2])
    old = q.row_span_fill(np.load(sys.argv[3]))
    new = fill_of(shoe)
    rows = np.flatnonzero(old.any(axis=1) & new.any(axis=1))

    def edge(f, r, side):
        c = np.flatnonzero(f[r])
        return c[0] if side == 'left' else c[-1]
    left = {r: edge(old, r, 'left') - edge(new, r, 'left') for r in rows}
    right = {r: edge(new, r, 'right') - edge(old, r, 'right') for r in rows}
    print(f'{shoe}: fill gained {int((new & ~old).sum())}, lost '
          f'{int((old & ~new).sum())}; rows {rows[0] + 1}-{rows[-1] + 1} '
          '(1-based); outward shift in px:')
    for name, d in (('left', left), ('right', right)):
        for a, b in ((0, 145), (146, 249), (250, 299), (300, p.H)):
            v = np.array([d[r] for r in rows if a <= r <= b])
            if len(v):
                print(f'  {name} edge, 0-based rows {a}-{min(b, p.H - 1)}: '
                      f'median {np.median(v):g}, max {v.max()}, within 1 px '
                      f'on {np.mean(np.abs(v) <= 1):.0%} of {len(v)} rows')
elif what == 'speck328':
    out = cleaned(328) & ~fill_of(328)
    lab, n = ndi.label(out, structure=np.ones((3, 3)))
    dist = ndi.distance_transform_edt(~fill_of(328))
    f327 = fill_of(327)
    for dc in (0, 1):
        print(f'328 on 327, shift 0 rows {dc:+d} col:')
        for j in range(1, n + 1):
            rr, cc = np.nonzero(lab == j)
            inside = int(f327[rr, np.minimum(cc + dc, p.W - 1)].sum())
            print(f'  {len(rr)} px, rows {rr.min() + 1}-{rr.max() + 1}, cols '
                  f'{cc.min() + 1}-{cc.max() + 1} (1-based), '
                  f'{dist[rr, cc].max():.1f} px outside 328: {inside} of '
                  f'{len(rr)} inside 327\'s heel outline')
    for s in (327, 328):
        c, f = cleaned(s), fill_of(s)
        print(f'{s}: printed rows {np.flatnonzero(c.any(1))[[0, -1]] + 1}, '
              f'contour rows {np.flatnonzero(f.any(1))[[0, -1]] + 1} '
              '(1-based)')
else:
    sys.exit(f'unknown check {what!r}')
