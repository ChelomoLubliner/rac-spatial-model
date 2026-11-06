"""QA images of the T3 data preparation (plan T3 step 3; decisions A-087,
A-089). Every image is opened and described by the agent who made it
(user rule 10); the descriptions are in the task's results document.

    calibration_curves  the calibration grid (`prep.calibration_grid`):
                        the best on-contact rate per x scale and per y
                        scale (stage F and stage C, best offsets and best
                        other scale), and per orientation (stage O); the
                        strict and the dilated criterion
    offcontact_shoes    the shoes with the lowest strict on-contact rate
                        (from `prep.shoe_contact`), RACs drawn
    raw_sheet_<kk>      every shoe of the dataset, 32 per sheet (with
                        --raw-sheets): the raw contact record (white), its
                        RACs by the profile's mapping as hollow squares,
                        green on a contact pixel, red off it

Files: `Profile.qa_path(stem, 'png')`, i.e. `prep.qa_dir/<stem><suffix>.png`.
Command line (after calibrate_pixels and shoe_quality of the dataset):

    RAC_DATASET=old|new python -m contour_algorithm.qa_sheets [--raw-sheets]
"""

import argparse
import math
import sys

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw

from .calibrate_pixels import (legacy_pixel, load_dataset, on_image,
                               px_per_unit)
from .profiles import env, load_profile

WHITE = np.iinfo(np.uint8).max
GREEN = (0, 200, 0)
RED = (235, 30, 30)
BACKGROUND = 48
LABEL_COLOUR = (120, 220, WHITE)
PER_SHEET = 32
SHEET_COLUMNS = 8
N_OFFCONTACT = 24


def rac_tile(contact, col0, row0, hit, half=2):
    """RGB tile of one shoe: the contact record white on black and every
    RAC a hollow square of side 2 * half + 1 around its pixel, green if it
    is on contact (`hit`), red if not."""
    h, w = contact.shape
    img = np.zeros((h, w, 3), dtype=np.uint8)
    img[contact] = WHITE
    for c, r, on in zip(col0, row0, hit):
        colour = GREEN if on else RED
        for dr in range(-half, half + 1):
            for dc in range(-half, half + 1):
                if max(abs(dr), abs(dc)) != half:
                    continue
                rr, cc = r + dr, c + dc
                if 0 <= rr < h and 0 <= cc < w:
                    img[rr, cc] = colour
    return img


