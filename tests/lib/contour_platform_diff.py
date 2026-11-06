"""Record how a rerun's contour file differs from the committed one (T1).

Usage (thesis venv python, repo root):
  python -B tests/lib/contour_platform_diff.py RUN_CONTOUR OUT_PREFIX

RUN_CONTOUR = a contour txt written by the legacy code (LF or CRLF).
Writes OUT_PREFIX.npz with
  records  0-based indices of the records that differ from the committed
           data/contour_Active_Contour.txt,
  shoes    their 1-based shoe ids (record k -> shoe k + 1, k + 2 after 126),
  packed   np.packbits of those records of RUN_CONTOUR (shape n x 15159),
  sha_crlf sha256 of RUN_CONTOUR with LF -> CRLF,
and OUT_PREFIX.csv (record, shoe, differing_px, run_px, committed_px,
mean_dist_px, max_dist_px: distance from each rerun contour pixel to the
nearest committed contour pixel).
`apply_records(committed_bytes, npz)` rebuilds the rerun file (CRLF) from
the committed bytes and the npz, so a test can check both against the
recorded sha256.
"""

import csv
import hashlib
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:   # run as a script: make tests.lib importable
    sys.path.insert(0, str(REPO))
from tests.lib.old_records import (  # noqa: E402  (after the path)
    H, W, parse_records, shoe_of_record)

SIZE = W * H


def read_records(data):
    """Records of a contour file's bytes, flattened: bool (n, W * H)."""
    return parse_records(data)[0].reshape(-1, SIZE)


def apply_records(committed_bytes, npz):
    """Committed CRLF bytes with the npz records replaced (CRLF bytes)."""
    rec = np.frombuffer(committed_bytes, dtype=np.uint8).reshape(-1, SIZE + 2)
    rec = rec.copy()
    bits = np.unpackbits(npz['packed'], axis=1, count=SIZE).astype(bool)
    for row, k in zip(bits, npz['records']):
        rec[k, :SIZE] = np.where(row, 49, 48)
    return rec.tobytes()


def nearest(a, b):
    pa = np.argwhere(a).astype(float)
    pb = np.argwhere(b).astype(float)
    d = np.sqrt(((pa[:, None, :] - pb[None, :, :]) ** 2).sum(-1)).min(1)
    return float(d.mean()), float(d.max())


def main(argv):
    run_bytes = Path(argv[0]).read_bytes()
    prefix = Path(argv[1])
    committed = (REPO / 'data/contour_Active_Contour.txt').read_bytes()
    a, b = read_records(committed), read_records(run_bytes)
    assert a.shape == b.shape, (a.shape, b.shape)
    diff = (a != b).sum(axis=1)
    ks = np.flatnonzero(diff)
    lf = run_bytes.replace(b'\r\n', b'\n')
    sha_crlf = hashlib.sha256(lf.replace(b'\n', b'\r\n')).hexdigest()
    np.savez_compressed(prefix.with_suffix('.npz'), records=ks,
                        shoes=np.array([shoe_of_record(k) for k in ks]),
                        packed=np.packbits(b[ks], axis=1),
                        sha_crlf=np.array(sha_crlf))
    with open(prefix.with_suffix('.csv'), 'w', newline='') as f:
        w = csv.writer(f, lineterminator='\n')
        w.writerow(['record', 'shoe', 'differing_px', 'run_px',
                    'committed_px', 'mean_dist_px', 'max_dist_px'])
        for k in ks:
            m, x = nearest(b[k].reshape(H, W), a[k].reshape(H, W))
            w.writerow([k + 1, shoe_of_record(k), int(diff[k]),
                        int(b[k].sum()), int(a[k].sum()), f'{m:.3f}',
                        f'{x:.3f}'])
    rebuilt = apply_records(committed, np.load(prefix.with_suffix('.npz')))
    ok = hashlib.sha256(rebuilt).hexdigest() == sha_crlf
    print(f'records differing: {ks.size} of {a.shape[0]}; differing px '
          f'total {int(diff.sum())}; rebuilt-from-npz sha matches: {ok}')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
