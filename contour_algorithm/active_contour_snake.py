"""Step 0c: the two-pass snake of every shoe and of the prototype.

Ported from the thesis code (109f30a) with every dataset value from the
profile: the initial ellipse (`python.snake.center_rc`, `radii_rc`,
`n_points`), the snake parameters, the frame (W, H) and every path. The
contour file is written by `io_shoes.write_shoes` (binary CRLF) without
the shoes that have no contour record (computed from the locations,
`locations.record_skip_idx0`), never at a fixed path.
"""

import ctypes
import dataclasses
import functools
import glob
import io
import multiprocessing
import os

import cv2
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image
from skimage import img_as_ubyte
from skimage.filters import gaussian
from skimage.segmentation import active_contour
from tqdm import tqdm

from .extreme_values_x_y import dict_points, get_contour
from .io_shoes import write_shoes
from .locations import record_skip_idx0

WHITE = 255  # rac: literal-ok (an 8-bit grey level, not the NEW width)


def get_image(profile, entire_shoe, im_num, list_contour):
    img = np.nan
    if entire_shoe:
        img = img_as_ubyte(
            Image.open(profile.image_path('cleaned_shoes', im_num)))
    else:
        img = img_as_ubyte(Image.fromarray(list_contour[im_num]))
    return img


def plot_active_contour(img, init, snake):
    """Interactive view (plot_img=True only; never in batch runs): the
    initial ellipse red dashed, the snake blue, shown with Image.show()."""
    fig, ax = plt.subplots(figsize=(7, 7))
    ax.imshow(img, cmap=plt.cm.gray)
    ax.plot(init[:, 1], init[:, 0], '--r', lw=3)
    ax.plot(snake[:, 1], snake[:, 0], '-b', lw=3)
    ax.set_xticks([]), ax.set_yticks([])
    ax.axis([0, img.shape[1], img.shape[0], 0])
    buf = io.BytesIO()
    fig.savefig(buf, format='png')
    buf.seek(0)
    plt.close('all')
    img = Image.open(buf)
    img.show()


def save_img(profile, img, snake, im_num):
    """The second snake (blue) over the cleaned shoe: active-contour/im_<i>.
    """
    fig, ax = plt.subplots(figsize=(7, 7))
    ax.imshow(img, cmap=plt.cm.gray)
    ax.plot(snake[:, 1], snake[:, 0], '-b', lw=3)
    ax.set_xticks([]), ax.set_yticks([])
    ax.axis([0, img.shape[1], img.shape[0], 0])
    buf = io.BytesIO()
    fig.savefig(buf, format='png')
    buf.seek(0)
    plt.close('all')
    img = Image.open(buf)
    img.save(profile.image_path('active-contour', im_num))


OVERRIDE_COLUMNS = ('shoe', 'first_closing_radius', 'center_r', 'center_c',
                    'radius_r', 'radius_c', 'reason')


@functools.lru_cache(maxsize=4)
def _read_overrides(path, mtime_ns):
    """{shoe: {field: value}} of a snake override file (cached per file
    version; mtime_ns is part of the key)."""
    import pandas as pd
    table = pd.read_csv(path, dtype={'reason': str}, keep_default_na=False,
                        na_values={c: [''] for c in OVERRIDE_COLUMNS[1:-1]})
    if tuple(table.columns) != OVERRIDE_COLUMNS:
        raise ValueError(f'{path}: columns must be '
                         f'{",".join(OVERRIDE_COLUMNS)}')
    out = {}
    for row in table.to_dict('records'):
        shoe = int(row['shoe'])
        if shoe in out or not str(row['reason']).strip():
            raise ValueError(f'{path}: shoe {shoe} repeated or without a '
                             'reason')
        fields = {}
        r = row['first_closing_radius']
        if not pd.isna(r):
            if float(r) != int(r) or int(r) < 0:
                raise ValueError(f'{path}: shoe {shoe}: first_closing_radius '
                                 'must be an integer >= 0')
            fields['first_closing_radius'] = int(r)
        ellipse = [row[c] for c in ('center_r', 'center_c', 'radius_r',
                                    'radius_c')]
        given = [not pd.isna(v) for v in ellipse]
        if any(given) and not all(given):
            raise ValueError(f'{path}: shoe {shoe}: give all four ellipse '
                             'values or none')
        if all(given):
            if min(ellipse[2:]) <= 0:
                raise ValueError(f'{path}: shoe {shoe}: radii must be > 0')
            fields['center_rc'] = (float(ellipse[0]), float(ellipse[1]))
            fields['radii_rc'] = (float(ellipse[2]), float(ellipse[3]))
        if not fields:
            raise ValueError(f'{path}: shoe {shoe} overrides nothing')
        out[shoe] = fields
    return out


