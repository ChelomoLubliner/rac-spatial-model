# Decision register

Every decision that shapes the new-shoes work, with who took it and why. IDs: `D-` = decided or requested by a person (Micha, Shlomo, Naomi), `A-` = agent call (taken by an agent while the team was away; each one says how to confirm or reverse it). Statuses: `accepted`, `provisional` (an agent call waiting for evidence from a named task), `proposed` (needs a person), `open`.

Sources: `docs/2026-11-05-meeting-micha-new-shoes.md` (sections cited as "meeting 4", etc.), `docs/plans/2026-11-05-new-shoes-pipeline.md` ("plan F6" = fact F6 of the plan), `docs/qa/T0/probes/*.out`.

Append new decisions at the end of the right section; never rewrite an old entry: add a new one that supersedes it.

---

## Decisions by people (meeting of 2026-11-05)

### D-001 Run the complete pipeline on the new dataset
- **Date:** 2026-11-05. **Who:** Micha (request). **Status:** accepted.
- **Decision:** run the complete pipeline (snake contour, steps 1-6, old vs new comparison) on the 631 new shoes, in a new feature branch, with the same standardization as for the old dataset; the snake must be adapted to the new images.
- **Why:** Part 2 (validation) needs the new shoes standardized exactly like the old ones.
- **Source:** meeting 4, Part 1.

### D-002 Part 2 validation: per-shoe area probabilities
- **Date:** 2026-11-05. **Who:** Micha (request). **Status:** accepted.
- **Decision:** for each new shoe i and pixel j, S_ij = 1 on the contact surface, p_ij = the pixel probability from the logistic regression with the random effect set to 0; for each part k compute sum over j in k of p_ij S_ij; parts = Naomi's 14 areas or, if possible, a split into 10-20 cells; the shoes are standardized first; then compute the goodness of fit on the new file. "We don't need all of that" (Naomi's full option list).
- **Why:** a validation that matches how the results are used (probability of a RAC being in a region of a given shoe).
- **Source:** meeting 4, Part 2; Micha's email of Oct 29 (meeting 2).

### D-003 Normalize each shoe's expected counts to its observed total
- **Date:** 2026-11-05. **Who:** Shlomo ("ok do that"); proposed by Shlomo/Claude. **Status:** accepted by Shlomo; Micha to be told.
- **Decision:** E~_ik = n_i E_ik / sum_k' E_ik'.
- **Why:** with the random effect at 0 the raw sums are off in level, so a goodness-of-fit test would reject because of the level and not the spatial shape. After normalization the shoe effect cancels (approximately for the logit, since per-pixel probabilities are tiny), as in the 2022 corollary; the case-control offset and the sigma^2 scaling cancel too.
- **Source:** meeting 4 (proposal 1), meeting 9 question 1.

