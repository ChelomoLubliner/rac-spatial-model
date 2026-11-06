# fit_oldbasis_new.R: the NEW models refitted on the OLD spline basis (T5,
# decision A-112; plan section 5, "T6 common-basis refits").
#
# Usage (repo root): Rscript tools/fit_oldbasis_new.R NEW_X_NS_XY|CML_MODEL
#
# Step 3 fits each dataset on its own knots (quantiles of its own new_x and
# y) and boundary knots (its own range), so the NEW and OLD coefficients
# are not comparable. This refits the NEW case-control data
# (processed_data/new/dataCC_distance_new.csv) with the knots and boundary
# knots of the OLD data (processed_data/dataCC_distance.csv, the knots step
# 3 computes; they must equal, within 1e-12, the basis stored in the
# committed OLD model of the same feature) and writes
# saved_models/new/<feature>_oldbasis_new.rds (the NEW profile's models
# folder; user rule 1). NEW rows beyond the OLD
# boundary knots (linear extrapolation of ns) are counted and printed.
# Reads only; writes only that model. Refuses RAC_DATASET=old: there is
# nothing to refit for OLD.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1 || !args[1] %in% c("NEW_X_NS_XY", "CML_MODEL")) {
  stop("usage: Rscript tools/fit_oldbasis_new.R NEW_X_NS_XY|CML_MODEL",
       call. = FALSE)
}
feature <- args[1]
root <- normalizePath(".")
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
source(file.path(root, "statistical_model", "R", "compare.R"))
if (!identical(rac_env("RAC_DATASET", "new"), "new")) {
  stop("fit_oldbasis_new.R refits the NEW data only (RAC_DATASET must be ",
       "new or unset)", call. = FALSE)
}
suppressMessages({
  library(splines)
  library(lme4)
  library(survival)
})
P_old <- rac_profile("old", root = ROOT_PATH)
P_new <- rac_profile("new", root = ROOT_PATH)
out <- rac_model_path(P_new, paste(feature, "_oldbasis", sep = ""))
rac_ensure_dir(out)

cols <- c("n_Acc", "x", "y", "shoe", "row_number", "horiz_dist", "new_x")
old <- subset(read.csv(rac_path(P_old, "dataCC_distance"), header = TRUE),
              select = cols)
new <- subset(read.csv(rac_path(P_new, "dataCC_distance"), header = TRUE),
              select = cols)
b <- basis_knots(old)
committed <- basis_of(readRDS(rac_model_path(P_old, feature)))
# (the committed GLMM was fitted by the Windows R 4.4.3, whose CSV parser
# may differ from this R in the last bit of a few values, plan F51)
d <- max(abs(unlist(b) - unlist(committed)))
cat("OLD basis from the OLD CSV; identical() to the committed", feature,
    "model's basis:", identical(b, committed), "; max |difference|:", d, "\n")
stopifnot(d <= 1e-12)
str(b)
beyond_x <- new$new_x < b$bknots_x[1] | new$new_x > b$bknots_x[2]
beyond_y <- new$y < b$bknots_y[1] | new$y > b$bknots_y[2]
cat(sprintf(paste("NEW rows beyond the OLD boundary knots: new_x %d (%.3f%%),",
                  "y %d (%.3f%%), either %d (%.3f%%) of %d; cases among them",
                  "%d\n"),
            sum(beyond_x), 100 * mean(beyond_x), sum(beyond_y),
            100 * mean(beyond_y), sum(beyond_x | beyond_y),
            100 * mean(beyond_x | beyond_y), nrow(new),
            sum(new$n_Acc[beyond_x | beyond_y])))
set.seed(P_new$r$seed)
t0 <- Sys.time()
fit <- fit_common_basis(new, b$knots_x, b$knots_y, b$bknots_x, b$bknots_y,
                        feature)
secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
stopifnot(identical(basis_of(fit), b))
saveRDS(fit, file = out)
cat(sprintf("fitted %s on the OLD basis in %.1f s; written %s\n", feature,
            secs, out))
if (feature == "NEW_X_NS_XY") {
  cat("convergence code:", fit@optinfo$conv$opt, "\n")
  msgs <- fit@optinfo$conv$lme4$messages
  cat("lme4 messages:", if (is.null(msgs)) "none" else msgs, "\n")
  cat(sprintf("sigma^2 = %.7f, logLik = %.4f, nobs = %d, groups = %d\n",
              as.numeric(VarCorr(fit)$shoe), as.numeric(logLik(fit)),
              nobs(fit), ngrps(fit)))
  print(fixef(fit), digits = 7)
} else {
  cat(sprintf("iterations %d, loglik %.4f -> %.4f, n = %d, events = %d\n",
              fit$iter, fit$loglik[1], fit$loglik[2], fit$n, fit$nevent))
  print(coef(fit), digits = 7)
}
