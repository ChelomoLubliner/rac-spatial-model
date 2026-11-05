#!/usr/bin/env bash
# Fast test suite (plan section 4.5): committed checksums, every Python unit
# test under tests/python/ and every R test under tests/r/. Old-regression
# mode: nothing is written to the repository. Exit 0 only if all pass.
#
# Usage: bash tests/run_all.sh
# Optional: RAC_VENV_PY = the Python with numpy, scikit-image, opencv
#           (default: the thesis venv). Slow gates (legacy reruns,
#           tests/regress_old.sh) are separate and run in the background.

set -euo pipefail

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

# Every file of the work tree (path, size, mtime), .git excluded: the tests
# must not create, change or delete anything.
tree_state() {
  find . -path ./.git -prune -o -type f -printf '%p %s %T@\n' | LC_ALL=C sort
}
before=$(tree_state)

run_check "sha256 committed_79247d8 (Tier A, 24 files)" \
  sha256sum --quiet -c tests/baseline/committed_79247d8.sha256
run_check "sha256 old_baseline (11 OLD artifacts)" \
  sha256sum --quiet -c tests/baseline/old_baseline.sha256
run_check "python unittest discover tests/python" \
  "$py" -B -m unittest discover -s tests/python -t . -v
for t in tests/r/test_*.R; do
  run_check "Rscript $t" Rscript "$t"
done
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
