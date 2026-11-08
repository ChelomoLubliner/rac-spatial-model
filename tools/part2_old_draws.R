# part2_old_draws.R: OLD shoe-bootstrap draws of the step-3 GLMM for the
# Part 2 two-sample bootstrap (plan T7, section 9; decision A-043; the T7
# decisions in docs/results/validation.md).
#
# T5 step 3b (the OLD GLMM shoe bootstrap with stored resample ids) has not
# been run, and a Laplace refit takes 250-450 s on this machine (plan F37,
# F43), so B = 2000 Laplace refits are out of reach. Each draw here refits
# the OLD GLMM on one shoe resample by PIRLS at the committed variance
# parameter (nAGQ = 0, fit_glmm_fixed_theta() of statistical_model/R/
# validation.R; about 1.5 s), on the OLD spline basis (knots and boundary
# knots of the committed model, so every draw is in the parameterization of
# beta_old). The draw used by Part 2 is centred on the committed fit:
#   beta*_b = fixef(committed) + (beta_pirls(resample b) - beta_pirls(all OLD))
# so the surrogate's own level difference (nAGQ = 0 vs Laplace) cancels and
# only the resampling variation is kept. A shoe drawn twice is two groups.
# The resample ids (shoe codes of dataCC) are stored with every draw, so the
# 2022 regional theta can be refitted on the same OLD resamples (A-043).
#
# Usage (from the repository root):
#   Rscript tools/part2_old_draws.R [--B 2000] [--workers 4]
#   Rscript tools/part2_old_draws.R --laplace 8 [--workers 2]
#     the first draws refitted with the committed Laplace call on the same
#     resamples, to check the surrogate (writes a separate file)
# Output: part2_path(P_old, "old_glmm_draws", "rds") or, with --laplace,
#   part2_path(P_old, "old_glmm_draws_laplace_check", "rds").
# Draws depend only on the seed and the resample ids, not on the number of
# workers (the ids are drawn up front; PIRLS uses no random numbers).
suppressMessages({
  library(splines)
  library(lme4)
})
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
for (f in c("profile.R", "io.R", "compare.R", "validation.R")) {
  source(file.path(root, "statistical_model", "R", f))
}

args <- commandArgs(TRUE)
arg_value <- function(name, default) {
  k <- match(name, args)
  if (is.na(k)) default else as.integer(args[k + 1])
}
B <- arg_value("--B", 2000L)
workers <- arg_value("--workers", 4L)
laplace <- arg_value("--laplace", 0L)

P <- rac_profile("old", root = ROOT_PATH)
model <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
basis <- part2_basis(model)
theta <- getME(model, "theta")
beta_old <- fixef(model)
dat <- read.csv(rac_path(P, "dataCC_distance"))
dat <- dat[, c("n_Acc", "new_x", "y", "shoe")]
codes <- sort(unique(dat$shoe))
m <- length(codes)
ids <- part2_resample_ids(m, B, PART2_SEEDS$old_draws)

if (laplace > 0) {
  out <- part2_path(P, "old_glmm_draws_laplace_check", "rds")
  todo <- seq_len(laplace)
  one <- function(b) {
    t0 <- proc.time()[["elapsed"]]
    rs <- part2_resample_data(dat, codes, ids[b, ])
    fit <- fit_common_basis(rs, basis$knots_x, basis$knots_y, basis$bknots_x,
                            basis$bknots_y, "NEW_X_NS_XY")
    pr <- fit_glmm_fixed_theta(rs, basis, theta)
    list(b = b, laplace = fixef(fit), theta_laplace = getME(fit, "theta"),
         conv = fit@optinfo$conv$opt, pirls = pr$beta,
         seconds = proc.time()[["elapsed"]] - t0)
  }
  res <- parallel::mclapply(todo, one, mc.cores = workers,
                            mc.preschedule = FALSE)
  bad <- vapply(res, inherits, TRUE, what = "try-error")
  if (any(bad)) stop("Laplace refits failed: ", paste(todo[bad], collapse = ", "))
  full <- fit_glmm_fixed_theta(dat, basis, theta)
  saveRDS(list(b = todo,
               laplace = do.call(rbind, lapply(res, `[[`, "laplace")),
               theta_laplace = vapply(res, `[[`, 0, "theta_laplace"),
               conv = vapply(res, `[[`, 0, "conv"),
               pirls = do.call(rbind, lapply(res, `[[`, "pirls")),
               pirls_full = full$beta, beta_old = beta_old,
               theta_old = theta, ids = ids[todo, , drop = FALSE],
               seconds = vapply(res, `[[`, 0, "seconds"),
               seed = PART2_SEEDS$old_draws, codes = codes,
               R = R.version.string,
               lme4 = as.character(packageVersion("lme4"))), out)
  cat("wrote", out, "\n")
  quit(save = "no")
}

out <- part2_path(P, "old_glmm_draws", "rds")
t_start <- proc.time()[["elapsed"]]
full <- fit_glmm_fixed_theta(dat, basis, theta)
one <- function(b) {
  t0 <- proc.time()[["elapsed"]]
  r <- try(fit_glmm_fixed_theta(part2_resample_data(dat, codes, ids[b, ]),
                                basis, theta), silent = TRUE)
  if (inherits(r, "try-error")) {
    return(list(beta = rep(NA_real_, length(beta_old)), deviance = NA_real_,
                seconds = proc.time()[["elapsed"]] - t0,
                error = as.character(r)))
  }
  list(beta = unname(r$beta), deviance = r$deviance,
       seconds = proc.time()[["elapsed"]] - t0, error = "")
}
res <- parallel::mclapply(seq_len(B), one, mc.cores = workers)
# a worker that died returns a try-error instead of the list
res <- lapply(res, function(r) {
  if (is.list(r)) return(r)
  list(beta = rep(NA_real_, length(beta_old)), deviance = NA_real_,
       seconds = NA_real_, error = paste("worker:", as.character(r)))
})
beta <- do.call(rbind, lapply(res, `[[`, "beta"))
colnames(beta) <- names(beta_old)
failed <- which(nzchar(vapply(res, `[[`, "", "error")))
draws <- sweep(beta, 2, unname(full$beta)) + rep(unname(beta_old),
                                                 each = nrow(beta))
saveRDS(list(draws = draws, beta_pirls = beta, pirls_full = full$beta,
             beta_old = beta_old, theta_old = theta, ids = ids,
             codes = codes, seed = PART2_SEEDS$old_draws, B = B,
             failed = failed,
             errors = vapply(res, `[[`, "", "error")[failed],
             deviance = vapply(res, `[[`, 0, "deviance"),
             seconds = vapply(res, `[[`, 0, "seconds"),
             wall_seconds = proc.time()[["elapsed"]] - t_start,
             workers = workers,
             method = paste("PIRLS (nAGQ = 0) at the committed theta,",
                            "OLD basis, centred on the committed fixef"),
             R = R.version.string,
             lme4 = as.character(packageVersion("lme4"))), out)
cat(sprintf("wrote %s: B = %d, failed %d, wall %.0f s\n", out, B,
            length(failed), proc.time()[["elapsed"]] - t_start))
