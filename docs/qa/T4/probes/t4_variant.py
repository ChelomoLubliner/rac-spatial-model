"""Run a NEW snake variant in a scratch folder and score it (T4 scratch).

usage: variant.py NAME 'JSON snake overrides' [JOBS] [DATASET]
Writes <scratch>/t4/variants/NAME/{table.pkl, points.npz, summary.txt}.
The official images_new outputs are read (cleaned shoes, mask, matrices),
never written. Needs OPENBLAS_NUM_THREADS=1 (checked).
"""
import dataclasses
import json
import multiprocessing
import os
import sys
import time
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO))
os.environ.setdefault('MPLBACKEND', 'Agg')
from contour_algorithm import active_contour_snake as acs  # noqa
from contour_algorithm import qa_snake as q  # noqa
from contour_algorithm.profiles import load_profile  # noqa

name, over = sys.argv[1], json.loads(sys.argv[2])
jobs = int(sys.argv[3]) if len(sys.argv) > 3 else 12
dataset = sys.argv[4] if len(sys.argv) > 4 else 'new'
out = Path(os.environ['T4']) / 'variants' / name
out.mkdir(parents=True, exist_ok=True)
if dataset == 'new':
    p = load_profile('new')
else:  # the OLD scratch copy of the OLD --qa run
    root = Path(os.environ['T4']) / 'old_qa' / 'repo'
    p = load_profile('old', root=root, file=root / 'config/datasets.json')
threshold = over.pop('_threshold', None)
over = {k: (tuple(v) if isinstance(v, list) else v) for k, v in over.items()}
qp = dataclasses.replace(p, snake=dataclasses.replace(p.snake, **over))
mask_override = None
if threshold is not None:  # another prototype mask: cleaned shoes in scratch
    from PIL import Image
    from skimage import img_as_ubyte
    mats = np.load(p.saved_path('list_matrices', 'npy'))
    tp = dataclasses.replace(p, superpose_threshold=threshold)
    mask_override = acs.prototype_mask_from(
        tp, img_as_ubyte(mats.sum(axis=0) >= threshold))
    (out / 'cleaned_shoes').mkdir(exist_ok=True)
    qp = dataclasses.replace(qp, images_dir=out, superpose_threshold=threshold)
    for i in range(len(mats)):
        Image.fromarray(mats[i] & mask_override).save(
            qp.image_path('cleaned_shoes', i))
    np.save(out / 'mask.npy', mask_override)
threads = acs.numpy_blas_threads()
assert threads == 1, threads


def job(i):
    rec = {}
    arr = acs.active_contour_shoe(qp, None, plot_img=False,
                                  save_img_bool=False, im_num=i, record=rec)
    return arr, rec


t0 = time.time()
n = p.num_shoe
with multiprocessing.get_context('fork').Pool(jobs) as pool:
    res = pool.map(job, range(n), chunksize=4)
secs = time.time() - t0
run = q.load_run(p)
if mask_override is not None:
    run['mask'] = mask_override
skip = set(p.skip_idx0())
keep = [i for i in range(n) if i not in skip]
run['records'] = np.stack([res[i][0] for i in keep])
for key in ('init', 'first', 'second'):
    run[key] = np.stack([r[1][key] for r in res])
np.savez_compressed(out / 'points.npz', records=run['records'],
                    init=run['init'], first=run['first'],
                    second=run['second'])
tab = q.metrics_table(qp, run, jobs=jobs, log=lambda *a: None)
tab.to_pickle(out / 'table.pkl')
f = tab['qa_flags']
lines = [f'{name} {json.dumps(sys.argv[2])} snakes {secs:.1f} s',
         f'pass {100 * (f == "").mean():.1f}% flagged {(f != "").sum()} '
         f'coverage<0.99 {(tab.coverage < 0.99).sum()} '
         f'tight<0.95 {(tab.tightness < q.TIGHTNESS_TASK_LOW).sum()} '
         f'self-int {(tab.self_intersections > 0).sum()}',
         f'coverage p1 {tab.coverage.quantile(.01):.4f} median '
         f'{tab.coverage.median():.5f} min {tab.coverage.min():.4f}; '
         f'tightness p1 {tab.tightness.quantile(.01):.3f} median '
         f'{tab.tightness.median():.3f} p99 {tab.tightness.quantile(.99):.3f}',
         'flags ' + str(f[f != ''].str.split(';').explode()
                        .value_counts().to_dict()),
         'flagged ' + ' '.join(str(s) for s in tab.shoe[f != ''])]
(out / 'summary.txt').write_text('\n'.join(lines) + '\n')
print('\n'.join(lines))
