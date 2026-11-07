# tests/r/test_compare_old_new.R: statistical_model/R/compare_old_new.R and
# the committed outputs of the OLD-vs-NEW comparison (plan T6 step 1; the
# T6 task: statistical_model/compare_old_new_7.Rmd,
# tools/fit_compare_models.R).
#
# 1. Names: a compare file lies in a compare folder and ends with
#    _old_vs_new; a T6 fit of NEW lies in a new folder and ends with _new,
#    of OLD in saved_models/t6 without a suffix; t6_compare_path() refuses
#    a NEW profile; t6_new_output() refuses an existing file.
# 2. Bases: t6_spec("K8") is basis_knots(); t6_design() of the step-3 basis
#    on the prototype grid is step 4's design matrix (built here as step 4
#    builds it, with predict() of the ns() bases): identical() for both
#    datasets; the full tensor has 34 columns and the finer y basis 84 with
#    15 y knots that contain the 5 step-3 knots.
# 3. Maps: t6_step4_map() equals step 4's own matrix `intens` (the code of
#    shoe_std_results_4.Rmd evaluated unchanged, as tools/figures_png.R does,
#    with its PDF sent to a null device): identical() for the OLD GLMM and the
#    NEW CML; prototype dims; NA exactly outside the mask.
# 4. equality_wald(): W(b, b) = 0; under H0 the model-based test with the
#    true V and the paired-difference test with a bootstrap V of B = 200
#    draws (re-estimated in every replicate, F(p, B - p) reference) reject
#    in [0.03, 0.07] (2,000 replicates, seed 7); the separate-draws chi^2
#    version is reported (plan T6 step 1, F36).
# 5. Offset refits: fit_offset() on 20 NEW shoes uses the offsets
#    log((px - n) / 100) (getME offset, max diff 0) and the data's own
#    basis; t6_eta() refuses MEAN_OFFSET for an offset refit; the committed
#    refits (saved_models/NEW_X_NS_XY_offset.rds and the NEW twin): offsets
#    = log((pixel_count - cases) / 100) per row, intercept within 0.01 of the
#    no-offset intercept + mean over shoes of log(100 / (px - n)), spatial
#    coefficients within 0.05 of the no-offset fit on OLD (plan; T0 0.0184)
#    and 0.1 on NEW (F82: 0.084), sigma^2 printed.
# 6. Calibration: the weights add up to every shoe's contact pixels S, the
#    calibrated surface reproduces the RAC total, and the delta-method
#    gradient equals a numerical gradient.
# 7. Naomi's 14 areas: naomi_area() = a port of her loops (rac-intensity,
#    "Organizing data to include subsets (larger areas).R", lines 28-117)
#    on 20,000 random points; all 14 areas on the prototype; the mirror.
# 8. Every committed T6 fit record is tied to the step-2 rows of its rule
#    (its knots recomputed, its shoes, rows and cases) and converged: code 0,
#    or, for a GLMM whose optimizer stopped at its own limit, the Laplace
#    deviance rebuilt from the rows = -2 logLik at the record and a flat
#    central-difference gradient there; the T6 tables are tied to the models
#    they come from (fixed effects, the GLMM equality Wald).
# 9. Bootstrap helpers on a toy: t6_boot_draws() refuses draws of another
#    fit; t6_boot_pair() pairs by index and drops the intercept;
#    t6_wald_boot() = b' cov(draws)^-1 b with F(p, B - p); t6_logdens_sd()
#    (streamed in chunks) = sd() and quantile() of the explicit per-draw log
#    densities; a draw equal to the fit gives the calibrated density of
#    t6_density(). Every committed bootstrap record: B x p draws centred on
#    its fit (the committed model or T6 record), ids of the fit's shoes,
#    seed, no NA; the bootstrap tables of the Rmd recomputed from it.
# 10. tools/run_compare_fits.sh (--dry-run) runs every job of
#    tools/fit_compare_models.R --list exactly once, and each job that reads
#    another fit runs in a later stage than that fit.
# 11. The T6 review fixes (it runs before section 10):
#    t6_cal_rows' per-shoe cases and contact pixels; t6_logdens_boot =
#    an explicit per-draw calibration for the kinds fixed, resampled (each
#    draw recalibrated on its resampled shoes) and shape (each draw divided
#    by its resampled observed density), on simulated draws and resamples;
#    every shoe drawn once gives resampled = fixed and shape = fixed -
#    log(observed density); the committed bootstrap cut bands of OLD at row
#    110 recomputed from the record; t6_pinned_band and the band share of
#    the shares table; the model-free regional table (two regions, point
#    estimates and bootstrap intervals recomputed with the Rmd's seed and
#    order of draws); the moment estimator of sigma^2 (plan F82's values
#    and the table's estimates); t6_match_racs on a synthetic shift and
#    mirror and on three committed pairs; the primary equality test (no
#    reprints, shoe bootstrap) recomputed from the records; the
#    full-tensor between-area ratios recomputed from their records.
# Writes only below tempdir().
#
# Run from anywhere:  Rscript tests/r/test_compare_old_new.R
suppressMessages({
  library(splines)
  library(lme4)
  library(survival)
})
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "io.R", "compare.R", "compare_old_new.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
pass <- function(name) cat("PASS", name, "\n")
t_all <- proc.time()[["elapsed"]]
P_old <- rac_profile("old", root = ROOT_PATH)
P_new <- rac_profile("new", root = ROOT_PATH)
read_step2 <- function(P) {
  d <- read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
  subset(d, select = c("n_Acc", "x", "y", "shoe", "row_number", "horiz_dist",
                       "new_x"))
}
D <- list(old = read_step2(P_old), new = read_step2(P_new))
CODES <- list(old = read.csv(rac_path(P_old, "shoe_codes")),
              new = read.csv(rac_path(P_new, "shoe_codes")))
PC <- list(old = read.csv(rac_path(P_old, "pixel_counts")),
           new = read.csv(rac_path(P_new, "pixel_counts")))