def snake_overrides(profile):
    """{1-based shoe: {SnakeParams field: value}} of the profile's per-shoe
    snake fallbacks (inputs.snake_overrides; NEW only, A-097; OLD: {})."""
    path = profile.snake_overrides
    if path is None:
        return {}
    table = _read_overrides(str(path), os.stat(path).st_mtime_ns)
    bad = [s for s in table if not 1 <= s <= profile.num_shoe]
    if bad:
        raise ValueError(f'{path}: shoe ids outside 1..{profile.num_shoe}: '
                         f'{bad}')
    return table


def snake_params(profile, shoe=None):
    """The snake parameters of a shoe: the profile's, with the shoe's
    overrides applied (shoe None: the prototype, never overridden)."""
    sp = profile.snake
    if shoe is None:
        return sp
    fields = snake_overrides(profile).get(shoe)
    return sp if not fields else dataclasses.replace(sp, **fields)


def init_snake(profile, shoe=None):
    """The initial ellipse, (n_points, 2) as (row, col).

    shoe: the 1-based shoe id the snake is for (None: the prototype); a
    shoe starts from the profile's ellipse unless the profile's snake
    overrides give it its own (A-097)."""
    sp = snake_params(profile, shoe)
    (center_r, center_c), (radius_r, radius_c) = sp.center_rc, sp.radii_rc
    s = np.linspace(0, 2 * np.pi, sp.n_points)
    y = center_r + radius_r * np.sin(s)
    x = center_c + radius_c * np.cos(s)
    init = np.array([y, x]).T
    return init


def extreme_values(profile, im_arr):
    all_points = np.argwhere(im_arr)
    points_dict = dict_points(all_points, x_true=True)
    new_points_x = []
    for x_i in points_dict.keys():
        for new_y_i in range(min(points_dict[x_i]),
                             max(points_dict[x_i]) + 1):
            new_points_x.append((x_i, new_y_i))
    new_arr = np.zeros((profile.H, profile.W), dtype=bool)
    new_arr[tuple(zip(*new_points_x))] = True
    new_image = Image.fromarray(new_arr)

    return new_image.point(lambda x: WHITE if x == 0 else 0)


def get_snake_image(profile, snake):
    """The snake drawn as an open polyline of thickness 3, as a bool (H, W)
    image.

    The drawing is done on a (W, H) array with cv2's (x, y) = (row, col)
    of the snake and transposed back, a double swap that is correct for
    any W and H (plan F15; locked by tests/python/test_snake_geometry.py).
    """
    # create a blank image of the same size as the input image
    output = np.zeros((profile.W, profile.H))
    # draw the snake on the output image
    cv2.polylines(output, [np.int32(snake)], False, (WHITE, 0, 0),
                  thickness=3)

    # convert the output image to PNG format
    png_bytes = cv2.imencode('.png', output)[1].tobytes()
    img = cv2.imdecode(np.frombuffer(png_bytes, np.uint8),
                       cv2.IMREAD_UNCHANGED)
    img = cv2.transpose(img)
    return Image.fromarray(img.astype(bool))


def combined_snake_arr(profile, snake, original_img):
    snake_img = get_snake_image(profile, snake)
    snake_arr = np.array(snake_img, dtype=bool)
    first_snake_contour_arr = extreme_values(profile, snake_arr)
    snake_arr = np.array(snake_img, dtype=bool)
    # Get the part of the shoe that is out of the first_snake
    out_first_snake_arr = np.bitwise_and(first_snake_contour_arr,
                                         np.array(original_img, dtype=bool))
    # Combine out_first_snake_arr and first_snake_arr to calculate extreme
    # values
    new_first_comb_arr = np.add(out_first_snake_arr, snake_arr)
    comb_coordinates = get_contour(new_first_comb_arr)
    comb_arr = np.zeros((profile.H, profile.W), dtype=bool)
    comb_arr[tuple(zip(*comb_coordinates))] = True
    comb_extremes_img = Image.fromarray(comb_arr)
    return comb_extremes_img


