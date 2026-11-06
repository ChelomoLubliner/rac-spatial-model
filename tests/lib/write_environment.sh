#!/usr/bin/env bash
# Record the software environment of the Tier B reruns (plan T1 step 7).
# Read-only: prints versions; nothing is installed or changed.
# Usage: bash tests/lib/write_environment.sh > tests/baseline/local/environment.txt
# Optional: RAC_VENV_PY, RAC_THESIS_REPO, RAC_WIN_PY, RAC_WIN_RSCRIPT
# (the Windows interpreters are queried only if they exist).

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
thesis=${RAC_THESIS_REPO:-/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint}
py=${RAC_VENV_PY:-$thesis/venv/bin/python}
win_py=${RAC_WIN_PY:-$thesis/venv-wind/Scripts/python.exe}
win_r=${RAC_WIN_RSCRIPT:-/mnt/c/Users/mehes/AppData/Local/Programs/R/R-4.4.3/bin/Rscript.exe}
export PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
# WSL variables reach a Windows process only through WSLENV.
export WSLENV="${WSLENV:+$WSLENV:}PIP_DISABLE_PIP_VERSION_CHECK:PIP_NO_CACHE_DIR"

echo "# Environment of the T1 Tier B reruns, recorded $(date --iso-8601=seconds)"
echo
echo "## System"
uname -a
grep -E '^PRETTY_NAME=' /etc/os-release || true
nproc
echo
echo "## Git"
echo "this repo: $(git -C "$repo" rev-parse HEAD) ($(git -C "$repo" rev-parse --abbrev-ref HEAD))"
echo "thesis repo HEAD: $(timeout 600 git -C "$thesis" --no-optional-locks rev-parse HEAD)"
echo
echo "## R (WSL)"
Rscript -e 'suppressMessages({library(lme4); library(survival); library(splines);
  library(imager); library(fields); library(ggplot2)});
  pk <- c("rmarkdown", "knitr", "lme4", "Matrix", "survival", "imager",
          "fields", "smoothie", "plotly", "rgl", "dplyr", "ggplot2",
          "data.table", "doParallel", "jsonlite", "digest", "png", "spam");
  for (p in pk) cat(sprintf("%-11s %s\n", p, as.character(packageVersion(p))));
  cat("car installed:", requireNamespace("car", quietly = TRUE), "\n");
  print(sessionInfo())' 2>&1
echo "pandoc: $(pandoc --version | head -n 1)"
echo
echo "## Python (WSL thesis venv: $py)"
timeout 600 "$py" -B -c 'import sys; print(sys.version)'
timeout 600 "$py" -B -m pip freeze
if [[ -x "$win_py" ]]; then
  echo
  echo "## Python (Windows venv-wind, diagnostics only: $win_py)"
  (cd /mnt/c && timeout 600 "$win_py" -B -I -c \
    'import sys; print(sys.version); print("base_prefix", sys.base_prefix)' \
    | tr -d '\r')
  # The base interpreter is the Microsoft Store Python 3.13, which updates
  # itself: pyvenv.cfg keeps the version at creation, base_prefix names the
  # Store package now in use (decision A-071).
  win_cfg="$(dirname "$(dirname "$win_py")")/pyvenv.cfg"
  echo "pyvenv.cfg (modified $(stat -c %y "$win_cfg")):"
  tr -d '\r' < "$win_cfg"
  (cd /mnt/c && timeout 600 "$win_py" -B -m pip freeze | tr -d '\r')
fi
if [[ -x "$win_r" ]]; then
  echo
  echo "## R (Windows, diagnostics only: $win_r)"
  # one line: a multi-line -e argument does not survive the Windows
  # command line. sessionInfo() after loading the step-3 packages: this R
  # reproduces the committed GLMM bit for bit (A-055, A-065).
  (cd /mnt/c && timeout 600 "$win_r" -e 'for (p in c("lme4", "Matrix", "survival", "car")) cat(p, as.character(packageVersion(p)), "\n"); cat(R.version.string, "\n"); suppressMessages({library(splines); library(lme4); library(survival)}); print(sessionInfo())' \
    2>&1 | tr -d '\r')
fi