# --- 1. names --------------------------------------------------------------------
for (k in c("csv", "pdf", "png")) {
  p <- t6_compare_path(P_old, k, "maps")
  parts <- strsplit(sub(ROOT_PATH, "", p, fixed = TRUE), "/", fixed = TRUE)[[1]]
  stopifnot(endsWith(p, paste("maps_old_vs_new.", k, sep = "")),
            any(parts %in% c("compare", "T6")), !any(parts == "new"))
}
stopifnot(inherits(tryCatch(t6_compare_path(P_new, "csv", "x"), error = identity), "error"))
pn <- sub(ROOT_PATH, "", t6_fit_path(P_new, "CML_MODEL_full"), fixed = TRUE)
po <- sub(ROOT_PATH, "", t6_fit_path(P_old, "CML_MODEL_full"), fixed = TRUE)
stopifnot(identical(pn, "saved_models/new/t6/CML_MODEL_full_new.rds"),
          identical(po, "saved_models/t6/CML_MODEL_full.rds"))
tmp <- tempfile()
writeLines("x", tmp)
stopifnot(inherits(tryCatch(t6_new_output(tmp), error = identity), "error"),
          identical(t6_new_output(tmp, force = TRUE), tmp))
unlink(tmp)
pass("names: compare files in compare folders with _old_vs_new; NEW fits new/t6/*_new.rds; OLD fits t6/*.rds; no overwrite")

# --- 2. bases ----------------------------------------------------------------------
G <- t6_grid(P_old)
pr <- P_old$prototype
step4_design <- function(d) {
  xcoor <- t(matrix(rep((-pr$col_shoe / 2 + 1:pr$col_shoe) * pr$coords$rel_Y_cord /
                          pr$coords$rel_col_shoe, pr$row_shoe), pr$col_shoe, pr$row_shoe))
  ycoor <- -matrix(rep((-pr$row_shoe / 2 + 1:pr$row_shoe) * pr$coords$rel_Y_cord /
                         pr$coords$rel_col_shoe, pr$col_shoe), pr$row_shoe, pr$col_shoe)
  xy <- expand.grid(xcoor[1, ], ycoor[, 1])
  stopifnot(identical(xy[[1]], G$x), identical(xy[[2]], G$y))
  knots_new_x <- as.numeric(quantile(d$new_x, 1:3 / 4))
  knotsy <- as.numeric(quantile(d$y, 1:5 / 6))
  bas_new_x <- ns(d$new_x, knots = knots_new_x)
  basy <- ns(d$y, knots = knotsy)
  nd <- rep(1, length(xy[[1]]))
  for (i in 1:length(predict(basy, 1))) {
    for (j in 1:length(predict(bas_new_x, 1))) {
      nd <- cbind(nd, predict(bas_new_x, xy[[1]])[, j] * predict(basy, xy[[2]])[, i])
    }
  }
  nd
}
for (ds in names(D)) {
  sp <- t6_spec(D[[ds]], "K8")
  stopifnot(identical(sp[-1], basis_knots(D[[ds]])))
  X1 <- cbind(1, t6_design(sp, G$x, G$y))
  stopifnot(identical(unname(step4_design(D[[ds]])), unname(X1)))
  sf <- t6_spec(D[[ds]], "fineY")
  stopifnot(ncol(t6_design(t6_spec(D[[ds]], "full"), D[[ds]]$new_x[1:9], D[[ds]]$y[1:9])) == 34,
            ncol(t6_design(sf, D[[ds]]$new_x[1:9], D[[ds]]$y[1:9])) == 84,
            length(sf$knots_y) == 15, all(sp$knots_y %in% sf$knots_y),
            identical(sf$bknots_y, sp$bknots_y))
}
pass("bases: the step-3 design on the prototype grid = step 4's newdesignmat (both datasets); full 34, finer y 84 columns")

