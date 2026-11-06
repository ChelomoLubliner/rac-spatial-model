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
#                              through a binary connection (so the eol is
#                              written as given on every platform), creating
#                              the folder if needed
# rac_ensure_dir(path)         create the parent folder of a file to write
# rac_new_output(P, path)      a model or figure about to be written: for
#                              OLD it must not exist (the committed files
#                              come from Windows R and never get a WSL
#                              rerun in place; OLD runs belong in a scratch
#                              copy that deletes them first, decision
#                              A-075); creates the folder; returns path
# rac_model_feature()          RAC_MODEL_FEATURE: NEW_X_NS_XY (default) or
#                              CML_MODEL
# rac_distance_impl()          RAC_DISTANCE_IMPL: vectorized (default since
#                              its byte-identity proof on OLD, A-076) or
#                              legacy (the row loops of step 2)
# Reading a profile does not use the random number generator (tested in
# tests/r/test_profile.R), so it can run before set.seed().
# User rule 1 is checked when a profile is read (T2 review; decision
# A-083): rac_profile() refuses a non-OLD profile in which an output file or
# folder lies in no NEW folder (RAC_NAMESPACE_FOLDERS), an output file lacks
# the suffix, an output file is an input of any dataset of the file or an
# output of another dataset, or an output lies in a work folder of another
# dataset; the same rule as contour_algorithm/profiles.py. So an edited
# path can never make a NEW run overwrite an OLD output or a raw input
# (rac_write_csv() itself does not check paths).
# The optional prep entry names the outputs of the T3 data preparation,
# written by the Python tools (decisions A-087, A-088): keys ending in _dir
# are folders, the others files (null: none); the rule-1 check covers them
# too, and an OLD prep.qa_dir is a work folder of the OLD profile.

RAC_DATASETS <- c("old", "new")
RAC_NAMESPACE_FOLDERS <- c("new", "new_shoes", "images_new", "sheets_new")

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

# The output files and folders named by a (cleaned) profile entry E, as
# named character vectors of relative paths.
.rac_output_paths <- function(E) {
  paths <- E$r$paths
  is_dir <- endsWith(names(paths), "_dir")
  key <- paste("r.paths", names(paths), sep = ".")
  prep <- Filter(Negate(is.null), as.list(E$prep))  # no prep: list()
  p_names <- as.character(names(prep))
  p_dir <- endsWith(p_names, "_dir")
  p_key <- paste("prep", p_names, sep = ".")
  named <- function(v, k) {
    if (length(v)) setNames(unlist(v), k) else character(0)
  }
  list(files = c(python.contour_out = E$python$contour_out,
                 named(paths[!is_dir], key[!is_dir]),
                 named(prep[!p_dir], p_key[!p_dir])),
       dirs = c(python.images_dir = E$python$images_dir,
                r.knit_dir = E$r$knit_dir, r.log_dir = E$r$log_dir,
                named(paths[is_dir], key[is_dir]),
                named(prep[p_dir], p_key[p_dir])))
}

# The input files named by a (cleaned) profile entry E.
.rac_input_paths <- function(E) {
  unname(unlist(c(E$inputs[c("contacts", "locations", "cross_check",
                             "sticker_masks")],
                  E$prototype[c("contour", "mask")])))
}

