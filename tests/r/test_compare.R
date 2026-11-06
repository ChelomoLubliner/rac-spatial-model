# statistical_model/R/compare.R, the T5 part of the plan's T6 interface
# (decisions A-112, A-118; T6 adds its own checks to this file).
#
# 1. spatial_term_key(): the coefficients of every committed model, OLD
#    (step 3) and NEW (step 3 and the OLD-basis refits of A-112), map to
#    "(Intercept)" (GLMM only) then x1:y1, x2:y1, ..., x4:y6 (new_x varying
#    fastest), so their positions agree; any other name is refused.
# 2. fit_common_basis() refuses data with a column named bx or by (it would
#    replace the basis in the formula).
# 3. fit_common_basis() with the data's own basis is step 3 itself: on a
#    subsample of NEW shoes (the 20 codes picked with set.seed(20) from the
#    shoes with at most 25 cases, so that the fits stay fast: the check is
#    one of code, deterministic, so a small sample suffices), step 3's
#    own Random() (evaluated from re_model_shoe_std_3.Rmd, its save
#    redirected to a temporary file) and fit_common_basis(basis_knots())
#    give identical() fixed effects, theta and vcov (GLMM) and identical()
#    coefficients and vcov (CML), with the same keys; basis_of() reads back
#    basis_knots() from both.
# Writes only below tempdir().
#
# Run from anywhere:  Rscript tests/r/test_compare.R
suppressMessages({
  library(splines)
  library(lme4)
  library(survival)
})
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "compare.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
pass <- function(name) cat("PASS", name, "\n")
P_old <- rac_profile("old", root = ROOT_PATH)
P_new <- rac_profile("new", root = ROOT_PATH)

# --- 1. the keys of every committed model ---------------------------------------
keys <- paste("x", rep(1:4, 6), ":y", rep(1:6, each = 4), sep = "")
coef_names <- function(m) {
  if (inherits(m, "merMod")) names(fixef(m)) else names(coef(m))
}
models <- c(rac_model_path(P_old, "NEW_X_NS_XY"),
            rac_model_path(P_old, "CML_MODEL"),
            rac_model_path(P_new, "NEW_X_NS_XY"),
            rac_model_path(P_new, "CML_MODEL"),
            rac_model_path(P_new, "NEW_X_NS_XY_oldbasis"),
            rac_model_path(P_new, "CML_MODEL_oldbasis"))
for (path in models) {
  m <- readRDS(path)
  want <- if (inherits(m, "merMod")) c("(Intercept)", keys) else keys
  stopifnot(identical(spatial_term_key(coef_names(m)), want))
}
rm(m)
invisible(gc())
bad <- tryCatch(spatial_term_key(c("x1:y1", "bx1")), error = function(e) e)
stopifnot(inherits(bad, "error"), grepl("bx1", conditionMessage(bad)),
          identical(spatial_term_key("x1:y1"), "x1:y1"))
pass(sprintf(paste("spatial_term_key: the %d committed models (OLD and NEW",
                   "step 3, the OLD-basis refits) all map to (Intercept),",
                   "x1:y1 ... x4:y6 in the same positions; other names",
                   "refused"), length(models)))

# --- 2. the clash check ------------------------------------------------------------
d <- read.csv(rac_path(P_new, "dataCC_distance"), header = TRUE)
d <- subset(d, select = c("n_Acc", "x", "y", "shoe", "row_number",
                          "horiz_dist", "new_x"))
b <- basis_knots(d)
for (clash in c("bx", "by")) {
  dd <- d[d$shoe <= 2, ]
  dd[[clash]] <- 0
  e <- tryCatch(fit_common_basis(dd, b$knots_x, b$knots_y, b$bknots_x,
                                 b$bknots_y, "CML_MODEL"),
                error = function(e) e)
  stopifnot(inherits(e, "error"), grepl("bx or by", conditionMessage(e)))
}
pass("fit_common_basis refuses data with a column named bx or by")

# --- 3. fit_common_basis() = step 3 on a subsample ----------------------------------
n_case <- tapply(d$n_Acc, d$shoe, sum)
set.seed(20)
pick <- sort(sample(as.integer(names(n_case)[n_case <= 25]), 20))
sub <- d[d$shoe %in% pick, ]
code <- tempfile(fileext = ".R")
invisible(knitr::purl(file.path(root, "statistical_model",
                                "re_model_shoe_std_3.Rmd"),
                      output = code, documentation = 0, quiet = TRUE))
exprs <- parse(code)
k <- which(vapply(exprs, function(e) {
  is.call(e) && identical(e[[1]], as.name("<-")) &&
    identical(e[[2]], as.name("Random"))
}, TRUE))
stopifnot(length(k) == 1)
step3 <- new.env()
step3$model_out <- tempfile(fileext = ".rds")
eval(exprs[[k]], envir = step3)
bs <- basis_knots(sub)
t0 <- proc.time()[["elapsed"]]
s3 <- utils::capture.output(
  g3 <- step3$Random(dat = sub, model_feat = "NEW_X_NS_XY"))
gc_ <- fit_common_basis(sub, bs$knots_x, bs$knots_y, bs$bknots_x,
                        bs$bknots_y, "NEW_X_NS_XY")
stopifnot(identical(unname(fixef(g3)), unname(fixef(gc_))),
          identical(getME(g3, "theta"), getME(gc_, "theta")),
          identical(unname(as.matrix(vcov(g3))), unname(as.matrix(vcov(gc_)))),
          identical(spatial_term_key(names(fixef(g3))),
                    spatial_term_key(names(fixef(gc_)))),
          identical(basis_of(g3), bs), identical(basis_of(gc_), bs))
s3 <- utils::capture.output(
  c3 <- step3$Random(dat = sub, model_feat = "CML_MODEL"))
cc_ <- fit_common_basis(sub, bs$knots_x, bs$knots_y, bs$bknots_x,
                        bs$bknots_y, "CML_MODEL")
stopifnot(identical(unname(coef(c3)), unname(coef(cc_))),
          identical(unname(vcov(c3)), unname(vcov(cc_))),
          identical(c3$method, "exact"), identical(cc_$method, "exact"),
          identical(spatial_term_key(names(coef(c3))),
                    spatial_term_key(names(coef(cc_)))),
          identical(basis_of(c3), bs), identical(basis_of(cc_), bs))
unlink(c(code, step3$model_out))
pass(sprintf(paste("fit_common_basis with the data's own basis = step 3's",
                   "Random() on %d NEW shoes (%d rows, %d cases): GLMM fixef,",
                   "theta, vcov and CML coef, vcov identical(), same keys",
                   "(%.1f s)"),
             length(pick), nrow(sub), sum(sub$n_Acc),
             proc.time()[["elapsed"]] - t0))
cat("ALL PASS test_compare\n")
