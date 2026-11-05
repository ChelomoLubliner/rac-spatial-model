# T0 review-fix probes (R side). Run from the repo root:
#   Rscript docs/qa/T0/probes/t0_review.R
# Reads committed files only; writes nothing. Sections:
#   S1 K8: the fitted surface is pinned to the intercept on two edges
#   S2 an in-sample regional X^2 on the fitting partition is 0
#   S3 phi under independent multinomials; heterogeneity vs dependence
#   S4 variance under dependence: cluster-robust CML (Efron ties)
#   S5 offsets: var(log(100 / px)) and the exact control fraction
#   S6 Sys.getenv() for a set-but-empty RAC_DATASET
suppressMessages({
  library(lme4)
  library(survival)
  library(splines)
})

cat("=== S1. K8: ns(new_x):ns(y) without main effects\n")
d <- read.csv("processed_data/dataCC_distance.csv")
m <- readRDS("saved_models/NEW_X_NS_XY.rds")
b <- fixef(m)
kx <- as.numeric(quantile(d$new_x, 1:3 / 4))
ky <- as.numeric(quantile(d$y, 1:5 / 6))
bx <- ns(d$new_x, knots = kx)
by <- ns(d$y, knots = ky)
design <- function(xv, yv) {
  px <- predict(bx, xv)
  py <- predict(by, yv)
  cbind(1, do.call(cbind, lapply(seq_len(ncol(py)), function(i) {
    px * py[, i]
  })))
}
x_mod <- getME(m, "X")
x_reb <- design(d$new_x, d$y)
cat(sprintf("columns: %d; max |rebuilt X - getME(X)| = %g\n",
            ncol(x_reb), max(abs(x_reb - x_mod))))
cat("boundary knots new_x:", format(attr(bx, "Boundary.knots"), digits = 7),
    "| y:", format(attr(by, "Boundary.knots"), digits = 7), "\n")
cat("ns basis at its left boundary: new_x", max(abs(predict(bx, min(d$new_x)))),
    " y", max(abs(predict(by, min(d$y)))), "\n")
yy <- seq(min(d$y), max(d$y), length.out = 5)
xx <- seq(min(d$new_x), max(d$new_x), length.out = 5)
edge <- function(xv, yv) round(as.numeric(design(xv, yv) %*% b), 6)
cat(sprintf("intercept = %.6f\n", b[1]))
cat("eta on the edge new_x = min (5 y values):",
    edge(rep(min(d$new_x), 5), yy), "\n")
cat("eta on the heel edge y = min (5 new_x values):",
    edge(xx, rep(min(d$y), 5)), "\n")
cat("eta on the edge new_x = max (same 5 y):",
    edge(rep(max(d$new_x), 5), yy), "\n")
cat("eta on the toe edge y = max (same 5 new_x):",
    edge(xx, rep(max(d$y), 5)), "\n")
eta <- as.numeric(x_mod %*% b)
cat("eta over the 51,849 dataCC rows: quantiles 1/10/50/90/99%:",
    round(quantile(eta, c(.01, .1, .5, .9, .99)), 3), "\n")
near_x <- d$new_x < min(d$new_x) + 0.03
near_y <- d$y < min(d$y) + 0.03
cat(sprintf(paste("rows within 0.03 of the new_x = min edge: %d (%d cases);",
                  "within 0.03 of the heel edge: %d (%d cases)\n"),
            sum(near_x), sum(d$n_Acc[near_x]), sum(near_y),
            sum(d$n_Acc[near_y])))
cat("eta on those rows, quantiles 10/50/90%: new_x edge",
    round(quantile(eta[near_x], c(.1, .5, .9)), 3), "| heel edge",
    round(quantile(eta[near_y], c(.1, .5, .9)), 3), "\n")
full <- ncol(ns(d$new_x, knots = kx)) + ncol(ns(d$y, knots = ky)) + 1 +
  ncol(x_reb) - 1
cat("fixed effects of the full tensor (main effects + interaction):", full,
    "\n")

