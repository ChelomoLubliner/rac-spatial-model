# t5_basis_y.R: is the NEW heel-front misfit of the step-3 surface the y
# resolution of the step-3 basis, the sole designs, or both? (Second T5
# review fixes: the statistics reviewer's major finding 1 on the T5 review
# fixes; decisions A-119 and A-120. Ported from the reviewer's scratch
# probes finer_basis.R, cv_basis.R and stat_checks.R section 2.)
#
# Efron CML (survival::coxph, Surv(1, n_Acc) + strata(shoe), ties "efron")
# on the committed step-3 case-control rows of each dataset, four bases
# (new_x varying fastest in the interaction columns):
#   K8       the step-3 basis: ns(new_x, 3 knots):ns(y, 5 knots), no main
#            effects (24 coefficients; plan K8)
#   full     the same knots as a full tensor (main effects and
#            interaction; 34)
#   full_5x9 5 and 9 quantile knots, full tensor (76; t5_gof.R section H)
#   fullU    the nested finer y basis: the step-3 y knots plus the 10
#            quantiles 1:10/11 of y (15 interior knots), the same boundary
#            knots, the step-3 x knots, full tensor (84)
# Knots are quantiles over all case-control rows, as step 3 places them.
# The expected count of a row is n_i w / (sum of w over shoe i's rows), w =
# exp(linear predictor): the conditional multinomial of the CML, so each
# shoe's level cancels and O/E measures the shape of the surface.
# Regions (as t5_gof.R): the band y in (-0.18, -0.10] (plan F79); CI cut
# 250 (y within +-0.02 of prototype row 250, both edge rows, t5_gof.R D);
# the peak window around the withdrawn NEW map maximum (new_x 0.135,
# y -0.155: |dx| < 0.025, |dy| < 0.04; t5_gof.R C). NEW groups: A = ids
# 1-343 and 442-490 (post hoc, plan F79), B = the others.
#   A. In sample, both datasets: coefficients, loglik, AIC, the LR tests
#      K8 -> full -> fullU (model-based, so only indicative under
#      dependence), O/E in the regions, the cells of t5_gof.R A (E >= 15;
#      |z| > 3 and sum z^2, binomial z: descriptive), and the y profile
#      over the heel front in 0.02 bins under K8 and fullU; for NEW, the
#      local maxima of the K8 and fullU surfaces on the prototype grid of
#      the step-4 maps (t5_gof.R C's method: 31 x 31 px window, inside the
#      prototype mask; the CML has no intercept, so the height is given
#      relative to the surface's median) with the raw case/control ratio
#      around each (the dataset's ratio = 1; t5_gof.R C's ratio/all), to
#      see whether the withdrawn right heel-midfoot maximum (new_x 0.135,
#      y -0.155) remains and which maxima the data support.
#   B. 5-fold cross-validation by shoe (whole shoes per fold, seed 2026):
#      the held-out log score of the cases (sum over held-out cases of
#      log(w / sum of w over the shoe's rows), coefficients from the other
#      four folds; the knots are not re-placed per fold) and the held-out
#      O/E in the regions; the gain of fullU over each other basis with
#      its standard error over shoes; for K8 and fullU, where the held-out
#      fit differs (the cells of A with E >= 15, binomial z: the heel-front
#      cells, y in (-0.28, -0.04], against the others; a split of the log
#      score by the place of the case cannot show this, because lowering
#      the probability of a region costs its own cases and pays every other
#      case of the shoe through the normalization) and the held-out O/E
#      with shoe-bootstrap 95% percentile intervals (whole shoes resampled,
#      B = 2000, seed 7, the held-out expected counts fixed).
#   C. NEW: own-group fits (group A alone, group B alone, each on the
#      pooled knots) against the pooled fit, O/E in the band: does one
#      surface fit both groups?
# (A refit of the step-3 GLMM on NEW with the fullU basis, glmer with 85
# fixed effects and step 3's nlminbwrap optimizer, was tried as a section
# D and stopped unfinished after 2 h 26 min: one deviance evaluation takes
# 0.72 s here and nlminb differentiates 86 parameters numerically. The
# GLMM maps on a finer basis belong to T6, A-119.)
# Reads committed files only; writes nothing.
# Usage (repo root): Rscript docs/qa/T5/probes/t5_basis_y.R
#   (about 3-4 minutes on an idle machine)
suppressMessages({
  library(splines)
  library(survival)
})
root <- normalizePath(".")
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "compare.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
t_start <- proc.time()[["elapsed"]]
prof <- list(old = rac_profile("old", root = ROOT_PATH),
             new = rac_profile("new", root = ROOT_PATH))
