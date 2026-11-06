"""Step 0d: pixel position (COL, ROW) of every RAC; plotly views (--html).

aspix_x / aspix_y convert a coordinate to a 1-based pixel exactly as the R
functions of dataCC_1.Rmd do (x mirrored). Parameters (`coords`):
rel_col_shoe and rel_row_shoe are the relevant columns and rows (OLD: out
of 307 columns only 150 contain contact in some shoe, out of 395 rows
300), rel_x_cord and rel_Y_cord the coordinate ranges (x in -0.25..0.25,
y in -0.5..0.5 in the OLD locations file), so 1 px = 1/300 unit.
"""

import math

import numpy as np
import pandas as pd
from tqdm import tqdm

from .locations import read_locations


def aspix_x(profile, x):
    c = profile.coords
    not_rel_col = math.ceil((profile.W - c.rel_col_shoe) / 2)
    delx = (2 * c.rel_x_cord) / c.rel_col_shoe
    temp = ((x + c.rel_x_cord) / delx).apply(
        lambda x: math.floor(x)) + not_rel_col
    pix_x = profile.W - temp
    return pix_x


def aspix_y(profile, y):
    c = profile.coords
    not_rel_row = math.ceil((profile.H - c.rel_row_shoe) / 2)
    dely = (2 * c.rel_Y_cord) / c.rel_row_shoe
    temp = ((y + c.rel_Y_cord) / dely).apply(
        lambda x: math.floor(x)) + not_rel_row
    pix_y = profile.H - temp
    return pix_y


def init_locations_new(profile):
    """Write the RAC table with 0-based shoe ids and COL, ROW to
    saved/<locations_pixels stem>.csv (OLD: the legacy locations_new.csv).
    """
    locations = read_locations(profile)
    locations['shoe'] = locations['shoe'] - 1
    new_cols = {'COL': aspix_x(profile, locations['x']),
                'ROW': aspix_y(profile, locations['y']),
                'INSIDE_SNAKE': np.nan,
                'HORIZ_DIST_SNAKE': np.nan,
                'DIST_SNAKE': np.nan}
    locations = pd.concat([locations, pd.DataFrame(new_cols)], axis=1)
    locations.to_csv(profile.saved_path(profile.stem('locations_pixels'),
                                        'csv'), index=False)


def save_html(profile, total_df, shoe_num, algo):
    """Plot the RACs and the snake of one shoe (plotly HTML, --html)."""
    import plotly.graph_objs as go
    import plotly.offline as pyo
    scatter = go.Scatter(x=total_df['ROW'].to_list(),
                         y=total_df['COL'].to_list(), mode='markers')
    fig = go.Figure(data=scatter)
    pyo.plot(fig, filename=str(profile.image_path('snake_rac_html', shoe_num,
                                                  'html')),
             auto_open=False)


def dist_per_shoe(profile, shoe_arr, shoe_num, algo):
    locations_all = pd.read_csv(
        profile.saved_path(profile.stem('locations_pixels'), 'csv'))
    locations = locations_all[locations_all['shoe'] == shoe_num]
    locations_coord = list(zip(locations['ROW'].to_list(),
                               locations['COL'].to_list()))
    shoe_coord = list(np.argwhere(shoe_arr[shoe_num] == True))  # noqa: E712
    total_df = pd.DataFrame(locations_coord + shoe_coord,
                            columns=['ROW', 'COL'])
    save_html(profile, total_df, shoe_num, algo)


def main(profile, html=False):
    print(f'{profile.dataset}\ndistance_extremities_main')
    init_locations_new(profile)
    if not html:  # the per-shoe loop only writes the plotly views (A-017)
        return
    list_snake = list(np.load(profile.saved_path('active-contour_all',
                                                 'npy')))
    skip = set(profile.skip_idx0())
    for i in tqdm(range(len(list_snake))):
        if i in skip:  # no RACs (OLD shoe 127) or excluded
            continue
        dist_per_shoe(profile, list_snake, i, 'SNAKE')
