# shellcheck shell=bash
# Scratch-directory helpers (plan section 4.5, decision A-034).
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
# scratchpad cannot collide, and only such a folder can be deleted.

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

# rac_scratch_new NAME: create and print a fresh run folder NAME_XXXXXX.
rac_scratch_new() {
  local name=${1:?rac_scratch_new needs a name}
  if [[ ! "$name" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "scratch.sh: bad run-folder name: $name" >&2
    return 2
  fi
  mktemp -d "$RAC_SCRATCH/${name}_XXXXXX"
}

# rac_scratch_remove DIR: delete DIR, only if it is a folder directly
# created under RAC_SCRATCH (non-empty path with the RAC_SCRATCH/ prefix).
rac_scratch_remove() {
  local dir=${1:-}
  if [[ -z "$dir" || "$dir" != "$RAC_SCRATCH"/* || "$dir" == *"/../"* ]]; then
    echo "scratch.sh: refusing to delete '$dir'" >&2
    return 2
  fi
  if [[ ! -d "$dir" ]]; then
    echo "scratch.sh: not a directory: '$dir'" >&2
    return 2
  fi
  rm -rf -- "$dir"
}
