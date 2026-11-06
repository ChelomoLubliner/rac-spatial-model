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
RAC_DATASET=new python -m contour_algorithm.main [--steps create,contour,snake,distance] [--html]
```

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
| `main.py` | | The CLI above |

## Regression (OLD)

The ported step 0 with the OLD profile reproduces, on WSL, the T1 rerun of the verbatim code
(Tier B) exactly: the contour file (CRLF, sha256 `e18d50df...`) and all 1,556 intermediate
`.npy`/`.png` files; under the Windows venv-wind it reproduces the committed contour (Tier A,
`ca8a07f2...`). Evidence and commands: `docs/tests/T2-profiles-results.md`. Fast checks:
`tests/python/test_snake_old_regression.py` (8 shoes), `test_io_shoes.py`, `test_profiles.py`,
`test_snake_geometry.py`, `test_locations.py`, `test_sentinel_profile.py` (the profile values reach
the outputs on a tiny fixture, A-035).

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
