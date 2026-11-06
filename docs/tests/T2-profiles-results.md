# T2-profiles: results (2026-11-06)

Task T2 of `docs/plans/2026-11-05-new-shoes-pipeline.md`: dataset profiles for the Python contour code
and the R steps, OLD outputs unchanged. Every block below is a real command and its real output
(`<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`;
long outputs trimmed with an explicit marker). Decisions A-073 to A-081.

## 0. Summary

| Check | Result | Section |
|---|---|---|
| T2c: flake8 findings of the ported code | 106 -> 0; each kept module is the same Python AST as its verbatim blob | 1 |
| T2a: profile file and accessors | `config/datasets.json`, `profiles.py`, `R/profile.R`; OLD = the legacy literals (`identical()` doubles) and path strings; NEW namespaced; 5 deliberately colliding profiles all caught | 2 |
| T2d: ported step 0, OLD, WSL | contour = Tier B with CRLF (`e18d50df...`), 1,556 of 1,556 intermediates = Tier B, RAC-pixel CSV = both legacy WSL runs | 3.1 |
| T2d: ported step 0, OLD, venv-wind | contour = **Tier A** (`ca8a07f2...`), four npy = Tier B, `active-contour_all.npy` = the thesis run of 2025-11-13 | 7.3 |
| T2d: OLD gallery with the ported snake | WSL: 11 of 11 files = the T1 WSL build; venv-wind: 11 of 11 files = the committed `docs/qa/sheets_old/` | 3.2 |
| T2b: step 1 through the profile | the three CSVs = Tier A raw (CRLF written directly) | 4.1 |
| T2b: sentinel tests (A-035, A-050) | Python 5 tests and R 10 checks pass; two mutations of step 2 caught | 4.2 |
| T2b: no-hardcoding scans | Python/shell and R pass; allowlist tight | 4.3 |
| T2e: step 5 on the committed models | `W = 428.6933, df = 24, p = 9.43e-76` without car; with car (Windows R) `W_car = 428.6933` | 5 |
| Vectorized step 2 (optional) | both OLD CSVs = Tier A; 20-22 s in the gates (51.4 s in the proof run on a loaded machine) instead of 19-23 min; default since (A-076) | 6 |
| Windows R step-3 gate (A-065) | `RESULT 27 of 27 fields the same` vs the Tier A GLMM | 7.2 |
| Full OLD gate `regress_old.sh --steps 0-6` | ALL PASS, run as `--steps 0` and `--steps 1-6` (A-081); my first two chained attempts failed by design and are shown | 7.1 |
| NEW step 1, real NEW data (scratch smoke test) | 83,090 rows = 631 x 100 + 19,990 cases (plan F2); only `_new` files written | 7.5 |
| `bash tests/run_all.sh old` | ALL PASS | 8 |

## 1. T2c: the style-only port

Commits `9adc036` (the three modules `main.py` never imports dropped, A-073; `requirements.txt` pinned)
and `6c3488f` (flake8 fixes). The verbatim files were copied to `<scratch>/t2/verbatim` before the edits.

```bash
cd <scratch>/t2/verbatim && flake8 *.py | wc -l
```
```text
106
```
After T2c (and still at the end of T2):
```bash
flake8 contour_algorithm/ | wc -l
```
```text
0
```
"No logic change" was checked by comparing the Python ASTs, after removing line numbers, docstrings
and bare strings, and turning a placeholder-free f-string into its constant
(`<scratch>/t2/ast_same.py`; it reports DIFFERENT for a changed constant, `beta=0.10 -> 0.11`, and for
`i == 126 -> i == 125`):
```bash
python3 <scratch>/t2/ast_same.py <scratch>/t2/verbatim contour_algorithm active_contour_snake.py contour.py create_files_shoes.py distance_extremities.py extreme_values_x_y.py globals.py main.py remove_noise.py
```
```text
active_contour_snake.py: same program
contour.py: same program
create_files_shoes.py: same program
distance_extremities.py: same program
extreme_values_x_y.py: same program
globals.py: same program
main.py: same program
remove_noise.py: same program
```
`tests/run_all.sh` lints `contour_algorithm/` since T2c (the exclusion of A-064 is deleted).

## 2. T2a: the profile file and its accessors

`config/datasets.json` (both datasets; keys starting with `_` are comments), `contour_algorithm/profiles.py`
(`env`, `load_profile`, `Profile`), `statistical_model/R/profile.R` (`rac_env`, `rac_profile`,
`rac_analysis_shoes`, `rac_path`, `rac_model_path`, `rac_image_path`, `rac_write_csv`, `rac_new_output`,
`rac_model_feature`, `rac_distance_impl`). Schema additions to plan 4.3: A-074.

R (`tests/r/test_profile.R`, from the final suite run of section 8):
```text
PASS rac_profile() leaves .Random.seed unchanged (jsonlite loaded by it)
PASS OLD profile values identical() to the legacy literals (doubles)
PASS OLD paths are the legacy strings; OLD CSV line endings as committed
PASS OLD analysis shoes 1-126, 128-387 (integer)
PASS NEW profile: 255 x 367, 631 shoes, the OLD prototype frame 307 x 395
PASS NEW outputs (18 files, 5 folders) namespaced; none equals or lies inside an OLD output or a tracked file
PASS RAC_DATASET: unset and empty give old, new gives new, others error
PASS rac_env(): unset and "" give the default for every RAC_* variable
PASS RAC_PROFILE_FILE selects another profile file; empty means default
PASS rac_write_csv: CRLF for OLD dataCC, LF for NEW, folders created
PASS rac_new_output: refuses an existing OLD output, NEW may be rewritten
PASS config.R: OLD MEAN_OFFSET -4.614310784; without the pixel-count file OLD falls back to log(100/10615), NEW is NA with a warning; MODEL_FEATURE from RAC_MODEL_FEATURE
ALL PASS test_profile
```
Python (`tests/python/test_profiles.py`, 19 tests: OLD legacy constants and names, the OLD outputs are
tracked files, NEW namespacing, no collision, selection, `RAC_PROFILE_FILE`, validation, and the CLI and
runner refusals) passes in every suite run (section 8).

