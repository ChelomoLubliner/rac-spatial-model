# wald.R: Wald test that all spatial coefficients of a fitted model are 0.
#
# Replaces `car::linearHypothesis` in step 5 when the car package is not
# installed (plan section 6 and T2e; created in T1). For H0: L beta = 0 with
# L selecting the spatial coefficients, the Wald statistic is
#   W = b' V^-1 b,  b = the spatial coefficients, V = their covariance,
# referred to chi^2 with df = length(b). This is what
# car::linearHypothesis(test = "Chisq") computes for this hypothesis matrix.
#
# GLMM (merMod): the intercept is dropped, so df = 24 for NEW_X_NS_XY.
# CML (clogit/coxph): there is no intercept, all coefficients are spatial.
# If car is installed (and use_car = TRUE), its statistic is added as W_car
# so that both can be compared.

wald_all_spatial <- function(model, V = NULL, use_car = TRUE) {
  if (inherits(model, "merMod")) {
    co <- lme4::fixef(model)
    idx <- seq_along(co)[-1]
  } else if (inherits(model, "coxph")) {
    co <- stats::coef(model)
    idx <- seq_along(co)
  } else {
    stop("wald_all_spatial: unsupported model class ", class(model)[1])
  }
  vc <- if (is.null(V)) as.matrix(stats::vcov(model)) else as.matrix(V)
  stopifnot(nrow(vc) == length(co), ncol(vc) == length(co))
  b <- unname(co[idx])
  vb <- unname(vc[idx, idx, drop = FALSE])
  w <- as.numeric(crossprod(b, solve(vb, b)))
  df <- length(b)
  out <- list(W = w, df = df, p = stats::pchisq(w, df, lower.tail = FALSE),
              method = "manual")
  if (use_car && requireNamespace("car", quietly = TRUE)) {
    hm <- diag(length(co))[idx, , drop = FALSE]
    lh <- car::linearHypothesis(model, hypothesis.matrix = hm,
                                rhs = rep(0, df), test = "Chisq",
                                vcov. = vc, coef. = co)
    out$W_car <- as.numeric(lh$Chisq[2])
    out$p_car <- as.numeric(lh[["Pr(>Chisq)"]][2])
    out$method <- "manual+car"
  }
  class(out) <- "rac_wald"
  out
}

print.rac_wald <- function(x, ...) {
  cat(sprintf(paste0("Wald test, all %d spatial coefficients = 0 (%s):",
                     " W = %.4f, df = %d, p = %.3g\n"),
              x$df, x$method, x$W, x$df, x$p))
  if (!is.null(x$W_car)) {
    cat(sprintf("  car::linearHypothesis: W = %.4f, p = %.3g\n",
                x$W_car, x$p_car))
  } else {
    cat("  car::linearHypothesis: not run (car not installed)\n")
  }
  invisible(x)
}
