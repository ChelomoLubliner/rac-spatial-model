# The committed NEW outputs of steps 1-6 (plan T5 step 1, review focus 3
# and 4; decisions A-110, A-111, A-112, A-113).
#
# 1. Step 1 (processed_data/new/): dataCC_new.csv has one code per analysis
#    shoe, n_controls controls per shoe and one case per distinct RAC pixel
#    (19,990 with the legacy mapping kept by T3, A-087); shoe_codes_new.csv
#    maps code k to the k-th analysis shoe; the contact surface S
#    recomputed here (raw records, erase list, all_cont_new.csv, RAC pixels
#    by step 1's own aspix) gives exactly shoe_pixel_counts_new.csv; every
#    control lies on S and on no RAC pixel, every case on a RAC pixel;
#    all_cont_new.csv is the set of pixels in contact on >= r.stamp_threshold
#    shoes (A-110: the sweep removes nothing on NEW). A check of its own:
#    the seven NEW CSVs of steps 1, 2 and 5 exist and have LF line endings
#    only.
# 2. Step 2: dataCC_distance_new.csv keeps (n_Acc, x, y, shoe) of
#    dataCC_new.csv; min_dist, horiz_dist, distance_shape, new_x are finite;
#    horiz_dist >= min_dist; every distance_shape value is a per-row half
#    width of the OLD prototype contour in its own 307 x 395 frame after the
#    CSV round trip (the prototype frame was used, A-006); the contour file
#    holds length(rac_analysis_shoes(P)) records (A-053); step 2 recomputed
#    here for EVERY shoe from the committed contour (compute_distances(),
#    step 2's shape chunk, rac_write_csv(), as the vectorized step 2 runs)
#    writes dataCC_distance_temp_new.csv and dataCC_distance_new.csv byte
#    for byte, so a step 2 left stale by a change of any contour record
#    fails here (A-113; the T5 version checked only 25 shoes).
# 3. Step 3 and the OLD-basis refits (saved_models/new/), each a check of
#    its own: the step-3 GLMM converged (code 0, no lme4 message), 25 fixed
#    effects, 631 groups, and it was fitted on the committed CSV: its
#    response = n_Acc, its grouping factor = the shoe codes and getME(X) =
#    the step-3 design rebuilt from dataCC_distance_new.csv with the
#    step-3 basis; the CML has 24 coefficients, model.matrix() = that design
#    without the intercept, its status = n_Acc, its strata = the shoe codes,
#    n and nevent; the OLD-basis refits (A-112) the same against the design
#    on the OLD basis (knots of processed_data/dataCC_distance.csv). So a
#    model left stale by a change of the CSV fails here (A-113). A negative
#    control shows that each comparison is not vacuous: it rejects copies
#    of the CSV with one shoe's new_x moved by a pixel, one case and one
#    control swapped, or one row moved to another shoe.
# 4. Step 5: wald_test_new.csv has df 24 and the W of wald_all_spatial() on
#    the NEW GLMM; its vcov label says which vcov lme4 used.
# 5. Steps 4-6: the 8 NEW PDFs exist and are PDFs, and their PNG twins
#    (tools/figures_png.R, A-111) exist in docs/qa/T5/new/. Existence only:
#    a stale or swapped figure passes (plan T8's tests/e2e/test_new_rerun.sh
#    will re-render and compare them; until then, rerun
#    docs/qa/T5/probes/t5_new_rerun.sh --oldbasis --png after any change of
#    a NEW model).
# 6. No collision: every tracked or new file in the NEW output folders of
#    T5 has a stem ending in the NEW suffix, and the OLD output folders hold
#    only the OLD files (Tier A, the write-once lists
#    tests/baseline/old_added_*.sha256 of the tasks that add OLD files,
#    README files).
# Every check runs even when an earlier one fails (each prints PASS or FAIL
# with its reason, so a stale chain shows every stale output at once): a
# check that needs a CSV which is missing or unreadable FAILs with that
# reason (second T5 review fixes, A-113 corrected). The script exits 1 if
# any failed. Writes only below tempdir().
#
# Run from anywhere:  Rscript tests/r/test_new_outputs.R
suppressMessages({
  library(dplyr)
  library(splines)
  library(lme4)
  library(survival)
})
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "io.R", "distances.R", "wald.R", "compare.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
source(file.path(root, "tests", "lib", "rmd_chunk.R"))
P <- rac_profile("new", root = ROOT_PATH)
P_old <- rac_profile("old", root = ROOT_PATH)
W <- P$col_shoe
H <- P$row_shoe
shoes <- rac_analysis_shoes(P)
n_shoes <- length(shoes)
csv_round_trip <- function(df) {
  f <- tempfile(fileext = ".csv")
  write.csv(df, f, row.names = FALSE)
  read.csv(f, header = TRUE)
}
same_bytes <- function(a, b) {
  file.exists(a) && file.exists(b) && file.size(a) == file.size(b) &&
    identical(readBin(a, "raw", file.size(a)), readBin(b, "raw", file.size(b)))
}

