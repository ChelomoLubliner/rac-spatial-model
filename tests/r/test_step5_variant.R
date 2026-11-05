# tests/legacy/step5_without_car.R (T1 review, finding 10.2).
# Run from anywhere: Rscript tests/r/test_step5_variant.R
#  1. From the committed statistical_tests_5.Rmd (the 79247d8 blob, which
#     the legacy R runner extracts) it writes exactly the variant that the
#     T1 R chains A and B ran (sha256 pinned below).
#  2. It refuses inputs that break its splice: library(car) after the
#     linearHypothesis chunk, or print(testing) as the last line (the old
#     script silently wrote a wrong variant for both).
# Writes only to R's session temp folder.
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
pass <- function(name) cat("PASS", name, "\n")
script <- file.path(root, "tests", "legacy", "step5_without_car.R")
rscript <- file.path(R.home("bin"), "Rscript")

run_variant <- function(lines_in) {
  input <- tempfile(fileext = ".Rmd")
  output <- tempfile(fileext = ".Rmd")
  writeLines(lines_in, input)
  out <-suppressWarnings(system2(rscript, c(shQuote(script), shQuote(input),
                                             shQuote(output)),
                                  stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  list(status = if (is.null(status)) 0L else status, log = out,
       output = output)
}

# 1. The committed Rmd -> the T1 variant (sha256 of the variant in
#    <scratch>/t1/legacy_r_oTZO3x and legacy_r_OB7DF8).
blob <- system2("git", c("-C", shQuote(root), "--no-optional-locks", "show",
                         "79247d8:statistical_model/statistical_tests_5.Rmd"),
                stdout = TRUE)
stopifnot(is.null(attr(blob, "status")), length(blob) > 100)
r <- run_variant(blob)
stopifnot(r$status == 0)
sha <- digest::digest(file = r$output, algo = "sha256")
stopifnot(identical(sha, paste0("4b0249dcb2bbe266f8361b7d2dfbc58d",
                                "c29fc9852852ed370fcbf80bf1e4e13e")))
v <- readLines(r$output)
stopifnot(!any(trimws(v) == "library(car)"),
          sum(grepl("wald_all_spatial(random_model)", v, fixed = TRUE)) == 1,
          !any(grepl("linearHypothesis(", v, fixed = TRUE)))
pass(sprintf("committed Rmd -> the T1 step-5 variant (sha256 %s...)",
             substr(sha, 1, 12)))

chunk <- c("testing <- linearHypothesis(random_model,",
           "                            test = c(\"Chisq\", \"F\"))",
           "print(testing)")
# A valid synthetic input: car first, a line after the chunk.
ok <- run_variant(c("library(car)", "a <- 1", chunk, "b <- 2"))
stopifnot(ok$status == 0,
          identical(readLines(ok$output), c(
            "a <- 1",
            "# T1 scratch variant: manual Wald test (car is not installed here).",
            "source(paste(ROOT_PATH, \"statistical_model/R/wald.R\", sep = \"\"))",
            "testing <- wald_all_spatial(random_model)",
            "print(testing)",
            "b <- 2")))
pass("synthetic input: car line removed, chunk replaced, the rest kept")

# 2. Inputs that break the splice are refused (non-zero exit).
last_line <- run_variant(c("library(car)", "a <- 1", chunk))
car_after <- run_variant(c("a <- 1", chunk, "library(car)", "b <- 2"))
stopifnot(last_line$status != 0, car_after$status != 0,
          any(grepl("last < length(x)", last_line$log, fixed = TRUE)),
          any(grepl("car_line < first", car_after$log, fixed = TRUE)))
pass("print(testing) as the last line and library(car) after the chunk are refused")
cat("ALL PASS test_step5_variant\n")
