# Vectorized step-2 distances = the legacy loops, bit for bit (decisions
# A-016, A-039; plan T5 interface, done in T2; review focus 1).
#
# 1. The float window of horiz_dist (plan F14): with the data y after the
#    15-digit CSV round trip and the contour y in memory, abs(dy) < 0.01
#    admits 160 of the 392 OLD three-row pairs with the data row above the
#    contour row and 161 with it below (152 and 151 of 364 on the NEW
#    lattice); horiz_dist_vec() admits exactly the same pairs.
# 2. The legacy functions and the legacy distance_shape loop, taken as text
#    from the chunks of statistical_model/dataCC_distance_2.Rmd (CSV writer
#    stubbed), against min_dist_vec(), horiz_dist_vec() and
#    distance_shape_vec() on 400 random OLD rows of 30 random shoes (seed
#    1) with their committed contour records, plus 6 rows moved beyond the
#    contour in y (no contour point within 0.01: the min_dist fallback; no
#    prototype row within 0.01: the nearest-y fallback of distance_shape):
#    identical() min_dist, horiz_dist, distance_shape and new_x.
# 3. Optional (RAC_SLOW_TESTS=1, about 1 minute): the whole OLD step 2 with
#    RAC_DISTANCE_IMPL=vectorized, rendered in a temporary copy, writes both
#    CSVs with the Tier A sha256. tests/regress_old.sh --steps 2 checks the
#    same on every gate run.
# Writes only below tempdir().
#
# Run from anywhere:  Rscript tests/r/test_distances_vectorized.R
suppressMessages(library(dplyr))
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
source(file.path(root, "statistical_model", "R", "distances.R"))
pass <- function(name) cat("PASS", name, "\n")
P <- rac_profile("old", root = ROOT_PATH)
N <- rac_profile("new", root = ROOT_PATH)
csv_round_trip <- function(df) {
  f <- tempfile(fileext = ".csv")
  write.csv(df, f, row.names = FALSE)
  read.csv(f, header = TRUE)
}

# --- 1. the float window ------------------------------------------------------
lattice <- function(n_rows) {
  y_mem <- -((-n_rows / 2 + 1:n_rows) * P$coords$rel_Y_cord /
               P$coords$rel_col_shoe)
  list(mem = y_mem, csv = csv_round_trip(data.frame(y = y_mem))$y)
}
window_counts <- function(n_rows) {
  y <- lattice(n_rows)
  r <- 1:(n_rows - 3)
  below <- abs(y$csv[r + 3] - y$mem[r]) < 0.01  # data row 3 rows below
  above <- abs(y$csv[r] - y$mem[r + 3]) < 0.01  # data row 3 rows above
  # the same pairs through horiz_dist_vec(): one shoe per pair, the data row
  # at x = 0, one contour point at x = 0.5
  n <- length(r)
  nd <- data.frame(x = 0, y = c(y$csv[r + 3], y$csv[r]), shoe = seq_len(2 * n))
  cd <- data.frame(shoe = seq_len(2 * n), x = 0.5, y = c(y$mem[r], y$mem[r + 3]))
  h <- horiz_dist_vec(nd, cd)
  stopifnot(identical(is.finite(h), c(below, above)))
  c(pairs = n, below = sum(below), above = sum(above))
}
old_w <- window_counts(P$row_shoe)
new_w <- window_counts(N$row_shoe)
stopifnot(identical(unname(old_w), c(392L, 161L, 160L)),
          identical(unname(new_w), c(364L, 151L, 152L)))
y_old <- lattice(P$row_shoe)
y_new <- lattice(N$row_shoe)
stopifnot(sum(y_old$csv != y_old$mem) == 263, sum(y_new$csv != y_new$mem) == 245)
pass(sprintf(paste("float window (F14): OLD %d of %d three-row pairs with the",
                   "data row above, %d below; NEW %d and %d of %d; the round",
                   "trip changes 263 of %d and 245 of %d y values;",
                   "horiz_dist_vec admits the same pairs"),
             old_w[["above"]], old_w[["pairs"]], old_w[["below"]],
             new_w[["above"]], new_w[["below"]], new_w[["pairs"]],
             P$row_shoe, N$row_shoe))

