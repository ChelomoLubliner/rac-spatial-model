# T1 second review fixes: results (OLD dataset)

**Date:** 2026-11-06. **Branch:** `feature/new-shoes-pipeline`. **Task:** fix the findings of the second pair of T1 reviews, of the fix pass `823a80c..2d39846` (engineering `9ddc9f0`, reproducibility `ba3639a`; both in `docs/progress/LOG.md`).
**Scratch:** `<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`. This pass works in `<scratch>/t1rv2/` (`RAC_SCRATCH=<scratch>/t1rv2`).
Every output below is pasted by a script from the files the real runs wrote, under `<scratch>/t1rv2/evidence/`; only the scratch prefix is shortened to `<scratch>`. Trimmed output is marked.

## 0. Summary

Finding labels: **R** = reproducibility review, **E** = engineering review, numbered as in each review.

| Finding | Fix | Evidence | Commit |
|---|---|---|---|
| **R1** (major) The live OLD-regression check passes on stale committed files | Each runner deletes the outputs of the steps it runs before the first step, lists them and fails if one is missing or not newer afterwards (`tests/lib/run_outputs.sh`). Every live check first calls `check_run_manifest()` (`tests/lib/run_manifest.R`, `.py`). Plan 4.5 and T2 step 3 amended (A-067) | The previous test printed ALL PASS on the reviewer's stale folder; the new one exits 1. A rebuilt stale folder is a committed negative test. Stub runs show that each runner fails without its outputs. Fresh runs pass the strict checks (section 1) | `4d7dfec`, `969e7d9`, `0a6a727` |
| **E1** = **R4** (major) The `compare_models.R` CLI exits 0 for dumps that are not identical | `quit(status = if (all(tab$identical)) 0 else 1)`, with CLI test cases (A-069) | All 5 reported dumps exit 1 now; the new cases fail against the old file; the Windows fit's dump: 22 of 22, exit 0 (section 2) | `a781041` |
| **E2** = **R2** The step-3 Tier A gate reads its reference from the work tree | Reference = the `79247d8` blob, sha256-checked; both sha256 values in `compare.txt`; the driver sets `RAC_DATASET=old` (A-070) | Windows run at `4d7dfec`: 27 of 27 fields equal the Tier A blob (section 3) | `4d7dfec` |
| **R3** The Windows platform of Tier A is not frozen | `environment.txt` records venv-wind's Store base interpreter; F21 and F40 reconciled; every venv-wind Tier A check of T2 and T4 logs its interpreter (A-071) | Section 4 | `b3f7520`, `90392ae`, docs |
| **E3** A-062 residual risk; `rac_scratch_root` can be reassigned | Run marker `.rac_scratch_run`, required for deletion; read-only root, guarded for a second `source` (A-068) | 16 tests, 9 of them fail against the old library (section 5) | `223b5e6` |
| **E4.1** Sixth copy of the OLD frame, reader and mapping; `tests/` outside `test_no_hardcoding` | `tests/lib/old_records.py` used by all seven helpers; plan: the scan covers `tests/` except an allowlist (A-072) | Before/after outputs identical; under venv-wind the gallery equals the committed one byte for byte (section 6) | `0c4829e`, docs |
| **E4.2**, **E4.3** The `!identical()` assertion; a missing space | Printed as a NOTE; space fixed | `run_all.sh` (section 7) | `386951e` |
| **E4.4** Shoe 11's heel is not "shared" | Sentence corrected with numbers from the records | Section 6.4 | docs |

## 1. Stale outputs pass the live check (R1; decision A-067)

### 1.1 The bug, reproduced with the previous test
The reviewer's folder `<scratch>/rv2_t1/fake_stale_zv7m57` holds only `repo/`. It contains the committed step-1 CSVs with CR removed, the committed step-2 CSVs and CML, and an older WSL GLMM. The test as of `ba3639a`, run on it (from a mirror folder that links `tests/lib`, `tests/baseline` and `statistical_model` of the repo):
```bash
RAC_REGRESS_R_RUN=<scratch>/rv2_t1/fake_stale_zv7m57 Rscript <scratch>/t1rv2/oldregress/tests/r/test_old_regression.R
```
```text
PASS Tier B step-2 CSVs byte-identical to Tier A 
PASS Tier B step-1 CSVs = Tier A bytes after LF -> CRLF (raw: LF, differ) 
PASS CML: Tier B identical() to Tier A in every field 
PASS GLMM structure identical (nobs, groups, convergence, optimizer, names) 
PASS GLMM differs from Tier A as recorded in T1: max|dfixef| 0.000767, W 427.7804 (Tier A 428.6933; RX 427.7674), sigma^2 0.95979590 (Tier A 0.95977909) 
PASS live rerun: the five CSVs equal Tier B byte for byte 
PASS live rerun: models identical() to Tier B in every field 
ALL PASS test_old_regression
exit 0
```
None of steps 1, 2 and the CML fit ran, yet the check printed "ALL PASS".

### 1.2 The fix
- **`tests/lib/run_outputs.sh`** (new): `rac_outputs_begin RUN PATH...` deletes the listed outputs from the run folder and writes `outputs_expected.txt`. It refuses paths that are absolute, empty or contain `.` or `..` components, and paths that are directories. `rac_outputs_end RUN` writes `outputs_regenerated.sha256` (every listed output that is a regular file newer than the list) and `outputs_missing.txt`, and returns 1 if an output is missing.
- **The runners** source it:

| Runner | Outputs deleted before the run and required after it | Step rows in `timings.tsv` |
|---|---|---|
| `tests/legacy/run_legacy_r.sh` | step 1: `repo/data/all_cont.csv`, `repo/processed_data/dataCC.csv`, `shoe_pixel_counts.csv`; step 2: `dataCC_distance_temp.csv`, `dataCC_distance.csv`; step 3: `repo/saved_models/NEW_X_NS_XY.rds`, `CML_MODEL.rds`; step 4: `repo/model_images/NEW_X_NS_XY_SHOE.pdf`, `CML_MODEL_SHOE.pdf`; step 5: `CI_shoe_cuts.pdf`, `CI_cut_110.pdf`, `CI_cut_190.pdf`, `CI_cut_250.pdf`; step 6: `pixel_inten_JASAup.pdf`, `difference_random_cml.pdf` (only the steps that run) | `step1` ... `step6` (unchanged) |
| `tests/legacy/run_legacy_python.sh` | `data/contour_Active_Contour.txt` and the 8 `images/saved/` files (the folder starts empty anyway) | `step0` (new) |
| `tests/legacy/run_windows_r_step3.sh` | `repo/saved_models/NEW_X_NS_XY.rds` | `step3_glmm_win` (new) |

