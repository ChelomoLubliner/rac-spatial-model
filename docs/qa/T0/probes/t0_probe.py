"""T0 read-only probes (part 1): raw formats, RACs, calibration, masks.

Evidence for docs/plans/2026-11-05-new-shoes-pipeline.md. Reads data only
and writes four evidence PNGs into <out_dir>. Never writes into the repo's
data folders or into the thesis repo. Run with the thesis venv python and
-B, so that importing the thesis module does not write bytecode there:

    VENV/bin/python -I -B t0_probe.py <repo_root> <thesis_contour_dir> \
        <out_dir>
"""
import sys

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw
from scipy import ndimage

REPO, THESIS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, THESIS)
from extreme_values_x_y import get_contour  # noqa: E402


def load(path, w, h, n):
    """Fixed-stride reader: n records of w*h chars + CRLF."""
    raw = open(path, 'rb').read()
    stride = w * h + 2
    arr = np.frombuffer(raw, dtype=np.uint8)
    recs = np.stack([arr[i * stride:i * stride + w * h] for i in range(n)])
    return recs.reshape(n, h, w).astype(np.int16) - 48, raw


def section(title):
    print('\n=== ' + title)


section('A. raw file structure')
for name, path, w, h, n in [
        ('old contacts', 'data/contacts_data.txt', 307, 395, 387),
        ('old contour', 'data/contour_Active_Contour.txt', 307, 395, 386),
        ('new contacts', 'data/new_shoes/contacts_data_new.txt', 255, 367,
         631)]:
    recs, raw = load(f'{REPO}/{path}', w, h, n)
    stride = w * h + 2
    seps = {raw[stride * i - 2:stride * i] for i in range(1, n + 1)}
    print(f'{name}: bytes={len(raw)} expected={stride * n} '
          f'separators={seps} values={np.unique(recs).tolist()}')
OLD, _ = load(f'{REPO}/data/contacts_data.txt', 307, 395, 387)
CONT, _ = load(f'{REPO}/data/contour_Active_Contour.txt', 307, 395, 386)
NEW, _ = load(f'{REPO}/data/new_shoes/contacts_data_new.txt', 255, 367, 631)

section('B. RAC locations')
old_loc = pd.read_csv(f'{REPO}/data/locations_data.csv')
raw = pd.read_csv(f'{REPO}/data/new_shoes/locations_data_new_raw.txt',
                  sep=r'\s+', header=None,
                  names=['shoe', 'rac', 'x', 'y', 'type'])
s23 = pd.read_csv(f'{REPO}/data/new_shoes/locations_new_snake_2023.csv')
print(f'old: RACs={len(old_loc)} shoes={old_loc.shoe.nunique()} '
      f'missing={sorted(set(range(1, 388)) - set(old_loc.shoe))}')
print(f'new: RACs={len(raw)} shoes={raw.shoe.nunique()} '
      f'missing={sorted(set(range(1, 632)) - set(raw.shoe))}')
cnt = raw.groupby('shoe').size()
print(f'new RACs/shoe: min={cnt.min()} median={cnt.median()} '
      f'mean={cnt.mean():.2f} max={cnt.max()}')
print(f'first RAC raw x={raw.x[0]} 2023 x={s23.x[0]} ratio='
      f'{raw.x[0] / s23.x[0]:.6f}; max |raw/2 - 2023| x='
      f'{np.abs(raw.x / 2 - s23.x).max():.2e} y='
      f'{np.abs(raw.y / 2 - s23.y).max():.2e}')
print(f'new coords /2: x in [{(raw.x / 2).min():.4f}, '
      f'{(raw.x / 2).max():.4f}], y in [{(raw.y / 2).min():.4f}, '
      f'{(raw.y / 2).max():.4f}]; old: x in [{old_loc.x.min():.4f}, '
      f'{old_loc.x.max():.4f}], y in [{old_loc.y.min():.4f}, '
      f'{old_loc.y.max():.4f}]')

section('C. contact pixels per shoe')
for name, recs in [('old', OLD), ('new', NEW)]:
    px = recs.sum(axis=(1, 2))
    print(f'{name}: min={px.min()} median={np.median(px)} max={px.max()}')
px_new = NEW.sum(axis=(1, 2))
order = np.argsort(px_new)
print('new smallest 8 (shoe, px):',
      [(int(i + 1), int(px_new[i])) for i in order[:8]])