# check(name, expr): evaluates expr (in this script's environment, so its
# assignments stay visible to the later checks); its value is the detail
# printed after PASS; an error prints FAIL with the reason and is counted.
failed <- character(0)
check <- function(name, expr) {
  out <- tryCatch(list(ok = TRUE, value = force(expr)),
                  error = function(e) list(ok = FALSE,
                                           value = conditionMessage(e)))
  if (out$ok) {
    cat("PASS", out$value, "\n")
  } else {
    cat("FAIL", name, ":", out$value, "\n")
    failed <<- c(failed, name)
  }
  invisible(out$ok)
}

# the step-3 design (plan F28): intercept, then bx[, j] * by[, i] with
# new_x varying fastest, on the given knots and boundary knots
design <- function(nx, y, b) {
  bx <- ns(nx, knots = b$knots_x, Boundary.knots = b$bknots_x)
  by <- ns(y, knots = b$knots_y, Boundary.knots = b$bknots_y)
  X <- matrix(1, length(nx), 1)
  for (i in seq_len(ncol(by))) {
    for (j in seq_len(ncol(bx))) X <- cbind(X, bx[, j] * by[, i])
  }
  X
}
# Was model m fitted on the rows of d with the basis b? One flag per
# property; all TRUE when it was.
glmm_vs_csv <- function(m, d, b) {
  Xm <- unname(as.matrix(getME(m, "X")))
  X <- design(d$new_x, d$y, b)
  c(y = identical(as.numeric(getME(m, "y")), as.numeric(d$n_Acc)),
    shoe = identical(as.character(getME(m, "flist")[[1]]),
                     as.character(d$shoe)),
    X = identical(dim(Xm), dim(X)) && max(abs(X - Xm)) == 0)
}
cml_vs_csv <- function(m, d, b) {
  mm <- unname(model.matrix(m))
  X <- design(d$new_x, d$y, b)[, -1, drop = FALSE]
  mf <- model.frame(m)
  c(status = identical(as.numeric(m$y[, "status"]), as.numeric(d$n_Acc)),
    strata = identical(as.character(mf[["strata(shoe)"]]),
                       paste("shoe=", d$shoe, sep = "")),
    X = identical(dim(mm), dim(X)) && max(abs(X - mm)) == 0,
    n = m$n == nrow(d) && m$nevent == sum(d$n_Acc))
}
fails_of <- function(flags) {
  if (all(flags)) return(NULL)
  paste(names(flags)[!flags], collapse = ", ")
}

