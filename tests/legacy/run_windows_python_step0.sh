#!/usr/bin/env bash
# Run the ported step 0 (python -m contour_algorithm.main, OLD profile)
# under the thesis Windows venv (venv-wind) in a fresh scratch copy and
# compare its contour with the committed file (Tier A) (plan T2 step 3;
# decisions A-060, A-071). On WSL the snake differs in 30 of 386 records
# (platform numerics, A-060), so tests/regress_old.sh checks Tier B there
# and this is the Tier A gate of step 0.
#
# Usage: RAC_SCRATCH=<scratch dir> bash tests/legacy/run_windows_python_step0.sh
# Optional: RAC_WINPY_COMMIT (default HEAD): the commit whose
#           contour_algorithm/ and config/ run, with the OLD inputs of that
#           commit; RAC_WIN_PY (default: venv-wind's Scripts/python.exe).
# The copy (git archive: contour_algorithm, config, data/contacts_data.txt,
# data/locations_data.csv) has no contour file, so the run must write it;
# it and the eight images/saved files are listed in outputs_expected.txt
# and must exist and be newer than that list afterwards (A-067). Windows
# Python reaches the copy through \\wsl.localhost (wslpath -w). WSL
# variables reach a Windows process only through WSLENV, so the driver sets
# RAC_DATASET=old and MPLBACKEND=Agg, removes RAC_PROFILE_FILE, and logs
# sys.version and sys.base_prefix (the Store base of venv-wind updates
# itself, A-071).
# Compared (compare.txt): the contour file = Tier A (sha256 in
# tests/baseline/committed_79247d8.sha256); the four platform-independent
# npy intermediates (list_matrices, old_freq_min_18, freq_min_18,
# list_contour) = Tier B; reported only: active-contour_all.npy against the
# thesis run of 2025-11-13 that wrote the committed contour (read-only;
# skipped when the thesis repo is absent). PNG bytes are not compared:
# Windows Pillow encodes other bytes for the same pixels (A-054).
# Prints the run folder on the first line. Exit 0 only if the run succeeds,
# writes every listed output, and the contour and the four npy files match.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../lib/scratch.sh
source "$here/../lib/scratch.sh"
# shellcheck source=../lib/run_outputs.sh
source "$here/../lib/run_outputs.sh"
repo=$rac_repo_root
commit=${RAC_WINPY_COMMIT:-HEAD}
thesis=/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint
win_py=${RAC_WIN_PY:-$thesis/venv-wind/Scripts/python.exe}
if [[ ! -x "$win_py" ]]; then
  echo "run_windows_python_step0.sh: Windows python not found: $win_py" >&2
  exit 2
fi

run=$(rac_scratch_new winpy_step0)
echo "$run"
mkdir -p "$run/repo" "$run/logs"
git -C "$repo" archive --format=tar "$commit" contour_algorithm config \
  data/contacts_data.txt data/locations_data.csv | tar -x -C "$run/repo"
echo "commit=$(git -C "$repo" rev-parse "$commit")" > "$run/source.txt"

saved=()
for f in list_matrices.npy old_freq_min_18.npy freq_min_18.npy \
  list_contour.npy active-contour_all.npy all_shoes_superposed.png \
  old_freq_min_18.png freq_min_18.png; do
  saved+=("repo/images/saved/$f")
done
rac_outputs_begin "$run" repo/data/contour_Active_Contour.txt "${saved[@]}"

# Windows paths with forward slashes (Python accepts them in UNC paths).
win_path() {
  local p
  p=$(wslpath -w "$1")
  printf '%s' "${p//\\//}"
}
cat > "$run/step0_win.py" <<EOF
import os
import platform
import sys

repo = '$(win_path "$run/repo")'
os.chdir(repo)
sys.path.insert(0, repo)
os.environ['RAC_DATASET'] = 'old'
os.environ['MPLBACKEND'] = 'Agg'
os.environ.pop('RAC_PROFILE_FILE', None)
with open('$(win_path "$run/interpreter.txt")', 'w') as f:
    f.write(f'sys.version {sys.version}\n')
    f.write(f'sys.base_prefix {sys.base_prefix}\n')
    f.write(f'sys.executable {sys.executable}\n')
    f.write(f'platform {platform.platform()}\n')
from contour_algorithm import main  # noqa: E402
sys.exit(main.main([]))
EOF

start=$(date +%s.%N)
status=0
# cd /mnt/c: a Windows process cannot start in a \\wsl.localhost folder.
(cd /mnt/c && "$win_py" -B "$(win_path "$run/step0_win.py")") 2>&1 |
  tr -d '\r' > "$run/logs/step0_win.log" || status=$?
end=$(date +%s.%N)
printf 'step\tseconds\texit\nstep0_win\t%s\t%s\n' \
  "$(echo "$end - $start" | bc)" "$status" > "$run/timings.tsv"
written=0
rac_outputs_end "$run" || written=1
if [[ -f "$run/interpreter.txt" ]]; then
  tr -d '\r' < "$run/interpreter.txt" > "$run/interpreter.tmp"
  mv "$run/interpreter.tmp" "$run/interpreter.txt"
fi

fail=0
{
  echo "commit $(cat "$run/source.txt")"
  cat "$run/interpreter.txt" 2> /dev/null || echo "no interpreter.txt"
  echo "step 0 exit $status, outputs written: $([[ $written -eq 0 ]] && echo yes || echo NO)"
  want=$(awk '$2 == "data/contour_Active_Contour.txt" {print $1}' \
    "$repo/tests/baseline/committed_79247d8.sha256")
  got=$(sha256sum < "$run/repo/data/contour_Active_Contour.txt" 2> /dev/null |
    cut -d' ' -f1 || true)
  echo "contour sha256 $got (Tier A $want)"
  if [[ -n "$got" && "$got" == "$want" ]]; then
    echo "RESULT contour = Tier A"
  else
    echo "RESULT contour differs from Tier A"
  fi
  for f in list_matrices.npy old_freq_min_18.npy freq_min_18.npy \
    list_contour.npy; do
    w=$(awk -v p="images/saved/$f" '$2 == p {print $1}' \
      "$repo/tests/baseline/local/python_intermediates.sha256")
    g=$(sha256sum < "$run/repo/images/saved/$f" 2> /dev/null | cut -d' ' -f1 ||
      true)
    if [[ -n "$g" && "$g" == "$w" ]]; then
      echo "RESULT $f = Tier B"
    else
      echo "RESULT $f differs from Tier B ($g vs $w)"
    fi
  done
  tnpy=$thesis/images/saved/active-contour_all.npy
  if [[ -f "$tnpy" ]]; then
    if cmp -s "$tnpy" "$run/repo/images/saved/active-contour_all.npy"; then
      echo "INFO active-contour_all.npy = the thesis run of 2025-11-13"
    else
      echo "INFO active-contour_all.npy differs from the thesis run"
    fi
  fi
} > "$run/compare.txt" 2>&1
if [[ $status -ne 0 || $written -ne 0 ]] ||
  grep -q '^RESULT .*differs' "$run/compare.txt"; then
  fail=1
fi
echo "$fail" > "$run/exit_status"
cat "$run/compare.txt"
exit "$fail"
