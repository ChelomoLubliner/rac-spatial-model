# validation.R: Part 2, the out-of-sample validation of the OLD-fitted models
# on the NEW shoes (plan T7 and section 9; meeting 4, Part 2; decisions
# D-002 to D-005, A-008 to A-011, A-025, A-026, A-030, A-043, A-051, and the
# T7 decisions recorded in docs/results/validation.md).
#
# Micha's quantity: for every shoe i and every contact pixel j, p_ij = the
# pixel probability of the OLD GLMM with the random effect 0 (eta = the
# spline surface + MEAN_OFFSET of OLD), S_ij = 1 on the contact surface;
# E_ik = sum over the pixels j of part k of p_ij S_ij, normalized to the
# shoe's observed total n_i (D-003), compared with the observed counts O_ik.
# Pixels are those of step 1 (raw contact x the stamp mask of the dataset,
# the erase list applied, every RAC pixel set to 1) in each shoe's own
# image; new_x is computed from the shoe's own contour and the OLD
# prototype with the step-2 arithmetic (R/distances.R), so for a sampled
# pixel it is identical() to the step-2 CSV (tests/r/test_validation_pixels.R).
#
# Paths (no new profile key; user rule 1):
# part2_path(P, stem, ext, kind)  <data root>/validation[/new]/<stem><suffix>.<ext>
#                                 with the data root of the profile
#                                 (processed_data) or the image root
#                                 (model_images); NEW outputs in a new
#                                 folder with the _new suffix
# part2_cache_path(P, stem)       logs/validation[/new]/<stem><suffix>.rds
#                                 (logs/ is not tracked)
#
# Readers and the pixel table:
# part2_round_trip(v)             the doubles write.csv writes and read.csv
#                                 reads back (15 significant digits), the
#                                 round trip every step-1/2 value made
# part2_read_records(path, W, H, n)
#                                 the n fixed-stride 0/1 records (H x W
#                                 integer matrices; CRLF checked)
# part2_coords(P)                 list(x per column, y per row) in memory,
#                                 the legacy xcoor/ycoor expressions
# part2_aspix(x, y, P)            the RAC pixel (col, row) of step 1
# part2_distance_per_y(P)         the prototype half-widths of step 2
# part2_pixel_table(P, verbose, codes)
#                                 every contact pixel of every analysis
#                                 shoe (or of the shoe codes given):
#                                 code, shoe, row, col, x, y, new_x,
#                                 horiz_dist, N (RACs in the pixel); x, y,
#                                 horiz_dist and new_x after the round
#                                 trips of steps 1 and 2
#
# Partitions:
# naomi_area(x, y)                Naomi's 14 areas (2022), x in Naomi's
#                                 frame (the locations files; the pixel
#                                 frame of dataCC is mirrored, plan F7)
# naomi_area_band(a)              the y band (1 heel .. 5 toe) of an area
# grid_cuts_from_old(new_x, y, n_y, n_x)
#                                 data.frame(n_y, n_x, band, y_lo, y_hi,
#                                 x_cut_1..): y cuts at the quantiles
#                                 1:(n_y-1)/n_y of y, new_x cuts at the
#                                 quantiles 1:(n_x-1)/n_x within each band
#                                 (A-008: over OLD contact pixels)
# grid_cell(new_x, y, cuts)       cell (band - 1) * n_x + column; bands and
#                                 columns are (lo, hi] intervals
# grid_band(cell, n_x)            the band of a grid cell
#
# Linear predictors:
# part2_basis(model)              the knots of a step-3 or common-basis model
# part2_coef_parts(co)            intercept, main x, main y and interaction
#                                 matrix of a coefficient vector named like
#                                 the step-3, full-tensor or bx/by models
# part2_design(new_x, y, basis)   the step-3 design matrix (24 interaction
#                                 columns, new_x fastest, plus the intercept)
# part2_eta(Bx, By_img, row, parts)
#                                 eta of every pixel from the x basis of the
#                                 pixels and the y basis of the image rows
#
# Cell statistics (shoes x cells matrices; plan section 9):
# normalize_expected(E, n)        E~ = n_i E_ik / sum_k E_ik
# merge_cells(E, band, nbr, min_expected)
#                                 merge map so that every pooled E >= 5
# pearson_pooled(O, E)            X^2, df = K' - 1, p
# phi0(pi, n, E)                  exact E[X^2]/(K' - 1) under independent
#                                 multinomials with shoe-specific pi
# effect_sizes(X2, E0, df, N)     Cramer's w, w net of the noise floor E0,
#                                 RMSEA-type index
# regional_fit(O, S, w)           the 2022 theta: conditional multinomial
#                                 MLE (= Poisson GLM shoe + area +
#                                 offset(log S)), shoe weights w
# regional_expected(theta, Sak, n)
#                                 E~R for a test partition from the area x
#                                 cell contact counts
# log_score_terms(...)            per-shoe log-score contributions
# wald_param(D, Sigma, GVG)       D' (Sigma + G V G')^+ D, df = rank
#
# Bootstrap (B replicates, worker-independent):
# part2_resample_ids(m, B, seed)  B x m matrix of resampled positions
# fit_glmm_fixed_theta(dat, basis, theta)
#                                 the OLD GLMM refitted at the given
#                                 variance parameter by PIRLS (nAGQ = 0):
#                                 the fast surrogate of a Laplace refit used
#                                 for the OLD shoe-bootstrap draws (T5 has no
#                                 draws; A-043; validated in T7 against
#                                 Laplace refits of the same resamples)

PART2_SEEDS <- list(boot = 20261105L, old_draws = 20261106L,
                    pairs = 20261108L, laplace_check = 20261109L)

part2_path <- function(P, stem, ext = "csv", kind = c("data", "images")) {
  kind <- match.arg(kind)
  top <- if (kind == "data") P$r$paths$dataCC else P$r$paths$images_dir
  top <- strsplit(top, "/", fixed = TRUE)[[1]][1]
  parts <- c(top, "validation", if (!identical(P$dataset, "old")) P$dataset)
  path <- paste(P$root, paste(parts, collapse = "/"), "/", stem, P$suffix,
                ".", ext, sep = "")
  path
}

part2_cache_path <- function(P, stem) {
  top <- strsplit(P$r$log_dir, "/", fixed = TRUE)[[1]][1]
  parts <- c(top, "validation", if (!identical(P$dataset, "old")) P$dataset)
  paste(P$root, paste(parts, collapse = "/"), "/", stem, P$suffix, ".rds",
        sep = "")
}

part2_round_trip <- function(v) {
  tf <- tempfile(fileext = ".csv")
  on.exit(unlink(tf))
  utils::write.csv(data.frame(v = v), tf, row.names = FALSE)
  utils::read.csv(tf)$v
}

part2_read_records <- function(path, W, H, n) {
  stride <- W * H + 2
  if (file.size(path) != stride * n) {
    stop(path, " is not ", n, " records of ", W, " x ", H, " + 2 bytes",
         call. = FALSE)
  }
  con <- file(path, "rb")
  on.exit(close(con))
  raw <- readBin(con, "raw", n = stride * n)
  ends <- seq_len(n) * stride
  if (!all(raw[ends - 1] == as.raw(13L)) || !all(raw[ends] == as.raw(10L))) {
    stop(path, ": a record does not end with CRLF", call. = FALSE)
  }
  lapply(seq_len(n), function(i) {
    b <- as.integer(raw[(i - 1) * stride + seq_len(W * H)]) - 48L
    if (any(b != 0L & b != 1L)) stop(path, ": record ", i, " is not 0/1")
    matrix(b, H, W, byrow = TRUE)
  })
}

part2_coords <- function(P) {
  col_shoe <- P$col_shoe
  row_shoe <- P$row_shoe
  rel_Y_cord <- P$coords$rel_Y_cord
  rel_col_shoe <- P$coords$rel_col_shoe
  # the legacy xcoor[r, c] and ycoor[r, c] of steps 1 and 2
  list(x = (-col_shoe / 2 + 1:col_shoe) * rel_Y_cord / rel_col_shoe,
       y = -((-row_shoe / 2 + 1:row_shoe) * rel_Y_cord / rel_col_shoe))
}