# --- 1. step 1 ---------------------------------------------------------------
dataCC <- NULL     # set by check "step 1" when dataCC_new.csv can be read
check("step 1", {
  dataCC <- read.csv(rac_path(P, "dataCC"), header = TRUE)
  codes <- read.csv(rac_path(P, "shoe_codes"), header = TRUE)
  counts <- read.csv(rac_path(P, "pixel_counts"), header = TRUE)
  mask <- as.matrix(read.csv(rac_path(P, "all_cont"), header = TRUE))
  stopifnot(identical(names(dataCC), c("n_Acc", "x", "y", "shoe")),
            identical(codes$code, seq_len(n_shoes)),
            identical(codes$shoe, shoes),
            identical(sort(unique(dataCC$shoe)), seq_len(n_shoes)),
            all(dataCC$n_Acc %in% c(0, 1)),
            all(table(dataCC$shoe[dataCC$n_Acc == 0]) == P$r$n_controls),
            identical(counts$shoe, shoes), all(counts$pixel_count > 0),
            all(dim(mask) == c(H, W)), all(mask %in% c(0, 1)))
  # the raw records, the erase list, the stamp mask and the RAC pixels
  con <- file(rac_path(P, "contacts"), "rb")
  bytes <- readBin(con, "raw", P$num_shoe * (W * H + 2))
  close(con)
  stopifnot(length(bytes) == P$num_shoe * (W * H + 2))
  raw <- lapply(seq_len(P$num_shoe), function(i) {
    matrix(as.numeric(bytes[(i - 1) * (W * H + 2) + seq_len(W * H)] ==
                        as.raw(49)), H, W, byrow = TRUE)
  })
  sticker <- rac_read_sticker_masks(P)
  if (!is.null(sticker)) raw <- rac_apply_sticker_masks(raw, sticker)
  for (i in P$r$contact_flip_shoes) raw[[i]] <- raw[[i]][, W:1]
  sum_raw <- Reduce(`+`, raw)
  stopifnot(identical(unname(mask == 1),
                      unname(sum_raw >= P$r$stamp_threshold)))
  eval(parse(text = rmd_chunk(file.path(root, "statistical_model",
                                        "dataCC_1.Rmd"), "2.init_functions")))
  loc <- read_locations(P)
  rac_col <- aspix_x(loc$x)
  rac_row <- aspix_y(loc$y)
  scale <- P$coords$rel_col_shoe / P$coords$rel_Y_cord
  cc_col <- round(dataCC$x * scale + W / 2)
  cc_row <- round(H / 2 - dataCC$y * scale)
  stopifnot(all(abs(dataCC$x * scale + W / 2 - cc_col) < 1e-6),
            all(abs(H / 2 - dataCC$y * scale - cc_row) < 1e-6))
  n_px <- integer(n_shoes)
  on_s <- logical(nrow(dataCC))
  on_rac <- logical(nrow(dataCC))
  for (k in seq_len(n_shoes)) {
    s <- shoes[k]
    rac <- matrix(FALSE, H, W)
    sel <- loc$shoe == s
    rac[cbind(rac_row[sel], rac_col[sel])] <- TRUE
    S <- (raw[[s]] * mask == 1) | rac
    n_px[k] <- sum(S)
    rows <- which(dataCC$shoe == k)
    idx <- cbind(cc_row[rows], cc_col[rows])
    on_s[rows] <- S[idx]
    on_rac[rows] <- rac[idx]
  }
  n_cases <- sum(!duplicated(data.frame(loc$shoe, rac_row, rac_col)))
  stopifnot(identical(as.numeric(n_px), as.numeric(counts$pixel_count)),
            all(on_s), identical(on_rac, dataCC$n_Acc == 1),
            sum(dataCC$n_Acc) == n_cases,
            nrow(dataCC) == n_cases + n_shoes * P$r$n_controls)
  rm(raw, bytes, sum_raw)
  invisible(gc())
  sprintf(paste("step 1: %d shoes, %d controls each, %d cases (the",
                "distinct RAC pixels), %d rows; S recomputed from the raw",
                "records, the erase list, the stamp mask (>= %d shoes,",
                "no pixel swept) and the RAC pixels = the pixel counts;",
                "every control on S and on no RAC pixel"),
          n_shoes, P$r$n_controls, n_cases, nrow(dataCC),
          P$r$stamp_threshold)
})
check("LF line endings", {
  keys <- c("dataCC", "pixel_counts", "all_cont", "shoe_codes",
            "dataCC_distance_temp", "dataCC_distance", "wald_test")
  paths <- vapply(keys, rac_path, "", P = P)
  if (!all(file.exists(paths))) {
    stop("missing: ", paste(basename(paths[!file.exists(paths)]),
                            collapse = ", "))
  }
  for (key in keys) {
    b <- readBin(paths[[key]], "raw", file.size(paths[[key]]))
    stopifnot(identical(P$r$eol[[key]], "\n"), !any(b == as.raw(13)))
  }
  sprintf("LF line endings: the %d NEW CSVs of steps 1, 2 and 5 have LF only",
          length(keys))
})

