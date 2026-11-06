"""Snake metrics of the 386 committed OLD contours (T1 reference for QA).

Reads only committed files; writes docs/qa/sheets_old/snake_metrics_old.csv
(one row per contour record) and prints quantiles. Definitions (all from
data/contour_Active_Contour.txt, data/contacts_data.txt,
data/freq_min_18.png, data/locations_data.csv):
  fill            row-span fill of the contour (each row filled between its
                  leftmost and rightmost contour pixel)
  coverage        share of the cleaned contact pixels (raw AND mask) in fill
  coverage_raw    share of the raw contact pixels in fill
  rac_coverage    share of the shoe's RAC pixels in fill; RAC pixels by the
                  R mapping aspix_x/aspix_y of dataCC_1.Rmd (0-based here);
                  no flip of shoe 9 (the contour is not flipped either, K1)
  contour_px      contour pixels
  outside_mask    share of contour pixels outside the prototype mask
  removed_px      raw contact pixels outside the mask (removed by cleaning)
  touches_border  a contour pixel on the image border
T4 defines the official metrics (plan T4, snake_metrics()); these are a
first reference with the same intent.

Usage (repo root): python -B tests/legacy/old_snake_metrics.py
"""

import csv
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:   # run as a script: make tests.lib importable
    sys.path.insert(0, str(REPO))
from tests.lib.old_records import (  # noqa: E402  (after the path)
    H, W, read_records, shoe_of_record)


def row_span_fill(contour):
    fill = np.zeros_like(contour)
    for r in np.flatnonzero(contour.any(axis=1)):
        cols = np.flatnonzero(contour[r])
        fill[r, cols.min():cols.max() + 1] = True
    return fill


def aspix(x, y):
    """R aspix_x / aspix_y (1-based), returned 0-based (col, row)."""
    delx = (2 * 0.25) / 150
    dely = (2 * 0.5) / 300
    col = W - (math.floor((x + 0.25) / delx) + math.ceil((W - 150) / 2))
    row = H - (math.floor((y + 0.5) / dely) + math.ceil((H - 300) / 2))
    return col - 1, row - 1


def main():
    raw = read_records(REPO / 'data/contacts_data.txt', sep=b'\r\n')
    contour = read_records(REPO / 'data/contour_Active_Contour.txt',
                           sep=b'\r\n')
    mask = np.array(Image.open(REPO / 'data/freq_min_18.png')) > 0
    racs = {}
    with open(REPO / 'data/locations_data.csv', newline='') as f:
        for r in csv.DictReader(f):
            racs.setdefault(int(r['shoe']), []).append(
                aspix(float(r['x']), float(r['y'])))
    rows = []
    for k in range(contour.shape[0]):
        shoe = shoe_of_record(k)
        c, s = contour[k], raw[shoe - 1]
        fill = row_span_fill(c)
        cleaned = s & mask
        pts = racs[shoe]
        inside = sum(bool(fill[rr, cc]) for cc, rr in pts)
        border = bool(c[0].any() or c[-1].any() or c[:, 0].any()
                      or c[:, -1].any())
        rows.append(dict(
            record=k + 1, shoe=shoe,
            coverage=round(float((cleaned & fill).sum() / cleaned.sum()), 4),
            coverage_raw=round(float((s & fill).sum() / s.sum()), 4),
            rac_coverage=round(inside / len(pts), 4), n_rac=len(pts),
            contour_px=int(c.sum()),
            outside_mask=round(float((c & ~mask).sum() / c.sum()), 4),
            removed_px=int((s & ~mask).sum()), touches_border=border))
    out = REPO / 'docs/qa/sheets_old/snake_metrics_old.csv'
    with open(out, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
        w.writeheader()
        w.writerows(rows)
    print(f'wrote {out.relative_to(REPO)} ({len(rows)} records)')
    for key in ('coverage', 'coverage_raw', 'rac_coverage', 'contour_px',
                'outside_mask', 'removed_px'):
        v = np.array([r[key] for r in rows], dtype=float)
        q = np.quantile(v, [0, 0.01, 0.05, 0.5, 0.95, 0.99, 1])
        lo = sorted(rows, key=lambda r: r[key])[:3]
        print(f'{key:13s} min {q[0]:.4g} p1 {q[1]:.4g} p5 {q[2]:.4g} '
              f'median {q[3]:.4g} p95 {q[4]:.4g} p99 {q[5]:.4g} max '
              f'{q[6]:.4g}; lowest: '
              + ', '.join(f"{r['shoe']} ({r[key]})" for r in lo))
    print('touches_border:', sum(r['touches_border'] for r in rows))


if __name__ == '__main__':
    main()
