# T7 review fixes: exact commands and real outputs

**Date:** 2026-11-07. **Task:** fix the statistics review of T7-validation (LOG 2026-11-07 11:05, commit `84b2eff`): major findings 1-3 (the model-comparison intervals, the wording of named analysis 3, the size of the misfit) and minor findings 4-7 (the block bootstrap, the real-structure calibration, the context of Naomi's Nelder-Mead fit, the framing of the log-score gain). **Branch:** `feature/new-shoes-pipeline` (HEAD `a4edb42` when the task started; T7 itself had not been committed). Interpretation: `docs/results/validation.md` (revised); decisions T7-13 to T7-17 there. The first T7 run's commands and outputs stay in `docs/tests/T7-results.md`. Every block below is the real output of the command above it; trimmed output is marked `[... N lines omitted ...]`. The machine was shared with the T6 review-fix agent (its knit of `compare_old_new_7.Rmd` ran at the same time; load average 6 to 12).

## 1. What changed

| File | Change |
|---|---|
| `statistical_model/R/validation.R` | new: `part2_shift_ci()` (bootstrap interval centred on the point), `part2_uniform_expected()`, `part2_calib_slope()` (cell-level calibration slope, conditional on each shoe's total), `part2_pixel_slope()`, `part2_pixel_slope_grid()` and `part2_pixel_slope_boot()` (pixel-level slope and its shoe bootstrap), `part2_block_groups()`, `part2_shoe_sums()` (with a cumulative-sum path for pixel tables ordered by shoe), `part2_kl_uniform()` (the gain over uniform a model expects for itself) |
| `statistical_model/validation_8.Rmd` | the bootstrap also stores the OLD-noise dilution of the calibration slope and the block-bootstrap statistics (appended after the first run's statistics, which are unchanged); new sections 6b (uniform benchmark, cell-level slopes), 6c (pixel-level slope and its dilution, cached), 7b (blocks); section 7 rewritten (two estimands, centred intervals, the gain table, the split by RAC count); section 8 adds the uniform model and the in-sample slope; the log-score figure redrawn, a calibration figure added |
| `tests/r/test_validation_stats.R` | section 11: tests of every new function |
| `tests/r/slow/test_validation_real_calibration.R` | new: the plan's slow calibration on real structure, with coverage checks of both interval types |
| `docs/qa/T7/probes/t7_pair_profiles_hardcore.R` | new: toy pair profiles with inhibition (a 2-px hard core or a same-pixel exclusion) |
| new outputs | `processed_data/validation/new/part2_{benchmark,contrast,pixel_slope,logscore_gain,logscore_tercile,block}_new.csv`, `model_images/validation/new/part2_calibration_new.{pdf,png}` |
| changed outputs | `part2_logscore_new.csv` and `part2_delta_x2_new.csv` (interval columns: `_new`, `_two`, and the first run's interval as `_two_raw`), OLD `processed_data/validation/part2_tests.csv` (uniform rows, slope columns), the log-score figure |

## 2. Unit tests of the new functions

```
$ time Rscript tests/r/test_validation_stats.R
[... 13 lines omitted: sections 1-10, unchanged, ALL PASS as in docs/tests/T7-results.md section 5 ...]
PASS part2_shift_ci: the percentile interval moved so that the replicates' mean is the point 
PASS part2_uniform_expected: n_i S_ik / S_i by hand 
  cell slope 0.6071 (SE 0.0129, true 0.6) = Poisson GLM 0.6071
PASS part2_calib_slope = the Poisson GLM with shoe effects (alpha and SE); 1 for the model's own counts, 0 for uniform; weights = duplicates; counts off contact refused 
  pixel slope 0.7316 = cell slope with pixels as cells 0.7316; grid vs exact over 30 resamples: max 1.3e-11
PASS part2_pixel_slope = part2_calib_slope with every pixel a cell; 1 for the true counts; weights 0 drop shoes; grid bootstrap = exact per resample 
PASS part2_shoe_sums: the cumulative-sum path (codes in order) and rowsum agree; empty codes 0 
PASS part2_block_groups: consecutive ids in blocks 
  intensities 1 and 2 on equal areas: expected gain over uniform 0.0566 nats per RAC
PASS part2_kl_uniform: the expected log-score gain over uniform by hand 
ALL PASS test_validation_stats (34 s)

real	0m34.767s
```

Two things this caught while it was written: a test toy whose pixel counts were interleaved across shoes (a stray `t()`; the slope of the scrambled data was near 0, so some resamples fell below the grid and `part2_pixel_slope_boot()` refused them, as it should), and a one-step Newton solution on the grid accurate only to 2.4e-6, replaced by the root of a cubic Hermite interpolant of the score (1.3e-11).

## 3. Naomi's Nelder-Mead fit in its sampling context (minor finding 6)

```
$ grep -n "Nelder-Mead" docs/qa/T7/probes/t7_naomi2022.out
33:Nelder-Mead (2022 default): convergence 1, value 33099.7612; BFGS value 33098.1525
$ Rscript -e 'nm <- 33099.7612; bfgs <- 33098.1525; cat(sprintf("log-likelihood gap NM - BFGS optimum: %.4f units on 13 free parameters\n", nm - bfgs)); cat(sprintf("95%% joint likelihood-ratio region of 13 parameters: within %.3f log-likelihood units of the optimum (qchisq(0.95, 13) / 2)\n", qchisq(0.95, 13) / 2)); cat(sprintf("LR statistic of the NM point against the optimum: 2 x gap = %.3f on 13 df, p = %.3f\n", 2 * (nm - bfgs), pchisq(2 * (nm - bfgs), 13, lower.tail = FALSE)))'
log-likelihood gap NM - BFGS optimum: 1.6087 units on 13 free parameters
95% joint likelihood-ratio region of 13 parameters: within 11.181 log-likelihood units of the optimum (qchisq(0.95, 13) / 2)
LR statistic of the NM point against the optimum: 2 x gap = 3.217 on 13 df, p = 0.997
```

Correct but immaterial for Naomi's conclusions: the Nelder-Mead point lies deep inside the 95% joint likelihood region of the 13 relative intensities (and that region assumes independent RACs, which understates the uncertainty).

## 4. The pair profile with inhibition (finding 2)

```
$ time Rscript docs/qa/T7/probes/t7_pair_profiles_hardcore.R > docs/qa/T7/probes/t7_pair_profiles_hardcore.out
                d0 (0,2] (2,4] (4,8] (8,16] (16,32] (2,8]
null         1.047 1.014 1.020 0.991  0.976   0.966 0.997
null_d0      0.000 1.004 1.014 0.991  0.975   0.967 0.995
null_hc      0.000 0.000 1.035 0.987  0.972   0.965 0.997
smooth_03    1.148 1.096 1.076 1.048  1.013   0.974 1.054
smooth_03_d0 0.000 1.108 1.084 1.055  1.015   0.975 1.061
smooth_03_hc 0.000 0.000 1.094 1.046  1.013   0.978 1.056
smooth_05    1.275 1.227 1.194 1.156  1.097   0.999 1.164
smooth_05_d0 0.000 1.215 1.178 1.159  1.100   0.999 1.163
smooth_05_hc 0.000 0.000 1.197 1.136  1.086   1.003 1.149
smooth_08    1.596 1.527 1.484 1.407  1.272   1.047 1.423
smooth_08_d0 0.000 1.546 1.517 1.407  1.269   1.043 1.430
smooth_08_hc 0.000 0.000 1.442 1.352  1.235   1.044 1.370
fine_hc      0.000 0.000 2.180 1.844  1.365   0.894 1.913
clumps_hc    0.000 0.000 3.048 1.672  0.955   0.918 1.953
1880 s

real	31m21.998s
```

Rows: the scenario that generated the RACs (model true; smooth shoe-specific intensity at 40 px with log-sd 0.3, 0.5, 0.8; heterogeneity at 6-12 px; clumps of 2-4 RACs within 2-6 px), without inhibition, with same-pixel exclusion (`_d0`) or with a 2-px hard core (`_hc`); mean observed/expected pair ratio against null 2 over 50 toy replicates. Read: inhibition removes heterogeneity's excess at the shortest distances (so "no excess below 2 px" does not single out clustering), but leaves its slow decay beyond 2 px (log-sd 0.5 with a hard core: 1.20, 1.14, 1.09; NEW: 1.54, 1.31, 1.04). The rows without a core are a fresh Monte Carlo of the first probe's rows (`t7_pair_profiles.out`: smooth_05 1.284 1.235 1.201 1.173 1.101 0.999), equal within 0.04. Interpretation in `docs/results/validation.md`, named analysis 3.

## 5. How far the replicates sit from the point (finding 1)

NEW-only replicates (fits held fixed) of Delta X^2: the reviewer's probe `dx2_newonly.R`, rerun unchanged from the scratchpad (`t7rev/`), the same 2,000 resamples as the knit:

```
$ Rscript <scratch>/t7rev/dx2_newonly.R
primary  g10 dX2   49.4 NEW-only (fits fixed): mean   50.1 pct [  11.4,   91.7] basic [   7.1,   87.5] P(v<=0) 0.0040
primary  g15 dX2   56.2 NEW-only (fits fixed): mean   57.1 pct [   8.6,  110.1] basic [   2.3,  103.8] P(v<=0) 0.0095
primary  g20 dX2   71.9 NEW-only (fits fixed): mean   72.5 pct [  20.3,  128.1] basic [  15.7,  123.5] P(v<=0) 0.0025
primary  a14 dX2  128.1 NEW-only (fits fixed): mean  129.9 pct [  71.9,  189.8] basic [  66.4,  184.2] P(v<=0) 0.0000
all      g10 dX2  100.5 NEW-only (fits fixed): mean  101.2 pct [  56.5,  151.1] basic [  50.0,  144.6] P(v<=0) 0.0000
all      g15 dX2  104.4 NEW-only (fits fixed): mean  105.3 pct [  49.2,  165.8] basic [  43.1,  159.7] P(v<=0) 0.0000
all      g20 dX2  127.2 NEW-only (fits fixed): mean  128.3 pct [  66.0,  190.4] basic [  63.9,  188.3] P(v<=0) 0.0000
all      a14 dX2  199.4 NEW-only (fits fixed): mean  198.9 pct [ 127.9,  271.4] basic [ 127.4,  270.9] P(v<=0) 0.0000
```

So the NEW-only replicates of Delta X^2 are shifted by 0.6 to 1.8 X^2 units (mean minus point), against 7.5 to 16.6 for the two-sample replicates (section 6). The log-score differences (`<scratch>/t7fix/ls_newonly_shift.R`, on the per-shoe terms the reviewer recomputed by a second route, equal to `part2_eval()`'s to 1e-11):

```
$ Rscript <scratch>/t7fix/ls_newonly_shift.R
primary  glmm - r2022  RAC-weighted: point +0.000003, replicate mean - point -0.0000060 (-0.002 sd); shoe-weighted: point +0.007559, shift -0.0001024 (-0.036 sd)
primary  glmm - unif   RAC-weighted: point +0.011267, replicate mean - point -0.0000163 (-0.004 sd); shoe-weighted: point +0.006260, shift -0.0001346 (-0.034 sd)
primary  r2022 - unif  RAC-weighted: point +0.011265, replicate mean - point -0.0000103 (-0.004 sd); shoe-weighted: point -0.001298, shift -0.0000322 (-0.010 sd)
all      glmm - r2022  RAC-weighted: point +0.000004, replicate mean - point -0.0000292 (-0.014 sd); shoe-weighted: point +0.005585, shift -0.0000176 (-0.008 sd)
all      glmm - unif   RAC-weighted: point +0.011891, replicate mean - point -0.0000653 (-0.023 sd); shoe-weighted: point +0.006483, shift -0.0000431 (-0.013 sd)
all      r2022 - unif  RAC-weighted: point +0.011888, replicate mean - point -0.0000361 (-0.018 sd); shoe-weighted: point +0.000899, shift -0.0000255 (-0.010 sd)
```

The NEW-only replicates of a log score are shifted by at most 0.04 of their SD; the two-sample ones by up to 0.57 of their SD (median 0.24; `shift_two / sd_two` in `part2_logscore_new.csv`), which is why their intervals are centred on the point (T7-13) (section 6).
