# compare_dumps() of tests/lib/compare_models.R (T1 review, finding 10.1)
# and its CLI exit status (T1 review 2, engineering finding 1; A-069).
# Run from anywhere: Rscript tests/r/test_compare_models.R
# A dump compared with itself gives identical rows for every field, and a
# field that is present in only one of the two dumps is an error (the old
# intersect() silently skipped it, so a live check could pass with a field
# missing). The CLI exits 1 for any field that is not identical(), also a
# NaN, a length change or a changed character field (the old exit status
# counted only rows with a numeric max |a - b|, so all of these exited 0).
# Reads the Tier A and Tier B dumps; writes only to R's session temp folder.
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
source(file.path(root, "tests", "lib", "compare_models.R"))
pass <- function(name) cat("PASS", name, "\n")
error_of <- function(expr) {
  tryCatch({
    expr
    "no error"
  }, error = function(e) conditionMessage(e))
}

ta <- readRDS(file.path(root, "tests", "baseline", "models_committed.rds"))
tb <- readRDS(file.path(root, "tests", "baseline", "local", "models_local.rds"))
stopifnot(length(ta) == 22, identical(names(ta), names(tb)))

self <- compare_dumps(ta, ta)
stopifnot(identical(self$field, names(ta)), all(self$identical),
          all(self$all_equal_tol0))
pass("a dump compared with itself: 22 fields, all identical")

ab <- compare_dumps(ta, tb)
glmm_numeric <- c("fixef", "vcov", "vcov_rx", "theta", "sigma2", "varcorr",
                  "loglik", "deviance", "wald_glmm", "wald_glmm_rx")
stopifnot(identical(ab$field, names(ta)),
          identical(ab$field[!ab$identical], glmm_numeric))
pass(sprintf(paste("Tier A vs Tier B: all 22 fields compared; the %d that",
                   "differ are the GLMM estimates (T1 section 5.3)"),
             length(glmm_numeric)))

e1 <- error_of(compare_dumps(ta, tb[setdiff(names(tb), "vcov_rx")]))
e2 <- error_of(compare_dumps(ta[setdiff(names(ta), "varcorr")], tb))
e3 <- error_of(compare_dumps(c(ta, list(extra = 1)), tb))
stopifnot(grepl("only in a: vcov_rx; only in b: $", e1),
          grepl("only in a: ; only in b: varcorr$", e2),
          grepl("only in a: extra;", e3))
pass("a field missing from either dump, or an extra field, is an error")

# The CLI exit status: 0 only if every field is identical().
lib <- file.path(root, "tests", "lib", "compare_models.R")
rscript <- file.path(R.home("bin"), "Rscript")
ta_path <- file.path(root, "tests", "baseline", "models_committed.rds")
cli <- function(b) {
  f <- tempfile(fileext = ".rds")
  saveRDS(b, f)
  out <- suppressWarnings(system2(rscript, shQuote(c(lib, ta_path, f)),
                                  stdout = TRUE, stderr = TRUE))
  s <- attr(out, "status")
  list(status = if (is.null(s)) 0L else s,
       n_false = sum(grepl("identical=FALSE", out, fixed = TRUE)))
}
all_nan <- ta
for (f in glmm_numeric) all_nan[[f]][] <- NaN
cases <- list(
  same = list(ta, 0L, 0L),
  nan_fixef = list(within(ta, fixef[1] <- NaN), 1L, 1L),
  short_fixef = list(within(ta, fixef <- fixef[-1]), 1L, 1L),
  optimizer = list(within(ta, optimizer <- "bobyqa"), 1L, 1L),
  cml_method = list(within(ta, cml_method <- "breslow"), 1L, 1L),
  all_glmm_nan = list(all_nan, 1L, 10L),
  tier_b = list(tb, 1L, 10L))
for (n in names(cases)) {
  r <- cli(cases[[n]][[1]])
  if (r$status != cases[[n]][[2]] || r$n_false != cases[[n]][[3]]) {
    stop(sprintf("CLI case %s: exit %d with %d rows FALSE (want %d, %d)", n,
                 r$status, r$n_false, cases[[n]][[2]], cases[[n]][[3]]))
  }
}
pass(paste("CLI: exit 0 for the same dump; exit 1 for a NaN, a shorter",
           "fixef, a changed optimizer or cml_method, all GLMM fields NaN,",
           "and Tier B"))
cat("ALL PASS test_compare_models\n")
