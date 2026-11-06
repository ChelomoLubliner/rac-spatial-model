# T3-new-data: results (2026-11-06)

Task T3-newdata = the first part of plan task T3 (`docs/plans/2026-11-05-new-shoes-pipeline.md`): the NEW locations in the OLD column format, the pixel calibration of the NEW images (validated on OLD first), the shoes without RACs and with RACs off the contact surface, and the skip list. Every block below is a real command and its real output (`<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`; `VENV` = `/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python`; long outputs trimmed with an explicit marker). Decisions A-086 (pre-registration) to A-090 and D-014; plan Revision 8, facts F51-F55. `docs/tests/T3-results.md` points here (A-090).

## 0. Summary

| Check | Result | Section |
|---|---|---|
| Baseline before any change (`48f6f89`) | `bash tests/run_all.sh old` ALL PASS (3 min 36 s) | 1 |
| Pre-registration | grids, criteria and the reading of rule (i) committed as A-086 (`a9981e8`) before any grid ran on the real data | 1 |
| Derived NEW locations CSV | `data/new_shoes/locations_data_new.csv`, 20,013 RACs, `shoe,x,y,type,rac_num`; x and y equal the 2023 file exactly (max abs diff 0 <= 1e-6) and are bit-identical to raw / 2 in Python and `identical()` in R; rebuilds byte for byte | 2 |
| Pixel mapping, R vs Python vs 2023 | R `aspix` evaluated from `dataCC_1.Rmd` = Python `legacy_pixel` for all 13,287 OLD and 20,013 NEW RACs; = the 2023 `COL/ROW` for all NEW RACs; the two F6 RACs right. R parses OLD x 11, y 4 and NEW x 4, y 2 values 1 ulp off; no pixel changes | 3 |
| Calibration, OLD (validation) | x mirrored, y not flipped (0.848 vs 0.44-0.55); one optimum at 300 over 100-700 px per unit; stage F strict (300, 301, -0.5, -0.5) 0.8839; Delta 0.0023 [-0.0007, **0.0061**]; legacy hit rate **0.8478** strict, **0.9903** with 1-pixel dilation | 4 |
| Calibration, NEW | the same orientation (0.808 vs 0.39-0.52); one optimum at 300 over 100-700; stage F strict (297, 301, -0.5, -0.75) 0.8380; Delta 0.0025 [-0.0014, **0.0056**]; legacy hit rate **0.8078** strict, **0.9747** dilated; 2023 `COL/ROW` = legacy (0 RACs differ) | 4 |
| Rule of A-086 | strict: (i) False, (ii) False (margin 0.005 not met on either dataset), (iii) True; dilated: all True. **Decision A-087: keep the generalized legacy mapping for NEW** (departs from the primary criterion; for Shlomo to confirm) | 4.4 |
| Post-hoc cross-check | NEW at the OLD optimum loses 0.0031 [-0.0007, 0.0075] (dilated 0.0003) | 4.5 |
| Shoes without RACs / off contact | NEW none without RACs; every RAC off contact: 69, 515, 629 (629 also with dilation); OLD 127 without RACs; 9, 268 all off. Skip list: none skipped, none excluded (A-089) | 5 |
| Images looked at | 2 calibration figures, 2 off-contact sheets, all 20 raw NEW sheets, 1 enlarged artefact view (scratch); no police-type sticker seen on NEW; frame artefacts on 9 NEW shoes | 6 |
| Tests | 43 new Python tests (143 in all, 3 skipped live checks), 1 new R script (15 in all) | 7 |
| OLD regression | Tier A 24/24, old_baseline 11/11, old_added_t2 2/2; `regress_old.sh --steps 1`: the four step-1 CSVs byte-identical (Tier A / old_added_t2), ALL PASS | 8 |

## 1. Baseline and pre-registration

```
$ bash tests/run_all.sh old        # at 48f6f89, before any change
[... per-test output omitted ...]
== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS        72s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        23s  Rscript tests/r/test_compare_glmm_fits.R
PASS         4s  Rscript tests/r/test_compare_models.R
PASS         8s  Rscript tests/r/test_distances_vectorized.R
PASS         2s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        34s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_profile.R
PASS        48s  Rscript tests/r/test_profile_sentinels.R
PASS         8s  Rscript tests/r/test_run_manifest.R
PASS         2s  Rscript tests/r/test_step5_variant.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         0s  flake8 (all Python files)
PASS         4s  shellcheck (all shell scripts)
PASS         1s  work tree unchanged by the tests (no file created or modified)
ALL PASS
exit 0
```

The calibration grids, the criteria (strict on-contact rate primary, 1-pixel dilation secondary, mean distance as a cross-check) and the reading of rule (i) were written into `docs/decisions.md` as A-086 and committed (`a9981e8 docs: pre-register the T3 pixel calibration grids and rule reading (A-086)`) before any calibration grid ran on the real data. Exploration before that commit: file formats, parsing, the 2023 `COL/ROW` (no grid).

## 2. Derived NEW locations CSV (A-088)

