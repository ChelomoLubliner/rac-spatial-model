# t5_boot.R: shoe-bootstrap percentile intervals for the O/E and band
# density numbers of t5_gof.R (second T5 review fixes: the statistics
# reviewer's minor finding on uncertainty; decision A-120). Ported from the
# reviewer's scratch probes stat_checks.R (section 3) and reprint_boot.R,
# with the same seeds and the same order of draws.
#
# The z values of t5_gof.R are binomial: they ignore the dependence of RACs
# within a shoe and the differences between shoes. Here whole shoes are
# resampled with replacement and each statistic is recomputed as a ratio of
# sums over the resampled shoes (95% percentile intervals). The intervals
# carry the between-shoe variation and the within-shoe dependence, not the
# estimation error of the fitted surface (the fit is held fixed).
#   1. O/E of the committed GLMMs (fitted values with each shoe's BLUP, as
#      t5_gof.R), B = 2000, seed 1, one set of resamples for every region:
#      NEW: CI cut 250 pooled (y within +-0.02 of prototype row 250, both
#      edge rows; t5_gof.R D) and at its right peak (|new_x - 0.135| <=
#      0.02), the peak window of the withdrawn map maximum (t5_gof.R C), the
#      band y in (-0.18, -0.10] for all shoes, group A (ids 1-343 and
#      442-490; post hoc, plan F79) and group B; cuts 110 and 190; then OLD
#      (its own resamples, seed 2): the band and cut 250.
#   2. The band's RAC density relative to the shoe group's own: (RAC px in
#      the band / S px in the band) / (RAC px / S px on the whole shoes),
#      from the contact surfaces S of step 1 (built as t5_gof.R E builds
#      them; the pixel counts are checked), B = 4000, seed 3, in this order:
#      the OLD prints of the 50 group-A same_shoe reprints (T0 verdicts),
#      the 319 OLD shoes that are not same_shoe partners, NEW group A, NEW
#      group B; with the RAC px in the band, the number expected at each
#      shoe's own density, and the shoes with a band RAC.
# Reads committed files only; writes nothing.
# Usage (repo root): Rscript docs/qa/T5/probes/t5_boot.R     (about 2 min)
suppressMessages({
  library(splines)
  library(lme4)
})
root <- normalizePath(".")
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "io.R", "compare.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
source(file.path(root, "tests", "lib", "rmd_chunk.R"))
t_start <- proc.time()[["elapsed"]]
prof <- list(old = rac_profile("old", root = ROOT_PATH),
             new = rac_profile("new", root = ROOT_PATH))
P0 <- prof$old
sc <- P0$prototype$coords$rel_Y_cord / P0$prototype$coords$rel_col_shoe
y_of_row <- function(row) -(-P0$prototype$row_shoe / 2 + row) * sc
is_a <- function(id) id <= 343 | (id >= 442 & id <= 490)

