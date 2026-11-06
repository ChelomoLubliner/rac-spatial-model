# Sentinel profile in R: each profile value reaches the outputs of steps 1
# and 2 (decisions A-035, A-050, A-053; plan T2 step 1).
#
# Renders the real dataCC_1.Rmd and dataCC_distance_2.Rmd (rmarkdown, in
# Rscript subprocesses) on the tiny fixture of tests/fixtures/make_sentinel.py
# (6 shoes of 40 x 60 px, dataset `new` of its profile file, selected with
# the test-only RAC_PROFILE_FILE) inside a temporary root, and checks that
# the sentinel values, which differ from both real datasets, shape the
# outputs: stamp threshold 2 and sweep bound 40 (all_cont, from the records
# with the fixture's erase rectangle on shoe 6 erased), the R flip list
# [3], 5 controls per shoe, seed 7 (two renders identical, seed 8
# different), the skip list (shoe 4 without RACs, shoe 5 excluded: codes 1-4
# = shoes 1, 2, 3, 6), the data coordinates at 20 px per unit (RAC pixels by
# aspix from P$coords, control coordinates on the 1/20 grid), the prototype
# frame of step 2 (44 x 66 px at 25 px per unit: every distance_shape is a
# half-width of the fixture prototype in its own frame; a copy of step 2
# that uses the data frame for the prototype fails), and the record-count
# check of step 2 (a contour file one record short stops it). The fixture's
# rel_x_cord / rel_Y_cord (data 0.3 / 0.6, prototype 0.35 / 0.7) differ from
# the legacy 0.25 / 0.5 (T2 review), and copies of steps 1 and 2 with a
# leftover 0.25 or 0.5 fail. The expected values are computed here from the
# fixture's profile file. Writes only below tempdir().
#
# Run from anywhere:  Rscript tests/r/test_profile_sentinels.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
pass <- function(name) cat("PASS", name, "\n")
fixture <- file.path(root, "tests", "fixtures", "sentinel")
profile_file <- file.path(fixture, "sentinel_profile.json")
W <- 40; H <- 60; N <- 6
fx <- jsonlite::fromJSON(profile_file, simplifyVector = TRUE)$datasets$new
cx <- fx$coords             # data frame: 20 px per unit
pc <- fx$prototype$coords   # prototype frame: 25 px per unit
stopifnot(cx$rel_x_cord != 0.25, cx$rel_Y_cord != 0.5,
          pc$rel_x_cord != 0.25, pc$rel_Y_cord != 0.5,
          isTRUE(all.equal(cx$rel_col_shoe / cx$rel_Y_cord, 20)),
          isTRUE(all.equal(pc$rel_col_shoe / pc$rel_Y_cord, 25)))

# A fresh root with the step code and the fixture inputs.
new_root <- function(profile = NULL) {
  r <- tempfile("sentinel_r_")
  dir.create(file.path(r, "statistical_model", "R"), recursive = TRUE)
  for (f in c(list.files(file.path(root, "statistical_model"),
                         pattern = "\\.(Rmd|R)$", full.names = TRUE),
              list.files(file.path(root, "statistical_model", "R"),
                         full.names = TRUE))) {
    rel <- substring(f, nchar(file.path(root, "statistical_model")) + 2)
    invisible(file.copy(f, file.path(r, "statistical_model", rel)))
  }
  dir.create(file.path(r, "data", "new_shoes"), recursive = TRUE)
  invisible(file.copy(list.files(file.path(fixture, "data"),
                                 full.names = TRUE), file.path(r, "data")))
  invisible(file.copy(file.path(r, "data", "contour_sentinel_r.txt"),
                      file.path(r, "data", "new_shoes",
                                "contour_sentinel_new.txt")))
  pf <- profile_file
  if (!is.null(profile)) {
    pf <- file.path(r, "profile.json")
    writeLines(jsonlite::toJSON(profile, auto_unbox = TRUE, null = "null",
                                digits = NA), pf)
  }
  list(root = r, profile = pf)
}

# Render one Rmd of the temporary root; returns the exit status.
# impl: RAC_DISTANCE_IMPL for step 2 ("" = the default).
render <- function(rt, rmd, impl = "") {
  log <- file.path(rt$root, paste(rmd, ".log", sep = ""))
  sm <- file.path(rt$root, "statistical_model")
  code <- paste("a <- commandArgs(trailingOnly = TRUE);",
                "rmarkdown::render(a[1], knit_root_dir = a[2],",
                "output_dir = a[3], intermediates_dir = a[3],",
                "envir = new.env(), quiet = TRUE)")
  status <- system2("Rscript", c("-e", shQuote(code), file.path(sm, rmd), sm,
                                 file.path(rt$root, "knit")),
                    env = c("RAC_DATASET=new",
                            paste("RAC_PROFILE_FILE=", rt$profile, sep = ""),
                            paste("RAC_DISTANCE_IMPL=", impl, sep = ""),
                            "RGL_USE_NULL=TRUE"),
                    stdout = log, stderr = log)
  attr(status, "log") <- log
  status
}
out <- function(rt, rel) file.path(rt$root, rel)

