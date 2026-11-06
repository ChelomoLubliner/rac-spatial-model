# t5_gof.R: goodness of fit of the step-3 GLMM on both datasets, and the NEW
# heel-front band (T5 review fixes; the statistics reviewer's major
# finding 1; decision A-114).
#
# O/E = observed cases / expected cases in a region of the standardized shoe
# (new_x, y), expected = the sum of the GLMM's fitted probabilities with each
# shoe's BLUP (fitted(), the conditional fit) over the case-control rows of
# the region. The BLUP absorbs each shoe's level, so O/E measures the shape
# of the fixed surface. z = (O - E) / sqrt(sum mu (1 - mu)): binomial, it
# ignores the estimation error of the fit and any dependence between RACs,
# so it is descriptive (a |z| of 3 is not a test at 0.003).
#   A. cells of 0.04 (new_x) x 0.08 (y), the statistics reviewer's grid
#      (new_x breaks -0.20, -0.16, ..., 0.24; y breaks -0.52, ..., 0.52),
#      cells with E >= 15: count, |z| > 3, |z| > 2, sum z^2, the cells with
#      |z| > 3; every cell is written to
#      COMPARE_DIR/residual_cells_old_vs_new.csv
#   B. y profile: 0.02-wide bins of y from -0.36 to 0
#   C. the local maxima of the step-4 map surface (the fixed effects on the
#      prototype grid inside the prototype mask, 31 x 31 px window), with
#      O/E within +-0.025 in new_x and strictly within 0.04 in y (+-11 px)
#      around each, and the raw case/control ratio there against the
#      dataset's
#   D. the step-5 CI cuts (rows 110, 190, 250 of the prototype frame,
#      y = (197.5 - row) / 300): O/E within +-0.02 of y (+-6 px, both edge
#      rows included), pooled and per 0.04-wide new_x bin; and at the cut
#      curve's right-half maximum (within +-0.02 in new_x), with the
#      relative half-width of step 5's model-based Random band there
# (The y lattice of both datasets is (k + 0.5) / 300, so rows lie exactly on
# the edges of the +-0.02 and +-0.04 windows: the 1e-9 tolerances make the
# inclusion explicit instead of leaving it to the rounding of y.)
#   E. NEW only: O/E in y (-0.16, -0.10] per block of 49 shoe ids; group A
#      = ids 1-343 and 442-490 (found from this table post hoc by the
#      statistics reviewer), group B = the others; per group in the band
#      y (-0.18, -0.10]: cases, controls, case/control ratio against the
#      group's own, O/E, z, shoes with a control and with a case there;
#      then the contact surface S itself, pixel by pixel (raw records, erase
#      list, flips, all_cont mask, RAC pixels, as step 1 builds S): S px and
#      RAC px in the band per group, shoes with S in the band
#   F. the same_shoe reprints of T0 (docs/qa/T0/compare/
#      overlap_verdicts_t0_old_vs_new.csv): RAC px and S px in the band on
#      the NEW prints and on the OLD prints of the same soles, by group; the
#      registration of each pair in y (the mode of the RAC-to-RAC
#      differences, so that the band is the same place on both prints)
#   G. A by group (NEW group A, NEW group B)
#   H. does a richer basis remove the misfit? Efron CML on the step-3 basis
#      (K8), the full tensor (main effects and interaction), and the full
#      tensor with 5 and 9 interior knots; expected count of a row =
#      n_i w_row / sum of w over shoe i's rows; sum z^2 and |z| > 3 over the
#      E >= 15 cells, O/E in the window of C's maximum inside the band
#
# Reads committed files only; writes only COMPARE_DIR/residual_cells_old_vs_new.csv.
# Usage (repo root): Rscript docs/qa/T5/probes/t5_gof.R COMPARE_DIR
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1)
suppressMessages({
  library(splines)
  library(lme4)
  library(survival)
})
root <- normalizePath(".")
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "io.R", "compare.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
source(file.path(root, "tests", "lib", "rmd_chunk.R"))
t_start <- proc.time()[["elapsed"]]

