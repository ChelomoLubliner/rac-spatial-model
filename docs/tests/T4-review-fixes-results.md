# T4 review fixes: results (2026-11-06)

Fixes for the three T4-snake reviews (`docs/progress/LOG.md`, entries "T4-snake review (reviewer:engineer)", "(reviewer:vision)", "(reviewer:reproducibility)"): three major findings and the minor notes. Every block below is a real command and its real output (`<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`; `VPY` = `<scratch>/t1/venv_copy/bin/python`, the thesis venv copied to the Linux filesystem in T1, the same packages; long outputs trimmed with an explicit marker). Commits `405da3a` (code, erase list, overrides, review file, probes), `a612b6d` (NEW contour and QA outputs), `8fefa20` (tests and gates), `9d51fff` (the OLD snake test checks the OpenBLAS thread count; the gate's live check and the fast suite drop the thread variables), `f05e00d` (OLD QA reference), then the docs commit. Decisions A-099 to A-106 (`docs/decisions.md`); the visual review, sheet by sheet, in `docs/qa/snake-qa.md` (NEW section, rewritten), with the notes written right after each view in `<scratch>/t4fix/visual_notes.md`. The scripts of the exploration are committed as `docs/qa/T4/probes/t4fix_*.py` (scratch copies in `<scratch>/t4fix/`).

## 0. Summary

| Finding | Fix | Evidence | Section |
|---|---|---|---|
| **Major 1** (vision): visibly wrong contours that no band flags (a RAC far outside a RAC-rich shoe; cut heels and toes); the fallback never tried on them | absolute triggers next to the share bands: a RAC 3 px or more outside the record fill, cleaned contact more than 8 px outside (A-099); the radius-16/24 fallback run and looked at on every flagged shoe; 15 more overrides taken (165 at radius 16; A-102); 185's dropped | T4 contour under the new bands: 41 flagged; corrected outputs: 30 flagged, all resolved; 120, 222, 286, 12, 267 on radius 24; 18 recorded (no radius helps); 328 recorded as a partial print | 1, 3 |
| **Major 2** (vision): frame artefacts survive in cleaned shoes (584, 586, 580, small remnants) | 23 erase rectangles (A-100): 584's line, 586's band block, 580's bar outside the same-design heel envelope, line ends of 148 and 186, 105's debris blob, 481's dash; step 0, mask, QA and sheets rebuilt and looked at | no artefact left in a cleaned shoe or a contour; 580's heel ends on row 332 like its aligned partners; residuals named (223's stroke, 586's blunt toe) | 2, 7 |
| **Major 3** (engineer): no test pins the T4 step-0 behaviours | the sentinel fixture's NEW entry gets a closing radius, an override and an erase rectangle; `test_t4_values_reach_outputs`; forked = serial on the fixture; the NEW rebuild gate `tests/rebuild_new.sh` (A-103) | the reviewer's three mutants are caught (they passed 45 tests before); the rebuild gate passes | 8, 9 |
| Minor: partial prints not listed | review classes `partial_print`, `spike`, `rim_cut`, `mask_cut` (A-101) | 56 rows: 30 flagged, 26 classed | 4 |
| Minor: initial-ellipse claim | documentation corrected; an enlarged ellipse tried, not taken (A-105) | 43 shoes with print outside the ellipse (OLD 13); 94.5% vs 95.1% | 6.3 |
| Minor: spikes and rim cuts (9, 376; 170, 46, 294) | 376 and 46 on radius 24; 9, 170, 294 (and 205) classed `spike` / `rim_cut` | section 3 | 3, 4 |
| Minor: the 98.10% headline holds only with the relaxed tightness band | the literal-band rate stated beside every headline; A-093 erratum (A-106) | T4: 602 of 631 (95.40%); now 588 (93.19%) | 6.1 |
| Minor: `docs/qa/snake_qa_new.csv` outside a NEW folder, a hand copy | moved to `docs/qa/sheets_new/snake_qa_new.csv`, written by `qa_snake --metrics` (A-104) | `Files.test_complete` | 8 |
| Minor: `--thresholds` without the BLAS check; hard-coded 8; NEW dims in tests; circular test; OLD `--sheets` crash; `--jobs` on Windows | `check_blas_threads` before the study; 8 read from the OLD profile; boundaries from the profile; docstring; refusals with exit 2 (`qa_snake.refusal`, `main`) | `CommandLine`, `Stickers` tests | 8 |
| Minor: A-092's portability claim; the OLD gate's silent dependence on 16 threads; the environment record | A-092 narrowed (A-103); kernel in the step-0 log and in `environment.txt`; `openblas_tier_b.txt`; `regress_old.sh` unsets the thread variables and stops on another count | `taskset -c 0-3` refused in 3 s; the gate with `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=3` passes | 9 |
| Minor: doc slips (14 R scripts, section numbers, 0.9696, the OLD reference's restore step, suite commit) | corrected in `T4-snake-results.md`; errata A-106 | | 10 |

Output sha256: NEW contour `0af52b05648d67c9b8e712aca6d03d4d73c5ae30bdd32ea81a348a46c13e8372` (T4: `88d55933...`). OLD outputs unchanged (section 11).

## 1. Major 1: absolute QA triggers (A-099)

The distance from each RAC pixel and each cleaned contact pixel to the record's row-span fill, on the committed T4 contours (NEW) and on the committed OLD contour (the T4 OLD QA copy, `<scratch>/t4/old_qa/repo`, its contour = Tier A `ca8a07f2...`):
```bash
$VPY -B <scratch>/t4fix/trigger.py <scratch>/t4fix/trigger_new.csv new        # = docs/qa/T4/probes/t4fix_triggers.py
$VPY -B <scratch>/t4fix/trigger.py <scratch>/t4fix/trigger_old.csv old <scratch>/t4/old_qa/repo
```
```
new: 631 shoes
  RAC outside the fill by > 2 px: 11 shoes
  RAC outside the fill by > 2.9 px: 11 shoes
  RAC outside the fill by > 4 px: 9 shoes
  RAC outside the fill by > 6 px: 9 shoes
  cleaned contact outside the fill by > 4 px: 59 shoes
  cleaned contact outside the fill by > 6 px: 39 shoes
  cleaned contact outside the fill by > 8 px: 31 shoes
  cleaned contact outside the fill by > 10 px: 18 shoes
  cleaned contact outside the fill by > 12 px: 10 shoes
  quantiles rac_out_max_px [0.0, 0.0, 0.0, 8.36] max 28.284271247461902
  quantiles contact_out_max_px [0.0, 3.61, 7.62, 13.42] max 24.08318915758459
old: 386 shoes
  RAC outside the fill by > 2 px: 4 shoes
  RAC outside the fill by > 2.9 px: 3 shoes
  RAC outside the fill by > 4 px: 3 shoes
  RAC outside the fill by > 6 px: 2 shoes
  cleaned contact outside the fill by > 4 px: 55 shoes
  cleaned contact outside the fill by > 6 px: 42 shoes
  cleaned contact outside the fill by > 8 px: 23 shoes
  cleaned contact outside the fill by > 10 px: 14 shoes
  cleaned contact outside the fill by > 12 px: 11 shoes
  quantiles rac_out_max_px [0.0, 0.0, 0.0, 1.19] max 8.0
  quantiles contact_out_max_px [0.0, 6.32, 8.06, 15.52] max 24.166091947189145
```
The NEW shoes with a RAC 3 px or more outside: 8, 107, 18, 506, 286, 11, 120, 121, 140, 222, 113 (unflagged by T4: 18, 286, 120, 222, 113); with contact more than 8 px outside, 31, the reviewer's 120, 328, 12, 286, 267 among them (full lists in `<scratch>/t4fix/trigger_new.csv`). The reviewer's 205 has its RAC 2.0 px from the fill (below the trigger; it is classed `rim_cut`, section 4). `qa_snake` computes both distances (`rac_out_max_px`, `contact_out_max_px`) and `BANDS` flags `> 2.9` (that is >= 3) and `> 8`. The T4 contour under the new bands: **41 flagged, 590 pass (93.50%)**.

## 2. Major 2: the erase list and the rebuilt mask (A-100)

### 2.1 What survived (pixel dumps, `<scratch>/t4fix/dump.py`; `#` cleaned contact, `e` erased, `r` removed by the mask, `o`/`*` contour)
584, the row below the heel (columns 80-190):
```
 333 ,,,,,,,,,,,,,,,,,,,o,,,,,,,,,,,,,,,,,,,,###################,,,,,,,,,o,,,,,,,,,,,,,,,,,,,,
 334   ,,,,,,,####,,,,,,o#####,,,,,,,,,,##########,,######,,,,,,,,###,,oo,,,,,,,,,,,,,,,,,,,,        rrrr
```
A straight 1-px line on row 334 (columns 89-180, 28 px inside the mask) under a heel that ends on row 333 at columns 120-138.

586 against the same-design 587 aligned on the forefoot (`<scratch>/t4fix/align.py 586 587 47 140 80 175`: best shift +4 rows, -1 column, Jaccard 0.530): contact per row in columns 105-141:
```
row  586(cols 95-160)  587 row-4 (cols 94-159)   586 cols105-141  587(row-4, cols104-140)
37 33 0     33 0
38 34 0     34 0
39 37 0     37 0
40 36 0     36 0
41 33 4     33 4
42 31 5     31 5
43 33 10     27 10
44 33 12     26 12
[... rows 45-60 omitted: in columns 105-141, 586 has 4-24 px per row against 8-17 on the aligned 587 ...]
```
Rows 37-42 are a solid block of the band (31-37 px per row against 0-5); from row 43 on both prints have separate lugs (586 about twice as inked at rows 43-46, comparable below). A pixel template from the aligned 587 does not fit 586's lugs even below the band (`<scratch>/t4fix/template_dump.py 586 33 56 90 170 1 587:4:-1`: `kept near a template: 207, away (x): 345`, many `x` at rows 47-56), so the block is erased as a rectangle.

580 against its aligned partners (583 shift -1, +1; 584 -1, +1; 581 -2, +1; `align.py` over the heel, rows 200-320): per-row extent of the kept contact, columns 100-170:
```
row | 580 kept (count, span cols 100-170) | 583 | 581 | 584 (aligned)
326 46 109-166 | 28 114-141 | 22 108-129 | 43 109-151
327 42 111-158 | 28 115-142 | 21 110-130 | 39 111-149
328 39 114-157 | 26 115-140 | 21 111-131 | 36 112-147
329 47 110-158 | 24 116-139 | 20 112-131 | 33 114-146
330 50 109-158 | 18 119-137 | 18 114-131 | 29 117-145
331 48 110-158 | 15 120-134 | 10 120-129 | 25 118-142
332 47 110-158 | 7 125-132 | 0 - | 19 121-139
333 47 109-158 | 0 - | 0 - | 24 101-144
334 46 109-158 | 0 - | 0 - | 0 -
```
(584's row 333 aligned is its own frame line.) 580's rows 329-334 are a solid bar 50 columns wide; its rows 325-328 reach 7-15 columns beyond the partners on the right (the wedge's remnants).

### 2.2 The added rectangles
```bash
$VPY -B docs/qa/T4/probes/t4fix_erase_list.py <scratch>/t4fix/erase_check.csv
```
On the T4 run (mask 35,156 px), when the rectangles were chosen (`<scratch>/t4fix/propose_erase.py`, the same code):
```
580 rectangles erase exactly the contact outside the envelope: True 199
105 rectangles hold exactly the blob: True 96
584,334,334,85,185: erased 32 (in mask 28)
586,37,42,105,141: erased 204 (in mask 204)
580,325,325,154,167: erased 1 (in mask 1)
580,326,326,153,167: erased 8 (in mask 8)
580,327,327,151,158: erased 8 (in mask 8)
580,328,328,150,157: erased 8 (in mask 8)
580,329,329,110,112: erased 3 (in mask 3)
580,329,329,148,158: erased 11 (in mask 11)
580,330,330,109,115: erased 7 (in mask 7)
580,330,330,147,158: erased 12 (in mask 12)
580,331,331,110,116: erased 7 (in mask 7)
580,331,331,144,158: erased 15 (in mask 15)
580,332,332,110,117: erased 8 (in mask 8)
580,332,332,141,158: erased 18 (in mask 18)
580,333,334,109,158: erased 93 (in mask 93)
148,30,30,87,100: erased 14 (in mask 3)
186,31,37,157,210: erased 172 (in mask 1)
186,33,33,95,105: erased 1 (in mask 1)
186,212,216,187,190: erased 7 (in mask 1)
186,260,263,182,184: erased 6 (in mask 1)
105,28,37,156,169: erased 81 (in mask 7)
105,38,41,159,169: erased 15 (in mask 4)
481,335,335,80,92: erased 6 (in mask 6)
total new erased 737 in mask 455 ; zero rows: []
wrote .../erase_proposed.csv 48 rows
```
No rectangle holds a RAC pixel (the probe prints `RAC!` otherwise; `test_qa_snake.Stickers.test_new_list`). Rerun at the end on the final images, the probe writes the committed list byte for byte: `wrote .../erase_check.csv 48 rows; equal to the committed list: True` (the "in mask" counts then use the final mask). 9's isolated mark above the toe was considered and left: it lies in line with the forefoot's centre rib (section 3).

### 2.3 Step 0 with the longer list (run 1) and the mask
```bash
RAC_DATASET=new MPLBACKEND=Agg TQDM_DISABLE=1 PYTHONDONTWRITEBYTECODE=1 $VPY -B -m contour_algorithm.main --qa --jobs 14
```
```
erase list: 48 rectangles on 11 shoes, 4143 contact pixels erased
step0 contour: 27.4 s
numpy OpenBLAS threads: 1, snake jobs: 14
numpy OpenBLAS kernel: Haswell
Active contour processing complete - 631 shoes, 631 contour records (shoes without a record: [])
step0 snake: 75.1 s
real	1m46.654s
```
Against the T4 run (three short numpy snippets on the saved T4 outputs in `<scratch>/t4fix/run1/`; the superposition check ran on the proposal before the run):
```
mask px before 35156 after 34509 pixels changed 935
contour records changed: 43 [9, 13, 14, 15, 24, 35, 36, 37, 55, 56, 67, 73, 104, 105, 114, 118, 119, 125, 128, 142, 148, 149, 156, 185, 186, 264, 314, 326, 329, 337, 379, 386, 388, 401, 422, 423, 481, 486, 577, 580, 581, 584, 586]
shoes whose matrices changed: [105, 148, 186, 481, 580, 584, 586]

pixels whose superposition count changes: 695 ; counts before at those pixels: min 1 max 367
threshold 18 : superposition >= t changes at 2 pixels
threshold 29 : superposition >= t changes at 1 pixels

lost 791 px in 22 pieces
   rows 19 165 cols 118 204 px 237
   rows 20 92 cols 69 117 px 122
[... 16 more pieces of 6-110 px along both sides and the heel bottom omitted ...]
gained 144 px in 1 pieces
   rows 240 342 cols 145 183 px 144
contact removed by the mask: before 3939 after 4149
shoes losing most contact to the new mask: [(36, 30), (104, 22), (55, 16), (14, 16), (125, 14), (156, 13), (15, 12), (35, 11), (581, 10), (105, 8), (114, 8), (486, 8), (379, 7), (422, 7), (577, 7)]
```
Two pixels of the superposition >= 18 changed, and the prototype snake turned that into a mask ring of 1-3 px: the snake's sensitivity to tiny input changes (A-060), not a new choice. The threshold study on the new matrices:
```bash
RAC_DATASET=new OPENBLAS_NUM_THREADS=1 MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 $VPY -B -m contour_algorithm.qa_snake --thresholds 13,18,24,29,36 --compare 18,29 --jobs 14
```
```
threshold 13: mask 34736 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9973, removed 4045 px from 90 shoes
threshold 18: mask 34509 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9969, removed 4149 px from 92 shoes
threshold 24: mask 33946 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9968, removed 4295 px from 97 shoes
threshold 29: mask 33428 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9965, removed 4463 px from 103 shoes
threshold 36: mask 33520 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9964, removed 4537 px from 104 shoes
wrote .../docs/qa/T4/new/mask_threshold_new.csv
wrote .../docs/qa/sheets_new/prototype/prototype_mask_new.png
new: 631 shoes, 41 flagged, 590 pass every band (93.50%)
```
Both thresholds still pass the plan's criteria and 18 still keeps more sole (A-096 stands). The figure was looked at (snake-qa.md).

## 3. Major 1: the fallback on the flagged shoes (A-102)

Radius 16 and 24 on the 41 flagged shoes and on the reviewer's 9, 205, 294, 376 (`<scratch>/t4fix/fallback_batch.py`, = `docs/qa/T4/probes/t4fix_fallback.py`; `*` = the run's configuration; flags abbreviated):
```bash
OPENBLAS_NUM_THREADS=1 PYTHONDONTWRITEBYTECODE=1 $VPY -B <scratch>/t4fix/fallback_batch.py <scratch>/t4fix/fb1 14 8 11 12 14 18 24 35 36 46 69 107 113 120 121 140 149 165 170 173 222 231 235 263 267 286 302 314 328 375 401 405 422 427 432 437 456 503 506 583 585 586 9 205 294 376
```
```
8 *r24: c0.980 t0.98 ro28 co9 [cov,fill,racc,racout,cout] | r16: c0.978 t0.97 ro29 co12 [cov,turn,fill,racc,racout,cout] | r24: c0.980 t0.98 ro28 co9 [cov,fill,racc,racout,cout]
11 *r10: c1.000 t1.05 ro10 co0 [racc,racout] | r16: c1.000 t1.02 ro9 co0 [turn,racc,racout] | r24: c1.000 t1.04 ro7 co0 [turn,racc,racout]
12 *r10: c0.992 t0.99 ro0 co16 [cout] | r16: c1.000 t1.00 ro0 co0 [-] | r24: c1.000 t1.01 ro0 co0 [-]
14 *r10: c0.997 t0.96 ro0 co11 [mask,cout] | r16: c0.994 t0.96 ro0 co8 [mask,cout] | r24: c0.992 t0.95 ro0 co2 [-]
18 *r10: c0.999 t0.97 ro15 co5 [racout] | r16: c0.999 t0.99 ro15 co6 [racout] | r24: c1.000 t1.00 ro15 co0 [racout]
24 *r10: c0.999 t0.97 ro0 co9 [cout] | r16: c0.999 t0.96 ro0 co9 [cout] | r24: c1.000 t0.97 ro0 co8 [cout]
35 *r10: c0.995 t0.93 ro0 co10 [cout] | r16: c0.996 t0.95 ro0 co2 [mask] | r24: c0.994 t0.95 ro0 co4 [mask]
36 *r10: c0.997 t0.96 ro0 co1 [mask] | r16: c0.997 t0.98 ro0 co1 [mask] | r24: c0.995 t0.97 ro0 co2 [mask]
46 *r10: c0.991 t0.98 ro0 co8 [cout] | r16: c0.989 t0.94 ro0 co7 [cov] | r24: c0.993 t0.95 ro0 co2 [-]
69 *r10: c0.994 t0.95 ro0 co12 [cout] | r16: c0.999 t0.97 ro0 co1 [-] | r24: c1.000 t0.96 ro0 co0 [-]
107 *r10: c0.993 t0.96 ro16 co16 [racc,racout,cout] | r16: c0.997 t0.95 ro16 co17 [racc,racout,cout] | r24: c0.998 t0.94 ro18 co19 [racc,racout,cout]
113 *r24: c0.999 t0.98 ro3 co2 [racout] | r16: c0.999 t0.98 ro4 co6 [racc,racout] | r24: c0.999 t0.98 ro3 co2 [racout]
120 *r10: c0.998 t0.97 ro8 co24 [racout,cout] | r16: c0.998 t0.96 ro6 co24 [racout,cout] | r24: c0.999 t0.97 ro0 co13 [cout]
121 *r10: c0.994 t0.92 ro8 co9 [racc,racout,cout] | r16: c0.993 t0.91 ro7 co8 [racc,racout] | r24: c0.990 t0.93 ro11 co11 [racc,racout,cout]
140 *r10: c0.996 t1.02 ro8 co9 [racc,racout,cout] | r16: c0.997 t1.02 ro4 co4 [racc,racout] | r24: c1.000 t1.01 ro2 co0 [racc]
149 *r10: c1.000 t0.96 ro0 co9 [cout] | r16: c1.000 t0.98 ro0 co4 [-] | r24: c1.000 t0.98 ro0 co2 [-]
165 *r10: c0.990 t0.97 ro0 co6 [cov] | r16: c0.998 t0.97 ro0 co6 [-] | r24: c0.998 t1.00 ro0 co3 [turn]
170 *r10: c0.988 t0.96 ro0 co3 [cov] | r16: c0.987 t0.95 ro0 co3 [cov] | r24: c0.987 t0.94 ro0 co3 [cov]
173 *r10: c0.998 t0.93 ro0 co11 [cout] | r16: c0.999 t0.94 ro0 co4 [-] | r24: c0.999 t0.96 ro0 co2 [-]
222 *r10: c0.999 t0.99 ro4 co8 [racout] | r16: c0.999 t0.96 ro2 co6 [-] | r24: c1.000 t1.02 ro0 co0 [-]
231 *r10: c0.999 t0.98 ro0 co10 [cout] | r16: c0.999 t1.03 ro0 co0 [-] | r24: c0.999 t1.01 ro0 co0 [-]
235 *r10: c0.998 t0.97 ro0 co8 [cout] | r16: c0.999 t0.99 ro0 co0 [-] | r24: c1.000 t1.02 ro0 co0 [-]
263 *r10: c1.000 t1.07 ro2 co0 [racc] | r16: c1.000 t1.06 ro2 co0 [racc] | r24: c1.000 t1.06 ro1 co0 [racc]
267 *r10: c0.991 t1.03 ro0 co10 [cout] | r16: c0.991 t1.04 ro0 co9 [cout] | r24: c1.000 t1.03 ro0 co0 [-]
286 *r10: c0.997 t0.99 ro11 co13 [racout,cout] | r16: c0.994 t0.98 ro7 co9 [racout,cout] | r24: c1.000 t1.04 ro0 co0 [-]
302 *r10: c0.999 t0.99 ro0 co10 [cout] | r16: c0.999 t1.02 ro0 co0 [-] | r24: c1.000 t1.01 ro0 co0 [-]
314 *r10: c1.000 t1.03 ro0 co8 [cout] | r16: c1.000 t1.02 ro0 co8 [cout] | r24: c1.000 t1.05 ro0 co3 [-]
328 *r10: c0.996 t0.96 ro0 co20 [cout] | r16: c0.999 t1.03 ro0 co0 [-] | r24: c0.999 t1.04 ro0 co0 [-]
375 *r10: c0.995 t0.86 ro0 co7 [tight] | r16: c0.999 t0.89 ro0 co0 [tight] | r24: c0.996 t0.90 ro0 co9 [tight,cout]
401 *r10: c1.000 t1.00 ro0 co16 [cout] | r16: c1.000 t0.97 ro0 co13 [cout] | r24: c1.000 t1.01 ro0 co11 [cout]
405 *r10: c0.999 t0.89 ro0 co2 [tight] | r16: c1.000 t0.95 ro0 co0 [-] | r24: c1.000 t0.96 ro0 co0 [-]
422 *r10: c1.000 t0.98 ro0 co15 [cout] | r16: c1.000 t0.99 ro0 co14 [cout] | r24: c1.000 t1.01 ro0 co11 [cout]
427 *r10: c0.997 t0.96 ro0 co9 [cout] | r16: c0.998 t0.96 ro0 co7 [-] | r24: c0.999 t0.98 ro0 co0 [-]
432 *r10: c0.996 t0.95 ro0 co11 [cout] | r16: c0.996 t0.96 ro0 co9 [cout] | r24: c0.996 t0.98 ro0 co7 [-]
437 *r10: c1.000 t0.98 ro0 co12 [cout] | r16: c1.000 t0.99 ro0 co9 [cout] | r24: c1.000 t1.02 ro0 co3 [-]
456 *r10: c0.994 t0.98 ro0 co11 [cout] | r16: c0.994 t1.00 ro0 co10 [cout] | r24: c0.996 t1.03 ro0 co5 [-]
503 *r10: c1.000 t1.04 ro2 co0 [racc] | r16: c1.000 t1.04 ro3 co0 [racc,racout] | r24: c1.000 t1.05 ro1 co0 [racc]
506 *r10: c0.995 t1.05 ro14 co8 [racc,racout,cout] | r16: c1.000 t1.05 ro7 co0 [racc,racout] | r24: c1.000 t1.08 ro6 co0 [racc,racout]
583 *r10: c0.999 t1.02 ro0 co10 [cout] | r16: c0.999 t1.04 ro0 co9 [cout] | r24: c0.999 t1.08 ro0 co1 [-]
585 *r10: c0.993 t0.99 ro0 co14 [cout] | r16: c0.993 t1.02 ro0 co9 [cout] | r24: c0.997 t1.04 ro0 co1 [-]
586 *r10: c0.999 t1.01 ro0 co8 [cout] | r16: c0.999 t1.00 ro0 co6 [-] | r24: c0.999 t1.03 ro0 co4 [-]
9 *r10: c0.998 t1.02 ro0 co4 [-] | r16: c0.997 t0.99 ro0 co3 [-] | r24: c0.998 t0.96 ro0 co4 [-]
205 *r10: c1.000 t0.96 ro2 co0 [-] | r16: c0.999 t0.93 ro3 co0 [racout] | r24: c1.000 t0.98 ro2 co0 [-]
294 *r10: c0.991 t1.03 ro0 co3 [-] | r16: c0.994 t1.04 ro0 co2 [-] | r24: c0.991 t1.03 ro0 co2 [-]
376 *r10: c0.995 t0.95 ro0 co8 [-] | r16: c0.998 t0.95 ro0 co4 [-] | r24: c1.000 t0.98 ro0 co0 [-]
```
Fewer bands broken does not settle it: on many shoes radius 24 passes only because it bulges out to an isolated speck. Where the flagged part lies (`$VPY -B <scratch>/t4fix/flag_facts.py <scratch>/t4fix/run3/flag_facts.csv` on the run-3 outputs; the facts quoted in the review file), for example:
```
149 [contact_out_max_px] cov 0.9999 t 0.961 rac 1.0 (n 9); mask cut 0
   outside: 1 px (1 outside) 8.9 px out, 15.0 px from the print, toe right
231 [contact_out_max_px] cov 0.9993 t 0.979 rac 1.0 (n 12); mask cut 0
   outside: 5 px (5 outside) 10.3 px out, 18.0 px from the print, toe left
328 [contact_out_max_px] cov 0.9959 t 0.963 rac 1.0 (n 11); mask cut 0
   outside: 3 px (3 outside) 20.1 px out, 11.4 px from the print, heel centre; 6 px (6 outside) 19.9 px out, 11.4 px from the print, heel centre; 5 px (5 outside) 18.0 px out, 15.6 px from the print, heel right; 4 px (4 outside) 2.0 px out, 2.2 px from the print, heel right
432 [contact_out_max_px] cov 0.9957 t 0.947 rac 1.0 (n 6); mask cut 0
   outside: 39 px (39 outside) 11.3 px out, 10.6 px from the print, heel left
585 [contact_out_max_px] cov 0.9926 t 0.992 rac 1.0 (n 18); mask cut 0
   outside: 29 px (29 outside) 13.6 px out, 19.8 px from the print, arch right; 4 px (2 outside) 1.0 px out, 2.8 px from the print, toe centre
[... the other 25 flagged shoes omitted; all 30 in <scratch>/t4fix/run3/flag_facts.txt ...]
```
Each candidate was looked at side by side around its flagged part (`<scratch>/t4fix/fb2/focus_{a,b,c,d}.png`, radius 10 / 16 / 24 on the corrected images; notes in snake-qa.md and `visual_notes.md`); same-design partners were aligned where a mark could be sole: 427's mark above the toe lies where the aligned 426 and 431 have their toe tips (`426 aligned: first print row 38`, `431 aligned: first print row 34`, 427's mark on row 40), so it is the printed toe tip and radius 24 was taken; 432's blob and 422's piece lie where the aligned 433 and 423 have no heel; 328's specks lie below where the aligned 327's heel ends. Taken: 12, 46, 69, 120, 140, 173, 222, 235, 267, 286, 376, 427, 456, 506 (radius 24) and 165 (radius 16); 185 dropped (its profile contour passes every band on the corrected images; radius 10 and 24 enclose the same heel). Not taken, with the reason, in A-102 and the review file.

```bash
OPENBLAS_NUM_THREADS=1 PYTHONDONTWRITEBYTECODE=1 $VPY -B docs/qa/T4/probes/t4fix_overrides.py data/new_shoes/snake_overrides_new.csv
RAC_DATASET=new MPLBACKEND=Agg TQDM_DISABLE=1 PYTHONDONTWRITEBYTECODE=1 $VPY -B -m contour_algorithm.main --qa --jobs 14
```
Run 2 (21 overrides) and run 3 (23, with 376 and 427 after the look); the record comparisons are a short numpy snippet against the saved previous contour, the pass line is `qa_snake.metrics_table` on run 2:
```
records changed vs run 1: [12, 46, 69, 120, 140, 165, 173, 185, 222, 235, 267, 286, 456, 506]
new: 631 shoes, 31 flagged, 600 pass every band (95.09%)
[... run 3 ...]
erase list: 48 rectangles on 11 shoes, 4143 contact pixels erased
step0 create: 1.7 s
step0 contour: 27.6 s
numpy OpenBLAS threads: 1, snake jobs: 14
numpy OpenBLAS kernel: Haswell
Active contour processing complete - 631 shoes, 631 contour records (shoes without a record: [])
step0 snake: 74.7 s
step0 distance: 0.2 s
real	1m46.467s
0af52b05648d67c9b8e712aca6d03d4d73c5ae30bdd32ea81a348a46c13e8372  data/new_shoes/contour_Active_Contour_new.txt
records changed vs run 2: [376, 427]
```
The overrides' before/after (radius 10 against the override, printed by `t4_overrides_figure.py`):
```
   8 before r10 coverage 0.9821 tightness 0.887 rac 0.667 flags coverage;tightness;coverage_fill;rac_coverage;rac_out_max_px;contact_out_max_px
   8 after r24  coverage 0.9802 tightness 0.976 rac 0.667 flags coverage;coverage_fill;rac_coverage;rac_out_max_px;contact_out_max_px
  12 before r10 coverage 0.9916 tightness 0.988 rac 1.000 flags contact_out_max_px
  12 after r24  coverage 1.0000 tightness 1.006 rac 1.000 flags none
[... 18 more pairs omitted (this is the run-2 invocation, 21 overrides; run 3 adds 376 and 427); the numbers of all 23 are in each override's reason in data/new_shoes/snake_overrides_new.csv ...]
 557 before r10 coverage 0.9955 tightness 0.933 rac 0.962 flags rac_coverage;rac_out_max_px;contact_out_max_px
 557 after r24  coverage 0.9979 tightness 1.012 rac 1.000 flags none
```

## 4. Minor: review classes (A-101)

`docs/qa/T4/new/snake_review_new.csv` (56 rows, written from the run-3 facts and the visual notes): the 30 flagged shoes (25 `ok_after_review`, 5 `override`: 8, 113, 120, 140, 506) and 26 classed shoes that pass. Classes in all: `partial_print` 28 (8, 11, 12, 18, 69, 107, 109, 112, 113, 120, 121, 140, 163, 173, 186, 222, 263, 267, 274, 286, 328, 361, 376, 420, 427, 456, 506, 557), `spike` 1 (9), `rim_cut` 3 (170, 205, 294), `mask_cut` 9 (14, 15, 36, 104, 125, 379, 422, 423, 486). 46's rim cut is fixed by its override.

## 5. The OLD reference under the new bands

The OLD reference table (`docs/qa/T4/old/snake_metrics.csv`) rebuilt with the new metrics, by the exact sequence (the restore step is needed: WSL step 0 writes Tier B, 30 records off the committed contour, A-060):
```bash
rsync -a --exclude /.git --exclude '/images*/' --exclude /logs/ --exclude /.claude ./ <scratch>/t4fix/oldref/repo/
cd <scratch>/t4fix/oldref/repo && rm data/contour_Active_Contour.txt
env -u OPENBLAS_NUM_THREADS -u GOTO_NUM_THREADS -u OMP_NUM_THREADS RAC_DATASET=old MPLBACKEND=Agg TQDM_DISABLE=1 PYTHONDONTWRITEBYTECODE=1 $VPY -B -m contour_algorithm.main --qa
sha256sum data/contour_Active_Contour.txt
git -C <repo> show 79247d8:data/contour_Active_Contour.txt > data/contour_Active_Contour.txt
sha256sum data/contour_Active_Contour.txt
RAC_DATASET=old MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 $VPY -B -m contour_algorithm.qa_snake --metrics --jobs 14
```
```
numpy OpenBLAS threads: 16, snake jobs: 1
numpy OpenBLAS kernel: Haswell
Active contour processing complete - 387 shoes, 386 contour records (shoes without a record: [127])
step0 snake: 1216.0 s
exit 0
e18d50df5da9599440c99f9fbb6f23ce98bdc695479a4078c06feb96b9b1b7c4  data/contour_Active_Contour.txt
ca8a07f2a46614a14383a8017b688663caba8350c3ea41c51792d8ebd0ec7e56  data/contour_Active_Contour.txt
old: 386 shoes, 34 flagged, 352 pass every band (91.19%)
wrote <scratch>/t4fix/oldref/repo/docs/qa/T4/old/snake_metrics.csv
```
(Step 0 ran beside the OLD gate, hence 1,216 s for the snakes; the step-0 contour is Tier B, `e18d50df...`; the restored one is Tier A, `ca8a07f2...`.) Against the committed T4 table (a short pandas comparison of the two files):
```
columns added: ['rac_out_max_px', 'contact_out_max_px', 'review_class']
every T4 column except qa_flags identical: True
OLD under the new bands: flagged 34 pass 352
OLD under the T4 bands: 365 pass (T4 table: 365 )
OLD flags: {'rac_coverage': 4, 'outside_mask_frac': 4, 'rac_out_max_px': 3, 'tightness': 4, 'contact_out_max_px': 23, 'coverage': 9, 'turning': 4, 'coverage_fill': 4, 'self_intersections': 1, 'max_turn_deg': 4}
OLD with the literal tightness 0.95 too: 336 (87.05%)
```
So the accepted OLD contours pass 91.19% under the bands that the corrected NEW contours pass at 95.25%; the contact trigger flags 23 of 386 OLD shoes (NEW after the fixes: 19 of 631). The band percentiles of A-093 are unchanged (`test_qa_snake.Flags.test_bands_come_from_the_old_reference`).

## 6. The corrected NEW contours

### 6.1 Pass rates and distribution
```bash
$VPY -B docs/qa/T4/probes/t4fix_summary.py <scratch>/t4fix/trigger_new.csv
```
```
final: 631 shoes, flagged 30, pass 601 (95.25%)
literal tightness 0.95 band too: pass 588 (93.19%)
T4 bands only (no A-099 triggers): pass 618 (97.94%)
flags: {'coverage': 2, 'coverage_fill': 1, 'rac_coverage': 8, 'rac_out_max_px': 7, 'contact_out_max_px': 19, 'outside_mask_frac': 2, 'tightness': 2}
resolution: {'override': 5, 'ok_after_review': 25} ; classes (all listed): {'partial_print': 28, 'spike': 1, 'mask_cut': 9, 'rim_cut': 3}
coverage<0.99: [8, 170] | tightness<0.95: 18 | <0.9047: [375, 405]
coverage            min 0.9802 p1 0.9926 p5 0.9970 median 1.0000 p95 1.0000 p99 1.0000 max 1.0000
coverage_fill       min 0.9841 p1 0.9964 p5 0.9987 median 1.0000 p95 1.0000 p99 1.0000 max 1.0000
coverage_r          min 0.9840 p1 0.9968 p5 0.9994 median 1.0000 p95 1.0000 p99 1.0000 max 1.0000
rac_coverage        min 0.6667 p1 0.9631 p5 1.0000 median 1.0000 p95 1.0000 p99 1.0000 max 1.0000
tightness           min 0.8574 p1 0.9276 p5 0.9593 median 1.0126 p95 1.0757 p99 1.0891 max 1.1018
turning             min 2.1676 p1 2.3189 p5 2.5203 median 3.1939 p95 3.9764 p99 4.2464 max 4.4520
max_turn_deg        min 8.5300 p1 11.3770 p5 13.2800 median 17.5600 p95 23.7200 p99 26.7000 max 29.5600
n_contour_px        min 611.0000 p1 665.3000 p5 682.5000 median 709.0000 p95 744.0000 p99 755.7000 max 766.0000
outside_mask_frac   min 0.0000 p1 0.0000 p5 0.0000 median 0.0057 p95 0.1578 p99 0.2790 max 0.3665
self_intersections  min 0.0000 p1 0.0000 p5 0.0000 median 0.0000 p95 0.0000 p99 0.0000 max 0.0000
touches_border      min 0.0000 p1 0.0000 p5 0.0000 median 0.0000 p95 0.0000 p99 0.0000 max 0.0000
rac_out_max_px      min 0.0000 p1 0.0000 p5 0.0000 median 0.0000 p95 0.0000 p99 2.7708 max 28.2840
contact_out_max_px  min 0.0000 p1 0.0000 p5 0.0000 median 0.0000 p95 5.1925 p99 11.7942 max 20.1250
erase list: 48 rectangles on 11 shoes; 4143 px erased, 2010 inside the mask
overrides: 23 {24: 22, 16: 1}
T4 commit contour under the new bands: flagged 41, pass 590 (93.50%)
```
**Headline, with its caveats:** 601 of 631 NEW shoes (95.25%) pass every band, and the other 30 are reviewed (none excluded). The 97% target of the task is not met by the pass rate under the stricter bands of A-099: the triggers flag isolated specks and off-print RACs that review resolves, and the T4 bands alone pass 618 (97.94%). With the task's literal tightness 0.95 the rate is 588 (93.19%); T4's 98.10% was 602 (95.40%) under the literal band (A-106). The outline quality, not the rate, is what the review checked.

### 6.2 The 2023 cross-check
```bash
$VPY -B docs/qa/T4/probes/t4_crosscheck_racs.py
```
```
in_2023  False   True    All
in_new                      
False       15      0     15
True        38  19960  19998
All         53  19960  20013
RACs inside both: 19960
d_new vs d_2023: corr 0.9802 | diff median 0.339 mean 0.315 p5 -3.537 p95 4.000 | |diff| <= 1: 0.3780, <= 2: 0.6475
h_new vs h_2023: corr 0.9813 | diff median 0.000 mean 0.438 p5 -3.000 p95 4.000 | |diff| <= 1: 0.4832, <= 2: 0.7313
per shoe median |dd|: median 1.63 p90 2.7 p99 3.71 max 7.49 shoe 506
inside_new 19998 inside_2023 19960 shoes inside_new < inside_2023: []
```
19,998 of 20,013 RACs inside the corrected contours (T4: 19,993; 2023: 19,960).

### 6.3 The initial ellipse (A-105)
```bash
$VPY -B docs/qa/T4/probes/t4fix_ellipse_margin.py new .
$VPY -B docs/qa/T4/probes/t4fix_ellipse_margin.py old <scratch>/t4/old_qa/repo
$VPY -B docs/qa/T4/probes/t4fix_ellipse_margin.py new . 180 128 162 95
$VPY -B docs/qa/T4/probes/t4fix_ellipse_margin.py new . 185 128 167 98
```
```
new ellipse (185, 128) / (162, 95): shoes with print outside 43 of 631; margin p1 -4.47 p5 -1.11 median 6.77 px
  most print outside: [(14, 97), (15, 72), (104, 46), (35, 44), (125, 38), (170, 35), (63, 18), (103, 17)]
old ellipse (200, 155) / (162, 90): shoes with print outside 13 of 386; margin p1 -1.75 p5 0.81 median 6.74 px
  most print outside: [(143, 51), (176, 9), (340, 8), (329, 8), (359, 7), (341, 7), (266, 6), (69, 5)]
new ellipse (180.0, 128.0) / (162.0, 95.0): shoes with print outside 155 of 631; margin p1 -6.38 p5 -3.24 median 7.86 px
  most print outside: [(170, 129), (63, 115), (132, 76), (37, 76), (35, 75), (169, 65), (142, 63), (56, 59)]
new ellipse (185.0, 128.0) / (167.0, 98.0): shoes with print outside 3 of 631; margin p1 0.54 p5 3.89 median 11.77 px
  most print outside: [(586, 1), (422, 1), (14, 1), (624, 0), (623, 0), (622, 0), (621, 0), (620, 0)]
```
```bash
OPENBLAS_NUM_THREADS=1 T4=<scratch>/t4fix PYTHONDONTWRITEBYTECODE=1 $VPY -B docs/qa/T4/probes/t4_variant.py ell_167_98 '{"radii_rc": [167, 98]}' 14
OPENBLAS_NUM_THREADS=1 T4=<scratch>/t4fix PYTHONDONTWRITEBYTECODE=1 $VPY -B docs/qa/T4/probes/t4_variant.py official_check '{}' 14
```
(run-2 images and overrides)
```
ell_167_98 "{\"radii_rc\": [167, 98]}" snakes 69.2 s
pass 94.5% flagged 35 coverage<0.99 2 tight<0.95 17 self-int 0
official_check "{}" snakes 71.7 s
pass 95.1% flagged 31 coverage<0.99 2 tight<0.95 19 self-int 0
```
The enlarged ellipse does not improve the snakes; the 2023 values stay.

## 7. Visual review

Looked at, on the corrected outputs: all 13 final-snake, 13 cleaned, 13 prototype and 13 ellipse/first-snake sheets of run 2 (the final and ellipse sheets 8 and 9 again after run 3, which changed only 376 and 427), `prototype_mask_new.png`, the 30 flagged figures of run 3 (three per view), `overrides_before_after_new.png` (run 2 with 21 pairs, run 3 with all 23), the side-by-side fallback zooms (`focus_a`-`focus_d`, 31 shoes x 3 radii), 4x zooms of 580, 584, 586, 587, 581, 583 after the erase fix and of the mask-edge cuts (14, 15, 36, 104, 125, 379, 486, 581). Several first opens came back without the picture (the viewer's request limit); notes written before a picture had displayed were deleted, and those images were reopened. Descriptions: `docs/qa/snake-qa.md` (NEW section) and `<scratch>/t4fix/visual_notes.md`.

## 8. Tests

New and changed tests (all in the fast suite):
- `tests/python/test_sentinel_profile.py`: `test_t4_values_reach_outputs` (the fixture's closing radius 2: set to 0 alone, the snakes of shoes 1, 2, 4, 5, 6 change; the override of shoe 3 removed alone, only shoe 3 changes; a second step 0 without the erase list gives other matrices, snake and record for shoe 6 only); `test_values_reach_outputs` and `test_snake_parameters_reach_every_call` account for the erase rectangle and for shoe 3's own ellipse. The fixture (`make_sentinel.py`, regenerated; `Fixture.test_committed_fixture_is_the_generator_output` passes) gives its NEW entry `snake.first_closing_radius: 2`, `inputs.snake_overrides` (shoe 3: radius 5, ellipse (31, 21) / (24, 14)) and `inputs.sticker_masks` (shoe 6, rows 50-56, columns 10-31, 53 contact px, no RAC).
- `tests/python/test_qa_snake.py` (26 -> 31 tests): `Metrics.test_absolute_triggers` (a RAC 2 px outside passes, 3 px flags while the share passes; a speck 9 px outside flags while coverage passes; no RAC is no flag), new band cases, `Review.test_valid_and_invalid`, `CommandLine.test_old_has_no_sheets_folder`, `CommandLine.test_jobs_need_fork` (fork mocked away: `qa_snake.refusal`, `run_snakes` and `main --jobs 2` refuse), `Blas.test_corename`, `Blas.test_jobs_identical` on the sentinel fixture (self-contained), `Stickers.test_validation` with the boundaries from the profile, `Files.test_complete` with the task copy in the sheets folder, `Files.test_all_flags_resolved` with the classes, `Profiles.test_new_values` with the 23 overrides.
- `tests/python/test_contour_new.py`: no named exception left (18 and 113 are in the review file, 120 and 286 enclose their RACs); `test_record_is_its_shoe` says what it checks.
- `tests/r/test_profile_sentinels.R` and `tests/r/test_sticker_masks.R`: the expectations apply the fixture's erase rectangle; the boundary cases come from the profile.

```bash
MPLBACKEND=Agg TQDM_DISABLE=1 PYTHONDONTWRITEBYTECODE=1 $VPY -B -m unittest tests.python.test_sentinel_profile
MPLBACKEND=Agg TQDM_DISABLE=1 PYTHONDONTWRITEBYTECODE=1 $VPY -B -m unittest tests.python.test_qa_snake
MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 $VPY -B -m unittest tests.python.test_contour_new
Rscript tests/r/test_profile_sentinels.R
Rscript tests/r/test_sticker_masks.R
```
```
Ran 8 tests in 2.547s
OK
Ran 31 tests in 7.339s
OK
Ran 3 tests in 3.134s
OK
PASS skip list: shoe 4 (no RACs) and 5 (excluded) have no code; codes 1-4
PASS stamp threshold 2, sweep bound 40, R flip [3]: all_cont = the sweep of sum >= 2 (922 px, 16 removed)
[... 9 more PASS lines ...]
ALL PASS test_profile_sentinels
PASS rac_apply_sticker_masks erases exactly the listed rectangles
PASS rac_read_sticker_masks: OLD none, NEW read, malformed lists stop
PASS NEW erase list: R erases 4143 contact pixels in 11 shoes, per rectangle as Python
PASS step 1 applies the erase list before the stamp mask and the RACs: shoe 1 loses 375 pixels; every count as expected; no control of shoe 1 in the rectangle
```

**The engineer's mutation experiment, repeated.** Three scratch copies (`<scratch>/t4fix/mutants/`), each with one T4 step-0 behaviour removed exactly as the reviewer did: the Python erase list (`read_sticker_masks(profile)[:0]`), the per-shoe overrides in `active_contour_shoe` (`sp = profile.snake`, `init_snake(profile)`), the closing before the first snake (`gaussian(original_img, ...)`). The same five test modules the reviewer ran (45 tests passed on every mutant before):
```bash
cd <scratch>/t4fix/mutants/<k> && MPLBACKEND=Agg TQDM_DISABLE=1 PYTHONDONTWRITEBYTECODE=1 $VPY -B -m unittest tests.python.test_sentinel_profile tests.python.test_qa_snake tests.python.test_contour_new tests.python.test_snake_geometry tests.python.test_io_shoes
```
```
== mutant erase
FAIL: test_t4_values_reach_outputs (tests.python.test_sentinel_profile.Sentinel.test_t4_values_reach_outputs)
FAIL: test_values_reach_outputs (tests.python.test_sentinel_profile.Sentinel.test_values_reach_outputs)
Ran 51 tests in 13.809s
FAILED (failures=2)
== mutant override
FAIL: test_snake_parameters_reach_every_call (tests.python.test_sentinel_profile.Sentinel.test_snake_parameters_reach_every_call) (call=6)
FAIL: test_snake_parameters_reach_every_call (tests.python.test_sentinel_profile.Sentinel.test_snake_parameters_reach_every_call) (call=7)
FAIL: test_t4_values_reach_outputs (tests.python.test_sentinel_profile.Sentinel.test_t4_values_reach_outputs)
Ran 51 tests in 14.209s
FAILED (failures=3)
== mutant closing
FAIL: test_t4_values_reach_outputs (tests.python.test_sentinel_profile.Sentinel.test_t4_values_reach_outputs)
Ran 51 tests in 14.175s
FAILED (failures=1)
```
Each mutant is now caught by the fast suite; a stale committed contour is caught by `tests/rebuild_new.sh` (section 9).

The fast suite on the final tree (the code of `9d51fff`; the docs uncommitted):
```bash
RAC_VENV_PY=$VPY bash tests/run_all.sh
```
```
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS        77s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        21s  Rscript tests/r/test_compare_glmm_fits.R
PASS         3s  Rscript tests/r/test_compare_models.R
PASS         7s  Rscript tests/r/test_distances_vectorized.R
PASS         2s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        32s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         1s  Rscript tests/r/test_profile.R
PASS        49s  Rscript tests/r/test_profile_sentinels.R
PASS         8s  Rscript tests/r/test_run_manifest.R
PASS         2s  Rscript tests/r/test_step5_variant.R
PASS         8s  Rscript tests/r/test_sticker_masks.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         0s  flake8 (all Python files)
PASS         5s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS
Ran 178 tests in 74.504s
OK (skipped=3)
real	3m48.291s
```
178 Python tests (172 at T4; 3 skipped: the live checks that need a run folder; `Blas.test_jobs_identical` no longer skips), 14 R scripts. An earlier run of the suite on the tree before the OpenBLAS precondition of `test_snake_old_regression` also passed (178 tests, 3 skipped, 14 R scripts; `<scratch>/t4fix/runall_1.log`).

## 9. Reproducibility: OpenBLAS and the rebuild gate (A-103)

The kernel getter and the thread count (the step-0 log now prints both):
```bash
$VPY -B -c "from contour_algorithm import active_contour_snake as a; print(a.numpy_blas_threads(), a.numpy_blas_corename())"
OPENBLAS_NUM_THREADS=1 $VPY -B -c "from contour_algorithm import active_contour_snake as a; print(a.numpy_blas_threads(), a.numpy_blas_corename())"
```
```
16 Haswell
1 Haswell
```
The environment record (appended section, the only change to `tests/baseline/local/environment.txt`; and the new `tests/baseline/local/openblas_tier_b.txt`: `threads 16`, `kernel Haswell`):
```bash
bash tests/lib/write_environment.sh --openblas >> tests/baseline/local/environment.txt
```
```
## numpy OpenBLAS, recorded 2026-11-06T17:38:59+02:00 (T4 review fixes)
WSL thesis venv: /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python
numpy OpenBLAS (threads with the library default, kernel):
threads 16 kernel Haswell
```
The OLD gate refuses another thread count before step 0 (OpenBLAS follows the CPU affinity: 4 CPUs, 4 threads):
```bash
taskset -c 0-3 $VPY -B -c "from contour_algorithm.active_contour_snake import numpy_blas_threads; print(numpy_blas_threads())"
RAC_SCRATCH=<scratch>/t4fix/gates RAC_VENV_PY=$VPY taskset -c 0-3 bash tests/regress_old.sh --steps 0
```
```
4
regress_old.sh: numpy's OpenBLAS would run 4 threads; both OLD step-0 baselines were written with 16 (/home/mehes/projects/rac-spatial-model/tests/baseline/local/openblas_tier_b.txt), and the snake depends on the count (A-092): the OLD contour cannot be compared on this machine

real	0m3.228s
exit 2
```
With an inherited `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=3` (which used to give a contour that is neither Tier A nor Tier B, 32 records off) the gate removes the variables for OLD: section 11.

The NEW rebuild gate on the corrected tree:
```bash
RAC_SCRATCH=<scratch>/t4fix/gates RAC_VENV_PY=$VPY bash tests/rebuild_new.sh --keep
```
```
== rebuild_new.sh: <scratch>/t4fix/gates/rebuild_new_XKcXBL
result  check                                          detail
PASS    pipeline run                                   step 0 and qa_snake --metrics exit 0
INFO    OpenBLAS                                       numpy OpenBLAS threads: 1; numpy OpenBLAS kernel: Haswell
PASS    data/new_shoes/contour_Active_Contour_new.txt  byte-identical, sha256 0af52b05648d...
PASS    docs/qa/T4/new/snake_metrics_new.csv           byte-identical, sha256 fb4633a3a884...
PASS    docs/qa/T4/new/sticker_erased_new.csv          byte-identical, sha256 3b2a22241c9f...
PASS    docs/qa/sheets_new/snake_qa_new.csv            byte-identical, sha256 fb4633a3a884...
timings (s):
step        seconds        exit
step0       113.860528495  0
qa_metrics  17.046026787   0
ALL PASS
```
Rerun at `f05e00d` (the code and data of the final state; the run folder deleted after the pass):
```bash
RAC_SCRATCH=<scratch>/t4fix/gates RAC_VENV_PY=$VPY bash tests/rebuild_new.sh
```
```
PASS    pipeline run                                   step 0 and qa_snake --metrics exit 0
INFO    OpenBLAS                                       numpy OpenBLAS threads: 1; numpy OpenBLAS kernel: Haswell
PASS    data/new_shoes/contour_Active_Contour_new.txt  byte-identical, sha256 0af52b05648d...
PASS    docs/qa/T4/new/snake_metrics_new.csv           byte-identical, sha256 fb4633a3a884...
PASS    docs/qa/T4/new/sticker_erased_new.csv          byte-identical, sha256 3b2a22241c9f...
PASS    docs/qa/sheets_new/snake_qa_new.csv            byte-identical, sha256 fb4633a3a884...
timings (s):
step        seconds        exit
step0       107.656081588  0
qa_metrics  14.807823050   0
ALL PASS
```
`OPENBLAS_CORETYPE` is not pinned (A-103): a forced kernel would not remove the platform effect (A-098) and would crash on a CPU without its instructions.

## 10. Corrections in the T4 documents

- `docs/tests/T4-snake-results.md`: "16 R scripts" corrected to 14 (sections 1 and 10, and the LOG); the RAC-coverage band 0.9696 (was 0.9695); the literal-band pass rate (602, 95.40%) next to the headline; the suite ran at `8c5f6b9` for the results doc and at `1a69e26` in the engineer's and the reproducibility reviewer's runs; the section 6 variant table records the exploration state (at HEAD `t4_variant.py '{}'` runs closing 10 with the committed overrides; the legacy row needs `{"first_closing_radius": 0}` and a profile without overrides); the OLD reference's exact commands with the restore step (section 3 there, and section 5 here).
- `docs/decisions.md`: errata A-106 (A-093's 24 -> 20 shoes; A-094 section 5 -> 6; A-098 section 9 -> 8; A-095's "none survives"); A-092's portability claim narrowed by A-103.
- `docs/qa/snake-qa.md`: the NEW section rewritten (the "fine" sheet notes, the ellipse claim and the sticker claim of T4 were wrong in parts).
- Commit `8c5f6b9` was labelled `test:` but also added `qa_snake --crosscheck`: noted; feature code stays out of `test:` commits from here on.

## 11. OLD regression

T4's review fixes change step 0 only in the NEW profile path, the log lines, the fork guard and the gates; OLD has no erase list, no overrides, closing radius 0 and the library thread default. R is unchanged (only the R tests changed). Gates run on the work tree of these fixes, whose code equals `8fefa20` for the first two runs below and `9d51fff` for the inherited-variable rerun (`9d51fff` changes only the gate's live-check environment and the tests):
```bash
RAC_SCRATCH=<scratch>/t4fix/gates RAC_VENV_PY=$VPY bash tests/regress_old.sh --steps 0 --keep
RAC_SCRATCH=<scratch>/t4fix/gates RAC_VENV_PY=$VPY bash tests/regress_old.sh --steps 1 --keep
```
```
== regress_old.sh --steps 0: <scratch>/t4fix/gates/regress_old_lqqlQS
result  check                                 detail
PASS    pipeline run                          every step exit 0, every output regenerated
PASS    step 0 OpenBLAS threads = baseline    16 threads (kernel Haswell, baseline Haswell)
PASS    step 0 contour = Tier B (CRLF)        data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B         1556 npy/png files, all equal
PASS    live check test_snake_old_regression  logs/live_snake.txt
timings (s):
step   seconds         exit
step0  1244.842053707  0
ALL PASS

== regress_old.sh --steps 1: <scratch>/t4fix/gates/regress_old_Huqtbo
result  check                                  detail
PASS    pipeline run                           every step exit 0, every output regenerated
PASS    step 1 all_cont.csv = Tier A           data/all_cont.csv sha256 d582cf502184...
PASS    step 1 dataCC.csv = Tier A             processed_data/dataCC.csv sha256 cc4a476976ae...
PASS    step 1 shoe_pixel_counts.csv = Tier A  processed_data/shoe_pixel_counts.csv sha256 24bbd19cff59...
PASS    step 1 shoe_codes.csv = old_added_t2   processed_data/shoe_codes.csv sha256 3d6c09fe66e1...
timings (s):
step   seconds        exit
step1  162.870654855  0
ALL PASS
```
(Step 0 took 1,245 s because the OLD QA reference ran beside it; alone it takes about 400 s.) The committed-file checksums pass in the fast suite (Tier A, `old_baseline`, `old_added_t2`); no committed OLD file changed:
```bash
git diff 72f857e --stat -- ':(glob)data/*.txt' ':(glob)data/*.csv' ':(glob)data/*.png' ':(glob)processed_data/*' ':(glob)saved_models/*' ':(glob)model_images/*'; echo "[end of list]"
sha256sum -c tests/baseline/committed_79247d8.sha256 --quiet && echo "Tier A checksums OK"
sha256sum -c tests/baseline/old_baseline.sha256 --quiet && echo "old_baseline OK"
sha256sum -c tests/baseline/old_added_t2.sha256 --quiet && echo "old_added_t2 OK"
```
```
[end of list]
Tier A checksums OK
old_baseline OK
old_added_t2 OK
```

**With an inherited `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=3`** (the reproducibility reviewer's failure case). The first run found a gap in my fix: the pipeline ran with the variables removed (contour and intermediates = Tier B), but the gate's live check, which reruns two platform-sensitive snakes, still inherited them:
```bash
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=3 RAC_SCRATCH=<scratch>/t4fix/gates RAC_VENV_PY=$VPY bash tests/regress_old.sh --steps 0 --keep
```
```
PASS    pipeline run                          every step exit 0, every output regenerated
PASS    step 0 OpenBLAS threads = baseline    16 threads (kernel Haswell, baseline Haswell)
PASS    step 0 contour = Tier B (CRLF)        data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B         1556 npy/png files, all equal
FAIL    live check test_snake_old_regression  logs/live_snake.txt
[... logs/live_snake.txt ...]
FAIL: test_platform_sensitive_records (tests.python.test_snake_old_regression.SnakeOld.test_platform_sensitive_records) (shoe=176)
AssertionError: 1403 != 0
FAIL: test_platform_sensitive_records (tests.python.test_snake_old_regression.SnakeOld.test_platform_sensitive_records) (shoe=354)
AssertionError: 14 != 0
```
Fixed: the live check runs with the same environment as the pipeline (the three variables removed); the fast suite's Python tests run without them too; and `test_snake_old_regression` checks the thread count before any rerun and fails with the reason instead of a pixel count:
```bash
OPENBLAS_NUM_THREADS=1 MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 $VPY -B -m unittest tests.python.test_snake_old_regression
MPLBACKEND=Agg PYTHONDONTWRITEBYTECODE=1 $VPY -B -m unittest tests.python.test_snake_old_regression
```
```
FAIL: test_platform_sensitive_records (tests.python.test_snake_old_regression.SnakeOld.test_platform_sensitive_records) (shoe=176)
AssertionError: numpy OpenBLAS runs 1 threads; the OLD baselines were written with 16 (tests/baseline/local/openblas_tier_b.txt) and the snake depends on the count (A-092): run without OPENBLAS_NUM_THREADS, OMP_NUM_THREADS and GOTO_NUM_THREADS on a machine where the library default is 16
[... the same message for shoe 354 and for the four other reruns ...]
Ran 6 tests in 11.744s
OK (skipped=2)
```
(the second line is the run without the variables). The rerun of the gate with the inherited variables:

```bash
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=3 RAC_SCRATCH=<scratch>/t4fix/gates RAC_VENV_PY=$VPY bash tests/regress_old.sh --steps 0 --keep
```
```
== regress_old.sh --steps 0: <scratch>/t4fix/gates/regress_old_HKsg7i
result  check                                 detail
PASS    pipeline run                          every step exit 0, every output regenerated
PASS    step 0 OpenBLAS threads = baseline    16 threads (kernel Haswell, baseline Haswell)
PASS    step 0 contour = Tier B (CRLF)        data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B         1556 npy/png files, all equal
PASS    live check test_snake_old_regression  logs/live_snake.txt
timings (s):
step   seconds        exit
step0  348.297502362  0
ALL PASS
```
So the OLD regression holds: OLD step 0 reproduces Tier B (contour `e18d50df...`, all 1,556 intermediates) with and without inherited thread variables, OLD step 1 reproduces the Tier A CSVs byte for byte, and no committed OLD file changed. Steps 2-6 read no file that these fixes changed (R code unchanged; the R tests pass). The venv-wind (Tier A) check of OLD step 0 was not rerun: the OLD code path is unchanged apart from log lines and the fork guard, and the T4 reproducibility review ran it at `1a69e26` (committed contour byte for byte).

## 12. Timings

| What | Time |
|---|---|
| NEW step 0 (create 1.7-1.9 s, contour 27-28 s, snakes 75-79 s with 14 jobs), three runs | 1 min 46 s - 1 min 52 s |
| NEW QA with metrics, 52 sheets, 631 figures, flagged figures, cross-check | 3 min 22 s - 3 min 26 s (metrics alone 15-19 s) |
| Mask threshold study (5 thresholds) | 18 s |
| One snake variant on 631 shoes (14 jobs) | 69-72 s snakes |
| NEW rebuild gate `tests/rebuild_new.sh` | 2 min 11 s (step 0 114 s, metrics 17 s) |
| OLD `regress_old.sh --steps 0` | 1,245 s beside the OLD reference run; 348 s alone (inherited variables); 633 s for the first inherited-variable run (live check failed) |
| OLD QA reference: OLD step 0 with `--qa` (serial) beside the gate; `qa_snake --metrics` | snakes 1,216 s; 15 s |
| OLD `regress_old.sh --steps 1` | 163 s |
| `tests/run_all.sh` | 3 min 48 s (final); the first run, beside the OLD gates, reported 373 s of check times (not timed as a whole) |
| Python sentinel test / test_qa_snake / R sentinel test / R erase-list test | 2.5 s / 7.3 s / 49 s / 8 s |

The fallback batches and the override writer were not timed.
