# Slow calibration checks of the Part 2 tests with E estimated (plan T7
# step 2, test_validation_stats "with E estimated", review focus 7; plan
# F34, decision A-043). Not part of tests/run_all.sh (about 30-60 min);
# run in the background and paste the output into docs/tests/T7-results.md:
#
#   Rscript tests/r/slow/test_validation_calibration.R
#
# The F34 toy: the real RACs per shoe of both datasets (OLD 386 shoes, NEW
# 631), K = 15 cells, shoe-specific contact shares S_ik (Dirichlet around a
# common share), a cell model pi_ik = theta_k S_ik / sum_l theta_l S_il.
# Each replicate simulates the OLD counts, fits theta on them by its
# conditional multinomial MLE (regional_fit, the same estimator as the 2022
# model), simulates the NEW counts from the TRUE theta and tests the NEW
# counts against E~ = n_i pi_ik(theta_hat):
#   - fixed: the fixed-surface Pearson test (chi^2_{K-1}): must reject more
#     than 0.5 (F34: 0.787), because it ignores the OLD estimation error;
#   - newonly: the NEW-only shoe bootstrap (B = 199, theta fixed): > 0.5
#     (F34: 0.795);
#   - wald: wald_param with Sigma_mult + G V G' (V the inverse Fisher
#     information of log theta on OLD): within 0.05 +- 2.5 SE under
#     independence (F34: 0.045);
#   - two: two_sample_bootstrap (B = 199; OLD resample refits of theta):
#     within 0.05 +- 2.5 SE under independence (F34: 0.050), within
#     [0.02, 0.08] under between-shoe heterogeneity (Dirichlet 100 around
#     each shoe's pi, F34: 0.035).
# 400 replicates per scenario (seed 20261106, inner B = 199).
#
# A third part checks the dispersion phi with the r'' centring (A-051,
# F39): with theta known and a common misfit (one cell's theta x 1.25),
# phi stays within 0.03 of phi0; under heterogeneity it exceeds phi0 by
# more than 0.3 (200 replicates, B = 200).
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "io.R", "validation.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
pass <- function(name) cat("PASS", name, "\n")
t_all <- proc.time()[["elapsed"]]
workers <- as.integer(rac_env("RAC_WORKERS", "4"))

n_old <- as.vector(table(read_locations(rac_profile("old", root = ROOT_PATH))$shoe))
n_new <- as.vector(table(read_locations(rac_profile("new", root = ROOT_PATH))$shoe))
K <- 15
band <- rep(1:5, each = 3)
reps <- 400
Bin <- 199

set.seed(20261106)
share <- runif(K, 0.5, 1.5)
share <- share / sum(share)
theta <- exp(rnorm(K, 0, 0.25))
mk_S <- function(m) t(apply(matrix(rgamma(m * K, 50 * share), m, K, byrow = TRUE),
                            1, function(r) r / sum(r)))
