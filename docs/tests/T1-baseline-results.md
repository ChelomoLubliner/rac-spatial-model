# T1 results: baseline and reproduction (OLD dataset)

**Date:** 2026-11-05/06. **Branch:** `feature/new-shoes-pipeline`. **Task:** T1 of `docs/plans/2026-11-05-new-shoes-pipeline.md`.
**Scratch:** `<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`; the T1 runs are in `<scratch>/t1/` (`RAC_SCRATCH=<scratch>/t1`).
Every output below is pasted from the real run; long outputs are trimmed only where marked `[... omitted ...]` or `...`. Absolute scratch paths in pasted output are shortened to `<scratch>`, `<run>` (a run folder) or `<venv>` (the thesis venv), and trailing spaces are dropped; nothing else is edited.

## 0. Summary

| Artifact | Tier A (committed at `79247d8`) reproduced on WSL? | Tier B (unmodified code on WSL) | Evidence and cause |
|---|---|---|---|
| `data/contour_Active_Contour.txt` | **No: 30 of 386 records differ** (19,027 px; mean distance per record at most 1.50 px, max 8.94 px). **Yes under the thesis Windows venv: 386 of 386 records identical** | `tests/baseline/local/python_contour.sha256`; Tier A plus `contour_linux_diff.npz` | Platform numerics (4.4), A-060 |
| `data/freq_min_18.png` | Pixels identical, bytes differ (807 vs 767) | intermediates sha256 | PNG encoder: zlib-ng build of the Pillow wheel (4.2), A-054 |
| `data/contour_prototype.png` | Pixels identical to the 4-boundary of the regenerated mask (748 px); the pipeline does not write this file | n/a | 4.3 |
| Python intermediates (`list_matrices.npy`, `old_freq_min_18.npy`, `freq_min_18.npy`, `list_contour.npy`) | Byte-identical to the thesis 2025-11-13 run | sha256 | 4.3 |
| `active-contour_all.npy`, `active-contour/*.png` | 30 snake arrays (the same 30 shoes) and 31 renders differ from the thesis run | sha256 | 4.3, 4.4 |
| `data/all_cont.csv`, `processed_data/dataCC.csv`, `processed_data/shoe_pixel_counts.csv` (step 1) | Same content; written LF on Linux; **LF -> CRLF gives the committed bytes exactly** | `r_outputs.sha256` | 5.2, A-005 confirmed |
| `processed_data/dataCC_distance_temp.csv`, `dataCC_distance.csv` (step 2) | **Byte-identical** | `r_outputs.sha256` | 5.2 |
| `processed_data/dataCC_distance_part4.csv` | Untouched (no code writes it, K7) | n/a | 5.2 |
| `saved_models/CML_MODEL.rds` | **`identical()` in every field** (coef, vcov, loglik, n, nevent, iter); the .rds bytes differ (serialized environments) | `models_local.rds` | 5.3 |
| `saved_models/NEW_X_NS_XY.rds` | **No:** max abs fixef diff 7.666e-4, sigma^2 0.95979590 vs 0.95977909, logLik diff 1.15e-6; no Hessian, so `vcov()` = RX: W 427.7804 vs 428.6933. **Yes, bit for bit, with the Windows R 4.4.3 + lme4 1.1-37 + Matrix 1.7-2** | `models_local.rds` (two WSL reruns `identical()`) | lme4 1.1-38 derivative rule (5.3), A-055 |
| 8 PDFs (steps 4-6) | Bytes differ (Producer R 4.4.3 vs 4.3.3, embedded dates, GLMM); visually identical; plotted matrices differ by at most 1.6e-7 | `pdf_normalized.sha256` (identical in two WSL reruns) | 5.5 |
| Wald test, all 24 spatial coefficients = 0 | **428.69 reproduced** on the committed GLMM by the manual test (= car to 4.8e-15) | 427.7804 on the WSL refit | 5.4 |

Gate: `bash tests/run_all.sh` passes (section 3.1): 20 Python tests (1 skipped by design), 3 R test scripts, 2 checksum files, unchanged work tree.

## 1. Environment

`tests/baseline/local/environment.txt` (written by `bash tests/lib/write_environment.sh`). Main lines:

```text
Linux Taxes67-lp 6.18.54.1-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Tue Oct  6 19:13:07 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
PRETTY_NAME="Ubuntu 24.04.2 LTS"
16
this repo: e4fedce3f5221591beb2317898a19964019f1c4c (feature/new-shoes-pipeline)
thesis repo HEAD: 109f30a0217aab16e35a31aaed628a555f57031d
lme4        1.1.38
Matrix      1.6.5
car installed: FALSE
R version 4.3.3 (2024-02-29)
pandoc: pandoc 3.1.3
## Python (WSL thesis venv: /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python)
3.12.3 (main, Jan  8 2026, 11:30:50) [GCC 13.3.0]
## Python (Windows venv-wind, diagnostics only: ...)
3.13.14 (tags/v3.13.14:fd17997, Jun 10 2026, 13:03:48) [MSC v.1944 64 bit (AMD64)]
## R (Windows, diagnostics only: /mnt/c/Users/mehes/AppData/Local/Programs/R/R-4.4.3/bin/Rscript.exe)
lme4 1.1.37
Matrix 1.7.2
survival 3.8.3
car 3.1.3
R version 4.4.3 (2025-02-28 ucrt)
```
Both venvs have numpy 2.2.6, scipy 1.16.3, scikit-image 0.25.2, opencv-python 4.12.0.88, pillow 12.0.0, matplotlib 3.10.7, pandas 2.3.3, plotly 6.4.0 (venv-wind also has black, ruff and other dev tools). `contour_algorithm/requirements-lock.txt` = the WSL venv's `pip freeze`. The Windows interpreters were used only for read-only diagnostics (they read the repo through `\\wsl.localhost\Ubuntu\...` and wrote only to `<scratch>/t1`, except the gallery, which they wrote into `docs/qa/sheets_old/`, A-061).

## 2. Tier A

