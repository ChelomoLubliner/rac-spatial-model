# t5_k8_edges.R: the K8 edges of the GLMM on both datasets (plan K8, F28;
# T5 step 4).
#
# The step-3 formula ns(new_x, knots):ns(y, knots) has no main effects, and
# both ns bases are 0 at their left boundary knot (the data minimum), so the
# fixed-effect log-odds equals the intercept along the whole edge
# new_x = min(new_x) and the whole heel edge y = min(y), while the opposite
# edges vary. For each dataset's GLMM this prints: the boundary knots, the
# check that eta = intercept on both left edges (computed on a grid along
# them), the range of eta along the right and top edges, eta over the
# case-control rows (p1, p50, p99), and the rows within 0.03 of each pinned
# edge (count, cases, median eta), as F28 did for OLD. Writes
# <compare>/k8_edges_old_vs_new.csv.
#
# Usage (repo root): Rscript docs/qa/T5/probes/t5_k8_edges.R COMPARE_DIR
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1)
suppressMessages({
  library(splines)
  library(lme4)
})
root <- normalizePath(".")
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
source(file.path(root, "statistical_model", "R", "compare.R"))

design <- function(nx, y, b) {
  bx <- ns(nx, knots = b$knots_x, Boundary.knots = b$bknots_x)
  by <- ns(y, knots = b$knots_y, Boundary.knots = b$bknots_y)
  X <- matrix(1, length(nx), 1)
  for (i in seq_len(ncol(by))) {
    for (j in seq_len(ncol(bx))) X <- cbind(X, bx[, j] * by[, i])
  }
  X
}

rows <- list()
for (ds in c("old", "new")) {
  P <- rac_profile(ds, root = ROOT_PATH)
  d <- read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
  m <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
  b <- basis_of(m)
  stopifnot(identical(b, basis_knots(d)))
  beta <- unname(fixef(m))
  eta <- as.vector(design(d$new_x, d$y, b) %*% beta)
  gy <- seq(b$bknots_y[1], b$bknots_y[2], length.out = 201)
  gx <- seq(b$bknots_x[1], b$bknots_x[2], length.out = 201)
  left <- as.vector(design(rep(b$bknots_x[1], 201), gy, b) %*% beta)
  heel <- as.vector(design(gx, rep(b$bknots_y[1], 201), b) %*% beta)
  right <- as.vector(design(rep(b$bknots_x[2], 201), gy, b) %*% beta)
  top <- as.vector(design(gx, rep(b$bknots_y[2], 201), b) %*% beta)
  near_x <- d$new_x <= b$bknots_x[1] + 0.03
  near_y <- d$y <= b$bknots_y[1] + 0.03
  r <- data.frame(
    dataset = ds, intercept = beta[1],
    bknot_x_lo = b$bknots_x[1], bknot_x_hi = b$bknots_x[2],
    bknot_y_lo = b$bknots_y[1], bknot_y_hi = b$bknots_y[2],
    left_edge_max_abs_dev = max(abs(left - beta[1])),
    heel_edge_max_abs_dev = max(abs(heel - beta[1])),
    right_edge_min = min(right), right_edge_max = max(right),
    top_edge_min = min(top), top_edge_max = max(top),
    eta_p1 = unname(quantile(eta, 0.01)), eta_p50 = median(eta),
    eta_p99 = unname(quantile(eta, 0.99)),
    near_left_rows = sum(near_x), near_left_cases = sum(d$n_Acc[near_x]),
    near_left_eta_median = median(eta[near_x]),
    near_heel_rows = sum(near_y), near_heel_cases = sum(d$n_Acc[near_y]),
    near_heel_eta_median = median(eta[near_y]))
  rows[[ds]] <- r
  cat(sprintf(paste("%s: intercept %.6f; left edge new_x = %.7f and heel",
                    "edge y = %.7f: max |eta - intercept| %.2g and %.2g;",
                    "right edge eta %.3f to %.3f, top edge %.3f to %.3f;",
                    "eta over dataCC p1/p50/p99 %.3f/%.3f/%.3f; within 0.03",
                    "of the left edge %d rows (%d cases), median eta %.3f;",
                    "of the heel edge %d rows (%d cases), median eta %.3f\n"),
              ds, beta[1], b$bknots_x[1], b$bknots_y[1],
              r$left_edge_max_abs_dev, r$heel_edge_max_abs_dev,
              r$right_edge_min, r$right_edge_max, r$top_edge_min,
              r$top_edge_max, r$eta_p1, r$eta_p50, r$eta_p99,
              r$near_left_rows, r$near_left_cases, r$near_left_eta_median,
              r$near_heel_rows, r$near_heel_cases, r$near_heel_eta_median))
}
out <- file.path(args[1], "k8_edges_old_vs_new.csv")
utils::write.csv(do.call(rbind, rows), out, row.names = FALSE)
cat("written", out, "\n")