part2_aspix <- function(x, y, P) {
  # aspix_x and aspix_y of dataCC_1.Rmd, with the profile's values
  col_shoe <- P$col_shoe
  row_shoe <- P$row_shoe
  rel_col_shoe <- P$coords$rel_col_shoe
  rel_row_shoe <- P$coords$rel_row_shoe
  rel_x_cord <- P$coords$rel_x_cord
  rel_Y_cord <- P$coords$rel_Y_cord
  not_rel_col <- ceiling((col_shoe - rel_col_shoe) / 2)
  delx <- (2 * rel_x_cord) / rel_col_shoe
  pix_x <- col_shoe - (floor((x + rel_x_cord) / delx) + not_rel_col)
  not_rel_row <- ceiling((row_shoe - rel_row_shoe) / 2)
  dely <- (2 * rel_Y_cord) / rel_row_shoe
  pix_y <- row_shoe - (floor((y + rel_Y_cord) / dely) + not_rel_row)
  list(col = pix_x, row = pix_y)
}

part2_distance_per_y <- function(P) {
  img <- t(as.matrix(imager::load.image(rac_path(P, "prototype_contour"))))
  col_proto <- P$prototype$col_shoe
  row_proto <- P$prototype$row_shoe
  stopifnot(all(dim(img) == c(row_proto, col_proto)))
  rel_Y <- P$prototype$coords$rel_Y_cord
  rel_col <- P$prototype$coords$rel_col_shoe
  xcoor <- t(matrix(rep((-col_proto / 2 + 1:col_proto) * rel_Y / rel_col,
                        row_proto), col_proto, row_proto))
  ycoor <- -matrix(rep((-row_proto / 2 + 1:row_proto) * rel_Y / rel_col,
                       col_proto), row_proto, col_proto)
  ec <- data.frame(x = xcoor[img == 1], y = ycoor[img == 1])
  dplyr::summarise(dplyr::group_by(ec, y), min_x = abs(min(x)),
                   max_x = max(x))
}

# The contact matrices S of step 1 for every analysis shoe (list by code)
# and the RAC count matrices (list by code).
part2_contacts <- function(P) {
  W <- P$col_shoe
  H <- P$row_shoe
  data <- part2_read_records(rac_path(P, "contacts"), W, H, P$num_shoe)
  sm <- rac_read_sticker_masks(P)
  if (!is.null(sm)) data <- rac_apply_sticker_masks(data, sm)
  for (i in P$r$contact_flip_shoes) data[[i]] <- data[[i]][, W:1]
  allcont <- as.matrix(utils::read.csv(rac_path(P, "all_cont")))
  dimnames(allcont) <- NULL
  stopifnot(identical(dim(allcont), c(as.integer(H), as.integer(W))),
            all(allcont %in% c(0, 1)))
  loc <- read_locations(P)
  if (length(P$excluded_shoes)) {
    loc <- loc[!loc$shoe %in% P$excluded_shoes, ]
  }
  shoes <- rac_analysis_shoes(P)
  stopifnot(identical(as.integer(unique(loc$shoe)), as.integer(shoes)))
  pix <- part2_aspix(loc$x, loc$y, P)
  if (any(pix$col < 1 | pix$col > W | pix$row < 1 | pix$row > H)) {
    stop("part2_contacts: a RAC maps outside the image", call. = FALSE)
  }
  S <- vector("list", length(shoes))
  N <- vector("list", length(shoes))
  for (k in seq_along(shoes)) {
    i <- shoes[k]
    sel <- loc$shoe == i
    lin <- pix$row[sel] + (pix$col[sel] - 1) * H
    acc <- matrix(tabulate(lin, nbins = W * H), H, W)
    s <- data[[i]] * allcont
    s[acc >= 1] <- 1
    S[[k]] <- s
    N[[k]] <- acc
  }
  list(S = S, N = N, shoes = shoes, n_rac = as.vector(table(
    factor(loc$shoe, levels = shoes))))
}

# Contour points of every analysis shoe (list by code): x and y in memory,
# as step 2 computes them (no round trip).
part2_contour_points <- function(P) {
  W <- P$col_shoe
  H <- P$row_shoe
  n_rec <- length(rac_analysis_shoes(P))
  rec <- part2_read_records(rac_path(P, "contour"), W, H, n_rec)
  xy <- part2_coords(P)
  lapply(rec, function(m) {
    idx <- which(m == 1)
    r <- (idx - 1) %% H + 1
    cc <- (idx - 1) %/% H + 1
    list(x = xy$x[cc], y = xy$y[r])
  })
}

# Step-2 distances of the pixels of one shoe: x, y after the round trip,
# row the image row (pixels of one row share y), cx, cy the contour points.
# Returns horiz_dist before its round trip (Inf where no contour point lies
# within 0.01 in y) and min_dist where horiz_dist is Inf (NA elsewhere).
.part2_shoe_distances <- function(x, y, row, cx, cy) {
  horiz <- rep(Inf, length(x))
  by_row <- split(seq_along(x), row)
  for (rr in names(by_row)) {
    i <- by_row[[rr]]
    yv <- y[i[1]]
    j <- which(abs(yv - cy) < 0.01)
    if (!length(j)) next
    m <- rep(Inf, length(i))
    xi <- x[i]
    for (jj in j) {
      m <- pmin(m, sqrt((xi - cx[jj])^2 + (yv - cy[jj])^2))
    }
    horiz[i] <- m
  }
  mind <- rep(NA_real_, length(x))
  inf <- which(is.infinite(horiz))
  if (length(inf)) {
    m <- rep(Inf, length(inf))
    for (jj in seq_along(cx)) {
      m <- pmin(m, sqrt((x[inf] - cx[jj])^2 + (y[inf] - cy[jj])^2))
    }
    mind[inf] <- m
  }
  list(horiz = horiz, min_dist = mind)
}

part2_pixel_table <- function(P, verbose = FALSE, codes = NULL) {
  ct <- part2_contacts(P)
  cp <- part2_contour_points(P)
  stopifnot(length(cp) == length(ct$shoes))
  if (is.null(codes)) codes <- seq_along(ct$shoes)
  xy <- part2_coords(P)
  x_rt <- part2_round_trip(xy$x)
  y_rt <- part2_round_trip(xy$y)
  H <- P$row_shoe
  parts <- vector("list", length(ct$shoes))
  for (k in codes) {
    idx <- which(ct$S[[k]] == 1)
    r <- as.integer((idx - 1) %% H + 1)
    cc <- as.integer((idx - 1) %/% H + 1)
    d <- .part2_shoe_distances(x_rt[cc], y_rt[r], r, cp[[k]]$x, cp[[k]]$y)
    parts[[k]] <- data.frame(code = k, shoe = as.integer(ct$shoes[k]),
                             row = r, col = cc, N = as.integer(ct$N[[k]][idx]),
                             horiz_raw = d$horiz, min_dist_raw = d$min_dist)
    if (verbose && k %% 50 == 0) message("distances: shoe code ", k)
  }
  px <- do.call(rbind, parts)
  px$x <- x_rt[px$col]
  px$y <- y_rt[px$row]
  # the two temp-CSV round trips of step 2 (compute_distances)
  inf <- is.infinite(px$horiz_raw)
  horiz <- px$horiz_raw
  if (any(inf)) {
    horiz[inf] <- part2_round_trip(part2_round_trip(px$min_dist_raw[inf]))
  }
  horiz[!inf] <- part2_round_trip(px$horiz_raw[!inf])
  px$horiz_dist <- horiz
  px$fallback <- inf
  dpy <- part2_distance_per_y(P)
  ds <- distance_shape_vec(px$x, px$y, dpy)
  new_x <- (px$x * ds) / (abs(px$x) + px$horiz_dist)
  px$distance_shape <- ds
  px$new_x <- part2_round_trip(new_x)
  px$horiz_raw <- NULL
  px$min_dist_raw <- NULL
  attr(px, "n_rac") <- ct$n_rac
  attr(px, "shoes") <- ct$shoes
  attr(px, "y_levels") <- y_rt
  px
}

# --- partitions ---------------------------------------------------------------

naomi_area <- function(x, y) {
  band <- ifelse(y < -0.35, 1L, ifelse(y < -0.15, 2L,
                 ifelse(y < 0, 3L, ifelse(y < 0.15, 4L, 5L))))
  a <- ifelse(x < 0, band, 11L - band)
  a[a == 4L & y > 12 * (x + 0.02)^2 - 0.07] <- 11L
  a[a == 5L & y < -12 * (x + 0.01)^2 + 0.4] <- 12L
  a[a == 6L & y < -20 * (x + 0.01)^2 + 0.4] <- 13L
  a[a == 7L & y > 16 * (x + 0.02)^2 - 0.07] <- 14L
  as.integer(a)
}