```
$ RAC_DATASET=new VENV -B -m contour_algorithm.locations
wrote /home/mehes/projects/rac-spatial-model/data/new_shoes/locations_data_new.csv (20013 RACs, 590963 bytes)
$ head -5 data/new_shoes/locations_data_new.csv
shoe,x,y,type,rac_num
1,-0.2047770,0.0510655,6,1
1,-0.0075810,0.3234315,1,2
1,-0.1071655,0.1555180,1,3
1,-0.1596700,0.0268570,2,4
$ RAC_DATASET=new VENV -B -m contour_algorithm.locations --check
/home/mehes/projects/rac-spatial-model/data/new_shoes/locations_data_new.csv: identical to a fresh build
$ RAC_DATASET=old VENV -B -m contour_algorithm.locations; echo "old exit $?"
contour_algorithm.locations: the old profile has no derived locations CSV (prep.locations_csv is null)
old exit 2
```

Value checks (Python, before the tests were written; the tests of section 7 assert the same):

```
x csv==reader True bits True csv==2023 True maxdiff 0.0
y csv==reader True bits True csv==2023 True maxdiff 0.0
shoe/rac/type True
neg zero rows [10623] [True] [True]
```

R (`statistical_model/`, R 4.3.3):

```
csv vs raw/2 identical x: TRUE  y: TRUE
n differ x: 0  y: 0  max abs diff: 0 0
csv vs 2023 identical x: TRUE  y: TRUE  n differ: 0 0
columns: shoe x y type rac_num
```

The raw file has a leading space on every line, one trailing space and 6 decimals in every coordinate; the halves need 7. The text differs from the 2023 file (pandas wrote the shortest repr, e.g. `-0.15967`, `7.35e-05`), the values do not. One RAC has x = -0 (shoe 255, RAC 48), kept as `-0.0000000`.

## 3. Pixel mapping and R's number parser (F51)

```
$ VENV -B -m unittest -v tests.python.test_pixel_mapping   # inside run_all on the scratch clone (section 8)
[... test lines omitted ...]
old: 13287 RACs, R and Python pixels identical; doubles that differ by 1 ulp (R parser): x 11, y 4
new: 20013 RACs, R and Python pixels identical; doubles that differ by 1 ulp (R parser): x 4, y 2
$ Rscript tests/r/test_pixel_mapping.R
== Rscript tests/r/test_pixel_mapping.R
PASS NEW: aspix of dataCC_1.Rmd equals the 2023 COL / ROW for all 20013 RACs 
PASS derived NEW CSV: x and y identical() to read_locations (raw / 2) and to the 2023 file; shoe, type, rac_num identical 
PASS OLD: the two RACs of F6 map to (125, 138) and (175, 340) 
ALL PASS test_pixel_mapping
```

`tests/lib/aspix_dump.R` evaluates the chunk `2.init_functions` of `statistical_model/dataCC_1.Rmd` itself (`tests/lib/rmd_chunk.R`), so the test checks the pipeline's code, not a copy. The calibration family reproduces the legacy mapping at the legacy setting except for one RAC per dataset that lies exactly on a pixel boundary (NEW: x = -0; `test_legacy_setting_of_the_family`).

## 4. Pixel calibration (A-086, A-087)

### 4.1 OLD (validation, the mapping is known)

```
$ time RAC_DATASET=old VENV -B -m contour_algorithm.calibrate_pixels
old stage O strict: 196 rows, best Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False), 5.2 s
old stage C strict: 3721 rows, best Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False), 5.2 s
old stage F strict: 1681 rows, best Setting(sx=300.0, sy=301.0, dc=-0.5, dr=-0.5, mirror_x=True, flip_y=False), 21.4 s
old stage O dilated: 196 rows, best Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False), 5.2 s
old stage C dilated: 3721 rows, best Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False), 5.0 s
old stage F dilated: 1681 rows, best Setting(sx=297.0, sy=299.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False), 21.5 s
legacy_aspix                     hits  11265 rate 0.847821 dilated 0.990291 mean_dist 0.1787 outside 0 diff_legacy 0 None
best_s0_strict                   hits  11714 rate 0.881614 dilated 0.991194 mean_dist 0.1420 outside 0 diff_legacy 9896 Setting(sx=300.0, sy=300.0, dc=-0.5, dr=-0.5, mirror_x=True, flip_y=False)
optimum_strict                   hits  11745 rate 0.883947 dilated 0.991194 mean_dist 0.1399 outside 0 diff_legacy 10120 Setting(sx=300.0, sy=301.0, dc=-0.5, dr=-0.5, mirror_x=True, flip_y=False)
best_s0_dilated                  hits  11481 rate 0.864078 dilated 0.991495 mean_dist 0.1600 outside 0 diff_legacy 3347 Setting(sx=300.0, sy=300.0, dc=0.0, dr=-0.25, mirror_x=True, flip_y=False)
optimum_dilated                  hits  11573 rate 0.871002 dilated 0.991796 mean_dist 0.1521 outside 0 diff_legacy 11459 Setting(sx=297.0, sy=299.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False)
grid_legacy                      hits  11265 rate 0.847821 dilated 0.990291 mean_dist 0.1787 outside 0 diff_legacy 1 Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False)
orientation_mirror1_flip0        hits  11265 rate 0.847821 dilated 0.990291 mean_dist 0.1787 outside 0 diff_legacy 1 Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False)
orientation_mirror1_flip1        hits   6005 rate 0.451946 dilated 0.639347 mean_dist 2.4746 outside 0 diff_legacy 13287 Setting(sx=240.0, sy=300.0, dc=-2.0, dr=18.0, mirror_x=True, flip_y=True)
orientation_mirror0_flip0        hits   7357 rate 0.553699 dilated 0.758185 mean_dist 1.1327 outside 0 diff_legacy 13189 Setting(sx=240.0, sy=300.0, dc=6.0, dr=0.0, mirror_x=False, flip_y=False)
orientation_mirror0_flip1        hits   5841 rate 0.439603 dilated 0.615263 mean_dist 2.6176 outside 0 diff_legacy 13287 Setting(sx=240.0, sy=280.0, dc=12.0, dr=20.0, mirror_x=False, flip_y=True)
r_script_2023                    hits   2910 rate 0.219011 dilated 0.320915 mean_dist 16.6337 outside 1 diff_legacy 13286 None
r_script_2023_swapped            hits   5856 rate 0.440732 dilated 0.616392 mean_dist 2.2683 outside 0 diff_legacy 13269 None
bootstrap.strict.delta_full = 0.002333107548731843
bootstrap.strict.lo = -0.0007263260786902576
bootstrap.strict.hi = 0.006120052416330708
bootstrap.dilated.delta_full = 0.00030104613532023783
bootstrap.dilated.lo = -0.0008896371798809016
bootstrap.dilated.hi = 0.0015988670388296222
conditions.strict.orientation_mirrored_unflipped = True
conditions.strict.optimum_in_band = True
conditions.strict.delta_hi_below_margin = False
conditions.strict.all = False
conditions.strict.argmax_is_s0 = False
conditions.dilated.orientation_mirrored_unflipped = True
conditions.dilated.optimum_in_band = True
conditions.dilated.delta_hi_below_margin = True
conditions.dilated.all = True
conditions.dilated.argmax_is_s0 = False
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T3/old/calibration_grid.csv and /home/mehes/projects/rac-spatial-model/docs/qa/T3/old/pixel_calibration.csv (70.8 s)

real	1m23.113s
user	1m10.019s
sys	0m2.608s
exit 0
```

