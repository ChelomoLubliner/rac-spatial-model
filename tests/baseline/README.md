# Old-dataset baseline (T1)

Two tiers (plan section 4.5, decision A-004). Files here are written once in T1 and never edited
afterwards, except to add a missing file (with a LOG entry).

## Tier A: the files committed at `79247d8`

| File | Content | Made by |
|---|---|---|
| `committed_79247d8.sha256` | sha256 of every file tracked at `79247d8` under `data/`, `processed_data/`, `saved_models/`, `model_images/` (24 files; `README.md` files excluded), from the git blobs | `bash tests/lib/make_tier_a.sh` |
| `old_baseline.sha256` | The 11 OLD pipeline artifacts a rerun must reproduce: `data/contour_Active_Contour.txt`, `data/freq_min_18.png`, `data/contour_prototype.png`, `data/all_cont.csv`, `processed_data/*.csv` (5), `saved_models/*.rds` (2). A subset of the line above | same |
| `committed_79247d8_eol.tsv` | path, bytes, kind, LF count, CR count, CRLF count of the same 24 files | same |
| `models_committed.rds` | `dump_models()` of `saved_models/NEW_X_NS_XY.rds` and `CML_MODEL.rds`: fixef, full vcov (default = finite-difference Hessian, and RX), theta, sigma^2, logLik, nobs, groups, convergence, CML coef/vcov/logLik, manual Wald W. For `identical()` comparisons | `Rscript tests/lib/dump_models.R saved_models/NEW_X_NS_XY.rds saved_models/CML_MODEL.rds tests/baseline/models_committed.rds tests/baseline/old_model_summary` |
| `old_model_summary.txt`, `old_model_summary.csv` | Every scalar of that dump at full precision (`sprintf("%.17g")`): GLMM fixef, vcov diagonals, theta, sigma^2, logLik; CML coef, vcov diagonal, logLik; Wald W. (The plan calls the text file `models_committed.txt`.) | same |

Checked by `tests/run_all.sh` (`sha256sum -c`), `tests/python/test_baseline_raw_data.py` and
`tests/r/test_baseline_committed.R`.

## Tier B: `local/`, the unmodified code re-run on this machine (T1)

| File | Content |
|---|---|
| `local/python_contour.sha256` | sha256 of the contour txt written by the legacy Python run (LF, as Python writes it on Linux) and of the same bytes with LF -> CRLF |
| `local/python_intermediates.sha256` | sha256 of every `.npy` and `.png` the legacy Python run wrote under `images/` (paths relative to the run folder). The plotly HTML files are not hashed (random div ids) |
| `local/r_outputs.sha256` | sha256 of the CSVs written by the legacy R run (raw, LF) |
| `local/pdf_normalized.sha256` | `tests/lib/pdf_normalize.py` hashes (dates removed) of the 8 PDFs of the legacy R run |
| `local/models_local.rds`, `local/old_model_summary_local.txt`, `.csv` | `dump_models()` of the models refitted by the legacy R run |
| `local/environment.txt` | `uname -a`, R `sessionInfo()`, `pip freeze` of the venv, git commits; the Windows interpreters used for diagnostics (venv-wind, R 4.4.3) |
| `local/contour_linux_diff.npz`, `.csv` | The 30 contour records (of 386) in which the Linux rerun differs from the committed (Windows) contour: record indices, shoe ids, the Linux records (bit-packed), the sha256 of the Linux file with CRLF; the CSV gives differing pixels and the mean/max distance to the committed contour per record (`tests/lib/contour_platform_diff.py`). Tier A with these records replaced = Tier B |
| `local/contour_windows_check.txt` | The same legacy snake under the thesis Windows venv: 0 of 386 records differ from the committed contour |

Tier B comes from these runs (2026-11-05/06, `docs/tests/T1-baseline-results.md`): Python
`<scratch>/t1/legacy_py_MXmkvc` (thesis code `109f30a`, the venv copied to the Linux filesystem,
decision A-056); R chain A `<scratch>/t1/legacy_r_oTZO3x` (all six steps of `79247d8`; step 5
without car, decision A-057). An independent R chain B (steps 3-6 from the committed CSVs) gave
`identical()` models and identical normalized PDF hashes.

How they were produced and compared: `docs/tests/T1-baseline-results.md`.
