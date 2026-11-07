# fit_compare_models.R: the model fits of the OLD-vs-NEW comparison (plan
# T6), one job per call, so that the long ones run in the background in
# parallel. Every fit reads only committed files (the step-2 CSVs, the
# step-1 pixel counts and shoe codes, the T0 overlap verdicts) and uses the
# helpers of statistical_model/R/compare_old_new.R.
#
# Usage (repo root):
#   Rscript tools/fit_compare_models.R JOB [--force]
#   Rscript tools/fit_compare_models.R --list
#   bash tools/run_compare_fits.sh [--jobs N] [--slow]   (every job, in
#     dependency order, each from its own copy of this file)
# A job never overwrites an existing output unless --force is given.
# Never edit this file while a job runs from it: Rscript reads its --file
# while it runs, so a job reads the edited bytes after its fit returns (on
# 2026-11-07 that crashed five T6 fits after up to 107 minutes, before they
# saved anything; docs/tests/T6-results.md). Start long jobs from a copy, as
# tools/run_compare_fits.sh does.
#
# Outputs (user rule 1: NEW fits in a new folder with the _new suffix):
#   offset_old, offset_new: the plan's GLMM refits with the offset
#     log((px - n) / 100) (fit_offset, the data's own step-3 basis; plan
#     section 5: saved_models/NEW_X_NS_XY_offset.rds and
#     saved_models/new/NEW_X_NS_XY_offset_new.rds, the full model objects)
#   every other job: a compact record (t6_summary: coefficients, RX vcov,
#     sigma^2, loglik, convergence, shoes, timing) at
#     saved_models/t6/<stem>.rds (OLD data) or
#     saved_models/new/t6/<stem>_new.rds (NEW data)
# Jobs (dataset, model, basis, shoes):
#   nagq0_*:      the step-3 basis, glmer with nAGQ = 0 (to measure what
#                 nAGQ = 0 changes against the committed nAGQ = 1 fits)
#   full*_:       the full tensor on the dataset's own step-3 knots (A-116)
#   fineY*_:      the nested finer y basis on the dataset's own knots
#                 (A-119, plan F84); *_glmm0 with nAGQ = 0, *_glmm with
#                 nAGQ = 1 (hours: a GLMM with 85 fixed effects)
#   fineYold_*:   NEW on the OLD data's nested finer y basis (the common
#                 finer basis of the OLD-vs-NEW differences)
#   norep_*:      NEW without the shoes judged same_shoe or uncertain in the
#                 T0 visual review (plan F25), on the OLD step-3 basis
#   groupB_*:     NEW group B only (without the post-hoc group A of F79), on
#                 the OLD step-3 basis
#   offset_norep: the offset refit of NEW without those shoes, OLD basis
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(".")
if (!file.exists(file.path(root, "statistical_model", "config.R"))) {
  stop("run from the repository root", call. = FALSE)
}
ROOT_PATH <- paste(root, "/", sep = "")
suppressMessages({
  library(splines)
  library(lme4)
  library(survival)
})
for (f in c("profile.R", "compare.R", "compare_old_new.R")) {
  source(file.path(root, "statistical_model", "R", f))
}
P <- list(old = rac_profile("old", root = ROOT_PATH),
          new = rac_profile("new", root = ROOT_PATH))

