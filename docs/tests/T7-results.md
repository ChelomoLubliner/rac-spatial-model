# T7 results: Part 2 out-of-sample validation (exact commands and real outputs)

**Date:** 2026-11-07. **Task:** plan T7 (section 9), computed brief "T7-validation". **Branch:** `feature/new-shoes-pipeline` (HEAD `a3e7a06` when the task started). Interpretation and tables: `docs/results/validation.md`. Every block below is the real output of the command above it; trimmed output is marked `[... N lines omitted ...]`. Times were measured on a machine shared with the T6 agent, which ran six to ten R fits and a 1,000-draw bootstrap at the same time (load average 20 to 310), so wall times are long and vary.

No commit was made by this task: the brief says another agent (T6) works in the same repository at the same time, so T7 does not run `git add` or `git commit`; the files are listed in section 12 for the orchestrator to commit.

## 1. Pixel tables (every contact pixel of every shoe, both datasets)

Command (probe, scratchpad `t7/build_px.R`; the same function `part2_pixel_table()` is what `validation_8.Rmd` caches):

```
cd statistical_model && Rscript <scratch>/t7/build_px.R
```

```
old pixel table: 4080720 rows, 47.72054 secs 
 pixel counts == step 1: TRUE TRUE 
 RACs per shoe == locations: TRUE  total 13287 
 dataCC rows matched: 51849 of 51849 
 identical new_x: TRUE  horiz: TRUE  dshape: FALSE 
 cases on RAC pixels: TRUE TRUE 
 fallback pixels: 58  NA/Inf new_x: 0 
 saved /home/mehes/projects/rac-spatial-model/processed_data/validation/pixels_full.rds 17.78507 secs 
new pixel table: 5796891 rows, 1.72994 mins 
 pixel counts == step 1: TRUE TRUE 
 RACs per shoe == locations: TRUE  total 20013 
 dataCC rows matched: 83090 of 83090 
 identical new_x: TRUE  horiz: TRUE  dshape: FALSE 
 cases on RAC pixels: TRUE TRUE 
 fallback pixels: 34  NA/Inf new_x: 0 
 saved /home/mehes/projects/rac-spatial-model/processed_data/validation/new/pixels_full_new.rds 19.49437 mins 

real	22m59.015s
user	3m29.681s
sys	6m44.179s
```

`dshape: FALSE` is expected: the step-2 CSV holds `distance_shape` after its CSV round trip, the table holds it in memory; `new_x` (computed in memory from the same values, then written) is `identical()`. The 19-minute save of the NEW table was swapping caused by this probe's string keys while T6's fits held most of the memory (the Rmd uses integer keys). The cached tables (`processed_data/**/pixels_full*.rds`) are ignored by git (`.gitignore`).

## 2. Frozen OLD-only definitions and the provisional NEW shoe set (before any NEW Part 2 number)

Command (probe, scratchpad `t7/freeze.R`: `part2_definitions()` and `part2_shoe_set()` of `statistical_model/R/validation.R`, written with `part2_freeze()`):

```
cd statistical_model && Rscript <scratch>/t7/freeze.R
```

```
definitions 6.178819 mins 
   n_y n_x band         y_lo         y_hi     x_cut_1    x_cut_2    x_cut_3
1    5   2    1         -Inf -0.305000000  0.01501301         NA         NA
2    5   2    2 -0.305000000 -0.008333333  0.04172566         NA         NA
3    5   2    3 -0.008333333  0.168333333  0.05606667         NA         NA
4    5   2    4  0.168333333  0.298333333  0.01936493         NA         NA
5    5   2    5  0.298333333          Inf  0.00208568         NA         NA
6    5   3    1         -Inf -0.305000000 -0.04927986 0.06627241         NA
7    5   3    2 -0.305000000 -0.008333333 -0.03419540 0.08993574         NA
8    5   3    3 -0.008333333  0.168333333 -0.01291111 0.11767811         NA
9    5   3    4  0.168333333  0.298333333 -0.04396024 0.08187023         NA
10   5   3    5  0.298333333          Inf -0.04087779 0.04732254         NA
11   5   4    1         -Inf -0.305000000 -0.07356713 0.01501301 0.08690635
12   5   4    2 -0.305000000 -0.008333333 -0.06186869 0.04172566 0.10988215
13   5   4    3 -0.008333333  0.168333333 -0.04973118 0.05606667 0.14462323
14   5   4    4  0.168333333  0.298333333 -0.07324466 0.01936493 0.11461832
15   5   4    5  0.298333333          Inf -0.06203436 0.00208568 0.07118402
      model partition area      theta theta_rel  glm_rel naomi_cml_rel O_old
1     r2022        aR    1 0.00215349  1.000000 1.000000      1.000000   739
2     r2022        aR    2 0.00379048  1.760159 1.760159      1.760155  1581
3     r2022        aR    3 0.00339922  1.578470 1.578470      1.578467   552
4     r2022        aR    4 0.00368977  1.713395 1.713395      1.713391   612
5     r2022        aR    5 0.00272547  1.265608 1.265608      1.265606  1209
6     r2022        aR    6 0.00313100  1.453922 1.453922      1.453919  1683
7     r2022        aR    7 0.00336621  1.563143 1.563143      1.563139   347
8     r2022        aR    8 0.00355179  1.649322 1.649322      1.649318   212
9     r2022        aR    9 0.00415625  1.930010 1.930010      1.930006  1464
10    r2022        aR   10 0.00247229  1.148038 1.148038      1.148036   749
11    r2022        aR   11 0.00380030  1.764719 1.764719      1.764715  1000
12    r2022        aR   12 0.00293457  1.362705 1.362705      1.362702  1456
13    r2022        aR   13 0.00377756  1.754159 1.754159      1.754155  1166
14    r2022        aR   14 0.00382762  1.777406 1.777406      1.777402   517
[... 29 lines omitted: r_newx (areas on -new_x) and r_grid15 (the 15-cell grid), in processed_data/validation/part2_regional_theta.csv ...]
max rel diff theta vs glm: 8.770762e-15  vs Naomi CML: 2.26891e-06 
shoe set: primary 478 shoes 13636 RACs
                      
                       fail pass
  different_shoe          0    2
  none                   58  451
  same_shoe               6   61
  uncertain               5   17
  unreviewed_candidate    6   25
in_all 631 20013 
in_same_only 495 14153 
in_quality_off 542 16100 
in_quality_raw 479 14880 
in_excl_candidates 453 12419 
written /home/mehes/projects/rac-spatial-model/processed_data/validation/part2_grid_cuts.csv 
written /home/mehes/projects/rac-spatial-model/processed_data/validation/part2_regional_theta.csv 
written /home/mehes/projects/rac-spatial-model/processed_data/validation/new/part2_shoe_set_provisional_new.csv 
```

