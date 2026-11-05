OLD_DATASET = True



if OLD_DATASET:
    DATASET = 'contacts_data.txt'
    FOLDER = '../images/'
    LOCATIONS = 'locations_data.csv'
    W, H = 307, 395  # COL, ROW
else:
    DATASET = 'contacts_data_naomi_fast.txt'
    FOLDER = '../images/'
    LOCATIONS = 'results_data_naomi_fast.txt'
    W, H = 255, 367





