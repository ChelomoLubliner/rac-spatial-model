# T5 results: R steps 1-6 on the 631 NEW shoes

**Date:** 2026-11-06. **Task:** T5-newmodel (plan task T5, steps 1, 3, 4, 5 and 6; the robust variances of step 3b are a later task). **Branch:** `feature/new-shoes-pipeline`. **Commits:** `cb7340f` (the NEW R stamp threshold, A-110, with the recomputed T4 QA tables), `4c767bf` (NEW steps 1-2 and their QA), `9f279b5` (NEW steps 3-6, the OLD-basis refits, the PNG twins), `c3a057b` (tests), then the docs commit. Decisions A-110 to A-112 (`docs/decisions.md`). Every number below is real output of the command above it; `<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`. The NEW contour used throughout is the committed `data/new_shoes/contour_Active_Contour_new.txt`, sha256 `f7703bcd...` (T4 second review fixes); if T4 changes it again, steps 2-6 must be rerun (`RAC_DATASET=new tools/run_pipeline.sh --steps 2-6`) and `tests/r/test_new_outputs.R` fails until they are (section 8.1).

## 1. Summary

| Item | Result |
|---|---|
| Police stamps on NEW | **none**: the step-1 stamp sweep removes 0 px at threshold 8 (OLD: 1,110 px, the two stamp blobs beside the toe); the frame-artefact remnants lie outside the R mask at threshold 8 and 13, and so does the margin debris except a few isolated specks next to the sole, inside the mask region at both thresholds (section 4) |
| R stamp threshold (A-110) | **8** (the OLD value), not the provisional proportional 13: 13 would remove 5,661 more contact px on 99 more shoes, 99.4% of them inside the shoe's own contour (real sole edge) |
| Step 1 | 83,090 rows = 19,990 cases + 631 x 100 controls; S per shoe 1,345-18,504 px (median 8,925); `MEAN_OFFSET` **-4.465503119** (OLD -4.614310784); all 63,100 controls on S; 309 s |
| Step-1 QA | the contact surface S of all 631 shoes on 13 sheets, **every sheet looked at**: no sticker, label or frame artefact in any S (all are erased by the erase list or removed by the R mask); S reaches outside the contour fill on 72 shoes (490 px; OLD 91 shoes, 4,585 px) and 7 controls (0.011%) landed there (OLD 63) |
| Step 2 | `new_x` in [-0.185, 0.2317] (OLD [-0.1917, 0.2417]), quantiles within 0.003 of OLD's; no NA or Inf; `horiz_dist >= min_dist`; no point outside the prototype outline; 36 rows (0.043%, 11 cases) beyond the OLD boundary knots, all in y; legacy loops = vectorized on 2,000 random NEW rows; 36 s |
| Step 3 GLMM | converged (code 0, no lme4 message), 25 fixed effects, 631 groups, **sigma^2 0.7556134** (OLD 0.9597791; both without the per-shoe offset, plan K2), RX vcov (lme4 1.1-38 stores no Hessian above 10,000 rows), 595 s |
| Step 3 CML | exact, 4 iterations, 24 coefficients, 19,990 events, 290 s |
| Step 5 Wald (manual, all 24 spatial = 0) | GLMM **W = 585.89, df 24, p = 2.1e-108** (RX vcov; OLD 428.69 with the committed Hessian vcov, 427.77 with RX); CML 576.03 (OLD 420.67) |
| OLD basis (A-112) | NEW refitted on the OLD knots: GLMM sigma^2 0.7553, W 623.12; CML W 612.50 (622 s and 405 s) |
| Steps 4-6 | 8 NEW PDFs in `model_images/new/`, all looked at; PNG twins in `docs/qa/T5/new/` (A-111) |
| Tests | `tests/r/test_new_outputs.R` (6 checks, 3 mutants caught), `tests/r/test_figures_png.R`, the NEW part of `tests/r/test_distances_vectorized.R`; `bash tests/run_all.sh` **ALL PASS** (184 Python tests, 3 skipped live checks; 17 R scripts; flake8; shellcheck; work tree unchanged) |
| OLD regression | **identical**: `tests/regress_old.sh --steps 1-6` ALL PASS (five CSVs = Tier A byte for byte, `shoe_codes.csv` = `old_added_t2`, both models `identical()` to Tier B, 8 normalized PDFs = Tier B, Wald W 427.7804472165 = Tier B) and `--steps 0` ALL PASS (contour = Tier B, 1,556 intermediates = Tier B); the T4 QA tables recomputed, `tests/rebuild_new.sh` ALL PASS against `cb7340f` |
| NEW determinism | a fresh rerun of NEW steps 1-6 reproduces every committed NEW output exactly (7 CSVs byte for byte, both models `identical()`, 8 PDFs after removing their dates; section 10.4) |

## 2. Step 1: does NEW need the police-stamp cleaning? (A-110)

The legacy step 1 keeps the contact pixels that are in contact on at least t shoes and then sweeps the top half row by row to clear the columns outside that mask, which removed the police stamps beside the OLD toes. The probe evaluates the chunks `3_contacts_data` and `4.contacts` of `statistical_model/dataCC_1.Rmd` themselves, with `P$r$stamp_threshold` set in turn:

```bash
Rscript docs/qa/T5/probes/t5_stamp_mask.R docs/qa/T5/new docs/qa/T5/compare <scratch>/t5/stamp
```
```
old : records read in 9.050531 secs 
old t=8: >=t 29719 px, mask 28609 px, swept 1110 px in 13 comps; kept share p5 0.9427 median 0.9987 min 0.8894
old t=8: equal to the committed data/all_cont.csv
new : records read in 11.49185 secs 
new t=8: >=t 29503 px, mask 29503 px, swept 0 px in 0 comps; kept share p5 0.9901 median 1.0000 min 0.9294
new t=13: >=t 28930 px, mask 28929 px, swept 1 px in 1 comps; kept share p5 0.9870 median 0.9996 min 0.9294
written: docs/qa/T5/compare/stamp_threshold_old_vs_new.csv 

real	0m40.651s
user	0m29.320s
sys	0m11.320s
```
The OLD mask the probe computes equals the committed `data/all_cont.csv`, so the probe runs the real code. The table `docs/qa/T5/compare/stamp_threshold_old_vs_new.csv` (one row per dataset and threshold):

| | OLD t = 8 | NEW t = 8 | NEW t = 13 |
|---|---|---|---|
| px in contact on >= t shoes | 29,719 | 29,503 | 28,930 |
| removed by the sweep | 1,110 px in 13 pieces (908 px r43-95 c205-233, 182 px r45-70 c94-111, ...) | 0 | 1 (row 182, col 91) |
| R mask | 28,609 | 29,503 | 28,929 |
| contact removed from the shoes | 38,434 of 4,117,127 | 11,829 of 5,804,872 | 17,490 |
| shoes losing any pixel | 282 | 300 | 399 |
| kept share p1 / p5 / median / min | 0.924 / 0.943 / 0.9987 / 0.889 | 0.973 / 0.990 / 1.000 / 0.929 | 0.965 / 0.987 / 0.9996 / 0.929 |
| shoes below 0.99 / 0.95 | 91 / 27 | 32 / 1 | 48 / 2 |
| RAC pixels off the mask (step 1 adds them back to S) | 16 of 13,249 | 11 of 19,990 | 27 |

```bash
PYTHONPATH=. python -B docs/qa/T5/probes/t5_stamp_figure.py docs/qa/T5/new <scratch>/t5/stamp
```
```
docs/qa/T5/new/stamp_mask_new.png (395, 833, 3) x2
t8: 29503 px, 3 components (4-connectivity: 3); components other than the main one (size, first 1-based row/col): [(1, [26, 122]), (1, [335, 162])]
t13: 28929 px, 2 components (4-connectivity: 2); components other than the main one (size, first 1-based row/col): [(1, [28, 118])]
old t8: 28609 px, 2 components (4-connectivity: 2); components other than the main one (size, first 1-based row/col): [(1, [53, 126])]
ring t8 minus t13: 574 px, rows 26-336; inside the step-0 mask: 574 px
docs/qa/T5/new/stamp_worst_new.png shoes [580, 506, 104, 36, 35, 132, 14, 582, 152, 229, 186, 586]
[... 25 lines omitted: the kept shares of these 12 shoes (580 0.929 to 586 0.980) and of the 8 lowest OLD ones (150 0.889 to 233 0.925) ...]
```
Whether the extra pixels that 13 removes are sole (with the committed NEW contour; first run as a scratch script, the same code committed as the probe):
```bash
PYTHONPATH=. python -B docs/qa/T5/probes/t5_stamp_ring.py <scratch>/t5/stamp
```
```
contact in the ring (t8 mask minus t13 mask): 5661 px; inside the shoe's own contour fill 5628, outside 33 on 11 shoes [(294, 11), (148, 5), (142, 3), (432, 3), (585, 3), (35, 2), (185, 2), (8, 1), (329, 1), (551, 1)]
contact removed by the t8 mask itself: inside the contour fill 7613, outside 4216
```