### 4.2 NEW

```
$ time RAC_DATASET=new VENV -B -u -m contour_algorithm.calibrate_pixels
new stage O strict: 196 rows, best Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False), 8.6 s
new stage C strict: 3721 rows, best Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False), 8.3 s
new stage F strict: 1681 rows, best Setting(sx=297.0, sy=301.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False), 33.8 s
new stage O dilated: 196 rows, best Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False), 8.1 s
new stage C dilated: 3721 rows, best Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False), 9.5 s
new stage F dilated: 1681 rows, best Setting(sx=296.0, sy=299.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False), 32.8 s
legacy_aspix                     hits  16166 rate 0.807775 dilated 0.974666 mean_dist 0.2672 outside 0 diff_legacy 0 None
best_s0_strict                   hits  16720 rate 0.835457 dilated 0.980063 mean_dist 0.2299 outside 0 diff_legacy 17476 Setting(sx=300.0, sy=300.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False)
optimum_strict                   hits  16771 rate 0.838005 dilated 0.979463 mean_dist 0.2288 outside 0 diff_legacy 17476 Setting(sx=297.0, sy=301.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False)
best_s0_dilated                  hits  16696 rate 0.834258 dilated 0.980163 mean_dist 0.2316 outside 0 diff_legacy 18767 Setting(sx=300.0, sy=300.0, dc=-0.75, dr=-0.75, mirror_x=True, flip_y=False)
optimum_dilated                  hits  16584 rate 0.828661 dilated 0.980812 mean_dist 0.2357 outside 0 diff_legacy 17591 Setting(sx=296.0, sy=299.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False)
grid_legacy                      hits  16166 rate 0.807775 dilated 0.974666 mean_dist 0.2672 outside 0 diff_legacy 1 Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False)
orientation_mirror1_flip0        hits  16166 rate 0.807775 dilated 0.974666 mean_dist 0.2672 outside 0 diff_legacy 1 Setting(sx=300.0, sy=300.0, dc=0.0, dr=0.0, mirror_x=True, flip_y=False)
orientation_mirror1_flip1        hits   8081 rate 0.403788 dilated 0.575176 mean_dist 2.8749 outside 0 diff_legacy 20013 Setting(sx=240.0, sy=300.0, dc=-2.0, dr=8.0, mirror_x=True, flip_y=True)
orientation_mirror0_flip0        hits  10449 rate 0.522111 dilated 0.714685 mean_dist 1.3888 outside 0 diff_legacy 19931 Setting(sx=240.0, sy=300.0, dc=4.0, dr=0.0, mirror_x=False, flip_y=False)
orientation_mirror0_flip1        hits   7860 rate 0.392745 dilated 0.561685 mean_dist 3.1126 outside 0 diff_legacy 20013 Setting(sx=240.0, sy=280.0, dc=6.0, dr=20.0, mirror_x=False, flip_y=True)
r_script_2023                    hits   3609 rate 0.180333 dilated 0.264278 mean_dist 17.4809 outside 379 diff_legacy 20013 None
r_script_2023_swapped            hits   7856 rate 0.392545 dilated 0.560985 mean_dist 2.7932 outside 0 diff_legacy 19972 None
cols_rows_2023                   hits  16166 rate 0.807775 dilated 0.974666 mean_dist 0.2672 outside 0 diff_legacy 0 None
bootstrap.strict.delta_full = 0.002548343576675161
bootstrap.strict.lo = -0.001351661400239113
bootstrap.strict.hi = 0.005638143430492168
bootstrap.dilated.delta_full = 0.0006495777744466097
bootstrap.dilated.lo = -0.00025337737647218925
bootstrap.dilated.hi = 0.0015417409112808216
conditions.strict.orientation_mirrored_unflipped = True
conditions.strict.optimum_in_band = True
conditions.strict.delta_hi_below_margin = False
conditions.strict.all = False
conditions.strict.argmax_is_s0 = False
conditions.dilated.orientation_mirrored_unflipped = True
conditions.dilated.optimum_in_band = True
conditions.dilated.delta_hi_below_margin = True
conditions.dilated.all = True
conditions.dilated.argmax_is_s0 = False
rule.strict.i = False
rule.strict.ii = False
rule.strict.iii = True
rule.strict.keep_legacy = False
rule.dilated.i = True
rule.dilated.ii = True
rule.dilated.iii = True
rule.dilated.keep_legacy = True
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T3/new/calibration_grid_new.csv and /home/mehes/projects/rac-spatial-model/processed_data/new/pixel_calibration_new.csv (109.6 s)

real	2m2.772s
user	1m46.806s
sys	0m4.545s
exit 0
```

