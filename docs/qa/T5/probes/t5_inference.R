# t5_inference.R: the inference checks of the T5 review fixes (the
# statistics reviewer's minor findings 1, 2 and 5 and the convergence note;
# decisions A-115, A-116).
#   1. Convergence of the NEW GLMM: lme4 1.1-38 runs no gradient or Hessian
#      check when nobs > check.conv.nobsmax (10,000) and stores no
#      derivatives (plan F42), so "conv code 0, no lme4 message" is not
#      evidence. This rebuilds step 3's deviance function (devFunOnly) for
#      the committed CSV, evaluates it at the stored optimum (it must equal
#      -2 logLik) and takes a central-difference gradient (step 1e-4) in
#      theta and every fixed effect.
#   2. Model-based against cluster-robust Wald: the Efron CML (step 3's
#      basis; survival has no robust variance for the exact CML, plan F29)
#      with cluster(shoe): W (all 24 = 0) with the model-based and the
#      robust variance, both datasets; and W per case (W grows with the
#      number of cases, so W does not compare across datasets).
#   3. The cost of K8: Efron CML on the step-3 basis against the full
#      tensor (main effects and interaction), likelihood-ratio statistic and
#      df; the log-intensity at the left and the right edge of the data
#      (2nd and 98th percentile of new_x) relative to the median new_x, in
#      10 y bands (deciles of y), under both fits; O/E across the width
#      (u = new_x / distance_shape: -1 the left contour, +1 the right) of
#      the step-3 GLMM fitted with BLUPs.
#   4. The level of the step 4-6 maps (plan K3, D-009): the empirical RAC
#      pixels per contact pixel; the map mean (intensity -log(1 - p) on the
#      prototype mask, MEAN_OFFSET and exp(-sigma^2 / 2) as step 4 does);
#      and the RAC total predicted by the committed GLMM, each shoe's sum
#      over its contact surface S estimated from its controls (they are a
#      simple random sample of S without the case pixels: sum over S of
#      exp(eta) = (px - n) / 100 x the controls' sum + the cases' sum; the
#      intensity of a pixel is exp(eta + b_i) x f_i, f_i = 100 / (px - n),
#      plan F35), with b_i = each shoe's BLUP, b_i = 0, and b_i = 0 with the
#      factors exp(+sigma^2 / 2) and exp(-sigma^2 / 2).
# Reads committed files only; writes nothing.
# Usage (repo root): Rscript docs/qa/T5/probes/t5_inference.R
suppressMessages({
  library(splines)
  library(lme4)
  library(survival)
})
root <- normalizePath(".")
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "compare.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
wald <- function(b, V) {
  R <- chol(V)
  z <- backsolve(R, b, transpose = TRUE)
  sum(z^2)
}
t_start <- proc.time()[["elapsed"]]
prof <- list(old = rac_profile("old", root = ROOT_PATH),
             new = rac_profile("new", root = ROOT_PATH))
dat <- lapply(prof, function(P) {
  read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
})
glmm <- lapply(prof, function(P) readRDS(rac_model_path(P, "NEW_X_NS_XY")))

cat("== 1. convergence of the NEW GLMM (lme4", as.character(
  packageVersion("lme4")), ")\n")
g <- glmm$new
cat("check.conv.nobsmax:", glmerControl()$checkConv$check.conv.nobsmax,
    "; nobs", nobs(g), "; derivatives stored:", !is.null(g@optinfo$derivs),
    "\n")
dat_s3 <- subset(dat$new, select = c("n_Acc", "x", "y", "shoe", "row_number",
                                      "horiz_dist", "new_x"))
local({
  dat <- dat_s3
  knots_new_x <- as.numeric(quantile(dat$new_x, 1:3 / 4))
  knotsy <- as.numeric(quantile(dat$y, 1:5 / 6))
  shoe <- dat$shoe
  dev <- glmer(n_Acc ~ ns(dat$new_x, knots = knots_new_x):ns(dat$y,
                                                           knots = knotsy) +
                 (1 | shoe), data = dat, family = binomial(link = "logit"),
               control = glmerControl(optimizer = "nlminbwrap"),
               devFunOnly = TRUE)
  p0 <- c(getME(g, "theta"), fixef(g))
  d0 <- dev(p0)
  h <- 1e-4
  gr <- vapply(seq_along(p0), function(k) {
    e <- replace(numeric(length(p0)), k, h)
    (dev(p0 + e) - dev(p0 - e)) / (2 * h)
  }, 1)
  cat(sprintf(paste("deviance at the stored optimum %.6f, -2 logLik %.6f;",
                    "central-difference gradient (step %g): |d/dtheta| %.4f,",
                    "max |d/dbeta| %.4f (%s), median |d/dbeta| %.4f\n"),
              d0, -2 * as.numeric(logLik(g)), h, abs(gr[1]),
              max(abs(gr[-1])), c("(Intercept)", sprintf("term %d", 1:24))[
                which.max(abs(gr[-1]))], median(abs(gr[-1]))))
})

