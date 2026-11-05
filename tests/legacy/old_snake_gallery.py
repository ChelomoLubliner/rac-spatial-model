"""OLD reference gallery of the snake (T1 item 6).

Re-runs the legacy snake (contour_algorithm/, verbatim thesis code) for a
representative set of OLD shoes inside a temporary folder, captures the
legacy figures of `plot_active_contour` (cleaned shoe, initial ellipse red
dashed, snake blue; the legacy code calls Image.show(), which is redirected
to a list here), and builds contact sheets:

  sheet_old_<kk>.png  8 shoes per sheet, 3 panels per shoe:
    1. legacy figure: cleaned shoe + init ellipse + FIRST snake
    2. legacy figure: cleaned shoe + init ellipse + SECOND snake
    3. raw shoe: pixels kept by the prototype mask in grey, pixels removed
       by the mask (stamps, stickers, noise) in red, mask boundary
       (data/contour_prototype.png) in green, final contour (the committed
       record) in blue; both lines dilated by 1 px for display
  prototype_old.png   the prototype: superposition count, >= 18 region,
                      prototype snake (first, second), freq_min_18 and its
                      boundary, the R stamp mask data/all_cont.csv
  gallery_shoes_old.csv  one row per shoe: selection reason, metrics, and
                      whether the re-run equals the committed record

Every re-run contour is compared with its committed record; any difference
is reported (exit 1).

Usage (thesis venv python, repo root):
  MPLBACKEND=Agg python -B tests/legacy/old_snake_gallery.py \
      --out docs/qa/sheets_old [--work DIR]
"""

import argparse
import csv
import os
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
LEGACY = REPO / 'contour_algorithm'
W, H = 307, 395
SKIPPED_IDX0 = 126
SEED = 20261105
N_RANDOM = 24
SHOES_PER_SHEET = 8

# 1-based shoe ids with a reason (plan facts and known issues).
KNOWN = {
    9: 'left shoe not flipped (K1, F9, F17)',
    127: 'no RACs, no contour record',
    35: 'lowest RAC on-contact rate (F27)',
    153: 'lowest RAC on-contact rate (F27)',
    236: 'printed twice inside OLD (K10, pair 236-277)',
    277: 'printed twice inside OLD (K10, pair 236-277)',
    237: 'printed twice inside OLD (K10, pair 237-278)',
    278: 'printed twice inside OLD (K10, pair 237-278)',
    38: 'possible duplicate 38-299 (F26)',
    194: 'square sticker below the heel (F25)',
}
STICKER = (7, 12, 24, 29, 55, 56, 66, 94, 110, 113, 116, 121, 160, 239,
           264, 267, 299, 371)


def read_records(path, width=W, height=H):
    data = Path(path).read_bytes()
    size = width * height
    stride = size + 2
    arr = np.frombuffer(data, dtype=np.uint8).reshape(-1, stride)
    assert np.all(arr[:, size] == 13) and np.all(arr[:, size + 1] == 10)
    return (arr[:, :size] - 48).reshape(-1, height, width).astype(bool)


def inner_boundary4(mask):
    p = np.pad(mask, 1, constant_values=False)
    interior = (p[1:-1, 1:-1] & p[:-2, 1:-1] & p[2:, 1:-1]
                & p[1:-1, :-2] & p[1:-1, 2:])
    return mask & ~interior


def row_span_fill(contour):
    fill = np.zeros_like(contour)
    for r in np.flatnonzero(contour.any(axis=1)):
        cols = np.flatnonzero(contour[r])
        fill[r, cols.min():cols.max() + 1] = True
    return fill


def record_index(idx0):
    if idx0 == SKIPPED_IDX0:
        return None
    return idx0 if idx0 < SKIPPED_IDX0 else idx0 - 1


