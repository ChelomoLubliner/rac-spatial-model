# Slow calibration of the Part 2 two-sample chain on real structure (plan
# T7 step 2, test_validation_stats: "a slow version on real structure";
# T7 review, statistics minor finding 5). Not part of tests/run_all.sh
# (about 1 h on 4 workers); run in the background and paste the output into
# the T7 test results:
#
#   RAC_WORKERS=4 Rscript tests/r/slow/test_validation_real_calibration.R
#
# Setting: 160 real OLD shoes drawn once (seed 20261110): 60 "OLD-like"
# (the fitting sample) and 100 "NEW-like" (the validation sample), each with
# its own contact pixels (the cached Part 2 pixel table of validation_8.Rmd)
# and its real number of RACs n_i. Truth: the committed OLD GLMM surface,
# random effect 0: pi_ij proportional to plogis(eta_ij + MEAN_OFFSET) over
# the shoe's contact pixels. Replicate r:
#   - the RACs of every shoe drawn independently from pi_i;
#   - OLD-like: the step-1 case-control sample (every RAC pixel a case, the
#     profile's n_controls controls from the other contact pixels, without
#     replacement) and the step-3 GLMM refitted by PIRLS at the committed
#     variance parameter (fit_glmm_fixed_theta, the surrogate of the T7 OLD
#     draws, T7-2) -> beta_hat; the 2022 theta (Naomi's areas on the
#     shoe's own coordinates) by regional_fit -> theta_hat;
#   - inner B: OLD-like shoe resamples refitted the same way (beta*_b,
#     theta*_b) and NEW-like shoe resamples, paired as in the T7 bootstrap.
# Statistics of each replicate:
#   (a) named analysis 1 (Naomi's areas, the GLMM): the two-sample p, the
#       NEW-only p and the fixed-surface chi^2 p;
#   (b) the RAC-weighted log-score difference GLMM - 2022 and (c) Delta X^2
#       = X^2(GLMM) - X^2(2022) on the 15-cell grid, each with the NEW-only
#       interval and the two-sample interval, both centred on the point
#       (part2_shift_ci), and the raw two-sample percentile interval.
# Targets: E1 = the expectation given the replicate's fits (the published
# fitted surfaces; exact: sum over the pixels of pi_true for (b), and
# sum_k [Var(O_k) + (mu_k - E_k)^2] / E_k under independent multinomials
# for (c)); E2 = the mean of E1 over the replicates (the model classes: the
# procedure's expectation over OLD samples).
# Checks: the two-sample test rejects within 0.05 +- 2.5 sqrt(0.05 x 0.95
# / reps) (the plan); the NEW-only intervals cover E1 within 0.95 +- 2.5
# sqrt(0.95 x 0.05 / reps); the centred two-sample intervals cover E2 at
# least 0.95 - 2.5 SE (valid; in this setting without dataset shift the log
# score of a refitted surface varies at second order, so they may be
# conservative, which is reported). Reported without assertion: the
# fixed-surface and NEW-only rejection, the coverage of E2 by the raw
# two-sample and the NEW-only intervals, and the mean shift of the
# two-sample replicates.
#
# RAC_CALIB_REPS (default 400, the plan's 200 doubled for the coverage
# estimates) and RAC_CALIB_B (default 100, the plan's inner B) set the
# replicates and the inner bootstrap size (a quick run: 4 and 10).
suppressMessages({
  library(splines)
  library(lme4)
})
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "io.R", "distances.R", "compare.R", "validation.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
pass <- function(name) cat("PASS", name, "\n")
t_all <- proc.time()[["elapsed"]]
workers <- as.integer(rac_env("RAC_WORKERS", "4"))
reps <- as.integer(rac_env("RAC_CALIB_REPS", "400"))
Bin <- as.integer(rac_env("RAC_CALIB_B", "100"))

P <- rac_profile("old", root = ROOT_PATH)
glmm <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
basis <- part2_basis(glmm)
theta_re <- getME(glmm, "theta")
beta0 <- fixef(glmm)
pc <- read.csv(rac_path(P, "pixel_counts"))
MO <- mean(log(P$r$n_controls / pc$pixel_count))
cuts <- read.csv(part2_path(P, "part2_grid_cuts"))
px <- part2_pixel_table_cached(P)
n_all <- attr(px, "n_rac")
y_levels <- attr(px, "y_levels")
m_all <- length(n_all)