glmm <- "NEW_X_NS_XY"
cml <- "CML_MODEL"
job <- function(ds, feature, basis, shoes = "all", nagq = 1L,
                offset = FALSE, stem, optimizer = "nlminbwrap") {
  list(ds = ds, feature = feature, basis = basis, shoes = shoes,
       nagq = as.integer(nagq), offset = offset, stem = stem,
       optimizer = optimizer)
}
jobs <- list(
  offset_old = job("old", glmm, "K8_own", offset = TRUE,
                   stem = "NEW_X_NS_XY_offset"),
  offset_new = job("new", glmm, "K8_own", offset = TRUE,
                   stem = "NEW_X_NS_XY_offset"),
  nagq0_old = job("old", glmm, "K8_own", nagq = 0, stem = "NEW_X_NS_XY_nagq0"),
  nagq0_new = job("new", glmm, "K8_own", nagq = 0, stem = "NEW_X_NS_XY_nagq0"),
  full_old_glmm = job("old", glmm, "full_own", stem = "NEW_X_NS_XY_full"),
  # nlminbwrap stopped at its iteration limit on the NEW full tensor
  # (convergence code 1 after 4,148 s, 2026-11-07); bobyqa, as the finer-y
  # GLMMs use, stops at its evaluation limit at the same point (code 1);
  # the gradient check of tests/r/test_compare_old_new.R shows the optimum
  full_new_glmm = job("new", glmm, "full_own", stem = "NEW_X_NS_XY_full",
                      optimizer = "bobyqa"),
  full_old_cml = job("old", cml, "full_own", stem = "CML_MODEL_full"),
  full_new_cml = job("new", cml, "full_own", stem = "CML_MODEL_full"),
  fineY_old_cml = job("old", cml, "fineY_own", stem = "CML_MODEL_fineY"),
  fineY_new_cml = job("new", cml, "fineY_own", stem = "CML_MODEL_fineY"),
  fineYold_new_cml = job("new", cml, "fineY_old", stem = "CML_MODEL_fineYold"),
  fineY_old_glmm0 = job("old", glmm, "fineY_own", nagq = 0,
                        stem = "NEW_X_NS_XY_fineY_nagq0"),
  fineY_new_glmm0 = job("new", glmm, "fineY_own", nagq = 0,
                        stem = "NEW_X_NS_XY_fineY_nagq0"),
  fineYold_new_glmm0 = job("new", glmm, "fineY_old", nagq = 0,
                           stem = "NEW_X_NS_XY_fineYold_nagq0"),
  fineY_old_glmm = job("old", glmm, "fineY_own", stem = "NEW_X_NS_XY_fineY",
                       optimizer = "bobyqa"),
  fineY_new_glmm = job("new", glmm, "fineY_own", stem = "NEW_X_NS_XY_fineY",
                       optimizer = "bobyqa"),
  fineYold_new_glmm = job("new", glmm, "fineY_old",
                          stem = "NEW_X_NS_XY_fineYold", optimizer = "bobyqa"),
  norep_glmm = job("new", glmm, "K8_old", shoes = "norep",
                   stem = "NEW_X_NS_XY_oldbasis_norep"),
  norep_cml = job("new", cml, "K8_old", shoes = "norep",
                  stem = "CML_MODEL_oldbasis_norep"),
  groupB_glmm = job("new", glmm, "K8_old", shoes = "groupB",
                    stem = "NEW_X_NS_XY_oldbasis_groupB"),
  groupB_cml = job("new", cml, "K8_old", shoes = "groupB",
                   stem = "CML_MODEL_oldbasis_groupB"),
  offset_norep = job("new", glmm, "K8_old", shoes = "norep", offset = TRUE,
                     stem = "NEW_X_NS_XY_offset_oldbasis_norep"))

# Profile jobs: an approximate profile-likelihood 95% interval for sigma^2
# of a fitted GLMM (sigma = theta is moved, the intercept re-optimized at
# each value, the spatial coefficients held at their estimates; the Laplace
# deviance of glmer, nAGQ = 1, as in the fits). The fit must exist first.
prof_job <- function(ds, fit, basis, shoes = "all", offset = FALSE,
                     committed = FALSE) {
  list(ds = ds, fit = fit, basis = basis, shoes = shoes, offset = offset,
       committed = committed)
}
profiles <- list(
  profile_glmm_old = prof_job("old", glmm, "K8_own", committed = TRUE),
  profile_glmm_new = prof_job("new", glmm, "K8_own", committed = TRUE),
  profile_off_old = prof_job("old", "NEW_X_NS_XY_offset", "K8_own",
                             offset = TRUE, committed = TRUE),
  profile_off_new = prof_job("new", "NEW_X_NS_XY_offset", "K8_own",
                             offset = TRUE, committed = TRUE),
  profile_norep = prof_job("new", "NEW_X_NS_XY_oldbasis_norep", "K8_old",
                           shoes = "norep"),
  profile_off_norep = prof_job("new", "NEW_X_NS_XY_offset_oldbasis_norep",
                               "K8_old", shoes = "norep", offset = TRUE))

