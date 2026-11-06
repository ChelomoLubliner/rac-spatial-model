#!/usr/bin/env bash
# OLD steps 1, 2 and 5 knitted by the Windows R 4.4.3 (the platform of the
# committed GLMM and figures, which has the car package) in a fresh scratch
# copy, and compared with the baselines (decisions A-065, A-082, A-084; T2
# review, reproducibility finding 1: the committed step-5 CSV must be the
# same with and without car).
#
# Usage: RAC_SCRATCH=<scratch dir> bash tests/legacy/run_windows_r_steps.sh
#            --steps LIST
#   LIST  steps among 1, 2 and 5, comma-separated (e.g. 1,2,5 or 5); they
#         run in the order 1, 2, 5
# Optional: RAC_WINR_COMMIT (default HEAD): the commit that is knitted (its
#           git archive; the work tree is not used);
#           RAC_WIN_RSCRIPT (default: the Windows R 4.4.3 Rscript.exe);
#           RAC_DISTANCE_IMPL: passed on to step 2 when set (WSL variables
#           reach the Windows R only through WSLENV).
# Before the first step the outputs of the steps that run are deleted from
# the copy and listed (tests/lib/run_outputs.sh, A-067). Each step is
# knitted by rac_win_knit (tests/lib/win_r.sh: chunk option error = FALSE,
# and no "## Error" line in the .md, A-084) with RAC_DATASET=old. Only
# outputs that the run regenerated are compared:
#   step 1  data/all_cont.csv, processed_data/dataCC.csv and
#           processed_data/shoe_pixel_counts.csv = Tier A (raw sha256);
#           processed_data/shoe_codes.csv = tests/baseline/old_added_t2.sha256
#   step 2  processed_data/dataCC_distance_temp.csv and dataCC_distance.csv
#           = Tier A
#   step 5  processed_data/wald_test.csv = old_added_t2.sha256 (A-082); the
#           car cross-check line of the knit (INFO); the four CI figures
#           without their dates (tests/lib/pdf_normalize.py) against the
#           committed PDFs of the same commit (INFO: equal or not; no rule
#           requires a figure to be equal)
# Step 5 reads the committed models (step 3 has its own Windows gate,
# tests/legacy/run_windows_r_step3.sh). Prints the run folder on the first
# line, then the comparison table. Writes into the run folder: repo/ (the
# copy), source.txt, step<N>_win.R and .md, logs/, timings.tsv,
# compare.tsv, outputs_expected.txt, outputs_regenerated.sha256,
# outputs_missing.txt, exit_status. Exit 0 only if every knit succeeds and
# writes its outputs and every compared file matches.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../lib/scratch.sh
source "$here/../lib/scratch.sh"
# shellcheck source=../lib/run_outputs.sh
source "$here/../lib/run_outputs.sh"
# shellcheck source=../lib/win_r.sh
source "$here/../lib/win_r.sh"
repo=$rac_repo_root
commit=${RAC_WINR_COMMIT:-HEAD}

steps=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --steps)
      if [[ $# -lt 2 ]]; then
        echo "run_windows_r_steps.sh: --steps needs a value" >&2
        exit 2
      fi
      steps=$2
      shift 2
      ;;
    *)
      echo "run_windows_r_steps.sh: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done
if [[ ! "$steps" =~ ^[125](,[125])*$ ]]; then
  echo "run_windows_r_steps.sh: --steps takes steps 1, 2 and 5, not" \
    "'$steps'" >&2
  exit 2
fi
if [[ ! -x "$rac_win_rscript" ]]; then
  echo "run_windows_r_steps.sh: Windows Rscript not found: $rac_win_rscript" >&2
  exit 2
fi
has() { [[ ",$steps," == *",$1,"* ]]; }

run=$(rac_scratch_new winr_steps)
echo "$run"
mkdir -p "$run/repo" "$run/logs"
git -C "$repo" archive --format=tar "$commit" | tar -x -C "$run/repo"
{
  echo "commit=$(git -C "$repo" rev-parse "$commit")"
  echo "steps=$steps"
  echo "rscript=$rac_win_rscript"
} > "$run/source.txt"

step_outputs() {
  case $1 in
    1) printf '%s\n' repo/data/all_cont.csv repo/processed_data/dataCC.csv \
      repo/processed_data/shoe_pixel_counts.csv \
      repo/processed_data/shoe_codes.csv ;;
    2) printf '%s\n' repo/processed_data/dataCC_distance_temp.csv \
      repo/processed_data/dataCC_distance.csv ;;
    5) printf '%s\n' repo/model_images/CI_shoe_cuts.pdf \
      repo/model_images/CI_cut_110.pdf repo/model_images/CI_cut_190.pdf \
      repo/model_images/CI_cut_250.pdf repo/processed_data/wald_test.csv ;;
  esac
}
rmd_of() {
  case $1 in
    1) echo dataCC_1.Rmd ;;
    2) echo dataCC_distance_2.Rmd ;;
    5) echo statistical_tests_5.Rmd ;;
  esac
}
outputs=()
for s in 1 2 5; do
  if has "$s"; then
    mapfile -t -O "${#outputs[@]}" outputs < <(step_outputs "$s")
  fi
