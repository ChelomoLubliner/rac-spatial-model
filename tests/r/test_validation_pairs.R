# The within-shoe pair test of Part 2 (plan T7 step 2, test_validation_pairs;
# the rejection-rate checks of the plan's reduced setting are in
# tests/r/slow/test_validation_pairs_calibration.R).
#
# 1. pair_counts() counts each unordered pair once, puts pairs on the same
#    pixel in d0 and bands as (a, b].
# 2. pair_expected() (FFT) equals the brute-force double sum over pixel
#    pairs on a 30 x 30 toy (< 1e-9) for every band and for d0.
# 3. pair_kernels() pads enough: an image filling its frame gives the same
#    expected counts as the same image in a larger frame.
# 4. gauss_smooth_at() equals the dense separable smoothing at the pixels.
# 5. pair_summary(): pooled ratio, the Monte Carlo p convention and the
#    shoe-weighted ratio by hand on a 3-shoe toy.
# 6. pair_test_shoes(): the mean of 4,000 simulated pooled counts equals
#    the FFT expectation per band (|z| < 4), and a rerun with the same seed
#    gives the same simulations.
# 7. pair_sim_shoe() (squared integer distances, all samples of a chunk at
#    once) counts exactly as pair_counts() sample by sample.
#
# Run from anywhere:  Rscript tests/r/test_validation_pairs.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
source(file.path(root, "statistical_model", "R", "pairs.R"))
pass <- function(name) cat("PASS", name, "\n")

# 1. counting: points (1,1), (1,4), (5,1), (1,4) again
pc <- pair_counts(c(1, 1, 5, 1), c(1, 4, 1, 4))
# pairs: (1,1)-(1,4) d 3 twice, (1,1)-(5,1) d 4, (1,4)-(5,1) d 5 twice,
# (1,4)-(1,4) d 0 once: 6 = choose(4, 2) pairs
stopifnot(pc[["d0"]] == 1, pc[["(2,4]"]] == 3, pc[["(4,8]"]] == 2,
          sum(pc) == choose(4, 2), pc[["(0,2]"]] == 0)
stopifnot(all(pair_counts(c(1, 3), c(1, 1)) == c(0, 1, 0, 0, 0, 0)),
          all(pair_counts(c(1, 3.5), c(1, 1)) == c(0, 0, 1, 0, 0, 0)),
          sum(pair_counts(1, 1)) == 0)
pass("pair_counts: unordered pairs once, duplicates in d0, (a, b] bands")

# 2. FFT expectation = brute force
set.seed(3)
H <- 30
W <- 30
pim <- matrix(runif(H * W) * (runif(H * W) < 0.6), H, W)
pim <- pim / sum(pim)
kern <- pair_kernels(H, W)
e <- pair_expected(pim, 10, kern)
idx <- which(pim > 0, arr.ind = TRUE)
p <- pim[idx]
D <- sqrt(outer(idx[, 1], idx[, 1], "-")^2 + outer(idx[, 2], idx[, 2], "-")^2)
bf <- vapply(1:5, function(k) sum(outer(p, p) *
  (D > PAIR_ANNULI[k] & D <= PAIR_ANNULI[k + 1])), 0) * choose(10, 2)
stopifnot(max(abs(e[-1] - bf)) < 1e-9,
          abs(e[["d0"]] - choose(10, 2) * sum(p^2)) < 1e-12)
pass(sprintf("pair_expected (FFT) = brute force on a 30 x 30 toy (max diff %.1e)",
             max(abs(e[-1] - bf))))

# 3. padding: the same image in a larger frame
full <- matrix(runif(H * W), H, W)
full <- full / sum(full)
big <- matrix(0, H + 40, W + 25)
big[11:(10 + H), 6:(5 + W)] <- full
e1 <- pair_expected(full, 7, kern)
e2 <- pair_expected(big, 7, pair_kernels(H + 40, W + 25))
stopifnot(max(abs(e1 - e2)) < 1e-10)
pass("pair_kernels: no wrap-around for an image that fills its frame")

# 4. sparse smoothing = dense smoothing
M <- matrix(0, 40, 30)
k <- cbind(c(3, 17, 22, 40, 9), c(30, 2, 15, 7, 9))
M[k] <- c(1, 2, 1, 3, 1)
g <- gauss_smooth(M, 5)
q <- cbind(sample(40, 60, TRUE), sample(30, 60, TRUE))
stopifnot(max(abs(gauss_smooth_at(q[, 1], q[, 2], k[, 1], k[, 2], M[k], 5) -
                    g[q])) < 1e-15)
