# distances.R: the step-2 distances without the per-row loops (plan T5
# interface, done in T2; decisions A-016, A-039).
#
# dataCC_distance_2.Rmd computes, for every row of dataCC, the distance to
# the nearest contour point of its own shoe (min_dist), the distance to the
# nearest contour point within 0.01 in y (horiz_dist, min_dist where there
# is none) and the prototype half-width at its y (distance_shape). The
# legacy code loops over rows and contour points (about 19 minutes on OLD).
# These functions give the same doubles, bit for bit:
#   - every distance is sqrt((x1 - x2)^2 + (y1 - y2)^2) with the operands in
#     the legacy order (outer() subtracts element by element, x^2 is x * x
#     in R for both a scalar and a vector), and the minimum of the same
#     values is the same value (the legacy running minimum keeps the first
#     of equal values, which are equal);
#   - the y window is the same float test abs(y_i - y_j) < 0.01, in the
#     same direction (plan F14: it admits 160 of 392 three-row pairs with
#     the data row above the contour row and 161 with it below on OLD, so
#     an integer row window would differ);
#   - distance_shape is computed by the legacy expressions once per
#     distinct (y, side) instead of once per row: the value depends only on
#     them (rows are mapped back by exact double match);
#   - compute_distances() keeps the legacy write and read of the temp CSV
#     between the passes, so every value goes through the same 15-digit
#     round trips.
# The default of step 2 (rac_distance_impl(), decision A-076); RAC_DISTANCE_IMPL=legacy
# runs the row loops instead.
#
# min_dist_vec(new_data, contour_df)    numeric, one per row of new_data
# horiz_dist_vec(new_data, contour_df)  numeric; Inf where no contour point
#                                       has abs(dy) < 0.01 (the caller
#                                       applies the legacy fallback)
# distance_shape_vec(x, y, distance_per_y)
#                                       numeric (legacy window y +- 0.01,
#                                       first which.min, nearest-y fallback)
# compute_distances(dataCC, contour_df, P)
#                                       the data frame of the second temp
#                                       CSV read back, as the legacy chunks
#                                       leave it before distance_shape

.rac_rows_by_shoe <- function(new_data, contour_df) {
  rows <- split(seq_len(nrow(new_data)), new_data$shoe)
  pts <- split(seq_len(nrow(contour_df)), contour_df$shoe)
  missing <- setdiff(names(rows), names(pts))
  if (length(missing)) {
    stop("no contour points for shoe code(s) ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  list(rows = rows, pts = pts)
}

min_dist_vec <- function(new_data, contour_df) {
  out <- rep(NA_real_, nrow(new_data))
  g <- .rac_rows_by_shoe(new_data, contour_df)
  for (s in names(g$rows)) {
    i <- g$rows[[s]]
    j <- g$pts[[s]]
    d <- sqrt(outer(new_data$x[i], contour_df$x[j], "-")^2 +
                outer(new_data$y[i], contour_df$y[j], "-")^2)
    out[i] <- apply(d, 1, min)
  }
  out
}

horiz_dist_vec <- function(new_data, contour_df) {
  out <- rep(Inf, nrow(new_data))
  g <- .rac_rows_by_shoe(new_data, contour_df)
  for (s in names(g$rows)) {
    i <- g$rows[[s]]
    j <- g$pts[[s]]
    dy <- outer(new_data$y[i], contour_df$y[j], "-")
    d <- sqrt(outer(new_data$x[i], contour_df$x[j], "-")^2 + dy^2)
    d[!(abs(dy) < 0.01)] <- Inf
    out[i] <- apply(d, 1, min)
  }
  out
}

# The legacy expression of one row, kept as it is (dataCC_distance_2.Rmd).
.rac_distance_shape_one <- function(y_val, left, distance_per_y) {
  if (left) {
    new_val <- distance_per_y[(distance_per_y$y >= y_val - 0.01) & (distance_per_y$y <= y_val + 0.01), c("y", "min_x")]
    if (nrow(new_val) > 0) {
      closest_row_index <- which.min(abs(new_val$y - y_val))
      closest_value <- new_val[closest_row_index, ]$min_x
    } else {
      closest_y_index <- which.min(abs(distance_per_y$y - y_val))
      closest_value <- abs(distance_per_y[closest_y_index, ]$min_x)
    }
  } else {
    new_val <- distance_per_y[(distance_per_y$y >= y_val - 0.01) & (distance_per_y$y <= y_val + 0.01), c("y", "max_x")]
    if (nrow(new_val) > 0) {
      closest_row_index <- which.min(abs(new_val$y - y_val))
      closest_value <- new_val[closest_row_index, ]$max_x
    } else {
      closest_y_index <- which.min(abs(distance_per_y$y - y_val))
      closest_value <- distance_per_y[closest_y_index, ]$max_x
    }
  }
  closest_value
}

distance_shape_vec <- function(x, y, distance_per_y) {
  out <- rep(NA_real_, length(x))
  for (left in c(TRUE, FALSE)) {
    rows <- which((x <= 0) == left)
    if (!length(rows)) next
    uy <- unique(y[rows])
    vals <- vapply(uy, .rac_distance_shape_one, numeric(1), left = left,
                   distance_per_y = distance_per_y)
    out[rows] <- vals[match(y[rows], uy)]
  }
  out
}

compute_distances <- function(dataCC, contour_df, P) {
  new_data <- dataCC
  new_data$row_number <- seq_len(nrow(new_data))
  new_data$min_dist <- min_dist_vec(new_data, contour_df)
  rac_write_csv(new_data, P, "dataCC_distance_temp")
  new_data <- read.csv(rac_path(P, "dataCC_distance_temp"), header = TRUE)
  new_data$horiz_dist <- horiz_dist_vec(new_data, contour_df)
  inf <- is.infinite(new_data$horiz_dist)
  new_data$horiz_dist[inf] <- new_data$min_dist[inf]
  rac_write_csv(new_data, P, "dataCC_distance_temp")
  read.csv(rac_path(P, "dataCC_distance_temp"), header = TRUE)
}
