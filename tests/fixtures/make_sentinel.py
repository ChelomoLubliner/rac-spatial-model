"""Write the sentinel fixture of tests/fixtures/sentinel/ (decisions A-035,
A-050; plan T2 step 1).

A tiny synthetic dataset whose profile holds sentinel values, so that the
behaviour tests (tests/python/test_sentinel_profile.py,
tests/r/test_profile_sentinels.R) can show that each profile value reaches
the outputs of the real code: a leftover OLD literal (307, 395, 387, 150,
300, 0.25, 0.5, 8, 18, 100, 313, the snake init and snake parameters)
would give other outputs or an error. Every value differs from both real
datasets (T2 review: the snake parameters and rel_x_cord / rel_Y_cord
used to be the real ones, so a hard-coded copy went unnoticed) and, where
the real datasets coincide, from each other:
  - 6 shoes of 40 x 60 px (W x H), fixed-stride records with CRLF;
  - data coords at 20 px per unit (rel_col_shoe 12, rel_row_shoe 24,
    rel_x_cord 0.3, rel_Y_cord 0.6); locations in the NEW raw format
    (space-separated, no header, leading space, coordinates x 2: divisor 2),
    each RAC at the centre of the coordinate bin that the legacy aspix
    formulas map to its pixel (rac_coords). A leftover 0.25, 0.5, 150 or
    300 in a mapping changes the pixel or the 1/20 grid of the controls,
    which the tests check;
  - a prototype of 44 x 66 px at 25 px per unit (rel_col_shoe 17.5,
    rel_row_shoe 35, rel_x_cord 0.35, rel_Y_cord 0.7), so the prototype
    frame differs from the data frame in size and in scale;
  - shoe 4 has no RACs (shoes_without_racs [4]), shoe 5 is excluded
    (excluded_shoes [5]): analysis shoes 1, 2, 3, 6, contour records 1-4;
  - Python flips shoe 2 (python.contact_flip_shoes), R flips shoe 3
    (r.contact_flip_shoes): different on purpose, so that each language
    is shown to read its own list;
  - superposition threshold 2, snake center (30, 20), radii (25, 15),
    50 points, Gaussian sigma 2.5, alpha 0.012, beta 12 (first snake) and
    0.12 (second), gamma 0.0015 (real: 3, 0.015, 10, 0.10, 0.001; chosen so
    that every snake still encloses its sole, and each value set alone to
    the real one changes every snake); R stamp threshold 2, sweep bound
    40, 5 controls, seed 7;
  - the T4 step-0 values of the NEW entry (T4 review; real NEW: closing
    radius 10, overrides of radius 24 or 16, 48 erase rectangles; OLD: none
    of them): first-snake closing radius 2 (snake.first_closing_radius), a
    per-shoe snake override for shoe 3 (inputs.snake_overrides: closing
    radius 5 and its own ellipse) and an erase list with one rectangle on
    shoe 6 (inputs.sticker_masks: the bottom rows of its heel, no RAC in
    it), each of which changes the step-0 outputs
    (tests/python/test_sentinel_profile.py).
Shoes 1, 2 and 3 carry a 4 x 4 "stamp" in the top-left corner (shoe 3's
moves to the top right when R flips it), which the R sweep removes.

Run from the repo root: python tests/fixtures/make_sentinel.py [OUT_DIR]
(default tests/fixtures/sentinel). Deterministic: no random numbers.
"""

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

W, H, N = 40, 60, 6                 # data frame of the fixture
PW, PH = 44, 66                     # prototype frame of the fixture
PROFILE = 'sentinel_profile.json'
# data coords (20 px per unit) and prototype coords (25 px per unit)
COORDS = {'divisor': 2, 'rel_col_shoe': 12, 'rel_row_shoe': 24,
          'rel_x_cord': 0.3, 'rel_Y_cord': 0.6}
PROTO_COORDS = {'rel_col_shoe': 17.5, 'rel_row_shoe': 35,
                'rel_x_cord': 0.35, 'rel_Y_cord': 0.7}
SNAKE = {'center_rc': [30, 20], 'radii_rc': [25, 15], 'n_points': 50,
         'gaussian_sigma': 2.5, 'alpha': 0.012, 'beta_first': 12,
         'beta_second': 0.12, 'gamma': 0.0015}
# per shoe: (row shift, col shift, row radius, col radius, has stamp)
SOLES = [(0, 0, 24, 12, True), (1, 0, 23, 12, True), (0, 1, 24, 11, True),
         (-1, 0, 24, 12, False), (0, -1, 23, 12, False),
         (1, 1, 24, 12, False)]
