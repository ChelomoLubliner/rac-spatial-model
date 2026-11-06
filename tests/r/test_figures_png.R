# tools/figures_png.R draws the PNG twins of the step 4-6 figures with the
# Rmds' own code (decision A-111).
#
# 1. OLD, step 6 only, into a temporary folder: exactly the two PNGs of
#    step 6 are written (pixel_inten_JASAup.png, difference_random_cml.png),
#    each 8 x 8 inches at 150 dpi (1200 x 1200 px, the size of the PDF), and
#    nothing else: the committed OLD figures and the step-5 CSV are neither
#    refused nor rewritten (their bytes and modification times unchanged).
# 2. The namespace rule: NEW into a folder that is not named new, and OLD
#    into a folder named new, stop with an error before anything is drawn.
# Writes only below tempdir().
#
# Run from anywhere:  Rscript tests/r/test_figures_png.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
pass <- function(name) cat("PASS", name, "\n")
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
P <- rac_profile("old", root = ROOT_PATH)
tool <- file.path(root, "tools", "figures_png.R")
run_tool <- function(dataset, out, steps = "6") {
  system2("Rscript", c(shQuote(tool), shQuote(out), "--steps", steps),
          env = c(paste("RAC_DATASET=", dataset, sep = ""),
                  "RGL_USE_NULL=TRUE"),
          stdout = FALSE, stderr = FALSE)
}
png_size <- function(f) {
  b <- readBin(f, "raw", 24)
  stopifnot(identical(b[1:8], as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a,
                                       0x1a, 0x0a))))
  to_int <- function(x) sum(as.integer(x) * 256^(3:0))
  c(width = to_int(b[17:20]), height = to_int(b[21:24]))
}

# 1. OLD step 6
protected <- c(rac_image_path(P, "pixel_inten_JASAup"),
               rac_image_path(P, "difference_random_cml"),
               rac_path(P, "wald_test"))
before <- data.frame(md5 = tools::md5sum(protected),
                     mtime = file.mtime(protected))
out <- tempfile("figures_png_old_")
old_wd <- setwd(root)
st <- run_tool("old", out)
setwd(old_wd)
stopifnot(st == 0)
written <- sort(list.files(out))
stopifnot(identical(written, c("difference_random_cml.png",
                               "pixel_inten_JASAup.png")))
for (f in written) {
  stopifnot(identical(unname(png_size(file.path(out, f))), c(1200, 1200)))
}
after <- data.frame(md5 = tools::md5sum(protected),
                    mtime = file.mtime(protected))
stopifnot(identical(before, after))
unlink(out, recursive = TRUE)
pass(paste("OLD step 6: exactly its two PNGs, 1200 x 1200 px; the committed",
           "OLD figures and the step-5 CSV untouched"))

# 2. the namespace rule
setwd(root)
bad_new <- run_tool("new", tempfile("figures_png_newbad_"))
bad_old <- run_tool("old", file.path(tempfile("figures_png_oldbad_"), "new"))
setwd(old_wd)
stopifnot(bad_new != 0, bad_old != 0)
pass("NEW outside a new folder and OLD inside one are refused")
cat("ALL PASS test_figures_png\n")