- **`check_run_manifest(run, files, steps)`** (new, in `tests/lib/run_manifest.R` and `run_manifest.py`) stops unless four things hold. `exit_status` reads 0. Every row of `timings.tsv` has exit 0, and every required step has a row. No expected output is missing. Every compared file is on the regenerated list, with an unchanged sha256 and an mtime after the start.
- **The live checks** call it first: `tests/r/test_old_regression.R` (`RAC_REGRESS_R_RUN`; it requires `step1`, `step2`, `step3_glmm` and `step3_cml` and the five CSVs and both models); the new `tests/python/test_live_r_pdfs.py` (same variable; `step4_glmm`, `step4_cml`, `step5`, `step6` and the 8 PDFs, then their normalized hashes against Tier B); and `tests/python/test_snake_old_regression.py` (`RAC_REGRESS_PY_RUN`; `step0` and the contour, plus the new `test_full_run_intermediates`: all 1,556 `.npy`/`.png` files equal Tier B and are newer than the start).
- **Plan:** section 4.5 (the `regress_old.sh` bullet lists the deleted outputs per step; every comparison checks the manifest first) and T2 step 3 (the gate accepts only regenerated outputs, the venv-wind contour check included). Revision 5.

### 1.3 Tests

`tests/python/test_run_manifest.py`: the shell helper and the Python checker (folders built with the real `run_outputs.sh`):
```bash
/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python -B -m unittest tests.python.test_run_manifest -v
```
```text
test_a_copy_of_the_committed_tree_is_refused (tests.python.test_run_manifest.CheckRunManifest.test_a_copy_of_the_committed_tree_is_refused) ... ok
test_a_finished_run_passes (tests.python.test_run_manifest.CheckRunManifest.test_a_finished_run_passes) ... ok
test_failed_or_missing_steps_are_refused (tests.python.test_run_manifest.CheckRunManifest.test_failed_or_missing_steps_are_refused) ... ok
test_missing_unlisted_changed_or_old_outputs_are_refused (tests.python.test_run_manifest.CheckRunManifest.test_missing_unlisted_changed_or_old_outputs_are_refused) ... ok
test_module_is_the_one_documented (tests.python.test_run_manifest.CheckRunManifest.test_module_is_the_one_documented) ... ok
test_begin_deletes_and_lists (tests.python.test_run_manifest.RunOutputsShell.test_begin_deletes_and_lists) ... ok
test_begin_refuses_bad_paths_before_deleting (tests.python.test_run_manifest.RunOutputsShell.test_begin_refuses_bad_paths_before_deleting) ... ok
test_end_hashes_regenerated_and_lists_missing (tests.python.test_run_manifest.RunOutputsShell.test_end_hashes_regenerated_and_lists_missing) ... ok
test_end_rejects_a_restored_old_file_and_a_symlink (tests.python.test_run_manifest.RunOutputsShell.test_end_rejects_a_restored_old_file_and_a_symlink) ... ok

----------------------------------------------------------------------
Ran 9 tests in 0.340s

OK
exit 0
```
`tests/r/test_run_manifest.R`: the R checker, and the negative test the review asked for. It rebuilds the stale folder from the committed files. The test checks that the folder's five CSVs and its CML equal Tier B (so content checks alone cannot tell), then that `test_old_regression.R` fails on it. It must fail both with the bare folder and with a forged `exit_status` 0 and `timings.tsv`:
```bash
Rscript tests/r/test_run_manifest.R
```
```text
PASS a finished run passes: both outputs regenerated, steps exit 0 
PASS refused: exit_status 1, a step with exit 1, a step not run, an output missing, a file not on the list, changed, or older than the start 
PASS the stale folder's five CSVs equal Tier B byte for byte and its CML equals Tier B: content checks alone cannot tell 
PASS test_old_regression.R fails on the stale folder: no exit_status 
PASS with a forged exit_status 0 and timings.tsv it still fails: the outputs were never deleted and listed 
ALL PASS test_run_manifest
exit 0
```
`tests/python/test_runner_outputs.py`: the real runners with a stub in place of R (no model is fitted):
```bash
/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python -B -m unittest tests.python.test_runner_outputs -v
```
```text
test_a_step_that_writes_its_outputs_passes (tests.python.test_runner_outputs.LegacyR.test_a_step_that_writes_its_outputs_passes) ... ok
test_a_step_that_writes_nothing_fails_the_run (tests.python.test_runner_outputs.LegacyR.test_a_step_that_writes_nothing_fails_the_run) ... ok
test_a_fresh_model_is_compared_with_the_tier_a_blob (tests.python.test_runner_outputs.WindowsStep3.test_a_fresh_model_is_compared_with_the_tier_a_blob) ... ok
test_no_model_or_a_stale_model_fails (tests.python.test_runner_outputs.WindowsStep3.test_no_model_or_a_stale_model_fails) ... ok

----------------------------------------------------------------------
Ran 4 tests in 8.923s

OK
exit 0
```
**Green on the reviewer's folder.** The new test stops at the manifest, before any content is compared:
```bash
RAC_REGRESS_R_RUN=<scratch>/rv2_t1/fake_stale_zv7m57 Rscript tests/r/test_old_regression.R
```
```text
PASS Tier B step-2 CSVs byte-identical to Tier A 
PASS Tier B step-1 CSVs = Tier A bytes after LF -> CRLF (raw: LF, differ) 
PASS CML: Tier B identical() to Tier A in every field 
PASS GLMM structure identical (nobs, groups, convergence, optimizer, names) 
PASS GLMM differs from Tier A as recorded in T1: max|dfixef| 0.000767, W 427.7804 (Tier A 428.6933; RX 427.7674), sigma^2 0.95979590 (Tier A 0.95977909) 
Error: run manifest: no exit_status in <scratch>/rv2_t1/fake_stale_zv7m57 (not a finished runner folder)
Execution halted
exit 1
```
**Red for the stub test's stale case.** The previous `run_windows_r_step3.sh` (from `ba3639a`, run as a temporary copy next to the current one, deleted afterwards), with the stub copying the committed GLMM into place with `cp -p`, exits 0:
```bash
RAC_SCRATCH=<scratch>/t1rv2/redwin/scratch RAC_WIN_RSCRIPT=<stub> STUB_MODE=stale STUB_GLMM=$PWD/saved_models/NEW_X_NS_XY.rds bash tests/legacy/zz_old_winr_tmp.sh; echo "exit $?"; tail -1 <run>/compare.txt
```
```text
old runner, stale model copied with cp -p: exit 0
RESULT 27 of 27 fields the same
```
**The T1 run folders predate the manifest and are refused:**
```bash
for r in t1fix/legacy_r_FTg4vJ review_t1_repro/rchain_l8x7yU t1/legacy_r_oTZO3x; do RAC_REGRESS_R_RUN=<scratch>/$r Rscript tests/r/test_old_regression.R | grep -E 'run manifest|ALL PASS'; done
```
```text
== RAC_REGRESS_R_RUN=t1fix/legacy_r_FTg4vJ
Error: run manifest: no outputs_expected.txt / outputs_regenerated.sha256 in <scratch>/t1fix/legacy_r_FTg4vJ (outputs were not deleted before the run and listed after it)
exit 1
== RAC_REGRESS_R_RUN=review_t1_repro/rchain_l8x7yU
Error: run manifest: no exit_status in <scratch>/review_t1_repro/rchain_l8x7yU (not a finished runner folder)
exit 1
== RAC_REGRESS_R_RUN=t1/legacy_r_oTZO3x
Error: run manifest: no outputs_expected.txt / outputs_regenerated.sha256 in <scratch>/t1/legacy_r_oTZO3x (outputs were not deleted before the run and listed after it)
exit 1
```
That is intended. The reviewer had confirmed from mtimes and exit codes that these runs regenerated every file; the evidence under the strict check comes from the fresh runs of section 1.4.