xb <- seq(-0.20, 0.24, by = 0.04)
yb <- seq(-0.52, 0.52, by = 0.08)
oe <- function(s, mu = s$mu) {
  O <- sum(s$n_Acc)
  E <- sum(mu)
  c(rows = nrow(s), O = O, ctrl = sum(s$n_Acc == 0), E = E, OE = O / E,
    z = (O - E) / sqrt(sum(mu * (1 - mu))))
}
cells <- function(d, mu = d$mu) {
  key <- interaction(cut(d$new_x, xb), cut(d$y, yb), sep = "|", drop = TRUE)
  idx <- split(seq_len(nrow(d)), key)
  out <- do.call(rbind, lapply(names(idx), function(k) {
    i <- idx[[k]]
    data.frame(cell = k, t(oe(d[i, ], mu[i])))
  }))
  parts <- do.call(rbind, strsplit(out$cell, "|", fixed = TRUE))
  data.frame(new_x = parts[, 1], y = parts[, 2], out[, -1])
}
summ <- function(tb, label) {
  t15 <- tb[tb$E >= 15, ]
  cat(sprintf(paste("%s: %d cells with E >= 15 (%d rows of %d in the grid);",
                    "|z| > 3: %d, |z| > 2: %d, sum z^2 %.0f\n"),
              label, nrow(t15), sum(t15$rows), sum(tb$rows),
              sum(abs(t15$z) > 3), sum(abs(t15$z) > 2), sum(t15$z^2)))
  invisible(t15)
}
fmt_cells <- function(t15) {
  b <- t15[abs(t15$z) > 3, ]
  b <- b[order(b$z), ]
  if (!nrow(b)) return(invisible(NULL))
  print(data.frame(new_x = b$new_x, y = b$y, O = b$O,
                   E = sprintf("%.1f", b$E), OE = sprintf("%.2f", b$OE),
                   z = sprintf("%.2f", b$z)), row.names = FALSE)
}
# the S (contact surface) of every analysis shoe, step 1's construction
contact_surfaces <- function(P) {
  W <- P$col_shoe
  H <- P$row_shoe
  con <- file(rac_path(P, "contacts"), "rb")
  bytes <- readBin(con, "raw", P$num_shoe * (W * H + 2))
  close(con)
  raw <- lapply(seq_len(P$num_shoe), function(i) {
    matrix(bytes[(i - 1) * (W * H + 2) + seq_len(W * H)] == as.raw(49), H, W,
           byrow = TRUE)
  })
  sm <- rac_read_sticker_masks(P)
  if (!is.null(sm)) raw <- rac_apply_sticker_masks(raw, sm)
  for (i in P$r$contact_flip_shoes) raw[[i]] <- raw[[i]][, W:1]
  mask <- as.matrix(read.csv(rac_path(P, "all_cont"), header = TRUE)) == 1
  env <- new.env()
  env$P <- P
  eval(parse(text = rmd_chunk(file.path(root, "statistical_model",
                                        "dataCC_1.Rmd"), "2.init_functions")),
       envir = env)
  loc <- read_locations(P)
  rr <- env$aspix_y(loc$y)
  rc <- env$aspix_x(loc$x)
  shoes <- rac_analysis_shoes(P)
  pc <- read.csv(rac_path(P, "pixel_counts"), header = TRUE)
  out <- lapply(seq_along(shoes), function(k) {
    s <- shoes[k]
    rac <- matrix(FALSE, H, W)
    sel <- loc$shoe == s
    rac[cbind(rr[sel], rc[sel])] <- TRUE
    list(S = (raw[[s]] & mask) | rac, rac = rac)
  })
  stopifnot(identical(vapply(out, function(o) sum(o$S), 1),
                      as.numeric(pc$pixel_count)))
  out
}
band_rows <- function(P, lo, hi) {
  y <- (P$row_shoe / 2 - seq_len(P$row_shoe)) * P$coords$rel_Y_cord /
    P$coords$rel_col_shoe
  which(y > lo & y <= hi)
}

