# Part 2 pixel tables and linear predictors (plan T7 step 2,
# test_validation_pixels).
#
# 1. For every shoe of both datasets: the step-1 contact surface S rebuilt
#    by part2_contacts() (raw records, erase list, flips, the stamp mask,
#    RAC pixels set to 1) has the pixel count of shoe_pixel_counts(_new).csv,
#    and its RAC counts sum to the shoe's RACs in the locations.
# 2. On a subset of shoes per dataset (OLD: the flipped shoe 9 and every
#    shoe with a step-2 row that has no contour point within 0.01 in y, the
#    min_dist fallback, plus 6 random shoes; NEW: every shoe of the erase
#    list with a fallback row, plus 6 random shoes), the full pixel table's
#    x, y, new_x and horiz_dist are identical() to the step-2 CSV on every
#    case-control row of those shoes, and the cases are its RAC pixels.
#    (The Rmd checks this for every row of both datasets.)
# 3. The design matrix of the step-3 basis on the OLD case-control rows
#    equals getME(model, "X") (max abs diff < 1e-12), X %*% fixef equals
#    predict(re.form = NA) (< 1e-10), and part2_eta() (the per-pixel x basis
#    times the per-row y basis) equals X %*% fixef (< 1e-12).
# 4. exp of the CML linear predictor by part2_eta() equals
#    exp(predict(cml, type = "lp", reference = "zero")) (relative < 1e-10).
# Writes only below tempdir().
#
# Run from anywhere:  Rscript tests/r/test_validation_pixels.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
suppressMessages({
  library(splines)
  library(lme4)
  library(survival)
  library(dplyr)
})
for (f in c("profile.R", "io.R", "distances.R", "compare.R", "validation.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
pass <- function(name) cat("PASS", name, "\n")
t_all <- proc.time()[["elapsed"]]

# the image row and column of a step-2 row (inverse of the pixel centre)
row_col <- function(d, P) {
  per_px <- P$coords$rel_Y_cord / P$coords$rel_col_shoe
  list(col = round(d$x / per_px + P$col_shoe / 2),
       row = round(-d$y / per_px + P$row_shoe / 2))
}

for (ds in c("old", "new")) {
  P <- rac_profile(ds, root = ROOT_PATH)
  # 1. S and RACs of every shoe
  ct <- part2_contacts(P)
  pc <- read.csv(rac_path(P, "pixel_counts"))
  s_cnt <- vapply(ct$S, sum, 0)
  n_cnt <- vapply(ct$N, sum, 0)
  stopifnot(identical(as.integer(pc$shoe), as.integer(ct$shoes)),
            identical(as.numeric(pc$pixel_count), as.numeric(s_cnt)),
            identical(as.integer(n_cnt), as.integer(ct$n_rac)),
            all(vapply(ct$S, function(s) all(s %in% c(0, 1)), TRUE)))
  pass(sprintf("%s: S of all %d shoes = step-1 pixel counts; RACs per shoe = locations (%d)",
               ds, length(ct$shoes), sum(n_cnt)))

  # 2. the full chain on a subset of shoes
  d <- read.csv(rac_path(P, "dataCC_distance"))
  cp <- part2_contour_points(P)
  near <- vapply(seq_len(nrow(d)), function(i) 0, 0)
  fb_codes <- integer(0)
  for (k in unique(d$shoe)) {
    rows <- which(d$shoe == k)
    yc <- unique(cp[[k]]$y)
    mind <- vapply(d$y[rows], function(v) min(abs(v - yc)), 0)
    if (any(!(mind < 0.01))) fb_codes <- c(fb_codes, k)
  }
  set.seed(if (ds == "old") 21 else 22)
  special <- if (ds == "old") {
    match(P$r$contact_flip_shoes, ct$shoes)
  } else {
    match(unique(rac_read_sticker_masks(P)$shoe), ct$shoes)
  }
  codes <- sort(unique(c(special, fb_codes,
                         sample(seq_along(ct$shoes), 6))))
  px <- part2_pixel_table(P, codes = codes)
  sel <- d$shoe %in% codes
  rc <- row_col(d[sel, ], P)
  key_p <- (px$code - 1) * P$col_shoe * P$row_shoe + (px$col - 1) * P$row_shoe +
    px$row
  key_d <- (d$shoe[sel] - 1) * P$col_shoe * P$row_shoe +
    (rc$col - 1) * P$row_shoe + rc$row
  m <- match(key_d, key_p)
  stopifnot(!anyNA(m), identical(px$x[m], d$x[sel]), identical(px$y[m], d$y[sel]),
            identical(px$new_x[m], d$new_x[sel]),
            identical(px$horiz_dist[m], d$horiz_dist[sel]),
            all((px$N[m] > 0) == (d$n_Acc[sel] == 1)),
            identical(as.numeric(tabulate(px$code, length(ct$shoes))[codes]),
                      as.numeric(pc$pixel_count[codes])))
  pass(sprintf(paste("%s: pixel table of %d shoes (incl. %s; min_dist fallback",
                     "shoes %s): x, y, new_x, horiz_dist identical() to the",
                     "step-2 CSV on %d rows; %d fallback pixels"),
               ds, length(codes), paste(ct$shoes[special], collapse = ","),
               paste(ct$shoes[fb_codes], collapse = ","), sum(sel),
               sum(px$fallback)))
}

# 3-4. design matrix and linear predictors on the OLD case-control rows
P <- rac_profile("old", root = ROOT_PATH)
glmm <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
cml <- readRDS(rac_model_path(P, "CML_MODEL"))
basis <- part2_basis(glmm)
d <- read.csv(rac_path(P, "dataCC_distance"))
X <- part2_design(d$new_x, d$y, basis)
Xm <- as.matrix(getME(glmm, "X"))
dimnames(Xm) <- NULL
lp <- as.vector(X %*% fixef(glmm))
stopifnot(identical(dim(X), dim(Xm)), max(abs(X - Xm)) < 1e-12,
          max(abs(lp - predict(glmm, re.form = NA, type = "link"))) < 1e-10)
rc <- row_col(d, P)
y_levels <- part2_round_trip(part2_coords(P)$y)
stopifnot(identical(y_levels[rc$row], d$y))
eta <- part2_eta(part2_bx(d$new_x, basis), part2_by(y_levels, basis), rc$row,
                 part2_coef_parts(fixef(glmm)))
stopifnot(max(abs(eta - lp)) < 1e-12)
pass(sprintf(paste("OLD design matrix = getME(X) (max %.1e); X beta = predict(re.form = NA)",
                   "(max %.1e); part2_eta = X beta (max %.1e)"),
             max(abs(X - Xm)), max(abs(lp - predict(glmm, re.form = NA))),
             max(abs(eta - lp))))
eta_c <- part2_eta(part2_bx(d$new_x, basis), part2_by(y_levels, basis), rc$row,
                   part2_coef_parts(coef(cml)))
ref <- exp(predict(cml, type = "lp", reference = "zero"))
stopifnot(max(abs(exp(eta_c) / ref - 1)) < 1e-10)
pass(sprintf("OLD CML: exp(part2_eta) = exp(predict(lp, reference = zero)) (max rel %.1e)",
             max(abs(exp(eta_c) / ref - 1))))
cat(sprintf("ALL PASS test_validation_pixels (%.0f s)\n",
            proc.time()[["elapsed"]] - t_all))
