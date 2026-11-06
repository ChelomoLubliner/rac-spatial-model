#!/usr/bin/env bash
# The OLD regression gate (plan section 4.5; decisions A-004, A-067).
#
# Usage: RAC_SCRATCH=<scratch dir> bash tests/regress_old.sh --steps LIST
#            [--keep] [--py PYTHON]
#   LIST    steps 0-6 as for tools/run_pipeline.sh ("0-6", "1,2", "5", ...)
#   PYTHON  the Python for step 0 and the Python live check (default
#           RAC_VENV_PY, else the thesis venv)
# Copies the work tree into a fresh run folder RAC_SCRATCH/regress_old_XXXXXX
# (repo/: rsync without .git, images*/, logs/, .claude), deletes there every
# output of the steps that run and lists them (tests/lib/run_outputs.sh),
# runs tools/run_pipeline.sh with RAC_DATASET=old in the copy, and compares
# only what the run regenerated (every compared file must be on its
# outputs_regenerated.sha256, A-067):
#   step 0     the contour file = Tier B written with CRLF (this is WSL;
#              Tier A, the Windows result, is checked under venv-wind, A-060)
#              and all 1,556 intermediate .npy/.png files = Tier B
#   steps 1-2  the five CSVs = Tier A by raw sha256 (the OLD profile writes
#              the committed line endings, A-005); step 1 also writes
#              processed_data/shoe_codes.csv, compared with its sha256 in
#              tests/baseline/old_added_t2.sha256 (the OLD files T2 added;
#              never with the work-tree file, which an in-place run could
#              have replaced, A-070, A-082)
#   step 3     the dump of both models identical() to Tier B in every field
#              (tests/lib/dump_models.R, compare_models.R; the WSL GLMM refit
#              differs from Tier A, A-055; tests/legacy/run_windows_r_step3.sh
#              is the Tier A gate of step 3)
#   steps 4-6  the 8 PDFs without their dates = Tier B, when step 3 ran in
#              the same run (Tier B drew them from the WSL refit); with the
#              committed models (step 3 not run) they have no byte baseline
#              on this machine and are reported as INFO
#   step 5     processed_data/wald_test.csv: its sha256 in
#              tests/baseline/old_added_t2.sha256 when step 5 reads the
#              committed models (step 3 not run); W = Tier B's W (a WSL
#              refit, 427.7804) when step 3 ran
# and runs the live checks that the steps cover (test_snake_old_regression
# for step 0, test_old_regression.R for steps 1-3, test_live_r_pdfs for steps
# 3-6).
# Step 0 and steps 2-6 are never compared in one run: step 2 reads the
# contour, which step 0 rewrites on WSL as Tier B (30 records differ from
# the committed Windows contour, A-060), while the step-2 to step-6
# baselines were computed from the committed contour. Such a request (e.g.
# --steps 0-6) runs as two runs, --steps 0 and --steps <the others>, each
# in its own run folder with the committed inputs (A-081); exit 0 only if
# both pass. Writes timings.tsv, compare.tsv, logs/, exit_status into the run
# folder and prints a summary; exit 0 only if every step and comparison
# passes. The run folder is deleted after a pass unless --keep, and kept
# after a failure. Nothing in the repository is written. Refuses
# RAC_PROFILE_FILE (A-049).

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/scratch.sh
source "$here/lib/scratch.sh"
# shellcheck source=lib/run_outputs.sh
source "$here/lib/run_outputs.sh"
repo=$rac_repo_root

if [[ -n "${RAC_PROFILE_FILE:-}" ]]; then
  echo "regress_old.sh: RAC_PROFILE_FILE is set; it is a test hook and a" \
    "real run refuses it (decision A-049)" >&2
  exit 2
