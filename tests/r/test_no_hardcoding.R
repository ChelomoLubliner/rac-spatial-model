# No dataset literal in the R code (plan T2 step 1; decisions A-035, A-072).
# tests/python/test_no_hardcoding.py covers Python and shell with the same
# rules (tests/lib/hardcoding_scan.py); this is an independent R version.
#
# Scans the R and Rmd files of statistical_model/, tools/ (since the T5
# review fixes, A-118) and tests/ (tracked and new, not ignored; the profile
# file statistical_model/R/profile.R is not scanned). Comments are removed
# first (# outside a string; in an Rmd only the code chunks are code).
# Forbidden everywhere: the dataset numbers 307, 395, 387, 386, 255, 367,
# 631, 126 and the OLD pixel scale 150, 300 as whole tokens, the profile
# constants (allcont >= <n>, the snake init, set.seed(313),
# N_CONTROLS <- <n>) and the legacy relative paths ../data/,
# ../images/. In statistical_model/ and tools/ (the pipeline code, as the
# Python scan treats tools/) also: any set.seed(<number>) and string
# literals that name a data or output location (processed_data,
# saved_models, model_images, data/, images/, a file name with a data
# extension). A line whose comment holds "rac: literal-ok" is exempt. The
# OLD-only test files below state legacy values on purpose (A-072); an
# entry without a finding fails, so the list stays tight.
#
# Run from anywhere:  Rscript tests/r/test_no_hardcoding.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
pass <- function(name) cat("PASS", name, "\n")

allowlist <- c(
  "tests/r/test_baseline_committed.R" =
    "T1 baseline: states the committed model and data counts (A-072)",
  "tests/legacy/compare_figure_matrices.R" =
    "OLD-only diagnostic that redraws the committed OLD figures (A-072)",
  "tests/r/test_profile.R" =
    "states the legacy OLD literals the profile must give (T2)",
  "tests/r/test_no_hardcoding.R" =
    "its self-test feeds the patterns to the scanner")

numbers <- "(^|[^[:alnum:]_.$])(307|395|387|386|255|367|631|126|150|300)([^[:alnum:]_.]|$)"
constants <- c(stamp = "allcont[[:space:]]*>=[[:space:]]*[0-9]",
               snake = "(200|185)[[:space:]]*\\+[[:space:]]*162|(155|128)[[:space:]]*\\+[[:space:]]*(90|95)",
               seed = "set\\.seed\\([[:space:]]*313[[:space:]]*\\)",
               controls = "N_CONTROLS[[:space:]]*<-[[:space:]]*[0-9]",
               parent = "\\.\\./(images|data|Data)/")
pipeline_seed <- "set\\.seed\\([[:space:]]*[0-9]"
output_path <- paste0("processed_data|saved_models|model_images|images_new|",
                      "(^|[/])(data|images)/|",
                      "[[:alnum:]_]\\.(csv|rds|pdf|npy|png|txt|html)$")

# The line without its comment; NA if the comment holds the exemption.
strip_comment <- function(line) {
  chars <- strsplit(line, "", fixed = TRUE)[[1]]
  quote <- ""
  k <- 1
  while (k <= length(chars)) {
    ch <- chars[k]
    if (nzchar(quote)) {
      if (ch == "\\") {
        k <- k + 1
      } else if (ch == quote) {
        quote <- ""
      }
    } else if (ch %in% c("\"", "'", "`")) {
      quote <- ch
    } else if (ch == "#") {
      comment <- paste(chars[k:length(chars)], collapse = "")
      if (grepl("rac: literal-ok", comment, fixed = TRUE)) return(NA_character_)
      return(paste(chars[seq_len(k - 1)], collapse = ""))
    }
    k <- k + 1
  }
  line
}

code_lines <- function(lines, rmd) {
  keep <- rep(!rmd, length(lines))
  if (rmd) {
    inside <- FALSE
    for (i in seq_along(lines)) {
      if (grepl("^[[:space:]]*```[[:space:]]*\\{r", lines[i])) {
        inside <- TRUE
      } else if (inside && grepl("^[[:space:]]*```[[:space:]]*$", lines[i])) {
        inside <- FALSE
      } else if (inside) {
        keep[i] <- TRUE
      }
    }
  }
  out <- vapply(lines, strip_comment, "", USE.NAMES = FALSE)
  out[!keep] <- NA_character_
  out
}

