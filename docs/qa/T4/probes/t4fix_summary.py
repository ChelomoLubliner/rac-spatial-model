"""Summary of the committed NEW QA table (T4 review fixes probe): pass
rates (every band; with the task's literal tightness 0.95; the T4 bands
without the A-099 triggers), flag counts, resolutions and review classes,
the metric distribution, the erase list and the overrides; and the T4
contour (commit 1a69e26) under the new bands, from the trigger table of
t4fix_triggers.py.

usage (repo root):
  python -B docs/qa/T4/probes/t4fix_summary.py [TRIGGERS_T4.csv]
"""
import io
import subprocess
import sys
from collections import Counter
from pathlib import Path

import pandas as pd

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO))
from contour_algorithm import qa_snake as q  # noqa: E402

t = pd.read_csv(REPO / 'docs/qa/T4/new/snake_metrics_new.csv',
                keep_default_na=False)
n = len(t)
f = t.qa_flags != ''
print(f'final: {n} shoes, flagged {int(f.sum())}, pass {n - int(f.sum())} '
      f'({100 * (n - int(f.sum())) / n:.2f}%)')
lit = (~f) & (t.tightness >= q.TIGHTNESS_TASK_LOW)
print(f'literal tightness 0.95 band too: pass {int(lit.sum())} '
      f'({100 * lit.mean():.2f}%)')
t4b = [b for b in q.BANDS if b[0] not in ('rac_out_max_px',
                                          'contact_out_max_px')]
ob = t.apply(lambda r: q.flag_shoe(r, t4b), axis=1)
print(f'T4 bands only (no A-099 triggers): pass {int((ob == "").sum())} '
      f'({100 * (ob == "").mean():.2f}%)')
print('flags:', dict(Counter(x for s in t.qa_flags[f]
                             for x in s.split(';'))))
print('resolution:', dict(Counter(t.resolution[f])),
      '; classes (all listed):',
      dict(Counter(t.review_class[t.review_class != ''])))
print('coverage<0.99:', list(t.shoe[t.coverage < 0.99]),
      '| tightness<0.95:', int((t.tightness < 0.95).sum()),
      '| <0.9047:', list(t.shoe[t.tightness < 0.9047]))
for c in ('coverage', 'coverage_fill', 'coverage_r', 'rac_coverage',
          'tightness', 'turning', 'max_turn_deg', 'n_contour_px',
          'outside_mask_frac', 'self_intersections', 'touches_border',
          'rac_out_max_px', 'contact_out_max_px'):
    v = t[c].astype(float)
    print(f'{c:19s} min {v.min():.4f} p1 {v.quantile(.01):.4f} p5 '
          f'{v.quantile(.05):.4f} median {v.median():.4f} p95 '
          f'{v.quantile(.95):.4f} p99 {v.quantile(.99):.4f} max '
          f'{v.max():.4f}')
s = pd.read_csv(REPO / 'docs/qa/T4/new/sticker_erased_new.csv')
print('erase list:', len(s), 'rectangles on', s.shoe.nunique(), 'shoes;',
      int(s.erased_px.sum()), 'px erased,', int(s.erased_in_mask_px.sum()),
      'inside the mask')
o = pd.read_csv(REPO / 'data/new_shoes/snake_overrides_new.csv')
print('overrides:', len(o), dict(Counter(o.first_closing_radius)))
if len(sys.argv) > 1:
    trig = pd.read_csv(sys.argv[1])
    old = subprocess.run(['git', '-C', str(REPO), 'show',
                          '1a69e26:docs/qa/T4/new/snake_metrics_new.csv'],
                         capture_output=True, text=True, check=True).stdout
    t4 = pd.read_csv(io.StringIO(old), keep_default_na=False)
    m = t4.merge(trig[['shoe', 'rac_out_max_px', 'contact_out_max_px']],
                 on='shoe')
    fl = m.apply(lambda r: q.flag_shoe(r), axis=1)
    print(f'T4 commit contour under the new bands: flagged '
          f'{int((fl != "").sum())}, pass {int((fl == "").sum())} '
          f'({100 * (fl == "").mean():.2f}%)')
