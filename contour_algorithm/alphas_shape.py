import io

import alphashape
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import MultiPolygon, Polygon
from skimage import img_as_ubyte, measure
from tqdm import tqdm

from globals import FOLDER, H, W


def get_image(entire_shoe, im_num, contour_source):
    """Return either the cleaned shoe image or a contour mask."""
    if entire_shoe:
        return img_as_ubyte(Image.open(f'{FOLDER}cleaned_shoes/im_{im_num}.png'))
    return img_as_ubyte(Image.fromarray(contour_source[im_num]))


def save_img(original_img, result_arr, alpha, im_num):
    """Overlay the alpha-shape result on the original image and save."""
    fig, ax = plt.subplots(figsize=(7, 7))
    ax.imshow(original_img, cmap=plt.cm.gray)

    if result_arr is not None:
        temp_contours = measure.find_contours(result_arr, level=0.5)
        for contour in temp_contours:
            ax.plot(contour[:, 1], contour[:, 0], color='blue', lw=3)
    ax.set_xticks([])
    ax.set_yticks([])
    ax.axis([0, original_img.shape[1], original_img.shape[0], 0])

    buf = io.BytesIO()
    fig.savefig(buf, format='png')
    buf.seek(0)
    plt.close('all')
    Image.open(buf).save(f'{FOLDER}Alpha_Shape/im_{im_num}_al_{alpha}.png')


def alpha_func(points, alpha):
    """Return the alpha shape mask for the provided points."""
    shape = alphashape.alphashape(points, alpha)
    image = Image.new('1', (W, H), color=0)
    draw = ImageDraw.Draw(image)

    if isinstance(shape, Polygon):
        draw_polygon(shape, draw)
    elif isinstance(shape, MultiPolygon):
        for poly in shape.geoms:
            draw_polygon(poly, draw)

    new_points = np.argwhere(np.array(image, dtype=bool))
    return new_points, image


def get_alpha_shape_mask(contour_source, im_num, alpha):
    """Compute the alpha shape for a shoe image and save visualisations."""
    original_img = get_image(True, im_num, contour_source)
    original_points = np.argwhere(original_img > 0)
    #final_arr = np.zeros((H, W), dtype=bool)
    first_tep_arr = np.zeros((H, W), dtype=bool)
    first_step_points, new_image = alpha_func(original_points, alpha)
    first_tep_arr[tuple(zip(*list(first_step_points)))] = True
    save_img(original_img, first_tep_arr, alpha, im_num)
    # for sec_alpha in [0.01]:
    #     final_points, final_image = alpha_func(first_step_points, alpha=sec_alpha)
    #     final_arr[tuple(zip(*list(final_points)))] = True

        #save_img(original_img, first_tep_arr, None, alpha, '', im_num)
    return #(np.array(final_image, dtype=bool) == True)

def draw_polygon(polygon, draw):
    """Draw a polygon onto the provided PIL draw context."""
    coords = [(int(y), int(x)) for x, y in polygon.exterior.coords]
    draw.line(coords + [coords[0]], fill=1, width=1)

# def get_alpha_shape_html(points, im_num, alpha=5.0):
#     shape = alphashape.alphashape(points, alpha)
#     scatter_trace = go.Scatter(x=points[:, 0], y=points[:, 1], mode='markers')
#     line_traces = []
#
#     def shape_to_traces(geom):
#         coords = np.array(geom.exterior.coords)
#         return go.Scatter(x=coords[:, 0], y=coords[:, 1], mode='lines')
#
#     if isinstance(shape, Polygon):
#         line_traces.append(shape_to_traces(shape))
#     elif isinstance(shape, MultiPolygon):
#         for poly in shape.geoms:
#             line_traces.append(shape_to_traces(poly))
#
#     fig = go.Figure(data=[scatter_trace] + line_traces)
#     pyo.plot(fig, filename=f'{FOLDER}Alpha_Shape_html/plot_cont_{im_num}.html', auto_open=False)

def main():
    print(f"{FOLDER.split('/')[1]}\nmain_Alpha_Shape")
    list_contour = np.load(f'{FOLDER}saved/list_contour.npy')
    alpha_all = []
    for i in tqdm(range(len(list_contour))):
        alpha_arr = get_alpha_shape_mask(list_contour, i, 0.02)
        alpha_all.append(np.matrix(alpha_arr))
    print(len(alpha_all))
    np.save(f'{FOLDER}saved/alpha_all.npy', alpha_all)


if __name__ == '__main__':
    main()