S_old <- mk_S(length(n_old))
S_new <- mk_S(length(n_new))
pi_of <- function(th, S) {
  num <- S * rep(th, each = nrow(S))
  num / rowSums(num)
}
sim_counts <- function(n, pi, hetero) {
  t(vapply(seq_along(n), function(i) {
    p <- pi[i, ]
    if (hetero) {
      p <- rgamma(K, 100 * p)
      p <- p / sum(p)
    }
    as.vector(rmultinom(1, n[i], p))
  }, numeric(K)))
}
info <- function(n, pi) diag(colSums(n * pi), K) - crossprod(pi, n * pi)
one_rep <- function(r, hetero) {
  set.seed(20261106 + r + if (hetero) 100000 else 0)
  O_old <- sim_counts(n_old, pi_of(theta, S_old), hetero)
  O_new <- sim_counts(n_new, pi_of(theta, S_new), hetero)
  th_hat <- regional_fit(O_old, S_old)
  pi_hat_new <- pi_of(th_hat, S_new)
  E_old <- n_new * pi_hat_new
  ob <- part2_obs_stats(O_new, E_old, band)
  # Wald with the parameter term: V = (OLD information of log theta)^+
  V <- MASS::ginv(info(n_old, pi_of(th_hat, S_old)))
  G <- info(n_new, pi_hat_new)
  wp <- wald_param(ob$D, ob$Sigma, G %*% V %*% t(G))
  # two-sample bootstrap: OLD resample refits, NEW resamples
  Wn <- part2_weights(length(n_new), Bin, 1000 + r)
  Wo <- part2_weights(length(n_old), Bin, 2000 + r)
  draw <- function(b) n_new * pi_of(regional_fit(O_old, S_old, w = Wo[b, ]), S_new)
  tb <- two_sample_bootstrap(O_new, E_old, draw, Wn, band)
  c(fixed = ob$p_chisq <= 0.05,
    newonly = (1 + sum(tb$X2_new >= ob$X2)) / (Bin + 1) <= 0.05,
    wald = wp$p <= 0.05, two = tb$p_boot <= 0.05,
    X2 = ob$X2, E0 = tb$E0)
}
for (hetero in c(FALSE, TRUE)) {
  t0 <- proc.time()[["elapsed"]]
  res <- parallel::mclapply(seq_len(reps), one_rep, hetero = hetero,
                            mc.cores = workers)
  res <- do.call(rbind, res)
  rate <- colMeans(res[, c("fixed", "newonly", "wald", "two")])
  se <- sqrt(0.05 * 0.95 / reps)
  cat(sprintf(paste("%s (%d replicates, %.0f s): rejection at 5%%: fixed",
                    "%.3f, NEW-only bootstrap %.3f, parameter-corrected Wald",
                    "%.3f, two-sample bootstrap %.3f; mean X^2 %.1f, mean E0",
                    "%.1f (K - 1 = %d)\n"),
              if (hetero) "heterogeneity" else "independence", reps,
              proc.time()[["elapsed"]] - t0, rate[["fixed"]],
              rate[["newonly"]], rate[["wald"]], rate[["two"]],
              mean(res[, "X2"]), mean(res[, "E0"]), K - 1))
  if (!hetero) {
    stopifnot(rate[["fixed"]] > 0.5, rate[["newonly"]] > 0.5,
              abs(rate[["wald"]] - 0.05) <= 2.5 * se,
              abs(rate[["two"]] - 0.05) <= 2.5 * se)
    pass("independence: fixed-surface and NEW-only tests over-reject; Wald with the parameter term and two-sample bootstrap hold their size")
  } else {
    stopifnot(rate[["two"]] >= 0.02, rate[["two"]] <= 0.08)
    pass("heterogeneity: the two-sample bootstrap stays within [0.02, 0.08]")
  }
}

# dispersion with the r'' centring (theta known)
reps2 <- 200
Wd <- part2_weights(length(n_new), 200, 33)
pi_true <- pi_of(theta, S_new)
E_true <- n_new * pi_true
mis <- theta
mis[8] <- mis[8] * 1.25
pi_mis <- pi_of(mis, S_new)
disp <- function(scenario) {
  vapply(seq_len(reps2), function(r) {
    set.seed(5000 + r)
    O <- switch(scenario,
                misfit = sim_counts(n_new, pi_mis, FALSE),
                hetero = sim_counts(n_new, pi_true, TRUE))
    ob <- part2_obs_stats(O, E_true, band)
    x2n <- vapply(seq_len(nrow(Wd)), function(b)
      part2_boot_one(ob, ob$Em, Wd[b, ])$X2_new, 0)
    c(phi = mean(x2n) / (ob$K_merged - 1), phi0 = ob$phi0, X2 = ob$X2)
  }, numeric(3))
}
dm <- disp("misfit")
dh <- disp("hetero")
cat(sprintf(paste("dispersion: common misfit (mean X^2 %.0f) phi %.3f vs phi0",
                  "%.3f; heterogeneity phi %.3f vs phi0 %.3f\n"),
            mean(dm["X2", ]), mean(dm["phi", ]), mean(dm["phi0", ]),
            mean(dh["phi", ]), mean(dh["phi0", ])))
stopifnot(abs(mean(dm["phi", ]) - mean(dm["phi0", ])) < 0.03,
          mean(dh["phi", ]) - mean(dh["phi0", ]) > 0.3)
pass("phi with the r'' centring: near phi0 under a common misfit, above it under heterogeneity")
cat(sprintf("ALL PASS test_validation_calibration (%.0f s)\n",
            proc.time()[["elapsed"]] - t_all))