### 1.4 Fresh runs from the new runners (launched together at `4d7dfec`, 03:22)
**Python** (`legacy_py_rJehu1`, the verified venv copy):
```bash
RAC_SCRATCH=<scratch>/t1rv2 RAC_VENV_PY=<scratch>/t1/venv_copy/bin/python bash tests/legacy/run_legacy_python.sh
```
Timing, `timings.tsv`, `exit_status` and the manifest:
```text
$ cat timing.txt (resource lines trimmed to three)
start 2026-11-06T03:22:31+02:00
end 2026-11-06T03:39:57+02:00
exit 0
seconds 1046.253292318
	User time (seconds): 8015.25
	Elapsed (wall clock) time (h:mm:ss or m:ss): 17:26.24
	Maximum resident set size (kbytes): 493288
$ cat timings.tsv exit_status outputs_expected.txt outputs_regenerated.sha256 outputs_missing.txt
step	seconds	exit
step0	1046.253292318	0
0
data/contour_Active_Contour.txt
images/saved/list_matrices.npy
images/saved/old_freq_min_18.npy
images/saved/freq_min_18.npy
images/saved/list_contour.npy
images/saved/active-contour_all.npy
images/saved/all_shoes_superposed.png
images/saved/old_freq_min_18.png
images/saved/freq_min_18.png
d43fda7eb631599eb1b7ebb8775e0c7d82c5ef40c9e5272165542c0f2f8aa917  data/contour_Active_Contour.txt
fde24863f7fcb42560c3c275ee7f12de2213228cb37fa761711044947f6f48e9  images/saved/list_matrices.npy
bc3891376184d1750e2838578385deb516a3780598fa031421c31e6ce5d69e3d  images/saved/old_freq_min_18.npy
1cb5f7cfe3738e306cb893efc82159d0a3885483d87d5b5eed4efd7b10240e34  images/saved/freq_min_18.npy
8329d4ea7ac16a0beda9f04ad52f4c6782c9025075a9aeedfff617d8b094e0ec  images/saved/list_contour.npy
eb05a126cf583c6684d5fc6b19387c0ddf400450c9ef6d2ff39e233c3d19a569  images/saved/active-contour_all.npy
4b3ecc025db2168eedda8525f0b7c74f377549aa11d5695a303de8ed9bf49da5  images/saved/all_shoes_superposed.png
1f9c817882edfae4f6a9b2298a2bb054a4e8cd4a1460e59dab756bd879e81cdd  images/saved/old_freq_min_18.png
6aa7e1a748bf9321c08d9b4fee07f591610d6d80330ae0bb1acbacd10007fb1d  images/saved/freq_min_18.png
$ cat .rac_scratch_run
<scratch>/t1rv2/legacy_py_rJehu1
```
The strict live checks (contour, all 1,556 intermediates, newer than the start):
```bash
RAC_REGRESS_PY_RUN=<scratch>/t1rv2/legacy_py_rJehu1 MPLBACKEND=Agg <thesis venv>/bin/python -B -m unittest tests.python.test_snake_old_regression -v
```
```text
test_full_rerun_recorded (tests.python.test_snake_old_regression.SnakeOld.test_full_rerun_recorded) ... ok
test_full_run_folder (tests.python.test_snake_old_regression.SnakeOld.test_full_run_folder) ... ok
test_full_run_intermediates (tests.python.test_snake_old_regression.SnakeOld.test_full_run_intermediates) ... ok
test_inputs (tests.python.test_snake_old_regression.SnakeOld.test_inputs) ... ok
test_platform_sensitive_records (tests.python.test_snake_old_regression.SnakeOld.test_platform_sensitive_records) ... [ WARN:0@20.631] global loadsave.cpp:1617 imencodeWithMetadata Unsupported depth image for selected encoder is fallbacked to CV_8U.
ok
test_reproduces_committed_records (tests.python.test_snake_old_regression.SnakeOld.test_reproduces_committed_records) ... ok

----------------------------------------------------------------------
Ran 6 tests in 33.198s

OK
exit 0
```
Against Tier A, the same picture as in T1 (30 records, 19,027 px; the 30 per-record lines are removed by the `grep -v`):
```bash
<scratch>/t1/venv_copy/bin/python -B tests/lib/compare_legacy_python.py <scratch>/t1rv2/legacy_py_rJehu1 | grep -v "^  record"
```
```text
# legacy Python run <scratch>/t1rv2/legacy_py_rJehu1
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
RESULT contour_identical=False masks_identical=True thesis_intermediates_identical=True
exit 1
```
**R** (`legacy_r_ck4pCJ`, all six steps):
```bash
RAC_SCRATCH=<scratch>/t1rv2 bash tests/legacy/run_legacy_r.sh
```
```text
$ cat timings.tsv exit_status outputs_expected.txt outputs_regenerated.sha256 outputs_missing.txt legacy_source.txt
step	seconds	exit
step1	146.386327581	0
step2	1386.882077921	0
step3_glmm	259.625303718	0
step3_cml	202.796988104	0
step4_glmm	13.355756311	0
step4_cml	13.144121571	0
step5	25.260867398	0
step6	17.865132103	0
0
repo/data/all_cont.csv
repo/processed_data/dataCC.csv
repo/processed_data/shoe_pixel_counts.csv
repo/processed_data/dataCC_distance_temp.csv
repo/processed_data/dataCC_distance.csv
repo/saved_models/NEW_X_NS_XY.rds
repo/saved_models/CML_MODEL.rds
repo/model_images/NEW_X_NS_XY_SHOE.pdf
repo/model_images/CML_MODEL_SHOE.pdf
repo/model_images/CI_shoe_cuts.pdf
repo/model_images/CI_cut_110.pdf
repo/model_images/CI_cut_190.pdf
repo/model_images/CI_cut_250.pdf
repo/model_images/pixel_inten_JASAup.pdf
repo/model_images/difference_random_cml.pdf
488e728d693defbe994d2ea240e831d5c09455257dcb7f5755074500b1baf29e  repo/data/all_cont.csv
d7b292f92251bb3608cb084f3439b68f724ccd1e58bb6dd1fef1134884ced813  repo/processed_data/dataCC.csv
de268739ba6610c8f922609377e13b40ba9186132042b6a378e2c6e5bd91e81f  repo/processed_data/shoe_pixel_counts.csv
43d7c9b87946e1bb761be538c8e0f8dcb335c06d0186862c7c4b04a507c7f91f  repo/processed_data/dataCC_distance_temp.csv
f0e697ac6f793de4b06cf39f4b044691631abd94b8a044a4dd254143f29804bf  repo/processed_data/dataCC_distance.csv
5925748e83d0291e717ecb2b1eb65e9ed9846d26f37a22a7b37345ea6a468256  repo/saved_models/NEW_X_NS_XY.rds
696440462e8b7778e2ddf889d15b36c0bd7fca0c91e70d5c940508967b6581dc  repo/saved_models/CML_MODEL.rds
811023ea1b93db374cf8852792a1b15a86ba026efb002c6337ab0fb825af3b68  repo/model_images/NEW_X_NS_XY_SHOE.pdf
9b274733cf4f15b6a29fa330785d977f3bb622ee0153fca785e1b7c0643290d7  repo/model_images/CML_MODEL_SHOE.pdf
9b15b1fc938f6a2d2de689fffbab5e5c98c57680739f8ef5caf058efbef14765  repo/model_images/CI_shoe_cuts.pdf
c81aea3f5cab6f4c06f52f2c064a58a121f94e66141245d416556dff19840e5d  repo/model_images/CI_cut_110.pdf
ebeaf4df882b96f38963d690135cae588c3d71d556bb384ca723e73a74f67d2b  repo/model_images/CI_cut_190.pdf
b8e21f350413e67c6e278aeb8a01622d6dc3442c8b721bcc9d7e904e77864663  repo/model_images/CI_cut_250.pdf
e04c5bc1fa35bb96cb3379b32dae2a46cfd7eaefe726898294e116c3964bdeb4  repo/model_images/pixel_inten_JASAup.pdf
9a07743cc346c34593e04f2ee1a10eee8f58d0274f99601eeeeea7ceb422f0c1  repo/model_images/difference_random_cml.pdf
commit=79247d82459f25d5f823ddb4b91873b7ab13f3d5 steps=1,2,3,4,5,6
$ cat logs/step5_variant.log
step5_without_car: removed line 20 (library(car)); replaced lines 125 to 130 by the manual Wald test
$ sha256sum repo/statistical_model/statistical_tests_5.Rmd  (the step-5 variant that ran)
4b0249dcb2bbe266f8361b7d2dfbc58dc29fc9852852ed370fcbf80bf1e4e13e  repo/statistical_model/statistical_tests_5.Rmd
```
The strict live checks:
```bash
RAC_REGRESS_R_RUN=<scratch>/t1rv2/legacy_r_ck4pCJ Rscript tests/r/test_old_regression.R
RAC_REGRESS_R_RUN=<scratch>/t1rv2/legacy_r_ck4pCJ <thesis venv>/bin/python -B -m unittest tests.python.test_live_r_pdfs -v
```
```text
$ RAC_REGRESS_R_RUN=<scratch>/t1rv2/legacy_r_ck4pCJ Rscript tests/r/test_old_regression.R
PASS Tier B step-2 CSVs byte-identical to Tier A 
PASS Tier B step-1 CSVs = Tier A bytes after LF -> CRLF (raw: LF, differ) 
PASS CML: Tier B identical() to Tier A in every field 
PASS GLMM structure identical (nobs, groups, convergence, optimizer, names) 
PASS GLMM differs from Tier A as recorded in T1: max|dfixef| 0.000767, W 427.7804 (Tier A 428.6933; RX 427.7674), sigma^2 0.95979590 (Tier A 0.95977909) 
PASS live rerun: exit 0 for every step; the five CSVs and both models were regenerated by the run (A-067) 
PASS live rerun: the five CSVs equal Tier B byte for byte 
PASS live rerun: models identical() to Tier B in every field 
ALL PASS test_old_regression
exit 0
$ RAC_REGRESS_R_RUN=<scratch>/t1rv2/legacy_r_ck4pCJ <thesis venv>/bin/python -B -m unittest tests.python.test_live_r_pdfs -v
test_normalized_pdfs_equal_tier_b (tests.python.test_live_r_pdfs.LiveRun.test_normalized_pdfs_equal_tier_b) ... ok
test_tier_b_lists_the_8_pdfs (tests.python.test_live_r_pdfs.TierB.test_tier_b_lists_the_8_pdfs) ... ok

----------------------------------------------------------------------
Ran 2 tests in 0.007s

OK
exit 0
```
Step 5's Wald test (manual, from the knitted HTML of the car-free variant):
```text
## Wald test, all 24 spatial coefficients = 0 (manual): W = 427.7804, df = 24, p = 1.45e-75
##   car::linearHypothesis: not run (car not installed)
```
**Windows R step 3** (`winr_step3_kMdls7`): section 3.

