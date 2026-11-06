# shellcheck shell=bash
# The Windows R from WSL, for the Tier A gates of the R steps (decisions
# A-065, A-084). Sourced by tests/legacy/run_windows_r_step3.sh and
# tests/legacy/run_windows_r_steps.sh.
#
# The Windows R 4.4.3 has no pandoc, so the Rmds run through knitr::knit.
# knitr's default chunk option error = TRUE turns an error in a chunk into an
# "## Error" line of the .md and lets the knit go on and return normally (T2
# review: an in-place step-5 knit printed four "## Error: refusing ..."
# lines, and the driver saw no failure). rmarkdown::render sets error =
# FALSE. rac_win_knit therefore sets error = FALSE before knitr::knit, so a
# chunk error stops the knit and Rscript exits non-zero, and it also fails
# when the knitted .md holds a knitr error line, in case a chunk option or
# a later knitr version brings error = TRUE back.
#
#   rac_win_rscript   the Windows Rscript.exe (RAC_WIN_RSCRIPT, default the
#                     Windows R 4.4.3 that reproduces the committed GLMM)
#   rac_win_path P    the Windows path of the WSL path P, with forward
#                     slashes (R on Windows takes them in UNC paths)
#   rac_win_knit RUN NAME WORKDIR RMD [VAR=VALUE ...]
#                     knits WORKDIR/RMD with the Windows R into
#                     RUN/NAME_win.md. The driver RUN/NAME_win.R sets
#                     RGL_USE_NULL=TRUE and every VAR=VALUE (WSL variables
#                     reach a Windows process only through WSLENV), unsets
#                     RAC_PROFILE_FILE (A-049), works in WORKDIR, and prints
#                     the knit time and the R, lme4 and Matrix versions. Log:
#                     RUN/logs/NAME_win.log (CR removed). Returns the Rscript
#                     exit status if it is not 0; else 1 if the .md is
#                     missing or has a line that starts with "## Error" (the
#                     line is copied to the log); else 0.
# The caller has set -euo pipefail; RUN must be a scratch run folder.

rac_win_rscript=${RAC_WIN_RSCRIPT:-/mnt/c/Users/mehes/AppData/Local/Programs/R/R-4.4.3/bin/Rscript.exe}

rac_win_path() {
  local p
  p=$(wslpath -w "$1")
  printf '%s' "${p//\\//}"
}

rac_win_knit() {
  local run=$1 name=$2 wd=$3 rmd=$4 kv status=0
  shift 4
  local driver=$run/${name}_win.R md=$run/${name}_win.md
  local log=$run/logs/${name}_win.log
  mkdir -p "$run/logs"
  rm -f "$md"
  {
    echo 'Sys.setenv(RGL_USE_NULL = "TRUE")'
    for kv in "$@"; do
      if [[ ! "$kv" =~ ^[A-Z][A-Z0-9_]*=[^\"\\]*$ ]]; then
        echo "rac_win_knit: bad variable '$kv'" >&2
        return 2
      fi
      printf 'Sys.setenv(%s = "%s")\n' "${kv%%=*}" "${kv#*=}"
    done
    printf 'setwd("%s")\n' "$(rac_win_path "$wd")"
    printf 'rmd <- "%s"\n' "$rmd"
    printf 'md <- "%s"\n' "$(rac_win_path "$md")"
    cat << 'EOR'
Sys.unsetenv("RAC_PROFILE_FILE")
options(rgl.useNULL = TRUE)
# a chunk error stops the knit (knitr's default is error = TRUE)
knitr::opts_chunk$set(error = FALSE)
t0 <- proc.time()[["elapsed"]]
knitr::knit(rmd, output = md, quiet = TRUE)
cat(sprintf("knit seconds %.1f\n", proc.time()[["elapsed"]] - t0))
cat(R.version.string, "| lme4", as.character(packageVersion("lme4")),
    "| Matrix", as.character(packageVersion("Matrix")), "\n")
EOR
  } > "$driver"
  # cd /mnt/c: Windows cannot start a process in a \\wsl.localhost folder
  (cd /mnt/c && "$rac_win_rscript" "$(rac_win_path "$driver")") 2>&1 |
    tr -d '\r' > "$log" || status=$?
  if [[ $status -ne 0 ]]; then return "$status"; fi
  if [[ ! -f "$md" ]]; then
    echo "rac_win_knit: the knit wrote no $md" >> "$log"
    return 1
  fi
  if grep -n '^## Error' "$md" >> "$log"; then
    echo "rac_win_knit: knitr error lines in $md (above)" >> "$log"
    return 1
  fi
  return 0
}
