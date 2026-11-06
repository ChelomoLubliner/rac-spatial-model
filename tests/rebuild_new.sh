#!/usr/bin/env bash
# The NEW rebuild gate (T4 review fixes; decisions A-035, A-103, A-108).
#
# Usage: RAC_SCRATCH=<scratch dir> bash tests/rebuild_new.sh [--keep]
#            [--full] [--py PYTHON] [--jobs N]
#   PYTHON  the Python for step 0 (default RAC_VENV_PY, else the thesis venv)
#   N       forked processes for the snakes and the QA metrics (default 14;
#           1 on a platform without fork)
# Copies the work tree into a fresh run folder RAC_SCRATCH/rebuild_new_XXXXXX
# (repo/: rsync without .git, images*/, logs/, .claude), deletes there the
# committed NEW outputs that it checks, runs NEW step 0 (python -m
# contour_algorithm.main --qa) and the QA metrics (python -m
# contour_algorithm.qa_snake --metrics) in the copy, and compares the
# regenerated files byte for byte with the files committed at HEAD (git
# show HEAD:<path>, never the work tree's copies: A-070's rule for OLD):
#   data/new_shoes/contour_Active_Contour_new.txt   the NEW contour
#   docs/qa/T4/new/snake_metrics_new.csv            the QA metrics, flags,
#                                                   review merged
#   docs/qa/T4/new/sticker_erased_new.csv           the erase counts
#   docs/qa/sheets_new/snake_qa_new.csv             the task copy
# A compared file whose work-tree copy differs from HEAD fails too (an
# uncommitted in-place rebuild: the committed state and the work tree
# disagree).
# --full also rebuilds and compares the QA figures and tables of the T4
# documents (about 5 more minutes): qa_snake --sheets --flagged
# --crosscheck (the contact sheets of docs/qa/sheets_new, one figure per
# flagged shoe in docs/qa/T4/new/flagged, which must hold exactly HEAD's
# files, and crosscheck_2023_new.csv), qa_snake --thresholds
# 13,18,24,29,36 --compare 18,29 (mask_threshold_new.csv,
# prototype_mask_new.png) and docs/qa/T4/probes/t4_overrides_figure.py
# (overrides_before_after_new.png); the last two run snakes, with one
# OpenBLAS thread as the NEW profile.
# A code or profile edit that changes the NEW snakes (the erase list, the
# closing, the overrides, the mask, the thread count, the kernel) without a
# rebuild and commit of the outputs fails this gate, while the unit tests
# stay green. The runs drop OPENBLAS_CORETYPE (a forced kernel; A-108), and
# the step-0 log's thread count and kernel must be the NEW profile's
# (python.blas_threads, python.blas_kernel; step 0 itself refuses another
# kernel). Writes timings.tsv, compare.tsv, logs/, head/ (the HEAD blobs)
# and exit_status into the run folder and prints a summary; exit 0 only if
# every step and comparison passes. The run folder is deleted after a pass
# unless --keep, and kept after a failure. Nothing in the repository is
# written. Refuses RAC_PROFILE_FILE (A-049). About 2.5 minutes on this
# machine with 14 jobs (7-8 with --full).

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/scratch.sh
source "$here/lib/scratch.sh"
repo=$rac_repo_root

if [[ -n "${RAC_PROFILE_FILE:-}" ]]; then
  echo "rebuild_new.sh: RAC_PROFILE_FILE is set; it is a test hook and a" \
    "real run refuses it (decision A-049)" >&2
  exit 2
fi
keep=0
full=0
jobs=14
py=${RAC_VENV_PY:-/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python}
while [[ $# -gt 0 ]]; do
  case $1 in
    --py | --jobs)
      if [[ $# -lt 2 ]]; then
        echo "rebuild_new.sh: $1 needs a value" >&2
        exit 2
      fi
      if [[ $1 == --py ]]; then py=$2; else jobs=$2; fi
      shift 2
      ;;
    --keep)
      keep=1
      shift
      ;;
    --full)
      full=1
      shift
      ;;
    *)
      echo "rebuild_new.sh: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done
