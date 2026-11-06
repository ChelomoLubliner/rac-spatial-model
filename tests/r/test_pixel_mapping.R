# Pixel mapping of the RACs, R side (plan T3 step 1; decisions A-087,
# A-088; facts F5, F6). Evaluates aspix_x / aspix_y from dataCC_1.Rmd itself
# (chunk "2.init_functions", defaults from the profile P) on the locations
# step 1 reads (read_locations(P)):
#   1. NEW: the R pixel of every RAC equals the 2023 COL / ROW;
#   2. OLD: the two RACs where the multiply form differs (F6) map to
#      (125, 138) and (175, 340);
#   3. the derived NEW CSV (prep.locations_csv) read by read.csv gives the
#      same doubles as read_locations(P) (raw / 2) and as the 2023 file,
#      with the same shoe, type and rac_num.
# The Python side (all RACs of both datasets against R) is
# tests/python/test_pixel_mapping.py. Reads only.
#
# Run from anywhere:  Rscript tests/r/test_pixel_mapping.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
source(file.path(root, "statistical_model", "R", "io.R"))
source(file.path(root, "tests", "lib", "rmd_chunk.R"))
pass <- function(name) cat("PASS", name, "\n")
Sys.unsetenv(c("RAC_DATASET", "RAC_PROFILE_FILE"))
eval(parse(text = rmd_chunk(file.path(root, "statistical_model",
                                      "dataCC_1.Rmd"), "2.init_functions")))
stopifnot(is.function(aspix_x), is.function(aspix_y))

# 1. NEW against the 2023 COL / ROW (the defaults read the global P)
P <- rac_profile("new")
loc <- read_locations(P)
ref <- read.csv(rac_path(P, "cross_check"))
stopifnot(nrow(loc) == 20013, nrow(ref) == nrow(loc),
          identical(as.integer(loc$shoe), as.integer(ref$shoe)),
          identical(aspix_x(loc$x), as.numeric(ref$COL)),
          identical(aspix_y(loc$y), as.numeric(ref$ROW)))
pass("NEW: aspix of dataCC_1.Rmd equals the 2023 COL / ROW for all 20013 RACs")

# 3. the derived NEW CSV
csv <- read.csv(paste(P$root, P$prep$locations_csv, sep = ""))
stopifnot(identical(names(csv), c("shoe", "x", "y", "type", "rac_num")),
          identical(csv$x, loc$x), identical(csv$y, loc$y),
          identical(csv$x, ref$x), identical(csv$y, ref$y),
          identical(csv$shoe, loc$shoe), identical(csv$type, loc$type),
          identical(csv$rac_num, loc$rac_num))
pass(paste("derived NEW CSV: x and y identical() to read_locations (raw / 2)",
           "and to the 2023 file; shoe, type, rac_num identical"))

# 2. OLD, the two RACs of F6
P <- rac_profile("old")
loc <- read_locations(P)
f6 <- list(list(shoe = 46, x = 0.09425, y = 0.2, want = c(125, 138)),
           list(shoe = 239, x = -0.07, y = -0.47346, want = c(175, 340)))
for (r in f6) {
  k <- which(loc$shoe == r$shoe & loc$x == r$x & loc$y == r$y)
  stopifnot(length(k) == 1,
            identical(c(aspix_x(loc$x[k]), aspix_y(loc$y[k])), r$want))
}
pass("OLD: the two RACs of F6 map to (125, 138) and (175, 340)")
cat("ALL PASS test_pixel_mapping\n")
