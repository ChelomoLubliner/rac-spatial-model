# T0-architecture: results

**Date:** 2026-11-05. **Task:** architecture plan (no pipeline code changed). **Agent:** T0 architect.

T0 ships documents, so the checks below are (a) the read-only probes whose output backs every number in the plan, and (b) checks of the documents themselves. All outputs are pasted from the saved files or from the terminal, unedited. `<scratchpad>` stands for the session scratch directory `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`.

## 1. Restore the thesis repo (side effect of the interrupted first T0 run)

```bash
P=/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/contour_algorithm/__pycache__/extreme_values_x_y.cpython-312.pyc; ls -la --time-style=full-iso "$P" && rm -- "$P" && echo "removed stray pyc created 2026-11-05 18:36 by the interrupted T0 probe"; timeout 60 git -C /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint --no-optional-locks status --porcelain --ignored -- contour_algorithm/__pycache__ | head -5
```
```text
-rwxrwxrwx 1 mehes mehes 2173 2026-11-05 18:36:16.037754100 +0200 /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/contour_algorithm/__pycache__/extreme_values_x_y.cpython-312.pyc
removed stray pyc created 2026-11-05 18:36 by the interrupted T0 probe
!! contour_algorithm/__pycache__/
```
The folder is gitignored (`!!`); no tracked file of the thesis repo was changed. Decision A-023.

## 2. Evidence images before re-running the probes

```bash
mkdir -p /home/mehes/projects/rac-spatial-model/docs/qa/T0/probes && cd /home/mehes/projects/rac-spatial-model/docs/qa/T0 && sha256sum *.png | tee <scratchpad>/t0b/png_before.sha256
```
```text
dbf06a98873cc3ffba7ed018d2dbc6e2806c7087bca99c370eeb62ce35c71ecb  new_sheet_16_racs.png
6153807e4672240721318cd5cf90e00767f60ac18f6e31ee6d781e1f0bdf1619  new_superposition.png
7de8663d8a15e381162f98b1b2a6e651ac10cc293390611641d6af6733afbd7a  old_prototypes.png
41aa4b10cb13d5b01eb4dd0e96c5bc7e8ca9781f4f9f2797a3b39ec4b244baa9  old_rmask_stamps.png
```

## 3. Lint and run the probes (repo root; thesis venv python with `-I -B`)

```bash
cd /home/mehes/projects/rac-spatial-model && PY=/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python; TH=/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint; Q=docs/qa/T0/probes; flake8 $Q/*.py && echo "flake8 clean"; shellcheck $Q/t0_probe.sh && echo "shellcheck clean"; date '+start %F %T'; s=$(date +%s); timeout 900 "$PY" -I -B $Q/t0_probe.py "$PWD" "$TH/contour_algorithm" "$PWD/docs/qa/T0" > $Q/t0_probe.out 2>&1; echo "t0_probe.py exit $? in $(( $(date +%s) - s ))s"; s=$(date +%s); timeout 900 "$PY" -I -B $Q/t0_facts.py "$PWD" "$TH" > $Q/t0_facts.out 2>&1; echo "t0_facts.py exit $? in $(( $(date +%s) - s ))s"
```
```text
flake8 clean
shellcheck clean
start 2026-11-05 20:17:40
t0_probe.py exit 0 in 82s
t0_facts.py exit 0 in 17s
```
```bash
cd /home/mehes/projects/rac-spatial-model && Q=docs/qa/T0/probes; s=$(date +%s); timeout 900 Rscript $Q/t0_probe.R > $Q/t0_probe_R.out 2>&1; echo "t0_probe.R exit $? in $(( $(date +%s) - s ))s"; s=$(date +%s); timeout 900 bash $Q/t0_probe.sh /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint > $Q/t0_probe_sh.out 2>&1; echo "t0_probe.sh exit $? in $(( $(date +%s) - s ))s"; cd docs/qa/T0 && sha256sum -c <scratchpad>/t0b/png_before.sha256
```
```text
t0_probe.R exit 0 in 8s
t0_probe.sh exit 0 in 6s
new_sheet_16_racs.png: OK
new_superposition.png: OK
old_prototypes.png: OK
old_rmask_stamps.png: OK
```
The probes regenerate the four evidence PNGs byte-identically. `t0_probe.sh` was then changed to strip the CR that the Windows venv's `pyvenv.cfg` carries, and re-run:

