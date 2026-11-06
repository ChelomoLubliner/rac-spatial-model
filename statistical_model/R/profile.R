# profile.R: dataset profiles for the R steps (plan section 4, A-003).
#
# Every dimension, count, skip list, threshold and path of the R steps comes
# from one entry of config/datasets.json, selected by RAC_DATASET=old|new
# (default old). The same file drives the Python step 0
# (contour_algorithm/profiles.py). OLD keeps the committed values and paths
# exactly; every NEW output sits in a new folder and carries the suffix _new.
#
# rac_env(name, default)       an RAC_* variable; unset or "" -> default
#                              (Sys.getenv() returns "" for a set-but-empty
#                              variable; decisions A-033, A-049)
# rac_profile(dataset, root, file)
#                              the profile list: numbers as doubles (like the
#                              legacy literals), empty arrays as numeric(0),
#                              plus P$root (with a trailing "/") and P$file
# rac_analysis_shoes(P)        1-based ids of the shoes with a contour record
#                              (all minus shoes_without_racs, excluded_shoes)
# rac_path(P, key)             absolute path of an input or output; for OLD
#                              the exact string paste(ROOT_PATH, "...",
#                              sep = "") built in the legacy Rmds
# rac_model_path(P, feature)   saved_models/<feature>.rds, or
#                              saved_models/new/<feature>_new.rds
# rac_image_path(P, stem)      model_images/<stem>.pdf, or
#                              model_images/new/<stem>_new.pdf
# rac_write_csv(x, P, key)     write.csv(x, rac_path(P, key),
#                              row.names = FALSE, eol = P$r$eol[[key]]),
#                              creating the folder if needed
# rac_ensure_dir(path)         create the parent folder of a file to write
# rac_new_output(P, path)      a model or figure about to be written: for
#                              OLD it must not exist (the committed files
#                              come from Windows R and never get a WSL
#                              rerun in place; OLD runs belong in a scratch
#                              copy that deletes them first, decision
#                              A-075); creates the folder; returns path
# rac_model_feature()          RAC_MODEL_FEATURE: NEW_X_NS_XY (default) or
#                              CML_MODEL
# rac_distance_impl()          RAC_DISTANCE_IMPL: legacy (default) or
#                              vectorized
# Reading a profile does not use the random number generator (tested in
# tests/r/test_profile.R), so it can run before set.seed().

RAC_DATASETS <- c("old", "new")

rac_env <- function(name, default) {
  v <- Sys.getenv(name, unset = NA_character_)
  if (is.na(v) || !nzchar(v)) default else v
}

# JSON arrays that hold numbers (jsonlite reads [] as list()).
.rac_numeric_vectors <- c("shoes_without_racs", "excluded_shoes",
                          "contact_flip_shoes", "center_rc", "radii_rc")

.rac_clean <- function(x) {
  if (is.list(x)) {
    if (!is.null(names(x))) x <- x[!startsWith(names(x), "_")]
    nm <- names(x)
    for (i in seq_along(x)) {
      if (!is.null(nm) && nm[i] %in% .rac_numeric_vectors) {
        x[[i]] <- as.numeric(unlist(x[[i]]))
      } else if (!is.null(x[[i]])) {
        x[[i]] <- .rac_clean(x[[i]])
      }
    }
    x
  } else if (is.numeric(x)) {
    as.numeric(x)
  } else {
    x
  }
}

.rac_check_rel <- function(rel, what) {
  if (!is.character(rel) || length(rel) != 1 || !nzchar(rel) ||
      startsWith(rel, "/") || grepl("\\", rel, fixed = TRUE) ||
      any(strsplit(rel, "/", fixed = TRUE)[[1]] %in% c("", ".", ".."))) {
    stop("profile: ", what, " must be a relative path without empty, '.' ",
         "or '..' parts: '", paste(rel, collapse = " "), "'", call. = FALSE)
  }
  invisible(rel)
}

.rac_check_shoes <- function(v, n, what) {
  if (length(v) && (any(v != round(v)) || is.unsorted(v, strictly = TRUE) ||
                    any(v < 1 | v > n))) {
    stop("profile: ", what, " must be sorted unique shoe ids in 1..", n,
         call. = FALSE)
  }
  invisible(v)
}