def shoe_metrics(raw, mask, contour):
    cleaned = raw & mask
    out = {'contact_px': int(raw.sum()), 'cleaned_px': int(cleaned.sum()),
           'removed_by_mask_px': int((raw & ~mask).sum())}
    if contour is None:
        out.update(coverage='', contour_px='')
        return out
    fill = row_span_fill(contour)
    out['coverage'] = round(float((cleaned & fill).sum() / cleaned.sum()), 4)
    out['contour_px'] = int(contour.sum())
    return out


def select_shoes(raw_all, mask, contour_all):
    rows = {}
    for idx0 in range(raw_all.shape[0]):
        k = record_index(idx0)
        c = None if k is None else contour_all[k]
        rows[idx0 + 1] = shoe_metrics(raw_all[idx0], mask, c)
    reasons = {s: [r] for s, r in KNOWN.items()}
    for s in STICKER:
        reasons.setdefault(s, []).append('sticker or label beside the sole '
                                         '(F25)')
    with_rec = [s for s in rows if rows[s]['coverage'] != '']

    def add(ids, why):
        for s in ids:
            reasons.setdefault(s, []).append(why)
    add(sorted(with_rec, key=lambda s: rows[s]['coverage'])[:8],
        'lowest snake coverage')
    add(sorted(with_rec, key=lambda s: rows[s]['contour_px'])[:3],
        'fewest contour px')
    add(sorted(with_rec, key=lambda s: -rows[s]['contour_px'])[:3],
        'most contour px')
    add(sorted(rows, key=lambda s: rows[s]['contact_px'])[:3],
        'smallest contact area')
    add(sorted(rows, key=lambda s: -rows[s]['contact_px'])[:3],
        'largest contact area')
    add(sorted(rows, key=lambda s: -rows[s]['removed_by_mask_px'])[:4],
        'most pixels removed by the mask')
    rng = np.random.default_rng(SEED)
    pool = [s for s in rows if s not in reasons]
    add(sorted(rng.choice(pool, size=N_RANDOM, replace=False).tolist()),
        f'random (seed {SEED})')
    return {s: (rows[s], '; '.join(reasons[s])) for s in sorted(reasons)}


def crop_white(img):
    a = np.asarray(img.convert('RGB'))
    nonwhite = np.any(a < 250, axis=2)
    r = np.flatnonzero(nonwhite.any(axis=1))
    c = np.flatnonzero(nonwhite.any(axis=0))
    return Image.fromarray(a[r.min():r.max() + 1, c.min():c.max() + 1])


def dilate1(m):
    """3 x 3 dilation, for display only (thicker lines)."""
    p = np.pad(m, 1, constant_values=False)
    out = np.zeros_like(m)
    for dr in (0, 1, 2):
        for dc in (0, 1, 2):
            out |= p[dr:dr + m.shape[0], dc:dc + m.shape[1]]
    return out


def mask_panel(raw, mask, contour):
    rgb = np.zeros(raw.shape + (3,), dtype=np.uint8)
    rgb[raw & mask] = (170, 170, 170)
    rgb[raw & ~mask] = (230, 30, 30)
    rgb[dilate1(inner_boundary4(mask))] = (0, 200, 0)
    if contour is not None:
        rgb[dilate1(contour)] = (40, 110, 255)
    return Image.fromarray(rgb)


