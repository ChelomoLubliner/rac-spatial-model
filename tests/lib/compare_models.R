# compare_models.R: compare two model dumps made by dump_models.R.
#
# As a library: source("tests/lib/compare_models.R");
#   tab <- compare_dumps(a, b)   # a, b = lists from dump_models()
# returns one row per field: identical() (with attributes), all.equal with
# tolerance 0 (values only), max |a - b|, max |a - b| / max |a|, and the
# number of elements. Stops if a field is present in only one dump.
# CLI: Rscript tests/lib/compare_models.R <dump_a.rds> <dump_b.rds>
#   prints the table; exit 0 only if every field (numeric or character, of
#   any length) is identical(), else 1. A NaN, a length change or a changed
#   character field gives no max |a - b| (NA) but still fails (decision
#   A-069; T1 review 2, engineering finding 1: the old exit status counted
#   only the rows with a numeric max |a - b|).

compare_dumps <- function(a, b) {
  # Both dumps must have the same fields: a field missing from one side
  # must not let a comparison pass unnoticed (T1 review).
  only_a <- setdiff(names(a), names(b))
  only_b <- setdiff(names(b), names(a))
  if (length(only_a) || length(only_b)) {
    stop("compare_dumps: the dumps have different fields; only in a: ",
         paste(only_a, collapse = ", "), "; only in b: ",
         paste(only_b, collapse = ", "))
  }
  fields <- names(a)
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
  quit(status = if (all(tab$identical)) 0 else 1)
}
