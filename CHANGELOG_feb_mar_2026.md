# Changelog: Feb 18 -- Mar 18, 2026

> Monthly summary for the `rac-spatial-model` repository.
> Prepared for meeting with Naomi (advisor) and Micha.

**Period**: Feb 18 -- Mar 18, 2026
**Commits**: 4
**Contributors**: chelomo (Shlomo), with Claude Code assistance

---

## Overview

The repository was created from scratch during this period. Work progressed in three phases:

1. **Repository bootstrap** (Feb 25--26) -- Full pipeline migrated into a clean, organized repo with documentation, raw data, pre-fitted models, and generated figures.
2. **Critical offset correction + hypothesis test** (Mar 16) -- Addressed Naomi's feedback: replaced the incorrect hardcoded `log(0.005)` offset with a properly derived shoe-specific `MEAN_OFFSET`, ported the `linearHypothesis` test from the old codebase, and regenerated all outputs.
3. **Minor figure update** (Mar 18) -- Refreshed shoe visualization.

---

## 1. Initial commit: repository reorganization

**Date**: Feb 25, 2026 | **Commit**: `6cdc0b9`

Established the project with a flat top-level layout. All R analysis code lives in `statistical_model/`; data, outputs, and models are organized by type at root level.

### What was added

**27 files** including the complete 6-step R pipeline, raw data, pre-fitted models, and generated figures.

#### Pipeline files (`statistical_model/`)

| Step | File | Purpose |
|:----:|------|---------|
| -- | `config.R` | Central configuration: paths, contour algorithm, model selection |
| 1 | `dataCC_1.Rmd` | Load 387 shoes, clean police stamps, case-control sampling (100 controls/shoe) |
| 2 | `dataCC_distance_2.Rmd` | Compute min Euclidean & horizontal distance to contour; derive standardized `new_x` |
| 3 | `re_model_shoe_std_3.Rmd` | Fit GLMM (`NEW_X_NS_XY`) or conditional logistic (`CML_MODEL`) |
| 4 | `shoe_std_results_4.Rmd` | Generate intensity heatmaps from fitted model |
| 5 | `statistical_tests_5.Rmd` | Confidence intervals for Random vs CML at cross-sections |
| 6 | `model_comparison_6.Rmd` | Side-by-side comparison figure for the paper |

#### Data files (`data/`)

| File | Description |
|------|-------------|
| `contacts_data.txt` | *Added in next commit* |
| `locations_data.csv` | RAC locations (x, y, shoe) -- 13,288 rows |
| `all_cont.csv` | Cumulative contact surface across 387 shoes |
| `contour_prototype.png` | Prototype shoe contour for `new_x` standardization |
| `freq_min_18.png` | Binary contact-surface mask (pixels with >= 8 shoes) |

#### Pre-fitted models (`saved_models/`)

| File | Size | Model |
|------|------|-------|
| `NEW_X_NS_XY.rds` | ~25 MB | Binomial GLMM: `n_Acc ~ ns(new_x,3):ns(y,5) + (1\|shoe)` |
| `CML_MODEL.rds` | ~2.6 MB | Conditional logistic: `n_Acc ~ ns(new_x,3):ns(y,5) + strata(shoe)` |

#### Generated figures (`model_images/`)

- `NEW_X_NS_XY_SHOE.pdf` / `CML_MODEL_SHOE.pdf` -- intensity heatmaps per model
- `CI_shoe_cuts.pdf` -- shoe outline with cross-section lines at rows 110, 190, 250
- `CI_cut_110.pdf`, `CI_cut_190.pdf`, `CI_cut_250.pdf` -- CI ribbon plots (Random vs CML)
- `pixel_inten_JASAup.pdf` -- side-by-side comparison figure (paper Figure)

#### Documentation

- `README.md` -- project overview, pipeline diagram, quick start, repo structure
- `PIPELINE_DETAILS.md` -- full technical specification (coordinate transforms, spline basis, performance benchmarks)

---

## 2. Added raw data files

**Date**: Feb 26, 2026 | **Commit**: `d7d319d`

Added the two large raw text files that were missing from the initial commit:

| File | Rows | Description |
|------|------|-------------|
| `data/contacts_data.txt` | 387 | Binary contact matrices (307x395 pixels each) for all 387 shoes |
| `data/contour_Active_Contour.txt` | 386 | Active Contour boundary matrices (shoe 127 excluded -- no RACs) |

These are the primary inputs to Steps 1 and 2 of the pipeline. Without them, the pipeline cannot be re-run from scratch.

---

## 3. Major update: shoe-specific offset and hypothesis test

**Date**: Mar 16, 2026 | **Commit**: `0e86838`