# --- 1. O/E with the fitted values held fixed --------------------------------
boot_oe <- function(d, mu, draws, shoes, sel) {
  O <- tapply(d$n_Acc * sel, d$shoe, sum)[as.character(shoes)]
  E <- tapply(mu * sel, d$shoe, sum)[as.character(shoes)]
  idx <- match(draws, shoes)
  dim(idx) <- dim(draws)
  r <- colSums(matrix(O[idx], nrow(idx))) / colSums(matrix(E[idx], nrow(idx)))
  sprintf("%.3f [%.3f, %.3f] (O %d, E %.1f)", sum(O) / sum(E),
          quantile(r, 0.025), quantile(r, 0.975), sum(O), sum(E))
}
cat("== 1. O/E of the committed GLMMs (BLUPs held fixed), shoe bootstrap\n")
for (ds in c("new", "old")) {
  P <- prof[[ds]]
  d <- read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
  g <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
  stopifnot(nobs(g) == nrow(d),
            identical(as.numeric(getME(g, "y")), as.numeric(d$n_Acc)))
  mu <- as.numeric(fitted(g))
  set.seed(if (ds == "new") 1 else 2)
  shoes <- sort(unique(d$shoe))
  B <- 2000
  draws <- replicate(B, sample(shoes, length(shoes), replace = TRUE))
  cut_rows <- function(row) abs(d$y - y_of_row(row)) <= 0.02 + 1e-9
  band <- d$y > -0.18 & d$y <= -0.10
  cat(sprintf("%s: %d shoes, B = %d\n", ds, length(shoes), B))
  if (ds == "new") {
    a <- is_a(d$shoe)
    sel <- list(
      "cut 250 pooled" = cut_rows(250),
      "cut 250 right peak (new_x 0.135)" = cut_rows(250) &
        abs(d$new_x - 0.135) <= 0.02,
      "peak window (0.135, -0.155)" = abs(d$new_x - 0.135) < 0.025 &
        abs(d$y + 0.155) < 0.04 - 1e-9,
      "band, all NEW" = band, "band, group A (post hoc)" = band & a,
      "band, group B" = band & !a,
      "cut 110 pooled" = cut_rows(110), "cut 190 pooled" = cut_rows(190))
  } else {
    sel <- list("band, all OLD" = band, "cut 250 pooled" = cut_rows(250))
  }
  for (nm in names(sel)) {
    cat(sprintf("  %-34s %s\n", nm, boot_oe(d, mu, draws, shoes, sel[[nm]])))
  }
}

# --- 2. band RAC density relative to the group's own -------------------------
# the contact surface S of every analysis shoe, step 1's construction (the
# same code as t5_gof.R's contact_surfaces)
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
per_shoe <- function(ds) {
  s <- contact_surfaces(prof[[ds]])
  r <- band_rows(prof[[ds]], -0.18, -0.10)
  data.frame(S = vapply(s, function(o) sum(o$S), 1),
             Sb = vapply(s, function(o) sum(o$S[r, ]), 1),
             R = vapply(s, function(o) sum(o$rac), 1),
             Rb = vapply(s, function(o) sum(o$rac[r, ]), 1))
}
bo <- per_shoe("old")
bn <- per_shoe("new")
ids_old <- rac_analysis_shoes(prof$old)
ids_new <- rac_analysis_shoes(prof$new)
v <- read.csv(file.path(root, "docs", "qa", "T0", "compare",
                        "overlap_verdicts_t0_old_vs_new.csv"))
v <- v[v$verdict == "same_shoe", ]
ko <- match(v$old[is_a(v$new)], ids_old)
stopifnot(!anyNA(ko), length(ko) == 50, !anyNA(match(v$old, ids_old)))
ratio <- function(b) (sum(b$Rb) / sum(b$Sb)) / (sum(b$R) / sum(b$S))
set.seed(3)
ci <- function(b, B = 4000) {
  r <- replicate(B, ratio(b[sample(nrow(b), replace = TRUE), ]))
  sprintf(paste("%.3f [%.3f, %.3f] (%d shoes; RAC px in the band %d,",
                "expected at the shoes' own density %.1f; shoes with a band",
                "RAC %d)"),
          ratio(b), quantile(r, 0.025), quantile(r, 0.975), nrow(b),
          sum(b$Rb), sum(b$R * b$Sb / b$S), sum(b$Rb > 0))
}
cat("\n== 2. band RAC density / the group's own, shoe bootstrap (B = 4000, seed 3)\n")
cat("OLD prints of the 50 group-A reprints:", ci(bo[ko, ]), "\n")
cat("OLD shoes that are not same_shoe partners:",
    ci(bo[-match(v$old, ids_old), ]), "\n")
cat("NEW group A (post hoc):", ci(bn[is_a(ids_new), ]), "\n")
cat("NEW group B:", ci(bn[!is_a(ids_new), ]), "\n")
cat("band RAC px per OLD reprint shoe that has one:",
    paste(bo$Rb[ko][bo$Rb[ko] > 0], collapse = ", "), "\n")
cat(sprintf("\nt5_boot.R done in %.0f s\n",
            proc.time()[["elapsed"]] - t_start))