fi
steps=""
keep=0
py=${RAC_VENV_PY:-/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python}
while [[ $# -gt 0 ]]; do
  case $1 in
    --steps | --py)
      if [[ $# -lt 2 ]]; then
        echo "regress_old.sh: $1 needs a value" >&2
        exit 2
      fi
      if [[ $1 == --steps ]]; then steps=$2; else py=$2; fi
      shift 2
      ;;
    --keep)
      keep=1
      shift
      ;;
    *)
      echo "regress_old.sh: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done
if [[ ! "$steps" =~ ^[0-6](-[0-6])?(,[0-6](-[0-6])?)*$ ]]; then
  echo "regress_old.sh: --steps takes steps 0-6, not '$steps'" >&2
  exit 2
fi
declare -A want=()
IFS=, read -r -a parts <<< "$steps"
for part in "${parts[@]}"; do
  for ((s = ${part%-*}; s <= ${part#*-}; s++)); do want[$s]=1; done
done
has() { [[ -n "${want[$1]:-}" ]]; }

if has 0 && { has 2 || has 3 || has 4 || has 5 || has 6; }; then
  rest=""
  for s in 1 2 3 4 5 6; do
    if has "$s"; then rest+="${rest:+,}$s"; fi
  done
  echo "regress_old.sh: step 0 rewrites the contour that steps 2-6 read;" \
    "on WSL it is Tier B, and their baselines come from the committed" \
    "contour, so this runs as two runs: --steps 0 and --steps $rest (A-081)"
  args=()
  if [[ $keep -eq 1 ]]; then args+=(--keep); fi
  split=0
  bash "$here/regress_old.sh" --steps 0 --py "$py" "${args[@]}" || split=1
  bash "$here/regress_old.sh" --steps "$rest" --py "$py" "${args[@]}" ||
    split=1
  echo "== regress_old.sh --steps $steps (as --steps 0 and --steps $rest):" \
    "$([[ $split -eq 0 ]] && echo "ALL PASS" || echo "SOME CHECKS FAILED")"
  exit "$split"
fi

run=$(rac_scratch_new regress_old)
echo "$run"
mkdir -p "$run/repo" "$run/logs" "$run/models"
rsync -a --exclude /.git --exclude '/images*/' --exclude /logs/ \
  --exclude /.claude "$repo/" "$run/repo/"
echo regress_old > "$run/runner.txt"
{
  echo "steps=$steps"
  echo "head=$(git -C "$repo" rev-parse HEAD)"
  echo "python=$py"
  echo "work tree changes (git status --short):"
  git -C "$repo" status --short
} > "$run/source.txt"

# What each step writes (paths relative to the run folder).
step_outputs() {
  case $1 in
    0)
      echo repo/data/contour_Active_Contour.txt
      for f in list_matrices.npy old_freq_min_18.npy freq_min_18.npy \
        list_contour.npy active-contour_all.npy all_shoes_superposed.png \
        old_freq_min_18.png freq_min_18.png; do
        echo "repo/images/saved/$f"
      done
      ;;
    1) printf '%s\n' repo/data/all_cont.csv repo/processed_data/dataCC.csv \
      repo/processed_data/shoe_pixel_counts.csv \
      repo/processed_data/shoe_codes.csv ;;
    2) printf '%s\n' repo/processed_data/dataCC_distance_temp.csv \
      repo/processed_data/dataCC_distance.csv ;;
    3) printf '%s\n' repo/saved_models/NEW_X_NS_XY.rds \
      repo/saved_models/CML_MODEL.rds ;;
    4) printf '%s\n' repo/model_images/NEW_X_NS_XY_SHOE.pdf \
      repo/model_images/CML_MODEL_SHOE.pdf ;;
    5) printf '%s\n' repo/model_images/CI_shoe_cuts.pdf \
      repo/model_images/CI_cut_110.pdf repo/model_images/CI_cut_190.pdf \
      repo/model_images/CI_cut_250.pdf repo/processed_data/wald_test.csv ;;
    6) printf '%s\n' repo/model_images/pixel_inten_JASAup.pdf \
      repo/model_images/difference_random_cml.pdf ;;
  esac
}
outputs=()
for s in 0 1 2 3 4 5 6; do
  if has "$s"; then
    mapfile -t -O "${#outputs[@]}" outputs < <(step_outputs "$s")
  fi
done
rac_outputs_begin "$run" "${outputs[@]}"

