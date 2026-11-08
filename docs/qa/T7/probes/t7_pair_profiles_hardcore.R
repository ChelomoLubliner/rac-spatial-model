# t7_pair_profiles_hardcore.R: the distance profile of the pair excess
# against null 2 when the RACs of a shoe also inhibit each other at short
# range (T7 review fix, statistics finding 2). The NEW data show a deficit
# of pairs on the same pixel (ratio 0.35) and none at (0, 2] px (0.97); the
# toys of t7_pair_profiles.R have no inhibition, so their "no excess below
# 2 px" signature of clustering could also come from shoe-specific
# heterogeneity plus inhibition. Here every scenario is also run with
#   hc: a hard core, no two RACs of a shoe within 2 px (d <= 2), and
#   d0: same-pixel exclusion only (no two RACs on one pixel),
# by sequential inhibition (a draw that violates the core is redrawn from
# the same intensity). Same toy shoes, intensity, null 2, 50 replicates and
# 199 simulations per replicate as t7_pair_profiles.R (seed rule 31000 + r,
# 91000 + r). The rows without a core are a fresh Monte Carlo of that
# probe's rows (RACs drawn one at a time here, all at once there, so the
# random numbers differ; the two agree within 0.04, most bands within 0.02).
#
# Run from the repository root:
#   Rscript docs/qa/T7/probes/t7_pair_profiles_hardcore.R
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
# core: 0 = none, 1 = same-pixel exclusion, 2 = hard core d <= 2 px
ok_core <- function(j, taken, core) {
  if (core == 0 || !length(taken)) return(TRUE)
  d2 <- (prow[taken] - prow[j])^2 + (pcol[taken] - pcol[j])^2
  if (core == 1) all(d2 > 0) else all(d2 > 4)
}
draw_core <- function(p, n, core) {
  out <- integer(0)
  tries <- 0
  while (length(out) < n) {
    j <- sample.int(length(p), 1, prob = p)
    tries <- tries + 1
    if (tries > 100000) stop("draw_core: no room")
    if (ok_core(j, out, core)) out <- c(out, j)
  }
  out
}
draw_clumps <- function(n, core) {
  out <- integer(0)
  while (length(out) < n) {
    j <- sample.int(length(piC), 1, prob = piC)
    if (!ok_core(j, out, core)) next
    k <- min(sample(2:4, 1), n - length(out))
    out <- c(out, j)
    tries <- 0
    while (k > 1 && tries < 1000) {
      tries <- tries + 1
      rad <- runif(1, 2, 6)
      ang <- runif(1, 0, 2 * pi)
      hit <- which(prow == round(prow[j] + rad * sin(ang)) &
                     pcol == round(pcol[j] + rad * cos(ang)))
      if (length(hit) && ok_core(hit, out, core)) {
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
gen <- function(scenario, n, core) {
  switch(scenario,
         null = draw_core(piC, n, core),
         clumps = draw_clumps(n, core),
         smooth_03 = draw_core(piC * exp(field(40, 0.3)), n, core),
         smooth_05 = draw_core(piC * exp(field(40, 0.5)), n, core),
         smooth_08 = draw_core(piC * exp(field(40, 0.8)), n, core),
         fine = draw_core(piC * exp(field(runif(1, 6, 12), 1.2)), n, core))
}
prof <- function(scenario, core) {
  rows <- parallel::mclapply(seq_len(reps), function(r) {
    set.seed(31000 + r)
    shoes <- lapply(seq_len(nshoe), function(i) {
      null2_shoe(gen(scenario, n_shoe[i], core))
    })
    res <- pair_test_shoes(shoes, sims, 91000 + r, kern, H, W)
    o <- colSums(res$obs)
    e <- colSums(res$exp)
    c(o / e, "(2,8]" = sum(o[c("(2,4]", "(4,8]")]) / sum(e[c("(2,4]", "(4,8]")]))
  }, mc.cores = 2)
  colMeans(do.call(rbind, rows))
}
t0 <- proc.time()[["elapsed"]]
specs <- list(c("null", 0), c("null", 1), c("null", 2),
              c("smooth_03", 0), c("smooth_03", 1), c("smooth_03", 2),
              c("smooth_05", 0), c("smooth_05", 1), c("smooth_05", 2),
              c("smooth_08", 0), c("smooth_08", 1), c("smooth_08", 2),
              c("fine", 2), c("clumps", 2))
out <- t(vapply(specs, function(sp) prof(sp[1], as.integer(sp[2])),
                numeric(length(PAIR_ANNULI) + 1)))
rownames(out) <- vapply(specs, function(sp) {
  paste(sp[1], c("", "_d0", "_hc")[as.integer(sp[2]) + 1], sep = "")
}, "")
print(round(out, 3))
cat(sprintf("%.0f s\n", proc.time()[["elapsed"]] - t0))