## 2. The `compare_models.R` CLI exit status (E1 = R4; decision A-069)
The five dumps of the review, against `tests/baseline/models_committed.rds`, with the CLI of `ba3639a` and with the fixed one:
```bash
for n in nan_fixef short_fixef optimizer cml_method all_glmm_nan; do Rscript <old>/compare_models_old.R tests/baseline/models_committed.rds <scratch>/t1rv2/cmpcli/$n.rds; Rscript tests/lib/compare_models.R tests/baseline/models_committed.rds <scratch>/t1rv2/cmpcli/$n.rds; done
```
```text
nan_fixef: old CLI exit 0, fixed CLI exit 1 (rows identical=FALSE: 1)
short_fixef: old CLI exit 0, fixed CLI exit 1 (rows identical=FALSE: 1)
optimizer: old CLI exit 0, fixed CLI exit 1 (rows identical=FALSE: 1)
cml_method: old CLI exit 0, fixed CLI exit 1 (rows identical=FALSE: 1)
all_glmm_nan: old CLI exit 0, fixed CLI exit 1 (rows identical=FALSE: 10)
```
The test with its new CLI cases, then the same test against the old library (mirror folder `<scratch>/t1rv2/oldcmp`):
```bash
Rscript tests/r/test_compare_models.R
Rscript <scratch>/t1rv2/oldcmp/tests/r/test_compare_models.R
```
```text
PASS a dump compared with itself: 22 fields, all identical 
PASS Tier A vs Tier B: all 22 fields compared; the 10 that differ are the GLMM estimates (T1 section 5.3) 
PASS a field missing from either dump, or an extra field, is an error 
PASS CLI: exit 0 for the same dump; exit 1 for a NaN, a shorter fixef, a changed optimizer or cml_method, all GLMM fields NaN, and Tier B 
ALL PASS test_compare_models
exit 0
```
```text
PASS a dump compared with itself: 22 fields, all identical 
PASS Tier A vs Tier B: all 22 fields compared; the 10 that differ are the GLMM estimates (T1 section 5.3) 
PASS a field missing from either dump, or an extra field, is an error 
Error: CLI case nan_fixef: exit 0 with 1 rows FALSE (want 1, 1)
Execution halted
exit 1
```
The A-065 evidence under the strict exit status: the fresh Windows fit (section 3), dumped with the committed CML, against the committed dump:
```bash
Rscript tests/lib/dump_models.R <scratch>/t1rv2/winr_step3_kMdls7/repo/saved_models/NEW_X_NS_XY.rds saved_models/CML_MODEL.rds <scratch>/t1rv2/winr_dump.rds <scratch>/t1rv2/winr_dump
Rscript tests/lib/compare_models.R tests/baseline/models_committed.rds <scratch>/t1rv2/winr_dump.rds; echo "compare_models exit $?"
```
```text
fixef         n=25   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov          n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov_rx       n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
theta         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
sigma2        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
varcorr       n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
loglik        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
deviance      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
nobs          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
ngrps         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
conv          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=   NA
optimizer     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
cml_coef      n=24   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_vcov      n=576  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_loglik    n=2    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_n         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_nevent    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_iter      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_method    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
wald_glmm     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_glmm_rx  n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_cml      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
compare_models exit 0
```

