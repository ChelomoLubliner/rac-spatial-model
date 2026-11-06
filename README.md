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

The steps are the six `.Rmd` files of `statistical_model/` (working directory: `statistical_model/`),
run in order:

| Step | File | Output |
|:----:|------|--------|
| 1 | `dataCC_1.Rmd` | Load raw data, remove police stamps, case-control sampling |
| 2 | `dataCC_distance_2.Rmd` | Compute min distance from each pixel to shoe contour |
| 3 | `re_model_shoe_std_3.Rmd` | Fit the selected model &rarr; `saved_models/*.rds` |
| 4 | `shoe_std_results_4.Rmd` | Intensity heatmap for the fitted model |
| 5 | `statistical_tests_5.Rmd` | Confidence intervals (Random vs CML) |
| 6 | `model_comparison_6.Rmd` | Side-by-side comparison figure |

**Rerunning the OLD steps (the committed results) -- not in this working tree.** The committed OLD
contour, models and figures were made on Windows (R 4.4.3 and the thesis Windows venv); a rerun on
another platform reproduces the CSVs byte for byte, but not those files bit for bit. So the code
refuses to overwrite them in place: knitting Step 3, 4, 5 or 6 here with `RAC_DATASET` unset or `old`
(RStudio's Knit button included), or running `python -m contour_algorithm.main`, stops at once with
`refusing to overwrite the committed OLD output ...`, before it computes or writes anything (decision
A-075; the user has yet to confirm this change of the old workflow). Steps 1 and 2 are not refused:
they rewrite the same bytes. To rerun OLD steps, use a copy:

- `RAC_SCRATCH=<scratch folder> bash tests/regress_old.sh --steps 1-6 --keep` copies the tree to a
  scratch folder, deletes there the outputs of the steps it runs, runs them, compares every output
  with the baselines and keeps the run folder with all outputs (see *Datasets* below);
- or copy the repository yourself and delete, in the copy, the outputs of the steps you rerun.

**NEW dataset**: set `RAC_DATASET=new` (see below); every NEW output has its own path, so the steps
run in this tree. To fit **both** models, run Step 3 twice -- once with each value of the environment
variable `RAC_MODEL_FEATURE` (read by `statistical_model/config.R`; `NEW_X_NS_XY` when unset):

```bash
cd statistical_model
RAC_DATASET=new RAC_MODEL_FEATURE=CML_MODEL Rscript -e 'rmarkdown::render("re_model_shoe_std_3.Rmd")'
```

(`tools/run_pipeline.sh` does this for you: it runs Steps 3 and 4 once per model.)

### Datasets: OLD (387 shoes) and NEW (631 shoes)

Every dimension, count, skip list, threshold and path comes from a **dataset profile** in
`config/datasets.json`, read by both the Python contour code (`contour_algorithm/profiles.py`)
and the R steps (`statistical_model/R/profile.R`). Select it with `RAC_DATASET`:

| `RAC_DATASET` | Dataset | Frame | Outputs |
|---|---|---|---|
| `old` (default; unset or empty) | the 387 original shoes | 307 x 395 | the committed paths, unchanged |
| `new` | the 631 shoes of `data/new_shoes/` | 255 x 367 | a `new` folder and the suffix `_new`, e.g. `processed_data/new/dataCC_new.csv`, `saved_models/new/NEW_X_NS_XY_new.rds`, `images_new/` |

Both datasets use the OLD prototype (`data/contour_prototype.png`, `data/freq_min_18.png`) for
`new_x` and the maps, so the standardized coordinate means the same for both. Run steps with

```bash
RAC_DATASET=new tools/run_pipeline.sh --steps 0-6      # 0 = the snake contour (Python)
```

which renders each Rmd (steps 3 and 4 once per model) and logs to `logs/<dataset>/`. The committed
OLD outputs are never overwritten in place: the OLD contour, models and figures come from Windows
builds that a rerun on another platform does not reproduce bit for bit, so the code refuses to
overwrite them; OLD runs belong in `tests/regress_old.sh` (a scratch copy, compared with the
baselines; `RAC_SCRATCH` must name a scratch folder):

```bash
RAC_SCRATCH=<scratch folder> bash tests/regress_old.sh --steps 0-6 --keep
```

The plan and the decisions behind this are in `docs/plans/2026-11-05-new-shoes-pipeline.md` and
`docs/decisions.md`; the fast tests run with `bash tests/run_all.sh`.

### Skip the fitting

The pre-fitted OLD models ship in `saved_models/` and the OLD figures in `model_images/`. Steps 4--6
read those models, but for OLD they run only in a copy (they would overwrite the committed figures):
`RAC_SCRATCH=<scratch folder> bash tests/regress_old.sh --steps 4-6 --keep` draws them from the
committed models in a few minutes. For NEW, Steps 4--6 run in this tree once Step 3 has fitted the NEW
models. Times on this machine (WSL): Step 1 about 2 min, Step 2 about 20 s, Step 3 about 4 min per
model.

---

## Repository Structure

```
rac-spatial-model/
├── data/                          # raw input + reference images
│   ├── contacts_data.txt          #   387 shoe contact matrices (307x395)
│   ├── locations_data.csv         #   RAC locations (x, y, shoe)
│   ├── contour_Active_Contour.txt #   shoe boundary contours
│   ├── all_cont.csv               #   cumulative contact surface (Step 1)
│   ├── freq_min_18.png            #   prototype mask: snake-filled superposition (>= 18 shoes)
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
