# compare_old_new.R: the OLD-vs-NEW comparison helpers (plan T6; the T6
# task's statistical_model/compare_old_new_7.Rmd and
# tools/fit_compare_models.R use them). Sourced after profile.R and
# compare.R (T5: basis_knots, fit_common_basis, basis_of, spatial_term_key),
# which this file does not change.
#
# Names and paths (no literal output path, A-079; nothing in the profile
# file, which T6 does not edit):
#   t6_compare_path(P_old, kind, stem)  a file built from both datasets:
#       kind "csv" -> <processed_data>/compare/<stem>_old_vs_new.csv,
#       "pdf" -> <model_images>/compare/<stem>_old_vs_new.pdf,
#       "png" -> docs/qa/T6/<stem>_old_vs_new.png (plan section 5); the
#       folders come from the OLD profile's own paths
#   t6_fit_path(P, stem)  a T6 model fit of one dataset: OLD
#       saved_models/t6/<stem>.rds, NEW saved_models/new/t6/<stem>_new.rds
#       (user rule 1: a new folder and the _new suffix)
#   t6_new_output(path, force)  refuses to overwrite an existing T6 output
#       unless force is TRUE (as rac_new_output does for OLD, A-075); makes
#       the folder
# Shoe sets of NEW:
#   t6_reprint_ids(root)  NEW ids judged same_shoe or uncertain in the T0
#       visual review (docs/qa/T0/compare/overlap_verdicts_t0_old_vs_new.csv,
#       plan F25; T3's own screen is not done, so this is the list of D-012)
#   t6_group_a(id)  NEW group A of plan F79 (ids 1-343 and 442-490; a post
#       hoc split, descriptive only, A-120)
# Bases (new_x varying fastest in every interaction block, as step 3):
#   t6_spec(data, type)  type "K8" = the step-3 basis (3 quartile knots of
#       new_x, 5 sextile knots of y, boundary knots = the data range, the
#       interaction only: 24 columns, plan K8); "full" = the same knots, the
#       full tensor (main effects and interaction: 34); "fineY" = the
#       nested finer y basis of plan F84 (the 5 step-3 y knots plus the 10
#       quantiles 1:10/11 of y, 15 interior knots, the same boundary knots
#       and x knots, full tensor: 84), exactly as
#       docs/qa/T5/probes/t5_basis_y.R builds it
#   t6_design(spec, new_x, y)  the design matrix without intercept, columns
#       named x<j>:y<i> (and x<j>, y<i> for the full tensors); for K8 its
#       values are those of step 4's grid design, which builds the same
#       products with predict() of the same ns() bases
# Fits:
#   t6_fit(data, spec, feature, offset, nAGQ)  the GLMM (glmer, (1 | shoe),
#       step 3's nlminbwrap optimizer) or the exact CML (clogit,
#       strata(shoe)) on the design of spec
#   t6_offset_values(data, codes, pixel_counts)  per row
#       log((px - n) / 100): px = the step-1 contact pixels S of the row's
#       shoe, n its case pixels; minus the log of the control sampling
#       fraction 100 / (px - n) (plan F35, A-044)
#   fit_offset(data, codes, pixel_counts, feature)  the plan's interface: the
#       step-3 GLMM on the data's own step-3 basis with that offset (formula
#       of fit_common_basis, so basis_of() and spatial_term_key() read it);
#       its intercept is on the population scale, so a prediction from it
#       never adds MEAN_OFFSET (t6_eta refuses one); start (optional) as
#       glmer's, e.g. from t6_offset_start()
#   t6_summary(model, spec, label, data, seconds)  a compact record of a
#       fit: coefficients (keys of spatial_term_key, or the design's names),
#       vcov (GLMM: the RX-based one, A-055), sigma^2, loglik, convergence,
#       the shoes used, versions; what the Rmd needs, at a few kB
#   t6_from_model(model, label, data)  the same record of a committed
#       step-3 or OLD-basis model (its basis read back with basis_of())
# Maps and cuts (the prototype frame of steps 4-6, A-006):
#   t6_grid(P)  the prototype grid of step 4 (x varying fastest) and its mask
#   t6_eta(fit, spec, new_x, y, mean_offset = NULL)  the linear predictor
#       without shoe effect (CML: intercept 0); mean_offset is added for a
#       no-offset GLMM only
#   t6_step4_map(fit, spec, grid, mean_offset, sigma2, m_random)  step 4's
#       intensity matrix ("intens": -log(1 - p) x exp(-sigma^2 / 2), the CML
#       moved to the GLMM's mean m_random), NA outside the mask: the maps
#       as the pipeline draws them (their level depends on known issue K3)
#   t6_calibration(fit, spec, data, codes, pixel_counts)  the level that
#       makes the surface reproduce the dataset's observed RAC total: rows
#       weighted 1 (cases) and (px - n) / 100 (controls, a simple random
#       sample of the non-case contact pixels), c = N / sum(w exp(eta)), so
#       c exp(eta(x)) is the dataset-average RAC density per contact pixel
#       at x; independent of the intercept, MEAN_OFFSET and sigma^2 (K3)
#   t6_density(fit, spec, new_x, y, cal, se = TRUE)  that density and the
#       delta-method SE of its log: gradient X(x) - sum_r pi_r X_r with
#       pi_r = w_r exp(eta_r) / sum(w exp(eta)) (model-based V)
# Tests:
#   equality_wald(b1, b2, V1, V2, Dd, drop_intercept)  plan T6: model-based
#       W = d' (V1 + V2)^-1 d with chi^2_p; with Dd (B x p paired difference
#       draws, A-045) W = d' cov(Dd)^-1 d referred to F(p, B - p) through
#       W (B - p) / (p (B - 1))
# Checks added by the T6 review fixes:
#   t6_pinned_band(specs, new_x, y, width = 0.03)  TRUE within `width`
#       units of the K8-pinned edges of any step-3 basis in specs (new_x
#       near its left boundary knot, y near its heel boundary knot: plan K8
#       pins the step-3 log-odds to the intercept there, so map differences
#       there are not data); full and finer bases are not pinned
#   t6_per_shoe(data, codes, pixel_counts)  per shoe: cases n, controls nc,
#       contact pixels px (sorted by code)
#   t6_sigma2_moment(n, nc, px, offset)  the moment estimator of sigma^2 of
#       plan F82: var over shoes of m_i minus mean(1/n + 1/nc), the GLMM's
#       binomial sampling variance of a shoe's log-odds; m_i = log(n / nc)
#       without the offset (spread of RAC counts), log(n / (px - n)) with it
#       (spread of RAC density per contact pixel)
#   t6_shoe_regions(data, codes, pixel_counts, regions)  model-free: per
#       shoe the cases and the contact pixels the rows stand for (as in
#       t6_calibration) overall (all_*) and in each region (<region>_cases,
#       <region>_px); regions = named functions(data) -> logical per row
#   t6_region_density(tab, regions, counts)  the RAC density of each region
#       (cases / contact pixels) over the shoes weighted by `counts`
#       (B x shoes, e.g. how often each shoe is drawn by a whole-shoe
#       bootstrap; default: every shoe once); B x regions
#   t6_match_racs(o, n, radius, shifts, mirrors)  the RACs of two prints of
#       one sole matched by location: the NEW print (n: x, y) is moved by
#       every shift (dx, dy) in shifts x shifts and mirror, the move that
#       gives the most OLD RACs (o) a NEW RAC within `radius` wins (the
#       first in the order mirror, dx, dy on ties), and at that move RACs
#       are paired one to one, closest pair first, while closer than radius
# Naomi's 14 areas (2022 paper; naomikap/rac-intensity, "Organizing data to
# include subsets (larger areas).R", lines 28-117):
#   naomi_area(x, y)  the area of points given in the frame of the
#       locations file (x NOT mirrored)
#   t6_area_of_grid(grid, mirror = TRUE)  the area of each prototype pixel;
#       the dataCC frame mirrors x (plan F7: corr -0.99994), so the rule is
#       applied to -x; mirror = FALSE reproduces the meeting's script, which
#       applied it to x
#   t6_area_stats(value, area)  per area: pixels, mean, p10, p90, min, max

