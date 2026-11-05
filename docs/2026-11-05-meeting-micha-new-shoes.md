# Meeting 2026-11-05: R&R plan, Micha's requests, and the new-shoes work

**Date:** 2026-11-05
**Participants:** Naomi Kaplan-Damary (1st author), Shlomo / Chelomo Lubliner (2nd), Micha Mandel (senior), Sarena Wiesner, Yoram Yekutieli, Yaron Shor
**Written by:** Shlomo, with Claude Code, during and right after the meeting
**Branch:** `feature/new-shoes-pipeline`

> This note records what was understood in the meeting. Where something is **Micha's request**, it says so. Where something is **our proposal** (Shlomo/Claude), it is marked as such and still needs Micha's agreement.

> **Corrections found after the meeting (added 2026-11-05 by the T0 review pass; the meeting text below is unchanged):**
> 1. "A different dataset from the 387 shoes (**no overlap**)" (sections 3.2 and 5) is **unverified**: about 30 new shoes look like reprints of old shoes (same sole, same print position, RACs at the same places). See plan fact F25 and decision D-012 (question for Micha and Yoram); Part 2 excludes them from its primary analysis (A-024).
> 2. The old dataset has **13,287** RACs; the CSV's 13,288 lines include the header (plan F1).
> 3. Section 7: the fixed contour output path is at `active_contour_snake.py:175` and the `i == 126` skip at `:177` (not 172 and 175).

---

## 1. Context: the revise-and-resubmit

| Item | Value |
|---|---|
| Journal | **Forensic Science International** (Elsevier) |
| Manuscript | FSI-D-26-01184, *"Spatial Modeling of Randomly Acquired Characteristics on Shoe Soles"* |
| Decision | Revise and resubmit, received 2026-10-25 (Associate Editor: Sebastien Moret) |
| **Revision due** | **2026-12-04** |
| Also required | Source files (no PDF), Highlights file (3–5 bullets, 85 characters max each), optional graphical abstract |

**The editor's own demands, beyond the reviewers:**
- Examine the **independence assumptions** in detail.
- Discuss the fact that **sole design and material** were not taken into account.
- For both, give an in-depth discussion of the consequences for validity and practical use.
- **Conclusions must stay strictly within what the data support.**
- Every reviewer point must be addressed "to full satisfaction", and the paper goes back to the reviewers.

### Reviewer 1 (statistical and forensic), main points
1. The **added forensic value** is unclear. The "factor of 2" intensity difference already appears in Kaplan-Damary et al. (2022).
2. Questioned assumptions: **independence**, ignoring **sole design and material**.
3. RACs are reduced to their **center of gravity** (size, shape and geometry are ignored).
4. The model assumes the **same intensity function for all shoes**, with only one shoe-specific parameter.
5. Can the results support real **RAC rarity** assessments? For now they only describe relative intensity by location.
6. **Validation:** "more extensive validation and comparison with actual (non-simulated) and **out-of-sample data** might be of critical interest."
- Other remarks: clearer highlights; avoid biased words ("suspect"); the hierarchy of propositions; the phrase on p. 4 "our model does not assume local dependence on contact surface"; many references are not cited, inconsistently formatted, or have dead links.

### Reviewer 2 (footwear examiner, not the statistics)
Terminology and practice points: "footwear" rather than "shoe"; "outsole impression" rather than "shoeprint"; avoid "identification"; RACs are not observed in the crime-scene impression (features are); "different" rather than "inconsistent"; "damage from use" rather than "wear"; how RACs were marked and verified; why an automatic perimeter (snake) rather than a hand-drawn one; RACs are not rare on outsoles but are rare in casework; stress that **shape and orientation** matter together with location; many factors besides gait (activity, material, surface).

---

## 2. Email thread before the meeting (Oct 25–29), summarized

- **Naomi (Oct 25):** we got an R&R, and she will work on the revisions.
- **Micha (Oct 26):**
  - Dependence between RACs mostly affects the **variance**, less the spatial probability. We need a **reference** for this.
  - The model gives the probability of **one RAC** at a location. It **cannot** give the probability of a *set* of RACs, so we must think about what the estimate means forensically.
  - Shoe shape is partly handled by the standardization (if distance from the sole edge is the key factor). This goes into the limitations, as does the "same function for everyone" assumption.
  - For validation, there is **the additional file with locations**.
