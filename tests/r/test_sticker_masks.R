# Erase list of stickers and frame artefacts in R (decision A-095; the
# Python twin is contour_algorithm/stickers.py and test_qa_snake.py).
#
# 1. rac_apply_sticker_masks() on synthetic matrices.
# 2. rac_read_sticker_masks(): OLD has none; the NEW list is read with its
#    columns; malformed files stop.
# 3. On the real NEW records, R erases per rectangle exactly the number of
#    contact pixels that the Python QA wrote to
#    docs/qa/T4/new/sticker_erased_new.csv (both languages, same pixels).
# 4. Step 1 (dataCC_1.Rmd, rendered in an Rscript subprocess) on the
#    sentinel fixture of tests/fixtures/make_sentinel.py with its own erase
#    list (one rectangle on shoe 6, T4 review) and with a test list (one
#    rectangle on shoe 1) in its place: in each run every count equals the
#    record (with that run's rectangles erased) times the run's stamp mask
#    plus the RAC pixels, shoe 1 loses exactly its contact pixels inside the
#    test rectangle, and no control of shoe 1 lies in it; so the Rmd applies
#    the list before the stamp mask and the RACs.
# Writes only below tempdir().
#
# Run from anywhere:  Rscript tests/r/test_sticker_masks.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
pass <- function(name) cat("PASS", name, "\n")
source(file.path(root, "statistical_model", "R", "profile.R"))
source(file.path(root, "statistical_model", "R", "io.R"))
root_slash <- paste(root, "/", sep = "")
cols <- c("shoe", "row0", "row1", "col0", "col1", "reason")

# 1. the eraser
data <- list(matrix(1, 4, 5), matrix(1, 4, 5), matrix(1, 4, 5))
sm <- data.frame(shoe = c(2L, 2L), row0 = c(1L, 4L), row1 = c(2L, 4L),
                 col0 = c(2L, 1L), col1 = c(3L, 5L), reason = c("a", "b"))
out <- rac_apply_sticker_masks(data, sm)
stopifnot(all(out[[1]] == 1), all(out[[3]] == 1), sum(out[[2]] == 0) == 9,
          out[[2]][1, 2] == 0, out[[2]][2, 3] == 0, out[[2]][4, 5] == 0,
          out[[2]][3, 1] == 1, out[[2]][1, 4] == 1,
          identical(rac_apply_sticker_masks(data, NULL), data))
pass("rac_apply_sticker_masks erases exactly the listed rectangles")

# 2. the reader
P_old <- rac_profile("old", root = root_slash)
stopifnot(is.null(rac_read_sticker_masks(P_old)))
P_new <- rac_profile("new", root = root_slash)
sm_new <- rac_read_sticker_masks(P_new)
stopifnot(identical(names(sm_new), cols), nrow(sm_new) > 0,
          is.integer(sm_new$shoe), all(nzchar(trimws(sm_new$reason))))
# one past the frame and the shoe count, from the profile
w1 <- P_new$col_shoe + 1
h1 <- P_new$row_shoe + 1
n1 <- P_new$num_shoe + 1
bad_rows <- c("1,0,5,1,5,x", "1,5,4,1,5,x", paste0("1,1,5,1,", w1, ",x"),
              paste0(n1, ",1,5,1,5,x"), "1,1,5,1,5,",
              paste0("1,1,", h1, ",1,5,x"))
for (b in bad_rows) {
  tmp <- tempfile("stickers_")
  dir.create(tmp)
  writeLines(c(paste(cols, collapse = ","), b), file.path(tmp, "s.csv"))
  P <- P_new
  P$root <- paste(tmp, "/", sep = "")
  P$inputs$sticker_masks <- "s.csv"
  err <- tryCatch({
    rac_read_sticker_masks(P)
    FALSE
  }, error = function(e) TRUE)
  if (!err) stop("a malformed erase list was accepted: ", b)
}
pass("rac_read_sticker_masks: OLD none, NEW read, malformed lists stop")

