# t5_stamp_mask.R: the R stamp mask of step 1 on NEW, thresholds 8 and 13
# (plan T3 step 4, carried into T5; decision A-110).
#
# Evaluates the pipeline's own code: chunk "3_contacts_data" of
# statistical_model/dataCC_1.Rmd (records, erase list, flips, then the
# stamp threshold and the two sweeps) and chunk "4.contacts" (the RAC pixel
# matrices), with P$r$stamp_threshold set to each threshold in turn. For
# OLD it runs the committed threshold 8 and checks that the mask equals the
# committed data/all_cont.csv.
#
# Writes (argv[1] = NEW folder, argv[2] = compare folder, argv[3] = scratch):
#   <compare>/stamp_threshold_old_vs_new.csv   one row per (dataset,
#                                   threshold)
#   <new>/stamp_shoes_new.csv       per NEW shoe and threshold: contact px,
#                                   px kept by the mask, RAC pixels off
#                                   the mask (filled back by step 1)
#   <scratch>/<dataset>_t<t>_mask.csv, <dataset>_sum.csv   the masks and the
#                                   superposition counts, for the figure
#
# Usage (repo root):
#   Rscript docs/qa/T5/probes/t5_stamp_mask.R NEW_DIR COMPARE_DIR SCRATCH
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3)
out_dir <- args[1]
cmp_dir <- args[2]
scr <- args[3]
root <- normalizePath(".")
ROOT_PATH <- paste(root, "/", sep = "")
source(file.path(root, "statistical_model", "R", "profile.R"))
source(file.path(root, "statistical_model", "R", "io.R"))
source(file.path(root, "tests", "lib", "rmd_chunk.R"))
rmd <- file.path(root, "statistical_model", "dataCC_1.Rmd")
chunk3 <- rmd_chunk(rmd, "3_contacts_data")
split_at <- grep("#########cleaning the data set", chunk3, fixed = TRUE)
stopifnot(length(split_at) == 1)
read_part <- chunk3[seq_len(split_at - 1)]
clean_part <- chunk3[split_at:length(chunk3)]
init_fun <- rmd_chunk(rmd, "2.init_functions")
contacts4 <- rmd_chunk(rmd, "4.contacts")

# 4-connected components of a logical matrix: list of c(size, row0, row1,
# col0, col1)
components <- function(m) {
  nr <- nrow(m)
  nc <- ncol(m)
  lab <- matrix(0L, nr, nc)
  out <- list()
  k <- 0L
  queue <- integer(sum(m))
  for (s in which(m)) {
    if (lab[s] != 0L) next
    k <- k + 1L
    lab[s] <- k
    queue[1] <- s
    head <- 1L
    tail <- 1L
    while (head <= tail) {
      p <- queue[head]
      head <- head + 1L
      r <- (p - 1L) %% nr + 1L
      cc <- (p - 1L) %/% nr + 1L
      q <- c(if (r > 1L) p - 1L, if (r < nr) p + 1L, if (cc > 1L) p - nr,
             if (cc < nc) p + nr)
      q <- q[m[q] & lab[q] == 0L]
      if (length(q)) {
        lab[q] <- k
        queue[tail + seq_along(q)] <- q
        tail <- tail + length(q)
      }
    }
    members <- queue[seq_len(tail)]
    rr <- (members - 1L) %% nr + 1L
    cc <- (members - 1L) %/% nr + 1L
    out[[k]] <- c(size = tail, row0 = min(rr), row1 = max(rr),
                  col0 = min(cc), col1 = max(cc))
  }
  out
}

