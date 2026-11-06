#!/usr/bin/env bash
# t5_new_rerun.sh: rerun NEW steps 1-6 in a scratch copy and compare them
# with the NEW outputs committed at HEAD (T5 determinism check; plan T8's
# tests/e2e/test_new_rerun.sh is the gate this precedes).
#
# Usage (from anywhere):
#   RAC_SCRATCH=<scratch dir> bash docs/qa/T5/probes/t5_new_rerun.sh \
#       [--oldbasis] [--png]
# Copies the work tree (no .git, images*/, logs/, .claude) into a fresh
# RAC_SCRATCH/new_rerun_XXXXXX folder, deletes there the NEW outputs of
# steps 1-6, runs RAC_DATASET=new tools/run_pipeline.sh --steps 1-6 in the
# copy, and prints, for each output, SAME or DIFF against the HEAD blob:
# the 7 CSVs by sha256, the two models field by field (tests/lib/
# dump_models.R and compare_models.R: identical()), the 8 PDFs by the
# sha256 after their dates are removed (tests/lib/pdf_normalize.py).
# --oldbasis (T5 review fixes): also deletes the two OLD-basis refits
#   (A-112) in the copy, refits both from the rerun's CSV with
#   tools/fit_oldbasis_new.R (in parallel, about 11 minutes) and compares
#   them with HEAD field by field and byte for byte (.rds).
# --png (T5 review fixes): also draws the 8 NEW and the 8 OLD PNG twins
#   (tools/figures_png.R, A-111) from the copy into the run folder and
#   compares them byte for byte with docs/qa/T5/new/ and docs/qa/T5/old/ at
#   HEAD.
# Exit 0 only if every output is the same. Writes nothing into the
# repository; the run folder is kept for inspection.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../../../../tests/lib/scratch.sh
source "$here/../../../../tests/lib/scratch.sh"
repo=$rac_repo_root
oldbasis=0
png=0
for a in "$@"; do
  case $a in
    --oldbasis) oldbasis=1 ;;
    --png) png=1 ;;
    *)
      echo "t5_new_rerun.sh: unknown argument '$a'" >&2
      exit 2
      ;;
  esac
done
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
refits=(saved_models/new/NEW_X_NS_XY_oldbasis_new.rds
  saved_models/new/CML_MODEL_oldbasis_new.rds)
for f in "${csvs[@]}" "${models[@]}"; do rm "$run/repo/$f"; done
if [[ $oldbasis -eq 1 ]]; then
  for f in "${refits[@]}"; do rm "$run/repo/$f"; done
fi
rm "$run/repo"/model_images/new/*_new.pdf
mkdir -p "$run/head/saved_models/new"
for f in "${models[@]}" "${refits[@]}"; do
  git -C "$repo" show "HEAD:$f" > "$run/head/$f"
done
(cd "$run/repo" && RAC_DATASET=new bash tools/run_pipeline.sh --steps 1-6)
status=0
if [[ $oldbasis -eq 1 ]]; then
  pids=()
  for feature in NEW_X_NS_XY CML_MODEL; do
    (cd "$run/repo" && RAC_DATASET=new Rscript tools/fit_oldbasis_new.R \
      "$feature" > "$run/oldbasis_$feature.log" 2>&1) &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      echo "an OLD-basis refit failed (see $run/oldbasis_*.log)"
      status=1
    fi
  done
  grep -h '^fitted' "$run"/oldbasis_*.log || true
fi
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
if [[ $oldbasis -eq 1 ]]; then
  echo "== the OLD-basis refits (A-112)"
  for f in "${refits[@]}"; do
    if cmp -s "$run/repo/$f" "$run/head/$f"; then
      echo "SAME  $f (bytes)"
    else
      echo "DIFF  $f (bytes)"
      status=1
    fi
  done
  Rscript "$repo/tests/lib/dump_models.R" "${refits[@]/#/$run/head/}" \
    "$run/dump_refits_head.rds" "$run/dump_refits_head" > /dev/null
  Rscript "$repo/tests/lib/dump_models.R" "${refits[@]/#/$run/repo/}" \
    "$run/dump_refits_rerun.rds" "$run/dump_refits_rerun" > /dev/null
  if Rscript "$repo/tests/lib/compare_models.R" \
    "$run/dump_refits_head.rds" "$run/dump_refits_rerun.rds"; then
    echo "OLD-basis refits: every field identical()"
  else
    status=1
  fi
fi
if [[ $png -eq 1 ]]; then
  echo "== PNG twins (bytes: rerun vs HEAD)"
  for ds in new old; do
    (cd "$run/repo" && RAC_DATASET=$ds Rscript tools/figures_png.R \
      "$run/png/$ds" > "$run/png_$ds.log" 2>&1) || status=1
    for f in "$run/png/$ds"/*.png; do
      rel=docs/qa/T5/$ds/$(basename "$f")
      if git -C "$repo" show "HEAD:$rel" | cmp -s - "$f"; then
        echo "SAME  $rel"
      else
        echo "DIFF  $rel"
        status=1
      fi
    done
    n=$(find "$run/png/$ds" -name '*.png' | wc -l)
    echo "$ds: $n PNG twins drawn"
    if [[ $n -ne 8 ]]; then status=1; fi
  done
fi
if [[ $status -eq 0 ]]; then echo "ALL SAME"; else echo "SOME DIFFER"; fi
exit "$status"