```bash
cd /home/mehes/projects/rac-spatial-model && Q=docs/qa/T0/probes && flake8 $Q/*.py && echo "flake8 clean" && shellcheck $Q/t0_probe.sh && echo "shellcheck clean" && s=$(date +%s) && timeout 900 bash $Q/t0_probe.sh /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint > $Q/t0_probe_sh.out 2>&1; echo "t0_probe.sh exit $? in $(( $(date +%s) - s ))s"; printf 'CR in t0_probe_sh.out: %s\n' "$(tr -cd '\r' < $Q/t0_probe_sh.out | wc -c)"; python3 $Q/t0_doc_checks.py; echo "doc checks exit $?"
```
```text
flake8 clean
shellcheck clean
t0_probe.sh exit 0 in 6s
CR in t0_probe_sh.out: 0
1. tracked artifacts: 25 | missing from the table: []
2. NEW paths in the table: 55 | violating the rule: []
3. mermaid: subgraph=3 end=3 labelled nodes=32 edges=43
RESULT: PASS
doc checks exit 0
```
(An earlier inline version of these checks, run before the naming table was corrected, flagged six NEW paths: shorthand such as `superposed_min_<t>_new.npy/.png`, bare names such as `CI_cut_110_new.pdf`, and `logs/new/...`. They were rewritten as full paths, and the checks were saved as `t0_doc_checks.py` before this run.)

## 4. Probe outputs (verbatim)

### 4.1 `docs/qa/T0/probes/t0_probe.out`
```text

=== A. raw file structure
old contacts: bytes=46930329 expected=46930329 separators={b'\r\n'} values=[0, 1]
old contour: bytes=46809062 expected=46809062 separators={b'\r\n'} values=[0, 1]
new contacts: bytes=59053397 expected=59053397 separators={b'\r\n'} values=[0, 1]

=== B. RAC locations
old: RACs=13287 shoes=386 missing=[127]
new: RACs=20013 shoes=631 missing=[]
new RACs/shoe: min=1 median=24.0 mean=31.72 max=281
first RAC raw x=-0.409554 2023 x=-0.204777 ratio=2.000000; max |raw/2 - 2023| x=0.00e+00 y=0.00e+00
new coords /2: x in [-0.2390, 0.1701], y in [-0.5147, 0.4983]; old: x in [-0.2330, 0.1721], y in [-0.5025, 0.4961]

=== C. contact pixels per shoe
old: min=3729 median=10266.0 max=19672
new: min=1343 median=8924.0 max=19145
new smallest 8 (shoe, px): [(428, 1343), (163, 1376), (8, 2016), (375, 2963), (359, 2965), (112, 2988), (165, 3070), (286, 3154)]

=== D. pixel calibration feasibility
old legacy R aspix mapping: RACs on contact = 0.8479
old best (rate, s, mirror_x, flip_y, dc, dr): (np.float64(0.8816), 300, True, False, -1, -1)
new coarse best (rate, s, mirror_x, flip_y, dc, dr): (np.float64(0.7534), 300, True, False, 0, 0)
new fine top5 (rate, sx, sy, dc, dr): [(np.float64(0.8352), 298, 300, -1, -1), (np.float64(0.8345), 296, 300, -1, -1), (np.float64(0.8343), 300, 300, -1, -1), (np.float64(0.8328), 294, 300, -1, -1), (np.float64(0.8318), 298, 302, -1, -1)]
new 2023 COL/ROW (1-indexed) on contact = 0.8078

=== E. left/right (flip) score: corr with mean shoe, flipped/orig
old: top=[(9, 1.164), (127, 1.022), (237, 0.989), (222, 0.988)] n(ratio>1)=2
new: top=[(618, 0.989), (498, 0.989), (27, 0.987), (274, 0.987)] n(ratio>1)=0

=== F. committed OLD contour vs contact (row-span fill)
shoe 9 coverage: unflipped=0.977 flipped=0.700
coverage over 386: min=0.700 p5=0.947 median=1.000; worst=[(9, 0.7), (150, 0.889), (241, 0.912), (239, 0.917)]
contour pixels/shoe: min=614 median=700.0 max=742

=== G. contour_prototype.png vs freq_min_18.png
freq_min_18 px=32975 contour_prototype px=748 xor(4-boundary)=0 xor(get_contour)=1

=== H. cleaning masks
old: all_cont px=28609 >=8 px=29719 removed by sweep=1110 all_cont outside freq_min_18=0 freq_min_18 outside all_cont=4366
new: max overlap=466 union px=36894
new t=8: px=29536 components=6 outside main=7
new t=13: px=28949 components=2 outside main=1
new t=18: px=28559 components=1 outside main=0
new t=29: px=27881 components=1 outside main=0

=== I. evidence images written
/home/mehes/projects/rac-spatial-model/docs/qa/T0/old_prototypes.png (2492, 790)
/home/mehes/projects/rac-spatial-model/docs/qa/T0/old_rmask_stamps.png (614, 790)
/home/mehes/projects/rac-spatial-model/docs/qa/T0/new_superposition.png (2076, 734)
/home/mehes/projects/rac-spatial-model/docs/qa/T0/new_sheet_16_racs.png (2040, 734)
sheet shoes: [428, 163, 8, 375, 359, 112, 165, 286, 22, 91, 296, 320, 473, 519, 596, 599]
```

