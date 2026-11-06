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
# Since T2 the step reads the dataset profile: config/datasets.json is
# archived too (when the commit has it), and a config.R that takes the
# model from RAC_MODEL_FEATURE (rac_model_feature()) is accepted in place
# of the legacy literal MODEL_FEATURE <- "NEW_X_NS_XY"; the driver sets
# RAC_MODEL_FEATURE=NEW_X_NS_XY.
# The Windows R has no pandoc, so the Rmd runs through knitr::knit (code
# and output, no HTML). The copy is on the Linux file system; Windows R
# reaches it through \\wsl.localhost (wslpath -w). The copy has no model
# file, so the knit must write saved_models/NEW_X_NS_XY.rds; it is listed
# in outputs_expected.txt and must exist and be newer than that list after
# the knit (tests/lib/run_outputs.sh, decision A-067). The reference GLMM is
# the Tier A blob 79247d8:saved_models/NEW_X_NS_XY.rds, extracted into the
# run folder and checked against tests/baseline/committed_79247d8.sha256
# (exit 2 on a mismatch), never the work-tree file, which an OLD step run
# in place could overwrite (A-070). WSL variables reach a Windows process
# only through WSLENV, so the driver sets RAC_DATASET=old and
# RAC_MODEL_FEATURE=NEW_X_NS_XY itself (the gate is for the OLD GLMM; the
# legacy Rmd ignores both; T2 adds here any other RAC_* variable its
# step 3 reads).
# Prints the run folder on the first line. Outputs: repo/ (the copy),
# committed_glmm.rds (the reference), step3_win.R (the driver),
# step3_win.md (the knit), logs/step3_win.log, compare.txt (starts with
# the sha256 of both models), timing.txt, timings.tsv, outputs_expected.txt,
# outputs_regenerated.sha256, outputs_missing.txt, exit_status. Exit 0 only
# if the knit succeeds, writes the model, and every compared field equals
# the committed GLMM.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../lib/scratch.sh
source "$here/../lib/scratch.sh"
# shellcheck source=../lib/run_outputs.sh
source "$here/../lib/run_outputs.sh"
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

# The reference: the Tier A blob, checked against the committed hash list.
ref_path=saved_models/NEW_X_NS_XY.rds
git -C "$repo" cat-file blob "79247d8:$ref_path" > "$run/committed_glmm.rds"
ref_want=$(awk -v p="$ref_path" '$2 == p {print $1}' \
  "$repo/tests/baseline/committed_79247d8.sha256")
ref_sha=$(sha256sum < "$run/committed_glmm.rds" | cut -d' ' -f1)
if [[ -z "$ref_want" || "$ref_sha" != "$ref_want" ]]; then
  echo "run_windows_r_step3.sh: reference GLMM sha256 $ref_sha is not the" \
    "Tier A value '$ref_want'" >&2
  exit 2
fi

paths=(statistical_model processed_data/dataCC_distance.csv
  processed_data/shoe_pixel_counts.csv data/all_cont.csv)
if git -C "$repo" cat-file -e "$commit:config/datasets.json" 2> /dev/null; then
  paths+=(config/datasets.json)
fi
git -C "$repo" archive --format=tar "$commit" "${paths[@]}" |
  tar -x -C "$run/repo"
echo "commit=$(git -C "$repo" rev-parse "$commit")" > "$run/legacy_source.txt"
if ! grep -qE '^MODEL_FEATURE <- ("NEW_X_NS_XY"|rac_model_feature\(\))' \
  "$run/repo/statistical_model/config.R"; then
  echo "run_windows_r_step3.sh: config.R selects neither NEW_X_NS_XY nor" \
    "the RAC_MODEL_FEATURE model" >&2
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
Sys.setenv(RGL_USE_NULL = "TRUE", RAC_DATASET = "old",
           RAC_MODEL_FEATURE = "NEW_X_NS_XY")
Sys.unsetenv("RAC_PROFILE_FILE")
options(rgl.useNULL = TRUE)
setwd("$wd")
t0 <- proc.time()[["elapsed"]]
knitr::knit("re_model_shoe_std_3.Rmd", output = "../../step3_win.md", quiet = TRUE)
cat(sprintf("knit seconds %.1f\n", proc.time()[["elapsed"]] - t0))
cat(R.version.string, "| lme4", as.character(packageVersion("lme4")),
    "| Matrix", as.character(packageVersion("Matrix")), "\n")
EOF

fit="$run/repo/$ref_path"
rac_outputs_begin "$run" "repo/$ref_path"
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
printf 'step\tseconds\texit\nstep3_glmm_win\t%s\t%s\n' \
  "$(echo "$end - $start" | bc)" "$status" > "$run/timings.tsv"

written=0
rac_outputs_end "$run" || written=1
if [[ $status -eq 0 && $written -eq 0 ]]; then
  {
    echo "reference 79247d8:$ref_path sha256 $ref_sha (Tier A)"
    echo "fit       repo/$ref_path sha256 $(sha256sum < "$fit" | cut -d' ' -f1)"
    Rscript "$repo/tests/lib/compare_glmm_fits.R" "$run/committed_glmm.rds" \
      "$fit" 2>&1
  } > "$run/compare.txt" || status=$?
else
  echo "no model written by this knit (knit exit $status)" > "$run/compare.txt"
  if [[ $status -eq 0 ]]; then status=1; fi
fi
echo "$status" > "$run/exit_status"
exit "$status"
