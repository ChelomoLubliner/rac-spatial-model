# Slow size and power checks of the within-shoe pair test (plan T7 step 2,
# test_validation_pairs, reduced setting; decision A-046). Not part of
# tests/run_all.sh; run in the background and paste the output into
# docs/tests/T7-results.md:
#
#   Rscript tests/r/slow/test_validation_pairs_calibration.R
#
# Toy shoes: 60 shoes of 100 x 60 px, contact = an ellipse with a regular
# pattern of gaps (lugs), a smooth fitted intensity pi_C (a toe-heel
# gradient), 10-60 RACs per shoe. The statistic is the pooled count of
# unordered pairs at (2, 8] px, its Monte Carlo p from 199 simulations;
# 200 replicates per scenario (seed 13).
#   A. RACs drawn from pi_C, tested against null 1 (pi_C): rejection within
#      0.05 +- 2.5 sqrt(0.05 x 0.95 / 200);
#   B. clumps (each event places 2-4 RACs within 2-6 px), against null 2:
#      rejection > 50%;
#   C. smooth shoe-specific intensities only (pi_C times exp of a Gaussian
#      random field of scale 40 px, log-intensity sd 0.8, declared before
#      the first run), against null 2: rejection <= 10% (the plan's claim);
#      C03 and C05 (sd 0.3 and 0.5) characterize how the rejection grows
#      with the strength of the heterogeneity (added after the first run,
#      on the old simulation code, rejected in 100% at sd 0.8: no assertion
#      on them);
#   D. heterogeneity below h (random fields of scale 6-12 px, no clumps),
#      against null 2: rejection > 30% (the test cannot tell contagion from
#      fine-scale inhomogeneity; the report says so, A-046).
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", "..", ".."))
})
for (f in c("profile.R", "pairs.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
pass <- function(name) cat("PASS", name, "\n")
t_all <- proc.time()[["elapsed"]]
workers <- as.integer(rac_env("RAC_WORKERS", "3"))

H <- 100
W <- 60
nshoe <- 60
sims <- 199
reps <- 200
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
      tr <- round(prow[j] + rad * sin(ang))
      tc <- round(pcol[j] + rad * cos(ang))
      hit <- which(prow == tr & pcol == tc)
      if (length(hit)) {
        out <- c(out, hit)
        k <- k - 1
      }
    }
  }
  out
}
make_shoe <- function(idx, null) {
  N <- tabulate(idx, nbins = length(pix))
  if (null == "null1") {
    p <- piC
  } else {
    r <- which(N > 0)
    g <- gauss_smooth_at(prow, pcol, prow[r], pcol[r], N[r], PAIR_H)
    p <- 0.5 * piC + 0.5 * g / sum(g)
  }
  list(row = prow, col = pcol, N = N, pi = p)
}
one_rep <- function(r, scenario) {
  set.seed(13000 + r + 1000 * match(scenario, c("A", "B", "C", "D", "C03", "C05")))
  shoes <- lapply(seq_len(nshoe), function(i) {
    n <- n_shoe[i]
    idx <- switch(scenario,
                  A = draw_iid(piC, n),
                  B = draw_clumps(n),
                  C = draw_iid(piC * exp(field(40, 0.8)), n),
                  C03 = draw_iid(piC * exp(field(40, 0.3)), n),
                  C05 = draw_iid(piC * exp(field(40, 0.5)), n),
                  D = draw_iid(piC * exp(field(runif(1, 6, 12), 1.2)), n))
    make_shoe(idx, if (scenario == "A") "null1" else "null2")
  })
  res <- pair_test_shoes(shoes, sims, 77000 + r, kern, H, W)
  o <- sum(res$obs[, "(2,4]"] + res$obs[, "(4,8]"])
  s <- res$sims[, "(2,4]"] + res$sims[, "(4,8]"]
  c(p = (1 + sum(s >= o)) / (sims + 1),
    ratio = o / sum(res$exp[, "(2,4]"] + res$exp[, "(4,8]"]))
}
rates <- list()
for (scenario in c("A", "B", "C", "D", "C03", "C05")) {
  t0 <- proc.time()[["elapsed"]]
  res <- do.call(rbind, parallel::mclapply(seq_len(reps), one_rep,
                                           scenario = scenario,
                                           mc.cores = workers))
  rates[[scenario]] <- mean(res[, "p"] <= 0.05)
  cat(sprintf("scenario %s: rejection at 5%% %.3f, mean ratio (2,8] %.3f (%.0f s)\n",
              scenario, rates[[scenario]], mean(res[, "ratio"]),
              proc.time()[["elapsed"]] - t0))
}
se <- sqrt(0.05 * 0.95 / reps)
checks <- list(
  "A: under null 1 data the (2, 8] test holds its size" = abs(rates$A - 0.05) <= 2.5 * se,
  "B: clumps are detected against null 2 (> 50%)" = rates$B > 0.5,
  "C: smooth shoe-specific intensities (40 px, sd 0.8) absorbed by null 2 (<= 10%)" = rates$C <= 0.10,
  "D: heterogeneity below h (6-12 px) flagged like clustering (> 30%)" = rates$D > 0.30)
for (nm in names(checks)) cat(if (checks[[nm]]) "PASS" else "FAIL", nm, "\n")
cat(sprintf("characterization, no assertion: rejection at sd 0.3 %.3f, 0.5 %.3f, 0.8 %.3f\n",
            rates$C03, rates$C05, rates$C))
cat(sprintf("%s test_validation_pairs_calibration (%.0f s)\n",
            if (all(unlist(checks))) "ALL PASS" else "SOME CHECKS FAILED",
            proc.time()[["elapsed"]] - t_all))
if (!all(unlist(checks))) quit(status = 1)
