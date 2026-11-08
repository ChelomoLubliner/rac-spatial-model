# t7_pair_profiles.R: the distance profile of the pair excess (observed /
# expected pairs per band, against null 2) in the toy scenarios of
# tests/r/slow/test_validation_pairs_calibration.R, to read the real NEW
# profile (part2_pairs_new.csv). Clumps put the excess at short range and
# let it vanish beyond the clump size; a smooth shoe-specific intensity
# (scale 40 px) that null 2 does not absorb raises the ratio over every band
# up to about the field's scale. 50 replicates per scenario, 199
# simulations each, the same toy shoes and seed rule as the calibration.
#
# Run from the repository root: Rscript docs/qa/T7/probes/t7_pair_profiles.R
root <- normalizePath(".")
for (f in c("profile.R", "pairs.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
H <- 100
W <- 60
nshoe <- 60
sims <- 199
reps <- 50
rr <- row(matrix(0, H, W))
cc <- col(matrix(0, H, W))
ell <- ((rr - 50.5) / 47)^2 + ((cc - 30.5) / 27)^2 <= 1
lug <- !((rr %% 9) %in% c(0, 1) & (cc %% 7) == 0)
S <- ell & lug
pix <- which(S)
prow <- rr[pix]
pcol <- cc[pix]
piC <- exp(0.012 * (H - prow))
piC <- piC / sum(piC)
kern <- pair_kernels(H, W)
set.seed(13)
n_shoe <- sample(10:60, nshoe, replace = TRUE)
field <- function(scale, amp) {
  z <- gauss_smooth(matrix(rnorm(H * W), H, W), scale)[pix]
  amp * (z - mean(z)) / sd(z)
}
draw_iid <- function(p, n) sample.int(length(p), n, replace = TRUE, prob = p)
draw_clumps <- function(n) {
  out <- integer(0)
  while (length(out) < n) {
    j <- draw_iid(piC, 1)
    k <- min(sample(2:4, 1), n - length(out))
    out <- c(out, j)
    while (k > 1) {
      rad <- runif(1, 2, 6)
      ang <- runif(1, 0, 2 * pi)
      hit <- which(prow == round(prow[j] + rad * sin(ang)) &
                     pcol == round(pcol[j] + rad * cos(ang)))
      if (length(hit)) {
        out <- c(out, hit)
        k <- k - 1
      }
    }
  }
  out
}
null2_shoe <- function(idx) {
  N <- tabulate(idx, nbins = length(pix))
  r <- which(N > 0)
  g <- gauss_smooth_at(prow, pcol, prow[r], pcol[r], N[r], PAIR_H)
  list(row = prow, col = pcol, N = N, pi = 0.5 * piC + 0.5 * g / sum(g))
}
prof <- function(scenario) {
  rows <- parallel::mclapply(seq_len(reps), function(r) {
    set.seed(31000 + r)
    shoes <- lapply(seq_len(nshoe), function(i) {
      n <- n_shoe[i]
      null2_shoe(switch(scenario,
                        clumps = draw_clumps(n),
                        smooth_08 = draw_iid(piC * exp(field(40, 0.8)), n),
                        smooth_05 = draw_iid(piC * exp(field(40, 0.5)), n),
                        fine = draw_iid(piC * exp(field(runif(1, 6, 12), 1.2)), n),
                        null = draw_iid(piC, n)))
    })
    res <- pair_test_shoes(shoes, sims, 91000 + r, kern, H, W)
    colSums(res$obs) / colSums(res$exp)
  }, mc.cores = 2)
  colMeans(do.call(rbind, rows))
}
out <- t(vapply(c("null", "clumps", "smooth_05", "smooth_08", "fine"), prof,
                numeric(length(PAIR_ANNULI))))
print(round(out, 3))
