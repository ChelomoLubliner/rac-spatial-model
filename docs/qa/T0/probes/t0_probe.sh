#!/usr/bin/env bash
# T0 read-only probes (shell side). Run from the repo root:
#   bash docs/qa/T0/probes/t0_probe.sh <thesis_repo_root>
# Reads only. Git commands on the thesis repo use --no-optional-locks so
# that they never rewrite its index.
set -u
THESIS="$1"

echo "=== line endings of committed text outputs (CR count vs lines)"
for f in processed_data/dataCC.csv processed_data/dataCC_distance.csv \
         processed_data/dataCC_distance_temp.csv \
         processed_data/dataCC_distance_part4.csv \
         processed_data/shoe_pixel_counts.csv data/all_cont.csv \
         data/locations_data.csv data/new_shoes/locations_data_new_raw.txt \
         data/new_shoes/locations_new_snake_2023.csv; do
  printf '%-45s lines=%-6s CR=%s\n' "$f" "$(wc -l < "$f")" \
    "$(tr -cd '\r' < "$f" | wc -c)"
done

echo "=== 2026-03-16 regeneration of dataCC.csv / all_cont.csv: EOL only?"
for f in processed_data/dataCC.csv data/all_cont.csv; do
  feb=$(git show "6cdc0b9:$f" | tr -d '\r' | sha256sum | cut -c1-16)
  now=$(tr -d '\r' < "$f" | sha256sum | cut -c1-16)
  rawfeb=$(git show "6cdc0b9:$f" | sha256sum | cut -c1-16)
  rawnow=$(sha256sum < "$f" | cut -c1-16)
  echo "$f raw feb=$rawfeb now=$rawnow | LF-normalized feb=$feb now=$now"
done

echo "=== PDF metadata of committed figures"
for f in model_images/*.pdf; do
  printf '%-40s %s\n' "$f" \
    "$(strings "$f" | grep -E '^/(CreationDate|Producer)' | tr '\n' ' ')"
done

echo "=== thesis contour code: differs from HEAD only by CR?"
(
  cd "$THESIS" || exit 1
  echo "HEAD $(git --no-optional-locks rev-parse --short HEAD)"
  echo "files modified (raw): $(git --no-optional-locks status \
    --porcelain -- contour_algorithm/*.py | wc -l)"
  echo "diff ignoring CR at EOL (lines): $(git --no-optional-locks diff \
    --ignore-cr-at-eol -- contour_algorithm/*.py | wc -l)"
)

echo "=== thesis venvs (package versions)"
for d in "$THESIS/venv/lib/python3.12/site-packages" \
         "$THESIS/venv-wind/Lib/site-packages"; do
  echo "$d"
  for p in scikit_image numpy opencv_python pillow scipy matplotlib pandas; do
    find "$d" -maxdepth 1 -name "${p}-*.dist-info" -printf '  %f\n'
  done
done
grep -h '^version' "$THESIS/venv/pyvenv.cfg" "$THESIS/venv-wind/pyvenv.cfg" \
  | tr -d '\r'

echo "=== thesis 2025-11-13 run outputs (images/saved)"
ls -la --time-style=long-iso "$THESIS/images/saved"
ls -la --time-style=full-iso "$THESIS/data/contour_Active_Contour.txt"

echo "=== tools"
for t in flake8 shellcheck pandoc pdftoppm qpdf gs magick; do
  printf '%-10s %s\n' "$t" "$(command -v "$t" || echo MISSING)"
done
nproc
free -g | head -2