Recorded right after writing (no NEW Part 2 number existed yet; the first one was computed by the knit started at 06:53):

```
$ date '+%Y-%m-%d %H:%M:%S %Z' && sha256sum processed_data/validation/part2_grid_cuts.csv processed_data/validation/part2_regional_theta.csv processed_data/validation/new/part2_shoe_set_provisional_new.csv
2026-11-07 06:44:39 IST
b007832877d30a37195cce352199efda70f783844bc0b08a62942974afd1bb6e  processed_data/validation/part2_grid_cuts.csv
e2267d4d1c2839e786c4d0b93ad066df763355f1dfe02034a8f5a1703d5bf0ed  processed_data/validation/part2_regional_theta.csv
51d0816045105d4f14d162b658af4b2e56c06fe6a670045ea486df58bad45004  processed_data/validation/new/part2_shoe_set_provisional_new.csv
```

`validation_8.Rmd` recomputes the cuts, the regional theta and the shoe set and stops if any differs from these files (chunk `definitions`).

## 3. OLD shoe-bootstrap draws (surrogate refits) and their checks

```
$ Rscript tools/part2_old_draws.R --B 2000 --workers 4      # logs/validation/old_draws.log
wrote /home/mehes/projects/rac-spatial-model/processed_data/validation/old_glmm_draws.rds: B = 2000, failed 0, wall 1246 s
```

Summary (`logs/validation/draws_summary.out`):

```
draws: B = 2000, failed 0, wall 1245 s, median 1.64 s per draw (workers 4)
full-data surrogate vs committed fixef: max |diff| / SE over the 24 spatial coefficients 0.0538 (intercept 0.366)
shoe-bootstrap / model-based (Hessian) SE, 24 spatial: min 1.033, median 1.170, max 1.378
Wald all 24 spatial = 0 with the bootstrap V: W = 243.56, Hotelling F(24, 1976) p = 2.98e-35 (model-based Hessian W = 428.69)
CML / GLMM model-based SE of the spatial coefficients: min 0.986, median 1.004, max 1.124; max |coef CML - fixef GLMM| 0.0240
```

The intercept of the nAGQ = 0 surrogate is 0.37 SE off the Laplace fit; it cancels in every Part 2 quantity (normalized per shoe) and the draws are centred on the committed fit (`draws = fixef + (beta_pirls(b) - beta_pirls(all))`).

## 4. The 2022 regional model reproduced with Naomi's code path

```
$ Rscript docs/qa/T7/probes/t7_naomi2022.R > docs/qa/T7/probes/t7_naomi2022.out
```

```
area masks: pixels covered 0 / 1 / 2+ times: 29165 92100 0 
RACs on a zero-contact cell of their area: 0 
 area naomi_nm naomi_bfgs t7_r2022 rac_naomi rac_t7 px_naomi  px_t7
    1   1.0000     1.0000   1.0000       739    739   327221 333862
    2   1.8552     1.7445   1.7602      1581   1581   422554 427702
    3   1.6744     1.5649   1.5785       552    552   176420 178045
    4   1.8462     1.7314   1.7134       614    612   163766 168292
    5   1.3959     1.3136   1.2656      1216   1209   435250 452616
    6   1.4578     1.3660   1.4539      1683   1683   545243 522963
    7   1.5067     1.4284   1.5631       346    347   110512 102699
    8   1.6954     1.5436   1.6493       212    212    72396  69101
    9   1.9794     1.8656   1.9300      1464   1464   358002 352025
   10   1.1795     1.0993   1.1480       749    749   300469 292831
   11   1.8542     1.7356   1.7647       998   1000   268349 269764
   12   1.4041     1.3116   1.3627      1449   1456   483435 476098
   13   1.7914     1.6807   1.7542      1166   1166   302570 295838
   14   1.8881     1.7585   1.7774       518    517   137477 138884
 t7_over_naomi
       1.00000
       1.00900
       1.00865
       0.98958
       0.96348
       1.06437
       1.09433
       1.06850
       1.03454
       1.04435
       1.01680
       1.03894
       1.04369
       1.01076
Nelder-Mead (2022 default): convergence 1, value 33099.7612; BFGS value 33098.1525
max |T7 r2022 / Naomi 2022 (BFGS) - 1| = 0.0943; max |NM / BFGS - 1| = 0.0983
between-area ratio max/min: Naomi 2022 1.866, T7 r2022 1.930
```