dat <- list()
glmm <- list()
prof <- list()
for (ds in c("old", "new")) {
  P <- rac_profile(ds, root = ROOT_PATH)
  g <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
  d <- read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
  stopifnot(nobs(g) == nrow(d),
            identical(as.numeric(getME(g, "y")), as.numeric(d$n_Acc)))
  d$mu <- as.numeric(fitted(g))
  dat[[ds]] <- d
  glmm[[ds]] <- g
  prof[[ds]] <- P
}

cat("== A. cells of 0.04 (new_x) x 0.08 (y), GLMM fitted with BLUPs\n")
all_cells <- list()
for (ds in c("old", "new")) {
  d <- dat[[ds]]
  out_grid <- sum(is.na(cut(d$new_x, xb)) | is.na(cut(d$y, yb)))
  tb <- cells(d)
  all_cells[[ds]] <- data.frame(dataset = ds, tb)
  t15 <- summ(tb, ds)
  cat(sprintf("   rows outside the grid: %d (%d cases)\n", out_grid,
              sum(d$n_Acc[is.na(cut(d$new_x, xb)) | is.na(cut(d$y, yb))])))
  fmt_cells(t15)
}
res_csv <- file.path(args[1], "residual_cells_old_vs_new.csv")
tab <- do.call(rbind, all_cells)
tab$E <- round(tab$E, 3)
tab$OE <- round(tab$OE, 4)
tab$z <- round(tab$z, 3)
write.csv(tab, res_csv, row.names = FALSE)
cat("written", res_csv, "\n")
t15n <- all_cells$new[all_cells$new$E >= 15, ]
inband <- t15n[t15n$y == "(-0.2,-0.12]", ]
cat(sprintf(paste("NEW cells with E >= 15 in y (-0.20, -0.12]: %d, O/E %.2f",
                  "to %.2f, z %.1f to %.1f\n"), nrow(inband), min(inband$OE),
            max(inband$OE), min(inband$z), max(inband$z)))

cat("\n== B. y profile (0.02 bins), GLMM fitted with BLUPs\n")
for (ds in c("old", "new")) {
  d <- dat[[ds]]
  tot <- sum(d$n_Acc) / sum(d$n_Acc == 0)
  cat(sprintf("%s (overall case/control %.3f)\n%-16s %6s %6s %7s %6s %6s %6s\n",
              ds, tot, "y", "ctrl", "cases", "ratio", "O/E", "z",
              "shoes"))
  yb2 <- cut(d$y, seq(-0.36, 0, by = 0.02))
  for (b in levels(yb2)) {
    s <- d[!is.na(yb2) & yb2 == b, ]
    r <- oe(s)
    cat(sprintf("%-16s %6d %6d %7.3f %6.3f %6.2f %6d\n", b, r[["ctrl"]],
                r[["O"]], r[["O"]] / r[["ctrl"]], r[["OE"]], r[["z"]],
                length(unique(s$shoe[s$n_Acc == 1]))))
  }
}

