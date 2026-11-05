# compare_models.R: compare two model dumps made by dump_models.R.
#
# As a library: source("tests/lib/compare_models.R");
#   tab <- compare_dumps(a, b)   # a, b = lists from dump_models()
# returns one row per field: identical() (with attributes), all.equal with
# tolerance 0 (values only), max |a - b|, max |a - b| / max |a|, and the
# number of elements.
# CLI: Rscript tests/lib/compare_models.R <dump_a.rds> <dump_b.rds>
#   prints the table; exit 0 if every numeric field is identical().

compare_dumps <- function(a, b) {
  fields <- intersect(names(a), names(b))
  rows <- lapply(fields, function(f) {
    x <- a[[f]]
    y <- b[[f]]
    num <- is.numeric(x) && is.numeric(y) && length(x) == length(y)
    d <- if (num) max(abs(as.numeric(x) - as.numeric(y))) else NA_real_
    scale <- if (num) max(abs(as.numeric(x))) else NA_real_
    data.frame(
      field = f,
      n = length(x),
      identical = identical(x, y),
      all_equal_tol0 = isTRUE(all.equal(unname(x), unname(y),
                                        tolerance = 0,
                                        check.attributes = FALSE)),
      max_abs_diff = d,
      max_rel_diff = if (num && scale > 0) d / scale else NA_real_,
      stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

format_compare <- function(tab) {
  sprintf("%-13s n=%-4d identical=%-5s all.equal(tol=0)=%-5s max|diff|=%-11s rel=%s",
          tab$field, tab$n, tab$identical, tab$all_equal_tol0,
          formatC(tab$max_abs_diff, format = "g", digits = 4),
          formatC(tab$max_rel_diff, format = "g", digits = 4))
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  stopifnot(length(args) == 2)
  tab <- compare_dumps(readRDS(args[1]), readRDS(args[2]))
  writeLines(format_compare(tab))
  numeric_fields <- !is.na(tab$max_abs_diff)
  quit(status = if (all(tab$identical[numeric_fields])) 0 else 1)
}
