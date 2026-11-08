# New shoes: full pipeline, old vs new, and out-of-sample validation (report for Micha)

**Date:** 2026-11-08 · **Branch:** `feature/new-shoes-finish` (based on `feature/new-shoes-pipeline`) · **Status:** draft. The final reviews of the whole branch are still to do (planned for 2026-11-11).

Every number below is taken from the result documents, which cite their sources (CSVs, commands, outputs):
- `docs/tests/T5-new-pipeline-results.md` (model on the new shoes)
- `docs/results/old-vs-new.md` (T6)
- `docs/results/validation.md` (T7)
- `docs/qa/snake-qa.md` (snake)

---

## 1. What was asked (meeting of 2026-11-05)

- **Part 1:** run the complete model on the new dataset, with the same standardization as for the old shoes, and adapt the snake.
- **Part 2:** for each new shoe and each pixel, take p·S with the random effect set to 0, sum it over parts of the shoe (Naomi's 14 areas, or a grid of 10 to 20 cells on the standardized shoe), and run a goodness-of-fit test on the new file.

## 2. Data

| | Old (paper) | New (second file) |
|---|---|---|
| Shoes | 387 (386 with RACs) | 631 (all have RACs) |
| RACs | 13,287 | 20,013 |
| Image | 307 × 395 | 255 × 367; same pixel scale (300 px per unit) after dividing the coordinates by 2 |

**⚠️ Overlap (decision D-012):** the team said in the meeting that the datasets don't overlap. The data disagree.
- About **67 new shoes are very likely reprints of old shoes**, and 22 more are uncertain. That is 15.8% of the new RACs.
- Evidence that doesn't depend on judging the images: consecutive new ids map onto consecutive old ids far more often than chance would (16 of 57 pairs, where about 0.3 would be expected).
- **Please confirm with Sarena or Yoram.** The validation uses the shoes that are not reprints (478 shoes).

## 3. Part 1: snake and model on the new shoes

**Snake:**
- All 631 contours were built.
- Visual QA was done three times by an image reviewer, using sheets of every shoe with the initial ellipse, the first snake, the final snake, the prototype and the cleaned shoe (`docs/qa/sheets_new/`).
- Stickers and frame lines were erased.
- 23 shoes received a fallback snake, and shoe 170 received its own ellipse.
- Quality matches the old shoes.

**Model (same pipeline, all outputs namespaced `_new`):**

| | Old | New |
|---|---|---|
| Case-control rows | 51,849 | 83,090 |
| GLMM sigma² (no offset, as committed) | 0.960 | 0.756 |
| Wald test, all 24 spatial terms = 0 (RX vcov) | W = 427.8 | **W = 585.9, p ≈ 10⁻¹⁰⁸** |
| CML Wald | 420.7 | 576.0 |

→ On an independent collection, RAC intensity is again **far from uniform**.

**Reproducibility:** after every step, the old pipeline still reproduces the committed files exactly. That holds bit for bit on Windows (where they were produced) and byte for byte between WSL reruns.

## 4. Old vs new (T6)

- **Overall level:** not significantly different. The ratio new/old is 1.06 [0.93, 1.22].
- **Spatial shape:** different, but modestly.
  - Primary test: shoe bootstrap W = 46.7, p = 0.0056. The model-based test (118) overstates the difference.
  - Most of the shoe agrees within ±20–45%. The main relief is shared: high in the forefoot and at the heel, low at the toe tip.
- **Where the shapes differ** (model-free regional table):
  - New is higher at the heel bottom (1.23).
  - New is higher in a band at the top of the midfoot (1.32).
  - New is lower in a band at the front of the heel (0.63).
- **sigma² with the offset:** old 0.979, new 0.641, so new shoes vary less between shoes.
- **Random effects vs CML:** they agree within about 2% on both datasets.

## 5. Part 2: goodness-of-fit on the new file (T7)

Method, as Micha asked:
- Sum p·S per part, using the old-fitted GLMM with the random effect set to 0.
- Scale each shoe to its observed number of RACs.
- Parts: Naomi's 14 areas and grids of 10, 15 and 20 cells.

The p-value comes from a **two-sample shoe bootstrap** (B = 2,000), which includes the old estimation error. A naive χ² with fixed expected counts would reject a correct model about 80% of the time.

| Result | Value |
|---|---|
| **Goodness of fit, 14 areas (primary)** | **X² = 298 on 13 df, noise floor 49, p_boot = 0.0005**. The old surface does **not** transfer exactly to the new shoes |
| Same test for the 2022 regional model | X² = 170 |
| Continuous vs 2022, per RAC (log-score) | **a tie** (+0.000003 nats) |
| Continuous vs 2022, per shoe | continuous ahead by about **0.8%**. The lead is in the lightly marked shoes |
| Both models vs uniform placement | about +1.1% probability for the pixel of a RAC |
| Independence | pairs of RACs 2–8 px apart are **37% more frequent** than expected (old: 45%). The area counts are overdispersed (phi 1.6–2.0) |

⚠️ **A few intervals in `validation.md` are still being recomputed** after the statistics review: the centred model-class intervals and the calibration slope. The point estimates above don't change.

## 6. Other findings for the paper

1. **Knots:** the 5 y knots are too coarse for the new data (5-fold CV by shoe favours a finer y basis on new, and not on old). This supports meeting issue 8.4: report a knot sensitivity analysis.
2. **Sole design:** one design (392 new shoes) prints a heel-front band but almost never has RACs there. A single surface for all shoes doesn't hold everywhere. This is Reviewer 1's point 4 and the editor's "sole design" point.
3. **Naomi's 2022 estimator:** `optim` with the default Nelder-Mead **stops at its iteration limit**, so its intensities are up to 9.8% from the converged optimum. If Table 1 of 2022 came from this call, it is not at the optimum. **Tell Naomi.**
4. **Wald statistic and vcov:** W is 428.7 with the Hessian vcov and 427.8 with the RX vcov. State the vcov method in the paper.

## 7. Suggested message to Reviewer 1 (points 1 and 6), to discuss

> We validated the model on an independent collection of 631 shoe prints (478 after excluding reprints of the original shoes). The spatial non-uniformity replicates strongly (Wald p ≈ 10⁻¹⁰⁸). The fitted surface transfers only partly: a goodness-of-fit test that accounts for estimation error rejects exact transfer (p = 0.0005), and the shapes differ in a few bands while the overall level agrees. Per RAC, the continuous surface predicts as well as the 2022 regional model, and per shoe it is slightly better. RACs within a shoe are not independent: pairs at short range are about 40% more frequent than expected. We therefore present the model as a description of where single RACs tend to occur, not as a tool to compute the probability of a set of RACs. We discuss sole design and dataset differences as limitations.

## 8. Open questions

| # | For | Question |
|---|---|---|
| D-012 | Sarena / Yoram | Which new shoes are reprints of old shoes? |
| 8.2 | Naomi | Why `exp(-σ²/2)`? The expectation is `exp(+σ²/2)`; see `pixel analysis.R:364` |
| 8.1 | Micha | Refit the GLMM with the per-shoe offset? With the offset, σ² is 0.979 on old |
| 8.4 | Micha / Naomi | Knot choice: report a sensitivity analysis |
| — | Naomi | Should the 2022 estimator be rerun to convergence? |
