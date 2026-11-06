# figures_png.R: PNG twins of the figures of steps 4, 5 and 6, for viewing
# in the docs (plan section 5, "map PNGs for viewing"; T5, decision A-111).
#
# Usage (repo root):
#   RAC_DATASET=old|new Rscript tools/figures_png.R OUT_DIR [--steps 4,5,6]
#
# This machine has no PDF rasterizer (no pdftoppm, gs, magick; R pdftools
# and magick are not installed), so the PNGs are drawn, not converted: the
# code of statistical_model/shoe_std_results_4.Rmd (once per model),
# statistical_tests_5.Rmd and model_comparison_6.Rmd is extracted with
# knitr::purl and evaluated unchanged, from statistical_model/, in an
# environment where
#   - pdf(file, height, width) opens png(OUT_DIR/<name>.png) of the same
#     size in inches at 150 dpi instead (<name> = the PDF's file name
#     without .pdf, so model_images/new/CI_cut_110_new.pdf gives
#     CI_cut_110_new.png);
#   - rac_new_output(P, path) returns path without checking or creating it,
#     so a committed OLD figure is neither refused nor written;
#   - rac_write_csv() writes nothing (step 5's Wald CSV is not rewritten);
#   - the plots drawn before pdf() go to a null device.
# So a PNG shows what the PDF of the same code shows, from the models and
# CSVs of the dataset's profile (for OLD: the committed models). Nothing is
# written outside OUT_DIR. OUT_DIR must be a NEW folder for NEW (a folder
# named new, user rule 1) and must not be one for OLD.
args <- commandArgs(trailingOnly = TRUE)
steps <- c(4, 5, 6)
if (length(args) >= 3 && args[2] == "--steps") {
  steps <- as.numeric(strsplit(args[3], ",", fixed = TRUE)[[1]])
  args <- args[1]
}
if (length(args) != 1 || !all(steps %in% c(4, 5, 6))) {
  stop("usage: RAC_DATASET=old|new Rscript tools/figures_png.R OUT_DIR ",
       "[--steps 4,5,6]", call. = FALSE)
}
root <- normalizePath(".")
if (!file.exists(file.path(root, "statistical_model", "config.R"))) {
  stop("run from the repository root", call. = FALSE)
}
out_dir <- normalizePath(args[1], mustWork = FALSE)
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
P0 <- rac_profile(root = ROOT_PATH)
in_new <- "new" %in% strsplit(out_dir, "/", fixed = TRUE)[[1]]
if (P0$dataset != "old" && !in_new) {
  stop("OUT_DIR of the ", P0$dataset, " figures must lie in a folder named ",
       "new (user rule 1): ", out_dir, call. = FALSE)
}
if (P0$dataset == "old" && in_new) {
  stop("OUT_DIR of the OLD figures lies in a NEW folder: ", out_dir,
       call. = FALSE)
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(RGL_USE_NULL = "TRUE")

png_env <- function(out_dir) {
  e <- new.env(parent = globalenv())
  e$pdf <- function(file, height, width, ...) {
    f <- file.path(out_dir, sub("\\.pdf$", ".png", basename(file)))
    grDevices::png(f, width = width, height = height, units = "in",
                   res = 150)
    cat("png:", f, "\n")
    invisible(NULL)
  }
  e$rac_new_output <- function(P, path) path
  e$rac_write_csv <- function(x, P, key) invisible(NULL)
  e
}

run_rmd <- function(rmd, feature) {
  code <- tempfile(fileext = ".R")
  on.exit(unlink(code))
  knitr::purl(file.path(root, "statistical_model", rmd), output = code,
              documentation = 0, quiet = TRUE)
  Sys.setenv(RAC_MODEL_FEATURE = feature)
  old_wd <- setwd(file.path(root, "statistical_model"))
  on.exit(setwd(old_wd), add = TRUE)
  n_dev <- length(grDevices::dev.list())
  grDevices::pdf(file = NULL)  # the null device for the inline plots
  sys.source(code, envir = png_env(out_dir))
  while (length(grDevices::dev.list()) > n_dev) grDevices::dev.off()
  cat(rmd, feature, "done\n")
}

if (4 %in% steps) {
  run_rmd("shoe_std_results_4.Rmd", "NEW_X_NS_XY")
  run_rmd("shoe_std_results_4.Rmd", "CML_MODEL")
}
if (5 %in% steps) run_rmd("statistical_tests_5.Rmd", "NEW_X_NS_XY")
if (6 %in% steps) run_rmd("model_comparison_6.Rmd", "NEW_X_NS_XY")
cat("figures_png: done (", P0$dataset, ", steps ",
    paste(steps, collapse = ","), ") -> ", out_dir, "\n", sep = "")
