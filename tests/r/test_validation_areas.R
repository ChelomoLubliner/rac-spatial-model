# Part 2 partitions (plan T7 step 2, review focus 3): Naomi's 14 areas and
# the pre-registered grid of A-008.
#
# 1. naomi_area() equals a literal transcription of Naomi's two loops of
#    2022 (`Code/Organizing data to include subsets (larger areas).R`, the
#    loops that set sub_area; copied below with only the data frame name
#    kept) on every OLD RAC (x, y of locations_data.csv).
# 2. Over a 1,001 x 1,001 grid of [-0.3, 0.3] x [-0.6, 0.6] every point gets
#    exactly one label in 1..14, all 14 occur, and naomi_area_band() gives
#    each area's y band.
# 3. Mirror (F7): the dataCC pixel frame mirrors x, so naomi_area(-x_pixel,
#    y_pixel) of the RAC's pixel centre equals naomi_area(x, y) for >= 99%
#    of OLD RACs (only boundary pixels may differ).
# 4. Grid cells (A-008): on quantile cuts of a continuous synthetic sample
#    every cell holds 1/K of the points (within 0.5%), and bands and
#    columns are (lo, hi] intervals (a point on a cut goes to the lower
#    cell). (The OLD contact pixels themselves lie on a lattice, so their
#    cells are equal only up to ties; Part 2 reports the cell sizes.)
# 5. The frozen cuts have the A-008 shape: K = 10, 15, 20 with 5 y bands.
#
# Run from anywhere:  Rscript tests/r/test_validation_areas.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
suppressMessages(library(splines))
for (f in c("profile.R", "io.R", "distances.R", "compare.R", "validation.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
pass <- function(name) cat("PASS", name, "\n")

# Naomi's loops, verbatim (2022), on a data frame data_RAC with x and y
naomi_loops <- function(data_RAC) {
  data_RAC$sub_area <- NA
  for (i in 1:length(data_RAC$x))
  {
    if (data_RAC$x[i]< 0)
    {
      if ((data_RAC$y[i]< -0.35))
      {
        data_RAC$sub_area[i]<- 1
      }
      if ((data_RAC$y[i]>= -0.35) && (data_RAC$y[i]< -0.15))
      {
        data_RAC$sub_area[i]<- 2
      }
      if ((data_RAC$y[i]>= -0.15) && (data_RAC$y[i]< 0))
      {
        data_RAC$sub_area[i]<- 3
      }
      if ((data_RAC$y[i]>= 0) && (data_RAC$y[i]< 0.15))
      {
        data_RAC$sub_area[i]<- 4
      }
      if ((data_RAC$y[i]>= 0.15))
      {
        data_RAC$sub_area[i]<- 5
      }
    }
    else
    {
      if ((data_RAC$y[i]< -0.35))
      {
        data_RAC$sub_area[i]<- 10
      }
      if ((data_RAC$y[i]>= -0.35) && (data_RAC$y[i]< -0.15))
      {
        data_RAC$sub_area[i]<- 9
      }
      if ((data_RAC$y[i]>= -0.15) && (data_RAC$y[i]< 0))
      {
        data_RAC$sub_area[i]<- 8
      }
      if ((data_RAC$y[i]>= 0) && (data_RAC$y[i]< 0.15))
      {
        data_RAC$sub_area[i]<- 7
      }
      if ((data_RAC$y[i]>= 0.15))
      {
        data_RAC$sub_area[i]<- 6
      }

    }
  }

  for (i in 1:length(data_RAC$x))
  {
    if(data_RAC$sub_area[i]==4)
    {
      if(data_RAC$y[i]>12*(data_RAC$x[i]+0.02)^2-0.07)
      {data_RAC$sub_area[i]<-11}
    }
  }

  for (i in 1:length(data_RAC$x))
  {
    if(data_RAC$sub_area[i]==5)
    {
      if(data_RAC$y[i]< -12*(data_RAC$x[i]+0.01)^2+0.4)
      {data_RAC$sub_area[i]<-12}
    }
  }

  for (i in 1:length(data_RAC$x))
  {
    if(data_RAC$sub_area[i]==6)
    {
      if(data_RAC$y[i]< -20*(data_RAC$x[i] +0.01)^2+0.4)
      {data_RAC$sub_area[i]<-13}
    }
  }

  for (i in 1:length(data_RAC$x))
  {
    if(data_RAC$sub_area[i]==7)
    {
      if(data_RAC$y[i] > 16*(data_RAC$x[i]+0.02)^2-0.07)
      {data_RAC$sub_area[i]<-14}
    }
  }
  data_RAC$sub_area
}

P <- rac_profile("old", root = ROOT_PATH)
loc <- read_locations(P)

# 1. literal transcription on every OLD RAC
ref <- naomi_loops(loc[, c("x", "y")])
got <- naomi_area(loc$x, loc$y)
stopifnot(identical(as.integer(ref), got), length(got) == nrow(loc))
pass(sprintf("naomi_area == Naomi's 2022 loops on all %d OLD RACs (%d areas used)",
             nrow(loc), length(unique(got))))

# 2. a fine grid: one label in 1..14 everywhere, every area occurs, bands
gx <- seq(-0.3, 0.3, length.out = 1001)
gy <- seq(-0.6, 0.6, length.out = 1001)
gg <- expand.grid(x = gx, y = gy)
a <- naomi_area(gg$x, gg$y)
stopifnot(length(a) == nrow(gg), !anyNA(a), all(a %in% 1:14),
          identical(sort(unique(a)), 1:14))
band_y <- cut(gg$y, c(-Inf, -0.35, -0.15, 0, 0.15, Inf), right = FALSE,
              labels = FALSE)
stopifnot(all(naomi_area_band(a) == band_y))
# the transcription agrees on a sample of the grid too (the loops are slow)
set.seed(7)
smp <- sample(nrow(gg), 20000)
stopifnot(identical(as.integer(naomi_loops(gg[smp, ])), a[smp]))
pass("1,001 x 1,001 grid: exactly one label in 1..14, all 14 occur, bands right; loops agree on 20,000 points")

# 3. mirror: the RAC's pixel centre in the dataCC frame, x negated
pix <- part2_aspix(loc$x, loc$y, P)
xy <- part2_coords(P)
a_pix <- naomi_area(-xy$x[pix$col], xy$y[pix$row])
agree <- mean(a_pix == got)
a_nomirror <- naomi_area(xy$x[pix$col], xy$y[pix$row])
stopifnot(agree >= 0.99, mean(a_nomirror == got) < 0.6)
pass(sprintf(paste("mirror: naomi_area(-x_pixel, y_pixel) == naomi_area(x, y)",
                   "for %.4f of OLD RACs; without the mirror %.4f"),
             agree, mean(a_nomirror == got)))

# 4. grid cells on quantile cuts: every cell holds 1/K of a continuous
#    sample; cells are (lo, hi] in y bands and in new_x within each band
set.seed(11)
nx <- rnorm(200000, 0, 0.08)
ny <- runif(200000, -0.5, 0.5)
for (n_x in 2:4) {
  ck <- grid_cuts_from_old(nx, ny, 5, n_x)
  cell <- grid_cell(nx, ny, ck)
  K <- 5 * n_x
  share <- tabulate(cell, K) / length(cell)
  stopifnot(all(cell %in% seq_len(K)), max(abs(share - 1 / K)) < 0.005,
            identical(grid_band(cell, n_x),
                      1L + findInterval(ny, ck$y_hi[-5], left.open = TRUE)))
}
# a point exactly on a cut goes to the lower cell
ck <- grid_cuts_from_old(nx, ny, 5, 3)
stopifnot(grid_cell(ck$x_cut_1[1], ck$y_hi[1], ck) == 1L,
          grid_cell(ck$x_cut_1[1] + 1e-9, ck$y_hi[1], ck) == 2L,
          grid_cell(ck$x_cut_1[2], ck$y_hi[1] + 1e-9, ck) == 4L)
pass("grid cells: 1/K of a continuous sample per cell (K = 10, 15, 20), (lo, hi] bands")

# 5. the frozen cuts are the A-008 construction (5 bands; 2, 3, 4 columns)
fz <- read.csv(part2_path(P, "part2_grid_cuts"))
stopifnot(identical(sort(unique(fz$n_x * fz$n_y)), c(10L, 15L, 20L)),
          all(table(fz$n_x) == 5), all(diff(fz$y_hi[fz$n_x == 3])[1:3] > 0))
pass("frozen grid cuts: K = 10, 15, 20 with 5 y bands")
cat("ALL PASS test_validation_areas\n")