**Motivation**: Naomi identified that the hardcoded offset `log(0.005)` was incorrect. The offset in a case-control design should reflect the actual sampling ratio per shoe: `offset_i = log(N_CONTROLS / contact_pixels_i)`. The old value `log(0.005) = log(1/200)` didn't correspond to any valid calculation -- it was a leftover from when the design used 20 controls instead of 100, and even then was approximate. Additionally, she requested porting the `linearHypothesis` test from her old codebase to verify spatial significance.

### 3.1 Shoe-specific `MEAN_OFFSET` (replaces `log(0.005)`)

**The problem**: In a case-control design, the offset adjusts for the sampling fraction. With `N_CONTROLS = 100` controls per shoe, the correct offset for shoe *i* is:

```
offset_i = log(100 / contact_pixels_i)
```

Since grid predictions aren't shoe-specific, we use the mean across all 387 shoes: `MEAN_OFFSET = mean(offset_i)`.

**Files changed**:

| File | Change |
|------|--------|
| `dataCC_1.Rmd` | New chunk: computes per-shoe contact pixel counts from `data_temp[[i]]`, writes `processed_data/shoe_pixel_counts.csv`. Hardcoded `size=100` replaced with `N_CONTROLS` constant. |
| `config.R` | Added `N_CONTROLS = 100`. Reads `shoe_pixel_counts.csv` and computes `MEAN_OFFSET`. Fallback: `log(100/10615)` using Naomi's average if file is missing. |
| `statistical_tests_5.Rmd:86` | `+ log(0.005)` → `+ MEAN_OFFSET` |
| `shoe_std_results_4.Rmd:83,97` | `+ log(0.005)` → `+ MEAN_OFFSET` (two occurrences: Random model and NEW_X_NS_XY branch) |
| `model_comparison_6.Rmd:79` | `+ log(0.005)` → `+ MEAN_OFFSET` |

**New file**: `processed_data/shoe_pixel_counts.csv` (387 rows: shoe ID + contact pixel count)

### 3.2 `linearHypothesis` test (ported from old codebase)

**Source**: `naomikap/rac-intensity`, `Code/pixel analysis.R` ~line 370

**Purpose**: Tests whether all spatial spline coefficients are jointly zero:
- H0: beta_1 = beta_2 = ... = beta_p = 0 (all fixed effects except intercept)
- Uses the random effects (GLMM) estimator
- Chi-squared and F tests via `car::linearHypothesis()`

**Files changed**:

| File | Change |
|------|--------|
| `statistical_tests_5.Rmd` | Added `library(car)`. New `linearHypothesis_test` chunk: constructs contrast matrix (identity minus intercept row), runs `linearHypothesis()` with the GLMM's variance-covariance matrix. |

### 3.3 Regenerated outputs

All downstream outputs were regenerated with the corrected offset:

- `data/all_cont.csv` -- updated (792 lines changed)
- `processed_data/dataCC.csv` -- fully regenerated (~52K rows, different due to case-control resampling with seed)
- All 7 PDF figures in `model_images/` -- regenerated with corrected intensity values

**Impact**: The corrected offset shifts all intensity predictions. Since `MEAN_OFFSET = log(100/~10615) ≈ -4.66` vs the old `log(0.005) ≈ -5.30`, predictions on the log-odds scale increase by ~0.64, yielding somewhat higher estimated RAC intensities.

---

## 4. Minor shoe image update

**Date**: Mar 18, 2026 | **Commit**: `1c83700`

Updated `model_images/NEW_X_NS_XY_SHOE.pdf` (binary change, same file size). Cosmetic refresh of the shoe intensity heatmap.

---

## Summary of current state

### Pipeline status

All outputs are **up-to-date** with the corrected `MEAN_OFFSET` and the `linearHypothesis` test in place.

### Open items from Naomi's review (Mar 16)

| Item | Status |
|------|--------|
| Fix shoe-specific offset (replace `log(0.005)`) | Done (commit `0e86838`) |
| Port `linearHypothesis` test from old codebase | Done (commit `0e86838`) |
| Verify both estimates + CIs are properly based on case-control design with shoe specification | To discuss |

### Files in the repository (30 total)

```
rac-spatial-model/
├── data/                              # 6 files (raw inputs + reference images)
├── processed_data/                    # 5 files (pipeline-generated datasets)
├── saved_models/                      # 2 files (fitted .rds model objects)
├── model_images/                      # 7 PDF figures
├── statistical_model/                 # 7 R files (config + 6-step pipeline)
├── README.md
├── PIPELINE_DETAILS.md
├── CHANGELOG_feb_mar_2026.md
└── .gitignore
```
