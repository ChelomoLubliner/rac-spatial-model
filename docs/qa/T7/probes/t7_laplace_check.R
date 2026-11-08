# t7_laplace_check.R: do the surrogate OLD bootstrap draws (PIRLS at the
# committed theta, tools/part2_old_draws.R) move like Laplace refits of the
# same resamples? Reads part2_path(P_old, "old_glmm_draws_laplace_check",
# "rds") (written by `tools/part2_old_draws.R --laplace 8`) and the
# B = 2000 draws. For each checked resample b and coefficient: the Laplace
# deviation from the committed fit, the surrogate deviation from the
# surrogate's full-data fit, and their difference in units of the
# bootstrap SD; plus the normalized NEW cell expectations (Naomi's areas on
# (-new_x, y), all NEW shoes) under both, as a Part 2 quantity.
#
# Run from the repository root: Rscript docs/qa/T7/probes/t7_laplace_check.R
suppressMessages({
  library(splines)
  library(lme4)
})
ROOT_PATH <- paste(normalizePath("."), "/", sep = "")
for (f in c("profile.R", "io.R", "distances.R", "compare.R", "validation.R")) {
  source(file.path(ROOT_PATH, "statistical_model", "R", f))
}
P_old <- rac_profile("old", root = ROOT_PATH)
P_new <- rac_profile("new", root = ROOT_PATH)
lc <- readRDS(part2_path(P_old, "old_glmm_draws_laplace_check", "rds"))
dr <- readRDS(part2_path(P_old, "old_glmm_draws", "rds"))
stopifnot(identical(lc$ids, dr$ids[lc$b, , drop = FALSE]))
sd_b <- apply(dr$draws, 2, sd)
dev_lap <- sweep(lc$laplace, 2, lc$beta_old)
dev_pir <- sweep(lc$pirls, 2, lc$pirls_full)
stopifnot(max(abs(lc$pirls - dr$beta_pirls[lc$b, ])) < 1e-8)
z <- sweep(dev_pir - dev_lap, 2, sd_b, "/")
cat(sprintf("checked resamples: %s; Laplace conv codes %s; seconds per Laplace refit %s\n",
            paste(lc$b, collapse = ","), paste(lc$conv, collapse = ","),
            paste(round(lc$seconds), collapse = ",")))
cat(sprintf("theta (sd of the shoe effect): committed %.4f; Laplace refits %s\n",
            lc$theta_old, paste(sprintf("%.4f", lc$theta_laplace), collapse = ", ")))
cat(sprintf(paste("|surrogate deviation - Laplace deviation| / bootstrap SD,",
                  "24 spatial coefficients x %d resamples: median %.3f, p90 %.3f,",
                  "max %.3f\n"), nrow(z), median(abs(z[, -1])),
            quantile(abs(z[, -1]), 0.9), max(abs(z[, -1]))))
cat(sprintf("correlation of the two deviations (spatial coefficients): %.4f\n",
            cor(as.vector(dev_pir[, -1]), as.vector(dev_lap[, -1]))))
cat(sprintf("ratio of their spreads (sd surrogate / sd Laplace deviations): %.3f\n",
            sd(as.vector(dev_pir[, -1])) / sd(as.vector(dev_lap[, -1]))))
# the Part 2 quantity: pooled normalized expected counts on Naomi's areas
basis <- part2_basis(readRDS(rac_model_path(P_old, "NEW_X_NS_XY")))
px <- part2_pixel_table_cached(P_new)
cuts <- read.csv(part2_path(P_old, "part2_grid_cuts"))
prep <- part2_prepare(px, basis, cuts, length(attr(px, "shoes")))
pc_old <- read.csv(rac_path(P_old, "pixel_counts"))
off <- mean(log(P_old$r$n_controls / pc_old$pixel_count))
pooled <- function(beta) {
  ev <- part2_eval(prep, part2_coef_parts(beta), "logit", off)
  colSums(normalize_expected(part2_agg(prep, ev$Eg, "a14"), prep$n))
}
E0 <- pooled(lc$beta_old)
rows <- lapply(seq_along(lc$b), function(k) {
  b <- lc$b[k]
  el <- pooled(setNames(lc$laplace[k, ], names(lc$beta_old)))
  es <- pooled(setNames(dr$draws[b, ], names(lc$beta_old)))
  c(max_abs_diff = max(abs(es - el)), max_abs_shift_laplace = max(abs(el - E0)),
    max_abs_shift_surrogate = max(abs(es - E0)))
})
tab <- do.call(rbind, rows)
print(round(cbind(b = lc$b, tab), 2), row.names = FALSE)
cat(sprintf(paste("Naomi's areas, all NEW shoes (N = %d): the surrogate's",
                  "expected counts differ from the Laplace refit's by at most",
                  "%.2f RACs per area, while the draws move them by up to %.2f",
                  "(Laplace) and %.2f (surrogate)\n"), sum(prep$n),
            max(tab[, 1]), max(tab[, 2]), max(tab[, 3])))
