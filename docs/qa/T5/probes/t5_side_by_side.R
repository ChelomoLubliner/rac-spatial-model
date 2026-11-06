# t5_side_by_side.R: the OLD fits and the NEW fits on the OLD basis, side by
# side (T5, A-112; descriptive only, the equality tests are T6's).
#
# Usage (repo root): Rscript docs/qa/T5/probes/t5_side_by_side.R
suppressMessages({library(lme4); library(survival)})
o <- readRDS("saved_models/NEW_X_NS_XY.rds")
n <- readRDS("saved_models/new/NEW_X_NS_XY_oldbasis_new.rds")
bo <- fixef(o); bn <- fixef(n)
so <- sqrt(diag(as.matrix(vcov(o, use.hessian = FALSE)))); sn <- sqrt(diag(as.matrix(vcov(n))))
tab <- data.frame(term = c("(Intercept)", sprintf("x%d:y%d", rep(1:4, 6), rep(1:6, each = 4))),
                  OLD = round(bo, 4), OLD_se = round(so, 4), NEW_oldbasis = round(bn, 4), NEW_se = round(sn, 4),
                  z_diff = round((bn - bo) / sqrt(so^2 + sn^2), 2))
rownames(tab) <- NULL
print(tab, row.names = FALSE)
cat(sprintf("GLMM: correlation of the 24 spatial coefficients OLD vs NEW (OLD basis) %.3f; sigma^2 OLD %.4f NEW-oldbasis %.4f\n",
            cor(bo[-1], bn[-1]), as.numeric(VarCorr(o)$shoe), as.numeric(VarCorr(n)$shoe)))
co <- readRDS("saved_models/CML_MODEL.rds"); cn <- readRDS("saved_models/new/CML_MODEL_oldbasis_new.rds")
cat(sprintf("CML: correlation of the 24 coefficients OLD vs NEW (OLD basis) %.3f; max |z_diff| %.2f\n",
            cor(coef(co), coef(cn)), max(abs((coef(cn) - coef(co)) / sqrt(diag(vcov(co)) + diag(vcov(cn)))))))