### D-004 Run both the pooled chi-square and a shoe bootstrap
- **Date:** 2026-11-05. **Who:** Shlomo ("yes you will do both"). **Status:** accepted.
- **Decision:** pooled Pearson chi-square over all 631 shoes (cells merged so that E >= 5, df = K - 1) and a bootstrap over whole shoes.
- **Why:** about 32 RACs per shoe is too few for a per-shoe test; resampling whole shoes keeps dependent RACs together; disagreement between the two tests is itself evidence of dependence (editor's independence demand).
- **Source:** meeting 4 (proposals 2-3), meeting 9 question 2. Exact definitions: plan section 9 and A-009.

### D-005 Areas and cells are defined on the standardized shoe (new_x)
- **Date:** 2026-11-05. **Who:** Micha. **Status:** accepted.
- **Decision:** the partition (Naomi's areas and the grid) is applied on `new_x`, not on raw x.
- **Source:** meeting 4 ("cells/areas are defined on the standardized shoe"), meeting 9 question 3.

### D-006 Compare with the 2022 regional model on equal terms, plus a log score
- **Date:** 2026-11-05. **Who:** proposed by Shlomo/Claude, agreed in principle by Shlomo. **Status:** accepted (in principle); Micha to be told.
- **Decision:** run the same test for the 2022 regional model on the new shoes; optionally a log score (average log-probability of each new RAC's location); do it for both partitions (Naomi's 14 areas on `new_x` and a 10-20 cell grid).
- **Why:** answers reviewer 1 points 1 (added value) and 6 (out-of-sample validation) together.
- **Source:** meeting 4 (proposals 4-5).

### D-007 Engineering requirements
- **Date:** 2026-11-05. **Who:** Shlomo. **Status:** accepted.
- **Decision:** (1) no collisions: every new-dataset file has a `new` folder and a `_new` suffix, old files keep their names; (2) exact reproducibility of the old outputs at every step, checked against a baseline taken before any change; (3) several subagents: implementers, reviewers, a statistics expert, an analyst, visualization, strong end-to-end tests; (4) compare old vs new at every stage; (5) first full result for Micha by about 2026-11-12; paper due 2026-12-04.
- **Source:** meeting 6.

### D-008 Refit the old GLMM with the per-shoe offset before 2026-12-04?
- **Date:** 2026-11-05. **Who:** team. **Status:** open.
- **Context:** the GLMM is fitted without the offset log(100 / pixels_i) (meeting 8, issue 1). Not urgent for Part 2 (it cancels after D-003).
- **Source:** meeting 9 question 4, meeting 10 question 4.

### D-009 exp(-sigma^2/2) or exp(+sigma^2/2)?
- **Date:** 2026-11-05. **Who:** Naomi (to be asked). **Status:** open.
- **Context:** `model_comparison_6.Rmd:125` (and Naomi's `pixel analysis.R:364`) multiply by exp(-sigma^2/2) = 0.62 while her comment says the lognormal expectation is exp(+sigma^2/2) = 1.62. Affects only the absolute level.
- **Source:** meeting 8 issue 2, meeting 9 question 5.

### D-010 Reference for "dependence affects the variance, not the estimate"
- **Date:** 2026-11-05. **Who:** proposed by Claude: Liang and Zeger (1986), GEE; Micha to confirm. **Status:** proposed.
- **Source:** meeting 9.

### D-011 Workflow rules for the autonomous run
- **Date:** 2026-11-05. **Who:** Shlomo (rules relayed to every task of the workflow). **Status:** accepted.
- **Decision:** dataset selected by `RAC_DATASET=old|new` (default old) in both languages; tests with stdlib `unittest` and plain `Rscript` (no package installs); manual Wald test because `car` is not installed (must equal 428.69 on old); `docs/progress/LOG.md`, this file and `docs/tests/<task>-results.md` kept current with real output only; raw data byte-identical; LF code, flake8 and shellcheck clean; long jobs in the background; look at every image and check every new shoe for stickers; never modify the thesis repo; full autonomy overnight with decisions recorded here.

### D-012 Are the two datasets disjoint? (the meeting's "no overlap" is unverified)
- **Date:** 2026-11-05. **Who:** Micha and Yoram (to be asked); raised by the T0 statistics reviewer, confirmed by the T0 fix pass. **Status:** open.
- **Context:** the meeting recorded the new dataset as "a different dataset from the 387 shoes (no overlap)" (meeting 3.2, 5). The data contradict this: 34 NEW shoes have RACs that coincide with one OLD shoe far beyond chance, 30 of them look like the same physical shoe in side-by-side images, and consecutive NEW pairs map onto consecutive OLD pairs (plan F25). Inside OLD, shoes 236/237 and 277/278 look like one pair printed twice (F26, K10).
- **Question for Micha and Yoram:** were some shoes printed (or collected) again for the second dataset? Is there a list linking the two numberings?
- **Until answered:** A-024 (the overlap screen and a primary Part 2 set without the reprints).
- **Evidence:** `docs/qa/T0/probes/t0_review.out` (R5, R6, R8), `t0_review_pairs.out`, `docs/qa/T0/compare/overlap_pairs/*.png`, `docs/qa/T0/old/pair_old_*.png`.

### D-013 Per-shoe quality rule for Part 2
- **Date:** 2026-11-05. **Who:** Micha (to confirm the agent call A-029). **Status:** proposed.
- **Context:** NEW has more faint or partial prints than OLD (plan F27: 135 NEW vs 55 OLD shoes below 0.7 of RACs on contact; NEW 112 has about 30 RACs on a heel that did not print). On such shoes S is not the surface where RACs can be observed, so a goodness-of-fit test would reject for data reasons.
- **Proposal:** A-029 (pre-registered in T3, from OLD numbers only), with and without the exclusion reported.

---

## Agent calls

### A-001 Keep the OLD prototype for `new_x` on both datasets
- **Date:** 2026-11-05. **Who:** agent call (Claude, in the meeting). **Status:** accepted as working rule; **tell Micha**.
- **Decision:** `new_x` of the new shoes is computed with `data/contour_prototype.png` (the old prototype), so `new_x` means the same thing for both datasets and the old-fitted model can be evaluated on the new shoes (Part 2).
- **Why:** a new prototype would define a different standardized coordinate and break the out-of-sample comparison.
- **Source:** meeting 7 ("Prototype for new_x").

### A-002 Cleaning masks are computed per dataset
- **Date:** 2026-11-05. **Who:** agent call (Claude, in the meeting). **Status:** accepted; thresholds provisional (A-014).
- **Decision:** the Python cleaning mask (snake-filled superposition, used before the snake) and the R stamp mask (`allcont >= t` + sweep, used for the contact surface S) are rebuilt from the new shoes themselves.
- **Why:** stamps and stickers sit at dataset-specific places; the new images have other dimensions (255 x 367).
- **Source:** meeting 7.

### A-003 One profile file read by both languages
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** `config/datasets.json` holds every per-dataset value and path; Python reads it with `json`, R with `jsonlite` (installed, 2.0.0) and coerces numbers with `as.numeric()`.
- **Why:** dimensions, skip lists and paths are shared by the Python and R halves; two copies would drift. Alternative rejected: separate `profiles.py` and `profiles.R` with a cross-language consistency test (more moving parts).

### A-004 Two-tier old baseline; regression runs in scratch copies
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** Tier A = files committed at `79247d8`; Tier B = the unmodified code re-run on this machine (T1). Every regression run happens in a copy of the working tree under the scratch directory, never in the real tree.
- **Why:** the committed GLMM and PDFs were produced on Windows with R 4.4.3 (plan F18, F20) and may not be bit-reproducible here; Tier B separates "the refactor changed something" from "the platform differs". Scratch copies make it impossible to overwrite a committed file during testing.

### A-005 Old outputs keep their committed line endings
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** provisional (T1 confirms that Linux R with these EOLs reproduces the committed bytes).
- **Decision:** the old profile writes `dataCC.csv`, `shoe_pixel_counts.csv`, `all_cont.csv` with `\r\n` and `dataCC_distance.csv`, `dataCC_distance_temp.csv` with `\n` (what is committed, plan F19); new CSVs use `\n`; the fixed-stride contour txt files always use `\r\n` (the R readers depend on a 2-byte separator).
- **Why:** the requirement is byte identity; the committed files got their EOLs from where they were produced (Windows R) and committed (the March commit kept CRLF). The 2026-03-16 "regeneration" of `dataCC.csv` changed only the EOL (plan F19).

### A-006 Maps, CI cuts and `distance_shape` use the prototype frame for both datasets
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** step 2 builds the prototype's coordinates with the prototype dimensions (307 x 395), and steps 4-6 evaluate the model on the 307 x 395 grid with `data/freq_min_18.png` as mask and the same cut rows (110, 190, 250) and crops, for both datasets.
- **Why:** the model lives on (`new_x`, y), the standardized coordinates defined by the old prototype (A-001); using the new image size would mismatch the 307 x 395 mask and the cut rows and make old and new maps incomparable.

### A-007 Naomi's 14 areas are evaluated at (-new_x, y)
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted (T7 test pins it).
- **Decision:** the area rules (Naomi, lines 28-117) are applied to x = -new_x.
- **Why:** the pipeline's x is the mirror of the x in `locations_data.csv` (corr -0.999941, plan F7), and Naomi's rules (x < 0 side, shifted parabolas) are written in the file's frame. The meeting's within-area ratios (meeting 3.1) were computed without the sign flip; they are close (the parabolas are almost symmetric) but should be recomputed in T7.

### A-008 Part 2 grid, pre-registered
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** provisional (Micha to confirm; answers meeting open question 2).
- **Decision:** K = 15 cells = 5 y-bands (quintiles of y over old contact pixels) x 3 `new_x` bands (terciles of old contact pixels inside each band); sensitivities K = 10 (5 x 2) and K = 20 (5 x 4); cut points frozen from old data before any new data enter T7.
- **Why:** equal old contact surface per cell balances the expected counts (about 1,300 new RACs per cell); defining the cells on old data only keeps the test honest.

### A-009 Bootstrap definition
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted (statistics expert reviews in T7).
- **Decision:** centered shoe bootstrap of the pooled X^2: B = 2000, seed 20261105, resample the 631 shoes with replacement, statistic computed on the per-shoe residual vectors minus the observed discrepancy; p_boot = (1 + #{X^2* >= X^2}) / (B + 1); report the dispersion ratio mean(X^2*) / (K' - 1).
- **Why:** gives the null distribution of X^2 under the observed within-shoe dependence without assuming independent RACs (plan section 9).

### A-010 2022 regional model refit on the old shoes
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** provisional (answers meeting open question 3; Micha/Naomi may prefer the published values).
- **Decision:** theta is refit on the old shoes with the same partition on `new_x`: Poisson GLM N_ik ~ shoe + area + offset(log S_ik) (equal to the conditional multinomial MLE of 2022); sensitivity with Naomi's areas on raw x.
- **Why:** the published theta belong to areas on raw x, so they cannot be used with areas on `new_x` (D-005).

### A-011 Part 2 counts every RAC
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** O_ik counts RACs (duplicates in one pixel counted: 23 such pixels in the new data); the binary pixel indicator is a sensitivity analysis.
- **Why:** each RAC is one draw of the multinomial; duplicates are rare (plan F2), so the choice hardly matters.

### A-012 Knots: own knots for the new fit, common basis for comparisons
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** step 3 on the new data keeps the pipeline's quantile knots of the new data (Part 1 = the pipeline as is); T6 adds a refit of the new data with the old knots and boundary knots, used for coefficient comparisons and the equality Wald test.
- **Why:** coefficients on different bases are not comparable; maps on the prototype frame are.

### A-013 Pixel-mapping decision rule for the new images
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** provisional (T3 applies it after the statistics expert signs it off).
- **Decision:** keep the generalized legacy mapping (W = 255, H = 367, `rel_col_shoe` 150, `rel_row_shoe` 300, 1 px = 1/300) if (i) on old data the on-contact optimum has scale 300, x mirrored, y not flipped; (ii) on new data the optimum scale is in [294, 306] on both axes with the same mirroring; (iii) the new optimum's offset from the generalized legacy mapping equals the old optimum's offset from the legacy mapping within 1 px. Otherwise use calibrated parameters.
- **Why:** "same standardization as the old dataset" (D-001). T0 numbers satisfy all three (plan F6): old optimum 0.8816 at scale 300 and -0.5 px vs legacy 0.8479; new optimum 0.8352 at (298, 300) and -0.5 px vs generalized legacy 0.8078; the 2023 COL/ROW equal the generalized legacy mapping (plan F5).

### A-014 Provisional cleaning thresholds
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** provisional (T3 for R, T4 for Python; answers meeting open question 1).
- **Decision:** proportional thresholds as defaults: Python superposition 29 (18 x 631/387 = 29.3) and R stamp mask 13 (8 x 631/387 = 13.04), with the stamp-sweep bound set to `col_shoe` = 255 for new (the legacy bound 300 crashes, plan F13).
- **Why:** the same relative frequency as the thresholds the user chose by eye on the old shoes; T0 shows >= 13, >= 18 and >= 29 all give one main component on the new data (plan F12). Final choice by the pre-registered criteria of the plan (T3 step 4, T4 step 3) and by looking at the masks.

### A-015 The old Python flip of shoe 9 stays off
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted; known issue K1 to report.
- **Decision:** the old profile reproduces the committed contour, in which shoe 9 was not flipped (`create_files_shoes.py:26-30` is dead code), while R flips shoe 9's contact. Not fixed for the old analysis.
- **Why:** exact old regression (D-007); the effect is one shoe with 2 RACs, both off-contact (plan F9). Evidence: 386/386 committed contour records equal the thesis run of 2025-11-13, whose `list_matrices[8]` is the unflipped shoe 9.

### A-016 Vectorized step-2 distances only after a byte-identity proof
- **Date:** 2026-11-05. **Who:** agent call (T0 architect), within D-011. **Status:** accepted.
- **Decision:** T5 may replace the double loop; it becomes the default only after the old outputs are byte-identical; the legacy loop stays available (`RAC_DISTANCE_IMPL=legacy`).
- **Why:** Part 2 needs `new_x` for millions of pixels; the float neighbourhood `abs(dy) < 0.01` admits 160 of 392 three-row pairs (plan F14), so only an exact-semantics implementation is acceptable.

### A-017 Plotly HTML outputs off by default
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** the per-shoe plotly HTML files (`extreme_values/`, `snake_rac_html/`) are written only with `--html`.
- **Why:** no output uses them; they took 1.8 GB each for the old shoes.

### A-018 Index conventions
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** image file names keep the legacy 0-based index for both datasets (`im0.png` is shoe 1); shoe ids are 1-based everywhere else (JSON, CSV, QA labels).

### A-019 New snake initialization starts from the 2023 values
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** provisional (T4).
- **Decision:** the first new run uses the init ellipse already in the thesis code (center row 185, col 128; radii 162, 95); global adjustments come before any per-shoe override.
- **Why:** relative to the new superposition (rows 27-335, cols 74-196) it has the same margins as the old ellipse has to the old superposition (plan F16).

### A-020 Seeds
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** step 1 uses `set.seed(313)` for both datasets; the Part 2 bootstrap uses 20261105; test simulations use the seeds written in the plan.

### A-021 No silent old fallback for the new MEAN_OFFSET
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** when `processed_data/new/shoe_pixel_counts_new.csv` is missing, the new `MEAN_OFFSET` is `NA` with a warning; the old profile keeps the legacy fallback `log(100 / 10615)`.
- **Why:** the fallback is Naomi's old-data average; using it for the new shoes would be silently wrong.

### A-022 Port the Python contour code into this repo
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** accepted.
- **Decision:** the thesis `contour_algorithm/` (HEAD `109f30a`) is ported to `contour_algorithm/` in this repo (LF, flake8-clean, profile-driven); old intermediates go to `images/`, new ones to `images_new/` (both gitignored).
- **Why:** the thesis repo must not be modified, and the legacy code has fixed paths that would collide (`FOLDER = '../images/'`, the fixed contour output path).

### A-023 Restore the thesis repo after an earlier probe
- **Date:** 2026-11-05. **Who:** agent call (T0 architect). **Status:** done.
- **Decision:** removed `contour_algorithm/__pycache__/extreme_values_x_y.cpython-312.pyc` from the thesis repo. It was created at 18:36 by the interrupted first T0 run (it imported a thesis module without `-B`). It is gitignored, no tracked file changed; the other `.pyc` files there date from 2025-12-24 and were left alone. From now on Python runs with `-B` and legacy code runs from scratch copies.

### A-024 Overlap screen before Part 2; primary set without reprints of OLD shoes
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the statistics reviewer's critical finding). **Status:** provisional (until D-012 is answered; T3 applies it).
- **Decision:** (1) the meeting's "no overlap" is treated as **unverified** (D-012); (2) T3 runs a pre-registered overlap screen of every NEW shoe against every OLD shoe (image correlation; symmetric RAC match with one rigid shift and with one shift per half; each statistic's threshold = max(0.30, its NEW-NEW null maximum); margin 0.15 over the second-best OLD shoe; plan T3 step 3b); (3) every candidate is judged visually (`same_shoe`, `uncertain`, `different_shoe`); (4) the primary Part 2 analysis excludes `same_shoe` and `uncertain`, with sensitivities "all 631" and "only `same_shoe` excluded"; (5) T6 comparisons are also run without them; (6) the list goes to Micha and Yoram.
- **Why:** on a reprinted shoe the OLD-fitted model has seen the same RACs, so the "out-of-sample" test would partly measure memory. The T0 screen found 34 candidates (1,309 NEW RACs, 6.5%), 30 likely the same shoe by eye (plan F25). A rigid-only rule under-counts because prints deform by 1-4 px between toe and heel (8 of the 26 rigid pairs), hence the second statistic.
- **Alternatives rejected:** trusting the meeting statement (contradicted by the data); excluding only the statistician's 16 (the all-OLD search and the two-half statistic find more; both are listed); an image-only screen (misses reprints whose prints differ, e.g. NEW 531 vs OLD 67, image rank 43).
- **Evidence:** `docs/qa/T0/probes/t0_review.out` R5-R8, `t0_review_pairs.out`, 36 pair images in `docs/qa/T0/compare/overlap_pairs/` (described in `docs/tests/T0-review-fixes-results.md`).

### A-025 Model comparison: the pixel log score is primary, the comparator is the real 2022 model
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass). **Status:** accepted as working rule; Micha to be told. **Supersedes:** the "Delta X^2 on the same partition" element of the D-006 implementation, and A-010 as the main comparator (A-010's new_x refit becomes a sensitivity).
- **Decision:** the primary comparison between the continuous model and the regional model is the pixel-level log score (RAC- and shoe-weighted, shoe-bootstrap intervals); the regional comparator is the 2022 model itself: theta on Naomi's 14 areas evaluated on raw x (`naomi_area(-x, y)`), fitted on the 386 OLD shoes; cell-level X^2 comparisons are made on the grid, on which neither model was fitted; on Naomi's areas the comparison is labelled as tilted; an in-sample regional X^2 on its fitting partition is reported as "identically 0 by construction", never as a fit.
- **Why:** a regional theta fitted on the test partition satisfies sum_i O_ik = sum_i E~R_ik exactly (Poisson score equations; T0 toy check: X^2 = 7e-24, plan F31), and a test on cell totals cannot reward the continuous model's resolution inside cells, which is the claimed added value (R1 point 1). The grid regional model is not the 2022 model.
- **Evidence:** `docs/qa/T0/probes/t0_review_R.out` S2; plan section 9.

### A-026 Dispersion is extra-multinomial variation; a within-shoe test addresses dependence
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass). **Status:** accepted (statistics expert implements it in T7). **Supersedes:** the rationale "disagreement between the two tests is itself evidence of dependence" in D-004 and A-009 (the decision to run both tests stands).
- **Decision:** phi > 1, or a pooled/bootstrap disagreement, is reported as extra-multinomial variation (within-shoe dependence **or** between-shoe heterogeneity of the spatial pattern), against its exact expectation under independent multinomials phi_0 = [K' - sum_k sum_i n_i pi_ik^2 / E_k] / (K' - 1) <= 1 from the same pi_ik. A within-shoe pair-count test (pairs within r px against the fitted model and against a heterogeneity-adjusted null; plan section 9) answers the editor's independence demand directly. T7's "clustered" Dirichlet simulation is relabelled heterogeneity, and a clumped-RAC simulation is added.
- **Why:** with one pattern per shoe the two mechanisms give the same cell counts (T0 simulation with the real NEW n_i: heterogeneity alone phi = 3.44, clumps alone phi = 1.84, independence with shoe-specific pi phi = 0.96 vs exact phi_0 = 0.968; plan F31); under independence phi <= 1, not "about 1". They differ in spatial scale, which the pair test uses.
- **Evidence:** `docs/qa/T0/probes/t0_review_R.out` S3.

### A-027 Known issue K8: the fitted surface is pinned to the intercept on two edges
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the statistics reviewer's finding). **Status:** accepted; Naomi and Micha to be told (paper limitation).
- **Decision:** record K8 (plan section 2); the statistics expert inspects the T5 maps and the T7 cell residuals near new_x = -0.1917 and y = -0.5017; T7 adds an OLD refit with the full tensor `ns(new_x) * ns(y)` (35 fixed effects) and reports whether the named primary results change. The OLD analysis is not changed (old regression).
- **Why:** `ns(new_x):ns(y)` has no main effects and both bases vanish at their left boundary knot, so eta = intercept = -2.271582 along both edges, while the opposite edges are free (T0: verified at 5 points per edge, rebuilt design matrix == `getME(X)`; plan F28).
- **Evidence:** `docs/qa/T0/probes/t0_review_R.out` S1.

### A-028 Robust variances for both models and both datasets (meeting 8.5)
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass). **Status:** accepted (T5, T6). **Answers:** meeting item 8.5, which no task carried before.
- **Decision:** T5 computes a shoe-bootstrap variance (B = 200, background, parallel, worker-independent seeds) for the GLMM and for the **exact** CML of each dataset, plus the Efron + `cluster(shoe)` CML sandwich as an indicative cross-check; it reports SE ratios, the all-24 Wald with the bootstrap V and the CI cuts with bootstrap bands (new files; the committed step-5 outputs are untouched). T6's equality Wald uses the bootstrap V as primary. The report cites the widening as evidence that dependence affects the variance.
- **Why:** every CI and Wald test assumes RACs independent given the shoe effect; an indicative Efron + `cluster(shoe)` refit gives robust/model SE ratios median 1.13, max 1.37, and W 394 -> 234 (df 24). `survival` refuses a robust variance for the exact method ("robust variance plus the exact method is not supported"), so the exact CML needs the bootstrap; an exact refit takes 189 s here (plan F29).
- **Alternatives rejected:** Efron + cluster only (its coefficients differ from the exact fit by up to 0.59, so it is a different estimator); a hand-coded sandwich from numerical per-stratum scores of the exact likelihood (possible, but slower to validate than the bootstrap; can be added if the bootstrap fails).
- **Evidence:** `docs/qa/T0/probes/t0_review_R.out` S4, `t0_review_cml.out`.

### A-029 Per-shoe quality rule for Part 2 (pre-registered in T3)
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass). **Status:** provisional (D-013, Micha).
- **Decision:** quality_flag = fail if (n >= 10 and the best on-contact rate under shifts up to 4 px is below the 5th percentile of the same statistic over OLD shoes with >= 10 RACs) or the census marks the print as partial with RACs on an unprinted part of the sole; the primary Part 2 analysis excludes failing shoes; sensitivities: no exclusion, and the raw-rate rule (rate < 0.584, the OLD p5). The rule is applied to OLD too, for the in-sample sensitivity. Per-shoe diagnostics (rate, best shift and its offset, best flip rate) go into `shoe_census_new.csv`.
- **Why:** partial prints make S the wrong surface (plan F27). The shifted rate targets "S does not cover the RACs" and does not penalize small misregistration, which barely moves RACs between cells (NEW 599: 0.22 -> 0.91 with a shift of 4 px or less; such shoes stay). The threshold comes from OLD only, so it is not tuned on NEW outcomes.
- **Evidence:** `docs/qa/T0/probes/t0_review.out` R3, `docs/qa/T0/new/low_contact_shoes_new.png`.