def first_snake_image(sp, original_img):
    """The image the first snake of a shoe runs on (before its blur): the
    cleaned shoe itself (legacy), or, with snake.first_closing_radius r >
    0, its morphological closing with a disk of radius r, so that separate
    sole elements (heel pads, lugs) form one silhouette (NEW, A-094)."""
    if not sp.first_closing_radius:
        return original_img
    from skimage.morphology import binary_closing, disk
    r = sp.first_closing_radius
    # padded with background, so that the closing is the same near the
    # image border (skimage's erosion counts pixels outside as foreground)
    padded = np.pad(np.asarray(original_img) > 0, r)
    closed = binary_closing(padded, disk(r))[r:-r, r:-r]
    return img_as_ubyte(closed)


def first_sigma(sp):
    """The blur of the first snake: snake.first_gaussian_sigma, else the
    legacy snake.gaussian_sigma."""
    if sp.first_gaussian_sigma is None:
        return sp.gaussian_sigma
    return sp.first_gaussian_sigma


def active_contour_shoe(profile, list_contour, plot_img, save_img_bool,
                        im_num, record=None):
    """The contour (bool (H, W)) of shoe image im_num: a first snake on the
    blurred cleaned shoe, a second one on the first snake combined with
    the parts of the shoe outside it.

    record: None, or a dict that receives the initial ellipse ('init') and
    the two snakes ('first', 'second'), (n_points, 2) float arrays (row,
    col), for the QA figures and metrics (T4, `--qa`); it changes nothing
    in the computation."""
    sp = snake_params(profile, im_num + 1)
    original_img = get_image(profile, True, im_num, list_contour)
    # First active-contour: beta = beta_first
    init = init_snake(profile, shoe=im_num + 1)
    first_snake = active_contour(
        gaussian(first_snake_image(sp, original_img), first_sigma(sp),
                 preserve_range=False),
        init,
        alpha=sp.alpha,
        beta=sp.beta_first,
        gamma=sp.gamma,
    )
    if plot_img:
        plot_active_contour(original_img, init, first_snake)
    # Combine first snake with original to capture missing regions
    comb_extremes_img = combined_snake_arr(profile, first_snake, original_img)
    # Second snake on combined extremes image
    second_snake = active_contour(
        gaussian(img_as_ubyte(comb_extremes_img), sp.gaussian_sigma,
                 preserve_range=False),
        init,
        alpha=sp.alpha,
        beta=sp.beta_second,
        gamma=sp.gamma,
    )

    if save_img_bool:
        save_img(profile, original_img, second_snake, im_num)
    if plot_img:
        plot_active_contour(img_as_ubyte(comb_extremes_img), init,
                            second_snake)
        plot_active_contour(original_img, init, second_snake)
    snake_img = get_snake_image(profile, second_snake)
    snake_arr = np.array(snake_img, dtype=bool)
    comb_coordinates = get_contour(snake_arr)
    comb_arr = np.zeros((profile.H, profile.W), dtype=bool)
    comb_arr[tuple(zip(*comb_coordinates))] = True
    if record is not None:
        record.update(init=init, first=first_snake, second=second_snake)
    return comb_arr


def active_contour_on_prototype(profile, record=None):
    """The prototype cleaning mask: the two-pass snake on the superposition
    (>= python.superpose_threshold shoes), filled; saved to the profile's
    prototype-mask files (png, npy) and returned."""
    original_img = img_as_ubyte(Image.open(
        profile.saved_path(profile.stem('superposed'), 'png')))
    final_arr = prototype_mask_from(profile, original_img, record=record)
    final_img = Image.fromarray(final_arr)
    stem = profile.stem('prototype_mask')
    final_img.save(profile.saved_path(stem, 'png'))
    np.save(profile.saved_path(stem, 'npy'), final_arr)
    return final_arr


def prototype_mask_from(profile, original_img, record=None):
    """The filled two-pass snake of a superposition image (uint8 0/255,
    (H, W)), as a bool (H, W) array; writes nothing (the T4 threshold
    comparison calls it for several thresholds). record: as in
    active_contour_shoe."""
    sp = profile.snake
    init = init_snake(profile)
    first_snake = active_contour(gaussian(original_img, sp.gaussian_sigma,
                                          preserve_range=False),
                                 init, alpha=sp.alpha, beta=sp.beta_first,
                                 gamma=sp.gamma)
    comb_extremes_img = combined_snake_arr(profile, first_snake, original_img)
    # Do second snake on comb_extremes_img
    second_snake = active_contour(
        gaussian(img_as_ubyte(comb_extremes_img), sp.gaussian_sigma,
                 preserve_range=False),
        init,
        alpha=sp.alpha,
        beta=sp.beta_second,
        gamma=sp.gamma,
    )
    snake_img = get_snake_image(profile, second_snake)
    snake_arr = np.array(snake_img, dtype=bool)
    final_arr = ~np.array(extreme_values(profile, snake_arr), dtype=bool)
    if record is not None:
        record.update(init=init, first=first_snake, second=second_snake)
    return final_arr