**Looked at:**
- `docs/qa/T5/new/stamp_mask_new.png` (three panels, 2x; colours of `docs/qa/T0/old_rmask_stamps.png`): NEW t = 13 (left) and t = 8 (middle), OLD t = 8 (right). White = the R mask, red = in contact on >= t shoes but removed by the sweep, blue = the step-0 cleaning mask outside the R mask, grey = contact on any shoe outside both, orange (left panel only) = the ring that 13 removes beyond 8. NEW has no red in either panel; the orange ring is a thin line along the whole outline; the grey outside the masks is scattered margin debris and 580's heel wedge, all outside the mask. OLD has the two red stamp blobs beside the toe and grey label rectangles beside the forefoot and below the heel. Both NEW masks lie inside the step-0 mask (a blue ring all round).
- `docs/qa/T5/new/stamp_worst_new.png` (the 12 shoes that lose the largest share to the t = 13 mask; kept white, removed by 13 only orange, removed by both red, RACs green, the t = 13 outline blue): 580's frame wedge right of the heel (red: removed by both), 582's top line and the strip left of its heel (red), 186's line remnants at the top right (red), 586's band remnants (red), margin debris on 36, 104, 35 (red). The orange pieces are sole edges: 506's right side, 132's right forefoot edge, 229's right edge, 14's left forefoot edge, 152's left edge. 14's and 104's toe tips are cut by both thresholds (red), as T4 found for the step-0 mask (`mask_cut` class).

**Decision (A-110):** threshold 8 for NEW. Against the plan's criteria (T3 step 4: "no sole pixel lost on the overlay, sticker components removed"), 8 loses less sole and removes the same artefacts; it is also the OLD value, as A-096 kept the OLD 18 for the step-0 mask. The sweep bound stays 255 (`col_shoe`).

**Consequence for T4's tables:** the step-0 QA reports `coverage_r` (coverage of R's contact surface) with the profile's R mask, and its threshold study draws the R masks of the OLD and the profile's threshold. Rebuilt in a scratch copy with the new profile:

```bash
RAC_SCRATCH=<scratch>/t5/gates bash tests/rebuild_new.sh --full --keep
```
```
== rebuild_new.sh: <scratch>/t5/gates/rebuild_new_G3HyxR
result  check                                                detail
PASS    pipeline run                                         every step exit 0
PASS    OpenBLAS threads and kernel = NEW profile            1 threads, kernel Haswell
PASS    data/new_shoes/contour_Active_Contour_new.txt        = HEAD, sha256 f7703bcdbdb0...
FAIL    docs/qa/T4/new/snake_metrics_new.csv                 differs from HEAD; see <scratch>/t5/gates/rebuild_new_G3HyxR/repo/docs/qa/T4/new/snake_metrics_new.csv
PASS    docs/qa/T4/new/sticker_erased_new.csv                = HEAD, sha256 7a3517ce6811...
FAIL    docs/qa/sheets_new/snake_qa_new.csv                  differs from HEAD; see <scratch>/t5/gates/rebuild_new_G3HyxR/repo/docs/qa/sheets_new/snake_qa_new.csv
PASS    docs/qa/T4/new/crosscheck_2023_new.csv               = HEAD, sha256 b942de44faa6...
FAIL    docs/qa/T4/new/mask_threshold_new.csv                differs from HEAD; see <scratch>/t5/gates/rebuild_new_G3HyxR/repo/docs/qa/T4/new/mask_threshold_new.csv
PASS    docs/qa/T4/new/overrides_before_after_new.png        = HEAD, sha256 bc39544b34d5...
PASS    docs/qa/sheets_new/prototype/prototype_mask_new.png  = HEAD, sha256 31983d4e0eea...
PASS    contact sheets (docs/qa/sheets_new)                  52 files = HEAD
PASS    flagged figures (docs/qa/T4/new/flagged)             29 files = HEAD
timings (s):
step              seconds        exit
step0             148.646646792  0
qa_metrics        40.701948204   0
qa_figures        149.570927098  0
qa_thresholds     48.092775182   0
overrides_figure  51.316419196   0
SOME CHECKS FAILED (run folder kept)
```
The three expected differences, column by column against HEAD, which was then `f3b5d6e` (run inline before `cb7340f`; the same code is `docs/qa/T5/probes/t5_t4_table_diff.py`):
```bash
python3 docs/qa/T5/probes/t5_t4_table_diff.py <scratch>/t5/gates/rebuild_new_G3HyxR/repo
```
```
docs/qa/T4/new/snake_metrics_new.csv rows 631 631 | columns only in HEAD: [] | only in new: []
   changed column coverage_r in 10 rows; e.g. [('8', '0.984', '0.9836'), ('35', '0.9999', '0.9998'), ('142', '0.9998', '0.9995'), ('148', '0.9991', '0.9986')]
   coverage_r change: min -0.0012999999999999678 max -9.999999999998899e-05
docs/qa/sheets_new/snake_qa_new.csv rows 631 631 | columns only in HEAD: [] | only in new: []
   changed column coverage_r in 10 rows; e.g. [('8', '0.984', '0.9836'), ('35', '0.9999', '0.9998'), ('142', '0.9998', '0.9995'), ('148', '0.9991', '0.9986')]
   coverage_r change: min -0.0012999999999999678 max -9.999999999998899e-05
docs/qa/T4/new/mask_threshold_new.csv rows 5 5 | columns only in HEAD: ['r13_outside_px', 'r13_contact_outside_px'] | only in new: []
```
The three regenerated files were committed with the profile (`cb7340f`); the same probe at `c3a057b` reports no difference left:
```
docs/qa/T4/new/snake_metrics_new.csv rows 631 631 | columns only in HEAD: [] | only in new: []
docs/qa/sheets_new/snake_qa_new.csv rows 631 631 | columns only in HEAD: [] | only in new: []
docs/qa/T4/new/mask_threshold_new.csv rows 5 5 | columns only in HEAD: [] | only in new: []
```
and the fast gate passes against `cb7340f`:
```bash
RAC_SCRATCH=<scratch>/t5/gates bash tests/rebuild_new.sh
```
```
== rebuild_new.sh: <scratch>/t5/gates/rebuild_new_T4rUCz
result  check                                          detail
PASS    pipeline run                                   every step exit 0
PASS    OpenBLAS threads and kernel = NEW profile      1 threads, kernel Haswell
PASS    data/new_shoes/contour_Active_Contour_new.txt  = HEAD, sha256 f7703bcdbdb0...
PASS    docs/qa/T4/new/snake_metrics_new.csv           = HEAD, sha256 15f5f261cc75...
PASS    docs/qa/T4/new/sticker_erased_new.csv          = HEAD, sha256 7a3517ce6811...
PASS    docs/qa/sheets_new/snake_qa_new.csv            = HEAD, sha256 15f5f261cc75...
timings (s):
step        seconds        exit
step0       176.166544006  0
qa_metrics  42.371293797   0
ALL PASS
```
`python -m unittest tests.python.test_qa_snake tests.python.test_profiles tests.python.test_contour_new` on the changed profile: `Ran 62 tests in 41.121s OK`.

## 3. Step 1 run and outputs