## 3. The Windows R step-3 gate takes its reference from the Tier A blob (E2 = R2; decision A-070)
```bash
RAC_SCRATCH=<scratch>/t1rv2 bash tests/legacy/run_windows_r_step3.sh   # -> <scratch>/t1rv2/winr_step3_kMdls7
```
```text
$ cat compare.txt
reference 79247d8:saved_models/NEW_X_NS_XY.rds sha256 ae670fd392cef406b4170aa2a1480fe4b5e9c6cc1969ef0e5df21aa7bcd9fb57 (Tier A)
fit       repo/saved_models/NEW_X_NS_XY.rds sha256 e891c7122e0573cb761993f299016a293630699631999cb1f3314e6ffa9b6f3b
theta        identical same
beta         identical same
u            identical same
optinfo      identical same
devcomp      identical same
Gp           identical same
flist        identical same
cnms         identical same
lower        identical same
frame_data   identical same
resp_y       identical same
resp_mu      identical same
resp_eta     identical same
resp_weights identical same
resp_offset  identical same
resp_wtres   identical same
X            identical same
Zt           identical same
Lambdat      identical same
fixef        identical same
vcov         identical same
vcov_rx      identical same
loglik       identical same
deviance     identical same
sigma2       identical same
call         all.equal same
frame        all.equal same
RESULT 27 of 27 fields the same
$ cat exit_status timings.tsv outputs_expected.txt outputs_regenerated.sha256 outputs_missing.txt
0
step	seconds	exit
step3_glmm_win	635.035696559	0
repo/saved_models/NEW_X_NS_XY.rds
e891c7122e0573cb761993f299016a293630699631999cb1f3314e6ffa9b6f3b  repo/saved_models/NEW_X_NS_XY.rds
$ tail -2 logs/step3_win.log
knit seconds 631.3
R version 4.4.3 (2025-02-28 ucrt) | lme4 1.1.37 | Matrix 1.7.2 
$ head -3 step3_win.R
Sys.setenv(RGL_USE_NULL = "TRUE", RAC_DATASET = "old",
           RAC_MODEL_FEATURE = "NEW_X_NS_XY")
Sys.unsetenv("RAC_PROFILE_FILE")
```
The reference is the `79247d8` blob (sha256 `ae670fd3...`, the Tier A value), and the new fit equals it in all 27 fields; knit 631.3 s with two other jobs running. The fit's file bytes differ from the committed file (serialized environments, as in T1). The stub tests of section 1.3 cover the failure paths: no model, or a stale model.