# Bootstrap jobs: shoe-bootstrap draws of a GLMM on the OLD step-3 basis by
# the PIRLS surrogate (t6_pirls_beta, t6_resample; B draws, the resampled
# shoe codes drawn up front from the job's seed, so the draws do not depend
# on the number of workers); for the bootstrap equality Wald test of the
# OLD and NEW surfaces (paired difference draws, F(p, B - p); A-045), the
# bootstrap all-spatial Wald and the bootstrap bands at the cuts. The
# boot_full_* jobs do the same for the full tensor of each dataset (its own
# step-3 knots), for the intervals of Naomi's area ratios (T6 review fixes).
#   Rscript tools/fit_compare_models.R boot_old [--force] [--B 1000] [--workers 4]
boot_job <- function(ds, fit, basis, shoes, seed, committed) {
  list(ds = ds, fit = fit, basis = basis, shoes = shoes, seed = seed,
       committed = committed)
}
boots <- list(
  boot_old = boot_job("old", glmm, "K8_own", "all", T6_SEEDS$boot_old, TRUE),
  boot_new_ob = boot_job("new", "NEW_X_NS_XY_oldbasis", "K8_old", "all",
                         T6_SEEDS$boot_new, TRUE),
  boot_norep = boot_job("new", "NEW_X_NS_XY_oldbasis_norep", "K8_old",
                        "norep", T6_SEEDS$boot_norep, FALSE),
  # T6 review fixes: the full tensor of each dataset (its own step-3 knots,
  # no K8 pin), for the bootstrap intervals of Naomi's area ratios
  boot_full_old = boot_job("old", "NEW_X_NS_XY_full", "full_own", "all",
                           T6_SEEDS$boot_full_old, FALSE),
  boot_full_new = boot_job("new", "NEW_X_NS_XY_full", "full_own", "all",
                           T6_SEEDS$boot_full_new, FALSE))
opt_value <- function(flag, default) {
  k <- which(args == flag)
  if (!length(k)) return(default)
  v <- as.integer(args[k + 1])
  args <<- args[-c(k, k + 1)]
  v
}
B_boot <- opt_value("--B", 1000L)
workers <- opt_value("--workers", 4L)

if (length(args) == 1 && args[1] == "--list") {
  for (nm in names(boots)) {
    cat(sprintf("%-20s %-4s bootstrap of %s (%s)\n", nm, boots[[nm]]$ds,
                boots[[nm]]$fit, boots[[nm]]$shoes))
  }
  for (nm in names(jobs)) {
    j <- jobs[[nm]]
    cat(sprintf("%-20s %-4s %-12s %-10s %-7s nAGQ %d%s\n", nm, j$ds,
                j$feature, j$basis, j$shoes, j$nagq,
                if (j$offset) " offset" else ""))
  }
  for (nm in names(profiles)) {
    cat(sprintf("%-20s %-4s profile of %s\n", nm, profiles[[nm]]$ds,
                profiles[[nm]]$fit))
  }
  quit(save = "no")
}
if (!length(args) %in% 1:2 ||
    !args[1] %in% c(names(jobs), names(profiles), names(boots)) ||
    (length(args) == 2 && args[2] != "--force")) {
  stop("usage: Rscript tools/fit_compare_models.R JOB [--force] | --list",
       call. = FALSE)
}
force <- length(args) == 2
is_profile <- args[1] %in% names(profiles)
is_boot <- args[1] %in% names(boots)
j <- if (is_profile) profiles[[args[1]]] else if (is_boot) boots[[args[1]]] else jobs[[args[1]]]
Pd <- P[[j$ds]]
plan_offset <- !is_profile && !is_boot && j$offset && j$shoes == "all"
out <- if (is_boot) {
  t6_fit_path(Pd, paste(j$fit, "_bootpirls", sep = ""))
} else if (is_profile) {
  t6_fit_path(Pd, paste("profile_", j$fit, sep = ""))
} else if (plan_offset) {
  rac_model_path(Pd, j$stem)
} else {
  t6_fit_path(Pd, j$stem)
}
t6_new_output(out, force)

read_step2 <- function(Px) {
  d <- read.csv(rac_path(Px, "dataCC_distance"), header = TRUE)
  subset(d, select = c("n_Acc", "x", "y", "shoe", "row_number",
                       "horiz_dist", "new_x"))
}
d_old <- read_step2(P$old)
d <- if (j$ds == "old") d_old else read_step2(P$new)
codes <- read.csv(rac_path(Pd, "shoe_codes"), header = TRUE)
pc <- read.csv(rac_path(Pd, "pixel_counts"), header = TRUE)
if (j$shoes != "all") {
  stopifnot(j$ds == "new", identical(codes$code, codes$shoe))
  drop <- switch(j$shoes,
                 norep = t6_reprint_ids(root),
                 groupB = codes$shoe[t6_group_a(codes$shoe)])
  d <- d[!d$shoe %in% drop, ]
}
spec <- switch(j$basis,
               K8_own = t6_spec(d, "K8"),
               full_own = t6_spec(d, "full"),
               fineY_own = t6_spec(d, "fineY"),
               K8_old = t6_spec(d_old, "K8"),
               fineY_old = t6_spec(d_old, "fineY"))