# 3. the real NEW records: R counts = the Python counts
counts <- read.csv(file.path(root, "docs", "qa", "T4", "new",
                             "sticker_erased_new.csv"),
                   stringsAsFactors = FALSE)
stopifnot(identical(counts$shoe, sm_new$shoe),
          identical(counts$row0, sm_new$row0),
          identical(counts$col1, sm_new$col1))
W <- P_new$col_shoe
H <- P_new$row_shoe
con <- file(rac_path(P_new, "contacts"), "rb")
record <- function(shoe) {
  seek(con, (shoe - 1) * (W * H + 2))
  chars <- readChar(con, W * H, useBytes = TRUE)
  matrix(as.integer(charToRaw(chars) == charToRaw("1")), H, W, byrow = TRUE)
}
records <- list()
for (s in unique(sm_new$shoe)) records[[s]] <- record(s)
close(con)
r_counts <- integer(nrow(sm_new))
for (k in seq_len(nrow(sm_new))) {
  r_counts[k] <- sum(records[[sm_new$shoe[k]]][
    sm_new$row0[k]:sm_new$row1[k], sm_new$col0[k]:sm_new$col1[k]])
}
erased <- rac_apply_sticker_masks(records, sm_new)
total <- sum(vapply(unique(sm_new$shoe), function(s)
  sum(records[[s]]) - sum(erased[[s]]), numeric(1)))
stopifnot(identical(r_counts, counts$erased_px),
          total == sum(counts$erased_px))
pass(paste("NEW erase list: R erases", total, "contact pixels in",
           length(unique(sm_new$shoe)), "shoes, per rectangle as Python"))

# 4. step 1 on the sentinel fixture, with and without an erase list
fixture <- file.path(root, "tests", "fixtures", "sentinel")
profile_file <- file.path(fixture, "sentinel_profile.json")
prof <- jsonlite::fromJSON(profile_file, simplifyVector = FALSE)
new_root <- function(stickers = NULL) {
  r <- tempfile("stickers_r_")
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
  p <- prof
  if (!is.null(stickers)) {
    write.csv(stickers, file.path(r, "data", "stickers.csv"),
              row.names = FALSE)
    p$datasets$new$inputs$sticker_masks <- "data/stickers.csv"
  }
  pf <- file.path(r, "profile.json")
  writeLines(jsonlite::toJSON(p, auto_unbox = TRUE, null = "null",
                              digits = NA), pf)
  list(root = r, profile = pf)
}
render_step1 <- function(rt) {
  sm_dir <- file.path(rt$root, "statistical_model")
  code <- paste("a <- commandArgs(trailingOnly = TRUE);",
                "rmarkdown::render(a[1], knit_root_dir = a[2],",
                "output_dir = a[3], intermediates_dir = a[3],",
                "envir = new.env(), quiet = TRUE)")
  status <- system2("Rscript", c("-e", shQuote(code),
                                 file.path(sm_dir, "dataCC_1.Rmd"), sm_dir,
                                 file.path(rt$root, "knit")),
                    env = c("RAC_DATASET=new",
                            paste("RAC_PROFILE_FILE=", rt$profile, sep = ""),
                            "RGL_USE_NULL=TRUE"),
                    stdout = file.path(rt$root, "step1.log"),
                    stderr = file.path(rt$root, "step1.log"))
  stopifnot(status == 0)
  fx <- jsonlite::fromJSON(rt$profile)$datasets$new
  list(counts = read.csv(file.path(rt$root, fx$r$paths$pixel_counts)),
       allcont = as.matrix(read.csv(file.path(rt$root,
                                              fx$r$paths$all_cont))),
       dataCC = read.csv(file.path(rt$root, fx$r$paths$dataCC)), fx = fx)
}
plain <- render_step1(new_root())
fx <- plain$fx
Wf <- fx$col_shoe
Hf <- fx$row_shoe
# the rectangle: the top half of shoe 1's rows, every column
rect <- data.frame(shoe = 1L, row0 = 1L, row1 = as.integer(Hf / 2),
                   col0 = 1L, col1 = as.integer(Wf),
                   reason = "test rectangle")