section('D. pixel calibration feasibility')
xo, yo, so = old_loc.x.values, old_loc.y.values, old_loc.shoe.values
c1 = 307 - (np.floor((xo + 0.25) * 300) + 79)
r1 = 395 - (np.floor((yo + 0.5) * 300) + 48)
legacy = OLD[so - 1, (r1 - 1).astype(int), (c1 - 1).astype(int)].mean()
print(f'old legacy R aspix mapping: RACs on contact = {legacy:.4f}')


def rate(recs, shoe, x, y, sx, sy, cx, cy, mirror_x, flip_y):
    w, h = recs.shape[2], recs.shape[1]
    col = np.floor(cx + (-x if mirror_x else x) * sx).astype(int)
    row = np.floor(cy + (y if flip_y else -y) * sy).astype(int)
    ok = (col >= 0) & (col < w) & (row >= 0) & (row < h)
    val = np.zeros(len(x))
    val[ok] = recs[shoe[ok] - 1, row[ok], col[ok]]
    return val.mean()


best = max((rate(OLD, so, xo, yo, s, s, 153.5 + dc, 197.5 + dr, mx, fy),
            s, mx, fy, dc, dr)
           for s in (280, 290, 300, 310, 320) for mx in (True, False)
           for fy in (False, True) for dc in range(-6, 7)
           for dr in range(-6, 7))
print('old best (rate, s, mirror_x, flip_y, dc, dr):',
      (round(best[0], 4),) + best[1:])
xn, yn, sn = raw.x.values / 2, raw.y.values / 2, raw.shoe.values
coarse = max((rate(NEW, sn, xn, yn, s, s, 127.5 + dc, 183.5 + dr, mx, fy),
              s, mx, fy, dc, dr)
             for s in range(240, 345, 10) for mx in (True, False)
             for fy in (False, True) for dc in range(-20, 21, 4)
             for dr in range(-20, 21, 4))
print('new coarse best (rate, s, mirror_x, flip_y, dc, dr):',
      (round(coarse[0], 4),) + coarse[1:])
_, s0, mx0, fy0, dc0, dr0 = coarse
fine = sorted(((rate(NEW, sn, xn, yn, sx, sy, 127.5 + dc, 183.5 + dr,
                     mx0, fy0), sx, sy, dc, dr)
               for sx in range(s0 - 12, s0 + 13, 2)
               for sy in range(s0 - 12, s0 + 13, 2)
               for dc in range(dc0 - 5, dc0 + 6)
               for dr in range(dr0 - 5, dr0 + 6)), reverse=True)
print('new fine top5 (rate, sx, sy, dc, dr):',
      [(round(f[0], 4),) + f[1:] for f in fine[:5]])
on23 = NEW[s23.shoe.values - 1, s23.ROW.values - 1, s23.COL.values - 1]
print(f'new 2023 COL/ROW (1-indexed) on contact = {on23.mean():.4f}')

section('E. left/right (flip) score: corr with mean shoe, flipped/orig')
for name, recs in [('old', OLD), ('new', NEW)]:
    r = recs.astype(np.float32)
    m = r.mean(0)
    ratio = (r[:, :, ::-1] * m).sum((1, 2)) / (r * m).sum((1, 2))
    idx = np.argsort(-ratio)[:4]
    top = [(int(i + 1), round(float(ratio[i]), 3)) for i in idx]
    print(f'{name}: top={top} n(ratio>1)={int((ratio > 1).sum())}')

section('F. committed OLD contour vs contact (row-span fill)')


def rowfill(cont):
    filled = np.zeros(cont.shape, dtype=bool)
    for i in range(cont.shape[0]):
        j = np.flatnonzero(cont[i])
        if j.size:
            filled[i, j.min():j.max() + 1] = True
    return filled


ids = [i for i in range(1, 388) if i != 127]
cov = []
for k, sid in enumerate(ids):
    filled = rowfill(CONT[k])
    shoe = OLD[sid - 1]
    if sid == 9:
        unfl = (shoe * filled).sum() / shoe.sum()
        shoe = shoe[:, ::-1]
        print(f'shoe 9 coverage: unflipped={unfl:.3f} '
              f'flipped={(shoe * filled).sum() / shoe.sum():.3f}')
    cov.append((shoe * filled).sum() / max(shoe.sum(), 1))