dat <- lapply(prof, function(P) {
  read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
})
P0 <- prof$old
sc <- P0$prototype$coords$rel_Y_cord / P0$prototype$coords$rel_col_shoe
y_of_row <- function(row) -(-P0$prototype$row_shoe / 2 + row) * sc
is_a <- function(id) id <= 343 | (id >= 442 & id <= 490)
regions <- function(d) {
  list(band = d$y > -0.18 & d$y <= -0.10,
       cut250 = abs(d$y - y_of_row(250)) <= 0.02 + 1e-9,
       peak = abs(d$new_x - 0.135) < 0.025 & abs(d$y + 0.155) < 0.04 - 1e-9)
}
oe <- function(O, E) sum(O) / sum(E)
inter <- function(X, Y) {
  do.call(cbind, lapply(seq_len(ncol(Y)), function(i) X * Y[, i]))
}
designs <- function(d) {
  b <- basis_knots(d)
  bx <- ns(d$new_x, knots = b$knots_x)
  by <- ns(d$y, knots = b$knots_y)
  ky_u <- sort(unique(c(b$knots_y, as.numeric(quantile(d$y, 1:10 / 11)))))
  by_u <- ns(d$y, knots = ky_u)
  stopifnot(length(ky_u) == 15,
            identical(attr(by, "Boundary.knots"),
                      attr(by_u, "Boundary.knots")))
  bx2 <- ns(d$new_x, knots = as.numeric(quantile(d$new_x, 1:5 / 6)))
  by2 <- ns(d$y, knots = as.numeric(quantile(d$y, 1:9 / 10)))
  list(K8 = inter(bx, by), full = cbind(bx, by, inter(bx, by)),
       full_5x9 = cbind(bx2, by2, inter(bx2, by2)),
       fullU = cbind(bx, by_u, inter(bx, by_u)))
}
fit_cml <- function(X, d) {
  tm <- rep(1, nrow(d))
  f <- coxph(Surv(tm, d$n_Acc) ~ X + strata(d$shoe), ties = "efron")
  cf <- coef(f)
  k <- sum(!is.na(cf))
  cf[is.na(cf)] <- 0
  list(coef = cf, k = k, loglik = f$loglik[2])
}
# expected count per row (and the probability of the row within its shoe)
expected <- function(eta, d) {
  w <- exp(eta - ave(eta, d$shoe, FUN = max))
  p <- w / ave(w, d$shoe, FUN = sum)
  list(E = ave(d$n_Acc, d$shoe, FUN = sum) * p, p = p)
}
# t5_gof.R A: cells of 0.04 (new_x) x 0.08 (y), E >= 15, binomial z
xb <- seq(-0.20, 0.24, by = 0.04)
yb <- seq(-0.52, 0.52, by = 0.08)
cell_summary <- function(d, E) {
  key <- interaction(cut(d$new_x, xb), cut(d$y, yb), drop = TRUE)
  O <- tapply(d$n_Acc, key, sum)
  Ec <- tapply(E, key, sum)
  V <- tapply(E * (1 - E), key, sum)
  z <- ((O - Ec) / sqrt(V))[Ec >= 15]
  sprintf("cells E >= 15: %d, |z| > 3: %d, sum z^2 %.0f", length(z),
          sum(abs(z) > 3), sum(z^2))
}
region_line <- function(d, E, ds) {
  r <- regions(d)
  out <- sprintf("band O/E %.2f, cut 250 %.2f, peak window %.2f",
                 oe(d$n_Acc[r$band], E[r$band]),
                 oe(d$n_Acc[r$cut250], E[r$cut250]),
                 oe(d$n_Acc[r$peak], E[r$peak]))
  if (ds == "new") {
    a <- is_a(d$shoe)
    out <- paste(out, sprintf("(band: A %.2f, B %.2f)",
                              oe(d$n_Acc[r$band & a], E[r$band & a]),
                              oe(d$n_Acc[r$band & !a], E[r$band & !a])))
  }
  out
}

