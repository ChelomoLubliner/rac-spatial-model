# T1 review fixes: results (OLD dataset)

**Date:** 2026-11-06. **Branch:** `feature/new-shoes-pipeline`. **Task:** fix the findings of the two T1 reviews (engineering `e94cc4a`, reproducibility `38d12fa`; both in `docs/progress/LOG.md`).
**Scratch:** `<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`; this pass works in `<scratch>/t1fix/` (`RAC_SCRATCH=<scratch>/t1fix`).
Every output below is pasted from the real run. Absolute scratch paths are shortened to `<scratch>`; trimmed output is marked `[... omitted ...]`; nothing else is edited.

## 0. Summary

Findings are numbered as in the review task: **B1** = the blocking finding, **m1-m10** = the minor notes in the order given.

| Finding | Fix | Evidence | Commit |
|---|---|---|---|
| **B1** (major) `rac_scratch_remove` deletes the scratch root (`"$RAC_SCRATCH/"`) and nested paths | Deletes only a real directory directly under the validated root, named `NAME_XXXXXX`; trailing slashes stripped; `//`, `.`, `..` refused (A-062) | Bug reproduced; the new tests fail on the old library (20 subtests) and pass on the new one (11 tests); on a mirror of the real scratchpad only `mktemp` run folders are accepted (section 1) | `823a80c` |
| **m1** A WSL-only step-3 gate cannot show Tier A | `tests/legacy/run_windows_r_step3.sh` + `tests/lib/compare_glmm_fits.R`; T2 gate extended; Windows R `sessionInfo()` recorded (A-065) | The committed GLMM reproduced in 27 of 27 fields, its dump in 22 of 22 (section 4) | `33c519f` |
| **m2, m6** The "live" checks were circular; "deterministic" not shown | Relabelled as Tier B hash-file consistency checks; determinism rests on independent full reruns (A-066) | The reviewer's runs re-checked with the repo tests; fresh full Python and R reruns at `2196d83` (section 5) | docs commit |
| **m3, m8** `contour_algorithm/` overwrites the committed contour if run in place; 106 flake8 findings | T2c first, T2d right after T2a; how to run it and how to restore the contour documented; lint in `run_all.sh` with that folder excluded until T2c (A-064) | Plan T2, `contour_algorithm/README.md`; the lint check catches a probe file (section 3.3) | `2196d83`, docs commit |
| **m4, m9b** Section 4.3 called image indices "records" | Both lists given, computed from `contour_linux_diff.csv` | Section 6.2 | docs commit |
| **m5** Thesis repo touched in the T0 window (outside T1) | Recorded; nothing to change | Section 7 | docs commit |
| **m7** `wald_all_spatial()` accepts a permuted `V`; intercept dropped by position | `V`'s dimnames must equal the coefficient names in order; intercept dropped by name (A-063) | Section 2 | `b955103` |
| **m9a** Section 5.3 dropped two table rows silently | Full table pasted; the same slip in the two diagnostic blocks of section 5.3 fixed with regenerated full tables | Section 6.3 | docs commit |
| **m10** `compare_dumps()` ignores missing fields; `step5_without_car.R` assumptions; `.claude` in the tree snapshot; OLD constants in helpers | Stop on missing fields; two assertions; `.claude` pruned; `tests/` scoped out of T2's `test_no_hardcoding` | Sections 3.1, 3.2, 3.3; plan T2 | `2196d83` |

Also in this pass: the overlay diagnostic `tests/legacy/plot_contour_platform_diff.py` and its evidence image `docs/qa/T1/old/contour_platform_diff_old.png` (`8d96427`, section 5.3).

## 1. The scratch deletion guard (blocking finding; A-062)

### 1.1 The bug, reproduced with the old library
```bash
cd <scratch>/t1fix && rm -rf repro_bug && mkdir -p repro_bug/root/keep_me repro_bug/root/a/b && echo keep > repro_bug/root/keep_me/file.txt && ROOT=$(cd repro_bug/root && pwd -P) && for target in "$ROOT/a/b" "$ROOT/"; do RAC_SCRATCH=$ROOT bash -c 'set -euo pipefail; source /home/mehes/projects/rac-spatial-model/tests/lib/scratch.sh; rac_scratch_remove "$1"; echo "rc=$?"' _ "$target"; echo "target $target exists after: $(test -e "$target" && echo yes || echo no); root exists: $(test -d "$ROOT" && echo yes || echo no)"; done
```
```text
rc=0
target <scratch>/t1fix/repro_bug/root/a/b exists after: no; root exists: yes
rc=0
target <scratch>/t1fix/repro_bug/root/ exists after: no; root exists: no
```
Both defects are confirmed: the nested `a/b` is deleted, and `"$ROOT/"` deletes the root together with `keep_me/file.txt`.