cat("\n== C. local maxima of the step-4 map surface (31 x 31 px window)\n")
P <- prof$old
mask <- t(as.matrix(imager::load.image(rac_path(P, "prototype_mask"))))
Wp <- P$prototype$col_shoe
Hp <- P$prototype$row_shoe
sc <- P$prototype$coords$rel_Y_cord / P$prototype$coords$rel_col_shoe
xs <- (-Wp / 2 + 1:Wp) * sc
ys <- -(-Hp / 2 + 1:Hp) * sc
stopifnot(all(dim(mask) == c(Hp, Wp)))
peaks <- list()
for (ds in c("old", "new")) {
  d <- dat[[ds]]
  b <- basis_knots(d)
  bx <- ns(d$new_x, knots = b$knots_x)
  by <- ns(d$y, knots = b$knots_y)
  gr <- expand.grid(x = xs, y = ys)
  X <- predict(bx, gr$x)
  Y <- predict(by, gr$y)
  M <- cbind(1, do.call(cbind, lapply(seq_len(ncol(Y)),
                                      function(i) X * Y[, i])))
  eta <- matrix(as.vector(M %*% fixef(glmm[[ds]])), Hp, Wp, byrow = TRUE)
  eta[mask == 0] <- NA
  pk <- which(!is.na(eta), arr.ind = TRUE)
  ismax <- apply(pk, 1, function(p) {
    r0 <- max(1, p[1] - 15):min(Hp, p[1] + 15)
    c0 <- max(1, p[2] - 15):min(Wp, p[2] + 15)
    eta[p[1], p[2]] >= max(eta[r0, c0], na.rm = TRUE)
  })
  pk <- pk[ismax, , drop = FALSE]
  med <- median(eta, na.rm = TRUE)
  tot <- sum(d$n_Acc) / sum(d$n_Acc == 0)
  cat(sprintf("%s: map eta median %.3f\n%8s %8s %8s %10s %6s %6s %7s %6s %10s\n",
              ds, med, "new_x", "y", "eta-med", "plot x,y", "cases", "ctrl",
              "O/E", "z", "ratio/all"))
  rows <- list()
  for (j in seq_len(nrow(pk))) {
    r <- pk[j, 1]
    cc <- pk[j, 2]
    s <- d[abs(d$new_x - xs[cc]) < 0.025 &
             abs(d$y - ys[r]) < 0.04 - 1e-9, ]
    o <- oe(s)
    ratio <- (o[["O"]] / o[["ctrl"]]) / tot
    cat(sprintf("%8.3f %8.3f %8.2f %4.2f,%4.2f %6d %6d %7.3f %6.2f %10.2f\n",
                xs[cc], ys[r], eta[r, cc] - med, (cc - 1) / (Wp - 1),
                (Hp - r) / (Hp - 1), o[["O"]], o[["ctrl"]], o[["OE"]],
                o[["z"]], ratio))
    rows[[j]] <- data.frame(new_x = xs[cc], y = ys[r], OE = o[["OE"]])
  }
  peaks[[ds]] <- do.call(rbind, rows)
}

cat("\n== D. the step-5 CI cuts: O/E within +-0.02 of the cut's y\n")
for (ds in c("old", "new")) {
  d <- dat[[ds]]
  b <- basis_knots(d)
  bx <- ns(d$new_x, knots = b$knots_x)
  by <- ns(d$y, knots = b$knots_y)
  for (row in c(110, 190, 250)) {
    y0 <- ys[row]
    s <- d[abs(d$y - y0) <= 0.02 + 1e-9, ]
    p <- oe(s)
    xbin <- cut(s$new_x, xb)
    per <- vapply(split(seq_len(nrow(s)), xbin, drop = TRUE), function(i) {
      o <- oe(s[i, ])
      sprintf("%.2f (z %.1f, O %d)", o[["OE"]], o[["z"]], o[["O"]])
    }, "")
    # the map's (= the cut curve's) maximum on the right half of the row
    inside <- which(mask[row, ] == 1 & xs > 0)
    Xr <- predict(bx, xs[inside])
    Yr <- predict(by, rep(y0, length(inside)))
    Mr <- cbind(1, do.call(cbind, lapply(seq_len(ncol(Yr)),
                                         function(i) Xr * Yr[, i])))
    er <- as.vector(Mr %*% fixef(glmm[[ds]]))
    xpk <- xs[inside][which.max(er)]
    w <- s[abs(s$new_x - xpk) <= 0.02, ]
    q <- oe(w)
    # step 5's Random band at that point: eta + MEAN_OFFSET +- 1.96 se, se
    # from vcov() (the default vcov, as step 5), on the intensity scale
    xr <- Mr[which.max(er), ]
    se <- sqrt(as.numeric(t(xr) %*% as.matrix(vcov(glmm[[ds]])) %*% xr))
    pcs <- read.csv(rac_path(prof[[ds]], "pixel_counts"), header = TRUE)
    eta0 <- max(er) + mean(log(100 / pcs$pixel_count))
    inten <- function(e) -log(1 - plogis(e))
    hi <- inten(eta0 + 1.96 * se) / inten(eta0) - 1
    lo <- 1 - inten(eta0 - 1.96 * se) / inten(eta0)
    cat(sprintf(paste("%s row %d (y = %.3f): pooled O %d, E %.1f, O/E %.3f,",
                      "z %.2f; right-half maximum of the curve at new_x %.3f",
                      "(column %d): O/E %.3f (z %.2f, O %d); the model-based",
                      "Random band there -%.1f%% / +%.1f%%\n   by new_x bin:",
                      "%s\n"),
                ds, row, y0, p[["O"]], p[["E"]], p[["OE"]], p[["z"]], xpk,
                inside[which.max(er)], q[["OE"]], q[["z"]], q[["O"]],
                100 * lo, 100 * hi, paste(names(per), per, collapse = "; ")))
  }
}

