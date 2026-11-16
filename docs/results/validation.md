# Part 2: does the OLD-fitted model predict where RACs fall on new shoes?

**Task:** plan T7 (`docs/plans/2026-11-05-new-shoes-pipeline.md`, section 9), Micha's request of the meeting of 2026-11-05 (section 4, Part 2). **Date:** 2026-11-07. **Status:** results on a **provisional** shoe set (the T3 frozen set does not exist, decision T7-1) and with **surrogate** OLD bootstrap refits (T5 step 3b was not run, decision T7-2, validated against Laplace refits). Exact commands and raw outputs: `docs/tests/T7-results.md`. Code: `statistical_model/validation_8.Rmd`, `statistical_model/R/validation.R`, `statistical_model/R/pairs.R`, `tools/part2_old_draws.R`, `tools/part2_k8_fits.R`. **Revised** the same day after the statistics review of T7 (LOG 2026-11-07 11:05; major findings 1-3, minor findings 4-7): every model-comparison interval for two estimands (T7-13), the pair test worded within its calibration (T7-14), the misfit read against the spatial signal (T7-15), a block bootstrap (T7-16), the real-structure calibration (T7-17); commands and outputs of the revision in `docs/tests/T7-review-fixes-results.md`.

**All 631 shoes (2026-11-12, A-148):** a rerun on all 631 new shoes is in `processed_data/validation/new/all_new_shoes/` and the reports `reports/new_shoes_report_all631.html`; X^2 on the areas 504 (noise floor 62), same conclusions. The numbers below remain the planned 478-shoe set.

## Summary in plain language

- **What was tested (Micha's request).** For every NEW shoe and every pixel of its contact surface, the model fitted on the OLD shoes gives the probability of a RAC there (random effect 0). Summed over each of Naomi's 14 areas, or over cells of a 10-, 15- or 20-cell grid, and scaled to the shoe's actual number of RACs, these sums say how many RACs each part of each NEW shoe should carry. They were compared with where the NEW RACs actually are, on 478 NEW shoes (13,636 RACs) that are not reprints of OLD shoes and whose prints pass the quality rule, and on all 631 as a check.
- **The OLD surface does not transfer to the NEW shoes, and the misfit is large relative to NEW's spatial signal.** On Naomi's areas the discrepancy (Pearson X^2 = 298 on 13 df) is six times its noise floor (49, the value a correct model would give once the OLD estimation error, the dependence of RACs within a shoe and the differences between shoes are allowed for); none of 2,000 bootstrap replicates of a correct model came near it (p = 0.0005). How large is it? Placing the RACs uniformly on each shoe's contact surface, with no spatial model at all, gives X^2 = 490 on the same areas: the OLD surface removes only 39% of NEW's departure from uniform (47% net of the noise floors; 38-51% on the grids, 51-60% net), where in sample it removes 85% of OLD's; likewise its pixel probabilities realize on NEW 39% of the log-score gain over uniform that they would have if they were right (96% on OLD). The 2022 regional model removes 65% (57-65% on the grids). The misfit has two parts. (a) **Attenuation:** the OLD contrasts against uniform are too strong on NEW (calibration slope 0.70, 95% interval 0.55-0.85, on the areas; 0.68 (0.55-0.80) at the pixel level; a correct OLD surface would show about 0.95 (0.81-1.12; pixel level 0.93, 0.82-1.05) through OLD estimation noise alone, one-sided p 0.008 (pixel level 0.002): NEW's RACs are spread more evenly than the OLD surface says. (b) **A shift along the shoe that the OLD contrasts do not describe:** recalibrating the contrasts removes only 9% of the X^2 (4-10% on the grids), because NEW carries more RACs than either version predicts at the rear midfoot (areas 2 and 9: 32-33% above uniform, where the OLD surface expects 6-18%) and fewer in the central forefoot (area 12: 20% below uniform, where it expects 2% below; area 13: 5% below, where it expects 29% above). The first version called this misfit "small by Cohen's convention" (w = 0.15); against the whole spatial signal (w = 0.19 for uniform placement) it is not. The pattern holds for every shoe set, grid and model variant tried.
- **Per RAC the continuous model predicts new RACs no better than the 2022 regional model; per shoe it is slightly ahead.** Two questions are kept apart (T7-13): how well do the *published fitted surfaces* predict NEW (only NEW sampling varies), and how well do the two *model classes*, each fitted on a collection of OLD's size, predict new shoes (OLD estimation noise included)? Per RAC the two models tie for both: log-score difference +0.000003 nats (published surfaces, 95% interval -0.0056 to +0.0050; model classes -0.0069 to +0.0062). Per shoe (every shoe counted once) the published continuous surface is ahead by 0.0076 nats, 0.8% in the probability given to a RAC's pixel (95% interval +0.0020 to +0.0132), about half its in-sample lead on OLD (0.0148 nats); for the model classes the interval reaches 0 (-0.00003 to +0.0148). The lead sits in the lightly marked shoes (+0.0131 nats in the third of the shoes with the fewest RACs, +0.0003 in the third with the most). On the grid cells the published 2022 surfaces fit NEW better than the published continuous surface (Delta X^2 +49 to +72, every 95% interval above 0), which is not significant once OLD estimation noise is included (model-class intervals -17 to +131, -23 to +149 and -11 to +172 for K = 10, 15 and 20). Both models give a RAC's pixel 1.1% more probability than uniform placement (geometric mean): 44% of the GLMM's in-sample gain on OLD.
- **The RACs of a shoe are not independent draws from the model.** Pairs of RACs 2-8 pixels apart are 37% more frequent (95% interval 29-46%) than independent placement predicts, both from the fitted surface and from its version adjusted to each shoe's own RAC pattern (OLD 45%). The test does not say why: its calibration shows that the adjustment does not absorb smooth differences between shoes (with a modest shoe-specific pattern it rejects in 69% of toy replicates), so contagion (one damage event leaving several RACs), very fine unevenness of the sole and shoe-specific patterns are not separated. The distance profile limits the last one: in NEW the excess falls steeply from 2-4 px (1.54) to 8-16 px (1.04), which shoe-specific patterns smooth enough to leave the 8-16 px band near 1 cannot do; toys put their share of NEW's excess at about a quarter, at most a half (in OLD perhaps half). Whatever the mechanism, a set of RACs cannot be given the product of single-RAC probabilities. The area counts also vary between shoes more than independent RACs allow (dispersion phi 1.6-2.0 against 0.99 in NEW, 2.0-2.5 in OLD).
- **What this means for the paper.** (1) Reviewer 1, point 6 (out-of-sample validation): the OLD surface reproduces 39% of NEW's departure from uniform placement on Naomi's areas (the 2022 model 65%); its contrasts are too strong for NEW and NEW's RACs sit further toward the rear midfoot; and the expected counts carry an OLD estimation error as large as the new data's own noise. (2) Reviewer 1, point 1 (added value over 2022): per RAC a tie; per shoe the published continuous surface is ahead by about 0.8%; on grid cells the published 2022 surfaces fit better, which is not significant once OLD estimation noise is included: on new shoes the finer continuous surface adds no clear predictive value. (3) The editor's independence question: the RACs of a shoe are not independent draws from the common surface nor from its shoe-adjusted version; through contagion, fine unevenness or shoe-specific patterns (not separated), a set of RACs cannot be given the product of single-RAC probabilities, and variances computed under independence are too small. (4) The gain over uniform placement (1.1% in the probability of a RAC's pixel, geometric mean) is a KL-type quantity, small even for real contrasts (intensities 1 and 2 on two equal areas give only 5.8%); it measures how much of the model's own predicted gain NEW realizes (39%; 96% in sample on OLD), not the strength of the location effect.
- **Caveats.** The NEW collection differs in source, scan format, RAC marking and mix of sole designs (dataset shift), so "does not transfer" can mean a different population as much as a wrong model. The shoe set is provisional (T3 never froze one), and the OLD estimation error comes from fast surrogate refits that were checked against full refits and, on real shoe structure, in a simulation of the whole chain (section 2.5: the primary test rejects a true model at 5.2% at the 5% level; the NEW-only log-score interval covers its target only 91% of the time). Every interval treats the NEW shoes as independent; resampling blocks of consecutive ids, a proxy for pairs of shoes of one wearer, raises the dispersion from 1.74 to 2.20 (blocks of 4) and widens the comparison intervals by up to 1.27 times (NEW-only Delta X^2; 1.13 times for the two-sample intervals), without changing the primary test (`part2_block_new.csv`, T7-16); with blocks of 4 the published-surface K = 15 Delta X^2 interval just reaches 0 (-0.6 to +123). Details in "Limitations".


