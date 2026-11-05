# shellcheck shell=bash
# Scratch-directory helpers (plan section 4.5, decisions A-034 and A-062).
#
# Source this file from a bash script that runs with `set -euo pipefail`:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/scratch.sh"
#   run_dir=$(rac_scratch_new legacy_py)
#   ...
#   rac_scratch_remove "$run_dir"
#
# RAC_SCRATCH must name an existing directory chosen by the caller (its own
# scratchpad). There is no default. It must not be /, $HOME, the repository,
# a folder inside the repository, or a folder that contains the repository.
# Run folders are created with mktemp -d, so parallel agents that share one
# scratchpad cannot collide, and only a folder of that shape (a direct
# child NAME_XXXXXX of RAC_SCRATCH) can be deleted.

set -euo pipefail

: "${RAC_SCRATCH:?set RAC_SCRATCH to a scratch directory}"

rac_repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)

if [[ ! -d "$RAC_SCRATCH" ]]; then
  echo "scratch.sh: RAC_SCRATCH is not a directory: $RAC_SCRATCH" >&2
  exit 2
fi
RAC_SCRATCH=$(cd "$RAC_SCRATCH" && pwd -P)
rac_home=$(cd "${HOME:-/}" && pwd -P)

case "$RAC_SCRATCH" in
  / | "$rac_home")
    echo "scratch.sh: refusing RAC_SCRATCH=$RAC_SCRATCH (/ or \$HOME)" >&2
    exit 2
    ;;
  "$rac_repo_root" | "$rac_repo_root"/*)
    echo "scratch.sh: refusing RAC_SCRATCH inside the repository" >&2
    exit 2
    ;;
esac
case "$rac_repo_root/" in
  "$RAC_SCRATCH"/*)
    echo "scratch.sh: refusing RAC_SCRATCH that contains the repository" >&2
    exit 2
    ;;
esac
export RAC_SCRATCH
# The validated root, kept apart so that a caller that later changes or
# empties RAC_SCRATCH cannot move what rac_scratch_remove may delete.
rac_scratch_root=$RAC_SCRATCH

# rac_scratch_new NAME: create and print a fresh run folder NAME_XXXXXX.
rac_scratch_new() {
  local name=${1:?rac_scratch_new needs a name}
  if [[ ! "$name" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "scratch.sh: bad run-folder name: $name" >&2
    return 2
  fi
  mktemp -d "$rac_scratch_root/${name}_XXXXXX"
}

# rac_scratch_remove DIR: delete DIR, only if it has the shape of a run
# folder made by rac_scratch_new: its parent is exactly the validated
# RAC_SCRATCH, its name is NAME_XXXXXX (NAME from [A-Za-z0-9_.-], then six
# [A-Za-z0-9] characters, the mktemp suffix), and it is a real directory,
# not a symlink. Trailing slashes are stripped first, and a path with an
# empty ('//'), '.' or '..' component is refused. So "$RAC_SCRATCH/" (an
# empty $name in "$RAC_SCRATCH/$name"), "$RAC_SCRATCH//", "$RAC_SCRATCH/.",
# a nested "$RAC_SCRATCH/a/b" and hand-made folders such as venv_copy can
# never reach rm (decision A-062, T1 review finding 1). Callers pass only
# paths returned by rac_scratch_new.
rac_scratch_remove() {
  local dir=${1:-} parent base
  local re='^[A-Za-z0-9_.-]+_[A-Za-z0-9]{6}$'
  while [[ "$dir" == */ ]]; do
    dir=${dir%/}
  done
  parent=${dir%/*}
  base=${dir##*/}
  if [[ -z "$dir" || -z "$rac_scratch_root" || "$rac_scratch_root" == / \
    || "$dir" == *//* || "/$dir/" == */./* || "/$dir/" == */../* \
    || "$parent" != "$rac_scratch_root" || ! "$base" =~ $re ]]; then
    echo "scratch.sh: refusing to delete '${1:-}' (only a run folder" \
      "NAME_XXXXXX directly under $rac_scratch_root)" >&2
    return 2
  fi
  if [[ -L "$dir" || ! -d "$dir" ]]; then
    echo "scratch.sh: not a run directory (missing, or a symlink): '$dir'" >&2
    return 2
  fi
  rm -rf -- "$dir"
}
