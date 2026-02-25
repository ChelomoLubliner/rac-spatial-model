# Statistical Model Pipeline - Technical Details

> **Complete technical specification of the R statistical analysis pipeline**

## Pipeline Overview

The statistical model consists of **6 sequential R Markdown files** that process forensic shoeprint data from raw case-control sampling through spatial modeling to final comparison figures.

**Execution Order**: 1 → 2 → 3 → 4 → 5 → 6 (strict dependencies; Steps 5-6 require both models fitted)

---

## File Structure

```
rac-spatial-model/
├── data/                      # Raw input data + reference images
├── processed_data/            # Pipeline-generated datasets
├── saved_models/              # Trained model files (.rds)
├── model_images/              # Generated visualizations
│
└── statistical_model/         # R code only
    ├── config.R               # Central configuration
    ├── dataCC_1.Rmd           # Step 1: Data preparation
    ├── dataCC_distance_2.Rmd  # Step 2: Distance calculations
    ├── re_model_shoe_std_3.Rmd # Step 3: Statistical modeling
    ├── shoe_std_results_4.Rmd # Step 4: Results & visualization
    ├── statistical_tests_5.Rmd # Step 5: Confidence intervals
    └── model_comparison_6.Rmd # Step 6: Side-by-side comparison
```

---

## Detailed Module Analysis

### Configuration: `config.R`

**Purpose**: Central configuration loaded by all .Rmd files

**Key Variables**:
```r
ROOT_PATH            # Auto-detected project root
CONTOUR_ALGORITHM    # "Active_Contour"
IMAGE_NUMBER         # "171" or "135" (for specific shoe analysis)
MODEL_FEATURE        # "NEW_X_NS_XY" or "CML_MODEL"
```

**Path Detection**:
- If RStudio: Uses `rstudioapi` to detect file location
- Fallback: Uses `getwd()` assumption

---

### Step 1: `dataCC_1.Rmd` - Data Preparation & Case-Control Sampling

**Seed**: 313 (reproducibility)

#### Key Operations

**1. Load Raw Data**
- Reads: `data/contacts_data.txt` (387 shoes × 307×395 pixels)
- Character-based reading: `(307 * 395 + 2) * 387` characters
- Creates list of 387 contact matrices

**2. Data Cleaning**
- **Mirror Shoe 9**: Flips shoe 9 horizontally to match orientation
- **Remove Police Stamps**:
  - Creates cumulative contact surface (`allcont >= 8`)
  - Identifies lower and upper bounds algorithmically
  - Removes stamp regions from all shoes

**3. RAC Location Processing**
- Reads: `data/locations_data.csv`
- Converts X,Y coordinates to pixel positions using:
  - `aspix_x()`: X coordinate → column pixel
  - `aspix_y()`: Y coordinate → row pixel
- Handles multiple RACs per pixel (counts them)

**4. Contact Surface Adjustment**
- Sets contact surface = 1 where RACs exist
- Rationale: RACs may tear sole, creating apparent gaps

**5. Case-Control Sampling**
- **Strategy**: Within-cluster case-control sub-sampling
- **Per shoe**:
  - ALL cases (pixels with RACs, n_Acc = 1)
  - 100 random controls (pixels without RACs, n_Acc = 0)
- **Rationale**: High-resolution intensity estimation is computationally expensive

#### Outputs
```
processed_data/dataCC.csv        # Case-control dataset (~8,000 rows)
data/all_cont.csv      # Cumulative contact surface
```

#### Key Functions
```r
aspix_x(x, col_shoe=307, rel_col_shoe=150, rel_x_cord=0.25)
aspix_y(y, row_shoe=395, rel_row_shoe=300, rel_Y_cord=0.5)
```

#### Coordinate System
- **X range**: [-0.25, 0.25] → 307 pixels
- **Y range**: [-0.5, 0.5] → 395 pixels
- **Relevant region**: 150×300 pixels (center)

---

### Step 2: `dataCC_distance_2.Rmd` - Distance Calculations

#### Key Operations

**1. Load Case-Control Data**
- Reads: `processed_data/dataCC.csv`

**2. Load Contour Data**
- Reads: `data/contour_Active_Contour.txt`
- **Format**: Same as contacts_data.txt (387 shoes × 307×395 pixels)
- Converts contour matrices to X,Y coordinates
- Processes 386 shoes (shoe 127 excluded - no RACs)

