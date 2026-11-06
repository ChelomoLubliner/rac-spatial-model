# compare.R: refits of one dataset on another dataset's spline basis (plan
# T6 interface; created in T5 for the NEW refits on the OLD basis, decision
# A-112; T6 adds the comparison functions).
#
# Step 3 (re_model_shoe_std_3.Rmd) builds its basis from the data it fits:
# ns(new_x) with 3 interior knots at the quartiles of new_x and ns(y) with 5
# at the sextiles of y, boundary knots = the data range (ns's default), and
# the interaction ns(new_x):ns(y) without main effects (24 columns, new_x
# varying fastest). The NEW fit therefore has its own basis, so its
# coefficients cannot be set beside the OLD ones; a refit of the NEW data on
# the OLD knots and boundary knots can (NEW points beyond the OLD boundary
# knots get ns's linear extrapolation; their share is reported).
#
# basis_knots(data, nknotsx = 3, nknotsy = 5)
#     list(knots_x, knots_y, bknots_x, bknots_y): the knots step 3 uses for
#     this data (as.numeric(quantile(...)) exactly as Random() computes
#     them) and the boundary knots ns() takes by default (range()).
# fit_common_basis(data, knots_x, knots_y, bknots_x, bknots_y, feature)
#     the step-3 model (feature NEW_X_NS_XY: glmer with (1 | shoe), the
#     nlminbwrap optimizer; CML_MODEL: clogit with strata(shoe)) fitted to
#     data on the given basis; its fixed effects have the step-3 order.
# basis_of(model)
#     list(knots_x, knots_y, bknots_x, bknots_y) read back from a fitted
#     step-3 or common-basis model (the attributes of its two ns() terms);
#     attaches splines when it is not attached (the CML's model frame is
#     rebuilt by evaluating its formula, which calls ns()).

basis_knots <- function(data, nknotsx = 3, nknotsy = 5) {
  list(knots_x = as.numeric(quantile(data$new_x, 1:nknotsx / (1 + nknotsx))),
       knots_y = as.numeric(quantile(data$y, 1:nknotsy / (1 + nknotsy))),
       bknots_x = range(data$new_x), bknots_y = range(data$y))
}

fit_common_basis <- function(data, knots_x, knots_y, bknots_x, bknots_y,
                             feature) {
  dat <- data
  shoe <- dat$shoe
  bx <- splines::ns(dat$new_x, knots = knots_x, Boundary.knots = bknots_x)
  by <- splines::ns(dat$y, knots = knots_y, Boundary.knots = bknots_y)
  if (identical(feature, "NEW_X_NS_XY")) {
    lme4::glmer(n_Acc ~ bx:by + (1 | shoe), data = dat,
                family = stats::binomial(link = "logit"),
                control = lme4::glmerControl(optimizer = "nlminbwrap"))
  } else if (identical(feature, "CML_MODEL")) {
    strata <- survival::strata
    survival::clogit(n_Acc ~ bx:by + strata(shoe), data = dat)
  } else {
    stop("fit_common_basis: feature must be NEW_X_NS_XY or CML_MODEL, not '",
         feature, "'", call. = FALSE)
  }
}

basis_of <- function(model) {
  # a coxph (CML) model frame is rebuilt by evaluating the step-3 formula,
  # which calls ns() by name, so splines must be on the search path
  if (!"package:splines" %in% search()) {
    suppressPackageStartupMessages(library(splines))
  }
  mf <- stats::model.frame(model)
  ns_terms <- Filter(function(v) inherits(v, "ns"), as.list(mf))
  if (length(ns_terms) != 2) {
    stop("basis_of: the model frame does not hold two ns() terms",
         call. = FALSE)
  }
  bx <- ns_terms[[1]]
  by <- ns_terms[[2]]
  list(knots_x = as.numeric(attr(bx, "knots")),
       knots_y = as.numeric(attr(by, "knots")),
       bknots_x = as.numeric(attr(bx, "Boundary.knots")),
       bknots_y = as.numeric(attr(by, "Boundary.knots")))
}