cat("\n== 2. model-based and cluster(shoe)-robust Wald, Efron CML\n")
for (ds in c("old", "new")) {
  d <- dat[[ds]]
  b <- basis_knots(d)
  bx <- ns(d$new_x, knots = b$knots_x)
  by <- ns(d$y, knots = b$knots_y)
  m <- coxph(Surv(rep(1, nrow(d)), n_Acc) ~ bx:by + strata(shoe) +
               cluster(shoe), data = d, ties = "efron")
  se_m <- sqrt(diag(m$naive.var))
  se_r <- sqrt(diag(m$var))
  w_m <- wald(coef(m), m$naive.var)
  w_r <- wald(coef(m), m$var)
  cml <- readRDS(rac_model_path(prof[[ds]], "CML_MODEL"))
  w_exact <- wald(coef(cml), vcov(cml))
  gb <- fixef(glmm[[ds]])[-1]
  vb <- suppressWarnings(as.matrix(vcov(glmm[[ds]], use.hessian = FALSE)))
  w_glmm <- wald(gb, vb[-1, -1])
  n_case <- sum(d$n_Acc)
  cat(sprintf(paste("%s: Efron W model-based %.1f, cluster-robust %.1f",
                    "(ratio %.3f); robust/model SE median %.3f, max %.3f;",
                    "cases %d; W per case: exact CML %.4f, GLMM (RX) %.4f,",
                    "Efron model-based %.4f, robust %.4f\n"),
              ds, w_m, w_r, w_r / w_m, median(se_r / se_m), max(se_r / se_m),
              n_case, w_exact / n_case, w_glmm / n_case, w_m / n_case,
              w_r / n_case))
}

cat("\n== 3. the cost of K8 (Efron CML: step-3 basis vs full tensor)\n")
for (ds in c("old", "new")) {
  d <- dat[[ds]]
  b <- basis_knots(d)
  bx <- ns(d$new_x, knots = b$knots_x)
  by <- ns(d$y, knots = b$knots_y)
  r <- clogit(n_Acc ~ bx:by + strata(shoe), data = d, method = "efron")
  f <- clogit(n_Acc ~ bx + by + bx:by + strata(shoe), data = d,
              method = "efron")
  lr <- 2 * (f$loglik[2] - r$loglik[2])
  dfd <- sum(!is.na(coef(f))) - sum(!is.na(coef(r)))
  cat(sprintf(paste("%s: K8 %d coef, loglik %.3f; full %d coef, loglik %.3f;",
                    "LR %.2f on %d df (p %.2g, model-based); LR x 0.57",
                    "(about the robust deflation of W in 2) %.1f\n"),
              ds, sum(!is.na(coef(r))), r$loglik[2], sum(!is.na(coef(f))),
              f$loglik[2], lr, dfd, pchisq(lr, dfd, lower.tail = FALSE),
              lr * 0.57))
  lp <- function(m, xv, yv) {
    X <- predict(bx, xv)
    Y <- predict(by, yv)
    M <- do.call(cbind, lapply(seq_len(ncol(Y)), function(i) X * Y[, i]))
    if (length(coef(m)) > ncol(M)) M <- cbind(X, Y, M)
    cf <- coef(m)
    cf[is.na(cf)] <- 0
    as.vector(M %*% cf)
  }
  d$yb <- cut(d$y, quantile(d$y, seq(0, 1, length.out = 11)),
              include.lowest = TRUE)
  cat(sprintf("%-18s %7s %7s | %6s %6s %6s | %6s %6s %6s\n", "y band (decile)",
              "x_L", "x_R", "K8 L", "full L", "diff", "K8 R", "full R",
              "diff"))
  dl <- dr <- numeric(0)
  for (lev in levels(d$yb)) {
    s <- d[d$yb == lev, ]
    xl <- as.numeric(quantile(s$new_x, 0.02))
    xr <- as.numeric(quantile(s$new_x, 0.98))
    xc <- median(s$new_x)
    ym <- median(s$y)
    kl <- lp(r, xl, ym) - lp(r, xc, ym)
    fl <- lp(f, xl, ym) - lp(f, xc, ym)
    kr <- lp(r, xr, ym) - lp(r, xc, ym)
    fr <- lp(f, xr, ym) - lp(f, xc, ym)
    dl <- c(dl, fl - kl)
    dr <- c(dr, fr - kr)
    cat(sprintf("%-18s %7.3f %7.3f | %6.2f %6.2f %6.2f | %6.2f %6.2f %6.2f\n",
                lev, xl, xr, kl, fl, fl - kl, kr, fr, fr - kr))
  }
  cat(sprintf(paste("   full - K8 at the left edge: %.2f to %.2f, |diff| >",
                    "0.1 in %d of 10 bands; at the right edge: %.2f to %.2f,",
                    "|diff| <= 0.06 in %d of 10\n"),
              min(dl), max(dl), sum(abs(dl) > 0.1), min(dr), max(dr),
              sum(abs(dr) <= 0.06)))
  mu <- as.numeric(fitted(glmm[[ds]]))
  u <- d$new_x / d$distance_shape
  ub <- cut(u, c(-1.0001, -0.95, -0.85, -0.7, -0.4, 0, 0.4, 0.7, 0.85, 0.95,
                 1.0001))
  cat("   O/E across the width (u = new_x / distance_shape), GLMM with BLUPs:\n")
  for (lev in levels(ub)) {
    i <- which(ub == lev)
    O <- sum(d$n_Acc[i])
    E <- sum(mu[i])
    cat(sprintf("   u %-16s rows %6d cases %5d O/E %.3f z %6.2f\n", lev,
                length(i), O, O / E, (O - E) / sqrt(sum(mu[i] * (1 - mu[i])))))
  }
}