# The fixture as R reads it (rows x cols), the R flip of shoe 3 applied.
raw <- readBin(file.path(fixture, "data", "contacts_sentinel.txt"), "raw",
               N * (W * H + 2))
shoes <- lapply(seq_len(N), function(i) {
  b <- raw[(i - 1) * (W * H + 2) + seq_len(W * H)]
  matrix(as.integer(b == as.raw(49)), H, W, byrow = TRUE)
})
# the fixture's erase list (one rectangle on shoe 6, T4 review), applied to
# the stored records before the flip, as step 1 does (A-095)
erase <- read.csv(file.path(fixture, fx$inputs$sticker_masks),
                  stringsAsFactors = FALSE)
stopifnot(nrow(erase) >= 1)
for (k in seq_len(nrow(erase))) {
  shoes[[erase$shoe[k]]][erase$row0[k]:erase$row1[k],
                         erase$col0[k]:erase$col1[k]] <- 0L
}
shoes[[3]] <- shoes[[3]][, W:1]

# The legacy stamp sweep, re-implemented with explicit bounds.
sweep <- function(allcont, bound) {
  h <- floor(H / 2)
  lb <- rep(NA, h)
  j <- 1
  while (allcont[h, j] == 0) j <- j + 1
  lb[1] <- j - 1
  for (i in 2:h) {
    j <- lb[i - 1]
    if (allcont[h - i + 1, j] == 0) {
      while ((allcont[h - i + 1, j] == 0) && j < bound) j <- j + 1
      lb[i] <- j - 1
    } else {
      while ((allcont[h - i + 1, j] == 1) && j > 0) j <- j - 1
      lb[i] <- j
    }
  }
  for (i in 1:h) allcont[h - i + 1, 1:lb[i]] <- 0
  ub <- rep(NA, h)
  j <- W
  while (allcont[h, j] == 0) j <- j - 1
  ub[1] <- j + 1
  for (i in 2:h) {
    j <- ub[i - 1]
    if (allcont[h - i + 1, j] == 0) {
      while ((allcont[h - i + 1, j] == 0) && j > 0) j <- j - 1
      ub[i] <- j + 1
    } else {
      while ((allcont[h - i + 1, j] == 1) && j < bound) j <- j + 1
      ub[i] <- j
    }
  }
  for (i in 1:h) allcont[h - i + 1, ub[i]:W] <- 0
  allcont
}

# --- step 1 -----------------------------------------------------------------
a <- new_root()
stopifnot(render(a, "dataCC_1.Rmd") == 0)
dcc <- read.csv(out(a, "processed_data/new/dataCC_new.csv"))
codes <- read.csv(out(a, "processed_data/new/shoe_codes_new.csv"))
stopifnot(identical(codes$code, 1:4), identical(codes$shoe, c(1L, 2L, 3L, 6L)),
          identical(sort(unique(dcc$shoe)), 1:4))
pass("skip list: shoe 4 (no RACs) and 5 (excluded) have no code; codes 1-4")

total <- Reduce(`+`, shoes)
want <- sweep((total >= 2) * 1, 40)
got <- unname(as.matrix(read.csv(out(a, "processed_data/new/all_cont_new.csv"))))
stopifnot(all(dim(got) == c(H, W)), all(got == want))
stopifnot(sum(want) < sum(total >= 2))  # the sweep removed the stamp
pass(sprintf(paste("stamp threshold 2, sweep bound 40, R flip [3]: all_cont",
                   "= the sweep of sum >= 2 (%d px, %d removed)"),
             sum(want), sum(total >= 2) - sum(want)))

ctrl <- table(dcc$shoe[dcc$n_Acc == 0])
stopifnot(length(ctrl) == 4, all(ctrl == 5))
pass("n_controls 5: 5 controls per shoe")

# RAC pixels by aspix with P$coords (20 px per unit, x mirrored)
loc <- read.table(file.path(fixture, "data", "locations_sentinel.txt"),
                  col.names = c("shoe", "rac_num", "x", "y", "type"))
loc$x <- loc$x / cx$divisor
loc$y <- loc$y / cx$divisor
loc <- loc[loc$shoe != 5, ]
col <- W - (floor((loc$x + cx$rel_x_cord) / (2 * cx$rel_x_cord / cx$rel_col_shoe)) +
              ceiling((W - cx$rel_col_shoe) / 2))