rac_profile <- function(dataset = rac_env("RAC_DATASET", "old"),
                        root = ROOT_PATH,
                        file = rac_env("RAC_PROFILE_FILE",
                                       "config/datasets.json")) {
  if (is.null(dataset) || length(dataset) != 1 || is.na(dataset) ||
      !nzchar(dataset)) {
    dataset <- "old"  # A-033: an empty RAC_DATASET means old
  }
  if (!dataset %in% RAC_DATASETS) {
    stop("RAC_DATASET must be one of ", paste(RAC_DATASETS, collapse = ", "),
         ", not '", dataset, "'", call. = FALSE)
  }
  if (!endsWith(root, "/")) root <- paste(root, "/", sep = "")
  if (!startsWith(file, "/")) file <- paste(root, file, sep = "")
  cfg <- jsonlite::fromJSON(file, simplifyVector = TRUE)
  P <- cfg$datasets[[dataset]]
  if (is.null(P)) {
    stop("profile file ", file, " has no dataset '", dataset, "'",
         call. = FALSE)
  }
  P <- .rac_clean(P)
  if (!identical(P$dataset, dataset)) {
    stop("profile entry '", dataset, "' names dataset '", P$dataset, "'",
         call. = FALSE)
  }
  want_suffix <- if (dataset == "old") "" else paste("_", dataset, sep = "")
  if (!identical(P$suffix, want_suffix)) {
    stop("profile '", dataset, "': suffix '", P$suffix, "'", call. = FALSE)
  }
  .rac_check_shoes(P$shoes_without_racs, P$num_shoe, "shoes_without_racs")
  .rac_check_shoes(P$excluded_shoes, P$num_shoe, "excluded_shoes")
  .rac_check_shoes(P$r$contact_flip_shoes, P$num_shoe, "r.contact_flip_shoes")
  if (length(intersect(P$shoes_without_racs, P$excluded_shoes))) {
    stop("profile '", dataset, "': a shoe is both without RACs and excluded",
         call. = FALSE)
  }
  if (!P$inputs$locations_format %in% c("csv", "space_no_header")) {
    stop("profile '", dataset, "': locations_format '",
         P$inputs$locations_format, "'", call. = FALSE)
  }
  for (key in names(P$r$paths)) {
    .rac_check_rel(P$r$paths[[key]], paste("r.paths", key, sep = "."))
  }
  for (key in c("contacts", "locations")) {
    .rac_check_rel(P$inputs[[key]], paste("inputs", key, sep = "."))
  }
  .rac_check_rel(P$python$contour_out, "python.contour_out")
  .rac_check_rel(P$prototype$contour, "prototype.contour")
  .rac_check_rel(P$prototype$mask, "prototype.mask")
  .rac_check_rel(P$r$knit_dir, "r.knit_dir")
  .rac_check_rel(P$r$log_dir, "r.log_dir")
  P$root <- root
  P$file <- file
  P
}

rac_analysis_shoes <- function(P) {
  setdiff(seq_len(P$num_shoe), c(P$shoes_without_racs, P$excluded_shoes))
}

rac_path <- function(P, key) {
  rel <- switch(key,
    contacts = P$inputs$contacts,
    locations = P$inputs$locations,
    cross_check = P$inputs$cross_check,
    sticker_masks = P$inputs$sticker_masks,
    contour = P$python$contour_out,
    prototype_contour = P$prototype$contour,
    prototype_mask = P$prototype$mask,
    P$r$paths[[key]])
  if (is.null(rel)) {
    stop("rac_path: the ", P$dataset, " profile has no path '", key, "'",
         call. = FALSE)
  }
  paste(P$root, rel, sep = "")
}

rac_model_path <- function(P, feature) {
  paste(P$root, P$r$paths$models_dir, "/", feature, P$suffix, ".rds",
        sep = "")
}

rac_image_path <- function(P, stem) {
  paste(P$root, P$r$paths$images_dir, "/", stem, P$suffix, ".pdf", sep = "")
}

rac_ensure_dir <- function(path) {
  d <- dirname(path)
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  invisible(path)
}

rac_new_output <- function(P, path) {
  if (identical(P$dataset, "old") && file.exists(path)) {
    stop("refusing to overwrite the committed OLD output ", path, ": OLD ",
         "runs belong in a scratch copy (tests/regress_old.sh deletes the ",
         "outputs first), or delete the file first (decision A-075)",
         call. = FALSE)
  }
  rac_ensure_dir(path)
}

rac_write_csv <- function(x, P, key) {
  eol <- P$r$eol[[key]]
  if (is.null(eol)) {
    stop("rac_write_csv: the ", P$dataset, " profile has no eol for '", key,
         "'", call. = FALSE)
  }
  path <- rac_ensure_dir(rac_path(P, key))
  utils::write.csv(x, path, row.names = FALSE, eol = eol)
  invisible(path)
}

rac_model_feature <- function() {
  f <- rac_env("RAC_MODEL_FEATURE", "NEW_X_NS_XY")
  if (!f %in% c("NEW_X_NS_XY", "CML_MODEL")) {
    stop("RAC_MODEL_FEATURE must be NEW_X_NS_XY or CML_MODEL, not '", f, "'",
         call. = FALSE)
  }
  f
}

rac_distance_impl <- function() {
  f <- rac_env("RAC_DISTANCE_IMPL", "legacy")
  if (!f %in% c("legacy", "vectorized")) {
    stop("RAC_DISTANCE_IMPL must be legacy or vectorized, not '", f, "'",
         call. = FALSE)
  }
  f
}