T6_SUFFIX <- "_old_vs_new"

t6_compare_path <- function(P_old, kind, stem) {
  if (!identical(P_old$dataset, "old")) {
    stop("t6_compare_path: pass the OLD profile", call. = FALSE)
  }
  folder <- switch(kind,
    csv = file.path(dirname(rac_path(P_old, "dataCC")), "compare"),
    pdf = paste(P_old$root, P_old$r$paths$images_dir, "/compare", sep = ""),
    png = paste(P_old$root, "docs/qa/T6", sep = ""),
    stop("t6_compare_path: kind must be csv, pdf or png", call. = FALSE))
  file.path(folder, paste(stem, T6_SUFFIX, ".", kind, sep = ""))
}

t6_fit_path <- function(P, stem) rac_model_path(P, paste("t6/", stem, sep = ""))

t6_new_output <- function(path, force = FALSE) {
  if (file.exists(path) && !isTRUE(force)) {
    stop("refusing to overwrite the T6 output ", path, " (pass force)",
         call. = FALSE)
  }
  rac_ensure_dir(path)
}

t6_reprint_ids <- function(root) {
  f <- file.path(root, "docs", "qa", "T0", "compare",
                 paste("overlap_verdicts_t0", T6_SUFFIX, ".csv", sep = ""))
  v <- utils::read.csv(f, stringsAsFactors = FALSE)
  stopifnot(all(c("new", "verdict") %in% names(v)), !anyDuplicated(v$new))
  sort(as.integer(v$new[v$verdict %in% c("same_shoe", "uncertain")]))
}

t6_group_a <- function(id) id <= 343 | (id >= 442 & id <= 490)

t6_spec <- function(data, type = c("K8", "full", "fineY")) {
  type <- match.arg(type)
  b <- basis_knots(data)
  if (type == "fineY") {
    b$knots_y <- sort(unique(c(b$knots_y,
                               as.numeric(stats::quantile(data$y,
                                                          1:10 / 11)))))
  }
  c(list(type = type), b)
}

