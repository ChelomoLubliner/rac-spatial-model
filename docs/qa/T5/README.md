# T5 QA evidence: R steps 1-6 on the NEW shoes

Written by T5-newmodel (2026-11-06), extended by the T5 review fixes and the second T5 review fixes (2026-11-07). Every image below was opened and looked at; what was seen is in `docs/tests/T5-new-pipeline-results.md` (sections named per file) and, for the review-fix files, in `docs/tests/T5-review-fixes-results.md`. Decisions A-110 to A-112, A-113 to A-118 and A-119 to A-121 (`docs/decisions.md`).

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
| `heel_front_band_shoes_new.png` | *(T5 review fixes, A-114)* For each block of 49 NEW ids (13 rows), the 7 shoes with the most contact in the band y (-0.18, -0.10], cropped to rows 150-300: S white, RAC pixels green, the band between cyan lines; label: id, group (A = ids 1-343 and 442-490), contact px and RAC px in the band; `docs/tests/T5-review-fixes-results.md` section 3. *(Second T5 review fixes, A-120: the groups are a post-hoc split chosen on NEW's band data, so the figure is descriptive in the band.)* |

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
| `residual_cells_old_vs_new.csv` | *(T5 review fixes, A-114)* O/E of each step-3 GLMM (fitted with the shoes' BLUPs) on 0.04 (new_x) x 0.08 (y) cells, both datasets: rows, cases, controls, E, O/E, z; review-fixes results section 3 |
| `heel_front_band_old_vs_new.png` | *(T5 review fixes, A-114)* NEW group A, NEW group B, OLD: the share of shoes with contact per pixel, the RAC pixels per contact pixel (6 x 6 px blocks), and both along y (with the OLD prints of the 50 group-A reprints), the band y (-0.18, -0.10] marked; review-fixes results section 3. *(Second T5 review fixes: the misfit of the step-3 surface in this band is mainly its y resolution on NEW, A-119; the group panels are descriptive, the OLD reprints the confirmatory part, A-120.)* |

## `probes/`

`t5_stamp_mask.R`, `t5_stamp_figure.py`, `t5_stamp_ring.py` and `t5_t4_table_diff.py` (section 2), `t5_step1_sheets.py` and `t5_step1_zoom.py` (section 4), `t5_step2_figures.py` (section 5), `t5_model_summary.R` and `t5_side_by_side.R` (section 6), `t5_k8_edges.R` (section 7), `t5_new_rerun.sh` (section 10.4: a fresh rerun of NEW steps 1-6 compared with HEAD; since the T5 review fixes `--oldbasis` also refits and compares the two OLD-basis models and `--png` the 16 PNG twins). T5 review fixes (`docs/tests/T5-review-fixes-results.md`): `t5_gof.R` (goodness of fit, the heel-front band, A-114), `t5_band_figure.py` (its two figures), `t5_inference.R` (convergence, robust Wald, the cost of K8, the map levels; A-115, A-116), `t5_sigma2.R` (what sigma^2 measures; `--offset-refit` refits NEW with the offset, about 8-12 minutes; A-115). Second T5 review fixes (`docs/tests/T5-review2-fixes-results.md`): `t5_basis_y.R` (the step-3 basis against finer bases in sample and in 5-fold cross-validation by shoe, own-group fits; `--glmm` also refits the NEW GLMM on the finer y basis; A-119), `t5_boot.R` (shoe-bootstrap intervals for the O/E and band-density numbers of `t5_gof.R`; A-120); `t5_inference.R` section 3 now gives the direct cluster-robust Wald of the K8 cost (A-116 corrected). Each states its usage in its header and writes only to the folders named on its command line. They read committed files, with three exceptions (corrected by the T5 review fixes; checked in a fresh clone, review-fixes results section 5): `t5_step1_zoom.py` reads `s_outside_contour_new.csv` from its OUT_DIR, so run `t5_step1_sheets.py` into the same folder first (or use `docs/qa/T5/new`, which holds the committed copy); `t5_stamp_figure.py` reads the gitignored `images_new/saved/freq_min_18_new.png`, so NEW step 0 must have run in the tree (`RAC_DATASET=new python -m contour_algorithm.main --jobs 14`, which on this machine rewrites the committed contour with the same bytes; or run from the `repo/` folder of a `tests/rebuild_new.sh --keep` run), and the masks and counts that `t5_stamp_mask.R` writes, so run that first with the same NEW_DIR and SCRATCH.