# User rule 1 for the non-OLD entry P (see the header); entries = every
# cleaned entry of the profile file, by name.
.rac_check_namespace <- function(P, entries) {
  parts <- function(rel) strsplit(rel, "/", fixed = TRUE)[[1]]
  inside <- function(p, d) p == d || startsWith(p, paste(d, "/", sep = ""))
  o <- .rac_output_paths(P)
  bad <- character(0)
  for (k in names(o$dirs)) {
    if (!any(parts(o$dirs[[k]]) %in% RAC_NAMESPACE_FOLDERS)) {
      bad <- c(bad, sprintf("%s '%s' lies in no NEW folder", k, o$dirs[[k]]))
    }
  }
  for (k in names(o$files)) {
    pp <- parts(o$files[[k]])
    stem <- sub("\\.[^.]*$", "", pp[length(pp)])
    if (!any(pp[-length(pp)] %in% RAC_NAMESPACE_FOLDERS)) {
      bad <- c(bad, sprintf("%s '%s' lies in no NEW folder", k, o$files[[k]]))
    } else if (!endsWith(stem, P$suffix)) {
      bad <- c(bad, sprintf("%s '%s' lacks the suffix '%s'", k, o$files[[k]],
                            P$suffix))
    }
  }
  protected <- character(0)  # path -> what it is
  for (nm in names(entries)) {
    E <- entries[[nm]]
    inp <- .rac_input_paths(E)
    protected <- c(protected, setNames(rep(paste("an input of the", nm,
                                                 "profile"), length(inp)), inp))
    if (identical(nm, P$dataset)) next
    out <- unname(.rac_output_paths(E)$files)
    protected <- c(protected, setNames(rep(paste("an output of the", nm,
                                                 "profile"), length(out)), out))
    work <- sort(c(E$python$images_dir, E$r$knit_dir, E$r$log_dir,
                   E$prep$qa_dir))
    all_out <- c(o$files, o$dirs)
    for (k in names(all_out)) {
      for (w in work) {
        if (inside(all_out[[k]], w)) {
          bad <- c(bad, sprintf(paste("%s '%s' lies in '%s', a work folder",
                                      "of the %s profile"),
                                k, all_out[[k]], w, nm))
        }
      }
    }
  }
  for (k in names(o$files)) {
    f <- o$files[[k]]
    if (f %in% names(protected)) {
      bad <- c(bad, sprintf("%s '%s' is %s", k, f, protected[[f]]))
    }
  }
  if (length(bad)) {
    stop("profile '", P$dataset, "' breaks the NEW namespace (user rule 1: ",
         "every NEW output lies in a folder named one of ",
         paste(RAC_NAMESPACE_FOLDERS, collapse = ", "), ", ends with '",
         P$suffix, "' and is never an input or another dataset's output): ",
         paste(bad, collapse = "; "), call. = FALSE)
  }
  invisible(P)
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
  # (jsonlite would read a missing file's name as JSON text)
  if (!file.exists(file)) stop("profile file ", file, " not found", call. = FALSE)
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
  for (key in c("cross_check", "sticker_masks", "snake_overrides")) {
    if (!is.null(P$inputs[[key]])) {
      .rac_check_rel(P$inputs[[key]], paste("inputs", key, sep = "."))
    }
  }
  if (!is.null(P$prep) && !is.list(P$prep)) {
    stop("profile '", dataset, "': prep must be an object", call. = FALSE)
  }
  for (key in names(P$prep)) {
    if (!is.null(P$prep[[key]])) {
      .rac_check_rel(P$prep[[key]], paste("prep", key, sep = "."))
    }
  }
  .rac_check_rel(P$python$contour_out, "python.contour_out")
  .rac_check_rel(P$prototype$contour, "prototype.contour")
  .rac_check_rel(P$prototype$mask, "prototype.mask")
  .rac_check_rel(P$r$knit_dir, "r.knit_dir")
  .rac_check_rel(P$r$log_dir, "r.log_dir")
  .rac_check_rel(P$python$images_dir, "python.images_dir")
  if (dataset != "old") {
    .rac_check_namespace(P, lapply(cfg$datasets, .rac_clean))
  }
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
  # A binary connection writes eol as given. A file name would be opened in
  # text mode, where R on Windows turns every "\n" into "\r\n" (so "\r\n"
  # would become "\r\r\n"); on Linux both give the same bytes.
  con <- file(path, "wb")
  on.exit(close(con))
  utils::write.csv(x, con, row.names = FALSE, eol = eol)
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
  f <- rac_env("RAC_DISTANCE_IMPL", "vectorized")
  if (!f %in% c("legacy", "vectorized")) {
    stop("RAC_DISTANCE_IMPL must be legacy or vectorized, not '", f, "'",
         call. = FALSE)
  }
  f
}