Named settings: `legacy_aspix` = the R mapping; `grid_legacy` = the family at the legacy setting (1 RAC differs, on a boundary); `best_s0_*` = scale 300 / 300 at its best offsets; `optimum_*` = the stage-F argmax; `orientation_*` = the stage-O best of each mirror/flip combination (coarse offsets); `r_script_2023*` = the 2023 R script's `rel_col_shoe` 333 / `rel_row_shoe` 180 and swapped (negative controls); `cols_rows_2023` = the 2023 file's own pixels. `diff_legacy` = RACs mapped to another pixel than `legacy_aspix`.

### 4.3 The surfaces near the optimum (from the committed grids)

```
$ VENV -B -c "<print the stage-F strict profiles of docs/qa/T3/*/calibration_grid*.csv>"
old stage F strict, best rate per sy (other scale and offsets at their best):
 sy  sx   dc    dr  hits     rate
296 302 -0.5 -1.00 10947 0.823888
297 302 -0.5 -0.75 11159 0.839843
298 302 -0.5 -0.75 11427 0.860014
299 302 -0.5 -0.75 11609 0.873711
300 300 -0.5 -0.50 11714 0.881614
301 300 -0.5 -0.50 11745 0.883947
302 300 -0.5 -0.50 11611 0.873862
303 300 -0.5 -0.25 11351 0.854294
304 300 -0.5 -0.25 11084 0.834199
old stage F strict, best rate per sx (other scale and offsets at their best):
 sx  sy    dc   dr  hits     rate
296 301 -0.75 -0.5 11687 0.879582
297 301 -0.50 -0.5 11720 0.882065
298 301 -0.50 -0.5 11722 0.882216
299 301 -0.50 -0.5 11734 0.883119
300 301 -0.50 -0.5 11745 0.883947
301 301 -0.50 -0.5 11726 0.882517
302 301 -0.50 -0.5 11717 0.881839
303 301 -0.75 -0.5 11685 0.879431
304 301 -0.75 -0.5 11667 0.878076
new stage F strict, best rate per sy (other scale and offsets at their best):
 sy  sx   dc    dr  hits     rate
296 299 -0.5 -1.00 15992 0.799081
297 299 -0.5 -0.75 16246 0.811772
298 299 -0.5 -0.75 16459 0.822415
299 299 -0.5 -1.00 16630 0.830960
300 297 -0.5 -0.75 16756 0.837256
301 297 -0.5 -0.75 16771 0.838005
302 297 -0.5 -0.50 16666 0.832759
303 297 -0.5 -0.75 16427 0.820816
304 297 -0.5 -0.50 16107 0.804827
new stage F strict, best rate per sx (other scale and offsets at their best):
 sx  sy    dc    dr  hits     rate
296 301 -0.50 -0.75 16761 0.837506
297 301 -0.50 -0.75 16771 0.838005
298 301 -0.50 -0.75 16749 0.836906
299 301 -0.50 -0.75 16751 0.837006
300 300 -0.50 -0.75 16720 0.835457
301 300 -0.75 -0.75 16715 0.835207
302 300 -0.75 -0.75 16684 0.833658
303 300 -0.50 -0.75 16671 0.833009
304 300 -0.50 -0.75 16638 0.831360
```

The y scale is sharp (OLD and NEW: 300 and 301 within 0.0023 and 0.0008, 299 and 302 about 0.008 lower); the x scale is flat (OLD 297-302 within 0.0021, NEW 296-301 within 0.0028), as T0 found (F30). The best row offset is -0.5 px on OLD and -0.75 px on NEW, the best column offset -0.5 px on both.

### 4.4 The rule

| Condition (A-086) | OLD strict | NEW strict | OLD dilated | NEW dilated |
|---|---|---|---|---|
| stage-O optimum x mirrored, y not flipped | True | True | True | True |
| stage-F optimum within 300 +- 6 on both axes | True (300, 301) | True (297, 301) | True (297, 299) | True (296, 299) |
| Delta 95% upper bound < 0.005 | **False** (0.0061) | **False** (0.0056) | True (0.0016) | True (0.0015) |
| literal: argmax exactly (300, 300) | False | False | False | False |
| (iii) NEW and OLD optimum offsets within 1 px | | True (-0.5 vs -0.5; -0.75 vs -0.5) | | True |
| **keep the generalized legacy mapping** | | **False** | | **True** |