### A-030 Named primary analyses, effect sizes, CML as secondary, binomial calibration checks
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass). **Status:** accepted; Micha to be told.
- **Decision:** before any NEW Part 2 number: (1) goodness of fit = Naomi's 14 areas on (-new_x, y), continuous GLMM, bootstrap p, primary shoe set, with Cramer's w; (2) model comparison = RAC-weighted log-score difference continuous minus 2022 model with its shoe-bootstrap interval; (3) dependence = the within-shoe pair test at r = 4 px against the heterogeneity-adjusted null. Effect sizes: Cramer's w = sqrt(X^2 / N) and an RMSEA-type index. The OLD CML is a secondary model (relative intensity exp(eta)). Calibration of the tests in T7 is checked with binomial rejection rates at alpha 0.05 and 0.10, not with a KS test on discrete B = 200 p-values.
- **Why:** 2 partitions x 2 models x 2 tests x several sensitivities would otherwise invite choosing after the fact; with N about 20,000 p-values alone say little; the CML is shown in the paper and was not validated; KS on tied discrete p-values is weak.

### A-031 Excluded shoes: indexing and records
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the engineering reviewer's finding). **Status:** accepted (T2 implements, T4 may use).
- **Decision:** profile field `excluded_shoes` (1-based, default []); analysis shoes = all minus `shoes_without_racs` minus `excluded_shoes`, ascending; contour record k and `dataCC` code k are the k-th analysis shoe; step 1 writes the code-to-id table (`processed_data/shoe_codes.csv`, `processed_data/new/shoe_codes_new.csv`); excluded shoes stay in the dataset masks unless the exclusion decision says the image is invalid. `RecordMap` tests a synthetic case.
- **Why:** T4 allowed excluding a NEW shoe, but nothing defined how the contour records, the record-to-shoe mapping and the factor codes shift; a silent shift would misassign every later shoe.

