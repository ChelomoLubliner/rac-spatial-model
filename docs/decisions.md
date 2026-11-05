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
