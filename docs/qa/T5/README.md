# T5 QA evidence: R steps 1-6 on the NEW shoes

Written by T5-newmodel (2026-11-06). Every image below was opened and looked at; what was seen is in `docs/tests/T5-new-pipeline-results.md` (sections named per file). Decisions A-110 to A-112 (`docs/decisions.md`).

## `new/` (NEW only, `_new` names)

| File | Content |
|---|---|
| `stamp_mask_new.png` | The R stamp mask of step 1 (2x): NEW at threshold 13 and 8, OLD at 8 (colours of `docs/qa/T0/old_rmask_stamps.png`: white = mask, red = removed by the sweep, blue = step-0 cleaning mask beyond it, grey = contact on any shoe outside both, orange = what 13 removes beyond 8). NEW has no police stamp (no red); results section 2 |
| `stamp_worst_new.png` | The 12 NEW shoes that lose the largest share of their contact to the threshold-13 mask (kept white, removed by 13 only orange, by both red, RACs green, the mask outline blue): the orange is sole edge, the red artefact remnants and debris; section 2 |
| `stamp_shoes_new.csv` | Per NEW shoe and threshold (8, 13): contact px, px kept by the mask, kept share, RAC pixels off the mask |
| `s_sheet_01_new.png` ... `s_sheet_13_new.png` | The contact surface S of step 1 for all 631 shoes, 49 per sheet (white = S, red = removed by the R mask, magenta = erased by the erase list, blue = contour, green = RACs, yellow = the 100 controls); every sheet looked at, no sticker or artefact in any S; section 4 |
| `s_outside_contour_new.csv` | Per shoe: S px, S px outside the contour's row-span fill and the largest distance, raw contact removed by the mask inside / outside the fill, cases and controls outside the fill |
| `s_outside_zoom_new.png` | The shoes with a control outside the fill (8, 28, 148, 432, 583) and the six with the largest distance of S from it, 2x; section 4 |
| `model_summary_new.csv` | Estimates and SEs of the four NEW fits (step-3 GLMM and CML, the OLD-basis refits of A-112), term order intercept, x1:y1 ... x4:y6 |
| `<stem>_new.png` (8 files) | PNG twins of `model_images/new/<stem>_new.pdf`, drawn by `tools/figures_png.R` with the Rmds' own code (A-111); section 7 |

## `old/` (OLD reference, no suffix)

| File | Content |
|---|---|
| `<stem>.png` (8 files) | PNG twins of the committed `model_images/<stem>.pdf`, drawn from the committed OLD models (A-111) |
| `s_outside_contour.csv` | The step-1 screen of `new/s_outside_contour_new.csv` on OLD, for scale (shoe 9 carries the K1 mirror) |

## `compare/` (built from both datasets, `_old_vs_new`)

| File | Content |
|---|---|
| `stamp_threshold_old_vs_new.csv` | The stamp-mask numbers per dataset and threshold (OLD 8, NEW 8 and 13) |
| `step2_distributions_old_vs_new.png` | Densities of `new_x` and y (controls, cases), `min_dist` and `horiz_dist - min_dist` (px), OLD blue, NEW orange, knots dotted; section 5 |
| `step2_standardized_old_vs_new.png` | The controls and cases of each dataset on the standardized shoe (new_x, y) with the OLD prototype outline; section 5 |
| `k8_edges_old_vs_new.csv` | The K8 edges of both GLMMs: eta pinned to the intercept on the left and heel edges, the free edges' range, rows near the pinned edges; section 7 |

## `probes/`

`t5_stamp_mask.R`, `t5_stamp_figure.py`, `t5_stamp_ring.py` and `t5_t4_table_diff.py` (section 2), `t5_step1_sheets.py` and `t5_step1_zoom.py` (section 4), `t5_step2_figures.py` (section 5), `t5_model_summary.R` and `t5_side_by_side.R` (section 6), `t5_k8_edges.R` (section 7), `t5_new_rerun.sh` (section 10.4: a fresh rerun of NEW steps 1-6 compared with HEAD). Each states its usage in its header; they read committed files and write only to the folders named on their command line.
