# pairs.R: the within-shoe dependence test of Part 2 (plan T7, section 9;
# decisions A-026, A-046): unordered pairs of RACs of one shoe by distance
# band, against independent placement from a null intensity.
#
# Every RAC of shoe i sits on a pixel (row, col) of the shoe's own image;
# the distance of a pair is the Euclidean distance of the pixel centres in
# pixels. Annuli (a, b]: (0, 2], (2, 4], (4, 8], (8, 16], (16, 32]; pairs
# on the same pixel (distance 0, duplicate RAC pixels) are counted
# separately. The primary statistic (A-046) is the pooled count in (2, 8]
# against null 2.
#
# Null 1: the RACs of shoe i are n_i independent draws from pi_i, the
#   fitted continuous model normalized over the shoe's contact pixels.
# Null 2: draws from pi_h_i = 0.5 pi_i + 0.5 g_i S_i / sum(g_i S_i), with
#   g_i the Gaussian smoothing (sd h = 24 px) of the shoe's own RAC counts:
#   heterogeneity on scales >= h is absorbed, structure below h is not.
#
# PAIR_ANNULI                 the band limits (pixels)
# pair_counts(row, col, breaks)
#     unordered pairs per band of one shoe (duplicates in "d0")
# pair_kernels(H, W, breaks)  FFTs of the annulus indicators on the padded
#                             grid (no wrap-around for offsets <= max band)
# pair_expected(pi_img, n, kern)
#     n (n - 1) / 2 times sum_j sum_j' pi(j) pi(j') 1(a < |j - j'| <= b) per
#     band, and n (n - 1) / 2 sum_j pi(j)^2 for "d0"
# gauss_smooth(M, h)          separable Gaussian smoothing, zero outside
# gauss_smooth_at(row, col, rk, ck, Nk, h)
#                             the same at given pixels from sparse counts
# PAIR_H, PAIR_SIMS           h = 24 px and 999 simulations (plan section 9)
# pair_sim(cs, rows, cols, n, breaks)
#     pair counts of n independent draws from a shoe's pixels with
#     cumulative probabilities cs
# pair_sim_shoe(cs, rows, cols, n, sims, breaks)
#     the same for `sims` samples at once (sims x bands matrix)
# pair_test_shoes(shoes, sims, seed, breaks, kern)
#     the observed, expected and simulated pair counts of a list of shoes
#     (each: row, col, pi (one null), N) and per-shoe tables

PAIR_ANNULI <- c(0, 2, 4, 8, 16, 32)

.pair_band_names <- function(breaks) {
  paste("(", head(breaks, -1), ",", breaks[-1], "]", sep = "")
}

pair_counts <- function(row, col, breaks = PAIR_ANNULI) {
  nb <- length(breaks) - 1
  out <- numeric(nb + 1)
  names(out) <- c("d0", .pair_band_names(breaks))
  if (length(row) < 2) return(out)
  d <- as.vector(stats::dist(cbind(row, col)))
  out[1] <- sum(d == 0)
  k <- findInterval(d, breaks, left.open = TRUE)
  ok <- d > 0 & k >= 1 & k <= nb
  out[-1] <- tabulate(k[ok], nbins = nb)
  out
}

pair_kernels <- function(H, W, breaks = PAIR_ANNULI) {
  R <- max(breaks)
  Hp <- stats::nextn(H + R)
  Wp <- stats::nextn(W + R)
  off <- -R:R
  dd <- sqrt(outer(off^2, off^2, "+"))
  nb <- length(breaks) - 1
  fk <- vector("list", nb)
  for (k in seq_len(nb)) {
    K <- matrix(0, Hp, Wp)
    hit <- which(dd > breaks[k] & dd <= breaks[k + 1], arr.ind = TRUE)
    K[cbind((off[hit[, 1]] %% Hp) + 1, (off[hit[, 2]] %% Wp) + 1)] <- 1
    fk[[k]] <- stats::fft(K)
  }
  names(fk) <- .pair_band_names(breaks)
  list(H = H, W = W, Hp = Hp, Wp = Wp, fft = fk, breaks = breaks)
}

