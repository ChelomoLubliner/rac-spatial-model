"""Snake QA of step 0 (plan T4): per-shoe metrics, flags, QA figures and
contact sheets of a dataset's snake run (decisions A-091 to A-096).

Input: the outputs of ``python -m contour_algorithm.main --qa`` for the
profile's dataset (the shoe matrices, the prototype cleaning mask, the
contour file and ``saved/snake_points``: the initial ellipse and both
snakes of every shoe) and the RAC locations. Nothing of step 0 is
recomputed, so the QA describes exactly the run that wrote the contour.

Metrics of one shoe (``snake_metrics``; pixel units; "cleaned" = the raw
contact AND the prototype mask, the image the snake runs on):
  coverage        share of the cleaned contact pixels inside the polygon of
                  the final (second) snake (the task's coverage, target
                  >= 0.99)
  coverage_fill   the same share inside the row-span fill of the contour
                  record (each row filled between its leftmost and
                  rightmost contour pixel: what the R distances see; the
                  OLD reference of tests/legacy/old_snake_metrics.py)
  coverage_r      share of the R contact pixels (raw AND the R stamp mask,
                  plus every RAC pixel: dataCC_1.Rmd's data_temp, from
                  which R samples the controls) inside the row-span fill
  rac_coverage    share of the shoe's RAC pixels inside the row-span fill
  tightness       polygon area / convex-hull area of the cleaned contact
                  (target about 0.95-1.15)
  self_intersections  crossings of the closed snake polyline (0 for a
                  simple curve)
  turning         total absolute turning of the polyline / 2 pi (1 for a
                  convex curve; wiggles and loops raise it)
  max_turn_deg    largest turning angle at one vertex
  gap_mean_px, gap_max_px  distance from the snake points to the nearest
                  cleaned contact pixel (how loosely the snake hangs)
  cut_max_px      largest distance from a cleaned contact pixel outside the
                  polygon to the polygon (how deep the snake cuts in)
  rac_out_max_px  largest distance from a RAC pixel outside the record's
                  row-span fill to the fill (0: every RAC inside; NaN: no
                  RAC): one RAC far outside, which the rac_coverage share
                  of a RAC-rich shoe hides (T4 review, A-099)
  contact_out_max_px  the same for the cleaned contact pixels: printed sole
                  (or a speck) far outside the fill (A-099)
  n_contour_px, outside_mask_frac, touches_border, bbox  of the record

Flags (``flag_shoe``): a shoe fails QA when any pre-registered band of
``BANDS`` is broken (A-093); ``resolution`` records what review decided.

Command line (from the repository root, after step 0 with --qa):

    RAC_DATASET=old|new python -m contour_algorithm.qa_snake \\
        [--metrics] [--sheets] [--figures] [--flagged] [--crosscheck] \\
        [--thresholds T,T,...] [--jobs N]

--metrics writes the metrics table (`prep.snake_qa`) and, for a profile
with a sheets folder, its copy under the task's name
`<prep.sheets_dir>/snake_qa<suffix>.csv` (A-104); --sheets the contact
sheets (`prep.sheets_dir`/<kind>/); --figures one two-panel QA figure per
shoe (images*/qa_snake/); --flagged a large figure of every flagged shoe
(`prep.snake_qa_dir`/flagged/; the figures of shoes that are no longer
flagged are removed); --crosscheck the 2023 cross-check table. Refused
before anything is written (exit 2): --sheets and --thresholds without
the profile's sheets folder (OLD has none), --crosscheck without its 2023
file (inputs.cross_check; OLD has none), --jobs N > 1 where fork is not
available (Windows). --thresholds runs prototype snakes, so it checks the
OpenBLAS thread count and kernel first (A-092, A-108).
"""

import argparse
import math
import sys

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw

from .profiles import env, load_profile

# Pre-registered QA bands (A-093), fixed from the task and the OLD
# reference (docs/qa/T4/old/snake_metrics.csv: the committed OLD contours,
# which the user accepted, with the WSL snakes for the polygon metrics)
# before any NEW variant was scored: (metric, low, high); a value outside
# [low, high] flags the shoe.
#   task:  coverage >= 0.99; tightness about 0.95-1.15 (low end: the OLD p1
#          0.9047, because accepted OLD contours that follow the arch
#          concavity go down to 0.848, p5 0.941; TIGHTNESS_TASK_LOW is
#          reported beside it); no self-intersection; smoothness: total
#          turning and the largest turn at one vertex at most the OLD p99
#   plan:  contour pixels within the OLD range +-10% [553, 816]; no border
#          contact; coverage of the record fill and of the RACs at least the
#          OLD p1; contour share outside the mask at most the OLD p99
#   review (T4 review, A-099): absolute triggers beside the shares, so that
#          one RAC or one printed part far outside cannot hide in a share:
#          a RAC 3 px or more outside the record fill (distances are square
#          roots of integers, so > 2.9 means >= 3), cleaned contact more
#          than 8 px outside it (about the OLD p95, 8.06)
BANDS = (
    ('coverage', 0.99, None),
    ('tightness', 0.9047, 1.15),
    ('self_intersections', None, 0),
    ('turning', None, 4.4622),
    ('max_turn_deg', None, 31.4595),
    ('n_contour_px', 553, 816),
    ('touches_border', None, 0),
    ('coverage_fill', 0.9886, None),
    ('rac_coverage', 0.9696, None),
    ('outside_mask_frac', None, 0.3393),
    ('rac_out_max_px', None, 2.9),
    ('contact_out_max_px', None, 8.0),
)
# metrics that are undefined (NaN) for a shoe without RACs: not a flag
NO_RAC_NAN = ('rac_coverage', 'rac_out_max_px')
TIGHTNESS_TASK_LOW = 0.95
RESOLUTIONS = ('', 'ok_after_review', 'override', 'excluded')
REVIEW_CLASSES = ('', 'partial_print', 'spike', 'rim_cut', 'mask_cut')