set.seed(20261110)
pick <- sample.int(m_all, 160)
codes_o <- pick[1:60]
codes_n <- pick[61:160]
sub_px <- function(codes) {
  keep <- px$code %in% codes
  s <- px[keep, c("code", "row", "col", "x", "y", "new_x")]
  s$code <- match(s$code, codes)
  s$N <- 0L
  attr(s, "y_levels") <- y_levels
  s
}
px_o <- sub_px(codes_o)
px_n <- sub_px(codes_n)
n_o <- n_all[codes_o]
n_n <- n_all[codes_n]
rm(px)
invisible(gc())

# the truth on every pixel of both samples
truth_pi <- function(s) {
  Bx <- part2_bx(s$new_x, basis)
  By <- part2_by(y_levels, basis)
  p <- stats::plogis(part2_eta(Bx, By, s$row, part2_coef_parts(beta0)) + MO)
  p / as.vector(rowsum(p, s$code, reorder = TRUE))[s$code]
}
pi_o <- truth_pi(px_o)
pi_n <- truth_pi(px_n)
by_o <- split(seq_len(nrow(px_o)), px_o$code)
by_n <- split(seq_len(nrow(px_n)), px_n$code)

# the NEW-like preparation (pixels fixed; the RAC parts updated per
# replicate)
prep_n <- part2_prepare(px_n, basis, cuts, length(codes_n))
with_racs <- function(pr, N) {
  pr$groups$O <- as.vector(rowsum(N, pr$grp, reorder = TRUE))
  pr$n <- as.vector(rowsum(N, pr$code, reorder = TRUE))
  pr$rac <- which(N > 0)
  pr$rac_N <- N[pr$rac]
  pr$rac_code <- pr$code[pr$rac]
  pr
}
sak <- list(a14 = part2_sak(prep_n, "aR", "a14"),
            g15 = part2_sak(prep_n, "aR", "g15"))
S_aR_n <- part2_agg(prep_n, prep_n$groups$S, "aR")
aR_o <- naomi_area(-px_o$x, px_o$y)
key_aR_o <- px_o$code + (aR_o - 1L) * length(codes_o)
S_aR_o <- matrix(tabulate(key_aR_o, nbins = length(codes_o) * 14L), length(codes_o), 14)
cell_n <- list(a14 = prep_n$groups$a14[prep_n$grp],
               g15 = prep_n$groups$g15[prep_n$grp])
band <- list(a14 = naomi_area_band(seq_len(14)),
             g15 = grid_band(seq_len(15), 3L))
lpi_R <- function(th, aR, code, S_aR) {
  log(th[aR]) - log(as.vector(S_aR %*% th))[code]
}
aR_n <- prep_n$groups$aR[prep_n$grp]
# the true cell probabilities of the NEW-like shoes on the 15-cell grid:
# the mean and variance of the pooled counts under independent multinomials
key_g <- prep_n$code + (cell_n$g15 - 1L) * length(codes_n)
PT <- numeric(length(codes_n) * 15)
PT[sort(unique(key_g))] <- as.vector(rowsum(pi_n, key_g, reorder = TRUE))
PT <- matrix(PT, length(codes_n), 15)
mu_g15 <- colSums(n_n * PT)
vr_g15 <- colSums(n_n * PT * (1 - PT))

