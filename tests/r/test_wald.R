# Manual Wald test of statistical_model/R/wald.R (task rule 3, plan T2e).
# Run from anywhere: Rscript tests/r/test_wald.R
suppressMessages({
  library(lme4)
  library(survival)
})
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
source(file.path(root, "statistical_model", "R", "wald.R"))
pass <- function(name) cat("PASS", name, "\n")

g <- readRDS(file.path(root, "saved_models", "NEW_X_NS_XY.rds"))
w <- wald_all_spatial(g)
stopifnot(round(w$W, 2) == 428.69, w$df == 24, w$p < 1e-70)
pass(sprintf("committed GLMM: W = %.6f, df = %d, p = %.3g", w$W, w$df, w$p))

# Same statistic through the hypothesis-matrix form used by car:
# (L b)' (L V L')^-1 (L b) with L = I[-1, ], and through a Cholesky factor.
co <- fixef(g)
vc <- as.matrix(vcov(g))
L <- diag(length(co))[-1, ]
lb <- L %*% co
w_l <- as.numeric(t(lb) %*% solve(L %*% vc %*% t(L)) %*% lb)
w_chol <- sum(backsolve(chol(vc[-1, -1]), co[-1], transpose = TRUE)^2)
stopifnot(isTRUE(all.equal(w$W, w_l, tolerance = 1e-10)),
          isTRUE(all.equal(w$W, w_chol, tolerance = 1e-10)))
pass(sprintf("L-matrix form %.10f and Cholesky form %.10f agree", w_l, w_chol))

# An explicit V is used as given; V = I gives the sum of squares.
w_i <- wald_all_spatial(g, V = diag(length(co)), use_car = FALSE)
stopifnot(isTRUE(all.equal(w_i$W, sum(co[-1]^2), tolerance = 1e-12)))
pass("explicit V = identity gives sum(b^2)")

# V's dimnames must be the coefficient names in coefficient order (A-063,
# T1 review): a permuted V with dimnames is an error, not a wrong W.
stopifnot(identical(dimnames(vc), list(names(co), names(co))))
w_u <- wald_all_spatial(g, V = unname(vc), use_car = FALSE)
stopifnot(identical(w_u$W, w$W))
pass("V without dimnames is used by position (same W as the default)")
set.seed(1)
perm <- c(1, sample(2:25))
vp <- vc[perm, perm]
msg_of <- function(expr) {
  tryCatch({
    expr
    "no error"
  }, error = function(e) conditionMessage(e))
}
stopifnot(grepl("not the coefficient names",
                msg_of(wald_all_spatial(g, V = vp, use_car = FALSE))))
w_pos <- wald_all_spatial(g, V = unname(vp), use_car = FALSE)$W
stopifnot(abs(w_pos - w$W) > 100)
pass(sprintf(paste("permuted V with dimnames is an error (used by position",
                   "it would give W = %.2f)"), w_pos))
v_rn <- vc
rownames(v_rn) <- paste0("b", seq_along(co))
v_cn <- vc
colnames(v_cn) <- rev(names(co))
stopifnot(grepl("not the coefficient names",
                msg_of(wald_all_spatial(g, V = v_rn, use_car = FALSE))),
          grepl("not the coefficient names",
                msg_of(wald_all_spatial(g, V = v_cn, use_car = FALSE))))
pass("wrong row names or reversed column names are an error")

# The intercept is dropped by name: another merMod (lme4's cbpp data).
m1 <- glmer(cbind(incidence, size - incidence) ~ period + (1 | herd),
            data = cbpp, family = binomial)
w1 <- wald_all_spatial(m1, use_car = FALSE)
b1 <- fixef(m1)[names(fixef(m1)) != "(Intercept)"]
v1 <- as.matrix(vcov(m1))[names(b1), names(b1)]
stopifnot(w1$df == 3,
          isTRUE(all.equal(w1$W, drop(t(b1) %*% solve(v1) %*% b1),
                           tolerance = 1e-12)))
pass(sprintf("cbpp merMod: intercept dropped by name, W = %.4f, df = 3",
             w1$W))
m0 <- glmer(cbind(incidence, size - incidence) ~ 0 + period + (1 | herd),
            data = cbpp, family = binomial)
stopifnot(grepl("no \"\\(Intercept\\)\"", msg_of(wald_all_spatial(m0))))
pass("merMod without an intercept is an error")

# CML: no intercept, all 24 coefficients (T0: model-based W = 420.67)
cm <- readRDS(file.path(root, "saved_models", "CML_MODEL.rds"))
wc <- wald_all_spatial(cm)
stopifnot(wc$df == 24, round(wc$W, 2) == 420.67)
pass(sprintf("committed CML: W = %.6f, df = %d", wc$W, wc$df))

err <- tryCatch(wald_all_spatial(lm(dist ~ speed, cars)),
                error = function(e) conditionMessage(e))
stopifnot(grepl("unsupported model class", err))
pass("unsupported model class is an error")

if (requireNamespace("car", quietly = TRUE)) {
  stopifnot(isTRUE(all.equal(w$W, w$W_car, tolerance = 1e-8)),
            isTRUE(all.equal(wc$W, wc$W_car, tolerance = 1e-8)))
  pass(sprintf("car::linearHypothesis W = %.6f equals the manual W", w$W_car))
} else {
  stopifnot(is.null(w$W_car), w$method == "manual")
  cat("SKIPPED car comparison: car not installed\n")
}
cat("ALL PASS test_wald\n")
