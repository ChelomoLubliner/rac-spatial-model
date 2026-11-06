#!/usr/bin/env bash
# Run steps of the pipeline for one dataset (plan section 4.4).
#
# Usage: RAC_DATASET=old|new tools/run_pipeline.sh --steps LIST
#            [--py PYTHON] [--timings FILE]
#   LIST     steps 0-6, e.g. "0-6", "1,2", "3-5", "4": 0 = the Python snake
#            contour (contour_algorithm), 1-6 = the Rmds of
#            statistical_model/; steps 3 and 4 run once per model
#            (NEW_X_NS_XY, then CML_MODEL, through RAC_MODEL_FEATURE)
#   PYTHON   the Python for step 0 (default RAC_VENV_PY, else the thesis
#            venv; nothing is installed)
#   FILE     append one row per step (step, seconds, exit) to this TSV
#            (the timings.tsv of tests/regress_old.sh)
# The dataset comes from RAC_DATASET (unset or empty: old), every value and
# path from its profile (config/datasets.json). Each Rmd is rendered with
# rmarkdown::render(knit_root_dir = statistical_model/, output_dir = the
# profile's r.knit_dir, output_file = <stem>[_GLMM|_CML]<suffix>.html,
# intermediates_dir = a folder below r.log_dir, envir = new.env()); each
# step logs to <r.log_dir>/<step><suffix>.log (logs/ is gitignored);
# RGL_USE_NULL=TRUE keeps rgl headless. Stops at the first failing step
# (exit 1). Refuses, with exit 2 and before writing anything, a set
# RAC_PROFILE_FILE (a test hook, A-049), an unknown dataset and a bad LIST.
# An OLD run in this tree is refused by the code itself where it would
# overwrite the committed contour, a model or a figure (A-075): OLD runs
# belong in tests/regress_old.sh, which runs this script in a scratch copy.
# Never run an OLD and a NEW run at the same time in one tree.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ -n "${RAC_PROFILE_FILE:-}" ]]; then
  echo "run_pipeline.sh: RAC_PROFILE_FILE is set; it is a test hook and a" \
    "real run refuses it (decision A-049)" >&2
  exit 2
fi
steps=""
py=${RAC_VENV_PY:-/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python}
timings=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --steps | --py | --timings)
      if [[ $# -lt 2 ]]; then
        echo "run_pipeline.sh: $1 needs a value" >&2
        exit 2
      fi
      case $1 in
        --steps) steps=$2 ;;
        --py) py=$2 ;;
        --timings) timings=$2 ;;
      esac
      shift 2
      ;;
    *)
      echo "run_pipeline.sh: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done
if [[ ! "$steps" =~ ^[0-6](-[0-6])?(,[0-6](-[0-6])?)*$ ]]; then
  echo "run_pipeline.sh: --steps takes steps 0-6 such as 0-6, 1,2 or 3-5," \
    "not '$steps'" >&2
  exit 2
fi
declare -A want=()
IFS=, read -r -a parts <<< "$steps"
for part in "${parts[@]}"; do
  first=${part%-*}
  last=${part#*-}
  if ((first > last)); then
    echo "run_pipeline.sh: bad step range '$part'" >&2
    exit 2
  fi
  for ((s = first; s <= last; s++)); do want[$s]=1; done
done

# The profile values this runner needs (the system python3 is enough:
# contour_algorithm.profiles uses the standard library only).
if ! info=$(cd "$repo" && python3 -B -c '
import sys
from contour_algorithm.profiles import load_profile
try:
    p = load_profile()
except ValueError as e:
    sys.exit(str(e))
for v in (p.dataset, p.suffix, p.r["knit_dir"], p.r["log_dir"]):
    print(v)' 2>&1); then
  echo "run_pipeline.sh: $info" >&2
  exit 2
fi
mapfile -t fields <<< "$info"
dataset=${fields[0]}
suffix=${fields[1]}
knit_dir=$repo/${fields[2]}
log_dir=$repo/${fields[3]}
mkdir -p "$log_dir" "$knit_dir"
echo "run_pipeline.sh: dataset $dataset, steps $steps, logs ${fields[3]}"

run_step() {
  local tag=$1 start end secs status=0
  shift
  start=$(date +%s.%N)
  "$@" > "$log_dir/$tag$suffix.log" 2>&1 || status=$?
  end=$(date +%s.%N)
  secs=$(echo "$end - $start" | bc)
  if [[ -n "$timings" ]]; then
    printf '%s\t%s\t%s\n' "$tag" "$secs" "$status" >> "$timings"
  fi
  echo "$tag: exit $status, $secs s"
  if [[ $status -ne 0 ]]; then
    echo "run_pipeline.sh: step $tag failed; see $log_dir/$tag$suffix.log" >&2
    exit 1
  fi
}

step0() {
  cd "$repo" && MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 \
    RAC_DATASET=$dataset "$py" -B -m contour_algorithm.main
}

# render RMD OUT_STEM MODEL_FEATURE
render() {
  local tmp=$log_dir/knit_tmp/$2$suffix
  mkdir -p "$tmp"
  RAC_DATASET=$dataset RAC_MODEL_FEATURE=$3 RGL_USE_NULL=TRUE Rscript -e '
    a <- commandArgs(trailingOnly = TRUE)
    rmarkdown::render(a[1], knit_root_dir = a[2], output_file = a[3],
                      output_dir = a[4], intermediates_dir = a[5],
                      envir = new.env())' \
    "$repo/statistical_model/$1" "$repo/statistical_model" \
    "$2$suffix.html" "$knit_dir" "$tmp"
}

if [[ -n "${want[0]:-}" ]]; then run_step step0 step0; fi
if [[ -n "${want[1]:-}" ]]; then
  run_step step1 render dataCC_1.Rmd dataCC_1 NEW_X_NS_XY
fi
if [[ -n "${want[2]:-}" ]]; then
  run_step step2 render dataCC_distance_2.Rmd dataCC_distance_2 NEW_X_NS_XY
fi
if [[ -n "${want[3]:-}" ]]; then
  run_step step3_glmm render re_model_shoe_std_3.Rmd \
    re_model_shoe_std_3_GLMM NEW_X_NS_XY
  run_step step3_cml render re_model_shoe_std_3.Rmd \
    re_model_shoe_std_3_CML CML_MODEL
fi
if [[ -n "${want[4]:-}" ]]; then
  run_step step4_glmm render shoe_std_results_4.Rmd \
    shoe_std_results_4_GLMM NEW_X_NS_XY
  run_step step4_cml render shoe_std_results_4.Rmd \
    shoe_std_results_4_CML CML_MODEL
fi
if [[ -n "${want[5]:-}" ]]; then
  run_step step5 render statistical_tests_5.Rmd statistical_tests_5 \
    NEW_X_NS_XY
fi
if [[ -n "${want[6]:-}" ]]; then
  run_step step6 render model_comparison_6.Rmd model_comparison_6 \
    NEW_X_NS_XY
fi
echo "run_pipeline.sh: done ($dataset, steps $steps)"
