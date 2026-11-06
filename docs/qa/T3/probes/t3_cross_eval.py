"""T3 post-hoc cross-check of the pixel calibration (decision A-087).

Not pre-registered (A-086 fixed the rule before the run; this probe was
written after the rule's strict-criterion margin failed on both datasets):
each dataset is evaluated at the other dataset's stage-F optimum (relative
to its own legacy centre), with shoe-bootstrap 95% intervals (B = 200,
seed 20261107, as in A-086) of the rate differences. Reads the committed
calibration summaries; writes nothing. Run from the repository root:

    VENV/bin/python -B docs/qa/T3/probes/t3_cross_eval.py \
        > docs/qa/T3/probes/t3_cross_eval.out
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm import calibrate_pixels as cp  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402


def setting(summary, name):
    def get(key):
        return summary[('setting', f'{name}.{key}')]
    return cp.Setting(float(get('sx')), float(get('sy')), float(get('dc')),
                      float(get('dr')), get('mirror_x') == 'True',
                      get('flip_y') == 'True')


def interval(draws):
    lo, hi = np.percentile(draws, [2.5, 97.5])
    return f'[{lo:.6f}, {hi:.6f}]'


def main():
    res = {}
    for ds in ('old', 'new'):
        p = load_profile(ds)
        res[ds] = (p, cp.load_dataset(p),
                   cp.read_summary(p.prep_path('pixel_calibration')))
    for ds, other in (('old', 'new'), ('new', 'old')):
        p, d, s = res[ds]
        centre = cp.legacy_center(p.coords, p.W, p.H)
        lc, lr = cp.legacy_pixel(d['x'], d['y'], p.coords, p.W, p.H)
        for crit, key in (('strict', 'contacts'), ('dilated', 'dilated')):
            sub = {'contacts': d[key], 'shoe': d['shoe']}
            own = setting(s, f'optimum_{crit}')
            oth = setting(res[other][2], f'optimum_{crit}')
            _, h_own, n = cp.per_shoe_hits(sub, *own.pixels(d['x'], d['y'],
                                                            *centre))
            _, h_oth, _ = cp.per_shoe_hits(sub, *oth.pixels(d['x'], d['y'],
                                                            *centre))
            _, h_leg, _ = cp.per_shoe_hits(sub, lc - 1, lr - 1)
            total = n.sum()
            print(f'{ds} {crit}: own optimum {own} rate '
                  f'{h_own.sum() / total:.6f}; at the {other} optimum {oth} '
                  f'rate {h_oth.sum() / total:.6f}; legacy '
                  f'{h_leg.sum() / total:.6f}')
            print(f'   own - other optimum '
                  f'{(h_own.sum() - h_oth.sum()) / total:.6f} 95% '
                  f'{interval(cp.bootstrap_delta(h_own, h_oth, n))}; other '
                  f'optimum - legacy {(h_oth.sum() - h_leg.sum()) / total:.6f}'
                  f' 95% {interval(cp.bootstrap_delta(h_oth, h_leg, n))}')


if __name__ == '__main__':
    main()
