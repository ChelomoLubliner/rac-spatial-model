# Dataset profiles in R (plan T2 step 1; decisions A-003, A-033, A-049).
# rac_profile("old") must give the legacy literals (doubles) and the exact
# legacy path strings; NEW must be namespaced and must keep the OLD
# prototype frame; the selection rules for RAC_DATASET and every RAC_*
# variable; reading a profile must not touch the RNG; rac_write_csv() writes
# the profile's line endings; rac_new_output() refuses to overwrite an OLD
# model or figure (A-075); config.R gives the legacy MEAN_OFFSET for OLD,
# the OLD fallback without the pixel-count file, and NA with a warning for
# NEW without it (A-021), and MODEL_FEATURE from RAC_MODEL_FEATURE. Writes
# only to tempdir().
#
# Run from anywhere:  Rscript tests/r/test_profile.R
root <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(file.path(dirname(f), "..", ".."))
})
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
pass <- function(name) cat("PASS", name, "\n")
rac_vars <- c("RAC_DATASET", "RAC_PROFILE_FILE", "RAC_MODEL_FEATURE",
              "RAC_DISTANCE_IMPL")
Sys.unsetenv(rac_vars)

# 0. Reading a profile does not use the RNG, including the first load of
# jsonlite (so the Rmds can read P before set.seed()).
stopifnot(!"jsonlite" %in% loadedNamespaces())
set.seed(1)
before <- .Random.seed
P <- rac_profile("old")
invisible(rac_profile("new"))
stopifnot("jsonlite" %in% loadedNamespaces(), identical(before, .Random.seed))
pass("rac_profile() leaves .Random.seed unchanged (jsonlite loaded by it)")

# 1. OLD values are identical() to the legacy literals (doubles).
legacy <- list(col_shoe = 307, row_shoe = 395, num_shoe = 387,
               rel_col_shoe = 150, rel_row_shoe = 300, rel_x_cord = 0.25,
               rel_Y_cord = 0.5)
got <- list(col_shoe = P$col_shoe, row_shoe = P$row_shoe,
            num_shoe = P$num_shoe, rel_col_shoe = P$coords$rel_col_shoe,
            rel_row_shoe = P$coords$rel_row_shoe,
            rel_x_cord = P$coords$rel_x_cord, rel_Y_cord = P$coords$rel_Y_cord)
stopifnot(identical(got, legacy))
stopifnot(identical(P$r$stamp_threshold, 8), identical(P$r$n_controls, 100),
          identical(P$r$seed, 313), identical(P$r$stamp_sweep_bound, 300),
          identical(P$r$contact_flip_shoes, 9),
          identical(P$shoes_without_racs, 127),
          identical(P$excluded_shoes, numeric(0)),
          identical(P$r$mean_offset_fallback_pixels, 10615),
          identical(P$prototype$col_shoe, 307),
          identical(P$prototype$row_shoe, 395),
          identical(P$prototype$coords$rel_Y_cord, 0.5),
          identical(P$prototype$coords$rel_col_shoe, 150))
pass("OLD profile values identical() to the legacy literals (doubles)")

# 2. OLD paths are the exact strings the legacy Rmds built.
CONTOUR_ALGORITHM <- "Active_Contour"
legacy_paths <- c(
  dataCC = paste(ROOT_PATH, "processed_data/dataCC.csv", sep = ""),
  pixel_counts = paste(ROOT_PATH, "processed_data/shoe_pixel_counts.csv",
                       sep = ""),
  all_cont = paste(ROOT_PATH, "data/all_cont.csv", sep = ""),
  dataCC_distance_temp = paste(ROOT_PATH,
                               "processed_data/dataCC_distance_temp.csv",
                               sep = ""),
  dataCC_distance = paste(ROOT_PATH, "processed_data/dataCC_distance.csv",
                          sep = ""),
  contour = paste(ROOT_PATH, "data/contour_", CONTOUR_ALGORITHM, ".txt",
                  sep = ""),
  contacts = paste(ROOT_PATH, "data/contacts_data.txt", sep = ""),
  locations = paste(ROOT_PATH, "data/locations_data.csv", sep = ""),
  prototype_contour = paste(ROOT_PATH, "data/contour_prototype.png", sep = ""),
  prototype_mask = paste(ROOT_PATH, "data/freq_min_18.png", sep = ""))
for (k in names(legacy_paths)) stopifnot(identical(rac_path(P, k),
                                                   legacy_paths[[k]]))
