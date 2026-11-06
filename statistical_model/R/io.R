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
