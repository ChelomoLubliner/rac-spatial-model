# io.R: input readers of the R steps (plan T2; T3 extends and tests them).
#
# read_locations(P)  the RAC table of the profile's dataset: the OLD CSV as
#                    the legacy step 1 read it (read.csv(header = TRUE):
#                    shoe, x, y, type, orientation, grade); the NEW raw file
#                    (space-separated, no header, a leading space:
#                    shoe rac_num x y type) as columns shoe, rac_num, x, y,
#                    type. x and y are divided by P$coords$divisor (NEW raw
#                    coordinates are 2 times the OLD scale, plan F4); the
#                    OLD values are returned untouched (divisor 1). Shoe ids
#                    are 1-based and must lie in 1..num_shoe.

read_locations <- function(P) {
  path <- rac_path(P, "locations")
  fmt <- P$inputs$locations_format
  if (identical(fmt, "csv")) {
    loc <- read.csv(path, header = TRUE)
  } else if (identical(fmt, "space_no_header")) {
    loc <- read.table(path, header = FALSE,
                      col.names = c("shoe", "rac_num", "x", "y", "type"))
  } else {
    stop("read_locations: unknown locations format '", fmt, "'",
         call. = FALSE)
  }
  if (P$coords$divisor != 1) {
    loc$x <- loc$x / P$coords$divisor
    loc$y <- loc$y / P$coords$divisor
  }
  if (anyNA(loc$shoe) || any(loc$shoe < 1 | loc$shoe > P$num_shoe)) {
    stop("read_locations: shoe ids outside 1..", P$num_shoe, " in ", path,
         call. = FALSE)
  }
  loc
}

# rac_read_sticker_masks(P)  the profile's erase list of stickers and frame
#                    artefacts (inputs.sticker_masks; decision A-095; the
#                    Python twin is contour_algorithm/stickers.py): a
#                    data.frame shoe, row0, row1, col0, col1, reason, 1-based
#                    inclusive pixel ranges of the stored record; NULL when
#                    the profile has none (OLD). Stops on a malformed file.
# rac_apply_sticker_masks(data, sm)  the list of contact matrices (row_shoe x
#                    col_shoe, indexed by shoe id) with every listed rectangle
#                    set to 0; applied right after the records are read,
#                    before any flip, exactly as the Python step 0 does.

rac_read_sticker_masks <- function(P) {
  if (is.null(P$inputs$sticker_masks)) return(NULL)
  path <- rac_path(P, "sticker_masks")
  sm <- read.csv(path, stringsAsFactors = FALSE, colClasses = c(
    "integer", "integer", "integer", "integer", "integer", "character"))
  cols <- c("shoe", "row0", "row1", "col0", "col1", "reason")
  if (!identical(names(sm), cols)) {
    stop("rac_read_sticker_masks: ", path, " must have the columns ",
         paste(cols, collapse = ","), call. = FALSE)
  }
  bad <- is.na(sm$shoe) | sm$shoe < 1 | sm$shoe > P$num_shoe |
    sm$row0 < 1 | sm$row1 > P$row_shoe | sm$row0 > sm$row1 |
    sm$col0 < 1 | sm$col1 > P$col_shoe | sm$col0 > sm$col1 |
    trimws(sm$reason) == ""
  if (any(bad)) {
    stop("rac_read_sticker_masks: invalid rows ", paste(which(bad),
         collapse = ", "), " in ", path, call. = FALSE)
  }
  sm
}

rac_apply_sticker_masks <- function(data, sm) {
  for (k in seq_len(NROW(sm))) {
    i <- sm$shoe[k]
    data[[i]][sm$row0[k]:sm$row1[k], sm$col0[k]:sm$col1[k]] <- 0
  }
  data
}