printf 'step\tseconds\texit\n' > "$run/timings.tsv"
status=0
(
  cd "$run/repo" && env -u RAC_PROFILE_FILE RAC_DATASET=old \
    bash tools/run_pipeline.sh --steps "$steps" --py "$py" \
    --timings "$run/timings.tsv"
) > "$run/logs/pipeline.log" 2>&1 || status=$?
if ! rac_outputs_end "$run"; then
  if [[ $status -eq 0 ]]; then status=1; fi
fi
echo "$status" > "$run/exit_status"
cp -p "$run/repo/logs/old/"*.log "$run/logs/" 2> /dev/null || true

# --- comparisons -----------------------------------------------------------
printf 'result\tcheck\tdetail\n' > "$run/compare.tsv"
fail=0
record() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$run/compare.tsv"
  if [[ $1 == FAIL ]]; then fail=1; fi
}
sha() { sha256sum "$1" | cut -d' ' -f1; }
want_sha() { awk -v p="$2" '$2 == p {print $1}' "$1"; }
# Is the path (relative to the run folder) on the regenerated list, exactly?
regenerated() {
  awk -v p="$1" 'substr($0, 67) == p {found = 1} END {exit !found}' \
    "$run/outputs_regenerated.sha256" 2> /dev/null
}

if [[ $status -ne 0 ]]; then
  record FAIL "pipeline run" "exit $status; see $run/logs/pipeline.log"
else
  record PASS "pipeline run" "every step exit 0, every output regenerated"
fi

# Compare one regenerated file with an expected sha256.
check_sha() {
  local name=$1 rel=$2 expect=$3 got
  if ! regenerated "repo/$rel"; then
    record FAIL "$name" "not regenerated by this run: $rel"
    return
  fi
  got=$(sha "$run/repo/$rel")
  if [[ -n "$expect" && "$got" == "$expect" ]]; then
    record PASS "$name" "$rel sha256 ${got:0:12}..."
  else
    record FAIL "$name" "$rel sha256 ${got:0:12}..., expected ${expect:0:12}..."
  fi
}

if has 0; then
  check_sha "step 0 contour = Tier B (CRLF)" data/contour_Active_Contour.txt \
    "$(awk '/\[LF->CRLF\]/ {print $1}' \
      "$repo/tests/baseline/local/python_contour.sha256")"
  n=$(find "$run/repo/images" -type f \( -name '*.npy' -o -name '*.png' \) \
    -newer "$run/outputs_expected.txt" | wc -l)
  if (cd "$run/repo" && sha256sum --quiet -c \
    "$repo/tests/baseline/local/python_intermediates.sha256") \
    > "$run/logs/intermediates_check.txt" 2>&1 && [[ $n -eq 1556 ]]; then
    record PASS "step 0 intermediates = Tier B" "$n npy/png files, all equal"
  else
    record FAIL "step 0 intermediates = Tier B" \
      "$n npy/png files newer than the start; see logs/intermediates_check.txt"
  fi
fi
tier_a=$repo/tests/baseline/committed_79247d8.sha256
# The OLD files that T2 added (not in Tier A): their sha256 list, written
# once like the Tier A list (A-082)
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
if has 3; then
  if regenerated repo/saved_models/NEW_X_NS_XY.rds &&
    regenerated repo/saved_models/CML_MODEL.rds &&
    Rscript "$repo/tests/lib/dump_models.R" \
      "$run/repo/saved_models/NEW_X_NS_XY.rds" \
      "$run/repo/saved_models/CML_MODEL.rds" "$run/models/dump.rds" \
      "$run/models/dump" > "$run/logs/dump_models.txt" 2>&1 &&
    Rscript "$repo/tests/lib/compare_models.R" \
      "$repo/tests/baseline/local/models_local.rds" "$run/models/dump.rds" \
      > "$run/logs/compare_models.txt" 2>&1; then
    record PASS "step 3 models identical() to Tier B" \
      "every field of the dump (logs/compare_models.txt)"
  else
    record FAIL "step 3 models identical() to Tier B" \
      "see logs/dump_models.txt, logs/compare_models.txt"
  fi
