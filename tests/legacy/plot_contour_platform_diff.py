"""Overlay the committed (Windows) OLD contour records with a WSL rerun.

T1 review fixes, diagnostic only (decisions A-060, A-066). For each shoe
given, the two records are drawn in one zoomed panel: white = contour
pixel on both platforms, green = committed (Windows) only, magenta = the
rerun only. Reads only; writes the PNG named on the command line.

Usage (thesis venv python, from the repo root):
  python -B tests/legacy/plot_contour_platform_diff.py RERUN_CONTOUR \
      OUT_PNG SHOE [SHOE ...]
RERUN_CONTOUR is data/contour_Active_Contour.txt of a legacy run (LF or
CRLF); the committed file is data/contour_Active_Contour.txt of the repo.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
W, H = 307, 395            # OLD dataset frame
NO_RECORD_SHOE = 127       # shoe 127 has no RACs and no contour record
ZOOM = 3


def read_records(path):
    """Fixed-stride 0/1 records (LF or CRLF) as bool (n, H, W)."""
    data = Path(path).read_bytes()
    for sep in (b'\r\n', b'\n'):
        stride = W * H + len(sep)
        if len(data) % stride == 0:
            arr = np.frombuffer(data, np.uint8).reshape(-1, stride)
            if np.all(arr[:, W * H:] == np.frombuffer(sep, np.uint8)):
                return (arr[:, :W * H] == 49).reshape(-1, H, W)
    raise ValueError(f'{path}: not a fixed-stride 0/1 file')


def record_index(shoe):
    """0-based contour record of a shoe id (1-based)."""
    if shoe == NO_RECORD_SHOE:
        raise ValueError('shoe 127 has no contour record')
    return shoe - 1 if shoe < NO_RECORD_SHOE else shoe - 2


def panel(committed, rerun, shoe):
    a, b = committed, rerun
    rgb = np.zeros((H, W, 3), np.uint8)
    rgb[a & b] = (255, 255, 255)
    rgb[a & ~b] = (0, 200, 0)
    rgb[~a & b] = (255, 0, 255)
    rows, cols = np.nonzero(a | b)
    r0, r1 = max(rows.min() - 5, 0), min(rows.max() + 6, H)
    c0, c1 = max(cols.min() - 5, 0), min(cols.max() + 6, W)
    crop = rgb[r0:r1, c0:c1]
    im = Image.fromarray(crop).resize(
        (crop.shape[1] * ZOOM, crop.shape[0] * ZOOM), Image.NEAREST)
    canvas = Image.new('RGB', (im.width, im.height + 18), (40, 40, 40))
    canvas.paste(im, (0, 18))
    text = (f'shoe {shoe}: {int((a != b).sum())} px differ; white both, '
            'green Windows, magenta WSL')
    ImageDraw.Draw(canvas).text((4, 3), text, fill=(255, 255, 255))
    return canvas


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    rerun_path, out_png = argv[0], argv[1]
    shoes = [int(s) for s in argv[2:]]
    committed = read_records(REPO / 'data/contour_Active_Contour.txt')
    rerun = read_records(rerun_path)
    if committed.shape != rerun.shape:
        raise ValueError(f'record counts differ: {committed.shape} vs '
                         f'{rerun.shape}')
    panels = [panel(committed[record_index(s)], rerun[record_index(s)], s)
              for s in shoes]
    out = Image.new('RGB', (sum(p.width for p in panels)
                            + 10 * (len(panels) - 1),
                            max(p.height for p in panels)), (40, 40, 40))
    x = 0
    for p in panels:
        out.paste(p, (x, 0))
        x += p.width + 10
    out.save(out_png)
    for s in shoes:
        k = record_index(s)
        print(f'shoe {s} (record {k + 1}): '
              f'{int((committed[k] != rerun[k]).sum())} px differ')
    print(f'wrote {out_png} {out.size}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