Decision A-087 (agent call, for Shlomo to confirm): keep the generalized legacy mapping for NEW. The strict margin test fails on OLD too, where the mapping is known, so at this sample size it cannot confirm even the true mapping (interval width about 0.007 against a 0.005 margin); the validated version of the method (dilated) passes on both; NEW and OLD agree in every respect the rule looks at; a NEW-only correction of the half-pixel offset would treat the datasets differently while OLD must stay byte-identical. D-014 asks whether to correct the offset in both datasets. The profile values stay 150 / 300 / 0.25 / 0.5, now with a comment citing this evidence (`config/datasets.json`, NEW `coords`).

### 4.5 Post-hoc cross-check (not pre-registered)

```
$ VENV -B docs/qa/T3/probes/t3_cross_eval.py > docs/qa/T3/probes/t3_cross_eval.out
$ cat docs/qa/T3/probes/t3_cross_eval.out
old strict: own optimum Setting(sx=300.0, sy=301.0, dc=-0.5, dr=-0.5, mirror_x=True, flip_y=False) rate 0.883947; at the new optimum Setting(sx=297.0, sy=301.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False) rate 0.874313; legacy 0.847821
   own - other optimum 0.009633 95% [0.004951, 0.014950]; other optimum - legacy 0.026492 95% [0.017385, 0.035424]
old dilated: own optimum Setting(sx=297.0, sy=299.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False) rate 0.991796; at the new optimum Setting(sx=296.0, sy=299.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False) rate 0.991495; legacy 0.990291
   own - other optimum 0.000301 95% [0.000000, 0.000590]; other optimum - legacy 0.001204 95% [-0.000077, 0.002630]
new strict: own optimum Setting(sx=297.0, sy=301.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False) rate 0.838005; at the old optimum Setting(sx=300.0, sy=301.0, dc=-0.5, dr=-0.5, mirror_x=True, flip_y=False) rate 0.834907; legacy 0.807775
   own - other optimum 0.003098 95% [-0.000747, 0.007534]; other optimum - legacy 0.027132 95% [0.021669, 0.033196]
new dilated: own optimum Setting(sx=296.0, sy=299.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False) rate 0.980812; at the old optimum Setting(sx=297.0, sy=299.0, dc=-0.5, dr=-0.75, mirror_x=True, flip_y=False) rate 0.980563; legacy 0.974666
   own - other optimum 0.000250 95% [-0.000051, 0.000617]; other optimum - legacy 0.005896 95% [0.004040, 0.007561]
```

On NEW the OLD optimum is as good as NEW's own (the interval contains 0); OLD distinguishes the two optima (it resolves the 0.25 px row-offset difference better), inside rule (iii)'s 1 px. Both optima beat the legacy mapping by about 0.027 strict on both datasets: the half-pixel offset K5, common to both.

## 5. Shoes without RACs, RACs off contact, skip list (A-089)

```
$ time RAC_DATASET=old VENV -B -m contour_algorithm.shoe_quality
shoes 387, with RACs 386, RACs 13287
shoes without RACs: [127]
RACs off contact: strict 2022 (0.1522), dilated 129 (0.0097), outside the image 0
shoes with at least one RAC off contact: strict 322, dilated 65
shoes with every RAC off contact: strict [9, 268], dilated []
rate < 0.5: 6 shoes, 77 RACs
rate < 0.6: 22 shoes, 368 RACs
rate < 0.7: 55 shoes, 1257 RACs
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T3/old/shoe_contact.csv (387 rows)

real	0m13.028s
$ time RAC_DATASET=new VENV -B -m contour_algorithm.shoe_quality
shoes 631, with RACs 631, RACs 20013
shoes without RACs: []
RACs off contact: strict 3847 (0.1922), dilated 507 (0.0253), outside the image 0
shoes with at least one RAC off contact: strict 559, dilated 216
shoes with every RAC off contact: strict [69, 515, 629], dilated [629]
rate < 0.5: 23 shoes, 514 RACs
rate < 0.6: 68 shoes, 1449 RACs
rate < 0.7: 135 shoes, 3259 RACs
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T3/new/shoe_contact_new.csv (631 rows)

real	0m15.156s
```

These two tables were first written with a loop over the 81 shifts; `best_shift` was then vectorized and rewrites both tables byte for byte (`old vectorized == loop version bytes: True 0.8 s`, `new ... True 0.8 s`; `test_shoe_quality.Committed.test_tables_regenerate` checks it on every run).

A-029 preview (not applied; the census adds the partial-print part and step 3d freezes the set):

```
A-029 q (OLD p5 of best_shift_rate, n>=10): 0.8216614906832298
old n>=10: 302 below q: 16 769 RACs [15, 35, 44, 46, 62, 100, 124, 153, 154, 163, 175, 179, 183, 201, 274, 333]
old per-shoe rate p5/p10/p25/p50 [0.584, 0.643, 0.778, 0.88] dilated [0.939, 0.974, 1.0, 1.0]
new n>=10: 517 below q: 75 2994 RACs [11, 12, 13, 16, 18, 19, 28, 29, 30, 31, 32, 33, 34, 39, 47, 48, 103, 106, 107, 111, 112, 113, 115, 119, 120, 121, 122, 132, 140, 153, 158, 164, 176, 177, 185, 186, 187, 198, 207, 209, 214, 217, 226, 227, 263, 266, 282, 286, 309, 319, 325, 330, 353, 372, 375, 381, 382, 419, 420, 446, 461, 464, 470, 471, 474, 478, 482, 483, 498, 517, 551, 557, 569, 596, 619]
new per-shoe rate p5/p10/p25/p50 [0.5, 0.571, 0.718, 0.829] dilated [0.846, 0.909, 0.971, 1.0]
old shift gain > 0.2 (n>=10): 35 flip better than best shift by >0.15: []
new shift gain > 0.2 (n>=10): 62 flip better than best shift by >0.15: []
old n_rac_pixels sum 13249 dups 38
new n_rac_pixels sum 19990 dups 23
```