cat("\n== E. NEW: O/E in y (-0.16, -0.10] per block of 49 shoe ids\n")
d <- dat$new
codes_new <- read.csv(rac_path(prof$new, "shoe_codes"), header = TRUE)
stopifnot(identical(codes_new$code, codes_new$shoe))  # NEW code k = shoe k
blk <- (d$shoe - 1) %/% 49 + 1
inb <- d$y > -0.16 & d$y <= -0.10
cat(sprintf("%5s %9s %5s %7s %6s %6s\n", "block", "ids", "O", "E", "O/E", "z"))
for (k in sort(unique(blk))) {
  o <- oe(d[inb & blk == k, ])
  ids <- range(d$shoe[blk == k])
  cat(sprintf("%5d %4d-%-4d %5d %7.1f %6.2f %6.2f\n", k, ids[1], ids[2],
              o[["O"]], o[["E"]], o[["OE"]], o[["z"]]))
}
is_a <- function(id) id <= 343 | (id >= 442 & id <= 490)
grpA <- is_a(d$shoe)
band <- d$y > -0.18 & d$y <= -0.10
cat("band y (-0.18, -0.10], from the case-control rows:\n")
for (nm in c("A", "B", "all")) {
  sel <- switch(nm, A = grpA, B = !grpA, all = rep(TRUE, nrow(d)))
  s <- d[sel & band, ]
  o <- oe(s)
  cat(sprintf(paste("group %-3s %3d shoes, %5d cases (%.1f%% of NEW) | band:",
                    "cases %3d, controls %4d, ratio %.3f (group %.3f), O/E",
                    "%.2f, z %.1f; shoes with a control there %d, with a",
                    "case %d\n"),
              nm, length(unique(d$shoe[sel])), sum(d$n_Acc[sel]),
              100 * sum(d$n_Acc[sel]) / sum(d$n_Acc), o[["O"]], o[["ctrl"]],
              o[["O"]] / o[["ctrl"]],
              sum(d$n_Acc[sel]) / sum(d$n_Acc[sel] == 0), o[["OE"]], o[["z"]],
              length(unique(s$shoe[s$n_Acc == 0])),
              length(unique(s$shoe[s$n_Acc == 1]))))
}
surf <- list(new = contact_surfaces(prof$new), old = contact_surfaces(prof$old))
band_px <- function(ds, lo = -0.18, hi = -0.10) {
  rws <- band_rows(prof[[ds]], lo, hi)
  data.frame(S = vapply(surf[[ds]], function(o) sum(o$S), 1),
             S_band = vapply(surf[[ds]], function(o) sum(o$S[rws, ]), 1),
             rac = vapply(surf[[ds]], function(o) sum(o$rac), 1),
             rac_band = vapply(surf[[ds]], function(o) sum(o$rac[rws, ]), 1))
}
bn <- band_px("new")
ids_new <- rac_analysis_shoes(prof$new)
cat(sprintf("band = rows %s of the NEW frame (y = (%g - row) / 300)\n",
            paste(range(band_rows(prof$new, -0.18, -0.10)), collapse = "-"),
            prof$new$row_shoe / 2))
