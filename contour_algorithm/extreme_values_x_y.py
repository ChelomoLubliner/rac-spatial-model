import numpy as np


def dict_points(all_points, x_true):
    """Group points by x or y coordinate."""
    points_dict = {}
    for x_i, y_i in all_points:
        if x_true:
            if x_i not in points_dict:
                points_dict[x_i] = [y_i]
            else:
                points_dict[x_i].append(y_i)
        else :
            if y_i not in points_dict:
                points_dict[y_i] = [x_i]
            else:
                points_dict[y_i].append(x_i)
    return points_dict


def select_min_max_x(all_points):
    """Select the top and bottom pixel for each x coordinate."""
    points_dict = dict_points(all_points, x_true=True)
    new_points_x = []
    for x_i, y_values in points_dict.items():
        for new_y_i in (min(y_values), max(y_values)):
            new_points_x.append((x_i, new_y_i))
    return new_points_x


def select_min_max_y(all_points):
    """Select the leftmost and rightmost pixel for each y coordinate."""
    points_dict = dict_points(all_points, x_true=False)
    new_points_y = []
    for y_i, x_values in points_dict.items():
        for new_x_i in (min(x_values), max(x_values)):
            new_points_y.append((new_x_i, y_i))
    return new_points_y


def get_contour(im_array):
    """Return contour points by combining min/max selections on each axis."""
    all_points = np.argwhere(im_array)
    new_points_x = select_min_max_x(all_points)
    new_points_y = select_min_max_y(all_points)
    final_points = list(set().union(new_points_x, new_points_y))
    return final_points
