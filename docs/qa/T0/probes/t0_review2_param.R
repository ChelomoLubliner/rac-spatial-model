# T0 review-fix pass 2 probe (R): simulation checks for the second T0
# review (statistician), written independently of the reviewer's probes.
#
# P1  Part 2 goodness of fit when the expected counts come from a model
#     estimated on OLD (section 9 treats them as known). Toy with the real
#     per-shoe RAC counts of both datasets, K = 15 cells, shoe-specific
#     contact shares, a cell model fitted on OLD by its conditional
#     multinomial MLE (= Poisson GLM shoe + cell + offset). Size at
#     nominal 5% of: the fixed-E pooled Pearson test, the NEW-only shoe
#     bootstrap, a parameter-corrected Wald statistic and the two-sample
#     (OLD refit + NEW resample) shoe bootstrap; under independence and
#     under between-shoe heterogeneity.
# P2  Dispersion phi under a common (shoe-independent) misfit: bootstrap
#     residuals centred on the model, as in plan section 9, versus centred
#     on the model minus each shoe's share of the pooled misfit.
# P3  Wald tests with a bootstrap covariance (B = 200, p = 24): chi^2 vs
#     the Hotelling F(p, B - p) reference; equality test with V1 + V2 from
#     separate draws vs one covariance of paired difference draws.
#
# Simulation only; reads the two location files for n_i; writes nothing.
# Run from the repo root: Rscript docs/qa/T0/probes/t0_review2_param.R
t_start <- proc.time()[["elapsed"]]
old <- read.csv("data/locations_data.csv")
n_old <- as.numeric(table(old$shoe))
raw <- read.table("data/new_shoes/locations_data_new_raw.txt")
n_new <- as.numeric(table(raw$V1))
cat(sprintf("n_i: OLD %d shoes, %d RACs; NEW %d shoes, %d RACs\n",
            length(n_old), sum(n_old), length(n_new), sum(n_new)))

K <- 15
LT_TRUE <- 0.35 * sin(seq_len(K))              # true log relative intensity
ginv <- function(A, tol = 1e-10) {               # symmetric pseudo-inverse
  e <- eigen((A + t(A)) / 2, symmetric = TRUE)
  keep <- e$values > tol * max(e$values)
  e$vectors[, keep, drop = FALSE] %*%
    (t(e$vectors[, keep, drop = FALSE]) / e$values[keep])
}
expo <- function(m, conc = 30) {                 # contact share per cell
  g <- matrix(rgamma(m * K, conc / K), m, K)
  g / rowSums(g)
}
pi_of <- function(lt, S) {
  w <- S * rep(exp(lt), each = nrow(S))
  w / rowSums(w)
}
rmult <- function(n, P) {
  t(vapply(seq_along(n), function(i) as.numeric(rmultinom(1, n[i], P[i, ])),
           numeric(K)))
}
rdir_rows <- function(P, alpha) {                # Dirichlet(alpha * P_i)
  g <- matrix(rgamma(length(P), alpha * P), nrow(P))
  g / rowSums(g)
}
fit_lt <- function(O, S, n, lt = rep(0, K)) {    # conditional multinomial MLE
  Ok <- colSums(O)
  for (it in 1:500) {
    step <- log(Ok / colSums(n * pi_of(lt, S)))
    lt <- lt + step
    lt <- lt - mean(lt)
    if (max(abs(step)) < 1e-10) break
  }
  lt
}
info <- function(n, P) diag(colSums(n * P)) - t(P) %*% (n * P)

p1_rep <- function(alpha_het, B = 199) {
  S_o <- expo(length(n_old))
  S_n <- expo(length(n_new))
  P_o <- pi_of(LT_TRUE, S_o)
  P_n <- pi_of(LT_TRUE, S_n)
  if (is.finite(alpha_het)) {                    # heterogeneity around P
    P_o <- rdir_rows(P_o, alpha_het)
    P_n <- rdir_rows(P_n, alpha_het)
  }
  O_o <- rmult(n_old, P_o)
  O_n <- rmult(n_new, P_n)
  lt <- fit_lt(O_o, S_o, n_old)
  Pn_hat <- pi_of(lt, S_n)
  E_in <- n_new * Pn_hat                          # E~_ik (normalized)
  E <- colSums(E_in)
  D <- colSums(O_n) - E
  N <- sum(n_new)
  x2 <- sum(D^2 / E)
  # parameter-corrected Wald: Var(D) = Sigma_mult + G V G'; for this model
  # G = dE/dlt = info(NEW) and V = info(OLD)^+ (log-theta parametrization)
  I_n <- info(n_new, Pn_hat)
  I_o <- info(n_old, pi_of(lt, S_o))
  w_par <- as.numeric(t(D) %*% ginv(I_n + I_n %*% ginv(I_o) %*% I_n) %*% D)
  w_mult <- as.numeric(t(D) %*% ginv(I_n) %*% D)  # no parameter term
  # bootstraps: residuals minus each shoe's share of the pooled misfit
  r2 <- (O_n - E_in) - outer(n_new, D / N)
  x2_new <- x2_two <- numeric(B)
  for (b in seq_len(B)) {
    io <- sample.int(length(n_old), replace = TRUE)
    inew <- sample.int(length(n_new), replace = TRUE)
    lt_b <- fit_lt(O_o[io, ], S_o[io, ], n_old[io], lt)
    Eb_in <- n_new[inew] * pi_of(lt_b, S_n[inew, ])
    d_new <- colSums(r2[inew, , drop = FALSE])
    x2_new[b] <- sum(d_new^2 / colSums(E_in[inew, ]))
    d_two <- d_new - colSums(Eb_in - E_in[inew, ])
    x2_two[b] <- sum(d_two^2 / colSums(Eb_in))
  }
  c(fixed = x2 > qchisq(0.95, K - 1),
    wald_mult = w_mult > qchisq(0.95, K - 1),
    wald_par = w_par > qchisq(0.95, K - 1),
    boot_new = (1 + sum(x2_new >= x2)) / (B + 1) <= 0.05,
    boot_two = (1 + sum(x2_two >= x2)) / (B + 1) <= 0.05,
    x2 = x2, ex2_two = mean(x2_two))
}