class LegacySnake:
    """The legacy snake with its figures and snakes captured."""

    def __init__(self, work):
        os.environ.setdefault('MPLBACKEND', 'Agg')
        if str(LEGACY) not in sys.path:
            sys.path.insert(0, str(LEGACY))
        import active_contour_snake as acs
        import remove_noise as rn
        self.acs, self.rn = acs, rn
        self.folder = str(work) + '/'
        for sub in ('saved', 'cleaned_shoes'):
            os.makedirs(self.folder + sub, exist_ok=True)
        acs.FOLDER = self.folder
        rn.FOLDER = self.folder
        self.snakes, self.figures = [], []
        real = acs.active_contour

        def recording(image, snake, **kw):
            out = real(image, snake, **kw)
            self.snakes.append((np.array(snake), np.array(out)))
            return out
        acs.active_contour = recording
        Image.Image.show = lambda img, *a, **k: self.figures.append(
            img.copy())

    def run_shoe(self, list_matrices, idx0):
        self.snakes.clear()
        self.figures.clear()
        self.rn.save_cleaned_shoes(list_matrices, idx0)
        arr = self.acs.active_contour_shoe(None, plot_img=True,
                                           save_img_bool=False, im_num=idx0)
        return arr, list(self.figures), list(self.snakes)

    def run_prototype(self, old_freq_min_18):
        self.snakes.clear()
        Image.fromarray(old_freq_min_18).save(
            self.folder + 'saved/old_freq_min_18.png')
        self.acs.active_contour_on_prototype()
        final = np.load(self.folder + 'saved/freq_min_18.npy')
        return final, list(self.snakes)


def draw_sheet(items, out_path, title):
    import matplotlib.pyplot as plt
    rows = SHOES_PER_SHEET // 2  # same geometry for every sheet
    height = 2.95 * rows
    fig, axes = plt.subplots(rows, 6, figsize=(13.2, height), dpi=100)
    axes = np.atleast_2d(axes)
    for ax in axes.ravel():
        ax.axis('off')
    blank = np.full((H, W), 255, dtype=np.uint8)
    pad = [(None, [(blank, '')] * 3, '')] * (SHOES_PER_SHEET - len(items))
    for n, (shoe, panels, label) in enumerate(list(items) + pad):
        if shoe is None:  # keeps the full-sheet geometry on the last sheet
            r, c0 = divmod(n, 2)
            for j in range(3):
                axes[r, c0 * 3 + j].imshow(blank, cmap='gray', vmin=0,
                                           vmax=255)
                axes[r, c0 * 3 + j].set_title(' \n \n ', fontsize=6.5)
            continue
        r, c0 = divmod(n, 2)
        for j, (img, sub) in enumerate(panels):
            ax = axes[r, c0 * 3 + j]
            ax.imshow(img, interpolation='nearest')
            head = f'SHOE {shoe}: {label}\n' if j == 0 else ''
            ax.set_title(head + sub, fontsize=6.5, loc='left')
    fig.suptitle(title, fontsize=10)
    fig.tight_layout(rect=(0, 0, 1, 0.98))
    fig.savefig(out_path)
    plt.close(fig)


