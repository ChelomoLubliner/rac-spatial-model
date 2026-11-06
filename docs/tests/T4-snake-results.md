# T4 results: snake adaptation and QA on the 631 NEW shoes

**Date:** 2026-11-06. **Task:** T4-snake (plan task T4). **Branch:** `feature/new-shoes-pipeline`. **Commits:** `1771960` (code, profile, erase list, overrides, tests), `e758dab` (NEW contour and QA outputs), `8c5f6b9` (contour tests, 2023 cross-check), then the docs commit. Decisions A-091 to A-098 (`docs/decisions.md`). Visual review: `docs/qa/snake-qa.md` (NEW section). Every number below is real output of the named command; `<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`, `VPY` = the thesis venv copied to the Linux filesystem in T1 (`<scratch>/t1/venv_copy/bin/python`, Python 3.12.3, the same packages as the thesis venv on `/mnt/c`; the official contour was rebuilt with the `/mnt/c` interpreter byte for byte, section 8).

## 1. Summary

| Item | Result |
|---|---|
| NEW contour | `data/new_shoes/contour_Active_Contour_new.txt`, 631 records (no shoe skipped or excluded), CRLF stride 93,587, sha256 `88d559334a8c5f7b...` |
| QA pass rate | **619 of 631 shoes (98.10%) pass every band** (target >= 97%); the 12 flagged shoes are reviewed: 1 `override` (shoe 8, also on the fallback), 11 `ok_after_review`; none excluded |
| What changed for NEW only | one OpenBLAS thread (A-092); first snake on the cleaned shoe closed with a disk of radius 10 (A-094); erase list of 25 frame-artefact rectangles on 8 shoes (A-095); cleaning mask from >= 18 shoes, not 29 (A-096); closing radius 24 on 9 shoes (A-097); init ellipse = the 2023 values (A-019 confirmed) |
| Stickers | no police-type sticker on any NEW print; frame artefacts overlapping the mask erased (8 shoes), the rest removed by the cleaning; none survives in a cleaned shoe or a contour (looked at: all 13 cleaned and 13 final-snake sheets) |
| OLD regression | `regress_old.sh --steps 0` ALL PASS (contour = Tier B, 1,556 intermediates = Tier B, live check) and `--steps 1` ALL PASS (three Tier A CSVs and `shoe_codes.csv` byte-identical), both at `e758dab` |
| Tests | `bash tests/run_all.sh` ALL PASS at `8c5f6b9`: 172 Python tests (3 skipped live checks), 16 R scripts, flake8, shellcheck, work tree unchanged |
| Platform | a venv-wind (Windows) build of the same commit differs in 13 of 631 records (mean distance at most 1.24 px, max 3.6 px); everything before the snake is identical (A-098) |

## 2. The first NEW run (provisional profile) and the infrastructure

```bash
RAC_DATASET=new MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 $VPY -B -m contour_algorithm.main --steps create,contour --qa
```
```
step0 create: 1.8 s
step0 contour: 27.2 s
```
In 2023 the snake failed on the new shoes; the probable causes of plan risk R1 are gone in the ported code: the NEW run writes only below `images_new/` and `data/new_shoes/` with `_new` names, no index is skipped, and the shoe arrays, the mask and the ellipse are 367 x 255. The provisional profile (mask >= 29, the 2023 ellipse, the legacy snake) already ran without error; the work of T4 was quality, not crashes.

**OLD step 0 after the first code change** (`--qa`, `--jobs`, the snake record; same gate as at the end):
```bash
RAC_SCRATCH=<scratch>/t4 bash tests/regress_old.sh --steps 0 --keep
```
```
PASS    pipeline run                          every step exit 0, every output regenerated
PASS    step 0 contour = Tier B (CRLF)        data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B         1556 npy/png files, all equal
PASS    live check test_snake_old_regression  logs/live_snake.txt
step0  544.257599290  0
ALL PASS
```