if (is_boot) {
  est <- if (j$committed) {
    t6_from_model(readRDS(rac_model_path(Pd, j$fit)), j$fit, d)
  } else {
    readRDS(t6_fit_path(Pd, j$fit))
  }
  stopifnot(identical(est$spec[-1], spec[-1]), est$nobs == nrow(d))
  shoes <- sort(unique(d$shoe))
  set.seed(j$seed)
  ids <- t(vapply(seq_len(B_boot), function(b) {
    sample(shoes, length(shoes), replace = TRUE)
  }, numeric(length(shoes))))
  cat(sprintf("bootstrap %s: %s data, %d shoes, B = %d, %d workers, theta %.6f, seed %d\n",
              args[1], j$ds, length(shoes), B_boot, workers, est$theta, j$seed))
  t0 <- proc.time()[["elapsed"]]
  beta_all <- t6_pirls_beta(d, spec, est$theta)
  stopifnot(identical(names(beta_all), names(est$coef)))
  one <- function(b) t6_pirls_beta(t6_resample(d, ids[b, ]), spec, est$theta)
  res <- parallel::mclapply(seq_len(B_boot), function(b) {
    tryCatch(one(b), error = function(e) conditionMessage(e))
  }, mc.cores = workers)
  failed <- which(!vapply(res, is.numeric, TRUE))
  raw <- do.call(rbind, res[setdiff(seq_len(B_boot), failed)])
  draws <- sweep(raw, 2, beta_all) + matrix(est$coef, nrow(raw), length(est$coef),
                                            byrow = TRUE)
  colnames(draws) <- names(est$coef)
  out_rec <- list(fit = j$fit, dataset = j$ds, shoes_rule = j$shoes,
                  basis_rule = j$basis, spec = spec, theta = est$theta,
                  coef = est$coef, beta_all = beta_all, raw = raw,
                  draws = draws, ids = ids, failed = failed,
                  failed_messages = unlist(res[failed]), seed = j$seed,
                  B = B_boot, workers = workers,
                  seconds = proc.time()[["elapsed"]] - t0,
                  method = paste("shoe bootstrap, PIRLS at the fit's theta",
                                 "(nAGQ = 0 deviance function), centred on",
                                 "the fit"))
  saveRDS(out_rec, file = out)
  se_boot <- apply(draws, 2, stats::sd)
  se_model <- sqrt(diag(est$vcov))
  cat(sprintf(paste("done %s: %d draws (%d failed), %.0f s; |beta_pirls(all) - fit| max %.4f;",
                    "bootstrap / model SE (spatial): median %.3f, min %.3f, max %.3f\n"),
              args[1], nrow(draws), length(failed), out_rec$seconds,
              max(abs(beta_all - est$coef)), median((se_boot / se_model)[-1]),
              min((se_boot / se_model)[-1]), max((se_boot / se_model)[-1])))
  quit(save = "no")
}