**Negative controls of the namespacing and collision tests.** Each mutation edits one NEW path of a
copy of the profile (`<scratch>/t2/mut/*.json`): `dataCC` = the OLD `processed_data/dataCC.csv`;
`images_dir` = `images`; `knit_dir` = `statistical_model`; the contour without its `_new` suffix;
`images_dir` = `images/new` (inside the OLD folder).
```bash
for m in dataCC images_dir knit_dir contour_suffix images_inside; do printf '%-15s ' "$m"; RAC_PROFILE_FILE=<scratch>/t2/mut/$m.json python3 -B -m unittest tests.python.test_profiles.New 2>&1 | grep -E "^FAILED|^OK"; done
```
```text
dataCC          FAILED (failures=2)
images_dir      FAILED (failures=35)
knit_dir        FAILED (failures=3)
contour_suffix  FAILED (failures=1)
images_inside   FAILED (failures=17)
```
Every mutation is caught; the real profile passes.

## 3. T2d: the Python step 0 driven by the profile

Commit `69dc980`. `globals.py` is gone; every module takes the profile; `io_shoes.read_shoes` /
`write_shoes` (binary CRLF), the skip list computed from the locations (`locations.record_skip_idx0`,
A-074), the CLI refusals (A-049, A-075), output-identical rewrites (A-078). `get_snake_image` is **not**
changed: its `(W, H)` canvas plus transpose is a double swap, correct for both frames (plan F15);
`test_snake_geometry` locks it (a transposed drawing would not touch the image).

### 3.1 OLD step 0 on WSL = Tier B
Scratch driver `<scratch>/t2/t2d_step0.sh` (a copy of the work tree, the contour and the eight
`images/saved` files deleted first and listed, `python -m contour_algorithm.main`, the venv copy of
A-056):
```bash
bash <scratch>/t2/t2d_step0.sh <scratch>/t1/venv_copy/bin/python
```
```text
== exit 0, seconds 378.596349459
== contour sha256 (Tier B CRLF e18d50df...)
e18d50df5da9599440c99f9fbb6f23ce98bdc695479a4078c06feb96b9b1b7c4  <scratch>/t2/t2d_step0_yEkQzF/repo/data/contour_Active_Contour.txt
== intermediates vs Tier B
all match
== npy/png count under images/
1556
```
Per step (from its log): `create: 2.6 s`, `contour: 20.3 s`, `snake: 353.2 s`, `distance: 0.1 s`;
`Active contour processing complete - 387 shoes, 386 contour records (shoes without a record: [127])`.
The live check on that folder:
```bash
RAC_REGRESS_PY_RUN=<scratch>/t2/t2d_step0_yEkQzF MPLBACKEND=Agg <scratch>/t1/venv_copy/bin/python -B -m unittest tests.python.test_snake_old_regression -v
```
```text
test_full_rerun_recorded (tests.python.test_snake_old_regression.SnakeOld.test_full_rerun_recorded) ... ok
test_full_run_folder (tests.python.test_snake_old_regression.SnakeOld.test_full_run_folder) ... ok
test_full_run_intermediates (tests.python.test_snake_old_regression.SnakeOld.test_full_run_intermediates) ... ok
test_inputs (tests.python.test_snake_old_regression.SnakeOld.test_inputs) ... ok
test_platform_sensitive_records (tests.python.test_snake_old_regression.SnakeOld.test_platform_sensitive_records) ... [ WARN:0@3.954] global loadsave.cpp:1617 imencodeWithMetadata Unsupported depth image for selected encoder is fallbacked to CV_8U.
ok
test_reproduces_committed_records (tests.python.test_snake_old_regression.SnakeOld.test_reproduces_committed_records) ... ok
----------------------------------------------------------------------
Ran 6 tests in 8.941s
OK
```
The RAC-pixel CSV (`images/saved/locations_new.csv`, not in the Tier B lists) against both legacy WSL runs:
```bash
cmp <scratch>/t1rv2/legacy_py_rJehu1/images/saved/locations_new.csv <scratch>/t2/t2d_step0_yEkQzF/repo/images/saved/locations_new.csv && echo identical
cmp <scratch>/t1/legacy_py_MXmkvc/images/saved/locations_new.csv <scratch>/t2/t2d_step0_yEkQzF/repo/images/saved/locations_new.csv && echo identical
```
```text
identical
identical
```