t6_design <- function(spec, new_x, y) {
  plain <- function(m) matrix(as.numeric(m), nrow(m))
  bx <- plain(splines::ns(new_x, knots = spec$knots_x,
                          Boundary.knots = spec$bknots_x))
  by <- plain(splines::ns(y, knots = spec$knots_y,
                          Boundary.knots = spec$bknots_y))
  ix <- seq_len(ncol(bx))
  iy <- seq_len(ncol(by))
  inter <- do.call(cbind, lapply(iy, function(i) bx * by[, i]))
  colnames(inter) <- paste("x", rep(ix, length(iy)), ":y",
                           rep(iy, each = length(ix)), sep = "")
  if (identical(spec$type, "K8")) return(inter)
  colnames(bx) <- paste("x", ix, sep = "")
  colnames(by) <- paste("y", iy, sep = "")
  cbind(bx, by, inter)
}

t6_fit <- function(data, spec, feature, offset = NULL, nAGQ = 1L,
                   optimizer = "nlminbwrap", start = NULL) {
  dd <- data.frame(n_Acc = data$n_Acc, shoe = data$shoe)
  dd$X <- t6_design(spec, data$new_x, data$y)
  if (identical(feature, "NEW_X_NS_XY")) {
    if (is.null(offset)) {
      f <- n_Acc ~ X + (1 | shoe)
    } else {
      dd$off <- offset
      f <- n_Acc ~ X + (1 | shoe) + offset(off)
    }
    lme4::glmer(f, data = dd, family = stats::binomial(link = "logit"),
                control = lme4::glmerControl(optimizer = optimizer),
                nAGQ = nAGQ, start = start)
  } else if (identical(feature, "CML_MODEL")) {
    if (!is.null(offset)) stop("t6_fit: no offset for the CML", call. = FALSE)
    strata <- survival::strata
    survival::clogit(n_Acc ~ X + strata(shoe), data = dd, method = "exact")
  } else {
    stop("t6_fit: feature must be NEW_X_NS_XY or CML_MODEL", call. = FALSE)
  }
}

# px and n per row of data (codes: the step-1 shoe_codes table, code -> id)
t6_shoe_px <- function(data, codes, pixel_counts) {
  stopifnot(!anyDuplicated(codes$code), !anyDuplicated(pixel_counts$shoe),
            all(data$shoe %in% codes$code))
  id <- codes$shoe[match(data$shoe, codes$code)]
  px <- pixel_counts$pixel_count[match(id, pixel_counts$shoe)]
  n <- stats::ave(data$n_Acc, data$shoe, FUN = sum)
  if (anyNA(px) || any(px - n < 1)) {
    stop("t6_shoe_px: a shoe without a pixel count or without controls",
         call. = FALSE)
  }
  list(id = id, px = px, n = n)
}

t6_offset_values <- function(data, codes, pixel_counts) {
  s <- t6_shoe_px(data, codes, pixel_counts)
  n_ctrl <- stats::ave(1 - data$n_Acc, data$shoe, FUN = sum)
  log((s$px - s$n) / n_ctrl)
}

fit_offset <- function(data, codes, pixel_counts, feature = "NEW_X_NS_XY",
                       start = NULL) {
  if (!identical(feature, "NEW_X_NS_XY")) {
    stop("fit_offset: the offset refit is a GLMM (NEW_X_NS_XY); the CML ",
         "conditions the shoe level away", call. = FALSE)
  }
  if (any(c("bx", "by", "off") %in% names(data))) {
    stop("fit_offset: data has a column named bx, by or off", call. = FALSE)
  }
  b <- basis_knots(data)
  dat <- data
  shoe <- dat$shoe
  off <- t6_offset_values(data, codes, pixel_counts)
  bx <- splines::ns(dat$new_x, knots = b$knots_x, Boundary.knots = b$bknots_x)
  by <- splines::ns(dat$y, knots = b$knots_y, Boundary.knots = b$bknots_y)
  lme4::glmer(n_Acc ~ bx:by + (1 | shoe) + offset(off), data = dat,
              family = stats::binomial(link = "logit"),
              control = lme4::glmerControl(optimizer = "nlminbwrap"),
              start = start)
}

# Starting values for an offset refit from the no-offset fit `fit` (a
# t6_summary record): the spatial coefficients unchanged, the intercept moved
# by mean(-offset) over the shoes (plan F35: the refit's intercept is close
# to that), theta unchanged. Used only when glmer's own start fails (PIRLS
# step-halving), which happens on some small subsets.
t6_offset_start <- function(fit, offset, shoe) {
  b <- unname(fit$coef)
  b[1] <- b[1] - mean(tapply(offset, shoe, mean))
  list(theta = fit$theta, fixef = b)
}

t6_keys <- function(nm) {
  nm <- sub("^X", "", nm)
  ok <- grepl("^bx[0-9]+:by[0-9]+$", nm) |
    grepl("^ns\\(dat\\$new_x", nm)
  nm[ok] <- spatial_term_key(nm[ok])
  nm
}

