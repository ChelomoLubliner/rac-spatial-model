# compare_glmm_fits.R: are two fitted step-3 GLMMs (merMod .rds files) the
# same fit? (T1 review fixes, decision A-065)
#
# As a library: source("tests/lib/compare_glmm_fits.R");
#   tab <- compare_glmm_files(a_path, b_path)  # reads both files fresh
#   tab <- compare_glmm_fits(a, b)  # merMod objects, freshly read (below)
# returns data.frame(field, how, same): one row per compared field.
# CLI: Rscript tests/lib/compare_glmm_fits.R <a.rds> <b.rds>
#   prints the table; exit 0 only if every field is the same.
#
# A whole merMod is never identical() to another one, not even to a second
# readRDS() of the same file: its call, the terms of its model frame and
# the reference-class slots resp and pp hold environments (checked on the
# committed GLMM). So the fit is compared field by field, with identical():
# the slots theta, beta, u, optinfo (optimizer, control, the stored
# derivatives gradient and Hessian, convergence, feval), devcomp, Gp,
# flist, cnms and lower; the model frame without its terms and formula
# attributes; the response fields y, mu, eta, weights, offset, wtres; the
# X, Zt and Lambdat matrices; and the derived fixef, vcov() (the default:
# finite-difference Hessian when one is stored), vcov(use.hessian = FALSE)
# (RX), logLik, deviance and sigma^2. The call and the whole frame are
# compared with all.equal() (their environments differ by construction).
#
# Compare freshly read objects only (compare_glmm_files() and the CLI do).
# The first lme4 access to resp$wtres builds the C++ object behind resp,
# which recomputes resp$mu from eta (on the committed GLMM mu changes by up
# to 1.1e-16 and the stored value is overwritten). An object that went
# through an earlier comparison therefore no longer shows its stored mu,
# and comparing it with a fresh read reports resp_mu and resp_wtres as
# different (found while testing this file).

suppressMessages(library(lme4))

compare_glmm_fits <- function(a, b) {
  stopifnot(inherits(a, "merMod"), inherits(b, "merMod"))
  plain_frame <- function(g) {
    x <- g@frame
    attr(x, "terms") <- NULL
    attr(x, "formula") <- NULL
    x
  }
  vrx <- function(g) suppressWarnings(as.matrix(vcov(g, use.hessian = FALSE)))
  sig2 <- function(g) as.numeric(attr(VarCorr(g)[[1]], "stddev"))^2
  same <- list(
    theta = function(g) g@theta, beta = function(g) g@beta,
    u = function(g) g@u, optinfo = function(g) g@optinfo,
    devcomp = function(g) g@devcomp, Gp = function(g) g@Gp,
    flist = function(g) g@flist, cnms = function(g) g@cnms,
    lower = function(g) g@lower, frame_data = plain_frame,
    resp_y = function(g) g@resp$y, resp_mu = function(g) g@resp$mu,
    resp_eta = function(g) g@resp$eta,
    resp_weights = function(g) g@resp$weights,
    resp_offset = function(g) g@resp$offset,
    resp_wtres = function(g) g@resp$wtres,
    X = function(g) getME(g, "X"), Zt = function(g) getME(g, "Zt"),
    Lambdat = function(g) getME(g, "Lambdat"),
    fixef = function(g) fixef(g),
    vcov = function(g) as.matrix(vcov(g)), vcov_rx = vrx,
    loglik = function(g) as.numeric(logLik(g)),
    deviance = function(g) deviance(g), sigma2 = sig2)
  rows <- lapply(names(same), function(f) {
    data.frame(field = f, how = "identical",
               same = identical(same[[f]](a), same[[f]](b)),
               stringsAsFactors = FALSE)
  })
  rows <- c(rows, list(
    data.frame(field = "call", how = "all.equal",
               same = isTRUE(all.equal(a@call, b@call)),
               stringsAsFactors = FALSE),
    data.frame(field = "frame", how = "all.equal",
               same = isTRUE(all.equal(a@frame, b@frame)),
               stringsAsFactors = FALSE)))
  do.call(rbind, rows)
}

compare_glmm_files <- function(a_path, b_path) {
  compare_glmm_fits(readRDS(a_path), readRDS(b_path))
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2) {
    stop("usage: Rscript tests/lib/compare_glmm_fits.R <a.rds> <b.rds>")
  }
  tab <- compare_glmm_files(args[1], args[2])
  writeLines(sprintf("%-12s %-9s %s", tab$field, tab$how,
                     ifelse(tab$same, "same", "DIFFERENT")))
  cat(sprintf("RESULT %d of %d fields the same\n", sum(tab$same), nrow(tab)))
  quit(status = if (all(tab$same)) 0 else 1)
}