cov = np.array(cov)
worst = [(ids[i], round(float(cov[i]), 3)) for i in np.argsort(cov)[:4]]
print(f'coverage over 386: min={cov.min():.3f} '
      f'p5={np.percentile(cov, 5):.3f} median={np.median(cov):.3f}; '
      f'worst={worst}')
npx = CONT.sum((1, 2))
print(f'contour pixels/shoe: min={npx.min()} median={np.median(npx)} '
      f'max={npx.max()}')

section('G. contour_prototype.png vs freq_min_18.png')
fm = np.array(Image.open(f'{REPO}/data/freq_min_18.png')).astype(bool)
cp = np.array(Image.open(f'{REPO}/data/contour_prototype.png')) > 0
b4 = fm & ~ndimage.binary_erosion(fm)
g = np.zeros_like(fm)
g[tuple(zip(*get_contour(fm)))] = True
print(f'freq_min_18 px={fm.sum()} contour_prototype px={cp.sum()} '
      f'xor(4-boundary)={int((b4 ^ cp).sum())} '
      f'xor(get_contour)={int((g ^ cp).sum())}')

section('H. cleaning masks')
ac = pd.read_csv(f'{REPO}/data/all_cont.csv').values.astype(bool)
old_fl = OLD.copy()
old_fl[8] = old_fl[8][:, ::-1]
ge8 = old_fl.sum(0) >= 8
print(f'old: all_cont px={ac.sum()} >=8 px={ge8.sum()} removed by sweep='
      f'{int((ge8 & ~ac).sum())} all_cont outside freq_min_18='
      f'{int((ac & ~fm).sum())} freq_min_18 outside all_cont='
      f'{int((fm & ~ac).sum())}')
tot = NEW.sum(0)
print(f'new: max overlap={tot.max()} union px={(tot >= 1).sum()}')
for t in (8, 13, 18, 29):
    m = tot >= t
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    print(f'new t={t}: px={m.sum()} components={n} '
          f'outside main={int(m.sum() - sizes.max())}')

section('I. evidence images written')


def save(name, arr, scale=2):
    im = Image.fromarray(arr)
    im = im.resize((arr.shape[1] * scale, arr.shape[0] * scale),
                   Image.NEAREST)
    im.save(f'{OUT}/{name}')
    print(f'{OUT}/{name} {im.size}')


u8 = np.uint8
osup = (old_fl.sum(0) >= 1)
sep = np.full((395, 6), 128, u8)
save('old_prototypes.png', np.hstack([fm * u8(255), sep,
                                      (old_fl.sum(0) >= 18) * u8(255), sep,
                                      cp * u8(255), sep, osup * u8(255)]))
img = np.zeros((395, 307, 3), u8)
img[ac] = (255, 255, 255)
img[ge8 & ~ac] = (255, 0, 0)
img[fm & ~ac & ~ge8] = (0, 0, 255)
save('old_rmask_stamps.png', img)
sepn = np.full((367, 6), 128, u8)
dens = np.clip(tot / tot.max() * 255 * 3, 0, 255).astype(u8)
save('new_superposition.png', np.hstack([(tot >= 1) * u8(255), sepn,
                                         (tot >= 18) * u8(255), sepn,
                                         (tot >= 29) * u8(255), sepn, dens]))
rng = np.random.default_rng(1)
pick = [int(i + 1) for i in order[:8]]
pick += sorted(int(v) for v in rng.choice(np.arange(1, 632), 8,
                                          replace=False))
tiles = []
for s in pick:
    im = Image.fromarray(np.stack([NEW[s - 1] * 255] * 3, -1).astype(u8))
    d = ImageDraw.Draw(im)
    r = raw[raw.shoe == s]
    cols = np.floor(126.5 - 300 * r.x.values / 2).astype(int)
    rows = np.floor(182.5 - 300 * r.y.values / 2).astype(int)
    for c, rr in zip(cols, rows):
        d.rectangle([c - 2, rr - 2, c + 2, rr + 2], outline=(255, 0, 0))
    d.text((3, 3), f'shoe {s} px={px_new[s - 1]} n={len(r)}',
           fill=(0, 255, 0))
    tiles.append(np.array(im))
sheet = np.vstack([np.hstack(tiles[:8]), np.hstack(tiles[8:])])
save('new_sheet_16_racs.png', sheet, scale=1)
print('sheet shoes:', pick)