### 2.1 Checksums and EOL table
```bash
bash tests/lib/make_tier_a.sh
```
```text
files: 24 (all), 11 (old_baseline)
```
`tests/baseline/committed_79247d8.sha256` (24 lines) comes from the git blobs (`git cat-file blob 79247d8:<path> | sha256sum`), and the script exits 1 if a work-tree file differs from its blob (it did not). `old_baseline.sha256`:
```text
d582cf502184393d015f6d5c8b0c92a154657e21b9cd0471279da348b39d6eeb  data/all_cont.csv
ca8a07f2a46614a14383a8017b688663caba8350c3ea41c51792d8ebd0ec7e56  data/contour_Active_Contour.txt
f92e20c6f63574df52928cfbdc7c7dbd2de18874c25b0a2b3e7db3c1287efdef  data/contour_prototype.png
1fad0446f705d5a414b85f6c651901fad253b9830f479c8ea0d9c272bffe4496  data/freq_min_18.png
cc4a476976aea2a81e6df1363ada209c75954c81c6d6deb9c4b634d5b32f643a  processed_data/dataCC.csv
f0e697ac6f793de4b06cf39f4b044691631abd94b8a044a4dd254143f29804bf  processed_data/dataCC_distance.csv
f06b7201edec585c4f885f40792ef41170cf1f720af0bb2e1cda4fe682fccc67  processed_data/dataCC_distance_part4.csv
43d7c9b87946e1bb761be538c8e0f8dcb335c06d0186862c7c4b04a507c7f91f  processed_data/dataCC_distance_temp.csv
24bbd19cff59ecd961ee8ee7c26dc48816e6c04b7ff706d294351f5eb776faed  processed_data/shoe_pixel_counts.csv
17b545286c00ab6a7816fe95bd448f67d1647f73a8f8d758bf94faea5e3336bb  saved_models/CML_MODEL.rds
ae670fd392cef406b4170aa2a1480fe4b5e9c6cc1969ef0e5df21aa7bcd9fb57  saved_models/NEW_X_NS_XY.rds
```
EOL table (`committed_79247d8_eol.tsv`, text files; counts made in Python):
```text
path                                         bytes     kind    lf     cr     crlf
data/all_cont.csv                            244967    text    396    396    396
data/contacts_data.txt                       46930329  text    387    387    387
data/contour_Active_Contour.txt              46809062  text    386    386    386
data/locations_data.csv                      597502    text    13288  13288  13288
data/new_shoes/contacts_data_new.txt         59053397  text    631    631    631
data/new_shoes/locations_data_new_raw.txt    590942    text    20013  20013  20013
data/new_shoes/locations_new_snake_2023.csv  1328988   text    20014  20014  20014
processed_data/dataCC.csv                    1874286   text    51850  51850  51850
processed_data/dataCC_distance.csv           5676340   text    51850  0      0
processed_data/dataCC_distance_part4.csv     1921852   text    20970  20970  20970
processed_data/dataCC_distance_temp.csv      3927351   text    51850  0      0
processed_data/shoe_pixel_counts.csv         3974      text    387    387    387
[... 12 binary files (png, pdf, rds) omitted ...]
```

