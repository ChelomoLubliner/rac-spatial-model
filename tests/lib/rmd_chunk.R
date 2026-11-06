# rmd_chunk.R: the code of one labelled chunk of an R Markdown file, so a
# test can evaluate the pipeline's own function definitions (for example
# aspix_x / aspix_y of statistical_model/dataCC_1.Rmd, chunk
# "2.init_functions") instead of a copy of them (plan T3; A-088).
#
# rmd_chunk(path, label)  character vector of the chunk's code lines; an
#                         error if the label is missing or not unique
rmd_chunk <- function(path, label) {
  lines <- readLines(path, warn = FALSE)
  header <- sprintf("^```\\{r %s[,}]", gsub(".", "\\.", label, fixed = TRUE))
  start <- grep(header, lines)
  if (length(start) != 1) {
    stop("rmd_chunk: ", length(start), " chunks labelled '", label, "' in ",
         path, call. = FALSE)
  }
  ends <- grep("^```[[:space:]]*$", lines)
  end <- ends[ends > start][1]
  if (is.na(end)) stop("rmd_chunk: chunk '", label, "' is not closed",
                       call. = FALSE)
  lines[(start + 1):(end - 1)]
}