cat("\n=== S2. regional theta fitted on the test partition: in-sample X^2\n")
set.seed(1)
ns_shoe <- 40
k_area <- 6
cells <- expand.grid(shoe = factor(seq_len(ns_shoe)),
                     area = factor(seq_len(k_area)))
cells$s <- round(runif(nrow(cells), 50, 400))
theta <- c(1, 1.5, 0.7, 2, 1.2, 0.9)
a_i <- rnorm(ns_shoe, 0, 0.5)
mu <- exp(a_i[cells$shoe]) * theta[cells$area] * cells$s / 100
cells$n <- rpois(nrow(cells), mu)
fit <- glm(n ~ shoe + area + offset(log(s)), family = poisson, data = cells)
th <- exp(c(0, coef(fit)[grep("^area", names(coef(fit)))]))
w <- th[cells$area] * cells$s
n_i <- tapply(cells$n, cells$shoe, sum)
e_r <- as.numeric(n_i[cells$shoe] * w / tapply(w, cells$shoe, sum)[cells$shoe])
o_k <- tapply(cells$n, cells$area, sum)
e_k <- tapply(e_r, cells$area, sum)
cat(sprintf(paste("toy (40 shoes, 6 areas, N = %d): max |O_k - E~R_k| = %.3g;",
                  "X^2 = %.3g; max |E~R - fitted(glm)| = %.3g\n"),
            sum(cells$n), max(abs(o_k - e_k)), sum((o_k - e_k)^2 / e_k),
            max(abs(e_r - fitted(fit)))))

cat("\n=== S3. phi under independent multinomials; heterogeneity vs dependence\n")
loc_new <- read.table("data/new_shoes/locations_data_new_raw.txt")
n_real <- as.numeric(table(loc_new$V1))
k_cell <- 15
pi0 <- (1:k_cell) / sum(1:k_cell)
rdir <- function(alpha) {
  g <- rgamma(length(alpha), alpha)
  g / sum(g)
}
x2 <- function(o, e) sum((o - e)^2 / e)
set.seed(11)
reps <- 2000
alpha <- 30
pis <- t(vapply(seq_along(n_real), function(i) rdir(alpha * pi0),
                numeric(k_cell)))
e_true <- colSums(n_real * pis)
ex_formula <- k_cell - sum(colSums(n_real * pis^2) / e_true)
x2_true <- x2_common <- x2_clump <- numeric(reps)
for (r in seq_len(reps)) {
  o <- vapply(seq_along(n_real), function(i) {
    rmultinom(1, n_real[i], pis[i, ])
  }, numeric(k_cell))
  ok <- rowSums(o)
  x2_true[r] <- x2(ok, e_true)
  x2_common[r] <- x2(ok, sum(n_real) * pi0)
  # dependence, no heterogeneity: RACs come in clumps of 1 + Poisson(0.5)
  # that share a cell, each clump's cell drawn from pi0 (only the pooled
  # counts matter here, so clumps are drawn for all N RACs at once and the
  # last one is truncated)
  sz <- 1 + rpois(sum(n_real), 0.5)
  j <- which(cumsum(sz) >= sum(n_real))[1]
  sz <- sz[seq_len(j)]
  sz[j] <- sz[j] - (sum(sz) - sum(n_real))
  cl <- sample.int(k_cell, j, replace = TRUE, prob = pi0)
  oc <- tabulate(rep(cl, sz), k_cell)
  x2_clump[r] <- x2(oc, sum(n_real) * pi0)
}
cat(sprintf(paste("631 shoes with the real NEW n_i (N = %d), K = %d,",
                  "%d replicates:\n"), sum(n_real), k_cell, reps))
cat(sprintf(paste("  (a) independent, shoe-specific pi_i (Dirichlet, alpha",
                  "= %d), X^2 with the true pi_i: mean %.3f, exact",
                  "E[X^2] = %.3f, K - 1 = %d, phi = %.4f, exact phi_0 =",
                  "%.4f\n"),
            alpha, mean(x2_true), ex_formula, k_cell - 1,
            mean(x2_true) / (k_cell - 1), ex_formula / (k_cell - 1)))
