# Diagnostic (T1): the legacy step-5 linearHypothesis chunk, verbatim, on
# the committed GLMM, next to the manual Wald test of statistical_model/R/
# wald.R. Needs the car package (not installed on WSL; run it with an R
# that has car, e.g. the Windows R 4.4.3).
# Usage: Rscript diag_wald_car.R <repo root>
args <- commandArgs(trailingOnly = TRUE)
root <- args[1]
suppressMessages({
  library(lme4)
  library(survival)
  library(car)
})
random_model <- readRDS(file.path(root, "saved_models", "NEW_X_NS_XY.rds"))
cat(R.version.string, "| lme4", as.character(packageVersion("lme4")),
    "| car", as.character(packageVersion("car")), "\n")

# --- statistical_tests_5.Rmd, chunk linearHypothesis_test (verbatim) ---
co <- fixef(random_model)
vc <- vcov(random_model)

# Contrast matrix: identity matrix minus first row (intercept)
matr <- diag(length(co))[-1, ]

testing <- linearHypothesis(random_model,
                            hypothesis.matrix = matr,
                            rhs = rep(0, length(co) - 1),
                            test = c("Chisq", "F"),
                            vcov. = vc, coef. = co)
print(testing)
# --- end of the legacy chunk ---

source(file.path(root, "statistical_model", "R", "wald.R"))
w <- wald_all_spatial(random_model)
print(w)
cat(sprintf("legacy car Chisq %.17g | manual W %.17g | W_car %.17g\n",
            testing$Chisq[2], w$W, w$W_car))
cat(sprintf("relative difference manual vs legacy car: %.3g\n",
            abs(w$W - testing$Chisq[2]) / testing$Chisq[2]))
cml <- readRDS(file.path(root, "saved_models", "CML_MODEL.rds"))
wc <- wald_all_spatial(cml)
print(wc)