t6_summary <- function(model, spec, label, data, seconds = NA_real_,
                       extra = list()) {
  if (inherits(model, "merMod")) {
    b <- lme4::fixef(model)
    V <- as.matrix(stats::vcov(model, use.hessian = FALSE))
    msgs <- model@optinfo$conv$lme4$messages
    vc <- lme4::VarCorr(model)$shoe
    out <- list(feature = "NEW_X_NS_XY",
                sigma2 = as.numeric(vc),
                # steps 4-6 square the stored standard deviation
                sigma2_step4 = as.numeric(attr(vc, "stddev"))^2,
                theta = as.numeric(lme4::getME(model, "theta")),
                loglik = as.numeric(stats::logLik(model)),
                conv = model@optinfo$conv$opt,
                messages = if (is.null(msgs)) character(0) else msgs,
                nAGQ = model@devcomp$dims[["nAGQ"]],
                vcov_method = "RX")
  } else if (inherits(model, "coxph")) {
    b <- stats::coef(model)
    V <- as.matrix(stats::vcov(model))
    out <- list(feature = "CML_MODEL", sigma2 = NA_real_,
                sigma2_step4 = NA_real_, theta = NA_real_,
                loglik = model$loglik[2], conv = 0L, messages = character(0),
                iter = model$iter, method = model$method,
                vcov_method = "model-based (inverse information)")
  } else {
    stop("t6_summary: unsupported model class ", class(model)[1],
         call. = FALSE)
  }
  if (anyNA(b)) stop("t6_summary: ", label, " has NA coefficients",
                     call. = FALSE)
  keys <- t6_keys(names(b))
  names(b) <- keys
  dimnames(V) <- list(keys, keys)
  c(list(label = label, spec = spec, coef = b, vcov = V,
         nobs = nrow(data), shoes = sort(unique(data$shoe)),
         n_cases = sum(data$n_Acc), seconds = seconds,
         versions = c(R = R.version.string,
                      lme4 = as.character(utils::packageVersion("lme4")),
                      survival = as.character(
                        utils::packageVersion("survival")))),
    out, extra)
}

t6_from_model <- function(model, label, data, spec_type = "K8") {
  b <- basis_of(model)
  t6_summary(model, c(list(type = spec_type), b), label, data)
}

t6_grid <- function(P) {
  pr <- P$prototype
  # the arithmetic of step 4 (shoe_std_results_4.Rmd), operation for
  # operation, so that the grid coordinates are bit-identical to step 4's
  xs <- (-pr$col_shoe / 2 + seq_len(pr$col_shoe)) * pr$coords$rel_Y_cord /
    pr$coords$rel_col_shoe
  ys <- -((-pr$row_shoe / 2 + seq_len(pr$row_shoe)) * pr$coords$rel_Y_cord /
            pr$coords$rel_col_shoe)
  xy <- expand.grid(x = xs, y = ys)
  mask <- t(as.matrix(imager::load.image(rac_path(P, "prototype_mask"))))
  stopifnot(nrow(mask) == pr$row_shoe, ncol(mask) == pr$col_shoe)
  list(x = xy$x, y = xy$y, inside = as.vector(t(mask)) != 0, mask = mask,
       xs = xs, ys = ys, ncol = pr$col_shoe, nrow = pr$row_shoe)
}

# a grid vector (x varying fastest) as the row x col matrix of step 4
t6_as_matrix <- function(v, grid) {
  matrix(v, grid$nrow, grid$ncol, byrow = TRUE)
}

t6_eta <- function(fit, spec, new_x, y, mean_offset = NULL) {
  X1 <- cbind(1, t6_design(spec, new_x, y))
  b <- fit$coef
  if (identical(fit$feature, "CML_MODEL")) {
    if (!is.null(mean_offset)) stop("t6_eta: no MEAN_OFFSET for the CML",
                                    call. = FALSE)
    return(as.vector(X1 %*% c(0, b)))
  }
  stopifnot(identical(names(b)[1], "(Intercept)"),
            length(b) == ncol(X1))
  if (!is.null(mean_offset) && isTRUE(fit$offset_refit)) {
    stop("t6_eta: an offset refit is on the population scale; never add ",
         "MEAN_OFFSET to it", call. = FALSE)
  }
  if (is.null(mean_offset)) as.vector(X1 %*% b) else
    as.vector(X1 %*% b + mean_offset)
}

t6_step4_map <- function(fit, spec, grid, mean_offset, sigma2,
                         m_random = NULL) {
  X1 <- cbind(1, t6_design(spec, grid$x, grid$y))
  out <- !grid$inside
  if (identical(fit$feature, "CML_MODEL")) {
    if (is.null(m_random)) stop("t6_step4_map: the CML map needs the ",
                                "GLMM's mean m_random", call. = FALSE)
    pred <- X1 %*% c(0, fit$coef)
    pred[out] <- NA
    pred <- pred - mean(pred, na.rm = TRUE) + m_random
  } else {
    pred <- X1 %*% fit$coef + mean_offset
    pred[out] <- NA
  }
  m <- matrix(pred, grid$nrow, grid$ncol, byrow = 1)
  prob <- exp(m) / (1 + exp(m))
  -log(1 - prob) * exp(-sigma2 / 2)
}