### 4.2 `docs/qa/T0/probes/t0_facts.out`

The first line is an OpenCV warning on stderr: the legacy code passes a float64 array to `cv2.imencode`, which falls back to 8-bit, as in the thesis runs.

```text
[ WARN:0@12.945] global loadsave.cpp:1617 imencodeWithMetadata Unsupported depth image for selected encoder is fallbacked to CV_8U.

=== J. provenance of the committed OLD contour
thesis images/saved/active-contour_all.npy shape (387, 395, 307)
committed contour records equal to that npy (skip 0-idx 126): 386 of 386
thesis list_matrices[8] == raw shoe 9 unflipped: True | == flipped: False
thesis freq_min_18.npy == repo data/freq_min_18.png: True | px 32975 | old_freq_min_18.npy (superposition >=18) px 27312

=== K. coordinate frames, shoe 9, duplicates, 2023 mapping
old corr(x in locations_data.csv, x of the RAC pixel in the R dataCC frame) = -0.999941
old shoe 9: RACs 2 | on contact unflipped 0.0 | flipped 0.0
old RACs 13287 | duplicate RAC pixels 38 | RAC pixels 13249
new raw sorted by shoe: True | rac_num consecutive from 1 in every shoe: True
new type values: {1: 8533, 2: 10019, 3: 455, 4: 350, 5: 135, 6: 419, 7: 102}
new legacy-generalized pixels in bounds: 20013 of 20013 | duplicate RAC pixels 23 | RAC pixels 19990
new legacy-generalized mapping: RACs on raw contact = 0.8078
2023 columns: ['shoe', 'rac_num', 'x', 'y', 'type', 'COL', 'ROW', 'INSIDE_SNAKE', 'HORIZ_DIST_SNAKE', 'DIST_SNAKE', 'INSIDE_CONV', 'HORIZ_DIST_CONV', 'DIST_CONV']
2023 COL == legacy-generalized col: True | ROW == legacy-generalized row: True

=== L. prototype extents vs legacy init ellipses (0-indexed px)
old data/freq_min_18.png (snake-filled): rows 36-353 cols 95-225 centroid (r=195.5, c=156.8) px=32975
old superposition >=18 (no flip, as in the Python run): rows 44-347 cols 102-219 centroid (r=194.4, c=157.9) px=27312
new superposition >=18: rows 27-335 cols 74-196 centroid (r=180.5, c=132.2) px=28559
new superposition >=29: rows 28-334 cols 75-195 centroid (r=180.7, c=132.1) px=27881
old init ellipse: rows 38-362 cols 65-245 (center 200,155 radii 162,90)
new init ellipse: rows 23-347 cols 33-223 (center 185,128 radii 162,95)
old contact px/shoe p5/p50/p95: [6245, 10266, 16146]
new contact px/shoe p5/p50/p95: [4876, 8924, 14286]

=== M. legacy get_snake_image orientation for non-square images
W,H=307,395: shape (395, 307) | (row 50, col 20) set True | (row 300, col 200) set True | swapped (row 20, col 50) set False
W,H=255,367: shape (367, 255) | (row 50, col 20) set True | (row 300, col 200) set True | swapped (row 20, col 50) set False
```

