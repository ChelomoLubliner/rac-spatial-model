# T5 review fixes: results

**Date:** 2026-11-07. **Task:** fix the findings of the three T5-newmodel reviews (engineer `b980c86`, statistician `4e26cbb`, reproducibility `4cc6ffe`; LOG 2026-11-07 00:25, 00:45, 00:58). **Branch:** `feature/new-shoes-pipeline`. **Commits:** `468d31e`, `8de60f5` (the NEW outputs test), `e0f15be` (compare.R and its test), then the docs commit (probes, QA outputs, docs). **Decisions:** A-113 to A-118, corrections to A-108 and A-111, updates to D-008 and D-009 (`docs/decisions.md`); plan revision 13 (F75 and F77 corrected, F78-F83 added). Every number below is real output of the command above it; `<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`. Nothing here changes an OLD output or any code on an OLD path (section 6).

## 1. Summary

| Finding (reviewer, severity) | What was done | Evidence |
|---|---|---|
| No goodness-of-fit check; the NEW map reading goes beyond the data (statistician, major) | Residual O/E table for both datasets committed; every number of the review reproduced with committed probes; the contact surface checked pixel by pixel; the group designs looked at; the NEW map reading corrected (the right heel-midfoot maximum withdrawn, cut 250 about a quarter too high at the heel front); T6, T7, T8 told (A-114) | section 3 |
| The stale-step-2 guard checks 25 of 631 shoes; the OLD-basis refits are not tied to the data; six doc statements wrong (engineer 1-2, reproducibility 1, major) | `test_new_outputs.R`: step 2 recomputed for all 631 shoes byte for byte; both step-3 models and both OLD-basis refits tied to the CSV; negative control; every check runs; mutants M0-M2 after measuring their effect; the statements corrected (A-113) | section 2 |
| The K8 restriction costs more on NEW (statistician, minor) | Reproduced; stated in T5; the full tensor added to T6's map comparison (A-116) | section 4.3 |
| "OLD's shapes at higher levels" is K3 (statistician, minor) | Reproduced; dropped; calibration numbers to D-009 (A-115) | section 4.4 |
| sigma^2 is not spatial (statistician, minor) | Reproduced, NEW offset refit rerun (0.641); wording changed; numbers to T6 and D-008 (A-115) | section 4.5 |
| False precision of the Wald p; W compared across datasets (statistician, minor) | Reproduced (robust W 329.0); "p < 1e-16 (model-based)"; W not compared (A-115) | section 4.2 |
| "No lme4 message" is no convergence evidence (statistician, minor) | Independent gradient check reproduced and cited (A-115) | section 4.1 |
| A-111's seam position (reproducibility, minor) | Measured and looked at: y = 0.41 in all four PNGs; A-111 corrected | section 5.1 |
| Two probes do not rerun from a clean clone (reproducibility, minor) | Order and prerequisites in the usage lines and the T5 QA README; the documented order checked in a fresh clone (outputs byte-identical) | section 5.2 |
| README kernel-pin sentence and A-108's count (reproducibility, carried over from T4) | README and A-108 corrected; no platform pin, with the reasons (A-117) | section 5.3 |
| The figures are checked only for existence (engineer, minor) | Said so in the test, README and docs; T8's e2e test to compare them; `t5_new_rerun.sh --oldbasis --png` as its start, run once | sections 2, 6.3 |
| No hard-coding scan of `tools/*.R` (engineer, minor) | R scan extended to `tools/` (as pipeline code); `figures_png.R:60` marked; shown to fire without the marker (A-118) | section 5.4 |
| Coefficient names differ; `bx`/`by` clash; no test of `fit_common_basis()` = step 3 (engineer, nit) | `spatial_term_key()`, the clash check, `tests/r/test_compare.R` (A-118) | section 5.5 |

## 2. The stale-output guard of `tests/r/test_new_outputs.R` (A-113)

What changed (commits `468d31e`, `8de60f5`):
- **Step 2, all shoes:** step 2 is recomputed for all 631 shoes from the committed contour with the vectorized step's own code (`compute_distances()`, step 2's shape chunk, `rac_write_csv()` into a temporary root), and `dataCC_distance_temp_new.csv` and `dataCC_distance_new.csv` must be byte-identical to the committed files. The T5 version recomputed 25 fixed shoes (`set.seed(25)`).
- **Models tied to the CSV:** the step-3 GLMM by its basis (the knots of the CSV), response = `n_Acc`, grouping factor = the shoe codes and `getME(X)` = the design rebuilt from the CSV; the step-3 CML by its basis, status, strata, `model.matrix()` and n, nevent; both OLD-basis refits (A-112) the same way on the OLD basis. The T5 version checked the OLD-basis refits for basis, convergence, count and nobs only.
- **Negative control:** each comparison must reject three altered copies of the CSV (one shoe's new_x moved by a pixel; a case and a control swapped; a row moved to another shoe), so the comparisons are not vacuous.
- **Every check runs** and prints PASS or FAIL with its reason; the script exits 1 if any failed (a stale chain shows every stale output).
- **Figures:** still an existence check, now said in the test's output, its header, the README and `docs/tests/README.md`.

```bash
time Rscript tests/r/test_new_outputs.R    # the test is unchanged since 8de60f5
```
```
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw records, the erase list, the stamp mask (>= 8 shoes, no pixel swept) and the RAC pixels = the pixel counts; every control on S and on no RAC pixel; LF only 
PASS step 2: (n_Acc, x, y, shoe) = dataCC; finite distances, horiz_dist >= min_dist, |new_x| <= distance_shape; every distance_shape a half-width of the prototype in its own frame; 631 contour records; step 2 recomputed for all 631 shoes (83090 rows, 10.6 s) from the committed contour writes both step-2 CSVs byte for byte (new_x in [-0.1850, 0.2317]) 
PASS step 3 GLMM: converged, 25 fixed effects, 631 groups, 83090 rows; fitted on the committed CSV (its basis = the knots of the CSV, y = n_Acc, groups = the shoe codes, getME(X) = the step-3 design rebuilt from the CSV); sigma^2 0.7556 
PASS step 3 CML: 24 coefficients, 19990 events; fitted on the committed CSV (its basis = the knots of the CSV, status = n_Acc, strata = the shoe codes, model.matrix = the step-3 design without the intercept) 
PASS OLD-basis NEW_X_NS_XY (A-112): on the OLD basis and fitted on the committed CSV (y, shoe, X) 
PASS OLD-basis CML_MODEL (A-112): on the OLD basis and fitted on the committed CSV (status, strata, X, n) 
PASS negative control: the model-CSV comparisons reject a CSV with one shoe's new_x moved by a pixel (X), a case and a control swapped (y, status) and a row moved to another shoe (groups, strata) 
PASS step 5: wald_test_new.csv W = 585.8888, df 24, vcov RX = the W of the committed GLMM 
PASS steps 4-6: the 8 NEW PDFs and their PNG twins exist (existence only; a stale figure is not detected here) 
PASS no collision: 48 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the old_added lists and README files 
ALL PASS test_new_outputs

real	0m37.879s
user	0m33.088s
sys	0m2.335s
```
38 s under load (two gates were running), against 13.5 s for the T5 version (32 s on an idle machine). The 48 files of the NEW folders include the new `docs/qa/T5/new/heel_front_band_shoes_new.png`.

### 2.1 Mutants

Each mutant lives in its own clean clone of the repository (`git clone`, at `e0f15be`, updated to `8de60f5` with `git pull` before the final test runs); the work tree was never touched. Following the reproducibility reviewer's caution, the effect of each contour mutant on step 2 was measured first (`<scratch>/t5fix/mutants/effect.R`: recomputes step 2 for one shoe from the clone's contour and counts the committed rows that differ).