# the GLMM's mean log-odds over the mask (step 4's m)
t6_m_random <- function(fit, spec, grid, mean_offset) {
  X1 <- cbind(1, t6_design(spec, grid$x, grid$y))
  pred <- X1 %*% fit$coef + mean_offset
  pred[!grid$inside] <- NA
  mean(pred, na.rm = TRUE)
}

t6_calibration <- function(fit, spec, data, codes, pixel_counts) {
  keep <- data$shoe %in% fit$shoes
  d <- data[keep, ]
  stopifnot(nrow(d) == fit$nobs)
  s <- t6_shoe_px(d, codes, pixel_counts)
  n_ctrl <- stats::ave(1 - d$n_Acc, d$shoe, FUN = sum)
  w <- ifelse(d$n_Acc == 1, 1, (s$px - s$n) / n_ctrl)
  X1 <- cbind(1, t6_design(spec, d$new_x, d$y))
  b <- if (identical(fit$feature, "CML_MODEL")) c(0, fit$coef) else fit$coef
  eta <- as.vector(X1 %*% b)
  a <- max(eta)
  ew <- w * exp(eta - a)
  pi <- ew / sum(ew)
  N <- sum(d$n_Acc)
  list(log_c = log(N) - a - log(sum(ew)), N = N,
       contact_px = sum(w), xbar = colSums(X1 * pi),
       observed_density = N / sum(w))
}

t6_density <- function(fit, spec, new_x, y, cal, se = TRUE) {
  X1 <- cbind(1, t6_design(spec, new_x, y))
  if (identical(fit$feature, "CML_MODEL")) {
    eta <- as.vector(X1 %*% c(0, fit$coef))
  } else {
    eta <- as.vector(X1 %*% fit$coef)
  }
  out <- list(density = exp(eta + cal$log_c))
  if (se) {
    G <- sweep(X1, 2, cal$xbar)
    if (identical(fit$feature, "CML_MODEL")) G <- G[, -1, drop = FALSE]
    out$se_log <- sqrt(pmax(rowSums((G %*% fit$vcov) * G), 0))
  }
  out
}

equality_wald <- function(b1, b2, V1 = NULL, V2 = NULL, Dd = NULL,
                          drop_intercept = TRUE) {
  stopifnot(length(b1) == length(b2))
  if (!is.null(names(b1)) && !is.null(names(b2))) {
    stopifnot(identical(names(b1), names(b2)))
  }
  keep <- seq_along(b1)
  if (drop_intercept && !is.null(names(b1))) {
    keep <- which(names(b1) != "(Intercept)")
  }
  d <- as.numeric(b1[keep] - b2[keep])
  p <- length(d)
  if (is.null(Dd)) {
    stopifnot(!is.null(V1), !is.null(V2))
    V <- as.matrix(V1)[keep, keep] + as.matrix(V2)[keep, keep]
    W <- as.numeric(crossprod(d, solve(V, d)))
    return(list(W = W, df = p, p = stats::pchisq(W, p, lower.tail = FALSE),
                reference = "chi2"))
  }
  Dd <- as.matrix(Dd)
  if (ncol(Dd) != p) Dd <- Dd[, keep, drop = FALSE]
  B <- nrow(Dd)
  if (B <= p + 1) stop("equality_wald: need more than p + 1 draws",
                       call. = FALSE)
  W <- as.numeric(crossprod(d, solve(stats::cov(Dd), d)))
  Fs <- W * (B - p) / (p * (B - 1))
  list(W = W, df = p, p = stats::pf(Fs, p, B - p, lower.tail = FALSE),
       reference = sprintf("F(%d, %d)", p, B - p), F = Fs, B = B)
}

# Shoe bootstrap of a GLMM by the PIRLS surrogate (the device of T7's
# tools/part2_old_draws.R, written here independently): the fixed effects of
# a resample refitted at the fit's variance parameter theta by lme4's
# nAGQ = 0 deviance function (PIRLS for beta and the shoe effects jointly,
# about 1-3 s instead of 250-600 s for a Laplace refit). A draw is centred
# on the fit: beta*_b = beta_hat + (beta_pirls(resample b) -
# beta_pirls(all shoes)), so the surrogate's own level difference cancels
# and the resampling variation is kept. A shoe drawn twice is two groups.
T6_SEEDS <- list(boot_old = 20261107L, boot_new = 20261108L,
                 boot_norep = 20261109L, laplace_check = 20261110L,
                 # T6 review fixes: the full-tensor bootstraps (Naomi's
                 # areas without K8) and the Rmd's model-free bootstraps
                 boot_full_old = 20261111L, boot_full_new = 20261112L,
                 regions = 20261113L, sigma_moment = 20261114L)

