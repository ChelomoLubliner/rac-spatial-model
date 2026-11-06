#!/usr/bin/env bash
# t5_new_rerun.sh: rerun NEW steps 1-6 in a scratch copy and compare them
# with the NEW outputs committed at HEAD (T5 determinism check; plan T8's
# tests/e2e/test_new_rerun.sh is the gate this precedes).
#
# Usage (from anywhere): RAC_SCRATCH=<scratch dir> bash docs/qa/T5/probes/t5_new_rerun.sh
# Copies the work tree (no .git, images*/, logs/, .claude) into a fresh
# RAC_SCRATCH/new_rerun_XXXXXX folder, deletes there the NEW outputs of
# steps 1-6, runs RAC_DATASET=new tools/run_pipeline.sh --steps 1-6 in the
# copy, and prints, for each output, SAME or DIFF against the HEAD blob:
# the 7 CSVs by sha256, the two models field by field (tests/lib/
# dump_models.R and compare_models.R: identical()), the 8 PDFs by the
# sha256 after their dates are removed (tests/lib/pdf_normalize.py).
# Exit 0 only if every output is the same. Writes nothing into the
# repository; the run folder is kept for inspection.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../../../../tests/lib/scratch.sh
source "$here/../../../../tests/lib/scratch.sh"
repo=$rac_repo_root
run=$(rac_scratch_new new_rerun)
echo "$run"
rsync -a --exclude /.git --exclude '/images*/' --exclude /logs/ \
  --exclude /.claude "$repo/" "$run/repo/"
csvs=(processed_data/new/dataCC_new.csv
  processed_data/new/shoe_pixel_counts_new.csv
  processed_data/new/all_cont_new.csv processed_data/new/shoe_codes_new.csv
  processed_data/new/dataCC_distance_temp_new.csv
  processed_data/new/dataCC_distance_new.csv
  processed_data/new/wald_test_new.csv)
models=(saved_models/new/NEW_X_NS_XY_new.rds saved_models/new/CML_MODEL_new.rds)
for f in "${csvs[@]}" "${models[@]}"; do rm "$run/repo/$f"; done
rm "$run/repo"/model_images/new/*_new.pdf
mkdir -p "$run/head/saved_models/new"
for f in "${models[@]}"; do
  git -C "$repo" show "HEAD:$f" > "$run/head/$f"
done
(cd "$run/repo" && RAC_DATASET=new bash tools/run_pipeline.sh --steps 1-6)
status=0
echo "== CSVs (sha256: rerun vs HEAD)"
for f in "${csvs[@]}"; do
  a=$(sha256sum < "$run/repo/$f" | cut -c1-64)
  b=$(git -C "$repo" show "HEAD:$f" | sha256sum | cut -c1-64)
  if [[ "$a" == "$b" ]]; then
    echo "SAME  $f ${a:0:12}"
  else
    echo "DIFF  $f $a $b"
    status=1
  fi
done
echo "== models"
Rscript "$repo/tests/lib/dump_models.R" "${models[@]/#/$run/head/}" \
  "$run/dump_head.rds" "$run/dump_head" > /dev/null
Rscript "$repo/tests/lib/dump_models.R" "${models[@]/#/$run/repo/}" \
  "$run/dump_rerun.rds" "$run/dump_rerun" > /dev/null
if Rscript "$repo/tests/lib/compare_models.R" "$run/dump_head.rds" \
  "$run/dump_rerun.rds"; then
  echo "models: every field identical()"
else
  status=1
fi
echo "== PDFs (normalized sha256)"
for f in "$run/repo"/model_images/new/*_new.pdf; do
  rel=${f#"$run/repo/"}
  git -C "$repo" show "HEAD:$rel" > "$run/head_pdf.pdf"
  a=$(python3 "$repo/tests/lib/pdf_normalize.py" "$f" | cut -c1-64)
  b=$(python3 "$repo/tests/lib/pdf_normalize.py" "$run/head_pdf.pdf" |
    cut -c1-64)
  if [[ "$a" == "$b" ]]; then
    echo "SAME  $rel ${a:0:12}"
  else
    echo "DIFF  $rel"
    status=1
  fi
done
if [[ $status -eq 0 ]]; then echo "ALL SAME"; else echo "SOME DIFFER"; fi
exit "$status"