(The per-shoe rate quantiles and the shift and flip counts equal T0's R3, F27.) Decision A-089: `shoes_without_racs` NEW = [] (also computed from the data at every run), `excluded_shoes` NEW = []; off-contact RACs are handled as for OLD (step 1 adds their pixel to the contact surface); the low-contact shoes go to T4 (snake QA) and to the Part 2 quality rule.

## 6. Images (opened with the Read tool; full descriptions in `docs/qa/T3/README.md`)

```
$ RAC_DATASET=old VENV -B -m contour_algorithm.qa_sheets
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T3/old/calibration_curves.png
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T3/old/offcontact_shoes.png
$ RAC_DATASET=new VENV -B -m contour_algorithm.qa_sheets --raw-sheets
[... 20 raw sheet lines omitted ...]
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T3/new/raw_sheet_20_new.png
```

- `old/calibration_curves.png`, `new/calibration_curves_new.png`: one sharp optimum at 300 over 100-700 px per unit on both axes (no peak near 150 or 600); in the fine stage a sharp y peak at 300-301 and a flat x plateau; mirrored x / unflipped y far ahead of the other orientations; the two datasets' curves have nearly the same shape.
- `new/offcontact_shoes_new.png`: the 24 lowest rates: shoes with 1-5 RACs just beside lugs or blocks (515, 69, 629, 412, 576, 402, 431, 433), faint or partial prints (286, 112, 177, 498, 420, 166, 274, 390, ...) and the misregistered image type 599. No sticker.
- `old/offcontact_shoes.png`: the same causes on OLD; stickers (white rectangles or bars outside the sole) on OLD 59, 66, 142, 150, 374, which shows what police labels look like in these data.
- `new/raw_sheet_01_new.png` ... `raw_sheet_20_new.png` (every NEW shoe): no police-type sticker on any NEW record at sheet resolution; straight-edged frame artefacts (plate or paper edges) on 93, 148, 149, 186, 580, 582, 585, 586, 589 and a short stroke on 223; 580's solid wedge touches the heel's lower right (T4 must check that the cleaning removes it); many over-inked forefoots; faint or partial prints; every shoe in the OLD orientation. Per-sheet notes in `docs/qa/T3/README.md`, the flags in `docs/qa/T3/new/visual_flags_new.csv` (96 shoes; at sheet resolution, not the census).
- Scratch only: the 8 artefact shoes twice enlarged (`<scratch>/t3/artefacts_x2.png`).

## 7. Tests

New: `tests/python/test_locations_new.py` (6), `test_pixel_mapping.py` (5), `test_calibration.py` (22), `test_shoe_quality.py` (5), `test_qa_sheets.py` (4), `test_profiles.py` +1 (`New.test_prep_outputs`; collision cases and rule-1 cases added), `tests/r/test_pixel_mapping.R`, `tests/r/test_profile.R` (prep outputs, finding-1 rule, 3 more mutants, 4 more refused profiles), helpers `tests/lib/rmd_chunk.R`, `tests/lib/aspix_dump.R`. From the fast suite on the scratch clone of `b5d3c4c` (section 8):

```
[... other test lines omitted ...]
test_bootstrap_reproduced (tests.python.test_calibration.New.test_bootstrap_reproduced) ... ok
test_cols_rows_2023 (tests.python.test_calibration.New.test_cols_rows_2023) ... ok
test_fine_stage_in_band (tests.python.test_calibration.New.test_fine_stage_in_band) ... ok
test_grid_rows_recomputed (tests.python.test_calibration.New.test_grid_rows_recomputed)
The vectorized grid against a direct evaluation: the best row ... ok
test_named_settings_recomputed (tests.python.test_calibration.New.test_named_settings_recomputed) ... ok
test_orientation_and_coarse_stage (tests.python.test_calibration.New.test_orientation_and_coarse_stage) ... ok
test_rate_difference_interval (tests.python.test_calibration.New.test_rate_difference_interval)
The rule of A-086 read back from the two committed tables: ... ok
test_scale_band (tests.python.test_calibration.New.test_scale_band) ... ok
test_bootstrap_reproduced (tests.python.test_calibration.Old.test_bootstrap_reproduced) ... ok
test_fine_stage_in_band (tests.python.test_calibration.Old.test_fine_stage_in_band) ... ok
test_grid_rows_recomputed (tests.python.test_calibration.Old.test_grid_rows_recomputed)
The vectorized grid against a direct evaluation: the best row ... ok
test_named_settings_recomputed (tests.python.test_calibration.Old.test_named_settings_recomputed) ... ok
test_orientation_and_coarse_stage (tests.python.test_calibration.Old.test_orientation_and_coarse_stage) ... ok
test_recovers_legacy_scale (tests.python.test_calibration.Old.test_recovers_legacy_scale)
OLD (mapping known): x mirrored, y not flipped; the stage-F ... ok
test_deterministic (tests.python.test_calibration.Synthetic.test_deterministic) ... ok
test_legacy_placement_interval (tests.python.test_calibration.Synthetic.test_legacy_placement_interval)
Placed with the legacy mapping and 0.3 px jitter: the Delta ... ok
test_orientation_found (tests.python.test_calibration.Synthetic.test_orientation_found) ... ok
test_recovers_known_mapping (tests.python.test_calibration.Synthetic.test_recovers_known_mapping) ... ok
test_best_order_tie_break (tests.python.test_calibration.Units.test_best_order_tie_break) ... ok
test_bootstrap_definition (tests.python.test_calibration.Units.test_bootstrap_definition) ... ok
test_cli_refuses_profile_file (tests.python.test_calibration.Units.test_cli_refuses_profile_file) ... ok
test_dilate (tests.python.test_calibration.Units.test_dilate) ... ok
test_check_and_refusals (tests.python.test_locations_new.Cli.test_check_and_refusals) ... ok
test_derived_csv_committed (tests.python.test_locations_new.New.test_derived_csv_committed) ... ok
test_derived_csv_format (tests.python.test_locations_new.New.test_derived_csv_format) ... ok
test_derived_csv_values (tests.python.test_locations_new.New.test_derived_csv_values) ... ok
test_exact_halving (tests.python.test_locations_new.New.test_exact_halving)
Exact decimal halves of a small raw file, and a bad line. ... ok
test_matches_2023 (tests.python.test_locations_new.New.test_matches_2023) ... ok
test_f6_racs (tests.python.test_pixel_mapping.Mapping.test_f6_racs) ... ok
test_legacy_center (tests.python.test_pixel_mapping.Mapping.test_legacy_center)
x = 0 and y = 0 sit on the pixel edge cx0, cy0: RACs just on ... ok
test_legacy_setting_of_the_family (tests.python.test_pixel_mapping.Mapping.test_legacy_setting_of_the_family)
Setting(s0, s0, 0, 0) of the calibration family equals the ... ok
test_matches_r_aspix (tests.python.test_pixel_mapping.Mapping.test_matches_r_aspix) ... ok
test_new_equals_2023_colrow (tests.python.test_pixel_mapping.Mapping.test_new_equals_2023_colrow) ... ok
test_prep_outputs (tests.python.test_profiles.New.test_prep_outputs)
The T3 outputs (A-087, A-088): the derived locations CSV in ... ok
test_offcontact_sheets (tests.python.test_qa_sheets.Committed.test_offcontact_sheets) ... ok
test_raw_sheets (tests.python.test_qa_sheets.Committed.test_raw_sheets) ... ok
test_contact_sheet (tests.python.test_qa_sheets.Drawing.test_contact_sheet) ... ok
test_rac_tile (tests.python.test_qa_sheets.Drawing.test_rac_tile) ... ok
test_lists (tests.python.test_shoe_quality.Committed.test_lists) ... ok
test_tables_regenerate (tests.python.test_shoe_quality.Committed.test_tables_regenerate) ... ok
test_best_shift_recovers_a_shift (tests.python.test_shoe_quality.Quality.test_best_shift_recovers_a_shift)
Isolated contact pixels 10 px apart, so that only the exact ... ok
test_table (tests.python.test_shoe_quality.Quality.test_table) ... ok
test_threshold (tests.python.test_shoe_quality.Quality.test_threshold) ... ok
[...]
Ran 143 tests in 75.848s
OK (skipped=3)
```

```
== Rscript tests/r/test_profile.R
PASS rac_profile() leaves .Random.seed unchanged (jsonlite loaded by it) 
PASS OLD profile values identical() to the legacy literals (doubles) 
PASS OLD paths are the legacy strings; OLD CSV line endings as committed 
PASS OLD analysis shoes 1-126, 128-387 (integer) 
PASS NEW profile: 255 x 367, 631 shoes, the OLD prototype frame 307 x 395 
PASS NEW outputs (22 files, 5 folders) namespaced; none equals or lies inside an OLD output, an input or an OLD tracked file; committed NEW outputs pass, 8 mutants caught 
PASS rac_profile() refuses 14 NEW profiles that break rule 1; the real profile, the fixture and OLD load 
PASS RAC_DATASET: unset and empty give old, new gives new, others error 
PASS rac_env(): unset and "" give the default for every RAC_* variable 
PASS RAC_PROFILE_FILE selects another profile file; empty means default 
PASS rac_write_csv: CRLF for OLD dataCC, LF for NEW, folders created 
PASS rac_new_output: refuses an existing OLD output, NEW may be rewritten 
PASS config.R: OLD MEAN_OFFSET -4.614310784; without the pixel-count file OLD falls back to log(100/10615), NEW is NA with a warning; MODEL_FEATURE from RAC_MODEL_FEATURE 
ALL PASS test_profile
```

Notes. `test_calibration` recomputes from the data the hits at every named setting, at the best row of every stage and at 12 random grid rows (the vectorized grid against a direct evaluation), and reproduces the 200 bootstrap draws of both criteria bit for bit; its synthetic tests (RACs placed on real NEW contact pixels with a known mapping, a thinned-out grid for speed) recover a non-legacy mapping exactly (then the band condition fails), a non-mirrored placement, and a Delta upper bound below 0.005 for a legacy placement with 0.3 px jitter. Two first versions of tests were wrong and were fixed before the commit: the synthetic placement used u in (0.2, 0.8), which leaves several settings tied at rate 1; and the shift test of `test_shoe_quality` used a block wider than the shift (the tie went to the smaller shift, -2 instead of -3); both now use placements where only the true setting fits.

Interfaces against the plan's T3 list. `legacy_pixel(x, y, coords, width, height)` takes the profile's `Coords` instead of the plan's literal defaults (`rel_col=150, rel_row=300, ...`), which the no-hardcoding scan forbids in pipeline code. The plan's `calibration_grid(contacts, locs, scales_x, scales_y, offsets, mirror_x, flip_y)` is `calibrate_pixels.run_stage(images, shoe0, x, y, centre, s0, orientations, xscales, yscales, offsets)` (one row per orientation and scale pair at its best offsets) on top of `hit_matrix` (every setting), and `calibrate(profile, data=None, log=print, grids=None)` runs the three stages of A-086. `shoe_quality(contacts, locs, mapping)` is `shoe_quality(contacts, shoe, col0, row0, num_shoe)` with `profile_table(profile)` applying the profile's mapping. `on_contact_rate(contacts, shoe, col0, row0)` is as planned. The plan's module `locations.py` (readers) was extended rather than created (T2 had created it).

## 8. Gates (OLD regression)

Fast suite on a scratch clone of the committed code (`git clone --local` at `b5d3c4c`; run there so that the docs could be written meanwhile without tripping its unchanged-tree check):

```
$ cd <scratch>/t3/clone && time bash tests/run_all.sh old
[... per-test output omitted ...]
== summary
PASS         1s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS       104s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        23s  Rscript tests/r/test_compare_glmm_fits.R
PASS         3s  Rscript tests/r/test_compare_models.R
PASS         8s  Rscript tests/r/test_distances_vectorized.R
PASS         1s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        32s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         1s  Rscript tests/r/test_profile.R
PASS        50s  Rscript tests/r/test_profile_sentinels.R
PASS         8s  Rscript tests/r/test_run_manifest.R
PASS         1s  Rscript tests/r/test_step5_variant.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python files)
PASS         4s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS

real	4m9.261s
user	5m6.903s
sys	0m38.368s
exit 0
```

```
$ RAC_SCRATCH=<scratch>/t3/regress bash tests/regress_old.sh --steps 1 --keep
[... rsync and knit output omitted ...]
== regress_old.sh --steps 1: <scratch>/t3/regress/regress_old_7Mi9zl
result  check                                  detail
PASS    pipeline run                           every step exit 0, every output regenerated
PASS    step 1 all_cont.csv = Tier A           data/all_cont.csv sha256 d582cf502184...
PASS    step 1 dataCC.csv = Tier A             processed_data/dataCC.csv sha256 cc4a476976ae...
PASS    step 1 shoe_pixel_counts.csv = Tier A  processed_data/shoe_pixel_counts.csv sha256 24bbd19cff59...
PASS    step 1 shoe_codes.csv = old_added_t2   processed_data/shoe_codes.csv sha256 3d6c09fe66e1...
timings (s):
step   seconds        exit
step1  120.963233550  0
ALL PASS

real	2m2.300s
user	1m17.806s
sys	0m44.225s
exit 0
```

The same suite on the main tree after the docs commit `2bcf3a8` (it lints the T3 probe too):

```
$ time bash tests/run_all.sh old
[... per-test output omitted ...]
Ran 143 tests in 64.312s
OK (skipped=3)
flake8: 55 files
shellcheck: 14 files
[...]
== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS        92s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        21s  Rscript tests/r/test_compare_glmm_fits.R
PASS         3s  Rscript tests/r/test_compare_models.R
PASS         8s  Rscript tests/r/test_distances_vectorized.R
PASS         1s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        32s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         2s  Rscript tests/r/test_profile.R
PASS        48s  Rscript tests/r/test_profile_sentinels.R
PASS         8s  Rscript tests/r/test_run_manifest.R
PASS         2s  Rscript tests/r/test_step5_variant.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         0s  flake8 (all Python files)
PASS         4s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS

real	3m54.218s
user	3m38.661s
sys	0m33.247s
exit 0
```

No committed OLD file changed (Tier A 24/24, old_baseline 11/11, old_added_t2 2/2 in the suite); step 1 rerun from scratch writes the four OLD CSVs byte for byte. The OLD files added by T3 are QA files under `docs/qa/T3/old/` (not pipeline outputs); their regeneration is checked by `test_calibration` and `test_shoe_quality`.

## 9. Timings (s, this machine, idle except my jobs)

| Job | Wall |
|---|---|
| OLD calibration (stages O, C, F, both criteria, bootstrap) | 83 (stage F strict 21.4, dilated 21.5) |
| NEW calibration | 123 (stage F strict 33.8, dilated 32.8) |
| shoe tables OLD / NEW (loop version; vectorized: 0.8 s each plus about 12 s of loading) | 13 / 15 |
| QA images OLD / NEW (with the 20 raw sheets) | 22 / 43 |
| fast suite (clone; main tree after the docs commit) | 249 (Python 104); 234 (Python 92) |
| `regress_old.sh --steps 1` | 122 (step 1 121) |

## 10. Not done in this part of T3 (open, plan T3)

The sticker module (`stickers.py`, synthetic recall test) and the full-size census (`shoe_census_new.csv`, step 3); the overlap screen (3b); the quality rule applied with the census's partial-print part and the Part 2 shoe set frozen (3c, 3d); the R stamp threshold (step 4). The raw sheets, the per-shoe tables and the visual flags of this part are their inputs.