### 1.2 The fix and its tests
`rac_scratch_remove` now strips trailing slashes and refuses `//`, `.` and `..` components. It deletes only if the parent is exactly the `RAC_SCRATCH` validated at source time (kept in `rac_scratch_root`), the name matches `^[A-Za-z0-9_.-]+_[A-Za-z0-9]{6}$` and the path is a real directory, not a symlink. New tests in `tests/python/test_scratch_lib.py`:
- `test_remove_refuses_root_and_non_run_paths`: `$tmp/`, `$tmp//`, `$tmp/.`, `$tmp/./`, `$tmp/..`, `$tmp/a/b`, a nested `mktemp`-shaped `$tmp/a/b_abcdef` (also reached through `a/../a/`), `$tmp/keep_me` (also as `keep_me/` and `//keep_me`), `$tmp/venv_copy`, a plain file `$tmp/file_abcdef`, the relative `keep_me`, and `/`. Each must exit 2, and the target and `keep_me/file.txt` must survive.
- `test_empty_name_does_not_wipe_the_root`: `rac_scratch_remove "$RAC_SCRATCH/$name"` with `name=""`.
- `test_remove_refuses_a_symlink`: `link_abcdef -> <another folder>`, with and without a trailing slash.
- `test_remove_ignores_a_later_change_of_rac_scratch`: `RAC_SCRATCH` emptied or moved after sourcing.
- `test_remove_run_with_trailing_slash_spares_siblings`: a real run folder is still removed (given as `"$a/"`), and every sibling survives.
```bash
<scratch>/t1/venv_copy/bin/python -B -m unittest tests.python.test_scratch_lib -v
```
```text
test_bad_run_name (tests.python.test_scratch_lib.Guards.test_bad_run_name) ... ok
test_dangerous_roots_are_refused (tests.python.test_scratch_lib.Guards.test_dangerous_roots_are_refused) ... ok
test_empty_name_does_not_wipe_the_root (tests.python.test_scratch_lib.Guards.test_empty_name_does_not_wipe_the_root) ... ok
test_new_and_remove (tests.python.test_scratch_lib.Guards.test_new_and_remove) ... ok
test_remove_ignores_a_later_change_of_rac_scratch (tests.python.test_scratch_lib.Guards.test_remove_ignores_a_later_change_of_rac_scratch) ... ok
test_remove_refuses_a_symlink (tests.python.test_scratch_lib.Guards.test_remove_refuses_a_symlink) ... ok
test_remove_refuses_outside_paths (tests.python.test_scratch_lib.Guards.test_remove_refuses_outside_paths) ... ok
test_remove_refuses_root_and_non_run_paths (tests.python.test_scratch_lib.Guards.test_remove_refuses_root_and_non_run_paths) ... ok
test_remove_run_with_trailing_slash_spares_siblings (tests.python.test_scratch_lib.Guards.test_remove_run_with_trailing_slash_spares_siblings) ... ok
test_two_runs_do_not_collide (tests.python.test_scratch_lib.Guards.test_two_runs_do_not_collide) ... ok
test_unset_or_empty_is_refused (tests.python.test_scratch_lib.Guards.test_unset_or_empty_is_refused) ... ok

----------------------------------------------------------------------
Ran 11 tests in 0.422s

OK
```
**Red check:** the same test file run against the old library (`git show HEAD:tests/lib/scratch.sh`, before the fix commit) in a throwaway copy, with `TMPDIR` inside `<scratch>/t1fix/oldlib_check` so that nothing real could be hit. A first attempt put that copy at `<scratch>/t1fix/oldlib_check/tests/lib/`. The copied library then took `oldlib_check/` for the repository and refused every `RAC_SCRATCH` below it at source time, so that run proved nothing and was discarded. The valid run keeps the copy outside `TMPDIR`:
```bash
cd <scratch>/t1fix/oldlib_check/py && TMPDIR=<scratch>/t1fix/oldlib_check/tmp <scratch>/t1/venv_copy/bin/python -B -m unittest test_scratch_lib_oldlib 2>&1 | tail -3
```
```text
Ran 11 tests in 0.416s

FAILED (failures=20)
```
The failing subtests start with `target=<root>/` (`AssertionError: 0 != 2`: the old guard returned 0 and deleted the root). Every later subtest of that test then fails because the tree is gone. The symlink, empty-`$name` and changed-`RAC_SCRATCH` cases also return 0. The fixed library on the same reproduction:
```text
scratch.sh: refusing to delete '<scratch>/t1fix/oldlib_check/repro2/a/b' (only a run folder NAME_XXXXXX directly under <scratch>/t1fix/oldlib_check/repro2)
rc=2
target <scratch>/t1fix/oldlib_check/repro2/a/b exists after: yes; keep_me/file.txt: yes
scratch.sh: refusing to delete '<scratch>/t1fix/oldlib_check/repro2/' (only a run folder NAME_XXXXXX directly under <scratch>/t1fix/oldlib_check/repro2)
rc=2
target <scratch>/t1fix/oldlib_check/repro2/ exists after: yes; keep_me/file.txt: yes
```

### 1.3 What the guard accepts on the real scratchpad layout
An empty mirror of the entry names of `<scratch>/t1`, `<scratch>` and `<scratch>/review_t1_repro` was built (directories as empty directories, files as empty files, symlinks as dangling symlinks) in a fresh `mktemp` folder, `<scratch>/t1fix/mirror_leUZA9`. Then `rac_scratch_remove` was called on every mirrored entry, with `RAC_SCRATCH` set to the mirrored folder. Nothing real was touched.
```text
t1: entries 20; accepted for deletion: legacy_py_MXmkvc legacy_py_o4gTOt legacy_r_OB7DF8 legacy_r_oTZO3x
scratchpad: entries 18; accepted for deletion: none
review_t1_repro: entries 25; accepted for deletion: liveR_95moUH pychain_ZlQAFJ rchain_l8x7yU winR_qxv82f
```
Only `mktemp` run folders are accepted; `venv_copy`, `diag_glmm`, `diag_snake`, `gallery_*`, `try5_BNv6` and the task folders are refused. (A first version of this check, which pre-cleaned and removed its mirror with `rm -rf "$W"`, was stopped by the Claude Code safety check for unresolvable `rm -rf` targets. It was rewritten without any explicit removal; the mirror folder stays in scratch.)

## 2. `wald_all_spatial()`: dimnames of V, intercept by name (A-063)