run_dataset <- function(dataset, thresholds) {
  P <- rac_profile(dataset, root = ROOT_PATH)
  e <- new.env()
  e$P <- P
  e$ROOT_PATH <- ROOT_PATH
  for (f in c("rac_path", "rac_read_sticker_masks", "rac_apply_sticker_masks",
              "read_locations", "rac_analysis_shoes")) {
    assign(f, get(f), envir = e)
  }
  # the constants of the first code chunk of the Rmd
  eval(parse(text = c("col_shoe <- P$col_shoe", "row_shoe <- P$row_shoe",
                      "num_shoe <- P$num_shoe",
                      "rel_col_shoe <- P$coords$rel_col_shoe",
                      "rel_row_shoe <- P$coords$rel_row_shoe",
                      "rel_x_cord <- P$coords$rel_x_cord",
                      "rel_Y_cord <- P$coords$rel_Y_cord")), envir = e)
  eval(parse(text = init_fun), envir = e)
  t0 <- Sys.time()
  eval(parse(text = read_part), envir = e)
  cat(dataset, ": records read in", format(Sys.time() - t0), "\n")
  raw <- e$data
  sum_raw <- Reduce(`+`, raw)
  utils::write.csv(sum_raw, file.path(scr, paste0(dataset, "_sum.csv")),
                   row.names = FALSE)
  # the RAC pixel matrices of step 1 (chunk 4.contacts)
  eval(parse(text = contacts4), envir = e)
  acci <- e$acci
  shoes <- as.integer(unique(e$acciden$shoe))
  rows <- list()
  shoe_rows <- list()
  for (t in thresholds) {
    f <- new.env(parent = e)
    f$data <- raw
    f$P <- P
    f$P$r$stamp_threshold <- t
    eval(parse(text = clean_part), envir = f)
    mask <- f$allcont
    utils::write.csv(mask, file.path(scr, sprintf("%s_t%d_mask.csv", dataset,
                                                  t)), row.names = FALSE)
    ge <- sum_raw >= t
    swept <- ge & mask == 0
    comp_s <- components(swept)
    comp_m <- components(mask == 1)
    sizes_m <- sort(vapply(comp_m, function(z) z[["size"]], 0), TRUE)
    contact <- vapply(shoes, function(i) sum(raw[[i]]), 0)
    kept <- vapply(shoes, function(i) sum(raw[[i]] * mask), 0)
    rac_px <- vapply(shoes, function(i) sum(acci[[i]] >= 1), 0)
    rac_off_mask <- vapply(shoes, function(i)
      sum(acci[[i]] >= 1 & mask == 0), 0)
    rac_off_raw <- vapply(shoes, function(i)
      sum(acci[[i]] >= 1 & raw[[i]] == 0), 0)
    rac_on_raw_off_mask <- vapply(shoes, function(i)
      sum(acci[[i]] >= 1 & raw[[i]] == 1 & mask == 0), 0)
    share <- kept / contact
    rows[[length(rows) + 1]] <- data.frame(
      dataset = dataset, threshold = t, px_ge_t = sum(ge),
      mask_px = sum(mask), swept_px = sum(swept),
      swept_components = length(comp_s),
      swept_largest = if (length(comp_s)) max(vapply(comp_s, function(z)
        z[["size"]], 0)) else 0,
      swept_bboxes = paste(vapply(comp_s, function(z)
        sprintf("%d px r%d-%d c%d-%d", z[["size"]], z[["row0"]], z[["row1"]],
                z[["col0"]], z[["col1"]]), ""), collapse = "; "),
      mask_components = length(comp_m),
      mask_outside_main_px = sum(sizes_m) - sizes_m[1],
      contact_px = sum(contact), kept_px = sum(kept),
      removed_px = sum(contact) - sum(kept),
      shoes_losing_any = sum(kept < contact),
      kept_share_min = min(share),
      kept_share_p1 = unname(quantile(share, 0.01)),
      kept_share_p5 = unname(quantile(share, 0.05)),
      kept_share_median = median(share),
      shoes_below_0.99 = sum(share < 0.99),
      shoes_below_0.95 = sum(share < 0.95),
      rac_px = sum(rac_px), rac_px_off_mask = sum(rac_off_mask),
      rac_px_off_raw = sum(rac_off_raw),
      rac_px_on_raw_off_mask = sum(rac_on_raw_off_mask))
    shoe_rows[[length(shoe_rows) + 1]] <- data.frame(
      dataset = dataset, threshold = t, shoe = shoes, contact_px = contact,
      kept_px = kept, kept_share = round(share, 6), rac_px = rac_px,
      rac_px_off_mask = rac_off_mask, rac_px_on_raw_off_mask =
        rac_on_raw_off_mask)
    cat(sprintf("%s t=%d: >=t %d px, mask %d px, swept %d px in %d comps;",
                dataset, t, sum(ge), sum(mask), sum(swept), length(comp_s)),
        sprintf("kept share p5 %.4f median %.4f min %.4f\n",
                quantile(share, 0.05), median(share), min(share)))
    if (dataset == "old" && t == 8) {
      committed <- as.matrix(read.csv(rac_path(P, "all_cont")))
      stopifnot(identical(unname(committed), unname(mask * 1)) ||
                  all(unname(committed) == unname(mask)))
      cat("old t=8: equal to the committed data/all_cont.csv\n")
    }
  }
  list(rows = do.call(rbind, rows), shoes = do.call(rbind, shoe_rows))
}

old <- run_dataset("old", 8)
new <- run_dataset("new", c(8, 13))
utils::write.csv(rbind(old$rows, new$rows),
                 file.path(cmp_dir, "stamp_threshold_old_vs_new.csv"),
                 row.names = FALSE)
utils::write.csv(new$shoes, file.path(out_dir, "stamp_shoes_new.csv"),
                 row.names = FALSE)
utils::write.csv(old$shoes, file.path(scr, "old_stamp_shoes.csv"),
                 row.names = FALSE)
cat("written:", file.path(cmp_dir, "stamp_threshold_old_vs_new.csv"), "\n")