# the prototype grid of the step-4 maps and the local maxima of a surface
# on it (t5_gof.R C)
mask <- t(as.matrix(imager::load.image(rac_path(P0, "prototype_mask"))))
Wp <- P0$prototype$col_shoe
Hp <- P0$prototype$row_shoe
xs <- (-Wp / 2 + 1:Wp) * sc
ys <- -(-Hp / 2 + 1:Hp) * sc
grid_xy <- expand.grid(x = xs, y = ys)
grid_designs <- function(d) {
  b <- basis_knots(d)
  bx <- ns(d$new_x, knots = b$knots_x)
  by <- ns(d$y, knots = b$knots_y)
  by_u <- ns(d$y, knots = sort(unique(c(b$knots_y, as.numeric(
    quantile(d$y, 1:10 / 11))))))
  gx <- predict(bx, grid_xy$x)
  gy_u <- predict(by_u, grid_xy$y)
  list(K8 = inter(gx, predict(by, grid_xy$y)),
       fullU = cbind(gx, gy_u, inter(gx, gy_u)))
}
local_maxima <- function(eta_vec) {
  eta <- matrix(eta_vec, Hp, Wp, byrow = TRUE)
  eta[mask == 0] <- NA
  pk <- which(!is.na(eta), arr.ind = TRUE)
  ismax <- apply(pk, 1, function(p) {
    r0 <- max(1, p[1] - 15):min(Hp, p[1] + 15)
    c0 <- max(1, p[2] - 15):min(Wp, p[2] + 15)
    eta[p[1], p[2]] >= max(eta[r0, c0], na.rm = TRUE)
  })
  pk <- pk[ismax, , drop = FALSE]
  data.frame(new_x = xs[pk[, 2]], y = ys[pk[, 1]],
             rel = eta[pk] - median(eta, na.rm = TRUE))
}