## 4. venv-wind is not a frozen platform (R3; decision A-071)
Read-only queries; the thesis repo root, both venvs and `.git/index` kept their mtimes:
```text
$ tr -d '\r' < venv-wind/pyvenv.cfg; stat -c '%n %y' venv-wind/pyvenv.cfg
home = C:\Users\mehes\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0
include-system-site-packages = false
version = 3.13.9
executable = C:\Users\mehes\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\python.exe
command = C:\Users\mehes\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\python.exe -m venv C:\Users\mehes\Documents\repo\master_thesis_forensic_shoeprint\venv-wind
/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv-wind/pyvenv.cfg 2025-11-12 12:16:48.041539700 +0200
$ venv-wind/Scripts/python.exe -B -I -c '...sys.version, sys.base_prefix, sys.executable, sys._base_executable, platform...'
version 3.13.14 (tags/v3.13.14:fd17997, Jun 10 2026, 13:03:48) [MSC v.1944 64 bit (AMD64)]
base_prefix C:\Program Files\WindowsApps\PythonSoftwareFoundation.Python.3.13_3.13.3824.0_x64__qbz5n2kfra8p0
executable C:\Users\mehes\Documents\repo\master_thesis_forensic_shoeprint\venv-wind\Scripts\python.exe
base_executable C:\Users\mehes\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\python.exe
platform Windows-11-10.0.26300-SP0
```
So the venv was created on 2025-11-12 with the Store Python 3.13.9 (one day before the committed contour was written), and its base now runs 3.13.14 from Store package 3.13.3824.0. F21 read `pyvenv.cfg`, while F40 and A-060 used the running interpreter; both values are now explained in the plan. `tests/lib/write_environment.sh` prints `pyvenv.cfg` and `sys.base_prefix`. It now passes the `PIP_*` settings to the Windows pip through `WSLENV`; before, they never reached it. Regenerated `tests/baseline/local/environment.txt`, diff against the previous version (only the timestamp, the commit and the new lines):
```bash
bash tests/lib/write_environment.sh > tests/baseline/local/environment.txt   # 87 s
diff <previous environment.txt> tests/baseline/local/environment.txt
```
```text
1c1
< # Environment of the T1 Tier B reruns, recorded 2026-11-06T01:44:00+02:00
---
> # Environment of the T1 Tier B reruns, recorded 2026-11-06T03:43:30+02:00
9c9
< this repo: 2196d8319f37d0e18f2a7253f2eb476b04818b9f (feature/new-shoes-pipeline)
---
> this repo: b3f7520cf3f9b0a8f3b9934de937a01e7c2ded28 (feature/new-shoes-pipeline)
100a101,107
> base_prefix C:\Program Files\WindowsApps\PythonSoftwareFoundation.Python.3.13_3.13.3824.0_x64__qbz5n2kfra8p0
> pyvenv.cfg (modified 2025-11-12 12:16:48.041539700 +0200):
> home = C:\Users\mehes\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0
> include-system-site-packages = false
> version = 3.13.9
> executable = C:\Users\mehes\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\python.exe
> command = C:\Users\mehes\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\python.exe -m venv C:\Users\mehes\Documents\repo\master_thesis_forensic_shoeprint\venv-wind
```
Plan T2 step 3 and T4 step 8 now require every venv-wind Tier A check to log `sys.version` and `sys.base_prefix`.