one_rep <- function(r) {
  set.seed(20261110 + r)
  N_o <- integer(nrow(px_o))
  for (i in seq_along(by_o)) {
    j <- by_o[[i]]
    N_o[j] <- as.vector(rmultinom(1, n_o[i], pi_o[j]))
  }
  N_n <- integer(nrow(px_n))
  for (i in seq_along(by_n)) {
    j <- by_n[[i]]
    N_n[j] <- as.vector(rmultinom(1, n_n[i], pi_n[j]))
  }
  # OLD-like: case-control sample and fits
  cc <- do.call(rbind, lapply(seq_along(by_o), function(i) {
    j <- by_o[[i]]
    case <- j[N_o[j] > 0]
    ctrl <- j[N_o[j] == 0]
    ctrl <- ctrl[sample.int(length(ctrl), P$r$n_controls)]
    data.frame(n_Acc = rep(c(1, 0), c(length(case), length(ctrl))),
               new_x = px_o$new_x[c(case, ctrl)], y = px_o$y[c(case, ctrl)],
               shoe = i)
  }))
  O_aR_o <- matrix(0, length(codes_o), 14)
  ra <- rowsum(N_o, key_aR_o, reorder = TRUE)
  O_aR_o[as.integer(rownames(ra))] <- ra[, 1]
  beta_hat <- fit_glmm_fixed_theta(cc, basis, theta_re)$beta
  th_hat <- regional_fit(O_aR_o, S_aR_o)
  pr <- with_racs(prep_n, N_n)
  O_aR_n <- part2_agg(pr, pr$groups$O, "aR")
  N <- sum(pr$n)
  ev_one <- function(beta, th) {
    ev <- part2_eval(pr, part2_coef_parts(beta), "logit", MO)
    list(EC = lapply(c(a14 = "a14", g15 = "g15"), function(cl)
      normalize_expected(part2_agg(pr, ev$Eg, cl), pr$n)),
      ER = lapply(c(a14 = "a14", g15 = "g15"), function(cl)
        regional_expected(th, sak[[cl]], pr$n)),
      lsC = part2_ls_model(ev, pr$n),
      lsR = part2_ls_regional(th, O_aR_n, S_aR_n))
  }
  hat <- ev_one(beta_hat, th_hat)
  O <- lapply(c(a14 = "a14", g15 = "g15"), function(cl)
    part2_agg(pr, pr$groups$O, cl))
  ob_a <- part2_obs_stats(O$a14, hat$EC$a14, band$a14)
  ob_C <- part2_obs_stats(O$g15, hat$EC$g15, band$g15)
  ob_R <- part2_obs_stats(O$g15, hat$ER$g15, band$g15)
  ls_pt <- (sum(hat$lsC) - sum(hat$lsR)) / N
  dx_pt <- ob_C$X2 - ob_R$X2
  # E1: the exact expectations given the fits
  eta_hat <- part2_eta(pr$Bx, pr$By_img, pr$row, part2_coef_parts(beta_hat))
  lp <- stats::plogis(eta_hat + MO, log.p = TRUE)
  lpiC <- lp - log(as.vector(rowsum(exp(lp), pr$code, reorder = TRUE)))[pr$code]
  lpiR <- lpi_R(th_hat, aR_n, pr$code, S_aR_n)
  E1_ls <- sum(n_n[pr$code] * pi_n * (lpiC - lpiR)) / N
  e_x2 <- function(E) {
    Ek <- colSums(E)
    sum((vr_g15 + (mu_g15 - Ek)^2) / Ek)
  }
  E1_dx <- e_x2(hat$EC$g15) - e_x2(hat$ER$g15)
  # the inner bootstrap
  ids_o <- part2_resample_ids(length(codes_o), Bin, 30000 + r)
  Wn <- part2_weights(length(codes_n), Bin, 40000 + r)
  st <- matrix(NA_real_, Bin, 6, dimnames = list(NULL, c("x2_two", "x2_new",
    "ls_two", "ls_new", "dx_two", "dx_new")))
  for (b in seq_len(Bin)) {
    rs <- part2_resample_data(cc, seq_along(codes_o), ids_o[b, ])
    bb <- fit_glmm_fixed_theta(rs, basis, theta_re)$beta
    tb <- regional_fit(O_aR_o, S_aR_o, w = tabulate(ids_o[b, ], length(codes_o)))
    dr <- ev_one(bb, tb)
    w <- Wn[b, ]
    st[b, "x2_two"] <- part2_boot_one(ob_a, dr$EC$a14 %*% ob_a$map, w)$X2_two
    st[b, "x2_new"] <- part2_boot_one(ob_a, ob_a$Em, w)$X2_new
    st[b, "ls_two"] <- (sum(w * dr$lsC) - sum(w * dr$lsR)) / sum(w * pr$n)
    st[b, "ls_new"] <- (sum(w * hat$lsC) - sum(w * hat$lsR)) / sum(w * pr$n)
    st[b, "dx_two"] <- part2_boot_one(ob_C, dr$EC$g15 %*% ob_C$map, w)$X2_unc -
      part2_boot_one(ob_R, dr$ER$g15 %*% ob_R$map, w)$X2_unc
    st[b, "dx_new"] <- part2_boot_one(ob_C, ob_C$Em, w)$X2_unc -
      part2_boot_one(ob_R, ob_R$Em, w)$X2_unc
  }
  ci <- function(v, pt) unlist(part2_shift_ci(v, pt)[c("lo", "hi", "shift")])
  c(p_two = (1 + sum(st[, "x2_two"] >= ob_a$X2)) / (Bin + 1),
    p_new = (1 + sum(st[, "x2_new"] >= ob_a$X2)) / (Bin + 1),
    p_fixed = ob_a$p_chisq, X2 = ob_a$X2, E0 = mean(st[, "x2_two"]),
    ls_pt = ls_pt, ls_E1 = E1_ls,
    setNames(ci(st[, "ls_new"], ls_pt), c("ls_new_lo", "ls_new_hi", "ls_new_shift")),
    setNames(ci(st[, "ls_two"], ls_pt), c("ls_two_lo", "ls_two_hi", "ls_two_shift")),
    ls_raw_lo = stats::quantile(st[, "ls_two"], 0.025, names = FALSE),
    ls_raw_hi = stats::quantile(st[, "ls_two"], 0.975, names = FALSE),
    ls_sd_two = stats::sd(st[, "ls_two"]),
    dx_pt = dx_pt, dx_E1 = E1_dx,
    setNames(ci(st[, "dx_new"], dx_pt), c("dx_new_lo", "dx_new_hi", "dx_new_shift")),
    setNames(ci(st[, "dx_two"], dx_pt), c("dx_two_lo", "dx_two_hi", "dx_two_shift")),
    dx_raw_lo = stats::quantile(st[, "dx_two"], 0.025, names = FALSE),
    dx_raw_hi = stats::quantile(st[, "dx_two"], 0.975, names = FALSE),
    dx_sd_two = stats::sd(st[, "dx_two"]), N_old = sum(n_o), N_new = N)
}
res <- parallel::mclapply(seq_len(reps), function(r) {
  out <- try(one_rep(r), silent = TRUE)
  if (inherits(out, "try-error")) paste("replicate", r, ":", out) else out
}, mc.cores = workers, mc.preschedule = FALSE)
bad <- !vapply(res, is.numeric, TRUE)
if (any(bad)) {
  cat("replicates failed (excluded):", sum(bad), "\n")
  cat(unlist(res[bad]), sep = "\n")
}
stopifnot(mean(bad) <= 0.02)
R <- do.call(rbind, res[!bad])
cov_of <- function(lo, hi, target) mean(lo <= target & target <= hi)
E2_ls <- mean(R[, "ls_E1"])
E2_dx <- mean(R[, "dx_E1"])
rate <- c(two = mean(R[, "p_two"] <= 0.05), new = mean(R[, "p_new"] <= 0.05),
          fixed = mean(R[, "p_fixed"] <= 0.05))
