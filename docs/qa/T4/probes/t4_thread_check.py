"""Snakes of 24 NEW shoes saved to an npz (to compare BLAS thread counts)."""
import dataclasses
import os
import sys
import tempfile
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
os.environ['MPLBACKEND'] = 'Agg'
from contour_algorithm import active_contour_snake as acs  # noqa
from contour_algorithm.profiles import load_profile  # noqa

p = load_profile(sys.argv[3] if len(sys.argv) > 3 else 'new')
tmp = Path(tempfile.mkdtemp(prefix='thr_', dir=sys.argv[1]))
(tmp / 'saved').mkdir()
os.symlink(p.images_dir / 'cleaned_shoes', tmp / 'cleaned_shoes')
q = dataclasses.replace(p, images_dir=tmp)
n = 631 if p.dataset == 'new' else 387
idx = list(range(0, n, 26))[:24]
t0 = time.time()
out = {}
for i in idx:
    rec = {}
    arr = acs.active_contour_shoe(q, None, plot_img=False, save_img_bool=False,
                                  im_num=i, record=rec)
    out[f'c{i}'] = arr
    out[f'f{i}'] = rec['first']
    out[f's{i}'] = rec['second']
np.savez(sys.argv[2], **out)
print(f'{len(idx)} shoes {time.time() - t0:.1f} s, '
      f'OPENBLAS_NUM_THREADS={os.environ.get("OPENBLAS_NUM_THREADS")}')