naomi_area_band <- function(a) {
  c(1L, 2L, 3L, 4L, 5L, 5L, 4L, 3L, 2L, 1L, 4L, 5L, 5L, 4L)[a]
}

grid_cuts_from_old <- function(new_x, y, n_y, n_x) {
  yc <- as.numeric(stats::quantile(y, seq_len(n_y - 1) / n_y))
  band <- 1L + findInterval(y, yc, left.open = TRUE)
  lo <- c(-Inf, yc)
  hi <- c(yc, Inf)
  out <- data.frame(n_y = n_y, n_x = n_x, band = seq_len(n_y), y_lo = lo,
                    y_hi = hi)
  xc <- matrix(NA_real_, n_y, n_x - 1)
  for (b in seq_len(n_y)) {
    xc[b, ] <- as.numeric(stats::quantile(new_x[band == b],
                                          seq_len(n_x - 1) / n_x))
  }
  colnames(xc) <- paste("x_cut", seq_len(n_x - 1), sep = "_")
  cbind(out, xc)
}

grid_cell <- function(new_x, y, cuts) {
  stopifnot(length(unique(cuts$n_y)) == 1, length(unique(cuts$n_x)) == 1)
  n_x <- cuts$n_x[1]
  yc <- cuts$y_hi[-nrow(cuts)]
  band <- 1L + findInterval(y, yc, left.open = TRUE)
  cell <- integer(length(y))
  xcols <- grep("^x_cut_", names(cuts), value = TRUE)
  for (b in seq_len(nrow(cuts))) {
    sel <- which(band == b)
    xc <- as.numeric(cuts[b, xcols])
    xc <- xc[!is.na(xc)]
    cell[sel] <- (b - 1L) * n_x + 1L + findInterval(new_x[sel], xc,
                                                    left.open = TRUE)
  }
  cell
}

grid_band <- function(cell, n_x) as.integer((cell - 1L) %/% n_x + 1L)

# --- linear predictors --------------------------------------------------------

part2_basis <- function(model) basis_of(model)

part2_coef_parts <- function(co) {
  nm <- names(co)
  key <- nm
  key <- sub(paste("^ns\\(dat\\$new_x, knots = knots_new_x\\)([0-9]+):",
                   "ns\\(dat\\$y, knots = knotsy\\)([0-9]+)$", sep = ""),
             "x\\1:y\\2", key)
  key <- sub("^bx([0-9]+):by([0-9]+)$", "x\\1:y\\2", key)
  key <- sub("^bx([0-9]+)$", "x\\1", key)
  key <- sub("^by([0-9]+)$", "y\\1", key)
  ok <- key == "(Intercept)" | grepl("^x[0-9]+:y[0-9]+$", key) |
    grepl("^[xy][0-9]+$", key)
  if (!all(ok)) {
    stop("part2_coef_parts: unknown coefficient names: ",
         paste(nm[!ok], collapse = ", "), call. = FALSE)
  }
  inter <- grepl(":", key, fixed = TRUE)
  ia <- as.integer(sub("^x([0-9]+):y([0-9]+)$", "\\1", key[inter]))
  ib <- as.integer(sub("^x([0-9]+):y([0-9]+)$", "\\2", key[inter]))
  A <- matrix(0, max(ia), max(ib))
  A[cbind(ia, ib)] <- unname(co[inter])
  mx <- grepl("^x[0-9]+$", key)
  my <- grepl("^y[0-9]+$", key)
  u <- numeric(nrow(A))
  v <- numeric(ncol(A))
  if (any(mx)) u[as.integer(sub("^x", "", key[mx]))] <- unname(co[mx])
  if (any(my)) v[as.integer(sub("^y", "", key[my]))] <- unname(co[my])
  intercept <- if ("(Intercept)" %in% key) unname(co[key == "(Intercept)"]) else 0
  list(intercept = intercept, u = u, v = v, A = A, has_main = any(mx | my))
}

part2_design <- function(new_x, y, basis) {
  bx <- splines::ns(new_x, knots = basis$knots_x,
                    Boundary.knots = basis$bknots_x)
  by <- splines::ns(y, knots = basis$knots_y, Boundary.knots = basis$bknots_y)
  X <- matrix(1, length(new_x), 1 + ncol(bx) * ncol(by))
  k <- 1
  for (b in seq_len(ncol(by))) {
    for (a in seq_len(ncol(bx))) {
      k <- k + 1
      X[, k] <- bx[, a] * by[, b]
    }
  }
  X
}

part2_bx <- function(new_x, basis) {
  m <- splines::ns(new_x, knots = basis$knots_x,
                   Boundary.knots = basis$bknots_x)
  matrix(as.vector(m), nrow(m), ncol(m))
}

part2_by <- function(y, basis) {
  m <- splines::ns(y, knots = basis$knots_y, Boundary.knots = basis$bknots_y)
  matrix(as.vector(m), nrow(m), ncol(m))
}

part2_eta <- function(Bx, By_img, row, parts) {
  stopifnot(ncol(Bx) == nrow(parts$A), ncol(By_img) == ncol(parts$A))
  C <- By_img %*% t(parts$A)
  eta <- rep(parts$intercept, nrow(Bx))
  for (a in seq_len(ncol(Bx))) eta <- eta + Bx[, a] * C[row, a]
  if (parts$has_main) {
    eta <- eta + as.vector(Bx %*% parts$u) + as.vector(By_img %*% parts$v)[row]
  }
  eta
}

# --- cell statistics ----------------------------------------------------------

normalize_expected <- function(E, n) {
  E <- as.matrix(E)
  tot <- rowSums(E)
  if (any(!(tot > 0))) stop("normalize_expected: a shoe has no expected mass")
  E * (n / tot)
}

# Merge cells with pooled expected count below min_expected: the smallest
# such cell joins its neighbour of smallest pooled E in the same band, else
# in an adjacent band (nbr: optional list of allowed neighbours per cell;
# default all cells of the band). Returns the K x K' 0/1 map and the
# merged groups.
merge_cells <- function(E, band, nbr = NULL, min_expected = 5) {
  K <- length(E)
  stopifnot(length(band) == K)
  grp <- seq_len(K)
  repeat {
    Eg <- tapply(E, grp, sum)
    small <- as.integer(names(Eg)[Eg < min_expected])
    if (!length(small) || length(Eg) == 1) break
    g <- small[which.min(Eg[as.character(small)])]
    members <- which(grp == g)
    cand <- integer(0)
    for (m in members) {
      nb <- if (is.null(nbr)) which(band == band[m]) else nbr[[m]]
      cand <- c(cand, nb)
    }
    cand <- setdiff(unique(grp[cand]), g)
    if (!length(cand)) {
      bands <- unique(band[members])
      adj <- which(band %in% c(bands - 1L, bands + 1L))
      cand <- setdiff(unique(grp[adj]), g)
    }
    if (!length(cand)) cand <- setdiff(unique(grp), g)
    target <- cand[which.min(Eg[as.character(cand)])]
    grp[grp == g] <- target
  }
  ug <- sort(unique(grp))
  map <- matrix(0, K, length(ug))
  map[cbind(seq_len(K), match(grp, ug))] <- 1
  list(map = map, group = match(grp, ug), K_merged = length(ug))
}

pearson_pooled <- function(O, E) {
  X2 <- sum((O - E)^2 / E)
  df <- length(O) - 1
  list(X2 = X2, df = df, p = stats::pchisq(X2, df, lower.tail = FALSE))
}

# pi: shoes x K' model probabilities (rows sum to 1), n: RACs per shoe,
# E: pooled expected counts (colSums(n * pi)).
phi0 <- function(pi, n, E = colSums(n * pi)) {
  K <- ncol(pi)
  (K - sum(colSums(n * pi^2) / E)) / (K - 1)
}

effect_sizes <- function(X2, E0, df, N) {
  list(w = sqrt(X2 / N), w_net = sqrt(max(X2 - E0, 0) / N),
       rmsea = sqrt(max(X2 - E0, 0) / (df * (N - 1))))
}

