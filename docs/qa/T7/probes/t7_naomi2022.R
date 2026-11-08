# t7_naomi2022.R: the 2022 regional (CML) estimates recomputed with Naomi's
# own code path (plan section 9: "T7 compares it with a port of Naomi's
# funLogCMLlambda and with the published estimates if they can be found").
# The published table is not in the repository, so the 2022 pipeline is
# rerun on the committed OLD inputs: her contact surface (raw records, shoe
# 9 mirrored, the window rows/cols of rel_* kept, then every record
# mirrored; no stamp sweep, RAC pixels not added), her pixel-level area
# masks (subshape(), ported line for line), chi = contact pixels per area
# / 10000, n_ij = table(shoe, sub_area) of the RACs, and her CML_estimator
# (optim from the naive estimator, default Nelder-Mead, as in 2022) plus a
# BFGS run to convergence. Compared with the T7 regional theta r2022
# (part2_regional_theta.csv: Naomi's area rule at each pixel centre of the
# step-1 contact surface S).
#
# Run from the repository root: Rscript docs/qa/T7/probes/t7_naomi2022.R
ROOT_PATH <- paste(normalizePath("."), "/", sep = "")
for (f in c("profile.R", "io.R", "validation.R")) {
  source(file.path(ROOT_PATH, "statistical_model", "R", f))
}
P <- rac_profile("old", root = ROOT_PATH)
col_shoe <- P$col_shoe
row_shoe <- P$row_shoe
num_shoe <- P$num_shoe
rel_row_shoe <- P$coords$rel_row_shoe
rel_x_cord <- P$coords$rel_x_cord
rel_Y_cord <- P$coords$rel_Y_cord

data <- part2_read_records(rac_path(P, "contacts"), col_shoe, row_shoe, num_shoe)
data[[9]] <- data[[9]][, ncol(data[[9]]):1]
for (i in 1:num_shoe) {
  temp <- matrix(0, row_shoe, col_shoe)
  rr <- floor(row_shoe / 2 - rel_Y_cord * rel_row_shoe):floor(row_shoe / 2 + rel_Y_cord * rel_row_shoe)
  cc <- floor(col_shoe / 2 - rel_x_cord * rel_row_shoe):floor(col_shoe / 2 + rel_x_cord * rel_row_shoe)
  temp[rr, cc] <- data[[i]][rr, cc]
  data[[i]] <- temp
  data[[i]] <- data[[i]][, ncol(data[[i]]):1]
}

