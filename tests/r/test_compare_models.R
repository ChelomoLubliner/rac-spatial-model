# compare_dumps() of tests/lib/compare_models.R (T1 review, finding 10.1).
# Run from anywhere: Rscript tests/r/test_compare_models.R
# A dump compared with itself gives identical rows for every field, and a
# field that is present in only one of the two dumps is an error (the old
# intersect() silently skipped it, so a live check could pass with a field
# missing). Reads the Tier A and Tier B dumps; writes nothing.
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
cat("ALL PASS test_compare_models\n")
