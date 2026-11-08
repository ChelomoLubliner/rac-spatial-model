# part2_k8_fits.R: the OLD GLMM refitted on other spline bases, for the
# Part 2 sensitivities (plan section 9, "also reported"; K8, decisions A-027
# and A-119):
#   fulltensor  ns(new_x, the step-3 x knots) * ns(y, the step-3 y knots):
#               main effects + interaction, 35 fixed effects (K8 removed);
#               Laplace, the step-3 optimizer (nlminbwrap);
#   finey       the nested finer y basis of F84 (the 5 step-3 y knots plus
#               the quantiles 1:10/11 of y, 15 interior knots, the same
#               boundary knots) with the step-3 x knots, full tensor, 85
#               fixed effects; fitted with nAGQ = 0 (PIRLS for the fixed
#               effects, the variance by its own optimizer): a Laplace fit
#               of this size did not finish in 2 h 26 min on NEW (F84).
# Both on the committed OLD case-control data. Outputs (OLD only, no suffix):
#   part2_path(P_old, "glmm_fulltensor", "rds"), part2_path(P_old,
#   "glmm_finey", "rds"); each a list with the fit's fixef, vcov, theta,
#   the basis (knots), logLik, convergence code, seconds.
#
# Usage (repository root): Rscript tools/part2_k8_fits.R [fulltensor] [finey]
suppressMessages({
  library(splines)
  library(lme4)
})
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "io.R", "compare.R", "validation.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
which_fits <- commandArgs(TRUE)
if (!length(which_fits)) which_fits <- c("fulltensor", "finey")
P <- rac_profile("old", root = ROOT_PATH)
model <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
b3 <- part2_basis(model)
dat <- read.csv(rac_path(P, "dataCC_distance"))
dat <- dat[, c("n_Acc", "new_x", "y", "shoe")]
dat$shoe <- factor(dat$shoe)

fit_one <- function(basis, nagq) {
  bx <- ns(dat$new_x, knots = basis$knots_x, Boundary.knots = basis$bknots_x)
  by <- ns(dat$y, knots = basis$knots_y, Boundary.knots = basis$bknots_y)
  t0 <- proc.time()[["elapsed"]]
  fit <- glmer(n_Acc ~ bx * by + (1 | shoe), data = dat,
               family = binomial(link = "logit"), nAGQ = nagq,
               control = glmerControl(optimizer = "nlminbwrap"))
  list(fixef = fixef(fit), vcov = as.matrix(vcov(fit)),
       theta = getME(fit, "theta"), basis = basis,
       logLik = as.numeric(logLik(fit)), conv = fit@optinfo$conv$opt,
       messages = fit@optinfo$conv$lme4$messages, nAGQ = nagq,
       nobs = nobs(fit), seconds = proc.time()[["elapsed"]] - t0,
       R = R.version.string, lme4 = as.character(packageVersion("lme4")))
}
if ("fulltensor" %in% which_fits) {
  r <- fit_one(b3, 1L)
  out <- part2_path(P, "glmm_fulltensor", "rds")
  rac_ensure_dir(out)
  saveRDS(r, out)
  cat(sprintf("fulltensor: %d fixed effects, logLik %.4f, conv %d, %.0f s -> %s\n",
              length(r$fixef), r$logLik, r$conv, r$seconds, out))
}
if ("finey" %in% which_fits) {
  extra <- as.numeric(quantile(dat$y, seq_len(10) / 11))
  bf <- b3
  bf$knots_y <- sort(unique(c(b3$knots_y, extra)))
  stopifnot(length(bf$knots_y) == 15)
  r <- fit_one(bf, 0L)
  out <- part2_path(P, "glmm_finey", "rds")
  rac_ensure_dir(out)
  saveRDS(r, out)
  cat(sprintf("finey: %d fixed effects, logLik %.4f (nAGQ 0), conv %d, %.0f s -> %s\n",
              length(r$fixef), r$logLik, r$conv, r$seconds, out))
}