cat("band y (-0.18, -0.10], from the contact surface S (pixels):\n")
for (nm in c("A", "B", "all")) {
  sel <- switch(nm, A = is_a(ids_new), B = !is_a(ids_new),
                all = rep(TRUE, length(ids_new)))
  b <- bn[sel, ]
  cat(sprintf(paste("group %-3s S px in the band %6d of %7d (%.1f%%); RAC px",
                    "in the band %4d of %5d (%.2f%%); RAC px per S px: band",
                    "%.5f, whole shoe %.5f (ratio %.2f); shoes with S in the",
                    "band %d (with >= 50 px %d), with a RAC px there %d\n"),
              nm, sum(b$S_band), sum(b$S), 100 * sum(b$S_band) / sum(b$S),
              sum(b$rac_band), sum(b$rac), 100 * sum(b$rac_band) / sum(b$rac),
              sum(b$rac_band) / sum(b$S_band), sum(b$rac) / sum(b$S),
              (sum(b$rac_band) / sum(b$S_band)) / (sum(b$rac) / sum(b$S)),
              sum(b$S_band > 0), sum(b$S_band >= 50), sum(b$rac_band > 0)))
}
bo <- band_px("old")
cat(sprintf(paste("OLD all: S px in the band %d of %d (%.1f%%); RAC px in the",
                  "band %d of %d (%.2f%%); RAC px per S px: band %.5f, whole",
                  "shoe %.5f (ratio %.2f)\n"),
            sum(bo$S_band), sum(bo$S), 100 * sum(bo$S_band) / sum(bo$S),
            sum(bo$rac_band), sum(bo$rac), 100 * sum(bo$rac_band) / sum(bo$rac),
            sum(bo$rac_band) / sum(bo$S_band), sum(bo$rac) / sum(bo$S),
            (sum(bo$rac_band) / sum(bo$S_band)) / (sum(bo$rac) / sum(bo$S))))

cat("\n== F. the same_shoe reprints of T0: the band on both prints\n")
v <- read.csv(file.path(root, "docs", "qa", "T0", "compare",
                        "overlap_verdicts_t0_old_vs_new.csv"))
v <- v[v$verdict == "same_shoe", ]
ids_old <- rac_analysis_shoes(prof$old)
loc_new <- read_locations(prof$new)
loc_old <- read_locations(prof$old)
px_per <- prof$new$coords$rel_col_shoe / prof$new$coords$rel_Y_cord
stopifnot(px_per == prof$old$coords$rel_col_shoe / prof$old$coords$rel_Y_cord)
shift_y <- vapply(seq_len(nrow(v)), function(k) {
  a <- loc_new[loc_new$shoe == v$new[k], ]
  o <- loc_old[loc_old$shoe == v$old[k], ]
  dx <- round(outer(a$x, o$x, "-") * px_per)
  dy <- round(outer(a$y, o$y, "-") * px_per)
  ok <- abs(dx) <= 15 & abs(dy) <= 15
  if (!any(ok)) return(NA_real_)
  votes <- table(paste(dx[ok], dy[ok]))
  as.numeric(strsplit(names(votes)[which.max(votes)], " ")[[1]][2])
}, 1)
v$A <- is_a(v$new)
v$shift_y <- shift_y
kn <- match(v$new, ids_new)
ko <- match(v$old, ids_old)
stopifnot(!anyNA(kn), !anyNA(ko))
cat(sprintf(paste("%d same_shoe pairs (group A %d, group B %d); y shift NEW -",
                  "OLD of the matched RACs (px): median %g, |shift| <= 3 px",
                  "for %d pairs, range %g to %g\n"),
            nrow(v), sum(v$A), sum(!v$A), median(shift_y, na.rm = TRUE),
            sum(abs(shift_y) <= 3, na.rm = TRUE), min(shift_y, na.rm = TRUE),
            max(shift_y, na.rm = TRUE)))