erased_run <- render_step1(new_root(rect))
# the expected counts, from the fixture records: the stored record (the
# rectangle erased for shoe 1 in the second run), flipped for the R flip
# list, times the run's stamp mask (all_cont), plus every RAC pixel
con <- file(file.path(fixture, "data", basename(fx$inputs$contacts)), "rb")
raw <- lapply(seq_len(fx$num_shoe), function(s) {
  seek(con, (s - 1) * (Wf * Hf + 2))
  matrix(as.integer(charToRaw(readChar(con, Wf * Hf, useBytes = TRUE)) ==
                      charToRaw("1")), Hf, Wf, byrow = TRUE)
})
close(con)
loc <- read.table(file.path(fixture, "data", basename(fx$inputs$locations)),
                  col.names = c("shoe", "rac_num", "x", "y", "type"))
cx <- fx$coords
loc$x <- loc$x / cx$divisor
loc$y <- loc$y / cx$divisor
px <- Wf - (floor((loc$x + cx$rel_x_cord) / (2 * cx$rel_x_cord /
                                              cx$rel_col_shoe)) +
              ceiling((Wf - cx$rel_col_shoe) / 2))
py <- Hf - (floor((loc$y + cx$rel_Y_cord) / (2 * cx$rel_Y_cord /
                                              cx$rel_row_shoe)) +
              ceiling((Hf - cx$rel_row_shoe) / 2))
# the fixture's own erase list (the plain run) and the test rectangle (the
# second run, where it replaces the fixture's list)
fixture_rects <- read.csv(file.path(fixture, fx$inputs$sticker_masks),
                          stringsAsFactors = FALSE)
stopifnot(nrow(fixture_rects) == 1, fixture_rects$shoe != rect$shoe)
expected_counts <- function(run, rects) {
  vapply(run$counts$shoe, function(s) {
    d <- raw[[s]]
    for (k in which(rects$shoe == s)) {
      d[rects$row0[k]:rects$row1[k], rects$col0[k]:rects$col1[k]] <- 0
    }
    if (s %in% fx$r$contact_flip_shoes) d <- d[, ncol(d):1]
    d <- d * unname(run$allcont)
    d[cbind(py[loc$shoe == s], px[loc$shoe == s])] <- 1
    sum(d)
  }, numeric(1))
}
stopifnot(isTRUE(all.equal(as.numeric(plain$counts$pixel_count),
                           expected_counts(plain, fixture_rects),
                           tolerance = 0)),
          isTRUE(all.equal(as.numeric(erased_run$counts$pixel_count),
                           expected_counts(erased_run, rect), tolerance = 0)))
# the fixture's rectangle reaches the counts of the plain run: without it
# shoe 6 (code 4) would have more pixels
no_list <- expected_counts(plain, rect[0, ])
stopifnot(no_list[plain$counts$shoe == fixture_rects$shoe] >
            plain$counts$pixel_count[plain$counts$shoe == fixture_rects$shoe])
drop <- plain$counts$pixel_count[1] - erased_run$counts$pixel_count[1]
stopifnot(drop > 0)
ctl <- erased_run$dataCC[erased_run$dataCC$shoe == 1 &
                           erased_run$dataCC$n_Acc == 0, ]
row_of <- function(y) round(Hf / 2 - y * cx$rel_col_shoe / cx$rel_Y_cord)
stopifnot(nrow(ctl) > 0, all(row_of(ctl$y) > rect$row1))
pass(paste("step 1 applies the erase list before the stamp mask and the",
           "RACs: shoe 1 loses", drop, "pixels; every count as expected;",
           "no control of shoe 1 in the rectangle"))
