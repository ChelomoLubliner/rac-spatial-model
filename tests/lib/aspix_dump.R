# aspix_dump.R: the R pixel of every RAC of one dataset, for the Python
# test tests/python/test_pixel_mapping.py (plan T3; A-088). It evaluates
# the aspix_x / aspix_y definitions of statistical_model/dataCC_1.Rmd
# (chunk "2.init_functions", defaults from the profile P) on the locations
# that step 1 reads (read_locations(P)), and writes shoe, x, y (as %.17g,
# the double R parsed) and the 1-based col, row to a CSV.
#
# Usage: Rscript tests/lib/aspix_dump.R <dataset> <out.csv>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2)
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
source(file.path(root, "statistical_model", "R", "io.R"))
source(file.path(root, "tests", "lib", "rmd_chunk.R"))
P <- rac_profile(args[1])
eval(parse(text = rmd_chunk(file.path(root, "statistical_model",
                                      "dataCC_1.Rmd"), "2.init_functions")))
loc <- read_locations(P)
out <- data.frame(shoe = loc$shoe, x = sprintf("%.17g", loc$x),
                  y = sprintf("%.17g", loc$y), col = aspix_x(loc$x),
                  row = aspix_y(loc$y))
utils::write.csv(out, args[2], row.names = FALSE)
