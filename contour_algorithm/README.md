# contour_algorithm: step 0, the snake contour of every shoe

The thesis snake code (thesis repository
`/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint`, `contour_algorithm/` at
`109f30a`), ported into this repository in three reviewable steps:

| Commit | What |
|---|---|
| `fe94300` (T1) | Byte-identical copy of the thesis blobs (LF), plus `requirements-lock.txt` (the venv's `pip freeze`) |
| `9adc036`, `6c3488f` (T2c) | The three modules `main.py` never imported dropped (A-073); flake8 fixes only: each kept module has the same Python AST as its verbatim blob, docstrings and one placeholder-free f-string aside |
| T2d | Every dataset value from the dataset profile (`config/datasets.json`, `profiles.py`); package imports; `globals.py` removed |

## Run

From the repository root, with the thesis venv (`venv/bin/python`; nothing is installed):

```bash
RAC_DATASET=new python -m contour_algorithm.main [--steps create,contour,snake,distance] [--html] [--qa] [--jobs N]
RAC_DATASET=new python -m contour_algorithm.qa_snake [--metrics] [--sheets] [--figures] [--flagged] [--crosscheck] [--thresholds 13,18,29 [--compare 18,29]] [--jobs N]
```

`--qa` also saves the initial ellipse and both snakes of every shoe and of the prototype (`saved/snake_points`,
`saved/prototype_snake_points`), the input of `qa_snake`; `--jobs N` runs the shoe snakes in N forked processes
(bit-identical to one process; refused with exit 2 where the platform has no fork, i.e. Windows). Without them the
outputs are the legacy ones. The NEW profile runs numpy's OpenBLAS with one thread (`python.blas_threads`; the snake
depends on the thread count, decision A-092): `main` sets it and the snake step checks it; the step-0 log names the
thread count and the CPU kernel OpenBLAS chose (`numpy OpenBLAS kernel: Haswell` here; A-103). `qa_snake` refuses
`--sheets` and `--thresholds` for a profile without a sheets folder (OLD), checks the thread count before the
threshold study, and with `--metrics` also writes the task's copy `docs/qa/sheets_new/snake_qa_new.csv` (A-104).

`RAC_DATASET` is `old` (default; empty means old) or `new`. Every dimension, count, threshold,
snake parameter and path comes from that dataset's profile: OLD writes the legacy names under
`images/` and `data/contour_Active_Contour.txt`; NEW writes under `images_new/` with the suffix
`_new` and `data/new_shoes/contour_Active_Contour_new.txt` (plan section 5). Both `images*/` folders
are gitignored. `--html` also writes the per-shoe plotly views (off by default, A-017).

The CLI refuses, with exit 2 and before writing anything:
- `RAC_PROFILE_FILE` set (a test hook; decision A-049);
- an OLD run whose contour file exists. The committed `data/contour_Active_Contour.txt` is the
  Tier A baseline, written under Windows; a rerun on WSL differs in 30 of 386 records (A-060). OLD
  runs belong in a scratch copy: `tests/regress_old.sh` deletes the file there first (A-075).

## Modules

| Module | Step | What |
|---|---|---|
| `profiles.py` | | `load_profile()`, `env()`, `Profile` (dimensions, skip lists, snake parameters, `image_path()`, `saved_path()`, record mapping) |
| `io_shoes.py` | | `read_shoes()` (strict: size, CRLF separators, 0/1 bytes) and `write_shoes()` (binary CRLF on every platform) |
| `locations.py` | | `read_locations()` (OLD CSV; NEW raw file divided by 2) and `record_skip_idx0()` (shoes without RACs computed from the locations and checked against the profile, plus `excluded_shoes`) |
| `create_files_shoes.py` | 0a | Shoe images, `list_matrices`, the superposition, the mask `>= superpose_threshold`, the prototype snake |
| `contour.py`, `remove_noise.py` | 0b | Each shoe cleaned by the prototype mask; its extreme-value contour |
| `active_contour_snake.py` | 0c | The two-pass snake of each shoe; the contour file (one record per analysis shoe) |
| `distance_extremities.py` | 0d | Pixel (COL, ROW) of every RAC (`aspix_x`, `aspix_y`, as in R) |
| `stickers.py` | 0a | The profile's erase list (`inputs.sticker_masks`, NEW only): rectangles of frame artefacts erased from the stored records when they are read (R does the same in step 1, `statistical_model/R/io.R`; A-095) |
| `qa_snake.py` | T4 | Snake QA: per-shoe metrics and flag bands (A-093; the absolute triggers `rac_out_max_px`, `contact_out_max_px`, A-099), the review file with its classes (A-101), contact sheets, QA figures, the mask threshold study, the 2023 cross-check, the Python port of the R stamp mask |
| `main.py` | | The CLI above |

## Regression (OLD)

The ported step 0 with the OLD profile reproduces, on WSL, the T1 rerun of the verbatim code
(Tier B) exactly: the contour file (CRLF, sha256 `e18d50df...`) and all 1,556 intermediate
`.npy`/`.png` files; under the Windows venv-wind it reproduces the committed contour (Tier A,
`ca8a07f2...`). Evidence and commands: `docs/tests/T2-profiles-results.md`. Fast checks:
`tests/python/test_snake_old_regression.py` (8 shoes), `test_io_shoes.py`, `test_profiles.py`,
`test_snake_geometry.py`, `test_locations.py`, `test_sentinel_profile.py` (the profile values reach
the outputs on a tiny fixture, A-035).

## NEW profile (T4, decisions A-092 to A-097; T4 review fixes, A-099 to A-106)
The NEW snake differs from the legacy one in four profile values, all inactive for OLD: one OpenBLAS thread;
`snake.first_closing_radius` 10 (the first snake runs on the cleaned shoe closed with a disk of radius 10, so separate
heel pads and lugs form one silhouette; the image of the second snake is unchanged); the cleaning mask from the shoes in
contact on >= 18 of 631; per-shoe overrides (`inputs.snake_overrides`: closing radius 24 for 22 shoes, 16 for one).
The erase list (`inputs.sticker_masks`, 48 rectangles on 11 shoes) removes frame artefacts and debris before anything
else. Every NEW contour is the snake of the cleaned shoe as for OLD; 601 of 631 pass every QA band and the other 30 are
reviewed (`docs/qa/snake-qa.md`). `tests/rebuild_new.sh` rebuilds the committed contour and QA tables in a scratch copy.

## Known issues kept as they are (plan, known issues)
- K1: the thesis flip of image 8 was dead code (`FOLDER` never equalled `'Images/Old_Shoes/'`), so
  the committed contour of shoe 9 is unflipped while R flips its contact. The OLD profile keeps
  `python.contact_flip_shoes = []` (A-015).
- `get_snake_image()` draws on a `(W, H)` array and transposes back: a double swap, correct for
  non-square frames (plan F15), locked by `tests/python/test_snake_geometry.py`.
- The prototype mask of the legacy loop is `total >= t`; the port computes it directly (same array)
  and raises when `t` exceeds the maximum count, where the loop silently saved nothing.
- Dropped as dead code: the unused `superposed_pixels_reversed()` and `heatmap_superposed()`
  (commented out in the thesis `main()`), the module dictionary of `remove_noise.py`, the
  commented-out distance functions of `distance_extremities.py`. `list_contour.npy` is saved once
  after the loop (the thesis code saved it after every shoe; the last save is the same file).