for (f in c("NEW_X_NS_XY", "CML_MODEL")) {
  stopifnot(identical(rac_model_path(P, f),
                      paste(ROOT_PATH, "saved_models/", f, ".rds", sep = "")))
}
figures <- c("NEW_X_NS_XY_SHOE", "CML_MODEL_SHOE", "CI_shoe_cuts",
             "CI_cut_110", "CI_cut_190", "CI_cut_250", "pixel_inten_JASAup",
             "difference_random_cml")
for (s in figures) {
  stopifnot(identical(rac_image_path(P, s),
                      paste(ROOT_PATH, "model_images/", s, ".pdf", sep = "")))
}
stopifnot(identical(P$r$eol$dataCC, "\r\n"), identical(P$r$eol$all_cont, "\r\n"),
          identical(P$r$eol$pixel_counts, "\r\n"),
          identical(P$r$eol$dataCC_distance, "\n"),
          identical(P$r$eol$dataCC_distance_temp, "\n"))
pass("OLD paths are the legacy strings; OLD CSV line endings as committed")
stopifnot(identical(rac_analysis_shoes(P), c(1:126, 128:387)))
pass("OLD analysis shoes 1-126, 128-387 (integer)")

# 3. NEW: dimensions, the OLD prototype frame, namespaced outputs.
N <- rac_profile("new")
stopifnot(identical(N$col_shoe, 255), identical(N$row_shoe, 367),
          identical(N$num_shoe, 631),
          identical(N$prototype$col_shoe, 307),
          identical(N$prototype$row_shoe, 395),
          identical(N$prototype$contour, P$prototype$contour),
          identical(N$prototype$mask, P$prototype$mask),
          identical(N$shoes_without_racs, numeric(0)),
          identical(rac_analysis_shoes(N), 1:631),
          identical(N$r$stamp_sweep_bound, 255),
          is.null(N$r$mean_offset_fallback_pixels),
          identical(N$coords$divisor, 2))
pass("NEW profile: 255 x 367, 631 shoes, the OLD prototype frame 307 x 395")
git_lines <- function(...) {
  out <- system2("git", c("-C", shQuote(root), ...), stdout = TRUE)
  stopifnot(is.null(attr(out, "status")), length(out) > 0)
  out
}
tracked <- git_lines("ls-files")
# every file of the Tier A baseline commit is OLD (code, OLD outputs, the
# raw inputs of both datasets)
baseline <- git_lines("ls-tree", "-r", "--name-only", "79247d8")
rel <- function(p) substring(p, nchar(ROOT_PATH) + 1)
outputs_of <- function(Q) {
  c(vapply(names(Q$r$paths)[!endsWith(names(Q$r$paths), "_dir")],
           function(k) rel(rac_path(Q, k)), ""),
    contour = rel(rac_path(Q, "contour")),
    vapply(c("NEW_X_NS_XY", "CML_MODEL"),
           function(f) rel(rac_model_path(Q, f)), ""),
    vapply(figures, function(s) rel(rac_image_path(Q, s)), ""))
}
new_files <- outputs_of(N)
old_files <- outputs_of(P)
namespaced <- function(f) {
  parts <- strsplit(f, "/", fixed = TRUE)[[1]]
  stem <- sub("\\.[A-Za-z]+$", "", parts[length(parts)])
  any(parts[-length(parts)] %in% c("new", "new_shoes", "images_new")) &&
    endsWith(stem, "_new")
}
for (f in new_files) {
  if (!namespaced(f)) stop("NEW output not namespaced: ", f)
}
# The files no NEW output may be (T2 review, finding 2: the earlier rule
# took every tracked file for OLD and would fail once T4 commits the NEW
# contour): every file of the baseline commit, every tracked file outside
# the NEW namespace (the OLD files committed since 79247d8, such as T2's
# shoe_codes.csv and wald_test.csv), and every input of the profiles.
inputs_of <- function(Q) {
  keys <- c("contacts", "locations", "prototype_contour", "prototype_mask",
            if (!is.null(Q$inputs$cross_check)) "cross_check",
            if (!is.null(Q$inputs$sticker_masks)) "sticker_masks")
  vapply(keys, function(k) rel(rac_path(Q, k)), "")
}
collisions <- function(Q, O, tracked, baseline) {
  protected <- unique(c(baseline, tracked[!vapply(tracked, namespaced, TRUE)],
                        inputs_of(O), inputs_of(Q)))
  nf <- outputs_of(Q)
  unname(nf[nf %in% c(outputs_of(O), protected)])
}
stopifnot(!anyDuplicated(new_files), !any(new_files %in% old_files),
          length(collisions(N, P, tracked, baseline)) == 0)