string_literals <- function(code) {
  m <- regmatches(code, gregexpr("\"[^\"]*\"|'[^']*'", code))[[1]]
  substring(m, 2, nchar(m) - 1)
}

findings <- function(rel) {
  lines <- readLines(file.path(root, rel), warn = FALSE)
  code <- code_lines(lines, endsWith(rel, ".Rmd"))
  pipeline <- startsWith(rel, "statistical_model/") ||
    startsWith(rel, "tools/")
  out <- character(0)
  for (i in which(!is.na(code))) {
    hit <- character(0)
    if (grepl(numbers, code[i])) hit <- c(hit, "dataset number")
    for (nm in names(constants)) {
      if (grepl(constants[[nm]], code[i])) hit <- c(hit, nm)
    }
    if (pipeline && grepl(pipeline_seed, code[i])) hit <- c(hit, "seed literal")
    if (pipeline && any(grepl(output_path, string_literals(code[i])))) {
      hit <- c(hit, "output path")
    }
    if (length(hit)) {
      out <- c(out, sprintf("%s:%d: %s: %s", rel, i,
                            paste(hit, collapse = ", "),
                            substr(trimws(code[i]), 1, 80)))
    }
  }
  out
}

files <- system2("git", c("-C", shQuote(root), "ls-files", "-co",
                          "--exclude-standard"), stdout = TRUE)
files <- sort(unique(files[grepl("^(statistical_model|tools|tests)/", files) &
                             grepl("\\.(R|Rmd)$", files) &
                             files != "statistical_model/R/profile.R" &
                             file.exists(file.path(root, files))]))
stopifnot(length(files) > 10, "statistical_model/dataCC_1.Rmd" %in% files,
          "statistical_model/config.R" %in% files,
          "tools/fit_oldbasis_new.R" %in% files,
          "tools/figures_png.R" %in% files)

# 1. the scanner itself: comments, chunks, exemption, each rule
self <- c("x <- 307 # a comment with 387", "# 395 only a comment",
          "y <- \"a # 631 in a string\"", "z <- 255 # rac: literal-ok colour",
          "w <- 0.126 + v307", "set.seed(313)", "p <- '../data/x.txt'")
cl <- code_lines(self, FALSE)
stopifnot(identical(cl[2], ""), is.na(cl[4]),
          grepl(numbers, cl[1]), !grepl("387", cl[1]),
          grepl(numbers, cl[3]), !grepl(numbers, cl[5]),
          grepl(constants[["seed"]], cl[6]), grepl(constants[["parent"]], cl[7]))
rmd <- c("Text 307", "```{r}", "a <- 307", "```", "b <- 387")
stopifnot(identical(which(!is.na(code_lines(rmd, TRUE))), 3L))
stopifnot(any(grepl(output_path, string_literals(
  "f <- paste(ROOT_PATH, \"processed_data/dataCC.csv\", sep = \"\")"))),
  !any(grepl(output_path, string_literals(
    "source(paste(ROOT_PATH, \"statistical_model/R/io.R\", sep = \"\"))"))))
pass("scanner: comments and prose skipped, exemption marker, each rule")

# 2. the R code
bad <- unlist(lapply(setdiff(files, names(allowlist)), findings))
if (length(bad)) {
  writeLines(bad)
  stop(length(bad), " dataset literal(s) in R code")
}
pass(sprintf("no dataset literal in %d R/Rmd files (%d OLD-only files allowed)",
             length(setdiff(files, names(allowlist))), length(allowlist)))

# 3. the allowlist is needed
for (f in names(allowlist)) {
  stopifnot(f %in% files)
  if (!length(findings(f))) stop(f, " has no finding: remove its entry")
}
pass("every allowlisted file still needs its entry")
cat("ALL PASS test_no_hardcoding\n")