# --- 2. step 2 ---------------------------------------------------------------
# dist_csv: the committed step-2 CSV, set by check "step 2" when it can be
# read (the step-3 checks compare the models with it)
dist_csv <- NULL
check("step 2", {
  dist_csv <- read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
  if (!is.data.frame(dataCC)) {
    stop("step-1 CSV unavailable: ", basename(rac_path(P, "dataCC")),
         " could not be read (see the step 1 check)", call. = FALSE)
  }
  stopifnot(identical(names(dist_csv), c("n_Acc", "x", "y", "shoe",
                                         "row_number", "min_dist",
                                         "horiz_dist", "distance_shape",
                                         "new_x")),
            identical(dist_csv[c("n_Acc", "x", "y", "shoe")], dataCC),
            identical(dist_csv$row_number, seq_len(nrow(dataCC))))
  for (v in c("min_dist", "horiz_dist", "distance_shape", "new_x")) {
    stopifnot(all(is.finite(dist_csv[[v]])))
  }
  stopifnot(all(dist_csv$horiz_dist >= dist_csv$min_dist),
            all(dist_csv$distance_shape > 0),
            all(abs(dist_csv$new_x) <= dist_csv$distance_shape))
  # the prototype's per-row half-widths in its own frame (step 2's chunk)
  proto <- t(as.matrix(imager::load.image(rac_path(P, "prototype_contour"))))
  Wp <- P$prototype$col_shoe
  Hp <- P$prototype$row_shoe
  stopifnot(all(dim(proto) == c(Hp, Wp)), Wp != W, Hp != H)
  pc <- P$prototype$coords
  xp <- t(matrix(rep((-Wp / 2 + 1:Wp) * pc$rel_Y_cord / pc$rel_col_shoe, Hp),
                 Wp, Hp))
  yp <- -matrix(rep((-Hp / 2 + 1:Hp) * pc$rel_Y_cord / pc$rel_col_shoe, Wp),
                Hp, Wp)
  widths <- data.frame(x = xp[proto == 1], y = yp[proto == 1]) %>%
    group_by(y) %>% summarise(min_x = abs(min(x)), max_x = max(x))
  half <- csv_round_trip(data.frame(v = c(widths$min_x, widths$max_x)))$v
  stopifnot(all(dist_csv$distance_shape %in% half))
  n_rec <- file.size(rac_path(P, "contour")) / (W * H + 2)
  stopifnot(n_rec == n_shoes)
  # step 2 for every shoe, from the committed contour (record k = code k)
  cbytes <- readBin(rac_path(P, "contour"), "raw", n_rec * (W * H + 2))
  xc <- t(matrix(rep((-W / 2 + 1:W) * P$coords$rel_Y_cord /
                       P$coords$rel_col_shoe, H), W, H))
  yc <- -matrix(rep((-H / 2 + 1:H) * P$coords$rel_Y_cord /
                      P$coords$rel_col_shoe, W), H, W)
  contour_of <- function(i) {
    m <- matrix(cbytes[(i - 1) * (W * H + 2) + seq_len(W * H)] ==
                  as.raw(49), H, W, byrow = TRUE)
    data.frame(shoe = i, x = xc[m], y = yc[m])
  }
  contour_df <- do.call(rbind, lapply(seq_len(n_rec), contour_of))
  rm(cbytes)
  tmp <- tempfile("t5_new_outputs_")
  P_tmp <- P
  P_tmp$root <- paste(tmp, "/", sep = "")
  t0 <- proc.time()[["elapsed"]]
  nd <- compute_distances(dataCC, contour_df, P_tmp)
  nd$distance_shape <- distance_shape_vec(nd$x, nd$y, widths)
  nd$new_x <- (nd$x * nd$distance_shape) / (abs(nd$x) + nd$horiz_dist)
  rac_write_csv(nd, P_tmp, "dataCC_distance")
  secs <- proc.time()[["elapsed"]] - t0
  same <- vapply(c("dataCC_distance_temp", "dataCC_distance"), function(k)
    same_bytes(rac_path(P_tmp, k), rac_path(P, k)), TRUE)
  if (!all(same)) {
    back <- read.csv(rac_path(P_tmp, "dataCC_distance"), header = TRUE)
    v <- c("min_dist", "horiz_dist", "distance_shape", "new_x")
    stale <- if (identical(dim(back), dim(dist_csv))) {
      unique(dist_csv$shoe[rowSums(back[v] != dist_csv[v]) > 0])
    } else {
      NA
    }
    unlink(tmp, recursive = TRUE)
    stop(sprintf(paste("step 2 recomputed from the committed contour",
                       "differs from %s; the rows of %d shoe code(s) differ",
                       "(first: %s): rerun NEW steps 2-6"),
                 paste(basename(vapply(names(same)[!same], rac_path, "",
                                       P = P)), collapse = " and "),
                 length(stale), paste(head(sort(stale), 10), collapse = ", ")))
  }
  unlink(tmp, recursive = TRUE)
  sprintf(paste("step 2: (n_Acc, x, y, shoe) = dataCC; finite distances,",
                "horiz_dist >= min_dist, |new_x| <= distance_shape; every",
                "distance_shape a half-width of the prototype in its own",
                "frame; %d contour records; step 2 recomputed for all %d",
                "shoes (%d rows, %.1f s) from the committed contour writes",
                "both step-2 CSVs byte for byte (new_x in [%.4f, %.4f])"),
          n_rec, n_rec, nrow(nd), secs, min(dist_csv$new_x),
          max(dist_csv$new_x))
})

