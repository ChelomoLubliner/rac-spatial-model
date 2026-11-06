"""Step 0b helpers: clean each shoe with the prototype mask."""

import cv2
import numpy as np
from PIL import Image


def _imread(path):
    img = cv2.imread(str(path))
    if img is None:
        raise FileNotFoundError(f'cannot read image {path}')
    return img


def superpose_image_prototype(profile, im_num):
    """Draw the prototype mask over the shoe (to see which pixels the
    cleaning removes): shoe_on_prototype/im_<i>."""
    shoes = _imread(profile.image_path('shoes', im_num))
    contour = _imread(profile.saved_path(profile.stem('prototype_mask'),
                                         'png'))
    dst = cv2.addWeighted(contour, 0.25, shoes, 0.75, 0)
    new_image = Image.fromarray(cv2.cvtColor(dst, cv2.COLOR_BGR2RGB))
    new_image.save(profile.image_path('shoe_on_prototype', im_num))


def save_cleaned_shoes(profile, list_matrices, im_num):
    """The prototype mask limits every shoe: delete every pixel outside it
    (bitwise_and); saves cleaned_shoes/im_<i> and returns the array."""
    contour = np.load(profile.saved_path(profile.stem('prototype_mask'),
                                         'npy'))
    combined_arr = np.bitwise_and(list_matrices[im_num], contour)
    combined_image = Image.fromarray(combined_arr)
    combined_image.save(profile.image_path('cleaned_shoes', im_num))
    return combined_arr