# The 2022 regional model: theta (one per area) maximizing the conditional
# multinomial likelihood sum_i w_i sum_a O_ia log(theta_a S_ia /
# sum_a' theta_a' S_ia'), equal to the Poisson GLM O_ia ~ factor(shoe) +
# factor(area) + offset(log S_ia) on the cells with S_ia > 0 (Naomi's CML
# of 2022). Fixed point theta_a = O_.a / sum_i w_i n_i S_ia / (S_i. theta),
# accelerated by SQUAREM; theta is scaled so that sum_a theta_a S_.a = O_..
# (RACs per contact pixel, weights included).
regional_fit <- function(O, S, w = NULL, tol = 1e-13, maxit = 100000L) {
  O <- as.matrix(O)
  S <- as.matrix(S)
  if (is.null(w)) w <- rep(1, nrow(O))
  keep <- w > 0
  O <- O[keep, , drop = FALSE]
  S <- S[keep, , drop = FALSE]
  w <- w[keep]
  n <- rowSums(O)
  Ot <- colSums(w * O)
  St <- colSums(w * S)
  if (any(St <= 0)) stop("regional_fit: an area has no contact pixel")
  step <- function(th) {
    den <- as.vector(S %*% th)
    th <- Ot / colSums((w * n / den) * S)
    th * (sum(Ot) / sum(th * St))
  }
  th <- Ot / St
  th <- th * (sum(Ot) / sum(th * St))
  it <- 0L
  repeat {
    it <- it + 1L
    t1 <- step(th)
    t2 <- step(t1)
    r <- t1 - th
    v <- t2 - 2 * t1 + th
    sv <- sqrt(sum(v^2))
    alpha <- if (sv > 0) -sqrt(sum(r^2)) / sv else -1
    alpha <- min(-1, alpha)
    tn <- th - 2 * alpha * r + alpha^2 * v
    if (any(!is.finite(tn)) || any(tn < 0)) tn <- t2
    tn <- step(tn)
    if (max(abs(tn - th) / pmax(th, .Machine$double.xmin)) < tol || it >= maxit) {
      th <- tn
      break
    }
    th <- tn
  }
  names(th) <- colnames(O)
  attr(th, "iterations") <- it
  th
}

# Regional expected counts of a test partition: Sak = shoes x areas x cells
# array of contact pixels in area a and cell k, n = RACs per shoe.
regional_expected <- function(theta, Sak, n) {
  d <- dim(Sak)
  num <- matrix(0, d[1], d[3])
  for (a in seq_len(d[2])) num <- num + theta[a] * Sak[, a, ]
  den <- rowSums(num)
  num * (n / den)
}

# Moore-Penrose Wald statistic of the pooled discrepancy D with covariance
# Sigma + GVG (both annihilate the vector of ones); df = numerical rank.
wald_param <- function(D, Sigma, GVG = 0) {
  V <- Sigma + GVG
  e <- eigen((V + t(V)) / 2, symmetric = TRUE)
  tol <- max(dim(V)) * max(abs(e$values)) * .Machine$double.eps * 1e4
  pos <- e$values > tol
  Vinv <- e$vectors[, pos, drop = FALSE] %*%
    (t(e$vectors[, pos, drop = FALSE]) / e$values[pos])
  W <- as.numeric(t(D) %*% Vinv %*% D)
  df <- sum(pos)
  list(W = W, df = df, p = stats::pchisq(W, df, lower.tail = FALSE))
}

part2_resample_ids <- function(m, B, seed) {
  old <- if (exists(".Random.seed", envir = globalenv())) {
    get(".Random.seed", envir = globalenv())
  } else {
    NULL
  }
  on.exit(if (!is.null(old)) assign(".Random.seed", old, envir = globalenv()))
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion",
           sample.kind = "Rejection")
  matrix(sample.int(m, m * B, replace = TRUE), B, m, byrow = TRUE)
}

# --- the OLD GLMM refit used for the shoe-bootstrap draws ---------------------

fit_glmm_fixed_theta <- function(dat, basis, theta) {
  bx <- splines::ns(dat$new_x, knots = basis$knots_x,
                    Boundary.knots = basis$bknots_x)
  by <- splines::ns(dat$y, knots = basis$knots_y,
                    Boundary.knots = basis$bknots_y)
  dat$shoe <- factor(dat$shoe)
  glmod <- lme4::glFormula(n_Acc ~ bx:by + (1 | shoe), data = dat,
                           family = stats::binomial(link = "logit"))
  devfun <- do.call(lme4::mkGlmerDevfun, c(glmod, list(nAGQ = 0)))
  dev <- devfun(theta)
  rho <- environment(devfun)
  beta <- rho$pp$beta(1)
  names(beta) <- colnames(glmod$X)
  list(beta = beta, deviance = dev)
}

# The resampled data of one bootstrap draw: the rows of the drawn shoe codes,
# each draw relabelled as its own shoe (a shoe drawn twice is two groups).
part2_resample_data <- function(dat, codes, ids) {
  rows <- split(seq_len(nrow(dat)), dat$shoe)
  sel <- rows[as.character(codes[ids])]
  out <- dat[unlist(sel, use.names = FALSE), , drop = FALSE]
  out$shoe <- rep(seq_along(ids), lengths(sel))
  out
}

# --- the evaluation engine ------------------------------------------------------
#
# part2_prepare(px, basis, cuts, n_code)
#     per-pixel partitions and the joint groups of a pixel table: a14 =
#     naomi_area(-new_x, y) (Naomi's areas on the standardized shoe, D-005),
#     aR = naomi_area(-x, y) (the 2022 areas on the shoe's own coordinates,
#     A-025), g<K> = grid_cell(new_x, y, cuts of K cells) for every K in
#     cuts; the spline bases of the pixels (Bx) and of the image rows
#     (By_img); groups = one row per distinct (code, a14, aR, g...) with its
#     contact pixels S and RACs O.
# part2_eval(prep, parts, link, offset)
#     one pass over the pixels: per group the sum of p (link "logit": p =
#     plogis(eta + offset)) or of w (link "log": w = exp(eta)); per shoe the
#     total and the sum over its RACs of log p (log w): the log-score terms.
# part2_agg(prep, v, col)  shoes x cells matrix of a per-group value
# part2_sak(prep, area_col, cell_col)
#     shoes x areas x cells array of contact pixels

part2_partition_cols <- function(cuts) {
  c("a14", paste("g", sort(unique(cuts$n_y * cuts$n_x)), sep = ""))
}

part2_prepare <- function(px, basis, cuts, n_code) {
  out <- list(n_code = n_code)
  out$cols <- part2_partition_cols(cuts)
  cell <- list(a14 = naomi_area(-px$new_x, px$y), aR = naomi_area(-px$x, px$y))
  for (K in sort(unique(cuts$n_y * cuts$n_x))) {
    ck <- cuts[cuts$n_y * cuts$n_x == K, ]
    cell[[paste("g", K, sep = "")]] <- grid_cell(px$new_x, px$y, ck)
  }
  out$K <- c(a14 = 14L, aR = 14L)
  for (K in sort(unique(cuts$n_y * cuts$n_x))) {
    out$K[[paste("g", K, sep = "")]] <- as.integer(K)
  }
  key <- px$code - 1
  mult <- n_code
  for (nm in names(cell)) {
    key <- key + (cell[[nm]] - 1) * mult
    mult <- mult * out$K[[nm]]
  }
  stopifnot(mult < 2^52)
  uk <- sort(unique(key))
  out$grp <- match(key, uk)
  first <- match(seq_along(uk), out$grp)
  g <- data.frame(code = px$code[first])
  for (nm in names(cell)) g[[nm]] <- cell[[nm]][first]
  g$S <- tabulate(out$grp, nbins = length(uk))
  g$O <- as.vector(rowsum(px$N, out$grp, reorder = TRUE))
  out$groups <- g
  out$n <- as.vector(rowsum(px$N, px$code, reorder = TRUE))
  out$S_shoe <- tabulate(px$code, nbins = n_code)
  out$row <- px$row
  out$code <- px$code
  out$Bx <- part2_bx(px$new_x, basis)
  out$y_levels <- attr(px, "y_levels")
  out$By_img <- part2_by(out$y_levels, basis)
  out$rac <- which(px$N > 0)
  out$rac_N <- px$N[out$rac]
  out$rac_code <- px$code[out$rac]
  out$basis <- basis
  out
}

