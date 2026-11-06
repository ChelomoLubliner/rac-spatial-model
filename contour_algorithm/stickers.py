"""Erase list of stickers and frame artefacts (plan T3 step 3, T4 3b;
decision A-095).

Marks on a print that are not sole (police stickers or labels, the edges
of the lifting medium or the scanner plate) are removed by the prototype
mask when they lie outside it (the legacy AND-cleaning). Where such a mark
overlaps the mask it survives the cleaning and pulls the snake. The
profile's ``inputs.sticker_masks`` (NEW: data/new_shoes/
sticker_masks_new.csv; OLD: none) lists rectangles to erase from the raw
contact record, applied when the contacts are read, before anything else
(the superposition, the masks, the snake), by Python (create_files_shoes)
and by R (dataCC_1.Rmd), so both halves see the same contact surface.

File format (CSV, LF, header): shoe,row0,row1,col0,col1,reason. shoe is
the 1-based shoe id; row0..row1 and col0..col1 are 1-based inclusive pixel
ranges of the stored record (row 1 = the first line of the record, col 1
its first character; the frame of R's data[[shoe]][row, col] and of the
legacy COL/ROW), applied before any left-right flip; reason is free text
and must not be empty. A shoe may have several rows.
"""

import numpy as np
import pandas as pd

COLUMNS = ('shoe', 'row0', 'row1', 'col0', 'col1', 'reason')


def read_sticker_masks(profile):
    """The profile's erase list as a DataFrame with COLUMNS (empty when
    the profile has none); raises ValueError on a malformed file."""
    if profile.sticker_masks is None:
        return pd.DataFrame({c: pd.Series(dtype='int64' if c != 'reason'
                                          else 'object') for c in COLUMNS})
    table = pd.read_csv(profile.sticker_masks, dtype={'reason': str},
                        keep_default_na=False)
    where = profile.sticker_masks
    if tuple(table.columns) != COLUMNS:
        raise ValueError(f'{where}: columns must be {",".join(COLUMNS)}')
    for c in COLUMNS[:-1]:
        if not pd.api.types.is_integer_dtype(table[c]):
            raise ValueError(f'{where}: column {c} must hold integers')
    bad = table[~table['shoe'].between(1, profile.num_shoe)
                | (table['row0'] < 1) | (table['row1'] > profile.H)
                | (table['row0'] > table['row1'])
                | (table['col0'] < 1) | (table['col1'] > profile.W)
                | (table['col0'] > table['col1'])
                | (table['reason'].str.strip() == '')]
    if len(bad):
        raise ValueError(f'{where}: invalid rows (1-based shoe and ranges '
                         f'inside {profile.H} x {profile.W}, a reason): '
                         f'{bad.index.tolist()}')
    return table


def apply_sticker_masks(shoes, table):
    """(copy of shoes with the listed rectangles set False, the number of
    contact pixels each row of the table erased). shoes: bool (n, H, W),
    indexed by shoe - 1."""
    out = np.array(shoes, dtype=bool, copy=True)
    erased = []
    for r in table.itertuples(index=False):
        block = out[r.shoe - 1, r.row0 - 1:r.row1, r.col0 - 1:r.col1]
        erased.append(int(block.sum()))
        block[...] = False
    return out, erased