# every NEW output committed (T4: the NEW contour; T5: the NEW CSVs and
# models): still no collision; a NEW output that is an OLD tracked file or
# an input is still caught (mutated copies of N, built without rac_profile,
# whose rule-1 check would refuse them)
with_new <- c(tracked, new_files)
stopifnot("data/new_shoes/contour_Active_Contour_new.txt" %in% with_new,
          length(collisions(N, P, with_new, baseline)) == 0,
          "docs/decisions.md" %in% tracked, !"docs/decisions.md" %in% baseline)
mutants <- list(
  list("python", "contour_out", "data/contour_Active_Contour.txt"),
  list("r_path", "wald_test", "processed_data/wald_test.csv"),
  list("r_path", "dataCC", "docs/decisions.md"),
  list("python", "contour_out", "data/new_shoes/contacts_data_new.txt"),
  list("r_path", "all_cont", "data/new_shoes/README.md"))
for (m in mutants) {
  M <- N
  if (m[[1]] == "python") M$python[[m[[2]]]] <- m[[3]]
  else M$r$paths[[m[[2]]]] <- m[[3]]
  if (!identical(collisions(M, P, with_new, baseline), m[[3]])) {
    stop("collision not caught: ", m[[2]], " = ", m[[3]])
  }
}
old_dirs <- c(P$r$knit_dir, P$r$log_dir, P$python$images_dir)
new_dirs <- c(N$r$knit_dir, N$r$log_dir, N$python$images_dir,
              N$r$paths$models_dir, N$r$paths$images_dir)
inside <- function(p, d) p == d || startsWith(p, paste(d, "/", sep = ""))
for (p in c(new_files, new_dirs)) {
  for (d in c(old_files, old_dirs)) {
    if (inside(p, d)) stop("NEW path ", p, " is or lies inside OLD ", d)
  }
}
pass(sprintf(paste("NEW outputs (%d files, %d folders) namespaced; none",
                   "equals or lies inside an OLD output, an input or an OLD",
                   "tracked file; committed NEW outputs pass, %d mutants",
                   "caught"),
             length(new_files), length(new_dirs), length(mutants)))

# 3b. User rule 1 at load (T2 review; A-083): rac_profile() refuses a NEW
# profile whose outputs leave the NEW namespace, name an input or another
# dataset's output, or lie in an OLD work folder; the real profile and the
# sentinel fixture load; OLD keeps its legacy (not namespaced) paths.
cfg0 <- jsonlite::fromJSON(file.path(root, "config", "datasets.json"),
                           simplifyVector = FALSE)
broken <- function(edit) {
  cfg <- edit(cfg0)
  f <- tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(cfg, auto_unbox = TRUE, null = "null",
                              digits = NA), f)
  f
}
load_msg <- function(f, dataset = "new") {
  tryCatch({
    rac_profile(dataset, file = f)
    "loaded"
  }, error = function(e) conditionMessage(e))
}
edits <- list(
  "dataCC = the OLD dataCC.csv" = function(c) {
    c$datasets$new$r$paths$dataCC <- "processed_data/dataCC.csv"; c },
  "dataCC without the suffix" = function(c) {
    c$datasets$new$r$paths$dataCC <- "processed_data/new/dataCC.csv"; c },
  "dataCC without a NEW folder" = function(c) {
    c$datasets$new$r$paths$dataCC <- "processed_data/dataCC_new.csv"; c },
  "wald_test = the OLD file T2 added" = function(c) {
    c$datasets$new$r$paths$wald_test <- "processed_data/wald_test.csv"; c },
  "models_dir = the OLD folder" = function(c) {
    c$datasets$new$r$paths$models_dir <- "saved_models"; c },
  "knit_dir = the OLD knit folder" = function(c) {
    c$datasets$new$r$knit_dir <- "statistical_model"; c },
  "log_dir inside the OLD log folder" = function(c) {
    c$datasets$new$r$log_dir <- "logs/old/new"; c },
  "images_dir inside the OLD work folder" = function(c) {
    c$datasets$new$python$images_dir <- "images/new"; c },
  "contour = the raw NEW contacts" = function(c) {
    c$datasets$new$python$contour_out <- "data/new_shoes/contacts_data_new.txt"
    c },
  "contour = an OLD output (OLD entry edited)" = function(c) {
    c$datasets$old$python$contour_out <- "data/new_shoes/c_new.txt"
    c$datasets$new$python$contour_out <- "data/new_shoes/c_new.txt"
    c })
