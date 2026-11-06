"""Step-2 QA figures, OLD vs NEW (T5; the sanity checks of new_x).

Reads processed_data/dataCC_distance.csv and
processed_data/new/dataCC_distance_new.csv and the OLD prototype contour
(data/contour_prototype.png, the frame of new_x for both datasets, A-001),
and writes

  <compare>/step2_distributions_old_vs_new.png   small multiples: new_x of
      the controls and of the cases, y of the controls and of the cases,
      min_dist and horiz_dist - min_dist in pixels (x 300), OLD blue and
      NEW orange, densities; the knots of each dataset dotted
  <compare>/step2_standardized_old_vs_new.png    the controls and the cases
      of each dataset on the standardized shoe (new_x, y), 2-D histograms
      of 1/300 bins, with the prototype outline (distance_shape) drawn

Usage (repo root, thesis venv python):
  PYTHONPATH=. python -B docs/qa/T5/probes/t5_step2_figures.py COMPARE_DIR
"""
import sys
from pathlib import Path

import matplotlib
import numpy as np
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap
from PIL import Image

from contour_algorithm.profiles import load_profile

matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402

OLD_C, NEW_C = '#2a78d6', '#eb6834'
INK, INK2, SURFACE = '#0b0b0b', '#52514e', '#fcfcfb'


def knots(v, n):
    # R quantile type 7 = numpy's default linear interpolation
    return np.quantile(v, np.arange(1, n + 1) / (n + 1))


def prototype_outline(p):
    """(x, y) of the prototype contour pixels in its own frame, as step 2
    builds them (1-based pixel, x = (c - W/2) / scale)."""
    img = np.array(Image.open(p.prototype_contour)) > 0
    hp, wp = img.shape
    assert (hp, wp) == (p.prototype_row_shoe, p.prototype_col_shoe)
    scale = p.coords.rel_col_shoe / p.coords.rel_Y_cord
    rows, cols = np.nonzero(img)
    x = (cols + 1 - wp / 2) / scale
    y = -(rows + 1 - hp / 2) / scale
    return x, y


def main(cmp_dir):
    cmp_dir = Path(cmp_dir)
    p_old, p_new = load_profile('old'), load_profile('new')
    old = pd.read_csv(p_old.r_path('dataCC_distance'))
    new = pd.read_csv(p_new.r_path('dataCC_distance'))
    px = p_old.coords.rel_col_shoe / p_old.coords.rel_Y_cord
    plt.rcParams.update({'font.size': 9, 'axes.edgecolor': INK2,
                         'axes.labelcolor': INK, 'xtick.color': INK2,
                         'ytick.color': INK2, 'axes.titlecolor': INK})
    fig, axes = plt.subplots(2, 3, figsize=(12, 6.5), facecolor=SURFACE)
    panels = [
        ('new_x, controls', lambda d: d.new_x[d.n_Acc == 0], 'new_x', 3),
        ('new_x, cases (RACs)', lambda d: d.new_x[d.n_Acc == 1], 'new_x', 3),
        ('min_dist, all rows (px)', lambda d: d.min_dist * px, None, 0),
        ('y, controls', lambda d: d.y[d.n_Acc == 0], 'y', 5),
        ('y, cases (RACs)', lambda d: d.y[d.n_Acc == 1], 'y', 5),
        ('horiz_dist - min_dist (px)',
         lambda d: (d.horiz_dist - d.min_dist) * px, None, 0),
    ]
    for ax, (title, get, kcol, nk) in zip(axes.ravel(), panels):
        a, b = get(old).to_numpy(), get(new).to_numpy()
        lo, hi = min(a.min(), b.min()), max(a.max(), b.max())
        if kcol is None:
            hi = np.quantile(np.concatenate([a, b]), 0.995)
        bins = np.linspace(lo, hi, 80)
        for v, col, lab in ((a, OLD_C, f'OLD (n = {len(a):,})'),
                            (b, NEW_C, f'NEW (n = {len(b):,})')):
            ax.hist(v, bins=bins, density=True, histtype='step',
                    linewidth=2, color=col, label=lab)
        if kcol is not None:
            for d, col in ((old, OLD_C), (new, NEW_C)):
                for k in knots(d[kcol].to_numpy(), nk):
                    ax.axvline(k, color=col, linestyle=':', linewidth=1)
        ax.set_title(title, loc='left', fontsize=10)
        ax.set_facecolor(SURFACE)
        ax.grid(axis='y', color='#e4e3df', linewidth=0.6)
        ax.set_axisbelow(True)
        for s in ('top', 'right'):
            ax.spines[s].set_visible(False)
        ax.set_yticks([])
    axes[0, 2].legend(frameon=False, loc='upper right')
    fig.suptitle('Step 2 on OLD (387 shoes) and NEW (631 shoes): '
                 'densities; dotted = each dataset\'s spline knots',
                 x=0.01, ha='left', color=INK, fontsize=11)
    fig.tight_layout()
    out1 = cmp_dir / 'step2_distributions_old_vs_new.png'
    fig.savefig(out1, dpi=130, facecolor=SURFACE)
    plt.close(fig)
    print(out1)

    ox, oy = prototype_outline(p_old)
    cmap = LinearSegmentedColormap.from_list(
        'blues', ['#fcfcfb', '#c7dcf5', '#2a78d6', '#0e3d73'])
    fig, axes = plt.subplots(1, 4, figsize=(12, 6.2), facecolor=SURFACE)
    b = 1 / px
    xb = np.arange(-0.26, 0.26 + b, b)
    yb = np.arange(-0.56, 0.56 + b, b)
    for ax, (name, d, case) in zip(axes, (('OLD controls', old, 0),
                                          ('NEW controls', new, 0),
                                          ('OLD cases', old, 1),
                                          ('NEW cases', new, 1))):
        s = d[d.n_Acc == case]
        h, _, _ = np.histogram2d(s.new_x, s.y, bins=[xb, yb])
        h = h / h.sum()
        ax.imshow(np.sqrt(h.T[::-1]), cmap=cmap, aspect='equal',
                  extent=[xb[0], xb[-1], yb[0], yb[-1]],
                  interpolation='nearest')
        ax.scatter(ox, oy, s=0.4, color=INK2, linewidths=0)
        ax.set_title(f'{name}\n({len(s):,} points)', fontsize=10, color=INK)
        ax.set_xlabel('new_x')
        ax.set_facecolor(SURFACE)
        for sp in ax.spines.values():
            sp.set_visible(False)
    axes[0].set_ylabel('y')
    fig.suptitle('Points on the standardized shoe (new_x, y), square-root '
                 'density; grey = the OLD prototype outline (both datasets)',
                 x=0.01, ha='left', color=INK, fontsize=11)
    fig.tight_layout()
    out2 = cmp_dir / 'step2_standardized_old_vs_new.png'
    fig.savefig(out2, dpi=130, facecolor=SURFACE)
    plt.close(fig)
    print(out2)


if __name__ == '__main__':
    main(*sys.argv[1:])
