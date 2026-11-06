# Tests: organization and conventions

The test code is created from T1 on; this page fixes the conventions every task follows. The plan (`docs/plans/2026-11-05-new-shoes-pipeline.md`, sections 4.5 and 8) names each test and its assertions.

## Constraints
- **No package installs** (no `pip install`, no `install.packages`, no `apt`). `pytest`, `testthat` and R `car` are not available.
- Python tests use the standard library `unittest` and run with the thesis venv interpreter: `/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python` (system `python3` lacks numpy, scikit-image, opencv). Run it with `-B` when it imports anything from the thesis repo, so no bytecode is written there.
- R tests are plain scripts run with `Rscript`; they use `stopifnot()` and print `PASS <name>` / `SKIPPED <name>: <reason>`; any error exits non-zero.
- Code files use LF; Python is flake8-clean (default settings), shell is shellcheck-clean.

## Layout (created by the tasks named in brackets)

| Path | Content |
|---|---|
| `tests/run_all.sh` [T1] | Fast suite (< 5 min): every `tests/python/test_*.py`, every `tests/r/test_*.R`, `sha256sum -c` of `tests/baseline/committed_79247d8.sha256` and `old_baseline.sha256`, flake8 on every tracked or new Python file (except the verbatim `contour_algorithm/` until T2c, A-064), shellcheck on every shell script, and a check that the tests left the work tree unchanged (`.git` and `.claude` excluded). Exit 0 only if all pass |
| `tests/python/test_*.py` [T1-T4] | `python -m unittest discover -s tests/python -t .` from the repo root |
| `tests/r/test_*.R` [T1-T7] | `Rscript tests/r/test_<name>.R` from the repo root |
| `tests/baseline/` [T1] | Tier A: checksums, EOL table and model dumps of the files committed at `79247d8`. `local/` = Tier B: outputs of the unmodified code re-run on this machine. Never edited after T1, except to add a file that was missing, with a LOG entry |
| `tests/lib/` [T1-T2] | Helpers: `scratch.sh` (RAC_SCRATCH guards, A-034, A-062 and A-068: only a marked run folder can be deleted), `run_outputs.sh` (a runner deletes the outputs of the steps it runs and lists the regenerated ones, A-067), `run_manifest.R` and `run_manifest.py` (`check_run_manifest()`: the first thing every live check calls, A-067), `make_tier_a.sh`, `dump_models.R`, `compare_models.R` (CLI exit 0 only if every field is identical, A-069), `compare_glmm_fits.R` (two GLMM fits field by field, A-065), `pdf_normalize.py`, `compare_legacy_python.py`, `contour_platform_diff.py`, `old_records.py` (the one OLD frame, record reader and shoe/record mapping of the Python helpers, A-072), `write_environment.sh` |
| `tests/legacy/` [T1] | Scripts that run the unmodified code in scratch copies (`run_legacy_python.sh`, `run_legacy_r.sh`, `step5_without_car.R`, and `run_windows_r_step3.sh`: step 3 under the Windows R that wrote the committed GLMM, the Tier A gate for step 3, A-065), T1 diagnostics (`diag_glmm_refit.R`, `diag_wald_car.R`, `diag_snake_platform.py`, `compare_figure_matrices.R`) and the OLD gallery (`old_snake_gallery.py`, `old_snake_metrics.py`) |
| `tests/regress_old.sh` [T2] | The old-regression gate: copies the working tree to the scratch dir, deletes from the copy the outputs of the requested steps (A-067), runs them with `RAC_DATASET=old`, compares only regenerated outputs with Tier A / Tier B, prints a summary table |
| `tests/e2e/` [T8] | `test_old_full.sh` (all old steps), `test_new_rerun.sh` (new steps re-run reproduce the committed new outputs) |

## Platforms (T1)
The committed OLD contour was computed with the thesis Windows venv and the committed GLMM with the Windows R 4.4.3 (lme4 1.1-37); both are reproduced bit for bit there, while WSL differs in 30 of 386 contour records (about 1 px) and in the GLMM (fixef within 7.7e-4, no stored Hessian). Tests that re-run the snake are platform-aware (`test_snake_old_regression.py`), and Tier B is the WSL result (decisions A-055, A-060). Tier A for step 3 is checked under the Windows R with `tests/legacy/run_windows_r_step3.sh` (A-065). Evidence that a WSL rerun reproduces Tier B must come from a run that Tier B was **not** written from (A-066): Tier B was written from `<scratch>/t1/legacy_py_MXmkvc` and `legacy_r_oTZO3x`. A live check (`RAC_REGRESS_R_RUN`, `RAC_REGRESS_PY_RUN`) accepts only a run folder that proves it regenerated what is compared (A-067): `exit_status` 0, exit 0 for every step of `timings.tsv`, and the compared files on its `outputs_regenerated.sha256` list. venv-wind's base is the self-updating Microsoft Store Python, so a venv-wind check logs `sys.version` and `sys.base_prefix` (A-071).

## Regression tiers
- **Tier A** (committed at `79247d8`): the contour txt and the R CSVs must match by raw sha256.
- **Tier B** (unmodified code on this machine, T1): Python intermediates (npy, png) by sha256; models by `identical()` on `fixef`, `vcov`, `VarCorr`, `theta`, `logLik` and CML `coef`/`vcov`; PDFs by sha256 after removing the `/CreationDate` and `/ModDate` values.
- Model and PDF differences between Tier A and Tier B are platform differences (committed files came from Windows R 4.4.3); T1 reports them once, with the maximum absolute differences, and they are restated in the final report.

## Running long checks
Slow gates (`tests/regress_old.sh`, `tests/e2e/*`, the legacy runs) exceed the 10-minute foreground limit: start them in the background (`run_in_background`, or `nohup ... > logs/<name>.log 2>&1 &`), poll until they exit, then paste the summary. Every script that copies or deletes needs `RAC_SCRATCH` (your own scratch directory; there is no default) and works in a fresh `mktemp -d "$RAC_SCRATCH/<name>_XXXXXX"` folder made by `rac_scratch_new`; `rac_scratch_remove` deletes only such a folder (plan section 4.5, decisions A-034 and A-062). Only unit tests may set `RAC_PROFILE_FILE`; the pipeline runners and the regression and e2e scripts refuse to run when it is set (A-049).

## Statistical tests of tests
Tests of a statistical procedure check its rejection rate under a null with binomial bounds (A-030), and whenever a procedure uses an estimated quantity (OLD-fitted expectations, a bootstrap covariance), the null simulation re-estimates that quantity in every replicate instead of plugging in the truth (A-043, A-045). Note for agents: in the Claude Code tool shell `grep` is a ugrep wrapper (a leading `$` is an anchor there); scripts and documented commands that must reproduce elsewhere use `grep -F` or `/usr/bin/grep`.

## Results documents
One file per task: `docs/tests/T<n>-<short-name>-results.md` (T0-architecture, T0-review-fixes, T0-review2-fixes, T1-baseline, T2-profiles, T3-new-data, T4-snake, T5-new-pipeline, T6-compare, T7-validation, T8-report). For every check: the exact command in a code block, then its **real** output (trim only with an explicit `[... N lines omitted ...]` marker), then one line of interpretation. A skipped test says why. Images are described by the agent who opened them.

## Naming
Python: `tests/python/test_<area>.py`, classes `<Thing>`, methods `test_<behaviour>`; R: `tests/r/test_<area>.R` with one `stopifnot` block per named check. The plan refers to Python tests as `module.Class.method`.
