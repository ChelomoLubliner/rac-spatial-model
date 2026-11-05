# Diagnostic GLMM refit (T1 root-cause analysis of the GLMM difference).
#
# Fits the step-3 GLMM exactly as re_model_shoe_std_3.Rmd does (the body of
# its Random() function, copied verbatim: same formula text, knots and
# optimizer), optionally with calc.derivs = TRUE, and saves the model.
#
# Usage: Rscript diag_glmm_refit.R <dataCC_distance.csv> <out.rds> <derivs>
#   derivs: "default" (glmerControl(optimizer = "nlminbwrap"), as committed)
#           or "true" (the same plus calc.derivs = TRUE).
# Writes only <out.rds> and prints timing and versions.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3, args[3] %in% c("default", "true"))
suppressMessages({
  library(splines)
  library(lme4)
})
dataCC <- read.csv(args[1], header = TRUE)
dataCC <- subset(dataCC, select = c("n_Acc", "x", "y", "shoe", "row_number",
                                    "horiz_dist", "new_x"))
ctrl <- if (args[3] == "true") {
  glmerControl(optimizer = "nlminbwrap", calc.derivs = TRUE)
} else {
  glmerControl(optimizer = "nlminbwrap")
}
Random <- function(nknotsx = 3, nknotsy = 5, dat = dataCC) {
  knotsx <- as.numeric(quantile(dat$x,1:nknotsx/(1+nknotsx)))
  knots_new_x <- as.numeric(quantile(dat$new_x,1:nknotsx/(1+nknotsx)))
  knotsy <-as.numeric(quantile(dat$y,1:nknotsy/(1+nknotsy)))
  shoe<-dat$shoe
  est<- glmer(n_Acc ~ ns(dat$new_x,knots=knots_new_x):ns(dat$y,knots=knotsy) + (1 | shoe),data = dat, family = binomial(link = "logit"), control =ctrl)
  est
}
t0 <- proc.time()[["elapsed"]]
est <- Random(dat = dataCC)
secs <- proc.time()[["elapsed"]] - t0
saveRDS(est, file = args[2])
cat(sprintf("fit %.1f s | %s | lme4 %s | Matrix %s | derivs %s | Hessian %s\n",
            secs, R.version.string, packageVersion("lme4"),
            packageVersion("Matrix"), args[3],
            !is.null(est@optinfo$derivs$Hessian)))
cat(sprintf("fixef[1] %.17g | logLik %.17g\n", fixef(est)[1],
            as.numeric(logLik(est))))
