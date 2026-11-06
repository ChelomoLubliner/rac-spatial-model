# T4 snake QA files

QA files of plan task T4 (snake adaptation and QA on the new shoes; decisions A-091 to A-098). The visual review of every image, sheet by sheet, is in [`../snake-qa.md`](../snake-qa.md) (NEW section); commands and real outputs in [`../../tests/T4-snake-results.md`](../../tests/T4-snake-results.md). Paths come from the profile's `prep` entry (`snake_qa`, `snake_qa_dir`, `sheets_dir`).

| File | Written by | Content |
|---|---|---|
| `new/snake_metrics_new.csv` (copy: `../snake_qa_new.csv`) | `qa_snake --metrics` | One row per NEW shoe: the QA metrics (`qa_snake.py` docstring), `qa_flags` (broken bands, A-093), and `resolution`, `note` of the review |
| `new/snake_review_new.csv` | the reviewer | `shoe, resolution, note` of the 12 flagged shoes (merged into the metrics table) |
| `new/sticker_erased_new.csv` | `qa_snake --metrics` | The erase list (`data/new_shoes/sticker_masks_new.csv`) with the contact pixels each rectangle erases, in all and inside the mask (A-095) |
| `new/mask_threshold_new.csv` | `qa_snake --thresholds 13,18,24,29,36` | The prototype mask per superposition threshold: size, RAC pixels inside, per-shoe kept share, pixels removed, R stamp masks outside, the artefact shoes (A-096) |
| `new/crosscheck_2023_new.csv` | `qa_snake --crosscheck` | Per shoe: the 2023 `INSIDE_SNAKE` and `DIST_SNAKE` against the new contour |
| `new/flagged/im_<i>_new.png` | `qa_snake --flagged` | Each flagged shoe at twice the size (legacy 0-based image index: `im_7_new.png` is shoe 8) |
| `new/overrides_before_after_new.png` | `probes/t4_overrides_figure.py` | Before (radius 10) and after (radius 24) of the 9 per-shoe fallbacks (A-097) |
| `old/snake_metrics.csv` | `qa_snake --metrics` with `RAC_DATASET=old` in a scratch copy | The OLD reference: the same metrics on the committed contour; the source of the OLD percentiles of the bands |
| `probes/` | | Scripts of the exploration (variant runs, BLAS threads, forked runs, record comparisons, the venv-wind build, the artefact screens, the per-RAC 2023 cross-check, the overrides figure); each says how to run it |

Contact sheets (7 x 7 shoes, 13 per kind): `../sheets_new/{prototype,ellipse_first_snake,final_snake,cleaned}/`, plus `../sheets_new/prototype/prototype_mask_new.png`.