if (is_profile) {
  est <- if (j$committed) {
    t6_from_model(readRDS(rac_model_path(Pd, j$fit)), j$fit, d)
  } else {
    readRDS(t6_fit_path(Pd, j$fit))
  }
  stopifnot(identical(est$spec[-1], spec[-1]), est$nobs == nrow(d))
  off <- if (j$offset) t6_offset_values(d, codes, pc) else NULL
  dd <- data.frame(n_Acc = d$n_Acc, shoe = d$shoe)
  dd$X <- t6_design(spec, d$new_x, d$y)
  f <- n_Acc ~ X + (1 | shoe)
  if (!is.null(off)) {
    dd$off <- off
    f <- n_Acc ~ X + (1 | shoe) + offset(off)
  }
  cat(sprintf("profile %s: %s data, %d shoes, theta %.6f (sigma^2 %.6f)\n",
              args[1], j$ds, length(unique(d$shoe)), est$theta, est$sigma2))
  t0 <- proc.time()[["elapsed"]]
  devf <- lme4::glmer(f, data = dd, family = stats::binomial(link = "logit"),
                      control = lme4::glmerControl(optimizer = "nlminbwrap"),
                      devFunOnly = TRUE)
  b <- unname(est$coef)
  th <- est$theta
  n_eval <- 0
  dev <- function(t, a) {
    n_eval <<- n_eval + 1
    devf(c(t, a, b[-1]))
  }
  prof <- function(t) {
    stats::optimize(function(a) dev(t, a), interval = b[1] + c(-0.5, 0.5),
                    tol = 1e-7)$objective
  }
  at_est <- dev(th, b[1])
  o <- stats::optimize(prof, interval = th * c(0.9, 1.1), tol = 1e-6)
  crit <- stats::qchisq(0.95, 1)
  g <- function(t) prof(t) - o$objective - crit
  lo <- stats::uniroot(g, c(o$minimum * 0.5, o$minimum), tol = 1e-6)$root
  hi <- stats::uniroot(g, c(o$minimum, o$minimum * 1.8), tol = 1e-6)$root
  res <- list(fit = j$fit, dataset = j$ds, shoes_rule = j$shoes,
              offset = j$offset, theta_hat = th, sigma2_hat = th^2,
              deviance_at_estimates = at_est,
              minus2loglik = -2 * est$loglik, theta_min = o$minimum,
              deviance_min = o$objective, theta_lo = lo, theta_hi = hi,
              sigma2_lo = lo^2, sigma2_hi = hi^2, evaluations = n_eval,
              seconds = proc.time()[["elapsed"]] - t0,
              method = paste("profile of the Laplace deviance in theta, the",
                             "intercept re-optimized, the spatial",
                             "coefficients held at their estimates"))
  saveRDS(res, file = out)
  cat(sprintf(paste("done %s: deviance at the estimates %.4f (-2 logLik",
                    "%.4f); profile minimum at sigma^2 %.5f; 95%% interval",
                    "sigma^2 [%.4f, %.4f]; %d deviance evaluations, %.0f s\n"),
              args[1], at_est, -2 * est$loglik, o$minimum^2, lo^2, hi^2,
              n_eval, res$seconds))
  quit(save = "no")
}
cat(sprintf("job %s: %s data, %s, basis %s (%s, %d x and %d y knots), shoes %s (%d, %d rows, %d cases), nAGQ %d%s -> %s\n",
            args[1], j$ds, j$feature, j$basis, spec$type,
            length(spec$knots_x), length(spec$knots_y), j$shoes,
            length(unique(d$shoe)), nrow(d), sum(d$n_Acc), j$nagq,
            if (j$offset) ", offset log((px - n)/100)" else "", out))
# An offset refit whose default start fails (PIRLS step-halving, seen on
# small subsets) is retried once from the no-offset fit moved by the offset
# (t6_offset_start); the retry is recorded.
no_offset_ref <- function() {
  if (plan_offset) {
    return(t6_from_model(readRDS(rac_model_path(Pd, glmm)), glmm, d))
  }
  ref <- t6_fit_path(Pd, sub("offset_", "", j$stem, fixed = TRUE))
  if (!file.exists(ref)) stop("the no-offset fit ", ref, " is needed first",
                              call. = FALSE)
  readRDS(ref)
}
fit_once <- function(start = NULL) {
  if (plan_offset) {
    fit_offset(d, codes, pc, j$feature, start = start)
  } else {
    off <- if (j$offset) t6_offset_values(d, codes, pc) else NULL
    t6_fit(d, spec, j$feature, offset = off, nAGQ = j$nagq,
           optimizer = j$optimizer, start = start)
  }
}
t0 <- proc.time()[["elapsed"]]
retried <- ""
m <- tryCatch(fit_once(), error = function(e) e)
if (inherits(m, "error")) {
  if (!j$offset || !grepl("PIRLS|maxstephalfit", conditionMessage(m))) stop(m)
  retried <- conditionMessage(m)
  cat("default start failed (", retried, "); retrying from the no-offset ",
      "fit\n", sep = "")
  st <- t6_offset_start(no_offset_ref(), t6_offset_values(d, codes, pc),
                        d$shoe)
  m <- fit_once(start = st)
}
secs <- proc.time()[["elapsed"]] - t0
if (plan_offset) {
  saveRDS(m, file = out)
  s <- t6_from_model(m, j$stem, d)
} else {
  s <- t6_summary(m, spec, j$stem, d, secs,
                  extra = list(job = args[1], dataset = j$ds,
                               shoes_rule = j$shoes, basis_rule = j$basis,
                               offset_refit = j$offset,
                               optimizer = j$optimizer,
                               retried_after = retried))
  saveRDS(s, file = out)
}
if (nzchar(retried)) cat("note: fitted from the no-offset start\n")
cat(sprintf("done %s: %.0f s; conv %s%s; loglik %.4f; sigma^2 %s; %d coefficients\n",
            args[1], secs, s$conv,
            if (length(s$messages)) paste0(" (", paste(s$messages, collapse = "; "), ")") else "",
            s$loglik, format(s$sigma2, digits = 7), length(s$coef)))
