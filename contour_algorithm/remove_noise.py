import numpy as np
from PIL import Image
import cv2
from globals import FOLDER

my_dict = {1: True, 0: False}



# superpose the prototype shoe on every shoe to see which pixels would be deleted
def superpose_image_prototype(im_num):
    shoes = cv2.imread(f'{FOLDER}shoes/im{im_num}.png')
    contour = cv2.imread(f'{FOLDER}saved/freq_min_18.png')
    #dst = cv2.addWeighted(contour, 0.25, shoes, 0.75, 0)
    dst = cv2.addWeighted(contour, 0.25, shoes, 0.75, 0)
    new_image = Image.fromarray(cv2.cvtColor(dst, cv2.COLOR_BGR2RGB))
    new_image.save(FOLDER + f'shoe_on_prototype/im_{im_num}.png')


# the prototype shoe, freq_min_18 will be a limit for every shoe.
# Delete every pixel that isn't in the prototype shoe (bitwise_and)
def save_cleaned_shoes(list_matrices, im_num):
    contour = np.load(f'{FOLDER}saved/freq_min_18.npy')
    combined_arr = np.bitwise_and(list_matrices[im_num], contour)
    combined_image = Image.fromarray(combined_arr)
    combined_image.save(f'{FOLDER}cleaned_shoes/im_{im_num}.png')
    return combined_arr
