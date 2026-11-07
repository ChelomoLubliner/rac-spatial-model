#!/usr/bin/env bash
# run_compare_fits.sh: every model fit of the OLD-vs-NEW comparison (plan T6;
# statistical_model/compare_old_new_7.Rmd reads them), in dependency order.
#
# Usage (repo root):
#   bash tools/run_compare_fits.sh [--jobs N] [--slow] [--force] [--dry-run]
#                                  [JOB ...]
#     --jobs N  run up to N fits of one stage at a time (default 2; each needs
#               0.4-1.5 GB, the exact CMLs on the finer y basis about 3.5 GB)
#     --slow    also the three GLMMs on the finer y basis with nAGQ = 1
#               (hours each; without them the Rmd uses the nAGQ = 0 fits)
#     --force   pass --force to every job (overwrite existing outputs)
#     --dry-run print "stage <k>: <job> ..." for the selected jobs and exit
#     JOB ...   only these jobs (names of tools/fit_compare_models.R --list)
# Every job runs from its own copy of tools/fit_compare_models.R: Rscript
# reads its --file while it runs, so an edit of the script during a long fit
# changes what the fit reads after it returns (on 2026-11-07 that crashed five
# T6 fits after up to 107 minutes; docs/tests/T6-results.md). A job refuses an
# existing output unless --force. Logs: logs/compare_fits/<job>.log (ignored
# by git), one START/END line per job in logs/compare_fits/progress.txt.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo"

njobs=2
slow=0
dry=0
force=()
only=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --jobs) njobs=$2; shift 2 ;;
    --slow) slow=1; shift ;;
    --force) force=(--force); shift ;;
    --dry-run) dry=1; shift ;;
    -*) echo "run_compare_fits.sh: unknown option $1" >&2; exit 2 ;;
    *) only+=("$1"); shift ;;
  esac
done
if ! [[ $njobs =~ ^[1-9][0-9]*$ ]]; then
  echo "run_compare_fits.sh: --jobs needs a positive integer" >&2
  exit 2
fi

# stage 1: independent fits; stage 2: fits that start from a stage-1 fit
# (the bootstraps and profiles of the fits, the offset refit without the
# reprinted shoes, whose retry starts from the no-offset fit); stage 3: the
# profile of that offset refit
stage1=(offset_old offset_new nagq0_old nagq0_new
        full_old_glmm full_new_glmm full_old_cml full_new_cml
        fineY_old_cml fineY_new_cml fineYold_new_cml
        fineY_old_glmm0 fineY_new_glmm0 fineYold_new_glmm0
        norep_glmm norep_cml groupB_glmm groupB_cml boot_old boot_new_ob)
stage2=(offset_norep boot_norep boot_full_old boot_full_new
        profile_glmm_old profile_glmm_new profile_off_old profile_off_new
        profile_norep)
stage3=(profile_off_norep)
if [[ $slow -eq 1 ]]; then
  stage1+=(fineY_old_glmm fineY_new_glmm fineYold_new_glmm)
fi

selected() {
  local j=$1 o
  if [[ ${#only[@]} -eq 0 ]]; then return 0; fi
  for o in "${only[@]}"; do
    if [[ $o == "$j" ]]; then return 0; fi
  done
  return 1
}
if [[ $dry -eq 1 ]]; then
  k=0
  for stage in "${stage1[*]}" "${stage2[*]}" "${stage3[*]}"; do
    k=$((k + 1))
    line="stage $k:"
    for j in $stage; do
      if selected "$j"; then line="$line $j"; fi
    done
    echo "$line"
  done
  exit 0
fi

logdir=$repo/logs/compare_fits
mkdir -p "$logdir"
frozen=$(mktemp -d "${TMPDIR:-/tmp}/compare_fits_XXXXXX")
trap 'rm -rf "$frozen"' EXIT

# one job: a private copy of the script, its log, its START/END line
run_one() {
  local j=$1 copy start status=0
  copy=$frozen/$j.R
  cp tools/fit_compare_models.R "$copy"
  start=$(date +%s)
  echo "START $j $(date +%T)" >> "$logdir/progress.txt"
  Rscript "$copy" "$j" "${force[@]}" > "$logdir/$j.log" 2>&1 || status=$?
  echo "END $j exit=$status $(($(date +%s) - start))s $(date +%T)" >> "$logdir/progress.txt"
  return "$status"
}

run_stage() {
  local -a todo=()
  local j pid failed=0
  local -a pids=()
  for j in "$@"; do
    if selected "$j"; then todo+=("$j"); fi
  done
  for j in "${todo[@]}"; do
    while [[ $(jobs -rp | wc -l) -ge $njobs ]]; do
      wait -n || failed=1
    done
    run_one "$j" &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
  done
  return "$failed"
}

status=0
run_stage "${stage1[@]}" || status=1
run_stage "${stage2[@]}" || status=1
run_stage "${stage3[@]}" || status=1
if [[ $status -ne 0 ]]; then
  echo "run_compare_fits.sh: a job failed; see $logdir/progress.txt" >&2
fi
exit "$status"
