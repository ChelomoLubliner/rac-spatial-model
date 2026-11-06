# config.R
# This file is located at: rac-spatial-model/statistical_model/config.R
# ROOT_PATH points to: rac-spatial-model/
#
# P is the dataset profile (statistical_model/R/profile.R, plan section 4):
# RAC_DATASET=old|new (default old) selects it, and every dimension, count,
# skip list and path of the steps comes from it. OLD = the committed values
# and paths; NEW outputs carry a new folder and the suffix _new.
# MODEL_FEATURE comes from RAC_MODEL_FEATURE (NEW_X_NS_XY by default, or
# CML_MODEL), so nobody edits this file to switch models.

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  # Get the directory where config.R is located, then go up one level
  ROOT_PATH <- dirname(dirname(rstudioapi::getSourceEditorContext()$path))
} else {
  # Fallback: assume we're in statistical_model folder
  ROOT_PATH <- dirname(getwd())
}

ROOT_PATH <- paste(ROOT_PATH, "/", sep = "")
source(paste(ROOT_PATH, "statistical_model/R/profile.R", sep = ""))
source(paste(ROOT_PATH, "statistical_model/R/io.R", sep = ""))
P <- rac_profile(root = ROOT_PATH)
CONTOUR_ALGORITHM <- "Active_Contour"
IMAGE_NUMBER <- "171"
# 171/ 135
MODEL_FEATURE <- rac_model_feature()
# Options: "NEW_X_NS_XY", "CML_MODEL" (environment variable RAC_MODEL_FEATURE)

N_CONTROLS <- P$r$n_controls  # number of control pixels sampled per shoe in case-control design

# Shoe-specific offset for case-control design (replaces old hardcoded log(0.005))
# offset_i = log(N_CONTROLS / contact_pixels_i), averaged across shoes for grid predictions
SHOE_PIXEL_COUNTS_FILE <- rac_path(P, "pixel_counts")
if (file.exists(SHOE_PIXEL_COUNTS_FILE)) {
  shoe_pixel_counts <- read.csv(SHOE_PIXEL_COUNTS_FILE)
  MEAN_OFFSET <- mean(log(N_CONTROLS / shoe_pixel_counts$pixel_count))
} else if (!is.null(P$r$mean_offset_fallback_pixels)) {
  warning(basename(SHOE_PIXEL_COUNTS_FILE), " not found — run dataCC_1.Rmd first.")
  MEAN_OFFSET <- log(N_CONTROLS / P$r$mean_offset_fallback_pixels)  # fallback using Naomi's average (OLD only)
} else {
  # no silent OLD fallback for another dataset (decision A-021)
  warning(basename(SHOE_PIXEL_COUNTS_FILE), " not found — run dataCC_1.Rmd ",
          "first; MEAN_OFFSET is NA for the ", P$dataset, " dataset.")
  MEAN_OFFSET <- NA_real_
}
