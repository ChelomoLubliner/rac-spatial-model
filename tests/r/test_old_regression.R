# OLD regression of the R steps (T1): Tier B (the unmodified Rmds re-run on
# this machine, tests/baseline/local/) against Tier A (the files committed
# at 79247d8, tests/baseline/), and optionally a new rerun against Tier B.
#
# Run from anywhere:  Rscript tests/r/test_old_regression.R
# Live rerun check:   RAC_REGRESS_R_RUN=<run folder of
#   tests/legacy/run_legacy_r.sh or tests/regress_old.sh> Rscript ...
#   (its repo/ copy must hold the regenerated CSVs and models).
#
# What T1 established (docs/tests/T1-baseline-results.md):
#  - step-1 CSVs: same content as Tier A, LF instead of CRLF (R on Linux);
#    converted to CRLF they equal the committed bytes;
#  - step-2 CSVs: byte-identical to Tier A;
#  - CML: identical() to Tier A in every field;
#  - GLMM: NOT identical to Tier A on this machine (R 4.3.3, lme4 1.1.38,
#    Matrix 1.6.5 vs the committed R 4.4.3, lme4 1.1-37, Matrix 1.7-2; the
#    committed model is reproduced bit for bit by that Windows R). The
#    differences are pinned below at the values measured in T1, so any
#    change shows up; on this machine reruns must equal Tier B exactly.
suppressMessages({
  library(lme4)
  library(survival)
})
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
source(file.path(root, "tests", "lib", "dump_models.R"))
source(file.path(root, "tests", "lib", "compare_models.R"))
p <- function(...) file.path(root, ...)
pass <- function(name) cat("PASS", name, "\n")

read_sums <- function(path) {
  x <- readLines(path)
  data.frame(sha = substr(x, 1, 64), name = substring(x, 67),
             stringsAsFactors = FALSE)
}
sha_file <- function(path) digest::digest(file = path, algo = "sha256")

tier_a <- read_sums(p("tests", "baseline", "committed_79247d8.sha256"))
tier_b <- read_sums(p("tests", "baseline", "local", "r_outputs.sha256"))
a_sha <- setNames(tier_a$sha, tier_a$name)
b_sha <- setNames(tier_b$sha, tier_b$name)

# 1. CSVs: step 2 byte-identical, step 1 identical after LF -> CRLF.
step2 <- c("processed_data/dataCC_distance_temp.csv",
           "processed_data/dataCC_distance.csv")
step1 <- c("data/all_cont.csv", "processed_data/dataCC.csv",
           "processed_data/shoe_pixel_counts.csv")
stopifnot(identical(unname(b_sha[step2]), unname(a_sha[step2])))
pass("Tier B step-2 CSVs byte-identical to Tier A")
stopifnot(identical(unname(b_sha[paste(step1, "[LF->CRLF]")]),
                    unname(a_sha[step1])),
          all(unname(b_sha[step1]) != unname(a_sha[step1])))
pass("Tier B step-1 CSVs = Tier A bytes after LF -> CRLF (raw: LF, differ)")

# 2. Models: Tier B vs Tier A.
ta <- readRDS(p("tests", "baseline", "models_committed.rds"))
tb <- readRDS(p("tests", "baseline", "local", "models_local.rds"))
tab <- compare_dumps(ta, tb)
row <- function(f) tab[tab$field == f, ]
cml_fields <- grep("^cml_|^wald_cml$", tab$field, value = TRUE)
stopifnot(all(tab$identical[tab$field %in% cml_fields]))
pass("CML: Tier B identical() to Tier A in every field")
stopifnot(all(tab$identical[tab$field %in% c("nobs", "ngrps", "conv",
                                              "optimizer")]),
          identical(names(ta$fixef), names(tb$fixef)))
pass("GLMM structure identical (nobs, groups, convergence, optimizer, names)")
# max |Tier B - Tier A| per field, measured in T1 (pinned to 1e-6 relative)
known <- c(fixef = 0.0007666407906, vcov = 2.121049215,
           vcov_rx = 8.526166533e-06, theta = 8.579803485e-06,
           sigma2 = 1.681105155e-05, loglik = 1.152649929e-06,
           deviance = 0.001106419797, wald_glmm = 0.9128877846,
           wald_glmm_rx = 0.0130279428)
for (f in names(known)) {
  d <- row(f)$max_abs_diff
  stopifnot(!row(f)$identical, abs(d - known[[f]]) <= 1e-6 * known[[f]])
}
# lme4 1.1-38 stores no Hessian for nobs > 1e4, so Tier B's default vcov is
# the RX one; Tier A's default is the finite-difference Hessian one.
stopifnot(identical(tb$vcov, tb$vcov_rx), !identical(ta$vcov, ta$vcov_rx))
pass(sprintf(paste("GLMM differs from Tier A as recorded in T1: max|dfixef|",
                   "%.3g, W %.4f (Tier A %.4f; RX %.4f), sigma^2 %.8f",
                   "(Tier A %.8f)"),
             row("fixef")$max_abs_diff, tb$wald_glmm, ta$wald_glmm,
             ta$wald_glmm_rx, tb$sigma2, ta$sigma2))

# 3. Optional live rerun: must equal Tier B exactly on this machine.
run <- Sys.getenv("RAC_REGRESS_R_RUN", "")
if (nzchar(run)) {
  rr <- file.path(run, "repo")
  for (f in c(step1, step2)) {
    stopifnot(sha_file(file.path(rr, f)) == b_sha[[f]])
  }
  pass("live rerun: the five CSVs equal Tier B byte for byte")
  tl <- dump_models(file.path(rr, "saved_models", "NEW_X_NS_XY.rds"),
                    file.path(rr, "saved_models", "CML_MODEL.rds"))
  cmp <- compare_dumps(tb, tl)
  stopifnot(all(cmp$identical))
  pass("live rerun: models identical() to Tier B in every field")
} else {
  cat("SKIPPED live rerun check: RAC_REGRESS_R_RUN not set\n")
}
cat("ALL PASS test_old_regression\n")