## 5. Unit tests (fast suite files)

```
$ Rscript tests/r/test_validation_areas.R
PASS naomi_area == Naomi's 2022 loops on all 13287 OLD RACs (14 areas used) 
PASS 1,001 x 1,001 grid: exactly one label in 1..14, all 14 occur, bands right; loops agree on 20,000 points 
PASS mirror: naomi_area(-x_pixel, y_pixel) == naomi_area(x, y) for 0.9974 of OLD RACs; without the mirror 0.0000 
PASS grid cells: 1/K of a continuous sample per cell (K = 10, 15, 20), (lo, hi] bands 
PASS frozen grid cuts: K = 10, 15, 20 with 5 y bands 
ALL PASS test_validation_areas
```

```
$ time Rscript tests/r/test_validation_stats.R
PASS normalize_expected: rows sum to n_i; invariant to the scale of each row 
PASS merge_cells: E >= 5 after merging, same band first, adjacent band else; df = K' - 1 
PASS pearson_pooled and effect_sizes equal the hand formulas 
PASS phi0 0.9669 = Monte Carlo 0.9655 (SE 0.0098) and <= 1; = 1 for a common pi 
PASS regional_fit: recovery within 0.044; = Poisson GLM (2.0e-15); = Naomi's funLogCMLlambda by optim (9.4e-07); in-sample X^2 on its partition 0.0e+00 (identically 0 by construction); weights = duplicates; regional_expected by hand 
PASS log scores: continuous, regional and uniform terms by hand; RAC- and shoe-weighted means 
PASS part2_weights: m per row, reproducible, groups kept together; part2_boot_one with every shoe once 
  logit: max |G - finite difference| / max |G| = 7.17e-11
  log: max |G - finite difference| / max |G| = 5.77e-11
PASS part2_gradient = central finite differences (logit and log); log link intercept column 0 
  alpha 0.05: fixed-surface pooled 0.050, NEW-only bootstrap 0.058 (band +-0.024)
  alpha 0.10: fixed-surface pooled 0.106, NEW-only bootstrap 0.114 (band +-0.034)
PASS calibration with E known: pooled test at most nominal, shoe bootstrap at nominal 
PASS part2_effect_ci: a constant uncentred statistic gives the point estimate 
ALL PASS test_validation_stats (44 s)

real	0m44.339s
user	0m43.786s
sys	0m0.481s
```

```
$ time Rscript tests/r/test_validation_pixels.R
PASS old: S of all 386 shoes = step-1 pixel counts; RACs per shoe = locations (13287) 
PASS old: pixel table of 8 shoes (incl. 9; min_dist fallback shoes 349): x, y, new_x, horiz_dist identical() to the step-2 CSV on 926 rows; 11 fallback pixels 
PASS new: S of all 631 shoes = step-1 pixel counts; RACs per shoe = locations (20013) 
PASS new: pixel table of 18 shoes (incl. 148,149,186,580,582,585,586,589,584,105,481; min_dist fallback shoes 8): x, y, new_x, horiz_dist identical() to the step-2 CSV on 2191 rows; 6 fallback pixels 
PASS OLD design matrix = getME(X) (max 0.0e+00); X beta = predict(re.form = NA) (max 0.0e+00); part2_eta = X beta (max 2.0e-15) 
PASS OLD CML: exp(part2_eta) = exp(predict(lp, reference = zero)) (max rel 8.9e-16) 
ALL PASS test_validation_pixels (933 s)

real	15m43.601s
user	1m22.018s
sys	3m50.585s
```

