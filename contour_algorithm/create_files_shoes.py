import matplotlib.pyplot as plt
import numpy as np
from PIL import Image
from tqdm import tqdm

from active_contour_snake import active_contour_on_prototype
from globals import DATASET, FOLDER, H, W

MY_DICT = {1: True, 0: False}


def contacts_data():
    """Open dataset file, save list_lines, and images."""
    list_lines = []
    with open(f'../data/{DATASET}', 'r') as f:
        lines = f.readlines()
        print('Total lines:', len(lines))
        for i in tqdm(range(len(lines))):
            line = list(lines[i])
            line = np.array(list(map(int, line[:-1]))).reshape(H, W)
            line = np.vectorize(MY_DICT.get)(line)
            list_lines.append(np.matrix(line))
            img = Image.fromarray(line)
            img.save(f'{FOLDER}shoes/im{i}.png')
        # flip the image8 because it's left shoes
        if FOLDER == 'Images/Old_Shoes/':
            list_lines[8] = np.fliplr(list_lines[8])
            line = np.vectorize(MY_DICT.get)(list_lines[8])
            im8 = Image.fromarray(line)
            im8.save(f'{FOLDER}shoes/im8.png')
        # save list_lines
        np.save(f'{FOLDER}saved/list_matrices.npy', list_lines)


def superposition_all_shoes(list_lines):
    print('superposition_all_shoes')
    total = list_lines.sum(axis=0)
    Image.fromarray(total.astype(bool)).save(FOLDER + 'saved/all_shoes_superposed.png')


def superposed_pixels(list_lines):
    print('Superposed_pixels')
    # Dict to convert 0->False and non 0->True
    new_dict = {0: False}
    # max_pixel occurrence
    # total = superposed pixels
    total = list_lines.sum(axis=0)
    max_pixel = total.max()
    for max_pix in tqdm(range(max_pixel, 0, -1)):  # -1 -1
        new_dict[max_pix] = True
        line = np.vectorize(new_dict.get)(total)
        if max_pix == 18:
            np.save(f'{FOLDER}saved/old_freq_min_18.npy', line)
            Image.fromarray(line).save(FOLDER + 'saved/old_freq_min_18.png')
            break
        # if (max_pix % 10 == 0) | (max_pix < 25):
        #     img = Image.fromarray(line)
        #     img.save(f'{FOLDER}Superposed_Pixels/freq_min_{max_pix}.png')


def superposed_pixels_reversed(list_lines):
    # Dict to convert 0->False and non 0->True
    print('Superposed_pixels_reversed')
    new_dict = {0: False}
    total = list_lines.sum(axis=0)
    max_pixel = total.max()
    for max_pix in tqdm(range(1, max_pixel)):  # -1 -1
        new_dict[max_pix] = True
        line = np.vectorize(new_dict.get)(total)
        if (max_pix % 10 == 0) or (max_pix < 25):
            img = Image.fromarray(line)
            img.save(f'{FOLDER}Superposed_Pixels_Reversed/freq_max_{max_pix}.png')


def heatmap_superposed(list_lines):
    print('Heatmap_superposed')
    plt.imshow(list_lines.sum(axis=0), cmap='jet', interpolation='sinc')
    plt.savefig(FOLDER + 'saved/heatmap_superposed.png')





def main():
    print(f"{FOLDER.split('/')[1]}\nmain_create_files_init")
    contacts_data()
    list_lines = np.load(f'{FOLDER}saved/list_matrices.npy')
    len_lines = len(list_lines)
    print(f'Array of {len_lines} lines')
    superposition_all_shoes(list_lines)
    superposed_pixels(list_lines)
    # superposed_pixels_reversed(list_lines)
    # heatmap_superposed(list_lines)
    active_contour_on_prototype()


if __name__ == '__main__':
    main()