## 1. What was computed (Micha's request, as implemented)

For every NEW shoe i and every pixel j of its contact surface (S_ij = 1; the step-1 surface: raw contact x the NEW stamp mask, the erase list applied, every RAC pixel set to 1), the OLD-fitted GLMM gives p_ij with the random effect set to 0 (eta = the step-3 spline surface at the pixel's standardized coordinates + the OLD `MEAN_OFFSET`). The standardized coordinate `new_x` of every pixel is computed from the shoe's own snake contour and the OLD prototype with the step-2 arithmetic, so on the sampled pixels it is `identical()` to the step-2 CSV (all 83,090 NEW and 51,849 OLD case-control rows; section 2). For each part k: **E_ik = sum over j in k of p_ij S_ij**, normalized to the shoe's observed RAC total (E~_ik = n_i E_ik / sum_k E_ik, D-003), and compared with the observed counts O_ik.

| Element | As implemented |
|---|---|
| Parts | (A) Naomi's 14 areas of 2022 on the standardized shoe, at (-new_x, y) (the pipeline's x is the mirror of Naomi's, F7); (B) grids of A-008 on `new_x`: 5 y bands at the OLD contact-pixel quintiles of y, and in each band 2, 3 or 4 `new_x` bands at the OLD quantiles: K = 10, **15 (pre-registered)** and 20 (the brief's 4 x 5). Cut points from OLD only, frozen before any NEW number |
| Pooled test | Pearson X^2 over the shoes of the set, cells with E < 5 merged (none had to be), df = K' - 1. Because beta_old was estimated from about as many RACs as NEW has, this "fixed-surface" test rejects a correct model about 4 times out of 5 (plan F34; reproduced in section 2.4), so it is reported as **descriptive** |
| Primary p-value | the **two-sample shoe bootstrap** (A-043): B = 2,000 replicates; each pairs one OLD shoe-bootstrap refit of the GLMM (the OLD estimation error) with one resample of the NEW shoes (within-shoe dependence and between-shoe heterogeneity), centred residuals r'' (A-051) |
| Dispersion | NEW-only shoe bootstrap with the fit fixed: phi = mean X^2* / (K' - 1), against its exact value under independent multinomials, phi0 (<= 1); phi / phi0 > 1 = extra-multinomial variation (within-shoe dependence or between-shoe heterogeneity, A-026) |
| Effect sizes | Cramer's w = sqrt(X^2 / N), w_net = sqrt(max(X^2 - E0, 0) / N) with E0 = the bootstrap noise floor (the mean two-sample X^2*), an RMSEA-type index; per-cell O/E with two-sample 95% intervals and z_boot = (O - E) / bootstrap SD. Since the review fixes (T7-15) read against the **spatial signal**: the X^2 of uniform placement on the contact surface and the share of it each model removes, the **calibration slope** alpha (P_ik proportional to E_unif,ik (E_ik / E_unif,ik)^alpha, conditional on each shoe's total; at the pixel level p_ij^alpha) with the value OLD estimation noise alone would give, and the X^2 after recalibration |
| Secondary test | parameter-corrected pooled Wald D' (Sigma_mult + G V G')^+ D (valid under independence only) |
| 2022 model | theta per area by the conditional multinomial MLE (= Poisson GLM N ~ area + shoe + offset(log S)) on all 386 OLD shoes, areas at each pixel's own coordinates (-x, y) as in 2022 (A-025), refitted on every OLD bootstrap resample; sensitivities: theta on the areas at (-new_x, y) (r_newx) and on the 15-cell grid (r_grid15) |
| Log score | per RAC, log of the probability of its pixel among the shoe's contact pixels; continuous (GLMM, CML), 2022 regional, uniform (every contact pixel equally likely); RAC-weighted and shoe-weighted; since the review fixes (T7-13) intervals for two estimands, the published fitted surfaces (NEW-only bootstrap) and the model classes (two-sample bootstrap), both centred on the point; the gain over uniform also against the gain the model expects for itself (its KL divergence from uniform) |
| Dependence | within-shoe pair counts by distance band, against the fitted surface (null 1) and against a mixture with the shoe's own RACs smoothed at 24 px (null 2); Monte Carlo p from 999 simulations; primary band (2, 8] px (A-046) |

**Named primary analyses** (fixed before any NEW number, A-030/A-043/A-046): (1) goodness of fit on Naomi's 14 areas, GLMM, primary set, two-sample bootstrap p, w net of the noise floor; (2) the RAC-weighted log-score difference continuous minus 2022, primary set, two-sample interval (since the review fixes centred on the point, with the NEW-only interval of the published surfaces beside it, T7-13); (3) the pair test in (2, 8] px against null 2. Everything else is secondary or a sensitivity.

## 2. Inputs and checks

### 2.1 Pixel tables

