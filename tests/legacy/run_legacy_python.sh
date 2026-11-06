#!/usr/bin/env bash
# Run the UNMODIFIED thesis contour code (thesis repo commit 109f30a) on the
# OLD dataset in a fresh scratch folder, so nothing in this repository or in
# the thesis repository can be overwritten (plan T1 step 3, decision A-004).
#
# Usage: RAC_SCRATCH=<your scratch dir> bash tests/legacy/run_legacy_python.sh
# Optional: RAC_THESIS_REPO (default: the thesis repo under /mnt/c),
#           RAC_VENV_PY (default: its venv/bin/python),
#           RAC_LEGACY_COMMIT (default: 109f30a).
# Prints the run folder on the first line; the run keeps its outputs.
#
# Layout of the run folder (what the legacy code expects, relative to its
# working directory contour_algorithm/):
#   contour_algorithm/*.py   `git show <commit>:contour_algorithm/<file>`
#   data/                    copies of contacts_data.txt, locations_data.csv
#   Data -> data             the code reads ../Data/ in distance_extremities.py
#   images/<subfolders>      every folder the code writes into
# Outputs: data/contour_Active_Contour.txt (written with LF on Linux),
# images/saved/*.npy|png, images/<per-shoe folders>, logs/main.log,
# timing.txt, timings.tsv (one row, step0), outputs_expected.txt,
# outputs_regenerated.sha256, outputs_missing.txt, pip_freeze.txt,
# exit_status. The run folder starts without any output; the contour and
# the eight images/saved files are listed in outputs_expected.txt before the
# run and must exist and be newer than that list afterwards, or the run
# fails (tests/lib/run_outputs.sh, decision A-067).

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../lib/scratch.sh
source "$here/../lib/scratch.sh"
# shellcheck source=../lib/run_outputs.sh
source "$here/../lib/run_outputs.sh"
repo=$rac_repo_root

thesis=${RAC_THESIS_REPO:-/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint}
venv_py=${RAC_VENV_PY:-$thesis/venv/bin/python}
commit=${RAC_LEGACY_COMMIT:-109f30a}

run=$(rac_scratch_new legacy_py)
echo "$run"

mkdir -p "$run/contour_algorithm" "$run/data" "$run/logs"
for sub in shoes saved shoe_on_prototype cleaned_shoes extreme_values \
  active-contour snake_rac_html; do
  mkdir -p "$run/images/$sub"
done

# Legacy sources, exactly as committed in the thesis repo (read-only access).
mapfile -t py_files < <(timeout 600 git -C "$thesis" --no-optional-locks \
  ls-tree --name-only "$commit" contour_algorithm/ | grep -E '\.py$')
for f in "${py_files[@]}"; do
  timeout 600 git -C "$thesis" --no-optional-locks show "$commit:$f" \
    > "$run/$f"
done
{
  echo "thesis_repo=$thesis"
  echo "commit=$(timeout 600 git -C "$thesis" --no-optional-locks \
    rev-parse "$commit")"
  echo "python=$venv_py"
  echo "files=${py_files[*]}"
} > "$run/legacy_source.txt"

# Inputs are copied, never linked, so the legacy code cannot touch them.
cp -p "$repo/data/contacts_data.txt" "$repo/data/locations_data.csv" \
  "$run/data/"
ln -s data "$run/Data"

saved=()
for f in list_matrices.npy old_freq_min_18.npy freq_min_18.npy \
  list_contour.npy active-contour_all.npy all_shoes_superposed.png \
  old_freq_min_18.png freq_min_18.png; do
  saved+=("images/saved/$f")
done
rac_outputs_begin "$run" data/contour_Active_Contour.txt "${saved[@]}"

start=$(date +%s.%N)
echo "start $(date --iso-8601=seconds)" > "$run/timing.txt"
status=0
(
  cd "$run/contour_algorithm"
  MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 /usr/bin/time -v \
    "$venv_py" -B main.py
) > "$run/logs/main.log" 2>&1 || status=$?
end=$(date +%s.%N)
{
  echo "end $(date --iso-8601=seconds)"
  echo "exit $status"
  echo "seconds $(echo "$end - $start" | bc)"
} >> "$run/timing.txt"
printf 'step\tseconds\texit\nstep0\t%s\t%s\n' "$(echo "$end - $start" | bc)" \
  "$status" > "$run/timings.tsv"
rac_outputs_end "$run" || { [[ $status -ne 0 ]] || status=1; }

PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1 timeout 600 \
  "$venv_py" -B -m pip freeze > "$run/pip_freeze.txt" 2>&1 || true

echo "$status" > "$run/exit_status"
exit "$status"
