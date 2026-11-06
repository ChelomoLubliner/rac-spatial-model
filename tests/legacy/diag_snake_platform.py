"""Diagnostic (T1): re-run the legacy snake for chosen OLD shoes and compare
with the committed contour records; runs under any Python that has the
thesis packages (the WSL venv or the Windows venv-wind through interop).

Usage: python -B diag_snake_platform.py REPO_ROOT WORK_DIR OUT_NPZ SHOE...
  SHOE = 1-based shoe ids (not 127), or the single word "all" (the 386
  shoes with a contour record). WORK_DIR receives the legacy
  cleaned-shoe PNG and the mask npy; OUT_NPZ the re-run contours, the
  first and second snakes (float coordinates) and the platform string.
Prints, per shoe: differing pixels vs the committed record, and the mean
and max distance (px) from each re-run contour pixel to the nearest
committed contour pixel.
"""

import os
import platform
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE_REPO = Path(__file__).resolve().parents[2]
if str(HERE_REPO) not in sys.path:   # make tests.lib importable
    sys.path.insert(0, str(HERE_REPO))
from tests.lib.old_records import (  # noqa: E402  (after the path)
    N_CONTOUR_RECORDS, read_records, record_of_idx0, shoe_of_record)


def nearest_dist(a, b):
    pa = np.argwhere(a).astype(float)
    pb = np.argwhere(b).astype(float)
    d = np.sqrt(((pa[:, None, :] - pb[None, :, :]) ** 2).sum(-1)).min(1)
    return d.mean(), d.max()


def main(argv):
    repo, work, out_npz = Path(argv[0]), Path(argv[1]), Path(argv[2])
    if argv[3:] == ['all']:
        shoes = [shoe_of_record(k) for k in range(N_CONTOUR_RECORDS)]
    else:
        shoes = [int(s) for s in argv[3:]]
    os.environ.setdefault('MPLBACKEND', 'Agg')
    sys.path.insert(0, str(repo / 'contour_algorithm'))
    import active_contour_snake as acs
    import remove_noise as rn
    import numpy
    import scipy
    import skimage
    folder = str(work) + os.sep
    for sub in ('saved', 'cleaned_shoes'):
        os.makedirs(folder + sub, exist_ok=True)
    acs.FOLDER = folder
    rn.FOLDER = folder
    mask = np.array(Image.open(repo / 'data' / 'freq_min_18.png')) > 0
    np.save(folder + 'saved/freq_min_18.npy', mask)
    raw = read_records(repo / 'data' / 'contacts_data.txt', sep=b'\r\n')
    committed = read_records(repo / 'data' / 'contour_Active_Contour.txt',
                             sep=b'\r\n')
    snakes = []
    real = acs.active_contour

    def recording(image, snake, **kw):
        res = real(image, snake, **kw)
        snakes.append(np.array(res))
        return res
    acs.active_contour = recording
    tag = (f'{platform.system()} {platform.python_version()} numpy '
           f'{numpy.__version__} scipy {scipy.__version__} skimage '
           f'{skimage.__version__}')
    print(tag)
    result = {'platform': np.array(tag)}
    for shoe in shoes:
        idx0 = shoe - 1
        k = record_of_idx0(idx0)
        snakes.clear()
        rn.save_cleaned_shoes(raw, idx0)
        arr = acs.active_contour_shoe(None, plot_img=False,
                                      save_img_bool=False, im_num=idx0)
        diff = int((arr != committed[k]).sum())
        mean_d, max_d = nearest_dist(arr, committed[k]) if diff else (0, 0)
        print(f'shoe {shoe}: differing px {diff}; re-run {int(arr.sum())} '
              f'committed {int(committed[k].sum())} contour px; distance '
              f'to the committed contour mean {mean_d:.3f} max {max_d:.3f}')
        result[f'contour_{shoe}'] = arr
        result[f'first_{shoe}'] = snakes[0]
        result[f'second_{shoe}'] = snakes[1]
    np.savez(out_npz, **result)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