cv <- c(ls_new_E1 = cov_of(R[, "ls_new_lo"], R[, "ls_new_hi"], R[, "ls_E1"]),
        ls_two_E2 = cov_of(R[, "ls_two_lo"], R[, "ls_two_hi"], E2_ls),
        ls_raw_E2 = cov_of(R[, "ls_raw_lo"], R[, "ls_raw_hi"], E2_ls),
        ls_new_E2 = cov_of(R[, "ls_new_lo"], R[, "ls_new_hi"], E2_ls),
        dx_new_E1 = cov_of(R[, "dx_new_lo"], R[, "dx_new_hi"], R[, "dx_E1"]),
        dx_two_E2 = cov_of(R[, "dx_two_lo"], R[, "dx_two_hi"], E2_dx),
        dx_raw_E2 = cov_of(R[, "dx_raw_lo"], R[, "dx_raw_hi"], E2_dx),
        dx_new_E2 = cov_of(R[, "dx_new_lo"], R[, "dx_new_hi"], E2_dx))
reps <- nrow(R)
cat(sprintf(paste("real structure (%d replicates, inner B %d, %.0f s; OLD-like",
                  "%d shoes, %.0f RACs; NEW-like %d shoes, %.0f RACs):\n"),
            reps, Bin, proc.time()[["elapsed"]] - t_all, length(codes_o),
            mean(R[, "N_old"]), length(codes_n), mean(R[, "N_new"])))
