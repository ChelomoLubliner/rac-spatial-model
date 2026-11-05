# Tier A invariants of the committed OLD outputs (plan T1 step 1).
# Run from anywhere: Rscript tests/r/test_baseline_committed.R
# Reads committed files only; writes nothing.

suppressMessages({
  library(lme4)
  library(survival)
})
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
source(file.path(root, "statistical_model", "R", "wald.R"))
source(file.path(root, "tests", "lib", "dump_models.R"))
p <- function(...) file.path(root, ...)
pass <- function(name) cat("PASS", name, "\n")

# GLMM NEW_X_NS_XY (written by R 4.4.3 with lme4 1.1-37 on Windows)
g <- readRDS(p("saved_models", "NEW_X_NS_XY.rds"))
stopifnot(inherits(g, "glmerMod"), nobs(g) == 51849, ngrps(g) == 386,
          length(fixef(g)) == 25, g@optinfo$conv$opt == 0,
          g@optinfo$optimizer == "nlminbwrap",
          identical(dim(g@optinfo$derivs$Hessian), c(26L, 26L)))
s2 <- as.numeric(attr(VarCorr(g)$shoe, "stddev"))^2
stopifnot(round(s2, 7) == 0.9597791)
pass("glmm_structure (nobs 51849, 386 shoes, 25 fixef, conv 0, Hessian)")

w <- wald_all_spatial(g, use_car = FALSE)
stopifnot(w$df == 24, round(w$W, 2) == 428.69, w$p < 1e-70)
pass(sprintf("glmm_manual_wald W = %.4f df = %d p = %.3g", w$W, w$df, w$p))

# CML (written by R 4.3.3)
cm <- readRDS(p("saved_models", "CML_MODEL.rds"))
stopifnot(inherits(cm, "clogit"), length(coef(cm)) == 24, cm$nevent == 13249,
          cm$n == 51849, cm$method == "exact")
pass("cml_structure (24 coefficients, exact, 13249 events)")

# Case-control data
a <- read.csv(p("processed_data", "dataCC.csv"))
d <- read.csv(p("processed_data", "dataCC_distance.csv"))
stopifnot(nrow(a) == 51849, sum(a$n_Acc) == 13249,
          length(unique(a$shoe)) == 386,
          all(table(a$shoe[a$n_Acc == 0]) == 100),
          identical(sort(unique(a$shoe)), 1:386))
pass("dataCC (51849 rows, 13249 cases, 386 shoes, 100 controls each)")
cols <- c("n_Acc", "x", "y", "shoe")
stopifnot(identical(a[, cols], d[, cols]),
          identical(d$row_number, seq_len(nrow(d))),
          !anyNA(d$new_x), all(is.finite(d$horiz_dist)))
pass("dataCC_distance (n_Acc, x, y, shoe) identical to dataCC")

# MEAN_OFFSET as config.R computes it (sourced from statistical_model/)
env <- new.env()
old_wd <- setwd(p("statistical_model"))
source("config.R", local = env)
setwd(old_wd)
stopifnot(round(env$MEAN_OFFSET, 9) == -4.614310784,
          env$MODEL_FEATURE == "NEW_X_NS_XY", env$N_CONTROLS == 100)
pass(sprintf("config.R MEAN_OFFSET = %.9f", env$MEAN_OFFSET))

# The Tier A model dump is current
d_now <- dump_models(p("saved_models", "NEW_X_NS_XY.rds"),
                     p("saved_models", "CML_MODEL.rds"))
d_base <- readRDS(p("tests", "baseline", "models_committed.rds"))
stopifnot(identical(d_now, d_base))
tab <- read.csv(p("tests", "baseline", "old_model_summary.csv"),
                colClasses = c(value = "character"))
fx <- tab[tab$model == "glmm" & tab$quantity == "fixef", ]
cc <- tab[tab$model == "cml" & tab$quantity == "coef", ]
stopifnot(identical(as.numeric(fx$value), unname(d_base$fixef)),
          identical(as.numeric(cc$value), unname(d_base$cml_coef)),
          identical(fx$name, names(d_base$fixef)))
pass("models_committed.rds and old_model_summary.csv match the committed models")

cat("ALL PASS test_baseline_committed\n")
