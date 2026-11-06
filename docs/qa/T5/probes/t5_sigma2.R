# t5_sigma2.R: what the step-3 GLMM's sigma^2 measures, on both datasets
# (T5 review fixes; the statistics reviewer's minor finding 4; decision
# A-115).
#
# The random intercept b_i of shoe i absorbs everything that makes shoe i
# carry more or fewer RACs per contact pixel than the fixed surface says.
# With 100 controls per shoe, the cases of shoe i (n_i, its distinct RAC
# pixels) set its level almost alone. For each dataset this prints:
#   - n_i (cases per shoe): min, median, mean, max;
#   - cor(BLUP, log n_i), cor(BLUP, log px_i), cor(log n_i, log px_i)
#     (px_i = the step-1 pixel count of shoe i, the contact surface S);
#   - var log(n_i / 100), its mean sampling variance mean(1 / n_i + 1 / 100)
#     (delta method: n_i Poisson against the fixed 100 controls) and their
#     difference, the between-shoe variance of the log RAC density that the
#     counts alone imply; sigma^2 and var(BLUP) beside it;
#   - var log(100 / px_i), what an offset would remove (plan F32).
# With --offset-refit it also refits the NEW GLMM with
# offset(log((px - n) / 100)) (minus the log of the control sampling
# fraction 100 / (px - n), plan F35, A-044), as step 3 otherwise does
# (formula, nlminbwrap), and prints sigma^2, the intercept against the
# no-offset intercept + mean(log(100 / (px - n))), and the largest change of
# a spatial coefficient. About 12 minutes. Nothing is written (T6 fits the
# offset refits it compares, plan T6 fit_offset).
#
# Usage (repo root): Rscript docs/qa/T5/probes/t5_sigma2.R [--offset-refit]
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) <= 1, all(args %in% "--offset-refit"))
suppressMessages({
  library(splines)
  library(lme4)
})
root <- normalizePath(".")
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))

for (ds in c("old", "new")) {
  P <- rac_profile(ds, root = ROOT_PATH)
  g <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
  d <- read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
  pc <- read.csv(rac_path(P, "pixel_counts"), header = TRUE)
  stopifnot(nobs(g) == nrow(d),
            identical(as.numeric(getME(g, "y")), as.numeric(d$n_Acc)),
            nrow(pc) == length(unique(d$shoe)))
  n <- as.numeric(tapply(d$n_Acc, d$shoe, sum))
  codes <- sort(unique(d$shoe))
  px <- pc$pixel_count[codes]   # row k of the pixel counts = shoe code k
  re <- ranef(g)$shoe[as.character(codes), 1]
  s2 <- as.numeric(VarCorr(g)$shoe)
  lr <- log(n / 100)
  samp <- mean(1 / n + 1 / 100)
  cat(sprintf("== %s: %d shoes; cases per shoe min %d, median %g, mean %.1f, max %d\n",
              ds, length(n), min(n), median(n), mean(n), max(n)))
  cat(sprintf("   cor(BLUP, log n) %.3f ; cor(BLUP, log px) %.3f ; cor(log n, log px) %.3f\n",
              cor(re, log(n)), cor(re, log(px)), cor(log(n), log(px))))
  cat(sprintf(paste("   var log(n/100) %.4f ; its mean sampling variance %.4f ;",
                    "difference %.4f ; sigma^2 %.4f ; var(BLUP) %.4f ;",
                    "var log(100/px) %.4f\n"),
              var(lr), samp, var(lr) - samp, s2, var(re), var(log(100 / px))))
}

if (length(args) == 1) {
  P <- rac_profile("new", root = ROOT_PATH)
  dat <- read.csv(rac_path(P, "dataCC_distance"), header = TRUE)
  dat <- subset(dat, select = c("n_Acc", "x", "y", "shoe", "row_number",
                                "horiz_dist", "new_x"))
  pc <- read.csv(rac_path(P, "pixel_counts"), header = TRUE)
  n <- tapply(dat$n_Acc, dat$shoe, sum)
  px <- pc$pixel_count[as.integer(names(n))]
  off_shoe <- log((px - n) / 100)
  dat$off <- as.numeric(off_shoe[match(dat$shoe, as.integer(names(n)))])
  knots_new_x <- as.numeric(quantile(dat$new_x, 1:3 / 4))
  knotsy <- as.numeric(quantile(dat$y, 1:5 / 6))
  shoe <- dat$shoe
  t0 <- proc.time()[["elapsed"]]
  m <- glmer(n_Acc ~ ns(dat$new_x, knots = knots_new_x):ns(dat$y,
                                                         knots = knotsy) +
               (1 | shoe) + offset(off), data = dat,
             family = binomial(link = "logit"),
             control = glmerControl(optimizer = "nlminbwrap"))
  secs <- proc.time()[["elapsed"]] - t0
  g <- readRDS(rac_model_path(P, "NEW_X_NS_XY"))
  pred <- fixef(g)[1] + mean(-off_shoe)
  msgs <- m@optinfo$conv$lme4$messages
  cat(sprintf(paste("== NEW offset refit, offset(log((px - n)/100)): conv %s,",
                    "lme4 messages %s; sigma^2 %.5f (no offset %.5f);",
                    "intercept %.4f (no-offset intercept + mean(log(100/(px - n)))",
                    "= %.4f); largest |change| of a spatial coefficient %.4f;",
                    "%.0f s\n"),
              m@optinfo$conv$opt, if (is.null(msgs)) "none" else
                paste(msgs, collapse = "; "),
              as.numeric(VarCorr(m)$shoe), as.numeric(VarCorr(g)$shoe),
              fixef(m)[1], pred, max(abs(fixef(m)[-1] - fixef(g)[-1])), secs))
}