def numpy_blas_threads():
    """The thread count of numpy's bundled OpenBLAS, read through its own
    getter; None when the library or the getter is not found."""
    libs = os.path.dirname(np.__file__) + '.libs'
    for lib in sorted(glob.glob(os.path.join(libs, '*openblas*'))):
        try:
            dll = ctypes.CDLL(lib)
        except OSError:
            continue
        for name in ('scipy_openblas_get_num_threads64_',
                     'openblas_get_num_threads64_',
                     'openblas_get_num_threads'):
            getter = getattr(dll, name, None)
            if getter is not None:
                getter.restype = ctypes.c_int
                return int(getter())
    return None


def check_blas_threads(profile):
    """The OpenBLAS thread count of this process; raises RuntimeError when
    the profile fixes one (python.blas_threads) and the process runs
    another: the snakes depend on it (decision A-092)."""
    threads = numpy_blas_threads()
    want = profile.blas_threads
    if want is not None and threads != want:
        raise RuntimeError(
            f'numpy OpenBLAS runs {threads} threads, the {profile.dataset} '
            f'profile needs {want}: set OPENBLAS_NUM_THREADS={want} before '
            'numpy is imported (python -m contour_algorithm.main does)')
    return threads


# State shared with the forked snake workers of run_snakes(): set before
# the pool starts, so nothing is pickled on the way in (the profile holds
# mapping proxies, which do not pickle).
_JOB = {}


def _shoe_job(i):
    record = {} if _JOB['qa'] else None
    arr = active_contour_shoe(_JOB['profile'], _JOB['list_contour'],
                              plot_img=False, save_img_bool=True, im_num=i,
                              record=record)
    return arr, record


def run_snakes(profile, list_contour, jobs=1, qa=False):
    """The contour of every shoe image, in image order, and with qa the
    record of active_contour_shoe of every shoe (else None).

    jobs > 1 runs the shoes in that many forked processes (results in
    image order; tests/python/test_qa_snake.py checks that they equal the
    serial ones bit for bit). The default (jobs 1, qa False) is the legacy
    loop, unchanged."""
    n = len(list_contour)
    _JOB.update(profile=profile, list_contour=list_contour, qa=qa)
    try:
        if jobs <= 1:
            results = [_shoe_job(i) for i in tqdm(range(n))]
        else:
            ctx = multiprocessing.get_context('fork')
            with ctx.Pool(jobs) as pool:
                results = list(tqdm(pool.imap(_shoe_job, range(n)),
                                    total=n))
    finally:
        _JOB.clear()
    contours = [r[0] for r in results]
    records = [r[1] for r in results] if qa else None
    return contours, records


def save_snake_points(path, records):
    """The initial ellipses and both snakes of every shoe (T4 QA input):
    an npz with arrays init, first, second of shape (n, n_points, 2)."""
    np.savez(path, **{key: np.stack([r[key] for r in records])
                      for key in ('init', 'first', 'second')})


def main(profile, jobs=1, qa=False):
    print(f'{profile.dataset}\nactive_contour_snake')
    list_contour = np.load(profile.saved_path('list_contour', 'npy'))
    if len(list_contour) != profile.num_shoe:
        raise ValueError(f'list_contour has {len(list_contour)} shoes, the '
                         f'profile {profile.num_shoe}')
    # checked before the snakes run, so a wrong skip list fails at once
    skip = record_skip_idx0(profile)
    print(f'numpy OpenBLAS threads: {check_blas_threads(profile)}, '
          f'snake jobs: {jobs}')
    snake_all, records = run_snakes(profile, list_contour, jobs=jobs, qa=qa)
    np.save(profile.saved_path('active-contour_all', 'npy'), snake_all)
    if qa:
        save_snake_points(profile.saved_path('snake_points', 'npz'), records)

    # The contour file: one record per analysis shoe (plan section 4.3),
    # '0'/'1' row by row, CRLF after every record.
    n = write_shoes(profile.contour_out, snake_all, skip_idx0=skip)
    if n != len(profile.analysis_shoes()):
        raise ValueError(f'{n} contour records written, '
                         f'{len(profile.analysis_shoes())} analysis shoes')
    skipped = [i + 1 for i in skip]
    print(f'Active contour processing complete - {len(snake_all)} shoes, '
          f'{n} contour records (shoes without a record: {skipped})')