fi
pdfs=()
if has 4; then pdfs+=(NEW_X_NS_XY_SHOE CML_MODEL_SHOE); fi
if has 5; then pdfs+=(CI_shoe_cuts CI_cut_110 CI_cut_190 CI_cut_250); fi
if has 6; then pdfs+=(pixel_inten_JASAup difference_random_cml); fi
no_pdf_baseline="drawn from the committed models; the Tier B PDFs come"
no_pdf_baseline+=" from the WSL refit (run step 3 too to compare them)"
for stem in "${pdfs[@]}"; do
  rel=model_images/$stem.pdf
  expect=$(want_sha "$repo/tests/baseline/local/pdf_normalized.sha256" "$rel")
  if ! has 3; then
    if regenerated "repo/$rel"; then
      record INFO "$stem.pdf" "$no_pdf_baseline"
    else
      record FAIL "$stem.pdf" "not regenerated by this run"
    fi
  elif regenerated "repo/$rel"; then
    got=$(python3 "$repo/tests/lib/pdf_normalize.py" "$run/repo/$rel" |
      cut -d' ' -f1)
    if [[ "$got" == "$expect" ]]; then
      record PASS "$stem.pdf normalized = Tier B" "${got:0:12}..."
    else
      record FAIL "$stem.pdf normalized = Tier B" \
        "${got:0:12}..., expected ${expect:0:12}..."
    fi
  else
    record FAIL "$stem.pdf normalized = Tier B" "not regenerated by this run"
  fi
done
if has 5; then
  wald=processed_data/wald_test.csv
  if has 3; then
    # shellcheck disable=SC2016  # R code: $ is R's list operator
    if regenerated "repo/$wald" && Rscript -e '
      a <- commandArgs(trailingOnly = TRUE)
      w <- read.csv(a[1])
      tb <- readRDS(a[2])$wald_glmm
      cat(sprintf("W %.10f, Tier B %.10f, df %d\n", w$W, tb, w$df))
      stopifnot(nrow(w) == 1, w$df == 24,
                isTRUE(all.equal(w$W, tb, tolerance = 1e-12)))' \
      "$run/repo/$wald" "$repo/tests/baseline/local/models_local.rds" \
      > "$run/logs/wald_check.txt" 2>&1; then
      record PASS "step 5 Wald W = Tier B (WSL refit)" \
        "$(head -1 "$run/logs/wald_check.txt")"
    else
      record FAIL "step 5 Wald W = Tier B (WSL refit)" \
        "see logs/wald_check.txt"
    fi
  else
    check_sha "step 5 wald_test.csv = old_added_t2 (committed models)" \
      "$wald" "$(want_sha "$added" "$wald")"
  fi
fi

# --- live checks of the tests (they check the run manifest first, A-067) ---
live() {
  local name=$1 log=$2
  shift 2
  if "$@" > "$run/logs/$log" 2>&1; then
    record PASS "live check $name" "logs/$log"
  else
    record FAIL "live check $name" "logs/$log"
  fi
}
if [[ $status -eq 0 ]]; then
  if has 0; then
    live test_snake_old_regression live_snake.txt env -C "$repo" \
      RAC_REGRESS_PY_RUN="$run" MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 \
      "$py" -B -m unittest tests.python.test_snake_old_regression
  fi
  if has 1 && has 2 && has 3; then
    live test_old_regression.R live_r.txt env RAC_REGRESS_R_RUN="$run" \
      Rscript "$repo/tests/r/test_old_regression.R"
  fi
  if has 3 && has 4 && has 5 && has 6; then
    live test_live_r_pdfs live_pdfs.txt env -C "$repo" \
      RAC_REGRESS_R_RUN="$run" PYTHONDONTWRITEBYTECODE=1 \
      python3 -B -m unittest tests.python.test_live_r_pdfs
  fi
fi

echo
echo "== regress_old.sh --steps $steps: $run"
column -t -s $'\t' "$run/compare.tsv"
echo "timings (s):"
column -t -s $'\t' "$run/timings.tsv"
if [[ $fail -eq 0 ]]; then
  echo "ALL PASS"
  if [[ $keep -eq 0 ]]; then rac_scratch_remove "$run"; fi
else
  echo "SOME CHECKS FAILED (run folder kept)"
fi
exit "$fail"
