# Diagnostic (T1): how much do the plotted matrices of steps 4-6 differ
# between two pairs of models (committed vs refitted on this machine)?
# The PDFs cannot be byte-compared across R versions (plan F20), so this
# recomputes what they plot, with the formulas of shoe_std_results_4.Rmd,
# statistical_tests_5.Rmd and model_comparison_6.Rmd (copied, not sourced).
#
# Usage (repo root): Rscript tests/legacy/compare_figure_matrices.R \
#   <glmm_A.rds> <cml_A.rds> <glmm_B.rds> <cml_B.rds>
# Reads processed_data/dataCC_distance.csv, processed_data/
# shoe_pixel_counts.csv and data/freq_min_18.png; writes nothing.
suppressMessages({
  library(splines)
  library(lme4)
  library(survival)
  library(imager)
})
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4)
col_shoe <- 307
row_shoe <- 395
rel_col_shoe <- 150
rel_Y_cord <- 0.5
dataCC <- read.csv("processed_data/dataCC_distance.csv")
pc <- read.csv("processed_data/shoe_pixel_counts.csv")
MEAN_OFFSET <- mean(log(100 / pc$pixel_count))

xcoor <- t(matrix(rep((-col_shoe / 2 + 1:col_shoe) * rel_Y_cord / rel_col_shoe,
                      row_shoe), col_shoe, row_shoe))
ycoor <- -matrix(rep((-row_shoe / 2 + 1:row_shoe) * rel_Y_cord / rel_col_shoe,
                     col_shoe), row_shoe, col_shoe)
xy <- expand.grid(xcoor[1, ], ycoor[, 1])
colnames(xy) <- c("x", "y")
img <- t(as.matrix(load.image("data/freq_min_18.png")))
knots_new_x <- as.numeric(quantile(dataCC$new_x, 1:3 / 4))
knotsy <- as.numeric(quantile(dataCC$y, 1:5 / 6))
bas_new_x <- ns(dataCC$new_x, knots = knots_new_x)
basy <- ns(dataCC$y, knots = knotsy)
X <- rep(1, length(xy$x))
for (i in 1:length(predict(basy, 1))) {
  for (j in 1:length(predict(bas_new_x, 1))) {
    X <- cbind(X, predict(bas_new_x, xy$x)[, j] * predict(basy, xy$y)[, i])
  }
}
inside <- as.vector(t(img) != 0)

to_img <- function(v) matrix(v, row_shoe, col_shoe, byrow = TRUE)
inten <- function(eta) -log(1 - exp(eta) / (1 + exp(eta)))

figures <- function(glmm_path, cml_path) {
  g <- readRDS(glmm_path)
  cm <- readRDS(cml_path)
  s2 <- as.numeric(attr(VarCorr(g)$shoe, "stddev"))^2
  sc <- exp(-s2 / 2)
  eta_r <- X %*% fixef(g) + MEAN_OFFSET
  eta_r[!inside] <- NA
  m <- mean(eta_r, na.rm = TRUE)
  eta_c <- X %*% c(0, coef(cm))
  eta_c[!inside] <- NA
  eta_c <- eta_c - mean(eta_c, na.rm = TRUE) + m
  map_r <- to_img(inten(eta_r)) * sc
  map_c <- to_img(inten(eta_c)) * sc
  v_r <- as.matrix(vcov(g))
  v_c <- as.matrix(vcov(cm))
  se_r <- sqrt(rowSums((X %*% v_r) * X))
  se_c <- sqrt(rowSums((X[, -1] %*% v_c) * X[, -1]))
  band <- function(eta, se) {
    lapply(c(Low = -1, Mid = 0, High = 1),
           function(k) to_img(inten(eta + 1.96 * se * k)) * sc)
  }
  list(map_r = map_r, map_c = map_c,
       diff = map_r[, 40:(col_shoe - 40)] - map_c[, 40:(col_shoe - 40)],
       ci_r = band(eta_r, se_r), ci_c = band(eta_c, se_c), s2 = s2)
}

a <- figures(args[1], args[2])
b <- figures(args[3], args[4])
rel <- function(x, y) {
  ok <- !is.na(x) & !is.na(y) & x != 0
  max(abs(y[ok] - x[ok]) / abs(x[ok]))
}
cat(sprintf("sigma^2: A %.10f B %.10f\n", a$s2, b$s2))
for (nm in c("map_r", "map_c", "diff")) {
  cat(sprintf("%-6s (step %s): max |B - A| = %.3g, max |B - A| / |A| = %.3g, max |A| = %.3g\n",
              nm, c(map_r = "4 Random", map_c = "4 CML", diff = "6 diff")[nm],
              max(abs(b[[nm]] - a[[nm]]), na.rm = TRUE), rel(a[[nm]], b[[nm]]),
              max(abs(a[[nm]]), na.rm = TRUE)))
}
for (cut in c(110, 190, 250)) {
  for (est in c("ci_r", "ci_c")) {
    wa <- a[[est]]$High[cut, ] - a[[est]]$Low[cut, ]
    wb <- b[[est]]$High[cut, ] - b[[est]]$Low[cut, ]
    ok <- !is.na(wa)
    cat(sprintf("row %d %-6s: max |Mid B - Mid A| / Mid A = %.3g; band width B / A: min %.4f median %.4f max %.4f\n",
                cut, c(ci_r = "Random", ci_c = "CML")[est],
                rel(a[[est]]$Mid[cut, ], b[[est]]$Mid[cut, ]),
                min(wb[ok] / wa[ok]), median(wb[ok] / wa[ok]),
                max(wb[ok] / wa[ok])))
  }
}