part2_eval <- function(prep, parts, link = c("logit", "log"), offset = 0,
                       chunk = 1000000L) {
  link <- match.arg(link)
  npix <- nrow(prep$Bx)
  G <- nrow(prep$groups)
  Eg <- numeric(G)
  # pixels are processed in chunks so that a worker holds a few vectors of
  # the chunk's length, not of all pixels
  for (st in seq(1L, npix, by = chunk)) {
    i <- st:min(npix, st + chunk - 1L)
    eta <- part2_eta(prep$Bx[i, , drop = FALSE], prep$By_img, prep$row[i],
                     parts)
    v <- if (link == "logit") stats::plogis(eta + offset) else exp(eta)
    r <- rowsum(v, prep$grp[i], reorder = TRUE)
    k <- as.integer(rownames(r))
    Eg[k] <- Eg[k] + r[, 1]
  }
  eta_r <- part2_eta(prep$Bx[prep$rac, , drop = FALSE], prep$By_img,
                     prep$row[prep$rac], parts)
  lv <- if (link == "logit") {
    stats::plogis(eta_r + offset, log.p = TRUE)
  } else {
    eta_r
  }
  tot <- as.vector(rowsum(Eg, prep$groups$code, reorder = TRUE))
  lsum <- as.vector(rowsum(prep$rac_N * lv, prep$rac_code, reorder = TRUE))
  # every analysis shoe has RACs (OLD: 127 is not an analysis shoe)
  stopifnot(length(tot) == prep$n_code, length(lsum) == prep$n_code)
  list(Eg = Eg, tot = tot, lsum = lsum)
}

part2_agg <- function(prep, v, col) {
  K <- prep$K[[col]]
  n <- prep$n_code
  idx <- prep$groups$code + (prep$groups[[col]] - 1L) * n
  out <- numeric(n * K)
  r <- rowsum(v, idx, reorder = TRUE)
  out[as.integer(rownames(r))] <- r[, 1]
  matrix(out, n, K)
}

part2_sak <- function(prep, area_col, cell_col) {
  A <- prep$K[[area_col]]
  K <- prep$K[[cell_col]]
  n <- prep$n_code
  g <- prep$groups
  idx <- g$code + (g[[area_col]] - 1L) * n + (g[[cell_col]] - 1L) * n * A
  out <- numeric(n * A * K)
  r <- rowsum(g$S, idx, reorder = TRUE)
  out[as.integer(rownames(r))] <- r[, 1]
  array(out, c(n, A, K))
}

# Log-score terms per shoe (plan section 9): the sum over the shoe's RACs of
# log pi_i(j), pi_i(j) = v_ij / sum_j' v_ij' (continuous models), theta_a(j)
# / sum_a theta_a S_ia (regional), 1 / S_i (uniform).
part2_ls_model <- function(ev, n) ev$lsum - n * log(ev$tot)
part2_ls_regional <- function(theta, O_area, S_area) {
  as.vector(O_area %*% log(theta)) - rowSums(O_area) *
    log(as.vector(S_area %*% theta))
}
part2_ls_uniform <- function(n, S_shoe) -n * log(S_shoe)

# Gradient of the normalized expected cell counts with respect to the
# coefficients (plan section 9: G = dE~/dbeta): per shoe dE~_ik = (n_i /
# E_i) (dE_ik - pi_ik dE_i), dE_ik = sum over the pixels of p (1 - p) X_j
# (link "logit") or w X_j (link "log", the CML: there the intercept column
# is exactly 0; with the logit it is O(p), not 0). Returns a K x (1 + 24)
# matrix for the shoes in `use` (codes), cells of column `col`, from the
# step-3 basis.
part2_gradient <- function(prep, parts, col, use, offset = 0,
                           link = c("logit", "log")) {
  link <- match.arg(link)
  eta <- part2_eta(prep$Bx, prep$By_img, prep$row, parts)
  if (link == "logit") {
    p <- stats::plogis(eta + offset)
    wgt <- p * (1 - p)
  } else {
    p <- exp(eta)
    wgt <- p
  }
  K <- prep$K[[col]]
  na <- ncol(prep$Bx)
  nb <- ncol(prep$By_img)
  # per (shoe, cell): sums of p and of wgt * X_j (intercept, then a fastest)
  cell <- prep$groups[[col]][prep$grp]
  idx <- prep$code + (cell - 1L) * prep$n_code
  nn <- prep$n_code * K
  sumv <- function(v) {
    out <- numeric(nn)
    r <- rowsum(v, idx, reorder = TRUE)
    out[as.integer(rownames(r))] <- r[, 1]
    matrix(out, prep$n_code, K)
  }
  E <- sumv(p)
  dE <- array(0, c(prep$n_code, K, 1 + na * nb))
  dE[, , 1] <- sumv(wgt)
  j <- 1
  for (b in seq_len(nb)) {
    yb <- prep$By_img[prep$row, b]
    for (a in seq_len(na)) {
      j <- j + 1
      dE[, , j] <- sumv(wgt * prep$Bx[, a] * yb)
    }
  }
  n <- prep$n
  Ei <- rowSums(E)
  G <- matrix(0, K, 1 + na * nb)
  for (q in seq_len(dim(dE)[3])) {
    dEi <- rowSums(dE[, , q])
    pik <- E / Ei
    g <- (n / Ei) * (dE[, , q] - pik * dEi)
    G[, q] <- colSums(g[use, , drop = FALSE])
  }
  G
}

# --- one analysis: observed statistics and bootstrap replicates ---------------
#
# part2_obs_stats(O, Et, band, nbr, min_expected)
#     O, Et: shoes x K observed counts and normalized expected counts of the
#     shoes of one analysis set; cells merged on the pooled E (merge_cells);
#     returns the merge map, pooled O, E, D = O - E, X^2 (fixed surface),
#     phi0, the per-shoe residuals r'' = O - E~ - n_i D / N (A-051) and the
#     multinomial covariance Sigma_mult = sum_i n_i (diag(pi_i) - pi_i pi_i').
# part2_boot_one(ob, Eb, w)
#     one replicate: w = resample counts of the shoes, Eb = the shoes'
#     normalized expected counts at the replicate's OLD draw (merged cells;
#     ob$Em for the NEW-only bootstrap). Returns X2_two (centred two-sample,
#     plan section 9), X2_new (NEW-only, beta fixed), X2_unc (uncentred),
#     D_two (centred discrepancy per cell), O_unc and E_unc (uncentred
#     sums, for the per-cell O/E intervals).
# part2_weights(m, B, seed, groups)
#     B x m resample counts: shoes drawn with replacement, or, with groups
#     (one label per shoe), whole groups drawn with replacement (the pair
#     sensitivity, A-038).
# two_sample_bootstrap(O, Et_old, Et_draw, W, band, nbr)
#     the bootstrap of one analysis on cell tables (Et_draw(b): the shoes'
#     normalized expected counts at OLD draw b; NULL: beta fixed);
#     p_boot = (1 + #{X2* >= X2}) / (B + 1), E0 = mean X2*, phi = mean
#     X2_new* / (K' - 1).

part2_obs_stats <- function(O, Et, band, nbr = NULL, min_expected = 5) {
  O <- as.matrix(O)
  Et <- as.matrix(Et)
  mg <- merge_cells(colSums(Et), band, nbr, min_expected)
  Om <- O %*% mg$map
  Em <- Et %*% mg$map
  Ok <- colSums(Om)
  Ek <- colSums(Em)
  N <- sum(Ok)
  n <- rowSums(Om)
  pc <- pearson_pooled(Ok, Ek)
  pi <- Em / n
  D <- Ok - Ek
  list(map = mg$map, group = mg$group, K = ncol(O), K_merged = mg$K_merged,
       N = N, n = n, O = Ok, E = Ek, D = D, X2 = pc$X2, df = pc$df,
       p_chisq = pc$p, phi0 = phi0(pi, n, Ek), Om = Om, Em = Em,
       rpp = Om - Em - outer(n, D / N),
       Sigma = diag(Ek, length(Ek)) - crossprod(pi, n * pi))
}

part2_boot_one <- function(ob, Eb, w) {
  wc <- matrix(w, 1)
  D_two <- as.vector(wc %*% (ob$rpp - (Eb - ob$Em)))
  E_two <- as.vector(wc %*% Eb)
  E_new <- as.vector(wc %*% ob$Em)
  r_new <- as.vector(wc %*% ob$rpp)
  O_unc <- as.vector(wc %*% ob$Om)
  list(X2_two = sum(D_two^2 / E_two), X2_new = sum(r_new^2 / E_new),
       X2_unc = sum((O_unc - E_two)^2 / E_two), D_two = D_two,
       O_unc = O_unc, E_unc = E_two)
}

