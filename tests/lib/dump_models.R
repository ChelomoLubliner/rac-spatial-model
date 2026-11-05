# dump_models.R: full-precision dumps of the two step-3 models (plan T1).
#
# As a library (from the repo root):
#   source("tests/lib/dump_models.R")
#   d <- dump_models("saved_models/NEW_X_NS_XY.rds", "saved_models/CML_MODEL.rds")
# returns list(fixef, vcov, vcov_rx, theta, sigma2, varcorr, loglik, deviance,
#              nobs, ngrps, conv, optimizer, cml_coef, cml_vcov, cml_loglik,
#              cml_n, cml_nevent, cml_iter, cml_method, wald_glmm,
#              wald_glmm_rx, wald_cml).
#   vcov     = vcov(glmm), the default (finite-difference Hessian when the
#              fit stored one; this is what step 5 uses)
#   vcov_rx  = vcov(glmm, use.hessian = FALSE) (from RX; plan K11)
#   sigma2   = attr(VarCorr(glmm)$shoe, "stddev")^2, the step 4-6 formula
#   varcorr  = VarCorr(glmm)$shoe[1, 1]
#   wald_*   = manual W = b' V^-1 b over the 24 spatial coefficients
#
# CLI: Rscript tests/lib/dump_models.R <glmm.rds> <cml.rds> <out.rds> <prefix>
#   writes <out.rds> (the list, for identical() comparisons), <prefix>.txt
#   and <prefix>.csv (every scalar as sprintf("%.17g")).

suppressMessages({
  library(lme4)
  library(survival)
})

local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  root <- if (length(f) == 1) {
    normalizePath(file.path(dirname(f), "..", ".."))
  } else {
    getwd()
  }
  if (!exists("wald_all_spatial", mode = "function")) {
    source(file.path(root, "statistical_model", "R", "wald.R"),
           local = globalenv())
  }
})

dump_models <- function(glmm_path, cml_path) {
  g <- readRDS(glmm_path)
  cm <- readRDS(cml_path)
  stopifnot(inherits(g, "merMod"), inherits(cm, "coxph"))
  vh <- as.matrix(vcov(g))
  vrx <- suppressWarnings(as.matrix(vcov(g, use.hessian = FALSE)))
  vc <- VarCorr(g)
  list(
    fixef = fixef(g),
    vcov = vh,
    vcov_rx = vrx,
    theta = getME(g, "theta"),
    sigma2 = as.numeric(attr(vc$shoe, "stddev"))^2,
    varcorr = as.numeric(vc$shoe[1, 1]),
    loglik = as.numeric(logLik(g)),
    deviance = as.numeric(deviance(g)),
    nobs = nobs(g),
    ngrps = as.integer(ngrps(g)),
    conv = g@optinfo$conv$opt,
    optimizer = g@optinfo$optimizer,
    cml_coef = coef(cm),
    cml_vcov = as.matrix(vcov(cm)),
    cml_loglik = cm$loglik,
    cml_n = cm$n,
    cml_nevent = cm$nevent,
    cml_iter = cm$iter,
    cml_method = cm$method,
    wald_glmm = wald_all_spatial(g, V = vh, use_car = FALSE)$W,
    wald_glmm_rx = wald_all_spatial(g, V = vrx, use_car = FALSE)$W,
    wald_cml = wald_all_spatial(cm, use_car = FALSE)$W
  )
}

# Long table: model, quantity, index, name, value (character, %.17g).
models_table <- function(d) {
  rows <- list()
  add <- function(model, quantity, values, nms = names(values)) {
    force(nms)
    values <- as.numeric(values)
    if (is.null(nms)) nms <- rep("", length(values))
    rows[[length(rows) + 1]] <<- data.frame(
      model = model, quantity = quantity, index = seq_along(values),
      name = nms, value = sprintf("%.17g", values),
      stringsAsFactors = FALSE)
  }
  add("glmm", "fixef", d$fixef)
  add("glmm", "vcov_diag", diag(d$vcov), names(d$fixef))
  add("glmm", "vcov_rx_diag", diag(d$vcov_rx), names(d$fixef))
  add("glmm", "theta", d$theta)
  add("glmm", "sigma2", d$sigma2, "shoe")
  add("glmm", "varcorr", d$varcorr, "shoe")
  add("glmm", "loglik", d$loglik, "logLik")
  add("glmm", "deviance", d$deviance, "deviance")
  add("glmm", "nobs", d$nobs, "nobs")
  add("glmm", "ngrps", d$ngrps, "shoe")
  add("glmm", "conv", d$conv, "optinfo$conv$opt")
  add("glmm", "wald", d$wald_glmm, "W_vcov_default")
  add("glmm", "wald", d$wald_glmm_rx, "W_vcov_rx")
  add("cml", "coef", d$cml_coef)
  add("cml", "vcov_diag", diag(d$cml_vcov), names(d$cml_coef))
  add("cml", "loglik", d$cml_loglik, c("null", "model"))
  add("cml", "n", d$cml_n, "n")
  add("cml", "nevent", d$cml_nevent, "nevent")
  add("cml", "iter", d$cml_iter, "iter")
  add("cml", "wald", d$wald_cml, "W")
  do.call(rbind, rows)
}

write_model_dumps <- function(d, rds_path, prefix, header = character()) {
  saveRDS(d, rds_path)
  tab <- models_table(d)
  write.csv(tab, paste0(prefix, ".csv"), row.names = FALSE)
  con <- file(paste0(prefix, ".txt"), "w")
  on.exit(close(con))
  writeLines(c(header,
               sprintf("glmm optimizer: %s; cml method: %s",
                       d$optimizer, d$cml_method),
               sprintf("%-5s %-13s %3s %s  %s", "model", "quantity", "i",
                       "value", "name")), con)
  writeLines(sprintf("%-5s %-13s %3d %s  %s", tab$model, tab$quantity,
                     tab$index, tab$value, tab$name), con)
  invisible(tab)
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 4) {
    stop("usage: Rscript tests/lib/dump_models.R",
         " <glmm.rds> <cml.rds> <out.rds> <prefix>")
  }
  d <- dump_models(args[1], args[2])
  write_model_dumps(d, args[3], args[4], header = c(
    sprintf("glmm file: %s (sha256 %s)", args[1],
            digest::digest(file = args[1], algo = "sha256")),
    sprintf("cml file:  %s (sha256 %s)", args[2],
            digest::digest(file = args[2], algo = "sha256")),
    sprintf("dumped with %s, lme4 %s, survival %s", R.version.string,
            packageVersion("lme4"), packageVersion("survival"))))
  cat("wrote", args[3], paste0(args[4], c(".csv", ".txt")), sep = "\n")
}