```bash
RAC_DATASET=new bash tools/run_pipeline.sh --steps 1 --timings <scratch>/t5/runs/timings_new.tsv
```
```
run_pipeline.sh: dataset new, steps 1, logs logs/new
step1: exit 0, 309.058659066 s
run_pipeline.sh: done (new, steps 1)
```
```bash
Rscript -e '
d <- read.csv("processed_data/new/dataCC_new.csv")
cat("rows", nrow(d), "cols", paste(names(d), collapse=","), "\n")
cat("shoes", length(unique(d$shoe)), "range", range(d$shoe), "\n")
cat("cases", sum(d$n_Acc), "controls", sum(d$n_Acc==0), "\n")
tb <- table(d$shoe[d$n_Acc==0]); cat("controls per shoe all 100:", all(tb==100), length(tb), "\n")
pc <- read.csv("processed_data/new/shoe_pixel_counts_new.csv")
cat("pixel counts rows", nrow(pc), "range", range(pc$pixel_count), "median", median(pc$pixel_count), "\n")
cat("MEAN_OFFSET new (mean of logs):", sprintf("%.9f", mean(log(100/pc$pixel_count))), " log of mean:", sprintf("%.9f", log(100/mean(pc$pixel_count))), "\n")
po <- read.csv("processed_data/shoe_pixel_counts.csv")
cat("MEAN_OFFSET old:", sprintf("%.9f", mean(log(100/po$pixel_count))), "\n")
sc <- read.csv("processed_data/new/shoe_codes_new.csv"); cat("codes", nrow(sc), identical(sc$code, sc$shoe), "\n")
ac <- read.csv("processed_data/new/all_cont_new.csv"); cat("all_cont", dim(ac), sum(ac), "\n")
\'
```
```
rows 83090 cols n_Acc,x,y,shoe 
shoes 631 range 1 631 
cases 19990 controls 63100 
controls per shoe all 100: TRUE 631 
pixel counts rows 631 range 1345 18504 median 8925 
MEAN_OFFSET new (mean of logs): -4.465503119  log of mean: -4.520356249 
MEAN_OFFSET old: -4.614310784 
codes 631 TRUE 
all_cont 367 255 29503 
```
Outputs (LF line endings, no CR in any NEW CSV): `processed_data/new/dataCC_new.csv`, `shoe_pixel_counts_new.csv`, `all_cont_new.csv` (367 x 255, 29,503 px: the t = 8 mask of section 2), `shoe_codes_new.csv` (code k = shoe k). `MEAN_OFFSET` is the legacy mean of logs (plan K4); NEW shoes have fewer contact pixels than OLD (median 8,925 vs 10,266, plan F24), so NEW's offset is higher by 0.149 (a factor 1.16 in the map level).

## 4. Step-1 QA: the contact surface of every NEW shoe