### 3.2 The OLD gallery with the ported snake
`tests/legacy/old_snake_gallery.py` and `diag_snake_platform.py` now drive the ported package (OLD
profile, images folder moved to their work folder). On WSL (exit 1 by design: the 8 platform-sensitive
shoes):
```bash
MPLBACKEND=Agg <scratch>/t1/venv_copy/bin/python -B tests/legacy/old_snake_gallery.py --out <scratch>/t2/gallery_wsl
for f in $(ls <scratch>/t1rv2/consol/gallery_after/); do cmp -s <scratch>/t1rv2/consol/gallery_after/$f <scratch>/t2/gallery_wsl/$f && echo "same $f" || echo "DIFF $f"; done
```
```text
shoes: 68; sheets: 9; re-run differs from the committed record for: [11, 21, 80, 152, 176, 221, 349, 354]
same gallery_shoes_old.csv
same prototype_old.png
same sheet_old_01.png
[... sheet_old_02.png to sheet_old_08.png: same ...]
same sheet_old_09.png
```
Under venv-wind (Python 3.13.14, `sys.base_prefix` = `C:\Program Files\WindowsApps\PythonSoftwareFoundation.Python.3.13_3.13.3824.0_x64__qbz5n2kfra8p0`, A-071):
```bash
venv-wind/Scripts/python.exe -B tests/legacy/old_snake_gallery.py --out '\\wsl.localhost\Ubuntu\...\scratchpad\t2\gallery_win'
for f in $(git ls-files docs/qa/sheets_old/ | xargs -n1 basename); do ... cmp -s docs/qa/sheets_old/$f <scratch>/t2/gallery_win/$f ...; done
```
```text
shoes: 68; sheets: 9; re-run differs from the committed record for: []
same gallery_shoes_old.csv
same prototype_old.png
same sheet_old_01.png
[... sheet_old_02.png to sheet_old_08.png: same ...]
same sheet_old_09.png
(not produced by the script) snake_metrics_old.csv
byte-identical: 11
```
**Looked at** `sheet_old_01.png` of the venv-wind build (byte-identical to the committed sheet): shoes
3, 7, 9, 11, 12, 21, 23, 24. The red dashed ellipse encloses every print; the first blue snake contracts
onto the print and the second follows toe, arch and heel. In panel 3 the stickers beside the toe are red,
removed by the mask (a small square left of the toe on 3, a block right of the toe on 7, a bar on 12 and
on 24), and none lies inside a blue contour; shoe 9 shows the K1 strip cut on its left edge, shoe 11 the
partial print. The same as `docs/qa/snake-qa.md`, sheet 1.

### 3.3 Fast tests of the port
`test_io_shoes` (the legacy text parse on every record of both contact files and the exact legacy
expression on a sample; strict reader; CRLF round trip; the thesis snakes written with the OLD skip list
give the committed contour bytes; record mapping incl. a synthetic profile with `shoes_without_racs [2]`
and `excluded_shoes [5]`), `test_snake_geometry` (both frames), `test_locations` (OLD 13,287 RACs / 386
shoes / skip 126; NEW 20,013 / 631 / none; NEW raw / 2 = the 2023 file exactly), `test_sentinel_profile`
(section 4.2) and the CLI refusals in `test_profiles.Cli` (run in a temporary copy, so a broken guard could
not touch the repo). One test needed a correction while writing it: the snake image is the direct
`(H, W)` drawing plus a fringe of at most 1 px (cv2's thick-line raster is not symmetric under
transposition: 1,625 vs 1,445 px), so the test asserts containment within 1 px and no overlap with a
transposed drawing, not equality.

**Looked at** the step-0 outputs of the sentinel fixture (`<scratch>/t2/sentinel_view/sentinel_step0.png`):
the blue snakes enclose each synthetic sole with a 2-3 px margin, shoe 2 is mirrored (its bump moved from
the right to the left), the 4 x 4 stamps are in the `sum >= 2` image but outside the snake-filled
prototype mask and outside every contour.

## 4. T2b: the R steps and the runners

Commit `012753f`. `config.R` reads the profile (`P <- rac_profile(root = ROOT_PATH)`; the explicit root was
needed: as a default argument `ROOT_PATH` is looked up where `rac_profile` is defined, which a test that
sources `config.R` into its own environment exposed) and `MODEL_FEATURE` from `RAC_MODEL_FEATURE`. The
six Rmds take every value and path from `P`; steps 2, 4, 5, 6 use the prototype frame `P$prototype`.
`tools/run_pipeline.sh` and `tests/regress_old.sh` are new; `tests/legacy/run_windows_r_step3.sh`
archives `config/datasets.json`.

### 4.1 Step 1 through the profile = Tier A
```bash
RAC_SCRATCH=<scratch>/t2 bash tests/regress_old.sh --steps 1 --keep --py <scratch>/t1/venv_copy/bin/python
```
```text
result  check                                  detail
PASS    pipeline run                           every step exit 0, every output regenerated
PASS    step 1 all_cont.csv = Tier A           data/all_cont.csv sha256 d582cf502184...
PASS    step 1 dataCC.csv = Tier A             processed_data/dataCC.csv sha256 cc4a476976ae...
PASS    step 1 shoe_pixel_counts.csv = Tier A  processed_data/shoe_pixel_counts.csv sha256 24bbd19cff59...
INFO    step 1 shoe_codes.csv                  no committed file yet (written by T2)
timings (s):
step   seconds        exit
step1  110.131963381  0
ALL PASS
```
The new `processed_data/shoe_codes.csv` from that run (committed in T2b; sha256 `3d6c09fe...`):
code 1-126 = shoe 1-126, code 127 = shoe 128, ..., code 386 = shoe 387 (387 lines with the header).