### 2.1 The snake depends on the BLAS thread count (A-092)
```bash
TQDM_DISABLE=1 $VPY -B docs/qa/T4/probes/t4_thread_check.py <scratch>/t4 <scratch>/t4/thr_default.npz
OPENBLAS_NUM_THREADS=1 TQDM_DISABLE=1 $VPY -B docs/qa/T4/probes/t4_thread_check.py <scratch>/t4 <scratch>/t4/thr_one.npz
```
```
24 shoes 16.5 s, OPENBLAS_NUM_THREADS=None
24 shoes 13.8 s, OPENBLAS_NUM_THREADS=1
arrays 72 differ: ['c0', 'f0', 's0', 'c26', 'f26', 's26', 'f52', 's52', 'f78', 's78'] 52
max abs diff 13.208378521752252
```
52 of the 72 arrays (record, first and second snake of 24 NEW shoes, legacy snake) change when numpy's OpenBLAS runs one thread instead of the default 16. On OLD (one thread vs Tier B, the 16-thread WSL run; `docs/qa/T4/probes/t4_compare_records.py`):
```
records 386, identical 354, differing 32
differing: mean distance median 0.38 px, p90 1.16, max 1.78; max distance median 2.0, max 13.4
```
Forked snakes with the default threads (`t4_par_check.py`, 24 shoes): `serial 17.2 s for 24 shoes (0.71 s/shoe); forked x8 52.6 s; identical: True` (16 threads x 8 processes oversubscribe the 16 cores). The NEW profile therefore fixes one thread (`python.blas_threads: 1`); `main` sets `OPENBLAS_NUM_THREADS` and the snake step checks it (`numpy OpenBLAS threads: 1, snake jobs: 14` in every NEW log). OLD keeps the default, so the OLD gate is unchanged.

### 2.2 The R stamp mask in Python
```
(395, 307) (395, 307) 28609 28609 equal: True
NEW R mask t 8 29532 px; count>=t 29536
NEW R mask t 13 28948 px; count>=t 28949
```
`qa_snake.r_stamp_mask` (a port of the two sweeps of `dataCC_1.Rmd`) equals the committed OLD `data/all_cont.csv` (28,609 px; also `test_qa_snake.RStampMask`). On NEW the sweeps remove 4 px (t = 8) and 1 px (t = 13), as T0 found (F13).

## 3. QA metrics and bands (A-093)

