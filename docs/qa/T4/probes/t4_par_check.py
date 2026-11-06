"""Serial vs forked snakes on a subset of NEW shoes: identical?"""
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

p = load_profile('new')
tmp = Path(tempfile.mkdtemp(prefix='par_', dir=sys.argv[1]))
(tmp / 'active-contour').mkdir()
(tmp / 'saved').mkdir()
os.symlink(p.images_dir / 'cleaned_shoes', tmp / 'cleaned_shoes')
q = dataclasses.replace(p, images_dir=tmp)
lc = np.load(p.saved_path('list_contour', 'npy'))
idx = list(range(0, 631, 26))[:24]
sub = lc  # get_image reads cleaned PNGs by index
t0 = time.time()
ser = []
for i in idx:
    rec = {}
    arr = acs.active_contour_shoe(q, sub, plot_img=False, save_img_bool=False,
                                  im_num=i, record=rec)
    ser.append((arr, rec))
t1 = time.time()
import multiprocessing  # noqa
acs._JOB.update(profile=q, list_contour=sub, qa=True)
with multiprocessing.get_context('fork').Pool(8) as pool:
    par = pool.map(acs._shoe_job, idx)
acs._JOB.clear()
t2 = time.time()
same = all(np.array_equal(a[0], b[0]) and all(
    np.array_equal(a[1][k], b[1][k]) for k in ('init', 'first', 'second'))
    for a, b in zip(ser, par))
print(f'serial {t1 - t0:.1f} s for {len(idx)} shoes '
      f'({(t1 - t0) / len(idx):.2f} s/shoe); forked x8 {t2 - t1:.1f} s; '
      f'identical: {same}')
