"""Span of the first and last rows of each cleaned NEW print (scratch)."""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm.profiles import load_profile  # noqa

p = load_profile('new')
mat = np.load(p.saved_path('list_matrices', 'npy'))
mask = np.load(sys.argv[2]) if len(sys.argv) > 2 else np.load(
    p.saved_path(p.stem('prototype_mask'), 'npy'))
out = []
for i in range(len(mat)):
    c = mat[i] & mask
    rr = np.flatnonzero(c.any(1))

    def span(r):
        cols = np.flatnonzero(c[r])
        return int(cols[-1] - cols[0] + 1) if len(cols) else 0
    top = max(span(r) for r in rr[:3])
    bot = max(span(r) for r in rr[-3:])
    # gap: empty rows within the first / last 8 rows of the print
    first = c[rr[0]:rr[0] + 8].any(1)
    last = c[rr[-1] - 7:rr[-1] + 1].any(1)
    out.append((i + 1, int(rr[0]), int(rr[-1]), top, bot,
                int((~first).sum()), int((~last).sum())))
t = pd.DataFrame(out, columns=['shoe', 'r0', 'r1', 'top_span', 'bot_span',
                               'top_gap', 'bot_gap'])
t.to_csv(sys.argv[1], index=False)
print(t[['top_span', 'bot_span']].describe(percentiles=[.5, .9, .95, .99]))
print('top:', t.sort_values('top_span', ascending=False).head(25)[
    ['shoe', 'top_span', 'top_gap', 'r0']].to_string(index=False))
print('bottom:', t.sort_values('bot_span', ascending=False).head(25)[
    ['shoe', 'bot_span', 'bot_gap', 'r1']].to_string(index=False))
print('gaps:', t[(t.top_gap > 0) | (t.bot_gap > 0)].to_string(index=False))