def draw_prototype(total, ge18, proto_snakes, final, proto, allcont, out):
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(1, 6, figsize=(16.5, 4.6), dpi=100)
    (i1, s1), (i2, s2) = proto_snakes
    panels = [
        ('superposition: number of shoes per pixel', total, 'viridis'),
        ('>= 18 shoes (old_freq_min_18)', ge18, 'gray'),
        ('prototype snake 1 (init red, snake blue)', ge18, 'gray'),
        ('prototype snake 2 on the combined image', ge18, 'gray'),
        ('freq_min_18.png (filled) + boundary', final, 'gray'),
        ('R stamp mask all_cont.csv (red: mask only)', None, None),
    ]
    for ax, (t, img, cmap) in zip(axes, panels):
        ax.axis('off')
        ax.set_title(t, fontsize=8)
        if img is not None:
            ax.imshow(img, cmap=cmap, interpolation='nearest')
    for ax, (ini, sn) in ((axes[2], (i1, s1)), (axes[3], (i2, s2))):
        ax.plot(ini[:, 1], ini[:, 0], '--r', lw=1.5)
        ax.plot(sn[:, 1], sn[:, 0], '-b', lw=1.5)
    by, bx = np.nonzero(proto)
    axes[4].plot(bx, by, ',', color='lime')
    rgb = np.zeros(final.shape + (3,), dtype=np.uint8)
    rgb[final & allcont] = (200, 200, 200)
    rgb[final & ~allcont] = (230, 30, 30)
    rgb[~final & allcont] = (30, 30, 230)
    axes[5].imshow(rgb, interpolation='nearest')
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--work', type=Path)
    args = ap.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    raw_all = read_records(REPO / 'data/contacts_data.txt')
    contour_all = read_records(REPO / 'data/contour_Active_Contour.txt')
    mask = np.array(Image.open(REPO / 'data/freq_min_18.png')) > 0
    proto = np.array(Image.open(REPO / 'data/contour_prototype.png')
                     .convert('L')) > 0
    allcont = np.loadtxt(REPO / 'data/all_cont.csv', delimiter=',',
                         skiprows=1) > 0
    chosen = select_shoes(raw_all, mask, contour_all)

    tmp = None
    if args.work is None:
        tmp = tempfile.TemporaryDirectory(prefix='old_gallery_')
        work = Path(tmp.name)
    else:
        work = args.work
    snake = LegacySnake(work)
    np.save(str(work / 'saved/freq_min_18.npy'), mask)

    # The prototype itself: superposition >= 18 and the prototype snakes.
    total = raw_all.sum(axis=0)
    ge18 = total >= 18
    final, proto_snakes = snake.run_prototype(ge18)
    proto_ok = bool(np.array_equal(final, mask))
    draw_prototype(total, ge18, proto_snakes, final, proto, allcont,
                   args.out / 'prototype_old.png')
    np.save(str(work / 'saved/freq_min_18.npy'), mask)

    results, items = [], []
    for shoe, (metrics, reason) in chosen.items():
        idx0 = shoe - 1
        arr, figs, snakes = snake.run_shoe(raw_all, idx0)
        k = record_index(idx0)
        committed = None if k is None else contour_all[k]
        diff = '' if committed is None else int((arr != committed).sum())
        assert len(figs) == 3 and len(snakes) == 2, (shoe, len(figs))
        init, first = snakes[0]
        results.append(dict(shoe=shoe, reason=reason, **metrics,
                            rerun_diff_px=diff,
                            first_snake_rows=f'{first[:, 0].min():.0f}-'
                                             f'{first[:, 0].max():.0f}',
                            init_rows=f'{init[:, 0].min():.0f}-'
                                      f'{init[:, 0].max():.0f}'))
        short = reason if len(reason) <= 34 else reason[:32] + '..'
        label = (f'cov {metrics["coverage"]}, {metrics["contour_px"]} '
                 f'contour px\n{short}')
        final_c = committed if committed is not None else arr
        items.append((shoe, [
            (crop_white(figs[0]), 'init + 1st snake'),
            (crop_white(figs[2]), 'init + 2nd snake'),
            (mask_panel(raw_all[idx0], mask, final_c),
             'raw: kept / removed / mask / final'),
        ], label))

    sheets = [items[i:i + SHOES_PER_SHEET]
              for i in range(0, len(items), SHOES_PER_SHEET)]
    for n, part in enumerate(sheets, start=1):
        draw_sheet(part, args.out / f'sheet_old_{n:02d}.png',
                   f'OLD shoes, legacy snake re-run (sheet {n} of '
                   f'{len(sheets)}): red dashed = initial ellipse, blue = '
                   'snake; panel 3: grey kept, red removed by the mask, '
                   'green mask boundary, blue final contour')
    with open(args.out / 'gallery_shoes_old.csv', 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(results[0]),
                           lineterminator='\n')
        w.writeheader()
        w.writerows(results)
    bad = [r['shoe'] for r in results
           if r['rerun_diff_px'] not in ('', 0)]
    print(f'prototype re-run equals data/freq_min_18.png: {proto_ok}')
    print(f'shoes: {len(results)}; sheets: {len(sheets)}; re-run differs '
          f'from the committed record for: {bad}')
    if tmp is not None:
        tmp.cleanup()
    return 0 if (proto_ok and not bad) else 1


if __name__ == '__main__':
    sys.exit(main())
