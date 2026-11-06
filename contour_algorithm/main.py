"""Step 0 runner: the snake contour of every shoe of one dataset.

Usage, from the repository root:
  RAC_DATASET=old|new python -m contour_algorithm.main \\
      [--steps create,contour,snake,distance] [--html]

The dataset comes from RAC_DATASET (default old; plan section 4.1), every
value and path from its profile (config/datasets.json). --html writes the
per-shoe plotly views (A-017: off by default, 3.6 GB for OLD).

Refused (exit 2, before anything is written):
  - RAC_PROFILE_FILE set: it is a test hook; a fixture profile must never
    drive a real run (A-049);
  - an OLD run whose contour file already exists: the committed
    data/contour_Active_Contour.txt is the Tier A baseline and a rerun on
    another platform differs (30 of 386 records on WSL, A-060). OLD runs
    happen in a scratch copy (tests/regress_old.sh), which deletes the
    file first.
"""

import argparse
import os
import sys
import time

from .profiles import env, load_profile

STEPS = ('create', 'contour', 'snake', 'distance')
FOLDERS = ('shoes', 'saved', 'shoe_on_prototype', 'cleaned_shoes',
           'active-contour')
HTML_FOLDERS = ('extreme_values', 'snake_rac_html')


def make_folders(profile, html):
    for sub in FOLDERS + (HTML_FOLDERS if html else ()):
        (profile.images_dir / sub).mkdir(parents=True, exist_ok=True)
    profile.contour_out.parent.mkdir(parents=True, exist_ok=True)


def run(profile, steps=STEPS, html=None, log=print):
    """Run the given steps of step 0 in order; return {step: seconds}."""
    # imported here, so that the refusals of main() need no numpy, and
    # with a headless matplotlib backend (figures of step 0c)
    os.environ.setdefault('MPLBACKEND', 'Agg')
    from . import (active_contour_snake, contour, create_files_shoes,
                   distance_extremities)
    html = profile.write_html if html is None else html
    make_folders(profile, html)
    seconds = {}
    for step in STEPS:
        if step not in steps:
            continue
        start = time.monotonic()
        if step == 'create':
            create_files_shoes.main(profile)
        elif step == 'contour':
            contour.main(profile, html=html)
        elif step == 'snake':
            active_contour_snake.main(profile)
        else:
            distance_extremities.main(profile, html=html)
        seconds[step] = time.monotonic() - start
        log(f'step0 {step}: {seconds[step]:.1f} s')
    return seconds


def parse_steps(text):
    steps = tuple(s.strip() for s in text.split(',') if s.strip())
    bad = [s for s in steps if s not in STEPS]
    if bad or not steps:
        raise argparse.ArgumentTypeError(
            f'--steps takes a comma list of {",".join(STEPS)}, not {text!r}')
    return steps


def main(argv=None):
    if env('RAC_PROFILE_FILE', None) is not None:
        print('contour_algorithm.main: RAC_PROFILE_FILE is set; it is a test '
              'hook and a real run refuses it (decision A-049)',
              file=sys.stderr)
        return 2
    parser = argparse.ArgumentParser(prog='python -m contour_algorithm.main',
                                     description=__doc__.split('\n')[0])
    parser.add_argument('--steps', type=parse_steps, default=STEPS,
                        help='comma list of ' + ','.join(STEPS))
    parser.add_argument('--html', action='store_true',
                        help='also write the plotly HTML views')
    args = parser.parse_args(argv)
    try:
        profile = load_profile()
    except ValueError as e:
        print(f'contour_algorithm.main: {e}', file=sys.stderr)
        return 2
    if (profile.dataset == 'old' and 'snake' in args.steps
            and profile.contour_out.exists()):
        print(f'contour_algorithm.main: {profile.contour_out} exists; the '
              'OLD contour is the committed Tier A file and is never '
              'overwritten in place. Run tests/regress_old.sh (a scratch '
              'copy), or delete the file first.', file=sys.stderr)
        return 2
    print(f'dataset {profile.dataset}: {profile.num_shoe} shoes of '
          f'{profile.W} x {profile.H} px, profile {profile.file}')
    run(profile, args.steps, html=args.html or profile.write_html)
    return 0


if __name__ == '__main__':
    sys.exit(main())