### A-032 Corrections to A-013 (pixel-mapping rule)
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on both reviewers' findings). **Status:** accepted. **Supersedes:** the evidence numbers and rule (ii) of A-013.
- **Decision:** the OLD legacy rate is **0.8478** (exact R division form; the multiply form `(x + 0.25) * 300` gave 0.8479 and maps 2 RACs differently); F5 (2023 COL/ROW) is not calibration evidence; rule (ii) becomes "the shoe-bootstrap 95% interval of the NEW optimum scale (B = 200) contains 300 on both axes and the point optimum lies in [294, 306]"; the mean distance from each RAC to the nearest contact pixel is reported as a cross-check.
- **Why:** the T0 probe's label was inaccurate; the 2023 values only show that 2023 used the same formula; the on-contact criterion is flat in the x scale (NEW 296-302 within 0.0024) and sharp in y, so a fixed band sits at the limit of what it resolves, while a bootstrap interval states that resolution. The distance criterion was checked and is not sharper (plan F30), so it does not replace the rate.
- **Evidence:** `docs/qa/T0/probes/t0_probe.out` D, `t0_review.out` R1, R2.

### A-033 An empty RAC_DATASET means old, in both languages
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the engineering reviewer's finding). **Status:** accepted (T2).
- **Decision:** both readers map `""` to `old` explicitly before validating; `tests/r/test_profile.R` and `test_profiles.Env` test unset, set-but-empty, `new` and an invalid value.
- **Why:** `Sys.getenv("RAC_DATASET", "old")` and `os.environ.get("RAC_DATASET", "old")` both return `""` for a set-but-empty variable (checked, plan F33), which plan 4.1 would otherwise reject.

