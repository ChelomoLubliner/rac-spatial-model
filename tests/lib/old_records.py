"""The OLD dataset's fixed-stride record files and contour-record mapping.

One place for the OLD-only test and diagnostic helpers in tests/ (T1
review 2, nit 1: the frame, the record reader and the shoe/record mapping
had been copied into seven scripts). The pipeline's own reader comes with
the dataset profile in T2 (`io_shoes.read_shoes`); this module reads the
committed OLD files and the outputs of legacy reruns.

OLD frame: 307 columns x 395 rows. `data/contacts_data.txt` holds 387
records, one per shoe (shoes 1-387, image index idx0 = shoe - 1);
`data/contour_Active_Contour.txt` holds 386: shoe 127 (idx0 126) has no
RACs and no contour record. So contour record k (0-based) belongs to shoe
k + 1 for k < 126 and to shoe k + 2 from k = 126 on. Each record is
W * H bytes '0'/'1' followed by a separator: CRLF in the committed files,
LF in files that the legacy Python code wrote on Linux.
"""

from pathlib import Path

import numpy as np

W, H = 307, 395            # OLD frame: columns, rows
N_SHOES = 387              # records in contacts_data.txt
NO_RECORD_SHOE = 127       # 1-based shoe without RACs and contour record
SKIPPED_IDX0 = NO_RECORD_SHOE - 1   # its 0-based image index (126)
N_CONTOUR_RECORDS = N_SHOES - 1     # records in contour_Active_Contour.txt


def parse_records(data, width=W, height=H):
    """Records of fixed-stride 0/1 bytes with LF or CRLF separators.

    Returns (records as bool array (n, height, width), separator bytes).
    Raises ValueError unless the data are a whole number of records with
    one consistent separator, and every record byte is '0' or '1'.
    """
    size = width * height
    for sep in (b'\r\n', b'\n'):
        stride = size + len(sep)
        if not data or len(data) % stride:
            continue
        arr = np.frombuffer(data, dtype=np.uint8).reshape(-1, stride)
        if not np.all(arr[:, size:] == np.frombuffer(sep, dtype=np.uint8)):
            continue
        body = arr[:, :size]
        if not np.all((body == 48) | (body == 49)):
            raise ValueError('bytes other than 0/1 in the records')
        return (body == 49).reshape(-1, height, width), sep
    raise ValueError('not a fixed-stride 0/1 file with LF or CRLF separators')


def read_records(path, width=W, height=H, sep=None):
    """Bool records (n, height, width) of the file at path.

    If sep is given (b'\\r\\n' for the committed files), the file must use
    that separator; otherwise LF and CRLF are both accepted.
    """
    records, found = parse_records(Path(path).read_bytes(), width, height)
    if sep is not None and found != sep:
        raise ValueError(f'{path}: separator {found!r}, expected {sep!r}')
    return records


def record_of_idx0(idx0):
    """0-based contour record of the shoe with 0-based image index idx0."""
    if not 0 <= idx0 < N_SHOES:
        raise ValueError(f'image index {idx0} is not an OLD shoe')
    if idx0 == SKIPPED_IDX0:
        raise ValueError(f'shoe {NO_RECORD_SHOE} has no contour record')
    return idx0 if idx0 < SKIPPED_IDX0 else idx0 - 1


def record_of_shoe(shoe):
    """0-based contour record of a 1-based shoe id."""
    return record_of_idx0(shoe - 1)


def shoe_of_record(k):
    """1-based shoe id of the 0-based contour record k."""
    if not 0 <= k < N_CONTOUR_RECORDS:
        raise ValueError(f'record {k} is not an OLD contour record')
    return k + 1 if k < SKIPPED_IDX0 else k + 2