cat(sprintf(paste("  named analysis 1 (Naomi's areas), rejection at 5%%: two-sample",
                  "%.3f, NEW-only %.3f, fixed surface %.3f; mean X^2 %.1f, mean E0 %.1f\n"),
            rate[["two"]], rate[["new"]], rate[["fixed"]], mean(R[, "X2"]),
            mean(R[, "E0"])))
cat(sprintf(paste("  log score GLMM - 2022 (RAC-weighted): E2 %.5f (sd of E1 over",
                  "replicates %.5f); mean point %.5f; mean shift of the two-sample",
                  "replicates %.5f (%.2f of their sd)\n"),
            E2_ls, stats::sd(R[, "ls_E1"]), mean(R[, "ls_pt"]),
            mean(R[, "ls_two_shift"]), mean(R[, "ls_two_shift"] / R[, "ls_sd_two"])))
cat(sprintf(paste("    coverage: NEW-only of E1 %.3f; two-sample centred of E2 %.3f;",
                  "raw two-sample of E2 %.3f; NEW-only of E2 %.3f\n"),
            cv[["ls_new_E1"]], cv[["ls_two_E2"]], cv[["ls_raw_E2"]], cv[["ls_new_E2"]]))
cat(sprintf(paste("  Delta X^2 on the 15-cell grid: E2 %.2f (sd of E1 %.2f); mean",
                  "point %.2f; mean shift %.2f (%.2f of the sd)\n"),
            E2_dx, stats::sd(R[, "dx_E1"]), mean(R[, "dx_pt"]),
            mean(R[, "dx_two_shift"]), mean(R[, "dx_two_shift"] / R[, "dx_sd_two"])))
cat(sprintf(paste("    coverage: NEW-only of E1 %.3f; two-sample centred of E2 %.3f;",
                  "raw two-sample of E2 %.3f; NEW-only of E2 %.3f\n"),
            cv[["dx_new_E1"]], cv[["dx_two_E2"]], cv[["dx_raw_E2"]], cv[["dx_new_E2"]]))
out_rds <- Sys.getenv("RAC_CALIB_OUT")
if (nzchar(out_rds)) saveRDS(list(R = R, rate = rate, coverage = cv), out_rds)
se_size <- sqrt(0.05 * 0.95 / reps)
se_cov <- sqrt(0.95 * 0.05 / reps)
ok <- TRUE
chk <- function(cond, msg) {
  if (cond) pass(msg) else {
    cat("FAIL", msg, "\n")
    ok <<- FALSE
  }
}
chk(abs(rate[["two"]] - 0.05) <= 2.5 * se_size,
    "the two-sample bootstrap holds its size on real structure (0.05 +- 2.5 SE)")
chk(abs(cv[["ls_new_E1"]] - 0.95) <= 2.5 * se_cov,
    "log score: the NEW-only interval covers the fitted surfaces' expectation E1")
chk(cv[["ls_two_E2"]] >= 0.95 - 2.5 * se_cov,
    "log score: the centred two-sample interval covers the model classes' expectation E2 (at least nominal)")
chk(abs(cv[["dx_new_E1"]] - 0.95) <= 2.5 * se_cov,
    "Delta X^2: the NEW-only interval covers E1")
chk(cv[["dx_two_E2"]] >= 0.95 - 2.5 * se_cov,
    "Delta X^2: the centred two-sample interval covers E2 (at least nominal)")
cat(sprintf("%s test_validation_real_calibration (%.0f s)\n",
            if (ok) "ALL PASS" else "SOME CHECKS FAILED",
            proc.time()[["elapsed"]] - t_all))
if (!ok) quit(status = 1)