part2_weights <- function(m, B, seed, groups = NULL) {
  if (is.null(groups)) {
    ids <- part2_resample_ids(m, B, seed)
    W <- t(apply(ids, 1, tabulate, nbins = m))
  } else {
    stopifnot(length(groups) == m)
    g <- match(groups, unique(groups))
    G <- max(g)
    ids <- part2_resample_ids(G, B, seed)
    cnt <- t(apply(ids, 1, tabulate, nbins = G))
    W <- cnt[, g, drop = FALSE]
  }
  storage.mode(W) <- "double"
  W
}

two_sample_bootstrap <- function(O, Et_old, Et_draw = NULL, W, band,
                                 nbr = NULL, min_expected = 5) {
  ob <- part2_obs_stats(O, Et_old, band, nbr, min_expected)
  B <- nrow(W)
  X2_two <- X2_new <- X2_unc <- numeric(B)
  D_two <- ratio <- matrix(NA_real_, B, ob$K_merged)
  for (b in seq_len(B)) {
    Eb <- if (is.null(Et_draw)) ob$Em else as.matrix(Et_draw(b)) %*% ob$map
    r <- part2_boot_one(ob, Eb, W[b, ])
    X2_two[b] <- r$X2_two
    X2_new[b] <- r$X2_new
    X2_unc[b] <- r$X2_unc
    D_two[b, ] <- r$D_two
    ratio[b, ] <- r$O_unc / r$E_unc
  }
  dfm <- ob$K_merged - 1
  list(obs = ob, X2_two = X2_two, X2_new = X2_new, X2_unc = X2_unc,
       D_two = D_two, ratio = ratio,
       p_boot = (1 + sum(X2_two >= ob$X2)) / (B + 1),
       E0 = mean(X2_two), phi = mean(X2_new) / dfm, phi0 = ob$phi0,
       ratio_ci = apply(ratio, 2, stats::quantile, c(0.025, 0.975),
                        na.rm = TRUE))
}

# Basic-bootstrap interval of the net misfit X^2 - E0 from the uncentred
# replicates (their mean is about X^2 + E0), mapped to w_net and the
# RMSEA-type index (plan section 9, effect sizes; T7 decision).
part2_effect_ci <- function(X2, E0, X2_unc, df, N, level = 0.95) {
  a <- (1 - level) / 2
  T_obs <- X2 - E0
  T_star <- X2_unc - E0 - X2 + T_obs
  q <- stats::quantile(T_star, c(1 - a, a), names = FALSE)
  lim <- pmax(2 * T_obs - q, 0)
  list(net_lo = lim[1], net_hi = lim[2],
       w_net_lo = sqrt(lim[1] / N), w_net_hi = sqrt(lim[2] / N),
       rmsea_lo = sqrt(lim[1] / (df * (N - 1))),
       rmsea_hi = sqrt(lim[2] / (df * (N - 1))))
}

# --- cached pixel tables and the shoe sets --------------------------------------
#
# part2_pixel_table_cached(P, rebuild)
#     the pixel table, cached in part2_path(P, "pixels_full", "rds") (not
#     tracked: .gitignore) with the md5 of every input it was built from;
#     rebuilt when an input changed.
# part2_shoe_set(P_new, P_old)
#     the PROVISIONAL Part 2 shoe set (T7 decision; the frozen T3 set
#     processed_data/new/part2_shoe_set_new.csv of plan T3 step 3d does not
#     exist): the overlap decision from the T0 review (same_shoe, uncertain,
#     different_shoe; flagged but not reviewed: unreviewed_candidate; else
#     none) and the automatic part of the quality rule A-029 (fail if
#     n >= 10 and the best on-contact rate under shifts up to 4 px is below
#     q, the 5th percentile of the same over OLD shoes with >= 10 RACs; the
#     census part, partial prints with RACs on unprinted sole, was never
#     made). Primary: overlap not same_shoe or uncertain, quality pass.
#     Sensitivity columns: in_all, in_same_only (only same_shoe excluded),
#     in_quality_off, in_quality_raw (raw rate below the OLD p5 of the raw
#     rate, A-029), in_excl_candidates (also every unreviewed candidate).

part2_inputs_md5 <- function(P) {
  keys <- c("contacts", "locations", "contour", "all_cont", "pixel_counts",
            "dataCC_distance", "prototype_contour")
  if (!is.null(P$inputs$sticker_masks)) keys <- c(keys, "sticker_masks")
  f <- vapply(keys, function(k) rac_path(P, k), "")
  out <- unname(tools::md5sum(f))
  names(out) <- keys
  out
}

part2_pixel_table_cached <- function(P, rebuild = FALSE) {
  path <- part2_path(P, "pixels_full", "rds")
  md5 <- part2_inputs_md5(P)
  if (!rebuild && file.exists(path)) {
    px <- readRDS(path)
    if (identical(attr(px, "inputs_md5"), md5)) return(px)
    message("part2: the pixel table cache of ", P$dataset,
            " is stale or unlabelled; rebuilding it")
  }
  px <- part2_pixel_table(P)
  attr(px, "inputs_md5") <- md5
  rac_ensure_dir(path)
  saveRDS(px, path, compress = FALSE)
  px
}

part2_shoe_set <- function(P_new, P_old) {
  qn <- utils::read.csv(paste(P_new$root, P_new$prep$shoe_contact, sep = ""))
  qo <- utils::read.csv(paste(P_old$root, P_old$prep$shoe_contact, sep = ""))
  cand <- utils::read.csv(paste(P_new$root, "docs/qa/T0/compare/", # rac: literal-ok T0 evidence, no profile key
                                "overlap_candidates_t0_old_vs_new.csv", # rac: literal-ok
                                sep = ""), stringsAsFactors = FALSE)
  stopifnot(!anyDuplicated(cand$new), identical(qn$shoe, seq_len(P_new$num_shoe)))
  q <- as.numeric(stats::quantile(qo$best_shift_rate[qo$n_rac >= 10], 0.05))
  q_raw <- as.numeric(stats::quantile(qo$rate[qo$n_rac > 0], 0.05))
  dec <- rep("none", nrow(qn))
  k <- match(qn$shoe, cand$new)
  v <- cand$verdict[k]
  dec[!is.na(k)] <- ifelse(nzchar(v[!is.na(k)]), v[!is.na(k)],
                           "unreviewed_candidate")
  partner <- cand$old[k]
  fail <- qn$n_rac >= 10 & qn$best_shift_rate < q
  fail_raw <- qn$rate < q_raw
  overlap_out <- dec %in% c("same_shoe", "uncertain")
  out <- data.frame(shoe = qn$shoe, n_rac = qn$n_rac, rate = qn$rate,
                    best_shift_rate = qn$best_shift_rate,
                    overlap_decision = dec, old_partner = partner,
                    quality_flag = ifelse(fail, "fail", "pass"),
                    quality_q = q, raw_rate_flag = ifelse(fail_raw, "fail",
                                                          "pass"),
                    raw_rate_q = q_raw, stringsAsFactors = FALSE)
  out$include_primary <- !overlap_out & !fail
  out$in_all <- TRUE
  out$in_same_only <- dec != "same_shoe" & !fail
  out$in_quality_off <- !overlap_out
  out$in_quality_raw <- !overlap_out & !fail_raw
  out$in_excl_candidates <- !(dec %in% c("same_shoe", "uncertain",
                                         "unreviewed_candidate")) & !fail
  out$reason <- ifelse(out$include_primary, "included",
                       paste(ifelse(overlap_out, paste("overlap", dec), ""),
                             ifelse(fail, "quality fail", ""), sep = "; "))
  out$reason <- sub("^; |; $", "", out$reason)
  out
}

# --- the OLD-only definitions, frozen before any NEW Part 2 number ------------
#
# part2_definitions(px_old, basis)
#     list(cuts, theta): the grid cuts of A-008 (K = 15 = 5 y bands x 3 new_x
#     bands, pre-registered; sensitivities K = 10 = 5 x 2 and K = 20 = 5 x 4)
#     over the OLD contact pixels, read back through the CSV round trip; and
#     the regional theta fitted on all OLD shoes: r2022 (the 2022 model,
#     Naomi's areas on the shoe's own coordinates (-x, y), A-025), r_newx
#     (Naomi's areas on (-new_x, y), A-010) and r_grid15 (the 15-cell grid),
#     with the relative theta of a Poisson GLM and of Naomi's funLogCMLlambda
#     (optim, as in 2022) for comparison.
# naomi_funLogCMLlambda(l_lambda_minus1, contact_mat, n_ij)
#     Naomi's function (larger-areas code of 2022), ported line for line.