**3. Distance Calculations**

**Minimum Euclidean Distance**:
```r
calculate_min_distance(new_data, contour_alg_df)
```
- For each point in dataCC:
  - Finds contour points for same shoe
  - Calculates Euclidean distance to all contour points
  - Records minimum distance

**Minimum Horizontal Distance**:
```r
calculate_min_horiz_distance(new_data, contour_alg_df)
```
- Finds nearest contour point with similar Y coordinate (±0.01)
- If no horizontal match found: Uses `min_dist` instead

**4. Standardized X Coordinate (`new_x`)**
- Uses a prototype contour to compute the expected shoe width at each Y
- Computes: `new_x = (x * distance_shape) / (abs(x) + horiz_dist)`

#### Outputs
```
processed_data/dataCC_distance.csv    # Enhanced dataset with distances and new_x
```

#### Performance
- Nested loops: ~8,000 rows × ~contour points per shoe
- Runtime: ~3-5 minutes for full dataset

---

### Step 3: `re_model_shoe_std_3.Rmd` - Statistical Modeling

**Seed**: 313
**Key Libraries**: `lme4` (mixed-effects models), `splines` (natural cubic splines), `survival` (conditional logistic regression)

#### Key Operations

**1. Load Data**
- Reads: `processed_data/dataCC_distance.csv`
- Reads: `data/all_cont.csv`

**2. Model Fitting Function**
```r
Random(nknotsx=3, nknotsy=5, dat=dataCC, model_feat=MODEL_FEATURE)
```

**Model Specifications**:

| Model Feature | Formula | Method |
|--------------|---------|--------|
| `NEW_X_NS_XY` | `n_Acc ~ ns(new_x, knots=3):ns(y, knots=5) + (1\|shoe)` | GLMM (glmer) |
| `CML_MODEL` | `n_Acc ~ ns(new_x, knots=3):ns(y, knots=5) + strata(shoe)` | Conditional logistic (clogit) |

**NEW_X_NS_XY Details**:
- **Family**: Binomial with logit link
- **Random Effects**: Random intercept per shoe `(1|shoe)`
- **Optimizer**: `nlminbwrap`
- **Fixed Effects**: Natural cubic splines with interaction
- **Offset**: `log(0.005)` for case-control design

**CML_MODEL Details**:
- Conditional logistic regression via `survival::clogit()`
- Shoe-level stratification eliminates nuisance parameters
- No intercept (cancels in conditional likelihood)

**3. Model Saving**
```r
file_name <- paste(ROOT_PATH, "saved_models/",
                   MODEL_FEATURE, ".rds", sep = "")
saveRDS(est, file = file_name)
```

#### Outputs
```
saved_models/NEW_X_NS_XY.rds    # ~10 MB
saved_models/CML_MODEL.rds       # ~1 MB
```

#### Model Fitting Details
- **Convergence**: May show warnings for complex models
- **Runtime**: 5-10 minutes depending on model complexity
- **Memory**: 3-4 GB peak usage

---

### Step 4: `shoe_std_results_4.Rmd` - Results & Visualization

**Seed**: 313

#### Key Operations

**1. Load Trained Model**
```r
file_name <- paste(ROOT_PATH, "saved_models/",
                   MODEL_FEATURE, ".rds", sep = "")
rand <- readRDS(file = file_name)
```

**2. Create Prediction Grid**
- Generates 307×395 = 121,265 prediction points
- Uses `expand.grid()` for all pixel combinations

**3. Design Matrix Construction**
- Builds spline basis for entire grid using new_x and y
- Matrix multiplication: `(121,265 × N_params) × (N_params × 1)`

**4. Prediction Calculation**
- For NEW_X_NS_XY: `newdesignmat %*% fixef(rand) + log(0.005)`
- For CML_MODEL: `newdesignmat %*% c(0, coef(rand))`
- Sets NA for areas outside contour

**5. Probability & Intensity Conversion**
```r
prob.pred <- exp(pred) / (1 + exp(pred))     # Logit -> Probability
intens <- -log(1 - prob.pred)                 # Probability -> Intensity
```

**6. Visualization Generation**
- Intensity heatmaps with `image.plot()`
- PDF files saved to `model_images/`

