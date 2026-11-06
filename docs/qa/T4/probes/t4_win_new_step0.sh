#!/usr/bin/env bash
# NEW step 0 under venv-wind in a scratch copy of HEAD (T4 platform check,
# decision A-098; a probe, not a gate). Usage: t4_win_new_step0.sh <new
# empty run folder in your scratch directory>
set -euo pipefail
run=$1
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
thesis=/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint
win_py=$thesis/venv-wind/Scripts/python.exe
mkdir -p "$run/repo" "$run/logs"
git -C "$repo" archive --format=tar HEAD contour_algorithm config \
  data/new_shoes/contacts_data_new.txt data/new_shoes/locations_data_new_raw.txt \
  data/new_shoes/sticker_masks_new.csv data/new_shoes/snake_overrides_new.csv \
  | tar -x -C "$run/repo"
echo "commit=$(git -C "$repo" rev-parse HEAD)" > "$run/source.txt"
win_path() { local p; p=$(wslpath -w "$1"); printf '%s' "${p//\\//}"; }
cat > "$run/step0_win.py" <<PY
import os, platform, sys
repo = '$(win_path "$run/repo")'
os.chdir(repo)
sys.path.insert(0, repo)
os.environ['RAC_DATASET'] = 'new'
os.environ['MPLBACKEND'] = 'Agg'
os.environ['TQDM_DISABLE'] = '1'
os.environ.pop('RAC_PROFILE_FILE', None)
with open('$(win_path "$run/interpreter.txt")', 'w') as f:
    f.write(f'sys.version {sys.version}\n')
    f.write(f'sys.base_prefix {sys.base_prefix}\n')
    f.write(f'platform {platform.platform()}\n')
from contour_algorithm import main
sys.exit(main.main(['--steps', 'create,contour,snake']))
PY
start=$(date +%s)
status=0
(cd /mnt/c && "$win_py" -B "$(win_path "$run/step0_win.py")") 2>&1 | tr -d '\r' > "$run/logs/step0_win.log" || status=$?
echo "exit $status seconds $(( $(date +%s) - start ))" > "$run/done.txt"