naomi_funLogCMLlambda <- function(l_lambda_minus1, contact_mat, n_ij) {
  l_lambda <- c(0, l_lambda_minus1)
  -sum(n_ij * (log(contact_mat * (
    t(as.matrix(exp(l_lambda)) %*% rep(1, nrow(contact_mat))) / (
      (contact_mat %*% exp(l_lambda)) %*% rep(1, ncol(contact_mat)))))),
    na.rm = TRUE)
}

part2_definitions <- function(px_old, basis) {
  parts <- lapply(2:4, function(n_x) {
    ck <- grid_cuts_from_old(px_old$new_x, px_old$y, 5, n_x)
    for (j in 1:3) {
      nm <- paste("x_cut", j, sep = "_")
      if (is.null(ck[[nm]])) ck[[nm]] <- NA_real_
    }
    ck
  })
  cuts <- part2_csv_round_trip(do.call(rbind, parts))
  n_code <- length(attr(px_old, "shoes"))
  prep <- part2_prepare(px_old, basis, cuts, n_code)
  th <- NULL
  for (spec in list(c("r2022", "aR"), c("r_newx", "a14"),
                    c("r_grid15", "g15"))) {
    O <- part2_agg(prep, prep$groups$O, spec[2])
    S <- part2_agg(prep, prep$groups$S, spec[2])
    theta <- regional_fit(O, S)
    cells <- data.frame(O = as.vector(O), S = as.vector(S),
                        shoe = factor(rep(seq_len(nrow(O)), ncol(O))),
                        area = factor(rep(seq_len(ncol(O)), each = nrow(O))))
    cells <- cells[cells$S > 0, ]
    gl <- stats::glm(O ~ shoe + area + offset(log(S)), family = stats::poisson,
                     data = cells)
    ga <- stats::coef(gl)[paste("area", seq_len(ncol(O))[-1], sep = "")]
    start <- log((colSums(O) / colSums(S))[-1] / (colSums(O) / colSums(S))[1])
    op <- stats::optim(start, naomi_funLogCMLlambda, contact_mat = S / 10000,
                       n_ij = O, method = "BFGS",
                       control = list(reltol = 1e-14, maxit = 1000))
    th <- rbind(th, data.frame(model = spec[1], partition = spec[2],
                               area = seq_len(ncol(O)), theta = theta,
                               theta_rel = theta / theta[1],
                               glm_rel = c(1, exp(unname(ga))),
                               naomi_cml_rel = c(1, exp(op$par)),
                               O_old = colSums(O), S_old = colSums(S),
                               iterations = attr(theta, "iterations")))
  }
  rownames(th) <- NULL
  list(cuts = cuts, theta = part2_csv_round_trip(th))
}

# A data frame as write.csv writes it and read.csv reads it back.
part2_csv_round_trip <- function(df) {
  tf <- tempfile(fileext = ".csv")
  on.exit(unlink(tf))
  utils::write.csv(df, tf, row.names = FALSE)
  utils::read.csv(tf, stringsAsFactors = FALSE)
}

# Write a frozen definition file once; afterwards only check it (stop if the
# recomputed table differs from the file).
part2_freeze <- function(df, path) {
  if (file.exists(path)) {
    old <- utils::read.csv(path, stringsAsFactors = FALSE)
    if (!isTRUE(all.equal(old, df, tolerance = 0, check.attributes = FALSE))) {
      stop("part2_freeze: ", path, " differs from its recomputation; the ",
           "frozen definitions must not change (delete it only by a recorded ",
           "decision)", call. = FALSE)
    }
    return(invisible("checked"))
  }
  rac_ensure_dir(path)
  con <- file(path, "wb")
  on.exit(close(con))
  utils::write.csv(df, con, row.names = FALSE, eol = "\n")
  invisible("written")
}

# Bias-shifted percentile interval of the net misfit (T7-7, revised after
# the first NEW results): the uncentred two-sample replicates X2_unc are
# centred near X^2 + E0 and right-skewed, so the misfit's interval is the
# percentile interval of X2_unc - 2 E0 (the replicate statistic minus the
# noise floor, shifted by the bootstrap world's extra noise E0), truncated
# at 0, mapped to w_net and the RMSEA-type index. The basic interval of
# part2_effect_ci() reflects the long right tail to the left (its lower
# bound reached 0 on NEW although no centred replicate came near X^2).
part2_effect_ci_pct <- function(E0, X2_unc, df, N, level = 0.95) {
  a <- (1 - level) / 2
  lim <- pmax(stats::quantile(X2_unc, c(a, 1 - a), names = FALSE) - 2 * E0, 0)
  list(net_lo = lim[1], net_hi = lim[2],
       w_net_lo = sqrt(lim[1] / N), w_net_hi = sqrt(lim[2] / N),
       rmsea_lo = sqrt(lim[1] / (df * (N - 1))),
       rmsea_hi = sqrt(lim[2] / (df * (N - 1))))
}

# --- T7 review fixes: interval estimands, benchmarks, calibration slopes ------
#
# (statistics review of T7, 2026-11-07; decisions T7-13 to T7-17 in
# docs/results/validation.md)
#
# part2_shift_ci(v, point, level)
#     the percentile interval of the bootstrap replicates v shifted so that
#     their mean equals the point estimate (bias-shifted percentile). A
#     replicate carries one more layer of the noise it resamples than the
#     point estimate: a model refitted on an OLD resample predicts NEW worse
#     than the fit on all OLD shoes, and a resampled X^2 adds a second noise
#     floor. The raw percentile interval is then not centred on the point,
#     and its significance pattern comes from the interval method (review
#     finding 1). Every interval of a model comparison uses this rule, on
#     the NEW-only replicates (the published fitted surfaces held fixed) and
#     on the two-sample replicates (the model classes, OLD estimation noise
#     included).
# part2_uniform_expected(S_cells, S_shoe, n)
#     uniform placement on the contact surface (no spatial model):
#     E_ik = n_i S_ik / S_i, the benchmark of the spatial signal.
# part2_calib_slope(O, EM, EU, w, start, tol, maxit)
#     the calibration slope alpha of a model's expected cell counts EM
#     (shoes x cells) against counts O, conditional on each shoe's total:
#     P_ik(alpha) = EU_ik exp(alpha L_ik) / sum_k' EU_ik' exp(alpha L_ik'),
#     L_ik = log(EM_ik / EU_ik), EU the uniform expected counts (cells with
#     EU = 0, no contact pixel of the shoe, drop out); alpha maximizes
#     sum_i w_i sum_k O_ik log P_ik(alpha) (= the Poisson GLM O ~ shoe +
#     offset(log EU) + alpha L). alpha = 1: the model's contrasts hold;
#     alpha < 1: they are too strong (RACs spread more evenly than the
#     model says); alpha = 0: no better than uniform. O may be fractional or
#     negative (the bootstrap's H0 pseudo-counts O - n_i D / N): the
#     curvature, sum_i w_i n_i Var_Pi(L), depends on the row sums n_i only,
#     so the objective stays concave. Newton from `start`. Returns alpha,
#     se = information^(-1/2) (independent RACs), the fitted expected counts
#     n_i P_ik(alpha) and the iterations.
# part2_pixel_slope(lp, code, s, n, w, start, tol, maxit)
#     the same at the pixel level: P_ij(alpha) proportional to
#     exp(alpha lp_ij) over the contact pixels j of shoe i (lp = the model's
#     log pixel probability, or any log intensity; a constant per shoe
#     cancels); s_i = sum over the RACs r of shoe i of N_r lp_r (or, for the
#     OLD-noise dilution, sum_j q_ij lp_ij with fractional counts q_ij =
#     n_i pi_ij of the true surface); n_i the RACs of shoe i; w a weight per
#     shoe code (0 drops the shoe). Newton with the exact score and
#     information per iteration (three sums over the pixels).
# part2_pixel_slope_grid(lp, code, s, n, use, grid)
#     per-shoe moments of lp under P_i(alpha) at the grid points (centred
#     per shoe), for the shoe bootstrap; part2_pixel_slope_boot(gr, W)
#     solves the score of every resample (rows of W, columns = the shoes
#     `use`): the grid interval where the (decreasing) score changes sign,
#     then the root of the cubic Hermite interpolant of the score there
#     (exact score and information at both ends; equal to the exact fit per
#     resample to < 1e-6, tests/r/test_validation_stats.R).
# part2_block_groups(shoe, size)
#     consecutive-id blocks (shoe - 1) %/% size: a proxy for one-wearer
#     pairs and design batches (A-038) until T3 freezes the pair list.
# part2_shoe_sums(v, code, n_code)
#     the sum of v per shoe code (1..n_code; 0 for a code without values).
# part2_kl_uniform(lp, code, n_code)
#     per shoe, the expected log-score gain of the model over uniform
#     placement if the model were right: KL(pi_i || 1 / S_i) = sum_j pi_ij
#     log(pi_ij S_i), pi_i proportional to exp(lp) over the shoe's contact
#     pixels (the benchmark of the observed gain LS_model - LS_uniform).