### 4.2 Sentinel tests (A-035, A-050)
Python `tests/python/test_sentinel_profile.py` runs the real step 0 on the fixture of
`tests/fixtures/make_sentinel.py` (6 shoes of 40 x 60 px, dataset `new` of its own profile file) in a
temporary root: the superposition is `sum >= 2` and named `superposed_min_2_new.npy`, only shoe 2 is
flipped, `init_snake` is the ellipse (30, 20) / (25, 15) with 50 points, the contour file has 4 records of
40 * 60 + 2 bytes (shoe 4 without RACs, shoe 5 excluded), COL/ROW of every RAC are the pixels the fixture
placed it on (20 px per unit), every written file is in `images_new/` or `data/new_shoes/` and ends with
`_new`; and the committed fixture equals a fresh run of the generator. R `tests/r/test_profile_sentinels.R`
(from the final suite run):
```text
PASS skip list: shoe 4 (no RACs) and 5 (excluded) have no code; codes 1-4
PASS stamp threshold 2, sweep bound 40, R flip [3]: all_cont = the sweep of sum >= 2 (925 px, 16 removed)
PASS n_controls 5: 5 controls per shoe
PASS RAC pixels = aspix of P$coords (15 case pixels, one duplicate)
PASS control coordinates (c - col_shoe/2)/20 and -(r - row_shoe/2)/20
PASS seed 7: two renders identical; seed 8 draws other controls
PASS every distance_shape (10 values) is a half-width of the prototype in its own 44 x 66 frame
PASS step 2 legacy and vectorized: byte-identical CSVs on the fixture
PASS mutation checks: step 2 with P$col_shoe as prototype width fails (render error); with the data scale fails (values outside the prototype)
PASS a contour file with one record too few stops step 2 with an error
ALL PASS test_profile_sentinels
```

### 4.3 No dataset literal in code (A-079)
```text
== Rscript tests/r/test_no_hardcoding.R
PASS scanner: comments and prose skipped, exemption marker, each rule
PASS no dataset literal in 25 R/Rmd files (4 OLD-only files allowed)
PASS every allowlisted file still needs its entry
ALL PASS test_no_hardcoding
```
`tests/python/test_no_hardcoding.py` (Python and shell, 3 tests) passes. The scans found and fixed, in
pipeline code: the 8-bit value 255 of the snake drawing (now `WHITE = 255  # rac: literal-ok`) and the
file name in a `config.R` warning; in a new test, the lattice heights 395 and 367 (now from the profiles).
Not scanned: `docs/qa/T0/probes/` (frozen T0 evidence scripts) and the profile files.

### 4.4 Runner refusals
`test_profiles.Cli` (in a temporary copy): `python -m contour_algorithm.main` exits 2 with
`RAC_PROFILE_FILE` set (A-049), with `RAC_DATASET=foo`, with bad `--steps`, and for an OLD run whose
contour exists (A-075), each time without writing a file; `tools/run_pipeline.sh` and
`tests/regress_old.sh` exit 2 with `RAC_PROFILE_FILE` set (no run folder made), `run_pipeline.sh` with an
unknown dataset or `--steps 9`.

## 5. T2e: the manual Wald test in step 5

Commit `82c1661`. Step 5 no longer loads car; `wald_all_spatial()` runs (with car when installed) and
`processed_data/wald_test.csv` is written. Step 5 alone, in scratch, on the committed models:
```bash
RAC_SCRATCH=<scratch>/t2 bash tests/regress_old.sh --steps 5 --keep --py <scratch>/t1/venv_copy/bin/python
cat <scratch>/t2/regress_old_L7gAzU/repo/processed_data/wald_test.csv
grep -o "Wald test, all[^<]*" <scratch>/t2/regress_old_L7gAzU/repo/statistical_model/statistical_tests_5.html
grep -o "car::linearHypothesis: not run[^<]*" <scratch>/t2/regress_old_L7gAzU/repo/statistical_model/statistical_tests_5.html
```
```text
PASS    pipeline run          every step exit 0, every output regenerated
INFO    CI_shoe_cuts.pdf      drawn from the committed models; the Tier B PDFs come from the WSL refit (run step 3 too to compare them)
[... the same INFO for CI_cut_110.pdf, CI_cut_190.pdf, CI_cut_250.pdf ...]
INFO    step 5 wald_test.csv  no committed file yet (written by T2e)
step5  24.387469281  0
ALL PASS
"model","W","df","p","method","vcov","W_rx","p_rx","W_car","p_car"
"NEW_X_NS_XY",428.693335001072,24,9.42581267047078e-76,"manual","hessian",427.767419273715,1.46251348275581e-75,NA,NA
Wald test, all 24 spatial coefficients = 0 (manual): W = 428.6933, df = 24, p = 9.43e-76
car::linearHypothesis: not run (car not installed)
```
That file was the committed `processed_data/wald_test.csv` of T2 (replaced in the T2 review fixes by the
same line without the two car columns, decision A-082). With car: `test_wald.R` under the Windows R
(car 3.1-3) ends with `PASS car::linearHypothesis W = 428.693335 equals the manual W` / `ALL PASS
test_wald`, and the refactored step 5 knitted there (`<scratch>/t2/win_step5`, a copy of `c9d782b`, whose
step 5 is that of `82c1661`) writes
```text
"NEW_X_NS_XY",428.693335001072,24,9.42581267047078e-76,"manual+car","hessian",427.767419273715,1.46251348275581e-75,428.69333500107,9.42581267047992e-76
## Wald test, all 24 spatial coefficients = 0 (manual+car): W = 428.6933, df = 24, p = 9.43e-76
##   car::linearHypothesis: W = 428.6933, p = 9.43e-76
```
That Windows run also showed the file with CRLF although the profile asks for `\n`: R on Windows writes
a file name in text mode. `rac_write_csv` now writes through a binary connection (decision A-080); on
Linux the bytes are the same either way:
```text
x86_64-pc-linux-gnu path   \n    CR=0 LF=3
x86_64-pc-linux-gnu binary \n    CR=0 LF=3
x86_64-pc-linux-gnu path   \r\n  CR=3 LF=3
x86_64-pc-linux-gnu binary \r\n  CR=3 LF=3
x86_64-w64-mingw32 path   \n    CR=3 LF=3
x86_64-w64-mingw32 binary \n    CR=0 LF=3
x86_64-w64-mingw32 path   \r\n  CR=6 LF=3
x86_64-w64-mingw32 binary \r\n  CR=3 LF=3
```
(`<scratch>/t2/eolcheck/eol.R`: two rows plus the header written by `write.csv` to a file name and to a
`"wb"` connection, then CR and LF counted.)

