#!/usr/bin/env bash
# Write the Tier A baseline files (plan T1 step 2) from the blobs committed
# at 79247d8, and check that the working tree holds the same bytes.
#
# Usage (from anywhere): bash tests/lib/make_tier_a.sh
# Writes, under tests/baseline/:
#   committed_79247d8.sha256  every file tracked at 79247d8 under data/,
#                             processed_data/, saved_models/, model_images/,
#                             except README.md files (sha256sum format)
#   old_baseline.sha256       the OLD pipeline artifacts that a rerun must
#                             reproduce: the contour txt, the two prototype
#                             PNGs, data/all_cont.csv, processed_data/*.csv,
#                             saved_models/*.rds
#   committed_79247d8_eol.tsv path, bytes, kind, LF count, CR count, CRLF
#                             count
# Exit 1 if a working-tree file differs from its 79247d8 blob.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
commit=79247d8
out="$repo/tests/baseline"
cd "$repo"

mapfile -t files < <(git ls-tree -r --name-only "$commit" -- data \
  processed_data saved_models model_images | grep -v -E '(^|/)README\.md$')

sha_all="$out/committed_79247d8.sha256"
eol="$out/committed_79247d8_eol.tsv"
: > "$sha_all"
printf 'path\tbytes\tkind\tlf\tcr\tcrlf\n' > "$eol"
bad=0
for f in "${files[@]}"; do
  blob_sha=$(git cat-file blob "$commit:$f" | sha256sum | cut -d' ' -f1)
  tree_sha=$(sha256sum "$f" | cut -d' ' -f1)
  if [[ "$blob_sha" != "$tree_sha" ]]; then
    echo "DIFFERS from $commit: $f" >&2
    bad=1
  fi
  printf '%s  %s\n' "$blob_sha" "$f" >> "$sha_all"
  case "$f" in
    *.png | *.pdf | *.rds) kind=binary ;;
    *) kind=text ;;
  esac
  counts=$(python3 -c 'import sys
d = open(sys.argv[1], "rb").read()
print(len(d), d.count(b"\n"), d.count(b"\r"), d.count(b"\r\n"), sep="\t")' "$f")
  printf '%s\t%s\t%s\n' "$f" "$kind" "$counts" |
    awk -F'\t' -v OFS='\t' '{print $1, $3, $2, $4, $5, $6}' >> "$eol"
done

grep -E '  (data/contour_Active_Contour\.txt|data/freq_min_18\.png|data/contour_prototype\.png|data/all_cont\.csv|processed_data/[^/]+\.csv|saved_models/[^/]+\.rds)$' \
  "$sha_all" > "$out/old_baseline.sha256"

echo "files: ${#files[@]} (all), $(wc -l < "$out/old_baseline.sha256") (old_baseline)"
exit "$bad"