```bash
cd <scratch>/t5fix/mutants
python3 mutate_contour.py clone_m0 591 200     # M0: row 200 of record 591 one column right
python3 mutate_contour.py clone_m1 591 all     # M1: the whole record 591 one column right
python3 mutate_contour.py clone_m2 591 all     # M2: as M1, then NEW step 2 rerun (below)
for m in m0 m1; do Rscript effect.R clone_$m 591; done
```
```
record 591: rows 200 shifted one column right; contour px before 703, after 703; bytes changed 4
record 591: rows all shifted one column right; contour px before 703, after 703; bytes changed 1232
record 591: rows all shifted one column right; contour px before 703, after 703; bytes changed 1232
shoe code 591: 703 contour px; rows 107; rows that differ from the committed step-2 CSV: min_dist 0, horiz_dist 0, distance_shape 0, new_x 0
largest |change|: min_dist 0.000000 (0.00 px), horiz_dist 0.000000, new_x 0.000000
shoe code 591: 703 contour px; rows 107; rows that differ from the committed step-2 CSV: min_dist 107, horiz_dist 107, distance_shape 0, new_x 107
largest |change|: min_dist 0.003333 (1.00 px), horiz_dist 0.003333, new_x 0.004234
```
M0 changes no step-2 row, so nothing is stale and the test must pass; M1 makes all 107 rows of shoe 591 stale (by up to 1 px, new_x by up to 0.0042), as both reviewers found. For M2, NEW step 2 was rerun in the clone, which changes exactly shoe 591's rows:
```bash
cd <scratch>/t5fix/mutants/clone_m2 && RAC_DATASET=new bash tools/run_pipeline.sh --steps 2 && git status --short
git show HEAD:processed_data/new/dataCC_distance_new.csv > ../head_dist.csv
Rscript -e 'a <- read.csv("../head_dist.csv"); b <- read.csv("processed_data/new/dataCC_distance_new.csv"); v <- c("min_dist","horiz_dist","distance_shape","new_x"); d <- rowSums(a[v] != b[v]) > 0; cat("rows changed by the step-2 rerun:", sum(d), "; shoe codes:", unique(a$shoe[d]), "\n")'
```
```
run_pipeline.sh: dataset new, steps 2, logs logs/new
step2: exit 0, 27.249305582 s
run_pipeline.sh: done (new, steps 2)
 M data/new_shoes/contour_Active_Contour_new.txt
 M processed_data/new/dataCC_distance_new.csv
 M processed_data/new/dataCC_distance_temp_new.csv
rows changed by the step-2 rerun: 107 ; shoe codes: 591 
```
The test in each clone (at `8de60f5`):
```bash
for m in m0 m1 m2; do (cd clone_$m && Rscript tests/r/test_new_outputs.R > ../test_$m.log 2>&1; echo "exit $?"); cut -c1-120 test_$m.log; done
```
```
exit 0
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw 
PASS step 2: (n_Acc, x, y, shoe) = dataCC; finite distances, horiz_dist >= min_dist, |new_x| <= distance_shape; every di
PASS step 3 GLMM: converged, 25 fixed effects, 631 groups, 83090 rows; fitted on the committed CSV (its basis = the knot
PASS step 3 CML: 24 coefficients, 19990 events; fitted on the committed CSV (its basis = the knots of the CSV, status = 
PASS OLD-basis NEW_X_NS_XY (A-112): on the OLD basis and fitted on the committed CSV (y, shoe, X) 
PASS OLD-basis CML_MODEL (A-112): on the OLD basis and fitted on the committed CSV (status, strata, X, n) 
PASS negative control: the model-CSV comparisons reject a CSV with one shoe's new_x moved by a pixel (X), a case and a c
PASS step 5: wald_test_new.csv W = 585.8888, df 24, vcov RX = the W of the committed GLMM 
PASS steps 4-6: the 8 NEW PDFs and their PNG twins exist (existence only; a stale figure is not detected here) 
PASS no collision: 47 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the ol
ALL PASS test_new_outputs
exit 1
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw 
FAIL step 2 : step 2 recomputed from the committed contour differs from dataCC_distance_temp_new.csv and dataCC_distance
[... 8 PASS lines omitted: step 3 GLMM to no collision, as for M0 ...]
Error: 1 check(s) failed: step 2
Execution halted
exit 1
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw 
PASS step 2: (n_Acc, x, y, shoe) = dataCC; finite distances, horiz_dist >= min_dist, |new_x| <= distance_shape; every di
FAIL step 3 GLMM : the step-3 GLMM was not fitted on dataCC_distance_new.csv (basis, X differ): rerun NEW steps 3-6 
FAIL step 3 CML : the step-3 CML was not fitted on dataCC_distance_new.csv (basis, X differ): rerun NEW steps 3-6 
FAIL OLD-basis NEW_X_NS_XY : the OLD-basis NEW_X_NS_XY refit was not fitted on dataCC_distance_new.csv (X differ): rerun
FAIL OLD-basis CML_MODEL : the OLD-basis CML_MODEL refit was not fitted on dataCC_distance_new.csv (X differ): rerun too
PASS negative control: the model-CSV comparisons reject a CSV with one shoe's new_x moved by a pixel (X), a case and a c
PASS step 5: wald_test_new.csv W = 585.8888, df 24, vcov RX = the W of the committed GLMM 
PASS steps 4-6: the 8 NEW PDFs and their PNG twins exist (existence only; a stale figure is not detected here) 
PASS no collision: 47 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the ol
Error: 4 check(s) failed: step 3 GLMM; step 3 CML; OLD-basis NEW_X_NS_XY; OLD-basis CML_MODEL
Execution halted
```
The untruncated M1 FAIL line: `FAIL step 2 : step 2 recomputed from the committed contour differs from dataCC_distance_temp_new.csv and dataCC_distance_new.csv; the rows of 1 shoe code(s) differ (first: 591): rerun NEW steps 2-6`. So M0 passes (nothing is stale), M1 fails at step 2 and names shoe 591, M2 fails at all four model checks (step 5 passes: its W is still the W of the committed GLMM). The previous version of the test (from `4cc6ffe`) on M1, run once from the same clone, reproduces the reviewers' finding:
```bash
cd <scratch>/t5fix/mutants/clone_m1 && git show 4cc6ffe:tests/r/test_new_outputs.R > tests/r/test_new_outputs_at_4cc6ffe.R && (Rscript tests/r/test_new_outputs_at_4cc6ffe.R 2>&1 | cut -c1-200; echo "exit ${PIPESTATUS[0]}"); rm tests/r/test_new_outputs_at_4cc6ffe.R
```
```
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw records, the erase list, the stamp mask (>= 8 shoes, no pixel swept) and the RAC
PASS step 2: (n_Acc, x, y, shoe) = dataCC; finite distances, horiz_dist >= min_dist, |new_x| <= distance_shape; every distance_shape a half-width of the prototype in its own frame; 631 contour records
PASS step 3: GLMM converged (25 fixed effects, 631 groups, 83090 rows, X rebuilt from the CSV = getME(X), sigma^2 0.7556); CML 24 coefficients, 19990 events; both on the NEW basis; the OLD-basis refit
PASS step 5: wald_test_new.csv W = 585.8888, df 24, vcov RX 
PASS steps 4-6: the 8 NEW PDFs and their PNG twins exist 
PASS no collision: 47 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the old_added lists and README files 
ALL PASS test_new_outputs
exit 0
```
**Statements corrected** (each now says what the test checks, or carries a dated correction marker): `README.md` (the NEW outputs paragraph), `docs/tests/README.md` (layout row of `tests/r/`), `docs/tests/T5-new-pipeline-results.md` lines 3, 539 and 753 (and a corrections block at its top), `docs/progress/LOG.md` (the T5 entry's open issue), plan T5 step 1 and T8.

## 3. Goodness of fit and the NEW heel-front band (A-114)

The statistics reviewer's diagnostic scripts used a scratch file (`offcontact.rds`); the committed probe `docs/qa/T5/probes/t5_gof.R` recomputes everything from committed files, and adds the contact surface pixel by pixel (sections E, F) instead of only the controls. One difference from the reviewer's runs: the y lattice of both datasets is (k + 0.5) / 300, so rows lie exactly on the edges of a +-0.02 or +-0.04 window and their inclusion depended on the rounding of y; the probe makes it explicit (+-6 px for the cuts, both edge rows included; strictly within 0.04, +-11 px, around the map maxima). That moves the reviewer's cut-250 O/E 0.805 to 0.802 and the peak window's 0.668 to 0.651; nothing else changes.

```bash
Rscript docs/qa/T5/probes/t5_gof.R docs/qa/T5/compare
```
```
== A. cells of 0.04 (new_x) x 0.08 (y), GLMM fitted with BLUPs
old: 112 cells with E >= 15 (51702 rows of 51848 in the grid); |z| > 3: 0, |z| > 2: 10, sum z^2 154
   rows outside the grid: 1 (0 cases)
new: 113 cells with E >= 15 (82892 rows of 83088 in the grid); |z| > 3: 8, |z| > 2: 28, sum z^2 319
   rows outside the grid: 2 (0 cases)
         new_x             y   O     E   OE     z
   (0.12,0.16]  (-0.2,-0.12]  87 137.5 0.63 -5.31
   (0.08,0.12]  (-0.2,-0.12]  95 126.1 0.75 -3.39
 (-0.08,-0.04]  (-0.2,-0.12]  62  87.1 0.71 -3.26
      (0,0.04]  (-0.2,-0.12]  26  44.1 0.59 -3.22
     (-0.04,0]  (-0.2,-0.12]  39  59.8 0.65 -3.21
   (0.04,0.08]  (-0.2,-0.12]  51  73.0 0.70 -3.10
 (-0.16,-0.12] (-0.52,-0.44]  97  73.4 1.32  3.23
 (-0.16,-0.12]   (0.04,0.12] 195 154.5 1.26  3.88
written docs/qa/T5/compare/residual_cells_old_vs_new.csv 
NEW cells with E >= 15 in y (-0.20, -0.12]: 7, O/E 0.59 to 0.81, z -5.3 to -2.1

== B. y profile (0.02 bins), GLMM fitted with BLUPs
old (overall case/control 0.343)
y                  ctrl  cases   ratio    O/E      z  shoes
[... 10 lines omitted: (-0.36,-0.34] to (-0.18,-0.16], O/E 0.896 to 1.106, |z| <= 2.76 ...]
(-0.16,-0.14]       302     93   0.308  0.921  -1.00     51
(-0.14,-0.12]       247     66   0.267  0.795  -2.38     40
(-0.12,-0.1]        264     60   0.227  0.729  -3.06     34
[... 5 lines omitted: (-0.1,-0.08] to (-0.02,0], O/E 0.934 to 1.106 ...]
new (overall case/control 0.317)
y                  ctrl  cases   ratio    O/E      z  shoes
(-0.36,-0.34]      1074    267   0.249  0.879  -2.53    173
(-0.34,-0.32]      1117    368   0.329  1.025   0.57    231
(-0.32,-0.3]       1406    604   0.430  1.064   1.92    284
(-0.3,-0.28]       1549    757   0.489  1.133   4.38    308
(-0.28,-0.26]      1780    910   0.511  1.176   6.19    347
(-0.26,-0.24]      1830    756   0.413  1.015   0.51    301
(-0.24,-0.22]      1526    698   0.457  1.076   2.48    299
(-0.22,-0.2]       1084    389   0.359  0.980  -0.49    218
(-0.2,-0.18]        667    182   0.273  0.849  -2.70    106
(-0.18,-0.16]       537    133   0.248  0.841  -2.40     78
(-0.16,-0.14]       492     82   0.167  0.619  -5.27     58
(-0.14,-0.12]       478     56   0.117  0.429  -7.91     41
(-0.12,-0.1]        399     77   0.193  0.672  -4.24     56
(-0.1,-0.08]        389    108   0.278  0.875  -1.70     81
(-0.08,-0.06]       406    176   0.433  0.989  -0.19    104
(-0.06,-0.04]       475    230   0.484  1.069   1.28    142
(-0.04,-0.02]       521    261   0.501  1.126   2.44    158
(-0.02,0]           698    309   0.443  1.058   1.26    190

== C. local maxima of the step-4 map surface (31 x 31 px window)
old: map eta median -1.506
   new_x        y  eta-med   plot x,y  cases   ctrl     O/E      z  ratio/all
  -0.062   -0.282     0.32 0.44,0.29    307    626   0.970  -0.72       1.43
  -0.045    0.305     0.37 0.45,0.73    242    561   0.952  -1.03       1.26
  -0.018    0.058     0.24 0.48,0.55    123    323   0.930  -1.06       1.11
   0.182   -0.128     0.37 0.68,0.40      6      8   1.464   1.22       2.19
   0.222    0.275     0.23 0.72,0.71     20     53   1.094   0.50       1.10
new: map eta median -1.480
   new_x        y  eta-med   plot x,y  cases   ctrl     O/E      z  ratio/all
  -0.068   -0.312     0.31 0.43,0.26    417    823   1.056   1.46       1.60
  -0.058    0.322     0.16 0.44,0.75    339    942   0.950  -1.20       1.14
   0.005    0.012     0.28 0.50,0.51    148    312   1.007   0.12       1.50
   0.135   -0.155     0.30 0.63,0.38    104    504   0.651  -5.43       0.65
   0.188    0.365     0.40 0.68,0.78     43    119   1.007   0.06       1.14
   0.232    0.052     0.45 0.73,0.54     72    139   1.156   1.56       1.64

== D. the step-5 CI cuts: O/E within +-0.02 of the cut's y
old row 110 (y = 0.292): pooled O 827, E 832.5, O/E 0.993, z -0.24; right-half maximum of the curve at new_x 0.002 (column 154): O/E 0.922 (z -1.10, O 108); the model-based Random band there -12.6% / +14.4%
[... 1 line omitted: O/E per 0.04 new_x bin ...]
old row 190 (y = 0.025): pooled O 545, E 567.6, O/E 0.960, z -1.22; right-half maximum of the curve at new_x 0.225 (column 221): O/E 0.537 (z -1.73, O 5); the model-based Random band there -24.0% / +31.5%
[... 1 line omitted ...]
old row 250 (y = -0.175): pooled O 357, E 339.2, O/E 1.053, z 1.25; right-half maximum of the curve at new_x 0.178 (column 207): O/E 1.592 (z 1.96, O 9); the model-based Random band there -28.9% / +40.7%
[... 1 line omitted ...]
new row 110 (y = 0.292): pooled O 1169, E 1158.2, O/E 1.009, z 0.39; right-half maximum of the curve at new_x 0.215 (column 218): O/E 1.042 (z 0.15, O 9); the model-based Random band there -23.8% / +31.2%
[... 1 line omitted ...]
new row 190 (y = 0.025): pooled O 886, E 882.8, O/E 1.004, z 0.13; right-half maximum of the curve at new_x 0.225 (column 221): O/E 1.241 (z 1.22, O 21); the model-based Random band there -18.7% / +22.9%
[... 1 line omitted ...]
new row 250 (y = -0.175): pooled O 304, E 378.8, O/E 0.802, z -4.65; right-half maximum of the curve at new_x 0.135 (column 194): O/E 0.704 (z -3.46, O 63); the model-based Random band there -10.5% / +11.8%
   by new_x bin: (-0.16,-0.12] 0.73 (z -0.9, O 6); (-0.12,-0.08] 0.89 (z -1.0, O 55); (-0.08,-0.04] 0.73 (z -2.4, O 37); (-0.04,0] 0.69 (z -2.2, O 25); (0,0.04] 0.96 (z -0.2, O 25); (0.04,0.08] 0.79 (z -1.6, O 33); (0.08,0.12] 0.84 (z -1.6, O 60); (0.12,0.16] 0.71 (z -3.2, O 57); (0.16,0.2] 1.96 (z 2.0, O 6)

== E. NEW: O/E in y (-0.16, -0.10] per block of 49 shoe ids
block       ids     O       E    O/E      z
    1    1-49       1    28.0   0.04  -6.53
    2   50-98       5    17.2   0.29  -4.10
    3   99-147      3    22.8   0.13  -5.11
    4  148-196      6    25.1   0.24  -4.86
    5  197-245      2    19.4   0.10  -4.75
    6  246-294      0     6.9   0.00  -3.25
    7  295-343     10    27.0   0.37  -3.79
    8  344-392     36    42.9   0.84  -1.24
    9  393-441     34    35.2   0.97  -0.25
   10  442-490      6    26.0   0.23  -4.66
   11  491-539     43    44.1   0.98  -0.19
   12  540-588     48    51.8   0.93  -0.62
   13  589-631     21    31.2   0.67  -2.28
band y (-0.18, -0.10], from the case-control rows:
group A   392 shoes, 14109 cases (70.6% of NEW) | band: cases  70, controls  768, ratio 0.091 (group 0.360), O/E 0.32, z -12.4; shoes with a control there 225, with a case 37
group B   239 shoes,  5881 cases (29.4% of NEW) | band: cases 278, controls 1138, ratio 0.244 (group 0.246), O/E 0.88, z -2.5; shoes with a control there 229, with a case 118
group all 631 shoes, 19990 cases (100.0% of NEW) | band: cases 348, controls 1906, ratio 0.183 (group 0.317), O/E 0.65, z -9.8; shoes with a control there 454, with a case 155
band = rows 214-237 of the NEW frame (y = (183.5 - row) / 300)
band y (-0.18, -0.10], from the contact surface S (pixels):
group A   S px in the band  75489 of 3640750 (2.1%); RAC px in the band   70 of 14109 (0.50%); RAC px per S px: band 0.00093, whole shoe 0.00388 (ratio 0.24); shoes with S in the band 323 (with >= 50 px 230), with a RAC px there 37
group B   S px in the band 101438 of 2156141 (4.7%); RAC px in the band  278 of  5881 (4.73%); RAC px per S px: band 0.00274, whole shoe 0.00273 (ratio 1.00); shoes with S in the band 237 (with >= 50 px 232), with a RAC px there 118
group all S px in the band 176927 of 5796891 (3.1%); RAC px in the band  348 of 19990 (1.74%); RAC px per S px: band 0.00197, whole shoe 0.00345 (ratio 0.57); shoes with S in the band 560 (with >= 50 px 462), with a RAC px there 155
OLD all: S px in the band 130454 of 4080720 (3.2%); RAC px in the band 368 of 13249 (2.78%); RAC px per S px: band 0.00282, whole shoe 0.00325 (ratio 0.87)

== F. the same_shoe reprints of T0: the band on both prints
67 same_shoe pairs (group A 50, group B 17); y shift NEW - OLD of the matched RACs (px): median 0, |shift| <= 3 px for 62 pairs, range -4 to 10
group A (50 pairs): RAC px in the band: NEW prints 4 of 2420 (0.17%), OLD prints of the same soles 7 of 2232 (0.31%); S px in the band: NEW 1.9% of S, OLD 1.9%; RAC px per S px in the band: NEW 0.00040, OLD 0.00068
group B (17 pairs): RAC px in the band: NEW prints 17 of 735 (2.31%), OLD prints of the same soles 31 of 668 (4.64%); S px in the band: NEW 4.1% of S, OLD 3.5%; RAC px per S px in the band: NEW 0.00265, OLD 0.00532
group A, the OLD band moved by each pair's y shift: RAC px 7 of 2232
RAC px in the band, all OLD shoes: 368 of 13249 (2.78%)

== G. A by group (cells with E >= 15)
NEW group A: 112 cells with E >= 15 (53172 rows of 53307 in the grid); |z| > 3: 11, |z| > 2: 32, sum z^2 387
         new_x             y   O     E   OE     z
   (0.12,0.16]  (-0.2,-0.12]  20  50.2 0.40 -5.33
     (-0.04,0]  (-0.2,-0.12]   4  25.6 0.16 -5.12
 (-0.08,-0.04]  (-0.2,-0.12]  10  33.1 0.30 -4.89
   (0.08,0.12]  (-0.2,-0.12]  21  47.2 0.45 -4.70
   (0.04,0.08]  (-0.2,-0.12]  11  29.5 0.37 -4.13
      (0,0.04]  (-0.2,-0.12]   4  16.6 0.24 -3.69
 (-0.12,-0.08]  (-0.2,-0.12]  14  30.0 0.47 -3.46
 (-0.16,-0.12]    (0.12,0.2] 155 125.8 1.23  3.06
 (-0.16,-0.12]   (0.04,0.12] 153 120.5 1.27  3.56
   (0.04,0.08] (-0.12,-0.04] 115  88.9 1.29  3.61
 (-0.16,-0.12] (-0.52,-0.44]  86  60.4 1.42  3.89
NEW group B: 102 cells with E >= 15 (29050 rows of 29781 in the grid); |z| > 3: 0, |z| > 2: 12, sum z^2 166

== H. a richer basis (Efron CML; expected per row n_i w / sum w)
old (6 s for the three fits):
  K8       24 coef, loglik -64623.37; cells E >= 15: 112, |z| > 3: 1, sum z^2 182 ; window (0.182, -0.128): O/E 1.424, z 1.17 
  full     34 coef, loglik -64603.84; cells E >= 15: 112, |z| > 3: 0, sum z^2 149 ; window (0.182, -0.128): O/E 1.463, z 1.24 
  full_5x9 76 coef, loglik -64560.51; cells E >= 15: 110, |z| > 3: 0, sum z^2 86 ; window (0.182, -0.128): O/E 1.261, z 0.81 
new (9 s for the three fits):
  K8       24 coef, loglik -96639.22; cells E >= 15: 113, |z| > 3: 10, sum z^2 330 ; window (0.135, -0.155): O/E 0.638, z -5.84 
  full     34 coef, loglik -96591.90; cells E >= 15: 113, |z| > 3: 3, sum z^2 248 ; window (0.135, -0.155): O/E 0.654, z -5.47 
  full_5x9 76 coef, loglik -96511.97; cells E >= 15: 113, |z| > 3: 2, sum z^2 207 ; window (0.135, -0.155): O/E 0.764, z -3.31 

t5_gof.R done in 32 s
```
(The z values are binomial and ignore the fit's estimation error and any dependence between RACs: descriptive. The full table of A is `docs/qa/T5/compare/residual_cells_old_vs_new.csv`, 253 cells.)

**Reading.**
- **Residual table (both datasets):** NEW 8 of 113 cells beyond |z| 3 and sum z^2 319, OLD 0 of 112 and 154: the reviewer's numbers, reproduced. Six of NEW's eight cells lie in y (-0.20, -0.12], all overpredicted (O/E 0.59-0.75); the other two are underpredicted (the left heel bottom, 1.32, and the left midfoot edge, 1.26).
- **The band:** the y profile shows NEW's overprediction from -0.20 to -0.10, deepest in (-0.14, -0.12] (O/E 0.43, z -7.9), flanked by underpredicted heel-pad rows (-0.30, -0.26] (1.13, 1.18) and the dense rows above the band; OLD has a mild dip only ((-0.14, -0.10]: 0.80, 0.73).
- **Map maxima:** five of NEW's six local maxima are supported by their own data (O/E 0.95-1.16); the one at the right heel-midfoot (new_x 0.135, y -0.155; plot 0.63, 0.38) is contradicted: O/E 0.65, z -5.4, a raw case/control ratio 0.65 times NEW's. The surface bridges the band between the dense rows above it and the heel pads below it, and on the right side the bridge forms a local maximum. OLD's maxima are supported (0.93-1.09; the one at 1.46 has 14 rows).
- **The CI cuts:** NEW cut 250 runs through the band: pooled O/E 0.80 (z -4.6) and 0.70 at the curve's right peak (z -3.5), where step 5's model-based Random band is -10.5% / +11.8%: the NEW curve stands about 25% above the data there (40% at the right peak) and its band does not show it. NEW cuts 110 and 190 fit (1.01, 1.00), and so do OLD's three (0.96-1.05).
- **Which shoes (E):** the deficit sits in id blocks 1-7 and 10 (O/E 0.00-0.37), not in 8, 9, 11, 12 (0.84-0.98); block 13 is in between (0.67). Group A = ids 1-343 and 442-490 is the reviewer's post-hoc split, reproduced: 392 shoes, 70.6% of NEW's cases.
- **Pixel by pixel (new evidence):** group A's soles do print in the band (75,489 contact px, 2.1% of their contact, on 323 of 392 shoes, 230 of them with at least 50 px), but carry 0.24 times their own RAC density there; group B 1.00; all OLD 0.87. So the deficit is RACs missing where there is contact, not missing contact.
- **The same soles in OLD (F):** the 67 `same_shoe` pairs are registered alike in y (median shift 0 px, within 3 px for 62 pairs), so the band is the same place on both prints. The OLD prints of the 50 group-A soles also print in the band (1.9% of their contact, as their NEW prints) and carry 7 of 2,232 RAC px there (0.31%; all OLD 2.78%); moving the band by each pair's shift gives the same 7. The missing RACs belong to the soles, not to how NEW was marked.
- **By group (G):** group B alone has no cell beyond |z| 3 (sum z^2 166, as OLD's 154 on 112 cells); group A has 11 (387), seven of them in the band. The pooled surface sits between the two groups.
- **A richer basis (H):** the full tensor and a 5 x 9-knot full tensor lower NEW's misfit (10 -> 3 -> 2 cells beyond |z| 3) but leave the window at O/E 0.65 and 0.76: one smooth surface for all shoes cannot follow it.

**Figures (looked at).**
```bash
PYTHONPATH=. python -B docs/qa/T5/probes/t5_band_figure.py docs/qa/T5/compare docs/qa/T5/new
```
```
docs/qa/T5/compare/heel_front_band_old_vs_new.png
docs/qa/T5/new/heel_front_band_shoes_new.png (1813, 2197)
block ids      all_A  shoes_S>=50  shoes_RAC  S_band  RAC_band
    1   1-49       1           36          1   11971         1
    2  50-98       1           26          4    6807         5
    3  99-147      1           27          2    7309         3
    4 148-196      1           32          3    7905         8
    5 197-245      1           25          4    6300         5
    6 246-294      1            9          0    3434         0
    7 295-343      1           27          7   16311        21
    8 344-392      0           48         26   18587        60
    9 393-441      0           48         22   21489        56
   10 442-490      1           48         16   15452        27
   11 491-539      0           48         24   22457        53
   12 540-588      0           48         28   23365        67
   13 589-631      0           40         18   15540        42
```
- `docs/qa/T5/compare/heel_front_band_old_vs_new.png`. **Top row**, the share of shoes with contact per pixel. NEW group A's mean print is a round-lug sole: round lugs over the forefoot, a narrow waist at rows 200-245 and four round heel pads in two pairs (rows 250-275 and 300-325); the band, between the cyan lines, lies on the waist. NEW group B's mean print is a continuous outsole with contact through the band; OLD's has a milder waist. **Middle row**, the RAC pixels per contact pixel. Group A is bright (dense) just above the band (rows 190-210) and on the front heel pads, and near black inside the band. Group B is even through the band, and OLD has a small dark patch there. **Bottom row**, along y: group A's RAC density drops from about 0.007 just above the band to about 0.0005 inside it and rises to about 0.006 at the heel pads; the OLD prints of the 50 group-A reprints (dashed) drop to about 0 in the band with a peak of 0.009 above it; group B stays near 0.0025-0.003; OLD dips mildly to 0.0022. The contact share per bin has a deep minimum in the band for group A and for the reprints' OLD prints (about 0.005 of their contact per 6-row bin), against about 0.01 for group B.
- `docs/qa/T5/new/heel_front_band_shoes_new.png` (the 7 shoes of each block with the most contact in the band, rows 150-300; looked at in seven full-resolution crops of two block rows each, `<scratch>/t5fix/fig/crop_rows_*.png`). Group A, blocks 1-4 (22, 15, 35, 14, 19, 18, 23; 97, 56, 92, 74, 55, 66, 91; 143, 123, 124, 147, 104, 114, 105; 173, 186, 162, 169): round-lug runners. Their band crosses the lowest lug row and a hatched or striped shank bridge above the two front round heel pads; the RACs (green) sit on the lugs above and on the heel pads, with 0-2 in the band. Block 4 also holds block-grid soles with heel pads (194, 193, 192), with the same layout. Block 5: boots with lug bars (231, 235, 234, 233, the shank with moulded text), 228 and 229 with the band at the top of the heel block. Block 6: military boots (247, 271, 248, 258, 275, 283, 282), with the band at the heel breast. Block 7: moulded-name sneakers (329, 342, 335, 330, 334, 336, 331), with the band across the moulded logo of the shank; they have the most contact there of group A (986-1,547 px) and 0-7 RACs. Block 10 is mixed (466 and 467 with a moulded heel, 486 and 475 lugs, and 447 and 446 lattice soles with a continuous tread); its band holds 6 RACs against 26 expected. Group B, blocks 8, 9, 11-13: herringbone court soles (346, 347, 348), block grids (368, 369, 362), POLO-type soles (406, 402, 400, 399, 401, 407), runners with bars and moulded text (538, 539, 530, 531, 510, 511; 545, 546, 571, 557, 570, 558, 540), flat lattice soles (628, 630) and 598-599 (the other image type). Their tread runs through the band, and most of them carry RACs there (R0-R11).

**What this means (A-114).** One pooled surface for all NEW shoes misfits the heel front, and the fit there is a property of the soles. The waist, heel breast or shank logo of group A's soles prints, but it carries a quarter of their RAC density, on the NEW and on the OLD prints of the same soles alike. Our reading of the mechanism, not tested: that part of these soles meets the ground little in walking, so it collects little damage, yet it prints under the lab press. Group A is a post-hoc split by id blocks, not a design classification: it mixes several designs whose common feature is a waisted or recessed shank. Consequences, recorded in the plan:
- the NEW map reading is corrected (T5 results section 7 and F77: the right heel-midfoot maximum is withdrawn, and cut 250 is about a quarter too high at the heel front);
- T6 shows every OLD-vs-NEW map difference with and without group A, because the datasets mix designs differently;
- T7: Part 2 will reject in the band for design reasons, so it reports the residuals by group and words such a rejection as a design effect;
- T8 and the paper cite this under sole design (the editor's demand) and R1 point 4 (one intensity function for all shoes).

## 4. Inference, levels, sigma^2, K8 (A-115, A-116)

```bash
Rscript docs/qa/T5/probes/t5_inference.R
```
```
== 1. convergence of the NEW GLMM (lme4 1.1.38 )
check.conv.nobsmax: 10000 ; nobs 83090 ; derivatives stored: FALSE 
deviance at the stored optimum 83138.243772, -2 logLik 83138.243772; central-difference gradient (step 0.0001): |d/dtheta| 0.0237, max |d/dbeta| 0.0051 (term 23), median |d/dbeta| 0.0022

== 2. model-based and cluster(shoe)-robust Wald, Efron CML
old: Efron W model-based 394.2, cluster-robust 234.4 (ratio 0.595); robust/model SE median 1.132, max 1.373; cases 13249; W per case: exact CML 0.0318, GLMM (RX) 0.0323, Efron model-based 0.0298, robust 0.0177
new: Efron W model-based 580.9, cluster-robust 329.0 (ratio 0.566); robust/model SE median 1.064, max 1.211; cases 19990; W per case: exact CML 0.0288, GLMM (RX) 0.0293, Efron model-based 0.0291, robust 0.0165

== 3. the cost of K8 (Efron CML: step-3 basis vs full tensor)
old: K8 24 coef, loglik -64623.366; full 34 coef, loglik -64603.845; LR 39.04 on 10 df (p 2.5e-05, model-based); LR x 0.57 (about the robust deflation of W in 2) 22.3
y band (decile)        x_L     x_R |   K8 L full L   diff |   K8 R full R   diff
[-0.502,-0.395]     -0.138   0.139 |  -0.16   0.02   0.18 |  -0.11  -0.13  -0.02
(-0.395,-0.298]     -0.139   0.152 |  -0.22  -0.10   0.12 |  -0.09  -0.20  -0.11
(-0.298,-0.222]     -0.140   0.158 |  -0.12  -0.07   0.06 |   0.12   0.10  -0.02
(-0.222,-0.00833]   -0.119   0.171 |   0.08   0.13   0.05 |   0.33   0.37   0.04
(-0.00833,0.095]    -0.130   0.210 |  -0.29  -0.20   0.09 |  -0.00  -0.02  -0.02
(0.095,0.165]       -0.155   0.217 |  -0.29  -0.14   0.16 |   0.05   0.03  -0.02
(0.165,0.228]       -0.161   0.212 |  -0.20  -0.10   0.10 |   0.16   0.15  -0.02
(0.228,0.295]       -0.158   0.195 |  -0.32  -0.23   0.09 |   0.04   0.05   0.01
(0.295,0.375]       -0.145   0.178 |  -0.43  -0.42   0.01 |  -0.29  -0.30  -0.01
(0.375,0.512]       -0.119   0.133 |  -0.16  -0.33  -0.18 |  -0.27  -0.30  -0.03
   full - K8 at the left edge: -0.18 to 0.18, |diff| > 0.1 in 5 of 10 bands; at the right edge: -0.11 to 0.04, |diff| <= 0.06 in 9 of 10
   O/E across the width (u = new_x / distance_shape), GLMM with BLUPs:
[... 10 lines omitted: OLD, u bins; O/E 0.884 to 1.056 (|z| <= 1.96), except the 21 and 56 rows at the contour itself (2.072 and 0.710) ...]
new: K8 24 coef, loglik -96639.219; full 34 coef, loglik -96591.898; LR 94.64 on 10 df (p 6.4e-16, model-based); LR x 0.57 (about the robust deflation of W in 2) 53.9
y band (decile)        x_L     x_R |   K8 L full L   diff |   K8 R full R   diff
[-0.515,-0.412]     -0.138   0.135 |  -0.09   0.40   0.49 |  -0.06  -0.01   0.05
(-0.412,-0.312]     -0.137   0.149 |  -0.08  -0.21  -0.13 |   0.02  -0.13  -0.15
(-0.312,-0.245]     -0.146   0.160 |  -0.08  -0.18  -0.11 |   0.16   0.11  -0.05
(-0.245,-0.0617]    -0.131   0.158 |   0.01   0.16   0.15 |   0.21   0.27   0.07
(-0.0617,0.0783]    -0.125   0.205 |  -0.21  -0.03   0.18 |   0.13   0.12  -0.01
(0.0783,0.155]      -0.152   0.219 |  -0.20  -0.03   0.18 |   0.23   0.20  -0.03
(0.155,0.218]       -0.160   0.214 |  -0.05  -0.01   0.04 |   0.25   0.26   0.01
(0.218,0.288]       -0.159   0.199 |  -0.08  -0.03   0.05 |   0.16   0.17   0.01
(0.288,0.372]       -0.147   0.181 |  -0.14   0.01   0.14 |   0.13   0.14   0.01
(0.372,0.525]       -0.117   0.137 |   0.06   0.16   0.09 |   0.13   0.12  -0.01
   full - K8 at the left edge: -0.13 to 0.49, |diff| > 0.1 in 7 of 10 bands; at the right edge: -0.15 to 0.07, |diff| <= 0.06 in 8 of 10
   O/E across the width (u = new_x / distance_shape), GLMM with BLUPs:
   u (-1,-0.95]       rows     16 cases     7 O/E 2.606 z   2.98
   u (-0.95,-0.85]    rows    565 cases    82 O/E 0.778 z  -2.66
   u (-0.85,-0.7]     rows   6854 cases  1590 O/E 1.088 z   4.00
   u (-0.7,-0.4]      rows  13767 cases  3556 O/E 1.014 z   0.99
   u (-0.4,0]         rows  15598 cases  3786 O/E 0.966 z  -2.65
   u (0,0.4]          rows  17198 cases  3972 O/E 1.018 z   1.33
   u (0.4,0.7]        rows  16211 cases  3803 O/E 0.996 z  -0.34
   u (0.7,0.85]       rows   9161 cases  2181 O/E 0.957 z  -2.53
   u (0.85,0.95]      rows   3685 cases   992 O/E 1.032 z   1.23
   u (0.95,1]         rows     35 cases    21 O/E 1.821 z   3.62

== 4. the level of the maps (plan K3, D-009)
old: RAC px per S px 0.003247 (13249 / 4080720); map mean 0.001302 (map / empirical 0.401); MEAN_OFFSET -4.6143, exp(-sigma^2/2) 0.619
   predicted RAC total / observed: each shoe's BLUP 0.999; b = 0 0.636; b = 0 x exp(+sigma^2/2) 1.028; b = 0 x exp(-sigma^2/2) 0.394
new: RAC px per S px 0.003448 (19990 / 5796891); map mean 0.001771 (map / empirical 0.514); MEAN_OFFSET -4.4655, exp(-sigma^2/2) 0.685
   predicted RAC total / observed: each shoe's BLUP 0.995; b = 0 0.706; b = 0 x exp(+sigma^2/2) 1.029; b = 0 x exp(-sigma^2/2) 0.484
NEW / OLD: empirical RAC px per S px 1.062; map mean 1.361

t5_inference.R done in 25 s
```
```bash
Rscript -e 'cat(sprintf("LR x 0.57: NEW %.1f p %.2g ; OLD %.1f p %.3f ; chi2_10 95%% %.1f, 99.9%% %.1f\n", 94.64*0.57, pchisq(94.64*0.57, 10, lower.tail=FALSE), 39.04*0.57, pchisq(39.04*0.57, 10, lower.tail=FALSE), qchisq(0.95,10), qchisq(0.999,10)))'
```
```
LR x 0.57: NEW 53.9 p 5e-08 ; OLD 22.3 p 0.014 ; chi2_10 95% 18.3, 99.9% 29.6
```

### 4.1 Convergence
lme4 1.1-38 runs no gradient or Hessian check for more than 10,000 rows and stores no derivatives, so "code 0, no lme4 message" said nothing about convergence. The deviance function rebuilt from the committed CSV with step 3's own call equals -2 logLik at the stored optimum (83,138.243772), and its central-difference gradient is 0.024 in theta and at most 0.0051 in the fixed effects (median 0.0022): a converged fit (the reviewer's check, reproduced). T5 results section 6 and F75 now say this.

### 4.2 The Wald test
The model-based W of 580.9 (Efron CML; 585.9 for the GLMM) drops to 329.0 with a cluster-robust variance (OLD 394.2 -> 234.4, = plan F29); the conclusion (spatial structure, p far below any threshold) stands, but "p = 2.1e-108" has meaningless digits: it is now written "p < 1e-16 (model-based; the robust W comes with step 3b)". W grows with the number of cases (NEW 19,990, OLD 13,249): per case it is 0.0293 (NEW) and 0.0323 (OLD) for the GLMM, so a larger NEW W is not a stronger spatial effect, and W is not compared across the datasets.

### 4.3 The cost of K8 (A-116)
The full tensor fits NEW better than the K8 basis (LR 94.6 on 10 df; OLD 39.0). A robust deflation (about x0.57, the ratio of 4.2) leaves NEW far beyond chi^2_10 (53.9, p 5e-8) and OLD beyond the 5% point but not far (22.3, p 0.014; the review said "both far beyond"). At the left edge of the data the full tensor moves the log-intensity by -0.13 to +0.49 on NEW (more than 0.1 in 7 of 10 y bands, where the review said 6; the heel bottom from -0.09 to +0.40) and by -0.18 to +0.18 on OLD (5 of 10); at the right edge by at most 0.06 in 8 of 10 bands on NEW (the review said 9; 0.07 and -0.15 in two) and 9 of 10 on OLD. NEW's O/E across the width rises to 1.09 (z 4.0) at u in (-0.85, -0.70]. So the left-right contrast of the NEW maps is partly an artefact of K8's pinned left edge, while the right-edge stripe is supported (O/E 1.01-1.16 around its maxima, section 3 C). T6 adds the full-tensor fits of both datasets to its map comparison.

### 4.4 Map levels under K3
The observed RAC pixels per contact pixel differ by 6% between the datasets (0.003448 / 0.003247), the map means by 36% (0.001771 / 0.001302). The calibration shows why: with each shoe's own BLUP the committed GLMMs predict the observed RAC total (0.999, 0.995: the method works); with the random effect at 0 times exp(-sigma^2/2), as steps 4-6 draw the maps, they predict 0.394 (OLD) and 0.484 (NEW) of it, a dataset-dependent factor (sigma^2 differs); times exp(+sigma^2/2) both come to 1.03. So "OLD's shapes at higher levels" is dropped: under K3 the levels of the two datasets are not comparable, only the shapes. The numbers go to D-009 (Naomi's sign question).

### 4.5 What sigma^2 measures
```bash
Rscript docs/qa/T5/probes/t5_sigma2.R --offset-refit     # background, 7 min 43 s
```
```
== old: 386 shoes; cases per shoe min 1, median 22, mean 34.3, max 307
   cor(BLUP, log n) 0.992 ; cor(BLUP, log px) 0.140 ; cor(log n, log px) 0.149
   var log(n/100) 1.1336 ; its mean sampling variance 0.0997 ; difference 1.0339 ; sigma^2 0.9598 ; var(BLUP) 0.8579 ; var log(100/px) 0.0978
== new: 631 shoes; cases per shoe min 1, median 24, mean 31.7, max 281
   cor(BLUP, log n) 0.989 ; cor(BLUP, log px) 0.372 ; cor(log n, log px) 0.361
   var log(n/100) 0.9552 ; its mean sampling variance 0.0945 ; difference 0.8607 ; sigma^2 0.7556 ; var(BLUP) 0.6680 ; var log(100/px) 0.1205
== NEW offset refit, offset(log((px - n)/100)): conv 0, lme4 messages none; sigma^2 0.64102 (no offset 0.75561); intercept -6.3481 (no-offset intercept + mean(log(100/(px - n))) = -6.3522); largest |change| of a spatial coefficient 0.0835; 457 s

real	7m43.454s
user	7m42.039s
sys	0m1.245s
```
The shoe effect is the shoe's RAC count: the BLUPs correlate 0.99 with log n_i on both datasets, and the spread of log(n_i / 100) net of its sampling noise (1.03 OLD, 0.86 NEW) is what sigma^2 estimates (0.96, 0.76). sigma^2 is therefore the between-shoe dispersion of the RAC density (wear, marking), not a spatial parameter. On NEW the RAC count grows with the print size (cor 0.36; OLD 0.15), so the offset absorbs part of it: the NEW offset refit gives 0.641 (the reviewer's 0.6410 reproduced), while OLD's rose to 0.979 (F35); with the offset the OLD-NEW gap widens from 0.20 to 0.34. T6 gets these numbers (plan T6 (c), D-008).

## 5. Smaller fixes

### 5.1 The PNG seam (A-111 corrected)
```bash
python -B - <<'EOF'      # thesis venv python, repo root
import numpy as np
from PIL import Image
files = ['docs/qa/T5/old/NEW_X_NS_XY_SHOE.png', 'docs/qa/T5/old/CML_MODEL_SHOE.png',
         'docs/qa/T5/new/NEW_X_NS_XY_SHOE_new.png', 'docs/qa/T5/new/CML_MODEL_SHOE_new.png']
for f in files:
    a = np.asarray(Image.open(f).convert('RGB')).astype(int)
    h, w, _ = a.shape
    # coloured map pixels: not white, not grey/black
    sat = a.max(axis=2) - a.min(axis=2)
    col = sat > 60
    # the plot box: dark frame lines (rows where a long run is near black)
    dark = (a.sum(axis=2) < 150)
    frame_rows = [r for r in range(h) if dark[r].sum() > 0.5 * w * 0.6]
    # seam: a row with many white pixels where both neighbours are coloured
    white = (a.min(axis=2) > 245)
    seams = []
    for r in range(1, h - 1):
        both = col[r - 1] & col[r + 1] & white[r]
        if both.sum() > 20:
            seams.append((r, int(both.sum())))
    print(f, (h, w), 'frame rows (dark > 30% of width):', frame_rows[:3], '...', frame_rows[-3:], 'seam rows:', seams)
EOF
```
```
docs/qa/T5/old/NEW_X_NS_XY_SHOE.png (900, 900) frame rows (dark > 30% of width): [746, 747] ... [746, 747] seam rows: [(489, 177)]
docs/qa/T5/old/CML_MODEL_SHOE.png (900, 900) frame rows (dark > 30% of width): [746, 747] ... [746, 747] seam rows: [(489, 177)]
docs/qa/T5/new/NEW_X_NS_XY_SHOE_new.png (900, 900) frame rows (dark > 30% of width): [746, 747] ... [746, 747] seam rows: [(489, 177)]
docs/qa/T5/new/CML_MODEL_SHOE_new.png (900, 900) frame rows (dark > 30% of width): [746, 747] ... [746, 747] seam rows: [(489, 177)]
```
The left frame line of the plot box starts at row 122, so the seam (row 489 in all four) is at y = (747 - 489) / (747 - 122) = 0.413. Looked at: a 2x crop of rows 440-540 of the OLD and the NEW GLMM twins (`<scratch>/t5fix/fig/seam_zoom.png`) shows the white 1-px line at the same place in both, just above the dotted y = 0.4 grid line. A-111's "OLD at y = 0.49" was wrong; corrected there and in T5 results section 7.

### 5.2 The probes from a clean clone
`t5_step1_zoom.py` and `t5_stamp_figure.py` now state their prerequisites and order in their usage lines, and `docs/qa/T5/README.md` repeats them. Checked in a fresh clone at `8de60f5` (`<scratch>/t5fix/probes/verify_probe_order.sh`): first without the prerequisites (the reviewer's failure), then in the documented order, comparing with the committed files.
```bash
bash <scratch>/t5fix/probes/verify_probe_order.sh <scratch>/t5fix
```
```
8de60f5 test: the step-3 model checks report a stale basis with the other stale properties
== 1. t5_step1_zoom.py alone, into an empty folder
FileNotFoundError: [Errno 2] No such file or directory: '<scratch>/t5fix/probes/out/zoom/new/s_outside_contour_new.csv'
== 2. t5_step1_sheets.py, then t5_step1_zoom.py, same folder
sheets exit 0
zoom exit 0
s_outside_zoom_new.png = committed
== 3. t5_stamp_figure.py without NEW step 0 and without t5_stamp_mask.R
FileNotFoundError: [Errno 2] No such file or directory: '<scratch>/t5fix/probes/out/stamp/scr/new_sum.csv'
== 4. NEW step 0 in the clone (--jobs 14)
step 0 exit 0 in 157 s
-rw-r--r-- 1 mehes mehes 759 Nov  7 01:39 images_new/saved/freq_min_18_new.png
== 5. t5_stamp_mask.R, then t5_stamp_figure.py
stamp_mask exit 0
stamp_figure exit 0
stamp_mask_new.png = committed
stamp_worst_new.png = committed
stamp_shoes_new.csv = committed
stamp_threshold_old_vs_new.csv = committed
```
(`git status --short` after step 0 printed nothing: the in-place NEW step 0 rewrote the committed contour with the same bytes, as the README now says.)

### 5.3 The README's kernel-pin sentence and A-108 (A-117)
The README said the kernel pin stops an in-place NEW run from silently rewriting the committed contour. It does not stop another platform (a venv-wind NEW step 0 passes both checks and differs in 14 of 631 records at `088457d`; A-108's "13" was the T4 count). Corrected in the README and as a dated correction in A-108. No platform pin is added (A-117): a rewrite shows in `git status`, makes `tests/r/test_new_outputs.R` fail as soon as it changes step 2 (section 2) and makes `tests/rebuild_new.sh` fail; a pin would also stop T4's venv-wind comparison probe unless an override were added.

### 5.4 The hard-coding scan of `tools/*.R` (A-118)
`tests/r/test_no_hardcoding.R` scans `tools/*.R` as pipeline code (the Python scan treats `tools/` the same way); `tools/figures_png.R:60` (`res = 150`, a DPI) carries `# rac: literal-ok`.
```bash
Rscript tests/r/test_no_hardcoding.R
```
```
PASS scanner: comments and prose skipped, exemption marker, each rule 
PASS no dataset literal in 36 R/Rmd files (4 OLD-only files allowed) 
PASS every allowlisted file still needs its entry 
ALL PASS test_no_hardcoding
```
Without the marker (a temporary edit, restored in the same command; the diff afterwards showed only the marker change):
```
PASS scanner: comments and prose skipped, exemption marker, each rule 
tools/figures_png.R:60: dataset number: res = 150)
Error: 1 dataset literal(s) in R code
Execution halted
exit 1
```

### 5.5 Coefficient keys, the clash check and `tests/r/test_compare.R` (A-118)
`spatial_term_key()` maps `ns(dat$new_x, knots = knots_new_x)<j>:ns(dat$y, knots = knotsy)<i>` and `bx<j>:by<i>` to `x<j>:y<i>`; `fit_common_basis()` refuses data with a column `bx` or `by` (the check binds no variable, so the formula environment saved with a refit is unchanged: section 6.3 refits both OLD-basis models with it and compares the bytes).
```bash
Rscript tests/r/test_compare.R
```
```
PASS spatial_term_key: the 6 committed models (OLD and NEW step 3, the OLD-basis refits) all map to (Intercept), x1:y1 ... x4:y6 in the same positions; other names refused 
PASS fit_common_basis refuses data with a column named bx or by 
PASS fit_common_basis with the data's own basis = step 3's Random() on 20 NEW shoes (2258 rows, 258 cases): GLMM fixef, theta, vcov and CML coef, vcov identical(), same keys (29.4 s) 
ALL PASS test_compare
```
(The equality is one of code, so a small subsample suffices: 20 shoes with at most 25 cases keep it at 36 s; with 30 shoes of at most 40 cases it took 48 s and also passed.)

## 6. Gates

All three were run on the tree with every code change of this task (the code at `8de60f5`; the docs and probes were being written beside them, and no gate reads them). Several jobs ran at once (load up to about 17), so the times are long.

### 6.1 The fast suite
```bash
time bash tests/run_all.sh        # started 01:51, work tree = 8de60f5 + the uncommitted probes and docs
```
```
== sha256 committed_79247d8 (Tier A, 24 files)
== sha256 old_baseline (11 OLD artifacts)
== sha256 old_added_t2 (the 2 OLD files T2 added)
[... 271 lines omitted: the checksum checks and the verbose unittest output ...]
Ran 184 tests in 175.866s

OK (skipped=3)
[... 145 lines omitted: the PASS lines of the 17 R scripts (those of test_new_outputs.R, test_compare.R and test_no_hardcoding.R as in sections 2 and 5) and the lint runs, flake8: 88 files, shellcheck: 17 files ...]
== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS       207s  python unittest discover tests/python
PASS         7s  Rscript tests/r/test_baseline_committed.R
PASS        53s  Rscript tests/r/test_compare.R
PASS        32s  Rscript tests/r/test_compare_glmm_fits.R
PASS         5s  Rscript tests/r/test_compare_models.R
PASS        77s  Rscript tests/r/test_distances_vectorized.R
PASS        28s  Rscript tests/r/test_figures_png.R
PASS        42s  Rscript tests/r/test_new_outputs.R
PASS         3s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        48s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         2s  Rscript tests/r/test_profile.R
PASS        61s  Rscript tests/r/test_profile_sentinels.R
PASS        10s  Rscript tests/r/test_run_manifest.R
PASS         2s  Rscript tests/r/test_step5_variant.R
PASS        10s  Rscript tests/r/test_sticker_masks.R
PASS         5s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python files)
PASS         6s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS

real	10m3.431s
user	10m38.300s
sys	0m59.734s
exit 0
```
ALL PASS: 184 Python tests (3 skipped live checks), 17 R scripts (`test_compare.R` new), flake8 88 files (`t5_band_figure.py` new), shellcheck 17 files, and the work tree unchanged by the tests.

### 6.2 OLD regression: identical
Steps 1-6 (the steps whose R code neighbours this task's changes; `compare.R`, the tests and `tools/figures_png.R`'s comment are on no OLD step's path, which this gate shows):
```bash
RAC_SCRATCH=<scratch>/t5fix/gates bash tests/regress_old.sh --steps 1-6 --keep     # at 8de60f5, started 01:32
```
```
<scratch>/t5fix/gates/regress_old_dSCXKD

== regress_old.sh --steps 1-6: <scratch>/t5fix/gates/regress_old_dSCXKD
result  check                                          detail
PASS    pipeline run                                   every step exit 0, every output regenerated
PASS    step 1 all_cont.csv = Tier A                   data/all_cont.csv sha256 d582cf502184...
PASS    step 1 dataCC.csv = Tier A                     processed_data/dataCC.csv sha256 cc4a476976ae...
PASS    step 1 shoe_pixel_counts.csv = Tier A          processed_data/shoe_pixel_counts.csv sha256 24bbd19cff59...
PASS    step 1 shoe_codes.csv = old_added_t2           processed_data/shoe_codes.csv sha256 3d6c09fe66e1...
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
step1       110.847941485  0
step2       23.348354682   0
step3_glmm  267.695284077  0
step3_cml   283.616970986  0
step4_glmm  14.556154629   0
step4_cml   14.023139318   0
step5       26.899760622   0
step6       20.236596042   0
ALL PASS

real	12m55.455s
user	11m51.497s
sys	0m54.332s
```
The field-by-field model comparison it reads (`<run>/logs/compare_models.txt`):
```
fixef         n=25   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov          n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov_rx       n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
theta         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
sigma2        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
varcorr       n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
loglik        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
deviance      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
nobs          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
ngrps         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
conv          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=   NA
optimizer     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
cml_coef      n=24   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_vcov      n=576  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_loglik    n=2    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_n         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_nevent    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_iter      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_method    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
wald_glmm     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_glmm_rx  n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_cml      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
```
Step 0 (no step-0 code or profile value changed; run for completeness, after the steps 1-6 gate):
```bash
RAC_SCRATCH=<scratch>/t5fix/gates bash tests/regress_old.sh --steps 0
```
```
<scratch>/t5fix/gates/regress_old_XDyN7M

== regress_old.sh --steps 0: <scratch>/t5fix/gates/regress_old_XDyN7M
result  check                                          detail
PASS    pipeline run                                   every step exit 0, every output regenerated
PASS    step 0 OpenBLAS threads and kernel = baseline  16 threads, kernel Haswell
PASS    step 0 contour = Tier B (CRLF)                 data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B                  1556 npy/png files, all equal
PASS    live check test_snake_old_regression           logs/live_snake.txt
timings (s):
step   seconds        exit
step0  774.688069834  0
ALL PASS

real	14m18.091s
user	118m23.455s
sys	1m45.587s
```
**OLD regression: identical.** The five step-1/2 CSVs equal Tier A byte for byte and `shoe_codes.csv` its `old_added_t2` checksum; both models are `identical()` to Tier B in all 22 dumped fields (GLMM fixef, both vcovs, theta, sigma^2, logLik, deviance; CML coef, vcov, loglik, n, nevent, iter, method; the three Wald W); the 8 figures equal Tier B after removing their dates; the Wald W 427.7804472165 equals Tier B; step 0 writes the Tier B contour and 1,556 intermediates; the Tier A, `old_baseline` and `old_added_t2` checksums pass in the suite (6.1).

### 6.3 NEW determinism, with the OLD-basis refits and the PNG twins
The extended rerun probe (`--oldbasis --png`, section 2): NEW steps 1-6 in a scratch copy of the tree, then both OLD-basis refits (they ran `fit_common_basis()` with the clash check of A-118) and the 16 PNG twins, each compared with HEAD:
```bash
RAC_SCRATCH=<scratch>/t5fix/gates bash docs/qa/T5/probes/t5_new_rerun.sh --oldbasis --png     # started 01:33 at 8de60f5
```
```
<scratch>/t5fix/gates/new_rerun_wrZp59
run_pipeline.sh: dataset new, steps 1-6, logs logs/new
step1: exit 0, 247.170109156 s
step2: exit 0, 30.648231438 s
step3_glmm: exit 0, 575.463972133 s
step3_cml: exit 0, 401.608274930 s
step4_glmm: exit 0, 33.591137542 s
step4_cml: exit 0, 18.693388999 s
step5: exit 0, 35.353378963 s
step6: exit 0, 27.239414735 s
run_pipeline.sh: done (new, steps 1-6)
fitted CML_MODEL on the OLD basis in 363.6 s; written <scratch>/t5fix/gates/new_rerun_wrZp59/repo/saved_models/new/CML_MODEL_oldbasis_new.rds
fitted NEW_X_NS_XY on the OLD basis in 567.8 s; written <scratch>/t5fix/gates/new_rerun_wrZp59/repo/saved_models/new/NEW_X_NS_XY_oldbasis_new.rds
== CSVs (sha256: rerun vs HEAD)
SAME  processed_data/new/dataCC_new.csv 3c064f9dc5f0
SAME  processed_data/new/shoe_pixel_counts_new.csv 8faeb6735a39
SAME  processed_data/new/all_cont_new.csv 6513cc4283e5
SAME  processed_data/new/shoe_codes_new.csv ffbf32ae9bcf
SAME  processed_data/new/dataCC_distance_temp_new.csv ee3769786c4b
SAME  processed_data/new/dataCC_distance_new.csv 72e03d4efb89
SAME  processed_data/new/wald_test_new.csv fff19dcce95b
== models
fixef         n=25   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov          n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov_rx       n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
theta         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
sigma2        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
varcorr       n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
loglik        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
deviance      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
nobs          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
ngrps         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
conv          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=   NA
optimizer     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
cml_coef      n=24   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_vcov      n=576  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_loglik    n=2    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_n         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_nevent    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_iter      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_method    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
wald_glmm     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_glmm_rx  n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_cml      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
models: every field identical()
== PDFs (normalized sha256)
SAME  model_images/new/CI_cut_110_new.pdf 4e1e76fa04bf
SAME  model_images/new/CI_cut_190_new.pdf d5f73244fa97
SAME  model_images/new/CI_cut_250_new.pdf 139de94f41b9
SAME  model_images/new/CI_shoe_cuts_new.pdf 02bdbf9fc1bd
SAME  model_images/new/CML_MODEL_SHOE_new.pdf a550c2fb89f9
SAME  model_images/new/NEW_X_NS_XY_SHOE_new.pdf edf868cfa0f8
SAME  model_images/new/difference_random_cml_new.pdf 10611398f96a
SAME  model_images/new/pixel_inten_JASAup_new.pdf 83b79944b3e0
== the OLD-basis refits (A-112)
SAME  saved_models/new/NEW_X_NS_XY_oldbasis_new.rds (bytes)
SAME  saved_models/new/CML_MODEL_oldbasis_new.rds (bytes)
fixef         n=25   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov          n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov_rx       n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
theta         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
sigma2        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
varcorr       n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
loglik        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
deviance      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
nobs          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
ngrps         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
conv          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=   NA
optimizer     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
cml_coef      n=24   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_vcov      n=576  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_loglik    n=2    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_n         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_nevent    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_iter      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_method    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
wald_glmm     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_glmm_rx  n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_cml      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
OLD-basis refits: every field identical()
== PNG twins (bytes: rerun vs HEAD)
SAME  docs/qa/T5/new/CI_cut_110_new.png
SAME  docs/qa/T5/new/CI_cut_190_new.png
SAME  docs/qa/T5/new/CI_cut_250_new.png
SAME  docs/qa/T5/new/CI_shoe_cuts_new.png
SAME  docs/qa/T5/new/CML_MODEL_SHOE_new.png
SAME  docs/qa/T5/new/NEW_X_NS_XY_SHOE_new.png
SAME  docs/qa/T5/new/difference_random_cml_new.png
SAME  docs/qa/T5/new/pixel_inten_JASAup_new.png
new: 8 PNG twins drawn
SAME  docs/qa/T5/old/CI_cut_110.png
SAME  docs/qa/T5/old/CI_cut_190.png
SAME  docs/qa/T5/old/CI_cut_250.png
SAME  docs/qa/T5/old/CI_shoe_cuts.png
SAME  docs/qa/T5/old/CML_MODEL_SHOE.png
SAME  docs/qa/T5/old/NEW_X_NS_XY_SHOE.png
SAME  docs/qa/T5/old/difference_random_cml.png
SAME  docs/qa/T5/old/pixel_inten_JASAup.png
old: 8 PNG twins drawn
ALL SAME

real	34m15.109s
user	36m51.580s
sys	2m5.259s
```
**ALL SAME:** the 7 CSVs byte for byte, both step-3 models in all 22 fields, the 8 PDFs after removing their dates, both OLD-basis refits byte for byte as `.rds` files and in all 22 fields (so the clash check of `fit_common_basis()`, which binds no variable, left the saved formula environment unchanged), and the 8 NEW and 8 OLD PNG twins byte for byte. T8's `tests/e2e/test_new_rerun.sh` can start from this probe (34 minutes under load).

## 7. Files, timings, open points

| Kind | Files |
|---|---|
| tests | `tests/r/test_new_outputs.R` (rewritten: every shoe, models tied to the CSV, negative control, all checks run), `tests/r/test_compare.R` (new), `tests/r/test_no_hardcoding.R` (`tools/`) |
| code | `statistical_model/R/compare.R` (`spatial_term_key()`, the clash check), `tools/figures_png.R` (one comment marker) |
| probes | `docs/qa/T5/probes/t5_gof.R`, `t5_band_figure.py`, `t5_inference.R`, `t5_sigma2.R` (new); `t5_new_rerun.sh` (`--oldbasis`, `--png`); `t5_stamp_figure.py`, `t5_step1_zoom.py` (usage lines) |
| QA outputs (looked at) | `docs/qa/T5/compare/residual_cells_old_vs_new.csv`, `heel_front_band_old_vs_new.png`, `docs/qa/T5/new/heel_front_band_shoes_new.png` |
| docs | this file; `docs/tests/T5-new-pipeline-results.md` (corrections block, markers, residual table); `docs/decisions.md` (A-113 to A-118, corrections to A-108 and A-111, updates to D-008 and D-009); the plan (revision 13; F75, F77 corrected; F78-F83; section 5 row; T5-T8 notes; section 12); `docs/progress/LOG.md`; `README.md`; `docs/tests/README.md`; `docs/qa/T5/README.md` |

No OLD output, raw data file, profile value or step code changed; no NEW output of steps 1-6 changed (the rerun reproduces them, 6.3).

| What | Time (several jobs at once, load up to about 17) |
|---|---|
| `test_new_outputs.R` | 32 s idle (step 2 for all shoes 8.0 s), 38-42 s under load; T5 version 13.5 s |
| `test_compare.R` | 36 s idle, 53 s in the suite |
| `t5_gof.R` / `t5_inference.R` / `t5_sigma2.R` (with the offset refit) / `t5_band_figure.py` | 32-38 s / 25-28 s / 7 min 43 s (refit 457 s) / 22-27 s |
| mutant step-2 rerun (M2) | 27 s |
| probe-order check in a fresh clone (NEW step 0 with `--jobs 14`: 157 s) | about 5 min |
| `run_all.sh` | 10 min 3 s |
| `regress_old.sh --steps 1-6` / `--steps 0` | 12 min 55 s / 14 min 18 s |
| `t5_new_rerun.sh --oldbasis --png` | 34 min 15 s (GLMM 575 s, CML 402 s, refits 568 s and 364 s in parallel) |

**Open points.**
- T5 step 3b (shoe bootstrap and Efron-cluster robust variances on both datasets) is still to do; the robust W of 4.2 is the indicative Efron-cluster one.
- For Micha and Naomi (A-114): the NEW heel-front band is a sole-design effect with direct evidence (the OLD prints of the same soles agree); it bears on the editor's sole-design demand and R1 point 4. Group A is a post-hoc id-block split; a design classification of the soles (meeting question 6) would make the T6 and T7 splits principled.
- For Naomi (D-009): the K3 calibration numbers (exp(-sigma^2/2) puts the map level at 0.39 and 0.48 of the observed RAC density; exp(+sigma^2/2) at 1.03).
- For Shlomo (A-117): whether to pin the platform of NEW step 0 after all.
- For T6 (plan T6 (c), (d) and the closing sentence): sigma^2 as RAC-density dispersion with the NEW offset refit's 0.641; the full-tensor maps; every OLD-vs-NEW map difference with and without group A; levels only under a stated calibration; coefficients aligned with `spatial_term_key()`.
- For T7 (step 4, section 9): residuals by group; a rejection in the band worded as a design effect.
- For T8: the e2e rerun must compare the figures, the PNG twins and the OLD-basis refits (6.3 shows how).