```bash
RAC_DATASET=new PYTHONPATH=. python -B docs/qa/T5/probes/t5_step1_sheets.py docs/qa/T5/new
```
```
[... 14 lines omitted: the paths of s_outside_contour_new.csv and the 13 sheets ...]
controls on S: 63100 of 63100
cases that are RAC pixels: 19990 of 19990
S px outside the contour fill: total 490 on 72 shoes; largest distance 28.284
controls outside the fill: 7 on 5 shoes; cases outside: 15
raw contact removed by the mask: inside the fill 7613 outside 4216
 shoe  s_px  s_out_fill_px  s_out_fill_max_px  removed_px  removed_in_fill_px  removed_out_fill_px  erased_px  n_cases  n_controls  cases_out_fill  controls_out_fill  controls_on_s  cases_are_rac
    8  2013             33             28.284           4                   4                    0          0        3         100               1                  1            100              3
  328  5069             18             20.125           5                   5                    0          0       11         100               0                  0            100             11
  107  3258              9             16.401           3                   3                    0          0       22         100               2                  0            100             22
   18 10929              8             15.297           5                   5                    0          0       38         100               1                  0            100             38
  120  5526              7             13.038           0                   0                    0          0       49         100               0                  0            100             49
  585  4884             20             12.042          40                   0                   40         66       18         100               0                  0            100             18
[... 9 lines omitted: 302, 583, 432, 11, 121, 375, 28, 165, 48 ...]
```
The same screen on OLD for scale (sheets to scratch, the table kept as `docs/qa/T5/old/s_outside_contour.csv`):
```bash
RAC_DATASET=old PYTHONPATH=. python -B docs/qa/T5/probes/t5_step1_sheets.py <scratch>/t5/old_sheets
```
```
[... 9 lines omitted: the paths of the table and of the 8 OLD sheets ...]
controls on S: 38600 of 38600
cases that are RAC pixels: 13249 of 13249
S px outside the contour fill: total 4585 on 91 shoes; largest distance 31.048
controls outside the fill: 63 on 20 shoes; cases outside: 6
raw contact removed by the mask: inside the fill 10344 outside 28090
[... 16 lines omitted: the header and the 15 shoes with the largest distance of S from the fill, led by 9 (3,159 px outside, 31.0 px, 35 controls), 187, 153, 119 ...]
```
(3,159 of OLD's 4,585 px and 35 of its 63 controls belong to shoe 9, whose contact step 1 mirrors while its contour is not mirrored, plan K1.)

**Looked at: all 13 sheets `docs/qa/T5/new/s_sheet_<kk>_new.png`** (49 shoes per sheet, 1 px = 1 px; white = S, red = raw contact removed by the R mask, magenta = erased by the erase list, blue = the snake contour, green = RAC pixels, yellow = the 100 sampled controls; label: shoe, S px, removed px, RAC px, controls outside the fill):
- 01 (1-49, the round-lug runner with two or four heel pads): S inside every contour; red only at sole edges and margin debris: 14 and 15 (toe tips cut, 14 also its left forefoot edge), 22 (specks top right), 35 (debris top left and the left forefoot edge), 36 (scan debris around the toe), 37 (right edge); 8 is the faint partial print (2,013 px, one control outside its fill).
- 02 (50-98): the round-lug family with four heel pads; red at 85's right forefoot edge, 78, 88, specks on 55 and 92, and 93's thin vertical line beside the heel (removed).
- 03 (99-147): 114's handwritten mark at the top left is red (removed: not in S); 105's debris blob magenta (erased); 104's toe edge and debris, 125's toe tip (a T4 `mask_cut`), 132's right edge trimmed; 112 is the partial print with the unprinted heel.
- 04 (148-196): the frame lines of 148, 149 and 186 magenta (erased), 186's remnants red; 170's lower-left heel rim and 156's toe trimmed; 163 faint; 185 smeared with debris removed; 189-196 the block-grid design. 148 has two controls outside its fill (see the zoom).
- 05 (197-245): block grids and boots; red at sole edges (221, 228, 229) and specks outside (216, and 231's ambiguous mark at the top right, removed).
- 06 (246-294): the military boot family; only specks outside are red (254, 260, 264, 281, 285); 286 is the very faint print.
- 07 (295-343): boots and the moulded-name sneakers; red at 312's heel rim and specks (314, 325, 329, 330, 337).
- 08 (344-392): herringbone court soles (the moulded heel band of 344 and 345 is sole and stays in S), block grids; red at 361's forefoot edge, 368's heel edge and 379's heel bottom (a T4 `mask_cut`), a speck on 372.
- 09 (393-441): POLO soles, spirals, lattices; red at sole edges (397, 398, 411, 414) and at the heel bottoms of 422 and 423 (T4 `mask_cut`); 428 the faintest print; 432 has two controls outside its fill.
- 10 (442-490): lattices, waffles, U-heel sneakers; red at specks outside (455, 462) and sole edges (480, 486's toe); 481's dash erased.
- 11 (491-539): runners with moulded text; red along 506's right edge (sole), 520, 535; specks (493, 524).
- 12 (540-588): 580's band and wedge bars magenta, its heel wedge red; 582's tilted line magenta and the strip left of its heel red; 585's line under the heel and 586's band magenta; 581's handwritten mark red; 557's patch at the left midfoot red; 583 has one control outside its fill.
- 13 (589-631): 589's wedge tip red, 601's right forefoot edge trimmed, specks (610, 611); 598-599 the different image type; 628-631 flat lattice soles.

**No sticker, label, stamp or frame artefact survives into the contact surface S of any NEW shoe**: every one is magenta (erased by the erase list before step 1) or red (outside the R mask). The controls lie on white everywhere.

**Zoom** (`docs/qa/T5/probes/t5_step1_zoom.py` -> `docs/qa/T5/new/s_outside_zoom_new.png`; the shoes with a control outside the fill and the six with the largest distance of S from it; S outside the fill orange, controls outside red squares): 28 and 148 (two controls) are rim cuts of real sole, both in T4's `rim_cut` class; 8's specks are faint print beyond its partial-print contour (one control); 432 (two controls), 583 (one control), 328, 107, 18, 120, 585 and 302 are isolated debris specks inside the R-mask region. 7 of 63,100 controls (0.011%) lie outside their contour fill, against 63 of 38,600 on OLD.

## 5. Step 2: distances and `new_x`

```bash
RAC_DATASET=new bash tools/run_pipeline.sh --steps 2 --timings <scratch>/t5/runs/timings_new.tsv
```
```
run_pipeline.sh: dataset new, steps 2, logs logs/new
step2: exit 0, 35.958533077 s
run_pipeline.sh: done (new, steps 2)
```
```bash
Rscript -e '
d <- read.csv("processed_data/new/dataCC_distance_new.csv")
o <- read.csv("processed_data/dataCC_distance.csv")
cat("NEW rows", nrow(d), " cols:", paste(names(d), collapse=","), "\n")
for (v in c("min_dist","horiz_dist","distance_shape","new_x")) cat(sprintf("%-15s NA %d Inf %d  NEW [%.6f, %.6f]  OLD [%.6f, %.6f]\n", v, sum(is.na(d[[v]])), sum(is.infinite(d[[v]])), min(d[[v]]), max(d[[v]]), min(o[[v]]), max(o[[v]])))
cat("horiz_dist >= min_dist:", all(d$horiz_dist >= d$min_dist), " equal:", sum(d$horiz_dist == d$min_dist), "\n")
cat("x NEW range", range(d$x), " OLD", range(o$x), "\n")
cat("y NEW range", range(d$y), " OLD", range(o$y), "\n")
q <- function(v) sprintf("%.4f", quantile(v, c(.01,.05,.25,.5,.75,.95,.99)))
cat("new_x quantiles 1,5,25,50,75,95,99%: NEW", q(d$new_x), "\n                                    OLD", q(o$new_x), "\n")
cat("knots new_x NEW", sprintf("%.7f", quantile(d$new_x, 1:3/4)), " OLD", sprintf("%.7f", quantile(o$new_x, 1:3/4)), "\n")
cat("knots y     NEW", sprintf("%.7f", quantile(d$y, 1:5/6)), " OLD", sprintf("%.7f", quantile(o$y, 1:5/6)), "\n")
bx <- range(o$new_x); by <- range(o$y)
out_x <- d$new_x < bx[1] | d$new_x > bx[2]; out_y <- d$y < by[1] | d$y > by[2]
cat(sprintf("NEW rows beyond OLD boundary knots: new_x %d, y %d (%.3f%%), cases among them %d\n", sum(out_x), sum(out_y), 100*mean(out_x|out_y), sum(d$n_Acc[out_x|out_y])))
cat("|new_x| > distance_shape:", sum(abs(d$new_x) > d$distance_shape), "\n")
s <- function(v) paste(sprintf("%.3f", quantile(v, 1:5/6)), collapse=" ")
cat("y sextiles, controls: NEW", s(d$y[d$n_Acc==0]), " OLD", s(o$y[o$n_Acc==0]), "\n")
cat("y sextiles, cases:    NEW", s(d$y[d$n_Acc==1]), " OLD", s(o$y[o$n_Acc==1]), "\n")
\'
```
```
NEW rows 83090  cols: n_Acc,x,y,shoe,row_number,min_dist,horiz_dist,distance_shape,new_x 
min_dist        NA 0 Inf 0  NEW [0.000000, 0.217153]  OLD [0.000000, 0.206774]
horiz_dist      NA 0 Inf 0  NEW [0.000000, 0.226691]  OLD [0.000000, 0.213333]
distance_shape  NA 0 Inf 0  NEW [0.055000, 0.241667]  OLD [0.071667, 0.241667]
new_x           NA 0 Inf 0  NEW [-0.185000, 0.231667]  OLD [-0.191667, 0.241667]
horiz_dist >= min_dist: TRUE  equal: 26618 
x NEW range -0.1783333 0.2383333  OLD -0.1716667 0.2316667 
y NEW range -0.515 0.525  OLD -0.5016667 0.5116667 
new_x quantiles 1,5,25,50,75,95,99%: NEW -0.1537 -0.1335 -0.0689 0.0247 0.1061 0.1796 0.2100 
                                    OLD -0.1544 -0.1322 -0.0664 0.0220 0.1048 0.1789 0.2091 
knots new_x NEW -0.0688500 0.0246575 0.1060954  OLD -0.0663992 0.0219597 0.1047822 
knots y     NEW -0.3483333 -0.2183333 0.0783333 0.2016667 0.3150000  OLD -0.3250000 -0.1783333 0.0950000 0.2083333 0.3216667 
NEW rows beyond OLD boundary knots: new_x 0, y 36 (0.043%), cases among them 11
|new_x| > distance_shape: 0 
y sextiles, controls: NEW -0.355 -0.212 0.088 0.208 0.318  OLD -0.338 -0.185 0.095 0.212 0.325 
y sextiles, cases:    NEW -0.322 -0.232 0.045 0.175 0.295  OLD -0.302 -0.165 0.092 0.202 0.308 
```
Rows without a contour point within 0.01 in y (where step 2 sets `horiz_dist = min_dist`), counted with `horiz_dist_vec` on all rows: OLD 1 of 51,849 (0 cases), NEW 1 of 83,090 (1 case).

Reading: the standardization behaves on NEW as on OLD. `new_x` has the same range and quantiles (within 0.003); the smaller minimum of `distance_shape` (0.055 vs 0.0717) comes from NEW rows beyond OLD's y range (y up to 0.525 and down to -0.515), where the prototype outline narrows to its toe tip and heel bottom. The y knots are lower on NEW (-0.348 and -0.218 against -0.325 and -0.178): NEW's controls and, more so, its cases sit relatively lower (heel and midfoot). That is a dataset difference for T6, not a pipeline effect (the same code and prototype).

**NEW legacy loops = vectorized functions** (the NEW part added to `tests/r/test_distances_vectorized.R`, run alone):
```bash
Rscript tests/r/test_distances_vectorized.R
```
```
PASS float window (F14): OLD 160 of 392 three-row pairs with the data row above, 161 below; NEW 152 and 151 of 364; the round trip changes 263 of 395 and 245 of 367 y values; horiz_dist_vec admits the same pairs 
PASS min_dist and horiz_dist: the legacy loops of the Rmd and the vectorized functions identical() on 406 OLD rows (6 without a contour point within 0.01 in y) 
PASS distance_shape and new_x: the legacy loop and distance_shape_vec() identical() (228 distinct y) 
PASS NEW: min_dist, horiz_dist, distance_shape and new_x of the legacy loops and the vectorized functions identical() on 2000 random NEW rows of 603 shoes (seed 1; 0 without a contour point within 0.01 in y, 300 distinct y) 
SKIPPED whole OLD step 2 (set RAC_SLOW_TESTS=1; tests/regress_old.sh --steps 2 checks it on every gate run)
ALL PASS test_distances_vectorized

real	1m14.738s
user	1m6.869s
sys	0m3.948s
```

**Looked at:**
- `docs/qa/T5/compare/step2_distributions_old_vs_new.png` (densities, OLD blue, NEW orange, each dataset's knots dotted): the `new_x` densities of the controls and of the cases nearly coincide, and so do the new_x knots; the y densities differ at the heel: NEW has more mass below y = -0.2 (a peak of cases near y = -0.43 that OLD has weakly) and less in the forefoot, so its two lowest y knots sit 7 and 12 px lower; `min_dist` (px) has the same lattice-combed shape on both; `horiz_dist - min_dist` is 0-1 px for most rows on both.
- `docs/qa/T5/compare/step2_standardized_old_vs_new.png` (the points on the standardized shoe (new_x, y), square-root density, the OLD prototype outline in grey): every NEW point lies inside the prototype outline and NEW fills it to the edge as OLD does; NEW's controls show its dominant design (four round heel pads, around y = -0.25 and -0.43, and horizontal lug rows in the forefoot), OLD's are smoother; the cases of both concentrate on the heel and the forefoot with a sparse midfoot, NEW's sharply on the four pad positions.

## 6. Step 3: the NEW models

```bash
RAC_DATASET=new bash tools/run_pipeline.sh --steps 3 --timings <scratch>/t5/runs/timings_new.tsv
```
```
run_pipeline.sh: dataset new, steps 3, logs logs/new
step3_glmm: exit 0, 594.983664560 s
step3_cml: exit 0, 289.990047694 s
run_pipeline.sh: done (new, steps 3)
```
(Both fits ran while the two OLD-basis refits and the NEW rebuild gate ran beside them; the times are under that load.)

```bash
Rscript -e '
suppressMessages(library(lme4)); source("statistical_model/R/wald.R"); source("statistical_model/R/distances.R"); source("statistical_model/R/profile.R")
m <- readRDS("saved_models/new/NEW_X_NS_XY_new.rds")
cat("lme4", as.character(packageVersion("lme4")), "R", R.version.string, "\n")
cat("conv code", m@optinfo$conv$opt, "; lme4 messages:", if (is.null(m@optinfo$conv$lme4$messages)) "none" else m@optinfo$conv$lme4$messages, "; optimizer", m@optinfo$optimizer, "; warnings", length(m@optinfo$warnings), "\n")
cat("Hessian stored:", !is.null(m@optinfo$derivs$Hessian), "; vcov == RX vcov:", identical(as.matrix(vcov(m)), as.matrix(vcov(m, use.hessian = FALSE))), "\n")
cat(sprintf("sigma^2 %.7f (sd %.4f), theta %.7f, logLik %.4f, AIC %.2f\n", as.numeric(VarCorr(m)$shoe), sqrt(as.numeric(VarCorr(m)$shoe)), getME(m, "theta"), as.numeric(logLik(m)), AIC(m)))
print(wald_all_spatial(m))
\'
```
```
lme4 1.1.38 R R version 4.3.3 (2024-02-29) 
conv code 0 ; lme4 messages: none ; optimizer nlminbwrap ; warnings 0 
Hessian stored: FALSE ; vcov == RX vcov: TRUE 
sigma^2 0.7556134 (sd 0.8693), theta 0.8692603, logLik -41569.1219, AIC 83190.24
Wald test, all 24 spatial coefficients = 0 (manual): W = 585.8888, df = 24, p = 2.12e-108
  car::linearHypothesis: not run (car not installed)
```
```bash
Rscript docs/qa/T5/probes/t5_model_summary.R docs/qa/T5/new
```
```
NEW_X_NS_XY: conv 0, lme4 messages none, sigma^2 0.7556134, logLik -41569.1219, nobs 83090, groups 631, Wald W 585.8888 (df 24)
  knots new_x -0.0688500 0.0246575 0.1060954 | y -0.3483333 -0.2183333 0.0783333 0.2016667 0.3150000 | boundary new_x -0.1850000 0.2316667 | y -0.5150000 0.5250000 
CML_MODEL: method exact, iterations 4, loglik -39237.3149 -> -38937.5755, n 83090, events 19990, Wald W 576.0264 (df 24)
  knots new_x -0.0688500 0.0246575 0.1060954 | y -0.3483333 -0.2183333 0.0783333 0.2016667 0.3150000 | boundary new_x -0.1850000 0.2316667 | y -0.5150000 0.5250000 
NEW_X_NS_XY_oldbasis: conv 0, lme4 messages none, sigma^2 0.7552898, logLik -41548.8806, nobs 83090, groups 631, Wald W 623.1166 (df 24)
  knots new_x -0.0663992 0.0219597 0.1047822 | y -0.3250000 -0.1783333 0.0950000 0.2083333 0.3216667 | boundary new_x -0.1916667 0.2416667 | y -0.5016667 0.5116667 
CML_MODEL_oldbasis: method exact, iterations 4, loglik -39237.3149 -> -38917.7123, n 83090, events 19990, Wald W 612.4973 (df 24)
  knots new_x -0.0663992 0.0219597 0.1047822 | y -0.3250000 -0.1783333 0.0950000 0.2083333 0.3216667 | boundary new_x -0.1916667 0.2416667 | y -0.5016667 0.5116667 
written docs/qa/T5/new/model_summary_new.csv 
```
The fixed effects and standard errors of all four fits are in `docs/qa/T5/new/model_summary_new.csv` (term order: the intercept, then x1:y1, x2:y1, ..., x4:y6, new_x varying fastest). NEW GLMM, its own basis (estimate, SE):

| term | est | SE | term | est | SE | term | est | SE |
|---|---|---|---|---|---|---|---|---|
| (Intercept) | -1.8901 | 0.0565 | x1:y3 | -0.1978 | 0.1460 | x1:y5 | 0.4136 | 0.2155 |
| x1:y1 | -0.3058 | 0.2431 | x2:y3 | 0.0321 | 0.1581 | x2:y5 | -0.6987 | 0.3152 |
| x2:y1 | 0.9621 | 0.2659 | x3:y3 | 0.4075 | 0.1837 | x3:y5 | 2.8060 | 0.7202 |
| x3:y1 | 1.2878 | 0.3655 | x4:y3 | 0.2057 | 0.2239 | x4:y5 | 2.8379 | 1.3127 |
| x4:y1 | -0.4224 | 0.7276 | x1:y4 | 0.5632 | 0.1937 | x1:y6 | -0.9816 | 0.3111 |
| x1:y2 | 1.4395 | 0.2149 | x2:y4 | -0.3556 | 0.2574 | x2:y6 | -0.9829 | 0.5139 |
| x2:y2 | 0.0464 | 0.2110 | x3:y4 | 1.0618 | 0.2879 | x3:y6 | 0.3754 | 1.2507 |
| x3:y2 | 1.4379 | 0.2466 | x4:y4 | 0.1988 | 0.5040 | x4:y6 | 3.9094 | 2.2830 |
| x4:y2 | 0.9578 | 0.3391 | | | | | | |

**Reading (for the statistics expert, not a conclusion):**
- Convergence: code 0, no lme4 convergence message, no warning; the exact CML converged in 4 iterations.
- sigma^2 = 0.7556 against OLD 0.9598. Not comparable as it stands: the GLMM is fitted without the per-shoe offset (K2), so sigma^2 absorbs var(log(100/px)) (OLD 0.098; raw contact OLD 0.095, NEW 0.121, plan F32), and on OLD the offset refit's sigma^2 is 0.979 (F35). T6 fits both offset refits (A-044) for the comparable pair.
- The vcov is the RX-based one for NEW (lme4 1.1-38 stores no Hessian for more than 10,000 rows, F42), while the committed OLD step-5 W (428.69) uses the Windows Hessian; with RX on both, OLD 427.77 and NEW 585.89 (A-055's proposal). The model-based Wald tests assume RACs independent given the shoe effect (K9); the bootstrap versions are T5 step 3b.
- The OLD-basis refit has a higher log-likelihood than NEW's own quantile knots (-41548.88 vs -41569.12, the same 25 parameters): quantile knots are not the best knots for NEW (plan meeting issue 4, knots not justified).

**OLD basis (A-112):**
```bash
RAC_DATASET=new Rscript tools/fit_oldbasis_new.R NEW_X_NS_XY   # and CML_MODEL, in parallel
```
```
OLD basis from the OLD CSV; identical() to the committed NEW_X_NS_XY model's basis: TRUE ; max |difference|: 0 
List of 4
 $ knots_x : num [1:3] -0.0664 0.022 0.1048
 $ knots_y : num [1:5] -0.325 -0.178 0.095 0.208 0.322
 $ bknots_x: num [1:2] -0.192 0.242
 $ bknots_y: num [1:2] -0.502 0.512
NEW rows beyond the OLD boundary knots: new_x 0 (0.000%), y 36 (0.043%), either 36 (0.043%) of 83090; cases among them 11
fitted NEW_X_NS_XY on the OLD basis in 622.0 s; written <repo>/saved_models/new/NEW_X_NS_XY_oldbasis_new.rds
convergence code: 0 
lme4 messages: none 
sigma^2 = 0.7552898, logLik = -41548.8806, nobs = 83090, groups = 631
[... 10 lines omitted: the 25 fixed effects, in docs/qa/T5/new/model_summary_new.csv ...]

real	10m31.731s
user	10m9.288s
sys	0m2.985s
```
```
OLD basis from the OLD CSV; identical() to the committed CML_MODEL model's basis: TRUE ; max |difference|: 0 
[... 6 lines omitted: the same basis and boundary-knot lines as for the GLMM ...]
fitted CML_MODEL on the OLD basis in 405.2 s; written <repo>/saved_models/new/CML_MODEL_oldbasis_new.rds
iterations 4, loglik -39237.3149 -> -38917.7123, n = 83090, events = 19990
[... 8 lines omitted: the 24 coefficients, in docs/qa/T5/new/model_summary_new.csv ...]

real	6m51.795s
user	6m30.371s
sys	0m3.128s
```
A descriptive look on the common basis (the OLD SEs from the RX vcov, hence the lme4 warning; the formal equality tests are T6's, with the bootstrap V as primary, A-045):
```bash
Rscript docs/qa/T5/probes/t5_side_by_side.R
```
```
Warning message:
In vcov.merMod(o, use.hessian = FALSE) :
  variance-covariance matrix computed from finite-difference Hessian
and from RX differ by >1e-04: consider 'use.hessian=TRUE'
        term     OLD OLD_se NEW_oldbasis NEW_se z_diff
 (Intercept) -2.2716 0.0766      -1.9198 0.0531   3.77
       x1:y1 -0.2147 0.3062      -0.3240 0.2529  -0.28
       x2:y1  0.6387 0.3633       0.7926 0.2860   0.33
       x3:y1  2.5805 0.5066       1.0298 0.3855  -2.44
[... 7 lines omitted: x4:y1 to x2:y3 ...]
       x3:y3  2.0793 0.2371       0.4112 0.1842  -5.56
[... 13 lines omitted: x4:y3 to x4:y6 ...]
GLMM: correlation of the 24 spatial coefficients OLD vs NEW (OLD basis) 0.189; sigma^2 OLD 0.9598 NEW-oldbasis 0.7553
CML: correlation of the 24 coefficients OLD vs NEW (OLD basis) 0.177; max |z_diff| 5.56
```
Tensor-spline coefficients trade off against each other, so a low correlation of the coefficient vectors does not by itself mean dissimilar surfaces; the maps (section 7) and T6's tests are the comparison.

## 7. Steps 4-6: the NEW figures

```bash
RAC_DATASET=new bash tools/run_pipeline.sh --steps 4-6 --timings <scratch>/t5/runs/timings_new.tsv
```
```
run_pipeline.sh: dataset new, steps 4-6, logs logs/new
step4_glmm: exit 0, 14.572608731 s
step4_cml: exit 0, 13.116411914 s
step5: exit 0, 24.390929888 s
step6: exit 0, 18.408303970 s
run_pipeline.sh: done (new, steps 4-6)
```
`processed_data/new/wald_test_new.csv`:
```
"model","W","df","p","method","vcov","W_rx","p_rx"
"NEW_X_NS_XY",585.88877405274,24,2.11793465962583e-108,"manual","RX",585.88877405274,2.11793465962583e-108
```

**Looked at (Read tool, each NEW PDF; the OLD PDF beside it where it helps):**
- `model_images/new/NEW_X_NS_XY_SHOE_new.pdf` (GLMM, marginal intensity on the prototype, scale 0.0005-0.0028): highest at the centre of the midfoot just below the shoe's middle line (y about 0.5 of the plot), at the left heel (0.43, 0.26), at the right heel-midfoot (0.63, 0.38) and in a stripe along the right forefoot edge (x about 0.7, y 0.55-0.8, at NEW's right boundary knot); the forefoot centre is low except a spot at (0.44, 0.74); the toe tip is lowest. The OLD map (scale 0.0004-0.0019) peaks instead at the left forefoot (0.45, 0.73) and along the right midfoot edge, with the heel spot at the same place. The levels differ through `MEAN_OFFSET` and exp(-sigma^2/2) as well as through the fits, so T6 compares them on one scale.
- `CML_MODEL_SHOE_new.pdf`: the same pattern as the NEW GLMM map at this scale (the CML is mean-matched to the GLMM on the log-odds scale, as on OLD).
- `CI_shoe_cuts_new.pdf`: the CML probability with the cut rows 110 (forefoot: through the left spot and the right-edge stripe), 190 (top of the midfoot: the high centre and the right edge) and 250 (heel-midfoot: the left heel and the right side).
- `CI_cut_110_new.pdf`: peak a third of the way across (0.0020), dip right of centre (0.0014), rise at the right edge (0.0023, band 0.0018-0.0031); OLD has the same shape at lower levels (0.00196, 0.00115, 0.00166). At the left end the Random band is wider than the CML's on both datasets: the K8 edge, where the GLMM's log-odds is its intercept (whose SE remains) and the CML's basis is zero.
- `CI_cut_190_new.pdf`: rise to a peak right of centre (0.00237), dip (0.0020), rise at the right edge (0.0027, band to 0.0034); OLD rises to a plateau (0.0016-0.0017) with only a small rise at the right.
- `CI_cut_250_new.pdf`: left peak (0.00222), central dip (0.00176), right peak (0.00242) falling at the edge (0.00226); OLD: left peak (0.00167), dip (0.00114), rise to the right edge (0.00193).
- `pixel_inten_JASAup_new.pdf`: Random and CML side by side on one scale: indistinguishable by eye.
- `difference_random_cml_new.pdf`: Random - CML in [-3.5e-5, 1.4e-5], about 1-2% of the intensity; positive at the left forefoot spot and the left heel, negative along the right forefoot and right heel edges. OLD (`model_images/difference_random_cml.pdf`) has the same layout at about a quarter of the magnitude ([-8.5e-6, 6.7e-6]).

**PNG twins (A-111):**
```bash
RAC_DATASET=new Rscript tools/figures_png.R docs/qa/T5/new
RAC_DATASET=old Rscript tools/figures_png.R docs/qa/T5/old
```
```
png: <repo>/docs/qa/T5/new/NEW_X_NS_XY_SHOE_new.png 
shoe_std_results_4.Rmd NEW_X_NS_XY done
png: <repo>/docs/qa/T5/new/CML_MODEL_SHOE_new.png 
shoe_std_results_4.Rmd CML_MODEL done
[... 7 lines omitted: the four step-5 PNGs and the two step-6 PNGs ...]
model_comparison_6.Rmd NEW_X_NS_XY done
figures_png: done (new, steps 4,5,6) -> <repo>/docs/qa/T5/new

real	0m40.033s
user	0m37.809s
sys	0m2.446s
```
```
png: <repo>/docs/qa/T5/old/NEW_X_NS_XY_SHOE.png 
[... 11 lines omitted: the same for the OLD figures ...]
figures_png: done (old, steps 4,5,6) -> <repo>/docs/qa/T5/old

real	0m44.699s
user	0m42.951s
sys	0m2.021s
```
Looked at: the 8 NEW twins one by one and the OLD twins (`NEW_X_NS_XY_SHOE.png` at full size beside the committed PDF, the other 7 in one montage): each shows its PDF's content; `git status` showed no tracked file changed by either run. The heat-map PNGs have a 1-px seam between two rows of `image()` cells (OLD at y = 0.49, NEW at y = 0.41 of the plot), not in the PDFs and not removed by `antialias = "none"` (tried in scratch); the prototype mask has no hole there (checked).

**The K8 edges** (`docs/qa/T5/probes/t5_k8_edges.R`, the same code on both GLMMs; `docs/qa/T5/compare/k8_edges_old_vs_new.csv`):
```bash
Rscript docs/qa/T5/probes/t5_k8_edges.R docs/qa/T5/compare
```
```
old: intercept -2.271582; left edge new_x = -0.1916667 and heel edge y = -0.5016667: max |eta - intercept| 0 and 0; right edge eta -3.608 to -0.953, top edge -3.608 to -2.272; eta over dataCC p1/p50/p99 -2.238/-1.491/-1.166; within 0.03 of the left edge 200 rows (37 cases), median eta -1.969; of the heel edge 713 rows (109 cases), median eta -2.132
new: intercept -1.890142; left edge new_x = -0.1850000 and heel edge y = -0.5150000: max |eta - intercept| 0 and 0; right edge eta -1.890 to 1.797, top edge -2.738 to 1.797; eta over dataCC p1/p50/p99 -2.255/-1.500/-1.179; within 0.03 of the left edge 711 rows (107 cases), median eta -1.794; of the heel edge 838 rows (180 cases), median eta -1.796
```
On both datasets the fixed-effect log-odds equals the intercept along the whole left edge and the whole heel edge of the data (K8), while eta over the case-control rows is almost the same on both (p1/p50/p99). On NEW, 711 rows (107 cases) lie within 0.03 of the pinned left edge (OLD 200): NEW's left boundary knot (-0.185) is inside OLD's (-0.1917), so more NEW data sit near it. NEW's top-right corner (new_x 0.2317, y 0.525) extrapolates to eta 1.797; it lies outside the prototype mask, so the maps do not show it, but the right-edge stripe of the NEW maps (section 7, first bullet) is where the spline climbs toward it. The OLD figures agree with plan F28 except the heel-edge count: F28 counted y < edge + 0.03 (569 rows, 89 cases), this probe y <= edge + 0.03 (713, 109); the difference is the one lattice row at exactly 0.03 (checked in scratch: `<=: 713  <: 569  cases <: 89`).

## 8. Tests

### 8.1 `tests/r/test_new_outputs.R`
```bash
Rscript tests/r/test_new_outputs.R
```
```
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw records, the erase list, the stamp mask (>= 8 shoes, no pixel swept) and the RAC pixels = the pixel counts; every control on S and on no RAC pixel; LF only 
PASS step 2: (n_Acc, x, y, shoe) = dataCC; finite distances, horiz_dist >= min_dist, |new_x| <= distance_shape; every distance_shape a half-width of the prototype in its own frame; 631 contour records; 3510 rows of 25 random shoes recomputed from the committed contour identical() (new_x in [-0.1850, 0.2317]) 
PASS step 3: GLMM converged (25 fixed effects, 631 groups, 83090 rows, X rebuilt from the CSV = getME(X), sigma^2 0.7556); CML 24 coefficients, 19990 events; both on the NEW basis; the OLD-basis refits on the OLD basis 
PASS step 5: wald_test_new.csv W = 585.8888, df 24, vcov RX 
PASS steps 4-6: the 8 NEW PDFs and their PNG twins exist 
PASS no collision: 47 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the old_added lists and README files 
ALL PASS test_new_outputs

real	0m13.544s
user	0m11.896s
sys	0m1.642s
```
**Mutants** (each in its own scratch copy of the tree, `<scratch>/t5/mutants/`, deleted afterwards): (1) record 49 of the NEW contour with row 200 moved one column (49 is one of the 25 recomputed shoes); (2) one control of shoe code 3 moved by one pixel in both CSVs; (3) the NEW stamp threshold set to 13 in the profile:
```
== mutant contour
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw records, the erase list, the s
Error: identical(nd[[v]], ref[[v]]) is not TRUE
== mutant control
Error: all(abs(dataCC$x * scale + W/2 - cc_col) < 1e-06) is not TRUE
== mutant threshold
Error: identical(unname(mask == 1), unname(sum_raw >= P$r$stamp_threshold)) is not TRUE
```
All three are caught. Mutant (1) is the case that matters most: a NEW contour changed after step 2 (for example by a later T4 fix) fails the test until steps 2-6 are rerun.

### 8.2 `tests/r/test_figures_png.R`
```bash
Rscript tests/r/test_figures_png.R
```
```
PASS OLD step 6: exactly its two PNGs, 1200 x 1200 px; the committed OLD figures and the step-5 CSV untouched 
PASS NEW outside a new folder and OLD inside one are refused 
ALL PASS test_figures_png

real	0m17.489s
user	0m16.001s
sys	0m1.504s
```

### 8.3 Other tests run on this tree
`tests/r/test_distances_vectorized.R` (section 5), `tests/r/test_no_hardcoding.R` (`PASS no dataset literal in 33 R/Rmd files (4 OLD-only files allowed)`), `python -m unittest tests.python.test_no_hardcoding` (`Ran 3 tests ... OK`); the whole fast suite in section 10.

## 9. Files

| Kind | NEW (committed) |
|---|---|
| step 1 | `processed_data/new/dataCC_new.csv`, `shoe_pixel_counts_new.csv`, `all_cont_new.csv`, `shoe_codes_new.csv` |
| step 2 | `processed_data/new/dataCC_distance_temp_new.csv`, `dataCC_distance_new.csv` |
| step 3 | `saved_models/new/NEW_X_NS_XY_new.rds` (41 MB), `CML_MODEL_new.rds` (5 MB); OLD basis (A-112): `NEW_X_NS_XY_oldbasis_new.rds` (41 MB), `CML_MODEL_oldbasis_new.rds` (7 MB) |
| steps 4-6 | `model_images/new/{NEW_X_NS_XY_SHOE,CML_MODEL_SHOE,CI_shoe_cuts,CI_cut_110,CI_cut_190,CI_cut_250,pixel_inten_JASAup,difference_random_cml}_new.pdf`, `processed_data/new/wald_test_new.csv` |
| QA (looked at) | `docs/qa/T5/new/`: `stamp_mask_new.png`, `stamp_worst_new.png`, `stamp_shoes_new.csv`, `s_sheet_01_new.png` ... `s_sheet_13_new.png`, `s_outside_contour_new.csv`, `s_outside_zoom_new.png`, `model_summary_new.csv`, the 8 PNG twins; `docs/qa/T5/old/`: the 8 OLD PNG twins, `s_outside_contour.csv`; `docs/qa/T5/compare/`: `stamp_threshold_old_vs_new.csv`, `step2_distributions_old_vs_new.png`, `step2_standardized_old_vs_new.png`, `k8_edges_old_vs_new.csv` |
| code | `statistical_model/R/compare.R`, `tools/fit_oldbasis_new.R`, `tools/figures_png.R`, probes `docs/qa/T5/probes/t5_*.{R,py}` |
| tests | `tests/r/test_new_outputs.R`, `tests/r/test_figures_png.R`, NEW part of `tests/r/test_distances_vectorized.R` |
| T4 tables recomputed (A-110) | `docs/qa/T4/new/snake_metrics_new.csv`, `docs/qa/sheets_new/snake_qa_new.csv` (`coverage_r`), `docs/qa/T4/new/mask_threshold_new.csv` (no `r13_*` columns) |

No OLD output changed: the OLD folders hold only the Tier A files, the two T2 files and README files (test 8.1), and the Tier A checksums pass (section 10).

## 10. Gates

### 10.1 The fast suite, at `c3a057b`
```bash
bash tests/run_all.sh
```
```
[... 298 lines omitted: the checksum checks and the verbose unittest output ...]
Ran 184 tests in 114.373s
OK (skipped=3)
[... 136 lines omitted: the PASS lines of the 17 R scripts and the lint runs ...]
== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS       143s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        22s  Rscript tests/r/test_compare_glmm_fits.R
PASS         3s  Rscript tests/r/test_compare_models.R
PASS        46s  Rscript tests/r/test_distances_vectorized.R
PASS        18s  Rscript tests/r/test_figures_png.R
PASS        14s  Rscript tests/r/test_new_outputs.R
PASS         2s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        35s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         1s  Rscript tests/r/test_profile.R
PASS        53s  Rscript tests/r/test_profile_sentinels.R
PASS         8s  Rscript tests/r/test_run_manifest.R
PASS         2s  Rscript tests/r/test_step5_variant.R
PASS         9s  Rscript tests/r/test_sticker_masks.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python files)
PASS         5s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS

real	6m14.894s
user	7m4.234s
sys	0m49.598s
```
The two new R scripts (`test_figures_png.R`, `test_new_outputs.R`) and the NEW part of `test_distances_vectorized.R` ran inside the suite; the tree was not changed by the tests.

### 10.2 OLD regression, steps 1-6, at `c3a057b`
```bash
RAC_SCRATCH=<scratch>/t5/gates bash tests/regress_old.sh --steps 1-6 --keep
```
```
== regress_old.sh --steps 1-6: <scratch>/gates/regress_old_duW0Vz
result  check                                          detail
PASS    pipeline run                                   every step exit 0, every output regenerated
PASS    step 1 all_cont.csv = Tier A                   data/all_cont.csv sha256 d582cf502184...
PASS    step 1 dataCC.csv = Tier A                     processed_data/dataCC.csv sha256 cc4a476976ae...
PASS    step 1 shoe_pixel_counts.csv = Tier A          processed_data/shoe_pixel_counts.csv sha256 24bbd19cff59...
PASS    step 1 shoe_codes.csv = old_added_t2           processed_data/shoe_codes.csv sha256 3d6c09fe66e1...
PASS    step 2 dataCC_distance_temp.csv = Tier A       processed_data/dataCC_distance_temp.csv sha256 43d7c9b87946...
PASS    step 2 dataCC_distance.csv = Tier A            processed_data/dataCC_distance.csv sha256 f0e697ac6f79...
PASS    step 3 models identical() to Tier B            every field of the dump (logs/compare_models.txt)
PASS    NEW_X_NS_XY_SHOE.pdf normalized = Tier B       b99d794c1c9a...
PASS    CML_MODEL_SHOE.pdf normalized = Tier B         f79bf8e71c69...
PASS    CI_shoe_cuts.pdf normalized = Tier B           73b4093177d4...
PASS    CI_cut_110.pdf normalized = Tier B             b272df049df9...
PASS    CI_cut_190.pdf normalized = Tier B             1972d8dc93e6...
PASS    CI_cut_250.pdf normalized = Tier B             5c56923b2904...
PASS    pixel_inten_JASAup.pdf normalized = Tier B     f1fcbcfb7837...
PASS    difference_random_cml.pdf normalized = Tier B  8e18f4562914...
PASS    step 5 Wald W = Tier B (WSL refit)             W 427.7804472165, Tier B 427.7804472165, df 24
PASS    live check test_old_regression.R               logs/live_r.txt
PASS    live check test_live_r_pdfs                    logs/live_pdfs.txt
timings (s):
step        seconds        exit
step1       111.308265571  0
step2       25.885200748   0
step3_glmm  258.063543954  0
step3_cml   202.443135437  0
step4_glmm  13.257812080   0
step4_cml   12.614091564   0
step5       25.129307299   0
step6       18.639505003   0
ALL PASS

real	11m20.474s
user	10m24.930s
sys	0m53.727s
```
Every OLD output of steps 1-6 is reproduced: the five step-1/2 CSVs byte for byte against Tier A and `shoe_codes.csv` against `old_added_t2.sha256`, both models `identical()` to the T1 WSL refit (Tier B) in every dumped field, the 8 figures equal to Tier B after removing the PDF dates, the Wald W of the WSL refit equal to Tier B. The NEW profile change (A-110) and the new NEW outputs do not reach the OLD run.

### 10.3 OLD regression, step 0
The profile file is shared by step 0 (Python); A-110 changed only its NEW entry, and this run shows the OLD step 0 untouched:
```bash
RAC_SCRATCH=<scratch>/t5/gates bash tests/regress_old.sh --steps 0
```
```
== regress_old.sh --steps 0: <scratch>/t5/gates/regress_old_MGgqol
result  check                                          detail
PASS    pipeline run                                   every step exit 0, every output regenerated
PASS    step 0 OpenBLAS threads and kernel = baseline  16 threads, kernel Haswell
PASS    step 0 contour = Tier B (CRLF)                 data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B                  1556 npy/png files, all equal
PASS    live check test_snake_old_regression           logs/live_snake.txt
timings (s):
step   seconds        exit
step0  377.024227314  0
ALL PASS

real	7m22.930s
user	42m37.706s
sys	0m42.030s
```

### 10.4 NEW determinism: a fresh rerun reproduces the committed NEW outputs
NEW steps 1-6 rerun from scratch in a copy of the tree whose NEW step-1 to step-6 outputs were deleted, compared with the HEAD blobs (the committed probe; a first run of the same check from a scratch script, `<scratch>/t5/gates/new_rerun_oDk1Ah`, compared with the work-tree files and gave the same result, 18 min 39 s):
```bash
RAC_SCRATCH=<scratch>/t5/gates bash docs/qa/T5/probes/t5_new_rerun.sh
```
```
<scratch>/t5/gates/new_rerun_2rRRp2
run_pipeline.sh: dataset new, steps 1-6, logs logs/new
step1: exit 0, 236.965078460 s
step2: exit 0, 28.355498817 s
step3_glmm: exit 0, 479.708655546 s
step3_cml: exit 0, 289.120725662 s
step4_glmm: exit 0, 14.464848168 s
step4_cml: exit 0, 13.229880082 s
step5: exit 0, 24.411488950 s
step6: exit 0, 18.860276313 s
run_pipeline.sh: done (new, steps 1-6)
== CSVs (sha256: rerun vs HEAD)
SAME  processed_data/new/dataCC_new.csv 3c064f9dc5f0
SAME  processed_data/new/shoe_pixel_counts_new.csv 8faeb6735a39
SAME  processed_data/new/all_cont_new.csv 6513cc4283e5
SAME  processed_data/new/shoe_codes_new.csv ffbf32ae9bcf
SAME  processed_data/new/dataCC_distance_temp_new.csv ee3769786c4b
SAME  processed_data/new/dataCC_distance_new.csv 72e03d4efb89
SAME  processed_data/new/wald_test_new.csv fff19dcce95b
== models
fixef         n=25   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov          n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
[... 20 lines omitted: theta to wald_cml, every row identical=TRUE, all.equal(tol=0)=TRUE, max|diff| 0 or NA (character fields) ...]
models: every field identical()
== PDFs (normalized sha256)
SAME  model_images/new/CI_cut_110_new.pdf 4e1e76fa04bf
SAME  model_images/new/CI_cut_190_new.pdf d5f73244fa97
SAME  model_images/new/CI_cut_250_new.pdf 139de94f41b9
SAME  model_images/new/CI_shoe_cuts_new.pdf 02bdbf9fc1bd
SAME  model_images/new/CML_MODEL_SHOE_new.pdf a550c2fb89f9
SAME  model_images/new/NEW_X_NS_XY_SHOE_new.pdf edf868cfa0f8
SAME  model_images/new/difference_random_cml_new.pdf 10611398f96a
SAME  model_images/new/pixel_inten_JASAup_new.pdf 83b79944b3e0
ALL SAME

real	18m40.672s
user	16m51.735s
sys	1m49.113s
```
Every committed NEW output of steps 1-6 is reproduced exactly: the CSVs byte for byte (the case-control draw with the profile's seed included), both models `identical()` in every dumped field, the 8 figures after removing their dates. T8's `tests/e2e/test_new_rerun.sh` can start from this probe.

## 11. Timings (this machine, WSL; several jobs at once)

| What | Time |
|---|---|
| stamp probe (OLD + NEW 8 and 13) | 40.7 s |
| NEW step 1 | 309.1 s |
| step-1 sheets (NEW / OLD screen) | 50.0 s / 37.3 s |
| NEW step 2 (vectorized) | 36.0 s |
| NEW step 3 GLMM / CML | 595.0 s / 290.0 s |
| OLD-basis GLMM / CML (fit; whole script) | 622.0 s; 10 min 32 s / 405.2 s; 6 min 52 s |
| NEW steps 4 (GLMM, CML), 5, 6 | 14.6 s, 13.1 s, 24.4 s, 18.4 s |
| PNG twins NEW / OLD | 40.0 s / 44.7 s |
| `tests/rebuild_new.sh --full` / fast | 438 s of steps (step 0 149 s, metrics 41 s, figures 150 s, thresholds 48 s, overrides 51 s) / 219 s of steps |
| `test_new_outputs.R` / `test_figures_png.R` / `test_distances_vectorized.R` | 13.5 s / 17.5 s / 74.7 s |
| NEW rerun of steps 1-6 with comparison (`t5_new_rerun.sh`) | 18 min 41 s (step 1 237 s, step 2 28 s, GLMM 480 s, CML 289 s, steps 4-6 71 s) |
| OLD gates `regress_old.sh --steps 1-6` / `--steps 0` | 11 min 20 s / 7 min 23 s |
| `run_all.sh` | 6 min 15 s; 5 min 47 s on the final tree |

## 12. Not done here, and open points

- **T5 step 3b (robust variances on both datasets: shoe bootstrap, Efron-cluster CML, `robust_variance_5b.Rmd`, `tests/r/test_robust.R`) is not part of this task** and is not started. The measured fit times for its budget: NEW GLMM 595 s and exact CML 290 s under load (OLD, T1: GLMM 281-305 s, CML 228-230 s).
- For Shlomo: A-110 (NEW stamp threshold 8 instead of the provisional 13; it also changed `coverage_r` in two T4 QA tables), A-111 (PNG twins drawn, not converted), A-112 (OLD-basis refits recorded now for T6).
- For the statistics expert (plan T5 step 4): sigma^2 0.756 vs 0.960 is not comparable without the offset refits (T6); the right forefoot edge stripe of the NEW maps near NEW's right boundary knot, and the wider Random band at the K8 left edge on both datasets; NEW's cases sit lower (heel) than OLD's.
- If the NEW contour changes again (the last T4 vision review lists three cost-free fallbacks, 591, 148, 125, not applied), steps 2-6 must be rerun; `tests/r/test_new_outputs.R` detects a stale step 2.