### A-034 Scratch directories: RAC_SCRATCH, mktemp, guarded deletion
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the engineering reviewer's finding). **Status:** accepted (T1 creates `tests/lib/scratch.sh`).
- **Decision:** scripts take their scratch root from `RAC_SCRATCH` with no default (`${RAC_SCRATCH:?}`), run with `set -euo pipefail`, create run folders with `mktemp -d "$RAC_SCRATCH/<name>_XXXXXX"`, and delete only that path after checking that it is non-empty and starts with `"$RAC_SCRATCH/"`.
- **Why:** the plan used an undefined `$SCRATCH` in scripts that clean up after themselves (an empty value would resolve paths under `/`), and parallel agents share one scratchpad, so timestamp-named folders can collide.

### A-035 Sentinel profile tests for dataset constants
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the engineering reviewer's finding). **Status:** accepted (T2).
- **Decision:** besides the extended literal grep (stamp threshold 8, superposition 18, snake init values, seed 313, 100 controls), behaviour tests run the real code on a tiny synthetic fixture with a profile of sentinel values (selected by the test-only `RAC_PROFILE_FILE`) and assert that each sentinel reaches the outputs.
- **Why:** a grep cannot prove that a value is used; a leftover OLD literal would silently apply OLD values to NEW data.

### A-036 Un-ignore only the new report
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the engineering reviewer's finding). **Status:** accepted (T8).
- **Decision:** T8 adds `!reports/new_shoes_report.html` to `.gitignore`, never `!reports/*.html`; the untracked March `reports/offset_changes_report.html` (2026-03-16, the user's file) stays ignored and untouched.
- **Why:** the broad pattern would expose the March report to an accidental commit.

### A-037 The sigma^2 comparison is confounded by the omitted offset
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the statistics reviewer's finding). **Status:** accepted (T6); informs D-008.
- **Decision:** T6 states that the GLMM sigma^2 absorbs var(log(100/px)) and compares offset-adjusted refits (offset log(100/(px - cases)), both datasets, new files) as the comparable sigma^2 pair; if D-008 leads to a refit for the paper, it uses log(100/(px - cases)).
- **Why:** var(log(100/px)) differs between the datasets (raw contact: OLD 0.095, NEW 0.121); controls are sampled only from pixels without RACs, so the exact case-control fraction is 100/(px - cases), up to 0.0335 away in log from 100/px (OLD shoe 385; plan F32).
- **Evidence:** `docs/qa/T0/probes/t0_review_R.out` S5.

### A-038 Log score weights and pair resampling
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the statistics reviewer's finding). **Status:** accepted (T7).
- **Decision:** the log score is reported weighted by RAC (primary) and by shoe; the shoe bootstrap has a sensitivity that resamples suspected pairs of one wearer together (consecutive ids with an image partner at r >= 0.95; the list is frozen in T3).
- **Why:** the top 10% of NEW shoes hold 31.8% of the RACs (plan F27); 13 of the 15 NEW shoes with an image partner at r >= 0.95 have consecutive ids and unrelated RACs, i.e. probably two shoes of one wearer, so shoes are not fully independent bootstrap units (F26).

### A-039 Correction to F14 (float window of step 2)
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass, on the engineering reviewer's finding). **Status:** accepted. **Supersedes:** the "160 of 392" statement in A-016's rationale.
- **Decision:** F14 now states both directions (OLD: 160 of 392 three-row pairs with the data row above the contour row, 161 below; NEW lattice: 152 and 151 of 364), from a real `write.csv`/`read.csv` round trip in the probe; the vectorizer must reproduce the float comparison in both directions; the OLD byte-identity test is unchanged.
- **Evidence:** `docs/qa/T0/probes/t0_probe_R.out` (float semantics section).

### A-040 T0 probes corrected and re-run; NEW evidence images renamed
- **Date:** 2026-11-05. **Who:** agent call (T0 fix pass). **Status:** done.
- **Decision:** `t0_probe.py` section D now uses the exact R division form (the multiply form is printed and labelled as an approximation) and `t0_probe.R` computes the float window in both directions; both were re-run and their outputs replaced (diffs in `docs/tests/T0-review-fixes-results.md`). The two NEW evidence images moved to `docs/qa/T0/new/superposition_new.png` and `docs/qa/T0/new/sheet_16_racs_new.png` (rule: a `new` folder and a `_new` suffix); their bytes are unchanged (same sha256 as recorded in `docs/tests/T0-architecture-results.md`). New probes: `t0_review.py`, `t0_review_pairs.py`, `t0_review.R`, `t0_review_cml.R`.
- **Why:** the reviewers asked for the probe fixes; the renamed images were the only NEW-dataset files without the naming rule.