row <- H - (floor((loc$y + cx$rel_Y_cord) / (2 * cx$rel_Y_cord / cx$rel_row_shoe)) +
              ceiling((H - cx$rel_row_shoe) / 2))
code_of <- match(loc$shoe, codes$shoe)
want_cases <- unique(data.frame(shoe = code_of, x = (-W / 2 + col) / 20,
                                y = -(-H / 2 + row) / 20))
cases_of <- function(d) d[d$n_Acc == 1, c("shoe", "x", "y")]
cases <- cases_of(dcc)
# (+ 0 turns a negative zero, which R's CSV writes as 0, into 0)
key <- function(d) sort(sprintf("%d %.9f %.9f", d$shoe, d$x + 0, d$y + 0))
stopifnot(nrow(cases) == nrow(want_cases), identical(key(cases),
                                                     key(want_cases)))
pass(sprintf("RAC pixels = aspix of P$coords (%d case pixels, one duplicate)",
             nrow(cases)))
on_grid <- function(d) {
  ctl <- d[d$n_Acc == 0, ]
  cc <- ctl$x * 20 + W / 2
  rr <- -ctl$y * 20 + H / 2
  all(abs(cc - round(cc)) < 1e-9) && all(abs(rr - round(rr)) < 1e-9) &&
    all(round(cc) >= 1 & round(cc) <= W) && all(round(rr) >= 1 & round(rr) <= H)
}
stopifnot(on_grid(dcc))
pass("control coordinates (c - col_shoe/2)/20 and -(r - row_shoe/2)/20")

# copies of step 1 with a leftover legacy 0.25 / 0.5 in place of the
# fixture's rel_x_cord / rel_Y_cord must fail (T2 review)
mutate1 <- function(from, to) {
  m <- new_root()
  rmd <- file.path(m$root, "statistical_model", "dataCC_1.Rmd")
  txt <- readLines(rmd)
  stopifnot(length(grep(from, txt, fixed = TRUE)) == 1)
  writeLines(sub(from, to, txt, fixed = TRUE), rmd)
  st <- render(m, "dataCC_1.Rmd")
  res <- if (st != 0) "render error" else {
    d <- read.csv(out(m, "processed_data/new/dataCC_new.csv"))
    if (!identical(key(cases_of(d)), key(want_cases))) "RAC pixels moved"
    else if (!on_grid(d)) "controls off the 1/20 grid" else "PASSED (bad)"
  }
  unlink(m$root, recursive = TRUE)
  res
}
m1 <- c(
  x = mutate1("rel_x_cord = P$coords$rel_x_cord)", "rel_x_cord = 0.25)"),
  y = mutate1("rel_Y_cord = P$coords$rel_Y_cord)", "rel_Y_cord = 0.5)"),
  grid = mutate1("(-col_shoe/2+1:col_shoe)*rel_Y_cord/rel_col_shoe",
                 "(-col_shoe/2+1:col_shoe)*0.5/rel_col_shoe"))
stopifnot(all(m1 != "PASSED (bad)"))
pass(sprintf(paste("mutation checks, step 1: aspix with 0.25 for rel_x_cord",
                   "(%s), with 0.5 for rel_Y_cord (%s), control x with 0.5",
                   "(%s)"), m1[["x"]], m1[["y"]], m1[["grid"]]))

b <- new_root()
stopifnot(render(b, "dataCC_1.Rmd") == 0)
dcc_b <- read.csv(out(b, "processed_data/new/dataCC_new.csv"))
stopifnot(identical(dcc, dcc_b))
prof <- jsonlite::fromJSON(profile_file, simplifyVector = FALSE)
prof$datasets$new$r$seed <- 8
c8 <- new_root(prof)
stopifnot(render(c8, "dataCC_1.Rmd") == 0)
dcc_c <- read.csv(out(c8, "processed_data/new/dataCC_new.csv"))
stopifnot(nrow(dcc_c) == nrow(dcc), !identical(dcc, dcc_c),
          identical(dcc_c[dcc_c$n_Acc == 1, ], dcc[dcc$n_Acc == 1, ]))
pass("seed 7: two renders identical; seed 8 draws other controls")

# --- step 2 -----------------------------------------------------------------
stopifnot(render(a, "dataCC_distance_2.Rmd") == 0)
dist <- read.csv(out(a, "processed_data/new/dataCC_distance_new.csv"))
stopifnot(nrow(dist) == nrow(dcc), !anyNA(dist$new_x),
          all(is.finite(dist$min_dist)), all(is.finite(dist$horiz_dist)))