if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
  echo "rebuild_new.sh: --jobs takes a positive integer, not '$jobs'" >&2
  exit 2
fi

compared=(data/new_shoes/contour_Active_Contour_new.txt
  docs/qa/T4/new/snake_metrics_new.csv
  docs/qa/T4/new/sticker_erased_new.csv
  docs/qa/sheets_new/snake_qa_new.csv)
flagged_dir=docs/qa/T4/new/flagged
sheets=()
if [[ $full -eq 1 ]]; then
  compared+=(docs/qa/T4/new/crosscheck_2023_new.csv
    docs/qa/T4/new/mask_threshold_new.csv
    docs/qa/T4/new/overrides_before_after_new.png
    docs/qa/sheets_new/prototype/prototype_mask_new.png)
  while IFS= read -r f; do
    sheets+=("$f")
  done < <(git -C "$repo" ls-tree -r --name-only HEAD -- docs/qa/sheets_new |
    grep -E '_sheet_[0-9]+_new\.png$')
fi

run=$(rac_scratch_new rebuild_new)
echo "$run"
mkdir -p "$run/repo" "$run/logs" "$run/head"
rsync -a --exclude /.git --exclude '/images*/' --exclude /logs/ \
  --exclude /.claude "$repo/" "$run/repo/"
echo rebuild_new > "$run/runner.txt"
{
  echo "head=$(git -C "$repo" rev-parse HEAD)"
  echo "python=$py"
  echo "jobs=$jobs"
  echo "full=$full"
  echo "work tree changes (git status --short):"
  git -C "$repo" status --short
} > "$run/source.txt"
for f in "${compared[@]}" "${sheets[@]}"; do
  rm -f "$run/repo/$f"
done
if [[ $full -eq 1 ]]; then
  find "$run/repo/$flagged_dir" -maxdepth 1 -type f -delete 2> /dev/null ||
    true
fi
touch "$run/start_marker"

printf 'step\tseconds\texit\n' > "$run/timings.tsv"
status=0
step() {
  local name=$1 start code=0
  shift
  start=$(date +%s.%N)
  (cd "$run/repo" && env -u RAC_PROFILE_FILE -u OPENBLAS_CORETYPE \
    RAC_DATASET=new MPLBACKEND=Agg TQDM_DISABLE=1 PYTHONDONTWRITEBYTECODE=1 \
    "$@") > "$run/logs/$name.log" 2>&1 || code=$?
  printf '%s\t%s\t%s\n' "$name" \
    "$(echo "$(date +%s.%N) - $start" | bc)" "$code" >> "$run/timings.tsv"
  if [[ $code -ne 0 && $status -eq 0 ]]; then status=$code; fi
}
step step0 "$py" -B -m contour_algorithm.main --qa --jobs "$jobs"
if [[ $status -eq 0 ]]; then
  step qa_metrics "$py" -B -m contour_algorithm.qa_snake --metrics \
    --jobs "$jobs"
fi
if [[ $status -eq 0 && $full -eq 1 ]]; then
  step qa_figures "$py" -B -m contour_algorithm.qa_snake --sheets \
    --flagged --crosscheck --jobs "$jobs"
  step qa_thresholds env OPENBLAS_NUM_THREADS=1 "$py" -B -m \
    contour_algorithm.qa_snake --thresholds 13,18,24,29,36 --compare 18,29 \
    --jobs "$jobs"
  step overrides_figure env OPENBLAS_NUM_THREADS=1 "$py" -B \
    docs/qa/T4/probes/t4_overrides_figure.py
fi
echo "$status" > "$run/exit_status"

printf 'result\tcheck\tdetail\n' > "$run/compare.tsv"
fail=0
record() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$run/compare.tsv"
  if [[ $1 == FAIL ]]; then fail=1; fi
}
if [[ $status -ne 0 ]]; then
  record FAIL "pipeline run" "exit $status; see $run/logs/"
else
  record PASS "pipeline run" "every step exit 0"