## 6. Vectorized step 2 (optional part of the task; A-076)

Commit `c9d782b`. `statistical_model/R/distances.R` (the plan's T5 interface), selected by
`RAC_DISTANCE_IMPL`, default `vectorized` after this proof:
```bash
RAC_DISTANCE_IMPL=vectorized RAC_SCRATCH=<scratch>/t2 bash tests/regress_old.sh --steps 2 --keep --py <scratch>/t1/venv_copy/bin/python
```
```text
result  check                                     detail
PASS    pipeline run                              every step exit 0, every output regenerated
PASS    step 2 dataCC_distance_temp.csv = Tier A  processed_data/dataCC_distance_temp.csv sha256 43d7c9b87946...
PASS    step 2 dataCC_distance.csv = Tier A       processed_data/dataCC_distance.csv sha256 f0e697ac6f79...
timings (s):
step   seconds       exit
step2  51.444158977  0
ALL PASS
```
The knit of that run printed `## distance implementation: vectorized`, and the run took 51.4 s instead of
about 19 minutes. *(Corrected in the T2 review fixes, reproducibility finding 4: this paragraph first offered
`grep -c "row N" .../logs/step2.log` = 0 as evidence, but rmarkdown sends `message()` to the knit HTML, not
to the log, so the legacy loops give 0 there too. The discriminating evidence is the HTML: the vectorized
run's `dataCC_distance_2.html` has 0 progress messages `row N.<number>` (its 2 `row N` matches are code
echoes), the legacy-loop run `regress_old_rj6KaH` has 102 (51 per loop), plus the timing; commands and output
in `docs/tests/T2-review-fixes-results.md` section 6.)* `tests/r/test_distances_vectorized.R`:
```text
PASS float window (F14): OLD 160 of 392 three-row pairs with the data row above, 161 below; NEW 152 and 151 of 364; the round trip changes 263 of 395 and 245 of 367 y values; horiz_dist_vec admits the same pairs
PASS min_dist and horiz_dist: the legacy loops of the Rmd and the vectorized functions identical() on 406 OLD rows (6 without a contour point within 0.01 in y)
PASS distance_shape and new_x: the legacy loop and distance_shape_vec() identical() (228 distinct y)
SKIPPED whole OLD step 2 (set RAC_SLOW_TESTS=1; tests/regress_old.sh --steps 2 checks it on every gate run)
ALL PASS test_distances_vectorized
```
With `RAC_SLOW_TESTS=1` (73 s): `PASS whole OLD step 2, vectorized: both CSVs have the Tier A sha256`.
The legacy loops in the test are the text of the Rmd chunks, evaluated with the CSV writer stubbed, so
the test compares the real legacy code with the functions. The plan's NEW check (2,000 NEW rows, legacy
vs vectorized) waits for a NEW contour file (T4, T5).

## 7. The gates