### 4.3 `docs/qa/T0/probes/t0_probe_R.out`

```text
=== R environment
R version 4.3.3 (2024-02-29) 
BLAS: /usr/lib/x86_64-linux-gnu/blas/libblas.so.3.12.0 
LAPACK: /usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3.12.0 
RNGkind: Mersenne-Twister Inversion Rejection 
rmarkdown   installed=TRUE  2.29
knitr       installed=TRUE  1.50
lme4        installed=TRUE  1.1.38
survival    installed=TRUE  3.8.3
splines     installed=TRUE  4.3.3
imager      installed=TRUE  1.0.8
fields      installed=TRUE  17.1
smoothie    installed=TRUE  1.0.4
plotly      installed=TRUE  4.12.0
rgl         installed=TRUE  1.3.24
dplyr       installed=TRUE  1.1.4
ggplot2     installed=TRUE  4.0.0
data.table  installed=TRUE  1.17.8
doParallel  installed=TRUE  1.0.17
jsonlite    installed=TRUE  2.0.0
digest      installed=TRUE  0.6.37
png         installed=TRUE  0.1.8
boot        installed=TRUE  1.3.30
car         installed=FALSE 
hglm        installed=FALSE 
testthat    installed=FALSE 
sandwich    installed=FALSE 
pdftools    installed=FALSE 
magick      installed=FALSE 

=== committed model files (serialization info)
saved_models/NEW_X_NS_XY.rds : writer R 4.4.3 
saved_models/CML_MODEL.rds : writer R 4.3.3 

=== committed GLMM NEW_X_NS_XY
class: glmerMod  optimizer: nlminbwrap  conv: 0 
nobs: 51849  groups: 386  n fixef: 25 
sigma^2 = 0.9597791  exp(-s2/2) = 0.6189  exp(+s2/2) = 1.6159
manual Wald (all 24 spatial coef = 0): W = 428.6933 df = 24 p = 9.43e-76
first fixef names:
[1] "(Intercept)"                                                   
[2] "ns(dat$new_x, knots = knots_new_x)1:ns(dat$y, knots = knotsy)1"
[3] "ns(dat$new_x, knots = knots_new_x)2:ns(dat$y, knots = knotsy)1"

=== committed CML_MODEL
class: clogit coxph  n coef: 24 

=== committed processed data consistency
dataCC rows: 51849  cases: 13249  shoes: 386 
dataCC_distance rows: 51849  same (n_Acc,x,y,shoe): TRUE 
controls per shoe (unique): 100 
pixel counts: n=386 mean=10571.8135 MEAN_OFFSET=-4.614310784 log(100/mean)=-4.6608
knots new_x: -0.0663992  0.0219597  0.1047822 
knots y    : -0.325000 -0.178333  0.095000  0.208333  0.321667 
range new_x: -0.191667  0.241667  range y: -0.501667  0.511667 

=== R semantics used by the legacy stamp sweep
logical(0) && TRUE  -> NA 
logical(0) && FALSE -> FALSE 

=== float semantics of abs(dy) < 0.01 in dataCC_distance_2.Rmd
|drow| = 2: pairs with abs(dy) < 0.01: 393 of 393
|drow| = 3: pairs with abs(dy) < 0.01: 160 of 392
|drow| = 4: pairs with abs(dy) < 0.01: 0 of 391

=== legacy stamp sweep (dataCC_1.Rmd lines 93-136) on NEW dims
new t=8: >=t px=29536 | sweep with legacy bound 300: ERROR: subscript out of bounds | with bound col_shoe=255: kept px=29532 removed=4
new t=13: >=t px=28949 | sweep with legacy bound 300: ERROR: subscript out of bounds | with bound col_shoe=255: kept px=28948 removed=1
```