fi
# the OpenBLAS values of the run against the NEW profile's (A-092, A-108)
want_blas=$(cd "$run/repo" && env -u RAC_PROFILE_FILE "$py" -B -c \
  'from contour_algorithm.profiles import load_profile
p = load_profile("new")
print(p.blas_threads, p.blas_kernel)' 2> /dev/null) || want_blas="? ?"
threads=$(grep -o 'numpy OpenBLAS threads: [0-9]*' "$run/logs/step0.log" \
  2> /dev/null | head -n 1 | awk '{print $NF}' || true)
kernel=$(grep -o 'numpy OpenBLAS kernel: .*' "$run/logs/step0.log" \
  2> /dev/null | head -n 1 | awk '{print $NF}' || true)
if [[ "${threads:-?} ${kernel:-?}" == "$want_blas" ]]; then
  record PASS "OpenBLAS threads and kernel = NEW profile" \
    "$threads threads, kernel $kernel"
else
  record FAIL "OpenBLAS threads and kernel = NEW profile" \
    "logged ${threads:-nothing} threads, kernel ${kernel:-nothing};" \
    "profile: $want_blas (logs/step0.log)"
fi

# why a regenerated file is not the committed one ('' when it is): not at
# HEAD, not regenerated by this run, other bytes than the HEAD blob, or a
# work-tree copy that differs from HEAD
problem() {
  local f=$1 got=$run/repo/$1 blob=$run/head/$1
  mkdir -p "$(dirname "$blob")"
  if ! git -C "$repo" show "HEAD:$f" > "$blob" 2> /dev/null; then
    echo "not committed at HEAD"
  elif [[ ! -f "$got" || ! "$got" -nt "$run/start_marker" ]]; then
    echo "not regenerated by this run"
  elif ! cmp -s "$got" "$blob"; then
    echo "differs from HEAD; see $got"
  elif ! git -C "$repo" diff --quiet HEAD -- "$f"; then
    echo "the work tree's copy differs from HEAD (uncommitted change)"
  fi
}
for f in "${compared[@]}"; do
  why=$(problem "$f")
  if [[ -z "$why" ]]; then
    record PASS "$f" "= HEAD, sha256 $(sha256sum "$run/repo/$f" |
      cut -c1-12)..."
  else
    record FAIL "$f" "$why"
  fi
done
group() {
  local name=$1 f why bad=0 first=""
  shift
  for f in "$@"; do
    why=$(problem "$f")
    if [[ -n "$why" ]]; then
      bad=$((bad + 1))
      if [[ -z "$first" ]]; then first="$f: $why"; fi
    fi
  done
  if [[ $# -eq 0 ]]; then
    record FAIL "$name" "no file to compare"
  elif [[ $bad -eq 0 ]]; then
    record PASS "$name" "$# files = HEAD"
  else
    record FAIL "$name" "$bad of $# fail; first: $first"
  fi
}
if [[ $full -eq 1 ]]; then
  group "contact sheets (docs/qa/sheets_new)" "${sheets[@]}"
  head_set=$(git -C "$repo" ls-tree -r --name-only HEAD -- "$flagged_dir" |
    sort)
  got_set=$(cd "$run/repo" && find "$flagged_dir" -type f 2> /dev/null |
    sort)
  tree_extra=$(git -C "$repo" status --porcelain --untracked-files=all \
    -- "$flagged_dir")
  if [[ "$head_set" != "$got_set" ]]; then
    record FAIL "flagged figures: the set" \
      "regenerated $(echo "$got_set" | grep -c .) files, HEAD" \
      "$(echo "$head_set" | grep -c .); diff: $(diff <(echo "$head_set") \
        <(echo "$got_set") | grep '^[<>]' | head -n 3 | tr '\n' ' ')"
  elif [[ -n "$tree_extra" ]]; then
    record FAIL "flagged figures: the set" \
      "the work tree's folder differs from HEAD: $(echo "$tree_extra" |
        head -n 3 | tr '\n' ' ')"
  else
    mapfile -t flagged < <(echo "$got_set")
    group "flagged figures ($flagged_dir)" "${flagged[@]}"
  fi
fi

echo
echo "== rebuild_new.sh: $run"
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