part2_shift_ci <- function(v, point, level = 0.95) {
  a <- (1 - level) / 2
  shift <- mean(v) - point
  q <- stats::quantile(v, c(a, 1 - a), names = FALSE)
  list(lo = q[1] - shift, hi = q[2] - shift, shift = shift, sd = stats::sd(v))
}

part2_uniform_expected <- function(S_cells, S_shoe, n) {
  S_cells <- as.matrix(S_cells)
  stopifnot(nrow(S_cells) == length(S_shoe), length(n) == length(S_shoe),
            all(S_shoe > 0))
  S_cells * (n / S_shoe)
}

part2_calib_slope <- function(O, EM, EU, w = NULL, start = 1, tol = 1e-10,
                              maxit = 100L) {
  O <- as.matrix(O)
  EM <- as.matrix(EM)
  EU <- as.matrix(EU)
  stopifnot(identical(dim(O), dim(EM)), identical(dim(O), dim(EU)))
  if (is.null(w)) w <- rep(1, nrow(O))
  pos <- EU > 0
  if (any(EM[pos] <= 0)) stop("part2_calib_slope: a model count is 0 on contact")
  if (any(abs(O[!pos]) > 1e-9)) stop("part2_calib_slope: counts off contact")
  L <- matrix(0, nrow(O), ncol(O))
  L[pos] <- log(EM[pos] / EU[pos])
  n <- rowSums(O)
  sOL <- sum(w * rowSums(O * L))
  a <- start
  for (it in seq_len(maxit)) {
    E <- EU * exp(a * L)
    s0 <- rowSums(E)
    m1 <- rowSums(E * L) / s0
    v <- pmax(rowSums(E * L^2) / s0 - m1^2, 0)
    score <- sOL - sum(w * n * m1)
    info <- sum(w * n * v)
    step <- score / info
    a <- a + step
    if (abs(step) < tol) break
  }
  E <- EU * exp(a * L)
  list(alpha = a, se = 1 / sqrt(info), fitted = E * (n / rowSums(E)),
       iterations = it, converged = abs(step) < tol)
}

part2_shoe_sums <- function(v, code, n_code) {
  out <- numeric(n_code)
  if (!is.unsorted(code)) {
    # the pixel tables are ordered by shoe: sums from one cumulative sum (4
    # times faster than rowsum on millions of pixels; equal to it within
    # 1e-12 relative, tests/r/test_validation_stats.R)
    cnt <- tabulate(code, nbins = n_code)
    hit <- cnt > 0
    out[hit] <- diff(c(0, cumsum(v)[cumsum(cnt)[hit]]))
    return(out)
  }
  r <- rowsum(v, code, reorder = TRUE)
  out[as.integer(rownames(r))] <- r[, 1]
  out
}

part2_pixel_slope <- function(lp, code, s, n, w = NULL, start = 1,
                              tol = 1e-10, maxit = 100L) {
  n_code <- length(n)
  stopifnot(length(s) == n_code, length(lp) == length(code))
  if (is.null(w)) w <- rep(1, n_code)
  keep <- w[code] > 0
  lp <- lp[keep]
  code <- code[keep]
  # centring per shoe keeps exp() and the variance sums well conditioned
  # (the shoe's constant cancels in P_i)
  cnt <- part2_shoe_sums(rep(1, length(code)), code, n_code)
  mu <- part2_shoe_sums(lp, code, n_code) / pmax(cnt, 1)
  lc <- lp - mu[code]
  sc <- s - n * mu
  ws <- w > 0
  a <- start
  for (it in seq_len(maxit)) {
    e <- exp(a * lc)
    s0 <- part2_shoe_sums(e, code, n_code)
    s1 <- part2_shoe_sums(e * lc, code, n_code)
    s2 <- part2_shoe_sums(e * lc^2, code, n_code)
    m1 <- s1[ws] / s0[ws]
    v <- pmax(s2[ws] / s0[ws] - m1^2, 0)
    score <- sum(w[ws] * (sc[ws] - n[ws] * m1))
    info <- sum(w[ws] * n[ws] * v)
    step <- score / info
    a <- a + step
    if (abs(step) < tol) break
  }
  list(alpha = a, se = 1 / sqrt(info), iterations = it,
       converged = abs(step) < tol)
}

part2_pixel_slope_grid <- function(lp, code, s, n, use, grid) {
  n_code <- length(n)
  keep <- code %in% use
  lp <- lp[keep]
  code <- code[keep]
  cnt <- part2_shoe_sums(rep(1, length(code)), code, n_code)
  mu <- part2_shoe_sums(lp, code, n_code) / pmax(cnt, 1)
  lc <- lp - mu[code]
  M1 <- V <- matrix(NA_real_, length(use), length(grid))
  for (g in seq_along(grid)) {
    e <- exp(grid[g] * lc)
    s0 <- part2_shoe_sums(e, code, n_code)[use]
    s1 <- part2_shoe_sums(e * lc, code, n_code)[use]
    s2 <- part2_shoe_sums(e * lc^2, code, n_code)[use]
    M1[, g] <- s1 / s0
    V[, g] <- pmax(s2 / s0 - M1[, g]^2, 0)
  }
  list(grid = grid, M1 = M1, V = V, sc = (s - n * mu)[use], n = n[use])
}

part2_pixel_slope_boot <- function(gr, W) {
  W <- as.matrix(W)
  stopifnot(ncol(W) == length(gr$n))
  SC <- as.vector(W %*% gr$sc) - W %*% (gr$n * gr$M1)
  IN <- W %*% (gr$n * gr$V)
  G <- length(gr$grid)
  # the root must lie inside the grid: a positive score at the first grid
  # point and a negative one at the last
  if (any(SC[, 1] <= 0) || any(SC[, G] >= 0)) {
    stop("part2_pixel_slope_boot: a resample's slope lies outside the grid")
  }
  # the bracketing interval (the score decreases in alpha), then the root of
  # the cubic Hermite interpolant of the score on it (values and exact
  # derivatives -information at both ends; error of order h^4)
  g <- rowSums(SC > 0)
  r <- seq_len(nrow(W))
  s0 <- SC[cbind(r, g)]
  s1 <- SC[cbind(r, g + 1L)]
  h <- gr$grid[g + 1L] - gr$grid[g]
  d0 <- -IN[cbind(r, g)] * h
  d1 <- -IN[cbind(r, g + 1L)] * h
  t <- s0 / (s0 - s1)
  for (it in 1:30) {
    p <- (2 * t^3 - 3 * t^2 + 1) * s0 + (t^3 - 2 * t^2 + t) * d0 +
      (-2 * t^3 + 3 * t^2) * s1 + (t^3 - t^2) * d1
    dp <- (6 * t^2 - 6 * t) * s0 + (3 * t^2 - 4 * t + 1) * d0 +
      (-6 * t^2 + 6 * t) * s1 + (3 * t^2 - 2 * t) * d1
    t <- pmin(pmax(t - p / dp, 0), 1)
    if (max(abs(p / dp)) < 1e-12) break
  }
  gr$grid[g] + t * h
}

part2_block_groups <- function(shoe, size) {
  stopifnot(size >= 1)
  as.integer((shoe - 1L) %/% size)
}

part2_kl_uniform <- function(lp, code, n_code) {
  cnt <- part2_shoe_sums(rep(1, length(code)), code, n_code)
  mu <- part2_shoe_sums(lp, code, n_code) / pmax(cnt, 1)
  lc <- lp - mu[code]
  e <- exp(lc)
  s0 <- part2_shoe_sums(e, code, n_code)
  s1 <- part2_shoe_sums(e * lc, code, n_code)
  out <- s1 / s0 - log(s0) + log(cnt)
  out[cnt == 0] <- NA_real_
  out
}