#### Outputs
- `model_images/NEW_X_NS_XY_SHOE.pdf`
- `model_images/CML_MODEL_SHOE.pdf`

---

### Step 5: `statistical_tests_5.Rmd` - Confidence Intervals

#### Key Operations

**1. Load Both Models**
- Loads `NEW_X_NS_XY.rds` and `CML_MODEL.rds`
- Extracts random effect variance (sigma^2) from NEW_X_NS_XY

**2. CI for Random (NEW_X_NS_XY)**
- Computes variance-covariance matrix from fitted model
- Builds prediction +/- 1.96 * SE on log-odds scale
- Converts to intensity scale

**3. CI for CML**
- Mean adjustment: matches CML mean to random model mean on log-odds scale
- Computes SEs from clogit variance-covariance matrix

**4. Visualization**
- Shoe image with horizontal cut lines at rows 110, 190, 250
- CI ribbon plots at each cut comparing Random vs CML

#### Outputs
- `model_images/CI_shoe_cuts.pdf`
- `model_images/CI_cut_110.pdf`, `CI_cut_190.pdf`, `CI_cut_250.pdf`

---

### Step 6: `model_comparison_6.Rmd` - Side-by-Side Comparison

#### Key Operations

**1. Compute Both Intensities**
- Random: `intens_random * exp(-sigma^2/2)` (marginal scale)
- CML: `intens_cml * exp(-sigma^2/2)` (marginal scale)
- The factor `exp(-sigma^2/2)` converts from conditional to marginal intensity

**2. Side-by-Side Figure**
- Combines Random and CML into a single panel
- Saved as `pixel_inten_JASAup.pdf`

#### Outputs
- `model_images/pixel_inten_JASAup.pdf` (2-model comparison)

---

## Key Technical Details

### Coordinate Transformations

**From coordinates to pixels**:
```r
pix_x = col_shoe - (floor((x + rel_x_cord) / delx) + not_rel_col)
pix_y = row_shoe - (floor((y + rel_Y_cord) / dely) + not_rel_row)
```

Where:
- `delx = (2 * 0.25) / 150 = 0.00333...`
- `dely = (2 * 0.5) / 300 = 0.00333...`
- `not_rel_col = ceiling((307 - 150) / 2) = 79`
- `not_rel_row = ceiling((395 - 300) / 2) = 48`

### Model Formula Construction

For **NEW_X_NS_XY** with 3x5 knots:
- X basis: 5 spline functions (3 knots -> 3+2 df)
- Y basis: 7 spline functions (5 knots -> 5+2 df)
- Interaction: 5 x 7 = 35 terms
- Plus intercept: 36 fixed effects
- Plus 1 random effect variance: 37 parameters total

### Performance Characteristics

| Step | Runtime | Memory | Bottleneck |
|------|---------|--------|------------|
| 1. dataCC_1 | 2-3 min | ~1 GB | Data loading |
| 2. dataCC_distance_2 | 3-5 min | ~2 GB | Nested distance loops |
| 3. re_model_shoe_std_3 | 5-10 min | 3-4 GB | GLMM fitting |
| 4. shoe_std_results_4 | 3-5 min | ~2 GB | Grid prediction |
| 5. statistical_tests_5 | 2-4 min | ~1 GB | CI computation |
| 6. model_comparison_6 | 1-2 min | ~2 GB | Prediction |
| **Total** | **18-30 min** | **4-8 GB** | Model fitting |

### File Sizes

```
saved_models/NEW_X_NS_XY.rds            10 MB
saved_models/CML_MODEL.rds               1 MB
processed_data/dataCC_distance.csv             1.6 MB
processed_data/dataCC_distance_part4.csv       1.9 MB
processed_data/dataCC.csv                      740 KB
data/all_cont.csv                    240 KB
```

---

## Common Issues & Solutions

### Issue 1: Memory Errors
**Solution**: `memory.limit(size = 8000)` (Windows) or reduce dataset size for testing

### Issue 2: Model Convergence Warnings
**Solution**: Use `glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=100000))`

### Issue 3: Path Issues
**Solution**: Verify `ROOT_PATH` in config.R points to project root

---

## Reproducibility

- **Random Seed**: 313 (consistent across files 1, 3, 4)
- **Package Versions**: Managed via R session
- **Data**: Fixed input files
- **Models**: Saved as .rds for exact reproduction
