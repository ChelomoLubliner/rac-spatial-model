# Part 2 statistics on synthetic data (plan T7 step 2, test_validation_stats;
# the slow calibration checks with E estimated are in
# tests/r/slow/test_validation_calibration.R).
#
#  1. normalize_expected: rows sum to n_i (1e-9).
#  2. merge_cells: every merged E >= 5, merges stay in the band when they
#     can, else go to the adjacent band; df = K' - 1.
#  3. pearson_pooled equals the hand formula; effect_sizes on a toy.
#  4. phi0 equals the Monte Carlo mean of X^2 / (K - 1) under independent
#     multinomials with shoe-specific pi (within 3 MC standard errors) and
#     is <= 1.
#  5. regional_fit: recovers a simulated theta (relative error < 5%),
#     equals a Poisson GLM (shoe + area + offset(log S); 1e-8) and the
#     optimum of Naomi's funLogCMLlambda by optim (1e-4); its in-sample X^2
#     on its own partition is 0 (< 1e-8): "identically 0 by construction";
#     weight 2 equals a duplicated shoe; regional_expected by hand.
#  6. log scores on a two-shoe toy by hand, both weightings.
#  7. part2_weights: rows sum to m; with groups, grouped shoes always get
#     the same count; part2_boot_one with every shoe once: X2_two = 0,
#     O_unc = O.
#  8. part2_gradient equals a central finite difference of the pooled
#     normalized expected counts (relative 1e-6) on a 5-shoe pixel toy,
#     for the logit and the log link; with the log link its intercept
#     column is 0.
#  9. Calibration with E known (plan: 500 replicates, seed 11; the real
#     NEW n_i, K = 15, shoe-specific pi): the fixed-surface pooled test
#     rejects at most alpha + 2.5 SE at alpha 0.05 and 0.10, and the
#     NEW-only shoe bootstrap (B = 200) within alpha +- 2.5 SE.
# 10. part2_effect_ci (basic) and part2_effect_ci_pct (bias-shifted
#     percentile): a constant uncentred statistic collapses the interval
#     onto the point estimate; a right-skewed spread stays on the right in
#     the percentile interval and is reflected to the left (here to 0) by
#     the basic one.
# 11. T7 review fixes: part2_shift_ci moves the percentile interval so that
#     the replicates' mean is the point; part2_uniform_expected by hand;
#     part2_calib_slope equals the Poisson GLM O ~ shoe + offset(log EU) + L
#     (alpha and its SE), is 1 for the model's own counts and 0 for uniform
#     counts, a weight of 2 equals a duplicated shoe, and it recovers a
#     simulated slope; part2_pixel_slope equals the cell slope with every
#     pixel a cell, is 1 for the true fractional counts, and the grid
#     solution of the shoe bootstrap equals the exact fit per resample
#     (< 1e-6); part2_block_groups; part2_kl_uniform by hand (intensities 1
#     and 2 on equal areas: 0.0566 nats).
#
# Run from anywhere:  Rscript tests/r/test_validation_stats.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
suppressMessages(library(splines))
for (f in c("profile.R", "io.R", "distances.R", "compare.R", "validation.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
pass <- function(name) cat("PASS", name, "\n")
t_all <- proc.time()[["elapsed"]]

# 1. normalization
set.seed(1)
E <- matrix(rexp(40 * 7), 40, 7)
n <- rpois(40, 20) + 1
Et <- normalize_expected(E, n)
stopifnot(max(abs(rowSums(Et) - n)) < 1e-9,
          max(abs(normalize_expected(E * runif(40, 0.1, 10), n) - Et)) < 1e-9)
stopifnot(inherits(try(normalize_expected(rbind(E, 0), c(n, 1)), silent = TRUE),
                   "try-error"))
pass("normalize_expected: rows sum to n_i; invariant to the scale of each row")

# 2. merging
mg <- merge_cells(c(2, 50, 3, 40, 1, 60), band = c(1, 1, 2, 2, 3, 3))
Em <- as.vector(c(2, 50, 3, 40, 1, 60) %*% mg$map)
stopifnot(mg$K_merged == 3, all(Em >= 5), identical(mg$group, c(1L, 1L, 2L, 2L, 3L, 3L)))
mg2 <- merge_cells(c(30, 40, 2, 50, 60), band = c(1, 1, 2, 3, 3))
stopifnot(mg2$K_merged == 4, all(c(30, 40, 2, 50, 60) %*% mg2$map >= 5),
          mg2$group[3] == mg2$group[1] || mg2$group[3] == mg2$group[2] ||
            mg2$group[3] == mg2$group[4] || mg2$group[3] == mg2$group[5])
# the lonely cell (band 2) joined the smallest cell of an adjacent band
stopifnot(mg2$group[3] == mg2$group[1])
mg3 <- merge_cells(c(4, 1, 30, 30), band = c(1, 1, 1, 1),
                   nbr = list(2, c(1, 3), c(2, 4), 3))
stopifnot(all(c(4, 1, 30, 30) %*% mg3$map >= 5), mg3$K_merged == 3,
          mg3$group[1] == mg3$group[2])
O <- c(10, 52, 1, 45, 3, 55)
pp <- pearson_pooled(as.vector(O %*% mg$map), Em)
stopifnot(pp$df == mg$K_merged - 1)
nomerge <- merge_cells(c(10, 20, 30), band = c(1, 2, 3))
stopifnot(nomerge$K_merged == 3, identical(nomerge$map, diag(3)))
pass("merge_cells: E >= 5 after merging, same band first, adjacent band else; df = K' - 1")

# 3. Pearson and effect sizes
O <- c(12, 30, 58)
Ex <- c(20, 30, 50)
pp <- pearson_pooled(O, Ex)
stopifnot(abs(pp$X2 - (64 / 20 + 0 + 64 / 50)) < 1e-12, pp$df == 2,
          abs(pp$p - pchisq(pp$X2, 2, lower.tail = FALSE)) < 1e-15)
es <- effect_sizes(X2 = 40, E0 = 15, df = 14, N = 10000)
stopifnot(abs(es$w - sqrt(40 / 10000)) < 1e-15,
          abs(es$w_net - sqrt(25 / 10000)) < 1e-15,
          abs(es$rmsea - sqrt(25 / (14 * 9999))) < 1e-15,
          effect_sizes(10, 15, 14, 10000)$w_net == 0)
pass("pearson_pooled and effect_sizes equal the hand formulas")

# 4. phi0 is the exact expectation under independent multinomials
set.seed(4)
m <- 120
K <- 6
n <- sample(1:60, m, replace = TRUE)
base <- c(0.3, 0.2, 0.15, 0.15, 0.1, 0.1)
pi <- t(apply(matrix(rgamma(m * K, 30 * base), m, K, byrow = TRUE), 1,
              function(r) r / sum(r)))
Etk <- colSums(n * pi)
ph0 <- phi0(pi, n, Etk)
x2 <- replicate(4000, {
  Os <- t(vapply(seq_len(m), function(i) as.vector(rmultinom(1, n[i], pi[i, ])), numeric(K)))
  sum((colSums(Os) - Etk)^2 / Etk)
}) / (K - 1)
se <- sd(x2) / sqrt(length(x2))
stopifnot(ph0 <= 1, abs(mean(x2) - ph0) < 3 * se, ph0 < 0.99)
stopifnot(abs(phi0(matrix(base, m, K, byrow = TRUE), n) - 1) < 1e-12)
pass(sprintf("phi0 %.4f = Monte Carlo %.4f (SE %.4f) and <= 1; = 1 for a common pi",
             ph0, mean(x2), se))

# 5. the regional fit
set.seed(5)
m <- 280
A <- 8
S <- matrix(sample(500:5000, m * A, replace = TRUE), m, A)
S[sample(length(S), 30)] <- 0
th_true <- c(1, 1.5, 0.8, 2, 1.2, 0.6, 1.7, 1.1) * 2e-3
a <- rnorm(m, 0, 0.8)
O <- matrix(rpois(m * A, exp(a) * rep(th_true, each = m) * S), m, A)
O[rowSums(O) == 0, 1] <- 1
O[S == 0] <- 0
th <- regional_fit(O, S)
rel <- (th / th[1]) / (th_true / th_true[1])
stopifnot(max(abs(rel - 1)) < 0.05)
cells <- data.frame(O = as.vector(O), S = as.vector(S),
                    shoe = factor(rep(seq_len(m), A)),
                    area = factor(rep(seq_len(A), each = m)))
cells <- cells[cells$S > 0, ]
gl <- glm(O ~ shoe + area + offset(log(S)), family = poisson, data = cells)
g_rel <- c(1, exp(coef(gl)[paste("area", 2:A, sep = "")]))
stopifnot(max(abs((th / th[1]) / g_rel - 1)) < 1e-8)
op <- optim(log((th_true / th_true[1])[-1]), naomi_funLogCMLlambda,
            contact_mat = S / 10000, n_ij = O, method = "BFGS",
            control = list(reltol = 1e-14, maxit = 1000))
stopifnot(max(abs((th / th[1])[-1] / exp(op$par) - 1)) < 1e-4)
Sak_own <- array(0, c(m, A, A))
for (k in seq_len(A)) Sak_own[, k, k] <- S[, k]
Er <- regional_expected(th, Sak_own, rowSums(O))
stopifnot(max(abs(colSums(Er) - colSums(O))) < 1e-8)
x2_in <- pearson_pooled(colSums(O), colSums(Er))$X2
stopifnot(x2_in < 1e-8)
w <- rep(1, m)
w[1] <- 2
stopifnot(max(abs(regional_fit(O, S, w) / regional_fit(rbind(O, O[1, ]),
                                                        rbind(S, S[1, ])) - 1)) < 1e-10)
sak <- array(0, c(2, 2, 2))
sak[1, , ] <- matrix(c(3, 1, 0, 2), 2)
sak[2, , ] <- matrix(c(1, 1, 1, 1), 2)
er <- regional_expected(c(1, 3), sak, c(10, 4))
stopifnot(max(abs(er[1, ] - 10 * c(1 * 3 + 3 * 1, 1 * 0 + 3 * 2) / 12)) < 1e-12,
          max(abs(er[2, ] - 4 * c(4, 4) / 8)) < 1e-12)
pass(sprintf(paste("regional_fit: recovery within %.3f; = Poisson GLM (%.1e);",
                   "= Naomi's funLogCMLlambda by optim (%.1e); in-sample X^2",
                   "on its partition %.1e (identically 0 by construction);",
                   "weights = duplicates; regional_expected by hand"),
             max(abs(rel - 1)), max(abs((th / th[1]) / g_rel - 1)),
             max(abs((th / th[1])[-1] / exp(op$par) - 1)), x2_in))

# 6. log scores by hand: shoe 1 has 4 pixels, RACs at pixel 2 and twice at
#    pixel 4; shoe 2 has 2 pixels, one RAC at pixel 2
p1 <- c(0.1, 0.2, 0.3, 0.4) / 2
p2 <- c(1, 3) / 10
ev <- list(lsum = c(log(p1[2]) + 2 * log(p1[4]), log(p2[2])),
           tot = c(sum(p1), sum(p2)))
nn <- c(3, 1)
lsC <- part2_ls_model(ev, nn)
h1 <- log(0.2) + 2 * log(0.4)
h2 <- log(3 / 4)
stopifnot(max(abs(lsC - c(h1, h2))) < 1e-12)
rac_w <- sum(lsC) / sum(nn)
shoe_w <- mean(lsC / nn)
stopifnot(abs(rac_w - (h1 + h2) / 4) < 1e-12,
          abs(shoe_w - (h1 / 3 + h2 / 1) / 2) < 1e-12)
# regional: theta (1, 2); shoe 1 pixels in areas (1, 1, 2, 2), shoe 2 in (1, 2)
O_area <- rbind(c(0, 3), c(0, 1))
O_area[1, ] <- c(1, 2)
S_area <- rbind(c(2, 2), c(1, 1))
lsR <- part2_ls_regional(c(1, 2), O_area, S_area)
stopifnot(max(abs(lsR - c(log(1 / 6) + 2 * log(2 / 6), log(2 / 3)))) < 1e-12)
stopifnot(max(abs(part2_ls_uniform(nn, c(4, 2)) - c(-3 * log(4), -log(2)))) < 1e-12)
pass("log scores: continuous, regional and uniform terms by hand; RAC- and shoe-weighted means")

# 7. resampling weights and one replicate
Wt <- part2_weights(25, 50, 3)
stopifnot(all(rowSums(Wt) == 25), identical(Wt, part2_weights(25, 50, 3)))
grp <- rep(1:10, length.out = 25)
Wg <- part2_weights(25, 50, 3, groups = grp)
for (g in unique(grp)) {
  stopifnot(all(apply(Wg[, grp == g, drop = FALSE], 1,
                      function(r) length(unique(r)) == 1)))
}
set.seed(8)
Om <- matrix(rpois(30 * 5, 4), 30, 5)
Om[rowSums(Om) == 0, 1] <- 1
Ex <- normalize_expected(matrix(runif(30 * 5), 30, 5), rowSums(Om))
ob <- part2_obs_stats(Om, Ex, band = 1:5)
r1 <- part2_boot_one(ob, ob$Em, rep(1, 30))
stopifnot(abs(r1$X2_two) < 1e-20 + 1e-12, abs(r1$X2_new) < 1e-12,
          max(abs(r1$O_unc - ob$O)) < 1e-12,
          abs(r1$X2_unc - ob$X2) < 1e-9,
          max(abs(colSums(ob$rpp))) < 1e-9)
pass("part2_weights: m per row, reproducible, groups kept together; part2_boot_one with every shoe once")

# 8. the gradient of the pooled normalized expected counts
set.seed(9)
nshoe <- 5
H <- 40
yl <- seq(-0.45, 0.45, length.out = H)
toy <- do.call(rbind, lapply(seq_len(nshoe), function(k) {
  npx <- 400
  r <- sample(seq_len(H), npx, replace = TRUE)
  data.frame(code = k, row = r, y = yl[r], new_x = runif(npx, -0.15, 0.2),
             N = c(rep(1L, 6), rep(0L, npx - 6)))
}))
toy$x <- toy$new_x * 1.1
attr(toy, "y_levels") <- yl
bk <- basis_knots(toy)
ck <- grid_cuts_from_old(toy$new_x, toy$y, 5, 3)
prep <- part2_prepare(toy, bk, ck, nshoe)
nm <- c("(Intercept)", as.vector(outer(1:4, 1:6, function(a, b)
  paste("bx", a, ":by", b, sep = ""))))
co <- setNames(c(-2, rnorm(24, 0, 0.5)), nm)
pooled <- function(beta, link, offset) {
  ev <- part2_eval(prep, part2_coef_parts(beta), link, offset)
  colSums(normalize_expected(part2_agg(prep, ev$Eg, "g15"), prep$n))
}
for (link in c("logit", "log")) {
  off <- if (link == "logit") -1.5 else 0
  G <- part2_gradient(prep, part2_coef_parts(co), "g15", seq_len(nshoe), off,
                      link)
  h <- 1e-5
  Gn <- sapply(seq_along(co), function(q) {
    e <- replace(numeric(length(co)), q, h)
    (pooled(co + e, link, off) - pooled(co - e, link, off)) / (2 * h)
  })
  relerr <- max(abs(G - Gn)) / max(abs(Gn))
  stopifnot(relerr < 1e-6)
  if (link == "log") stopifnot(max(abs(G[, 1])) < 1e-12 * max(abs(G)))
  cat(sprintf("  %s: max |G - finite difference| / max |G| = %.2e\n", link, relerr))
}
pass("part2_gradient = central finite differences (logit and log); log link intercept column 0")

# 9. calibration with E known: real NEW n_i, K = 15, shoe-specific pi
P_new <- rac_profile("new", root = ROOT_PATH)
n_new <- as.vector(table(read_locations(P_new)$shoe))
m <- length(n_new)
K <- 15
set.seed(11)
base <- runif(K, 0.5, 1.5)
base <- base / sum(base)
pi <- t(apply(matrix(rgamma(m * K, 30 * base), m, K, byrow = TRUE), 1,
              function(r) r / sum(r)))
Etrue <- n_new * pi
reps <- 500
Bb <- 200
band <- rep(1:5, each = 3)
Wb <- part2_weights(m, Bb, 12)
pfix <- pboot <- numeric(reps)
for (r in seq_len(reps)) {
  Os <- t(vapply(seq_len(m), function(i) as.vector(rmultinom(1, n_new[i], pi[i, ])),
                 numeric(K)))
  ob <- part2_obs_stats(Os, Etrue, band)
  x2n <- vapply(seq_len(Bb), function(b) part2_boot_one(ob, ob$Em, Wb[b, ])$X2_new, 0)
  pfix[r] <- ob$p_chisq
  pboot[r] <- (1 + sum(x2n >= ob$X2)) / (Bb + 1)
}
for (al in c(0.05, 0.10)) {
  se <- sqrt(al * (1 - al) / reps)
  rf <- mean(pfix <= al)
  rb <- mean(pboot <= al)
  cat(sprintf("  alpha %.2f: fixed-surface pooled %.3f, NEW-only bootstrap %.3f (band +-%.3f)\n",
              al, rf, rb, 2.5 * se))
  stopifnot(rf <= al + 2.5 * se, abs(rb - al) <= 2.5 * se)
}
pass("calibration with E known: pooled test at most nominal, shoe bootstrap at nominal")

# 10. effect-size interval
ci <- part2_effect_ci(X2 = 60, E0 = 20, X2_unc = rep(80, 100), df = 14, N = 10000)
stopifnot(abs(ci$net_lo - 40) < 1e-12, abs(ci$net_hi - 40) < 1e-12)
cp <- part2_effect_ci_pct(E0 = 20, X2_unc = rep(80, 100), df = 14, N = 10000)
stopifnot(abs(cp$net_lo - 40) < 1e-12, abs(cp$net_hi - 40) < 1e-12,
          abs(cp$w_net_lo - sqrt(40 / 10000)) < 1e-15)
# a right-skewed spread: the percentile interval keeps the skew on the right
xu <- 80 + c(-10, 0, 0, 0, 40)
cq <- part2_effect_ci_pct(E0 = 20, X2_unc = rep(xu, 20), df = 14, N = 10000)
cb <- part2_effect_ci(X2 = 60, E0 = 20, X2_unc = rep(xu, 20), df = 14, N = 10000)
stopifnot(abs(cq$net_lo - 30) < 1e-12, abs(cq$net_hi - 80) < 1e-12,
          abs(cb$net_lo - 0) < 1e-12, abs(cb$net_hi - 50) < 1e-12)
pass("effect-size intervals: constant replicates give the point estimate; skew stays right (percentile) or is reflected (basic)")

# 11. T7 review fixes: centred intervals, the uniform benchmark, the
# calibration slope (cell and pixel level), blocks, the self-predicted gain
set.seed(21)
noise <- rnorm(400)
v <- 5 + 0.3 + noise
ci <- part2_shift_ci(v, 5)
stopifnot(abs(ci$lo - (5 + quantile(noise, 0.025, names = FALSE) - mean(noise))) < 1e-12,
          abs(ci$hi - (5 + quantile(noise, 0.975, names = FALSE) - mean(noise))) < 1e-12,
          abs(ci$shift - (0.3 + mean(noise))) < 1e-12)
cc <- part2_shift_ci(rep(7, 50), 2)
stopifnot(cc$lo == 2, cc$hi == 2, cc$shift == 5)
pass("part2_shift_ci: the percentile interval moved so that the replicates' mean is the point")

Sx <- matrix(c(10, 0, 30, 5, 5, 0), 2, 3, byrow = TRUE)
Eu <- part2_uniform_expected(Sx, rowSums(Sx), c(8, 4))
stopifnot(max(abs(Eu - rbind(c(2, 0, 6), c(2, 2, 0)))) < 1e-12)
pass("part2_uniform_expected: n_i S_ik / S_i by hand")

# the cell-level slope: a toy with shoe-specific contact, some cells off
# contact, counts simulated from P(alpha = 0.6)
set.seed(22)
m <- 400
K <- 8
Sc <- matrix(rgamma(m * K, 2), m, K)
Sc[matrix(runif(m * K) < 0.1, m, K)] <- 0
nn <- rpois(m, 30) + 2
th <- exp(rnorm(K, 0, 0.6))
EUc <- part2_uniform_expected(Sc, rowSums(Sc), nn)
EMc <- normalize_expected(t(t(Sc) * th), nn)
Lc <- ifelse(Sc > 0, log(EMc / pmax(EUc, 1e-300)), 0)  # rac: literal-ok (numerical guard against log(0), not a dataset number)
Pt <- EUc * exp(0.6 * Lc)
Pt <- Pt / rowSums(Pt)
Oc <- t(vapply(seq_len(m), function(i) as.vector(rmultinom(1, nn[i], Pt[i, ])),
               numeric(K)))
f <- part2_calib_slope(Oc, EMc, EUc)
long <- data.frame(O = as.vector(Oc), EU = as.vector(EUc), L = as.vector(Lc),
                   shoe = factor(rep(seq_len(m), K)))
long <- long[long$EU > 0, ]
gl <- stats::glm(O ~ shoe + L + offset(log(EU)), family = stats::poisson,
                 data = long)
stopifnot(f$converged, abs(f$alpha - coef(gl)[["L"]]) < 1e-7,
          abs(f$se / sqrt(vcov(gl)["L", "L"]) - 1) < 1e-5,
          abs(f$alpha - 0.6) < 4 * f$se,
          max(abs(rowSums(f$fitted) - nn)) < 1e-9)
stopifnot(abs(part2_calib_slope(EMc, EMc, EUc)$alpha - 1) < 1e-9,
          abs(part2_calib_slope(EUc, EMc, EUc)$alpha) < 1e-9)
# a weight of 2 equals the shoe counted twice
wv <- c(2, rep(1, m - 1))
f2 <- part2_calib_slope(Oc, EMc, EUc, w = wv)
f3 <- part2_calib_slope(rbind(Oc[1, ], Oc), rbind(EMc[1, ], EMc),
                        rbind(EUc[1, ], EUc))
stopifnot(abs(f2$alpha - f3$alpha) < 1e-10)
stopifnot(inherits(try(part2_calib_slope(Oc + 1, EMc, EUc), silent = TRUE),
                   "try-error"))
cat(sprintf("  cell slope %.4f (SE %.4f, true 0.6) = Poisson GLM %.4f\n",
            f$alpha, f$se, coef(gl)[["L"]]))
pass("part2_calib_slope = the Poisson GLM with shoe effects (alpha and SE); 1 for the model's own counts, 0 for uniform; weights = duplicates; counts off contact refused")

# the pixel-level slope: every pixel its own cell
set.seed(23)
nsh <- 6
npx <- 60
code <- rep(seq_len(nsh), each = npx)
lp <- rnorm(nsh * npx, -7, 0.8)
Npx <- as.vector(vapply(seq_len(nsh), function(i) {
  p <- exp(0.7 * lp[code == i])
  as.vector(rmultinom(1, 25 + 5 * i, p / sum(p)))
}, numeric(npx)))
n_sh <- as.vector(tapply(Npx, code, sum))
s_sh <- part2_shoe_sums(Npx * lp, code, nsh)
fp <- part2_pixel_slope(lp, code, s_sh, n_sh)
Om <- matrix(Npx, nsh, npx, byrow = TRUE)
EMp <- normalize_expected(matrix(exp(lp), nsh, npx, byrow = TRUE), n_sh)
EUp <- matrix(n_sh / npx, nsh, npx)
fc <- part2_calib_slope(Om, EMp, EUp)
stopifnot(fp$converged, abs(fp$alpha - fc$alpha) < 1e-9,
          abs(fp$se - fc$se) < 1e-9)
qpx <- as.vector(t(EMp))
fq <- part2_pixel_slope(lp, code, part2_shoe_sums(qpx * lp, code, nsh), n_sh)
stopifnot(abs(fq$alpha - 1) < 1e-9)
w0 <- c(1, 0, 1, 1, 0, 1)
fw <- part2_pixel_slope(lp, code, s_sh, n_sh, w = w0)
fs <- part2_calib_slope(Om[w0 > 0, ], EMp[w0 > 0, ], EUp[w0 > 0, ])
stopifnot(abs(fw$alpha - fs$alpha) < 1e-9)
# the grid solution of the shoe bootstrap equals the exact fit per resample
use <- seq_len(nsh)
gr <- part2_pixel_slope_grid(lp, code, s_sh, n_sh, use, seq(0, 2, by = 0.01))
Wp <- part2_weights(nsh, 30, 24)
ab <- part2_pixel_slope_boot(gr, Wp)
ex <- vapply(seq_len(nrow(Wp)), function(b)
  part2_pixel_slope(lp, code, s_sh, n_sh, w = Wp[b, ])$alpha, 0)
stopifnot(max(abs(ab - ex)) < 1e-6)
cat(sprintf("  pixel slope %.4f = cell slope with pixels as cells %.4f; grid vs exact over 30 resamples: max %.1e\n",
            fp$alpha, fc$alpha, max(abs(ab - ex))))
pass("part2_pixel_slope = part2_calib_slope with every pixel a cell; 1 for the true counts; weights 0 drop shoes; grid bootstrap = exact per resample")

set.seed(25)
cd <- sort(sample(c(1:7, 9), 5000, replace = TRUE))
vv <- rexp(5000) * sample(c(-1, 1), 5000, replace = TRUE)
ref <- numeric(10)
rr <- rowsum(vv, cd, reorder = TRUE)
ref[as.integer(rownames(rr))] <- rr[, 1]
fast <- part2_shoe_sums(vv, cd, 10)
perm <- sample.int(5000)
slow <- part2_shoe_sums(vv[perm], cd[perm], 10)
stopifnot(max(abs(fast - ref)) < 1e-10, max(abs(slow - ref)) < 1e-12,
          fast[8] == 0, fast[10] == 0)
pass("part2_shoe_sums: the cumulative-sum path (codes in order) and rowsum agree; empty codes 0")

stopifnot(identical(part2_block_groups(1:9, 2), c(0L, 0L, 1L, 1L, 2L, 2L, 3L, 3L, 4L)),
          identical(part2_block_groups(c(4L, 5L, 8L), 4), c(0L, 1L, 1L)))
pass("part2_block_groups: consecutive ids in blocks")

kl1 <- part2_kl_uniform(log(c(1, 1, 2, 4)), rep(1L, 4), 1L)
kl2 <- part2_kl_uniform(log(rep(c(1, 2), each = 50)), rep(1L, 100), 1L)
stopifnot(abs(kl1 - (0.25 * log(0.5) + 0.5 * log(2))) < 1e-12,
          abs(kl2 - ((1 / 3) * log(2 / 3) + (2 / 3) * log(4 / 3))) < 1e-12)
cat(sprintf("  intensities 1 and 2 on equal areas: expected gain over uniform %.4f nats per RAC\n", kl2))
pass("part2_kl_uniform: the expected log-score gain over uniform by hand")
cat(sprintf("ALL PASS test_validation_stats (%.0f s)\n",
            proc.time()[["elapsed"]] - t_all))
