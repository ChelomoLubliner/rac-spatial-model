# t5_model_summary.R: the four NEW fits of T5 side by side (step 3 and the
# OLD-basis refits of A-112), for the results document.
#
# Writes <new>/model_summary_new.csv: one row per term (the intercept, then
# the 24 terms x<j>:y<i> of ns(new_x):ns(y), new_x varying fastest), the
# estimate and standard error of each fit (GLMM: fixef, RX vcov, the only
# one lme4 1.1-38 stores here; CML: coef, vcov), and prints each fit's
# summary numbers (convergence, sigma^2, logLik, basis).
#
# Usage (repo root): Rscript docs/qa/T5/probes/t5_model_summary.R NEW_DIR
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1)
suppressMessages({
  library(lme4)
  library(survival)
})
root <- normalizePath(".")
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
source(file.path(root, "statistical_model", "R", "compare.R"))
source(file.path(root, "statistical_model", "R", "wald.R"))
P <- rac_profile("new", root = ROOT_PATH)
terms <- c("(Intercept)", sprintf("x%d:y%d", rep(1:4, 6), rep(1:6, each = 4)))
out <- data.frame(term = terms)
for (f in c("NEW_X_NS_XY", "CML_MODEL", "NEW_X_NS_XY_oldbasis",
            "CML_MODEL_oldbasis")) {
  m <- readRDS(rac_model_path(P, f))
  b <- basis_of(m)
  w <- wald_all_spatial(m, use_car = FALSE)
  if (inherits(m, "merMod")) {
    est <- unname(fixef(m))
    se <- sqrt(diag(as.matrix(vcov(m, use.hessian = FALSE))))
    cat(sprintf(paste("%s: conv %d, lme4 messages %s, sigma^2 %.7f,",
                      "logLik %.4f, nobs %d, groups %d, Wald W %.4f (df %d)\n"),
                f, m@optinfo$conv$opt,
                if (is.null(m@optinfo$conv$lme4$messages)) "none" else "yes",
                as.numeric(VarCorr(m)$shoe), as.numeric(logLik(m)), nobs(m),
                ngrps(m), w$W, w$df))
  } else {
    est <- c(NA, unname(coef(m)))
    se <- c(NA, sqrt(diag(vcov(m))))
    cat(sprintf(paste("%s: method %s, iterations %d, loglik %.4f -> %.4f,",
                      "n %d, events %d, Wald W %.4f (df %d)\n"),
                f, m$method, m$iter, m$loglik[1], m$loglik[2], m$n,
                m$nevent, w$W, w$df))
  }
  cat("  knots new_x", sprintf("%.7f", b$knots_x), "| y",
      sprintf("%.7f", b$knots_y), "| boundary new_x",
      sprintf("%.7f", b$bknots_x), "| y", sprintf("%.7f", b$bknots_y), "\n")
  out[[paste(f, "est", sep = "_")]] <- signif(est, 10)
  out[[paste(f, "se", sep = "_")]] <- signif(unname(se), 10)
}
path <- file.path(args[1], "model_summary_new.csv")
utils::write.csv(out, path, row.names = FALSE)
cat("written", path, "\n")