## 5. Scratch run marker and read-only root (E3; decision A-068)
`rac_scratch_new` writes `.rac_scratch_run` (the folder's own path); `rac_scratch_remove` requires it; `rac_scratch_root` is read-only.
```bash
<thesis venv>/bin/python -B -m unittest tests.python.test_scratch_lib -v
```
```text
test_bad_run_name (tests.python.test_scratch_lib.Guards.test_bad_run_name) ... ok
test_dangerous_roots_are_refused (tests.python.test_scratch_lib.Guards.test_dangerous_roots_are_refused) ... ok
test_empty_name_does_not_wipe_the_root (tests.python.test_scratch_lib.Guards.test_empty_name_does_not_wipe_the_root) ... ok
test_new_and_remove (tests.python.test_scratch_lib.Guards.test_new_and_remove) ... ok
test_new_writes_the_marker (tests.python.test_scratch_lib.Guards.test_new_writes_the_marker) ... ok
test_remove_ignores_a_later_change_of_rac_scratch (tests.python.test_scratch_lib.Guards.test_remove_ignores_a_later_change_of_rac_scratch) ... ok
test_remove_refuses_a_copy_or_a_bad_marker (tests.python.test_scratch_lib.Guards.test_remove_refuses_a_copy_or_a_bad_marker) ... ok
test_remove_refuses_a_symlink (tests.python.test_scratch_lib.Guards.test_remove_refuses_a_symlink) ... ok
test_remove_refuses_handmade_mktemp_shaped_folders (tests.python.test_scratch_lib.Guards.test_remove_refuses_handmade_mktemp_shaped_folders) ... ok
test_remove_refuses_outside_paths (tests.python.test_scratch_lib.Guards.test_remove_refuses_outside_paths) ... ok
test_remove_refuses_root_and_non_run_paths (tests.python.test_scratch_lib.Guards.test_remove_refuses_root_and_non_run_paths) ... ok
test_remove_run_with_trailing_slash_spares_siblings (tests.python.test_scratch_lib.Guards.test_remove_run_with_trailing_slash_spares_siblings) ... ok
test_root_is_readonly (tests.python.test_scratch_lib.Guards.test_root_is_readonly) ... ok
test_second_source (tests.python.test_scratch_lib.Guards.test_second_source) ... ok
test_two_runs_do_not_collide (tests.python.test_scratch_lib.Guards.test_two_runs_do_not_collide) ... ok
test_unset_or_empty_is_refused (tests.python.test_scratch_lib.Guards.test_unset_or_empty_is_refused) ... ok

----------------------------------------------------------------------
Ran 16 tests in 0.750s

OK
exit 0
```
The same 16 tests against the library of `ba3639a` (mirror `<scratch>/t1rv2/oldscratch`). Hand-made folders with `mktemp`-shaped names, and a copy of a run folder, are deleted (rc 0). The reassigned root moves the deletion scope, and a second `source` leaves the root writable:
```text
....F.F.FFFFF...FF..
FAIL: test_new_writes_the_marker (tests.python.test_scratch_lib.Guards.test_new_writes_the_marker)
AssertionError: False is not true
FAIL: test_remove_refuses_a_copy_or_a_bad_marker (tests.python.test_scratch_lib.Guards.test_remove_refuses_a_copy_or_a_bad_marker)
AssertionError: 0 != 2 : 
FAIL: test_remove_refuses_handmade_mktemp_shaped_folders (tests.python.test_scratch_lib.Guards.test_remove_refuses_handmade_mktemp_shaped_folders) (name='legacy_python')
AssertionError: 0 != 2 : 
FAIL: test_remove_refuses_handmade_mktemp_shaped_folders (tests.python.test_scratch_lib.Guards.test_remove_refuses_handmade_mktemp_shaped_folders) (name='results_backup')
AssertionError: 0 != 2 : 
FAIL: test_remove_refuses_handmade_mktemp_shaped_folders (tests.python.test_scratch_lib.Guards.test_remove_refuses_handmade_mktemp_shaped_folders) (name='tier_b_backup')
AssertionError: 0 != 2 : 
FAIL: test_remove_refuses_handmade_mktemp_shaped_folders (tests.python.test_scratch_lib.Guards.test_remove_refuses_handmade_mktemp_shaped_folders) (name='gallery_output')
AssertionError: 0 != 2 : 
FAIL: test_remove_refuses_handmade_mktemp_shaped_folders (tests.python.test_scratch_lib.Guards.test_remove_refuses_handmade_mktemp_shaped_folders) (name='shoe11_images')
AssertionError: 0 != 2 : 
FAIL: test_root_is_readonly (tests.python.test_scratch_lib.Guards.test_root_is_readonly)
AssertionError: 0 != 1
FAIL: test_second_source (tests.python.test_scratch_lib.Guards.test_second_source)
AssertionError: 'declare -r rac_scratch_root="/tmp/tmpijw9x__1"' not found in 'declare -- rac_scratch_root="/tmp/tmpijw9x__1"\n'
Ran 16 tests in 0.592s
FAILED (failures=9)
exit 1
```
(Traceback frames and separator lines removed by the paste script.)

## 6. Nits (E4; decision A-072)

### 6.1 One OLD record reader for the helpers
`tests/lib/old_records.py` holds the OLD frame (307 x 395) and `parse_records()`/`read_records()`: LF or CRLF, bytes checked to be 0/1, an optional expected separator. It also holds `record_of_idx0()`, `record_of_shoe()` and `shoe_of_record()`. Seven helpers import it instead of their own copies: `plot_contour_platform_diff.py`, `contour_platform_diff.py`, `compare_legacy_python.py`, `old_snake_metrics.py`, `old_snake_gallery.py`, `diag_snake_platform.py` and `test_snake_old_regression.py`. Scripts started as `python path/script.py` put the repo root on `sys.path` first, which also works for a `\\wsl.localhost` path under venv-wind.
```bash
<thesis venv>/bin/python -B -m unittest tests.python.test_old_records -v
```
```text
test_out_of_range (tests.python.test_old_records.Mapping.test_out_of_range) ... ok
test_record_shoe_mapping (tests.python.test_old_records.Mapping.test_record_shoe_mapping) ... ok
test_bad_layouts_are_refused (tests.python.test_old_records.Reader.test_bad_layouts_are_refused) ... ok
test_committed_files (tests.python.test_old_records.Reader.test_committed_files) ... ok
test_expected_separator (tests.python.test_old_records.Reader.test_expected_separator) ... ok
test_lf_and_crlf_give_the_same_records (tests.python.test_old_records.Reader.test_lf_and_crlf_give_the_same_records) ... ok

----------------------------------------------------------------------
Ran 6 tests in 1.334s

OK
exit 0
```
Before and after the switch, on the same inputs. The before outputs were captured with the files of `0a6a727`, before the switch; the inputs were the contour of `<scratch>/t1fix/legacy_py_doxevy` and the committed files; the venv copy was used, and the gallery and diag were also run under venv-wind:
```text
compare_legacy_python: stdout identical (45 lines)
cpd: stdout identical (2 lines)
metrics: stdout identical (9 lines)
diag: stdout identical apart from the OpenCV elapsed-time warning line (8 lines)
overlay: stdout identical apart from the output file name
overlay PNG after == committed docs/qa/T1/old/contour_platform_diff_old.png
contour_platform_diff.csv after == committed tests/baseline/local/contour_linux_diff.csv
contour_platform_diff npz arrays equal before/after/committed: True ['packed', 'records', 'sha_crlf', 'shoes']
diag npz arrays equal before/after: True (16 arrays)
files changed in docs/qa/sheets_old after both metrics runs: 0
gallery (WSL): stdout identical apart from the OpenCV warning line
gallery (WSL) files byte-identical before/after: 11 of 11
shoes: 68; sheets: 9; re-run differs from the committed record for: [11, 21, 80, 152, 176, 221, 349, 354]
exit 1
gallery (venv-wind, after) files byte-identical to the committed docs/qa/sheets_old: 11 of 11
shoes: 68; sheets: 9; re-run differs from the committed record for: []
exit 0
```
On WSL the gallery exits 1 by design: the 8 platform-sensitive shoes of T1 differ from the committed (Windows) records, and its CSV differs from the committed one only in `rerun_diff_px` and `first_snake_rows` of those 8 shoes. Under venv-wind, the diag re-runs shoes 176, 354, 11 and 21 with 0 differing pixels:
```text
Windows 3.13.14 numpy 2.2.6 scipy 1.16.3 skimage 0.25.2
shoe 176: differing px 0; re-run 712 committed 712 contour px; distance to the committed contour mean 0.000 max 0.000
shoe 354: differing px 0; re-run 694 committed 694 contour px; distance to the committed contour mean 0.000 max 0.000
shoe 11: differing px 0; re-run 621 committed 621 contour px; distance to the committed contour mean 0.000 max 0.000
shoe 21: differing px 0; re-run 671 committed 671 contour px; distance to the committed contour mean 0.000 max 0.000
```
**Looked at:** `sheet_old_02.png` of the venv-wind build (byte-identical to the committed sheet). On shoes 29, 35, 38, 55, 56, 61, 66 and 73 the first snake contracts from the red dashed ellipse onto the print, and the second follows the outline. In panel 3 the stickers are red, that is, removed by the mask: a rectangle right of the toe on 29, a small square on 55, a rectangle at the top left on 56, a vertical bar on the right on 66. The blue final contour hugs every print, and no sticker lies inside it. This matches `docs/qa/snake-qa.md`, sheet 2.

### 6.2 `test_no_hardcoding` covers `tests/` with an allowlist (plan T2 step 1)
Revision 4 had excluded all of `tests/`. Now T2's scan covers it, except an explicit list of OLD-only files kept in the test, each with its reason. A new file under `tests/` is scanned unless it is added there. The list in the plan comes from a scan of the current tree for the literals of the test, comment lines excluded. After the switch of 6.1 the remaining hits in the helpers are docstrings, an R diagnostic's frame (`compare_figure_matrices.R`), and `255` used as an 8-bit colour value in the two drawing scripts, which a blind scan would confuse with the NEW width 255:
```bash
for f in $(git ls-files -co --exclude-standard tests | grep -E '\.(py|R|sh)$'); do hits=$(grep -nE "\b(307|395|387|386|255|367|631|126)\b|1:386|\.\./images/|\.\./data/" "$f" | grep -vE '^\s*[0-9]+:\s*#' | wc -l); [[ $hits -gt 0 ]] && echo "$hits $f"; done
```
```text
2 tests/legacy/compare_figure_matrices.R
1 tests/legacy/diag_snake_platform.py
3 tests/legacy/old_snake_gallery.py
1 tests/legacy/old_snake_metrics.py
3 tests/legacy/plot_contour_platform_diff.py
1 tests/lib/contour_platform_diff.py
7 tests/lib/old_records.py
4 tests/python/test_baseline_raw_data.py
12 tests/python/test_old_records.py
7 tests/python/test_snake_old_regression.py
5 tests/r/test_baseline_committed.R
```

### 6.3 The serialization assertion and the spacing
`test_compare_glmm_fits.R` now prints `NOTE two reads of the committed GLMM identical(): FALSE` instead of asserting it (a later R or lme4 may serialize these environments identically, with nothing wrong). `test_step5_variant.R`: `out <- suppressWarnings(`. Both pass in `run_all.sh` (section 7).

### 6.4 Shoe 11's heel (the overlay description)
**Looked at:** a zoom of the heel of shoe 11 in `docs/qa/T1/old/contour_platform_diff_old.png`. Green (Windows) and magenta (WSL) run side by side around the whole heel, with only a few white (shared) pixels at the lower left. The description "the heel is shared" in `T1-review-fixes-results.md` section 5.3 was wrong. The numbers from the two records:
```bash
<scratch>/t1/venv_copy/bin/python -B -c "<count shared / Windows-only / WSL-only pixels in the top and bottom 20% of the rows of record_of_shoe(11), and which outline is further out per row>"
```
```text
toe (top 20%): rows 70-123: both 41, Windows only 108, WSL only 110
heel (bottom 20%): rows 287-341: both 18, Windows only 128, WSL only 129
heel rows where the left edge is further out: Windows 45 WSL 7 ; right edge: Windows 0 WSL 49
lowest row: Windows 340 WSL 341
```
So the WSL outline is shifted about one pixel to the right and down around the heel. The corrected sentence is in `T1-review-fixes-results.md` section 5.3, marked as a correction. The other three shoe descriptions were confirmed by the reviewer.

## 7. The fast suite at the end of this pass
```bash
bash tests/run_all.sh
```
```text
Ran 52 tests in 35.377s
OK (skipped=3)
flake8: 26 files (contour_algorithm/ excluded until T2c)
shellcheck: 9 files
[... the per-test lines of the Python and R tests omitted ...]
== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS        40s  python unittest discover tests/python
PASS         4s  Rscript tests/r/test_baseline_committed.R
PASS        22s  Rscript tests/r/test_compare_glmm_fits.R
PASS         3s  Rscript tests/r/test_compare_models.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS         8s  Rscript tests/r/test_run_manifest.R
PASS         1s  Rscript tests/r/test_step5_variant.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python except contour_algorithm/ until T2c)
PASS         1s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS
real	1m27.505s
user	1m49.154s
sys	0m13.770s
```

## 8. OLD regression at the end of this pass
- **Tier A files:** no committed data, model, figure, Rmd, `config.R` or legacy `.py` file changed in this pass. 24 of 24 Tier A and 11 of 11 OLD checksums verify (`run_all.sh`).
- **Python on WSL** (`legacy_py_rJehu1`, strict live checks): the contour (`d43fda7e...` LF, `e18d50df...` as CRLF) and all 1,556 intermediates equal Tier B, and all are newer than the start. Against Tier A: 30 of 386 records differ (19,027 px), as in T1, because the committed contour is a Windows result (A-060).
- **R on WSL** (`legacy_r_ck4pCJ`, all six steps, strict live checks, section 1.4): all 15 outputs deleted before the run and regenerated by it. The five CSVs are byte-identical to Tier B, both models are `identical()` to Tier B in every field, the 8 normalized PDFs equal Tier B, and step 5 prints W = 427.7804 (df 24), as in T1. Against Tier A, as in T1: the step-1 CSVs equal the committed bytes after LF -> CRLF, and the step-2 CSVs and the CML equal Tier A. The GLMM differs on WSL (`test_old_regression.R` pins the T1 differences: max |dfixef| 0.000767, W 427.7804 against 428.6933).
- **Windows R step 3** (`winr_step3_kMdls7`): 27 of 27 fields equal the Tier A blob; its dump equals the committed dump in 22 of 22 fields (`compare_models.R` exit 0).
- **Gallery under venv-wind:** all 11 committed `docs/qa/sheets_old/` files reproduced byte for byte by the consolidated script.
- **Unchanged from T1:** WSL differs from Tier A in the contour (30 records), in the GLMM (no stored Hessian, max fixef difference 7.7e-4) and in PNG, PDF and `.rds` bytes, each with its proven cause.

## 9. Timings (this pass, three jobs in parallel; load average up to 29 on 16 cores)
| Job | Seconds | Source |
|---|---|---|
| Legacy Python run, all 387 shoes (`legacy_py_rJehu1`) | 1046.3 (17:26 wall, 8015 s user) | `timing.txt`, `logs/main.log` |
| Legacy R step 1 / step 2 | 146.4 / 1386.9 | `legacy_r_ck4pCJ/timings.tsv` |
| Legacy R step 3: GLMM / CML | 259.6 / 202.8 | same |
| Legacy R step 4: GLMM / CML; step 5; step 6 | 13.4 / 13.1; 25.3; 17.9 | same |
| Windows R step 3 (`winr_step3_kMdls7`): knit / whole runner | 631.3 / 635.0 | `logs/step3_win.log`, `timings.tsv` |
| `write_environment.sh` | 87 | `time` |
| `tests/python/test_runner_outputs.py` (stub runners) | 8.9 to 17.5 | unittest |
| `tests/r/test_run_manifest.R` | 8 to 13 | `run_all.sh`, `time` |
| `bash tests/run_all.sh` (first run of this pass, under load) | 97.5 | `time` |
| `bash tests/run_all.sh` (final run of this pass) | 87.5 | `time` |

## 10. Files created or changed in this pass
- **New code and tests:** `tests/lib/run_outputs.sh`, `tests/lib/run_manifest.R`, `tests/lib/run_manifest.py`, `tests/lib/old_records.py`, `tests/python/test_run_manifest.py`, `tests/python/test_runner_outputs.py`, `tests/python/test_live_r_pdfs.py`, `tests/python/test_old_records.py`, `tests/r/test_run_manifest.R`.
- **Changed code:** `tests/lib/scratch.sh`, `tests/lib/compare_models.R`, `tests/lib/write_environment.sh`, `tests/legacy/run_legacy_r.sh`, `run_legacy_python.sh`, `run_windows_r_step3.sh`, the seven helpers of 6.1, `tests/r/test_old_regression.R`, `test_compare_models.R`, `test_compare_glmm_fits.R`, `test_step5_variant.R`, `tests/python/test_scratch_lib.py`, `test_snake_old_regression.py`.
- **Baseline:** `tests/baseline/local/environment.txt` (regenerated; diff in section 4), `tests/baseline/README.md`.
- **Docs:** this file; the plan (Revision 5: F21, F40, section 4.5, T2 files, T2 step 1 `test_no_hardcoding`, T2 step 3, T4 step 8); `docs/decisions.md` (A-067 to A-072; update notes on A-060, A-062, A-065, A-066); `docs/tests/T1-review-fixes-results.md` (shoe 11); `docs/tests/README.md`; `docs/qa/snake-qa.md` (platform note); `docs/progress/LOG.md`.
