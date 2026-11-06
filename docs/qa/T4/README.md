# T4 snake QA files

QA files of plan task T4 (snake adaptation and QA on the new shoes; decisions A-091 to A-098, revised by the T4 review fixes, A-099 to A-106, and the second T4 review fixes, A-107 to A-109). The visual review of every image, sheet by sheet, is in [`../snake-qa.md`](../snake-qa.md) (NEW section); commands and real outputs in [`../../tests/T4-snake-results.md`](../../tests/T4-snake-results.md), [`../../tests/T4-review-fixes-results.md`](../../tests/T4-review-fixes-results.md) and [`../../tests/T4-review2-fixes-results.md`](../../tests/T4-review2-fixes-results.md). Paths come from the profile's `prep` entry (`snake_qa`, `snake_qa_dir`, `sheets_dir`).

| File | Written by | Content |
|---|---|---|
| `new/snake_metrics_new.csv` (copy under the task's name: `../sheets_new/snake_qa_new.csv`, also written by `--metrics`, A-104) | `qa_snake --metrics` | One row per NEW shoe: the QA metrics (`qa_snake.py` docstring; since the review fixes also `rac_out_max_px`, `contact_out_max_px`, A-099), `qa_flags` (broken bands, A-093, A-099), and `resolution`, `review_class`, `note` of the review |
| `new/snake_review_new.csv` | the reviewer | `shoe, resolution, review_class, note` (A-101): every flagged shoe (29) with its resolution, and the classed shoes that pass (33: `partial_print`, `spike`, `rim_cut`, `mask_cut`; second review fixes, A-107); merged into the metrics table |
| `new/sticker_erased_new.csv` | `qa_snake --metrics` | The erase list (`data/new_shoes/sticker_masks_new.csv`) with the contact pixels each rectangle erases, in all and inside the mask (A-095) |
| `new/mask_threshold_new.csv` | `qa_snake --thresholds 13,18,24,29,36` | The prototype mask per superposition threshold: size, RAC pixels inside, per-shoe kept share, pixels removed, R stamp masks outside, the artefact shoes (A-096) |
| `new/crosscheck_2023_new.csv` | `qa_snake --crosscheck` | Per shoe: the 2023 `INSIDE_SNAKE` and `DIST_SNAKE` against the new contour |
| `new/flagged/im_<i>_new.png` | `qa_snake --flagged` | Each flagged shoe (29) at twice the size (legacy 0-based image index: `im_7_new.png` is shoe 8); figures of shoes that are no longer flagged are removed |
| `new/overrides_before_after_new.png` | `probes/t4_overrides_figure.py` | Before (radius 10) and after (radius 24, or 16 for 165, or 170's own ellipse, labelled `r10 ell`) of the 24 per-shoe fallbacks (A-097, A-102, A-107) |
| `old/snake_metrics.csv` | `qa_snake --metrics` with `RAC_DATASET=old` in a scratch copy | The OLD reference: the same metrics on the committed contour; the source of the OLD percentiles of the bands |
| `probes/` | | Scripts of the exploration (variant runs, BLAS threads, forked runs, record comparisons, the venv-wind build, the artefact screens, the per-RAC 2023 cross-check, the overrides figure; `t4fix_*` the T4 review fixes, among them the writers of the erase list and the override file; `t4fix2_*` the second review fixes: where the print crosses each shoe's initial ellipse, other ellipses or radii tried and drawn, zoom panels); each says how to run it |

Contact sheets (7 x 7 shoes, 13 per kind): `../sheets_new/{prototype,ellipse_first_snake,final_snake,cleaned}/`, plus `../sheets_new/prototype/prototype_mask_new.png`.

Rebuild check: `RAC_SCRATCH=<scratch folder> bash tests/rebuild_new.sh` rebuilds the NEW contour, `new/snake_metrics_new.csv`, `new/sticker_erased_new.csv` and the task copy in a scratch copy and compares them with the files committed at HEAD; `--full` also rebuilds and compares the contact sheets, the flagged figures (the exact set), `new/crosscheck_2023_new.csv`, `new/mask_threshold_new.csv`, `prototype_mask_new.png` and `new/overrides_before_after_new.png` (A-103, A-108).