t6_pirls_beta <- function(data, spec, theta) {
  dd <- data.frame(n_Acc = data$n_Acc, shoe = factor(data$shoe))
  dd$X <- t6_design(spec, data$new_x, data$y)
  glmod <- lme4::glFormula(n_Acc ~ X + (1 | shoe), data = dd,
                           family = stats::binomial(link = "logit"))
  devfun <- do.call(lme4::mkGlmerDevfun, c(glmod, list(nAGQ = 0)))
  devfun(theta)
  beta <- environment(devfun)$pp$beta(1)
  names(beta) <- t6_keys(colnames(glmod$X))
  beta
}

t6_resample <- function(data, ids) {
  rows <- split(seq_len(nrow(data)), data$shoe)
  sel <- rows[as.character(ids)]
  if (any(vapply(sel, is.null, TRUE))) {
    stop("t6_resample: a drawn shoe is not in the data", call. = FALSE)
  }
  out <- data[unlist(sel, use.names = FALSE), , drop = FALSE]
  out$shoe <- rep(seq_along(ids), lengths(sel))
  out
}

# Using the bootstrap records (tools/fit_compare_models.R boot_* jobs):
#   t6_boot_draws(rec, fit)  the draws matrix (B x p, failed draws already
#       left out by the job), checked against the fit it belongs to (same
#       coefficient keys, centred on the fit's coefficients)
#   t6_boot_pair(rec_a, rec_b, fit_a, fit_b)  the paired difference draws
#       a - b of the spatial coefficients (draw k of one with draw k of the
#       other; the two bootstraps resample their datasets independently, so
#       pairing by index is a random pairing), B = the smaller number of
#       draws (plan T6, A-045). The test then takes Var(b_a - b_b) as
#       V_a + V_b, i.e. the datasets as independent samples. That holds for
#       OLD vs NEW without the reprinted shoes; with them (67 NEW shoes are
#       prints of OLD soles, plan F25) Cov(b_old, b_new) > 0, V_a + V_b
#       overstates Var(b_old - b_new) and the test is conservative (T6
#       review fixes)
#   t6_wald_boot(b, draws)  the all-spatial Wald b' cov(draws)^-1 b with the
#       Hotelling reference F(p, B - p) (plan F36), via equality_wald
#   t6_cal_rows(fit, data, codes, pixel_counts)  the rows and weights of
#       t6_calibration (cases weight 1, controls (px - n) / n_ctrl), the
#       rows' shoes (a factor over the fit's shoes) and per shoe its cases
#       n_shoe and its contact pixels w_shoe (the sum of its weights)
#   t6_boot_ids(rec)  the resampled shoe codes of the draws (B x shoes,
#       failed draws left out, as in rec$draws)
#   t6_boot_counts(ids, shoes)  B x shoes: how often each shoe is drawn
#   t6_logdens_boot(fit, rows, draws, new_x, y, ids, kinds, chunk,
#       quantiles)  the bootstrap SD (over the draws) of the log calibrated
#       density at (new_x, y), for each of `kinds` (T6 review fixes):
#       "fixed"      each draw calibrated on the dataset's own rows and RAC
#                    total N, as t6_calibration does: the level held fixed,
#                    so this is the SD of the shape (the density relative to
#                    the dataset's average, its contact pixels fixed)
#       "resampled"  each draw calibrated on its own resampled shoes (their
#                    rows and their RAC total N*_b): the SD of the absolute
#                    density, level and shape; for statements about levels
#       "shape"      each draw divided by its own resampled observed density
#                    N*_b / S*_b (S = contact pixels): the SD of the log of
#                    density / observed density, with the normalisation
#                    resampled too; for statements about shape
#       ("resampled" and "shape" need ids); with quantiles = TRUE also the
#       2.5% and 97.5% quantiles of each (for "shape" of log(density /
#       observed density))
#   t6_logdens_sd(fit, rows, draws, new_x, y, chunk, quantiles)  the
#       "fixed" level of t6_logdens_boot (the interface the Rmd used first)
t6_boot_draws <- function(rec, fit) {
  d <- rec$draws
  if (!is.matrix(d) || anyNA(d) || !identical(colnames(d), names(fit$coef))) {
    stop("t6_boot_draws: the draws do not match the fit's coefficients",
         call. = FALSE)
  }
  if (max(abs(rec$coef - fit$coef)) > 1e-10) {
    stop("t6_boot_draws: the bootstrap was centred on another fit",
         call. = FALSE)
  }
  d
}

t6_boot_pair <- function(rec_a, rec_b, fit_a, fit_b) {
  da <- t6_boot_draws(rec_a, fit_a)
  db <- t6_boot_draws(rec_b, fit_b)
  stopifnot(identical(colnames(da), colnames(db)))
  B <- min(nrow(da), nrow(db))
  keep <- colnames(da) != "(Intercept)"
  da[seq_len(B), keep, drop = FALSE] - db[seq_len(B), keep, drop = FALSE]
}

t6_wald_boot <- function(b, draws) {
  keep <- names(b) != "(Intercept)"
  equality_wald(b[keep], 0 * b[keep], Dd = draws[, names(b)[keep], drop = FALSE],
                drop_intercept = FALSE)
}