# half-widths of the fixture prototype in its own frame (44 x 66 px, 25 px
# per unit), through the same CSV round trip as the data
proto <- png::readPNG(file.path(fixture, "data",
                                "prototype_contour_sentinel.png"))
stopifnot(identical(dim(proto), c(66L, 44L)))
px <- which(proto > 0, arr.ind = TRUE)
xs <- (-44 / 2 + px[, "col"]) * pc$rel_Y_cord / pc$rel_col_shoe
ys <- -(-66 / 2 + px[, "row"]) * pc$rel_Y_cord / pc$rel_col_shoe
half <- c(tapply(xs, ys, function(v) abs(min(v))), tapply(xs, ys, max))
tmp_csv <- tempfile(fileext = ".csv")
write.csv(data.frame(h = half), tmp_csv, row.names = FALSE)
half <- read.csv(tmp_csv)$h
in_proto <- function(v) all(vapply(v, function(z) any(abs(half - z) < 1e-12),
                                   TRUE))
stopifnot(in_proto(dist$distance_shape))
pass(sprintf(paste("every distance_shape (%d values) is a half-width of the",
                   "prototype in its own 44 x 66 frame"),
             length(unique(dist$distance_shape))))

# both implementations of step 2 write the same bytes (A-016)
both <- lapply(c("legacy", "vectorized"), function(impl) {
  r <- new_root()
  invisible(file.copy(out(a, "processed_data"), r$root, recursive = TRUE))
  stopifnot(render(r, "dataCC_distance_2.Rmd", impl) == 0)
  f <- c("processed_data/new/dataCC_distance_temp_new.csv",
         "processed_data/new/dataCC_distance_new.csv")
  sha <- vapply(f, function(x) digest::digest(file = out(r, x),
                                              algo = "sha256"), "")
  unlink(r$root, recursive = TRUE)
  sha
})
stopifnot(identical(both[[1]], both[[2]]),
          identical(unname(both[[2]][2]), digest::digest(
            file = out(a, "processed_data/new/dataCC_distance_new.csv"),
            algo = "sha256")))
pass("step 2 legacy and vectorized: byte-identical CSVs on the fixture")

# copies of step 2 that use the data frame for the prototype must fail:
# the data width (caught by the frame check of step 2) and the data scale
# (same dimensions, other half-widths: caught by the values)
mutate <- function(from, to) {
  m <- new_root()
  invisible(file.copy(out(a, "processed_data"), m$root, recursive = TRUE))
  rmd <- file.path(m$root, "statistical_model", "dataCC_distance_2.Rmd")
  txt <- readLines(rmd)
  stopifnot(length(grep(from, txt, fixed = TRUE)) == 1)
  writeLines(sub(from, to, txt, fixed = TRUE), rmd)
  st <- render(m, "dataCC_distance_2.Rmd")
  ok <- st == 0 && in_proto(read.csv(
    out(m, "processed_data/new/dataCC_distance_new.csv"))$distance_shape)
  unlink(m$root, recursive = TRUE)
  if (ok) "PASSED (bad)" else if (st != 0) "render error" else
    "values outside the prototype"
}
r1 <- mutate("P$prototype$col_shoe", "P$col_shoe")
r2 <- mutate("P$prototype$coords$rel_col_shoe", "P$coords$rel_col_shoe")
r3 <- mutate("proto_rel_Y_cord <- P$prototype$coords$rel_Y_cord",
             "proto_rel_Y_cord <- 0.5")
stopifnot(r1 != "PASSED (bad)", r2 == "values outside the prototype",
          r3 == "values outside the prototype")
pass(sprintf(paste("mutation checks: step 2 with P$col_shoe as prototype",
                   "width fails (%s); with the data scale fails (%s); with",
                   "a leftover 0.5 for the prototype rel_Y_cord fails (%s)"),
             r1, r2, r3))

# a contour file one record short stops step 2 (A-053)
s <- new_root()
invisible(file.copy(out(a, "processed_data"), s$root, recursive = TRUE))
invisible(file.copy(file.path(fixture, "data", "contour_sentinel_short.txt"),
                    out(s, "data/new_shoes/contour_sentinel_new.txt"),
                    overwrite = TRUE))
st <- render(s, "dataCC_distance_2.Rmd")
log <- readLines(attr(st, "log"))
if (!any(grepl("is not 4 records of 40 x 60 + 2 bytes", log, fixed = TRUE))) {
  writeLines(tail(log, 15))
}
stopifnot(st != 0, any(grepl("is not 4 records of 40 x 60 + 2 bytes", log,
                             fixed = TRUE)))
pass("a contour file with one record too few stops step 2 with an error")

for (r in list(a, b, c8, s)) unlink(r$root, recursive = TRUE)
cat("ALL PASS test_profile_sentinels\n")
