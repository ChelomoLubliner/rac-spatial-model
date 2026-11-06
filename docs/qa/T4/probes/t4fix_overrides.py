"""Write data/new_shoes/snake_overrides_new.csv from the reviewed fallback
decisions, with each shoe's QA numbers for the profile radius and its
override radius recomputed on the current step-0 images (T4 review fixes;
decisions A-097, A-102). Needs one OpenBLAS thread.

usage (repo root):
  python -B docs/qa/T4/probes/t4fix_overrides.py \\
      OUT.csv
"""
import csv
import dataclasses
import multiprocessing
import os
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
os.environ.setdefault('MPLBACKEND', 'Agg')
from contour_algorithm import active_contour_snake as acs  # noqa: E402
from contour_algorithm import qa_snake as q  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

assert acs.numpy_blas_threads() == 1
p = load_profile('new')
old = {}
with open(p.snake_overrides, newline='') as f:
    for row in csv.DictReader(f):
        old[int(row['shoe'])] = row['reason'].split(
            ' QA radius 10:')[0].rstrip('.')
# 185: its profile contour passes every band on the current images (the
# corrected erase list moved the mask, A-100), so by the A-097 rule it
# needs no fallback any more; looked at: radius 10 and 24 enclose the same
# heel and every RAC
old.pop(185, None)
WHY = {
    12: ('lower-left heel rim printed only as fragments: radius 24 encloses '
         'them with a rounded heel bottom; radius 10 cuts diagonally above '
         'them'),
    46: ('a lug ring at the right forefoot edge: radius 24 encloses it; '
         'radius 10 cuts through it'),
    69: ('toe top-left not printed: radius 24 gives a rounded toe that '
         'encloses the faint toe marks; radius 10 runs a straight diagonal '
         'under them (lopsided toe)'),
    120: ('lower-right heel pad not printed: radius 24 rounds the heel corner '
          'and encloses its RAC, which radius 10 leaves outside with a '
          'diagonal cut; an isolated 7-px stroke 27 px from the print stays '
          'outside'),
    140: ('lower-right heel pad barely printed: radius 24 encloses its rim '
          'and two of its three RACs; radius 10 cuts diagonally with a hook; '
          'one RAC 2 px outside remains'),
    165: ('faint print with specks around the pointed toe: radius 16 encloses '
          'them; radius 24 breaks the turning band with a jag at the top left '
          'of the toe (A-102)'),
    173: ('toe top-left not printed: radius 24 widens the toe top to the '
          'faint marks there; radius 10 runs a diagonal with a peak at the '
          'top right'),
    222: ('lower-right heel partly printed: radius 24 encloses the heel '
          'corner and its RAC'),
    235: ('right forefoot edge: radius 24 gives a convex edge that encloses '
          'the faint edge lugs; radius 10 dips into the sparse edge and '
          'bulges around one lug'),
    267: ('heel lower-right not printed: radius 24 gives a rounded heel '
          'bottom; radius 10 draws a V point down to the heel-tip blob'),
    286: ('very faint toe: radius 24 raises the toe top to the faint toe '
          'marks and encloses the RAC above the flat radius-10 top'),
    456: ('toe top-left faint: radius 24 encloses the faint toe marks next to '
          'the print; radius 10 cuts in under them'),
    506: ('toe top-right not printed: radius 24 gives a rounded toe top that '
          'encloses the marks there; two RACs above the toe, off the print, '
          'stay outside with both radii'),
    427: ('top right of the toe not printed: radius 10 leaves the isolated '
          'mark above the toe outside with a notch; the same-design 426 and '
          '431 (aligned) have their toe tips at that mark, so it is the '
          'printed toe tip; radius 24 rounds the toe over it'),
    376: ('faint toe: radius 10 draws a narrow finger up to the topmost toe '
          'speck; radius 24 rounds the toe over it; no QA band is broken by '
          'either, the override follows the visual review (the T4 review '
          'named the finger)'),
}
RADIUS = {s: 24 for s in list(old) + list(WHY)}
RADIUS[165] = 16
run = q.load_run(p)


def job(args):
    shoe, radius = args
    sp = dataclasses.replace(p.snake, first_closing_radius=radius)
    qp = dataclasses.replace(p, snake=sp, snake_overrides=None)
    rec = {}
    arr = acs.active_contour_shoe(qp, None, False, False, shoe - 1,
                                  record=rec)
    return shoe, radius, arr, rec['second']


shoes = sorted(RADIUS)
tasks = [(s, r) for s in shoes
         for r in sorted({p.snake.first_closing_radius, RADIUS[s]})]
with multiprocessing.get_context('fork').Pool(14) as pool:
    res = {(s, r): (a, sec) for s, r, a, sec in pool.map(job, tasks)}


def qa(shoe, radius):
    arr, second = res[(shoe, radius)]
    i = shoe - 1
    cleaned = run['matrices'][i] & run['mask']
    rac = run['racs'].get(shoe, np.zeros((0, 2), int))
    m = q.snake_metrics(cleaned, arr, run['mask'], second, rac)
    flags = q.flag_shoe(m)
    return (f'coverage {m["coverage"]:.4f}, tightness {m["tightness"]:.3f}, '
            f'RAC coverage {m["rac_coverage"]:.3f}, RAC out '
            f'{m["rac_out_max_px"]:.1f} px, contact out '
            f'{m["contact_out_max_px"]:.1f} px, flags '
            f'{flags or "none"}'), flags


rows = []
for shoe in shoes:
    r0 = p.snake.first_closing_radius
    before, fb = qa(shoe, r0)
    after, fa = qa(shoe, RADIUS[shoe])
    why = WHY.get(shoe, old.get(shoe))
    tag = 'A-097' if shoe in old else 'T4 review, A-102'
    rows.append((shoe, RADIUS[shoe], f'{why}. QA radius {r0}: {before}; '
                 f'radius {RADIUS[shoe]}: {after} ({tag})'))
    print(shoe, RADIUS[shoe], '| r10:', fb or '-', '| override:', fa or '-')
with open(sys.argv[1], 'w', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(acs.OVERRIDE_COLUMNS)
    for shoe, radius, reason in rows:
        w.writerow([shoe, radius, '', '', '', '', reason])
print('wrote', sys.argv[1], len(rows), 'overrides')