# RAC pixels (1-based R row, col) per shoe id; shoe 3 has two RACs in one
# pixel (the duplicate is counted once in dataCC, like OLD's 38 pixels);
# shoe 4 has none.
RACS = {1: [(22, 17), (30, 20), (35, 24), (39, 18)],
        2: [(25, 19), (31, 22), (37, 16)],
        3: [(23, 21), (28, 18), (28, 18), (33, 25), (40, 20)],
        5: [(24, 20), (32, 17), (38, 23)],
        6: [(21, 16), (29, 25), (34, 19), (36, 22)]}
ANALYSIS_SHOES = (1, 2, 3, 6)
# T4 step-0 values of the NEW entry (T4 review): the first-snake closing
# radius, one per-shoe override and one erase rectangle (1-based, inclusive)
CLOSING_RADIUS = 2
OVERRIDE = {'shoe': 3, 'first_closing_radius': 5, 'center_r': 31,
            'center_c': 21, 'radius_r': 24, 'radius_c': 14}
ERASE = {'shoe': 6, 'row0': 50, 'row1': 56, 'col0': 10, 'col1': 31}


def ellipse(h, w, cr, cc, rr, rc):
    r, c = np.mgrid[0:h, 0:w]
    return ((r - cr) / rr) ** 2 + ((c - cc) / rc) ** 2 <= 1.0


def inner_boundary4(mask):
    """Pixels of the mask with a 4-neighbour outside it."""
    m = np.pad(mask, 1)
    inner = (m[1:-1, 1:-1] & m[:-2, 1:-1] & m[2:, 1:-1] & m[1:-1, :-2]
             & m[1:-1, 2:])
    return mask & ~inner


def shoes():
    out = []
    for k, (dr, dc, rr, rc, stamp) in enumerate(SOLES):
        sole = ellipse(H, W, 29.5 + dr, 19.5 + dc, rr, rc)
        # a tread: every 6th diagonal is a groove
        r, c = np.mgrid[0:H, 0:W]
        sole &= (r + 2 * c + k) % 6 != 0
        if k == 1:  # shoe 2: a bump on its right side, so a flip shows
            sole |= ellipse(H, W, 45, 30, 3, 3)
        if stamp:
            sole[1:5, 1:5] = True
        out.append(sole)
    return np.array(out)


def rac_coords(row, col):
    """Raw (x divisor) coordinates whose R aspix pixel is (row, col),
    1-based: the centre of the pixel's bin, from the inverse of the legacy
    formulas with COORDS (x mirrored):
      aspix_x = W - (floor((x + rel_x_cord) / delx) + not_rel_col)."""
    c = COORDS
    delx = 2 * c['rel_x_cord'] / c['rel_col_shoe']
    dely = 2 * c['rel_Y_cord'] / c['rel_row_shoe']
    kx = W - math.ceil((W - c['rel_col_shoe']) / 2) - col
    ky = H - math.ceil((H - c['rel_row_shoe']) / 2) - row
    x = (kx + 0.5) * delx - c['rel_x_cord']
    y = (ky + 0.5) * dely - c['rel_Y_cord']
    return c['divisor'] * x, c['divisor'] * y