On the committed models the default vcov dimnames equal the coefficient names (so the new check cannot break the default path or `dump_models()`):
```text
glmm vcov dimnames == names(fixef): TRUE TRUE
glmm vcov_rx dimnames == names(fixef): TRUE TRUE
intercept name and position: (Intercept) 1
cml vcov dimnames == names(coef): TRUE TRUE  any (Intercept): FALSE
W with a permuted V used by position: 1884.9060 (correct 428.6933)
```
```bash
Rscript tests/r/test_wald.R
```
```text
PASS committed GLMM: W = 428.693335, df = 24, p = 9.43e-76
PASS L-matrix form 428.6933350011 and Cholesky form 428.6933350011 agree
PASS explicit V = identity gives sum(b^2)
PASS V without dimnames is used by position (same W as the default)
PASS permuted V with dimnames is an error (used by position it would give W = 1884.91)
PASS wrong row names or reversed column names are an error
PASS cbpp merMod: intercept dropped by name, W = 25.4882, df = 3
PASS merMod without an intercept is an error
PASS committed CML: W = 420.671242, df = 24
PASS unsupported model class is an error
SKIPPED car comparison: car not installed
ALL PASS test_wald
```
**Red check:** the new test against the old `wald.R` (`git show HEAD:statistical_model/R/wald.R` before the fix commit, in `<scratch>/t1fix/oldwald_*` with copies of the two models):
```text
PASS committed GLMM: W = 428.693335, df = 24, p = 9.43e-76
PASS L-matrix form 428.6933350011 and Cholesky form 428.6933350011 agree
PASS explicit V = identity gives sum(b^2)
PASS V without dimnames is used by position (same W as the default)
Error: grepl("not the coefficient names", msg_of(wald_all_spatial(g,  .... is not TRUE
Execution halted
exit 1
```
and the old function on a merMod without an intercept (`cbpp`, `~ 0 + period + (1 | herd)`):
```text
old wald.R: no error; df = 3 (of 4 coefficients; period1 silently dropped)
```
**car branch under the Windows R 4.4.3 (car 3.1-3):**
```bash
cd /mnt/c && /mnt/c/Users/mehes/AppData/Local/Programs/R/R-4.4.3/bin/Rscript.exe '\\wsl.localhost\Ubuntu\home\mehes\projects\rac-spatial-model\tests\r\test_wald.R' 2>&1 | tr -d '\r'
```
```text
PASS committed GLMM: W = 428.693335, df = 24, p = 9.43e-76
PASS L-matrix form 428.6933350011 and Cholesky form 428.6933350011 agree
PASS explicit V = identity gives sum(b^2)
PASS V without dimnames is used by position (same W as the default)
PASS permuted V with dimnames is an error (used by position it would give W = 1884.91)
PASS wrong row names or reversed column names are an error
PASS cbpp merMod: intercept dropped by name, W = 25.4882, df = 3
PASS merMod without an intercept is an error
PASS committed CML: W = 420.671242, df = 24
PASS unsupported model class is an error
PASS car::linearHypothesis W = 428.693335 equals the manual W
ALL PASS test_wald
```
(6.6 s; `git status` clean afterwards.)

## 3. Helpers and the fast suite

### 3.1 `compare_dumps()` refuses missing fields
```bash
Rscript tests/r/test_compare_models.R
```
```text
PASS a dump compared with itself: 22 fields, all identical
PASS Tier A vs Tier B: all 22 fields compared; the 10 that differ are the GLMM estimates (T1 section 5.3)
PASS a field missing from either dump, or an extra field, is an error
ALL PASS test_compare_models
```
Red check, the new test with the old `compare_models.R`:
```text
PASS a dump compared with itself: 22 fields, all identical
PASS Tier A vs Tier B: all 22 fields compared; the 10 that differ are the GLMM estimates (T1 section 5.3)
Error: grepl("only in a: vcov_rx; only in b: $", e1) is not TRUE
Execution halted
exit 1
```

### 3.2 `step5_without_car.R`: same variant, bad inputs refused
The variant of the committed Rmd (the `79247d8` blob, which the legacy runner extracts) is byte-identical to the one both T1 chains ran:
```bash
git show 79247d8:statistical_model/statistical_tests_5.Rmd > in.Rmd; Rscript tests/legacy/step5_without_car.R in.Rmd out.Rmd; sha256sum out.Rmd <scratch>/t1/legacy_r_oTZO3x/repo/statistical_model/statistical_tests_5.Rmd <scratch>/t1/legacy_r_OB7DF8/repo/statistical_model/statistical_tests_5.Rmd
```
```text
step5_without_car: removed line 20 (library(car)); replaced lines 125 to 130 by the manual Wald test
4b0249dcb2bbe266f8361b7d2dfbc58dc29fc9852852ed370fcbf80bf1e4e13e  <scratch>/t1fix/step5var_Nwq57j/out.Rmd
4b0249dcb2bbe266f8361b7d2dfbc58dc29fc9852852ed370fcbf80bf1e4e13e  <scratch>/t1/legacy_r_oTZO3x/repo/statistical_model/statistical_tests_5.Rmd
4b0249dcb2bbe266f8361b7d2dfbc58dc29fc9852852ed370fcbf80bf1e4e13e  <scratch>/t1/legacy_r_OB7DF8/repo/statistical_model/statistical_tests_5.Rmd
identical to the chain A variant
```
```bash
Rscript tests/r/test_step5_variant.R
```
```text
PASS committed Rmd -> the T1 step-5 variant (sha256 4b0249dcb2bb...)
PASS synthetic input: car line removed, chunk replaced, the rest kept
PASS print(testing) as the last line and library(car) after the chunk are refused
ALL PASS test_step5_variant
```
The old script on the two bad inputs: exit 0 both times, with wrong variants.
```text
step5_without_car: removed line 1 (library(car)); replaced lines 3 to 5 by the manual Wald test
last_line: exit 0; output:
    a <- 1
    # T1 scratch variant: manual Wald test (car is not installed here).
    source(paste(ROOT_PATH, "statistical_model/R/wald.R", sep = ""))
    testing <- wald_all_spatial(random_model)
    print(testing)
    NA
    print(testing)
step5_without_car: removed line 5 (library(car)); replaced lines 2 to 4 by the manual Wald test
car_after: exit 0; output:
    a <- 1
    # T1 scratch variant: manual Wald test (car is not installed here).
    source(paste(ROOT_PATH, "statistical_model/R/wald.R", sep = ""))
    testing <- wald_all_spatial(random_model)
    library(car)
    b <- 2
```
(In the second case the old splice deleted `print(testing)` instead of `library(car)`.)

### 3.3 Lint in `run_all.sh`; `.claude` pruned
`tests/run_all.sh` gained two checks: flake8 on every tracked or new Python file except `contour_algorithm/` (until T2c), and shellcheck on every shell script. Its work-tree snapshot now skips `.claude/` as well as `.git/`. The check catches a new, untracked bad file:
```bash
printf 'import os\nx=1\n' > tests/python/lint_probe_tmp.py && bash -c 'source <(sed -n "/^code_files()/,/^}/p;/^lint_python()/,/^}/p" tests/run_all.sh); lint_python; echo "lint_python exit $?"'; rm tests/python/lint_probe_tmp.py
```
```text
flake8: 20 files (contour_algorithm/ excluded until T2c)
tests/python/lint_probe_tmp.py:1:1: F401 'os' imported but unused
tests/python/lint_probe_tmp.py:2:2: E225 missing whitespace around operator
lint_python exit 1
```