pair_expected <- function(pi_img, n, kern) {
  stopifnot(identical(dim(pi_img), c(as.integer(kern$H), as.integer(kern$W))))
  Pp <- matrix(0, kern$Hp, kern$Wp)
  Pp[seq_len(kern$H), seq_len(kern$W)] <- pi_img
  fp <- stats::fft(Pp)
  npair <- n * (n - 1) / 2
  s <- vapply(kern$fft, function(fk) {
    conv <- Re(stats::fft(fp * fk, inverse = TRUE)) / (kern$Hp * kern$Wp)
    sum(Pp * conv)
  }, 0)
  c(d0 = npair * sum(pi_img^2), npair * s)
}

gauss_smooth <- function(M, h) {
  gr <- stats::dnorm(outer(seq_len(nrow(M)), seq_len(nrow(M)), "-"), sd = h)
  gc <- stats::dnorm(outer(seq_len(ncol(M)), seq_len(ncol(M)), "-"), sd = h)
  gr %*% M %*% gc
}

# The same smoothing of a sparse count image, evaluated only at the given
# pixels: g(j) = sum_k N_k dnorm(r_j - r_k, h) dnorm(c_j - c_k, h) over the
# pixels k with counts N_k (equal to gauss_smooth() at those pixels).
gauss_smooth_at <- function(row, col, rk, ck, Nk, h) {
  as.vector((stats::dnorm(outer(row, rk, "-"), sd = h) *
               stats::dnorm(outer(col, ck, "-"), sd = h)) %*% Nk)
}

PAIR_H <- 24
PAIR_SIMS <- 999L

pair_sim <- function(cs, rows, cols, n, breaks = PAIR_ANNULI) {
  j <- findInterval(stats::runif(n) * cs[length(cs)], cs) + 1L
  pair_counts(rows[j], cols[j], breaks)
}

# The pair counts of `sims` independent samples of n RACs from one shoe's
# pixels (cumulative probabilities cs): a sims x (bands + 1) matrix (d0
# first). All samples of a chunk are drawn at once and every unordered
# pair (a < b) of RAC positions is measured in one vectorized step.
pair_sim_shoe <- function(cs, rows, cols, n, sims, breaks = PAIR_ANNULI,
                          max_cells = 2000000) {
  nb <- length(breaks) - 1
  out <- matrix(0, sims, nb + 1)
  if (n < 2) return(out)
  ab <- which(upper.tri(matrix(FALSE, n, n)), arr.ind = TRUE)
  a <- ab[, 1]
  b <- ab[, 2]
  chunk <- max(1L, floor(max_cells / length(a)))
  for (s0 in seq(1L, sims, by = chunk)) {
    ss <- s0:min(sims, s0 + chunk - 1L)
    j <- findInterval(stats::runif(length(ss) * n) * cs[length(cs)], cs) + 1L
    R <- matrix(rows[j], length(ss), n)
    C <- matrix(cols[j], length(ss), n)
    # squared distances of pixel centres are integers, so comparing them
    # with the squared band limits is exact; band 0 = same pixel
    d2 <- (R[, a, drop = FALSE] - R[, b, drop = FALSE])^2 +
      (C[, a, drop = FALSE] - C[, b, drop = FALSE])^2
    k <- findInterval(d2, breaks^2, left.open = TRUE)
    ns <- length(ss)
    keep <- k <= nb
    cnt <- tabulate((k[keep]) * ns + rep(seq_len(ns), length(a))[keep],
                    nbins = (nb + 1) * ns)
    out[ss, ] <- matrix(cnt, ns, nb + 1)
  }
  out
}