`contour_algorithm/qa_snake.py`, from the step-0 outputs of `--qa` (nothing recomputed): coverage (cleaned contact inside the final snake's polygon), `coverage_fill` (inside the record's row-span fill), `coverage_r` (R's contact surface), RAC coverage, tightness (polygon / convex hull of the cleaned contact), self-intersections, total turning and largest turn, gap and cut distances, contour pixels, share outside the mask, border, bounding box. Bands: coverage >= 0.99; tightness in [0.9047, 1.15]; no self-intersection; turning <= 4.4622; largest turn <= 31.46 degrees; contour pixels in [553, 816]; no border contact; `coverage_fill` >= 0.9886; RAC coverage >= 0.9695; outside the mask <= 0.3393.

**OLD reference** (the committed contour; WSL snakes for the polygon metrics), written in a scratch copy:
```bash
cd <scratch>/t4/old_qa/repo && RAC_DATASET=old MPLBACKEND=Agg $VPY -B -m contour_algorithm.qa_snake --metrics --jobs 14
```
```
old: 386 shoes, 21 flagged, 365 pass every band (94.56%)
```
OLD percentiles used by the bands (`docs/qa/T4/old/snake_metrics.csv`): `coverage_fill` p1 0.9886, RAC coverage p1 0.9695, outside the mask p99 0.3393, tightness p1 0.9047, turning p99 4.4622, largest turn p99 31.458. The accepted OLD contours fall below the task's tightness 0.95 on 27 shoes (minimum 0.848: waisted soles whose contour follows the arch), hence the OLD p1 as the low end; the task's 0.95 count is reported beside it.

## 4. Prototype cleaning mask: 18 vs 29 (A-096)

```bash
RAC_DATASET=new OPENBLAS_NUM_THREADS=1 MPLBACKEND=Agg $VPY -B -m contour_algorithm.qa_snake --thresholds 13,18,24,29,36 --compare 18,29
```
```
threshold 13: mask 34749 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9973, removed 4334 px from 91 shoes
threshold 18: mask 35156 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9976, removed 4221 px from 87 shoes
threshold 24: mask 33959 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9968, removed 4595 px from 98 shoes
threshold 29: mask 33250 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9962, removed 5035 px from 105 shoes
threshold 36: mask 33091 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9963, removed 4943 px from 107 shoes
```
(`docs/qa/T4/new/mask_threshold_new.csv`, with the erase list applied; shoes with less than 0.99 of their contact kept: 12, 11, 14, 14, 14; the R stamp masks of thresholds 8 and 13 lie inside every mask; the frame-artefact shoes lose the same pixels at every threshold.) Both 18 and 29 pass the plan's criteria; 18 keeps more sole (section 6 for the snake scores), so 18 is taken against the plan's tie-break (A-096). Looked at: `docs/qa/sheets_new/prototype/prototype_mask_new.png` and the ring between the two masks on the 21 shoes with the most contact in it (`snake-qa.md`).

## 5. Erase list (A-095)

`data/new_shoes/sticker_masks_new.csv`, 25 rectangles on 148, 149, 186, 580, 582, 585, 586, 589, applied by Python (`stickers.py`) and R (`R/io.R`, step 1):
```
erase list: 25 rectangles on 8 shoes, 3406 contact pixels erased
```
(`docs/qa/T4/new/sticker_erased_new.csv`: 3,406 raw contact pixels erased, 1,647 of them inside the final mask.) With the list, the superposition >= 29 changed by 8 px and the prototype snake turned that into 668 px fewer mask pixels (33,877 -> 33,250), every RAC pixel still inside. R side, `Rscript tests/r/test_sticker_masks.R`:
```
PASS rac_apply_sticker_masks erases exactly the listed rectangles
PASS rac_read_sticker_masks: OLD none, NEW read, malformed lists stop
PASS NEW erase list: R erases 3406 contact pixels in 8 shoes, per rectangle as Python
PASS step 1 applies the erase list before the stamp mask and the RACs: shoe 1 loses 377 pixels; every count as expected; no control of shoe 1 in the rectangle
```

## 6. Snake variants (A-094)

Every variant on all 631 NEW shoes, bands of section 3 (`OPENBLAS_NUM_THREADS=1 T4=<scratch>/t4 $VPY -B docs/qa/T4/probes/t4_variant.py NAME 'JSON' 14 [old]`; NAME/JSON as in the table; `_threshold` builds another mask in scratch). Lines copied from each `summary.txt`:

| Images | Variant | Pass | Flagged | coverage < 0.99 | tightness < 0.95 | self-int |
|---|---|---|---|---|---|---|
| t29, no erase | legacy `{}` | 91.3% | 55 | 33 | 39 | 2 |
| t29, no erase | closing 4 | 93.7% | 40 | 16 | 40 | 1 |
| t29, no erase | closing 6 | 93.3% | 42 | 19 | 38 | 1 |
| t29, no erase | closing 8 | 94.6% | 34 | 13 | 34 | 1 |
| t29, no erase | first sigma 5 | 91.3% | 55 | 26 | 37 | 2 |
| t29, no erase | closing 6 + sigma 4 | 92.4% | 48 | 24 | 39 | 1 |
| t29, no erase | ellipse (182, 129) / (170, 98) | 91.4% | 54 | 24 | 35 | 2 |
| t29, no erase | closing 6 + that ellipse | 91.8% | 52 | 14 | 33 | 1 |
| t29, erase list | legacy | 89.9% | 64 | 30 | 36 | 2 |
| t29, erase list | closing 6, 8, 10, 12 | 92.6, 92.9, 93.7, 93.8% | 47, 45, 40, 39 | 16, 11, 6, 6 | 35, 30, 24, 21 | 1, 1, 0, 0 |
| t18, erase list | legacy | 92.7% | 46 | 30 | 37 | 2 |
| t18, erase list | **closing 10** | **96.8%** | 20 | 6 | 25 | 0 |
| t18, erase list | closing 12, 16, 20, 24 | 96.7, 96.8, 97.3, 97.3% | 21, 20, 17, 17 | 7, 7, 5, 4 | 23, 28, 18, 12 | 0 |
| OLD (committed images) | legacy, 1 thread | 94.3% | 22 | 9 | 26 | 2 |
| OLD | closing 10, 20, 24 | 94.6, 94.8, 95.9% | 21, 20, 16 | 2, 1, 1 | 17, 6, 6 | 1, 1, 0 |

The t29 runs with the erase list flag 16-21 shoes for `outside_mask_frac`: the tighter mask cuts real edges that the snake smooths over. How much the closing moves good contours (per-row width against the legacy snake on the same images, shoe means):
```
NEW t18_close10 vs legacy: mean width change +0.08 px (shoe median +0.17; wider 0.44, narrower 0.40); per-row |change| median 2.0 px; top outward +0.99, bottom outward +0.50
NEW t18_close16 vs legacy: mean width change +0.22 px (shoe median +0.26; wider 0.45, narrower 0.39); per-row |change| median 3.0 px; top outward +1.28, bottom outward +0.71
NEW t18_close20 vs legacy: mean width change +0.50 px (shoe median +0.44; wider 0.49, narrower 0.35); per-row |change| median 3.0 px; top outward +1.43, bottom outward +0.76
NEW t18_close24 vs legacy: mean width change +0.56 px (shoe median +0.61; wider 0.51, narrower 0.36); per-row |change| median 3.0 px; top outward +1.53, bottom outward +0.86
OLD o10_close10_1thread vs legacy: mean width change +0.14 px (shoe median +0.16; wider 0.44, narrower 0.38); per-row |change| median 2.0 px; top outward +0.67, bottom outward +0.48
OLD o20_close20_1thread vs legacy: mean width change +0.57 px (shoe median +0.58; wider 0.53, narrower 0.32); per-row |change| median 3.0 px; top outward +1.06, bottom outward +0.80
OLD o24_close24_1thread vs legacy: mean width change +0.77 px (shoe median +0.85; wider 0.54, narrower 0.30); per-row |change| median 3.0 px; top outward +1.16, bottom outward +0.87
```
Radius 10 does not widen the outline on average (+0.08 px), radius 20-24 do (+0.5 px, toe +1.5 px), so radius 10 is the profile value and 24 only a per-shoe fallback. How far the final NEW contours extend beyond the cleaned print (median over shoes, top, bottom, left, right: 7, 6, 7, 5 px) is within 1 px of the committed OLD contours (7, 5, 7, 5 px).

## 7. Final run, fallbacks and review (A-097)

```bash
rm -rf images_new
RAC_DATASET=new MPLBACKEND=Agg TQDM_DISABLE=1 PYTHONDONTWRITEBYTECODE=1 $VPY -B -m contour_algorithm.main --qa --jobs 14
RAC_DATASET=new MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 $VPY -B -m contour_algorithm.qa_snake --metrics --sheets --figures --flagged --crosscheck --jobs 14
sha256sum data/new_shoes/contour_Active_Contour_new.txt
```
```
erase list: 25 rectangles on 8 shoes, 3406 contact pixels erased
step0 create: 1.9 s
step0 contour: 27.7 s
numpy OpenBLAS threads: 1, snake jobs: 14
Active contour processing complete - 631 shoes, 631 contour records (shoes without a record: [])
step0 snake: 79.7 s
step0 distance: 0.2 s
new: 631 shoes, 12 flagged, 619 pass every band (98.10%)
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T4/new/snake_metrics_new.csv
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T4/new/sticker_erased_new.csv
wrote 52 sheets below /home/mehes/projects/rac-spatial-model/docs/qa/sheets_new
88d559334a8c5f7b6dfb9cadb766e2a8afef12dde664bdb917d31e5d1387c924  data/new_shoes/contour_Active_Contour_new.txt
```
(Step 0 took 1 min 52 s in all, the QA with sheets and figures 3 min 16 s.) With radius 10 alone (no override) 611 shoes passed (96.8%, the t18 closing-10 variant). The fallback (radius 24) was run on the 20 flagged shoes and on shoe 163, and both outlines of each were looked at side by side (`<scratch>/t4/r10_vs_r24.png`, `fallback_8_163.png`, `fallback_rac.png`, `zoom_405_165.png`); it was taken for 8, 63, 109, 112, 113, 163, 175, 185, 557 (`data/new_shoes/snake_overrides_new.csv`, each with its before/after metrics). Every record of the final file is the record of its configuration (radius 10, or 24 for the 9 shoes): `records not equal to their configuration: []`.

Final metric distribution (631 shoes, `snake_metrics_new.csv`):
```
coverage           min 0.9802 p1 0.9910 p5 0.9959 median 1.0000 p95 1.0000 p99 1.0000 max 1.0000
coverage_fill      min 0.9841 p1 0.9948 p5 0.9983 median 1.0000 p95 1.0000 p99 1.0000 max 1.0000
coverage_r         min 0.9840 p1 0.9958 p5 0.9990 median 1.0000 p95 1.0000 p99 1.0000 max 1.0000
rac_coverage       min 0.6667 p1 0.9532 p5 1.0000 median 1.0000 p95 1.0000 p99 1.0000 max 1.0000
tightness          min 0.8574 p1 0.9313 p5 0.9559 median 1.0122 p95 1.0753 p99 1.0891 max 1.1018
turning            min 2.1676 p1 2.3189 p5 2.5264 median 3.1753 p95 3.9712 p99 4.2464 max 4.4521
max_turn_deg       min 9.4700 p1 12.2970 p5 13.3550 median 17.5100 p95 23.7750 p99 27.5570 max 31.1900
n_contour_px       min 611.0000 p1 660.2000 p5 682.0000 median 708.0000 p95 745.0000 p99 756.0000 max 766.0000
outside_mask_frac  min 0.0000 p1 0.0000 p5 0.0000 median 0.0000 p95 0.1066 p99 0.2216 max 0.3289
self_intersections min 0.0000 p1 0.0000 p5 0.0000 median 0.0000 p95 0.0000 p99 0.0000 max 0.0000
touches_border     min 0.0000 p1 0.0000 p5 0.0000 median 0.0000 p95 0.0000 p99 0.0000 max 0.0000
coverage<0.99: 3 [8, 165, 170] | tightness<0.95: 20 | tightness<0.9047: 2
```

The 12 flagged shoes and their resolution (`docs/qa/T4/new/snake_review_new.csv`, merged into the metrics table):

| Shoe | Flags | Resolution | Reason (short) |
|---|---|---|---|
| 8 | coverage; coverage_fill; rac_coverage | override | very faint partial print; fallback taken; specks and 1 RAC off the print stay outside |
| 11 | rac_coverage | ok_after_review | 1 of 30 RACs 15 px from any contact |
| 107 | rac_coverage | ok_after_review | 2 of 22 RACs off the print (one on an isolated speck) |
| 121 | rac_coverage | ok_after_review | 1 of 18 RACs 9 px from contact |
| 140 | rac_coverage | ok_after_review | 3 RACs at a barely printed heel pad |
| 165 | coverage (0.9896) | ok_after_review | specks at the toe; the fallback adds a turning flag |
| 170 | coverage (0.9875) | ok_after_review | snake 1-2 px inside a heel-pad rim; fill coverage 0.9944 |
| 263 | rac_coverage | ok_after_review | 1 RAC 7 px from contact below the heel |
| 375 | tightness (0.857) | ok_after_review | S-shaped narrow print, contour follows it |
| 405 | tightness (0.892) | ok_after_review | waisted sole, contour follows the waist |
| 503 | rac_coverage | ok_after_review | 1 RAC 11 px from contact |
| 506 | rac_coverage | ok_after_review | 2 RACs above the toe, off the print |

Against the task's literal tightness 0.95: 20 shoes below (OLD: 27 of 386); below the band's 0.9047: 375 and 405 (reviewed).

## 8. Determinism and platforms (A-092, A-098)

The official contour was written by the Linux-filesystem copy of the venv; the run with the thesis venv on `/mnt/c` (the task's interpreter) rewrote it byte for byte:
```bash
RAC_DATASET=new MPLBACKEND=Agg TQDM_DISABLE=1 PYTHONDONTWRITEBYTECODE=1 /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python -B -m contour_algorithm.main --qa --jobs 14
sha256sum data/new_shoes/contour_Active_Contour_new.txt
cmp images_new/saved/snake_points_new.npz <scratch>/t4/snake_points_new_wsl_copy.npz && echo "snake_points identical"
```
```
step0 snake: 84.3 s
88d559334a8c5f7b6dfb9cadb766e2a8afef12dde664bdb917d31e5d1387c924  data/new_shoes/contour_Active_Contour_new.txt
snake_points identical
```
Forked = serial (`test_qa_snake.Blas.test_jobs_identical`, 8 shoes, 4 workers, one thread: `{"same": true, "threads": 1}`).

**venv-wind (Windows) build of HEAD**, serial (no fork on Windows), in a scratch copy:
```bash
bash docs/qa/T4/probes/t4_win_new_step0.sh <scratch>/t4/win_new
```
```
sys.version 3.13.14 (tags/v3.13.14:fd17997, Jun 10 2026, 13:03:48) [MSC v.1944 64 bit (AMD64)]
sys.base_prefix C:\Program Files\WindowsApps\PythonSoftwareFoundation.Python.3.13_3.13.3824.0_x64__qbz5n2kfra8p0
erase list: 25 rectangles on 8 shoes, 3406 contact pixels erased
step0 create: 12.9 s
step0 contour: 89.5 s
numpy OpenBLAS threads: 1, snake jobs: 1
Active contour processing complete - 631 shoes, 631 contour records (shoes without a record: [])
step0 snake: 441.9 s
exit 0 seconds 562
```
```
1bb3fbf4aa32c1cd7a73bcfa1bcf231453739df6353884f286a2072f82444c42  <scratch>/t4/win_new/repo/data/new_shoes/contour_Active_Contour_new.txt
list_matrices_new.npy identical
freq_min_18_new.npy identical
superposed_min_18_new.npy identical
list_contour_new.npy identical
records 631, identical 618, differing 13
differing: mean distance median 0.03 px, p90 1.13, max 1.24; max distance median 1.0, max 3.6
```
The platform effect on NEW (13 records, at most 1.24 px mean distance) is of the size found on OLD (30 of 386, at most 1.50 px, A-060).

## 9. Cross-check with the 2023 processing (plan T4 step 7)

The 2023 `DIST_SNAKE`, `HORIZ_DIST_SNAKE` and `INSIDE_SNAKE` are in pixels, the same unit as here. Per RAC:
```bash
$VPY -B docs/qa/T4/probes/t4_crosscheck_racs.py
```
```
in_2023  False   True    All
in_new
False       20      0     20
True        33  19960  19993
All         53  19960  20013
RACs inside both: 19960
d_new vs d_2023: corr 0.9803 | diff median 0.302 mean 0.303 p5 -3.528 p95 4.000 | |diff| <= 1: 0.3807, <= 2: 0.6492
h_new vs h_2023: corr 0.9816 | diff median 0.000 mean 0.429 p5 -3.000 p95 4.000 | |diff| <= 1: 0.4865, <= 2: 0.7333
```
Per shoe (`qa_snake --crosscheck`, `docs/qa/T4/new/crosscheck_2023_new.csv`): the median absolute distance difference per shoe has median 1.63 px, p90 2.69, p99 3.44, max 7.03 (shoe 163).
19,993 of 20,013 RACs lie inside the new contour (2023: 19,960); none is inside in 2023 and outside now. Distances to the contour agree to within 2 px for 65% of the RACs (horizontal distances 73%), correlation 0.98, and the new distances are on average 0.3 px larger (the closing). The largest per-shoe differences are faint or partial prints (163, 403, 506, 474, 628, 12, 177): the 2023 contours there were not the ones accepted now, which is consistent with "the snake failed in 2023".

## 10. Tests

```bash
bash tests/run_all.sh        # at 8c5f6b9
```
```
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS       159s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        21s  Rscript tests/r/test_compare_glmm_fits.R
PASS         3s  Rscript tests/r/test_compare_models.R
PASS         8s  Rscript tests/r/test_distances_vectorized.R
PASS         1s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        32s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         2s  Rscript tests/r/test_profile.R
PASS        49s  Rscript tests/r/test_profile_sentinels.R
PASS         8s  Rscript tests/r/test_run_manifest.R
PASS         1s  Rscript tests/r/test_step5_variant.R
PASS         8s  Rscript tests/r/test_sticker_masks.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python files)
PASS         4s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS
Ran 172 tests in 112.822s
OK (skipped=3)
```
Skipped (by design, they need a run folder): `test_live_r_pdfs.LiveRun.test_normalized_pdfs_equal_tier_b`, `test_snake_old_regression.SnakeOld.test_full_run_folder` and `.test_full_run_intermediates` (the last two ran inside the step-0 gate as its live check).

New tests of T4:
- `tests/python/test_qa_snake.py` (26 tests): geometry on synthetic shapes (polygon fill, row-span fill, convex hull, self-intersections of a circle, a figure eight and a loop, turning of a circle, a square and a zigzag); metrics on a synthetic disk print (an enclosing snake passes, a cutting snake loses coverage and RACs, a loose snake fails tightness, border and mask); the bands (each band, NaN handling, the OLD percentiles come from the committed OLD table); the R stamp mask port = `data/all_cont.csv`; the erase list (validation, application, the committed NEW list erases contact and no RAC pixel); the override file (values, validation, the ellipse override); profile isolation (OLD keeps the legacy snake, no threads, no overrides; NEW values; the closing merges elements and is border-safe); the BLAS guard and forked = serial; the committed outputs (complete table and sheets, the task copy, flags = bands, every flag resolved, the cross-check reproduced).
- `tests/python/test_contour_new.py` (3 tests): layout, record = shoe, RAC coverage with named exceptions.
- `tests/r/test_sticker_masks.R` (4 checks): R eraser, reader, the NEW counts equal Python's, and step 1 on the sentinel fixture applies the list before the stamp mask and the RACs.
- Changed: `test_profiles.py` and `tests/r/test_profile.R` (the `sheets_new` namespace folder).

## 11. OLD regression gates at `e758dab`

```bash
RAC_SCRATCH=<scratch>/t4 bash tests/regress_old.sh --steps 0 --keep
RAC_SCRATCH=<scratch>/t4 bash tests/regress_old.sh --steps 1 --keep
```
```
== regress_old.sh --steps 0: <scratch>/t4/regress_old_fZqDtV
PASS    pipeline run                          every step exit 0, every output regenerated
PASS    step 0 contour = Tier B (CRLF)        data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B         1556 npy/png files, all equal
PASS    live check test_snake_old_regression  logs/live_snake.txt
step0  398.029312646  0
ALL PASS

== regress_old.sh --steps 1: <scratch>/t4/regress_old_klXN6y
PASS    pipeline run                           every step exit 0, every output regenerated
PASS    step 1 all_cont.csv = Tier A           data/all_cont.csv sha256 d582cf502184...
PASS    step 1 dataCC.csv = Tier A             processed_data/dataCC.csv sha256 cc4a476976ae...
PASS    step 1 shoe_pixel_counts.csv = Tier A  processed_data/shoe_pixel_counts.csv sha256 24bbd19cff59...
PASS    step 1 shoe_codes.csv = old_added_t2   processed_data/shoe_codes.csv sha256 3d6c09fe66e1...
step1  121.227937306  0
ALL PASS
```
T4 changed step 0 and step 1 only (steps 2-6 untouched, `git diff 687e507 -- statistical_model/` touches `dataCC_1.Rmd`, `R/io.R` and `R/profile.R` only), so these two gates cover the OLD regression. The Windows Tier A gate of OLD step 0 (`tests/legacy/run_windows_python_step0.sh`) was not rerun: the OLD code path is unchanged (OLD has no erase list, no overrides, closing radius 0, the library thread default), and the WSL gate proves the ported step 0 still writes Tier B.

## 12. Timings

| What | Time |
|---|---|
| NEW step 0, official (create 1.9 s, contour 27.7 s, snake 79.7 s with 14 jobs) | 1 min 52 s |
| NEW QA metrics + 52 sheets + 631 figures + flagged figures | 3 min 16 s (metrics alone 19 s) |
| One snake variant on 631 shoes (14 jobs) + scoring | 70-93 s |
| NEW step 0 under venv-wind (serial) | 562 s |
| OLD `regress_old.sh --steps 0` | 398 s (544 s with other jobs running) |
| OLD `regress_old.sh --steps 1` | 121 s |
| `tests/run_all.sh` | about 5 min 10 s |