def contact_sheet(tiles, labels, ncols, out, label_h=14, gap=4):
    """Tiles in a grid of `ncols` columns, each with its label above it,
    written as a PNG to `out`."""
    th = max(t.shape[0] for t in tiles)
    tw = max(t.shape[1] for t in tiles)
    nrows = math.ceil(len(tiles) / ncols)
    canvas = np.full((nrows * (th + label_h + gap), ncols * (tw + gap), 3),
                     BACKGROUND, dtype=np.uint8)
    for k, tile in enumerate(tiles):
        r0 = (k // ncols) * (th + label_h + gap) + label_h
        c0 = (k % ncols) * (tw + gap)
        canvas[r0:r0 + tile.shape[0], c0:c0 + tile.shape[1]] = tile
    im = Image.fromarray(canvas)
    draw = ImageDraw.Draw(im)
    for k, text in enumerate(labels):
        r0 = (k // ncols) * (th + label_h + gap)
        c0 = (k % ncols) * (tw + gap)
        draw.text((c0 + 2, r0 + 1), text, fill=LABEL_COLOUR)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out, optimize=True)
    return out


def mapped(profile, data):
    """0-based RAC pixels by the profile's mapping and their strict hits."""
    col1, row1 = legacy_pixel(data['x'], data['y'], profile.coords,
                              profile.W, profile.H)
    col0, row0 = col1 - 1, row1 - 1
    shoe0 = data['shoe'] - 1
    ok = on_image(col0, row0, profile.W, profile.H)
    hit = np.zeros(len(col0), dtype=bool)
    hit[ok] = data['contacts'][shoe0[ok], row0[ok], col0[ok]]
    return col0, row0, hit


def shoe_tiles(profile, data, shoes, table=None):
    """Tiles and labels of the given 1-based shoes."""
    col0, row0, hit = mapped(profile, data)
    rows = None if table is None else table.set_index('shoe')
    tiles, labels = [], []
    for s in shoes:
        sel = data['shoe'] == s
        contact = data['contacts'][s - 1]
        tiles.append(rac_tile(contact, col0[sel], row0[sel], hit[sel]))
        n = int(sel.sum())
        text = f'{profile.dataset} {s} n={n}'
        if n:
            text += f' on={hit[sel].mean():.2f}'
        if rows is not None and n:
            b = rows.loc[s]
            text += (f' best={b["best_shift_rate"]:.2f}'
                     f'({int(b["best_dc"])},{int(b["best_dr"])})')
        else:
            text += f' px={int(contact.sum())}'
        labels.append(text)
    return tiles, labels


def raw_sheets(profile, data):
    """Every shoe of the dataset, PER_SHEET per sheet; return the paths."""
    shoes = list(range(1, profile.num_shoe + 1))
    paths = []
    for k in range(math.ceil(len(shoes) / PER_SHEET)):
        part = shoes[k * PER_SHEET:(k + 1) * PER_SHEET]
        tiles, labels = shoe_tiles(profile, data, part)
        paths.append(contact_sheet(tiles, labels, SHEET_COLUMNS,
                                   profile.qa_path(f'raw_sheet_{k + 1:02d}',
                                                   'png')))
    return paths


def offcontact_shoes(profile, data, table, out=None):
    """The N_OFFCONTACT shoes with RACs and the lowest strict rate (ties:
    more RACs first), with every shoe whose RACs are all off contact;
    written to `out` (default: the profile's QA file)."""
    t = table[table['n_rac'] > 0].sort_values(['rate', 'n_rac', 'shoe'],
                                              ascending=[True, False, True])
    pick = list(t['shoe'].head(N_OFFCONTACT))
    pick += [s for s in t.loc[t['all_off'], 'shoe'] if s not in pick]
    tiles, labels = shoe_tiles(profile, data, pick, table)
    if out is None:
        out = profile.qa_path('offcontact_shoes', 'png')
    return contact_sheet(tiles, labels, SHEET_COLUMNS, out)


def calibration_curves(profile, grid):
    """Profiles of the calibration grid (see the module docstring)."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    s0 = px_per_unit(profile.coords)
    fig, axes = plt.subplots(2, 3, figsize=(15, 8.5))
    for i, crit in enumerate(('strict', 'dilated')):
        g = grid[grid['criterion'] == crit]
        for j, stage in enumerate(('F', 'C')):
            ax = axes[i, j]
            t = g[g['stage'] == stage]
            for axis, colour in (('sx', 'tab:blue'), ('sy', 'tab:orange')):
                prof = t.groupby(axis)['rate'].max()
                ax.plot(prof.index, prof.to_numpy(), '.-', color=colour,
                        label=f'best rate per {axis} (other scale and '
                              'offsets at their best)')
            top = t.sort_values('rate', ascending=False, kind='stable')
            best = top.iloc[0]
            ax.axvline(s0[0], color='grey', ls='--', lw=1,
                       label=f'legacy {s0[0]:g} px per unit')
            ax.set_title(f'{profile.dataset} stage {stage}, {crit}: optimum '
                         f'sx={int(best["sx"])} sy={int(best["sy"])} '
                         f'dc={best["dc"]:g} dr={best["dr"]:g} '
                         f'rate={best["rate"]:.4f}', fontsize=9)
            ax.set_xlabel('scale (px per coordinate unit)')
            ax.set_ylabel(f'on-contact rate ({crit})')
            ax.grid(alpha=0.3)
            ax.legend(fontsize=7, loc='lower center')
        ax = axes[i, 2]
        o = g[g['stage'] == 'O']
        best_o = o.groupby(['mirror_x', 'flip_y'])['rate'].max()
        names = [f'mirror x={bool(m)}\nflip y={bool(f)}'
                 for m, f in best_o.index]
        ax.bar(range(len(best_o)), best_o.to_numpy(), color='tab:green')
        ax.set_xticks(range(len(best_o)), names, fontsize=8)
        for k, v in enumerate(best_o.to_numpy()):
            ax.text(k, v, f'{v:.3f}', ha='center', va='bottom', fontsize=8)
        ax.set_title(f'{profile.dataset} stage O, {crit}: best rate per '
                     'orientation', fontsize=9)
        ax.set_ylim(0, 1)
    fig.tight_layout()
    out = profile.qa_path('calibration_curves', 'png')
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=90)
    plt.close(fig)
    return out


def main(argv=None):
    if env('RAC_PROFILE_FILE', None) is not None:
        print('contour_algorithm.qa_sheets: RAC_PROFILE_FILE is set; it is a '
              'test hook and a real run refuses it (decision A-049)',
              file=sys.stderr)
        return 2
    parser = argparse.ArgumentParser(
        prog='python -m contour_algorithm.qa_sheets',
        description='QA images of the T3 data preparation (RAC_DATASET).')
    parser.add_argument('--raw-sheets', action='store_true',
                        help='also draw every shoe, 32 per sheet')
    args = parser.parse_args(argv)
    try:
        profile = load_profile()
        grid = pd.read_csv(profile.prep_path('calibration_grid'))
        table = pd.read_csv(profile.prep_path('shoe_contact'))
    except (ValueError, OSError) as e:
        print(f'contour_algorithm.qa_sheets: {e}', file=sys.stderr)
        return 2
    data = load_dataset(profile)
    paths = [calibration_curves(profile, grid),
             offcontact_shoes(profile, data, table)]
    if args.raw_sheets:
        paths += raw_sheets(profile, data)
    for p in paths:
        print(f'wrote {p}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
