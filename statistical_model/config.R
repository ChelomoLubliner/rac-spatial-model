# config.R
# This file is located at: rac-spatial-model/statistical_model/config.R
# ROOT_PATH points to: rac-spatial-model/

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  # Get the directory where config.R is located, then go up one level
  ROOT_PATH <- dirname(dirname(rstudioapi::getSourceEditorContext()$path))
} else {
  # Fallback: assume we're in statistical_model folder
  ROOT_PATH <- dirname(getwd())
}

ROOT_PATH <- paste(ROOT_PATH, "/", sep = "")
CONTOUR_ALGORITHM <- "Active_Contour"
IMAGE_NUMBER <- "171"
# 171/ 135
MODEL_FEATURE <- "NEW_X_NS_XY"
# Options: "NEW_X_NS_XY", "CML_MODEL"

N_CONTROLS <- 100  # number of control pixels sampled per shoe in case-control design

# Shoe-specific offset for case-control design (replaces old hardcoded log(0.005))
# offset_i = log(N_CONTROLS / contact_pixels_i), averaged across shoes for grid predictions
SHOE_PIXEL_COUNTS_FILE <- paste(ROOT_PATH, "processed_data/shoe_pixel_counts.csv", sep = "")
if (file.exists(SHOE_PIXEL_COUNTS_FILE)) {
  shoe_pixel_counts <- read.csv(SHOE_PIXEL_COUNTS_FILE)
  MEAN_OFFSET <- mean(log(N_CONTROLS / shoe_pixel_counts$pixel_count))
} else {
  warning("shoe_pixel_counts.csv not found — run dataCC_1.Rmd first.")
  MEAN_OFFSET <- log(N_CONTROLS / 10615)  # fallback using Naomi's average
}