cat("\n=== P1. Part 2 goodness of fit with OLD-estimated expectations\n")
R1 <- 400
for (sc in list(list(lab = "independent RACs (H0 true)", a = Inf),
                list(lab = "between-shoe heterogeneity, Dirichlet(100 pi)",
                     a = 100))) {
  set.seed(20261106)
  t0 <- proc.time()[["elapsed"]]
  res <- t(replicate(R1, p1_rep(sc$a)))
  rej <- colMeans(res[, 1:5])
  cat(sprintf("%s: %d replicates, B = 199, %.0f s\n", sc$lab, R1,
              proc.time()[["elapsed"]] - t0))
  cat(sprintf("  mean X^2 (fixed E) = %.2f (K - 1 = %d); mean two-sample bootstrap X^2* = %.2f\n",
              mean(res[, "x2"]), K - 1, mean(res[, "ex2_two"])))
  cat(sprintf("  rejection at nominal 5%% (binomial SE %.3f): fixed-E pooled %.3f | Wald, multinomial only %.3f | Wald + parameter term %.3f | NEW-only bootstrap %.3f | two-sample bootstrap %.3f\n",
              sqrt(0.05 * 0.95 / R1), rej["fixed"], rej["wald_mult"],
              rej["wald_par"], rej["boot_new"], rej["boot_two"]))
}

cat("\n=== P2. dispersion phi under a common misfit (NEW n_i, model known)\n")
p2_rep <- function(kind, B = 200) {
  S <- expo(length(n_new))
  P <- pi_of(LT_TRUE, S)
  Ptrue <- switch(kind,
                  indep = P,
                  misfit = pi_of(LT_TRUE + 0.15 * cos(seq_len(K) * 2), S),
                  het = rdir_rows(P, 100))
  O <- rmult(n_new, Ptrue)
  E_in <- n_new * P
  E <- colSums(E_in)
  D <- colSums(O) - E
  N <- sum(n_new)
  r <- O - E_in
  r2 <- r - outer(n_new, D / N)
  phi0 <- (K - sum(colSums(n_new * P^2) / E)) / (K - 1)
  a <- b2 <- numeric(B)
  for (b in seq_len(B)) {
    i <- sample.int(length(n_new), replace = TRUE)
    Eb <- colSums(E_in[i, ])
    a[b] <- sum((colSums(r[i, , drop = FALSE]) - D)^2 / Eb)
    b2[b] <- sum(colSums(r2[i, , drop = FALSE])^2 / Eb)
  }
  c(x2 = sum(D^2 / E), phi_model = mean(a) / (K - 1),
    phi_centred = mean(b2) / (K - 1), phi0 = phi0)
}
for (kind in c("indep", "misfit", "het")) {
  set.seed(20261107)
  res <- t(replicate(200, p2_rep(kind)))
  m <- colMeans(res)
  cat(sprintf("%-6s (200 replicates): mean X^2 %.1f | phi centred on the model %.3f | phi centred on the model minus the pooled misfit %.3f | phi_0 %.3f\n",
              kind, m["x2"], m["phi_model"], m["phi_centred"], m["phi0"]))
}
cat(sprintf("var(n)/mean(n): NEW %.1f, OLD %.1f\n", var(n_new) / mean(n_new),
            var(n_old) / mean(n_old)))

cat("\n=== P3. Wald tests with a bootstrap covariance, p = 24\n")
p <- 24
L <- chol(toeplitz(0.5^(0:(p - 1))))
draws <- function(B, scale = 1) matrix(rnorm(B * p), B, p) %*% L * scale
q95 <- qchisq(0.95, p)
set.seed(20261108)
reps <- 10000
for (B in c(200, 1000)) {
  w <- numeric(reps)
  for (r in seq_len(reps)) {
    b <- as.numeric(crossprod(L, rnorm(p)))
    w[r] <- sum(b * solve(cov(draws(B)), b))
  }
  cat(sprintf("one dataset, B = %4d: mean W %.2f (theory p (B - 1) / (B - p - 2) = %.2f); rejection chi^2_24 %.4f, F(p, B - p) %.4f\n",
              B, mean(w), p * (B - 1) / (B - p - 2), mean(w > q95),
              mean(w * (B - p) / (p * (B - 1)) > qf(0.95, p, B - p))))
}
B <- 200
w_sep <- w_pair <- numeric(reps)
for (r in seq_len(reps)) {
  d <- as.numeric(crossprod(L, rnorm(p))) * sqrt(1 + 1.5^2)
  d1 <- draws(B)
  d2 <- draws(B, 1.5)
  w_sep[r] <- sum(d * solve(cov(d1) + cov(d2), d))
  w_pair[r] <- sum(d * solve(cov(d1 - d2), d))
}
cat(sprintf("equality, B = %d per dataset (V2 = 2.25 V1): V1 + V2 from separate draws, chi^2_24: %.4f | one covariance of the paired differences: chi^2_24 %.4f, F(p, B - p) %.4f\n",
            B, mean(w_sep > q95), mean(w_pair > q95),
            mean(w_pair * (B - p) / (p * (B - 1)) > qf(0.95, p, B - p))))
cat(sprintf("\ntotal %.0f s\n", proc.time()[["elapsed"]] - t_start))