## 4. A Tier A gate for step 3 under the Windows R (A-065)

### 4.1 Why the comparison is field by field
Two reads of the same `.rds` file are not `identical()`, and not even `all.equal()`:
```text
identical(whole): FALSE | all.equal(whole): FALSE | identical(optinfo): TRUE | Hessian dim: 26 26
resp     identical FALSE all.equal FALSE
Gp       identical TRUE  all.equal TRUE
call     identical FALSE all.equal TRUE
frame    identical FALSE all.equal TRUE
flist    identical TRUE  all.equal TRUE
cnms     identical TRUE  all.equal TRUE
lower    identical TRUE  all.equal TRUE
theta    identical TRUE  all.equal TRUE
beta     identical TRUE  all.equal TRUE
u        identical TRUE  all.equal TRUE
devcomp  identical TRUE  all.equal TRUE
pp       identical FALSE all.equal FALSE
optinfo  identical TRUE  all.equal TRUE
frame without terms/formula attrs identical: TRUE
resp mu/eta/y/wtres identical: TRUE TRUE TRUE TRUE
X, Zt, Lambdat identical: TRUE TRUE TRUE
```
`tests/lib/compare_glmm_fits.R` therefore compares 27 fields: 25 with `identical()` and `call` and `frame` with `all.equal()`. While testing it I found that the object's history matters. A copy saved after one comparison differed from its source file in `resp_mu` and `resp_wtres` (`RESULT 23 of 27`). Tracing it, the first lme4 access to `resp$wtres` builds the C++ object behind `resp` and recomputes `resp$mu`:
```text
fresh object, only resp$wtres read -> mu changed: TRUE  max|dmu| 1.110223e-16
```
So the library compares fresh reads only (`compare_glmm_files()`, used by the CLI), and the test makes each changed copy from a fresh read.
```bash
Rscript tests/r/test_compare_glmm_fits.R
```
```text
PASS committed GLMM vs a second read of it: 27 of 27 fields the same
PASS an intercept changed by 1e-12: exactly beta and fixef differ
PASS a stored Hessian entry changed: optinfo and the default vcov differ, the RX vcov does not
PASS CLI: exit 0 for the same fit, 1 (25 of 27 the same) for the changed one
ALL PASS test_compare_glmm_fits
```

### 4.2 The run on the unmodified step 3 (at `2196d83`, with the runner as committed in `33c519f`)
```bash
RAC_SCRATCH=<scratch>/t1fix bash tests/legacy/run_windows_r_step3.sh   # -> <scratch>/t1fix/winr_step3_dDeVqT
```
`timing.txt`, `logs/step3_win.log`, `compare.txt`, `exit_status`:
```text
start 2026-11-06T01:52:10+02:00
end 2026-11-06T02:01:13+02:00
exit 0
seconds 542.540656700
[1] "../../step3_win.md"
knit seconds 541.1
R version 4.4.3 (2025-02-28 ucrt) | lme4 1.1.37 | Matrix 1.7.2
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
0
```
The copy held only `statistical_model/`, `processed_data/dataCC_distance.csv`, `processed_data/shoe_pixel_counts.csv` and `data/all_cont.csv` of `79247d8`, and an empty `saved_models/`, so the knit wrote the model it is compared on. The new `.rds` has sha256 `9bc6eccf...` and the committed one `ae670fd3...`: the bytes differ (serialized environments), the fit does not. The same fit through the T1 dump tools against the Tier A dump:
```bash
Rscript tests/lib/dump_models.R <run>/repo/saved_models/NEW_X_NS_XY.rds saved_models/CML_MODEL.rds <run>/models_winr.rds <run>/models_winr_summary
Rscript tests/lib/compare_models.R tests/baseline/models_committed.rds <run>/models_winr.rds
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
exit 0
```
(The CML part is the committed CML on both sides; the point is the GLMM rows.) **The committed GLMM is reproduced exactly with in-repo tooling.**

### 4.3 The Windows R `sessionInfo()` in `environment.txt`
`tests/lib/write_environment.sh` now loads splines, lme4 and survival in the Windows R and prints `sessionInfo()`. The regenerated file against the T1 version:
```bash
bash tests/lib/write_environment.sh > <scratch>/t1fix/environment_new.txt; diff tests/baseline/local/environment.txt <scratch>/t1fix/environment_new.txt
```
```text
1c1
< # Environment of the T1 Tier B reruns, recorded 2026-11-06T00:19:03+02:00
---
> # Environment of the T1 Tier B reruns, recorded 2026-11-06T01:44:00+02:00
9c9
< this repo: e4fedce3f5221591beb2317898a19964019f1c4c (feature/new-shoes-pipeline)
---
> this repo: 2196d8319f37d0e18f2a7253f2eb476b04818b9f (feature/new-shoes-pipeline)
139a140,168
> R version 4.4.3 (2025-02-28 ucrt)
> Platform: x86_64-w64-mingw32/x64
> Running under: Windows 11 x64 (build 26300)
>
> Matrix products: default
>
>
> locale:
> [1] LC_COLLATE=English_United States.utf8
> [2] LC_CTYPE=English_United States.utf8
> [3] LC_MONETARY=English_United States.utf8
> [4] LC_NUMERIC=C
> [5] LC_TIME=English_United States.utf8
>
> time zone: Asia/Jerusalem
> tzcode source: internal
>
> attached base packages:
> [1] splines   stats     graphics  grDevices utils     datasets  methods
> [8] base
>
> other attached packages:
> [1] survival_3.8-3 lme4_1.1-37    Matrix_1.7-2
>
> loaded via a namespace (and not attached):
>  [1] minqa_1.2.8      MASS_7.3-64      compiler_4.4.3   reformulas_0.4.1
>  [5] tools_4.4.3      Rcpp_1.1.0       nlme_3.1-167     grid_4.4.3
>  [9] rbibutils_2.3    nloptr_2.2.1     boot_1.3-31      Rdpack_2.6.4
> [13] lattice_0.22-6
```
Only the timestamp, the repo commit and the new section differ. So the WSL R packages, both `pip freeze` lists and the Windows Python are unchanged since the T1 runs, and the regenerated file replaced the old one (61 s).

