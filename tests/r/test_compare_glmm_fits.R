# tests/lib/compare_glmm_fits.R (decision A-065): the field-by-field GLMM
# comparison used by tests/legacy/run_windows_r_step3.sh.
# Run from anywhere: Rscript tests/r/test_compare_glmm_fits.R
# Every comparison reads its two files fresh (see the note on resp$mu in
# compare_glmm_fits.R). Writes only to R's session temp folder.
suppressMessages(library(lme4))
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
lib <- file.path(root, "tests", "lib", "compare_glmm_fits.R")
source(lib)
pass <- function(name) cat("PASS", name, "\n")
glmm <- file.path(root, "saved_models", "NEW_X_NS_XY.rds")

# Changed copies, each made from a fresh read and saved before any lme4
# call touches it.
changed_copy <- function(change) {
  g <- change(readRDS(glmm))
  f <- tempfile(fileext = ".rds")
  saveRDS(g, f)
  f
}
f_beta <- changed_copy(function(g) {
  g@beta[1] <- g@beta[1] + 1e-12
  g
})
f_hess <- changed_copy(function(g) {
  h <- g@optinfo$derivs$Hessian
  h[2, 2] <- h[2, 2] * (1 + 1e-9)
  g@optinfo$derivs$Hessian <- h
  g
})

stopifnot(!identical(readRDS(glmm), readRDS(glmm)))  # why field by field
tab <- compare_glmm_files(glmm, glmm)
stopifnot(nrow(tab) == 27, all(tab$same))
pass("committed GLMM vs a second read of it: 27 of 27 fields the same")

differing <- function(f) {
  t <- compare_glmm_files(glmm, f)
  t$field[!t$same]
}
stopifnot(identical(differing(f_beta), c("beta", "fixef")))
pass("an intercept changed by 1e-12: exactly beta and fixef differ")
stopifnot(identical(differing(f_hess), c("optinfo", "vcov")))
pass(paste("a stored Hessian entry changed: optinfo and the default vcov",
           "differ, the RX vcov does not"))

rscript <- file.path(R.home("bin"), "Rscript")
cli <- function(x, y) {
  out <- suppressWarnings(system2(rscript, shQuote(c(lib, x, y)),
                                  stdout = TRUE, stderr = TRUE))
  s <- attr(out, "status")
  list(status = if (is.null(s)) 0L else s, out = out)
}
same <- cli(glmm, glmm)
diff1 <- cli(glmm, f_beta)
stopifnot(same$status == 0, any(same$out == "RESULT 27 of 27 fields the same"),
          diff1$status == 1,
          any(diff1$out == "RESULT 25 of 27 fields the same"))
pass("CLI: exit 0 for the same fit, 1 (25 of 27 the same) for the changed one")
cat("ALL PASS test_compare_glmm_fits\n")
