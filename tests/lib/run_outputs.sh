# shellcheck shell=bash
# Outputs of a legacy or regression run (decision A-067; T1 review 2,
# reproducibility finding 1). A run folder may hold the committed file at
# the very path a step writes (run_legacy_r.sh extracts every committed
# output, tests/regress_old.sh copies the work tree), so a check that only
# hashes that path passes when the step never ran. Every runner therefore:
#
#   rac_outputs_begin "$run" repo/data/all_cont.csv ...   # before step one
#     deletes each listed file (paths relative to the run folder), checks
#     that none is left, and writes the list to $run/outputs_expected.txt;
#     the mtime of that file marks the start of the run.
#   rac_outputs_end "$run" || status=1                     # after the last
#     writes $run/outputs_regenerated.sha256 (sha256sum lines, paths
#     relative to the run folder) for every listed file that exists, is a
#     regular file and is newer than outputs_expected.txt, and
#     $run/outputs_missing.txt for the others; returns 1 if any is missing.
#
# The live checks (tests/lib/run_manifest.R and run_manifest.py) accept only
# files on the regenerated list whose sha256 is unchanged. Source this file
# from a bash script that runs with `set -euo pipefail`.

# rac_outputs_begin RUN PATH...: delete the outputs, write the expected list.
rac_outputs_begin() {
  local run=${1:-} p
  shift || true
  if [[ -z "$run" || ! -d "$run" || $# -eq 0 ]]; then
    echo "run_outputs.sh: usage: rac_outputs_begin RUN_DIR PATH..." >&2
    return 2
  fi
  if [[ -e "$run/outputs_expected.txt" ]]; then
    echo "run_outputs.sh: $run already has outputs_expected.txt" >&2
    return 2
  fi
  for p in "$@"; do
    if [[ -z "$p" || "$p" == /* || "$p" == */ || "$p" == *//* \
      || "/$p/" == */./* || "/$p/" == */../* ]]; then
      echo "run_outputs.sh: bad output path '$p' (relative, no empty," \
        "'.' or '..' component)" >&2
      return 2
    fi
    if [[ -d "$run/$p" && ! -L "$run/$p" ]]; then
      echo "run_outputs.sh: output path is a directory: $p" >&2
      return 2
    fi
  done
  for p in "$@"; do
    rm -f -- "$run/$p"
    if [[ -e "$run/$p" || -L "$run/$p" ]]; then
      echo "run_outputs.sh: could not delete $run/$p" >&2
      return 2
    fi
  done
  printf '%s\n' "$@" > "$run/outputs_expected.txt"
}

# rac_outputs_end RUN: hash the regenerated outputs, list the missing ones.
rac_outputs_end() {
  local run=${1:-} p missing=0
  local list="$run/outputs_expected.txt"
  local -a expected=()
  if [[ -z "$run" || ! -f "$list" ]]; then
    echo "run_outputs.sh: no outputs_expected.txt in '$run'" >&2
    return 2
  fi
  mapfile -t expected < "$list"
  : > "$run/outputs_regenerated.sha256"
  : > "$run/outputs_missing.txt"
  for p in "${expected[@]}"; do
    if [[ -f "$run/$p" && ! -L "$run/$p" && "$run/$p" -nt "$list" ]]; then
      (cd "$run" && sha256sum -- "$p") >> "$run/outputs_regenerated.sha256"
    else
      printf '%s\n' "$p" >> "$run/outputs_missing.txt"
      missing=1
    fi
  done
  if [[ $missing -ne 0 ]]; then
    echo "run_outputs.sh: outputs missing or not newer than the start:" \
      "$(tr '\n' ' ' < "$run/outputs_missing.txt")" >&2
  fi
  return "$missing"
}
