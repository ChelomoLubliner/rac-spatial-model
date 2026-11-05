"""Utilities to compute and visualize contours."""

import numpy as np
import plotly.graph_objs as go
import plotly.offline as pyo
from tqdm import tqdm

from extreme_values_x_y import get_contour
from globals import FOLDER, H, W
from remove_noise import save_cleaned_shoes, superpose_image_prototype


def scatter_plot_contour(coordinates, im_num):
    """Plot contour points as a scatter plot."""
    x = np.array([coord[0] for coord in coordinates])
    y = np.array([coord[1] for coord in coordinates])
    trace = go.Scatter(x=x, y=y, mode='markers')
    layout = go.Layout(title=f'Scatter plot of contour image {im_num}')
    fig = go.Figure(data=[trace], layout=layout)
    pyo.plot(fig, filename=f'{FOLDER}extreme_values/plot_cont_{im_num}.html', auto_open=False)


def save_new_contour_shoe(new_points, im_num):
    """Return a boolean mask representing the contour."""
    new_arr = np.zeros((H, W), dtype=bool)
    new_arr[tuple(zip(*new_points))] = True
    return new_arr


def remove_noise_get_contour(list_matrices, im_num):
    """Complete flow to generate a contour for a shoe image."""
    superpose_image_prototype(im_num)
    new_im = save_cleaned_shoes(list_matrices, im_num)
    new_points = get_contour(new_im)
    scatter_plot_contour(new_points, im_num)
    return save_new_contour_shoe(new_points, im_num)


def main():
    print(f"{FOLDER.split('/')[1]}\nmain_remove_noise_get_extreme_values")
    list_lines = np.load(f'{FOLDER}saved/list_matrices.npy')
    list_contour = []
    for i in tqdm(range(len(list_lines))):
        contour_item = remove_noise_get_contour(list_lines, i)
        list_contour.append(np.matrix(contour_item))
        np.save(f'{FOLDER}saved/list_contour.npy', list_contour)


if __name__ == '__main__':
    main()
