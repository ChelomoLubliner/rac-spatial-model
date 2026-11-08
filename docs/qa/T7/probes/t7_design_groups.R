# t7_design_groups.R: Part 2 residuals by the NEW design groups of plan F79
# (plan T7 step 4, A-120): group A = NEW ids 1-343 and 442-490, group B =
# the other NEW shoes. DESCRIPTIVE ONLY: group A was selected on NEW's own
# heel-front band data (T5), so a split by it is circular in that band; a
# confirmatory split needs a design classification made from the images
# without the RAC locations (meeting question 6).
#
# Reads processed_data/validation/new/part2_cells_new.csv and the
# provisional shoe set; per group (primary set): the pooled O and the OLD
# GLMM's normalized E per cell of Naomi's areas and of the 15-cell grid,
# O/E with a NEW-only shoe-bootstrap 95% interval (B = 2000, fit fixed;
# seed 20261105), and the fixed-surface X^2.
#
# Run from the repository root: Rscript docs/qa/T7/probes/t7_design_groups.R
root <- normalizePath(".")
cells <- read.csv(file.path(root, "processed_data/validation/new/part2_cells_new.csv"))
ss <- read.csv(file.path(root, "processed_data/validation/new/part2_shoe_set_provisional_new.csv"))
prim <- ss$shoe[ss$include_primary]
grpA <- c(1:343, 442:490)
set.seed(20261105)
for (part in c("a14", "g15")) {
  cat("==", part, "\n")
  d <- cells[cells$partition == part & cells$shoe %in% prim, ]
  K <- max(d$cell)
  out <- NULL
  for (g in c("A", "B")) {
    shoes <- if (g == "A") intersect(prim, grpA) else setdiff(prim, grpA)
    dg <- d[d$shoe %in% shoes, ]
    O <- tapply(dg$O, dg$cell, sum)
    E <- tapply(dg$E_glmm, dg$cell, sum)
    Om <- matrix(dg$O[order(dg$cell, dg$shoe)], ncol = K)
    Em <- matrix(dg$E_glmm[order(dg$cell, dg$shoe)], ncol = K)
    boot <- replicate(2000, {
      i <- sample(nrow(Om), replace = TRUE)
      colSums(Om[i, , drop = FALSE]) / colSums(Em[i, , drop = FALSE])
    })
    ci <- apply(boot, 1, quantile, c(0.025, 0.975))
    x2 <- sum((O - E)^2 / E)
    cat(sprintf("group %s: %d shoes, %d RACs, fixed-surface X^2 %.1f (df %d)\n", g,
                length(shoes), sum(O), x2, K - 1))
    out <- rbind(out, data.frame(group = g, cell = seq_len(K), O = as.vector(O),
                                 E = round(as.vector(E), 1),
                                 OE = round(as.vector(O / E), 3),
                                 lo = round(ci[1, ], 3), hi = round(ci[2, ], 3)))
  }
  w <- reshape(out, idvar = "cell", timevar = "group", direction = "wide")
  print(w, row.names = FALSE)
}