### 7.1 Full OLD regression on WSL
**First attempt: two chained 0-6 gates failed (a flaw of my gate, not of the code).** Both ran all
steps in one copy: at `82c1661` (step 2 with the legacy loops) and at `c9d782b` (vectorized step 2):
```bash
RAC_SCRATCH=<scratch>/t2 bash tests/regress_old.sh --steps 0-6 --keep --py <scratch>/t1/venv_copy/bin/python
```
```text
== regress_old.sh --steps 0-6: <scratch>/t2/regress_old_rj6KaH
result  check                                          detail
PASS    pipeline run                                   every step exit 0, every output regenerated
PASS    step 0 contour = Tier B (CRLF)                 data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B                  1556 npy/png files, all equal
PASS    step 1 all_cont.csv = Tier A                   data/all_cont.csv sha256 d582cf502184...
PASS    step 1 dataCC.csv = Tier A                     processed_data/dataCC.csv sha256 cc4a476976ae...
PASS    step 1 shoe_pixel_counts.csv = Tier A          processed_data/shoe_pixel_counts.csv sha256 24bbd19cff59...
PASS    step 1 shoe_codes.csv = committed              processed_data/shoe_codes.csv sha256 3d6c09fe66e1...
FAIL    step 2 dataCC_distance_temp.csv = Tier A       processed_data/dataCC_distance_temp.csv sha256 352d43d400a0..., expected 43d7c9b87946...
FAIL    step 2 dataCC_distance.csv = Tier A            processed_data/dataCC_distance.csv sha256 2ffaf75dbf92..., expected f0e697ac6f79...
FAIL    step 3 models identical() to Tier B            see logs/dump_models.txt, logs/compare_models.txt
FAIL    NEW_X_NS_XY_SHOE.pdf normalized = Tier B       b10d3343e7d8..., expected b99d794c1c9a...
[... the seven other PDFs: FAIL in the same way ...]
FAIL    step 5 Wald W = Tier B (WSL refit)             see logs/wald_check.txt
PASS    live check test_snake_old_regression           logs/live_snake.txt
FAIL    live check test_old_regression.R               logs/live_r.txt
FAIL    live check test_live_r_pdfs                    logs/live_pdfs.txt
step0       978.934798638   0
step1       117.722885611   0
step2       1193.192766538  0
step3_glmm  255.888114248   0
step3_cml   239.319838616   0
step4_glmm  15.868447545    0
step4_cml   15.341882731    0
step5       25.096397135    0
step6       19.166860692    0
SOME CHECKS FAILED (run folder kept)
```
The run at `c9d782b` (`<scratch>/t2/regress_old_aZqirz`) gave the same table, with the **same** step-2
hashes (`352d43d4...`, `2ffaf75d...`), and `step2 22.135104254` seconds. In one copy, step 2 read the
contour that step 0 had just written, which on WSL is Tier B (A-060), while every step-2 to step-6
baseline was computed from the committed contour. Checked, not assumed:
```bash
Rscript -e '...' # compare processed_data/dataCC_distance.csv with both runs, row by row
<venv>/bin/python -B - # the shoe codes of the 30 Tier B contour records that differ (contour_linux_diff.npz)
```
```text
gate1 vs gate2 identical: TRUE
rows differing: 2722 of 51849 ; shoe codes: 29
 [1]  11  21  26  62  69  80  96 117 141 151 156 162 173 175 187 191 202 206 220
[20] 234 265 285 322 339 348 353 369 381 383
Tier B contour records differing from Tier A: 30
as dataCC shoe codes (record k = code k+1): [8, 11, 21, 26, 62, 69, 80, 96, 117, 141, 151, 156, 162, 173, 175, 187, 191, 202, 206, 220, 234, 265, 285, 322, 339, 348, 353, 369, 381, 383]
step-2 codes with differing rows: 29 all among the 30: True
contour-different codes with identical step-2 rows: [8]
```
So the differences are confined to the shoes whose WSL contour differs, and the legacy and vectorized
step 2 agree byte for byte on this second input as well (A-076). `regress_old.sh` now runs such a
request as two runs, `--steps 0` and `--steps 1-6`, each from the committed inputs (A-081, commit
`ed68998`).

**The gate (final code).**
At `ed68998` (the code of the final tree; the work tree differed only in docs, recorded in the run's
`source.txt`):
```bash
RAC_SCRATCH=<scratch>/t2 bash tests/regress_old.sh --steps 0-6 --keep --py <scratch>/t1/venv_copy/bin/python
```
```text
regress_old.sh: step 0 rewrites the contour that steps 2-6 read; on WSL it is Tier B, and their baselines come from the committed contour, so this runs as two runs: --steps 0 and --steps 1,2,3,4,5,6 (A-081)
<scratch>/t2/regress_old_zzg9CP
== regress_old.sh --steps 0: <scratch>/t2/regress_old_zzg9CP
result  check                                 detail
PASS    pipeline run                          every step exit 0, every output regenerated
PASS    step 0 contour = Tier B (CRLF)        data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B         1556 npy/png files, all equal
PASS    live check test_snake_old_regression  logs/live_snake.txt
timings (s):
step   seconds        exit
step0  339.981398335  0
ALL PASS
<scratch>/t2/regress_old_EXeICT
== regress_old.sh --steps 1,2,3,4,5,6: <scratch>/t2/regress_old_EXeICT
result  check                                          detail
PASS    pipeline run                                   every step exit 0, every output regenerated
PASS    step 1 all_cont.csv = Tier A                   data/all_cont.csv sha256 d582cf502184...
PASS    step 1 dataCC.csv = Tier A                     processed_data/dataCC.csv sha256 cc4a476976ae...
PASS    step 1 shoe_pixel_counts.csv = Tier A          processed_data/shoe_pixel_counts.csv sha256 24bbd19cff59...
PASS    step 1 shoe_codes.csv = committed              processed_data/shoe_codes.csv sha256 3d6c09fe66e1...
PASS    step 2 dataCC_distance_temp.csv = Tier A       processed_data/dataCC_distance_temp.csv sha256 43d7c9b87946...
PASS    step 2 dataCC_distance.csv = Tier A            processed_data/dataCC_distance.csv sha256 f0e697ac6f79...
PASS    step 3 models identical() to Tier B            every field of the dump (logs/compare_models.txt)
PASS    NEW_X_NS_XY_SHOE.pdf normalized = Tier B       b99d794c1c9a...
PASS    CML_MODEL_SHOE.pdf normalized = Tier B         f79bf8e71c69...
PASS    CI_shoe_cuts.pdf normalized = Tier B           73b4093177d4...
PASS    CI_cut_110.pdf normalized = Tier B             b272df049df9...
PASS    CI_cut_190.pdf normalized = Tier B             1972d8dc93e6...
PASS    CI_cut_250.pdf normalized = Tier B             5c56923b2904...
PASS    pixel_inten_JASAup.pdf normalized = Tier B     f1fcbcfb7837...
PASS    difference_random_cml.pdf normalized = Tier B  8e18f4562914...
PASS    step 5 Wald W = Tier B (WSL refit)             W 427.7804472165, Tier B 427.7804472165, df 24
PASS    live check test_old_regression.R               logs/live_r.txt
PASS    live check test_live_r_pdfs                    logs/live_pdfs.txt
timings (s):
step        seconds        exit
step1       103.091590707  0
step2       20.415880900   0
step3_glmm  245.917432292  0
step3_cml   202.344915701  0
step4_glmm  12.989186773   0
step4_cml   12.929786624   0
step5       22.964925754   0
step6       18.110608111   0
ALL PASS
== regress_old.sh --steps 0-6 (as --steps 0 and --steps 1,2,3,4,5,6): ALL PASS
```
The R live check of that run (`logs/live_r.txt`) ends with
```text
PASS live rerun: exit 0 for every step; the five CSVs and both models were regenerated by the run (A-067)
PASS live rerun (tests/regress_old.sh): the five CSVs equal Tier A byte for byte
PASS live rerun: models identical() to Tier B in every field
ALL PASS test_old_regression
```
and `logs/compare_models.txt` has `identical=TRUE` with max|diff| 0 in all 22 fields (fixef n=25, vcov
and vcov_rx n=625, ..., wald_glmm, wald_glmm_rx, wald_cml). Step 2 ran the vectorized default here.
**Looked at** two of the regenerated figures: `NEW_X_NS_XY_SHOE.pdf` (the GLMM map on the prototype:
highest intensity, about 0.0015-0.0018, on the left forefoot, along the centre line and on the right side
of the midfoot; lowest, about 0.0005, at the toe tip and the heel edge) and `CI_cut_110.pdf` (CML and
Random bands almost on top of each other, peak about 0.00195 left of the centre, dip about 0.00115 right
of it, the widest band at the right edge); both as described for their Tier B twins in T1.

