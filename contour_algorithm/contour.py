"""Step 0b: clean every shoe and take its extreme-value contour."""

import numpy as np
from tqdm import tqdm

from .extreme_values_x_y import get_contour
from .remove_noise import save_cleaned_shoes, superpose_image_prototype


def scatter_plot_contour(profile, coordinates, im_num):
    """Plot contour points as a scatter plot (plotly HTML, only with
    --html: A-017)."""
    import plotly.graph_objs as go
    import plotly.offline as pyo
    x = np.array([coord[0] for coord in coordinates])
    y = np.array([coord[1] for coord in coordinates])
    trace = go.Scatter(x=x, y=y, mode='markers')
    layout = go.Layout(title=f'Scatter plot of contour image {im_num}')
    fig = go.Figure(data=[trace], layout=layout)
    pyo.plot(fig,
             filename=str(profile.image_path('extreme_values', im_num,
                                             'html')),
             auto_open=False)


def save_new_contour_shoe(profile, new_points, im_num):
    """Return a boolean mask representing the contour."""
    new_arr = np.zeros((profile.H, profile.W), dtype=bool)
    new_arr[tuple(zip(*new_points))] = True
    return new_arr


def remove_noise_get_contour(profile, list_matrices, im_num, html=False):
    """Complete flow to generate a contour for a shoe image."""
    superpose_image_prototype(profile, im_num)
    new_im = save_cleaned_shoes(profile, list_matrices, im_num)
    new_points = get_contour(new_im)
    if html:
        scatter_plot_contour(profile, new_points, im_num)
    return save_new_contour_shoe(profile, new_points, im_num)


def main(profile, html=False):
    print(f'{profile.dataset}\nmain_remove_noise_get_extreme_values')
    list_lines = np.load(profile.saved_path('list_matrices', 'npy'))
    list_contour = []
    for i in tqdm(range(len(list_lines))):
        contour_item = remove_noise_get_contour(profile, list_lines, i, html)
        list_contour.append(np.matrix(contour_item))
    # the legacy code saved after every shoe; the last save is this one
    np.save(profile.saved_path('list_contour', 'npy'), list_contour)