# --- 2. legacy chunks vs vectorized, 406 OLD rows ---------------------------
# (400 sampled rows of 30 shoes plus 6 rows beyond every contour in y)
rmd <- readLines(file.path(root, "statistical_model", "dataCC_distance_2.Rmd"))
chunk_with <- function(pattern) {
  starts <- grep("^```\\{r", rmd)
  ends <- grep("^```$", rmd)
  hit <- grep(pattern, rmd, fixed = TRUE)
  stopifnot(length(hit) == 1)
  s <- max(starts[starts < hit])
  e <- min(ends[ends > hit])
  rmd[(s + 1):(e - 1)]
}
legacy <- new.env()
legacy$rac_write_csv <- function(...) invisible(NULL)  # no file writes
legacy$ROOT_PATH <- ROOT_PATH
legacy$P <- P
eval(parse(text = chunk_with("calculate_min_distance <- function")),
     envir = legacy)

# the committed contour, as step 2 builds contour_df (x, y in memory)
W <- P$col_shoe
H <- P$row_shoe
n_rec <- length(rac_analysis_shoes(P))
raw <- readBin(rac_path(P, "contour"), "raw", n_rec * (W * H + 2))
xcoor <- t(matrix(rep((-W / 2 + 1:W) * P$coords$rel_Y_cord /
                        P$coords$rel_col_shoe, H), W, H))
ycoor <- -matrix(rep((-H / 2 + 1:H) * P$coords$rel_Y_cord /
                       P$coords$rel_col_shoe, W), H, W)
contour_of <- function(i) {  # record i = shoe code i
  m <- matrix(raw[(i - 1) * (W * H + 2) + seq_len(W * H)] == as.raw(49),
              H, W, byrow = TRUE)
  data.frame(shoe = i, x = xcoor[m], y = ycoor[m])
}
dataCC <- read.csv(rac_path(P, "dataCC"), header = TRUE)
dataCC$row_number <- seq_len(nrow(dataCC))
set.seed(1)
shoes <- sort(sample(unique(dataCC$shoe), 30))
contour_df <- do.call(rbind, lapply(shoes, contour_of))
pool <- which(dataCC$shoe %in% shoes)
sub <- dataCC[sort(sample(pool, 400)), ]
far <- sub[1:6, ]
far$y <- c(0.7, -0.7, 0.75, -0.75, 0.68, -0.69)  # beyond every contour
sub <- rbind(sub, far)
# (the values of a row depend only on its own shoe's contour points)

pass1_legacy <- suppressMessages(legacy$calculate_min_distance(sub, contour_df))
pass1_vec <- sub
pass1_vec$row_number <- seq_len(nrow(pass1_vec))
pass1_vec$min_dist <- min_dist_vec(pass1_vec, contour_df)
stopifnot(identical(pass1_legacy$min_dist, pass1_vec$min_dist))
# pass 2 reads the temp CSV in both implementations
in2 <- csv_round_trip(pass1_legacy)
pass2_legacy <- suppressMessages(legacy$calculate_min_horiz_distance(in2,
                                                                     contour_df))
h <- horiz_dist_vec(in2, contour_df)
h[is.infinite(h)] <- in2$min_dist[is.infinite(h)]
stopifnot(identical(pass2_legacy$horiz_dist, h))
n_inf <- sum(is.infinite(horiz_dist_vec(in2, contour_df)))
stopifnot(n_inf >= 6)
pass(sprintf(paste("min_dist and horiz_dist: the legacy loops of the Rmd and",
                   "the vectorized functions identical() on %d OLD rows (%d",
                   "without a contour point within 0.01 in y)"),
             nrow(sub), n_inf))

