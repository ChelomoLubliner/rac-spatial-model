# T0 read-only probes (R side). Run from the repo root:
#   Rscript docs/qa/T0/probes/t0_probe.R
# Reads committed files only; writes nothing.
suppressMessages({
  library(lme4)
  library(survival)
})
cat("=== R environment\n")
cat(R.version.string, "\n")
si <- sessionInfo()
cat("BLAS:", si$BLAS, "\nLAPACK:", si$LAPACK, "\n")
cat("RNGkind:", RNGkind(), "\n")
pk <- c("rmarkdown", "knitr", "lme4", "survival", "splines", "imager",
        "fields", "smoothie", "plotly", "rgl", "dplyr", "ggplot2",
        "data.table", "doParallel", "jsonlite", "digest", "png", "boot",
        "car", "hglm", "testthat", "sandwich", "pdftools", "magick")
ip <- rownames(installed.packages())
for (p in pk) {
  cat(sprintf("%-11s installed=%-5s %s\n", p, p %in% ip,
              if (p %in% ip) as.character(packageVersion(p)) else ""))
}

cat("\n=== committed model files (serialization info)\n")
for (f in c("saved_models/NEW_X_NS_XY.rds", "saved_models/CML_MODEL.rds")) {
  i <- infoRDS(f)
  cat(f, ": writer R", as.character(i$writer_version), "\n")
}

cat("\n=== committed GLMM NEW_X_NS_XY\n")
m <- readRDS("saved_models/NEW_X_NS_XY.rds")
cat("class:", class(m), " optimizer:", m@optinfo$optimizer,
    " conv:", m@optinfo$conv$opt, "\n")
cat("nobs:", nobs(m), " groups:", ngrps(m), " n fixef:", length(fixef(m)),
    "\n")
s2 <- as.numeric(attr(VarCorr(m)$shoe, "stddev"))^2
cat(sprintf("sigma^2 = %.7f  exp(-s2/2) = %.4f  exp(+s2/2) = %.4f\n",
            s2, exp(-s2 / 2), exp(s2 / 2)))
co <- fixef(m)
vc <- as.matrix(vcov(m))
b <- co[-1]
w <- as.numeric(t(b) %*% solve(vc[-1, -1], b))
cat(sprintf(paste("manual Wald (all 24 spatial coef = 0):",
                  "W = %.4f df = %d p = %.3g\n"),
            w, length(b), pchisq(w, length(b), lower.tail = FALSE)))
cat("first fixef names:\n")
print(head(names(co), 3))

cat("\n=== committed CML_MODEL\n")
cm <- readRDS("saved_models/CML_MODEL.rds")
cat("class:", class(cm), " n coef:", length(coef(cm)), "\n")

cat("\n=== committed processed data consistency\n")
a <- read.csv("processed_data/dataCC.csv")
d <- read.csv("processed_data/dataCC_distance.csv")
cols <- c("n_Acc", "x", "y", "shoe")
cat("dataCC rows:", nrow(a), " cases:", sum(a$n_Acc), " shoes:",
    length(unique(a$shoe)), "\n")
cat("dataCC_distance rows:", nrow(d), " same (n_Acc,x,y,shoe):",
    isTRUE(all.equal(a[, cols], d[, cols], tolerance = 0)), "\n")
cat("controls per shoe (unique):", unique(table(a$shoe[a$n_Acc == 0])), "\n")
pc <- read.csv("processed_data/shoe_pixel_counts.csv")
cat(sprintf(paste("pixel counts: n=%d mean=%.4f MEAN_OFFSET=%.9f",
                  "log(100/mean)=%.4f\n"),
            nrow(pc), mean(pc$pixel_count), mean(log(100 / pc$pixel_count)),
            log(100 / mean(pc$pixel_count))))
cat("knots new_x:", format(quantile(d$new_x, 1:3 / 4), digits = 6), "\n")
cat("knots y    :", format(quantile(d$y, 1:5 / 6), digits = 6), "\n")
cat("range new_x:", format(range(d$new_x), digits = 6), " range y:",
    format(range(d$y), digits = 6), "\n")

cat("\n=== R semantics used by the legacy stamp sweep\n")
cat("logical(0) && TRUE  ->", format(logical(0) && TRUE), "\n")
cat("logical(0) && FALSE ->", format(logical(0) && FALSE), "\n")

cat("\n=== float semantics of abs(dy) < 0.01 in dataCC_distance_2.Rmd\n")
# data y values pass through write.csv (15 significant digits); contour y
# values are computed in memory, exactly as in the Rmd.
ys <- -((-395 / 2 + 1:395) * 0.5 / 150)
ys_csv <- as.numeric(sprintf("%.15g", ys))
for (k in 2:4) {
  dk <- abs(ys_csv[1:(395 - k)] - ys[(1 + k):395])
  cat(sprintf("|drow| = %d: pairs with abs(dy) < 0.01: %d of %d\n",
              k, sum(dk < 0.01), length(dk)))
}

cat("\n=== legacy stamp sweep (dataCC_1.Rmd lines 93-136) on NEW dims\n")
read_shoes <- function(path, w, h, n) {
  v <- as.integer(readBin(path, "raw", n = file.size(path))) - 48L
  stride <- w * h + 2
  lapply(seq_len(n), function(i) {
    matrix(v[(i - 1) * stride + seq_len(w * h)], h, w, byrow = TRUE)
  })
}
sweep_mask <- function(allcont, col_shoe, row_shoe, bound) {
  h_width <- floor(row_shoe / 2)
  lb <- rep(NA, h_width)
  j <- 1
  while (allcont[h_width, j] == 0) j <- j + 1
  lb[1] <- j - 1
  for (i in 2:h_width) {
    j <- lb[i - 1]
    if (allcont[h_width - i + 1, j] == 0) {
      while ((allcont[h_width - i + 1, j] == 0) && j < bound) j <- j + 1
      lb[i] <- j - 1
    } else {
      while ((allcont[h_width - i + 1, j] == 1) && j > 0) j <- j - 1
      lb[i] <- j
    }
  }
  for (i in 1:h_width) allcont[h_width - i + 1, 1:lb[i]] <- 0
  ub <- rep(NA, h_width)
  j <- col_shoe
  while (allcont[h_width, j] == 0) j <- j - 1
  ub[1] <- j + 1
  for (i in 2:h_width) {
    j <- ub[i - 1]
    if (allcont[h_width - i + 1, j] == 0) {
      while ((allcont[h_width - i + 1, j] == 0) && j > 0) j <- j - 1
      ub[i] <- j + 1
    } else {
      while ((allcont[h_width - i + 1, j] == 1) && j < bound) j <- j + 1
      ub[i] <- j
    }
  }
  for (i in 1:h_width) allcont[h_width - i + 1, ub[i]:col_shoe] <- 0
  allcont
}
new <- read_shoes("data/new_shoes/contacts_data_new.txt", 255, 367, 631)
tot <- Reduce(`+`, new)
for (t in c(8, 13)) {
  ac <- (tot >= t) * 1
  r300 <- tryCatch({
    sweep_mask(ac, 255, 367, 300)
    "ok"
  }, error = function(e) paste("ERROR:", conditionMessage(e)))
  r255 <- sweep_mask(ac, 255, 367, 255)
  cat(sprintf(paste("new t=%d: >=t px=%d | sweep with legacy bound 300:",
                    "%s | with bound col_shoe=255: kept px=%d removed=%d\n"),
              t, sum(ac), r300, sum(r255), sum(ac) - sum(r255)))
}
