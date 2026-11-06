# Dataset profiles in R (plan T2 step 1; decisions A-003, A-033, A-049).
# rac_profile("old") must give the legacy literals (doubles) and the exact
# legacy path strings; NEW must be namespaced and must keep the OLD
# prototype frame; the selection rules for RAC_DATASET and every RAC_*
# variable; reading a profile must not touch the RNG; rac_write_csv() writes
# the profile's line endings. Writes only to tempdir().
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
tracked <- system2("git", c("-C", shQuote(root), "ls-files"), stdout = TRUE)
rel <- function(p) substring(p, nchar(ROOT_PATH) + 1)
new_files <- c(vapply(names(N$r$paths)[!endsWith(names(N$r$paths), "_dir")],
                      function(k) rel(rac_path(N, k)), ""),
               rel(rac_path(N, "contour")),
               vapply(c("NEW_X_NS_XY", "CML_MODEL"),
                      function(f) rel(rac_model_path(N, f)), ""),
               vapply(figures, function(s) rel(rac_image_path(N, s)), ""))
old_files <- c(vapply(names(P$r$paths)[!endsWith(names(P$r$paths), "_dir")],
                      function(k) rel(rac_path(P, k)), ""),
               rel(rac_path(P, "contour")),
               vapply(c("NEW_X_NS_XY", "CML_MODEL"),
                      function(f) rel(rac_model_path(P, f)), ""),
               vapply(figures, function(s) rel(rac_image_path(P, s)), ""))
for (f in new_files) {
  parts <- strsplit(f, "/", fixed = TRUE)[[1]]
  stem <- sub("\\.[A-Za-z]+$", "", parts[length(parts)])
  if (!(any(parts[-length(parts)] %in% c("new", "new_shoes")) &&
        endsWith(stem, "_new"))) {
    stop("NEW output not namespaced: ", f)
  }
}
stopifnot(!any(new_files %in% old_files), !any(new_files %in% tracked))
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
                   "equals or lies inside an OLD output or a tracked file"),
             length(new_files), length(new_dirs)))

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
unlink(sub("/$", "", tmp_root), recursive = TRUE)
pass("rac_write_csv: CRLF for OLD dataCC, LF for NEW, folders created")
cat("ALL PASS test_profile\n")