t6_cal_rows <- function(fit, data, codes, pixel_counts) {
  d <- data[data$shoe %in% fit$shoes, ]
  stopifnot(nrow(d) == fit$nobs)
  s <- t6_shoe_px(d, codes, pixel_counts)
  n_ctrl <- stats::ave(1 - d$n_Acc, d$shoe, FUN = sum)
  w <- ifelse(d$n_Acc == 1, 1, (s$px - s$n) / n_ctrl)
  shoe <- factor(d$shoe, levels = sort(unique(d$shoe)))
  list(X1 = cbind(1, t6_design(fit$spec, d$new_x, d$y)), w = w,
       N = sum(d$n_Acc), shoe = shoe,
       n_shoe = as.vector(rowsum(d$n_Acc, as.integer(shoe))),
       w_shoe = as.vector(rowsum(w, as.integer(shoe))))
}

t6_boot_ids <- function(rec) {
  ids <- rec$ids
  if (length(rec$failed)) ids <- ids[-rec$failed, , drop = FALSE]
  if (!is.matrix(ids) || nrow(ids) != nrow(rec$draws)) {
    stop("t6_boot_ids: the ids do not match the draws", call. = FALSE)
  }
  ids
}

t6_boot_counts <- function(ids, shoes) {
  m <- match(ids, as.numeric(as.character(shoes)))
  if (anyNA(m)) {
    stop("t6_boot_counts: a drawn shoe is not one of the fit's shoes",
         call. = FALSE)
  }
  m <- matrix(m, nrow(ids))
  K <- length(shoes)
  t(apply(m, 1, tabulate, nbins = K))
}

t6_logdens_boot <- function(fit, rows, draws, new_x, y, ids = NULL,
                            kinds = "fixed", chunk = 100L,
                            quantiles = FALSE) {
  kinds <- unique(kinds)
  stopifnot(length(kinds) >= 1,
            all(kinds %in% c("fixed", "resampled", "shape")))
  Xp <- cbind(1, t6_design(fit$spec, new_x, y))
  if (identical(fit$feature, "CML_MODEL")) {
    stop("t6_logdens_boot: the bootstrap draws are of a GLMM", call. = FALSE)
  }
  stopifnot(ncol(draws) == ncol(Xp), ncol(rows$X1) == ncol(Xp))
  B <- nrow(draws)
  if (any(kinds != "fixed")) {
    if (is.null(ids) || nrow(ids) != B) {
      stop("t6_logdens_boot: the kinds resampled and shape need the ",
           "resampled shoe ids of every draw", call. = FALSE)
    }
    cnt <- t6_boot_counts(ids, levels(rows$shoe))
    sg <- as.integer(rows$shoe)
  }
  acc <- lapply(stats::setNames(kinds, kinds), function(l) {
    list(s1 = numeric(nrow(Xp)), s2 = numeric(nrow(Xp)),
         all = if (quantiles) matrix(NA_real_, nrow(Xp), B) else NULL)
  })
  for (st in seq(1L, B, by = chunk)) {
    k <- st:min(B, st + chunk - 1L)
    Bk <- t(draws[k, , drop = FALSE])
    eta_r <- rows$X1 %*% Bk
    a <- apply(eta_r, 2, max)
    ew <- rows$w * exp(sweep(eta_r, 2, a))
    lp <- Xp %*% Bk
    if (any(kinds != "fixed")) {
      E <- rowsum(ew, sg)                    # shoes x draws of the chunk
      Ck <- cnt[k, , drop = FALSE]           # draws x shoes
      den <- rowSums(Ck * t(E))
    }
    for (l in kinds) {
      log_c <- switch(l,
        fixed = log(rows$N) - a - log(colSums(ew)),
        resampled = log(as.vector(Ck %*% rows$n_shoe)) - a - log(den),
        shape = log(as.vector(Ck %*% rows$w_shoe)) - a - log(den))
      ld <- sweep(lp, 2, log_c, "+")
      acc[[l]]$s1 <- acc[[l]]$s1 + rowSums(ld)
      acc[[l]]$s2 <- acc[[l]]$s2 + rowSums(ld^2)
      if (quantiles) acc[[l]]$all[, k] <- ld
    }
  }
  out <- lapply(acc, function(z) {
    r <- list(sd = sqrt(pmax(z$s2 / B - (z$s1 / B)^2, 0) * B / (B - 1)),
              B = B)
    if (quantiles) {
      r$q_lo <- apply(z$all, 1, stats::quantile, 0.025, names = FALSE)
      r$q_hi <- apply(z$all, 1, stats::quantile, 0.975, names = FALSE)
    }
    r
  })
  out
}

t6_logdens_sd <- function(fit, rows, draws, new_x, y, chunk = 100L,
                          quantiles = FALSE) {
  t6_logdens_boot(fit, rows, draws, new_x, y, kinds = "fixed",
                  chunk = chunk, quantiles = quantiles)$fixed
}

t6_pinned_band <- function(specs, new_x, y, width = 0.03) {
  band <- rep(FALSE, length(new_x))
  for (s in specs) {
    if (!identical(s$type, "K8")) next
    band <- band | new_x < s$bknots_x[1] + width | y < s$bknots_y[1] + width
  }
  band
}

