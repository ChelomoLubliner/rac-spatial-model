# Make the scratch variant of statistical_tests_5.Rmd used by the legacy R
# run (plan T1 step 4): `car` is not installed on this machine, so the
# `library(car)` line is removed and the body of the linearHypothesis chunk
# is replaced by the manual Wald test of statistical_model/R/wald.R (which
# also runs car::linearHypothesis when car is available). Every other line
# is unchanged; the figures of step 5 do not depend on this chunk.
#
# Usage: Rscript step5_without_car.R <input.Rmd> <output.Rmd>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2)
x <- readLines(args[1], warn = FALSE)

car_line <- which(trimws(x) == "library(car)")
stopifnot(length(car_line) == 1)

first <- which(grepl("^testing <- linearHypothesis\\(random_model,", x))
last <- which(trimws(x) == "print(testing)")
stopifnot(length(first) == 1, length(last) == 1, last > first)
# The splice below is correct only if library(car) comes before the chunk
# (its index is then unchanged by the splice) and print(testing) is not the
# last line ((last + 1):length(x) would count down otherwise). Both hold for
# the committed statistical_tests_5.Rmd; refuse anything else (T1 review).
stopifnot(car_line < first, last < length(x))

replacement <- c(
  "# T1 scratch variant: manual Wald test (car is not installed here).",
  "source(paste(ROOT_PATH, \"statistical_model/R/wald.R\", sep = \"\"))",
  "testing <- wald_all_spatial(random_model)",
  "print(testing)"
)
y <- c(x[seq_len(first - 1)], replacement, x[(last + 1):length(x)])
y <- y[-car_line]
writeLines(y, args[2])
cat("step5_without_car: removed line", car_line, "(library(car)); replaced",
    "lines", first, "to", last, "by the manual Wald test\n")
