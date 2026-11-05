# T0 review-fix pass 2 probe (R): sign of the per-shoe offset in a GLMM
# refit (plan T6 fit_offset, A-037), on the committed OLD data, and the
# GLMM fit time on this machine (input for the T5 bootstrap budget).
#
# Case-control logic: every RAC pixel of shoe i is a case (sampling
# fraction 1) and 100 controls are drawn from its px_i - cases_i non-RAC
# contact pixels (fraction f_i = 100 / (px_i - cases_i)). Then
#   logit P(case | sampled) = logit p + log(1 / f_i),
# so a refit that recovers the population intercept needs the offset
# log(1 / f_i) = log((px_i - cases_i) / 100). The plan wrote
# offset(log(100 / (px - cases))) = log(f_i), the opposite sign.
#
# Three fits with the committed model call of re_model_shoe_std_3.Rmd
# (same formula text, nlminbwrap): no offset (a local refit, compared with
# the committed model), the corrected sign and the plan's sign.
# Read-only: committed files only; nothing is written.
# Run from the repo root: Rscript docs/qa/T0/probes/t0_review2_offset.R
suppressMessages({
  library(lme4)
  library(splines)
})
dataCC <- read.csv("processed_data/dataCC_distance.csv")
m_comm <- readRDS("saved_models/NEW_X_NS_XY.rds")
pc <- read.csv("processed_data/shoe_pixel_counts.csv")
stopifnot(nrow(pc) == 386, length(unique(dataCC$shoe)) == 386,
          identical(sort(unique(dataCC$shoe)), seq_len(386)))
cases <- as.numeric(tapply(dataCC$n_Acc, dataCC$shoe, sum))
px <- pc$pixel_count                    # row k of pc is dataCC code k
log_inv_f <- log((px - cases) / 100)    # log(1 / f_i), corrected sign
cat(sprintf("OLD: %d rows, %d shoes, %d cases; mean log(100/(px - cases)) = %.6f, var = %.4f\n",
            nrow(dataCC), length(px), sum(cases), mean(-log_inv_f),
            var(log_inv_f)))

fit <- function(dat, off = NULL) {
  # same knots and formula text as Random() in re_model_shoe_std_3.Rmd
  knots_new_x <- as.numeric(quantile(dat$new_x, 1:3 / (1 + 3)))
  knotsy <- as.numeric(quantile(dat$y, 1:5 / (1 + 5)))
  shoe <- dat$shoe
  t0 <- proc.time()[["elapsed"]]
  if (is.null(off)) {
    est <- glmer(n_Acc ~ ns(dat$new_x,knots=knots_new_x):ns(dat$y,knots=knotsy) + (1 | shoe),
                 data = dat, family = binomial(link = "logit"),
                 control = glmerControl(optimizer = "nlminbwrap"))
  } else {
    dat$off <- off
    est <- glmer(n_Acc ~ ns(dat$new_x,knots=knots_new_x):ns(dat$y,knots=knotsy) + offset(off) + (1 | shoe),
                 data = dat, family = binomial(link = "logit"),
                 control = glmerControl(optimizer = "nlminbwrap"))
  }
  list(m = est, sec = proc.time()[["elapsed"]] - t0)
}
summ <- function(lab, f) {
  m <- f$m
  cat(sprintf("%-44s fit %6.1f s | intercept %9.6f | sigma^2 %.7f | logLik %.4f | conv %s\n",
              lab, f$sec, unname(fixef(m)[1]),
              unname(VarCorr(m)$shoe[1]), as.numeric(logLik(m)),
              paste(m@optinfo$conv$opt, collapse = ",")))
}

cat("\n=== committed GLMM (written by R 4.4.3 on Windows)\n")
cat(sprintf("intercept %.6f | sigma^2 %.7f | logLik %.4f\n",
            unname(fixef(m_comm)[1]), unname(VarCorr(m_comm)$shoe[1]),
            as.numeric(logLik(m_comm))))

cat("\n=== fits on this machine (", R.version.string, ")\n", sep = "")
f0 <- fit(dataCC)
summ("no offset (committed form, local refit)", f0)
cat(sprintf("  refit vs committed: identical(fixef) %s, max |diff fixef| %.3g, identical(vcov) %s, max |diff vcov| %.3g, |diff sigma^2| %.3g\n",
            identical(fixef(f0$m), fixef(m_comm)),
            max(abs(fixef(f0$m) - fixef(m_comm))),
            identical(as.matrix(vcov(f0$m)), as.matrix(vcov(m_comm))),
            max(abs(as.matrix(vcov(f0$m)) - as.matrix(vcov(m_comm)))),
            abs(VarCorr(f0$m)$shoe[1] - VarCorr(m_comm)$shoe[1])))