### 4.4 `docs/qa/T0/probes/t0_probe_sh.out`

```text
=== line endings of committed text outputs (CR count vs lines)
processed_data/dataCC.csv                     lines=51850  CR=51850
processed_data/dataCC_distance.csv            lines=51850  CR=0
processed_data/dataCC_distance_temp.csv       lines=51850  CR=0
processed_data/dataCC_distance_part4.csv      lines=20970  CR=20970
processed_data/shoe_pixel_counts.csv          lines=387    CR=387
data/all_cont.csv                             lines=396    CR=396
data/locations_data.csv                       lines=13288  CR=13288
data/new_shoes/locations_data_new_raw.txt     lines=20013  CR=20013
data/new_shoes/locations_new_snake_2023.csv   lines=20014  CR=20014
=== 2026-03-16 regeneration of dataCC.csv / all_cont.csv: EOL only?
processed_data/dataCC.csv raw feb=d7b292f92251bb36 now=cc4a476976aea2a8 | LF-normalized feb=d7b292f92251bb36 now=d7b292f92251bb36
data/all_cont.csv raw feb=488e728d693defbe now=d582cf502184393d | LF-normalized feb=488e728d693defbe now=488e728d693defbe
=== PDF metadata of committed figures
model_images/CI_cut_110.pdf              /CreationDate (D:20260316125710) /Producer (R 4.4.3) 
model_images/CI_cut_190.pdf              /CreationDate (D:20260316125711) /Producer (R 4.4.3) 
model_images/CI_cut_250.pdf              /CreationDate (D:20260316125711) /Producer (R 4.4.3) 
model_images/CI_shoe_cuts.pdf            /CreationDate (D:20260316125707) /Producer (R 4.4.3) 
model_images/CML_MODEL_SHOE.pdf          /CreationDate (D:20260316130410) /Producer (R 4.4.3) 
model_images/NEW_X_NS_XY_SHOE.pdf        /CreationDate (D:20260316131759) /Producer (R 4.4.3) 
model_images/difference_random_cml.pdf   /CreationDate (D:20260319105147) /Producer (R 4.4.3) 
model_images/pixel_inten_JASAup.pdf      /CreationDate (D:20260319105145) /Producer (R 4.4.3) 
=== thesis contour code: differs from HEAD only by CR?
HEAD 109f30a
files modified (raw): 11
diff ignoring CR at EOL (lines): 0
=== thesis venvs (package versions)
/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/lib/python3.12/site-packages
  scikit_image-0.25.2.dist-info
  numpy-2.2.6.dist-info
  opencv_python-4.12.0.88.dist-info
  pillow-12.0.0.dist-info
  scipy-1.16.3.dist-info
  matplotlib-3.10.7.dist-info
  pandas-2.3.3.dist-info
/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv-wind/Lib/site-packages
  scikit_image-0.25.2.dist-info
  numpy-2.2.6.dist-info
  opencv_python-4.12.0.88.dist-info
  pillow-12.0.0.dist-info
  scipy-1.16.3.dist-info
  matplotlib-3.10.7.dist-info
  pandas-2.3.3.dist-info
version = 3.12.3
version = 3.13.9
=== thesis 2025-11-13 run outputs (images/saved)
total 138528
drwxrwxrwx 1 mehes mehes     4096 2026-02-08 10:36 .
drwxrwxrwx 1 mehes mehes     4096 2025-11-13 12:20 ..
-rwxrwxrwx 1 mehes mehes        0 2025-11-13 11:54 .gitkeep
-rwxrwxrwx 1 mehes mehes 46929683 2025-11-13 07:50 active-contour_all.npy
-rwxrwxrwx 1 mehes mehes     1764 2025-11-13 07:41 all_shoes_superposed.png
-rwxrwxrwx 1 mehes mehes   121393 2025-11-13 07:41 freq_min_18.npy
-rwxrwxrwx 1 mehes mehes    50340 2026-02-08 13:03 freq_min_18.pdf
-rwxrwxrwx 1 mehes mehes      767 2025-11-13 07:41 freq_min_18.png
-rwxrwxrwx 1 mehes mehes 46929683 2025-11-13 07:42 list_contour.npy
-rwxrwxrwx 1 mehes mehes 46929683 2025-11-13 07:41 list_matrices.npy
-rwxrwxrwx 1 mehes mehes   741787 2025-11-13 11:54 locations_new.csv
-rwxrwxrwx 1 mehes mehes   121393 2025-11-13 07:41 old_freq_min_18.npy
-rwxrwxrwx 1 mehes mehes      870 2025-11-13 07:41 old_freq_min_18.png
-rwxrwxrwx 1 mehes mehes 46809062 2025-11-13 11:54:31.716860900 +0200 /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/data/contour_Active_Contour.txt
=== tools
flake8     /home/mehes/.local/bin/flake8
shellcheck /home/mehes/.local/bin/shellcheck
pandoc     /usr/bin/pandoc
pdftoppm   MISSING
qpdf       MISSING
gs         MISSING
magick     MISSING
16
               total        used        free      shared  buff/cache   available
Mem:              15           6           0           0           8           8
```

