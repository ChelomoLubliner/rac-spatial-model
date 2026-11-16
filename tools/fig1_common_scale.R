# Figs 1a and 1b of the report on one colour scale (Micha, 2026-11-16).
#
# Runs the map code of statistical_model/model_comparison_6.Rmd unchanged for
# each dataset (the chunks up to the matrix com_2_est = Random | CML, each
# exp(-sigma^2/2) * intensity, as in the paper) and draws both on one zlim.
# Nothing of OLD is overwritten: the Rmd's own figure paths are replaced by
# a null device before its chunks run. Outputs:
#   model_images/compare/pixel_inten_JASAup_common_scale_old_vs_new.{pdf,png}
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
  # x 1,000: RAC pixels per 1,000 contact pixels (the units of Fig. A2)
  list(est = 1000 * env$com_2_est, sigma_sq = env$sigma_sq,
       n_shoes = lme4::ngrps(env$random_model)[["shoe"]])
}

old <- map_for("old")
new <- map_for("new")
Sys.unsetenv("RAC_DATASET")

zlim <- range(c(old$est, new$est), na.rm = TRUE)
cat("sigma^2 old", old$sigma_sq, "new", new$sigma_sq, "\n")
cat("max old", max(old$est, na.rm = TRUE), "new", max(new$est, na.rm = TRUE),
    "common zlim", zlim, "\n")

# a perceptually uniform palette: the rainbow one exaggerates level steps
pal <- grDevices::hcl.colors(64, "viridis")
flip <- function(m) t(m[nrow(m):1, ])
draw <- function() {
  graphics::par(mfrow = c(1, 2), mar = c(3, 0.5, 3, 0.5), oma = c(1.5, 0, 2.5, 7))
  for (s in list(list(old, "Original collection"), list(new, "New collection"))) {
    graphics::image(flip(s[[1]]$est), zlim = zlim, col = pal,
                    axes = FALSE, useRaster = TRUE)
    graphics::mtext(paste0(s[[2]], ", ", s[[1]]$n_shoes, " shoes"), side = 3,
                    line = 1, cex = 1.3)
    graphics::mtext("Random effects", side = 1, at = 0.25, line = 0.8, cex = 1.05)
    graphics::mtext("CML", side = 1, at = 0.75, line = 0.8, cex = 1.05)
    for (at in c(0.25, 0.75)) {
      graphics::mtext("toe", side = 3, at = at, line = -0.2, cex = 0.85, col = "grey30")
      graphics::mtext("heel", side = 1, at = at, line = -0.6, cex = 0.85, col = "grey30")
    }
  }
  graphics::mtext("One colour scale for all four maps", outer = TRUE, side = 3,
                  line = 0.6, cex = 1.15, font = 2)
  graphics::mtext(paste("The CML level is set equal to the random-effects level;",
                        "both maps are multiplied by exp(-sigma^2/2), as in the paper."),
                  outer = TRUE, side = 1, line = 0.3, cex = 0.9, col = "grey30")
  graphics::par(mfrow = c(1, 1), oma = c(0, 0, 0, 1))
  fields::image.plot(zlim = zlim, legend.only = TRUE, col = pal,
                     legend.width = 1.2, legend.mar = 5,
                     legend.lab = "RAC pixels per 1,000 contact pixels",
                     legend.line = 3)
}

root <- dirname(getwd())
stem <- file.path(root, "model_images", "compare",
                  "pixel_inten_JASAup_common_scale_old_vs_new")
dir.create(dirname(stem), showWarnings = FALSE, recursive = TRUE)
grDevices::pdf(paste0(stem, ".pdf"), width = 13, height = 8)
draw()
grDevices::dev.off()
grDevices::png(paste0(stem, ".png"), width = 13, height = 8, units = "in",
               res = 130)
draw()
grDevices::dev.off()
cat("wrote", paste0(stem, c(".pdf", ".png")), sep = "\n")