cat("== A. in sample (Efron CML)\n")
X_all <- list()
E_in <- list()
for (ds in c("old", "new")) {
  d <- dat[[ds]]
  X <- designs(d)
  X_all[[ds]] <- X
  t0 <- proc.time()[["elapsed"]]
  fits <- lapply(X, fit_cml, d = d)
  E_in[[ds]] <- lapply(names(X), function(nm) {
    expected(as.vector(X[[nm]] %*% fits[[nm]]$coef), d)$E
  })
  names(E_in[[ds]]) <- names(X)
  cat(sprintf("%s: %d rows, %d cases, %d shoes (fits %.0f s)\n", ds, nrow(d),
              sum(d$n_Acc), length(unique(d$shoe)),
              proc.time()[["elapsed"]] - t0))
  for (nm in names(X)) {
    f <- fits[[nm]]
    cat(sprintf("  %-8s %2d coef, loglik %.2f, AIC %.1f | %s | %s\n", nm, f$k,
                f$loglik, -2 * f$loglik + 2 * f$k,
                region_line(d, E_in[[ds]][[nm]], ds),
                cell_summary(d, E_in[[ds]][[nm]])))
  }
  lr <- function(a, b) {
    s <- 2 * (fits[[b]]$loglik - fits[[a]]$loglik)
    k <- fits[[b]]$k - fits[[a]]$k
    sprintf("%s -> %s LR %.1f on %d df (p %.2g)", a, b, s, k,
            pchisq(s, k, lower.tail = FALSE))
  }
  cat("  model-based LR:", lr("K8", "full"), ";", lr("full", "fullU"), ";",
      lr("K8", "fullU"), "\n")
  if (ds == "new") {
    G <- grid_designs(d)
    all_ratio <- sum(d$n_Acc) / sum(d$n_Acc == 0)
    for (nm in c("K8", "fullU")) {
      m <- local_maxima(as.vector(G[[nm]] %*% fits[[nm]]$coef))
      cat(sprintf(paste("  %s surface, local maxima: new_x, y, height above",
                        "the median; around each (|dx| < 0.025, |dy| <",
                        "0.04) cases, controls and their ratio / NEW's\n"),
                  nm))
      for (j in seq_len(nrow(m))) {
        w <- abs(d$new_x - m$new_x[j]) < 0.025 &
          abs(d$y - m$y[j]) < 0.04 - 1e-9
        cat(sprintf(paste("    %7.3f %7.3f %+5.2f | cases %4d controls %5d",
                          "ratio %.2f\n"),
                    m$new_x[j], m$y[j], m$rel[j], sum(d$n_Acc[w]),
                    sum(d$n_Acc[w] == 0),
                    (sum(d$n_Acc[w]) / sum(d$n_Acc[w] == 0)) / all_ratio))
      }
    }
    rm(G)
  }
  yb2 <- cut(d$y, seq(-0.32, -0.04, by = 0.02))
  cat(sprintf("  %-14s %5s %6s %6s\n", "y (heel front)", "O", "K8",
              "fullU"))
  for (lev in levels(yb2)) {
    i <- which(yb2 == lev)
    cat(sprintf("  %-14s %5d %6.2f %6.2f\n", lev, sum(d$n_Acc[i]),
                oe(d$n_Acc[i], E_in[[ds]]$K8[i]),
                oe(d$n_Acc[i], E_in[[ds]]$fullU[i])))
  }
}