| | OLD (in-sample) | NEW |
|---|---|---|
| Shoes, RACs | 386, 13,287 | 631, 20,013 |
| Contact pixels (S = 1) | 4,080,720 | 5,796,891 |
| Pixels per shoe = step-1 `shoe_pixel_counts` | every shoe | every shoe |
| RACs per shoe = the locations file | every shoe | every shoe |
| x, y, `new_x`, `horiz_dist` `identical()` to the step-2 CSV | 51,849 of 51,849 rows | 83,090 of 83,090 rows |
| Pixels with no contour point within 0.01 in y (step 2's `min_dist` fallback) | 58 | 34 |

So Micha's sums run over exactly the contact surface and the standardization that the models were fitted on, extended from the sampled pixels to every pixel.

### 2.2 Definitions frozen from OLD before any NEW number (2026-11-07 06:44:39 IST)

Grid (A-008): y cuts at the OLD contact-pixel quintiles -0.3050, -0.0083, 0.1683, 0.2983 (band 1 = heel, 5 = toe); `new_x` cuts per band in `processed_data/validation/part2_grid_cuts.csv`. Regional theta of the 2022 model (relative to area 1): 1.76, 1.58, 1.71, 1.27, 1.45, 1.56, 1.65, 1.93, 1.15, 1.76, 1.36, 1.75, 1.78 for areas 2-14 (`part2_regional_theta.csv`; max/min 1.93). The fitting code equals a Poisson GLM to 8.8e-15 and Naomi's own `funLogCMLlambda` (optim) to 2.3e-6.

**The 2022 model reproduced with Naomi's code path** (`docs/qa/T7/probes/t7_naomi2022.R`): her pixel-level area masks partition her window exactly (92,100 pixels, none twice), and no RAC lies on a zero-contact cell. Two findings:
- Her estimator as published (`optim` with its default Nelder-Mead) **stops at its iteration limit** (convergence code 1): its relative intensities are up to 9.8% from the converged optimum (BFGS). **This is correct but immaterial for her conclusions** (review minor finding 6): the Nelder-Mead point is 1.61 log-likelihood units below the optimum (negative log-likelihood 33,099.76 vs 33,098.15) on 13 free parameters, while the 95% joint likelihood region of 13 parameters reaches 11.18 units below it (qchisq(0.95, 13) / 2); as a likelihood-ratio test the Nelder-Mead point is not rejected (2 x 1.61 = 3.2 on 13 df, p = 0.997), and that is under independent RACs, which understates the real uncertainty (named analysis 3). If the paper's Table 1 came from this call, its CML column is not at the optimum but well inside the estimate's sampling uncertainty. To tell Naomi in those terms.
- Our refit (the step-1 contact surface, Naomi's rule at each pixel centre) is within 9.4% of her converged estimates per area (max/min 1.93 vs 1.87); the difference comes from the contact surface (hers: the raw records in a window, no stamp sweep, RAC pixels not added) and the pixel-level boundaries (up to 7 RACs per area change sides).

### 2.3 Shoe sets (provisional, decision T7-1)

| Set | Rule | Shoes | RACs |
|---|---|---|---|
| **primary** | not a T0 `same_shoe` or `uncertain` reprint of an OLD shoe; quality pass (A-029, automatic part) | **478** | **13,636** |
| all | every NEW shoe | 631 | 20,013 |
| same_only | only `same_shoe` excluded | 495 | 14,153 |
| quality_off | reprints excluded, no quality rule | 542 | 16,100 |
| quality_raw | reprints excluded, raw on-contact rate >= 0.584 | 479 | 14,880 |
| excl_candidates | also the 31 unreviewed single-statistic candidates excluded | 453 | 12,419 |

Overlap decisions (T0 review) by quality flag: `same_shoe` 61 pass / 6 fail, `uncertain` 17 / 5, unreviewed candidates 25 / 6, `different_shoe` 2 / 0, not flagged 451 / 58.

### 2.4 The OLD estimation error: surrogate refits, checked

2,000 OLD shoe resamples, each refitted (PIRLS at the committed variance, nAGQ = 0, OLD basis) and centred on the committed fit (T7-2); 0 failures, 21 min on 4 workers; three draws recomputed bit for bit. Checks:

| Check | Result |
|---|---|
| Full-data surrogate vs the committed Laplace fit | spatial coefficients within 0.054 SE (intercept 0.37 SE; cancels in Part 2) |
| 8 resamples also refitted by full Laplace (all converged; 10-34 min each under load) | surrogate deviation - Laplace deviation: median 0.004, max 0.012 bootstrap SD; correlation 1.0000; spread ratio 0.996. Part 2 expected counts on Naomi's areas differ by at most 2.2 RACs (of 20,013) while the draws move them by up to 330 |
| Bootstrap / model-based SE of the 24 spatial coefficients | 1.03-1.38 (median 1.17); the independent cluster-robust CML of F29: median 1.13, max 1.37 |
| Wald test of all 24 spatial coefficients = 0 with the bootstrap covariance | W = 243.6 (model-based 428.7), Hotelling F(24, 1976) p = 3e-35: the spatial pattern of OLD stays highly significant once the dependence of RACs within a shoe is allowed for (a by-product for T5 step 3b) |

**Do the tests hold their size?** The slow calibration (`tests/r/slow/test_validation_calibration.R`; the real n_i of both datasets, a 15-cell model fitted on a simulated OLD sample, 400 replicates, inner B = 199):

| Rejection at 5% | fixed-surface X^2 | NEW-only bootstrap | Wald with G V G' | **two-sample bootstrap** |
|---|---|---|---|---|
| model true, RACs independent | 0.812 | 0.815 | 0.052 | **0.055** |
| model true, between-shoe heterogeneity | 0.975 | 0.828 | 0.417 | **0.028** |

So the fixed-surface test fails a true model four times out of five, as the plan predicted (F34: 0.787); the two-sample bootstrap of named analysis 1 does not. Under a common misfit the dispersion phi stays at phi0 (0.971 vs 0.980); under heterogeneity it rises (1.545).

### 2.5 Calibration of the whole chain on real shoe structure (T7-17, run 2026-11-08)

`RAC_WORKERS=4 Rscript tests/r/slow/test_validation_real_calibration.R` (400 replicates, inner B = 100, 7,759 s; 60 OLD-like real shoes with 1,654 RACs and 100 NEW-like real shoes with 3,318 RACs; RACs simulated from the committed OLD GLMM surface, so the model is true and there is no dataset shift; output copied to `docs/tests/T7-real-calibration-output.txt`):

| Check | Result | Verdict |
|---|---|---|
| Named analysis 1 (Naomi's areas), rejection at 5% | two-sample **0.052**; NEW-only 0.750; fixed surface 0.797 | PASS: the primary test holds its size |
| Log score GLMM - 2022: NEW-only interval covers E1 (published surfaces) | 0.910 | **FAIL** (below 0.95 - 2.5 SE): slightly too narrow |
| Log score: centred two-sample interval covers E2 (model classes) | 0.995 (raw uncentred 0.905) | PASS, conservative |
| Delta X^2 (K = 15): NEW-only interval covers E1 | 0.935 | PASS |
| Delta X^2: centred two-sample interval covers E2 | 0.993 (raw 0.958) | PASS, conservative |

**Reading.** The goodness-of-fit p-values of named analysis 1 are valid on real structure. The centred model-class intervals are conservative, which supports the centring of T7-13: the uncentred replicates are shifted by 0.75-0.88 of their SD. The NEW-only log-score intervals under-cover a little (91% for a nominal 95%), so the published-surface per-shoe lead (+0.0020 to +0.0132) should be read as a slightly optimistic interval. In this setting the OLD sample is smaller than the real one (60 against 386 shoes), so the check concerns the machinery, not every number.

## 3. Named primary analyses

### Named primary analysis 1: goodness of fit on Naomi's 14 areas (OLD GLMM, primary set)

| | Value |
|---|---|
| NEW shoes, RACs | 478, 13,636 |
| Pearson X^2 (14 areas, none merged, df 13) | **297.8** |
| Noise floor E0 = mean two-sample bootstrap X^2 under the model (OLD estimation error + NEW resampling, dependence, heterogeneity) | 49.0 (95% of the 2,000 null replicates below 94.7; largest 169.7) |
| **Two-sample bootstrap p** | **0.0005** (no replicate reached 297.8; 1/2001 is the smallest possible value) |
| Fixed-surface chi^2_13 p (descriptive only, F34) | 7e-56 |
| Cramer's w; net of the noise floor | 0.148; **0.135** (bias-shifted percentile 95%: 0.071-0.196; the basic interval 0-0.178, T7-7) |
| RMSEA-type index | 0.037 |
| Dispersion phi (NEW-only bootstrap, fit fixed) vs phi0 | 1.74 vs 0.994 (phi / phi0 = 1.75) |

Observed / expected per area (two-sample 95% intervals; areas in Naomi's frame: 1-5 for x < 0 from heel to toe, 10-6 for x >= 0 from heel to toe, 11-14 the central parts of 4, 5, 6, 7):

| Area | 1 heel | 2 rear | 3 mid | 4 ball | 5 fore | 6 fore | 7 ball | 8 mid | 9 rear | 10 heel | 11 ball c | 12 fore c | 13 fore c | 14 ball c |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| O/E, OLD GLMM | 1.09 | **1.24** | 0.93 | 1.03 | 0.96 | 1.01 | 1.06 | 0.94 | **1.13** | **1.20** | 0.93 | **0.82** | **0.74** | **0.84** |
| 95% interval | 0.97-1.22 | 1.13-1.38 | 0.81-1.06 | 0.90-1.17 | 0.87-1.07 | 0.92-1.10 | 0.89-1.24 | 0.77-1.13 | 1.00-1.27 | 1.07-1.35 | 0.81-1.06 | 0.73-0.91 | 0.66-0.84 | 0.73-0.97 |
| O/E, 2022 model | 1.19 | 1.13 | 1.04 | 1.05 | 0.95 | 0.96 | 0.94 | 0.99 | 1.04 | 1.21 | 0.91 | 0.88 | 0.82 | 0.89 |

The OLD surface misfits NEW **systematically along the shoe's length**: NEW carries 13-24% more RACs than predicted at the heel and the rear midfoot (areas 2, 9, 10) and 16-26% fewer in the central ball and forefoot (areas 12, 13, 14); the side areas of the forefoot and the midfoot fit. The 15-cell grid shows the same gradient (figure `part2_cells_map_new.png`): the heel band 1.09-1.21, the rear-midfoot band 1.08-1.20, the midfoot 0.92-1.01, the ball band 0.81-0.87, the toe band 0.85-1.03. The result is the same for every shoe set (X^2 263-504, w_net 0.13-0.15, p_boot 0.0005 in all six), for the OLD CML (X^2 296.9), for binarized RAC counts (298.2), without the 0.04% of NEW pixels outside the OLD boundary knots (295.8; 11 RACs there) and with offset 0 (expected counts change by at most 1.4 RACs per shoe and cell).

### Named primary analysis 2: model comparison by the log score (primary set)

Mean log probability per RAC of its own pixel among the shoe's contact pixels (nats; higher is better):

| | OLD GLMM | OLD CML | 2022 model | uniform on the contact surface |
|---|---|---|---|---|
| RAC-weighted | -9.21579 | -9.21571 | -9.21579 | -9.22705 |
| shoe-weighted | -9.08118 | -9.08109 | -9.08874 | -9.08744 |

| Difference (nats per RAC) | Point | 95% interval, published surfaces (NEW only) | 95% interval, model classes (two-sample, centred; T7-13) | Probability ratio per RAC |
|---|---|---|---|---|
| **GLMM - 2022, RAC-weighted (named analysis 2)** | **+0.000003** | **-0.0056 to +0.0050** | **-0.0069 to +0.0062** | **1.000** |
| GLMM - 2022, shoe-weighted | +0.0076 | +0.0020 to +0.0132 | -0.00003 to +0.0148 | 1.008 |
| GLMM - uniform, RAC-weighted | +0.0113 | +0.0038 to +0.0181 | +0.0006 to +0.0204 | 1.011 |
| 2022 - uniform, RAC-weighted | +0.0113 | +0.0064 to +0.0160 | +0.0043 to +0.0177 | 1.011 |
| GLMM - CML, RAC-weighted | -0.00008 | -0.00012 to -0.00004 | -0.00013 to -0.00002 | 1.000 |

Per RAC, the continuous model predicts where NEW RACs fall **exactly as well as the 2022 regional model** (difference 3e-6 nats; the published-surface interval excludes an advantage above about 0.5% in the probability given to a RAC's pixel for either model; the model-class interval, above about 0.6-0.7%), and both give a RAC's pixel only about **1% more probability than uniform placement** on the shoe's contact surface. The uncentred two-sample replicates are skewed to the left (hence the centring of T7-13) because each replicate scores a model refitted on an OLD resample, and a noisier fit predicts worse (more so for 24 spline coefficients than for 14 areas; plan section 9). Shoe-weighted (every shoe counts once), the published continuous surface is ahead by 0.0076 nats per RAC (0.8%; interval +0.0020 to +0.0132, excluding 0), but for the model classes the interval just reaches 0 (-0.00003 to +0.0148); the 2022 model is level with uniform. The same holds for every shoe set (RAC-weighted GLMM - 2022 between -0.0012 and +0.0023).

**In-sample on OLD** (the fits saw these RACs): GLMM -9.23460, 2022 model -9.24325, uniform -9.26025: the GLMM is ahead of the 2022 model by 0.0087 nats per RAC and of uniform by 0.0257 (the 2022 model by 0.0170). Out of sample the GLMM's advantage over the 2022 model is 0, and its advantage over uniform falls to 0.011 (less than half).

### The cell-level comparison on the grids (secondary)

On the grids, where neither model was fitted, the 2022 model's X^2 is lower:

| Grid (primary set) | X^2 GLMM (E0) | X^2 2022 (E0) | Delta X^2 = GLMM - 2022 | 95% interval, published surfaces (NEW only) | 95% interval, model classes (two-sample, centred; T7-13) |
|---|---|---|---|---|---|
| K = 10 | 176.3 (41.0) | 126.8 (34.2) | +49.4 | +10.7 to +91.0 | -16.9 to +130.7 |
| **K = 15 (pre-registered)** | 205.5 (57.1) | 149.3 (42.1) | +56.2 | +7.7 to +109.2 | -22.7 to +148.7 |
| K = 20 | 235.3 (65.6) | 163.4 (50.0) | +71.9 | +19.7 to +127.5 | -10.5 to +171.9 |
| Naomi's areas (tilted toward the 2022 model) | 297.8 (49.0) | 169.7 (52.7) | +128.1 | +70.1 to +188.0 | +29.5 to +241.7 |

Both models are rejected on every grid (two-sample p 0.0005 for the GLMM, 0.001-0.0025 for the 2022 model). The 2022 model's areas average the OLD intensity over large regions, so they carry less of OLD's local shape into NEW; the continuous surface's finer OLD detail is what does not transfer. With all 631 shoes every published-surface (NEW-only) Delta X^2 interval excludes 0 (for example K = 15: +104 [48, 165]); the centred model-class intervals include 0 on K = 10 and K = 15 (-1 to +225, -2 to +236) and exclude it on K = 20 and the areas.

### Parameter-corrected pooled test (secondary; valid under independence only)

| Partition (primary set) | W, V model-based | W, V bootstrap | df | multinomial-only W | phi_par (bootstrap V) |
|---|---|---|---|---|---|
| Naomi's areas | 133.6 | 66.1 | 13 | 301.8 | 2.00 |
| K = 15 | 89.1 | 40.0 | 14 | 209.0 | 2.24 |

All p <= 4e-4 on every partition and set. The parameter term is about as large as the multinomial one with the model-based OLD covariance (phi_par 0.97 on Naomi's areas) and twice as large with the bootstrap covariance (2.0), confirming that the OLD estimation error cannot be ignored (A-043).


### Named primary analysis 3: within-shoe dependence (pair test)

| Set | Band (px) | Null | Observed pairs | Expected | Ratio | Shoe-bootstrap 95% | Monte Carlo p |
|---|---|---|---|---|---|---|---|
| **NEW primary** | **(2, 8]** | **2** | **6,068** | **4,443** | **1.37** | **1.29-1.46** | **0.001** |
| NEW primary | (2, 8] | 1 | 6,068 | 4,170 | 1.46 | 1.36-1.58 | 0.001 |
| NEW primary | (2, 8], shoe-weighted | 2 | | | 1.69 | 1.45-1.98 | 0.001 |
| NEW all | (2, 8] | 2 | 9,241 | 6,940 | 1.33 | 1.28-1.40 | 0.001 |
| OLD (in-sample) | (2, 8] | 2 | 7,886 | 5,422 | 1.45 | 1.35-1.58 | 0.001 |

Distance profile against null 2 (NEW primary): same pixel 0.35 (14 pairs vs 40 expected), (0, 2] 0.97, (2, 4] 1.54, (4, 8] 1.31, (8, 16] 1.04, (16, 32] 0.94; OLD: 0.73, 1.26, 1.59, 1.41, 1.13, 0.98. p = 0.001 is the smallest value 999 simulations can give; the 95% simulation envelope of the (2, 8] ratio under null 2 is 0.97-1.04, so the observed 1.37 lies far outside it.

**Reading** (revised in the review fixes, T7-14). The test shows that the RACs of a shoe are **not independent draws from the fitted surface** (null 1), **nor from its heterogeneity-adjusted version** (null 2): in NEW, pairs 2-8 px apart are 37% more frequent than null 2 predicts (OLD 45%). It does not identify the mechanism. The slow calibration (`tests/r/slow/test_validation_pairs_calibration.R`, `docs/tests/T7-results.md` section 9) shows that the test holds its size when the model is true (rejection 0.045) and detects clumps (1.00), but that null 2 does **not** absorb smooth shoe-specific intensities, contrary to the plan's premise (A-046): at 40 px the (2, 8] test rejects in 69% of the toy replicates at a log-intensity sd of 0.3 and in all of them at 0.5 and 0.8. Three mechanisms stay open: contagion (one damage event leaving several RACs), inhomogeneity finer than the 24 px of null 2 (for example along tread edges), and shoe-specific intensity on larger scales.

The distance profile limits only the third. Mean ratio against null 2 over 50 toy replicates (`docs/qa/T7/probes/t7_pair_profiles_hardcore.R`, review fixes; "hard core": no two RACs of a shoe within 2 px; "same pixel": no two RACs on one pixel), with NEW and OLD (shoe-bootstrap 95% intervals, `part2_pairs_new.csv`, `part2_pairs.csv`):

| Ratio against null 2 | same pixel | (0, 2] | (2, 4] | (4, 8] | (8, 16] | (16, 32] | (2, 8] |
|---|---|---|---|---|---|---|---|
| toy: model true | 1.05 | 1.01 | 1.02 | 0.99 | 0.98 | 0.97 | 1.00 |
| toy: model true, hard core | 0 | 0 | 1.04 | 0.99 | 0.97 | 0.97 | 1.00 |
| toy: smooth shoe-specific intensity at 40 px, log-sd 0.3 | 1.15 | 1.10 | 1.08 | 1.05 | 1.01 | 0.97 | 1.05 |
| toy: log-sd 0.3, hard core | 0 | 0 | 1.09 | 1.05 | 1.01 | 0.98 | 1.06 |
| toy: log-sd 0.5 | 1.28 | 1.23 | 1.19 | 1.16 | 1.10 | 1.00 | 1.16 |
| toy: log-sd 0.5, same pixel excluded | 0 | 1.22 | 1.18 | 1.16 | 1.10 | 1.00 | 1.16 |
| toy: log-sd 0.5, hard core | 0 | 0 | 1.20 | 1.14 | 1.09 | 1.00 | 1.15 |
| toy: log-sd 0.8 | 1.60 | 1.53 | 1.48 | 1.41 | 1.27 | 1.05 | 1.42 |
| toy: log-sd 0.8, hard core | 0 | 0 | 1.44 | 1.35 | 1.24 | 1.04 | 1.37 |
| toy: heterogeneity at 6-12 px, hard core | 0 | 0 | 2.18 | 1.84 | 1.37 | 0.89 | 1.91 |
| toy: clumps of 2-4 RACs within 2-6 px, hard core | 0 | 0 | 3.05 | 1.67 | 0.96 | 0.92 | 1.95 |
| **NEW primary** | **0.35** (0.18-0.59) | **0.97** (0.84-1.12) | **1.54** (1.42-1.70) | **1.31** (1.24-1.40) | **1.04** (0.97-1.12) | **0.94** (0.89-1.00) | **1.37** (1.29-1.46) |
| OLD (in-sample) | 0.73 (0.51-1.01) | 1.26 (1.06-1.51) | 1.59 (1.44-1.79) | 1.41 (1.32-1.53) | 1.13 (1.06-1.21) | 0.98 (0.94-1.03) | 1.45 (1.35-1.58) |

- **The shortest distances do not discriminate.** NEW shows inhibition on the same pixel (14 pairs where 40 were expected) but none at (0, 2] px; OLD shows an excess at (0, 2] (1.26). The first toys had no inhibition, so the first reading ("no excess below 2 px, unlike heterogeneity"; "inhibition below about 2 px in both datasets") was not specific, and for OLD not true: with a hard core or a same-pixel exclusion, heterogeneity loses its excess at the shortest distances too, while its profile beyond 2 px stays as it was.
- **The decay beyond 2 px does discriminate.** Smooth heterogeneity raises every band up to its scale almost alike: from (2, 4] to (8, 16] its excess falls only by about half (log-sd 0.5 with a hard core: 1.20 to 1.09; 0.8: 1.44 to 1.24), with or without inhibition. NEW's falls from 1.54 to 1.04 and OLD's from 1.59 to 1.13. Heterogeneity strong enough to give NEW's (2, 8] ratio by itself (log-sd about 0.8, toy 1.37-1.43) would lift the (8, 16] band to 1.24-1.27, outside NEW's interval (0.97-1.12). Interpolating between the toy strengths, the heterogeneity that NEW's (8, 16] band allows accounts for about a quarter of NEW's 2-8 px excess at the band's point estimate and at most about half at its upper limit; the rest is structure on a few pixels, contagion or very fine inhomogeneity, which these data cannot separate (A-046). In OLD the (8, 16] band (1.06-1.21) allows stronger heterogeneity, which would account for about half of OLD's excess at the point estimate (a quarter to three quarters over its interval): there shoe-specific intensity may be a large part.
- The toys have their own geometry and RAC counts (60 shoes of 100 x 60 px, 10-60 RACs, fields at 40 px), so these shares are indicative, not a calibrated decomposition.

Whatever the mechanism, the RACs of a shoe are not independent draws from any surface the model provides, so a set of RACs cannot be given the product of single-RAC probabilities, and variances computed under independence are too small. (Scale: the prints span about 300 px from heel to toe; if a print is about 30 cm long, 1 px is about 1 mm and the excess sits at a few millimetres; the physical scale of the images is not recorded in the repository.)



## 4. Sensitivities

### 4.1 K8 and the basis (the OLD GLMM refitted, primary set)

| OLD fit | X^2 Naomi's areas | X^2 K = 15 | log score - 2022 (nats per RAC) | heel-front band y in (-0.18, -0.10]: O/E (NEW-only 95%) |
|---|---|---|---|---|
| step 3 (K8: no main effects) | 297.8 | 205.5 | +0.000003 | 0.67 (0.55-0.79) |
| full tensor (35 fixed effects, Laplace) | 281.5 | 222.9 | -0.00015 | 0.68 (0.56-0.80) |
| finer y basis (85, nAGQ = 0) | 257.3 | 219.5 | -0.00066 | 0.73 (0.60-0.85) |
| 2022 model | 169.7 | 149.3 | 0 | 0.66 (0.54-0.77) |

Neither removing the K8 restriction nor refining the y basis changes the picture: the X^2 stays 1.4-1.8 times the 2022 model's, the log score stays level with it, and the cells at the two pinned edges keep their residuals (heel band, 15-cell grid: 1.21, 1.12, 1.09 on the step-3 basis; 1.18, 1.21, 1.14 full tensor; 1.20, 1.24, 1.15 finer y; the lowest `new_x` column, cells 4, 7, 10, 13: 1.09, 0.95, 0.85, 1.03 against 1.08, 0.94, 0.84, 1.03 and 1.05, 0.91, 0.88, 1.01). So the heel excess and the ball deficit are not K8 artefacts. The **heel-front band** that T5 found over-predicted by NEW's own fit (F78, F84) is over-predicted by about a third by every OLD-fitted model, the 2022 model included (O/E 0.66-0.73); the finer y basis helps a little (0.73). There, NEW soles carry fewer RACs than any of the OLD-based surfaces expect, in line with the design finding of F79 (A-120: "the one-surface model does not hold across sole designs, and/or the step-3 basis is too coarse there").

### 4.2 Shoe sets, counting and coordinates

| Sensitivity | Naomi's areas X^2 (w_net) | log score GLMM - 2022 (RAC-weighted) |
|---|---|---|
| primary (478 shoes) | 297.8 (0.135) | +0.000003 |
| all 631 shoes | 504.1 (0.149) | +0.000004 |
| only `same_shoe` excluded (495) | 294.3 (0.131) | +0.00008 |
| quality rule off (542) | 397.7 (0.146) | -0.0012 |
| raw-rate quality rule (479) | 353.3 (0.142) | -0.0005 |
| also the unreviewed candidates excluded (453) | 263.1 (0.132) | +0.0023 |
| binarized RAC counts (primary) | 298.2 | |
| NEW pixels outside the OLD boundary knots removed (0.04% of pixels, 11 RACs) | 295.8 | |
| offset 0 instead of the OLD `MEAN_OFFSET` | expected counts change by at most 1.4 RACs per shoe and cell | |

The conclusions do not depend on the provisional shoe set, on the treatment of duplicate RAC pixels, or on the linear extrapolation of the OLD basis.

### 4.3 By the NEW design groups of F79 (descriptive only)

Group A (NEW ids 1-343 and 442-490) was chosen on NEW's own heel-front band data in T5, so a split by it is descriptive (A-120). Primary set, OLD GLMM, Naomi's areas (`docs/qa/T7/probes/t7_design_groups.R`; NEW-only shoe-bootstrap intervals):

| | shoes, RACs | X^2 (df 13) | w | areas 2 / 9 / 10 (rear) | area 12 | area 13 | area 14 |
|---|---|---|---|---|---|---|---|
| group A | 277, 9,045 | 230.0 | 0.159 | 1.24 / 1.11 / 1.24 | 0.75 (0.68-0.82) | 0.75 (0.67-0.83) | 0.88 |
| group B | 201, 4,591 | 97.5 | 0.146 | 1.24 / 1.16 / 1.11 | 0.96 (0.85-1.06) | 0.73 (0.63-0.83) | 0.77 |

Both groups carry the same toe-heel gradient with about the same size per RAC; they differ in area 12 (central forefoot, x < 0 in Naomi's frame). So the transfer misfit is not a composition effect of the design groups found in T5.

## 5. OLD in-sample values (descriptive; the fits saw these RACs)

| OLD, all 386 shoes | X^2 Naomi's areas | X^2 K = 15 | w (areas) | phi (areas) / phi0 |
|---|---|---|---|---|
| OLD GLMM | 64.2 | 26.5 | 0.070 | 2.29 / 0.994 |
| 2022 model | 1.1 (its own areas on raw x; near 0 by construction) | 22.2 | 0.009 | 2.30 / 0.994 |

On its own data the GLMM's misfit on the areas has w = 0.070, half of NEW's 0.148. The dispersion phi is larger in OLD (2.29) than in NEW (1.74): extra-multinomial variation is a property of both collections, not of the transfer. The regional sensitivity fits give X^2 = 0 identically on their own fitting partitions (r_newx on Naomi's areas: 4e-29; r_grid15 on K = 15: 1e-28), as they must (F31).

## 6. Figures (opened and inspected)

| File (`model_images/validation/new/`) | What it shows |
|---|---|
| `part2_obs_exp_new.png` (and `_all_new`) | O/E per area (labelled by position: heel, rear, mid, ball, fore; - / + the side of Naomi's x, c the central parts) and per grid cell, primary set (all shoes), with two-sample 95% intervals, for the OLD GLMM (blue), the 2022 model (orange) and the OLD CML (green crosses, on top of the GLMM). On every partition the heel and rear-midfoot cells sit above 1 and the ball band below; the toe band is near 1. The 2022 intervals overlap the GLMM's but its points are closer to 1 in the central forefoot (areas 12-14) and the ball band. |
| `part2_cells_map_new.png` (and `_g20_new` for K = 10 and 20) | The cells drawn on the OLD prototype (the frame of the step-4 maps, toe up), coloured by O/E (blue below 1, red above; colour key 0.5-2 under the panels), each cell labelled with its O/E. The pattern is a smooth toe-heel gradient, not a patchwork: the rear half red (1.08-1.24), the central ball and forefoot blue (0.74-0.85), the lateral forefoot and toe near 1. The 2022 model shows the same gradient, paler. |
| `part2_boot_new.png` | The two-sample null distributions of X^2 (blue: OLD estimation error included; grey: NEW-only, fit fixed) with the chi^2 95% point and the observed X^2 (red). The observed values (298 on the areas, 206 on K = 15, 149 for the 2022 model on K = 15) lie beyond nearly every replicate; the chi^2 reference sits far left of both bootstrap distributions, which is why the fixed-surface test is descriptive only. |
| `part2_logscore_new.png` | Log-score differences with two-sample intervals for every shoe set: GLMM - 2022 centred on 0 RAC-weighted and slightly positive shoe-weighted; GLMM - uniform and 2022 - uniform about +0.011 RAC-weighted. |
| `part2_pairs_new.png` | Pair ratios by distance against null 1 (grey) and null 2 (red) with simulation envelopes (boxes around 1) and shoe-bootstrap intervals, for the NEW primary set, all NEW shoes and OLD: the deficit on the same pixel, the peak at 2-4 px, the decay to about 1 beyond 8 px, alike in both datasets. |

## Decisions taken in T7

The brief asked T7 not to edit the shared files (`docs/decisions.md`, `docs/progress/LOG.md`) while T6 works in parallel, so the decisions are recorded here with provisional IDs T7-1 to T7-12. Each says how to confirm or reverse it.

### T7-1 A provisional Part 2 shoe set, frozen before any NEW Part 2 number
- **Who:** agent call (T7). **Status:** provisional (replace by the T3 frozen set; D-012, D-013).
- **Decision:** the primary set is every NEW shoe that the T0 visual review did not judge `same_shoe` or `uncertain` (plan F25: 67 and 22 shoes) and that passes the automatic part of the quality rule A-029 (fail if n >= 10 and the best on-contact rate under shifts up to 4 px is below q = 0.8217, the 5th percentile of the same statistic over the 302 OLD shoes with >= 10 RACs; 75 NEW shoes fail). 478 shoes, 13,636 RACs (68% of the NEW RACs). Written to `processed_data/validation/new/part2_shoe_set_provisional_new.csv` at 2026-11-07 06:44:39 IST (sha256 `51d08160...`), before the first NEW Part 2 number. Sensitivity sets: all 631 shoes; only `same_shoe` excluded; quality rule off; the raw-rate rule (rate < 0.584, the OLD p5 of the raw rate, applied literally to every shoe); also excluding the 31 flagged but unreviewed single-statistic candidates.
- **Why:** plan T3 steps 3 to 3d (the census at full size, the n-calibrated screen applied and reviewed in T3, the quality rule applied, the frozen `processed_data/new/part2_shoe_set_new.csv`) were never run, and Part 2 must not include reprints of OLD shoes (on them a validation measures memory, F25) or prints whose S is not the observable surface (F27). The T0 verdicts are the only visual review of the overlap; the automatic part of A-029 needs only T3's per-shoe contact table, made from OLD numbers only. The census part of A-029 (partial prints with RACs on unprinted sole, any n) needs the full-size census and is not applied.
- **Alternatives rejected:** all 631 shoes as primary (the reprints, F25); waiting for T3 (blocks Part 2 for the 2026-11-12 deadline); a T7 census of 631 shoes at full size (T3's work, with its own review).
- **To reverse:** when T3 freezes its set, point `validation_8.Rmd` at it and rerun (the bootstrap cache key includes the set's md5).

### T7-2 The OLD estimation error from surrogate shoe-bootstrap refits (B = 2,000)
- **Who:** agent call (T7). **Status:** provisional (the statistics expert reviews it).
- **Decision:** the OLD draws of the two-sample bootstrap (A-043) refit the OLD GLMM on each OLD shoe resample by PIRLS at the committed variance parameter (lme4 `mkGlmerDevfun` with nAGQ = 0 evaluated at the committed theta; the OLD basis fixed), about 1.6 s per draw instead of 250-450 s for a Laplace refit, and are centred on the committed fit: beta*_b = fixef + (beta_pirls(b) - beta_pirls(all)). B = 2,000, seed 20261106, 0 failures, 21 min on 4 workers (`tools/part2_old_draws.R`).
- **Why:** T5 step 3b (the OLD GLMM bootstrap with stored resample ids, which A-043 relies on) was never run; 2,000 Laplace refits would take about 140 CPU-hours (10-34 min each on this machine under load). Evidence that the surrogate moves like a Laplace refit: the full-data surrogate is within 0.054 SE of the committed spatial coefficients; on the first 8 resamples refitted by full Laplace the two deviations differ by at most 0.012 bootstrap SD (correlation 1.0000) and the Part 2 expected counts by at most 2.2 RACs (`docs/qa/T7/probes/t7_laplace_check.R`); its bootstrap SEs are 1.03-1.38 times the model-based ones (median 1.17), as the independent cluster-robust CML of plan F29 (median 1.13, max 1.37).
- **To confirm:** compare with the T5 Laplace draws when they exist (the same Rmd reads any draws file of the same layout).

### T7-3 The CML's parameter draws borrow the GLMM draws' deviations
- **Who:** agent call (T7). **Status:** provisional.
- **Decision:** in the two-sample bootstrap the OLD CML coefficients of replicate b are coef(CML) + (beta*_b - fixef)[spatial]; no CML refits.
- **Why:** an exact CML refit takes 190-440 s (F29, F43); the two models estimate the same spatial surface from the same data (largest coefficient difference 0.024; model-based SE ratio CML/GLMM 0.99-1.12, median 1.004). The CML results are secondary (A-030).

### T7-4 The OLD refits keep the committed spline basis
- **Who:** agent call (T7). **Status:** accepted.
- **Decision:** every OLD refit (bootstrap, sensitivity) uses the committed knots and boundary knots; the knots are not re-estimated on a resample.
- **Why:** E~(beta*) - E~(beta_old) must be a change of coefficients in one parameterization; the knots are design choices (D-015), not estimates that Part 2 propagates.

### T7-5 Output locations
- **Who:** agent call (T7), on the brief. **Status:** accepted.
- **Decision:** Part 2 outputs go to `processed_data/validation/` (OLD-only definitions and OLD in-sample tables, no suffix), `processed_data/validation/new/*_new.*`, `model_images/validation/new/*_new.{pdf,png}`, and caches to `logs/validation/` (not tracked; keyed by the md5 of every input); the plan's section 5 names (`processed_data/part2_*.csv`, `processed_data/new/part2_*_new.csv`, `model_images/new/part2_*_new.pdf`) are not used. The OLD-side T7 files are listed in the write-once list `tests/baseline/old_added_t7.sha256` (the mechanism of A-082), which the collision check of `tests/r/test_new_outputs.R` reads.
- **Why:** the brief names these folders; one T7 folder keeps T7's files apart from T6's concurrent outputs; user rule 1 holds (every NEW file in a `new` folder with `_new`).

### T7-6 Grids: K = 15 pre-registered, K = 10 and K = 20 beside it
- **Who:** agent call (T7). **Status:** provisional (Micha to confirm, A-008).
- **Decision:** the three grids of A-008 (5 y bands at the OLD contact-pixel quintiles of y; 2, 3 or 4 `new_x` bands per y band at the OLD quantiles within the band) are all reported; K = 15 is the pre-registered grid of the secondary analyses; the brief's "4 x 5 = 20 cells" is A-008's K = 20 and its "10 cells" is K = 10. Every NEW contact pixel is assigned through its `new_x` (each shoe mapped onto the prototype's width), so the grid is the prototype's; the outer bands are open, and the share of NEW pixels outside the OLD boundary knots is reported with a sensitivity.

### T7-7 Effect-size intervals (revised after the first NEW results)
- **Who:** agent call (T7). **Status:** provisional (statistics expert).
- **Decision:** the intervals of w_net and of the RMSEA-type index are **bias-shifted percentile intervals**: the 2.5% and 97.5% quantiles of the uncentred two-sample replicates X2_unc minus 2 E0, truncated at 0 (`part2_effect_ci_pct()`). The first choice, the basic-bootstrap interval of the net misfit X^2 - E0 (`part2_effect_ci()`), is reported beside it (`w_net_lo_basic`, `w_net_hi_basic` in `part2_tests_new.csv`).
- **Why:** the uncentred replicates are centred near X^2 + E0 and right-skewed (Naomi's areas, primary set: 2.5% 166, median 341, 97.5% 624, mean 353); the basic interval reflects the long right tail to the left, so its lower bound fell below 0 (w_net 0-0.178) although no centred null replicate came near the observed X^2 (their maximum 170 against 298). The percentile form keeps the skew on the right (w_net 0.071-0.196).
- **Note:** this change was made after the first NEW results were seen. It changes only these interval columns, no test, p-value or point estimate.
- **Review (2026-11-07):** the statistics reviewer found T7-7 defensible: a test inversion along the observed misfit direction, with the 2,000 centred two-sample replicates as the noise, gives w_net 0.082-0.184 on the areas, close to this interval. T7-7 is the rule of T7-13 applied to the net misfit: the uncentred replicates carry a second noise floor, and the interval removes it (here by 2 E0, there by the replicates' mean shift; on Naomi's areas the two shifts differ by 6.5 X^2 units, 104.4 against 97.9).

### T7-8 The uniform baseline of the log score
- **Decision:** "uniform-by-area" of the brief = the plan's pi_U: every contact pixel of the shoe equally likely (1 / S_i).

### T7-9 Pair test details
- **Decision:** distances between pixel centres in each shoe's own image; null 2's smoothing is a Gaussian with sd h = 24 px over the shoe's RAC counts (the plan's "Gaussian smoothing (h = 24 px)"); 999 simulations, seed 20261108; the shoe-bootstrap intervals use the resamples of the main bootstrap. No pair-resampling sensitivity (A-038): its frozen list of one-wearer pairs does not exist (T3). *(Review fixes: the consecutive-id block bootstrap of T7-16 is reported as its proxy, section 4.4.)*

### T7-10 K8 and basis sensitivities fitted in T7
- **Decision:** the OLD GLMM with the full tensor (35 fixed effects, Laplace, the step-3 optimizer) and with the nested finer y basis of F84 (85 fixed effects, nAGQ = 0, since a Laplace fit of that size did not finish in 2 h 26 min on NEW) are fitted by `tools/part2_k8_fits.R` and used for point estimates and the NEW-only dispersion of the named analyses; they have no two-sample bootstrap of their own.

### T7-11 The 2022 comparator is refitted on the step-1 surface
- **Decision:** the 2022 model's theta is refitted (Poisson GLM = conditional multinomial) on the step-1 contact surface S with Naomi's area rule at each pixel centre (`naomi_area(-x, y)`), not taken from the 2022 paper: the published estimates use another S (her window-restricted raw contact, no stamp sweep, RAC pixels not added) and her pixel-level area masks. Rerunning her code path gives relative intensities within 9.4% of ours per area (`docs/qa/T7/probes/t7_naomi2022.R`); her optimizer call (optim's default Nelder-Mead) stops at its iteration limit, up to 9.8% from the converged optimum (to tell Naomi).
- **Context added in the review fixes (minor finding 6):** that gap is 1.61 log-likelihood units on 13 parameters, deep inside the 95% joint likelihood region (11.18 units; LR 3.2 on 13 df, p = 0.997): correct, but immaterial for her conclusions; Naomi is told in those terms.

### T7-12 Parallel runs on a shared machine
- **Decision:** the bootstrap forks its workers (`RAC_WORKERS`) from a parent that first drops the pixel tables (R's garbage collector makes forked children copy the pages it touches: 4 workers reached 3 GB each and left 1 GB free with T6's fits running, so that run was stopped and restarted lean); the pair test runs sequentially. Results do not depend on the number of workers (resamples drawn up front; PIRLS and the evaluations use no random numbers): the 2,000 x 2,202 bootstrap statistics and the pair results of the run with 3 workers and of the final run with 2 workers are `identical()` (`docs/tests/T7-results.md` section 13).

### T7-13 Model-comparison intervals: two estimands, both centred on the point (review finding 1)
- **Who:** agent call (T7 review fixes), on the statistics reviewer's major finding 1 (LOG 2026-11-07 11:05). **Status:** provisional (statistics expert). **Supersedes:** the raw two-sample percentile intervals of the first run for the log-score differences and Delta X^2 (still written, as `lo_two_raw`, `hi_two_raw`).
- **Decision:** every interval of a model comparison (log scores, their differences, Delta X^2, the calibration slope) is reported for two estimands: **the published fitted surfaces** (what an examiner would use; the NEW-only shoe bootstrap, every fit held fixed; columns `_new`) and **the model classes** (each model fitted on an OLD-size collection; the two-sample bootstrap, OLD estimation noise included; columns `_two`). Both intervals are the percentile intervals of their replicates shifted so that the replicates' mean equals the point estimate (`part2_shift_ci()`).
- **Why:** each two-sample replicate scores a model refitted on an OLD resample, one layer of OLD estimation noise more than the point estimate, and a resampled X^2 carries a second noise floor; the raw percentile interval is then not centred on its point (log score, GLMM - 2022: replicate mean -0.0013 against the point +0.000003, 0.39 bootstrap SD; Delta X^2: the replicates exceed the point by 7.5 to 16.6), so the first run's significance pattern ("significant on the 20-cell grid and on every grid with all 631 shoes", "the interval excludes a GLMM advantage above 0.5% and a 2022 advantage above 0.8%") came from the interval method, not from the data. The shift removes that layer, as T7-7 does for the net misfit. The NEW-only replicates of Delta X^2 are shifted by less than 2 X^2 units (0.6 to 1.8 on the primary set; `docs/tests/T7-review-fixes-results.md`), those of a log score, a ratio of sums, hardly at all.
- **Note:** decided after the results were seen, on review; no test, p-value or point estimate changes. The real-structure calibration (T7-17) checks the coverage of both interval types.

### T7-14 Named analysis 3 is worded within its calibration (review finding 2)
- **Who:** agent call (T7 review fixes), on the reviewer's major finding 2. **Status:** provisional.
- **Decision:** the summary and the paper item say what the test supports: the RACs of a shoe are not independent draws from the common surface, nor from its heterogeneity-adjusted version (null 2); contagion, fine-scale inhomogeneity and shoe-specific intensity are not separated; the forensic consequence (no product of single-RAC probabilities) holds under all three. The null-2 calibration failure goes into the summary. The distance profile is used as evidence only against toys that also carry the inhibition seen in the data (`docs/qa/T7/probes/t7_pair_profiles_hardcore.R`: heterogeneity with a 2-px hard core or a same-pixel exclusion), and the OLD/NEW differences in the profile are reported, not merged.
- **Why:** the first wording ("even after allowing for shoe-specific patterns", "short-range clustering with inhibition below about 2 px", "in both datasets") went beyond the calibration (null 2 rejects 0.69 at a log-intensity sd of 0.3) and beyond the data (OLD has an excess at (0, 2] px, not inhibition).

### T7-15 The size of the misfit is read against the spatial signal (review finding 3)
- **Who:** agent call (T7 review fixes), on the reviewer's major finding 3. **Status:** provisional.
- **Decision:** named analysis 1 reports, beside Cramer's w, (a) the **uniform benchmark**: the X^2 of uniform placement on each shoe's contact surface and the share of it each model removes (raw and net of the noise floors), in sample on OLD too; (b) the **calibration slope** alpha of each model (`part2_calib_slope()`: the conditional Poisson fit O ~ shoe + offset(log E_unif) + alpha log(E / E_unif)), at the cell level and at the pixel level (`part2_pixel_slope()`), with its NEW-only interval, the value a correct OLD surface would show through OLD estimation noise alone (the dilution of the 2,000 OLD draws, 500 at the pixel level), and a one-sided p; (c) the model's X^2 after recalibration by alpha, that is, how much of the misfit the attenuation explains. "Small by Cohen's convention" is withdrawn.
- **Why:** Cohen's convention has no meaning here: the whole spatial signal of NEW (uniform placement) has w = 0.19, so a misfit of w = 0.15 is most of it.
- **Where the review was not followed:** the reviewer read the misfit as "mostly the OLD contrasts being about 30% too strong". The slope is real (section 3), but recalibrating the contrasts by it removes only 9% of the GLMM's X^2 on the areas (4-10% on the grids): most of the misfit is a redistribution along the shoe that the OLD contrasts do not have (section 3). The report says both.

### T7-16 Consecutive-id blocks as the proxy of the pair sensitivity A-038 (review minor finding 4)
- **Who:** agent call (T7 review fixes), on the reviewer's minor finding 4. **Status:** provisional (replace by the T3 pair list when it exists).
- **Decision:** the NEW shoes of the primary set are also resampled in blocks of 2 and 4 consecutive ids (`part2_block_groups()`: block = (id - 1) %/% size; 282 and 153 blocks), with the same OLD draws, for the named analyses, the dispersion, the model comparisons, the calibration slope and the pair ratio (section 4.4); every other interval is stated as conditional on independent shoes.
- **Why:** pairs of one wearer sit at consecutive ids (plan F26) and design batches too (F79); T3's frozen pair list (A-038) does not exist.

### T7-17 The real-structure calibration is run, on the chain actually used (review minor finding 5)
- **Who:** agent call (T7 review fixes), on the reviewer's minor finding 5. **Status:** accepted.
- **Decision:** `tests/r/slow/test_validation_real_calibration.R` runs the plan's slow calibration on real structure (60 OLD-like and 100 NEW-like real OLD shoes, RACs simulated from the committed GLMM surface, inner B = 100), with two changes: the OLD fits are the PIRLS surrogate of T7-2 on the step-1 case-control sample (the plan says glm without random effect; the surrogate is the chain the Part 2 intervals rest on), and 400 replicates instead of 200, because it also checks the coverage of the two interval types of T7-13 against the exact expectations of each replicate (E1, the fitted surfaces) and their mean (E2, the model classes). Results in section 2.5.


## Limitations

1. **Dataset shift between the two collections.** The NEW prints come from another collection, scanned in another format (255 x 367 px against 307 x 395), with their own marking of RACs, their own mix of sole designs and their own wear. NEW prints are fainter and more often partial (plan F27), and the reprinted shoes carry 3-4 times the RACs in NEW (F25), a direct sign that RAC marking or wear differs between the collections. A misfit of the OLD surface on NEW is therefore "the OLD surface does not transfer to NEW"; it is not by itself "the model is wrong" (A-051). The reverse also holds: a good fit would not prove that one surface fits every collection.
2. **Sole design.** One intensity surface for all shoes is an assumption (reviewer 1, point 4). T5 found a design-related deficit at the heel front (F79): a group of NEW soles prints there but carries about a quarter of its RAC density, and so do the OLD prints of the same soles. A misfit concentrated in that band is worded "the one-surface model does not hold across sole designs, and/or the step-3 basis is too coarse there" (A-120); the design groups of F79 were chosen on NEW's band data, so any split by them is descriptive.
3. **The shoe set is provisional (T7-1).** The overlap exclusion uses the T0 visual review (67 `same_shoe`, 22 `uncertain`); 31 flagged single-statistic candidates were never reviewed, and the census part of the quality rule (partial prints with RACs on unprinted sole, any n) was not applied. The sensitivity sets bracket both.
4. **The OLD estimation error comes from surrogate refits (T7-2),** checked against Laplace refits on 8 resamples only. The CML's parameter draws borrow the GLMM's deviations (T7-3). Both are approximations; both checks are reported above.
5. **The pair test cannot separate contagion from fine-scale inhomogeneity,** and its null 2 does not absorb shoe-specific heterogeneity (named primary analysis 3 and its calibration). The reading rests on the distance profile and on toys with their own geometry (with and without inhibition, T7-14): it bounds the share of smooth shoe-specific intensity (about a quarter, at most a half of NEW's 2-8 px excess), it does not decompose the excess.
6. **K8 and the basis.** The step-3 surface is pinned to its intercept along the left `new_x` edge and the heel edge (K8), and its y knots are coarse at NEW's heel front (F84). The full-tensor and finer-y sensitivities refit the OLD model, but without a two-sample bootstrap of their own.
7. **What Part 2 does not test.** It tests where a RAC falls given that the shoe has n_i RACs (the normalization removes the shoe's level, D-003). It does not test the level (how many RACs a shoe carries), the sigma^2 correction of the maps (K3, D-009), or the probability of a set of RACs, which the model does not give (Micha, 2026-10-26): within-shoe clustering (named analysis 3) means that the RACs of a shoe are not independent draws, so a product of single-RAC probabilities over a set of RACs is not their joint probability.
8. **Independence of shoes.** Pairs of shoes of one wearer (F26) are resampled as independent shoes; the pair-resampling sensitivity of A-038 needs a frozen list of such pairs, which T3 did not produce. Its proxy, blocks of consecutive ids (T7-16), raises the dispersion and widens the intervals (Naomi's areas, GLMM: phi 1.74 for single shoes, 1.92 for blocks of 2 ids, 2.20 for blocks of 4; noise floor 49, 51, 54; p_boot 0.0005 in every case; calibration-slope interval 0.55-0.85, 0.54-0.84, 0.55-0.85; `part2_block_new.csv`), so every interval in this report is conditional on independent shoes and the marginal ones (those that nearly touch 0) should be read with that in mind; the primary test is not affected.
9. **The calibration of the chain.** The two-sample bootstrap's size was shown on a cell-level toy (F34) and, since the review fixes, on real shoe structure with the PIRLS refits (section 2.5; rejection 0.052 at 5%; the centred two-sample intervals cover 99.3-99.5%, so they are conservative; the NEW-only log-score interval covers 91%, slightly below nominal). The latter setting has no dataset shift and a smaller OLD sample than the real one (60 against 386 shoes), so it is a check of the machinery, not of every number.


## Files

| File | What it is |
|---|---|
| `statistical_model/validation_8.Rmd` | the whole Part 2 analysis (both datasets; run from `statistical_model/`; knit to `logs/knit/validation/`) |
| `statistical_model/R/validation.R` | pixel tables, partitions, linear predictors, cell statistics, regional fit, bootstrap core, OLD refit surrogate, frozen definitions |
| `statistical_model/R/pairs.R` | the within-shoe pair test (FFT expectations, vectorized simulations) |
| `tools/part2_old_draws.R` | the 2,000 OLD shoe-bootstrap draws (and `--laplace 8`, the check) |
| `tools/part2_k8_fits.R` | the full-tensor and finer-y OLD GLMMs |
| `tests/r/test_validation_{areas,stats,pixels,pairs}.R` | fast tests (run by `tests/run_all.sh`) |
| `tests/r/slow/test_validation_{calibration,pairs_calibration}.R` | slow calibration checks (not in the fast suite; outputs in `docs/tests/T7-results.md`) |
| `tests/r/slow/test_validation_real_calibration.R` | the plan's real-structure calibration of the two-sample chain, with the coverage of both interval types (review fixes, T7-17; output in `docs/tests/T7-review-fixes-results.md`) |
| `docs/qa/T7/probes/t7_{naomi2022,laplace_check,pair_profiles,design_groups}.R` and `.out` | the 2022 reproduction, the surrogate-vs-Laplace check, the toy pair profiles, the residuals by the F79 design groups |
| `docs/qa/T7/probes/t7_pair_profiles_hardcore.R` and `.out` | the toy pair profiles with a 2-px hard core or a same-pixel exclusion (review fixes, T7-14) |
| `processed_data/validation/part2_grid_cuts.csv`, `part2_regional_theta.csv` | the OLD-only definitions, frozen before any NEW number |
| `processed_data/validation/old_glmm_draws.rds`, `old_glmm_draws_laplace_check.rds`, `glmm_fulltensor.rds`, `glmm_finey.rds` | the OLD draws and refits |
| `processed_data/validation/part2_{cells,tests,logscore,pairs}.csv` | OLD in-sample tables (`tests` with the uniform model and the in-sample slope since the review fixes) |
| `processed_data/validation/new/part2_shoe_set_provisional_new.csv` | the provisional NEW shoe set (frozen before any NEW number) |
| `processed_data/validation/new/part2_{cells,tests,cell_oe,logscore,delta_x2,wald_param,pairs,sensitivity,k8_sensitivity,k8_edge_cells,heel_front_band}_new.csv` | the NEW results (`logscore` and `delta_x2` with the intervals of T7-13: `_new`, `_two`, and the first run's `_two_raw`) |
| `processed_data/validation/new/part2_{benchmark,contrast,pixel_slope,logscore_gain,logscore_tercile,block}_new.csv` | review fixes: the uniform benchmark and the cell-level calibration slopes, the per-area contrasts against uniform, the pixel-level slopes, the gains over uniform against the self-predicted and the OLD in-sample gains, the log-score difference by thirds of the RAC counts, the block bootstrap |
| `model_images/validation/new/part2_{obs_exp,obs_exp_all,cells_map,cells_map_g20,boot,logscore,pairs,calibration}_new.{pdf,png}` | the figures (`calibration`: review fixes) |
| `docs/qa/T7/probes/t7_area_shares_map.R` (2026-11-09) | a probe outside the knit: reads `part2_contrast_new.csv`, writes `processed_data/validation/new/part2_area_shares_new.csv` and `model_images/validation/new/part2_area_shares_new.*`, `part2_oe_simple_new.*` (report figures 3 and 4); rerun it after every knit |
| `tests/baseline/old_added_t7.sha256` | the OLD-side files T7 added (write-once list, read by the collision check of `tests/r/test_new_outputs.R`) |
| not tracked: `processed_data/**/pixels_full*.rds`, `logs/validation/` | the pixel tables and the bootstrap, pair and pixel-slope caches |