# --- 3. step 3 and the OLD-basis refits ----------------------------------------
# Each check below compares a model with the step-2 CSV, on the knots of
# that CSV or of the OLD step-2 CSV. A missing or unreadable CSV (what a
# runner that deletes a step's outputs leaves after a failed step 2) makes
# each of them FAIL with that reason, and the script goes on.
step2_csv <- function() {
  if (!is.data.frame(dist_csv)) {
    stop("step-2 CSV unavailable: ", basename(rac_path(P, "dataCC_distance")),
         " could not be read (see the step 2 check)", call. = FALSE)
  }
  dist_csv
}
old_csv <- tryCatch(suppressWarnings(read.csv(rac_path(P_old,
                                                       "dataCC_distance"),
                                              header = TRUE)),
                    error = function(e) conditionMessage(e))
old_basis <- function() {
  if (!is.data.frame(old_csv)) {
    stop("OLD step-2 CSV unavailable: ",
         basename(rac_path(P_old, "dataCC_distance")), " could not be read (",
         old_csv, ")", call. = FALSE)
  }
  basis_knots(old_csv)
}
check("step 3 GLMM", {
  csv <- step2_csv()
  b_new <- basis_knots(csv)
  glmm <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
  stopifnot(inherits(glmm, "glmerMod"), glmm@optinfo$conv$opt == 0,
            is.null(glmm@optinfo$conv$lme4$messages),
            length(fixef(glmm)) == 25, ngrps(glmm) == n_shoes,
            nobs(glmm) == nrow(csv))
  bad <- fails_of(c(basis = identical(basis_of(glmm), b_new),
                    glmm_vs_csv(glmm, csv, b_new)))
  if (!is.null(bad)) {
    stop("the step-3 GLMM was not fitted on dataCC_distance_new.csv (",
         bad, " differ): rerun NEW steps 3-6")
  }
  sprintf(paste("step 3 GLMM: converged, 25 fixed effects, %d groups, %d",
                "rows; fitted on the committed CSV (its basis = the knots of",
                "the CSV, y = n_Acc, groups = the shoe codes, getME(X) = the",
                "step-3 design rebuilt from the CSV); sigma^2 %.4f"),
          ngrps(glmm), nobs(glmm), as.numeric(VarCorr(glmm)$shoe))
})
check("step 3 CML", {
  csv <- step2_csv()
  b_new <- basis_knots(csv)
  cml <- readRDS(rac_model_path(P, "CML_MODEL"))
  stopifnot(inherits(cml, "coxph"), length(coef(cml)) == 24,
            all(is.finite(coef(cml))))
  bad <- fails_of(c(basis = identical(basis_of(cml), b_new),
                    cml_vs_csv(cml, csv, b_new)))
  if (!is.null(bad)) {
    stop("the step-3 CML was not fitted on dataCC_distance_new.csv (",
         bad, " differ): rerun NEW steps 3-6")
  }
  sprintf(paste("step 3 CML: 24 coefficients, %d events; fitted on the",
                "committed CSV (its basis = the knots of the CSV, status =",
                "n_Acc, strata = the shoe codes, model.matrix = the step-3",
                "design without the intercept)"),
          cml$nevent)
})
for (f in c("NEW_X_NS_XY", "CML_MODEL")) {
  check(paste("OLD-basis", f), {
    csv <- step2_csv()
    b_old <- old_basis()
    path <- rac_model_path(P, paste(f, "_oldbasis", sep = ""))
    stopifnot(file.exists(path))
    m <- readRDS(path)
    stopifnot(identical(basis_of(m), b_old))
    if (f == "NEW_X_NS_XY") {
      stopifnot(m@optinfo$conv$opt == 0, length(fixef(m)) == 25)
      flags <- glmm_vs_csv(m, csv, b_old)
    } else {
      stopifnot(length(coef(m)) == 24, all(is.finite(coef(m))))
      flags <- cml_vs_csv(m, csv, b_old)
    }
    bad <- fails_of(flags)
    if (!is.null(bad)) {
      stop("the OLD-basis ", f, " refit was not fitted on ",
           "dataCC_distance_new.csv (", bad, " differ): rerun ",
           "tools/fit_oldbasis_new.R ", f)
    }
    sprintf(paste("OLD-basis %s (A-112): on the OLD basis and fitted on the",
                  "committed CSV (%s)"), f,
            paste(names(flags), collapse = ", "))
  })
}
check("negative control", {
  # the comparisons above must reject a CSV that differs from the fitted
  # one: one shoe's new_x moved by a pixel, a case and a control of one
  # shoe swapped, one row moved to another shoe
  csv <- step2_csv()
  b_new <- basis_knots(csv)
  k <- which(csv$shoe == max(csv$shoe))
  moved <- csv
  moved$new_x[k] <- moved$new_x[k] +
    P$coords$rel_Y_cord / P$coords$rel_col_shoe
  swapped <- csv
  j <- c(k[which(csv$n_Acc[k] == 1)[1]], k[which(csv$n_Acc[k] == 0)[1]])
  swapped$n_Acc[j] <- swapped$n_Acc[rev(j)]
  regrouped <- csv
  regrouped$shoe[k[1]] <- csv$shoe[1]
  stopifnot(length(j) == 2, !anyNA(j), csv$shoe[1] != csv$shoe[k[1]])
  glmm <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
  cml <- readRDS(rac_model_path(P, "CML_MODEL"))
  for (d in list(moved, swapped, regrouped)) {
    stopifnot(!all(glmm_vs_csv(glmm, d, b_new)),
              !all(cml_vs_csv(cml, d, b_new)))
  }
  stopifnot(!glmm_vs_csv(glmm, moved, b_new)[["X"]],
            !glmm_vs_csv(glmm, swapped, b_new)[["y"]],
            !glmm_vs_csv(glmm, regrouped, b_new)[["shoe"]],
            !cml_vs_csv(cml, moved, b_new)[["X"]],
            !cml_vs_csv(cml, swapped, b_new)[["status"]],
            !cml_vs_csv(cml, regrouped, b_new)[["strata"]])
  paste("negative control: the model-CSV comparisons reject a CSV with one",
        "shoe's new_x moved by a pixel (X), a case and a control swapped",
        "(y, status) and a row moved to another shoe (groups, strata)")
})