def profile_entry(dataset, suffix):
    new = dataset != 'old'

    def out(folder, stem, ext):
        if new:
            return f'{folder}/new/{stem}_new.{ext}'
        return f'{folder}/{stem}.{ext}'
    return {
        'dataset': dataset, 'suffix': suffix,
        'col_shoe': W, 'row_shoe': H, 'num_shoe': N,
        'shoes_without_racs': [4], 'excluded_shoes': [5],
        'coords': dict(COORDS),
        'inputs': {'contacts': 'data/contacts_sentinel.txt',
                   'locations': 'data/locations_sentinel.txt',
                   'locations_format': 'space_no_header',
                   'cross_check': None,
                   'sticker_masks': ('data/stickers_sentinel.csv' if new
                                     else None),
                   'snake_overrides': ('data/snake_overrides_sentinel.csv'
                                       if new else None)},
        'prototype': {'col_shoe': PW, 'row_shoe': PH,
                      'coords': dict(PROTO_COORDS),
                      'contour': 'data/prototype_contour_sentinel.png',
                      'mask': 'data/prototype_mask_sentinel.png'},
        'r': {'contact_flip_shoes': [3], 'stamp_threshold': 2,
              'stamp_sweep_bound': W, 'n_controls': 5, 'seed': 7,
              'mean_offset_fallback_pixels': None,
              'knit_dir': 'logs/knit/new' if new else 'statistical_model',
              'log_dir': 'logs/new' if new else 'logs/old',
              'paths': {
                  'dataCC': out('processed_data', 'dataCC', 'csv'),
                  'pixel_counts': out('processed_data', 'shoe_pixel_counts',
                                      'csv'),
                  'all_cont': out('processed_data', 'all_cont', 'csv'),
                  'shoe_codes': out('processed_data', 'shoe_codes', 'csv'),
                  'dataCC_distance_temp': out('processed_data',
                                              'dataCC_distance_temp', 'csv'),
                  'dataCC_distance': out('processed_data', 'dataCC_distance',
                                         'csv'),
                  'wald_test': out('processed_data', 'wald_test', 'csv'),
                  'models_dir': 'saved_models/new' if new else 'saved_models',
                  'images_dir': 'model_images/new' if new else 'model_images'},
              'eol': {k: '\n' for k in (
                  'dataCC', 'pixel_counts', 'all_cont', 'shoe_codes',
                  'dataCC_distance_temp', 'dataCC_distance', 'wald_test')}},
        'python': {'images_dir': 'images_new' if new else 'images',
                   'contact_flip_shoes': [2], 'superpose_threshold': 2,
                   'snake': dict(SNAKE, **({'first_closing_radius':
                                            CLOSING_RADIUS} if new else {})),
                   'write_html': False,
                   'contour_out': ('data/new_shoes/contour_sentinel_new.txt'
                                   if new else 'data/contour_sentinel.txt'),
                   'stems': {'superposed': 'superposed_min_{t}',
                             'prototype_mask': 'freq_min_{t}',
                             'locations_pixels': 'locations_pixels'}},
    }


def records(arrays):
    return b''.join((a.reshape(-1).astype(np.uint8) + 48).tobytes()
                    + b'\r\n' for a in arrays)


def main(out):
    out = Path(out)
    data = out / 'data'
    data.mkdir(parents=True, exist_ok=True)
    s = shoes()
    (data / 'contacts_sentinel.txt').write_bytes(records(s))
    lines = []
    for shoe, pix in RACS.items():
        for k, (row, col) in enumerate(pix, start=1):
            x, y = rac_coords(row, col)
            lines.append(f' {shoe} {k} {x:.6f} {y:.6f} {1 + k % 3} ')
    (data / 'locations_sentinel.txt').write_bytes(
        ('\r\n'.join(lines) + '\r\n').encode())
    # the contour file of R step 2: the inner boundary of each analysis
    # shoe's sole (the real one comes from the snake); and one record short
    bounds = [inner_boundary4(ellipse(H, W, 29.5 + SOLES[i - 1][0],
                                      19.5 + SOLES[i - 1][1],
                                      SOLES[i - 1][2], SOLES[i - 1][3]))
              for i in ANALYSIS_SHOES]
    (data / 'contour_sentinel_r.txt').write_bytes(records(bounds))
    (data / 'contour_sentinel_short.txt').write_bytes(records(bounds[:-1]))
    # the T4 inputs of the NEW entry: one erase rectangle, one override
    (data / 'stickers_sentinel.csv').write_text(
        'shoe,row0,row1,col0,col1,reason\n'
        + ','.join(str(ERASE[k])
                   for k in ('shoe', 'row0', 'row1', 'col0', 'col1'))
        + ',sentinel rectangle over the bottom of the heel\n')
    (data / 'snake_overrides_sentinel.csv').write_text(
        'shoe,first_closing_radius,center_r,center_c,radius_r,radius_c,'
        'reason\n'
        + ','.join(str(OVERRIDE[k]) for k in (
            'shoe', 'first_closing_radius', 'center_r', 'center_c',
            'radius_r', 'radius_c'))
        + ',sentinel override\n')
    proto = ellipse(PH, PW, 32.5, 21.5, 26, 13)
    Image.fromarray(inner_boundary4(proto)).save(
        data / 'prototype_contour_sentinel.png')
    Image.fromarray(proto).save(data / 'prototype_mask_sentinel.png')
    cfg = {'_comment': ['Sentinel profile of tests/fixtures/make_sentinel.py'
                        ' (A-035, A-050); test use only (RAC_PROFILE_FILE).'],
           'version': 1,
           'datasets': {'old': profile_entry('old', ''),
                        'new': profile_entry('new', '_new')}}
    (out / PROFILE).write_text(json.dumps(cfg, indent=2) + '\n')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1
         else Path(__file__).resolve().parent / 'sentinel')