cat("\n== 4. the level of the maps (plan K3, D-009)\n")
P0 <- prof$old
mask <- t(as.matrix(imager::load.image(rac_path(P0, "prototype_mask"))))
Wp <- P0$prototype$col_shoe
Hp <- P0$prototype$row_shoe
sc <- P0$prototype$coords$rel_Y_cord / P0$prototype$coords$rel_col_shoe
gr <- expand.grid(x = (-Wp / 2 + 1:Wp) * sc, y = -(-Hp / 2 + 1:Hp) * sc)
lev <- list()
for (ds in c("old", "new")) {
  P <- prof[[ds]]
  d <- dat[[ds]]
  g <- glmm[[ds]]
  pc <- read.csv(rac_path(P, "pixel_counts"), header = TRUE)
  s2 <- as.numeric(VarCorr(g)$shoe)
  mo <- mean(log(100 / pc$pixel_count))
  b <- basis_knots(d)
  bx <- ns(d$new_x, knots = b$knots_x)
  by <- ns(d$y, knots = b$knots_y)
  X <- predict(bx, gr$x)
  Y <- predict(by, gr$y)
  eta <- as.vector(cbind(1, do.call(cbind, lapply(seq_len(ncol(Y)), function(i)
    X * Y[, i]))) %*% fixef(g)) + mo
  lam <- -log(1 - plogis(eta)) * exp(-s2 / 2)
  lam <- lam[as.vector(t(mask)) == 1]
  rate <- sum(d$n_Acc) / sum(pc$pixel_count)
  e <- exp(as.vector(getME(g, "X") %*% fixef(g)))
  n <- tapply(d$n_Acc, d$shoe, sum)
  px <- pc$pixel_count[as.integer(names(n))]
  s_ctrl <- tapply(e * (d$n_Acc == 0), d$shoe, sum)
  s_case <- tapply(e * (d$n_Acc == 1), d$shoe, sum)
  f_i <- 100 / (px - n)
  base <- f_i * ((px - n) / 100 * s_ctrl + s_case)
  blup <- ranef(g)$shoe[names(n), 1]
  N <- sum(n)
  cat(sprintf(paste("%s: RAC px per S px %.6f (%d / %d); map mean %.6f",
                    "(map / empirical %.3f); MEAN_OFFSET %.4f, exp(-sigma^2/2)",
                    "%.3f\n   predicted RAC total / observed: each shoe's BLUP",
                    "%.3f; b = 0 %.3f; b = 0 x exp(+sigma^2/2) %.3f; b = 0 x",
                    "exp(-sigma^2/2) %.3f\n"),
              ds, rate, N, sum(pc$pixel_count), mean(lam), mean(lam) / rate,
              mo, exp(-s2 / 2), sum(exp(blup) * base) / N, sum(base) / N,
              sum(base) * exp(s2 / 2) / N, sum(base) * exp(-s2 / 2) / N))
  lev[[ds]] <- c(rate = rate, map = mean(lam))
}
cat(sprintf("NEW / OLD: empirical RAC px per S px %.3f; map mean %.3f\n",
            lev$new[["rate"]] / lev$old[["rate"]],
            lev$new[["map"]] / lev$old[["map"]]))
cat(sprintf("\nt5_inference.R done in %.0f s\n",
            proc.time()[["elapsed"]] - t_start))