subshape <- function(j, int) {
  res <- matrix(0, row_shoe, col_shoe)
  sep <- -c(-0.5, -0.35, -0.15, 0, 0.15, 0.5)
  sepPix <- floor(rel_row_shoe * sep + row_shoe / 2)
  if (j <= 5) {
    y <- sepPix[c(j + 1, j)]
    x <- c(1, (col_shoe - 1) / 2)
  } else {
    y <- sepPix[c(12 - j, 11 - j)]
    x <- c((col_shoe - 1) / 2 + 1, col_shoe)
  }
  res[((y[1]) + 1):(y[2]), (x[1]):(x[2])] <- 1
  bound <- function(x, k) {
    ifelse(k == 4, return(min(max(floor(-(12 * ((x - col_shoe / 2) / rel_row_shoe + 0.02)^2 - 0.07) * rel_row_shoe + row_shoe / 2), 1), row_shoe)),
           ifelse(k == 5, return(min(max(floor(-(-12 * ((x - col_shoe / 2) / rel_row_shoe + 0.01)^2 + 0.4) * rel_row_shoe + row_shoe / 2), 1), row_shoe)),
                  ifelse(k == 6, return(min(max(floor(-(-20 * ((x - col_shoe / 2) / rel_row_shoe + 0.01)^2 + 0.4) * rel_row_shoe + row_shoe / 2), 1), row_shoe)),
                         ifelse(k == 7, return(min(max(floor(-(16 * ((x - col_shoe / 2) / rel_row_shoe + 0.02)^2 - 0.07) * rel_row_shoe + row_shoe / 2), 1), row_shoe)),
                                return(1)))))
  }
  if (j == 4) {
    if (int == 0) {
      for (i in (x[1]):(x[2])) res[1:(bound(i, 4) - 1), i] <- 0
    } else {
      for (i in (x[1]):(x[2])) res[bound(i, 4):row_shoe, i] <- 0
    }
  }
  if (j == 5) {
    if (int == 0) {
      for (i in (x[1]):(x[2])) res[bound(i, 5):row_shoe, i] <- 0
    } else {
      for (i in (x[1]):(x[2])) res[1:(bound(i, 5) - 1), i] <- 0
    }
  }
  if (j == 6) {
    if (int == 0) {
      for (i in (x[1]):(x[2])) res[bound(i, 6):row_shoe, i] <- 0
    } else {
      for (i in (x[1]):(x[2])) res[1:(bound(i, 6) - 1), i] <- 0
    }
  }
  if (j == 7) {
    if (int == 0) {
      for (i in (x[1]):(x[2])) res[1:(bound(i, 7) - 1), i] <- 0
    } else {
      for (i in (x[1]):(x[2])) res[bound(i, 7):row_shoe, i] <- 0
    }
  }
  res
}
subshapes <- list()
for (i in 1:10) subshapes[[i]] <- subshape(i, 0)
for (i in 4:7) subshapes[[i + 7]] <- subshape(i, 1)
cover <- Reduce(`+`, subshapes)
cat("area masks: pixels covered 0 / 1 / 2+ times:", sum(cover == 0), sum(cover == 1),
    sum(cover >= 2), "\n")
chi <- matrix(0, num_shoe, 14)
for (i in 1:num_shoe) for (j in 1:14) chi[i, j] <- sum(data[[i]] * subshapes[[j]])
chi <- chi[-P$shoes_without_racs, ] / 10000
loc <- read_locations(P)
sub_area <- naomi_area(loc$x, loc$y)
n_ij <- matrix(as.numeric(table(loc$shoe, sub_area)), nrow(chi), 14, byrow = FALSE)
cat("RACs on a zero-contact cell of their area:", sum((chi == 0) * n_ij), "\n")
naive <- colMeans(n_ij / chi, na.rm = TRUE)
opt_nm <- optim(log(naive[-1] / naive[1]), naomi_funLogCMLlambda, hessian = TRUE,
                contact_mat = chi, n_ij = n_ij)
opt_bf <- optim(log(naive[-1] / naive[1]), naomi_funLogCMLlambda, method = "BFGS",
                contact_mat = chi, n_ij = n_ij, control = list(reltol = 1e-14, maxit = 1000))
th <- read.csv(file.path(ROOT_PATH, "processed_data/validation/part2_regional_theta.csv"))
r22 <- th[th$model == "r2022", ]
out <- data.frame(area = 1:14, naomi_nm = c(1, exp(opt_nm$par)),
                  naomi_bfgs = c(1, exp(opt_bf$par)), t7_r2022 = r22$theta_rel,
                  rac_naomi = colSums(n_ij), rac_t7 = r22$O_old,
                  px_naomi = round(colSums(chi) * 10000), px_t7 = r22$S_old)
out$t7_over_naomi <- out$t7_r2022 / out$naomi_bfgs
print(out, digits = 5, row.names = FALSE)
cat(sprintf("Nelder-Mead (2022 default): convergence %d, value %.4f; BFGS value %.4f\n",
            opt_nm$convergence, opt_nm$value, opt_bf$value))
cat(sprintf("max |T7 r2022 / Naomi 2022 (BFGS) - 1| = %.4f; max |NM / BFGS - 1| = %.4f\n",
            max(abs(out$t7_over_naomi - 1)), max(abs(out$naomi_nm / out$naomi_bfgs - 1))))
cat(sprintf("between-area ratio max/min: Naomi 2022 %.3f, T7 r2022 %.3f\n",
            max(out$naomi_bfgs) / min(out$naomi_bfgs), max(out$t7_r2022) / min(out$t7_r2022)))
