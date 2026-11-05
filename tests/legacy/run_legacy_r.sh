#!/usr/bin/env bash
# Run the UNMODIFIED R steps (statistical_model/*.Rmd as committed at
# 79247d8) on the OLD dataset in a fresh scratch copy of the committed tree
# (plan T1 step 4, decision A-004). Nothing in this repository is written.
#
# Usage: RAC_SCRATCH=<scratch dir> bash tests/legacy/run_legacy_r.sh [STEPS]
#   STEPS  comma-separated subset of 1,2,3,4,5,6 (default: all). Steps that
#          are not run keep the committed files of the copy, so "3,4,5,6"
#          refits the models from the committed step-2 output.
# Steps 3 and 4 run twice: MODEL_FEATURE = NEW_X_NS_XY, then CML_MODEL,
# switched by sed in the scratch config.R only. Step 5 runs the variant made
# by step5_without_car.R (car is not installed here). RGL_USE_NULL=TRUE
# keeps rgl headless. Prints the run folder on the first line.
# Outputs: repo/ (the copy, with the regenerated files), logs/<step>.log,
# timings.tsv (step, seconds, exit), sessionInfo.txt, exit_status.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../lib/scratch.sh
source "$here/../lib/scratch.sh"
repo=$rac_repo_root
commit=${RAC_LEGACY_R_COMMIT:-79247d8}
steps=${1:-1,2,3,4,5,6}
if [[ ! "$steps" =~ ^[1-6](,[1-6])*$ ]]; then
  echo "run_legacy_r.sh: bad STEPS '$steps'" >&2
  exit 2
fi

run=$(rac_scratch_new legacy_r)
echo "$run"
mkdir -p "$run/repo" "$run/logs" "$run/knit_tmp"

# The committed tree at $commit (blob bytes, no EOL conversion).
git -C "$repo" archive --format=tar "$commit" data processed_data \
  saved_models model_images statistical_model | tar -x -C "$run/repo"
# The manual Wald helper (new in T1) is needed by the step-5 variant.
mkdir -p "$run/repo/statistical_model/R"
cp -p "$repo/statistical_model/R/wald.R" "$run/repo/statistical_model/R/"
echo "commit=$(git -C "$repo" rev-parse "$commit") steps=$steps" \
  > "$run/legacy_source.txt"

sm="$run/repo/statistical_model"
Rscript "$here/step5_without_car.R" "$sm/statistical_tests_5.Rmd" \
  "$sm/statistical_tests_5.nocar.Rmd" > "$run/logs/step5_variant.log"
diff --strip-trailing-cr "$sm/statistical_tests_5.Rmd" \
  "$sm/statistical_tests_5.nocar.Rmd" \
  > "$run/step5_variant.diff" || true
mv "$sm/statistical_tests_5.nocar.Rmd" "$sm/statistical_tests_5.Rmd"

set_feature() {
  sed -i -E "s/^MODEL_FEATURE <- \"[A-Z_]+\"/MODEL_FEATURE <- \"$1\"/" \
    "$sm/config.R"
  grep -q "^MODEL_FEATURE <- \"$1\"" "$sm/config.R"
}

printf 'step\tseconds\texit\n' > "$run/timings.tsv"
overall=0
render() {
  local tag=$1 rmd=$2 out=$3 start end status=0
  mkdir -p "$run/knit_tmp/$tag"
  start=$(date +%s.%N)
  (
    cd "$sm"
    RGL_USE_NULL=TRUE Rscript -e "rmarkdown::render('$rmd',
      output_file = '$out', intermediates_dir = '$run/knit_tmp/$tag',
      envir = new.env())"
  ) > "$run/logs/$tag.log" 2>&1 || status=$?
  end=$(date +%s.%N)
  printf '%s\t%s\t%s\n' "$tag" "$(echo "$end - $start" | bc)" "$status" \
    >> "$run/timings.tsv"
  if [[ $status -ne 0 ]]; then overall=1; fi
}

has() { [[ ",$steps," == *",$1,"* ]]; }

if has 1; then render step1 dataCC_1.Rmd dataCC_1.html; fi
if has 2; then render step2 dataCC_distance_2.Rmd dataCC_distance_2.html; fi
if has 3; then
  set_feature NEW_X_NS_XY
  render step3_glmm re_model_shoe_std_3.Rmd re_model_shoe_std_3_GLMM.html
  set_feature CML_MODEL
  render step3_cml re_model_shoe_std_3.Rmd re_model_shoe_std_3_CML.html
  set_feature NEW_X_NS_XY
fi
if has 4; then
  set_feature NEW_X_NS_XY
  render step4_glmm shoe_std_results_4.Rmd shoe_std_results_4_GLMM.html
  set_feature CML_MODEL
  render step4_cml shoe_std_results_4.Rmd shoe_std_results_4_CML.html
  set_feature NEW_X_NS_XY
fi
if has 5; then
  render step5 statistical_tests_5.Rmd statistical_tests_5.html
fi
if has 6; then render step6 model_comparison_6.Rmd model_comparison_6.html; fi

Rscript -e 'suppressMessages({library(lme4); library(survival)});
  print(sessionInfo())' > "$run/sessionInfo.txt" 2>&1 || true
echo "$overall" > "$run/exit_status"
exit "$overall"