- **Naomi (Oct 29):** the validation file was used in Shlomo's thesis, right? She asks Sarena and Yoram whether any analysis by sole material was done (she believes not).
- **Micha (Oct 29):** we received the second file's data but did not use it in the end, and **Shlomo can update**. Its resolution was a bit different, but that can be overcome. **Before investing effort, decide how the file will be used, given the other comments: the test must fit how the analysis results are used.** He asks Sarena and Yoram whether the original data have any shoe-type variables (sport/work/military, or rubber/leather/polyurethane). The journal gives little time.
- **Yoram:** no shoe-type data was collected. Shoes could be classified from the images (sport / military / other), and most were sport shoes.

---

## 3. What was discussed in the meeting

### 3.1 Reviewer 1, point 1 (novelty), discussed with Sarena
- **Naomi's draft answer:** "The 2022 model assigns the same intensity to all locations within each predefined region. The current model estimates intensity as a smooth function of location, allowing variation within regions and gradual transitions across their boundaries."
- The reviewer asks about the **forensic** value, so Sarena's input is needed: when does the exact location matter in practice?
- **Supporting number (computed by Claude during the meeting, prototype shoe, Naomi's 14 areas):**

| | Ratio |
|---|---|
| Between areas (highest area mean ÷ lowest) | **1.75×** |
| Within one area (90th ÷ 10th percentile) | up to **2.4×** (areas 1 and 5) |
| Within one area (max ÷ min) | up to **5.5×** (toe areas 5 and 6; sensitive to edges) |

  → The intensity varies **as much inside one 2022 region as between regions**. A region model hides that. *(Script: Claude's scratchpad `within_region.R`. Not committed yet. Ratios don't depend on the offset or the σ² issue.)*

### 3.2 Reviewer 1, point 6 (validation)
**Naomi's three options** (from her response draft):
1. Use the additional dataset (if it has compatible RAC locations and contact surfaces). Fit the continuous model and the 2022 regional model on the original data, and compare their predictions on the new shoes.
2. If it is unsuitable, hold out some existing shoes, fit both models on the rest, and compare on the held-out shoes.
3. Present the contribution as a more flexible spatial representation, and acknowledge the lack of out-of-sample validation.

Pink comment on the draft: *the forensic team's input (Sarena and the others) is needed here again.*

**Facts established in the meeting:**
- The second dataset exists, and it is **a different dataset from the 387 shoes (no overlap), with a different format.** So option 1 is possible, and the whole set is out-of-sample.
- In the 2022 paper, Naomi ran a **goodness-of-fit** test with the conditional multinomial (Proposition 1 and Corollary 1: given a shoe's total nᵢ, the area counts are multinomial with pᵢⱼ = θⱼSᵢⱼ / Σⱼ′θⱼ′Sᵢⱼ′, and the shoe effect aᵢ cancels).

---

## 4. What Micha asked for (as understood)

Two parts. **Part 1 comes first**, because Part 2 needs it.

### PART 1: Run the complete model on the new shoes
**Micha's request:** run the **complete** pipeline on the new dataset, in a **new feature branch**, with **the same standardization as for the old dataset**. **The snake (active contour) must be adapted** to the new images.

What "complete" means here (the existing pipeline, step by step):

| Step | Code | For the new dataset |
|---|---|---|
| 0. Contour (snake) | Python `contour_algorithm/` (thesis repo) | Adapt to 255×367 and check every shoe |
| 1. Case-control data | `statistical_model/dataCC_1.Rmd` | New sizes, new files, 100 controls per shoe |
| 2. Distances + `new_x` | `dataCC_distance_2.Rmd` | Distances to each shoe's own contour; prototype width for `new_x` |
| 3. Fit models | `re_model_shoe_std_3.Rmd` | GLMM (`NEW_X_NS_XY`) and CML on the new shoes |
| 4. Intensity maps | `shoe_std_results_4.Rmd` | Heat maps for the new shoes |
| 5. CIs + hypothesis test | `statistical_tests_5.Rmd` | CIs at the cross-sections, `linearHypothesis` |
| 6. Comparison figure | `model_comparison_6.Rmd` | Random vs CML |
| + Compare old vs new | (new) | Same maps side by side, coefficients, σ², CIs |

### PART 2: The validation (what was discussed first)
**Micha's request (in his words, as relayed):**
- "We don't need all of that". He means Naomi's full option list. Instead, **for each shoe, compute the probability of being in each of the big areas.**
- **For each shoe i and each pixel j:** Sᵢⱼ = 1 if pixel j is on the contact surface (משטח דריכה), else 0. pᵢⱼ is the pixel's probability (the estimate from the logistic regression), **with the random effect set to 0**.
- **For each part k** (example: area 2): **Σ over j in k of pᵢⱼ·Sᵢⱼ**.
- The parts can be Naomi's 14 areas, or **"if possible", a split into 10–20 cells** (not necessarily those).
- The shoes must be **standardized** first (as for the old dataset). → The cells/areas are defined on the **standardized** shoe (`new_x`).
- Then compute the **goodness-of-fit on the new file**.

**What we propose on top (Shlomo/Claude, agreed in principle by Shlomo):**
1. **Normalize each shoe to its observed total** (Eᵢ(k) ← nᵢ · Eᵢ(k) / Σₖ′ Eᵢ(k′)). With the random effect set to 0, the raw sums are systematically off in level, so a goodness-of-fit test would reject because of the level, not the spatial shape. After normalizing, the shoe effect cancels (approximately for the logit, since per-pixel probabilities are tiny), as in the 2022 corollary. The normalization also removes the dependence on the case-control offset and on the σ² scaling. ✅ *Shlomo: "ok do that".*
2. **Too few RACs per shoe** (about 32 RACs per shoe in the new file, so 1–2 per cell): no chi-square per shoe. **Sum over all 631 shoes** (about 20,013 RACs → about 1,000 per cell with 20 cells), merge cells with expected count < 5, and run Pearson χ² with df = K − 1 (nothing is estimated on the new file).
3. **Run both tests:** the pooled chi-square **and** a **bootstrap over shoes** (resampling whole shoes keeps dependent RACs together). If the two disagree, that is itself evidence of dependence, which helps with the editor's independence demand. ✅ *Shlomo: "yes you will do both".*
4. **Run the same test for the 2022 regional model** on the new shoes, so the continuous model and the 2022 model are compared on equal terms. This answers R1 point 1 and point 6 together. Optionally, a **log-score** (the average log-probability of each new RAC's location) as a second comparison that works with small counts.
5. Do it for **both partitions**: Naomi's 14 areas (applied on `new_x`) and a 10–20 cell grid.

Naomi's 14-area rules are in code: `naomikap/rac-intensity`, `Code/Organizing data to include subsets (larger areas).R`, lines 28–117. They are cuts on (x, y): x < 0 vs. ≥ 0; y at −0.35, −0.15, 0, 0.15; and parabolas for areas 11–14.

---

## 5. Data facts (checked)

| | Original dataset | New dataset |
|---|---|---|
| Shoes | 387 (386 with RACs; **shoe 127 has no RACs**) | **631** (different shoes, no overlap) |
| RACs | 13,288 | **20,013** (mean about 32 per shoe, max 281) |
| Image size | 307 cols × 395 rows | **255 cols × 367 rows** |
| Coordinates | x in about [−0.25, 0.25], y in [−0.5, 0.5] | raw file: **2× larger** (y in about [−1, 1]) |
| Files in repo | `data/contacts_data.txt`, `data/locations_data.csv` | `data/new_shoes/` (see its README) |

- **The factor of 2 is confirmed:** the first RAC has raw x = −0.409554, and Shlomo's 2023 file has x = −0.204777, exactly half.
- **`data/new_shoes/locations_new_snake_2023.csv`** is Shlomo's 2023 processing (coordinates ÷ 2, `COL/ROW`, snake and convex-hull distances). It is useful as a **cross-check** but must be recomputed with the adapted snake.
- An old R script for the new shoes exists at `Desktop/These/DoK 23/R/NEW_NAOMI_CHELOMO/pas_important/naomi_chelomo_new_shoes.Rmd` (2023). It uses raw x (no `new_x`), and its `rel_col_shoe = 333` / `rel_row_shoe = 180` look wrong or swapped, so don't trust it.
- Contact file format: 631 records of 93,585 characters, separated by `\r\n` (record stride 93,585 + 2). **Never convert the line endings** (`.gitattributes` marks them `-text`).
- **In 2023, the snake failed on the new shoes** (Shlomo). This is the main technical risk.

---

## 6. Shlomo's engineering requirements (must hold for every step)

1. **No collisions:** every file created for the new dataset carries the dataset name (folder `.../new/` **and** a `_new` suffix). The old files keep their current names.
2. **Exact reproducibility:** at every step, rerunning the old dataset must give **exactly the same result** as the committed files (`data/contour_Active_Contour.txt`, `processed_data/*`, `saved_models/*`). We take a baseline (checksums + model coefficients) before changing anything. A step is not done until the old regression passes.
3. **Work with several subagents:** implementers, reviewers, a **statistics expert**, an analyst, **visualization**, and **strong end-to-end tests of the entire pipeline**.
4. **Compare everything:** old vs new at every stage (contours, case-control data, `new_x`, coefficients, σ², maps, CIs, tests).
5. **Timeline:** a first full result for Micha in **about 1 week** (by about 2026-11-12). The paper is due 2026-12-04.

---

## 7. Known code issues and risks (found 2026-11-05)

**Collisions and hard-coding in the Python contour code** (thesis repo `contour_algorithm/`):
- `globals.py`: `FOLDER = '../images/'` is the **same for both datasets**, so a new run overwrites the old intermediates.
- `active_contour_snake.py:172`: output fixed to `../data/contour_Active_Contour.txt`, so it would overwrite the old contour file.
- `active_contour_snake.py:175`: `if i == 126` skips shoe 127 **for any dataset**. It would wrongly drop a real new shoe.
- `create_files_shoes.py`: the left-shoe flip of image 8 runs only `if FOLDER == 'Images/Old_Shoes/'`, which never matches today. The baseline run will show whether the committed contours had shoe 8 flipped.
- `init_snake()`: the new-dataset ellipse is already partly adapted (center y = 185, x = 128; radii 162, 95). Correction: in the meeting Claude said x was never adapted, which was wrong.
- `get_snake_image()`: `np.zeros((W, H))` then a transpose, while the other arrays are `(H, W)`. Check this for non-square sizes.
- Cleaning mask threshold "≥ 18 shoes" (`superposed_pixels`) was set for 387 shoes. For 631 shoes, a proportional threshold would be about 29. **To decide.**

**Hard-coded sizes in R:** `dataCC_1.Rmd:14-19, 40-59` and `dataCC_distance_2.Rmd:23-28` (307 / 395 / 150 / 300), `1:386` loops in `dataCC_distance_2.Rmd`, `num_shoe <- 387` in several files, and fixed input/output paths in every step (`processed_data/dataCC.csv`, `saved_models/*.rds`, `model_images/*.pdf`, `data/freq_min_18.png`, `data/contour_prototype.png`). Step 1 also **writes `data/all_cont.csv`**, a committed file.

**Pixel-to-coordinate scale:** in the old data, 1 pixel = 1/300 coordinate unit (`rel_col_shoe = 150` over x ±0.25, `rel_row_shoe = 300` over y ±0.5). Distances and `new_x` are computed in coordinate units. **For the new images, the pixel scale must be calibrated.** Proposed method: choose the scale/offset/mirroring that puts the most RACs on contact pixels, check that it recovers 150/300 on the old data, and cross-check against the `COL/ROW` columns of the 2023 file.

**Prototype for `new_x`:** keep the **old** prototype (`data/contour_prototype.png`), so `new_x` means the same thing for both datasets and the old model can be applied to the new shoes. The cleaning mask is computed per dataset. *(Claude's call. Tell Micha.)*

**Packages:** the thesis venv `master_thesis_forensic_shoeprint/venv` (WSL, Python 3.12, scikit-image 0.25.2) works. Its versions should be frozen into this repo for reproducibility. R package **`car` is not installed** (needed for `linearHypothesis`). No `testthat` or `pytest`, so tests will be plain `Rscript` and `python -m unittest`.

---

## 8. Statistical issues found in the existing (old-dataset) code

| # | Issue | Status |
|---|---|---|
| 1 | The GLMM is fitted **without** the per-shoe offset log(100 / pixelsᵢ). The offset is only added at prediction, so the random intercept absorbs contact-area differences: var(offset) = 0.098 vs σ² = 0.960 (about 10%). CML is not affected. | To raise with Micha. Not urgent for the validation (it cancels after normalizing). |
| 2 | `model_comparison_6.Rmd:125` (and Naomi's original `pixel analysis.R:364`) multiplies by **exp(−σ²/2)** = 0.62, while Naomi's own comment says the lognormal expectation is exp(+σ²/2) = 1.62. | **Ask Naomi.** Affects only the absolute level. |
| 3 | `MEAN_OFFSET` = mean of logs (−4.614), not log of the mean (−4.661). About 5% in level. | Note. |
| 4 | Knots (3 for x, 5 for y) not justified, and no sensitivity analysis. | From the March review. Optional. |
| 5 | CIs may be too narrow under RAC dependence. Use a sandwich estimator or a shoe bootstrap. | Matches the editor's demand. Part 2 helps. |

---

## 9. Questions prepared for Micha (and what was answered)

| # | Question | Answer |
|---|---|---|
| 1 | With the random effect = 0, normalize each shoe to its observed total? | **Yes** ("ok do that") |
| 2 | Plain pooled chi-square, or a shoe bootstrap? | **Both** |
| 3 | Grid on raw x or on `new_x`? | **`new_x`** (Micha wants the standardized shoe) |
| 4 | Refit the GLMM with the offset before 2026-12-04? | Open, for the team |
| 5 | exp(−σ²/2) vs exp(+σ²/2)? | Open, **ask Naomi** (it's in her code) |
| + | Reference for "dependence affects the variance, not the estimate" | Proposed: **Liang & Zeger (1986), GEE**. Micha to confirm. |

Plain-language version (Hebrew + English) of these questions: Claude's scratchpad `questions_micha.html`.

---

## 10. Open questions
1. Cleaning-mask threshold for 631 shoes (18 as before, or about 29 proportionally)?
2. Grid design for Part 2: how many cells (10 or 20), and the cell boundaries on `new_x`?
3. The 2022 regional model on the new shoes: refit θⱼ on the old shoes (Poisson GLM with shoe effects and offset log Sᵢⱼ) or use the published values?
4. Refit the old GLMM with the offset (issue 8.1) for the revision, or not?
5. The σ² sign (issue 8.2): Naomi.
6. Sole type: Yoram says it could be classified from the images. Is that worth doing for the limitations section?

## 11. Next steps
1. Write the implementation plan (Part 1, then Part 2), with a big-picture diagram, subagent roles, and the old-dataset regression gate at every task.
2. Task 1 of the plan: **capture the old-dataset baseline** and check that today's code reproduces the committed files exactly. In 2023 something went wrong, and this will show it.
3. Then: dataset profiles (no collisions) → snake adaptation and QA on the 631 shoes → steps 1–6 on the new shoes → old-vs-new comparison → Part 2 validation → report for Micha.

## 12. Where things are
- This repo, branch `feature/new-shoes-pipeline`. Commit `c7f6478` added `data/new_shoes/`.
- Thesis repo (snake code): `/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/contour_algorithm/`
- Original new-shoes data: `C:\Users\mehes\Desktop\These\Files_thesis\Data\new_shoes\`
- Naomi's 2022 code: https://github.com/naomikap/rac-intensity (14 areas, `pixel analysis.R`)
