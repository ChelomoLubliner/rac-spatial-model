# Spatial Modeling of Randomly Acquired Characteristics on Outsoles

> Companion code for: **Spatial modeling of randomly acquired characteristics on outsoles with application to forensic shoeprint analysis**

Two spatial intensity estimators for Randomly Acquired Characteristics (RACs) on forensic shoe outsoles, fitted to a dataset of 387 athletic shoes digitized at 307 x 395 pixel resolution.

| Estimator | Method | Formula |
|-----------|--------|---------|
| **Random Effects** (`NEW_X_NS_XY`) | Binomial GLMM with shoe-level random intercepts | `n_Acc ~ ns(new_x, 3):ns(y, 5) + (1\|shoe)` |
| **CML** (`CML_MODEL`) | Conditional logistic regression with stratification | `n_Acc ~ ns(new_x, 3):ns(y, 5) + strata(shoe)` |

Both use a natural cubic spline interaction surface over a standardized horizontal coordinate (`new_x`) that accounts for sole shape.

---

## Pipeline

```
 data/contacts_data.txt ──┐
 data/locations_data.csv ──┼──> [1] dataCC_1 ──> processed_data/dataCC.csv
                           │
 data/contour_*.txt ───────┘        │
                                    v
                           [2] dataCC_distance_2 ──> processed_data/dataCC_distance.csv
                                    │
                                    v
                           [3] re_model_shoe_std_3 ──> saved_models/*.rds
                                    │
                    ┌───────────────┼───────────────┐
                    v               v               v
           [4] shoe_std_     [5] statistical_  [6] model_
               results_4        tests_5          comparison_6
                    │               │               │
                    v               v               v
              model_images/   model_images/   model_images/
              *_SHOE.pdf      CI_*.pdf        pixel_inten_JASAup.pdf
```

Steps must run **in order** (1 &rarr; 2 &rarr; 3 &rarr; 4/5/6). Steps 5 and 6 require both models fitted first.

---

## Quick Start

### Prerequisites

- **R** 4.0+ (tested with 4.3.x) &nbsp;&middot;&nbsp; **RStudio** recommended &nbsp;&middot;&nbsp; 4--8 GB RAM

```r
install.packages(c(
  "lme4", "splines", "survival", "ggplot2", "dplyr",
  "Matrix", "spam", "fields", "imager", "smoothie",
  "plotly", "data.table", "parallel", "doParallel", "rgl"
))
```

### Run the pipeline

Open each `.Rmd` in RStudio (working directory: `statistical_model/`) and knit in order:

| Step | File | Output |
|:----:|------|--------|
| 1 | `dataCC_1.Rmd` | Load raw data, remove police stamps, case-control sampling |
| 2 | `dataCC_distance_2.Rmd` | Compute min distance from each pixel to shoe contour |
| 3 | `re_model_shoe_std_3.Rmd` | Fit the selected model &rarr; `saved_models/*.rds` |
| 4 | `shoe_std_results_4.Rmd` | Intensity heatmap for the fitted model |
| 5 | `statistical_tests_5.Rmd` | Confidence intervals (Random vs CML) |
| 6 | `model_comparison_6.Rmd` | Side-by-side comparison figure |

To fit **both** models, run Step 3 twice -- once with each setting in `statistical_model/config.R`:

```r
MODEL_FEATURE <- "NEW_X_NS_XY"   # or "CML_MODEL"
```

### Skip the fitting

Pre-fitted `.rds` files ship in `saved_models/`, so Steps 4--6 work out of the box (Steps 1--3 take ~15 min).

---

## Repository Structure

```
rac-spatial-model/
├── data/                          # raw input + reference images
│   ├── contacts_data.txt          #   387 shoe contact matrices (307x395)
│   ├── locations_data.csv         #   RAC locations (x, y, shoe)
│   ├── contour_Active_Contour.txt #   shoe boundary contours
│   ├── all_cont.csv               #   cumulative contact surface (Step 1)
│   ├── freq_min_18.png            #   contact-surface mask (>= 8 shoes)
│   └── contour_prototype.png      #   prototype contour for new_x
│
├── processed_data/                # pipeline-generated datasets
│   ├── dataCC.csv                 #   case-control sample (Step 1)
│   ├── dataCC_distance.csv        #   with distances & new_x (Step 2)
│   ├── dataCC_distance_temp.csv   #   intermediate checkpoint
│   └── dataCC_distance_part4.csv  #   partial run checkpoint
│
├── saved_models/                  # fitted .rds model objects
│   ├── NEW_X_NS_XY.rds
│   └── CML_MODEL.rds
│
├── model_images/                  # generated PDF figures
│
├── statistical_model/             # R code only
│   ├── config.R
│   ├── dataCC_1.Rmd
│   ├── dataCC_distance_2.Rmd
│   ├── re_model_shoe_std_3.Rmd
│   ├── shoe_std_results_4.Rmd
│   ├── statistical_tests_5.Rmd
│   └── model_comparison_6.Rmd
│
├── PIPELINE_DETAILS.md            # full technical specification
└── .gitignore
```

---

## Technical Details

See [PIPELINE_DETAILS.md](PIPELINE_DETAILS.md) for coordinate transformations, spline basis construction, performance benchmarks, and troubleshooting.