cat(sprintf(paste("  (b) the same independent data, X^2 with the common",
                  "pi0 (heterogeneity ignored): mean %.2f, phi = %.2f\n"),
            mean(x2_common), mean(x2_common) / (k_cell - 1)))
cat(sprintf(paste("  (c) clumped RACs (dependence), common pi0, no",
                  "heterogeneity: mean %.2f, phi = %.2f\n"),
            mean(x2_clump), mean(x2_clump) / (k_cell - 1)))

cat("\n=== S4. CML: cluster-robust variance needs Efron ties\n")
cm <- readRDS("saved_models/CML_MODEL.rds")
cat("committed CML method:", cm$method, "\n")
msg <- tryCatch({
  clogit(n_Acc ~ ns(new_x, knots = kx):ns(y, knots = ky) + strata(shoe) +
           cluster(shoe), data = d, method = "exact")
  "fitted"
}, error = function(e) conditionMessage(e))
cat("exact + cluster(shoe):", msg, "\n")
t0 <- Sys.time()
ef <- clogit(n_Acc ~ ns(new_x, knots = kx):ns(y, knots = ky) + strata(shoe) +
               cluster(shoe), data = d, method = "efron")
cat(sprintf("efron + cluster(shoe) fit: %.1f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
cat(sprintf("max |coef(efron) - coef(committed exact)| = %.4f\n",
            max(abs(unname(coef(ef)) - unname(coef(cm))))))
ratio <- sqrt(diag(vcov(ef))) / sqrt(diag(ef$naive.var))
cat("robust / model SE ratio (efron): min", round(min(ratio), 3), "median",
    round(median(ratio), 3), "max", round(max(ratio), 3), "\n")
be <- coef(ef)
cat(sprintf(paste("Wald all 24 = 0 (efron fit): model-based W = %.2f,",
                  "cluster-robust W = %.2f; committed exact CML",
                  "model-based W = %.2f\n"),
            as.numeric(t(be) %*% solve(ef$naive.var, be)),
            as.numeric(t(be) %*% solve(vcov(ef), be)),
            as.numeric(t(coef(cm)) %*% solve(vcov(cm), coef(cm)))))

cat("\n=== S5. offsets\n")
pc <- read.csv("processed_data/shoe_pixel_counts.csv")
cases <- as.numeric(tapply(d$n_Acc, d$shoe, sum))
off <- log(100 / pc$pixel_count)
cat(sprintf("OLD var(log(100/px)) (committed cleaned counts) = %.4f\n",
            var(off)))
cat(sprintf(paste("OLD max |log(100/px) - log(100/(px - cases))| = %.4f",
                  "(shoe %d: px %d, cases %d)\n"),
            max(abs(off - log(100 / (pc$pixel_count - cases)))),
            pc$shoe[which.max(cases / pc$pixel_count)],
            pc$pixel_count[which.max(cases / pc$pixel_count)],
            cases[which.max(cases / pc$pixel_count)]))
count_ones <- function(path, w, h, n) {
  v <- readBin(path, "raw", n = file.size(path))
  stride <- w * h + 2
  vapply(seq_len(n), function(i) {
    sum(v[(i - 1) * stride + seq_len(w * h)] == as.raw(49))
  }, numeric(1))
}
px_new <- count_ones("data/new_shoes/contacts_data_new.txt", 255, 367, 631)
px_old <- count_ones("data/contacts_data.txt", 307, 395, 387)[-127]
cat(sprintf(paste("raw (uncleaned) contact px: var(log(100/px)) OLD (386)",
                  "= %.4f, NEW (631) = %.4f\n"),
            var(log(100 / px_old)), var(log(100 / px_new))))

cat("\n=== S6. Sys.getenv() for RAC_DATASET\n")
Sys.unsetenv("RAC_DATASET")
cat(sprintf("unset: [%s]\n", Sys.getenv("RAC_DATASET", "old")))
Sys.setenv(RAC_DATASET = "")
cat(sprintf("set to the empty string: [%s]\n",
            Sys.getenv("RAC_DATASET", "old")))