FULL = int(np.iinfo(np.uint8).max)  # an 8-bit channel at its maximum
WHITE = (240, 240, 240)
GREY = (FULL * 3 // 5,) * 3
RED = (230, 30, 30)
GREEN = (0, 200, 0)
BLUE = (40, 110, FULL)
YELLOW = (FULL, 210, 0)
ORANGE = (FULL, 140, 0)
MAGENTA = (FULL, 60, FULL)
SHEET_COLUMNS = 7
SHEET_ROWS = 7
SHEET_KINDS = ('prototype', 'ellipse_first_snake', 'final_snake', 'cleaned')


# --- geometry --------------------------------------------------------------

def polygon_mask(points, shape):
    """Bool image of the pixels whose centres lie inside the closed polygon
    through `points` ((n, 2) as (row, col))."""
    from skimage.draw import polygon2mask
    return polygon2mask(shape, np.asarray(points, dtype=float))


def row_span_fill(contour):
    """Each row filled between its leftmost and rightmost True pixel."""
    contour = np.asarray(contour, dtype=bool)
    fill = np.zeros_like(contour)
    for r in np.flatnonzero(contour.any(axis=1)):
        cols = np.flatnonzero(contour[r])
        fill[r, cols.min():cols.max() + 1] = True
    return fill


def convex_hull_area(mask):
    """Pixels of the convex hull image of `mask` (0 for an empty mask)."""
    from skimage.morphology import convex_hull_image
    mask = np.asarray(mask, dtype=bool)
    if not mask.any():
        return 0
    return int(convex_hull_image(mask).sum())


def _closed_segments(points, eps=1e-9):
    """Start and end points of the segments of the closed polyline, without
    zero-length segments (the snake's first and last points coincide)."""
    p = np.asarray(points, dtype=float)
    q = np.roll(p, -1, axis=0)
    keep = np.hypot(*(q - p).T) > eps
    return p[keep], q[keep]


def self_intersections(points):
    """Number of pairs of non-adjacent segments of the closed polyline that
    cross properly (touching or collinear overlaps are not counted)."""
    a, b = _closed_segments(points)
    n = len(a)
    if n < 4:
        return 0

    def orient(p, q, r):
        return ((q[..., 0] - p[..., 0]) * (r[..., 1] - p[..., 1])
                - (q[..., 1] - p[..., 1]) * (r[..., 0] - p[..., 0]))
    i, j = np.triu_indices(n, k=2)
    adjacent = (i == 0) & (j == n - 1)
    i, j = i[~adjacent], j[~adjacent]
    d1 = orient(a[i], b[i], a[j])
    d2 = orient(a[i], b[i], b[j])
    d3 = orient(a[j], b[j], a[i])
    d4 = orient(a[j], b[j], b[i])
    return int(np.count_nonzero((d1 * d2 < 0) & (d3 * d4 < 0)))


def turning(points):
    """(total absolute turning / 2 pi, largest turning angle in degrees) of
    the closed polyline."""
    a, b = _closed_segments(points)
    v = b - a
    if len(v) < 3:
        return float('nan'), float('nan')
    w = np.roll(v, -1, axis=0)
    cross = v[:, 0] * w[:, 1] - v[:, 1] * w[:, 0]
    dot = (v * w).sum(axis=1)
    ang = np.abs(np.arctan2(cross, dot))
    return float(ang.sum() / (2 * math.pi)), float(np.degrees(ang.max()))


def sample_nearest(img, points):
    """Values of `img` at the nearest pixel of each point (clipped to the
    image)."""
    p = np.rint(np.asarray(points, dtype=float)).astype(int)
    r = np.clip(p[:, 0], 0, img.shape[0] - 1)
    c = np.clip(p[:, 1], 0, img.shape[1] - 1)
    return img[r, c]


# --- the R stamp mask (dataCC_1.Rmd, chunk 3_contacts_data) ---------------

def r_stamp_mask(shoes, threshold, sweep_bound):
    """The R contact mask of step 1: pixels in contact on at least
    `threshold` shoes, minus everything left of the lower bound and right
    of the upper bound that the two sweeps trace from the middle row up to
    the first row. A port of the R loops with their 1-based indices
    (tests/python/test_qa_snake.py checks it against the committed OLD
    data/all_cont.csv)."""
    shoes = np.asarray(shoes)
    a = (shoes.sum(axis=0) >= threshold).astype(np.int8)
    nrow, ncol = a.shape

    def at(r, j):  # R allcont[r, j], 1-based
        return a[r - 1, j - 1]
    h = nrow // 2
    lb = [0] * (h + 1)
    j = 1
    while at(h, j) == 0:
        j += 1
    lb[1] = j - 1
    for i in range(2, h + 1):
        r = h - i + 1
        j = lb[i - 1]
        if at(r, j) == 0:
            while at(r, j) == 0 and j < sweep_bound:
                j += 1
            lb[i] = j - 1
        else:
            while at(r, j) == 1 and j > 0:
                j -= 1
            lb[i] = j
    for i in range(1, h + 1):
        r = h - i + 1
        if lb[i] >= 1:
            a[r - 1, :lb[i]] = 0
        else:  # R 1:0 is c(1, 0): column 1
            a[r - 1, 0] = 0
    ub = [0] * (h + 1)
    j = ncol
    while at(h, j) == 0:
        j -= 1
    ub[1] = j + 1
    for i in range(2, h + 1):
        r = h - i + 1
        j = ub[i - 1]
        if at(r, j) == 0:
            while at(r, j) == 0 and j > 0:
                j -= 1
            ub[i] = j + 1
        else:
            while at(r, j) == 1 and j < sweep_bound:
                j += 1
            ub[i] = j
    for i in range(1, h + 1):
        r = h - i + 1
        a[r - 1, ub[i] - 1:] = 0
    return a.astype(bool)


# --- metrics ---------------------------------------------------------------

def snake_metrics(cleaned, contour, proto_mask, second, rac_rc=(),
                  r_contact=None):
    """QA metrics of one shoe (module docstring). cleaned, contour,
    proto_mask, r_contact: bool (H, W); second: the final snake (n, 2) as
    (row, col); rac_rc: the RAC pixels (row, col), 0-based."""
    from scipy.ndimage import distance_transform_edt
    cleaned = np.asarray(cleaned, dtype=bool)
    contour = np.asarray(contour, dtype=bool)
    shape = cleaned.shape
    poly = polygon_mask(second, shape)
    fill = row_span_fill(contour)
    n_clean = int(cleaned.sum())
    area_poly = int(poly.sum())
    area_hull = convex_hull_area(cleaned)
    out = {
        'cleaned_px': n_clean,
        'coverage': (float((cleaned & poly).sum() / n_clean) if n_clean
                     else float('nan')),
        'coverage_fill': (float((cleaned & fill).sum() / n_clean) if n_clean
                          else float('nan')),
        'outside_poly_px': int((cleaned & ~poly).sum()),
        'area_poly': area_poly,
        'area_hull': area_hull,
        'tightness': (area_poly / area_hull if area_hull
                      else float('nan')),
    }
    if r_contact is not None:
        rc = np.asarray(r_contact, dtype=bool)
        n_r = int(rc.sum())
        out['coverage_r'] = (float((rc & fill).sum() / n_r) if n_r
                             else float('nan'))
    rac = np.asarray(rac_rc, dtype=int).reshape(-1, 2)
    out['n_rac'] = len(rac)
    out['rac_coverage'] = (float(fill[rac[:, 0], rac[:, 1]].mean())
                           if len(rac) else float('nan'))
    # how far the farthest RAC and contact pixel lie outside the fill
    # (A-099); an empty record has no fill: everything is "outside"
    to_fill = (distance_transform_edt(~fill) if fill.any()
               else np.full(shape, np.inf))
    out['rac_out_max_px'] = (float(to_fill[rac[:, 0], rac[:, 1]].max())
                             if len(rac) else float('nan'))
    out['contact_out_max_px'] = (float(to_fill[cleaned].max()) if n_clean
                                 else 0.0)
    out['self_intersections'] = self_intersections(second)
    out['turning'], out['max_turn_deg'] = turning(second)
    if n_clean:
        to_contact = distance_transform_edt(~cleaned)
        gap = sample_nearest(to_contact, second)
        out['gap_mean_px'] = float(gap.mean())
        out['gap_max_px'] = float(gap.max())
        outside = cleaned & ~poly
        out['cut_max_px'] = (float(distance_transform_edt(~poly)[outside]
                                   .max()) if outside.any() else 0.0)
    else:
        out.update(gap_mean_px=float('nan'), gap_max_px=float('nan'),
                   cut_max_px=float('nan'))
    n_px = int(contour.sum())
    out['n_contour_px'] = n_px
    out['outside_mask_frac'] = (float((contour & ~proto_mask).sum() / n_px)
                                if n_px else float('nan'))
    out['touches_border'] = int(bool(contour[0].any() or contour[-1].any()
                                     or contour[:, 0].any()
                                     or contour[:, -1].any()))
    rows = np.flatnonzero(contour.any(axis=1))
    cols = np.flatnonzero(contour.any(axis=0))
    out['bbox_r0'], out['bbox_r1'] = ((int(rows[0]), int(rows[-1]))
                                      if len(rows) else (-1, -1))
    out['bbox_c0'], out['bbox_c1'] = ((int(cols[0]), int(cols[-1]))
                                      if len(cols) else (-1, -1))
    return out


def flag_shoe(row, bands=BANDS):
    """Names of the broken bands of a metrics row ('' when it passes): a
    value below low or above high, or NaN (an undefined metric fails)."""
    broken = []
    for name, low, high in bands:
        if name not in row:
            continue
        v = row[name]
        if v is None or (isinstance(v, float) and math.isnan(v)):
            if name in NO_RAC_NAN:  # a shoe without RACs
                continue
            broken.append(name)
        elif ((low is not None and v < low)
              or (high is not None and v > high)):
            broken.append(name)
    return ';'.join(broken)


# --- data of a run ---------------------------------------------------------

def rac_pixels(profile):
    """{1-based shoe: (n, 2) int array of RAC pixels (row, col), 0-based}
    by the profile's mapping (calibrate_pixels.legacy_pixel = R aspix)."""
    from .calibrate_pixels import legacy_pixel
    from .locations import read_locations
    locs = read_locations(profile)
    col1, row1 = legacy_pixel(locs['x'], locs['y'], profile.coords,
                              profile.W, profile.H)
    rc = np.stack([row1 - 1, col1 - 1], axis=1)
    shoe = locs['shoe'].to_numpy(dtype=np.int64)
    ok = ((rc[:, 0] >= 0) & (rc[:, 0] < profile.H) & (rc[:, 1] >= 0)
          & (rc[:, 1] < profile.W))
    return {int(s): rc[(shoe == s) & ok] for s in np.unique(shoe)}


def load_run(profile):
    """The step-0 outputs of the profile's dataset that the QA reads."""
    from .io_shoes import read_shoes
    matrices = np.load(profile.saved_path('list_matrices', 'npy'))
    mask = np.load(profile.saved_path(profile.stem('prototype_mask'), 'npy'))
    shoes = profile.analysis_shoes()
    records = read_shoes(profile.contour_out, profile.W, profile.H,
                         len(shoes))
    from .stickers import apply_sticker_masks, read_sticker_masks
    pts = np.load(profile.saved_path('snake_points', 'npz'))
    stored = read_shoes(profile.contacts, profile.W, profile.H,
                        profile.num_shoe)
    # both halves erase the profile's list first (A-095): the Python
    # matrices carry it already, R's contact is rebuilt here the same way
    raw, _ = apply_sticker_masks(stored, read_sticker_masks(profile))
    shown = stored.copy()
    for shoe in profile.contact_flip_shoes:
        shown[shoe - 1] = np.fliplr(shown[shoe - 1])
    for shoe in profile.r['contact_flip_shoes']:
        raw[int(shoe) - 1] = raw[int(shoe) - 1][:, ::-1]
    return {
        'matrices': matrices, 'mask': mask, 'shoes': shoes,
        'records': records, 'init': pts['init'], 'first': pts['first'],
        'second': pts['second'], 'raw_r': raw,
        'erased': shown & ~matrices,
        'r_mask': r_stamp_mask(raw, profile.r['stamp_threshold'],
                               profile.r['stamp_sweep_bound']),
        'racs': rac_pixels(profile),
    }


# The run shared with the forked workers of metrics_table() (set before
# the pool starts; nothing large is pickled).
_RUN = {}


def _shoe_row(k):
    run = _RUN['run']
    shoe = run['shoes'][k]
    i = shoe - 1
    cleaned = run['matrices'][i] & run['mask']
    rac = run['racs'].get(shoe, np.zeros((0, 2), dtype=int))
    r_contact = run['raw_r'][i] & run['r_mask']
    if len(rac):
        r_contact = r_contact.copy()
        r_contact[rac[:, 0], rac[:, 1]] = True
    m = snake_metrics(cleaned, run['records'][k], run['mask'],
                      run['second'][i], rac, r_contact)
    row = {'shoe': shoe, 'record': k + 1,
           'raw_px': int(run['matrices'][i].sum()),
           'removed_by_mask_px': int((run['matrices'][i]
                                      & ~run['mask']).sum()), **m}
    row['qa_flags'] = flag_shoe(row)
    return row


def metrics_table(profile, run=None, log=print, jobs=1):
    """One row per analysis shoe: shoe, record, the metrics, flags (jobs:
    forked processes; the rows do not depend on it)."""
    import multiprocessing
    run = load_run(profile) if run is None else run
    _RUN['run'] = run
    try:
        ks = range(len(run['shoes']))
        if jobs <= 1:
            rows = [_shoe_row(k) for k in ks]
        else:
            with multiprocessing.get_context('fork').Pool(jobs) as pool:
                rows = pool.map(_shoe_row, ks, chunksize=8)
    finally:
        _RUN.clear()
    table = pd.DataFrame(rows)
    n_fail = int((table['qa_flags'] != '').sum())
    n = len(table)
    log(f'{profile.dataset}: {n} shoes, {n_fail} flagged, {n - n_fail} '
        f'pass every band ({100 * (n - n_fail) / n:.2f}%)')
    return table


ROUND = {'coverage': 4, 'coverage_fill': 4, 'coverage_r': 4,
         'rac_coverage': 4, 'tightness': 4, 'turning': 4,
         'max_turn_deg': 2, 'gap_mean_px': 3, 'gap_max_px': 3,
         'cut_max_px': 3, 'outside_mask_frac': 4, 'rac_out_max_px': 3,
         'contact_out_max_px': 3}


REVIEW_COLUMNS = ('shoe', 'resolution', 'review_class', 'note')


def read_review(profile):
    """The visual review, <snake_qa_dir>/snake_review<suffix>.csv, as a
    DataFrame indexed by shoe (REVIEW_COLUMNS; empty without a file).

    resolution: what the review decided for a flagged shoe (RESOLUTIONS;
    '' for a shoe that passes every band and is listed only for its
    class). review_class: '' or one of REVIEW_CLASSES, a known kind of
    contour that later tasks can select (T4 review, A-101): partial_print
    (the contour is the envelope of what was printed, not of the sole),
    spike (it reaches up to an isolated mark), rim_cut (it runs 1-3 px
    inside a printed rim), mask_cut (real sole beyond the cleaning mask's
    edge is cut). note: why, for every listed shoe."""
    path = snake_qa_path(profile, 'snake_review', 'csv')
    if not path.is_file():
        return pd.DataFrame(columns=REVIEW_COLUMNS[1:],
                            index=pd.Index([], name='shoe'))
    review = pd.read_csv(path, keep_default_na=False)
    if tuple(review.columns) != REVIEW_COLUMNS:
        raise ValueError(f'{path}: columns must be '
                         f'{",".join(REVIEW_COLUMNS)}')
    if review['shoe'].duplicated().any():
        raise ValueError(f'{path}: a shoe is listed twice')
    bad = set(review['resolution']) - set(RESOLUTIONS)
    bad |= set(review['review_class']) - set(REVIEW_CLASSES)
    if bad:
        raise ValueError(f'{path}: unknown resolutions or classes '
                         f'{sorted(bad)}')
    empty = review[(review['resolution'] == '')
                   & (review['review_class'] == '')]
    if len(empty) or (review['note'].str.strip() == '').any():
        raise ValueError(f'{path}: every row needs a resolution or a class, '
                         'and a note')
    return review.set_index('shoe')


def with_review(profile, table):
    """The metrics table with the visual review merged in (read_review):
    resolution, review_class and note, empty for the shoes the review
    does not list."""
    review = read_review(profile)
    out = table.copy()
    for col in REVIEW_COLUMNS[1:]:
        out[col] = ''
    hit = out['shoe'].isin(review.index)
    for col in REVIEW_COLUMNS[1:]:
        out.loc[hit, col] = review.loc[out.loc[hit, 'shoe'],
                                       col].to_numpy()
    return out


def write_table(table, path):
    """The metrics table as a CSV (LF, fixed rounding)."""
    out = table.copy()
    for col, nd in ROUND.items():
        if col in out:
            out[col] = out[col].round(nd)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(path, index=False, lineterminator='\n')
    return path


# --- drawing ---------------------------------------------------------------

def inner_boundary(mask):
    """The 4-connected inner boundary of a bool mask."""
    p = np.pad(mask, 1, constant_values=False)
    interior = (p[1:-1, 1:-1] & p[:-2, 1:-1] & p[2:, 1:-1]
                & p[1:-1, :-2] & p[1:-1, 2:])
    return mask & ~interior


def rgb(binary, colour=WHITE):
    img = np.zeros(binary.shape + (3,), dtype=np.uint8)
    img[binary] = colour
    return img


def draw_polyline(img, points, colour, width=1, dashed=False, closed=True,
                  scale=1.0):
    """Draw (row, col) points on an RGB array (in place); dashed: every
    other run of 6 segments."""
    im = Image.fromarray(img)
    d = ImageDraw.Draw(im)
    p = np.asarray(points, dtype=float) * scale
    xy = [(float(c), float(r)) for r, c in p]
    if closed:
        xy.append(xy[0])
    if dashed:
        for k in range(len(xy) - 1):
            if (k // 6) % 2 == 0:
                d.line([xy[k], xy[k + 1]], fill=colour, width=width)
    else:
        d.line(xy, fill=colour, width=width)
    img[...] = np.asarray(im)
    return img


def tile_prototype(raw, mask, erased=None):
    """Raw contact: kept by the mask grey-white, removed red, erased by
    the profile's erase list magenta; the mask boundary green (the
    information of shoe_on_prototype, in colour)."""
    img = np.zeros(raw.shape + (3,), dtype=np.uint8)
    img[raw & mask] = WHITE
    img[raw & ~mask] = RED
    if erased is not None:
        img[erased] = MAGENTA
    img[inner_boundary(mask)] = GREEN
    return img


def tile_ellipse_first(cleaned, init, first):
    img = rgb(cleaned, GREY)
    draw_polyline(img, init, RED, width=1, dashed=True)
    draw_polyline(img, first, BLUE, width=2)
    return img


def tile_final(raw, mask, second, erased=None):
    """The raw contact (removed by the mask in red, erased by the erase
    list magenta) and the final snake."""
    img = np.zeros(raw.shape + (3,), dtype=np.uint8)
    img[raw & mask] = WHITE
    img[raw & ~mask] = RED
    if erased is not None:
        img[erased] = MAGENTA
    draw_polyline(img, second, BLUE, width=2)
    return img


def tile_cleaned(cleaned):
    return rgb(cleaned, WHITE)


def contact_sheet(tiles, labels, label_colours, ncols, out, label_h=13,
                  gap=4, background=40):
    """Tiles in a grid with a label above each; a palette PNG."""
    th = max(t.shape[0] for t in tiles)
    tw = max(t.shape[1] for t in tiles)
    nrows = math.ceil(len(tiles) / ncols)
    canvas = np.full((nrows * (th + label_h + gap), ncols * (tw + gap), 3),
                     background, dtype=np.uint8)
    for k, tile in enumerate(tiles):
        r0 = (k // ncols) * (th + label_h + gap) + label_h
        c0 = (k % ncols) * (tw + gap)
        canvas[r0:r0 + tile.shape[0], c0:c0 + tile.shape[1]] = tile
    im = Image.fromarray(canvas)
    d = ImageDraw.Draw(im)
    for k, (text, colour) in enumerate(zip(labels, label_colours)):
        r0 = (k // ncols) * (th + label_h + gap)
        c0 = (k % ncols) * (tw + gap)
        d.text((c0 + 2, r0 + 1), text, fill=colour)
    out.parent.mkdir(parents=True, exist_ok=True)
    im = im.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=0)
    im.save(out, optimize=True)
    return out


def sheet_tiles(kind, run, table, shoes):
    """Tiles and labels of one kind for the given 1-based shoes."""
    by_shoe = table.set_index('shoe') if table is not None else None
    tiles, labels, colours = [], [], []
    for shoe in shoes:
        i = shoe - 1
        raw = run['matrices'][i]
        cleaned = raw & run['mask']
        erased = run['erased'][i] if 'erased' in run else None
        if kind == 'prototype':
            tile = tile_prototype(raw, run['mask'], erased)
        elif kind == 'ellipse_first_snake':
            tile = tile_ellipse_first(cleaned, run['init'][i],
                                      run['first'][i])
        elif kind == 'final_snake':
            tile = tile_final(raw, run['mask'], run['second'][i], erased)
        else:
            tile = tile_cleaned(cleaned)
        tiles.append(tile)
        text, colour = f'{shoe}', WHITE
        if by_shoe is not None and shoe in by_shoe.index:
            r = by_shoe.loc[shoe]
            if kind == 'prototype':
                text += f' rm={int(r["removed_by_mask_px"])}'
            elif kind == 'cleaned':
                text += f' px={int(r["cleaned_px"])}'
            else:
                text += f' cov={r["coverage"]:.3f} t={r["tightness"]:.2f}'
            if r['qa_flags']:
                text += ' !'
                colour = YELLOW
        labels.append(text)
        colours.append(colour)
    return tiles, labels, colours


def write_sheets(profile, run, table, kinds=SHEET_KINDS, log=print):
    """Every analysis shoe in sheets of SHEET_COLUMNS x SHEET_ROWS, one
    folder per kind below `prep.sheets_dir`; returns the paths."""
    folder = profile.prep_path('sheets_dir')
    shoes = list(run['shoes'])
    per = SHEET_COLUMNS * SHEET_ROWS
    paths = []
    for kind in kinds:
        for k in range(math.ceil(len(shoes) / per)):
            part = shoes[k * per:(k + 1) * per]
            tiles, labels, colours = sheet_tiles(kind, run, table, part)
            name = f'{kind}_sheet_{k + 1:02d}{profile.suffix}.png'
            paths.append(contact_sheet(tiles, labels, colours, SHEET_COLUMNS,
                                       folder / kind / name))
    log(f'wrote {len(paths)} sheets below {folder}')
    return paths


def pair_tile(run, shoe):
    """Two panels of one shoe side by side: the cleaned shoe with the
    initial ellipse (red dashed) and the first snake (blue); the raw shoe
    (removed by the mask red) with the final snake (blue)."""
    i = shoe - 1
    raw = run['matrices'][i]
    a = tile_ellipse_first(raw & run['mask'], run['init'][i],
                           run['first'][i])
    b = tile_final(raw, run['mask'], run['second'][i])
    gap = np.full((a.shape[0], 3, 3), 90, dtype=np.uint8)
    return np.concatenate([a, gap, b], axis=1)


def review_tile(run, shoe):
    """pair_tile with the shoe's RAC pixels drawn on the second panel as
    3 x 3 squares: green inside the contour's row-span fill, magenta
    outside it (the RACs that rac_coverage counts as missed)."""
    i = shoe - 1
    tile = pair_tile(run, shoe)
    k = list(run['shoes']).index(shoe)
    fill = row_span_fill(run['records'][k])
    rac = run['racs'].get(shoe, np.zeros((0, 2), dtype=int))
    off = run['matrices'][i].shape[1] + 3
    for r, c in rac:
        colour = GREEN if fill[r, c] else MAGENTA
        r0, r1 = max(r - 1, 0), min(r + 2, tile.shape[0])
        c0, c1 = max(c - 1, 0) + off, min(c + 2 + off, tile.shape[1])
        tile[r0:r1, c0:c1] = colour
    return tile


def pair_sheets(run, table, shoes, out_stem, per_sheet=20, ncols=4,
                tile=pair_tile):
    """Sheets of pair_tile for the given shoes (flagged-shoe review);
    returns the paths <out_stem>_<kk>.png."""
    by_shoe = table.set_index('shoe')
    paths = []
    for k in range(math.ceil(len(shoes) / per_sheet)):
        part = shoes[k * per_sheet:(k + 1) * per_sheet]
        tiles = [tile(run, s) for s in part]
        labels, colours = [], []
        for s in part:
            r = by_shoe.loc[s]
            labels.append(f'{s} cov={r["coverage"]:.3f} t={r["tightness"]:.2f}'
                          f' {r["qa_flags"]}')
            colours.append(YELLOW if r['qa_flags'] else WHITE)
        out = out_stem.parent / f'{out_stem.name}_{k + 1:02d}.png'
        paths.append(contact_sheet(tiles, labels, colours, ncols, out))
    return paths


def snake_qa_figure(original, init, first, second, out, title='',
                    scale=2):
    """Two panels: original + init red dashed + first snake blue; original
    + init red dashed + second snake blue (plan T4 interface), each scaled
    up `scale` times."""
    panels = []
    for snake in (first, second):
        base = rgb(np.asarray(original, dtype=bool), GREY)
        big = np.asarray(Image.fromarray(base).resize(
            (base.shape[1] * scale, base.shape[0] * scale), Image.NEAREST))
        big = big.copy()
        draw_polyline(big, init, RED, width=2, dashed=True, scale=scale)
        draw_polyline(big, snake, BLUE, width=2, scale=scale)
        panels.append(big)
    gap = np.full((panels[0].shape[0], 8, 3), FULL, dtype=np.uint8)
    img = np.concatenate([panels[0], gap, panels[1]], axis=1)
    head = np.full((18, img.shape[1], 3), FULL, dtype=np.uint8)
    im = Image.fromarray(np.concatenate([head, img], axis=0))
    ImageDraw.Draw(im).text((4, 3), title, fill=(0, 0, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out, optimize=True)
    return out


def flagged_figure(run, row, out, scale=2):
    """A large figure of one shoe: init + first snake on the cleaned shoe,
    init + second snake on the cleaned shoe, the raw shoe (removed by the
    mask red, mask boundary green, final snake blue, RAC pixels yellow)."""
    i = int(row['shoe']) - 1
    raw = run['matrices'][i]
    cleaned = raw & run['mask']
    panels = []
    for snake in (run['first'][i], run['second'][i]):
        base = rgb(cleaned, GREY)
        big = np.asarray(Image.fromarray(base).resize(
            (base.shape[1] * scale, base.shape[0] * scale),
            Image.NEAREST)).copy()
        draw_polyline(big, run['init'][i], RED, width=2, dashed=True,
                      scale=scale)
        draw_polyline(big, snake, BLUE, width=2, scale=scale)
        panels.append(big)
    base = tile_prototype(raw, run['mask'], run['erased'][i])
    rac = run['racs'].get(int(row['shoe']), np.zeros((0, 2), dtype=int))
    base[rac[:, 0], rac[:, 1]] = YELLOW
    big = np.asarray(Image.fromarray(base).resize(
        (base.shape[1] * scale, base.shape[0] * scale), Image.NEAREST)).copy()
    draw_polyline(big, run['second'][i], BLUE, width=2, scale=scale)
    panels.append(big)
    gap = np.full((panels[0].shape[0], 8, 3), FULL, dtype=np.uint8)
    img = np.concatenate([panels[0], gap, panels[1], gap, panels[2]], axis=1)
    head = np.full((30, img.shape[1], 3), FULL, dtype=np.uint8)
    im = Image.fromarray(np.concatenate([head, img], axis=0))
    text = (f'shoe {int(row["shoe"])}: cov {row["coverage"]:.4f}, fill '
            f'{row["coverage_fill"]:.4f}, tight {row["tightness"]:.3f}, '
            f'{int(row["n_contour_px"])} px, flags: {row["qa_flags"]}')
    ImageDraw.Draw(im).text((4, 3), text, fill=(0, 0, 0))
    ImageDraw.Draw(im).text(
        (4, 16), 'red dashed: initial ellipse; blue: first snake | second '
        'snake | raw shoe (red removed by the mask, magenta erased by the '
        'erase list, green mask boundary, yellow RACs)', fill=(0, 0, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out, optimize=True)
    return out


# --- the erase list (stickers.py) ------------------------------------------

def read_sticker_shoes(profile):
    """The shoes of the profile's erase list (none for OLD)."""
    from .stickers import read_sticker_masks
    return [int(s) for s in read_sticker_masks(profile)['shoe']]


def snake_qa_path(profile, stem, ext):
    """A T4 QA file: <prep.snake_qa_dir>/<stem><suffix>.<ext>."""
    if not stem or '/' in stem or '.' in stem:
        raise ValueError(f'bad stem {stem!r}')
    folder = profile.prep_path('snake_qa_dir')
    if folder is None:
        raise ValueError(f'the {profile.dataset} profile has no T4 QA folder')
    return folder / f'{stem}{profile.suffix}.{ext}'


def sticker_table(profile):
    """The profile's erase list with the number of raw contact pixels each
    rectangle erases (erased_px) and of those inside the prototype mask
    (erased_in_mask_px: what the cleaning alone would have kept)."""
    from .io_shoes import read_shoes
    from .stickers import apply_sticker_masks, read_sticker_masks
    table = read_sticker_masks(profile)
    raw = read_shoes(profile.contacts, profile.W, profile.H,
                     profile.num_shoe)
    _, erased = apply_sticker_masks(raw, table)
    mask = np.load(profile.saved_path(profile.stem('prototype_mask'),
                                      'npy'))
    _, inside = apply_sticker_masks(raw & mask, table)
    out = table.drop(columns=['reason'])
    out['erased_px'] = erased
    out['erased_in_mask_px'] = inside
    out['reason'] = table['reason']
    return out


# --- cross-check with the 2023 processing (plan T4 step 7) -----------------

def crosscheck_2023(profile, run):
    """Per shoe, the RACs of the 2023 file (`inputs.cross_check`: COL, ROW
    1-based, INSIDE_SNAKE, DIST_SNAKE in pixels) against the profile's
    contour: n_rac, inside_new (RAC pixel in the record's row-span fill),
    inside_2023, inside_disagree (new - 2023), and the absolute difference
    between DIST_SNAKE and the distance from the RAC pixel to the nearest
    contour pixel (median, p90, max; pixels)."""
    old = pd.read_csv(profile.cross_check)
    rows = []
    for shoe, g in old.groupby('shoe'):
        k = list(run['shoes']).index(int(shoe))
        rec = run['records'][k]
        fill = row_span_fill(rec)
        pts = np.argwhere(rec)
        r0 = g['ROW'].to_numpy() - 1
        c0 = g['COL'].to_numpy() - 1
        d = np.hypot(pts[:, 0][None, :] - r0[:, None],
                     pts[:, 1][None, :] - c0[:, None]).min(axis=1)
        dd = np.abs(d - g['DIST_SNAKE'].to_numpy())
        inside = fill[r0, c0]
        rows.append({'shoe': int(shoe), 'n_rac': len(g),
                     'inside_new': int(inside.sum()),
                     'inside_2023': int(g['INSIDE_SNAKE'].sum()),
                     'med_abs_dd': float(np.median(dd)),
                     'p90_abs_dd': float(np.quantile(dd, 0.9)),
                     'max_abs_dd': float(dd.max())})
    out = pd.DataFrame(rows)
    out['inside_disagree'] = out['inside_new'] - out['inside_2023']
    return out


# --- prototype cleaning-mask threshold (plan T4 step 3) --------------------

def threshold_study(profile, thresholds, r_thresholds=(), shoes_of_note=(),
                    log=print):
    """For each superposition threshold t: the snake-filled prototype mask
    that step 0a would build (prototype_mask_from, the profile's snake) and
    what it keeps and removes. Returns (table, {t: (mask, record)}).

    Columns: threshold, superposed_px (pixels in contact on >= t shoes),
    mask_px, mask rows and columns, rac_px_in_mask (share of the RAC pixels
    inside the mask), kept_median / kept_p5 / kept_p1 / kept_min (per shoe,
    the share of its raw contact inside the mask), shoes_kept_lt_099,
    removed_px (raw contact outside the mask, all shoes), shoes_removed
    (shoes that lose any pixel), r<t>_outside_px (pixels of the R stamp mask
    of threshold t outside this mask) and r<t>_contact_outside_px (R
    contact pixels of all shoes outside it), removed_<shoe> for the shoes
    of note (T3 frame artefacts)."""
    from skimage import img_as_ubyte

    from .active_contour_snake import prototype_mask_from
    matrices = np.load(profile.saved_path('list_matrices', 'npy'))
    total = matrices.sum(axis=0)
    raw_px = matrices.sum(axis=(1, 2))
    racs = rac_pixels(profile)
    rac_rc = np.concatenate([v for v in racs.values()])
    r_masks = {t: r_stamp_mask(matrices, t, profile.r['stamp_sweep_bound'])
               for t in r_thresholds}
    rows, masks = [], {}
    for t in thresholds:
        record = {}
        mask = prototype_mask_from(profile, img_as_ubyte(total >= t),
                                   record=record)
        masks[t] = (mask, record)
        kept = (matrices & mask).sum(axis=(1, 2)) / raw_px
        rr = np.flatnonzero(mask.any(axis=1))
        cc = np.flatnonzero(mask.any(axis=0))
        row = {'threshold': t, 'superposed_px': int((total >= t).sum()),
               'mask_px': int(mask.sum()),
               'mask_rows': f'{rr[0]}-{rr[-1]}',
               'mask_cols': f'{cc[0]}-{cc[-1]}',
               'rac_px_in_mask': float(mask[rac_rc[:, 0],
                                            rac_rc[:, 1]].mean()),
               'kept_median': float(np.median(kept)),
               'kept_p5': float(np.quantile(kept, 0.05)),
               'kept_p1': float(np.quantile(kept, 0.01)),
               'kept_min': float(kept.min()),
               'shoe_kept_min': int(np.argmin(kept)) + 1,
               'shoes_kept_lt_099': int((kept < 0.99).sum()),
               'removed_px': int((matrices & ~mask).sum()),
               'shoes_removed': int(((matrices & ~mask).sum(axis=(1, 2))
                                     > 0).sum())}
        for rt, rm in r_masks.items():
            row[f'r{rt}_outside_px'] = int((rm & ~mask).sum())
            row[f'r{rt}_contact_outside_px'] = int(
                (matrices & (rm & ~mask)).sum())
        for shoe in shoes_of_note:
            row[f'removed_{shoe}'] = int((matrices[shoe - 1] & ~mask).sum())
        rows.append(row)
        log(f'threshold {t}: mask {row["mask_px"]} px, RAC pixels inside '
            f'{row["rac_px_in_mask"]:.4f}, kept median '
            f'{row["kept_median"]:.4f}, p5 {row["kept_p5"]:.4f}, removed '
            f'{row["removed_px"]} px from {row["shoes_removed"]} shoes')
    return pd.DataFrame(rows), masks


def threshold_figure(profile, masks, out, chosen=None):
    """One column per threshold: the superposition count with the mask
    boundary (green), the initial ellipse (red dashed) and the prototype
    snakes (first light blue, second blue); below it the filled mask.
    Last column: the masks compared (white: in every mask; orange: only in
    the masks of the lower thresholds) over the union of all prints
    (grey)."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    matrices = np.load(profile.saved_path('list_matrices', 'npy'))
    total = matrices.sum(axis=0)
    ts = sorted(masks)
    fig, axes = plt.subplots(2, len(ts) + 1,
                             figsize=(3.3 * (len(ts) + 1), 9.6), dpi=110)
    for j, t in enumerate(ts):
        mask, rec = masks[t]
        ax = axes[0, j]
        ax.imshow(total, cmap='viridis', interpolation='nearest')
        b = np.argwhere(inner_boundary(mask))
        ax.plot(b[:, 1], b[:, 0], ',', color='lime')
        ax.plot(rec['init'][:, 1], rec['init'][:, 0], '--', color='red',
                lw=1)
        ax.plot(rec['first'][:, 1], rec['first'][:, 0], '-',
                color='deepskyblue', lw=0.8)
        ax.plot(rec['second'][:, 1], rec['second'][:, 0], '-', color='blue',
                lw=1)
        mark = ' (chosen)' if t == chosen else ''
        ax.set_title(f'>= {t} shoes{mark}: count, mask boundary,\n'
                     'ellipse, prototype snakes 1 and 2', fontsize=8)
        ax = axes[1, j]
        ax.imshow(mask, cmap='gray', interpolation='nearest')
        ax.set_title(f'freq_min_{t}{profile.suffix}: {int(mask.sum())} px',
                     fontsize=8)
    union = matrices.any(axis=0)
    img = np.zeros(union.shape + (3,), dtype=np.uint8)
    img[union] = (90, 90, 90)
    every = np.logical_and.reduce([masks[t][0] for t in ts])
    some = np.logical_or.reduce([masks[t][0] for t in ts])
    img[some & ~every] = ORANGE
    img[every] = (235, 235, 235)
    axes[0, -1].imshow(img, interpolation='nearest')
    axes[0, -1].set_title('white: in every mask; orange: only at the\n'
                          'lower threshold; grey: union of all prints',
                          fontsize=8)
    diff = np.zeros(union.shape + (3,), dtype=np.uint8)
    diff[some & ~every] = ORANGE
    axes[1, -1].imshow(diff, interpolation='nearest')
    axes[1, -1].set_title(f'difference only: {int((some & ~every).sum())} '
                          'px', fontsize=8)
    for ax in axes.ravel():
        ax.set_xticks([])
        ax.set_yticks([])
    fig.suptitle(f'{profile.dataset}: prototype cleaning mask per '
                 'superposition threshold', fontsize=10)
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out)
    plt.close(fig)
    return out


# --- command line ----------------------------------------------------------

def task_copy_path(profile):
    """The metrics table under the task's name, in the profile's sheets
    folder: <prep.sheets_dir>/snake_qa<suffix>.csv (A-104); None for a
    profile without a sheets folder (OLD)."""
    folder = profile.prep_path('sheets_dir')
    if folder is None:
        return None
    return folder / f'snake_qa{profile.suffix}.csv'


def prune_flagged(folder, keep, suffix):
    """Delete the flagged-shoe figures of `folder` that are not in `keep`
    (file names): the figures of shoes that are no longer flagged
    (second T4 review; im_164_new.png had to be removed by hand). Only
    files named like a per-shoe image, im_<index><suffix>.png, are
    touched. Returns the removed names, sorted."""
    import re
    pattern = re.compile(rf'im_\d+{re.escape(suffix)}\.png')
    keep = set(keep)
    removed = []
    if folder.is_dir():
        for f in sorted(folder.iterdir()):
            if (f.is_file() and pattern.fullmatch(f.name)
                    and f.name not in keep):
                f.unlink()
                removed.append(f.name)
    return removed


def refusal(profile, args):
    """Why the command line cannot run for this profile ('' when it
    can), checked before anything is written: --sheets and --thresholds
    write into the sheets folder, which OLD has not; --crosscheck needs
    the profile's 2023 file (inputs.cross_check; OLD has none); --jobs > 1
    needs fork (not on Windows)."""
    import multiprocessing
    if profile.prep_path('sheets_dir') is None:
        wants = [o for o, on in (('--sheets', args.sheets),
                                 ('--thresholds', args.thresholds)) if on]
        if wants:
            verb = 'need' if len(wants) > 1 else 'needs'
            return (f'{" and ".join(wants)} {verb} the profile\'s sheets '
                    f'folder (prep.sheets_dir), and the {profile.dataset} '
                    'profile has none')
    if args.crosscheck and profile.cross_check is None:
        return (f'--crosscheck needs the profile\'s 2023 cross-check file '
                f'(inputs.cross_check), and the {profile.dataset} profile '
                'has none')
    if args.jobs > 1 and 'fork' not in multiprocessing.get_all_start_methods():
        return (f'--jobs {args.jobs} runs forked processes, and this '
                'platform has no fork; use --jobs 1')
    return ''


def main(argv=None):
    if env('RAC_PROFILE_FILE', None) is not None:
        print('contour_algorithm.qa_snake: RAC_PROFILE_FILE is set; it is a '
              'test hook and a real run refuses it (decision A-049)',
              file=sys.stderr)
        return 2
    parser = argparse.ArgumentParser(
        prog='python -m contour_algorithm.qa_snake',
        description='Snake QA of a step-0 run (RAC_DATASET).')
    parser.add_argument('--metrics', action='store_true')
    parser.add_argument('--sheets', action='store_true')
    parser.add_argument('--figures', action='store_true')
    parser.add_argument('--flagged', action='store_true')
    parser.add_argument('--jobs', type=int, default=1,
                        help='forked processes for the metrics')
    parser.add_argument('--thresholds', default=None,
                        help='comma list: the prototype-mask threshold '
                             'study (mask_threshold table and the '
                             'prototype_mask figure of the sheets folder)')
    parser.add_argument('--crosscheck', action='store_true',
                        help='compare with the 2023 snake distances '
                             '(inputs.cross_check)')
    parser.add_argument('--compare', default=None,
                        help='comma list: the thresholds of the figure '
                             '(default: all of --thresholds)')
    args = parser.parse_args(argv)
    try:
        profile = load_profile()
    except ValueError as e:
        print(f'contour_algorithm.qa_snake: {e}', file=sys.stderr)
        return 2
    problem = refusal(profile, args)
    if problem:
        print(f'contour_algorithm.qa_snake: {problem}', file=sys.stderr)
        return 2
    if args.thresholds:
        from .active_contour_snake import check_blas_threads
        # the threshold study runs prototype snakes, which depend on the
        # OpenBLAS thread count (A-092): the profile's count or nothing
        try:
            check_blas_threads(profile)
        except RuntimeError as e:
            print(f'contour_algorithm.qa_snake: {e}', file=sys.stderr)
            return 2
        ts = [int(t) for t in args.thresholds.split(',')]
        # the R stamp masks of the OLD threshold and of this profile's
        r_ts = sorted({int(load_profile('old').r['stamp_threshold']),
                       int(profile.r['stamp_threshold'])})
        study, masks = threshold_study(
            profile, ts, r_thresholds=r_ts,
            shoes_of_note=sorted(set(read_sticker_shoes(profile))))
        out = snake_qa_path(profile, 'mask_threshold', 'csv')
        study.to_csv(out, index=False, lineterminator='\n')
        print(f'wrote {out}')
        chosen = profile.superpose_threshold
        pair = ts if not args.compare else [
            int(t) for t in args.compare.split(',') if int(t) in ts]
        fig = profile.prep_path('sheets_dir') / 'prototype' / (
            f'prototype_mask{profile.suffix}.png')
        fig = threshold_figure(profile, {t: masks[t] for t in pair}, fig,
                               chosen=chosen)
        print(f'wrote {fig}')
    run = load_run(profile)
    table = metrics_table(profile, run, jobs=args.jobs)
    if args.metrics:
        out = write_table(with_review(profile, table),
                          profile.prep_path('snake_qa'))
        print(f'wrote {out}')
        copy = task_copy_path(profile)
        if copy is not None:
            copy.write_bytes(out.read_bytes())
            print(f'wrote {copy}')
        if profile.sticker_masks is not None:
            out = snake_qa_path(profile, 'sticker_erased', 'csv')
            sticker_table(profile).to_csv(out, index=False,
                                          lineterminator='\n')
            print(f'wrote {out}')
    if args.crosscheck:
        out = snake_qa_path(profile, 'crosscheck_2023', 'csv')
        crosscheck_2023(profile, run).round(3).to_csv(
            out, index=False, lineterminator='\n')
        print(f'wrote {out}')
    if args.sheets:
        write_sheets(profile, run, table)
    if args.figures:
        for shoe in run['shoes']:
            i = shoe - 1
            snake_qa_figure(run['matrices'][i] & run['mask'], run['init'][i],
                            run['first'][i], run['second'][i],
                            profile.image_path('qa_snake', i),
                            title=f'{profile.dataset} shoe {shoe}')
    if args.flagged:
        folder = profile.prep_path('snake_qa_dir') / 'flagged'
        names = []
        for _, row in table[table['qa_flags'] != ''].iterrows():
            i = int(row['shoe']) - 1
            names.append(profile.image_path('qa_snake', i).name)
            flagged_figure(run, row, folder / names[-1])
        for name in prune_flagged(folder, names, profile.suffix):
            print(f'removed {folder / name} (no longer flagged)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
