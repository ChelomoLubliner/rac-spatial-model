# An OLD step run in place refuses before it writes anything (decisions
# A-075, A-082; T2 review, reproducibility finding 1).
#
# Steps 3-6 never overwrite a committed OLD model or figure: each checks all
# its protected outputs with rac_new_output() at its start, before it reads
# the data or writes any file, so an in-place OLD knit stops at once and
# leaves every file as it was. Before the fix, step 5 wrote
# processed_data/wald_test.csv and only then reached the guard of its first
# figure. This test copies the real step code, the profile file, the OLD
# inputs of steps 3-6, the committed models and the committed figures into
# a temporary root without wald_test.csv, renders each step there with
# RAC_DATASET=old (steps 3 and 4 once per model), and checks for each knit:
# a non-zero exit, the refusal message in its log, and no file of the root
# created, changed or deleted (so no wald_test.csv). The knit's own files go
# to a folder outside the root. Writes only below tempdir().
#
# Run from anywhere:  Rscript tests/r/test_output_guards.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
pass <- function(name) cat("PASS", name, "\n")

tmp <- tempfile("guards_")
rt <- file.path(tmp, "root")
knit_dir <- file.path(tmp, "knit")
dir.create(file.path(rt, "statistical_model", "R"), recursive = TRUE)
dir.create(knit_dir)
copy <- function(rel) {
  dir.create(dirname(file.path(rt, rel)), recursive = TRUE,
             showWarnings = FALSE)
  stopifnot(file.copy(file.path(root, rel), file.path(rt, rel),
                      copy.date = TRUE))
}
sm <- c(list.files(file.path(root, "statistical_model"),
                   pattern = "\\.(Rmd|R)$"),
        file.path("R", list.files(file.path(root, "statistical_model", "R"))))
for (f in file.path("statistical_model", sm)) copy(f)
copy(file.path("config", "datasets.json"))
# The OLD inputs of steps 3-6 and their committed outputs, read from the
# OLD profile (so the test follows the profile, not literals)
inputs <- c("dataCC_distance", "pixel_counts", "all_cont", "prototype_mask",
            "prototype_contour")
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
P <- rac_profile("old", root = ROOT_PATH)
rel <- function(p) substring(p, nchar(ROOT_PATH) + 1)
for (k in inputs) copy(rel(rac_path(P, k)))
models <- c("NEW_X_NS_XY", "CML_MODEL")
figures <- c("NEW_X_NS_XY_SHOE", "CML_MODEL_SHOE", "CI_shoe_cuts",
             "CI_cut_110", "CI_cut_190", "CI_cut_250", "pixel_inten_JASAup",
             "difference_random_cml")
for (f in models) copy(rel(rac_model_path(P, f)))
for (s in figures) copy(rel(rac_image_path(P, s)))
wald_rel <- rel(rac_path(P, "wald_test"))
stopifnot(!file.exists(file.path(rt, wald_rel)))

state <- function() {
  f <- list.files(rt, recursive = TRUE, all.files = TRUE)
  i <- file.info(file.path(rt, f))
  paste(f, i$size, format(i$mtime, "%Y-%m-%d %H:%M:%OS6"))
}

# Render one step in the root; returns the exit status and the log.
render <- function(rmd, feature) {
  log <- file.path(tmp, paste(sub("\\.Rmd$", "", rmd), feature, "log",
                              sep = "."))
  code <- paste("a <- commandArgs(trailingOnly = TRUE);",
                "rmarkdown::render(a[1], knit_root_dir = a[2],",
                "output_dir = a[3], intermediates_dir = a[3],",
                "envir = new.env(), quiet = TRUE)")
  smd <- file.path(rt, "statistical_model")
  status <- system2("Rscript", c("-e", shQuote(code), file.path(smd, rmd), smd,
                                 knit_dir),
                    env = c("RAC_DATASET=old", "RAC_PROFILE_FILE=",
                            paste("RAC_MODEL_FEATURE=", feature, sep = ""),
                            "RGL_USE_NULL=TRUE"),
                    stdout = log, stderr = log)
  list(status = status, log = readLines(log))
}

runs <- list(c("re_model_shoe_std_3.Rmd", "NEW_X_NS_XY"),
             c("re_model_shoe_std_3.Rmd", "CML_MODEL"),
             c("shoe_std_results_4.Rmd", "NEW_X_NS_XY"),
             c("shoe_std_results_4.Rmd", "CML_MODEL"),
             c("statistical_tests_5.Rmd", "NEW_X_NS_XY"),
             c("model_comparison_6.Rmd", "NEW_X_NS_XY"))
for (r in runs) {
  before <- state()
  t0 <- proc.time()[["elapsed"]]
  k <- render(r[1], r[2])
  secs <- proc.time()[["elapsed"]] - t0
  refused <- grepl("refusing to overwrite the committed OLD output", k$log,
                   fixed = TRUE)
  after <- state()
  if (k$status == 0 || !any(refused)) writeLines(tail(k$log, 15))
  if (!identical(after, before)) {
    cat("changed in the root (- before, + after; path size mtime):\n")
    for (x in setdiff(before, after)) cat("  -", x, "\n")
    for (x in setdiff(after, before)) cat("  +", x, "\n")
  }
  stopifnot(k$status != 0, any(refused), identical(after, before),
            !file.exists(file.path(rt, wald_rel)))
  pass(sprintf("%s (%s): refused in %.1f s, no file of the root changed",
               r[1], r[2], secs))
}
unlink(tmp, recursive = TRUE)
cat("ALL PASS test_output_guards\n")