(Full output of the background run, task output file; 82 s of CPU, the 15 min of wall time were swapping under T6's load.)

```
$ time Rscript tests/r/test_validation_pairs.R      # logs/validation/test_pairs.out
PASS pair_counts: unordered pairs once, duplicates in d0, (a, b] bands 
PASS pair_expected (FFT) = brute force on a 30 x 30 toy (max diff 7.1e-15) 
PASS pair_kernels: no wrap-around for an image that fills its frame 
PASS gauss_smooth_at = gauss_smooth at the pixels 
PASS pair_summary: pooled ratio, Monte Carlo p and shoe-weighted ratio by hand 
ALL PASS test_validation_pairs

real	0m1.955s
user	0m1.151s
sys	0m0.331s
```

## 6. Slow calibration (E estimated; plan F34 toy with the real n_i of both datasets)

```
$ RAC_WORKERS=3 Rscript tests/r/slow/test_validation_calibration.R    # logs/validation/slow_calibration.log
independence (400 replicates, 149 s): rejection at 5%: fixed 0.812, NEW-only bootstrap 0.815, parameter-corrected Wald 0.052, two-sample bootstrap 0.055; mean X^2 35.3, mean E0 34.6 (K - 1 = 14)
PASS independence: fixed-surface and NEW-only tests over-reject; Wald with the parameter term and two-sample bootstrap hold their size
heterogeneity (400 replicates, 174 s): rejection at 5%: fixed 0.975, NEW-only bootstrap 0.828, parameter-corrected Wald 0.417, two-sample bootstrap 0.028; mean X^2 56.8, mean E0 57.8 (K - 1 = 14)
PASS heterogeneity: the two-sample bootstrap stays within [0.02, 0.08]
dispersion: common misfit (mean X^2 88) phi 0.971 vs phi0 0.980; heterogeneity phi 1.545 vs phi0 0.980
PASS phi with the r'' centring: near phi0 under a common misfit, above it under heterogeneity
ALL PASS test_validation_calibration (378 s)
```

Plan F34 (T0 toy): fixed 0.787, NEW-only bootstrap 0.795, Wald with the parameter term 0.045, two-sample bootstrap 0.050; with heterogeneity 0.968, 0.787, 0.470 and 0.035. This implementation: 0.812, 0.815, 0.052, 0.055 and 0.975, 0.828, 0.417, 0.028: the same pattern, so the primary test of named analysis 1 (the two-sample bootstrap) holds its size where the fixed-surface test fails a correct model four times out of five.

## 7. The surrogate draws against Laplace refits of the same resamples

```
$ Rscript tools/part2_old_draws.R --laplace 8 --workers 2      # logs/validation/laplace_check.log
wrote /home/mehes/projects/rac-spatial-model/processed_data/validation/old_glmm_draws_laplace_check.rds 
$ Rscript docs/qa/T7/probes/t7_laplace_check.R > docs/qa/T7/probes/t7_laplace_check.out
checked resamples: 1,2,3,4,5,6,7,8; Laplace conv codes 0,0,0,0,0,0,0,0; seconds per Laplace refit 1298,2051,969,806,661,627,661,640
theta (sd of the shoe effect): committed 0.9797; Laplace refits 1.0121, 1.0122, 0.9126, 0.9186, 0.9449, 0.9651, 0.9331, 0.9950
|surrogate deviation - Laplace deviation| / bootstrap SD, 24 spatial coefficients x 8 resamples: median 0.004, p90 0.008, max 0.012
correlation of the two deviations (spatial coefficients): 1.0000
ratio of their spreads (sd surrogate / sd Laplace deviations): 0.996
     b max_abs_diff max_abs_shift_laplace max_abs_shift_surrogate
[1,] 1         0.61                 96.30                   95.83
[2,] 2         1.09                139.17                  138.07
[3,] 3         0.74                 83.86                   83.62
[4,] 4         0.99                129.44                  128.45
[5,] 5         0.73                128.50                  127.77
[6,] 6         0.85                102.91                  102.05
[7,] 7         2.20                329.99                  327.79
[8,] 8         0.78                114.56                  113.85
Naomi's areas, all NEW shoes (N = 20013): the surrogate's expected counts differ from the Laplace refit's by at most 2.20 RACs per area, while the draws move them by up to 329.99 (Laplace) and 327.79 (surrogate)
```

Determinism of the stored draws (three draws and the full-data fit recomputed from the stored resample ids; `logs/validation/draws_determinism.out`):

```
draw 1 recomputed identical: TRUE 
draw 777 recomputed identical: TRUE 
draw 2000 recomputed identical: TRUE 
full-data surrogate identical: TRUE 
resample ids regenerate from the seed: TRUE
```

## 8. K8 and basis sensitivity fits (OLD)

```
$ Rscript tools/part2_k8_fits.R fulltensor finey      # logs/validation/k8_fits.log
fulltensor: 35 fixed effects, logLik -25800.2537, conv 0, 2059 s -> /home/mehes/projects/rac-spatial-model/processed_data/validation/glmm_fulltensor.rds
finey: 85 fixed effects, logLik -25738.1993 (nAGQ 0), conv 0, 15 s -> /home/mehes/projects/rac-spatial-model/processed_data/validation/glmm_finey.rds
```

The full tensor raises the OLD log-likelihood from -25,819.28 (the step-3 model, 25 fixed effects) to -25,800.25 (35): LR 38.1 on 10 df, as the CML LR of 39.0 in plan F80. The finer-y fit uses nAGQ = 0, so its log-likelihood is not comparable with the Laplace ones.

## 9. Slow calibration of the pair test (plan reduced setting: 60 toy shoes, 199 simulations, 200 replicates)

First run, on the first (per-sample) simulation code, stopped by me after scenario C when the simulation was rewritten (`logs/validation/slow_pairs_calibration.log`):

```
scenario A: rejection at 5% 0.030, mean ratio (2,8] 1.002 (947 s)
scenario B: rejection at 5% 1.000, mean ratio (2,8] 2.010 (882 s)
scenario C: rejection at 5% 1.000, mean ratio (2,8] 1.443 (681 s)
```

Second run, on the vectorized simulation (`pair_sim_shoe`, proved equal to per-sample counting by `tests/r/test_validation_pairs.R`), with scenario C swept over the strength of the shoe-specific intensity (C03, C05 added after the first run; no assertion on them):

```
$ RAC_WORKERS=2 Rscript tests/r/slow/test_validation_pairs_calibration.R      # logs/validation/slow_pairs_calibration2.log
scenario A: rejection at 5% 0.045, mean ratio (2,8] 1.002 (509 s)
scenario B: rejection at 5% 1.000, mean ratio (2,8] 2.010 (273 s)
scenario C: rejection at 5% 1.000, mean ratio (2,8] 1.443 (303 s)
scenario D: rejection at 5% 1.000, mean ratio (2,8] 2.278 (932 s)
scenario C03: rejection at 5% 0.690, mean ratio (2,8] 1.064 (245 s)
scenario C05: rejection at 5% 1.000, mean ratio (2,8] 1.176 (243 s)
PASS A: under null 1 data the (2, 8] test holds its size 
PASS B: clumps are detected against null 2 (> 50%) 
FAIL C: smooth shoe-specific intensities (40 px, sd 0.8) absorbed by null 2 (<= 10%) 
PASS D: heterogeneity below h (6-12 px) flagged like clustering (> 30%) 
characterization, no assertion: rejection at sd 0.3 0.690, 0.5 1.000, 0.8 1.000
SOME CHECKS FAILED test_validation_pairs_calibration (2505 s)
```

**Finding (the plan assumed otherwise):** null 2 (the 1:1 mixture of the fitted surface and the shoe's own RACs smoothed at 24 px) does **not** absorb smooth shoe-specific intensities at 40 px: the (2, 8] test rejects 0.69 of the replicates at a log-intensity sd of 0.3 and all of them at 0.5 and 0.8 (pair ratios 1.06, 1.18, 1.44). Its size under the model (0.045) and its power against clumps hold. So an excess under null 2 is not by itself evidence of small-scale clustering; `docs/results/validation.md` reads the real result with the distance profile (section 10).

## 10. Toy pair profiles (reading the distance profile of named analysis 3)

```
$ Rscript docs/qa/T7/probes/t7_pair_profiles.R > docs/qa/T7/probes/t7_pair_profiles.out
             d0 (0,2] (2,4] (4,8] (8,16] (16,32]
null      1.068 1.009 1.015 0.999  0.976   0.963
clumps    1.959 2.103 3.150 1.710  0.941   0.918
smooth_05 1.284 1.235 1.201 1.173  1.101   0.999
smooth_08 1.557 1.531 1.512 1.418  1.278   1.046
fine      2.865 2.673 2.574 2.183  1.450   0.847
```

Mean observed/expected pair ratio against null 2 per band over 50 toy replicates (60 shoes, 199 simulations each): rows = the scenario that generated the RACs (model true; clumps; smooth shoe-specific intensity at 40 px with log-sd 0.5 and 0.8; heterogeneity at 6-12 px).

## 11. Residuals by the NEW design groups of F79 (descriptive)

```
$ Rscript docs/qa/T7/probes/t7_design_groups.R > docs/qa/T7/probes/t7_design_groups.out
== a14 
group A: 277 shoes, 9045 RACs, fixed-surface X^2 230.0 (df 13)
group B: 201 shoes, 4591 RACs, fixed-surface X^2 97.5 (df 13)
 cell  O.A    E.A  OE.A  lo.A  hi.A O.B   E.B  OE.B  lo.B  hi.B
    1  602  559.4 1.076 0.968 1.186 337 303.7 1.109 0.929 1.293
    2 1185  957.6 1.237 1.137 1.337 635 511.1 1.242 1.110 1.371
    3  364  379.3 0.960 0.842 1.089 212 240.0 0.883 0.726 1.039
    4  525  510.0 1.029 0.925 1.135 257 250.0 1.028 0.858 1.204
    5  910  916.0 0.993 0.912 1.072 412 455.2 0.905 0.806 1.013
    6 1196 1162.3 1.029 0.956 1.100 527 544.5 0.968 0.858 1.080
    7  278  246.2 1.129 0.983 1.290 107 117.5 0.910 0.707 1.127
    8  164  172.1 0.953 0.788 1.130  92  99.3 0.927 0.723 1.164
    9 1023  923.0 1.108 1.009 1.208 545 468.6 1.163 1.051 1.273
   10  666  536.9 1.240 1.121 1.354 318 286.0 1.112 0.951 1.277
   11  501  560.6 0.894 0.798 1.000 296 300.4 0.985 0.841 1.124
   12  742  990.9 0.749 0.682 0.815 459 479.9 0.957 0.852 1.063
   13  614  818.4 0.750 0.672 0.834 277 382.1 0.725 0.627 0.830
   14  275  312.3 0.881 0.784 0.981 117 152.7 0.766 0.596 0.947
== g15 
group A: 277 shoes, 9045 RACs, fixed-surface X^2 160.0 (df 14)
group B: 201 shoes, 4591 RACs, fixed-surface X^2 67.8 (df 14)
 cell O.A   E.A  OE.A  lo.A  hi.A O.B   E.B  OE.B  lo.B  hi.B
    1 708 566.2 1.251 1.129 1.371 308 273.8 1.125 0.966 1.290
    2 429 390.2 1.099 0.982 1.218 324 280.8 1.154 0.989 1.320
    3 556 505.5 1.100 0.988 1.215 296 277.5 1.067 0.919 1.242
    4 861 800.4 1.076 0.976 1.178 429 387.9 1.106 0.985 1.227
    5 619 521.9 1.186 1.050 1.312 339 275.0 1.233 1.045 1.423
    6 763 695.6 1.097 1.006 1.191 410 393.1 1.043 0.930 1.162
    7 637 638.4 0.998 0.909 1.096 263 310.0 0.848 0.724 0.984
    8 566 640.4 0.884 0.794 0.985 340 342.8 0.992 0.865 1.118
    9 675 682.6 0.989 0.896 1.083 354 334.4 1.059 0.926 1.202
   10 624 719.7 0.867 0.785 0.957 266 330.4 0.805 0.689 0.925
   11 542 695.3 0.780 0.693 0.868 277 310.4 0.892 0.770 1.023
   12 516 613.2 0.842 0.753 0.940 266 290.6 0.915 0.796 1.043
   13 566 545.0 1.039 0.940 1.142 270 270.2 0.999 0.839 1.170
   14 506 590.1 0.858 0.759 0.967 237 283.8 0.835 0.710 0.985
   15 477 440.7 1.082 0.951 1.219 212 230.2 0.921 0.786 1.064
```

## 12. The Part 2 analysis (`statistical_model/validation_8.Rmd`)

The analysis was knitted several times while it was being built (knits 1-6 stopped on errors that the log of this task records: a missing round trip in a check, a cache folder not created, helpers defined after their first use, and one run stopped by me when its forked workers took 3 GB each with 1 GB of RAM left). Run 1 is the first complete knit (3 workers, 09:20); run 2 the final one after the interval revision of T7-7 and the figure fixes (2 workers, both caches recomputed because `R/validation.R` changed):

```
$ cd statistical_model && RAC_WORKERS=2 Rscript -e 'rmarkdown::render("validation_8.Rmd", output_dir = "../logs/knit/validation", intermediates_dir = tempdir())'
32/36 [k8]          
34/36 [figures]     
36/36 [outputs]     
Output created: /home/mehes/projects/rac-spatial-model/logs/knit/validation/validation_8.html
```

Key lines printed by the knit (from `logs/knit/validation/validation_8.html`):

```
## OLD MEAN_OFFSET -4.614310784
## old: 4080720 contact pixels of 386 shoes, 13287 RACs; 51849 case-control rows: x, y, new_x, horiz_dist identical(); 58 pixels with the min_dist fallback
## new: 5796891 contact pixels of 631 shoes, 20013 RACs; 83090 case-control rows: x, y, new_x, horiz_dist identical(); 34 pixels with the min_dist fallback
## regional fit vs Poisson GLM: max rel diff 8.77e-15; vs Naomi's funLogCMLlambda (optim): 2.27e-06
## OLD in-sample sets: 386 370 shoes
## cells merged (E < 5) in 0 of 120 analyses
## pair test: 417 s
## Named primary analysis 3: (2, 8] px vs null 2: observed 6068, expected 4443.0, ratio 1.366 [shoe bootstrap 1.292, 1.463], Monte Carlo p 0.0010
## bootstrap: B = 2000 in 2511 s (2 workers)
## Named primary analysis 2: LS_C - LS_R2022 = 0.00000 per RAC, 95% interval [-0.00824, 0.00492]; ratio of the probabilities per RAC 1.0000
## offset 0 vs MEAN_OFFSET: max |delta E~| over shoes and cells = 1.38 RACs
## NEW pixels outside the OLD boundary knots: 2287 of 5796891 (0.039%), RACs there: 11 of 20013
## total time 3165 s
```

## 13. Reproducibility of the analysis (run 1 vs run 2)

```
keys differ (validation.R md5 changed): TRUE 
pair results identical() between the two runs: TRUE 
seconds run 1: 932  run 2: 417 
bootstrap replicates: run 1 (3 workers, 1913 s) vs run 2 (2 workers, 2508 s): identical() TRUE, dims 2000 x 2202
part2_cell_oe_new.csv                  bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_cells_new.csv                    bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_cells.csv                        bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_delta_x2_new.csv                 bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_grid_cuts.csv                    bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_heel_front_band_new.csv          bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_k8_edge_cells_new.csv            bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_k8_sensitivity_new.csv           bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_logscore_new.csv                 bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_logscore.csv                     bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_pairs_new.csv                    bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_pairs.csv                        bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_regional_theta.csv               bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_sensitivity_new.csv              bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_shoe_set_provisional_new.csv     bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_tests_new.csv                    bytes identical FALSE; common columns identical FALSE; columns added: w_net_lo_basic,w_net_hi_basic
part2_tests.csv                        bytes identical FALSE; common columns identical FALSE; columns added: 
part2_wald_param_new.csv               bytes identical TRUE ; common columns identical TRUE ; columns added: 
part2_tests_new.csv : columns that differ: w_net_lo, w_net_hi, rmsea_lo, rmsea_hi 
  the old basic interval = the new *_basic columns exactly
  partition   w_net w_net_lo w_net_hi w_net_lo_basic w_net_hi_basic   rmsea
1       a14 0.13507  0.07064   0.1964              0         0.1775 0.03746
2       g10 0.09961  0.00000   0.1612              0         0.1409 0.03320
3       g15 0.10434  0.01316   0.1671              0         0.1470 0.02789
4       g20 0.11154  0.02789   0.1736              0         0.1553 0.02559
  rmsea_lo rmsea_hi
1 0.019593  0.05448
2 0.000000  0.05373
3 0.003516  0.04467
4 0.006398  0.03983
part2_tests.csv : columns that differ: note 
                      old                                               new
13 in-sample, descriptive identically 0 by construction (fitting partition)
```

The bootstrap statistics (2,000 replicates x 2,202 statistics) and the pair results are `identical()` between the two runs, computed with 3 and with 2 workers. Every output CSV is byte-identical except the two test tables, where only the intended columns changed: the four interval columns of `part2_tests_new.csv` (T7-7; the first run's basic interval is kept unchanged as the new `_basic` columns) and the `note` of r_newx on Naomi's areas in `part2_tests.csv` (now labelled identically 0 by construction).

## 14. The OLD-side files T7 added (write-once list)

The collision check of `tests/r/test_new_outputs.R` allows a file outside a NEW folder of `processed_data/`, `saved_models/` or `model_images/` only if it is in Tier A or in a `tests/baseline/old_added_*.sha256` list (A-082). T7's OLD-side files (written by T7 alone, from OLD data):

```
$ git ls-files -co --exclude-standard processed_data saved_models model_images | grep validation | grep -v /new/ | LC_ALL=C sort | xargs sha256sum > tests/baseline/old_added_t7.sha256
$ cat tests/baseline/old_added_t7.sha256
d2534a9651066c299492104711cfa05d6b698b4a749493b0a0f8918f837b3fc4  processed_data/validation/glmm_finey.rds
9c09c134c8ace94b8714827a41253ff0487e0e3e03cadd08af95c9f1393e0a6a  processed_data/validation/glmm_fulltensor.rds
528d6a337e811b16aa11f55538de8372555606e0d2ab5bb2cfd2ef5d01e549e0  processed_data/validation/old_glmm_draws.rds
0037f8953ca581a26af1e3922b74d89de3566e8cee700f942c85f57e55153c34  processed_data/validation/old_glmm_draws_laplace_check.rds
2cbbfb52ad325a31a973872ff1e5dfba9a692db2ea4f8e42470f7ca53bd10d79  processed_data/validation/part2_cells.csv
b007832877d30a37195cce352199efda70f783844bc0b08a62942974afd1bb6e  processed_data/validation/part2_grid_cuts.csv
473fa739d7b981e855a27d13e8a44596e02ebb829872f986c56617e4b59c4135  processed_data/validation/part2_logscore.csv
d12f93eb0acc33020c9c943af5a075febe03a248e2eaa0653d771331319874ed  processed_data/validation/part2_pairs.csv
e2267d4d1c2839e786c4d0b93ad066df763355f1dfe02034a8f5a1703d5bf0ed  processed_data/validation/part2_regional_theta.csv
6f6a6d4dd79377556d5f07738e2251902696c8d132d099870ccfa4b195c5f5b6  processed_data/validation/part2_tests.csv
$ sha256sum -c tests/baseline/old_added_t7.sha256 --quiet && echo "old_added_t7: all OK"
old_added_t7: all OK
```

`part2_grid_cuts.csv` and `part2_regional_theta.csv` still have the checksums recorded when they were frozen (section 2). The `.rds` files hold their computing times, so a rerun of the tools writes the same numbers but not the same bytes; the CSVs are byte-reproducible (section 13).

## 15. Fast suite

```
$ time bash tests/run_all.sh      # log outside the repository
== summary
PASS         1s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS       149s  python unittest discover tests/python
PASS         6s  Rscript tests/r/test_baseline_committed.R
PASS        41s  Rscript tests/r/test_compare.R
PASS        23s  Rscript tests/r/test_compare_glmm_fits.R
PASS         4s  Rscript tests/r/test_compare_models.R
PASS        86s  Rscript tests/r/test_compare_old_new.R
PASS        51s  Rscript tests/r/test_distances_vectorized.R
PASS        19s  Rscript tests/r/test_figures_png.R
PASS        30s  Rscript tests/r/test_new_outputs.R
PASS         7s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        39s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         2s  Rscript tests/r/test_profile.R
PASS        57s  Rscript tests/r/test_profile_sentinels.R
PASS        10s  Rscript tests/r/test_run_manifest.R
PASS         2s  Rscript tests/r/test_step5_variant.R
PASS         9s  Rscript tests/r/test_sticker_masks.R
PASS         4s  Rscript tests/r/test_validation_areas.R
PASS         2s  Rscript tests/r/test_validation_pairs.R
PASS        42s  Rscript tests/r/test_validation_pixels.R
PASS        31s  Rscript tests/r/test_validation_stats.R
PASS         5s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python files)
PASS         5s  shellcheck (all shell scripts)
FAIL(1)      0s  work tree unchanged by the tests (no file created or modified)
SOME CHECKS FAILED

real	10m30.274s
user	11m33.245s
sys	1m0.800s
```

Every test passes, the four new T7 files included (`test_validation_areas.R` 4 s, `test_validation_pairs.R` 2 s, `test_validation_pixels.R` 42 s, `test_validation_stats.R` 31 s), and `test_new_outputs.R` passes its collision check with `tests/baseline/old_added_t7.sha256`. The last check failed because files were edited by hand while the suite ran, not by any test:

```
426,427c426,427
< ./docs/results/old-vs-new.md 28575 1794039081.4283533130
< ./docs/results/validation.md 44081 1794037613.6488072250
---
> ./docs/results/old-vs-new.md 28705 1794040340.3998121090
> ./docs/results/validation.md 44457 1794039939.4089436730
448,449c448,449
< ./docs/tests/T6-results.md 36330 1794039209.3386303960
< ./docs/tests/T7-results.md 28591 1794039665.4682006930
---
> ./docs/tests/T6-results.md 40623 1794040456.5530854610
> ./docs/tests/T7-results.md 30678 1794039925.0744204100
3932c3932
< ./tools/fit_compare_models.R 18164 1794035428.2714537110
---
> ./tools/fit_compare_models.R 18298 1794040448.4467801900
3936c3936
< ./tools/run_compare_fits.sh 4250 1794035056.5516250810
---
> ./tools/run_compare_fits.sh 4250 1794040448.4426592210
```

`docs/results/validation.md` and `docs/tests/T7-results.md` are mine (I edited them during the run); `docs/results/old-vs-new.md`, `docs/tests/T6-results.md`, `tools/fit_compare_models.R` and `tools/run_compare_fits.sh` belong to the T6 agent working in parallel. The four T7 test files were then run alone around the same tree-state comparison, with nothing edited by me:

```
tests/r/test_validation_areas.R: ALL PASS test_validation_areas
tests/r/test_validation_pairs.R: ALL PASS test_validation_pairs
tests/r/test_validation_stats.R: ALL PASS test_validation_stats (28 s)
tests/r/test_validation_pixels.R: ALL PASS test_validation_pixels (33 s)
tree diff: only ./logs/validation/regress_old_1-6.log (the log of the OLD gate running in the background, under the ignored logs/; not written by the tests)
```

## 16. OLD regression gate (steps 1-6, the work tree with every T7 file in it)

```
$ time RAC_SCRATCH=<scratch>/t7/gates bash tests/regress_old.sh --steps 1-6 --keep      # logs/validation/regress_old_1-6.log
== regress_old.sh --steps 1-6: /tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad/t7/gates/regress_old_CeeUdS
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
step1       113.448208333  0
step2       23.923949369   0
step3_glmm  277.440673362  0
step3_cml   219.742402649  0
step4_glmm  14.894291963   0
step4_cml   13.781012598   0
step5       25.783320180   0
step6       19.850689095   0
ALL PASS

real	12m6.795s
user	11m9.065s
sys	0m54.970s
```

No tracked file was modified by T7 (`git status`: 0 modified tracked files; T7 only added files), and the committed checksum lists still pass in the work tree:

```
$ sha256sum --quiet -c tests/baseline/committed_79247d8.sha256 && echo "Tier A: OK" (and old_baseline, old_added_t2)
Tier A: OK
old_baseline: OK
old_added_t2: OK
```

The OLD pipeline (`config.R` sources `R/profile.R` and `R/io.R` only) does not load any T7 file, so T7 cannot change an OLD output; the gate confirms it on the copy of the work tree.

## 17. Images looked at (Read tool, final versions)

| Image | What I saw |
|---|---|
| `model_images/validation/new/part2_obs_exp_new.png` | four panels (Naomi's areas with position labels, K = 10, 15, 20), primary set: GLMM (blue) and 2022 model (orange) O/E with two-sample intervals, CML crosses on the GLMM points; heel and rear-midfoot cells above 1 (up to 1.27), ball band below (down to 0.74), toe band near 1; titles carry X^2, E0 and p |
| `part2_obs_exp_all_new.png` | the same for all 631 shoes: the same gradient, slightly stronger (area 13 at 0.70, area 2 at 1.23) |
| `part2_cells_map_new.png`, `part2_cells_map_g20_new.png` | the cells on the OLD prototype, toe up, coloured by O/E with a key (0.5-2) and each cell's value; rear half red (1.04-1.27), central ball and forefoot blue (0.74-0.91), margins and toe near 1; the 2022 panels paler; no artefact (the white hairline of the first version is gone with `useRaster = TRUE`) |
| `part2_boot_new.png` | the two-sample (blue) and NEW-only (grey) null distributions of X^2, the chi^2 95% point (dashed) and the observed X^2 (red): 298 and 206 for the GLMM far beyond both distributions, 149 for the 2022 model on K = 15 in the far tail of its two-sample distribution |
| `part2_logscore_new.png` | log-score differences with intervals for every shoe set: GLMM - 2022 on 0 (RAC-weighted), slightly positive (shoe-weighted); GLMM - uniform and 2022 - uniform near +0.011 |
| `part2_pairs_new.png` | pair ratios by band (same pixel to 32 px) against null 1 and null 2 with envelopes and shoe-bootstrap bars, for NEW primary, NEW all and OLD: deficit on the same pixel, peak at 2-4 px, decay to about 1 beyond 8 px |
| scratchpad `t7/keytest.png` (not committed) | a test of the colour-key layout under four map panels with random images, before the final knit: the first layout overlapped the middle panels' heels, the layout with a separate key row did not |

## 18. Not done, and open points

- **Not committed** (the brief: T6 works in the same repository; no `git add`/`commit` by T7). The files of `docs/results/validation.md` "Files" and `tests/baseline/old_added_t7.sha256` are to be committed by the orchestrator, after the fast suite has been rerun while neither agent edits files (its last check failed only because of concurrent hand edits, section 15).
- **Shared docs not edited** (`docs/decisions.md`, `docs/progress/LOG.md`, the plan, `docs/README.md`): the T7 decisions are T7-1 to T7-12 in `docs/results/validation.md`, to be merged with A- numbers after T6's.
- **The frozen T3 shoe set** does not exist (plan T3 steps 3-3d); Part 2 runs on a provisional set (T7-1).
- **T5 step 3b** (OLD GLMM Laplace bootstrap) does not exist; surrogate draws were used and checked (T7-2).
- **Pair-resampling sensitivity** (A-038) not run: no frozen list of one-wearer pairs.
- **The plan's slow calibration "on real structure"** (60 OLD-like and 100 NEW-like real shoes, RACs simulated from the committed surface) was not run; the cell-level calibration with the real n_i of both datasets (section 6) and the pair calibration (section 9) were.
- **The finer-y OLD GLMM** was fitted with nAGQ = 0, not Laplace (T7-10).
- **Statistics-expert and independent reviews** of T7 have not happened yet.
- **For Naomi:** the 2022 CML call (optim, default Nelder-Mead) stops at its iteration limit, up to 9.8% from the optimum (section 4).
- **For the plan (A-046):** null 2 of the pair test does not absorb shoe-specific heterogeneity (section 9); the reading of named analysis 3 relies on the distance profile.
