"""Step 0 runner: the snake contour of every shoe of one dataset.

Usage, from the repository root:
  RAC_DATASET=old|new python -m contour_algorithm.main \\
      [--steps create,contour,snake,distance] [--html] [--qa] [--jobs N]

The dataset comes from RAC_DATASET (default old; plan section 4.1), every
value and path from its profile (config/datasets.json). --html writes the
per-shoe plotly views (A-017: off by default, 3.6 GB for OLD). --qa also
saves the initial ellipse and both snakes of every shoe and of the
prototype (saved/snake_points, saved/prototype_snake_points; the input of
contour_algorithm.qa_snake, T4). --jobs N runs the shoe snakes in N forked
processes (same results as one process, checked by
tests/python/test_qa_snake.py). Without --qa and --jobs the outputs are
the legacy ones (the OLD regression of tests/regress_old.sh).

Refused (exit 2, before anything is written):
  - RAC_PROFILE_FILE set: it is a test hook; a fixture profile must never
    drive a real run (A-049);
  - --jobs N > 1 where the platform has no fork (Windows): the snake
    workers are forked processes;
  - an OLD run whose contour file already exists: the committed
    data/contour_Active_Contour.txt is the Tier A baseline and a rerun on
    another platform differs (30 of 386 records on WSL, A-060). OLD runs
    happen in a scratch copy (tests/regress_old.sh), which deletes the
    file first;
  - a run of snake steps whose numpy OpenBLAS does not run the thread
    count or the kernel that the profile fixes (python.blas_threads,
    python.blas_kernel; NEW: 1 thread, the kernel its committed contour
    was built with; A-092, A-108): another count or kernel gives other
    snakes, so an in-place NEW run would rewrite the committed contour.
"""

import argparse
import multiprocessing
import os
import sys
import time

from .profiles import env, load_profile

STEPS = ('create', 'contour', 'snake', 'distance')
# the steps that run snakes: the prototype snake (0a) and the shoe snakes
SNAKE_STEPS = frozenset(('create', 'snake'))
FOLDERS = ('shoes', 'saved', 'shoe_on_prototype', 'cleaned_shoes',
           'active-contour')
HTML_FOLDERS = ('extreme_values', 'snake_rac_html')


def make_folders(profile, html):
    for sub in FOLDERS + (HTML_FOLDERS if html else ()):
        (profile.images_dir / sub).mkdir(parents=True, exist_ok=True)
    profile.contour_out.parent.mkdir(parents=True, exist_ok=True)


def run(profile, steps=STEPS, html=None, log=print, qa=False, jobs=1):
    """Run the given steps of step 0 in order; return {step: seconds}.

    When the steps run snakes (create: the prototype snake of step 0a;
    snake: step 0c), the profile's OpenBLAS thread count and kernel are
    checked first, before anything is written (RuntimeError; nothing to
    check for OLD; second T4 review)."""
    # imported here, so that the refusals of main() need no numpy, and
    # with a headless matplotlib backend (figures of step 0c)
    os.environ.setdefault('MPLBACKEND', 'Agg')
    from . import (active_contour_snake, contour, create_files_shoes,
                   distance_extremities)
    if SNAKE_STEPS & set(steps):
        active_contour_snake.check_blas_threads(profile)
    html = profile.write_html if html is None else html
    make_folders(profile, html)
    seconds = {}
    for step in STEPS:
        if step not in steps:
            continue
        start = time.monotonic()
        if step == 'create':
            create_files_shoes.main(profile, qa=qa)
        elif step == 'contour':
            contour.main(profile, html=html)
        elif step == 'snake':
            active_contour_snake.main(profile, jobs=jobs, qa=qa)
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


def positive_int(text):
    try:
        value = int(text)
    except ValueError:
        value = 0
    if value < 1:
        raise argparse.ArgumentTypeError(f'--jobs takes a positive integer, '
                                         f'not {text!r}')
    return value


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
    parser.add_argument('--qa', action='store_true',
                        help='also save the initial ellipses and snakes '
                             '(input of contour_algorithm.qa_snake)')
    parser.add_argument('--jobs', type=positive_int, default=1,
                        help='forked processes for the shoe snakes')
    args = parser.parse_args(argv)
    if args.jobs > 1 and 'fork' not in multiprocessing.get_all_start_methods():
        print(f'contour_algorithm.main: --jobs {args.jobs} runs forked '
              'processes, and this platform has no fork; use --jobs 1',
              file=sys.stderr)
        return 2
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
    if profile.blas_threads is not None:
        # before numpy is imported (run() imports it): the snake depends on
        # the OpenBLAS thread count (A-092); OLD keeps the library default
        os.environ['OPENBLAS_NUM_THREADS'] = str(profile.blas_threads)
    if (SNAKE_STEPS & set(args.steps)
            and (profile.blas_threads is not None
                 or profile.blas_kernel is not None)):
        # the thread count and the kernel that the profile fixes (A-092,
        # A-108; NEW only): refused here with the reason, before anything
        # is written (run() checks again for in-process callers)
        os.environ.setdefault('MPLBACKEND', 'Agg')
        from .active_contour_snake import check_blas_threads
        try:
            check_blas_threads(profile)
        except RuntimeError as e:
            print(f'contour_algorithm.main: {e}', file=sys.stderr)
            return 2
    print(f'dataset {profile.dataset}: {profile.num_shoe} shoes of '
          f'{profile.W} x {profile.H} px, profile {profile.file}')
    run(profile, args.steps, html=args.html or profile.write_html,
        qa=args.qa, jobs=args.jobs)
    return 0


if __name__ == '__main__':
    sys.exit(main())
