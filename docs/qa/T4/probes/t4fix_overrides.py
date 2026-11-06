"""Write data/new_shoes/snake_overrides_new.csv from the reviewed fallback
decisions, with each shoe's QA numbers for the profile snake and for its
override recomputed on the current step-0 images (T4 review fixes and
second T4 review fixes; decisions A-097, A-102, A-107). Needs one OpenBLAS
thread and the NEW step-0 images of the current erase list.

Self-contained (second T4 review): every shoe's override, reason and
decision tag is listed below, so a rerun writes the same file whatever
override file is in place (the earlier version took the reasons and the
tag from the file it read, so a rerun on its own output changed the tags).
Tags: A-097 for the shoes of the first fallback (T4), A-102 for those of
the T4 review fixes, A-107 for 170's own ellipse (second T4 review fixes).

usage (repo root):
  OPENBLAS_NUM_THREADS=1 RAC_DATASET=new python -B \\
      docs/qa/T4/probes/t4fix_overrides.py OUT.csv
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

A097, A102, A107 = 'A-097', 'T4 review, A-102', 'second T4 review, A-107'
R24 = {'first_closing_radius': 24}
# shoe: (override fields, decision tag, reason)
OVERRIDES = {
    8: (R24, A097,
        'very faint partial print (2016 px): radius 10 notches the left '
        'side; radius 24 gives a sole-shaped outline (still below the '
        'coverage band: isolated specks; one RAC below the heel off the '
        'print)'),
    12: (R24, A102,
         'lower-left heel rim printed only as fragments: radius 24 encloses '
         'them with a rounded heel bottom; radius 10 cuts diagonally above '
         'them'),
    46: (R24, A102,
         'a lug ring at the right forefoot edge: radius 24 encloses it; '
         'radius 10 cuts through it'),
    63: (R24, A097,
         'radius 24 also encloses the heel bottom and the RAC 1 px from '
         'contact below it'),
    69: (R24, A102,
         'toe top-left not printed: radius 24 gives a rounded toe that '
         'encloses the faint toe marks; radius 10 runs a straight diagonal '
         'under them (lopsided toe)'),
    109: (R24, A097,
          'toe printed only on its left: radius 24 also encloses the mark '
          'and the RAC at the unprinted right toe'),
    112: (R24, A097,
          'heel almost unprinted (T0, T3): radius 24 encloses the heel '
          'fragments that carry RACs; radius 10 cuts diagonally across '
          'them'),
    113: (R24, A097,
          'heel partly printed: radius 24 encloses the lower heel fragments '
          'that carry RACs'),
    120: (R24, A102,
          'lower-right heel pad not printed: radius 24 rounds the heel '
          'corner and encloses its RAC, which radius 10 leaves outside with '
          'a diagonal cut; an isolated 7-px stroke 27 px from the print '
          'stays outside'),
    140: (R24, A102,
          'lower-right heel pad barely printed: radius 24 encloses its rim '
          'and two of its three RACs; radius 10 cuts diagonally with a '
          'hook; one RAC 2 px outside remains'),
    163: (R24, A097,
          'very faint partial print (1376 px): radius 10 cuts diagonally '
          'and leaves the heel fragments outside; radius 24 encloses them'),
    165: ({'first_closing_radius': 16}, A102,
          'faint print with specks around the pointed toe: radius 16 '
          'encloses them; radius 24 breaks the turning band with a jag at '
          'the top left of the toe'),
    170: ({'center_rc': (187.0, 127.0), 'radii_rc': (167.0, 98.0)}, A107,
          'the rim of the lower-left heel pad lies beyond the profile '
          'ellipse (35 px of print outside it, 32 of them outside the '
          'contour, up to 3 px deep): the snakes start inside the rim and '
          'no closing radius recovers it (radius 16 and 24 recover 1 px and '
          'keep the coverage flag); this ellipse (2 px lower, 1 px left, '
          'radii +5 and +3) encloses the rim; elsewhere every part of the '
          'outline moves by at most 1 px at the median and at most 3 px '
          '(the left side of the arch), the right edge within 1 px on 91% '
          'of the rows; the enlarged ellipse (185, 128) / (167, 98) also '
          'encloses the rim but bulges 3-4 px into the empty space below '
          'the pad'),
    173: (R24, A102,
          'toe top-left not printed: radius 24 widens the toe top to the '
          'faint marks there; radius 10 runs a diagonal with a peak at the '
          'top right'),
    175: (R24, A097,
          'faint edges: radius 24 encloses the outer edge pixels that radius '
          '10 cuts'),
    222: (R24, A102,
          'lower-right heel partly printed: radius 24 encloses the heel '
          'corner and its RAC'),
    235: (R24, A102,
          'right forefoot edge: radius 24 gives a convex edge that encloses '
          'the faint edge lugs; radius 10 dips into the sparse edge and '
          'bulges around one lug'),
    267: (R24, A102,
          'heel lower-right not printed: radius 24 gives a rounded heel '
          'bottom; radius 10 draws a V point down to the heel-tip blob'),
    286: (R24, A102,
          'very faint toe: radius 24 raises the toe top to the faint toe '
          'marks and encloses the RAC above the flat radius-10 top'),
    376: (R24, A102,
          'faint toe: radius 10 draws a narrow finger up to the topmost toe '
          'speck; radius 24 rounds the toe over it; no QA band is broken by '
          'either, the override follows the visual review (the T4 review '
          'named the finger)'),
    427: (R24, A102,
          'top right of the toe not printed: radius 10 leaves the isolated '
          'mark above the toe outside with a notch; the same-design 426 and '
          '431 (aligned) have their toe tips at that mark, so it is the '
          'printed toe tip; radius 24 rounds the toe over it'),
    456: (R24, A102,
          'toe top-left faint: radius 24 encloses the faint toe marks next '
          'to the print; radius 10 cuts in under them'),
    506: (R24, A102,
          'toe top-right not printed: radius 24 gives a rounded toe top that '
          'encloses the marks there; two RACs above the toe, off the print, '
          'stay outside with both radii'),
    557: (R24, A097,
          'faint toe tip above the forefoot blocks (with a RAC): radius 24 '
          'encloses it; radius 10 stops at the blocks'),
}
# 185 (A-097) was dropped in the T4 review fixes: its profile contour
# passes every band on the corrected images (A-102)

p = load_profile('new')
acs.check_blas_threads(p)
assert p.blas_threads == 1
run = q.load_run(p)


def describe(fields):
    """How a set of snake parameters differs from the profile's, in words:
    the closing radius, and the ellipse when it is not the profile's."""
    sp = dataclasses.replace(p.snake, **fields)
    text = f'radius {sp.first_closing_radius}'
    if (sp.center_rc, sp.radii_rc) != (p.snake.center_rc, p.snake.radii_rc):
        (cr, cc), (rr, rc) = sp.center_rc, sp.radii_rc
        text += f', ellipse ({cr:g}, {cc:g}) / ({rr:g}, {rc:g})'
    return text