pass("gauss_smooth_at = gauss_smooth at the pixels")

# 5. pair_summary by hand on a 3-shoe toy
res <- list(
  obs = rbind(c(0, 1, 2, 1, 0, 0), c(0, 0, 0, 0, 0, 0), c(1, 0, 1, 0, 2, 1)),
  exp = rbind(c(0, 1, 1, 1, 1, 1), c(0, 0.5, 0.5, 0.5, 0.5, 0.5),
              c(0.2, 1, 2, 2, 1, 1)),
  sims = rbind(c(0, 1, 2, 2, 1, 1), c(0, 2, 5, 2, 1, 1), c(0, 0, 1, 1, 1, 1)),
  sim_shoe_ratio = c(0.5, 2, 1), use2 = c(TRUE, TRUE, TRUE))
colnames(res$obs) <- colnames(res$exp) <- colnames(res$sims) <-
  c("d0", "(0,2]", "(2,4]", "(4,8]", "(8,16]", "(16,32]")
Wt <- rbind(c(1, 1, 1), c(2, 0, 1), c(0, 3, 0))
sm <- pair_summary(res, Wt, "toy")
r28 <- sm[sm$band == "(2,8]" & sm$weight == "pairs", ]
# pooled (2, 8]: obs 2+1 + 0 + 1+0 = 4, exp 1+1 + 0.5+0.5 + 2+2 = 7
stopifnot(r28$obs == 4, r28$expected == 7, abs(r28$ratio - 4 / 7) < 1e-15)
# Monte Carlo p: sims (2,8] = 4, 7, 2 -> #{>= 4} = 2 -> (1 + 2) / 4
stopifnot(abs(r28$p_mc - 3 / 4) < 1e-15)
# shoe-weighted: mean of 3/2, 0/1, 1/4
sw <- sm[sm$weight == "shoes", ]
stopifnot(abs(sw$ratio - mean(c(3 / 2, 0, 1 / 4))) < 1e-15,
          abs(sw$p_mc - (1 + 2) / 4) < 1e-15)
pass("pair_summary: pooled ratio, Monte Carlo p and shoe-weighted ratio by hand")
# 6. the simulations average to the FFT expectation (3 toy shoes)
set.seed(6)
toy <- lapply(1:3, function(i) {
  pim <- matrix(runif(H * W) * (runif(H * W) < 0.7), H, W)
  pim <- pim / sum(pim)
  idx <- which(pim > 0, arr.ind = TRUE)
  N <- integer(nrow(idx))
  N[sample(nrow(idx), 12 + i)] <- 1L
  list(row = idx[, 1], col = idx[, 2], pi = pim[idx], N = N)
})
res <- pair_test_shoes(toy, 4000, 99, kern, H, W)
m_sim <- colMeans(res$sims)
se_sim <- apply(res$sims, 2, sd) / sqrt(nrow(res$sims))
e_tot <- colSums(res$exp)
zz <- (m_sim - e_tot) / se_sim
stopifnot(all(abs(zz[-1]) < 4), abs(m_sim[["d0"]] - e_tot[["d0"]]) < 4 * se_sim[["d0"]] + 1e-9)
stopifnot(identical(res$sims, pair_test_shoes(toy, 4000, 99, kern, H, W)$sims))
pass(sprintf("simulated pair counts average to the FFT expectation (max |z| %.2f over the bands); reproducible",
             max(abs(zz))))
# 7. the vectorized simulation counts exactly as pair_counts() per sample,
#    across chunk boundaries (max_cells small forces 6 samples per chunk)
cs <- cumsum(toy[[1]]$pi)
n <- 40
set.seed(8)
v <- pair_sim_shoe(cs, toy[[1]]$row, toy[[1]]$col, n, 20, max_cells = 5000)
chunk <- max(1L, floor(5000 / choose(n, 2)))
set.seed(8)
ref <- NULL
for (s0 in seq(1L, 20, by = chunk)) {
  ns <- length(s0:min(20, s0 + chunk - 1L))
  j <- findInterval(runif(ns * n) * cs[length(cs)], cs) + 1L
  Rm <- matrix(toy[[1]]$row[j], ns, n)
  Cm <- matrix(toy[[1]]$col[j], ns, n)
  ref <- rbind(ref, t(vapply(seq_len(ns), function(k) pair_counts(Rm[k, ], Cm[k, ]),
                             numeric(length(PAIR_ANNULI)))))
}
stopifnot(chunk == 6, identical(unname(v), unname(ref)))
pass("pair_sim_shoe = pair_counts per sample across chunks")
cat("ALL PASS test_validation_pairs\n")
