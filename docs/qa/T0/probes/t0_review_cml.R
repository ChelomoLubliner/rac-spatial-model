# T0 review-fix probe: can the exact CML carry a robust variance, and is an
# exact refit here identical to the committed CML? Run from the repo root:
#   Rscript docs/qa/T0/probes/t0_review_cml.R
# Reads committed files only; writes nothing. Takes about 3 minutes.
suppressMessages({
  library(survival)
  library(splines)
})
dat <- read.csv("processed_data/dataCC_distance.csv")
cm <- readRDS("saved_models/CML_MODEL.rds")
cat("committed CML method:", cm$method, "\n")
knots_new_x <- as.numeric(quantile(dat$new_x, 1:3 / 4))
knotsy <- as.numeric(quantile(dat$y, 1:5 / 6))
t0 <- Sys.time()
ex <- clogit(n_Acc ~ ns(new_x, knots = knots_new_x):ns(y, knots = knotsy) +
               strata(shoe), data = dat)
cat(sprintf("exact refit: %.1f s; coefficients identical() to committed: %s;",
            as.numeric(difftime(Sys.time(), t0, units = "secs")),
            identical(unname(coef(ex)), unname(coef(cm)))),
    "vcov identical():", identical(unname(vcov(ex)), unname(vcov(cm))),
    "| loglik identical():", identical(ex$loglik, cm$loglik), "\n")
r1 <- tryCatch({
  rs <- residuals(ex, type = "score")
  paste("available, dim", paste(dim(rs), collapse = " x "))
}, error = function(e) paste("ERROR:", conditionMessage(e)))
cat("score residuals of the exact fit:", r1, "\n")
r2 <- tryCatch({
  clogit(n_Acc ~ ns(new_x, knots = knots_new_x):ns(y, knots = knotsy) +
           strata(shoe) + cluster(shoe), data = dat, method = "exact")
  "fitted"
}, error = function(e) paste("ERROR:", conditionMessage(e)))
cat("exact method + cluster(shoe):", r2, "\n")