# shoes: list of list(row, col, pi, N) (pi over the shoe's contact pixels,
# summing to 1; N the RAC counts of those pixels). Returns list(obs, exp,
# sims): shoes x bands matrices obs and exp, and sims x bands pooled counts;
# plus the per-simulation shoe-weighted mean ratio of the primary band
# (2, 8] (shoes with >= 2 RACs). The simulations run shoe by shoe (all
# `sims` samples of a shoe at once), so they depend on the seed and the
# order of the shoes only.
pair_test_shoes <- function(shoes, sims, seed, kern, H, W,
                            breaks = PAIR_ANNULI) {
  nb <- length(breaks) - 1
  bn <- c("d0", .pair_band_names(breaks))
  obs <- ex <- matrix(0, length(shoes), nb + 1, dimnames = list(NULL, bn))
  for (i in seq_along(shoes)) {
    s <- shoes[[i]]
    rr <- rep(s$row, s$N)
    cc <- rep(s$col, s$N)
    obs[i, ] <- pair_counts(rr, cc, breaks)
    img <- matrix(0, H, W)
    img[cbind(s$row, s$col)] <- s$pi
    ex[i, ] <- pair_expected(img, sum(s$N), kern)
  }
  e28 <- ex[, "(2,4]"] + ex[, "(4,8]"]
  use2 <- vapply(shoes, function(s) sum(s$N), 0) >= 2
  old <- if (exists(".Random.seed", envir = globalenv())) {
    get(".Random.seed", envir = globalenv())
  } else {
    NULL
  }
  on.exit(if (!is.null(old)) assign(".Random.seed", old, envir = globalenv()))
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion",
           sample.kind = "Rejection")
  pooled <- matrix(0, sims, nb + 1, dimnames = list(NULL, bn))
  ratio_sum <- numeric(sims)
  for (i in seq_along(shoes)) {
    s <- shoes[[i]]
    n <- sum(s$N)
    if (n < 2) next
    m <- pair_sim_shoe(cumsum(s$pi), s$row, s$col, n, sims, breaks)
    pooled <- pooled + m
    ratio_sum <- ratio_sum + (m[, 3] + m[, 4]) / e28[i]
  }
  list(obs = obs, exp = ex, sims = pooled,
       sim_shoe_ratio = ratio_sum / sum(use2), use2 = use2)
}

# The summary table of one null: per band (and the primary (2, 8]) the
# pooled observed and expected counts, their ratio, the Monte Carlo p =
# (1 + #{sim >= obs}) / (sims + 1), the 2.5% and 97.5% simulation envelope
# of the ratio, and the shoe-bootstrap percentile interval of the pooled
# ratio (W: B x shoes resample counts); the shoe-weighted ratio of (2, 8].
pair_summary <- function(res, W, null_name) {
  bands <- colnames(res$obs)
  add28 <- function(M) cbind(M, "(2,8]" = M[, "(2,4]"] + M[, "(4,8]"])
  obs <- add28(res$obs)
  ex <- add28(res$exp)
  sims <- add28(res$sims)
  out <- do.call(rbind, lapply(colnames(obs), function(b) {
    o <- sum(obs[, b])
    e <- sum(ex[, b])
    br <- as.vector(W %*% obs[, b]) / as.vector(W %*% ex[, b])
    data.frame(null = null_name, band = b, weight = "pairs", obs = o,
               expected = e, ratio = o / e,
               p_mc = (1 + sum(sims[, b] >= o)) / (nrow(sims) + 1),
               env_lo = stats::quantile(sims[, b], 0.025, names = FALSE) / e,
               env_hi = stats::quantile(sims[, b], 0.975, names = FALSE) / e,
               ci_lo = stats::quantile(br, 0.025, names = FALSE, na.rm = TRUE),
               ci_hi = stats::quantile(br, 0.975, names = FALSE, na.rm = TRUE))
  }))
  u <- res$use2
  sr <- obs[u, "(2,8]"] / ex[u, "(2,8]"]
  sw <- mean(sr)
  Wu <- W[, u, drop = FALSE]
  bsw <- as.vector(Wu %*% sr) / rowSums(Wu)
  rbind(out, data.frame(null = null_name, band = "(2,8]", weight = "shoes",
                        obs = NA, expected = NA, ratio = sw,
                        p_mc = (1 + sum(res$sim_shoe_ratio >= sw)) /
                          (length(res$sim_shoe_ratio) + 1),
                        env_lo = stats::quantile(res$sim_shoe_ratio, 0.025,
                                                 names = FALSE),
                        env_hi = stats::quantile(res$sim_shoe_ratio, 0.975,
                                                 names = FALSE),
                        ci_lo = stats::quantile(bsw, 0.025, names = FALSE),
                        ci_hi = stats::quantile(bsw, 0.975, names = FALSE)))
}
