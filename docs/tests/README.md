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
| `tests/run_all.sh` [T1] | Fast suite (< 5 min): every `tests/python/test_*.py`, every `tests/r/test_*.R`, `sha256sum -c tests/baseline/committed_79247d8.sha256`. Exit 0 only if all pass |
| `tests/python/test_*.py` [T1-T4] | `python -m unittest discover -s tests/python -t .` from the repo root |
| `tests/r/test_*.R` [T1-T7] | `Rscript tests/r/test_<name>.R` from the repo root |
| `tests/baseline/` [T1] | Tier A: checksums, EOL table and model dumps of the files committed at `79247d8`. `local/` = Tier B: outputs of the unmodified code re-run on this machine. Never edited after T1, except to add a file that was missing, with a LOG entry |
| `tests/lib/` [T1-T2] | Helpers: `dump_models.R`, `compare_models.R`, `pdf_normalize.py` |
| `tests/legacy/` [T1] | Scripts that run the unmodified code in scratch copies (`run_legacy_python.sh`, `run_legacy_r.sh`) |
| `tests/regress_old.sh` [T2] | The old-regression gate: copies the working tree to the scratch dir, runs the requested steps with `RAC_DATASET=old`, compares with Tier A / Tier B, prints a summary table |
| `tests/e2e/` [T8] | `test_old_full.sh` (all old steps), `test_new_rerun.sh` (new steps re-run reproduce the committed new outputs) |

## Regression tiers
- **Tier A** (committed at `79247d8`): the contour txt and the R CSVs must match by raw sha256.
- **Tier B** (unmodified code on this machine, T1): Python intermediates (npy, png) by sha256; models by `identical()` on `fixef`, `vcov`, `VarCorr`, `theta`, `logLik` and CML `coef`/`vcov`; PDFs by sha256 after removing the `/CreationDate` and `/ModDate` values.
- Model and PDF differences between Tier A and Tier B are platform differences (committed files came from Windows R 4.4.3); T1 reports them once, with the maximum absolute differences, and they are restated in the final report.

## Running long checks
Slow gates (`tests/regress_old.sh`, `tests/e2e/*`, the legacy runs) exceed the 10-minute foreground limit: start them in the background (`run_in_background`, or `nohup ... > logs/<name>.log 2>&1 &`), poll until they exit, then paste the summary. Every script that copies or deletes needs `RAC_SCRATCH` (your own scratch directory; there is no default) and works in a fresh `mktemp -d "$RAC_SCRATCH/<name>_XXXXXX"` folder (plan section 4.5, decision A-034).

## Results documents
One file per task: `docs/tests/T<n>-<short-name>-results.md` (T0-architecture, T0-review-fixes, T1-baseline, T2-profiles, T3-new-data, T4-snake, T5-new-pipeline, T6-compare, T7-validation, T8-report). For every check: the exact command in a code block, then its **real** output (trim only with an explicit `[... N lines omitted ...]` marker), then one line of interpretation. A skipped test says why. Images are described by the agent who opened them.

## Naming
Python: `tests/python/test_<area>.py`, classes `<Thing>`, methods `test_<behaviour>`; R: `tests/r/test_<area>.R` with one `stopifnot` block per named check. The plan refers to Python tests as `module.Class.method`.