for (nm in names(edits)) {
  msg <- load_msg(broken(edits[[nm]]))
  if (!grepl("user rule 1", msg, fixed = TRUE)) {
    stop("rule 1 not enforced at load for '", nm, "': ", msg)
  }
}
stopifnot(identical(load_msg(file.path(root, "config", "datasets.json")),
                    "loaded"),
          identical(load_msg(file.path(root, "tests", "fixtures", "sentinel",
                                       "sentinel_profile.json")), "loaded"),
          identical(load_msg(broken(function(c) {
            c$datasets$old$r$paths$dataCC <- "processed_data/dataCC.csv"; c
          }), "old"), "loaded"))
pass(sprintf(paste("rac_profile() refuses %d NEW profiles that break rule 1;",
                   "the real profile, the fixture and OLD load"),
             length(edits)))

# 4. Selection: unset or "" -> old; new; anything else is an error.
Sys.unsetenv("RAC_DATASET")
stopifnot(identical(rac_profile()$dataset, "old"))
Sys.setenv(RAC_DATASET = "")
stopifnot(identical(rac_profile()$dataset, "old"),
          identical(rac_profile("")$dataset, "old"))
Sys.setenv(RAC_DATASET = "new")
stopifnot(identical(rac_profile()$dataset, "new"),
          identical(rac_profile("old")$dataset, "old"))
for (bad in c("foo", "OLD", "new ")) {
  Sys.setenv(RAC_DATASET = bad)
  stopifnot(inherits(try(rac_profile(), silent = TRUE), "try-error"))
}
stopifnot(inherits(try(rac_profile("foo"), silent = TRUE), "try-error"))
Sys.unsetenv("RAC_DATASET")
pass("RAC_DATASET: unset and empty give old, new gives new, others error")
for (v in rac_vars) {
  Sys.unsetenv(v)
  stopifnot(identical(rac_env(v, "dflt"), "dflt"))
  do.call(Sys.setenv, setNames(list(""), v))
  stopifnot(identical(rac_env(v, "dflt"), "dflt"))
  do.call(Sys.setenv, setNames(list("x"), v))
  stopifnot(identical(rac_env(v, "dflt"), "x"))
  Sys.unsetenv(v)
}
Sys.setenv(RAC_MODEL_FEATURE = "")
stopifnot(identical(rac_model_feature(), "NEW_X_NS_XY"))
Sys.setenv(RAC_MODEL_FEATURE = "CML_MODEL")
stopifnot(identical(rac_model_feature(), "CML_MODEL"))
Sys.setenv(RAC_MODEL_FEATURE = "GLMM")
stopifnot(inherits(try(rac_model_feature(), silent = TRUE), "try-error"))
Sys.setenv(RAC_DISTANCE_IMPL = "")
stopifnot(identical(rac_distance_impl(), "vectorized"))
Sys.setenv(RAC_DISTANCE_IMPL = "legacy")
stopifnot(identical(rac_distance_impl(), "legacy"))
Sys.setenv(RAC_DISTANCE_IMPL = "fast")
stopifnot(inherits(try(rac_distance_impl(), silent = TRUE), "try-error"))
Sys.unsetenv(rac_vars)
pass("rac_env(): unset and \"\" give the default for every RAC_* variable")

# 5. RAC_PROFILE_FILE names another profile file (tests only).
cfg <- jsonlite::fromJSON(file.path(root, "config", "datasets.json"),
                          simplifyVector = FALSE)
cfg$datasets$old$num_shoe <- 388
alt <- tempfile(fileext = ".json")
writeLines(jsonlite::toJSON(cfg, auto_unbox = TRUE, null = "null"), alt)
Sys.setenv(RAC_PROFILE_FILE = alt)
stopifnot(identical(rac_profile("old")$num_shoe, 388),
          identical(rac_profile("old")$file, alt))
Sys.setenv(RAC_PROFILE_FILE = "")
stopifnot(identical(rac_profile("old")$num_shoe, 387))
Sys.unsetenv("RAC_PROFILE_FILE")
pass("RAC_PROFILE_FILE selects another profile file; empty means default")

