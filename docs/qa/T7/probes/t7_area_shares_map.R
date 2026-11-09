# Part 2, Naomi's 14 areas on the standardized shoe: the OLD GLMM's predicted
# share of the NEW RACs per area (sum of p * S, random effect 0), the observed
# share, and observed / predicted (primary set). Reads only committed T7
# outputs (part2_contrast_new.csv) and the OLD prototype; no fit.
# Run from the repository root: Rscript docs/qa/T7/probes/t7_area_shares_map.R
# Writes model_images/validation/new/part2_area_shares_new.{png,pdf} and
# processed_data/validation/new/part2_area_shares_new.csv.
suppressMessages(library(dplyr))
ROOT_PATH <- paste(getwd(), "/", sep = "")
for (f in c("profile.R", "io.R", "distances.R", "compare.R", "validation.R")) {
  source(paste(ROOT_PATH, "statistical_model/R/", f, sep = ""))
}
P_old <- rac_profile("old", root = ROOT_PATH)
proto <- t(as.matrix(imager::load.image(rac_path(P_old, "prototype_mask"))))
pxy <- part2_coords(P_old)
inside <- which(proto == 1, arr.ind = TRUE)
area <- naomi_area(-pxy$x[inside[, 2]], pxy$y[inside[, 1]])

ct <- read.csv(paste(ROOT_PATH, "processed_data/validation/new/part2_contrast_new.csv", sep = ""))
ct <- ct[ct$partition == "a14" & ct$model == "glmm", ]
ct <- ct[order(ct$cell), ]
stopifnot(nrow(ct) == 14, all(ct$cell == 1:14))
tab <- data.frame(area = ct$cell,
                  predicted_pct = 100 * ct$E / sum(ct$E),
                  observed_pct = 100 * ct$O / sum(ct$O),
                  uniform_pct = 100 * ct$E_unif / sum(ct$E_unif),
                  predicted_vs_uniform = ct$E_over_unif,
                  observed_vs_uniform = ct$O_over_unif,
                  observed_vs_predicted = ct$OE)
write.csv(tab, paste(ROOT_PATH, "processed_data/validation/new/part2_area_shares_new.csv", sep = ""),
          row.names = FALSE)

zl <- log2(c(0.5, 2))
pal <- grDevices::colorRampPalette(c("#2c5aa0", "#9cc3e6", "#f7f7f7", "#f4a582", "#b2182b"))(41)
rows <- range(inside[, 1]) + c(-5, 5)
colsr <- range(inside[, 2]) + c(-5, 5)
C <- matrix(NA_integer_, nrow(proto), ncol(proto))
C[inside] <- area
Cc <- C[rows[1]:rows[2], colsr[1]:colsr[2]]
panel <- function(colour_value, label, main) {
  M <- matrix(NA_real_, nrow(proto), ncol(proto))
  M[inside] <- pmax(pmin(log2(colour_value[area]), zl[2]), zl[1])
  Mc <- M[rows[1]:rows[2], colsr[1]:colsr[2]]
  image(t(Mc)[, nrow(Mc):1], col = pal, zlim = zl, axes = FALSE,
        asp = nrow(Mc) / ncol(Mc), useRaster = TRUE)
  mtext("toe", side = 3, line = -1, cex = 0.6)
  mtext("heel", side = 1, line = -0.2, cex = 0.6)
  edge <- (Cc != cbind(Cc[, -1], NA)) | (Cc != rbind(Cc[-1, ], NA))
  edge[is.na(edge)] <- FALSE
  ee <- which(edge, arr.ind = TRUE)
  points((ee[, 2] - 1) / (ncol(Cc) - 1), 1 - (ee[, 1] - 1) / (nrow(Cc) - 1), pch = ".", col = "grey20")
  for (k in 1:14) {
    w <- which(Cc == k, arr.ind = TRUE)
    if (!nrow(w)) next
    text(mean((w[, 2] - 1) / (ncol(Cc) - 1)), mean(1 - (w[, 1] - 1) / (nrow(Cc) - 1)),
         label[k], cex = 0.6)
  }
  title(main = main, cex.main = 0.85)
}
draw <- function() {
  op <- par(mar = c(1.5, 0.5, 3, 0.5))
  layout(matrix(c(1, 2, 3, 4, 4, 4), 2, byrow = TRUE), heights = c(1, 0.1))
  panel(tab$predicted_vs_uniform, sprintf("%.1f%%", tab$predicted_pct),
        "Our model (OLD GLMM, b = 0): predicted %\ncolour: predicted / uniform")
  panel(tab$observed_vs_uniform, sprintf("%.1f%%", tab$observed_pct),
        "New shoes: observed %\ncolour: observed / uniform")
  panel(tab$observed_vs_predicted, sprintf("%.2f", tab$observed_vs_predicted),
        "Observed / predicted\n(red: more than predicted)")
  par(mar = c(2, 20, 0.5, 20))
  image(matrix(seq(zl[1], zl[2], length.out = 41)), col = pal, axes = FALSE, useRaster = TRUE)
  axis(1, at = seq(0, 1, length.out = 5), labels = c("0.5", "0.71", "1", "1.41", "2"),
       cex.axis = 0.6, mgp = c(1, 0.2, 0), tcl = -0.2)
  mtext("ratio (log scale)", side = 1, line = 0.9, cex = 0.55)
  par(op)
}
out <- paste(ROOT_PATH, "model_images/validation/new/part2_area_shares_new", sep = "")
png(paste(out, ".png", sep = ""), width = 1500, height = 1050, res = 150)
draw()
invisible(dev.off())
pdf(paste(out, ".pdf", sep = ""), width = 10, height = 7)
draw()
invisible(dev.off())
print(format(tab, digits = 3))
