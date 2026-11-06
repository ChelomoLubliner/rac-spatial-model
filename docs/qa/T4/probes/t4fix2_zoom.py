"""Zoom panels of NEW (or OLD) shoes from the step-0 run of the work tree
(second T4 review fixes; adapted from the vision reviewer's vz.py).

Per shoe one panel (the whole shoe, or a crop window, 0-based,
end-exclusive): raw contact kept by the mask dim white, removed by the
mask red, erased by the erase list magenta; mask boundary green; cleaned
contact outside the record's row-span fill yellow; contour record blue;
first snake cyan; initial ellipse orange dashed; RAC pixels: a green ring
inside the fill, a red ring with a magenta dot outside. An optional
second record (OTHER=path of a .npy bool (H, W) record) is drawn orange.

usage (repo root):
  RAC_DATASET=new python -B docs/qa/T4/probes/t4fix2_zoom.py OUT.png \\
      SCALE NCOL SHOE[:r0:r1:c0:c1[:OTHER.npy]] ...
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from contour_algorithm import qa_snake  # noqa: E402
from contour_algorithm.profiles import load_profile  # noqa: E402

out, scale, ncol = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
specs = sys.argv[4:]
P = load_profile()
run = qa_snake.load_run(P)
H, W = P.H, P.W
inner = qa_snake.inner_boundary(run['mask'])
rec_of = {s: k for k, s in enumerate(run['shoes'])}


def poly(d, pts, colour, r0, c0, dashed=False, width=1):
    pts = [((c - c0 + 0.5) * scale, (r - r0 + 0.5) * scale) for r, c in pts]
    pts.append(pts[0])
    for k in range(len(pts) - 1):
        if dashed and (k // 4) % 2:
            continue
        d.line([pts[k], pts[k + 1]], fill=colour, width=width)


panels = []
for spec in specs:
    parts = spec.split(':')
    shoe = int(parts[0])
    r0, r1, c0, c1 = ((int(v) for v in parts[1:5]) if len(parts) >= 5
                      else (0, H, 0, W))
    other = np.load(parts[5]) if len(parts) >= 6 else None
    i = shoe - 1
    k = rec_of[shoe]
    raw = run['matrices'][i]
    cleaned = raw & run['mask']
    rec = run['records'][k]
    fill = qa_snake.row_span_fill(rec)
    img = np.zeros((H, W, 3), np.uint8)
    img[raw & run['mask']] = (170, 170, 170)
    img[raw & ~run['mask']] = (230, 40, 40)
    img[run['erased'][i]] = (255, 0, 255)
    img[cleaned & ~fill] = (255, 230, 0)
    img[inner] = (0, 170, 0)
    if other is not None:
        img[other] = (255, 140, 0)
    img[rec] = (60, 120, 255)
    img = img[r0:r1, c0:c1]
    img = np.kron(img, np.ones((scale, scale, 1), dtype=np.uint8))
    im = Image.fromarray(img)
    d = ImageDraw.Draw(im)
    w = max(1, scale // 2)
    poly(d, run['init'][i], (255, 140, 0), r0, c0, dashed=True, width=w)
    poly(d, run['first'][i], (0, 220, 255), r0, c0, width=1)
    rac = run['racs'].get(shoe, np.zeros((0, 2), int))
    n_out = 0
    for rr, cc in rac:
        if not (r0 <= rr < r1 and c0 <= cc < c1):
            continue
        x, y = (cc - c0 + 0.5) * scale, (rr - r0 + 0.5) * scale
        inside = fill[rr, cc]
        col = (0, 255, 0) if inside else (255, 0, 0)
        rad = 1.5 * scale
        d.ellipse([x - rad, y - rad, x + rad, y + rad], outline=col,
                  width=max(1, scale // 2))
        if not inside:
            n_out += 1
            d.rectangle([x - scale / 2, y - scale / 2, x + scale / 2,
                         y + scale / 2], fill=(255, 0, 255))
    tw, th = im.size
    tile = Image.new('RGB', (tw, th + 14), (40, 40, 40))
    tile.paste(im, (0, 14))
    ImageDraw.Draw(tile).text(
        (2, 1), f'{shoe} r{r0}-{r1} c{c0}-{c1} RACout={n_out} '
        f'ylw={int((cleaned & ~fill).sum())}', fill=(255, 255, 255))
    panels.append(tile)

tw = max(t.size[0] for t in panels)
th = max(t.size[1] for t in panels)
nrow = int(np.ceil(len(panels) / ncol))
sheet = Image.new('RGB', (ncol * (tw + 6), nrow * (th + 6)), (15, 15, 15))
for k, t in enumerate(panels):
    sheet.paste(t, ((k % ncol) * (tw + 6), (k // ncol) * (th + 6)))
sheet.save(out)
print(out, sheet.size)
