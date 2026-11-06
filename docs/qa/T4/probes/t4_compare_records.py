"""Compare two sets of contour records (scratch): per record, differing
pixels and the symmetric mean / max distance between the contour pixel
sets (pixels). usage: compare_records.py A.npz|txt B.npz|txt W H [N]"""
import sys
from pathlib import Path

import numpy as np
from scipy.ndimage import distance_transform_edt

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm.io_shoes import read_shoes  # noqa


def load(path, W, H, n):
    if path.endswith('.npz'):
        return np.load(path)['records']
    return read_shoes(path, W, H, n)


a_path, b_path, W, H = sys.argv[1], sys.argv[2], int(sys.argv[3]), \
    int(sys.argv[4])
n = int(sys.argv[5]) if len(sys.argv) > 5 else None
a = load(a_path, W, H, n)
b = load(b_path, W, H, n if n else len(a))
assert a.shape == b.shape, (a.shape, b.shape)
rows = []
for k in range(len(a)):
    if np.array_equal(a[k], b[k]):
        rows.append((k + 1, 0, 0.0, 0.0))
        continue
    da = distance_transform_edt(~b[k])[a[k]]
    db = distance_transform_edt(~a[k])[b[k]]
    d = np.concatenate([da, db])
    rows.append((k + 1, int((a[k] != b[k]).sum()), float(d.mean()),
                 float(d.max())))
r = np.array(rows)
diff = r[r[:, 1] > 0]
print(f'records {len(a)}, identical {int((r[:, 1] == 0).sum())}, differing '
      f'{len(diff)}')
if len(diff):
    print(f'differing: mean distance median {np.median(diff[:, 2]):.2f} px, '
          f'p90 {np.quantile(diff[:, 2], .9):.2f}, max {diff[:, 2].max():.2f};'
          f' max distance median {np.median(diff[:, 3]):.1f}, max '
          f'{diff[:, 3].max():.1f}')
    top = diff[np.argsort(-diff[:, 2])][:10]
    print('largest mean distance (record, px, mean, max):',
          [(int(t[0]), int(t[1]), round(t[2], 2), round(t[3], 1))
           for t in top])