### 2.2 Model dumps
```bash
Rscript tests/lib/dump_models.R saved_models/NEW_X_NS_XY.rds saved_models/CML_MODEL.rds \
  tests/baseline/models_committed.rds tests/baseline/old_model_summary
```
`tests/baseline/old_model_summary.txt` (140 values at `%.17g`; the plan's `models_committed.txt`), selected lines:
```text
glmm file: saved_models/NEW_X_NS_XY.rds (sha256 ae670fd392cef406b4170aa2a1480fe4b5e9c6cc1969ef0e5df21aa7bcd9fb57)
cml file:  saved_models/CML_MODEL.rds (sha256 17b545286c00ab6a7816fe95bd448f67d1647f73a8f8d758bf94faea5e3336bb)
dumped with R version 4.3.3 (2024-02-29), lme4 1.1.38, survival 3.8.3
glmm optimizer: nlminbwrap; cml method: exact
glmm  fixef           1 -2.2715823477346397  (Intercept)
glmm  fixef           2 -0.21472901657102511  ns(dat$new_x, knots = knots_new_x)1:ns(dat$y, knots = knotsy)1
glmm  theta           1 0.97968315749449331
glmm  sigma2          1 0.95977908907838017  shoe
glmm  loglik          1 -25819.283941935646  logLik
glmm  nobs            1 51849  nobs
glmm  ngrps           1 386  shoe
glmm  wald            1 428.69333500107194  W_vcov_default
glmm  wald            1 427.76741927371535  W_vcov_rx
cml   loglik          2 -24182.091775000976  model
cml   nevent          1 13249  nevent
cml   wald            1 420.67124200351526  W
```

## 3. Tests

### 3.1 The fast suite
```bash
bash tests/run_all.sh
```
```text
== sha256 committed_79247d8 (Tier A, 24 files)
== sha256 old_baseline (11 OLD artifacts)
== python unittest discover tests/python
[... 15 lines omitted: test_baseline_raw_data (5), test_pdf_normalize (4), test_scratch_lib (6), all "ok" ...]
test_full_rerun_recorded (tests.python.test_snake_old_regression.SnakeOld.test_full_rerun_recorded) ... ok
test_full_run_folder (tests.python.test_snake_old_regression.SnakeOld.test_full_run_folder) ... skipped 'set RAC_REGRESS_PY_RUN to a legacy run folder'
test_inputs (tests.python.test_snake_old_regression.SnakeOld.test_inputs) ... ok
test_platform_sensitive_records (tests.python.test_snake_old_regression.SnakeOld.test_platform_sensitive_records) ... [ WARN:0@16.232] global loadsave.cpp:1617 imencodeWithMetadata Unsupported depth image for selected encoder is fallbacked to CV_8U.
ok
test_reproduces_committed_records (tests.python.test_snake_old_regression.SnakeOld.test_reproduces_committed_records) ... ok

----------------------------------------------------------------------
Ran 20 tests in 26.307s

OK (skipped=1)
== Rscript tests/r/test_baseline_committed.R
PASS glmm_structure (nobs 51849, 386 shoes, 25 fixef, conv 0, Hessian)
PASS glmm_manual_wald W = 428.6933 df = 24 p = 9.43e-76
PASS cml_structure (24 coefficients, exact, 13249 events)
PASS dataCC (51849 rows, 13249 cases, 386 shoes, 100 controls each)
PASS dataCC_distance (n_Acc, x, y, shoe) identical to dataCC
PASS config.R MEAN_OFFSET = -4.614310784
PASS models_committed.rds and old_model_summary.csv match the committed models
ALL PASS test_baseline_committed
== Rscript tests/r/test_old_regression.R
PASS Tier B step-2 CSVs byte-identical to Tier A
PASS Tier B step-1 CSVs = Tier A bytes after LF -> CRLF (raw: LF, differ)
PASS CML: Tier B identical() to Tier A in every field
PASS GLMM structure identical (nobs, groups, convergence, optimizer, names)
PASS GLMM differs from Tier A as recorded in T1: max|dfixef| 0.000767, W 427.7804 (Tier A 428.6933; RX 427.7674), sigma^2 0.95979590 (Tier A 0.95977909)
SKIPPED live rerun check: RAC_REGRESS_R_RUN not set
ALL PASS test_old_regression
== Rscript tests/r/test_wald.R
PASS committed GLMM: W = 428.693335, df = 24, p = 9.43e-76
PASS L-matrix form 428.6933350011 and Cholesky form 428.6933350011 agree
PASS explicit V = identity gives sum(b^2)
PASS committed CML: W = 420.671242, df = 24
PASS unsupported model class is an error
SKIPPED car comparison: car not installed
ALL PASS test_wald
== work tree unchanged by the tests (no file created or modified)

== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS        30s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS         3s  Rscript tests/r/test_wald.R
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS
```
Wall time 41.4 s. The skips are by design: the live-rerun checks need a run folder (`RAC_REGRESS_PY_RUN`, `RAC_REGRESS_R_RUN`), and car is absent on WSL. The OpenCV warning comes from `cv2.imencode` inside the legacy `get_snake_image()` and is harmless.

### 3.2 The optional branches, run once
```bash
RAC_REGRESS_PY_RUN=<scratch>/t1/legacy_py_MXmkvc MPLBACKEND=Agg <venv>/bin/python -B -m unittest tests.python.test_snake_old_regression -v
```
```text
Ran 5 tests in 24.395s
OK
```
(`test_full_run_folder` compared all 386 records of the WSL run with Tier B: 0 differing records.)
```bash
RAC_REGRESS_R_RUN=<scratch>/t1/legacy_r_oTZO3x Rscript tests/r/test_old_regression.R
```
```text
PASS live rerun: the five CSVs equal Tier B byte for byte
PASS live rerun: models identical() to Tier B in every field
ALL PASS test_old_regression
```
Under the Windows interpreters (from the repo root, through interop):
```bash
venv-wind/Scripts/python.exe -B -m unittest tests.python.test_snake_old_regression -v
```
```text
Ran 5 tests in 12.314s
OK (skipped=1)
```
(On Windows the platform-sensitive shoes 176 and 354 are compared with the committed records, and they pass.)
```bash
Rscript.exe '\\wsl.localhost\Ubuntu\home\mehes\projects\rac-spatial-model\tests\r\test_wald.R'
```
```text
PASS committed GLMM: W = 428.693335, df = 24, p = 9.43e-76
PASS L-matrix form 428.6933350011 and Cholesky form 428.6933350011 agree
PASS explicit V = identity gives sum(b^2)
PASS committed CML: W = 420.671242, df = 24
PASS unsupported model class is an error
PASS car::linearHypothesis W = 428.693335 equals the manual W
ALL PASS test_wald
```

## 4. Legacy Python (step 0)

The code is the thesis repo's `contour_algorithm/` at `109f30a` (`git show`, LF), copied into a fresh `mktemp` folder with copies of the two inputs; `Data -> data`; `MPLBACKEND=Agg`; `python -B main.py` (`tests/legacy/run_legacy_python.sh`). The same 12 files are now committed verbatim in `contour_algorithm/` (each `cmp`-identical to its blob; A-058).

### 4.1 Run 1: drvfs read failure
```bash
RAC_SCRATCH=<scratch>/t1 bash tests/legacy/run_legacy_python.sh   # -> <scratch>/t1/legacy_py_o4gTOt
```
```text
start 2026-11-05T23:38:16+02:00
end 2026-11-05T23:40:35+02:00
exit 1
seconds 139.471772929
[... logs/main.log ...]
  File ".../contour_algorithm/contour.py", line 20, in scatter_plot_contour
    pyo.plot(fig, filename=f'{FOLDER}extreme_values/plot_cont_{im_num}.html', auto_open=False)
  File "/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/lib/python3.12/site-packages/plotly/offline/offline.py", line 86, in get_plotlyjs
    plotlyjs = pkgutil.get_data("plotly", path).decode("utf-8")
  File "<frozen importlib._bootstrap_external>", line 1187, in get_data
OSError: [Errno 12] Cannot allocate memory
```
`free -m` at that time showed 7,714 MB available: a WSL drvfs failure while re-reading the 4.6 MB `plotly.min.js` from `/mnt/c` (about the 270th HTML file), not a code or memory problem. Fix (A-056): a `cp -a` copy of the venv on the Linux filesystem, verified with `diff -rq --no-dereference` (log: `cp_done 1144s`, `diff_identical 1826s`).

### 4.2 PNG bytes vs pixels (run 1 had finished its first step)
```text
list_matrices.npy (387, 395, 307) bool array_equal thesis: True bytes equal: True
old_freq_min_18.npy (395, 307) bool array_equal thesis: True bytes equal: True
freq_min_18.npy (395, 307) bool array_equal thesis: True bytes equal: True
freq_min_18.png pixels equal thesis: True mode 1 1 bytes equal: False
regenerated freq_min_18.png vs committed data/freq_min_18.png: pixels equal True diff px 0 committed sum 32975 mode 1
```
Root cause:
```text
Pillow 12.0.0 zlib 1.3 zlib-ng True                                   # WSL venv
Pillow 12.0.0 zlib 1.3.1.zlib-ng zlib_ng True                         # Windows venv-wind
data/freq_min_18.png [('IHDR', 13), ('IDAT', 710), ('IEND', 0)] ... decompressed IDAT bytes 15800 sha 87cc00e7892e5290
<run>/images/saved/freq_min_18.png [('IHDR', 13), ('IDAT', 750), ('IEND', 0)] ... decompressed IDAT bytes 15800 sha 87cc00e7892e5290
windows re-encode equals committed bytes: True 767 767 1fad0446f705d5a4
linux re-encode equals committed bytes: False 807 6aa7e1a748bf9321
```
Same IHDR and the same decompressed image data; only the compressor differs (A-054).

### 4.3 Run 2 (venv copy) and its comparison
```bash
RAC_SCRATCH=<scratch>/t1 RAC_VENV_PY=<scratch>/t1/venv_copy/bin/python bash tests/legacy/run_legacy_python.sh   # -> legacy_py_MXmkvc
```
```text
start 2026-11-06T00:13:54+02:00
end 2026-11-06T00:22:23+02:00
exit 0
seconds 508.964869598
	User time (seconds): 2925.79
	Elapsed (wall clock) time (h:mm:ss or m:ss): 8:28.95
	Maximum resident set size (kbytes): 516040
```
Loop times from the tqdm lines: reading the 387 records 22 s; cleaning, extreme values and plotly HTML 1 min 11 s; snakes 5 min 39 s; RAC locations and HTML 29 s. The HTML folders take 1.8 GB each.
```bash
<scratch>/t1/venv_copy/bin/python -B tests/lib/compare_legacy_python.py <scratch>/t1/legacy_py_MXmkvc \
  --thesis-images /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/images --write-tier-b tests/baseline/local
```
```text
## contour txt
committed: 46809062 bytes, 386 records, separator b'\r\n', sha256 ca8a07f2a46614a14383a8017b688663caba8350c3ea41c51792d8ebd0ec7e56
regenerated: 46808676 bytes, 386 records, separator b'\n', sha256 d43fda7eb631599eb1b7ebb8775e0c7d82c5ef40c9e5272165542c0f2f8aa917
regenerated with LF -> CRLF: sha256 e18d50df5da9599440c99f9fbb6f23ce98bdc695479a4078c06feb96b9b1b7c4; equals committed bytes: False
same number of records: True
records with any differing pixel: 30 of 386; total differing pixels: 19027
committed contour px per record: min 614, median 700, max 742
## prototype masks
freq_min_18.png: bytes equal False (767 vs 807 bytes); pixels equal True; differing px 0; mask px 32975 vs 32975
images/saved/freq_min_18.npy equals the committed PNG pixels: True
contour_prototype.png == inner 4-boundary of the committed mask: True (748 px)
contour_prototype.png == inner 4-boundary of the regenerated mask: True; differing px 0
## intermediates vs the thesis run (read-only)
list_matrices.npy: array equal True, bytes equal True, shape (387, 395, 307)
old_freq_min_18.npy: array equal True, bytes equal True, shape (395, 307)
freq_min_18.npy: array equal True, bytes equal True, shape (395, 307)
list_contour.npy: array equal True, bytes equal True, shape (387, 395, 307)
active-contour_all.npy: array equal False, bytes equal False, shape (387, 395, 307)
all_shoes_superposed.png: pixels equal True, bytes equal False
old_freq_min_18.png: pixels equal True, bytes equal False
freq_min_18.png: pixels equal True, bytes equal False
shoes/: 387 images; pixels differ in 0 []; bytes equal in 0
shoe_on_prototype/: 387 images; pixels differ in 0 []; bytes equal in 0
cleaned_shoes/: 387 images; pixels differ in 0 []; bytes equal in 0
active-contour/: 387 images; pixels differ in 31 [7, 10, 20, 25, 61, 68, 79, 95, 102, 116, 141, 151, 156, 162, 173, 175, 187, 191, 202, 206]; bytes equal in 0
## Tier B written to tests/baseline/local (1556 intermediate files hashed)
RESULT contour_identical=False masks_identical=True thesis_intermediates_identical=False
```
The 30 differing `active-contour_all.npy` arrays are exactly the 30 differing records (0-based 7, 10, 20, 25, 61, 68, 79, 95, 116, 141, 151, 156, 162, 173, 175, 187, 191, 202, 206, 220, 234, 265, 285, 322, 339, 348, 353, 369, 381, 383); shoe 127's snake (index 126) is identical. The 31st differing render (index 102, shoe 103, 226 px) has an identical rasterized contour: a sub-pixel change of the float snake alters only the anti-aliasing.

```bash
<scratch>/t1/venv_copy/bin/python -B tests/lib/contour_platform_diff.py <scratch>/t1/legacy_py_MXmkvc/data/contour_Active_Contour.txt tests/baseline/local/contour_linux_diff
```
```text
records differing: 30 of 386; differing px total 19027; rebuilt-from-npz sha matches: True
```
`tests/baseline/local/contour_linux_diff.csv`:
```text
record  shoe  differing_px  run_px  committed_px  mean_dist_px  max_dist_px
8       8     2             677     677           0.001         1.000
11      11    855           626     621           1.065         8.000
21      21    824           669     671           1.117         8.944
26      26    946           737     731           1.187         5.000
62      62    1304          672     670           1.099         2.236
69      69    222           708     708           0.178         3.162
80      80    947           727     726           0.932         3.606
96      96    744           705     705           0.590         2.828
117     117   4             718     718           0.003         1.000
141     142   42            680     678           0.032         1.000
151     152   1065          714     713           1.292         4.243
156     157   8             704     704           0.006         1.000
162     163   508           632     632           0.416         1.414
173     174   30            683     683           0.022         1.000
175     176   1402          716     712           1.151         6.083
187     188   12            709     709           0.008         1.000
191     192   106           693     691           0.079         1.414
202     203   1361          702     703           1.046         2.236
206     207   749           707     702           0.723         3.606
220     221   1308          719     717           1.167         3.606
234     235   781           685     690           0.676         2.236
265     266   227           691     692           0.165         1.414
285     286   668           711     705           0.718         3.162
322     323   1060          686     690           0.899         3.000
339     340   1359          710     717           1.495         3.606
348     349   303           610     615           0.254         2.000
353     354   18            694     694           0.013         1.000
369     370   181           699     704           0.126         1.000
381     382   1189          682     675           1.073         3.162
383     384   802           674     670           0.680         2.828
```

### 4.4 Platform diagnosis
The first gallery build (WSL) flagged 8 shoes whose re-run differs from the committed record while 6 test shoes matched, so the snake was re-run per shoe on both platforms (`tests/legacy/diag_snake_platform.py`).
```bash
MPLBACKEND=Agg <venv>/bin/python -B tests/legacy/diag_snake_platform.py . <work> <out.npz> 11 21 80 152 176 221 349 354 9 35
```
```text
Linux 3.12.3 numpy 2.2.6 scipy 1.16.3 skimage 0.25.2
shoe 11: differing px 855; re-run 626 committed 621 contour px; distance to the committed contour mean 1.065 max 8.000
shoe 21: differing px 824; re-run 669 committed 671 contour px; distance to the committed contour mean 1.117 max 8.944
shoe 80: differing px 947; re-run 727 committed 726 contour px; distance to the committed contour mean 0.932 max 3.606
shoe 152: differing px 1065; re-run 714 committed 713 contour px; distance to the committed contour mean 1.292 max 4.243
shoe 176: differing px 1402; re-run 716 committed 712 contour px; distance to the committed contour mean 1.151 max 6.083
shoe 221: differing px 1308; re-run 719 committed 717 contour px; distance to the committed contour mean 1.167 max 3.606
shoe 349: differing px 303; re-run 610 committed 615 contour px; distance to the committed contour mean 0.254 max 2.000
shoe 354: differing px 18; re-run 694 committed 694 contour px; distance to the committed contour mean 0.013 max 1.000
shoe 9: differing px 0; re-run 688 committed 688 contour px; distance to the committed contour mean 0.000 max 0.000
shoe 35: differing px 0; re-run 716 committed 716 contour px; distance to the committed contour mean 0.000 max 0.000
```
A second WSL run gave the same output; its npz is bit-identical to the first (`linux run1 vs run2 bit-identical (contours and float snakes): True`). The same command with `venv-wind/Scripts/python.exe` (57 s):
```text
Windows 3.13.14 numpy 2.2.6 scipy 1.16.3 skimage 0.25.2
shoe 11: differing px 0; re-run 621 committed 621 contour px; distance to the committed contour mean 0.000 max 0.000
[... shoes 21, 80, 152, 176, 221, 349, 354, 9: differing px 0 ...]
shoe 35: differing px 0; re-run 716 committed 716 contour px; distance to the committed contour mean 0.000 max 0.000
```
Float snakes, WSL vs Windows (max coordinate difference):
```text
shoe 11: max |linux - windows| first snake 1.69 px, second snake 7.07 px
shoe 21: max |linux - windows| first snake 23.3 px, second snake 9.16 px
shoe 80: max |linux - windows| first snake 1.08 px, second snake 2.85 px
shoe 152: max |linux - windows| first snake 4.21 px, second snake 3.38 px
shoe 176: max |linux - windows| first snake 3.13e-09 px, second snake 5.02 px
shoe 221: max |linux - windows| first snake 1.16 px, second snake 3.09 px
shoe 349: max |linux - windows| first snake 1.66 px, second snake 1.06 px
shoe 354: max |linux - windows| first snake 0.0476 px, second snake 0.174 px
shoe 9: max |linux - windows| first snake 6.9e-08 px, second snake 5.98e-11 px
shoe 35: max |linux - windows| first snake 5.67e-08 px, second snake 5.14e-11 px
```
For the identical contours the snakes still differ by about 1e-8 px (floating-point noise of the two numeric builds). For shoe 176 the first snakes differ by 3e-9 px, but the combined image built from them (via `np.int32` truncation in `cv2.polylines`) changes, and the second snake converges 5 px elsewhere. All 386 shoes under Windows (377 s; `tests/baseline/local/contour_windows_check.txt`):
```text
platform: Windows 3.13.14 numpy 2.2.6 scipy 1.16.3 skimage 0.25.2
records compared: 386
records with differing pixels: 0
exit 0 wall 377s
```
**Conclusion:** today's code reproduces the committed contour exactly on its original platform (Windows). On WSL it reproduces 356 of 386 records, and the other 30 differ by about one pixel. The flip of image 8 (K1) and the folder paths play no part: the WSL and Windows runs used the same code and inputs, and everything before the snake is identical. The committed files stay the baseline (A-060).

### 4.5 Tier B (Python)
`tests/baseline/local/python_contour.sha256`:
```text
d43fda7eb631599eb1b7ebb8775e0c7d82c5ef40c9e5272165542c0f2f8aa917  data/contour_Active_Contour.txt
e18d50df5da9599440c99f9fbb6f23ce98bdc695479a4078c06feb96b9b1b7c4  data/contour_Active_Contour.txt [LF->CRLF]
```
`python_intermediates.sha256`: 1,556 files (387 x 4 per-shoe PNGs and the 8 files of `images/saved/`). The plotly HTML files are not hashed (random div ids).

## 5. Legacy R (steps 1-6)

### 5.1 Runs and timings
```bash
RAC_SCRATCH=<scratch>/t1 bash tests/legacy/run_legacy_r.sh            # chain A -> legacy_r_oTZO3x
RAC_SCRATCH=<scratch>/t1 bash tests/legacy/run_legacy_r.sh 3,4,5,6    # chain B -> legacy_r_OB7DF8
```
Each chain extracts `git archive 79247d8` (data, processed_data, saved_models, model_images, statistical_model) into its run folder; steps 3 and 4 run once per `MODEL_FEATURE` (sed in the scratch `config.R`); step 5 runs the car-free variant (`tests/legacy/step5_without_car.R`):
```text
20d19
< library(car)
125,129c124,126
< testing <- linearHypothesis(random_model,
<                             hypothesis.matrix = matr,
<                             rhs = rep(0, length(co) - 1),
<                             test = c("Chisq", "F"),
<                             vcov. = vc, coef. = co)
---
> # T1 scratch variant: manual Wald test (car is not installed here).
> source(paste(ROOT_PATH, "statistical_model/R/wald.R", sep = ""))
> testing <- wald_all_spatial(random_model)
```
`timings.tsv` (seconds, exit status):

| Step | Chain A | Chain B |
|---|---|---|
| step1 (`dataCC_1.Rmd`) | 141.8, 0 | not run |
| step2 (`dataCC_distance_2.Rmd`) | 1133.8, 0 | not run |
| step3 GLMM (`NEW_X_NS_XY`) | 305.4, 0 | 281.0, 0 |
| step3 CML | 228.0, 0 | 230.1, 0 |
| step4 GLMM | 17.1, 0 | 16.0, 0 |
| step4 CML | 16.0, 0 | 14.2, 0 |
| step5 | 32.4, 0 | 29.5, 0 |
| step6 | 23.2, 0 | 20.6, 0 |

The knit logs hold no R warning or error; the only messages are pandoc's `[WARNING] This document format requires a nonempty <title> element` for Rmds without a YAML title. Other single-fit times measured: WSL GLMM with `calc.derivs = TRUE` 387.9 s (393 s CPU); Windows R GLMM 547.7 s.

### 5.2 CSVs (chain A vs Tier A)
```text
data/all_cont.csv                          raw_equal=no  LF-normalized_equal=yes regen_as_CRLF_equal_committed=yes mtime=2026-11-05 23:42:14
processed_data/dataCC.csv                  raw_equal=no  LF-normalized_equal=yes regen_as_CRLF_equal_committed=yes mtime=2026-11-05 23:42:14
processed_data/shoe_pixel_counts.csv       raw_equal=no  LF-normalized_equal=yes regen_as_CRLF_equal_committed=yes mtime=2026-11-05 23:40:15
processed_data/dataCC_distance_temp.csv    raw_equal=yes LF-normalized_equal=yes regen_as_CRLF_equal_committed=no  mtime=2026-11-06 00:00:48
processed_data/dataCC_distance.csv         raw_equal=yes LF-normalized_equal=yes regen_as_CRLF_equal_committed=no  mtime=2026-11-06 00:01:06
processed_data/dataCC_distance_part4.csv   raw_equal=yes LF-normalized_equal=yes regen_as_CRLF_equal_committed=yes mtime=2026-11-05 18:23:13
```
(The part4 file is the archive copy, untouched by every step.) Step 1 on Linux writes LF; converted to CRLF it equals the committed bytes, which confirms A-005 (the OLD profile must write these three files with `eol = "\r\n"`). Tier B: `tests/baseline/local/r_outputs.sha256`.

### 5.3 Models
**Committed vs WSL refit (chain B, from the committed step-2 CSV):**
```text
fixef         n=25   identical=FALSE all.equal(tol=0)=FALSE max|diff|=0.0007666   rel=0.0002971
vcov          n=625  identical=FALSE all.equal(tol=0)=FALSE max|diff|=2.121       rel=0.2479
vcov_rx       n=625  identical=FALSE all.equal(tol=0)=FALSE max|diff|=8.526e-06   rel=7.986e-07
theta         n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=8.58e-06    rel=8.758e-06
sigma2        n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=1.681e-05   rel=1.752e-05
loglik        n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=1.153e-06   rel=4.464e-11
deviance      n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=0.001106    rel=2.205e-08
nobs          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
ngrps         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
conv          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=   NA
cml_coef      n=24   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_vcov      n=576  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_loglik    n=2    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
[... cml_n, cml_nevent, cml_iter, cml_method identical ...]
wald_glmm     n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=0.9129      rel=0.002129
wald_glmm_rx  n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=0.01303     rel=3.046e-05
wald_cml      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
```
(`rel` = max |diff| / max |value|.) **Determinism on WSL:** chain A (all steps, from its own step-2 CSVs) vs chain B: every field `identical=TRUE` (fixef, vcov, vcov_rx, theta, sigma2, loglik, deviance, all CML fields, all three W). Tier B = chain A.

**Why the default vcov differs (K11):**
```text
committed : derivs NULL? FALSE  Hessian dim: 26 26  ntheta: 1  ...
local : derivs NULL? TRUE  Hessian dim: none  ntheta: 1  ...
    calc.derivs <- control$calc.derivs %||% (nrow(glmod$fr) <
        control$checkConv$check.conv.nobsmax)
check.conv.nobsmax default: 10000  nparmax: 20
```
lme4 1.1-38 `NEWS.Rd`: "derivative-based convergence checks are now skipped for models with large data (number of observations greater than the `check.conv.nobsmax` component of `[g]lmerControl()`); default threshold is 1e4 observations. If desired, derivatives can be calculated (but not checked) by explicitly setting `calc.derivs` to TRUE." The GLMM has 51,849 rows, so the WSL refit has no Hessian and `vcov()` falls back to RX; the committed model (lme4 1.1-37) stores the finite-difference Hessian and its default vcov uses it.

**Diagnostic 1, WSL refit with `calc.derivs = TRUE`** (`tests/legacy/diag_glmm_refit.R`, 387.9 s): vs the default WSL refit every field is identical except `vcov` (now Hessian-based) and `wald_glmm`:
```text
fixef         n=25   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov          n=625  identical=FALSE all.equal(tol=0)=FALSE max|diff|=5.189       rel=0.486
vcov_rx       n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
glmm  wald            1 431.18973544143188  W_vcov_default
glmm  wald            1 427.7804472165131  W_vcov_rx
```
So derivatives are computed after the fit and do not change it, and the Hessian vcov is numerically fragile: W = 428.69 (Windows Hessian), 431.19 (WSL Hessian), 427.77/427.78 (RX, both platforms).

**Diagnostic 2, the Windows R that wrote the committed model** (same script, `Rscript.exe`, 547.7 s):
```text
fit 547.7 s | R version 4.4.3 (2025-02-28 ucrt) | lme4 1.1.37 | Matrix 1.7.2 | derivs default | Hessian TRUE
fixef[1] -2.2715823477346397 | logLik -25819.283941935646
--- committed vs Windows R 4.4.3 refit (lme4 1.1-37)
fixef         n=25   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov          n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov_rx       n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
theta         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
sigma2        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
loglik        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
deviance      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
[... nobs, ngrps, conv, optimizer, wald_glmm, wald_glmm_rx identical ...]
Hessian identical: TRUE  theta identical: TRUE  beta identical: TRUE  u identical: TRUE
infoRDS writer: 4.4.3
```
**Conclusion:** the committed GLMM is exactly reproducible from the committed step-2 CSV and the step-3 code with R 4.4.3, lme4 1.1-37 and Matrix 1.7-2 on Windows. The WSL difference is the platform and package versions (an optimizer end point 7.7e-4 away in fixef, at a logLik 1.2e-6 away) plus lme4 1.1-38's derivative rule (A-055). The CML is reproduced exactly on WSL.

### 5.4 Wald test (all 24 spatial coefficients = 0)
The verbatim step-5 chunk with car (Windows R 4.4.3, car 3.1-3), next to `wald_all_spatial()` (`tests/legacy/diag_wald_car.R`):
```text
R version 4.4.3 (2025-02-28 ucrt) | lme4 1.1.37 | car 3.1.3
[... the 24 hypothesis lines ...]
Note: Coefficient covariance matrix supplied.

  Df  Chisq Pr(>Chisq)
1
2 24 428.69  < 2.2e-16 ***
Wald test, all 24 spatial coefficients = 0 (manual+car): W = 428.6933, df = 24, p = 9.43e-76
  car::linearHypothesis: W = 428.6933, p = 9.43e-76
legacy car Chisq 428.6933350010699 | manual W 428.69333500107194 | W_car 428.6933350010699
relative difference manual vs legacy car: 4.77e-15
Wald test, all 24 spatial coefficients = 0 (manual+car): W = 420.6712, df = 24, p = 4.23e-74
  car::linearHypothesis: W = 420.6712, p = 4.23e-74
```
**428.69 is proven** on the committed GLMM (the last line is the CML: 420.67). The WSL step-5 variant prints `W = 427.7804, df = 24, p = 1.45e-75` for the WSL refit (both chains), because that model's default vcov is the RX one (5.3).

### 5.5 Figures (steps 4-6)
Normalized PDF hashes (`tests/lib/pdf_normalize.py`: the `/CreationDate` and `/ModDate` values removed):
```text
model_images/CI_cut_110.pdf A=b272df049df94c3e B=b272df049df94c3e committed=e67ee0c3a5800932 A==B:yes
model_images/CI_cut_190.pdf A=1972d8dc93e6ad82 B=1972d8dc93e6ad82 committed=3c7b040947d4e343 A==B:yes
model_images/CI_cut_250.pdf A=5c56923b29046ca0 B=5c56923b29046ca0 committed=4ce27911e3ab81a6 A==B:yes
model_images/CI_shoe_cuts.pdf A=73b4093177d40b72 B=73b4093177d40b72 committed=c1112dd66a4dc9f4 A==B:yes
model_images/CML_MODEL_SHOE.pdf A=f79bf8e71c699206 B=f79bf8e71c699206 committed=1b063214806cdb0f A==B:yes
model_images/NEW_X_NS_XY_SHOE.pdf A=b99d794c1c9a538f B=b99d794c1c9a538f committed=f5861be7ffe01143 A==B:yes
model_images/difference_random_cml.pdf A=8e18f4562914e179 B=8e18f4562914e179 committed=65be93553e072aba A==B:yes
model_images/pixel_inten_JASAup.pdf A=f1fcbcfb78370123 B=f1fcbcfb78370123 committed=eded8668722dd53c A==B:yes
```
The two WSL chains give identical PDFs after normalization; the committed PDFs differ (`/Producer (R 4.4.3)` and the GLMM). How much the plotted matrices differ, committed models vs the WSL refit (`tests/legacy/compare_figure_matrices.R`, the formulas of steps 4-6 recomputed):
```text
sigma^2: A 0.9597790891 B 0.9597959001
map_r  (step 4 Random): max |B - A| = 1.56e-07, max |B - A| / |A| = 8.88e-05, max |A| = 0.00197
map_c  (step 4 CML): max |B - A| = 1.63e-08, max |B - A| / |A| = 8.28e-06, max |A| = 0.00197
diff   (step 6 diff): max |B - A| = 1.73e-07, max |B - A| / |A| = 103, max |A| = 8.3e-06
row 110 Random: max |Mid B - Mid A| / Mid A = 8.51e-05; band width B / A: min 0.9936 median 0.9980 max 1.0073
row 110 CML   : max |Mid B - Mid A| / Mid A = 8.28e-06; band width B / A: min 1.0000 median 1.0000 max 1.0000
row 190 Random: max |Mid B - Mid A| / Mid A = 3.72e-05; band width B / A: min 0.9977 median 0.9987 max 0.9992
row 190 CML   : max |Mid B - Mid A| / Mid A = 8.28e-06; band width B / A: min 1.0000 median 1.0000 max 1.0000
row 250 Random: max |Mid B - Mid A| / Mid A = 7.19e-05; band width B / A: min 0.9861 median 0.9976 max 0.9986
row 250 CML   : max |Mid B - Mid A| / Mid A = 8.28e-06; band width B / A: min 1.0000 median 1.0000 max 1.0000
```
(The relative difference of the step-6 map is large only where that map crosses 0; its absolute change, 1.7e-7, is 2% of its range.)

**Visual check:** I opened all 8 committed PDFs and their Tier B twins with the Read tool.
- `NEW_X_NS_XY_SHOE.pdf` and `CML_MODEL_SHOE.pdf`: intensity on the prototype, toe up; maxima (dark red, about 0.0018) at the left forefoot (x 0.45, y 0.73), along the right edge of the midfoot (x 0.67, y 0.40) and at the left heel (x 0.43, y 0.28); minima (blue, about 0.0004) at the toe tip and the heel edge. The twins look identical.
- `CI_shoe_cuts.pdf`: the CML map with the three cut rows (110, 190, 250) drawn as zero-valued dark lines; identical twins.
- `CI_cut_110/190/250.pdf`: the CML (red) and Random (blue) bands overlap almost entirely and widen toward the right edge (up to 0.0027 at row 250). The twins look identical except, at the right end of row 250, a hairline of the red CML edge above the blue edge in Tier B, where the Random band is up to 1.4% narrower (RX vcov).
- `pixel_inten_JASAup.pdf`: Random and CML side by side, practically identical maps (scale about 0.0003-0.0019); identical twins.
- `difference_random_cml.pdf`: from -8e-6 to +6.7e-6; positive in the left forefoot and the left heel, negative along the right edge of the midfoot and at the top right of the toe; in the twin, at most a faint shading change near the bottom of the heel.

## 6. Gallery and snake QA
`docs/qa/sheets_old/` (9 sheets, 68 OLD shoes, the prototype figure) and `docs/qa/snake-qa.md` (what I saw on every sheet and what a good contour looks like). The gallery was built with venv-wind (A-061):
```text
prototype re-run equals data/freq_min_18.png: True
shoes: 68; sheets: 9; re-run differs from the committed record for: []
```
(The first build on WSL printed `re-run differs from the committed record for: [11, 21, 80, 152, 176, 221, 349, 354]`, which led to section 4.4.) Metrics of all 386 committed contours (`python -B tests/legacy/old_snake_metrics.py`):
```text
wrote docs/qa/sheets_old/snake_metrics_old.csv (386 records)
coverage      min 0.9775 p1 0.9886 p5 0.9968 median 1 p95 1 p99 1 max 1; lowest: 153 (0.9775), 100 (0.9848), 187 (0.9855)
coverage_raw  min 0.8889 p1 0.9237 p5 0.9502 median 0.9999 p95 1 p99 1 max 1; lowest: 150 (0.8889), 241 (0.9116), 239 (0.9173)
rac_coverage  min 0.5 p1 0.9695 p5 1 median 1 p95 1 p99 1 max 1; lowest: 9 (0.5), 153 (0.9091), 241 (0.9375)
contour_px    min 614 p1 631.1 p5 670 median 700 p95 725.8 p99 734.1 max 742; lowest: 153 (614), 349 (615), 11 (621)
outside_mask  min 0 p1 0 p5 0 median 0.05705 p95 0.2368 p99 0.3393 max 0.4093; lowest: 4 (0.0), 7 (0.0), 13 (0.0)
removed_px    min 0 p1 0 p5 0 median 0 p95 497.2 p99 689.6 max 1132; lowest: 4 (0), 5 (0), 6 (0)
touches_border: 0
```
These definitions are not the T0 ones: the plan's "coverage p5 0.947, min 0.700 for shoe 9" (T4 step 1) used another pixel set; T4 defines the official `snake_metrics()`.

## 7. What is not reproduced exactly on WSL (with evidence)
1. **Contour txt:** 30 of 386 records (section 4.3); exact under venv-wind (4.4). Cause: platform numerics.
2. **PNG bytes** of the Python intermediates and of a regenerated `freq_min_18.png`: pixels identical (4.2). Cause: zlib-ng build.
3. **GLMM:** fixef within 7.7e-4, no stored Hessian, W 427.7804 (5.3); exact under Windows R 4.4.3 with lme4 1.1-37. Cause: platform and package versions, lme4 1.1-38 derivative rule.
4. **PDFs:** bytes (Producer string, dates, the GLMM); visually identical (5.5).
5. **The CML `.rds` bytes** (serialized environments); all numeric fields identical.

Everything else is reproduced exactly: the step-1 content (CRLF bytes after conversion), the step-2 CSVs (bytes), the CML (every field), the Python intermediates before the snake (bytes or pixels), the prototype mask and its boundary (pixels), and Wald 428.69 on the committed GLMM. The committed files remain the baseline downstream.

## 8. Timings (inputs for later budgets)

| What | Time |
|---|---|
| Legacy Python, full `main.py` (WSL, venv copy) | 509 s wall (snakes 339 s) |
| Legacy snake, all 386 shoes, Windows venv-wind (no HTML) | 377 s |
| Step 1 / step 2 (legacy double loop) | 141.8 s / 1133.8 s |
| GLMM fit, WSL (default; calc.derivs TRUE) | 281-305 s; 388 s |
| GLMM fit, Windows R 4.4.3 | 548 s |
| Exact CML fit, WSL | 228-230 s |
| Steps 4 / 5 / 6 | 14-17 s per model / 30-32 s / 21-23 s |
| `tests/run_all.sh` | 41 s |
| Gallery (68 shoes, Windows) | 95-112 s |
| venv copy (`cp -a`) + verification (`diff -rq`) | 1,144 s + 682 s |

## 9. Files created or changed in T1
- Tier A: `tests/baseline/{README.md, committed_79247d8.sha256, old_baseline.sha256, committed_79247d8_eol.tsv, models_committed.rds, old_model_summary.txt, old_model_summary.csv}`.
- Tier B: `tests/baseline/local/{python_contour.sha256, python_intermediates.sha256, r_outputs.sha256, pdf_normalized.sha256, models_local.rds, old_model_summary_local.txt, old_model_summary_local.csv, contour_linux_diff.npz, contour_linux_diff.csv, contour_windows_check.txt, environment.txt}`.
- Helpers: `tests/lib/{scratch.sh, make_tier_a.sh, dump_models.R, compare_models.R, pdf_normalize.py, compare_legacy_python.py, contour_platform_diff.py, write_environment.sh}`.
- Legacy runners and diagnostics: `tests/legacy/{run_legacy_python.sh, run_legacy_r.sh, step5_without_car.R, diag_glmm_refit.R, diag_wald_car.R, diag_snake_platform.py, compare_figure_matrices.R, old_snake_gallery.py, old_snake_metrics.py}`.
- Tests: `tests/run_all.sh`, `tests/python/{test_baseline_raw_data.py, test_snake_old_regression.py, test_scratch_lib.py, test_pdf_normalize.py}`, `tests/r/{test_baseline_committed.R, test_old_regression.R, test_wald.R}`.
- Code: `statistical_model/R/wald.R` (not yet sourced by any Rmd, A-057); `contour_algorithm/` (the verbatim thesis code, `requirements-lock.txt`, `README.md`; A-058).
- QA: `docs/qa/sheets_old/`, `docs/qa/snake-qa.md`.
- Config: `.gitignore` (`/images*/`, `/logs/`), `.shellcheckrc` (`external-sources=true`, `source-path=SCRIPTDIR`).
- Docs: this file, `docs/tests/T1-results.md` (pointer), `docs/progress/LOG.md`, `docs/decisions.md` (A-054 to A-061), the plan (Revision 3: F40-F44, K11, T1 ticked, T2 step 3 note).

No pipeline Rmd, no committed data file and no thesis-repo file was changed (`sha256sum -c` of the 24 committed files passes; the thesis tree was only read, with `-B` and `git --no-optional-locks`).
