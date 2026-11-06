"""Step 0a: shoe images, the superposition and the prototype cleaning mask.

Ported from the thesis code (109f30a) with the dataset values taken from
the profile (plan T2d). For OLD the outputs are the legacy ones byte for
byte (tests/regress_old.sh; Tier B of T1).
"""

import numpy as np
from PIL import Image
from tqdm import tqdm

from .active_contour_snake import active_contour_on_prototype
from .io_shoes import read_shoes


def contacts_data(profile):
    """Read the contact file, save one image per shoe and list_matrices.

    `python.contact_flip_shoes` (1-based) are mirrored left to right, as
    the legacy flip of image 8 intended; for OLD the list is empty: the
    legacy flip was dead code, so the committed contour has shoe 9
    unflipped (known issue K1, decision A-015).
    """
    shoes = read_shoes(profile.contacts, profile.W, profile.H,
                       profile.num_shoe)
    print('Total lines:', len(shoes))
    for i in tqdm(range(len(shoes))):
        Image.fromarray(shoes[i]).save(profile.image_path('shoes', i))
    for shoe in profile.contact_flip_shoes:
        i = shoe - 1
        shoes[i] = np.fliplr(shoes[i]).copy()
        Image.fromarray(shoes[i]).save(profile.image_path('shoes', i))
    np.save(profile.saved_path('list_matrices', 'npy'), shoes)


def superposition_all_shoes(profile, list_lines):
    print('superposition_all_shoes')
    total = list_lines.sum(axis=0)
    Image.fromarray(total.astype(bool)).save(
        profile.saved_path('all_shoes_superposed', 'png'))


def superposed_pixels(profile, list_lines):
    """Pixels in contact on at least `python.superpose_threshold` shoes.

    The legacy loop lowered a threshold from the maximum count and saved
    the mask when it reached 18; the mask is `total >= t` (same bool array;
    the legacy loop silently saved nothing when t exceeded the maximum).
    """
    print('Superposed_pixels')
    t = profile.superpose_threshold
    total = list_lines.sum(axis=0)
    if not 1 <= t <= total.max():
        raise ValueError(f'superpose_threshold {t} outside 1..{total.max()}')
    line = total >= t
    stem = profile.stem('superposed')
    np.save(profile.saved_path(stem, 'npy'), line)
    Image.fromarray(line).save(profile.saved_path(stem, 'png'))


def main(profile):
    print(f'{profile.dataset}\nmain_create_files_init')
    contacts_data(profile)
    list_lines = np.load(profile.saved_path('list_matrices', 'npy'))
    len_lines = len(list_lines)
    print(f'Array of {len_lines} lines')
    superposition_all_shoes(profile, list_lines)
    superposed_pixels(profile, list_lines)
    active_contour_on_prototype(profile)