## 5. Determinism evidence from runs Tier B was not written from (A-066)

Tier B was written from `<scratch>/t1/legacy_py_MXmkvc` (Python) and chain A `<scratch>/t1/legacy_r_oTZO3x` (R). Every run below is a different run.

### 5.1 The reproducibility reviewer's Python run (`<scratch>/review_t1_repro/pychain_ZlQAFJ`: thesis code from the `109f30a` blobs, inputs from the `79247d8` blobs, its own driver), checked with the repo tests
```bash
RAC_REGRESS_PY_RUN=<scratch>/review_t1_repro/pychain_ZlQAFJ MPLBACKEND=Agg <scratch>/t1/venv_copy/bin/python -B -m unittest tests.python.test_snake_old_regression.SnakeOld.test_full_run_folder -v
(cd <scratch>/review_t1_repro/pychain_ZlQAFJ && sha256sum --quiet -c /home/mehes/projects/rac-spatial-model/tests/baseline/local/python_intermediates.sha256; echo "sha256sum -c exit $?")
find <scratch>/review_t1_repro/pychain_ZlQAFJ/images -type f \( -name '*.npy' -o -name '*.png' \) | wc -l
sha256sum <scratch>/review_t1_repro/pychain_ZlQAFJ/data/contour_Active_Contour.txt; head -1 tests/baseline/local/python_contour.sha256
```
```text
== records (RAC_REGRESS_PY_RUN=<scratch>/review_t1_repro/pychain_ZlQAFJ)
----------------------------------------------------------------------
Ran 1 test in 2.882s

OK
== intermediates vs tests/baseline/local/python_intermediates.sha256
sha256sum -c exit 0
Tier B lines: 1556; npy+png files in the run's images/: 1556
== contour
d43fda7eb631599eb1b7ebb8775e0c7d82c5ef40c9e5272165542c0f2f8aa917  <scratch>/review_t1_repro/pychain_ZlQAFJ/data/contour_Active_Contour.txt
d43fda7eb631599eb1b7ebb8775e0c7d82c5ef40c9e5272165542c0f2f8aa917  data/contour_Active_Contour.txt
```
All 386 records, all 1,556 intermediates (no file missing, none extra) and the contour bytes equal Tier B.

### 5.2 The reproducibility reviewer's R chain (`rchain_l8x7yU`, all six steps from `git archive 79247d8` with every output deleted first; reached through the symlink `liveR_95moUH/repo`)
```bash
RAC_REGRESS_R_RUN=<scratch>/review_t1_repro/liveR_95moUH Rscript tests/r/test_old_regression.R
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
```
(This ran with the stricter `compare_dumps()`, so no dump field was skipped.)