# --- 4. step 5 ---------------------------------------------------------------
check("step 5", {
  glmm <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
  wt <- read.csv(rac_path(P, "wald_test"), header = TRUE)
  w <- wald_all_spatial(glmm, use_car = FALSE)
  v_rx <- identical(as.matrix(vcov(glmm)),
                    as.matrix(vcov(glmm, use.hessian = FALSE)))
  stopifnot(nrow(wt) == 1, wt$df == 24, wt$model == "NEW_X_NS_XY",
            abs(wt$W - w$W) <= 1e-12 * w$W, wt$method == "manual",
            identical(wt$vcov, if (v_rx) "RX" else "hessian"))
  sprintf("step 5: wald_test_new.csv W = %.4f, df %d, vcov %s = the W of the committed GLMM",
          wt$W, wt$df, wt$vcov)
})
rm(list = intersect(c("glmm", "cml", "m", "csv", "moved", "swapped",
                      "regrouped"), ls()))
invisible(gc())

# --- 5. figures -----------------------------------------------------------------
check("steps 4-6 figures", {
  stems <- c("NEW_X_NS_XY_SHOE", "CML_MODEL_SHOE", "CI_shoe_cuts",
             "CI_cut_110", "CI_cut_190", "CI_cut_250", "pixel_inten_JASAup",
             "difference_random_cml")
  for (s in stems) {
    pdf_path <- rac_image_path(P, s)
    png_path <- file.path(root, "docs", "qa", "T5", "new",
                          paste(s, P$suffix, ".png", sep = ""))
    stopifnot(file.exists(pdf_path), file.exists(png_path),
              identical(readBin(pdf_path, "raw", 4), charToRaw("%PDF")),
              identical(readBin(png_path, "raw", 4),
                        as.raw(c(0x89, 0x50, 0x4e, 0x47))))
  }
  sprintf(paste("steps 4-6: the %d NEW PDFs and their PNG twins exist",
                "(existence only; a stale figure is not detected here:",
                "after a change of a NEW model rerun",
                "docs/qa/T5/probes/t5_new_rerun.sh --oldbasis --png until",
                "T8's e2e test compares them)"),
          length(stems))
})

