# Documentation index

Work on branch `feature/new-shoes-pipeline`: run the RAC pipeline on the second (631-shoe) dataset and use it for out-of-sample validation (FSI revision, due 2026-12-04).

| Document | What it is |
|---|---|
| [2026-11-05-meeting-micha-new-shoes.md](2026-11-05-meeting-micha-new-shoes.md) | Meeting notes: the R&R, Micha's two requests (Part 1: complete pipeline on the new shoes; Part 2: validation), data facts, known code issues. The source of the requirements. Read its correction box first: the "no overlap" statement is unverified (decision D-012) |
| [plans/2026-11-05-new-shoes-pipeline.md](plans/2026-11-05-new-shoes-pipeline.md) | **The plan**: facts, big-picture diagram, dataset profiles, file-naming table, tasks T1-T8 with tests and regression gates, the Part 2 method, risks |
| [decisions.md](decisions.md) | Decision register: who decided what and why (`D-` people, `A-` agent calls) |
| [progress/LOG.md](progress/LOG.md) | Chronological log of every task: what was done, results, timings, blockers. Read the last entry first when resuming |
| [tests/README.md](tests/README.md) | How tests are organized, how to run them, the regression tiers, the results-document convention |
| `tests/T<n>-<task>-results.md` | Per-task results: exact commands and their real output ([T0](tests/T0-architecture-results.md), [T0 review fixes](tests/T0-review-fixes-results.md)) |
| `qa/T<n>/` | Visual QA evidence per task (`old/`, `new/`, `compare/` subfolders); each committed image is described in the task's results doc. [T0](qa/T0/README.md): probe scripts and evidence images, including the overlap screen of the review pass |

Project-level documents (repo root): [README.md](../README.md) (pipeline overview), [PIPELINE_DETAILS.md](../PIPELINE_DETAILS.md) (technical details of the six R steps; some numbers are wrong, see known issue K6 in the plan), [CHANGELOG_feb_mar_2026.md](../CHANGELOG_feb_mar_2026.md), [data/new_shoes/README.md](../data/new_shoes/README.md) (the new dataset's files and format).

## Resuming after an interruption
1. Read the last entry of `progress/LOG.md`.
2. Find the current task in the plan (section 8) and its checkboxes.
3. Run `bash tests/run_all.sh` (from T1 on) to confirm the tree is green before changing anything.