# 6. rac_write_csv: the profile's line ending, folders created.
tmp_root <- paste(tempfile("rac_root_"), "/", sep = "")
Q <- P
Q$root <- tmp_root
df <- data.frame(a = 1:2, b = c(0.5, 1 / 3))
rac_write_csv(df, Q, "dataCC")
raw <- readBin(rac_path(Q, "dataCC"), "raw", 1000)
stopifnot(sum(raw == as.raw(13)) == 3, sum(raw == as.raw(10)) == 3)
QN <- N
QN$root <- tmp_root
rac_write_csv(df, QN, "dataCC")
raw <- readBin(rac_path(QN, "dataCC"), "raw", 1000)
stopifnot(sum(raw == as.raw(13)) == 0, sum(raw == as.raw(10)) == 3,
          file.exists(paste(tmp_root, "processed_data/new/dataCC_new.csv",
                            sep = "")))
stopifnot(inherits(try(rac_write_csv(df, Q, "no_such_key"), silent = TRUE),
                   "try-error"))
# the bytes are those of write.csv to a file name on Linux (where text and
# binary mode agree), so the OLD outputs do not change
ref <- tempfile(fileext = ".csv")
write.csv(df, ref, row.names = FALSE, eol = "\r\n")
stopifnot(identical(readBin(ref, "raw", 1000),
                    readBin(rac_path(Q, "dataCC"), "raw", 1000)))
pass("rac_write_csv: CRLF for OLD dataCC, LF for NEW, folders created")

# 7. rac_new_output: an existing OLD model or figure is never overwritten
f_old <- rac_model_path(Q, "NEW_X_NS_XY")
stopifnot(identical(rac_new_output(Q, f_old), f_old), dir.exists(dirname(f_old)))
writeLines("x", f_old)
stopifnot(inherits(try(rac_new_output(Q, f_old), silent = TRUE), "try-error"))
f_new <- rac_image_path(QN, "CI_cut_110")
stopifnot(identical(rac_new_output(QN, f_new), f_new))
writeLines("x", f_new)
stopifnot(identical(rac_new_output(QN, f_new), f_new))
unlink(sub("/$", "", tmp_root), recursive = TRUE)
pass("rac_new_output: refuses an existing OLD output, NEW may be rewritten")

# 8. config.R: MEAN_OFFSET and MODEL_FEATURE.
run_config <- function(dir, dataset, feature = "") {
  e <- new.env()
  warn <- character(0)
  old_wd <- setwd(file.path(dir, "statistical_model"))
  on.exit(setwd(old_wd))
  Sys.setenv(RAC_DATASET = dataset, RAC_MODEL_FEATURE = feature)
  withCallingHandlers(sys.source("config.R", envir = e),
                      warning = function(w) {
                        warn <<- c(warn, conditionMessage(w))
                        invokeRestart("muffleWarning")
                      })
  list(env = e, warn = warn)
}
r_old <- run_config(root, "old")
stopifnot(round(r_old$env$MEAN_OFFSET, 9) == -4.614310784,
          !length(r_old$warn), identical(r_old$env$N_CONTROLS, 100),
          identical(r_old$env$MODEL_FEATURE, "NEW_X_NS_XY"),
          identical(r_old$env$P$dataset, "old"))
stopifnot(identical(run_config(root, "old", "CML_MODEL")$env$MODEL_FEATURE,
                    "CML_MODEL"))
# a root without any pixel-count file
bare <- tempfile("rac_bare_")
dir.create(file.path(bare, "statistical_model", "R"), recursive = TRUE)
dir.create(file.path(bare, "config"))
invisible(file.copy(file.path(root, "statistical_model", "config.R"),
                    file.path(bare, "statistical_model")))
invisible(file.copy(list.files(file.path(root, "statistical_model", "R"),
                               full.names = TRUE),
                    file.path(bare, "statistical_model", "R")))
invisible(file.copy(file.path(root, "config", "datasets.json"),
                    file.path(bare, "config")))
r_fb <- run_config(bare, "old")
stopifnot(identical(r_fb$env$MEAN_OFFSET, log(100 / 10615)),
          length(r_fb$warn) == 1)
r_new <- run_config(bare, "new")
stopifnot(identical(r_new$env$MEAN_OFFSET, NA_real_),
          length(r_new$warn) == 1, grepl("NA", r_new$warn),
          identical(r_new$env$P$dataset, "new"))
unlink(bare, recursive = TRUE)
Sys.unsetenv(rac_vars)
pass(paste("config.R: OLD MEAN_OFFSET -4.614310784; without the pixel-count",
           "file OLD falls back to log(100/10615), NEW is NA with a warning;",
           "MODEL_FEATURE from RAC_MODEL_FEATURE"))
cat("ALL PASS test_profile\n")