vc0 <- as.matrix(vcov(m_comm))
cat(sprintf("  relative: max |diff fixef| / |fixef| %.3g, max |diff vcov| / max |vcov| %.3g, max |diff SE| / SE %.3g\n",
            max(abs(fixef(f0$m) - fixef(m_comm)) / abs(fixef(m_comm))),
            max(abs(as.matrix(vcov(f0$m)) - vc0)) / max(abs(vc0)),
            max(abs(sqrt(diag(as.matrix(vcov(f0$m)))) - sqrt(diag(vc0))) /
                  sqrt(diag(vc0)))))
wald <- function(m) {
  b <- fixef(m)[-1]
  V <- as.matrix(vcov(m))[-1, -1]
  sum(b * solve(V, b))
}
cat(sprintf("  manual Wald (24 spatial coefficients = 0): committed W = %.4f, local refit W = %.4f\n",
            wald(m_comm), wald(f0$m)))
cat(sprintf("  committed model: max |vcov(use.hessian = TRUE) - vcov(use.hessian = FALSE)| / max |vcov| = %.3g\n",
            max(abs(as.matrix(vcov(m_comm, use.hessian = TRUE)) -
                      as.matrix(vcov(m_comm, use.hessian = FALSE)))) /
              max(abs(vc0))))
f1 <- fit(dataCC, log_inv_f[dataCC$shoe])   # per row: its shoe's value
summ("offset(log((px - cases) / 100)) [corrected]", f1)
f2 <- tryCatch(fit(dataCC, -log_inv_f[dataCC$shoe]),
               error = function(e) e)
if (inherits(f2, "error")) {
  cat(sprintf("%-44s ERROR with default starting values: %s\n",
              "offset(log(100 / (px - cases))) [plan T6]",
              conditionMessage(f2)))
  # retry from the values the plan's sign implies (intercept + 2 mean
  # log(1/f)); lme4 accepts start = list(theta, fixef) for glmer
  st <- list(theta = 1, fixef = c(fixef(f1$m)[1] + 2 * mean(log_inv_f),
                                  fixef(f1$m)[-1]))
  dd <- dataCC
  dd$off <- -log_inv_f[dataCC$shoe]
  t0 <- proc.time()[["elapsed"]]
  knots_new_x <- as.numeric(quantile(dd$new_x, 1:3 / (1 + 3)))
  knotsy <- as.numeric(quantile(dd$y, 1:5 / (1 + 5)))
  f2 <- tryCatch(list(m = glmer(n_Acc ~ ns(dd$new_x,knots=knots_new_x):ns(dd$y,knots=knotsy) + offset(off) + (1 | shoe),
                                data = dd, family = binomial(link = "logit"),
                                start = st,
                                control = glmerControl(optimizer = "nlminbwrap")),
                      sec = NA_real_),
                 error = function(e) e)
  if (inherits(f2, "error")) {
    cat(sprintf("  retry from the implied starting values: ERROR: %s\n",
                conditionMessage(f2)))
    f2 <- NULL
  } else {
    f2$sec <- proc.time()[["elapsed"]] - t0
    summ("  [plan T6 sign] retry from implied start", f2)
  }
} else {
  summ("offset(log(100 / (px - cases))) [plan T6]", f2)
}

b0 <- fixef(f0$m)
cat("\n=== checks\n")
cat(sprintf("expected corrected intercept = intercept(no offset) + mean(log(100/(px - cases))) = %.6f; fitted %.6f; difference %.4f\n",
            b0[1] + mean(-log_inv_f), fixef(f1$m)[1],
            fixef(f1$m)[1] - (b0[1] + mean(-log_inv_f))))
cat(sprintf("max |spatial coefficients (corrected) - (no offset)| = %.4f\n",
            max(abs(fixef(f1$m)[-1] - b0[-1]))))
re0 <- ranef(f0$m)$shoe[, 1]
re1 <- ranef(f1$m)$shoe[, 1]
cat(sprintf("cor(predicted random effect, log(1/f)): no-offset fit %.3f, corrected fit %.3f; var(log(1/f)) = %.4f\n",
            cor(re0, log_inv_f), cor(re1, log_inv_f), var(log_inv_f)))
cat(sprintf("sigma^2: no offset %.4f, corrected %.4f (< 0.96: %s)\n",
            VarCorr(f0$m)$shoe[1], VarCorr(f1$m)$shoe[1],
            VarCorr(f1$m)$shoe[1] < 0.96))
if (!is.null(f2)) {
  cat(sprintf("plan sign: sigma^2 %.4f, intercept %.4f, max |spatial coefficients - (no offset)| = %.4f\n",
              VarCorr(f2$m)$shoe[1], fixef(f2$m)[1],
              max(abs(fixef(f2$m)[-1] - b0[-1]))))
}