# --- 6. no collision ------------------------------------------------------------
check("no collision", {
  listed <- system2("git", c("-C", shQuote(root), "ls-files", "-co",
                             "--exclude-standard", "processed_data",
                             "saved_models", "model_images", "docs/qa/T5"),
                    stdout = TRUE)
  in_new <- vapply(strsplit(listed, "/", fixed = TRUE), function(p)
    any(p[-length(p)] %in% RAC_NAMESPACE_FOLDERS), TRUE)
  new_files <- listed[in_new]
  stem <- sub("\\.[^.]*$", "", basename(new_files))
  stopifnot(length(new_files) > 0, all(endsWith(stem, P$suffix)))
  tier_a <- sub("^[0-9a-f]{64}  ", "", readLines(file.path(
    root, "tests", "baseline", "committed_79247d8.sha256")))
  # the OLD files added since 79247d8, one write-once list per task (A-082)
  added <- sub("^[0-9a-f]{64}  ", "", unlist(lapply(Sys.glob(file.path(
    root, "tests", "baseline", "old_added_*.sha256")), readLines)))
  stopifnot(length(added) >= 2)
  old_side <- listed[!in_new & !startsWith(listed, "docs/")]
  extra <- setdiff(old_side, c(tier_a, added))
  stopifnot(length(extra) == 0 || all(basename(extra) == "README.md"))
  sprintf(paste("no collision: %d files in the NEW folders, every stem",
                "ends in %s; the OLD output folders hold only Tier A,",
                "the old_added lists and README files"),
          length(new_files), P$suffix)
})

if (length(failed)) {
  stop(length(failed), " check(s) failed: ", paste(failed, collapse = "; "),
       call. = FALSE)
}
cat("ALL PASS test_new_outputs\n")
