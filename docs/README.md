# Documentation index

Work on branch `feature/new-shoes-pipeline`: run the RAC pipeline on the second (631-shoe) dataset and use it for out-of-sample validation (FSI revision, due 2026-12-04).

| Document | What it is |
|---|---|
| [2026-11-05-meeting-micha-new-shoes.md](2026-11-05-meeting-micha-new-shoes.md) | Meeting notes: the R&R, Micha's two requests (Part 1: complete pipeline on the new shoes; Part 2: validation), data facts, known code issues. The source of the requirements. Read its correction box first: the "no overlap" statement is contradicted by the data (about 67 NEW shoes look like reprints of OLD shoes; decision D-012) |
| [plans/2026-11-05-new-shoes-pipeline.md](plans/2026-11-05-new-shoes-pipeline.md) | **The plan**: facts, big-picture diagram, dataset profiles, file-naming table, tasks T1-T8 with tests and regression gates, the Part 2 method, risks |
| [decisions.md](decisions.md) | Decision register: who decided what and why (`D-` people, `A-` agent calls) |
| [progress/LOG.md](progress/LOG.md) | Chronological log of every task: what was done, results, timings, blockers. Read the last entry first when resuming |
| [tests/README.md](tests/README.md) | How tests are organized, how to run them, the regression tiers, the results-document convention |
| `tests/T<n>-<task>-results.md` | Per-task results: exact commands and their real output ([T0](tests/T0-architecture-results.md), [T0 review fixes](tests/T0-review-fixes-results.md), [T0 second review fixes](tests/T0-review2-fixes-results.md), [T1 baseline](tests/T1-baseline-results.md), [T1 review fixes](tests/T1-review-fixes-results.md), [T2 profiles](tests/T2-profiles-results.md), [T2 review fixes](tests/T2-review-fixes-results.md), [T3 new data](tests/T3-new-data-results.md), [T4 snake](tests/T4-snake-results.md), [T4 review fixes](tests/T4-review-fixes-results.md), [T4 second review fixes](tests/T4-review2-fixes-results.md), [T5 new pipeline](tests/T5-new-pipeline-results.md), [T5 review fixes](tests/T5-review-fixes-results.md), [T5 second review fixes](tests/T5-review2-fixes-results.md), [T6 compare and its review fixes](tests/T6-results.md)) |
| [results/old-vs-new.md](results/old-vs-new.md) | T6: how the OLD and NEW datasets compare (data, contours, sigma^2, coefficients and equality tests, maps with level and shape separated, a model-free regional table, CI cuts, Naomi's 14 areas, Random vs CML), as corrected by the statistics review fixes (A-133 to A-138) |
| [qa/snake-qa.md](qa/snake-qa.md), `qa/sheets_old/` | The OLD snake reference (T1): contact sheets of 68 old shoes (initial ellipse, first and second snake, mask removal, final contour), what was seen on each sheet, and what a good contour looks like: the quality bar for the new shoes |
| `qa/T<n>/` | Visual QA evidence per task (`old/`, `new/`, `compare/` subfolders); each committed image is described in the task's results doc. [T0](qa/T0/README.md): probe scripts and evidence images, including the overlap screens of both review passes; the list of NEW shoes judged reprints of OLD shoes, with a note per shoe, is `qa/T0/compare/overlap_verdicts_t0_old_vs_new.csv`. [T3](qa/T3/README.md): pixel calibration tables and curves, per-shoe contact tables, the raw contact sheets of all 631 NEW shoes with RACs and what was seen on each. [T5](qa/T5/README.md): the R stamp-mask study (NEW has no police stamp, A-110), the step-1 contact surface of all 631 NEW shoes on 13 sheets, the step-2 figures OLD vs NEW, the PNG copies of the step 4-6 figures (A-111), the goodness of fit of the step-3 GLMMs and the NEW heel-front band (A-114; its cause, the y resolution of the step-3 basis, A-119; its reading, A-120) |

Dataset selection (from T2): `config/datasets.json` holds both datasets' values and paths; `RAC_DATASET=old|new` selects one for the Python step 0 (`python -m contour_algorithm.main`) and the R steps; `tools/run_pipeline.sh` runs steps for one dataset, `tests/regress_old.sh` is the OLD regression gate (a scratch copy). See the README section "Datasets".

Project-level documents (repo root): [README.md](../README.md) (pipeline overview), [PIPELINE_DETAILS.md](../PIPELINE_DETAILS.md) (technical details of the six R steps; some numbers are wrong, see known issue K6 in the plan), [CHANGELOG_feb_mar_2026.md](../CHANGELOG_feb_mar_2026.md), [data/new_shoes/README.md](../data/new_shoes/README.md) (the new dataset's files and format).

## Resuming after an interruption
1. Read the last entry of `progress/LOG.md`.
2. Find the current task in the plan (section 8) and its checkboxes.
3. Run `bash tests/run_all.sh` (from T1 on) to confirm the tree is green before changing anything.
