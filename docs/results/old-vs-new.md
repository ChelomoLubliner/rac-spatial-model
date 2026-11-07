# OLD vs NEW: how the two shoe datasets compare (T6)

**Date:** 2026-11-07 (T6, corrected the same day by the T6 review fixes). **Task:** T6 of `docs/plans/2026-11-05-new-shoes-pipeline.md` (Micha's "compare old vs new": the same maps side by side, coefficients, sigma^2, CIs; meeting note section 4). **Branch:** `feature/new-shoes-pipeline`. **Code:** `statistical_model/compare_old_new_7.Rmd`, `statistical_model/R/compare_old_new.R`, `tools/fit_compare_models.R`, `tools/run_compare_fits.sh`. **Tests, commands and raw outputs:** `docs/tests/T6-results.md` (section 12: the review fixes). **Decisions:** A-122 to A-138 in `docs/decisions.md`.

Every number below comes from the CSV tables the Rmd wrote (`processed_data/compare/*_old_vs_new.csv`) or from its printed output (`logs/knit/compare/compare_old_new_7.html`, not tracked). Figures: `model_images/compare/*_old_vs_new.pdf`, with PNG copies in `docs/qa/T6/`. "OLD" = the 386 shoes of the paper, "NEW" = the 631 shoes of the second file. "Reprints" = the 89 NEW shoes judged `same_shoe` (67) or `uncertain` (22) in the T0 visual review (plan F25; T3's own screen has not been run, so this is the list of decision D-012).

**What the review fixes changed** (statistics review of 2026-11-07 11:00, `docs/progress/LOG.md`): (1) the bootstrap |z| maps and CI-cut bands of the first version held each dataset's RAC total fixed, so they left out the sampling error of the overall level; absolute densities are now compared with draws recalibrated on their own resampled shoes, and shapes separately (A-133); (2) "NEW higher along the forefoot edges" is withdrawn: the raw data do not show it, and a model-free regional table now backs every regional statement (A-134); (3) the area ratios are given for every basis, with shoe-bootstrap intervals (A-135); (4) the sigma^2 difference without the offset is not robust (A-136); (5) the RAC-coding finding rests on matched RACs (A-137); (6) the primary equality test is the one without the reprints (A-138).

## Summary

| Question | Answer (95% intervals in brackets) |
|---|---|
| Do the data differ? | RACs per shoe are alike (median 22 OLD, 24 NEW). NEW prints have 12% less contact surface (median 8,925 vs 10,196 px; Wilcoxon p 3e-11), so NEW has more RAC pixels per contact pixel overall (3.45 vs 3.25 per 1,000), but **the overall level does not differ significantly: NEW / OLD 1.06 [0.93, 1.21]** (whole-shoe bootstrap). **The RAC type codes differ, for the same RACs:** on the 67 reprinted soles, 1,436 RACs of the OLD print are found again at the same place on the NEW print, and only 65% of them carry the same type code; 258 RACs coded 2 on the OLD print are coded 1 on the NEW print, 73 the other way (type-1 share of the matched RACs 0.27 OLD, 0.43 NEW). The two collections were coded (or marked) by different rules. |
| Do the contours differ? | No. The T4 QA metrics have the same distributions (tightness median 1.019 OLD, 1.013 NEW; per-shoe mean distance from the snake to the contact, median 5.75 and 5.77 px; contact inside the contour fill at least 0.978 and 0.984). |
| Is the spatial surface the same? | **No, but the difference is modest and much weaker than the model-based tests say.** Primary test (equality of the 24 spatial coefficients on the common OLD basis, GLMM, without the reprints, the one comparison whose two samples are independent): **shoe bootstrap W = 46.7, F(24, 976) p = 0.0056** (model-based 118.1; cluster-robust Efron CML 46.2, p 0.004). With all NEW shoes: 51.9 (p 0.0014; model-based 129.5); these tests are conservative, because 67 NEW shoes are prints of OLD soles and the tests ignore that covariance. |
| How large is the difference? | The NEW / OLD ratio of the two calibrated maps has a median of 1.11 and a central 90% range of 0.84-1.44 on the common basis (1.12 and 0.85-1.49 on each dataset's own knots). The level does not differ significantly (row 1), so the difference is mostly one of shape. Pointwise, with shoe-bootstrap SEs (not adjusted for multiplicity): NEW's absolute density is significantly higher on 21.5% of the prototype and lower on 3.9% (16.0% and 4.2% away from the K8-pinned edges); as shapes (each map divided by its dataset's observed density) NEW is relatively higher on 20.4% and lower on 12.3% (14.9% and 13.2% away from the pinned edges). Without the reprints: 14.2% and 6.6% (absolute), 19.2% and 12.1% (shape). |
| Where? | **In the raw data** (RAC pixels over contact pixels by region, whole-shoe bootstrap; table in section 5.1): NEW higher at the **heel bottom** (y < -0.35: 1.23 [1.05, 1.45]; as shape 1.15 [1.05, 1.28]) and in a **band at the top of the midfoot** (y -0.05 to 0.05: 1.32 [1.10, 1.61]); NEW lower in a **band at the heel front** (y -0.18 to -0.12: 0.63 [0.45, 0.90]) and, relative to its own level, in the **forefoot centre** (shape 0.82 [0.72, 0.94]; absolute 0.88 [0.73, 1.05], not significant). The two bands are in the data but not in the step-3 maps (only the finer-y basis follows them). **Not in the data:** NEW higher along the forefoot edges, at the toe and along the right midfoot edge; every model-free interval there contains 1 (e.g. right forefoot rim 1.12 [0.86, 1.46], right toe 1.01 [0.81, 1.30]). The GLMM's excess at the right toe edge is a spline feature where the data are sparse. At OLD's forefoot peak the bootstrap bands overlap (OLD 4.77 [4.17, 5.51], NEW 3.92 [3.55, 4.29] RAC px per 1,000 contact px), although the pointwise difference is significant (z -2.3; as shape -3.7). The left edge (new_x near -0.19) and the heel edge are pinned by K8 and say nothing. |
| sigma^2? | **NEW's shoes vary less in RAC density.** With the offset (the spread of RAC density per contact pixel): OLD 0.979 [0.839, 1.149], NEW 0.641 [0.565, 0.730], ratio 0.65, z = -4.1 (approximate profile likelihood); a model-free check (the moment estimator of plan F82, whole-shoe bootstrap) gives 0.71 [0.58, 0.87], z = -3.3; so z is about -3.3 to -4.1 (without the reprints -3.0 to -3.8). **Without the offset** (the spread of RAC counts, as committed): 0.960 vs 0.756, z -2.3 by the profile but -1.8 (0.83 [0.68, 1.02]) by the model-free check: **not robust**. |
| CIs at the cuts | On each dataset's own knots NEW lies above OLD at the heel-front cut (row 250) on 32% of its columns, but on the common basis on none (bootstrap): mostly NEW's coarse step-3 y knots (plan F84). At the forefoot cut (row 110), absolute densities with bootstrap bands that include the level: the bands overlap at OLD's peak and separate only at the K8-pinned left edge (NEW above, 6% of the columns, not data); pointwise z < -1.96 on 16% of the columns. As shapes NEW lies below OLD on 24% of the columns (disjoint bands, new_x -0.08 to 0.01; pointwise 39%). Shape bands are 1.18-1.34 times as wide as the model-based ones; the level widens the absolute bands by another 1.1-1.35. |
| Naomi's 14 areas | **The magnitudes depend on the spline basis; the conclusion does not.** Between areas (highest / lowest area mean): OLD 1.79-1.96, NEW 1.54-1.65 across the step-3, full-tensor and finer-y bases. Full tensor (no K8 pin), shoe-bootstrap intervals: **OLD 1.96 [1.74, 2.32], NEW 1.54 [1.48, 1.75]**. Within one area (largest p90 / p10): OLD 2.63-4.48, NEW 2.64-3.13 across the bases; full tensor **OLD 2.90 [2.69, 4.10] (area 6), NEW 2.72 [2.41, 3.44] (area 5)**. On every basis 3 to 9 of the 14 areas vary within as much as between. The meeting's 1.75x / 2.4x / 5.5x were computed with the areas applied to the unmirrored x; reproduced exactly and corrected here; the conclusion holds. |
| Random vs CML | Within -1.2% to +0.3% (OLD) and -1.7% to +0.6% (NEW) of each other: the two estimators agree on both datasets. |
| Do the reprints drive it? | No. Without the 89 reprinted or uncertain NEW shoes the surfaces still differ (the primary test above), and the model-free shape differences stay: heel bottom 1.15 [1.05, 1.28], midfoot-top band 1.23 [1.08, 1.40], heel-front band 0.65 [0.48, 0.90], forefoot centre 0.84 [0.73, 0.97]. Without them NEW's overall level equals OLD's (1.005 [0.88, 1.15]), so the absolute heel-bottom excess is smaller (1.16 [0.99, 1.37]). |

**Reading.** One spatial intensity surface describes both datasets to within about plus or minus 20-45% over most of the standardized shoe, and the main relief (high in the forefoot and at the heel, low at the toe tip, the back of the heel and the left edge) is shared. The overall RAC density per contact pixel does not differ significantly between the collections (1.06 [0.93, 1.21]). Their shapes do differ beyond sampling error (primary test p = 0.0056, robust variances), at places the raw data confirm: NEW relatively higher at the heel bottom and in a narrow band at the top of the midfoot, lower in a narrow band at the heel front and, relative to its own level, in the forefoot centre. The two bands are resolved only by a finer y basis. Part of the NEW heel-front deficit belongs to a group of NEW sole designs (plan F79, A-120), and the RAC type coding differs between the collections even for the same RACs, so a difference of "the intensity" cannot be separated here from differences of sole design and of marking. For the paper: the surface estimated on OLD transfers to NEW only approximately, which is what T7 (Part 2) tests formally; claims should say "similar in shape, not identical", and model-based CIs and Wald tests overstate precision: the shoe bootstrap makes the SEs of the map's shape 1.2-1.35 times larger (1.5-1.8 times with the level) and the Wald statistics 1.6-2.5 times smaller. Regional statements should rest on the model-free table (section 5.1), not on the spline maps alone, which extrapolate at sparse edges.

## 1. The data (task item 6)

`processed_data/compare/data_summary_old_vs_new.csv`, `rac_types_old_vs_new.csv`, `rac_types_reprint_pairs_old_vs_new.csv`, `rac_types_matched_old_vs_new.csv`, `rac_types_matched_pairs_old_vs_new.csv`; figure `data_overview_old_vs_new`.

| | OLD | NEW |
|---|---|---|
| shoes | 386 | 631 |
| RACs (RAC pixels, the cases) | 13,287 (13,249) | 20,013 (19,990) |
| controls, case-control rows | 38,600, 51,849 | 63,100, 83,090 |
| RACs per shoe: min / median / mean / p90 / max | 1 / 22 / 34.4 / 76 / 309 | 1 / 24 / 31.7 / 67 / 281 |
| share of RACs on the top 10% of shoes | 0.369 | 0.322 |
| contact px per shoe S: p5 / median / p95 | 5,839 / 10,196 / 16,005 | 4,880 / 8,925 / 14,286 |
| RAC px per 1,000 contact px: per-shoe median / overall | 2.18 / 3.25 | 2.62 / 3.45 |
| var log(100 / S); cor(log n, log S) | 0.098; 0.149 | 0.121; 0.361 |
| `MEAN_OFFSET` | -4.614311 | -4.465503 |

Per shoe (descriptive Wilcoxon tests; the shoes are no random sample of one population and 89 NEW shoes reprint OLD soles): RACs p = 0.67, contact px p = 3.1e-11, RAC density p = 0.0064. The overall density ratio NEW / OLD is 1.06 [0.93, 1.21] by a whole-shoe bootstrap (section 5.1): the per-shoe test above weighs each shoe equally, the overall ratio weighs each contact pixel, and only the latter is the level of the calibrated maps.

**RAC type** (the `type` column of the locations files; its codebook is not in the repository): type 1 is 24.2% of OLD's RACs and 42.6% of NEW's, type 2 58.8% and 50.1%, types 4 and 6 6.8% each on OLD but 1.7% and 2.1% on NEW. Per shoe the median type-1 share is 0.23 (OLD) and 0.48 (NEW). The NEW reprinted shoes (0.422 type 1) do not differ from the other NEW shoes (0.427), and on the 67 same-sole pairs (at least 5 RACs in both prints) the NEW print has the higher type-1 share in 58 pairs (median 0.47 vs 0.24, paired Wilcoxon p 3.2e-11).

**The same RACs were coded differently** (RAC-level evidence, review fix A-137). On each of the 67 pairs the NEW print's RACs were moved onto the OLD print's (`t6_match_racs`: every shift of up to 0.03 units in each direction, in steps of one prototype pixel, mirrored or not; the shift that gives the most OLD RACs a NEW RAC within 0.008 units, about 2.4 pixels, wins; then RACs are paired one to one, closest first). Every pair registered without a mirror, with a median shift of one pixel in x and in y. 1,436 of the 2,905 OLD and 3,158 NEW RACs pair up (a median 53% of an OLD print's RACs). Type on the OLD print (rows) against type on the NEW print (columns), matched RACs:

| OLD \ NEW | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| 1 | **313** | 73 | 1 | 2 | 0 | 0 | 0 |
| 2 | 258 | **585** | 6 | 4 | 2 | 5 | 0 |
| 3 | 3 | 16 | **15** | 0 | 0 | 1 | 0 |
| 4 | 29 | 39 | 1 | **13** | 0 | 1 | 2 |
| 5 | 0 | 0 | 0 | 0 | **4** | 0 | 0 |
| 6 | 8 | 34 | 12 | 0 | 0 | **8** | 0 |
| 7 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |

Only 65.3% of the matched RACs carry the same code on both prints. 258 RACs coded 2 on the OLD print are coded 1 on the NEW print, against 73 the other way; OLD's types 4 and 6 mostly become 1, 2 or 3 on the NEW print. The type-1 share of the matched RACs is 0.271 (OLD print) against 0.425 (NEW print), and 0.456 among the NEW RACs without an OLD match. Since these are the same RACs of the same soles, "the RACs differ" cannot explain the shift: **the two collections were coded (or marked) by different rules.** This matters for any analysis by RAC type and is a "dataset shift" to state in the paper's limitations (marking protocol), together with the reprints. Whether a codebook exists and whether both collections followed one protocol is a question for Shlomo, Naomi and Yoram.

## 2. Contours and step-2 distances (task item 6)

`contour_step2_summary_old_vs_new.csv` (the T4 QA tables `docs/qa/T4/old/snake_metrics.csv`, `docs/qa/T4/new/snake_metrics_new.csv`, and the step-2 CSVs); figure `contours_step2_old_vs_new`.

| per shoe | OLD median [min, max] | NEW median [min, max] |
|---|---|---|
| contour pixels | 700 [614, 742] | 709 [611, 766] |
| tightness (contour area / convex hull of the contact) | 1.019 [0.848, 1.091] | 1.013 [0.857, 1.102] |
| mean distance snake to contact (px) | 5.75 [3.62, 8.92] | 5.77 [4.00, 9.78] |
| cleaned contact inside the contour fill | 1.000 [0.978, 1.000] | 1.000 [0.984, 1.000] |
| longest cut of the print by the contour (px), p95 | 11.3 | 7.7 |

The NEW contours are as tight as the OLD ones and cut less of the print. Step 2 (distance to the own contour, `new_x`, y) has nearly the same distributions for cases and controls in both datasets (distance to the contour, median: cases 0.079 OLD and 0.074 NEW, controls 0.072 and 0.071 coordinate units); NEW's cases sit lower (median y 0.045 vs 0.092), the heel and midfoot weight that plan F74 noted.

## 3. sigma^2 (task item 3)

`sigma2_old_vs_new.csv`, `sigma2_tests_old_vs_new.csv`, `sigma2_moment_bootstrap_old_vs_new.csv`; figure `sigma2_old_vs_new`. Profile intervals: approximate profile likelihood (theta moved, the intercept re-optimized, the spatial coefficients held at their estimates; the Laplace deviance of `glmer` as in the fits; at the estimates it equals -2 logLik exactly in all six profiles); z: the log-sigma^2 difference over the SEs read from the profile intervals. Model-free check (review fix A-136): the moment estimator of plan F82, var over shoes of the per-shoe log-odds minus its mean binomial sampling variance 1/n + 1/100 (log(n / 100) without the offset, log(n / (px - n)) with it), with its SE and the interval of the NEW / OLD ratio from a whole-shoe bootstrap (OLD and NEW resampled independently, 4,000 draws).

| fit | offset | OLD | NEW | NEW / OLD | z, profile | model-free check: NEW / OLD, z |
|---|---|---|---|---|---|---|
| step-3 GLMM (committed) | none: spread of RAC counts | 0.960 [0.822, 1.127] | 0.756 [0.667, 0.859] | 0.79 | -2.31 (p 0.021) | 0.83 [0.68, 1.02], **-1.83 (p 0.067)** |
| refit with `offset(log((px - n)/100))` | spread of RAC density | 0.979 [0.839, 1.149] | 0.641 [0.565, 0.730] | 0.65 | -4.09 (p 4e-5) | 0.71 [0.58, 0.87], -3.27 (p 0.001) |
| NEW without reprints (OLD basis) | none | | 0.777 [0.678, 0.893] | 0.81 | -1.98 (p 0.048) | 0.85 [0.70, 1.04], -1.56 (p 0.12) |
| NEW without reprints (OLD basis) | offset | | 0.654 [0.570, 0.754] | 0.67 | -3.76 (p 2e-4) | 0.73 [0.59, 0.89], -2.98 (p 0.003) |
| NEW group B only (OLD basis) | none | | 0.675 | | | |

The moment estimates are OLD 1.034 and NEW 0.861 without the offset (F82's values), 1.039 and 0.741 with it; their bootstrap SEs of log sigma^2 (0.075 and 0.067 without the offset, 0.075 and 0.071 with it) are close to the SEs implied by the profile intervals (0.080 and 0.065 for both), so the different z values come from the two estimators (their point estimates differ), not from the interval methods.

The offset refits (plan F35, A-044) behave as predicted: intercept -6.8837 (OLD) and -6.3481 (NEW) against -6.8825 and -6.3522 predicted from the no-offset fits, spatial coefficients within 0.018 and 0.084. **sigma^2 is not a spatial quantity:** it is the between-shoe spread of the per-shoe level (with the offset, of the RAC density per contact pixel). **With the offset, the density pair:** NEW's shoes vary less in RAC density than OLD's, also without the reprints, by both estimators (z about -3.3 to -4.1). **Without the offset the difference is not robust:** it is significant by the profile (p 0.021) but not by the moment estimator (p 0.067), and the no-offset sigma^2 measures the spread of counts, which mixes density with contact area (F82). Possible reasons for the density difference (not separable here): a more homogeneous shoe population or wear, a different marking protocol (section 1), and NEW's lower contact areas.

## 4. Fixed effects and Wald tests (task item 2)

`fixef_old_vs_new.csv` (every coefficient with its model-based and bootstrap SE and both z values), `equality_wald_old_vs_new.csv` (with the columns `samples` and `primary`), `wald_all_spatial_old_vs_new.csv`, `bootstrap_se_ratio_old_vs_new.csv`; figure `fixef_zdiff_old_vs_new`. The two step-3 fits have different knots, so the coefficients are compared on the **common basis**: OLD's own step-3 knots, NEW refitted on them (T5, A-112). GLMM vcov: RX for both (A-055).

**Single coefficients:** 4 of the 24 spatial coefficients differ by |z| > 1.96 (model-based; 3 with bootstrap SEs); the largest is `x3:y3` (z = -5.56 model-based, -4.46 bootstrap). Without the reprints 3 of 24 (max 5.01); group B only 2 of 24 (max 3.33). Spline coefficients are not interpretable one by one; the joint tests are:

| equality of the 24 spatial coefficients | samples | W | df | p | reference |
|---|---|---|---|---|---|
| **GLMM, OLD vs NEW without reprints, shoe bootstrap (primary)** | independent | **46.7** | 24 | **0.0056** | F(24, 976) |
| GLMM, OLD vs NEW without reprints, model-based | independent | 118.1 | 24 | 2.1e-14 | chi^2 |
| CML exact, OLD vs NEW without reprints, model-based | independent | 118.7 | 24 | 1.7e-14 | chi^2 |
| CML Efron, OLD vs NEW without reprints, cluster-robust (indicative) | independent | 46.2 | 24 | 0.0042 | chi^2 |
| GLMM, OLD vs NEW (all), shoe bootstrap (1,000 paired difference draws) | shared soles ignored | 51.9 | 24 | 0.0014 | F(24, 976) |
| GLMM, OLD vs NEW (all), model-based | shared soles ignored | 129.5 | 24 | 1.9e-16 | chi^2 |
| CML exact, OLD vs NEW (all), model-based | shared soles ignored | 129.9 | 24 | 1.6e-16 | chi^2 |
| CML Efron, OLD vs NEW (all), cluster-robust (indicative) | shared soles ignored | 53.2 | 24 | 5.5e-4 | chi^2 |
| GLMM, OLD vs NEW group B only, model-based | shared soles ignored (26 of the 89 reprinted or uncertain shoes are in group B) | 46.3 | 24 | 0.0041 | chi^2 |

**Which test is primary** (review fix A-138). Every test takes Var(b_old - b_new) = V_old + V_new, i.e. two independent samples. That holds only without the reprints. With them, 67 NEW shoes are prints of OLD soles, so the two estimates share part of their data, Cov(b_old, b_new) > 0, V_old + V_new overstates the variance of the difference and the "all" tests are conservative (their p-values too large). The primary test is therefore the GLMM shoe bootstrap without the reprints (plan T6, A-045): whole shoes are resampled (a shoe drawn twice is two shoes), the GLMM's fixed effects are refitted by PIRLS at the fit's sigma, B = 1,000 per dataset, 0 failed draws, and the paired difference draws go to the Hotelling F reference (the separate-draws chi^2 version over-rejects: 0.083 at nominal 0.05 in the test of section 4 of `tests/r/test_compare_old_new.R`). The robust tests agree with each other (bootstrap 46.7, Efron cluster-robust 46.2 without the reprints) and are about 2.5 times smaller than the model-based W: RACs of one shoe are not independent given the shoe's level (K9). Bootstrap / model-based SE of the spatial coefficients: median 1.13 (OLD), 1.09 (NEW), 1.10 (NEW without reprints), range 0.97-1.35, matching the Efron cluster-robust ratios of plan F29 and F83 (median 1.13 OLD, 1.06 NEW).

**All 24 spatial coefficients = 0** (task item (f) of the plan): OLD 428.7 (stored Hessian vcov) or 427.8 (RX), NEW 585.9 (own knots) or 623.1 (OLD basis), all p < 1e-16 model-based; with the shoe bootstrap OLD 255.3, NEW (OLD basis) 377.1, NEW without reprints 311.4, all with F(24, 976) p < 1e-34. W grows with the number of cases and is not compared across the datasets (A-115).

## 5. Maps on the common prototype grid (task item 1)

Figures `intensity_maps_glmm_old_vs_new`, `intensity_maps_cml_old_vs_new` (each dataset on its own step-3 knots, model-based |z|), `intensity_maps_glmm_commonbasis_boot_old_vs_new` and `..._norep_boot_...` (common basis, shoe-bootstrap |z| with the level), `ratio_maps_commonbasis_shape_boot_old_vs_new` (shapes, model and data), `empirical_density_old_vs_new` and `..._norep_...` (the data without a model), `empirical_regions_old_vs_new` (section 5.1), `intensity_maps_asdrawn_old_vs_new` (step 4's levels), `ratio_maps_sensitivity_glmm_old_vs_new` and `..._cml_...` (the plan's sensitivities); tables `map_ratio_main_old_vs_new.csv`, `map_shares_old_vs_new.csv`, `map_ratio_summary_old_vs_new.csv`, `empirical_density_old_vs_new.csv`, `empirical_regions_old_vs_new.csv`, `bootstrap_map_se_old_vs_new.csv`.

**Common grid and scale.** Both datasets are drawn on the OLD prototype frame (307 x 395 px, the mask `data/freq_min_18.png`, x = `new_x`), the frame both step-4 maps use (A-006), with one colour scale per figure for the two density maps (from the lowest to the highest value of either; colour-vision-safe palettes checked with the dataviz validator). **Units:** each map is the model's spatial surface with the random effect at 0, scaled so that it reproduces its dataset's observed RAC total over all shoes' contact surfaces: RAC pixels per 1,000 contact pixels. The level then means the same thing for both datasets and does not depend on `MEAN_OFFSET` or on the exp(-sigma^2/2) factor of steps 4-6 (known issues K3 and K4, D-009). The maps as step 4 draws them differ in level by a constant factor 1.23 on top of the same shape (`intensity_maps_asdrawn`: NEW / OLD median 1.38 as drawn, 1.12 calibrated; the ratio of the two ratio maps lies in 1.2331-1.2347).

**Level and shape** (review fix A-133). A calibrated map is the product of a level (the dataset's overall RAC density) and a shape (the density relative to that level). Its uncertainty has both parts. The first version's bootstrap held each dataset's RAC total fixed when it recalibrated a draw, which leaves out the level's sampling error (a shoe-bootstrap SD of the log overall density of 0.056 OLD, 0.037 NEW, 0.040 NEW without reprints; the shape's SD at the median pixel is 0.069 and 0.050). Now:

- **absolute densities** (level and shape): every draw recalibrated on its own resampled shoes (their rows and their RAC total). The SD of the log density grows 1.31-fold (OLD) and 1.24-fold (NEW) at the median pixel (p5-p95 1.07-1.54 and 1.06-1.47); the bootstrap SE is then 1.77 (OLD) and 1.50 (NEW) times the model-based one;
- **shapes**: each map divided by its dataset's observed RAC density, each draw by its own resampled one. Its SD equals that of the fixed-total version to within 0.8% everywhere, so the first version's SDs were right for shapes, not for absolute densities. The bootstrap SE of the shape is 1.33 (OLD) and 1.22 (NEW) times the model-based one at the median pixel (p95 1.55 and 1.35).

The model-based SEs of the main figures hold the RAC total fixed too and assume RACs independent given the shoe (K9), so their |z| contours enclose too much; they are drawn for orientation only.

| NEW / OLD over the prototype (common basis unless noted) | p5 | median | p95 | outside 0.8-1.25 |
|---|---|---|---|---|
| GLMM, own knots (main figures) | 0.85 | 1.12 | 1.49 | 28% |
| GLMM, common basis | 0.84 | 1.11 | 1.44 | 25% |
| GLMM, common basis, NEW without reprints | 0.80 | 1.06 | 1.37 | 20% |
| CML, own knots | 0.85 | 1.12 | 1.50 | 28% |

**How much of the prototype differs** (`map_shares_old_vs_new.csv`; pointwise |z| > 1.96, not adjusted for multiplicity; "away from the pinned edges" leaves out the 6.8% of the prototype within 0.03 units of OLD's K8-pinned left and heel edges):

| quantity, variance | NEW (all): higher / lower | away from the pinned edges | NEW without reprints: higher / lower | away from the pinned edges |
|---|---|---|---|---|
| **absolute density, shoe bootstrap with the level** | **21.5% / 3.9%** | **16.0% / 4.2%** | **14.2% / 6.6%** | **8.7% / 7.1%** |
| absolute density, shoe bootstrap, RAC total fixed (first version, superseded) | 27.7% / 5.4% | 22.4% / 5.8% | 19.7% / 11.5% | 14.0% / 12.4% |
| absolute density, model-based (RAC total fixed, K9) | 36.2% / 8.0% | 31.6% / 8.6% | 26.9% / 15.9% | 21.6% / 17.1% |
| **shape: each map / its observed density, shoe bootstrap** | **20.4% / 12.3%** | **14.9% / 13.2%** | **19.2% / 12.1%** | **13.5% / 13.0%** |
| shape: each map / its mean over the prototype, shoe bootstrap | 17.1% / 15.4% | 11.5% / 16.5% | 15.6% / 15.9% | 9.9% / 17.0% |

Of the pixels where NEW's absolute density is significantly higher, about 30% lie in the pinned band (6.8% of the prototype), where the step-3 surfaces are pinned to their intercepts (K8) and the difference is not data. How much of the prototype counts as "higher" or "lower" as a shape depends on the reference the shapes are normalised to (each dataset's average density per contact pixel, or the map's mean over the prototype); the places do not.

**What the maps show.** Both datasets share the main relief: the highest RAC density in the forefoot and at the heel, lower at the toe tip, at the back of the heel and along the left edge. OLD's highest point is the forefoot centre-left (new_x about -0.05, y about 0.3), NEW's are the right forefoot edge, the centre of the midfoot and the left heel pad. On the common basis with bootstrap SEs that include the level, the significant regions are: NEW lower in the forefoot centre-left (an oval around new_x -0.07, y 0.2-0.35; without the reprints also a small patch right of centre), NEW higher over the lower heel (from about y -0.25 to the heel edge), a strip along the left edge, mostly inside the pinned band (not data), and, with all NEW shoes only, a small patch at the right toe edge. As shapes, NEW is relatively lower over most of the central forefoot (new_x -0.12 to 0.08, y 0.12-0.38) and relatively higher at the heel bottom. **Only part of this is in the data** (section 5.1): the heel-bottom excess and the forefoot-centre deficit (as a shape) are; an excess along the forefoot edges, at the toe and along the right midfoot edge is not: there the GLMM's ratio comes from its spline at sparse edges (up to about 2.1 at the right toe edge), while the region's data give ratios of 1.01-1.19 with intervals that contain 1. The empirical maps (`empirical_density`: the RAC pixels over the contact pixels the controls stand for, in a 21 x 21-pixel box, without a model) agree with the model ratio only moderately (median 1.06, p5 0.73, p95 1.52; correlation 0.46 of the log ratios over the supported prototype, 0.51 without the reprints). They show two sharp y bands that the step-3 surfaces smooth away: NEW much higher at the top of the midfoot (y about -0.05 to 0.05) and much lower at the heel front (y about -0.12 to -0.18, the band of plan F78-F79, where many NEW "group A" soles print without RACs).

### 5.1 The data by region (review fix A-134)

`empirical_regions_old_vs_new.csv`; figure `empirical_regions_old_vs_new`. The RAC density of a region = its RAC pixels over the contact pixels its rows stand for (cases 1, each control (px - n) / 100 of its shoe, as in the calibration), NEW / OLD; 95% intervals from a whole-shoe bootstrap (each dataset resampled by shoe, independently; 2,000 draws); "shape" = each region's density divided by its dataset's overall density (a level difference cancels); "GLMM" = the ratio the common-basis GLMM maps imply for the same region (its model-expected RAC pixels over its contact pixels, with each dataset's own contact pixels). `rel` = new_x / distance_shape, the position across the prototype's half-width (-1 the left edge, 1 the right edge). The regions were chosen after looking at the maps (the edges to check the first version's claims), so the intervals are descriptive, not confirmatory, and not adjusted for multiplicity.

| region (NEW all / OLD) | RAC px OLD / NEW | absolute | shape | GLMM |
|---|---|---|---|---|
| the whole standardized shoe | 13,249 / 19,990 | 1.06 [0.93, 1.21] | 1 | 1.06 |
| forefoot centre (-0.09 < new_x < -0.01, 0.22 < y < 0.38) | 804 / 1,001 | 0.88 [0.73, 1.05] | **0.82 [0.72, 0.94]** | 0.85 |
| forefoot right (new_x > 0.12, y > 0.15) | 945 / 1,384 | 1.06 [0.89, 1.27] | 1.00 [0.88, 1.12] | 1.04 |
| forefoot left (new_x < -0.13, y > 0.15) | 370 / 531 | 1.03 [0.84, 1.26] | 0.97 [0.81, 1.15] | 1.10 |
| forefoot right rim, outer 15% (rel > 0.85, 0.15 < y < 0.42) | 166 / 294 | 1.12 [0.86, 1.46] | 1.05 [0.82, 1.34] | 1.12 |
| forefoot left rim, outer 15% (rel < -0.85) | 32 / 25 | 0.74 [0.38, 1.44] | 0.69 [0.35, 1.34] | 1.23 |
| forefoot right rim, outer 25% (rel > 0.75) | 462 / 758 | 1.13 [0.93, 1.39] | 1.07 [0.90, 1.26] | 1.10 |
| forefoot left rim, outer 25% (rel < -0.75) | 250 / 399 | 1.18 [0.93, 1.53] | 1.11 [0.90, 1.38] | 1.16 |
| toe tip (y >= 0.42) | 459 / 690 | 1.04 [0.81, 1.35] | 0.98 [0.80, 1.20] | 1.03 |
| right toe (y >= 0.38, new_x > 0) | 443 / 649 | 1.01 [0.81, 1.30] | 0.95 [0.79, 1.15] | 0.97 |
| midfoot-top band (-0.05 < y < 0.05) | 1,023 / 1,711 | **1.32 [1.10, 1.61]** | **1.25 [1.10, 1.42]** | 1.10 |
| midfoot right edge (rel > 0.75, -0.12 < y < 0.15) | 518 / 898 | 1.19 [0.98, 1.47] | 1.12 [0.96, 1.32] | 1.15 |
| heel-front band (-0.18 < y < -0.12) | 308 / 271 | **0.63 [0.45, 0.90]** | **0.59 [0.44, 0.83]** | 1.11 |
| heel bottom (y < -0.35) | 1,481 / 2,828 | **1.23 [1.05, 1.45]** | **1.15 [1.05, 1.28]** | 1.30 |
| heel bottom, inner (-0.46 < y < -0.35) | 1,296 / 2,270 | **1.19 [1.01, 1.41]** | **1.12 [1.01, 1.25]** | 1.31 |
| heel bottom edge (y <= -0.46) | 185 / 558 | **1.52 [1.18, 2.02]** | **1.44 [1.14, 1.81]** | 1.41 |

Without the reprints (NEW 542 shoes): whole shoe 1.005 [0.88, 1.15]; forefoot centre 0.84 [0.70, 1.02], shape **0.84 [0.73, 0.97]**; midfoot-top band **1.24 [1.03, 1.49]**, shape **1.23 [1.08, 1.40]**; heel-front band **0.66 [0.47, 0.94]**, shape **0.65 [0.48, 0.90]**; heel bottom 1.16 [0.99, 1.37], shape **1.15 [1.05, 1.28]**; heel bottom edge **1.49 [1.14, 1.98]**; every rim, toe and midfoot-edge interval contains 1.

**Reading.** The raw data support four regional differences: NEW higher at the heel bottom (strongest at its edge) and in the midfoot-top band, lower in the heel-front band and, relative to its own level, in the forefoot centre. They do not support an excess along the forefoot edges, at the toe or along the right midfoot edge. The GLMM implies ratios close to the data where its basis can follow them (the forefoot centre, the heel bottom, the rims and the toe as region averages) and misses the two bands (heel-front band 1.11 against 0.63 in the data, midfoot-top band 1.10 against 1.32): the step-3 basis is too coarse in y there (plan F84).

**Sensitivities** (`map_ratio_summary_old_vs_new.csv`; GLMM unless noted; the |z| columns there are model-based):

| variant | NEW / OLD p5 | median | p95 | outside 0.8-1.25 |
|---|---|---|---|---|
| own step-3 knots (main) | 0.85 | 1.12 | 1.49 | 28% |
| common basis (NEW on OLD's knots) | 0.84 | 1.11 | 1.44 | 25% |
| full tensor (main effects + interaction; removes K8) | 0.84 | 1.10 | 1.60 | 31% |
| finer y knots, each its own (nAGQ 0) | 0.74 | 1.07 | 1.88 | 39% |
| finer y knots, common (OLD's) (nAGQ 0) | 0.75 | 1.08 | 1.92 | 39% |
| NEW without the reprinted shoes | 0.80 | 1.06 | 1.37 | 20% |
| NEW without group A (group B only; post hoc, descriptive) | 0.65 | 0.86 | 1.03 | 27% |

- **The basis matters at the edges and in y, not for the main pattern.** The forefoot-centre deficit and the heel-bottom excess are there in every variant. The full tensor changes the edges (K8 pins the left edge of the step-3 surfaces to the intercept): on its own dataset the full-tensor CML map is 0.86-1.18 (OLD) and 0.89-1.22 (NEW) times the step-3 map over the central 90% of the prototype, and 0.48-1.99 and 0.47-2.26 at the extremes, all at the edges. The finer y basis (plan F84) reproduces the two y bands of the empirical maps, so the step-3 maps understate the OLD-NEW difference in y and the finer basis is closer to the data; its corners and toe edge, where data are sparse, extrapolate (ratios beyond 2, drawn at the end colours).
- **nAGQ 0 is adequate for the finer-y maps:** on the step-3 basis the nAGQ 0 and nAGQ 1 maps agree within 0.997-1.009 (OLD) and 0.997-1.007 (NEW), sigma^2 0.9606 vs 0.9598 and 0.7579 vs 0.7556 (`nagq0_check_old_vs_new.csv`).
- **Without the reprints** the shape differences stay (median ratio 1.06; the forefoot deficit as clear or clearer, section 5.1).
- **Group B only** (the post-hoc split of plan F79; descriptive only, A-120): group B's RAC density is lower overall (median ratio 0.86) and its forefoot lower still; its heel front shows no deficit, which matches plan F79's band data (group B 1.01 of its own density there, group A 0.24).
- The CML sensitivity figure has no finer-y panels: the exact CMLs on the finer y basis need about 3.5 GB each, and all five attempts were killed (exit 137, out of memory) while other jobs ran (section 9).

## 6. Confidence intervals at the cuts (task item 4)

Figures `ci_cuts_old_vs_new` (own knots, GLMM line and model-based band, CML dashed), `ci_cuts_commonbasis_boot_old_vs_new` (common basis, absolute density, shoe-bootstrap bands with the level, with NEW without reprints), `ci_cuts_commonbasis_shape_boot_old_vs_new` (the same as shapes: each density over its dataset's observed density, bootstrap bands shaded, model-based dashed), `ci_cuts_sensitivity_old_vs_new` (CML, every variant); tables `ci_cuts_old_vs_new.csv`, `ci_cuts_summary_old_vs_new.csv`, `ci_cuts_bootstrap_old_vs_new.csv`, `ci_cuts_bootstrap_summary_old_vs_new.csv`. Cuts at the prototype rows 110 (y = 0.292, forefoot), 190 (0.025, midfoot) and 250 (-0.175, heel front), as in step 5. Columns of a cut where the NEW band lies entirely above / below the OLD band (pointwise |z| > 1.96 in brackets where given):

| cut | own knots, model-based | common basis, model-based | common basis, bootstrap, absolute (with the level) | common basis, bootstrap, shape | median NEW / OLD, absolute / shape |
|---|---|---|---|---|---|
| 110 forefoot | 11% / 20% | 11% / 23% | 6% / 0% (z: 9% / 16%) | 7% / 24% (z: 9% / 39%) | 0.97 / 0.91 |
| 190 midfoot | 4% / 0% | 6% / 0% | 0% / 0% (z: 3% / 0%) | 0% / 0% (z: 4% / 0%) | 1.11 / 1.05 |
| 250 heel front | 32% / 0% | 3% / 0% | 0% / 0% (z: 1% / 0%) | 0% / 0% (z: 1% / 0%) | 1.10 / 1.04 |

- **At the forefoot cut, at OLD's peak** (new_x = -0.052): OLD has 4.77 RAC px per 1,000 contact px [4.17, 5.51], NEW 3.92 [3.55, 4.29] and NEW without reprints 3.70 [3.36, 4.11] (bootstrap with the level). The bands overlap, but the pointwise difference is significant (z -2.3 for NEW, -2.8 without the reprints; two 95% bands of independent estimates may overlap at a difference that is significant at 5%). As shapes the peak is clearly lower on NEW: relative density OLD 1.47 [1.33, 1.63], NEW 1.14 [1.05, 1.24] (z -3.7), without the reprints 1.14 [1.04, 1.24] (z -3.6). The first version's "disjoint also under the bootstrap" (bands [4.30, 5.29] and [3.60, 4.26]) held the RAC totals fixed and is withdrawn.
- The NEW-above columns at row 110 (6%) are at the left edge (new_x -0.19 to -0.17), inside the K8-pinned band (dotted): not data. The NEW-below columns as shapes span new_x -0.08 to 0.01, the forefoot centre.
- The heel-front difference of the main figure (NEW above OLD on 32% of the columns) vanishes on the common basis: NEW's own step-3 y knots are too coarse there (plan F84; NEW's cut 250 lies about a quarter above its own data, F77).
- Bootstrap bands of the shape are 1.30-1.34 (OLD) and 1.20-1.23 (NEW) times as wide as the model-based bands at the median column; the level widens the absolute bands by another 1.26-1.35 (OLD) and 1.13-1.25 (NEW).
- Without the reprints NEW's forefoot cut drops further below OLD's (absolute bands disjoint on 10% of the columns, new_x -0.06 to -0.02, pointwise z < -1.96 on 27%; as shapes 20% and 39%).

## 7. Naomi's 14 areas: within and between (task item 5)

`areas14_old_vs_new.csv` (per fit and area, with model-based and, where they exist, bootstrap intervals), `areas14_summary_old_vs_new.csv` (per fit and interval method); figure `areas14_old_vs_new` (the full-tensor maps with bootstrap intervals). The 2022 rules (Naomi's `Organizing data to include subsets (larger areas).R`, lines 28-117, transcribed and checked against a port of her loops on 20,003 points; identical to T7's `naomi_area()` on 200,008 points) are applied on the prototype to (-new_x, y): the step-1 frame mirrors x (plan F7). Densities: the calibrated maps (the ratios are scale-free, so the level does not enter). Intervals: 95% of 1,000 shoe-bootstrap draws where a fit has them (the step-3 OLD fit, NEW on the common basis with and without the reprints, and the two full tensors, whose bootstraps were added by the review fixes: 795 and 1,071 s, 0 failed draws); otherwise of 1,000 draws from N(beta, V) (model-based V; the bootstrap widens the intervals, e.g. OLD between [1.67, 1.98] model-based, [1.63, 2.09] bootstrap).

| basis | fit | between areas: highest / lowest area mean | within one area: largest p90 / p10 | largest max / min | areas with p90 / p10 >= between |
|---|---|---|---|---|---|
| step-3 (committed) | OLD | 1.79 [1.63, 2.09] (13 / 1) | 2.63 [2.33, 3.44] (area 6) | 6.32 | 6 of 14 |
| step-3 (committed) | NEW, own knots | 1.58 [1.51, 1.72] (3 / 5), model-based | 2.64 [2.22, 3.21] (5), model-based | 5.30 | 3 |
| step-3, common basis | NEW on OLD's knots | 1.55 [1.46, 1.73] (4 / 5) | 2.74 [2.24, 3.42] (5) | 5.47 | 5 |
| step-3, common basis | NEW without reprints | 1.53 [1.45, 1.75] (4 / 12) | 2.82 [2.26, 3.64] (5) | 5.86 | 5 |
| **full tensor (no K8 pin)** | **OLD** | **1.96 [1.74, 2.32]** (13 / 1) | **2.90 [2.69, 4.10]** (6) | 6.48 | 4 |
| **full tensor (no K8 pin)** | **NEW** | **1.54 [1.48, 1.75]** (4 / 5) | **2.72 [2.41, 3.44]** (5) | 5.98 | 5 |
| finer y (nAGQ 0) | OLD | 1.90 [1.73, 2.24] (14 / 1), model-based | 4.48 [3.60, 6.58] (6), model-based | 26.55 | 6 |
| finer y (nAGQ 0) | NEW | 1.65 [1.52, 1.83] (4 / 1), model-based | 3.13 [2.73, 4.14] (5), model-based | 9.71 | 9 |
| step-3, CML | OLD / NEW | 1.78 / 1.57 | 2.63 / 2.64 | 6.27 / 5.31 | 6 / 3 |

(The interval of "largest p90 / p10" is that of the largest value over the 14 areas, draw by draw.)

**The magnitudes depend on the basis** (review fix A-135): between areas OLD 1.79-1.96 and NEW 1.54-1.65, within one area OLD 2.63-4.48 and NEW 2.64-3.13. The finer y basis has spurious maxima at the sparse data edge (plan F84), which inflate its within-area ratios (OLD 4.48, max / min 26.6). **Numbers to quote** (for Naomi's R&R answer to R1 point 1): the full tensor, which removes the K8 pin and keeps the step-3 knots: between areas OLD 1.96 [1.74, 2.32] and NEW 1.54 [1.48, 1.75]; within one area up to 2.90 [2.69, 4.10] (OLD, area 6) and 2.72 [2.41, 3.44] (NEW, area 5); with the range across the bases beside them.

**The meeting's numbers** (between 1.75x, within p90/p10 up to 2.4x in areas 1 and 5, max/min up to 5.5x) are reproduced exactly when the areas are applied to x without the mirror (1.753; 2.408 in areas 5 and 1; 5.515 in areas 6 and 5), which was the meeting script's error. With the mirror the committed OLD numbers become 1.79, 2.63 and 6.32. **The conclusion of the meeting holds on both datasets and on every basis:** the intensity varies as much inside one 2022 area as between the areas (3 to 9 of the 14 areas vary within at least as much as between), so a model that gives each area one intensity hides that variation. The per-area means differ between the datasets in the central forefoot (OLD's areas 13 and 14, between the parabolas, are the highest on the step-3 basis, 1.31 and 1.27 times the map mean; NEW's 0.96 and 1.12) and at the heel bottom (areas 1 and 10: OLD 0.73 and 0.75, NEW 0.90 and 0.94), which are the forefoot and heel-bottom differences of section 5.

## 8. Random (GLMM) vs CML (plan item (g))

`random_cml_old_vs_new.csv`; figure `random_cml_difference_old_vs_new`. (Random - CML) / CML of the calibrated maps: OLD -1.2% to +0.3% (p5 -0.51%, p95 +0.20%), NEW -1.7% to +0.6% (p5 -0.79%, p95 +0.39%). The two estimators give the same surface on both datasets; the largest differences are at the edges (the GLMM lower). So the GLMM's missing per-shoe offset (K2) does not move the shape. The Efron approximation of the CML is not interchangeable with the exact CML for maps: on the common basis it moves the CML map by 0.90-1.39 (OLD, p95 1.16) and 0.92-1.29 (NEW) (`efron_vs_exact_cml_old_vs_new.csv`), so Efron serves only for the robust SE ratios and the indicative robust Wald.

## 9. Limits and what was not done

- **Exact CMLs on the finer y basis:** not included. They need about 3.5 GB each (measured: 3.3 GB on the five largest NEW strata alone); all five attempts were killed (exit 137; the kernel log shows out-of-memory kills of 3.5 GB R processes) while the machine also ran T7's knits of about 10 GB, the last one started alone behind an 8 GB check (`docs/tests/T6-results.md` section 3.3). The finer-y sensitivity is present through the GLMMs (nAGQ 0, validated above). To complete: `bash tools/run_compare_fits.sh --jobs 1 fineY_old_cml fineY_new_cml fineYold_new_cml` on an idle machine, then knit the Rmd again.
- **GLMMs on the finer y basis with nAGQ 1:** not run to the end (stopped after 14 minutes to relieve memory; T5's attempt did not finish in 2 h 26 min). The Rmd uses them automatically if their records exist.
- **No bootstrap of the CML:** an exact CML refit took 2-16 minutes on the step-3 basis here, so 1,000 of them per dataset were not run; the cluster-robust Efron CML is the indicative robust CML test.
- **The reprint list** is T0's visual verdict list (D-012), not T3's pre-registered screen, which has not been run.
- **Shared soles:** with all NEW shoes the equality tests, the bootstrap |z| maps and the bootstrap bands treat OLD and NEW as independent, although 67 NEW shoes reprint OLD soles; they are conservative. The comparisons without the reprints are the ones whose assumptions hold.
- **Group A/B** is a post-hoc split chosen on NEW's heel-front data; it is descriptive only (A-120).
- **The regions of section 5.1** were chosen after looking at the maps; their intervals are descriptive and not adjusted for multiplicity.
- **K8** pins the left edge (new_x = -0.19) and the heel edge (y = -0.50) of every step-3 surface to its intercept; differences there are not data (the shares are also given without a 0.03-unit band along those edges).
- **The NEW full-tensor GLMM** stopped at its optimizer's limit with both nlminb (iteration limit) and bobyqa (evaluation limit), at the same point (log-likelihood -41523.50658 and -41523.50656, fixed effects within 0.003 SE); the Laplace deviance rebuilt from the data has a flat gradient there (theta -0.0015; every fixed effect at most 0.0135 deviance units per SE), checked in `tests/r/test_compare_old_new.R`. The record keeps the optimizer's code 1.
- **Profile intervals of sigma^2** hold the spatial coefficients at their estimates (an approximation; the spatial coefficients hardly depend on sigma, F35) and assume independence given the shoe level.
- **Pointwise |z| contours** are not adjusted for multiplicity.

## 10. Figures looked at

Every figure was opened and read (PNG copies in `docs/qa/T6/`; the ones the review fixes added or changed were looked at again on 2026-11-07 after the fixes):

| figure | what it shows |
|---|---|
| `data_overview` | ECDFs of RACs per shoe (nearly the same), contact px per shoe (NEW shifted left by about 12%), RAC density per shoe (NEW shifted right), and RAC type shares (type 1 43% NEW vs 24% OLD; types 4 and 6 rarer on NEW); small shares labelled with one decimal |
| `contours_step2` | QA ECDFs on top (contour length slightly higher on NEW, tightness and snake gap the same, coverage at 1 for almost every shoe), step-2 densities below (distance to the contour, new_x, y; NEW's cases peak more strongly at the heel pads, y about -0.28) |
| `intensity_maps_glmm`, `intensity_maps_cml` | the two calibrated maps on one scale, the difference and the ratio with model-based \|z\| contours, now labelled "model-based \|z\| = 1.96 (too narrow)" and explained in the note; GLMM and CML look identical; the contours enclose large areas (forefoot centre-left lower; the lower heel, the left edge, the right forefoot and right toe edges higher) |
| `intensity_maps_glmm_commonbasis_boot`, `..._norep_boot` | the same on the common basis with bootstrap \|z\| that include the level: the significant regions shrink to an oval in the forefoot centre-left (NEW lower), the lower heel (NEW higher), a strip along the left edge inside the dotted pinned band, and (all shoes only) a small patch at the right toe edge; without the reprints the heel region is smaller and a small "lower" patch appears right of the forefoot centre |
| `ratio_maps_commonbasis_shape_boot` | the shape ratio of the GLMM (all, without reprints) with bootstrap \|z\| beside the empirical shape ratio: the GLMM's relatively-lower region covers most of the central forefoot, its relatively-higher region the heel bottom; the data show the forefoot centre lower, the heel bottom higher, and the two y bands (midfoot top red, heel front dark blue) that the GLMM does not have; red patches at the toe rims in the data are small and noisy |
| `empirical_density`, `..._norep` | the raw densities: both show the forefoot and heel highs and the arch low; NEW has the sharp midfoot-top high and heel-front low; the empirical ratio has the same forefoot and heel pattern as the model ratio plus the two y bands, and no excess at the right toe edge where the GLMM ratio is darkest red |
| `empirical_regions` | the regional ratios with bootstrap intervals and the GLMM's ratios as open diamonds, absolute and as shape: the heel bottom (strongest at its edge) and the midfoot-top band clearly above 1, the heel-front band clearly below, the forefoot centre below as shape; every rim, toe and midfoot-edge interval crosses 1; the GLMM diamonds sit far from the data in the two bands |
| `intensity_maps_asdrawn` | step 4's maps: the same shapes, NEW about 1.36 times higher as drawn (1.10 calibrated) |
| `ratio_maps_sensitivity_glmm`, `..._cml` | the ratio under each variant, with the empirical ratio as the last panel; the finer-y panels (GLMM) reproduce the empirical y bands; the CML figure notes the missing finer-y fits |
| `ci_cuts`, `ci_cuts_sensitivity` | the three cuts on own knots and under every CML variant; the K8 left edge dotted; CML dashed lines coincide with the GLMM lines |
| `ci_cuts_commonbasis_boot` | absolute densities with bootstrap bands that include the level: at row 110 OLD's peak (4.77) lies above NEW (3.92) but the bands touch; rows 190 and 250 overlap everywhere |
| `ci_cuts_commonbasis_shape_boot` | the cuts as relative densities (1 = the dataset's average) with bootstrap bands and model-based dashed bands: at row 110 OLD's relative peak (1.47) is clearly above NEW's (1.14) over new_x -0.09 to -0.02; elsewhere the bands overlap; the caption gives the three observed densities (3.247, 3.448, 3.261) |
| `areas14` | the 14 areas on the full-tensor maps, the area means and the within-area p90 / p10 with bootstrap intervals, OLD and NEW side by side; OLD's heel-bottom areas 1 and 10 lowest (0.65 and 0.75 of the map mean) and the central forefoot areas 13, 14 and 11 highest (1.22-1.27); NEW's area means closer together (0.80-1.23); the widest within-area intervals in OLD areas 1 and 6 |
| `random_cml_difference` | both datasets within -1.7% to +0.6%, the GLMM lower only at the edges |
| `fixef_zdiff` | z of each spatial coefficient (common basis) for NEW (all), without reprints and group B; `x3:y3` stands out in all three |
| `sigma2` | the point estimates and profile intervals of section 3; OLD's and NEW's offset intervals do not overlap |

## Decisions

A-122 to A-132 (the T6 run: names, calibrated maps, the PIRLS bootstrap, nAGQ 0, the reprint list, frozen script copies, the mirrored areas, the sigma^2 profiles, bobyqa, the optional finer-y CMLs, the empirical maps) and A-133 to A-138 (the review fixes: level and shape, the model-free regions, the area ratios by basis, the sigma^2 estimators, the RAC-level type evidence, the primary equality test) in `docs/decisions.md`.
