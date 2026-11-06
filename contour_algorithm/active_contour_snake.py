"""Step 0c: the two-pass snake of every shoe and of the prototype.

Ported from the thesis code (109f30a) with every dataset value from the
profile: the initial ellipse (`python.snake.center_rc`, `radii_rc`,
`n_points`), the snake parameters, the frame (W, H) and every path. The
contour file is written by `io_shoes.write_shoes` (binary CRLF) without
the shoes that have no contour record (computed from the locations,
`locations.record_skip_idx0`), never at a fixed path.
"""

import io

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


def init_snake(profile):
    """The initial ellipse, (n_points, 2) as (row, col)."""
    sp = profile.snake
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


def active_contour_shoe(profile, list_contour, plot_img, save_img_bool,
                        im_num):
    """The contour (bool (H, W)) of shoe image im_num: a first snake on the
    blurred cleaned shoe, a second one on the first snake combined with
    the parts of the shoe outside it."""
    sp = profile.snake
    original_img = get_image(profile, True, im_num, list_contour)
    # First active-contour: beta = beta_first
    init = init_snake(profile)
    first_snake = active_contour(
        gaussian(original_img, sp.gaussian_sigma, preserve_range=False),
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
    return comb_arr


def active_contour_on_prototype(profile):
    """The prototype cleaning mask: the two-pass snake on the superposition
    (>= python.superpose_threshold shoes), filled."""
    sp = profile.snake
    original_img = img_as_ubyte(Image.open(
        profile.saved_path(profile.stem('superposed'), 'png')))
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
    final_img = Image.fromarray(final_arr)
    stem = profile.stem('prototype_mask')
    final_img.save(profile.saved_path(stem, 'png'))
    np.save(profile.saved_path(stem, 'npy'), final_arr)
    return


def main(profile):
    print(f'{profile.dataset}\nactive_contour_snake')
    list_contour = np.load(profile.saved_path('list_contour', 'npy'))
    if len(list_contour) != profile.num_shoe:
        raise ValueError(f'list_contour has {len(list_contour)} shoes, the '
                         f'profile {profile.num_shoe}')
    # checked before the snakes run, so a wrong skip list fails at once
    skip = record_skip_idx0(profile)
    snake_all = []
    for i in tqdm(range(len(list_contour))):
        snake_arr = active_contour_shoe(profile, list_contour, plot_img=False,
                                        save_img_bool=True, im_num=i)
        snake_all.append(snake_arr)
    np.save(profile.saved_path('active-contour_all', 'npy'), snake_all)

    # The contour file: one record per analysis shoe (plan section 4.3),
    # '0'/'1' row by row, CRLF after every record.
    n = write_shoes(profile.contour_out, snake_all, skip_idx0=skip)
    if n != len(profile.analysis_shoes()):
        raise ValueError(f'{n} contour records written, '
                         f'{len(profile.analysis_shoes())} analysis shoes')
    skipped = [i + 1 for i in skip]
    print(f'Active contour processing complete - {len(snake_all)} shoes, '
          f'{n} contour records (shoes without a record: {skipped})')