### 7.2 Step 3 under the Windows R (Tier A, A-065)
```bash
RAC_SCRATCH=<scratch>/t2 RAC_WINR_COMMIT=82c1661 bash tests/legacy/run_windows_r_step3.sh
```
```text
reference 79247d8:saved_models/NEW_X_NS_XY.rds sha256 ae670fd392cef406b4170aa2a1480fe4b5e9c6cc1969ef0e5df21aa7bcd9fb57 (Tier A)
fit       repo/saved_models/NEW_X_NS_XY.rds sha256 3baca3091e41fec73da7464074ea76abf37c500d3fc0b8af315daa4b443fd2a4
theta        identical same
beta         identical same
u            identical same
optinfo      identical same
[... devcomp, Gp, flist, cnms, lower, frame_data, resp_y, resp_mu, resp_eta, resp_weights, resp_offset, resp_wtres, X, Zt, Lambdat, fixef, vcov, vcov_rx, loglik, deviance, sigma2: identical same ...]
call         all.equal same
frame        all.equal same
RESULT 27 of 27 fields the same
```
`knit seconds 832.0`, `R version 4.4.3 (2025-02-28 ucrt) | lme4 1.1.37 | Matrix 1.7.2` (the step reads
`config/datasets.json`, archived from the commit). The `.rds` bytes differ (serialized environments, as
in T1).

### 7.3 Step 0 under venv-wind (Tier A, A-060, A-071, A-077)
```bash
RAC_SCRATCH=<scratch>/t2 RAC_WINPY_COMMIT=82c1661 bash tests/legacy/run_windows_python_step0.sh
```
```text
commit commit=82c166172a9d2940880791d3252c7935ae418d64
sys.version 3.13.14 (tags/v3.13.14:fd17997, Jun 10 2026, 13:03:48) [MSC v.1944 64 bit (AMD64)]
sys.base_prefix C:\Program Files\WindowsApps\PythonSoftwareFoundation.Python.3.13_3.13.3824.0_x64__qbz5n2kfra8p0
sys.executable C:\Users\mehes\Documents\repo\master_thesis_forensic_shoeprint\venv-wind\Scripts\python.exe
platform Windows-11-10.0.26300-SP0
step 0 exit 0, outputs written: yes
contour sha256 ca8a07f2a46614a14383a8017b688663caba8350c3ea41c51792d8ebd0ec7e56 (Tier A ca8a07f2a46614a14383a8017b688663caba8350c3ea41c51792d8ebd0ec7e56)
RESULT contour = Tier A
RESULT list_matrices.npy = Tier B
RESULT old_freq_min_18.npy = Tier B
RESULT freq_min_18.npy = Tier B
RESULT list_contour.npy = Tier B
INFO active-contour_all.npy = the thesis run of 2025-11-13
```
920.2 s (`create: 17.0 s`, `contour: 94.5 s`, `snake: 796.8 s`, with two other gates running). From the
raw contacts to the contour, the ported code under the platform of the committed contour writes it byte
for byte, and all 387 snakes equal the thesis run that wrote it.

### 7.4 Step 1 under the Windows R (cross-platform check of A-080)
The refactored step 1 (work tree after the A-080 fix, committed as `cf740fa`) knitted with the Windows
R 4.4.3 (`knitr::knit`) in `<scratch>/t2/win_step1` (inputs from HEAD):
```bash
for f in data/all_cont.csv processed_data/dataCC.csv processed_data/shoe_pixel_counts.csv processed_data/shoe_codes.csv; do a=$(sha256sum < $f | cut -c1-64); b=$(sha256sum < <scratch>/t2/win_step1/repo/$f | cut -c1-64); [ "$a" = "$b" ] && echo "same $f ${b:0:12}" || echo "DIFF $f $a $b"; done
```
```text
same data/all_cont.csv d582cf502184
same processed_data/dataCC.csv cc4a476976ae
same processed_data/shoe_pixel_counts.csv 24bbd19cff59
same processed_data/shoe_codes.csv 3d6c09fe66e1
```
(`knit seconds 166.5`.) The same seed and sampling give the same case-control sample on both R builds,
and the binary writer gives the committed CRLF bytes on Windows too.

