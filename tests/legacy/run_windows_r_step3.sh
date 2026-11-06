#!/usr/bin/env bash
# Fit the step-3 GLMM (re_model_shoe_std_3.Rmd, MODEL_FEATURE NEW_X_NS_XY)
# with the Windows R 4.4.3 + lme4 1.1-37 + Matrix 1.7-2 that produced the
# committed model, in a fresh scratch copy, and compare the new fit with
# the committed GLMM (Tier A) field by field (decision A-065; T1
# reproducibility review, finding 2). On WSL (R 4.3.3, lme4 1.1-38) the
# refit differs (A-055), so this is the Tier A gate for step 3.
#
# Usage: RAC_SCRATCH=<scratch dir> bash tests/legacy/run_windows_r_step3.sh
# Optional: RAC_WINR_COMMIT (default 79247d8): the commit whose
#           statistical_model/, step-2 CSV, data/all_cont.csv and
#           processed_data/shoe_pixel_counts.csv are knitted (T2 passes its
#           own commit to gate the refactored Rmd and adds the paths the
#           profile needs to the archive list below);
#           RAC_WIN_RSCRIPT (default: the Windows R 4.4.3 Rscript.exe).
# The Windows R has no pandoc, so the Rmd runs through knitr::knit (code
# and output, no HTML). The copy is on the Linux file system; Windows R
# reaches it through \\wsl.localhost (wslpath -w). The copy has no model
# file, so the knit must write saved_models/NEW_X_NS_XY.rds. The committed
# GLMM is read from this repository's saved_models/ (Tier A, 79247d8).
# Prints the run folder on the first line. Outputs: repo/ (the copy),
# step3_win.R (the driver), step3_win.md (the knit), logs/step3_win.log,
# compare.txt, timing.txt, exit_status. Exit 0 only if the knit succeeds
# and every compared field equals the committed GLMM.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../lib/scratch.sh
source "$here/../lib/scratch.sh"
repo=$rac_repo_root
commit=${RAC_WINR_COMMIT:-79247d8}
win_r=${RAC_WIN_RSCRIPT:-/mnt/c/Users/mehes/AppData/Local/Programs/R/R-4.4.3/bin/Rscript.exe}
if [[ ! -x "$win_r" ]]; then
  echo "run_windows_r_step3.sh: Windows Rscript not found: $win_r" >&2
  exit 2
fi

run=$(rac_scratch_new winr_step3)
echo "$run"
mkdir -p "$run/repo/saved_models" "$run/logs"

git -C "$repo" archive --format=tar "$commit" statistical_model \
  processed_data/dataCC_distance.csv processed_data/shoe_pixel_counts.csv \
  data/all_cont.csv | tar -x -C "$run/repo"
echo "commit=$(git -C "$repo" rev-parse "$commit")" > "$run/legacy_source.txt"
if ! grep -q '^MODEL_FEATURE <- "NEW_X_NS_XY"' \
  "$run/repo/statistical_model/config.R"; then
  echo "run_windows_r_step3.sh: config.R does not select NEW_X_NS_XY" >&2
  exit 2
fi

# R on Windows takes forward slashes in UNC paths.
win_path() {
  local p
  p=$(wslpath -w "$1")
  printf '%s' "${p//\\//}"
}
wd=$(win_path "$run/repo/statistical_model")
cat > "$run/step3_win.R" <<EOF
Sys.setenv(RGL_USE_NULL = "TRUE")
options(rgl.useNULL = TRUE)
setwd("$wd")
t0 <- proc.time()[["elapsed"]]
knitr::knit("re_model_shoe_std_3.Rmd", output = "../../step3_win.md", quiet = TRUE)
cat(sprintf("knit seconds %.1f\n", proc.time()[["elapsed"]] - t0))
cat(R.version.string, "| lme4", as.character(packageVersion("lme4")),
    "| Matrix", as.character(packageVersion("Matrix")), "\n")
EOF

start=$(date +%s.%N)
echo "start $(date --iso-8601=seconds)" > "$run/timing.txt"
status=0
# cd /mnt/c: Windows cannot start a process in a \\wsl.localhost folder.
(cd /mnt/c && "$win_r" "$(win_path "$run/step3_win.R")") 2>&1 |
  tr -d '\r' > "$run/logs/step3_win.log" || status=$?
end=$(date +%s.%N)
{
  echo "end $(date --iso-8601=seconds)"
  echo "exit $status"
  echo "seconds $(echo "$end - $start" | bc)"
} >> "$run/timing.txt"

fit="$run/repo/saved_models/NEW_X_NS_XY.rds"
if [[ $status -eq 0 && -f "$fit" ]]; then
  Rscript "$repo/tests/lib/compare_glmm_fits.R" \
    "$repo/saved_models/NEW_X_NS_XY.rds" "$fit" > "$run/compare.txt" 2>&1 ||
    status=$?
else
  echo "no model written (knit exit $status)" > "$run/compare.txt"
  if [[ $status -eq 0 ]]; then status=1; fi
fi
echo "$status" > "$run/exit_status"
exit "$status"
