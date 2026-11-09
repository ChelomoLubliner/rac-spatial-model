#!/usr/bin/env bash
# Fast test suite (plan section 4.5): committed checksums (Tier A, the OLD
# baseline subset, and the OLD files T2 added, A-082), every Python unit
# test under tests/python/, every R test under tests/r/, and the code-style
# rules (flake8 on every Python file, shellcheck on every shell script;
# user rule 5). Old-regression mode: nothing is written to the repository.
# Exit 0 only if all pass.
#
# Usage: bash tests/run_all.sh [old]
#   The only dataset argument is old (the default): the OLD regression
#   checks, the unit tests of both profiles and, since T5, the checks of
#   the committed NEW outputs (tests/r/test_new_outputs.R); there is no
#   separate NEW mode.
# Optional: RAC_VENV_PY = the Python with numpy, scikit-image, opencv
#           (default: the thesis venv). Slow gates (legacy reruns,
#           tests/regress_old.sh, tests/legacy/run_windows_*.sh) are
#           separate and run in the background.

set -euo pipefail

if [[ $# -gt 1 || "${1:-old}" != old ]]; then
  echo "run_all.sh: usage: bash tests/run_all.sh [old]" >&2
  exit 2
fi

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo"
py=${RAC_VENV_PY:-/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python}
export MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 RGL_USE_NULL=TRUE

declare -a names=() results=() seconds=()
record() {
  names+=("$1")
  results+=("$2")
  seconds+=("$3")
}
run_check() {
  local name=$1 start status=0
  shift
  start=$(date +%s)
  echo "== $name"
  "$@" || status=$?
  if [[ $status -eq 0 ]]; then
    record "$name" PASS "$(($(date +%s) - start))"
  else
    record "$name" "FAIL($status)" "$(($(date +%s) - start))"
  fi
}

# Every file of the work tree (path, size, mtime): the tests must not
# create, change or delete anything. Excluded: .git and .claude (the
# Claude Code harness may write its local settings there during a run).
tree_state() {
  find . \( -path ./.git -o -path ./.claude \) -prune -o -type f \
    -printf '%p %s %T@\n' | LC_ALL=C sort
}
before=$(tree_state)

# Tracked and new (not ignored) files matching a pattern that exist.
# shellcheck disable=SC2317  # called by the lint functions below
code_files() {
  local f
  git ls-files -co --exclude-standard -- "$1" | LC_ALL=C sort -u |
    while IFS= read -r f; do
      if [[ -f "$f" ]]; then printf '%s\n' "$f"; fi
    done
}
# shellcheck disable=SC2317  # invoked indirectly through run_check
lint_python() {
  local -a files=()
  # every tracked or new Python file, contour_algorithm/ included since the
  # T2c style-only commit (A-064)
  mapfile -t files < <(code_files '*.py')
  echo "flake8: ${#files[@]} files"
  # with no file argument flake8 would lint "."
  if [[ ${#files[@]} -eq 0 ]]; then return 1; fi
  flake8 -- "${files[@]}"
}
# shellcheck disable=SC2317  # invoked indirectly through run_check
lint_shell() {
  local -a files=()
  mapfile -t files < <(code_files '*.sh')
  echo "shellcheck: ${#files[@]} files"
  if [[ ${#files[@]} -eq 0 ]]; then return 1; fi
  shellcheck -- "${files[@]}"
}

run_check "sha256 committed_79247d8 (Tier A, 24 files)" \
  sha256sum --quiet -c tests/baseline/committed_79247d8.sha256
run_check "sha256 old_baseline (11 OLD artifacts)" \
  sha256sum --quiet -c tests/baseline/old_baseline.sha256
run_check "sha256 old_added_t2 (the 2 OLD files T2 added)" \
  sha256sum --quiet -c tests/baseline/old_added_t2.sha256
run_check "sha256 old_added_t6 (the OLD-side files T6 added)" \
  sha256sum --quiet -c tests/baseline/old_added_t6.sha256
run_check "sha256 old_added_t7 (the OLD-side files T7 added; updated once, A-145)" \
  sha256sum --quiet -c tests/baseline/old_added_t7.sha256
# the OLD snake reruns need numpy's OpenBLAS at the library default and its
# own kernel, as the baselines (tests/baseline/local/openblas_tier_b.txt,
# A-103, A-108); the NEW tests that need one thread set it in their own
# subprocesses
run_check "python unittest discover tests/python" \
  env -u OPENBLAS_NUM_THREADS -u GOTO_NUM_THREADS -u OMP_NUM_THREADS \
  -u OPENBLAS_CORETYPE \
  "$py" -B -m unittest discover -s tests/python -t . -v
for t in tests/r/test_*.R; do
  run_check "Rscript $t" Rscript "$t"
done
run_check "flake8 (all Python files)" lint_python
run_check "shellcheck (all shell scripts)" lint_shell
# shellcheck disable=SC2317  # invoked indirectly through run_check
tree_unchanged() {
  local after
  after=$(tree_state)
  if [[ "$before" == "$after" ]]; then return 0; fi
  diff <(echo "$before") <(echo "$after") | head -20
  return 1
}
run_check "work tree unchanged by the tests (no file created or modified)" \
  tree_unchanged

echo
echo "== summary"
fail=0
for i in "${!names[@]}"; do
  printf '%-8s %5ss  %s\n' "${results[$i]}" "${seconds[$i]}" "${names[$i]}"
  if [[ "${results[$i]}" != PASS ]]; then fail=1; fi
done
if [[ $fail -eq 0 ]]; then
  echo "ALL PASS"
else
  echo "SOME CHECKS FAILED"
fi
exit "$fail"