### 5.3 A fresh legacy Python run of this pass (at `2196d83`, the in-repo runner, the verified venv copy)
```bash
RAC_SCRATCH=<scratch>/t1fix RAC_VENV_PY=<scratch>/t1/venv_copy/bin/python bash tests/legacy/run_legacy_python.sh   # -> <scratch>/t1fix/legacy_py_doxevy
```
```text
start 2026-11-06T01:42:35+02:00
end 2026-11-06T01:55:40+02:00
exit 0
seconds 784.653735530
	User time (seconds): 6659.82
	Elapsed (wall clock) time (h:mm:ss or m:ss): 13:04.64
	Maximum resident set size (kbytes): 562684
```
(785 s instead of T1's 509 s: the R chain and the Windows R step 3 ran at the same time; load average up to 17 on 16 cores.)
```text
== records (RAC_REGRESS_PY_RUN=<scratch>/t1fix/legacy_py_doxevy)
----------------------------------------------------------------------
Ran 1 test in 2.582s

OK
== intermediates
sha256sum -c exit 0
Tier B lines: 1556; npy+png files in the run's images/: 1556
== contour
d43fda7eb631599eb1b7ebb8775e0c7d82c5ef40c9e5272165542c0f2f8aa917  <scratch>/t1fix/legacy_py_doxevy/data/contour_Active_Contour.txt
e18d50df5da9599440c99f9fbb6f23ce98bdc695479a4078c06feb96b9b1b7c4  (LF -> CRLF)
d43fda7eb631599eb1b7ebb8775e0c7d82c5ef40c9e5272165542c0f2f8aa917  data/contour_Active_Contour.txt
e18d50df5da9599440c99f9fbb6f23ce98bdc695479a4078c06feb96b9b1b7c4  data/contour_Active_Contour.txt [LF->CRLF]
```
Against Tier A (the committed files), the same picture as in T1:
```bash
<scratch>/t1/venv_copy/bin/python -B tests/lib/compare_legacy_python.py <scratch>/t1fix/legacy_py_doxevy | grep -v "^  record"
```
```text
# legacy Python run <scratch>/t1fix/legacy_py_doxevy
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
(Exit 1 because the WSL contour is not the committed Windows one, as recorded in T1. The 30 per-record lines are omitted by the `grep -v`.)

**Looked at:** `images/active-contour/im_175.png` of this run (shoe 176, the record with the most differing pixels, 1,402). The blue snake hugs the whole print: the toe at the top, the narrow waist at the midfoot followed on both sides, the heel at the bottom with a small notch at its lower centre. The cleaned shoe has no sticker or speck left. At this scale it matches the Windows panels of shoe 176 on `docs/qa/sheets_old/sheet_old_05.png`, where the specks to the right of the forefoot are drawn in red as removed. The zoomed overlay `docs/qa/T1/old/contour_platform_diff_old.png` (`tests/legacy/plot_contour_platform_diff.py`, committed (Windows) record vs this run's record; white both, green Windows only, magenta WSL only) shows what the 30 records' differences look like:
```bash
<scratch>/t1/venv_copy/bin/python -B tests/legacy/plot_contour_platform_diff.py <scratch>/t1fix/legacy_py_doxevy/data/contour_Active_Contour.txt docs/qa/T1/old/contour_platform_diff_old.png 21 176 11 354
```
```text
shoe 21 (record 21): 824 px differ
shoe 176 (record 175): 1402 px differ
shoe 11 (record 11): 855 px differ
shoe 354 (record 353): 18 px differ
wrote docs/qa/T1/old/contour_platform_diff_old.png (1530, 975)
```
- **Shoe 21:** most of the outline is shared or offset by one pixel. Along the left side of the midfoot (the arch, roughly 45-65% of the height), the Windows contour bows several pixels further into the concavity, while the WSL contour runs almost straight. This is the 8.94 px maximum of `contour_linux_diff.csv`.
- **Shoe 176:** a parallel one-pixel offset almost all the way round (green beside magenta, very little white), plus a small bump of the WSL contour at the top right of the toe (max 6.08 px).
- **Shoe 11** (a partial print): the toe's top left differs (the WSL contour follows the toe edge further out), and at the left arch the Windows contour again bows inward (max 8.00 px). The heel is **not** shared (corrected after the second T1 review, which saw alternating one-pixel offsets there): around the heel the two outlines run side by side about one pixel apart, the WSL outline shifted right and down. In the bottom 20% of the rows (287-341) only 18 pixels are on both contours, 128 only on the Windows one and 129 only on the WSL one; the left edge is further out on Windows in 45 rows, the right edge further out on WSL in 49 rows, and the WSL outline reaches one row lower (341 vs 340). Numbers from the two records; command in `docs/tests/T1-review2-fixes-results.md` section 6.4.
- **Shoe 354:** identical except for 18 single pixels at the right waist and near the heel.

### 5.4 A fresh legacy R chain of this pass (at `2196d83`; all six steps; the new `wald.R` and `step5_without_car.R`)
```bash
RAC_SCRATCH=<scratch>/t1fix bash tests/legacy/run_legacy_r.sh   # -> <scratch>/t1fix/legacy_r_FTg4vJ
```
`timings.tsv` (seconds, exit status; under load, see 5.3):
```text
step	seconds	exit
step1	135.770052762	0
step2	1146.879855317	0
step3_glmm	255.959025551	0
step3_cml	193.742621720	0
step4_glmm	12.551273894	0
step4_cml	12.296780943	0
step5	24.976730865	0
step6	17.851777526	0
```
The step-5 variant was the one T1 ran (`step5_variant.log`: `removed line 20 (library(car)); replaced lines 125 to 130 by the manual Wald test`; sha256 `4b0249dc...`), and the copied `wald.R` is `cmp`-identical to the one committed in `b955103`.
```bash
RAC_REGRESS_R_RUN=<scratch>/t1fix/legacy_r_FTg4vJ Rscript tests/r/test_old_regression.R
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
Step 5 through the new `wald_all_spatial()` (from the knitted HTML):
```text
## Wald test, all 24 spatial coefficients = 0 (manual): W = 427.7804, df = 24, p = 1.45e-75
##   car::linearHypothesis: not run (car not installed)
```
Normalized PDFs (`/CreationDate` and `/ModDate` removed) against Tier B:
```bash
(cd <scratch>/t1fix/legacy_r_FTg4vJ/repo && /usr/bin/python3 -B /home/mehes/projects/rac-spatial-model/tests/lib/pdf_normalize.py model_images/*.pdf) > <scratch>/t1fix/pdf_normalized_fresh.sha256
diff <(sort tests/baseline/local/pdf_normalized.sha256) <(sort <scratch>/t1fix/pdf_normalized_fresh.sha256) && echo "8 of 8 normalized PDF hashes equal Tier B"
```
```text
8 of 8 normalized PDF hashes equal Tier B
```
**Looked at:** the fresh `NEW_X_NS_XY_SHOE.pdf` is the GLMM intensity map on the prototype, toe up. Its maxima (dark red, about 0.0018) are at the left forefoot (x 0.45, y 0.73), along the right edge of the midfoot (x 0.67, y 0.40) and at the left heel (x 0.43, y 0.28); its minima (blue, about 0.0004) are at the toe tip and the heel edge. The fresh `CI_cut_250.pdf` shows the CML (red) and Random (blue) bands overlapping almost entirely and widening to the right, up to about 0.0027, with the CML upper edge a hairline above the Random edge at the right end. Both match the T1 descriptions of the Tier B twins (T1 results 5.5).

So, at `2196d83`, a fresh WSL rerun of every OLD step reproduces Tier B exactly. The contour, the 1,556 Python intermediates, the five CSVs, both models and the 8 normalized PDFs are equal. The step-1 CSVs equal Tier A after LF -> CRLF, and the step-2 CSVs and the CML equal Tier A. The GLMM equals Tier A when it is fitted with the Windows R (section 4).

## 6. Corrections of `T1-baseline-results.md`

### 6.1 Section 3.2 relabelled
Its two WSL "live" checks (`RAC_REGRESS_PY_RUN=<scratch>/t1/legacy_py_MXmkvc`, `RAC_REGRESS_R_RUN=<scratch>/t1/legacy_r_oTZO3x`) point at the folders Tier B was written from, so they are now called consistency checks of the Tier B hash files. The independent evidence is section 5 of this document (A-066).

### 6.2 Section 4.3: image indices vs record indices
Computed from `tests/baseline/local/contour_linux_diff.csv`, not by hand:
```bash
/usr/bin/python3 - <<'EOF'
import csv
rows = list(csv.DictReader(open('tests/baseline/local/contour_linux_diff.csv')))
print('columns:', list(rows[0].keys()))
rec1 = [int(r['record']) for r in rows]
shoe = [int(r['shoe']) for r in rows]
print('n =', len(rows))
print('1-based records:      ', rec1)
print('shoe ids:             ', shoe)
print('0-based image indices (shoe - 1):', [s - 1 for s in shoe])
print('0-based record indices (record - 1):', [r - 1 for r in rec1])
assert all((s == r) if r <= 126 else (s == r + 1) for r, s in zip(rec1, shoe))
print('record/shoe mapping check (shoe = record for record <= 126, record + 1 after): OK')
EOF
```
```text
columns: ['record', 'shoe', 'differing_px', 'run_px', 'committed_px', 'mean_dist_px', 'max_dist_px']
n = 30
1-based records:       [8, 11, 21, 26, 62, 69, 80, 96, 117, 141, 151, 156, 162, 173, 175, 187, 191, 202, 206, 220, 234, 265, 285, 322, 339, 348, 353, 369, 381, 383]
shoe ids:              [8, 11, 21, 26, 62, 69, 80, 96, 117, 142, 152, 157, 163, 174, 176, 188, 192, 203, 207, 221, 235, 266, 286, 323, 340, 349, 354, 370, 382, 384]
0-based image indices (shoe - 1): [7, 10, 20, 25, 61, 68, 79, 95, 116, 141, 151, 156, 162, 173, 175, 187, 191, 202, 206, 220, 234, 265, 285, 322, 339, 348, 353, 369, 381, 383]
0-based record indices (record - 1): [7, 10, 20, 25, 61, 68, 79, 95, 116, 140, 150, 155, 161, 172, 174, 186, 190, 201, 205, 219, 233, 264, 284, 321, 338, 347, 352, 368, 380, 382]
record/shoe mapping check (shoe = record for record <= 126, record + 1 after): OK
```
The list that section 4.3 called "0-based records" is the list of 0-based image indices. Both lists are now given there, and the CSV's `record` column is labelled as 1-based.

### 6.3 Section 5.3: the full table
The pasted table had dropped the `varcorr` and `optimizer` rows without the omission marker. The full output, Tier A dump vs Tier B dump (Tier B = chain A; chain B is `identical()` to chain A in every field, so the numbers are those of the table it replaces):
```bash
Rscript tests/lib/compare_models.R tests/baseline/models_committed.rds tests/baseline/local/models_local.rds
```
```text
fixef         n=25   identical=FALSE all.equal(tol=0)=FALSE max|diff|=0.0007666   rel=0.0002971
vcov          n=625  identical=FALSE all.equal(tol=0)=FALSE max|diff|=2.121       rel=0.2479
vcov_rx       n=625  identical=FALSE all.equal(tol=0)=FALSE max|diff|=8.526e-06   rel=7.986e-07
theta         n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=8.58e-06    rel=8.758e-06
sigma2        n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=1.681e-05   rel=1.752e-05
varcorr       n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=1.681e-05   rel=1.752e-05
loglik        n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=1.153e-06   rel=4.464e-11
deviance      n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=0.001106    rel=2.205e-08
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
wald_glmm     n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=0.9129      rel=0.002129
wald_glmm_rx  n=1    identical=FALSE all.equal(tol=0)=FALSE max|diff|=0.01303     rel=3.046e-05
wald_cml      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
exit 1
```
(Exit 1 because GLMM fields differ, as recorded in T1.) `varcorr` differs exactly as `sigma2` does (the same quantity read two ways), and `optimizer` is identical. Section 5.3 of the T1 document now holds this full table.

The two diagnostic blocks of the same section had the same slip. Diagnostic 1 (WSL refit with `calc.derivs = TRUE`) showed 3 of the 22 rows. The marker of Diagnostic 2 (Windows R refit) named 6 of the 15 omitted rows. Both now have an accurate marker and the full table, regenerated from the saved dumps:
```bash
Rscript tests/lib/compare_models.R tests/baseline/local/models_local.rds <scratch>/t1/diag_glmm/dump_local_derivs_true.rds
Rscript tests/lib/compare_models.R tests/baseline/models_committed.rds <scratch>/t1/diag_glmm/dump_windows_default.rds
```
In Diagnostic 1 only `vcov` (max |diff| 5.189) and `wald_glmm` (3.409) differ; all other 20 rows are identical (exit 1). Diagnostic 2 is identical in all 22 rows (exit 0); its CML rows compare the committed CML with itself, as the dump header shows (`cml file:  saved_models/CML_MODEL.rds (sha256 17b54528...)`). The T1 text was right in both cases; only the pasted tables were incomplete.

## 7. Thesis repository traces from the T0 window (outside T1)
Read-only `stat`/`ls` of two paths (no recursive search):
```bash
T=/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint; stat -c '%y %n' "$T/.git/index" "$T/.git/HEAD"; ls -la --time-style=full-iso "$T/contour_algorithm/__pycache__/"; git -C "$T" --no-optional-locks rev-parse HEAD
```
```text
2026-11-05 18:25:57.716584400 +0200 /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/.git/index
2025-11-13 11:12:06.345790700 +0200 /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/.git/HEAD
total 44
drwxrwxrwx 1 mehes mehes  4096 2026-11-05 20:15:42.205202500 +0200 .
drwxrwxrwx 1 mehes mehes  4096 2026-01-07 17:18:23.726102400 +0200 ..
-rwxrwxrwx 1 mehes mehes 11223 2025-12-24 12:37:35.253581500 +0200 active_contour_snake.cpython-313.pyc
-rwxrwxrwx 1 mehes mehes  3222 2025-12-24 12:37:48.471737600 +0200 contour.cpython-313.pyc
-rwxrwxrwx 1 mehes mehes  5611 2025-12-24 12:37:29.146112500 +0200 create_files_shoes.cpython-313.pyc
-rwxrwxrwx 1 mehes mehes  4871 2025-12-24 12:38:05.799775400 +0200 distance_extremities.cpython-313.pyc
-rwxrwxrwx 1 mehes mehes  2130 2025-12-24 12:37:48.420807400 +0200 extreme_values_x_y.cpython-313.pyc
-rwxrwxrwx 1 mehes mehes   489 2025-12-24 12:37:48.446381600 +0200 globals.cpython-313.pyc
-rwxrwxrwx 1 mehes mehes  1694 2025-12-24 12:38:05.779399700 +0200 remove_noise.cpython-313.pyc
109f30a0217aab16e35a31aaed628a555f57031d
```
The reviewer's observation holds. `.git/index` was rewritten at 18:25 on 2026-11-05, which is what an index-refreshing git command (for example `git status` without `--no-optional-locks`) does. The `__pycache__/` folder's modification time is 20:15 that day, while every `.pyc` in it dates from 2025-12-24: a file was created and removed there (for example a bytecode write by a Python run without `-B`). Both are inside the T0 window. The thesis HEAD is still `109f30a`. Nothing in this pass touched the thesis repo except reads with `--no-optional-locks` and `-B`, and the Windows interpreters only read the repo through interop. Later tasks keep doing so (LOG entry of this pass).

## 8. The fast suite and the OLD regression at the end of this pass
```bash
bash tests/run_all.sh
```
```text
== sha256 committed_79247d8 (Tier A, 24 files)
== sha256 old_baseline (11 OLD artifacts)
== python unittest discover tests/python
[... 24 per-test "ok" lines omitted; the one skip is by design ...]
test_full_run_folder (tests.python.test_snake_old_regression.SnakeOld.test_full_run_folder) ... skipped 'set RAC_REGRESS_PY_RUN to a legacy run folder'
Ran 25 tests in 25.323s
OK (skipped=1)
[... the R test outputs omitted: they are the PASS lines of sections 2, 3.1, 3.2 and 4.1, plus test_baseline_committed (7 PASS) and test_old_regression (5 PASS, live check skipped) ...]
== flake8 (all Python except contour_algorithm/ until T2c)
flake8: 20 files (contour_algorithm/ excluded until T2c)
== shellcheck (all shell scripts)
shellcheck: 8 files
== work tree unchanged by the tests (no file created or modified)

== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS        29s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        21s  Rscript tests/r/test_compare_glmm_fits.R
PASS         1s  Rscript tests/r/test_compare_models.R
PASS         2s  Rscript tests/r/test_old_regression.R
PASS         2s  Rscript tests/r/test_step5_variant.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         0s  flake8 (all Python except contour_algorithm/ until T2c)
PASS         1s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS

real	1m5.469s
```
**OLD regression, summary.** No committed data, model or figure file changed: the 24 Tier A checksums and the 11 of `old_baseline.sha256` verify. No pipeline Rmd, `config.R` or `contour_algorithm/*.py` changed in this pass. The code that changed is the test tooling and `statistical_model/R/wald.R`, which no Rmd sources yet.

| What was re-run in this pass | Compared with | Result |
|---|---|---|
| Legacy Python, full (`legacy_py_doxevy`, WSL) | Tier B | contour sha256 equal (LF and CRLF), 386/386 records, 1,556/1,556 intermediates, no extra file |
| the same run | Tier A | 30 of 386 contour records differ (19,027 px), prototype masks pixel-identical: the platform difference of T1, unchanged (A-060) |
| Legacy R steps 1-6 (`legacy_r_FTg4vJ`, WSL) | Tier B | five CSVs byte-identical, both models `identical()`, 8/8 normalized PDFs equal, step 5 W = 427.7804 |
| the same run | Tier A | step-1 CSVs equal after LF -> CRLF, step-2 CSVs and the CML equal; the GLMM differs exactly as recorded in T1 (A-055) |
| Step 3 under the Windows R (`winr_step3_dDeVqT`) | Tier A | GLMM equal in 27/27 fields, its dump in 22/22 (W = 428.6933) |
| The reviewer's Python run and R chain | Tier B | equal (section 5.1, 5.2) |

The only Tier A artifacts that a WSL rerun does not reproduce byte for byte are the contour (exact under the Windows venv, T1), the GLMM (exact under the Windows R, section 4), and the bytes of PNG, PDF and `.rds` files whose content is equal (encoder, producer, serialized environments). Each has a proven cause.

## 9. Timings

| What | Time |
|---|---|
| `tests/python/test_scratch_lib.py` (11 tests) | 0.4 s |
| `tests/r/test_wald.R` (WSL / Windows R) | 3.7 s / 6.6 s |
| `tests/r/test_compare_glmm_fits.R` | 21-30 s |
| `tests/run_all.sh` | 47 s after the first fixes; 65.5 s at the end (unloaded); 76 s with the background jobs running |
| Legacy Python, full (WSL, venv copy) | 785 s wall under load (T1: 509 s unloaded) |
| Legacy R chain: step 1 / step 2 / GLMM / CML / step 4 (x2) / step 5 / step 6 | 135.8 / 1146.9 / 256.0 / 193.7 / 12.6 + 12.3 / 25.0 / 17.9 s |
| Windows R step 3 (`knitr::knit`) | 541.1 s (542.5 s with the runner) |
| `write_environment.sh` (both platforms) | 61 s |

## 10. Files created or changed in this pass
- Code: `tests/lib/scratch.sh` (guard), `statistical_model/R/wald.R` (dimnames, intercept by name), `tests/lib/compare_models.R` (missing fields), `tests/legacy/step5_without_car.R` (assertions), `tests/run_all.sh` (lint, `.claude`), `tests/lib/write_environment.sh` (Windows R `sessionInfo()`).
- New code: `tests/legacy/run_windows_r_step3.sh`, `tests/lib/compare_glmm_fits.R`, `tests/legacy/plot_contour_platform_diff.py`.
- Tests: `tests/python/test_scratch_lib.py` (5 new tests), `tests/r/test_wald.R` (5 new checks), new `tests/r/test_compare_models.R`, `tests/r/test_step5_variant.R`, `tests/r/test_compare_glmm_fits.R`; the headers of `tests/python/test_snake_old_regression.py` and `tests/r/test_old_regression.R` (A-066 note).
- Baseline: `tests/baseline/local/environment.txt` (regenerated, section 4.3), `tests/baseline/README.md`.
- QA: `docs/qa/T1/old/contour_platform_diff_old.png`; `docs/qa/snake-qa.md` (Platform).
- Docs: this file; `docs/tests/T1-baseline-results.md` (sections 3.2, 4.3, 5.3); `docs/tests/README.md`; `docs/README.md`; `docs/decisions.md` (A-062 to A-066; update notes on A-034, A-055, A-058, A-060); the plan (Revision 4: section 4.5, F40, T2 order, files, `test_no_hardcoding` scope, step-3 gate); `contour_algorithm/README.md`; `docs/progress/LOG.md`.

Scratch only (not in the repo): `<scratch>/t1fix/` (runs `legacy_py_doxevy`, `legacy_r_FTg4vJ`, `winr_step3_dDeVqT`; the old-library and old-`wald.R` checks; the empty name mirror `mirror_leUZA9`; `environment_new.txt`; `overlay/`). The thesis repository was only read.
