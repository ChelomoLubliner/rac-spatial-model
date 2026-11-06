"""Fixed-stride shoe files: the contact file and the contour file.

One record per shoe: W x H characters '0'/'1' (row-major, H rows of W
columns), followed by the separator b'\\r\\n'. The R readers step through
the file with a stride of W * H + 2 (readChar), so a single LF would shift
every later record by one byte without an error (plan section 7, review
focus 2). The legacy writer used text mode and wrote LF on Linux (CRLF
only on Windows); `write_shoes` writes binary CRLF on every platform.
"""

from pathlib import Path

import numpy as np

SEPARATOR = b'\r\n'


def read_shoes(path, width, height, n):
    """Bool array (n, height, width) of the n records in `path`.

    Raises ValueError unless the file holds exactly n records of
    width * height bytes '0'/'1', each followed by b'\\r\\n'.
    """
    path = Path(path)
    data = path.read_bytes()
    size = width * height
    stride = size + len(SEPARATOR)
    if len(data) != n * stride:
        raise ValueError(f'{path}: {len(data)} bytes, not {n} records of '
                         f'{size} + {len(SEPARATOR)} bytes')
    arr = np.frombuffer(data, dtype=np.uint8).reshape(n, stride)
    sep = np.frombuffer(SEPARATOR, dtype=np.uint8)
    bad = np.flatnonzero(~np.all(arr[:, size:] == sep, axis=1))
    if bad.size:
        raise ValueError(f'{path}: the separator of record {bad[0]} '
                         f'(0-based) is not CRLF')
    body = arr[:, :size]
    if not np.all((body == 48) | (body == 49)):
        raise ValueError(f'{path}: bytes other than 0/1 in the records')
    return (body == 49).reshape(n, height, width)


def write_shoes(path, arrays, skip_idx0=()):
    """Write one record per array, except the 0-based indices in
    `skip_idx0`; return the number of records written.

    Each array is a 2-D (height, width) array of booleans or 0/1 values;
    its record is its values row by row as '0'/'1' characters followed by
    b'\\r\\n' (binary, so the same bytes on every platform).
    """
    skip = set(int(i) for i in skip_idx0)
    n = 0
    shape = None
    with open(path, 'wb') as f:
        for idx0, a in enumerate(arrays):
            if idx0 in skip:
                continue
            a = np.asarray(a)
            if a.ndim != 2:
                raise ValueError(f'record {idx0}: not a 2-D array')
            if shape is not None and a.shape != shape:
                raise ValueError(f'record {idx0}: shape {a.shape}, '
                                 f'expected {shape}')
            shape = a.shape
            if a.dtype != bool:
                if not np.all((a == 0) | (a == 1)):
                    raise ValueError(f'record {idx0}: values other than 0/1')
                a = a != 0
            f.write((a.reshape(-1).astype(np.uint8) + 48).tobytes())
            f.write(SEPARATOR)
            n += 1
    return n