# distance_shape and new_x: the legacy chunk, run once per implementation
shape_chunk <- chunk_with("distance_per_y <- entire_contour")
consts <- chunk_with("col_proto <- P$prototype$col_shoe")
run_shape <- function(impl) {
  e <- new.env()
  e$rac_write_csv <- function(x, P, key) assign("written", x, envir = e)
  e$P <- P
  e$ROOT_PATH <- ROOT_PATH
  e$new_data <- csv_round_trip(pass2_legacy)
  e$distance_impl <- impl
  e$load.image <- imager::load.image
  e$rac_path <- rac_path
  e$distance_shape_vec <- distance_shape_vec
  e$rac_analysis_shoes <- rac_analysis_shoes
  # the constants chunk reads dataCC; the shape chunk does not need it
  eval(parse(text = grep("dataCC", consts, value = TRUE, invert = TRUE)),
       envir = e)
  eval(parse(text = shape_chunk), envir = e)
  e$written
}
leg <- run_shape("legacy")
vec <- run_shape("vectorized")
stopifnot(identical(leg$distance_shape, vec$distance_shape),
          identical(leg$new_x, vec$new_x), identical(leg, vec),
          !anyNA(vec$distance_shape))
pass(sprintf(paste("distance_shape and new_x: the legacy loop and",
                   "distance_shape_vec() identical() (%d distinct y)"),
             length(unique(leg$y))))

# --- 3. optional: the whole OLD step 2, vectorized, = Tier A ----------------
if (identical(Sys.getenv("RAC_SLOW_TESTS"), "1")) {
  tmp <- tempfile("step2_vec_")
  dir.create(file.path(tmp, "statistical_model", "R"), recursive = TRUE)
  for (d in c("data", "processed_data", "config")) {
    dir.create(file.path(tmp, d))
  }
  invisible(file.copy(Sys.glob(file.path(root, "statistical_model", "*.R*")),
                      file.path(tmp, "statistical_model")))
  invisible(file.copy(Sys.glob(file.path(root, "statistical_model", "R", "*")),
                      file.path(tmp, "statistical_model", "R")))
  invisible(file.copy(file.path(root, "config", "datasets.json"),
                      file.path(tmp, "config")))
  for (f in c("data/contour_Active_Contour.txt", "data/contour_prototype.png",
              "processed_data/dataCC.csv",
              "processed_data/shoe_pixel_counts.csv")) {
    invisible(file.copy(file.path(root, f), file.path(tmp, f)))
  }
  sm <- file.path(tmp, "statistical_model")
  code <- paste("a <- commandArgs(trailingOnly = TRUE);",
                "rmarkdown::render(a[1], knit_root_dir = a[2],",
                "output_dir = a[3], intermediates_dir = a[3],",
                "envir = new.env(), quiet = TRUE)")
  st <- system2("Rscript", c("-e", shQuote(code),
                             file.path(sm, "dataCC_distance_2.Rmd"), sm,
                             file.path(tmp, "knit")),
                env = c("RAC_DATASET=old", "RAC_DISTANCE_IMPL=vectorized"),
                stdout = FALSE, stderr = FALSE)
  stopifnot(st == 0)
  tier_a <- readLines(file.path(root, "tests", "baseline",
                                "committed_79247d8.sha256"))
  for (f in c("processed_data/dataCC_distance_temp.csv",
              "processed_data/dataCC_distance.csv")) {
    want <- substr(tier_a[endsWith(tier_a, paste(" ", f, sep = ""))], 1, 64)
    got <- digest::digest(file = file.path(tmp, f), algo = "sha256")
    stopifnot(identical(got, want))
  }
  unlink(tmp, recursive = TRUE)
  pass("whole OLD step 2, vectorized: both CSVs have the Tier A sha256")
} else {
  cat("SKIPPED whole OLD step 2 (set RAC_SLOW_TESTS=1; tests/regress_old.sh",
      "--steps 2 checks it on every gate run)\n")
}
cat("ALL PASS test_distances_vectorized\n")
