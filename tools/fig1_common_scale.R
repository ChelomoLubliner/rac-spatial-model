# Figs 1a and 1b of the report on one colour scale (Micha, 2026-11-16).
#
# Runs the map code of statistical_model/model_comparison_6.Rmd unchanged for
# each dataset (the chunks up to the matrix com_2_est = Random | CML, each
# exp(-sigma^2/2) * intensity, as in the paper) and draws both on one zlim.
# Nothing of OLD is overwritten: the Rmd's own figure paths are replaced by
# a null device before its chunks run. Outputs:
#   model_images/compare/fig1a_original_common_scale.{pdf,png}
#   model_images/compare/fig1b_new_common_scale.{pdf,png}
#
# Run from statistical_model/:  Rscript ../tools/fig1_common_scale.R

suppressMessages(library(knitr))
rmd <- "model_comparison_6.Rmd"
stopifnot(file.exists(rmd))
code <- readLines(knitr::purl(rmd, output = tempfile(fileext = ".R"),
                              quiet = TRUE, documentation = 0))
# the Rmd stops on a committed OLD figure (A-075); this script writes none
guard <- 'rac_new_output(P, rac_image_path(P, s))'
stopifnot(sum(grepl(guard, code, fixed = TRUE)) == 1)
code <- sub(guard, '"/dev/null"', code, fixed = TRUE)
# stop before the Rmd writes its own PDF
cut <- grep('pdf(file = cmp_pdf[["pixel_inten_JASAup"]]', code, fixed = TRUE)
stopifnot(length(cut) == 1)
code <- code[seq_len(cut - 1)]

map_for <- function(dataset) {
  Sys.setenv(RAC_DATASET = dataset)
  env <- new.env(parent = globalenv())
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  eval(parse(text = code), envir = env)
  list(est = env$com_2_est, sigma_sq = env$sigma_sq,
       n_shoes = lme4::ngrps(env$random_model)[["shoe"]])
}

old <- map_for("old")
new <- map_for("new")
Sys.unsetenv("RAC_DATASET")

zlim <- range(c(old$est, new$est), na.rm = TRUE)
cat("sigma^2 old", old$sigma_sq, "new", new$sigma_sq, "\n")
cat("max old", max(old$est, na.rm = TRUE), "new", max(new$est, na.rm = TRUE),
    "common zlim", zlim, "\n")

# Exactly the report's Figs 1a and 1b (the Rmd's own plotting call:
# image.plot, default palette, same units, same labels), with one change:
# both use the same zlim.
one_fig <- function(est) {
  graphics::par(mar = c(2, 0, 0, 4))
  fields::image.plot(t(est[nrow(est):1, ]), axes = FALSE, xlab = "", zlim = zlim)
  graphics::mtext("Random", side = 1, at = 0.25, line = 0.5, cex = 2)
  graphics::mtext("CML", side = 1, at = 0.75, line = 0.5, cex = 2)
}

root <- dirname(getwd())
out <- file.path(root, "model_images", "compare")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
for (f in list(list(old, "fig1a_original_common_scale"),
               list(new, "fig1b_new_common_scale"))) {
  stem <- file.path(out, f[[2]])
  grDevices::pdf(paste0(stem, ".pdf"), height = 8, width = 8)
  one_fig(f[[1]]$est)
  grDevices::dev.off()
  grDevices::png(paste0(stem, ".png"), height = 8, width = 8, units = "in", res = 120)
  one_fig(f[[1]]$est)
  grDevices::dev.off()
  cat("wrote", stem, "\n")
}