def job(args):
    shoe, which = args
    fields = OVERRIDES[shoe][0] if which == 'override' else {}
    qp = dataclasses.replace(p, snake=dataclasses.replace(p.snake, **fields),
                             snake_overrides=None)
    rec = {}
    arr = acs.active_contour_shoe(qp, None, False, False, shoe - 1,
                                  record=rec)
    return shoe, which, arr, rec['second']


shoes = sorted(OVERRIDES)
tasks = [(s, w) for s in shoes for w in ('profile', 'override')]
with multiprocessing.get_context('fork').Pool(14) as pool:
    res = {(s, w): (a, sec) for s, w, a, sec in pool.map(job, tasks)}


def qa(shoe, which):
    arr, second = res[(shoe, which)]
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
    fields, tag, why = OVERRIDES[shoe]
    before, fb = qa(shoe, 'profile')
    after, fa = qa(shoe, 'override')
    radius = fields.get('first_closing_radius', '')
    ellipse = ['', '', '', '']
    if 'center_rc' in fields:
        ellipse = [f'{v:g}' for v in fields['center_rc'] + fields['radii_rc']]
    rows.append([shoe, radius, *ellipse,
                 f'{why}. QA {describe({})}: {before}; {describe(fields)}: '
                 f'{after} ({tag})'])
    print(shoe, describe(fields), '| profile:', fb or '-', '| override:',
          fa or '-')
with open(sys.argv[1], 'w', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(acs.OVERRIDE_COLUMNS)
    w.writerows(rows)
print('wrote', sys.argv[1], len(rows), 'overrides')