t6_per_shoe <- function(data, codes, pixel_counts) {
  s <- t6_shoe_px(data, codes, pixel_counts)
  sh <- factor(data$shoe, levels = sort(unique(data$shoe)))
  data.frame(shoe = as.numeric(levels(sh)),
             n = as.vector(tapply(data$n_Acc, sh, sum)),
             nc = as.vector(tapply(1 - data$n_Acc, sh, sum)),
             px = as.vector(tapply(s$px, sh, function(v) v[1])))
}

t6_sigma2_moment <- function(n, nc, px, offset) {
  m <- if (offset) log(n / (px - n)) else log(n / nc)
  stats::var(m) - mean(1 / n + 1 / nc)
}

t6_shoe_regions <- function(data, codes, pixel_counts, regions) {
  s <- t6_shoe_px(data, codes, pixel_counts)
  n_ctrl <- stats::ave(1 - data$n_Acc, data$shoe, FUN = sum)
  w <- ifelse(data$n_Acc == 1, 1, (s$px - s$n) / n_ctrl)
  sh <- factor(data$shoe, levels = sort(unique(data$shoe)))
  out <- data.frame(shoe = as.numeric(levels(sh)),
                    all_cases = as.vector(tapply(data$n_Acc, sh, sum)),
                    all_px = as.vector(tapply(w, sh, sum)))
  for (r in names(regions)) {
    k <- regions[[r]](data)
    stopifnot(is.logical(k), length(k) == nrow(data), !anyNA(k))
    out[[paste(r, "_cases", sep = "")]] <- as.vector(tapply(data$n_Acc * k, sh, sum))
    out[[paste(r, "_px", sep = "")]] <- as.vector(tapply(w * k, sh, sum))
  }
  out
}

t6_region_density <- function(tab, regions, counts = NULL) {
  if (is.null(counts)) counts <- matrix(1, 1, nrow(tab))
  stopifnot(ncol(counts) == nrow(tab))
  out <- vapply(regions, function(r) {
    as.vector(counts %*% tab[[paste(r, "_cases", sep = "")]]) /
      as.vector(counts %*% tab[[paste(r, "_px", sep = "")]])
  }, numeric(nrow(counts)))
  matrix(out, nrow(counts), length(regions), dimnames = list(NULL, regions))
}

t6_match_racs <- function(o, n, radius, shifts, mirrors = c(1, -1)) {
  r2 <- radius^2
  best <- list(score = -1)
  for (mir in mirrors) {
    DX <- outer(o$x, mir * n$x, "-")
    DY <- outer(o$y, n$y, "-")
    for (dx in shifts) {
      EX <- (DX - dx)^2
      for (dy in shifts) {
        score <- sum(rowSums(EX + (DY - dy)^2 < r2) > 0)
        if (score > best$score) {
          best <- list(score = score, mirror = mir, dx = dx, dy = dy)
        }
      }
    }
  }
  nx <- best$mirror * n$x + best$dx
  ny <- n$y + best$dy
  Dm <- outer(o$x, nx, "-")^2 + outer(o$y, ny, "-")^2
  pairs <- matrix(integer(0), 0, 2)
  dist <- numeric(0)
  while (length(Dm) && min(Dm) < r2) {
    w <- which(Dm == min(Dm), arr.ind = TRUE)[1, ]
    pairs <- rbind(pairs, c(w[[1]], w[[2]]))
    dist <- c(dist, sqrt(Dm[w[[1]], w[[2]]]))
    Dm[w[[1]], ] <- Inf
    Dm[, w[[2]]] <- Inf
  }
  c(best, list(matched = data.frame(i = pairs[, 1], j = pairs[, 2], d = dist)))
}

naomi_area <- function(x, y) {
  band <- cut(y, c(-Inf, -0.35, -0.15, 0, 0.15, Inf), right = FALSE,
              labels = FALSE)
  a <- ifelse(x < 0, band, 11 - band)
  a[a == 4 & y > 12 * (x + 0.02)^2 - 0.07] <- 11
  a[a == 5 & y < -12 * (x + 0.01)^2 + 0.4] <- 12
  a[a == 6 & y < -20 * (x + 0.01)^2 + 0.4] <- 13
  a[a == 7 & y > 16 * (x + 0.02)^2 - 0.07] <- 14
  as.integer(a)
}

t6_area_of_grid <- function(grid, mirror = TRUE) {
  naomi_area(if (mirror) -grid$x else grid$x, grid$y)
}

t6_area_stats <- function(value, area) {
  ok <- !is.na(value) & !is.na(area)
  do.call(rbind, lapply(sort(unique(area[ok])), function(k) {
    v <- value[ok & area == k]
    q <- stats::quantile(v, c(0.1, 0.9), names = FALSE)
    data.frame(area = k, pixels = length(v), mean = mean(v), p10 = q[1],
               p90 = q[2], min = min(v), max = max(v),
               ratio_p90_p10 = q[2] / q[1], ratio_max_min = max(v) / min(v))
  }))
}