cat("\n== B. 5-fold cross-validation by shoe (seed 2026)\n")
for (ds in c("new", "old")) {
  d <- dat[[ds]]
  X <- X_all[[ds]]
  set.seed(2026)
  shoes <- sort(unique(d$shoe))
  fold <- sample(rep(1:5, length.out = length(shoes)))
  fd <- fold[match(d$shoe, shoes)]
  t0 <- proc.time()[["elapsed"]]
  # per row: the held-out log probability of each case (NA for the
  # controls), one column per basis; per basis the held-out expected counts
  lp <- matrix(NA_real_, nrow(d), length(X), dimnames = list(NULL, names(X)))
  held <- list()
  for (nm in names(X)) {
    Eh <- numeric(nrow(d))
    for (k in 1:5) {
      tr <- fd != k
      te <- which(!tr)
      f <- fit_cml(X[[nm]][tr, , drop = FALSE], d[tr, ])
      e <- expected(as.vector(X[[nm]][te, , drop = FALSE] %*% f$coef),
                    d[te, ])
      Eh[te] <- e$E
      cs <- d$n_Acc[te] == 1
      lp[te[cs], nm] <- log(e$p[cs])
    }
    held[[nm]] <- Eh
    cat(sprintf("%s %-8s %2d cols: held-out log score %.1f | held-out %s\n",
                ds, nm, ncol(X[[nm]]), sum(lp[, nm], na.rm = TRUE),
                region_line(d, Eh, ds)))
  }
  cases <- d$n_Acc == 1
  fs <- factor(d$shoe, levels = shoes)
  # per shoe: the held-out log score of its cases (every shoe has a case)
  score <- apply(lp, 2, function(v) tapply(v[cases], fs[cases], sum))
  # the gain of fullU, with its standard error over shoes (the shoe is the
  # independent unit: SE = sqrt(m) sd of the per-shoe differences)
  gain <- function(other) {
    di <- score[, "fullU"] - score[, other]
    se <- sqrt(length(di)) * sd(di)
    sprintf("%s %+.1f (SE %.1f, z %.1f; %d of %d shoes gain)", other, sum(di),
            se, sum(di) / se, sum(di > 0), length(di))
  }
  cat(sprintf("%s: held-out log score of fullU minus %s; %s; %s (%.0f s)\n",
              ds, gain("K8"), gain("full"), gain("full_5x9"),
              proc.time()[["elapsed"]] - t0))
  key <- interaction(cut(d$new_x, xb), cut(d$y, yb), sep = "|", drop = TRUE)
  heel <- sub(".*[|]", "", levels(key)) %in%
    c("(-0.28,-0.2]", "(-0.2,-0.12]", "(-0.12,-0.04]")
  for (nm in c("K8", "fullU")) {
    O <- tapply(d$n_Acc, key, sum)
    Ec <- tapply(held[[nm]], key, sum)
    z <- (O - Ec) / sqrt(tapply(held[[nm]] * (1 - held[[nm]]), key, sum))
    ok <- Ec >= 15
    cat(sprintf(paste("  %s, held-out cells (E >= 15): heel front y (-0.28,",
                      "-0.04] %d cells, sum z^2 %.0f, |z| > 3: %d; the other",
                      "%d cells, sum z^2 %.0f, |z| > 3: %d\n"),
                nm, sum(ok & heel), sum(z[ok & heel]^2),
                sum(abs(z[ok & heel]) > 3), sum(ok & !heel),
                sum(z[ok & !heel]^2), sum(abs(z[ok & !heel]) > 3)))
  }
  set.seed(7)
  draws <- replicate(2000, sample(length(shoes), replace = TRUE))
  sel <- regions(d)
  if (ds == "new") {
    sel$band_A <- sel$band & is_a(d$shoe)
    sel$band_B <- sel$band & !is_a(d$shoe)
  }
  for (nm in c("K8", "fullU")) {
    parts <- vapply(names(sel), function(k) {
      O <- tapply(d$n_Acc * sel[[k]], fs, sum)
      E <- tapply(held[[nm]] * sel[[k]], fs, sum)
      rb <- colSums(matrix(O[draws], nrow(draws))) /
        colSums(matrix(E[draws], nrow(draws)))
      sprintf("%s %.2f [%.2f, %.2f]", k, sum(O) / sum(E),
              quantile(rb, 0.025), quantile(rb, 0.975))
    }, "")
    cat(sprintf("  %s, held-out O/E with shoe-bootstrap intervals: %s\n", nm,
                paste(parts, collapse = "; ")))
  }
}

cat(paste("\n== C. NEW: one surface for both groups? Band O/E, pooled vs",
          "own-group fits\n"))
d <- dat$new
a <- is_a(d$shoe)
band <- regions(d)$band
fmt <- function(O, E) sprintf("%.2f (O %d, E %.1f)", oe(O, E), sum(O), sum(E))
for (nm in c("K8", "full_5x9", "fullU")) {
  X <- X_all$new[[nm]]
  Ep <- E_in$new[[nm]]
  own <- lapply(list(A = a, B = !a), function(sel) {
    f <- fit_cml(X[sel, , drop = FALSE], d[sel, ])
    expected(as.vector(X[sel, , drop = FALSE] %*% f$coef), d[sel, ])$E
  })
  cat(sprintf(paste("%-8s pooled fit: all %s, A %s, B %s | own-group fits:",
                    "A %s, B %s\n"), nm,
              fmt(d$n_Acc[band], Ep[band]),
              fmt(d$n_Acc[band & a], Ep[band & a]),
              fmt(d$n_Acc[band & !a], Ep[band & !a]),
              fmt(d$n_Acc[a][band[a]], own$A[band[a]]),
              fmt(d$n_Acc[!a][band[!a]], own$B[band[!a]])))
}

cat(sprintf("\nt5_basis_y.R done in %.0f s\n",
            proc.time()[["elapsed"]] - t_start))