for (g in c(TRUE, FALSE)) {
  sel <- v$A == g
  bnew <- bn[kn[sel], ]
  bold <- bo[ko[sel], ]
  cat(sprintf(paste("group %s (%d pairs): RAC px in the band: NEW prints %d of",
                    "%d (%.2f%%), OLD prints of the same soles %d of %d",
                    "(%.2f%%); S px in the band: NEW %.1f%% of S, OLD %.1f%%;",
                    "RAC px per S px in the band: NEW %.5f, OLD %.5f\n"),
              if (g) "A" else "B", sum(sel), sum(bnew$rac_band),
              sum(bnew$rac), 100 * sum(bnew$rac_band) / sum(bnew$rac),
              sum(bold$rac_band), sum(bold$rac),
              100 * sum(bold$rac_band) / sum(bold$rac),
              100 * sum(bnew$S_band) / sum(bnew$S),
              100 * sum(bold$S_band) / sum(bold$S),
              sum(bnew$rac_band) / sum(bnew$S_band),
              sum(bold$rac_band) / sum(bold$S_band)))
}
# the OLD band shifted by each pair's registration (the same place on the sole)
rac_old_shift <- vapply(which(v$A), function(k) {
  sh <- if (is.na(v$shift_y[k])) 0 else v$shift_y[k]
  # a NEW y of the band is an OLD y lower by sh / px_per
  rws <- band_rows(prof$old, -0.18 - sh / px_per, -0.10 - sh / px_per)
  sum(surf$old[[ko[k]]]$rac[rws, ])
}, 1)
cat(sprintf(paste("group A, the OLD band moved by each pair's y shift: RAC px",
                  "%d of %d\n"), sum(rac_old_shift), sum(bo$rac[ko[v$A]])))
cat(sprintf("RAC px in the band, all OLD shoes: %d of %d (%.2f%%)\n",
            sum(bo$rac_band), sum(bo$rac), 100 * sum(bo$rac_band) / sum(bo$rac)))

cat("\n== G. A by group (cells with E >= 15)\n")
for (nm in c("A", "B")) {
  sel <- if (nm == "A") grpA else !grpA
  t15 <- summ(cells(d[sel, ]), paste("NEW group", nm))
  fmt_cells(t15)
}

cat("\n== H. a richer basis (Efron CML; expected per row n_i w / sum w)\n")
cml_E <- function(fit, d) {
  w <- exp(predict(fit, type = "lp", reference = "zero"))
  n <- ave(d$n_Acc, d$shoe, FUN = sum)
  n * w / ave(w, d$shoe, FUN = sum)
}
for (ds in c("old", "new")) {
  d <- dat[[ds]]
  b <- basis_knots(d)
  bx <- ns(d$new_x, knots = b$knots_x)
  by <- ns(d$y, knots = b$knots_y)
  kx2 <- as.numeric(quantile(d$new_x, 1:5 / 6))
  ky2 <- as.numeric(quantile(d$y, 1:9 / 10))
  bx2 <- ns(d$new_x, knots = kx2)
  by2 <- ns(d$y, knots = ky2)
  t0 <- proc.time()[["elapsed"]]
  fits <- list(
    K8 = clogit(n_Acc ~ bx:by + strata(shoe), data = d, method = "efron"),
    full = clogit(n_Acc ~ bx + by + bx:by + strata(shoe), data = d,
                  method = "efron"),
    full_5x9 = clogit(n_Acc ~ bx2 + by2 + bx2:by2 + strata(shoe), data = d,
                      method = "efron"))
  pk <- peaks[[ds]]
  pk <- pk[pk$y > -0.20 & pk$y <= -0.12, , drop = FALSE]
  cat(sprintf("%s (%.0f s for the three fits):\n", ds,
              proc.time()[["elapsed"]] - t0))
  for (nm in names(fits)) {
    f <- fits[[nm]]
    E <- cml_E(f, d)
    t15 <- cells(d, E)
    t15 <- t15[t15$E >= 15, ]
    line <- sprintf(paste("  %-8s %2d coef, loglik %.2f; cells E >= 15: %d,",
                          "|z| > 3: %d, sum z^2 %.0f"),
                    nm, sum(!is.na(coef(f))), f$loglik[2], nrow(t15),
                    sum(abs(t15$z) > 3), sum(t15$z^2))
    for (j in seq_len(nrow(pk))) {
      i <- abs(d$new_x - pk$new_x[j]) < 0.025 &
        abs(d$y - pk$y[j]) < 0.04 - 1e-9
      o <- oe(d[i, ], E[i])
      line <- paste(line, sprintf("; window (%.3f, %.3f): O/E %.3f, z %.2f",
                                  pk$new_x[j], pk$y[j], o[["OE"]], o[["z"]]))
    }
    cat(line, "\n")
  }
}
cat(sprintf("\nt5_gof.R done in %.0f s\n", proc.time()[["elapsed"]] - t_start))