### 7.5 NEW step 1 on the real NEW data (smoke test in scratch)
The NEW outputs belong to T3-T5; this only checks that the NEW profile drives step 1 on the real data
and writes only namespaced files (`<scratch>/t2/new_step1_smoke.sh`: a copy of the work tree,
`RAC_DATASET=new tools/run_pipeline.sh --steps 1`, the files listed before and after):
```text
exit 0
new files:
./logs/knit/new/dataCC_1_new.html
./logs/new/step1_new.log
./processed_data/new/all_cont_new.csv
./processed_data/new/dataCC_new.csv
./processed_data/new/shoe_codes_new.csv
./processed_data/new/shoe_pixel_counts_new.csv
```
The 24 Tier A files of the copy still verified (`sha256sum --quiet -c committed_79247d8.sha256`), and:
```text
rows 83090 cases 19990 shoes 631 controls/shoe 100-100
shoe codes 631 TRUE
all_cont dims 367 255 pixels 28948
pixel counts p5/p50/p95 4864.5 8921 14284.5 min 1344
x range -0.175 0.2383333 y range -0.515 0.5183333
```
19,990 case pixels and 83,090 rows are the plan's expectation with the generalized legacy mapping (F2,
T5 step 1); the contact pixels per shoe are close to the raw counts of F24 (4,876 / 8,924 / 14,286; the
stamp mask removes a few, the RAC pixels add a few). The provisional stamp threshold 13 was used (T3
decides it).

## 8. Fast suite

```bash
bash tests/run_all.sh old
```
```text
== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS        59s  python unittest discover tests/python
PASS         4s  Rscript tests/r/test_baseline_committed.R
PASS        21s  Rscript tests/r/test_compare_glmm_fits.R
PASS         3s  Rscript tests/r/test_compare_models.R
PASS         7s  Rscript tests/r/test_distances_vectorized.R
PASS         2s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS         0s  Rscript tests/r/test_profile.R
PASS        33s  Rscript tests/r/test_profile_sentinels.R
PASS         8s  Rscript tests/r/test_run_manifest.R
PASS         1s  Rscript tests/r/test_step5_variant.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         0s  flake8 (all Python files)
PASS         4s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS
```
`Ran 91 tests in 26.594s`, `OK (skipped=3)` (the three live checks without a run folder);
`flake8: 46 files`, `shellcheck: 12 files`; 2 min 29 s wall. `bash tests/run_all.sh new` exits 2
(`usage: bash tests/run_all.sh [old]`): there is no NEW output to check yet.

## 9. Timings

| What | Seconds | Note |
|---|---|---|
| Ported step 0, OLD, WSL | 378.6 | idle machine: create 2.6, contour 20.3, snake 353.2, distance 0.1 (T1 legacy: 509 with plotly HTML) |
| Ported step 0, OLD, WSL (final gate) | 340.0 | |
| Ported step 0, OLD, venv-wind | 920.2 | two gates running at the same time |
| Step 1, OLD | 103.1-121.1 | (T1: 141.8) |
| Step 2, OLD, vectorized | 20.4-22.1 | in the gates; 51.4 in the separate proof run (loaded machine) |
| Step 2, OLD, legacy loops | 1,193.2 | in the first gate (T1: 1,133.8-1,387) |
| Step 3 GLMM / CML, WSL | 245.9 / 202.3 | final gate |
| Step 3 GLMM, Windows R | 834.4 (knit 832.0) | loaded machine (T1: 541-631) |
| Steps 4 (x2), 5, 6 | 13.0, 12.9, 23.0, 18.1 | final gate |
| Step 1, Windows R | 166.5 | knit |
| NEW step 1 (scratch smoke test) | 305.8 | loaded machine |
| OLD gallery, WSL / venv-wind | 124 / 133 | |
| `bash tests/run_all.sh old` | 149 | |

The snake's numpy/scipy use many threads (one step-0 process showed 950 % CPU), so runs that overlap
slow each other down severalfold; the results did not change (every run above compared equal).

## 10. Not reproduced, limits, open points
- On WSL the contour is Tier B (30 records differ from Tier A by about 1 px, A-060) and the GLMM refit is
  Tier B (A-055); the PDFs cannot be byte-compared with the Windows-made committed ones (F20). Each of the
  three has its Tier A evidence on Windows (sections 7.2, 7.3) or, for the PDFs, only within this machine.
- `processed_data/shoe_codes.csv` and `processed_data/wald_test.csv` are new OLD files (plan section 5);
  no committed OLD file changed (24 of 24 Tier A checksums verify in every suite run).
- *(Added in the T2 review fixes.)* **Not listed here at first, and wrong:** `wald_test.csv` as committed in T2
  was not reproducible across platforms. Its `method`, `W_car` and `p_car` columns depended on whether car
  is installed, so step 5 under the Windows R (car 3.1-3) wrote `"manual+car"` and the car values instead of
  `"manual"` and `NA`, and an in-place knit there rewrote the committed file before the first figure guard
  stopped it (reproducibility review, finding 1). Also, `regress_old.sh` compared `shoe_codes.csv` and
  `wald_test.csv` with the work-tree files, and no baseline list covered them. Fixed by decision A-082: the
  CSV has no car column, the guards run before anything is written, and both files are in
  `tests/baseline/old_added_t2.sha256`; evidence in `docs/tests/T2-review-fixes-results.md` section 1.
- The NEW profile values marked provisional (pixel scale, stamp threshold 13, superposition threshold 29,
  snake init) are T3/T4 decisions; nothing NEW was computed in T2 except on the sentinel fixture.
- The plan's NEW legacy-vs-vectorized check of step 2 needs the NEW contour (T4/T5).