## 5. Final document checks (run while assembling this file)

```bash
cd /home/mehes/projects/rac-spatial-model
head -2 docs/plans/2026-11-05-new-shoes-pipeline.md
for f in docs/plans/2026-11-05-new-shoes-pipeline.md docs/README.md docs/decisions.md docs/progress/LOG.md docs/tests/README.md docs/qa/T0/README.md docs/qa/T0/probes/*; do printf '%s %s\n' "$(tr -cd '\r' < "$f" | wc -c)" "$f"; done
flake8 docs/qa/T0/probes/*.py && echo "flake8 clean"
shellcheck docs/qa/T0/probes/t0_probe.sh && echo "shellcheck clean"
python3 docs/qa/T0/probes/t0_doc_checks.py
```
```text
# Plan: Run the full RAC pipeline on the new 631-shoe dataset and validate it
**Date:** 2026-11-05
0 docs/plans/2026-11-05-new-shoes-pipeline.md
0 docs/README.md
0 docs/decisions.md
0 docs/progress/LOG.md
0 docs/tests/README.md
0 docs/qa/T0/README.md
0 docs/qa/T0/probes/t0_doc_checks.py
0 docs/qa/T0/probes/t0_facts.out
0 docs/qa/T0/probes/t0_facts.py
0 docs/qa/T0/probes/t0_probe.R
0 docs/qa/T0/probes/t0_probe.out
0 docs/qa/T0/probes/t0_probe.py
0 docs/qa/T0/probes/t0_probe.sh
0 docs/qa/T0/probes/t0_probe_R.out
0 docs/qa/T0/probes/t0_probe_sh.out
flake8 clean
shellcheck clean
1. tracked artifacts: 25 | missing from the table: []
2. NEW paths in the table: 55 | violating the rule: []
3. mermaid: subgraph=3 end=3 labelled nodes=32 edges=43
RESULT: PASS
```
Meaning: lines 1-2 of the plan are exactly as required; no CR in any T0 document or script; every tracked artifact under `data/`, `processed_data/`, `saved_models/`, `model_images/`, `reports/` appears in the plan's naming table; every NEW output path has a `new` folder and a `_new` stem; the mermaid block is balanced. This results file itself is checked for CR bytes after it is written (see the LOG entry).

## 6. What was not tested
- No pipeline code exists yet for the new dataset, so T0 has no unit tests; the plan names them per task.
- The mermaid diagram was checked for balance and read for syntax, not rendered (no renderer installed; not required).