done
rac_outputs_begin "$run" "${outputs[@]}"

vars=(RAC_DATASET=old RAC_MODEL_FEATURE=NEW_X_NS_XY)
if [[ -n "${RAC_DISTANCE_IMPL:-}" ]]; then
  vars+=("RAC_DISTANCE_IMPL=$RAC_DISTANCE_IMPL")
fi
printf 'step\tseconds\texit\n' > "$run/timings.tsv"
status=0
for s in 1 2 5; do
  if ! has "$s"; then continue; fi
  start=$(date +%s.%N)
  st=0
  rac_win_knit "$run" "step$s" "$run/repo/statistical_model" "$(rmd_of "$s")" \
    "${vars[@]}" || st=$?
  end=$(date +%s.%N)
  printf 'step%s_win\t%s\t%s\n' "$s" "$(echo "$end - $start" | bc)" "$st" \
    >> "$run/timings.tsv"
  if [[ $st -ne 0 ]]; then
    status=$st
    break
  fi
done
if ! rac_outputs_end "$run"; then
  if [[ $status -eq 0 ]]; then status=1; fi
fi
echo "$status" > "$run/exit_status"

# --- comparisons -----------------------------------------------------------
printf 'result\tcheck\tdetail\n' > "$run/compare.tsv"
fail=0
record() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$run/compare.tsv"
  if [[ $1 == FAIL ]]; then fail=1; fi
}
want_sha() { awk -v p="$2" '$2 == p {print $1}' "$1"; }
regenerated() {
  awk -v p="$1" 'substr($0, 67) == p {found = 1} END {exit !found}' \
    "$run/outputs_regenerated.sha256" 2> /dev/null
}
check_sha() {
  local name=$1 rel=$2 expect=$3 got
  if ! regenerated "repo/$rel"; then
    record FAIL "$name" "not regenerated by this run: $rel"
    return
  fi
  got=$(sha256sum "$run/repo/$rel" | cut -d' ' -f1)
  if [[ -n "$expect" && "$got" == "$expect" ]]; then
    record PASS "$name" "$rel sha256 ${got:0:12}..."
  else
    record FAIL "$name" "$rel sha256 ${got:0:12}..., expected ${expect:0:12}..."
  fi
}
if [[ $status -ne 0 ]]; then
  record FAIL "windows knits" "exit $status; see $run/logs/"
else
  record PASS "windows knits" "every knit exit 0, every output regenerated"
fi
tier_a=$repo/tests/baseline/committed_79247d8.sha256
added=$repo/tests/baseline/old_added_t2.sha256
if has 1; then
  for f in data/all_cont.csv processed_data/dataCC.csv \
    processed_data/shoe_pixel_counts.csv; do
    check_sha "step 1 $(basename "$f") = Tier A" "$f" "$(want_sha "$tier_a" "$f")"
  done
  check_sha "step 1 shoe_codes.csv = old_added_t2" processed_data/shoe_codes.csv \
    "$(want_sha "$added" processed_data/shoe_codes.csv)"
fi
if has 2; then
  for f in processed_data/dataCC_distance_temp.csv \
    processed_data/dataCC_distance.csv; do
    check_sha "step 2 $(basename "$f") = Tier A" "$f" "$(want_sha "$tier_a" "$f")"
  done
fi
if has 5; then
  check_sha "step 5 wald_test.csv = old_added_t2" processed_data/wald_test.csv \
    "$(want_sha "$added" processed_data/wald_test.csv)"
  car_line=$(grep -m1 -o 'car::linearHypothesis: [^#]*' "$run/step5_win.md" \
    2> /dev/null || true)
  record INFO "step 5 car cross-check" "${car_line:-no car line in the knit}"
  mkdir -p "$run/committed"
  for stem in CI_shoe_cuts CI_cut_110 CI_cut_190 CI_cut_250; do
    rel=model_images/$stem.pdf
    if ! regenerated "repo/$rel"; then
      record FAIL "$stem.pdf" "not regenerated by this run"
      continue
    fi
    git -C "$repo" cat-file blob "$commit:$rel" > "$run/committed/$stem.pdf"
    got=$(python3 "$repo/tests/lib/pdf_normalize.py" "$run/repo/$rel" |
      cut -d' ' -f1)
    want=$(python3 "$repo/tests/lib/pdf_normalize.py" \
      "$run/committed/$stem.pdf" | cut -d' ' -f1)
    if [[ "$got" == "$want" ]]; then
      record INFO "$stem.pdf" "equal to the committed PDF without dates (${got:0:12}...)"
    else
      record INFO "$stem.pdf" "differs from the committed PDF without dates (${got:0:12}... vs ${want:0:12}...)"
    fi
  done
fi

echo
echo "== run_windows_r_steps.sh --steps $steps: $run"
column -t -s $'\t' "$run/compare.tsv"
echo "timings (s):"
column -t -s $'\t' "$run/timings.tsv"
if [[ $fail -eq 0 ]]; then
  echo "ALL PASS"
else
  echo "SOME CHECKS FAILED"
fi
exit "$fail"