# --- 3. maps = step 4 ----------------------------------------------------------------
step4_intens <- function(dataset, feature) {
  code <- tempfile(fileext = ".R")
  on.exit(unlink(code))
  knitr::purl(file.path(root, "statistical_model", "shoe_std_results_4.Rmd"),
              output = code, documentation = 0, quiet = TRUE)
  old_env <- Sys.getenv(c("RAC_DATASET", "RAC_MODEL_FEATURE", "RGL_USE_NULL"), unset = NA)
  Sys.setenv(RAC_DATASET = dataset, RAC_MODEL_FEATURE = feature, RGL_USE_NULL = "TRUE")
  old_wd <- setwd(file.path(root, "statistical_model"))
  on.exit({
    setwd(old_wd)
    for (v in names(old_env)) {
      if (is.na(old_env[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old_env[v]))
    }
  }, add = TRUE)
  e <- new.env(parent = globalenv())
  e$pdf <- function(...) grDevices::pdf(file = NULL)
  e$rac_new_output <- function(P, path) path
  n_dev <- length(grDevices::dev.list())
  grDevices::pdf(file = NULL)
  suppressMessages(suppressWarnings(utils::capture.output(sys.source(code, envir = e))))
  while (length(grDevices::dev.list()) > n_dev) grDevices::dev.off()
  e
}
mean_offset <- function(P) mean(log(P$r$n_controls / read.csv(rac_path(P, "pixel_counts"))$pixel_count))
t0 <- proc.time()[["elapsed"]]
e <- step4_intens("old", "NEW_X_NS_XY")
m_old <- readRDS(rac_model_path(P_old, "NEW_X_NS_XY"))
f_old <- t6_from_model(m_old, "OLD GLMM", D$old)
mine <- t6_step4_map(f_old, f_old$spec, G, mean_offset(P_old), f_old$sigma2_step4)
stopifnot(identical(dim(mine), c(as.integer(pr$row_shoe), as.integer(pr$col_shoe))),
          identical(is.na(mine), G$mask == 0), identical(mine, e$intens))
e <- step4_intens("new", "CML_MODEL")
m_new <- readRDS(rac_model_path(P_new, "NEW_X_NS_XY"))
f_new <- t6_from_model(m_new, "NEW GLMM", D$new)
f_cml <- t6_from_model(readRDS(rac_model_path(P_new, "CML_MODEL")), "NEW CML", D$new)
mr <- t6_m_random(f_new, f_new$spec, G, mean_offset(P_new))
mine <- t6_step4_map(f_cml, f_cml$spec, G, NULL, f_new$sigma2_step4, m_random = mr)
stopifnot(identical(mine, e$intens), identical(is.na(mine), G$mask == 0))
pass(sprintf("maps: t6_step4_map = step 4's intens, identical(), OLD GLMM and NEW CML; %d x %d, NA outside the mask (%.0f s)",
             nrow(mine), ncol(mine), proc.time()[["elapsed"]] - t0))

# --- 4. equality_wald ------------------------------------------------------------------
b <- f_old$coef
V <- f_old$vcov
stopifnot(equality_wald(b, b, V, V)$W == 0, equality_wald(b, b, V, V)$df == 24)
set.seed(7)
p <- 24
A1 <- matrix(rnorm(p * p), p) / sqrt(p)
V1 <- crossprod(A1) + diag(0.2, p)
A2 <- matrix(rnorm(p * p), p) / sqrt(p)
V2 <- crossprod(A2) + diag(0.3, p)
R1 <- chol(V1)
R2 <- chol(V2)
reps <- 2000
Bb <- 200
rej <- matrix(FALSE, reps, 3, dimnames = list(NULL, c("known", "paired_F", "separate_chi2")))
for (r in seq_len(reps)) {
  b1 <- as.vector(crossprod(R1, rnorm(p)))
  b2 <- as.vector(crossprod(R2, rnorm(p)))
  d1 <- matrix(rnorm(Bb * p), Bb) %*% R1
  d2 <- matrix(rnorm(Bb * p), Bb) %*% R2
  rej[r, 1] <- equality_wald(b1, b2, V1, V2, drop_intercept = FALSE)$p < 0.05
  rej[r, 2] <- equality_wald(b1, b2, Dd = d1 - d2, drop_intercept = FALSE)$p < 0.05
  rej[r, 3] <- equality_wald(b1, b2, cov(d1), cov(d2), drop_intercept = FALSE)$p < 0.05
}
rates <- colMeans(rej)
print(round(rates, 4))
stopifnot(rates[["known"]] >= 0.03, rates[["known"]] <= 0.07,
          rates[["paired_F"]] >= 0.03, rates[["paired_F"]] <= 0.07)
pass(sprintf(paste("equality_wald: W(b, b) = 0; under H0 known V %.4f, paired draws with F(%d, %d) %.4f",
                   "(both in [0.03, 0.07]); separate draws with chi^2 %.4f (reported)"),
             rates[["known"]], p, Bb - p, rates[["paired_F"]], rates[["separate_chi2"]]))

# --- 5. offset refits ---------------------------------------------------------------------
d <- D$new
n_case <- tapply(d$n_Acc, d$shoe, sum)
set.seed(21)
pick <- sort(sample(as.integer(names(n_case)[n_case <= 25]), 20))
sub <- d[d$shoe %in% pick, ]
mo <- fit_offset(sub, CODES$new, PC$new)
px <- PC$new$pixel_count[match(sub$shoe, PC$new$shoe)]
n <- ave(sub$n_Acc, sub$shoe, FUN = sum)
stopifnot(max(abs(getME(mo, "offset") - log((px - n) / 100))) == 0,
          identical(basis_of(mo), basis_knots(sub)))
so <- t6_from_model(mo, "sub", sub)
so$offset_refit <- TRUE
stopifnot(inherits(tryCatch(t6_eta(so, so$spec, 0, 0, mean_offset = -4), error = identity), "error"),
          is.numeric(t6_eta(so, so$spec, 0, 0)))
pass("fit_offset: offsets log((px - n)/100) on 20 NEW shoes (max diff 0), own basis; t6_eta refuses MEAN_OFFSET for an offset refit")
for (ds in c("old", "new")) {
  P <- if (ds == "old") P_old else P_new
  path <- rac_model_path(P, "NEW_X_NS_XY_offset")
  stopifnot(file.exists(path))
  m <- readRDS(path)
  dd <- D[[ds]]
  pxs <- PC[[ds]]$pixel_count[match(CODES[[ds]]$shoe[match(dd$shoe, CODES[[ds]]$code)], PC[[ds]]$shoe)]
  ns_ <- ave(dd$n_Acc, dd$shoe, FUN = sum)
  base <- if (ds == "old") f_old else f_new
  pred <- base$coef[[1]] + mean(tapply(log(100 / (pxs - ns_)), dd$shoe, mean))
  dsp <- max(abs(fixef(m)[-1] - base$coef[-1]))
  stopifnot(nobs(m) == nrow(dd), max(abs(getME(m, "offset") - log((pxs - ns_) / 100))) == 0,
            abs(fixef(m)[[1]] - pred) < 0.01, dsp < if (ds == "old") 0.05 else 0.1,
            identical(basis_of(m), basis_knots(dd)), m@optinfo$conv$opt == 0)
  pass(sprintf(paste("%s offset refit: offsets exact; intercept %.6f vs predicted %.6f; largest spatial change %.4f;",
                     "sigma^2 %.6f (no offset %.6f)"), toupper(ds), fixef(m)[[1]], pred, dsp,
               as.numeric(VarCorr(m)$shoe), base$sigma2))
  rm(m)
  invisible(gc())
}

# --- 6. calibration ------------------------------------------------------------------------
cal <- t6_calibration(f_old, f_old$spec, D$old, CODES$old, PC$old)
ids <- CODES$old$shoe
stopifnot(abs(cal$contact_px - sum(PC$old$pixel_count[match(ids, PC$old$shoe)])) < 1e-6,
          cal$N == sum(D$old$n_Acc))
s_ <- t6_shoe_px(D$old, CODES$old, PC$old)
w <- ifelse(D$old$n_Acc == 1, 1, (s_$px - s_$n) / 100)
dens <- t6_density(f_old, f_old$spec, D$old$new_x, D$old$y, cal, se = FALSE)$density
stopifnot(abs(sum(w * dens) - cal$N) < 1e-6 * cal$N)
pts <- c(5000, 20000, 40000)
r0 <- t6_density(f_old, f_old$spec, D$old$new_x[pts], D$old$y[pts], cal)
num_grad <- sapply(seq_along(f_old$coef), function(k) {
  h <- 1e-6
  fp <- f_old
  fp$coef[k] <- fp$coef[k] + h
  cp <- t6_calibration(fp, fp$spec, D$old, CODES$old, PC$old)
  (log(t6_density(fp, fp$spec, D$old$new_x[pts], D$old$y[pts], cp, se = FALSE)$density) -
     log(r0$density)) / h
})
G1 <- sweep(cbind(1, t6_design(f_old$spec, D$old$new_x[pts], D$old$y[pts])), 2, cal$xbar)
stopifnot(max(abs(num_grad - G1)) < 1e-4)
pass(sprintf("calibration: weights sum to the contact pixels, the RAC total reproduced; delta gradient = numerical (max diff %.2g)",
             max(abs(num_grad - G1))))

# --- 7. Naomi's 14 areas ------------------------------------------------------------------
naomi_loops <- function(x, y) {
  a <- rep(NA_integer_, length(x))
  for (i in seq_along(x)) {
    if (x[i] < 0) {
      if (y[i] < -0.35) a[i] <- 1L
      if (y[i] >= -0.35 && y[i] < -0.15) a[i] <- 2L
      if (y[i] >= -0.15 && y[i] < 0) a[i] <- 3L
      if (y[i] >= 0 && y[i] < 0.15) a[i] <- 4L
      if (y[i] >= 0.15) a[i] <- 5L
    } else {
      if (y[i] < -0.35) a[i] <- 10L
      if (y[i] >= -0.35 && y[i] < -0.15) a[i] <- 9L
      if (y[i] >= -0.15 && y[i] < 0) a[i] <- 8L
      if (y[i] >= 0 && y[i] < 0.15) a[i] <- 7L
      if (y[i] >= 0.15) a[i] <- 6L
    }
  }
  for (i in seq_along(x)) if (a[i] == 4 && y[i] > 12 * (x[i] + 0.02)^2 - 0.07) a[i] <- 11L
  for (i in seq_along(x)) if (a[i] == 5 && y[i] < -12 * (x[i] + 0.01)^2 + 0.4) a[i] <- 12L
  for (i in seq_along(x)) if (a[i] == 6 && y[i] < -20 * (x[i] + 0.01)^2 + 0.4) a[i] <- 13L
  for (i in seq_along(x)) if (a[i] == 7 && y[i] > 16 * (x[i] + 0.02)^2 - 0.07) a[i] <- 14L
  a
}
set.seed(11)
rx <- c(runif(20000, -0.3, 0.3), -0.35, 0, 0.15)
ry <- c(runif(20000, -0.6, 0.6), -0.35, 0, -0.15)
stopifnot(identical(naomi_area(rx, ry), naomi_loops(rx, ry)))
am <- t6_area_of_grid(G, mirror = TRUE)
au <- t6_area_of_grid(G, mirror = FALSE)
stopifnot(identical(sort(unique(am[G$inside])), 1:14), identical(am, naomi_area(-G$x, G$y)),
          identical(au, naomi_area(G$x, G$y)), mean(am[G$inside] != au[G$inside]) > 0.5)
pass(sprintf("Naomi's areas: = her loops on 20,003 points; 14 areas on the prototype; mirrored differs from unmirrored on %.0f%% of it",
             100 * mean(am[G$inside] != au[G$inside])))

# --- 8. T6 records and tables ----------------------------------------------------------
recs_all <- c(Sys.glob(file.path(root, "saved_models", "t6", "*.rds")),
              Sys.glob(file.path(root, "saved_models", "new", "t6", "*.rds")))
recs <- recs_all[!grepl("/profile_|_bootpirls", recs_all)]
stopifnot(length(recs) >= 12)
reprints <- t6_reprint_ids(root)
for (path in recs) {
  r <- readRDS(path)
  ds <- r$dataset
  dd <- D[[ds]]
  if (r$shoes_rule == "norep") dd <- dd[!dd$shoe %in% reprints, ]
  if (r$shoes_rule == "groupB") dd <- dd[!t6_group_a(dd$shoe), ]
  src <- if (grepl("_old$", r$basis_rule)) D$old else dd
  want <- t6_spec(src, r$spec$type)
  stopifnot(identical(r$spec, want), r$nobs == nrow(dd), r$n_cases == sum(dd$n_Acc),
            identical(r$shoes, sort(unique(dd$shoe))),
            identical(ds == "new", grepl("/new/t6/", path) && endsWith(path, "_new.rds")),
            length(r$coef) == ncol(t6_design(r$spec, 0, 0)) + (r$feature == "NEW_X_NS_XY"))
  if (r$conv != 0) {
    # an optimizer that stopped at its own iteration or evaluation limit
    # (the NEW full-tensor GLMM: nlminb and bobyqa both, at the same point):
    # the record counts as converged only if the Laplace deviance rebuilt
    # from the step-2 rows equals -2 logLik there and its central-difference
    # gradient is flat (|g| <= 0.05 for theta, |g| x SE <= 0.05 for every
    # fixed effect, i.e. a move of one SE changes the deviance by at most
    # 0.05 to first order)
    stopifnot(r$feature == "NEW_X_NS_XY", r$nAGQ == 1)
    xd <- data.frame(n_Acc = dd$n_Acc, shoe = dd$shoe)
    xd$X <- t6_design(r$spec, dd$new_x, dd$y)
    devf <- glmer(n_Acc ~ X + (1 | shoe), data = xd, family = binomial, devFunOnly = TRUE)
    par0 <- c(r$theta, unname(r$coef))
    g <- vapply(seq_along(par0), function(k) {
      e <- replace(numeric(length(par0)), k, 1e-4)
      (devf(par0 + e) - devf(par0 - e)) / 2e-4
    }, 0)
    gse <- abs(g[-1]) * sqrt(diag(r$vcov))
    stopifnot(abs(devf(par0) + 2 * r$loglik) < 1e-6 * abs(r$loglik), abs(g[1]) <= 0.05, max(gse) <= 0.05)
    pass(sprintf("%s: %s stopped at its limit (conv %d); the deviance = -2 logLik there, gradient theta %.4f, max |g| x SE %.4f",
                 basename(path), r$optimizer, r$conv, g[1], max(gse)))
  }
}
pass(sprintf("T6 records: %d fits tied to the step-2 rows of their rule (knots, shoes, rows, cases), converged", length(recs)))
fx <- read.csv(t6_compare_path(P_old, "csv", "fixef"))
m_ob <- readRDS(rac_model_path(P_new, "NEW_X_NS_XY_oldbasis"))
f_ob <- t6_from_model(m_ob, "NEW GLMM, OLD basis", D$new)
rm(m_ob, m_old, m_new)
invisible(gc())
g <- fx[fx$model == "GLMM" & fx$comparison == "NEW (all) on the OLD basis", ]
stopifnot(identical(g$term, names(f_old$coef)), max(abs(g$b_old - f_old$coef)) < 1e-12,
          max(abs(g$b_new - f_ob$coef)) < 1e-12,
          max(abs(g$se_old - sqrt(diag(f_old$vcov)))) < 1e-12)
eq <- read.csv(t6_compare_path(P_old, "csv", "equality_wald"))
w <- equality_wald(f_old$coef, f_ob$coef, f_old$vcov, f_ob$vcov)
e1 <- eq[eq$model == "GLMM" & eq$comparison == "OLD vs NEW (all), OLD basis" & eq$reference == "chi2", ]
stopifnot(nrow(e1) == 1, abs(e1$W - w$W) < 1e-8 * w$W, e1$df == 24)
pass(sprintf("T6 tables: fixef table = the models (OLD GLMM, NEW GLMM on the OLD basis); GLMM equality W %.3f recomputed", w$W))

# --- 9. bootstrap helpers and records ----------------------------------------------------
set.seed(9)
toy <- list(coef = c("(Intercept)" = -6, "x1:y1" = 0.5, "x2:y1" = -0.3), feature = "NEW_X_NS_XY")
dr <- cbind(-6 + rnorm(240, 0, 0.1), 0.5 + rnorm(240, 0, 0.2), -0.3 + rnorm(240, 0, 0.3))
colnames(dr) <- names(toy$coef)
rec_t <- list(draws = dr, coef = toy$coef)
stopifnot(identical(t6_boot_draws(rec_t, toy), dr))
bad <- rec_t
bad$coef[2] <- 0.6
stopifnot(inherits(tryCatch(t6_boot_draws(bad, toy), error = identity), "error"))
bad <- rec_t
colnames(bad$draws)[2] <- "x9:y9"
stopifnot(inherits(tryCatch(t6_boot_draws(bad, toy), error = identity), "error"))
rec_u <- list(draws = dr[1:200, ] + 0.01, coef = toy$coef + 0.01)
toy_u <- toy
toy_u$coef <- toy$coef + 0.01
pd <- t6_boot_pair(rec_t, rec_u, toy, toy_u)
stopifnot(identical(dim(pd), c(200L, 2L)), identical(colnames(pd), c("x1:y1", "x2:y1")),
          max(abs(pd - (dr[1:200, 2:3] - (dr[1:200, 2:3] + 0.01)))) < 1e-15)
wb <- t6_wald_boot(toy$coef, dr)
bb <- toy$coef[2:3]
W_hand <- as.numeric(t(bb) %*% solve(cov(dr[, 2:3])) %*% bb)
stopifnot(abs(wb$W - W_hand) < 1e-10 * W_hand, wb$df == 2, wb$B == 240,
          abs(wb$p - pf(W_hand * (240 - 2) / (2 * 239), 2, 238, lower.tail = FALSE)) < 1e-12)
# t6_logdens_sd against explicit draws, on the OLD GLMM with simulated draws
Vs <- f_old$vcov
Rs <- chol(Vs)
drs <- t(f_old$coef + t(matrix(rnorm(250 * length(f_old$coef)), 250) %*% Rs))
colnames(drs) <- names(f_old$coef)
rows <- t6_cal_rows(f_old, D$old, CODES$old, PC$old)
pts <- c(17, 9000, 31000, 51000)
bs <- t6_logdens_sd(f_old, rows, drs, D$old$new_x[pts], D$old$y[pts], chunk = 37L, quantiles = TRUE)
Xp <- cbind(1, t6_design(f_old$spec, D$old$new_x[pts], D$old$y[pts]))
ld <- sapply(seq_len(nrow(drs)), function(k) {
  eta <- as.vector(rows$X1 %*% drs[k, ])
  as.vector(Xp %*% drs[k, ]) + log(rows$N) - log(sum(rows$w * exp(eta)))
})
stopifnot(max(abs(bs$sd - apply(ld, 1, sd))) < 1e-12,
          max(abs(bs$q_lo - apply(ld, 1, quantile, 0.025, names = FALSE))) < 1e-12,
          max(abs(bs$q_hi - apply(ld, 1, quantile, 0.975, names = FALSE))) < 1e-12)
one <- t6_logdens_sd(f_old, rows, rbind(f_old$coef, f_old$coef), D$old$new_x[pts], D$old$y[pts],
                     quantiles = TRUE)
stopifnot(max(abs(exp(one$q_lo) - t6_density(f_old, f_old$spec, D$old$new_x[pts], D$old$y[pts], cal,
                                              se = FALSE)$density)) < 1e-12 * max(exp(one$q_lo)))
pass("bootstrap helpers: draws tied to their fit, paired differences, Wald with F(p, B - p), streamed SD and quantiles = explicit")
boots <- recs_all[grepl("_bootpirls", recs_all)]
for (path in boots) {
  r <- readRDS(path)
  P <- if (r$dataset == "old") P_old else P_new
  fit <- if (file.exists(rac_model_path(P, r$fit))) {
    if (r$fit == "NEW_X_NS_XY" && r$dataset == "old") f_old else if (r$fit == "NEW_X_NS_XY_oldbasis") f_ob else
      suppressWarnings(t6_from_model(readRDS(rac_model_path(P, r$fit)), r$fit, D[[r$dataset]]))
  } else {
    readRDS(t6_fit_path(P, r$fit))
  }
  dd <- D[[r$dataset]]
  if (r$shoes_rule == "norep") dd <- dd[!dd$shoe %in% reprints, ]
  shoes <- sort(unique(dd$shoe))
  stopifnot(identical(colnames(r$draws), names(fit$coef)), max(abs(r$coef - fit$coef)) < 1e-12,
            nrow(r$draws) == r$B - length(r$failed), !anyNA(r$draws), identical(dim(r$ids), c(as.integer(r$B), length(shoes))),
            all(r$ids %in% shoes), r$seed %in% unlist(T6_SEEDS), identical(r$spec[-1], fit$spec[-1]),
            abs(r$theta - fit$theta) < 1e-12, grepl(if (r$dataset == "new") "/new/t6/" else "/saved_models/t6/", path))
  pass(sprintf("bootstrap record %s: %d draws (%d failed), seed %d, centred on %s, ids of its %d shoes",
               basename(path), nrow(r$draws), length(r$failed), r$seed, r$fit, length(shoes)))
}
wa <- t6_compare_path(P_old, "csv", "wald_all_spatial")
rb <- boots[grepl("/saved_models/t6/NEW_X_NS_XY_bootpirls", boots)]
rn <- boots[grepl("/new/t6/NEW_X_NS_XY_oldbasis_bootpirls_new", boots)]
if (length(rb) == 1 && length(rn) == 1) {
  ro <- readRDS(rb)
  rnw <- readRDS(rn)
  wb <- equality_wald(f_old$coef, f_ob$coef, Dd = t6_boot_pair(ro, rnw, f_old, f_ob))
  e2 <- eq[eq$model == "GLMM" & eq$comparison == "OLD vs NEW (all), OLD basis" & eq$B %in% nrow(ro$draws), ]
  stopifnot(nrow(e2) == 1, abs(e2$W - wb$W) < 1e-8 * wb$W, e2$df == 24, grepl("^F\\(24, ", e2$reference))
  pass(sprintf("T6 tables: the bootstrap equality Wald %.3f (%s, p %.3g) recomputed from the two bootstrap records",
               wb$W, wb$reference, wb$p))
}
if (file.exists(wa) && length(rb) == 1) {
  wt <- read.csv(wa)
  r <- readRDS(rb)
  wb <- t6_wald_boot(f_old$coef, r$draws)
  row <- wt[wt$fit == "glmm_old" & wt$variance == "shoe bootstrap", ]
  stopifnot(nrow(row) == 1, abs(row$W - wb$W) < 1e-8 * wb$W, row$B == nrow(r$draws))
  pass(sprintf("T6 tables: the OLD bootstrap all-spatial Wald %.3f (F reference, B = %d) recomputed from its record",
               wb$W, nrow(r$draws)))
}
# --- 11. T6 review fixes: level and shape, regions, sigma^2, RAC types, areas, primary test ----
t11 <- proc.time()[["elapsed"]]
rows_o <- t6_cal_rows(f_old, D$old, CODES$old, PC$old)
shoes_o <- as.numeric(levels(rows_o$shoe))
px_o <- PC$old$pixel_count[match(CODES$old$shoe[match(shoes_o, CODES$old$code)], PC$old$shoe)]
stopifnot(max(abs(rows_o$w_shoe - px_o)) < 1e-6 * max(px_o), sum(rows_o$n_shoe) == rows_o$N,
          identical(length(rows_o$shoe), nrow(rows_o$X1)))
# t6_logdens_boot = the explicit per-draw calibration, for every kind
set.seed(12)
ids_s <- t(replicate(nrow(drs), sample(shoes_o, length(shoes_o), replace = TRUE)))
pts11 <- c(23, 12000, 47000)
kb <- t6_logdens_boot(f_old, rows_o, drs, D$old$new_x[pts11], D$old$y[pts11], ids = ids_s,
                      kinds = c("fixed", "resampled", "shape"), chunk = 37L, quantiles = TRUE)
Xp11 <- cbind(1, t6_design(f_old$spec, D$old$new_x[pts11], D$old$y[pts11]))
for (kind in c("fixed", "resampled", "shape")) {
  ex <- sapply(seq_len(nrow(drs)), function(b) {
    eta <- as.vector(rows_o$X1 %*% drs[b, ])
    cnt <- tabulate(match(ids_s[b, ], shoes_o), nbins = length(shoes_o))
    E <- as.vector(tapply(rows_o$w * exp(eta), rows_o$shoe, sum))
    lp <- as.vector(Xp11 %*% drs[b, ])
    switch(kind,
           fixed = lp + log(rows_o$N) - log(sum(rows_o$w * exp(eta))),
           resampled = lp + log(sum(cnt * rows_o$n_shoe)) - log(sum(cnt * E)),
           shape = lp + log(sum(cnt * rows_o$w_shoe)) - log(sum(cnt * E)))
  })
  stopifnot(max(abs(kb[[kind]]$sd - apply(ex, 1, sd))) < 1e-12,
            max(abs(kb[[kind]]$q_lo - apply(ex, 1, quantile, 0.025, names = FALSE))) < 1e-12,
            max(abs(kb[[kind]]$q_hi - apply(ex, 1, quantile, 0.975, names = FALSE))) < 1e-12)
}
stopifnot(identical(kb$fixed$sd, t6_logdens_sd(f_old, rows_o, drs, D$old$new_x[pts11], D$old$y[pts11],
                                               chunk = 37L)$sd))
# every shoe drawn once: resampled = fixed, shape = fixed - log(observed density)
ids_1 <- matrix(rep(shoes_o, each = 3), 3)
k1 <- t6_logdens_boot(f_old, rows_o, drs[1:3, ], D$old$new_x[pts11], D$old$y[pts11], ids = ids_1,
                      kinds = c("fixed", "resampled", "shape"), quantiles = TRUE)
stopifnot(max(abs(k1$resampled$q_lo - k1$fixed$q_lo)) < 1e-12,
          max(abs(k1$shape$q_hi - (k1$fixed$q_hi - log(cal$observed_density)))) < 1e-12,
          inherits(tryCatch(t6_logdens_boot(f_old, rows_o, drs, 0, 0, kinds = "resampled"), error = identity), "error"),
          inherits(tryCatch(t6_boot_counts(matrix(c(shoes_o[1], -5), 1), shoes_o), error = identity), "error"),
          all(rowSums(t6_boot_counts(ids_s[1:5, ], shoes_o)) == length(shoes_o)))
pass("level and shape: t6_logdens_boot = the explicit per-draw calibration (fixed, resampled, shape); all shoes once = fixed")
# the committed bootstrap cut bands of OLD at row 110, recomputed from the record
ro <- readRDS(rb)
cbt <- read.csv(t6_compare_path(P_old, "csv", "ci_cuts_bootstrap"))
c110 <- cbt[cbt$series == "OLD" & cbt$row == 110, ]
kk <- (110 - 1) * G$ncol + c110$col
kb110 <- t6_logdens_boot(f_old, rows_o, t6_boot_draws(ro, f_old), G$x[kk], G$y[kk], ids = t6_boot_ids(ro),
                         kinds = c("fixed", "resampled", "shape"), quantiles = TRUE)
relerr <- function(a, b) max(abs(a - b) / abs(b))
stopifnot(nrow(c110) > 50, relerr(c110$lo_boot, 1000 * exp(kb110$resampled$q_lo)) < 1e-9,
          relerr(c110$hi_boot, 1000 * exp(kb110$resampled$q_hi)) < 1e-9,
          relerr(c110$se_log_boot, kb110$resampled$sd) < 1e-9,
          relerr(c110$rel_lo_boot, exp(kb110$shape$q_lo)) < 1e-9, relerr(c110$rel_hi_boot, exp(kb110$shape$q_hi)) < 1e-9,
          relerr(c110$se_log_boot_fixedN, kb110$fixed$sd) < 1e-9,
          median(kb110$resampled$sd / kb110$fixed$sd) > 1.1)
pass(sprintf(paste("bootstrap cut table: OLD row 110 bands recomputed from the record (%d columns); the level adds",
                   "a factor %.2f to the SD at the median column"), nrow(c110),
             median(kb110$resampled$sd / kb110$fixed$sd)))
# the pinned band and the shares table
band_g <- t6_pinned_band(list(f_old$spec), G$x[G$inside], G$y[G$inside], 0.03)
stopifnot(!any(t6_pinned_band(list(t6_spec(D$old, "full")), G$x, G$y, 0.03)),
          all(t6_pinned_band(list(f_old$spec), f_old$spec$bknots_x[1] + c(0, 0.0299), 0.2, 0.03)),
          !t6_pinned_band(list(f_old$spec), f_old$spec$bknots_x[1] + 0.0301, 0.2, 0.03))
shr <- read.csv(t6_compare_path(P_old, "csv", "map_shares"))
stopifnot(nrow(shr) == 10, all(abs(shr$band_share - mean(band_g)) < 1e-12),
          all(shr$share_higher >= 0 & shr$share_higher <= 1), all(shr$share_lower >= 0 & shr$share_lower <= 1),
          length(unique(shr$comparison)) == 2)
pass(sprintf("pinned band: %.1f%% of the prototype within 0.03 units of OLD's K8 edges, as in the shares table",
             100 * mean(band_g)))
# the model-free regions: point estimates and bootstrap intervals recomputed
# (two regions, defined here again) with the Rmd's seed and order of draws
rd <- lapply(list(old = P_old, new = P_new), function(P) {
  d <- read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
  d[, c("n_Acc", "new_x", "y", "shoe", "distance_shape")]
})
rd$norep <- rd$new[!rd$new$shoe %in% reprints, ]
reg2 <- list(heel_bottom = function(d) d$y < -0.35,
             forefoot_centre = function(d) d$new_x > -0.09 & d$new_x < -0.01 & d$y > 0.22 & d$y < 0.38)
rt <- list(old = t6_shoe_regions(rd$old, CODES$old, PC$old, reg2),
           new = t6_shoe_regions(rd$new, CODES$new, PC$new, reg2),
           norep = t6_shoe_regions(rd$norep, CODES$new, PC$new, reg2))
stopifnot(abs(t6_region_density(rt$old, "all") - cal$observed_density) < 1e-12 * cal$observed_density)
er <- read.csv(t6_compare_path(P_old, "csv", "empirical_regions"))
set.seed(T6_SEEDS$regions)
cnt <- lapply(rt, function(tab) {
  idx <- replicate(er$B[1], sample(nrow(tab), replace = TRUE))
  t(apply(idx, 2, tabulate, nbins = nrow(tab)))
})
for (nw in c("new", "norep")) {
  cmp <- if (nw == "new") "NEW (all) / OLD" else "NEW without reprints / OLD"
  for (r in names(reg2)) {
    e <- er[er$comparison == cmp & er$region == r, ]
    est <- t6_region_density(rt[[nw]], r) / t6_region_density(rt$old, r)
    lvl <- t6_region_density(rt[[nw]], "all") / t6_region_density(rt$old, "all")
    rb_n <- t6_region_density(rt[[nw]], c("all", r), cnt[[nw]])
    rb_o <- t6_region_density(rt$old, c("all", r), cnt$old)
    rq <- quantile(rb_n[, r] / rb_o[, r], c(0.025, 0.975), names = FALSE)
    sq <- quantile((rb_n[, r] / rb_n[, "all"]) / (rb_o[, r] / rb_o[, "all"]), c(0.025, 0.975), names = FALSE)
    stopifnot(nrow(e) == 1, abs(e$ratio - est) < 1e-9 * est, abs(e$shape_ratio - est / lvl) < 1e-9,
              abs(e$ratio_lo - rq[1]) < 1e-9, abs(e$ratio_hi - rq[2]) < 1e-9,
              abs(e$shape_lo - sq[1]) < 1e-9, abs(e$shape_hi - sq[2]) < 1e-9,
              e$cases_old == sum(rt$old[[paste(r, "_cases", sep = "")]]))
  }
}
pass(sprintf("model-free regions: heel bottom and forefoot centre ratios and their %d-draw shoe-bootstrap intervals recomputed",
             er$B[1]))
# sigma^2: the moment estimator of plan F82 and the table
mb <- read.csv(t6_compare_path(P_old, "csv", "sigma2_moment_bootstrap"))
ps_o <- t6_per_shoe(D$old, CODES$old, PC$old)
ps_n <- t6_per_shoe(D$new, CODES$new, PC$new)
stopifnot(identical(ps_o$shoe, shoes_o), all(ps_o$nc == 100), max(abs(ps_o$px - px_o)) == 0)
for (off in c(FALSE, TRUE)) {
  r <- mb[mb$offset == (if (off) "log((px - n)/100)" else "none") & mb$new == "NEW (all)", ]
  so_ <- t6_sigma2_moment(ps_o$n, ps_o$nc, ps_o$px, off)
  sn_ <- t6_sigma2_moment(ps_n$n, ps_n$nc, ps_n$px, off)
  stopifnot(nrow(r) == 1, abs(r$sigma2_old - so_) < 1e-12, abs(r$sigma2_new - sn_) < 1e-12)
}
stopifnot(abs(t6_sigma2_moment(ps_o$n, ps_o$nc, ps_o$px, FALSE) - 1.034) < 5e-4,
          abs(t6_sigma2_moment(ps_n$n, ps_n$nc, ps_n$px, FALSE) - 0.861) < 5e-4)
pass("sigma^2 moment estimator: = plan F82 (1.034 OLD, 0.861 NEW without offset); the bootstrap table's estimates recomputed")
# RAC matching: a synthetic shift and mirror, and three committed pairs recomputed
set.seed(13)
so <- data.frame(x = runif(40, -0.2, 0.2), y = runif(40, -0.45, 0.45))
# (noise 2e-4, radius 0.0012 below the grid step 0.0025: only the true shift
# matches every point)
sn <- rbind(data.frame(x = so$x[1:30] - 0.01 + rnorm(30, 0, 2e-4), y = so$y[1:30] + 0.02 + rnorm(30, 0, 2e-4)),
            data.frame(x = runif(5, -0.2, 0.2), y = runif(5, -0.45, 0.45)))
sg <- seq(-0.03, 0.03, by = 0.0025)
m1 <- t6_match_racs(so, sn, 0.0012, sg)
m2 <- t6_match_racs(so, transform(sn, x = -x), 0.0012, sg)
stopifnot(m1$mirror == 1, abs(m1$dx - 0.01) < 1e-9, abs(m1$dy + 0.02) < 1e-9, m2$mirror == -1,
          all(1:30 %in% m1$matched$j), all(m1$matched$i[m1$matched$j <= 30] == m1$matched$j[m1$matched$j <= 30]),
          identical(m1$matched$i, m2$matched$i), !anyDuplicated(m1$matched$i), !anyDuplicated(m1$matched$j),
          all(m1$matched$d < 0.0012))
mp <- read.csv(t6_compare_path(P_old, "csv", "rac_types_matched_pairs"))
mt <- read.csv(t6_compare_path(P_old, "csv", "rac_types_matched"))
LOC <- list(old = read_locations(P_old), new = read_locations(P_new))
px_unit <- P_old$prototype$coords$rel_col_shoe / P_old$prototype$coords$rel_Y_cord
for (k in c(1, round(nrow(mp) / 2), nrow(mp))) {
  o <- LOC$old[LOC$old$shoe == mp$old[k], ]
  n <- LOC$new[LOC$new$shoe == mp$new[k], ]
  m <- t6_match_racs(o, n, 0.008, seq(-0.03, 0.03, by = 1 / px_unit))
  stopifnot(nrow(m$matched) == mp$matched[k], m$mirror == mp$mirror[k], abs(m$dx - mp$dx[k]) < 1e-12,
            abs(m$dy - mp$dy[k]) < 1e-12,
            abs(mean(o$type[m$matched$i] == n$type[m$matched$j]) - mp$same_type[k]) < 1e-12)
}
stopifnot(sum(mt$racs) == sum(mp$matched))
pass(sprintf("RAC matching: a synthetic shift and mirror recovered; 3 of the %d same_shoe pairs recomputed; %d matched RACs",
             nrow(mp), sum(mt$racs)))
# the primary equality test (without reprints, shoe bootstrap) recomputed
rr <- readRDS(boots[grepl("/new/t6/NEW_X_NS_XY_oldbasis_norep_bootpirls_new", boots)])
f_norep <- readRDS(t6_fit_path(P_new, "NEW_X_NS_XY_oldbasis_norep"))
wr <- equality_wald(f_old$coef, f_norep$coef, Dd = t6_boot_pair(ro, rr, f_old, f_norep))
e3 <- eq[eq$primary, ]
stopifnot(nrow(e3) == 1, e3$comparison == "OLD vs NEW without reprints, OLD basis", e3$model == "GLMM",
          abs(e3$W - wr$W) < 1e-8 * wr$W, all(eq$samples[!grepl("without reprints", eq$comparison)] ==
                                               "shared soles ignored: conservative"))
pass(sprintf("primary equality test: GLMM without reprints, shoe bootstrap W %.3f (%s, p %.3g) recomputed", wr$W,
             wr$reference, wr$p))
# areas: the between-area ratio of the full tensors recomputed from their records
abs_ <- read.csv(t6_compare_path(P_old, "csv", "areas14_summary"))
am <- t6_area_of_grid(G, mirror = TRUE)
for (ds in c("old", "new")) {
  ff <- readRDS(t6_fit_path(if (ds == "old") P_old else P_new, "NEW_X_NS_XY_full"))
  lam <- exp(as.vector(cbind(1, t6_design(ff$spec, G$x[G$inside], G$y[G$inside])) %*% ff$coef))
  mu <- tapply(lam, am[G$inside], mean)
  row <- abs_[abs_$fit == paste("glmm_full", ds, sep = "_") & abs_$interval == "shoe bootstrap", ]
  stopifnot(nrow(row) == 1, abs(row$between - max(mu) / min(mu)) < 1e-9, row$draws == 1000,
            row$between_lo <= row$between, row$between_hi >= row$between)
}
stopifnot(all(c("glmm_old", "glmm_new_ob", "glmm_norep_new", "glmm_full_old", "glmm_full_new") %in%
                abs_$fit[abs_$interval == "shoe bootstrap"]))
pass(sprintf("areas: full-tensor between-area ratios recomputed from the records; bootstrap intervals for 5 fits (%.0f s for section 11)",
             proc.time()[["elapsed"]] - t11))

# --- 10. the fit runner covers every job of the fit script ------------------------------
old_wd <- setwd(root)
jobs_r <- system2("Rscript", c("tools/fit_compare_models.R", "--list"), stdout = TRUE)
runner <- system2("bash", c("tools/run_compare_fits.sh", "--dry-run", "--slow"), stdout = TRUE)
setwd(old_wd)
names_r <- sort(sub(" .*$", "", jobs_r))
stages <- strsplit(sub("^stage [0-9]+: ?", "", runner), " ", fixed = TRUE)
names_sh <- sort(unlist(stages))
stopifnot(length(runner) == 3, identical(names_r, names_sh), !anyDuplicated(names_sh),
          # what a stage-2 or stage-3 job reads comes from an earlier stage
          all(c("norep_glmm", "boot_old", "boot_new_ob", "offset_old", "offset_new", "full_old_glmm",
                "full_new_glmm") %in% stages[[1]]),
          all(c("boot_norep", "offset_norep", "profile_norep", "boot_full_old", "boot_full_new") %in% stages[[2]]),
          identical(stages[[3]], "profile_off_norep"))
pass(sprintf("fit runner: tools/run_compare_fits.sh runs each of the %d jobs of fit_compare_models.R --list once, in dependency order",
             length(names_r)))
cat(sprintf("ALL PASS test_compare_old_new (%.0f s)\n", proc.time()[["elapsed"]] - t_all))
