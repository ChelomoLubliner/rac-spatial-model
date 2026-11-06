# T4 second review fixes: results (2026-11-06)

Fixes for the second round of T4-snake reviews (`docs/progress/LOG.md`, entries of 2026-11-06 19:15 (engineer), 19:25 (reproducibility) and 19:30 (vision)): one major finding (vision) and the minor notes of the three reviews. Every block below is a real command and its real output (`<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`; `VPY` = `<scratch>/t1/venv_copy/bin/python`, the thesis venv copied to the Linux filesystem in T1, the same packages; long outputs trimmed with an explicit marker; `RAC_DATASET=new PYTHONDONTWRITEBYTECODE=1` is set for every NEW probe and left out below). Commits `437ed27` (code), `dd26bb8` (NEW data and QA outputs, probes), `586c18a` (tests and gates), `873b49e` (two note corrections, the checks probe), then the docs commit. Decisions A-107 to A-109 (`docs/decisions.md`); plan revision 11 with F68 corrected and F69-F71; the NEW section of `docs/qa/snake-qa.md` corrected.

## 0. Summary

| Finding | Fix | Evidence | Section |
|---|---|---|---|
| **Major** (vision): the ellipse failure misdiagnosed ("the top"; "the contours still reach the toe tip"); 170's cut is fixable | A-105, F68 and `snake-qa.md` corrected (toe 29 shoes, heel 15; 159 of 516 px left outside); 170 starts from its own ellipse (187, 127) / (167, 98) (A-107); the other 27 shoes tried with three ellipses, none taken | 170: coverage 0.9875 -> 1.0, no band broken; its forefoot and right side within 1 px at the median | 1, 2 |
| Minor (vision): rim cuts and peaks not classed | 28, 37, 148, 169, 591 `rim_cut`; 518, 527 `spike`; each note says which fallback would help | radius 16/24 and two ellipses run on each | 3 |
| Minor (vision): 186 keeps 3 px of its frame line | a 49th rectangle (rows 250-252, cols 183-186) erases exactly the line piece; mask unchanged | only 186's matrix changes (6 px); its contour moves <= 2 px | 4 |
| Minor (vision): the 328 note | reworded: 6 rows above 327's lowest print, 10 above its contour; one speck inside 327's heel | the alignment and the speck check | 3 |
| Minor (engineer): the fork test could run step 0 in the work tree | `run` and `load_profile` mocked to fail; the reason checked | the fork mutant fails cleanly, writes nothing | 6 |
| Minor (engineer): the prototype snake ran unchecked | `check_blas_threads` at the start of `main.run()`, `prototype_mask_from`, `active_contour_shoe` | `test_every_snake_path_is_checked`; 3 mutants caught | 5, 6 |
| Minor (engineer): partial automated coverage of the QA files; stale flagged figures | `rebuild_new.sh --full`; `--flagged` prunes; `Files.test_flagged_figures` | `--full`: 52 sheets, 29 flagged figures, 6 more files = HEAD | 5, 6 |
| Minor (engineer): nits | A-104 cited; "needs"; the `--crosscheck` refusal in `refusal()`; 'override' iff an override row; the corename getter under venv-wind (this pass's Tier A run logs `numpy OpenBLAS kernel: Haswell`, 16 threads, as the reproducibility reviewer's did) | tests; section 9 | 6, 9 |
| Minor (reproducibility): `OPENBLAS_CORETYPE` neither removed nor checked | the NEW profile pins the kernel (`python.blas_kernel` "Haswell"), every snake path checks it, NEW main refuses another; both gates remove the variable and check the kernel (A-108) | refusals shown for NEW main, the OLD gate and the OLD snake test | 5 |
| Minor (reproducibility): the NEW gate compared with the work tree | compares with the HEAD blobs; a work-tree copy that differs from HEAD fails | the gate's new rows | 5 |
| Minor (reproducibility): the override writer not idempotent | self-contained probe; 13 wrong tags corrected (A-109) | a rerun writes the same bytes | 7 |
| Minor (reproducibility): "every T4 column identical" | corrected here and in the LOG: every T4 column except `qa_flags`, which gains the A-099 trigger names on 24 rows | | 10 |

Output sha256: NEW contour `f7703bcdbdb0f823991ca8ea1942e04cda0cd8d867321a498602bd4332ced10d` (T4 review fixes: `0af52b05...`). OLD outputs unchanged (section 9).

## 1. The ellipse failure, measured (A-107)

Where the cleaned print crosses each shoe's initial ellipse (the polygon of the 400 points the snakes start from) on the run of the T4 review fixes (the committed `0af52b05...` contour and its saved snakes):
```bash
$VPY -B docs/qa/T4/probes/t4fix2_ellipse_cross.py
```
```
shoe out toe side heel lost lost_toe lost_heel rmin rmax
170 35 0 0 35 32 0 32 321 335
125 38 38 0 0 14 14 0 19 23
104 46 46 0 0 13 13 0 21 28
9 13 13 0 0 13 13 0 20 23
35 44 36 0 8 10 2 8 20 336
423 8 0 0 8 8 0 8 339 341
103 17 17 0 0 6 6 0 20 25
518 11 11 0 0 6 6 0 23 23
169 7 0 0 7 6 0 6 324 329
586 5 0 0 5 5 0 5 329 333
[... 33 more rows trimmed; full output <scratch>/t4fix2/ellipse_cross_committed.txt ...]
new: 43 shoes with cleaned print outside the initial ellipse polygon (43 by the analytic ellipse); 516 px, of them 159 outside the record fill
  at the toe: 29 shoes, 413 px, 82 outside the fill
  at the heel: 15 shoes, 103 px, 77 outside the fill: [35, 37, 46, 55, 56, 63, 142, 169, 170, 314, 401, 422, 423, 432, 586]
  at the sides: 0 shoes; at toe and heel: [35]
  shoes with print beyond the ellipse outside the fill: [9, 14, 15, 35, 36, 37, 46, 55, 82, 89, 103, 104, 105, 125, 142, 156, 169, 170, 231, 314, 349, 401, 422, 423, 432, 518, 584, 586]
```
The reviewer's numbers are reproduced exactly (43 shoes; 29 toe, 15 heel, 35 both; 516 px; 159 outside the fill). Rows are 0-based in this table. So A-105's "the print crosses the ellipse's top" and "the final contours still reach the toe tip" were both incomplete: the heel bottom crosses on 15 shoes, and 82 px of toe print stay outside.

**Three other ellipses on the 28 shoes with print lost beyond the ellipse** (E1 = (187, 127) / (167, 98), the reviewer's; E2 = (188, 128) / (165, 97); E3 = (185, 128) / (167, 98), A-105's enlarged ellipse; each shoe keeps its own closing radius; `profile` reruns the committed parameters):
```bash
OPENBLAS_NUM_THREADS=1 TQDM_DISABLE=1 $VPY -B docs/qa/T4/probes/t4fix2_ellipse_trial.py <scratch>/t4fix2/trial1.csv <scratch>/t4fix2/trial1 lost E1=187,127,167,98 E2=188,128,165,97 E3=185,128,167,98
```
```
 shoe     tag  same_as_committed  print_outside_ellipse  lost  recovered  fill_gained  fill_lost  dwidth_median  dwidth_maxabs  coverage  coverage_fill  tightness  contact_out_max_px                                flags
    9 profile               True                     13    13          0            0          0            0.0            0.0  0.997873       0.998272   1.020639            4.000000
    9      E1              False                      2    13         13          391        129            1.0            9.0  0.999468       1.000000   1.027986            0.000000
    9      E2              False                     13    13          0          176        351            0.0            7.0  0.997608       0.997873   1.014658           11.045361                   contact_out_max_px
    9      E3              False                      0    13         13          132        429           -1.0           44.0  0.999203       1.000000   1.010530            0.000000
   37 profile               True                      4     4          0            0          0            0.0            0.0  0.995490       0.997933   0.920484            3.605551
   37      E1              False                      0     4          4         1281          0            3.0           53.0  0.999875       0.999875   0.960050            3.162278
   37      E2              False                      0     4          4          954         38            2.0           53.0  0.999875       0.999875   0.947790            2.236068
   37      E3              False                      0     4          4         1058          7            3.0           56.0  0.999749       0.999875   0.952591            2.828427
  104 profile               True                     46    13          0            0          0            0.0            0.0  0.995420       0.999071   0.971045            2.000000
  104      E1              False                      3    13          2           95        408           -1.0           40.0  0.994889       0.998872   0.961919            2.828427
  104      E2              False                     43    13          0            3       1121           -3.0           39.0  0.992500       0.997345   0.937976            2.828427
  104      E3              False                      0    13         13          615        312            0.0           32.0  0.999004       0.999934   0.980882            1.000000                    outside_mask_frac
  125 profile               True                     38    14          0            0          0            0.0            0.0  0.994179       0.998012   0.990970            2.236068
  125      E1              False                     13    14         14          609         95            2.0           11.0  0.996876       1.000000   1.008053            0.000000
  125      E2              False                     38    14          3          487        289            0.0           53.0  0.994889       0.998296   0.998551            2.000000
  125      E3              False                      0    14          2           82        431           -1.0           44.0  0.993895       0.997444   0.981166            2.236068
  169 profile               True                      7     6          0            0          0            0.0            0.0  0.993960       0.998224   0.957699            2.828427
  169      E1              False                      0     6          6          360        458           -1.0           43.0  1.000000       1.000000   0.948090            0.000000
  169      E2              False                      0     6          6          645        465            0.0           44.0  1.000000       1.000000   0.960723            0.000000
  169      E3              False                      0     6          6          927         81            2.0           45.0  1.000000       1.000000   0.982394            0.000000
  170 profile               True                     35    32          0            0          0            0.0            0.0  0.987521       0.994395   0.961078            3.000000                             coverage
  170      E1              False                      0    32         32          893         62            1.0           64.0  1.000000       1.000000   0.982036            0.000000
  170      E2              False                      0    32         32         1263         20            4.0           60.0  1.000000       1.000000   0.995444            0.000000
  170      E3              False                      0    32         32         1228         55            2.0           66.0  1.000000       1.000000   0.994175            0.000000
[... the rows of the other 22 shoes trimmed; full table <scratch>/t4fix2/trial1.csv; every `profile` row has same_as_committed True; no ellipse recovers a pixel of 15, 105, 231, 314, 401, 422, 423, 432, 584 or 586 (specks, debris, 423's corner piece) ...]
wrote <scratch>/t4fix2/trial1.csv 112 rows
```
The profile ellipse rewrites all 28 committed records (a check of the probe). The snake answers the ellipse globally: the fill changes by about 100 to 1,400 px and the median row width by up to 4 px, not only where the print was cut. `dwidth_maxabs` is large where a recovered part adds or removes whole row ends (the rim rows of 170).

**Looked at** (Read tool; `t4fix2_ellipse_figure.py`: committed record blue, the tag's record orange, both magenta, contact outside the tag's fill yellow, the tag's ellipse red):
- `fig_170.png` (whole shoe, 4 tiles) and `fig_170_heel.png` (4x, rows 230-350): the profile ellipse runs through the lower-left heel pad's rim, and the committed contour follows the ellipse there, leaving the rim (yellow) outside. E1 encloses the rim tightly, 1-2 px outside the pad, with no yellow left. E2 runs 1-3 px looser along both forefoot sides. E3 encloses the rim but bulges 3-4 px into the empty space below-left of the pad.
- `fig_169.png`, `fig_169_heel.png`: 169 (same design) loses a 6-px sliver of the lower-left pad's left edge where the ellipse crosses. E1 encloses it but makes a notch up between the two lower pads; E3 encloses it but runs 1-3 px wider along the whole left side.
- `fig_37.png`: the bottom-right edge of the lower-right pad is cut; all three ellipses enclose it but run 1-2 px outside the committed contour almost all the way round.
- `fig_toes.png` (3x, toes of 125, 104, 9): 125 keeps a 1-2 px sliver of its toe tip (14 px) outside, and E1 encloses it with little change elsewhere. 104's E1 recovers 2 px and notches the top; its E3 runs 2-3 px above the print and adds the outside-mask flag. 9 keeps its spike to the isolated mark with every ellipse.

**170's override, measured against the committed record** (`t4fix2_ellipse_trial.py ... 170 r16=r16 r24=r24 E1=187,127,167,98`, then the edge check of the installed record against the record of the T4 review fixes):
```
 shoe     tag  same_as_committed  print_outside_ellipse  lost  recovered  fill_gained  fill_lost  dwidth_median  dwidth_maxabs  coverage  coverage_fill  tightness  contact_out_max_px    flags
  170 profile               True                     35    32          0            0          0            0.0            0.0  0.987521       0.994395   0.961078                 3.0 coverage
  170     r16              False                     35    32          1          317        470            0.0           34.0  0.986569       0.993761   0.953690                 3.0 coverage
  170     r24              False                     35    32          1          269        965            0.0           31.0  0.986781       0.993866   0.936833                 3.0 coverage
  170      E1              False                      0    32         32          893         62            1.0           64.0  1.000000       1.000000   0.982036                 0.0
```
```bash
$VPY -B docs/qa/T4/probes/t4fix2_checks.py edges 170 <scratch>/t4fix2/head_rec_170.npy
```
```
170: fill gained 893, lost 62; rows 25-340 (1-based); outward shift in px:
  left edge, 0-based rows 0-145: median 0, max 2, within 1 px on 91% of 122 rows
  left edge, 0-based rows 146-249: median 1, max 3, within 1 px on 65% of 104 rows
  left edge, 0-based rows 250-299: median 1, max 2, within 1 px on 90% of 50 rows
  left edge, 0-based rows 300-366: median 7.5, max 62, within 1 px on 0% of 40 rows
  right edge, 0-based rows 0-145: median 1, max 2, within 1 px on 80% of 122 rows
  right edge, 0-based rows 146-249: median 0, max 2, within 1 px on 99% of 104 rows
  right edge, 0-based rows 250-299: median 0, max 0, within 1 px on 100% of 50 rows
  right edge, 0-based rows 300-366: median 0, max 2, within 1 px on 92% of 40 rows
```
Radius 16 and 24 recover 1 px and keep the coverage flag, so no closing radius fixes 170. E1 encloses the rim (the lower-left heel, 0-based rows 300 and below, runs a median 7.5 px further out). Elsewhere every part moves by at most 1 px at the median and at most 3 px (the left side of the arch). My first wording of the override reason, "the forefoot does not move", was wrong for its right edge (1 px out at the median); it was corrected in `873b49e` before the docs commit, and A-107 states it correctly. **Decision (A-107):** E1 for 170 through the override file's ellipse columns; no other ellipse override. By the A-097/A-102 rule a fallback is taken when it breaks fewer bands *and* gives the better outline: 169, 37 and 125 break no band, and for 104 and 9 no ellipse gives the better outline.

**After the override**, on the rebuilt run:
```bash
$VPY -B docs/qa/T4/probes/t4fix2_ellipse_cross.py
$VPY -B docs/qa/T4/probes/t4fix2_checks.py parts
```
```
new: 42 shoes with cleaned print outside the initial ellipse polygon (42 by the analytic ellipse); 481 px, of them 127 outside the record fill
  at the toe: 29 shoes, 413 px, 82 outside the fill
  at the heel: 14 shoes, 68 px, 45 outside the fill: [35, 37, 46, 55, 56, 63, 142, 169, 314, 401, 422, 423, 432, 586]
  at the sides: 0 shoes; at toe and heel: [35]
```
```
9 13 13 px of a 16-px piece (3 in the fill) rows 21-24 -> sole
14 3 3 px of a 7432-px piece (7429 in the fill) rows 21-22 -> sole
[... 23 rows trimmed ...]
423 8 8 px of a 32-px piece (0 in the fill) rows 340-342 -> speck
432 3 3 px of a 39-px piece (0 in the fill) rows 334-336 -> speck
518 6 3 px of a 6-px piece (3 in the fill) rows 24-24 -> sole; 3 px of a 11-px piece (5 in the fill) rows 24-24 -> sole
584 1 1 px of a 4-px piece (3 in the fill) rows 27-27 -> sole
586 5 5 px of a 5-px piece (0 in the fill) rows 330-334 -> speck
total: {'sole': 90, 'speck': 37}
```
Of the 127 px still left outside, 90 are slivers of 1-13 px of printed parts the contour otherwise encloses (toe tips, pad rims, 9's mark) and 37 are isolated specks or debris. 423's 8 px belong to its heel corner piece beyond the mask edge (`mask_cut`), which the rule counts as a speck because it is separated from the print.

## 2. The NEW rebuild with the two changes

Step 0a-0b with the 49-row erase list, then the override writer, then the full step 0 and the QA (exact commands as in `docs/qa/snake-qa.md`):
```bash
RAC_DATASET=new MPLBACKEND=Agg TQDM_DISABLE=1 $VPY -B -m contour_algorithm.main --steps create,contour --qa
```
```
erase list: 49 rectangles on 11 shoes, 4149 contact pixels erased
step0 create: 1.8 s
step0 contour: 27.2 s
shoes whose matrix changed: [186] px: 6
mask equal: True 34509
superposition equal: True 28539
```
(the last three lines: my comparison with copies of the previous `list_matrices_new.npy`, `freq_min_18_new.npy` and `superposed_min_18_new.npy`; the superposition has count 1 at the erased pixels, so the >= 18 region and the mask cannot change).
```bash
RAC_DATASET=new MPLBACKEND=Agg TQDM_DISABLE=1 $VPY -B -m contour_algorithm.main --qa --jobs 14
SNAKES=<scratch>/t4fix2/snake_points_head.npz $VPY -B docs/qa/T4/probes/t4fix2_checks.py records <scratch>/t4fix2/contour_head.txt
```
```
numpy OpenBLAS threads: 1, snake jobs: 14
numpy OpenBLAS kernel: Haswell
Active contour processing complete - 631 shoes, 631 contour records (shoes without a record: [])
step0 snake: 76.3 s
real	1m47.923s
```
```
records that differ (shoe, px): [(170, 864), (186, 85)]; the other 629 are byte-identical
saved init differs for shoes [170]
saved first differs for shoes [170, 186]
saved second differs for shoes [170, 186]
```
(`contour_head.txt` and `snake_points_head.npz` are copies of the committed contour and saved snakes of `0af52b05...`, taken before the run.) 170's record equals the trial's E1 record (`np.array_equal`: True).
```bash
RAC_DATASET=new MPLBACKEND=Agg TQDM_DISABLE=1 $VPY -B -m contour_algorithm.qa_snake --metrics --sheets --figures --flagged --crosscheck --jobs 14
RAC_DATASET=new OPENBLAS_NUM_THREADS=1 MPLBACKEND=Agg TQDM_DISABLE=1 $VPY -B -m contour_algorithm.qa_snake --thresholds 13,18,24,29,36 --compare 18,29 --jobs 14
OPENBLAS_NUM_THREADS=1 RAC_DATASET=new MPLBACKEND=Agg $VPY -B docs/qa/T4/probes/t4_overrides_figure.py
```
```
new: 631 shoes, 29 flagged, 602 pass every band (95.40%)
wrote 52 sheets below /home/mehes/projects/rac-spatial-model/docs/qa/sheets_new
removed /home/mehes/projects/rac-spatial-model/docs/qa/T4/new/flagged/im_169_new.png (no longer flagged)
```
```
threshold 36: mask 33520 px, RAC pixels inside 1.0000, kept median 1.0000, p5 0.9964, removed 4531 px from 104 shoes
wrote .../docs/qa/T4/new/mask_threshold_new.csv
```
```
 170 before r10 coverage 0.9875 tightness 0.961 rac 1.000 flags coverage
 170 after r10 ell coverage 1.0000 tightness 0.982 rac 1.000 flags none
[... the 23 other pairs as in the T4 review fixes ...]
wrote .../docs/qa/T4/new/overrides_before_after_new.png
```
What changed in git: the contour, the four sheets 04 (shoes 148-196 hold 170 and 186), the metrics table and its copy (170, 186 and the review rows), the erase counts (one row), the cross-check (rows 170 and 186), the threshold table (only `removed_px` and `removed_186`, by 3-6 px: 186's line piece is now erased instead of mask-removed), `prototype_mask_new.png` (4 px of the union panel), the before/after figure, and 170's flagged figure (removed). The other 48 sheets and the other 29 flagged figures are byte-identical.

**Headline** (`$VPY -B docs/qa/T4/probes/t4fix_summary.py`):
```
final: 631 shoes, flagged 29, pass 602 (95.40%)
literal tightness 0.95 band too: pass 589 (93.34%)
T4 bands only (no A-099 triggers): pass 619 (98.10%)
flags: {'coverage': 1, 'coverage_fill': 1, 'rac_coverage': 8, 'rac_out_max_px': 7, 'contact_out_max_px': 19, 'outside_mask_frac': 2, 'tightness': 2}
resolution: {'override': 5, 'ok_after_review': 24} ; classes (all listed): {'partial_print': 28, 'spike': 3, 'mask_cut': 9, 'rim_cut': 7}
coverage<0.99: [8] | tightness<0.95: 18 | <0.9047: [375, 405]
erase list: 49 rectangles on 11 shoes; 4149 px erased, 2013 inside the mask
overrides: 24 {24.0: 22, 16.0: 1, nan: 1}
```
2023 cross-check: 19,998 of 20,013 RACs inside the new contours (unchanged). The task's 97% is met only under the T4 bands (98.10%); under the A-099 triggers it is 95.40%, and every one of the 29 flagged shoes is reviewed (none excluded).

## 3. Review classes and notes (vision minor notes 1 and 3)

Each unclassed shoe tried with radius 16 and 24 and two ellipses, to say in its note what would help:
```bash
OPENBLAS_NUM_THREADS=1 TQDM_DISABLE=1 $VPY -B docs/qa/T4/probes/t4fix2_ellipse_trial.py <scratch>/t4fix2/trial2.csv <scratch>/t4fix2/trial2 28,37,148,169,591,518,527 r16=r16 r24=r24 E1=187,127,167,98 E3=185,128,167,98
```
```
 shoe     tag  same_as_committed  print_outside_ellipse  lost  recovered  fill_gained  fill_lost  dwidth_median  dwidth_maxabs  coverage  coverage_fill  tightness  contact_out_max_px flags
   28 profile               True                      0     0          0            0          0            0.0            0.0  0.995815       0.997010   0.948795            6.324555
   28     r16              False                      0     0          0          354        198            1.0            8.0  0.995815       0.997010   0.954883            6.000000
   28     r24              False                      0     0          0          720        244            0.0           13.0  0.995964       0.997010   0.965370            4.472136
   28      E1              False                      0     0          0          365        827           -3.0           11.0  0.994320       0.996562   0.932324            7.071068
   28      E3              False                      0     0          0          312        720           -2.0           29.0  0.995366       0.996861   0.934858            6.000000
   37 profile               True                      4     4          0            0          0            0.0            0.0  0.995490       0.997933   0.920484            3.605551
   37     r16              False                      4     4          0         1047         47            3.0           11.0  0.996617       0.999248   0.953168            2.236068
   37     r24              False                      4     4          0          863         90            2.0           45.0  0.996617       0.999374   0.946765            2.000000
[... E1, E3 of 37 as in section 1 ...]
  148 profile               True                      0     0          0            0          0            0.0            0.0  0.992528       0.998282   0.989418            2.828427
  148     r16              False                      0     0          0          317        114            1.0           30.0  0.995963       0.999656   0.994659            1.000000
  148     r24              False                      0     0          0          353        701            0.0           11.0  0.992356       0.998712   0.976381            2.000000
  148      E1              False                      0     0          0          531        316           -1.0           54.0  0.999828       1.000000   0.991873            0.000000
  148      E3              False                      0     0          0          604         75            0.0           52.0  1.000000       1.000000   1.000398            0.000000
  169     r16              False                      7     6          3          703        755            1.0           41.0  0.995381       0.999289   0.950307            2.000000
  169     r24              False                      7     6          6         1515        532            5.0           45.0  1.000000       1.000000   0.987669            0.000000
[... 169's profile, E1, E3 as in section 1 ...]
  518 profile               True                     11     6          0            0          0            0.0            0.0  0.996681       0.998970   1.017738            2.000000
  518      E1              False                      0     6          6          956        159            2.0           23.0  1.000000       1.000000   1.046296            0.000000
  518      E3              False                      0     6          6         1388          0            3.0           25.0  1.000000       1.000000   1.067976            0.000000
[... 518's r16, r24 and the five rows of 527 (nothing outside; its variants change little) trimmed ...]
  591 profile               True                      0     0          0            0          0            0.0            0.0  0.994836       0.996668   0.998019            5.000000
  591     r16              False                      0     0          0         1230          4            3.0           11.0  1.000000       1.000000   1.045608            0.000000
  591     r24              False                      0     0          0          588        325            0.0            9.0  1.000000       1.000000   1.008624            0.000000
  591      E1              False                      0     0          0          287        286           -1.0            8.0  0.994836       0.996668   0.998019            5.000000
  591      E3              False                      0     0          0           43        522           -1.0           11.0  0.995002       0.996668   0.979721            5.000000
```
37's cut pixels under each variant (my count: cleaned contact outside the variant's fill, all and at the lower-right heel pad, 0-based rows >= 300): profile 33 and 31, r16 12 and 10, r24 10 and 8, E1 2 and 0, E3 2 and 0. My first note said that radius 16 and 24 "keep the cut"; they leave 8-10 px of it, and the note was corrected in `873b49e`.

**Looked at** (`t4fix2_zoom.py`, 6x: kept contact grey, contact outside the fill yellow, contour blue, first snake cyan, ellipse orange dashed, mask boundary green; and the whole shoes at 2x):
- 28: the upper-right heel pad is a ring pattern, and the contour runs through its outermost ring: a yellow arc of 20 px, up to 6.3 px outside. Real sole; no variant encloses it.
- 37: the bottom-right edge of the lower-right pad (23 px, up to 3.6 px), where the ellipse passes close by.
- 148: the bottom-left edge of the lower-left pad (20 px, up to 2.8 px).
- 169: the left edge of the lower-left pad (15 px, up to 2.8 px), exactly where the ellipse crosses.
- 591: the right ends of the heel's diagonal strokes (14 + 6 px, up to 5 px).
- 518 and 527 (the same Nike-type design: striped toe, square blocks, heel triangles): the striped toe narrows to a point.
```bash
$VPY -B docs/qa/T4/probes/t4fix2_checks.py toes 518 527 9
```
```
518: top printed row 24, contour top row 22 (1-based); fill widths from the top [7, 11, 13, 17, 20, 23, 25, 28]
527: top printed row 25, contour top row 19 (1-based); fill widths from the top [7, 10, 12, 14, 16, 18, 20, 22]
9: top printed row 21, contour top row 25 (1-based); fill widths from the top [3, 5, 7, 9, 11, 12, 14, 16]
```
518's narrow peak sits 2 rows above its shortest top stripe, whose two ends stick out (6 px). 527's peak rises 6 rows above its topmost mark, into empty space. 9 stops 4 rows below the top of its isolated mark.

All are within the OLD tolerance (contact out < 8 px) and break no band, so the A-102 rule takes no fallback. Classed: 28, 37, 148, 169, 591 `rim_cut`; 518, 527 `spike`. 170 leaves the review file (its cut is gone). The ellipse crossing is named in the notes of 9, 104, 125 and 423.

**328** (`$VPY -B $S/rv_vis2/align.py 327 328 <band>`, the reviewer's script, then the speck check):
```
shift of 328 onto 327: dr=0 dc=0 overlap=2312 (A px in band 3066, B 3826)          [band rows 40-200]
shift of 328 onto 327: dr=-1 dc=3 overlap=689 (A px in band 1847, B 827)           [band rows 250-340]
shift of 328 onto 327: dr=0 dc=1 overlap=2946 (A px in band 5643, B 5073)          [whole sole]
shoe 327: print rows 43-319, contour rows 39-323 (in 327 frame)
shoe 328: print rows 28-332, contour rows 26-313 (in 327 frame)
```
```bash
$VPY -B docs/qa/T4/probes/t4fix2_checks.py speck328
```
```
328 on 327, shift 0 rows +0 col:
  4 px, rows 294-296, cols 166-167 (1-based), 2.0 px outside 328: 4 of 4 inside 327's heel outline
  5 px, rows 314-316, cols 162-164 (1-based), 18.0 px outside 328: 5 of 5 inside 327's heel outline
  3 px, rows 327-328, cols 149-151 (1-based), 20.1 px outside 328: 0 of 3 inside 327's heel outline
  6 px, rows 331-333, cols 135-138 (1-based), 19.9 px outside 328: 0 of 6 inside 327's heel outline
[... the same for shift 0 rows +1 col ...]
327: printed rows [ 44 320], contour rows [ 40 324] (1-based)
328: printed rows [ 29 333], contour rows [ 27 314] (1-based)
```
(the heel band's weak overlap, 689 px, is not used; the whole-sole and forefoot shifts agree.) The reviewer is right: 328's contour ends on row 314 (1-based), 6 rows above 327's lowest print and 10 above its contour, and the upper of the three specks (rows 314-316) lies inside 327's heel outline. The note is reworded; `partial_print` stays.

## 4. 186's frame-line remnant (vision minor note 2)

Pixel dump of 186's right side (0-based rows and columns from 150; `#` kept in the mask, `r` kept outside it, `e` erased, `o` contour, `+` contour on contact):
```
249 ###..........................o..#r................
250 ###..........................o..#.rr..............
251 ............................o...#.................
[...]
259 ########.....##.#........+#....eee................
260 ###########..#..##......oo##.#..e.................
261 .#########.............o####.##..e................
262 ..########.............o......#..e................
(249, 182) component 84 size 6 rows 249 251 cols 182 185
(260, 179) component 88 size 4 rows 260 262 cols 179 180
```
Looked at (8x, `z186b.png`): the line's fragments (rows ~201-203, 211-215, 249-251, 259-262, 0-based) lie on one slightly tilted straight course (column ~189 at row 202, ~182 at row 260). The reviewer's 3 px (0-based column 182, rows 249-251) are on it and 8-connected to its red pixels, so they are frame line. The 13 px right of the heel (0-based rows 258-262, columns 174-180) lie 1-8 px left of the course and are not joined to it. 187, the next shoe, has another design, so it cannot settle what they are; they stay, outside the contour, named as a residual. The rectangle and its check:
```bash
$VPY -B docs/qa/T4/probes/t4fix_erase_list.py <scratch>/t4fix2/erase_list_v2.csv
```
```
580 rectangles erase exactly the contact outside the envelope: True 199
105 rectangles hold exactly the blob: True 96
186 rectangle erases exactly the line piece: True 6 px, of them inside the mask: [(250, 183), (251, 183), (252, 183)]
[... the other added rows as in the T4 review fixes ...]
186,250,252,183,186: erased 6 (in mask 3)
total new erased 743 in mask 443 ; zero rows: []
wrote <scratch>/t4fix2/erase_list_v2.csv 49 rows; equal to the committed list: False
```
(the list then installed; a rerun says True). No row prints `RAC!`, so no RAC pixel lies in a rectangle; `Stickers.test_new_list` checks the same. After the rebuild:
```bash
$VPY -B docs/qa/T4/probes/t4fix2_checks.py outside 186
```
```
186: 13 cleaned px outside the fill at (row, col), 1-based: [(259, 177), (259, 178), (260, 177), (261, 177), (261, 178), (261, 180), (262, 175), (262, 176), (262, 177), (262, 178), (262, 180), (262, 181), (263, 181)]
```
186's record changed by 85 px (fill +10 / -34 px; 43 rows between 0-based rows 166 and 325 change width, by at most 2 px). Looked at (`z186_after.png`, 3x, the new contour blue over the previous one orange): the new contour runs up to 1-2 px inside the old one along the right side from the arch to the heel and no longer bends toward the erased remnant.

## 5. OpenBLAS and the gates (A-108)

**NEW step 0 refuses another kernel** (in a scratch copy of the work tree, so that a failing refusal could not touch the committed contour):
```bash
OPENBLAS_CORETYPE=Sandybridge RAC_DATASET=new $VPY -B -m contour_algorithm.main --steps snake; echo "exit $?"
```
```
contour_algorithm.main: numpy OpenBLAS runs the Sandybridge kernel, and the new contour was built with Haswell (python.blas_kernel): another kernel gives other snakes (A-103, A-108). Unset OPENBLAS_CORETYPE; on a machine whose OpenBLAS picks another kernel the committed contour cannot be rebuilt, and changing python.blas_kernel is a decision to record
exit 2
```
No `images_new/` was created, and the copy's contour kept its sha256 (`f7703bcdbdb0f823`). Under `OPENBLAS_CORETYPE=Sandybridge` numpy reports `16 Sandybridge`; `OPENBLAS_CORETYPE=Haswell` with one thread passes the check, because it is the same kernel.

**The OLD gate refuses another kernel before step 0** (the scratch copy with its `openblas_tier_b.txt` edited to `kernel Zen`):
```bash
RAC_SCRATCH=<scratch>/t4fix2/gates RAC_VENV_PY=$VPY bash <copy>/tests/regress_old.sh --steps 0
```
```
regress_old.sh: numpy's OpenBLAS would run the Haswell kernel; both OLD step-0 baselines were written with Zen (.../coretype_demo/repo/tests/baseline/local/openblas_tier_b.txt), and the snake depends on the kernel (A-103, A-108): the OLD contour cannot be compared on this machine
real	0m6.296s
exit 2
```
No run folder was made.

**The OLD snake test explains a forced kernel:**
```bash
OPENBLAS_CORETYPE=Sandybridge MPLBACKEND=Agg $VPY -B -m unittest tests.python.test_snake_old_regression
```
```
      8 AssertionError: numpy OpenBLAS runs the Sandybridge kernel; the OLD baselines were written with Haswell (tests/baseline/local/openblas_tier_b.txt) and the snake depends on it (A-103, A-108): run without OPENBLAS_CORETYPE on a machine whose OpenBLAS picks Haswell
      1 FAILED (failures=8, skipped=2)
```
(the counts are from `sort | uniq -c`; the eight subtests of the two rerun tests; before the fix they failed with pixel counts.)

**The NEW gate against HEAD, with `--full`**, at `586c18a`:
```bash
RAC_SCRATCH=<scratch>/t4fix2/gates RAC_VENV_PY=$VPY bash tests/rebuild_new.sh --full --keep
```
```
result  check                                                detail
PASS    pipeline run                                         every step exit 0
PASS    OpenBLAS threads and kernel = NEW profile            1 threads, kernel Haswell
PASS    data/new_shoes/contour_Active_Contour_new.txt        = HEAD, sha256 f7703bcdbdb0...
PASS    docs/qa/T4/new/snake_metrics_new.csv                 = HEAD, sha256 0bd778440da9...
PASS    docs/qa/T4/new/sticker_erased_new.csv                = HEAD, sha256 7a3517ce6811...
PASS    docs/qa/sheets_new/snake_qa_new.csv                  = HEAD, sha256 0bd778440da9...
PASS    docs/qa/T4/new/crosscheck_2023_new.csv               = HEAD, sha256 b942de44faa6...
PASS    docs/qa/T4/new/mask_threshold_new.csv                = HEAD, sha256 b95fd3a8c537...
PASS    docs/qa/T4/new/overrides_before_after_new.png        = HEAD, sha256 bc39544b34d5...
PASS    docs/qa/sheets_new/prototype/prototype_mask_new.png  = HEAD, sha256 31983d4e0eea...
PASS    contact sheets (docs/qa/sheets_new)                  52 files = HEAD
PASS    flagged figures (docs/qa/T4/new/flagged)             29 files = HEAD
timings (s):
step              seconds        exit
step0             142.584442843  0
qa_metrics        25.683738613   0
qa_figures        171.101899218  0
qa_thresholds     31.570493260   0
overrides_figure  44.244332279   0
ALL PASS
real	7m0.965s
```
(beside the two OLD gates; `873b49e` later changed only two notes, and the gate's final run at the docs commit is in section 9.)

## 6. Tests

New and changed tests (all in the fast suite):
- `tests/python/test_qa_snake.py` (31 -> 37 tests):
  - `Blas.test_kernel_guard`: a fixed kernel other than the process's is refused; NEW fixes Haswell, OLD none.
  - `Blas.test_every_snake_path_is_checked`: with a wrong thread count, `prototype_mask_from`, `active_contour_shoe` and `main.run()` raise before a snake runs (`active_contour` mocked to fail) or anything is written (the temporary root stays empty).
  - `Blas.test_cli_refuses_another_kernel`: `main --steps snake` exits 2 with the kernel's name, and `run` is never called.
  - `CommandLine.test_old_has_no_sheets_folder`: checks the "needs"/"need" wording.
  - `CommandLine.test_crosscheck_needs_the_2023_file`.
  - `CommandLine.test_jobs_need_fork`: `run` and `load_profile` of step 0 are mocked to raise, and the message must name fork.
  - `CommandLine.test_prune_flagged`.
  - `Files.test_flagged_figures`: the folder holds exactly the flagged shoes.
  - `Files.test_all_flags_resolved`: a flagged shoe is `override` exactly when it has an override row.
  - `Profiles.test_new_values`: 170's ellipse override and the NEW kernel.
- `tests/python/test_profiles.py`: a blank or non-string `python.blas_kernel` is refused.
- `tests/python/test_snake_old_regression.py`: the kernel is part of the precondition.

```bash
env -u OPENBLAS_NUM_THREADS -u OPENBLAS_CORETYPE MPLBACKEND=Agg TQDM_DISABLE=1 $VPY -B -m unittest tests.python.test_qa_snake tests.python.test_profiles tests.python.test_contour_new tests.python.test_sentinel_profile tests.python.test_snake_old_regression
```
```
Ran 76 tests in 23.175s
OK (skipped=2)
```
**Mutation check** (`<scratch>/t4fix2/mutate.py`: each mutant edits one guard in a fresh copy of the work tree, then `unittest tests.python.test_qa_snake`):
```
no_fork_guard: FAILED (failures=1) | FAIL: test_jobs_need_fork CommandLine.test_jobs_need_fork);
no_check_in_prototype: FAILED (failures=1) | FAIL: test_every_snake_path_is_checked Blas.test_every_snake_path_is_c;
no_check_in_shoe: FAILED (errors=1) | ERROR: test_every_snake_path_is_checked Blas.test_every_snake_path_is_;
no_check_in_run: FAILED (failures=1) | FAIL: test_every_snake_path_is_checked Blas.test_every_snake_path_is_c;
no_kernel_check: FAILED (failures=2) | FAIL: test_cli_refuses_another_kernel Blas.test_cli_refuses_another_ke;FAIL: test_kernel_guard Blas.test_kernel_guard);
no_cli_precheck: FAILED (failures=1) | FAIL: test_cli_refuses_another_kernel Blas.test_cli_refuses_another_ke;
crosscheck_refusal_gone: FAILED (failures=1) | FAIL: test_crosscheck_needs_the_2023_file CommandLine.test_crosscheck_;
prune_keeps_all: FAILED (failures=1) | FAIL: test_prune_flagged CommandLine.test_prune_flagged);
```
All 8 caught. No mutant copy gained an `images_new/` folder: the fork mutant now fails without running step 0. The engineer's other noted gap (removing the task-copy write breaks no fast test) is still caught only by `rebuild_new.sh`, which deletes and regenerates the copy.

The full fast suite on the final tree: section 9.

## 7. The override writer (A-109)

The first run of the self-contained `t4fix_overrides.py` against the committed file of the T4 review fixes (my comparison of the two CSVs, row by row):
```
added: ['170'] removed: []
12 differs in ['reason'] | QA numbers equal: True | tags: A-097) -> T4 review, A-102)
46 differs in ['reason'] | QA numbers equal: True | tags: A-097) -> T4 review, A-102)
[... 69, 120, 140, 165, 173, 222, 235, 267, 286, 456 the same ...]
506 differs in ['reason'] | QA numbers equal: True | tags: A-097) -> T4 review, A-102)
```
Every QA number of the 23 old rows came back identical. The rows of 8, 63, 109, 112, 113, 163, 175, 376, 427 and 557 are byte-identical; 13 rows change only their tag (and 165 its duplicated "(A-102)"). The final file (after 170's corrected reason), rewritten from itself:
```bash
OPENBLAS_NUM_THREADS=1 TQDM_DISABLE=1 $VPY -B docs/qa/T4/probes/t4fix_overrides.py <scratch>/t4fix2/overrides_v6_rerun.csv
cmp <scratch>/t4fix2/overrides_v6_rerun.csv data/new_shoes/snake_overrides_new.csv && echo "rerun byte-identical"
```
```
wrote <scratch>/t4fix2/overrides_v6_rerun.csv 24 overrides
rerun byte-identical
```

## 8. Visual review (user rule 10)

Looked at with the Read tool, and described where they are used above:
- the reviewer's `cmp170.png`;
- my candidate-ellipse figures `fig_170.png`, `fig_170_heel.png` (4x), `fig_169.png`, `fig_169_heel.png` (4x), `fig_37.png`, `fig_toes.png` (3x: 125, 104, 9);
- the 186 zooms `z186.png`, `z186b.png` (8x, with 187), `z186_after.png` (3x, the new outline over the old);
- the 6x rim-cut and toe zooms `z_rim.png` (28, 37, 148, 169) and `z_rim2.png` (591, 518, 527), and the 2x whole shoes `z_518_527.png` (518, 527, 28, 591);
- the rebuilt `final_snake_sheet_04_new.png` (whole sheet), rows 4 and 6 of `ellipse_first_snake_sheet_04_new.png`, 186's tiles of `cleaned_sheet_04_new.png` and `prototype_sheet_04_new.png` (2x);
- rows 1-2 and 5 of `overrides_before_after_new.png`.

Summary of what I saw:
- 170's ellipse is visibly larger and lower than its neighbours' on the ellipse sheet, and its first and final snakes wrap the whole lower-left heel pad.
- 186's cleaned tile shows sole only at sheet size (forefoot lugs, two C-shaped heel pads), and its prototype tile shows the erased lines in magenta.
- Nothing else changed on the sheets: the other 48 sheets are byte-identical.

All scratch images are in `<scratch>/t4fix2/`.

## 9. OLD regression and the final suite

The code change on the OLD path: `check_blas_threads` (which checks nothing for OLD: it fixes neither threads nor kernel) is now called at the start of `main.run()`, `prototype_mask_from` and `active_contour_shoe`, and the OpenBLAS getter is cached. The OLD gate's environment additionally drops `OPENBLAS_CORETYPE` (not set in these runs) and checks the kernel. R code, `tools/` and the OLD profile entry are unchanged. Gates on the work tree of `586c18a` (code, data and tests of this pass; `873b49e` changed two NEW notes only), run beside each other and beside the NEW `--full` gate:
```bash
RAC_SCRATCH=<scratch>/t4fix2/gates RAC_VENV_PY=$VPY bash tests/regress_old.sh --steps 0 --keep
RAC_SCRATCH=<scratch>/t4fix2/gates RAC_VENV_PY=$VPY bash tests/regress_old.sh --steps 1-6 --keep
```
```
== regress_old.sh --steps 0: <scratch>/t4fix2/gates/regress_old_e8tcqP
result  check                                          detail
PASS    pipeline run                                   every step exit 0, every output regenerated
PASS    step 0 OpenBLAS threads and kernel = baseline  16 threads, kernel Haswell
PASS    step 0 contour = Tier B (CRLF)                 data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B                  1556 npy/png files, all equal
PASS    live check test_snake_old_regression           logs/live_snake.txt
timings (s):
step   seconds        exit
step0  858.006738907  0
ALL PASS
```
```
== regress_old.sh --steps 1-6: <scratch>/t4fix2/gates/regress_old_mXPIO0
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
step1       222.859081208  0
step2       37.121757124   0
step3_glmm  376.825664213  0
step3_cml   261.156146656  0
step4_glmm  16.679542373   0
step4_cml   38.604350761   0
step5       53.268469987   0
step6       18.987397211   0
ALL PASS
```
(step 0 took 858 s and the whole step-0 gate 14 min 42 s beside the other gates; steps 1-6: 17 min 20 s.) The step-1 and step-2 CSVs are Tier A byte for byte, both models are `identical()` to Tier B in every field of the dump, the 8 PDFs equal Tier B after date normalization, W = 427.7804472165 = Tier B (df 24), and the live checks pass.

**With inherited `OPENBLAS_CORETYPE=Sandybridge` and `OPENBLAS_NUM_THREADS=1`** (the reproducibility reviewer's failure case; the gate removes both):
```bash
OPENBLAS_CORETYPE=Sandybridge OPENBLAS_NUM_THREADS=1 RAC_SCRATCH=<scratch>/t4fix2/gates RAC_VENV_PY=$VPY bash tests/regress_old.sh --steps 0
```
```
== regress_old.sh --steps 0: <scratch>/t4fix2/gates/regress_old_N0GAxY
result  check                                          detail
PASS    pipeline run                                   every step exit 0, every output regenerated
PASS    step 0 OpenBLAS threads and kernel = baseline  16 threads, kernel Haswell
PASS    step 0 contour = Tier B (CRLF)                 data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B                  1556 npy/png files, all equal
PASS    live check test_snake_old_regression           logs/live_snake.txt
timings (s):
step   seconds        exit
step0  633.150439024  0
ALL PASS
```
(11 min 0 s; the run folder deleted after the pass.)

**Tier A under venv-wind** (the Windows thesis venv; the code of `873b49e` by `git archive`):
```bash
RAC_SCRATCH=<scratch>/t4fix2/gates bash tests/legacy/run_windows_python_step0.sh
```
```
<scratch>/t4fix2/gates/winpy_step0_bU9vcB
commit commit=873b49e889800942ceb79ef5f968abbfa8bb97c8
sys.version 3.13.14 (tags/v3.13.14:fd17997, Jun 10 2026, 13:03:48) [MSC v.1944 64 bit (AMD64)]
sys.base_prefix C:\Program Files\WindowsApps\PythonSoftwareFoundation.Python.3.13_3.13.3824.0_x64__qbz5n2kfra8p0
sys.executable C:\Users\mehes\Documents\repo\master_thesis_forensic_shoeprint\venv-wind\Scripts\python.exe
platform Windows-11-10.0.26300-SP0
step 0 exit 0, outputs written: yes
contour sha256 ca8a07f2a46614a14383a8017b688663caba8350c3ea41c51792d8ebd0ec7e56 (Tier A ca8a07f2a46614a14383a8017b688663caba8350c3ea41c51792d8ebd0ec7e56)
RESULT contour = Tier A
RESULT list_matrices.npy = Tier B
RESULT old_freq_min_18.npy = Tier B
RESULT freq_min_18.npy = Tier B
RESULT list_contour.npy = Tier B
INFO active-contour_all.npy = the thesis run of 2025-11-13
```
Its step-0 log (`logs/step0_win.log`) prints `numpy OpenBLAS threads: 16, snake jobs: 1` and `numpy OpenBLAS kernel: Haswell`: the kernel getter works under venv-wind too (the engineer's nit 5; the reproducibility reviewer saw the same at `cbba2ef`). 11 min 6 s.

**No committed OLD file, R file, `tools/` file, baseline or raw input changed:**
```bash
git diff 015551b --stat -- ':(glob)data/*.txt' ':(glob)data/*.csv' ':(glob)data/*.png' ':(glob)processed_data/*' ':(glob)saved_models/*' ':(glob)model_images/*' 'statistical_model' 'tools' 'data/new_shoes/contacts_data_new.txt' 'data/new_shoes/locations_data_new_raw.txt' 'data/new_shoes/locations_new_snake_2023.csv' 'data/new_shoes/locations_data_new.csv' 'tests/baseline'; echo "[end of list]"
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
The profile file changed only in its NEW entry (`python.blas_kernel` and a comment line).

**The NEW gate at `873b49e`** (after the two note corrections):
```bash
RAC_SCRATCH=<scratch>/t4fix2/gates RAC_VENV_PY=$VPY bash tests/rebuild_new.sh
```
```
PASS    pipeline run                                   every step exit 0
PASS    OpenBLAS threads and kernel = NEW profile      1 threads, kernel Haswell
PASS    data/new_shoes/contour_Active_Contour_new.txt  = HEAD, sha256 f7703bcdbdb0...
PASS    docs/qa/T4/new/snake_metrics_new.csv           = HEAD, sha256 f59b84ef2cdb...
PASS    docs/qa/T4/new/sticker_erased_new.csv          = HEAD, sha256 7a3517ce6811...
PASS    docs/qa/sheets_new/snake_qa_new.csv            = HEAD, sha256 f59b84ef2cdb...
timings (s):
step        seconds        exit
step0       114.889748864  0
qa_metrics  15.661256335   0
ALL PASS
real	2m13.086s
```

**The fast suite on the final tree** (the code, data and tests of `873b49e` with this pass's documents in the work tree; nothing was edited during the run):
```bash
RAC_VENV_PY=$VPY bash tests/run_all.sh
```
```

real	3m57.369s
```
`Ran 184 tests in 80.339s`, `OK (skipped=3)`: the three live checks that need a run folder. The R erase-list test reports `PASS NEW erase list: R erases 4149 contact pixels in 11 shoes, per rectangle as Python`. The first suite run of this pass (before the commits, `<scratch>/t4fix2/runall_1.log`) passed every test but failed `work tree unchanged`, because I edited `docs/decisions.md` and the plan while it ran (the check's diff names exactly those two files).

## 10. Corrections

- The LOG entry of the T4 review fixes (18:35) and that implementer's report said "every T4 column identical" for the rebuilt OLD QA reference `docs/qa/T4/old/snake_metrics.csv`. In fact every T4 column except `qa_flags` is identical; `qa_flags` gains the A-099 trigger names on 24 rows by design (`docs/tests/T4-review-fixes-results.md` said it correctly). Recorded here and in this pass's LOG entry, since old LOG entries are not rewritten.
- A-105, F68 and `docs/qa/snake-qa.md`: the ellipse diagnosis (section 1). A-105 stays as written and A-107 corrects it; F68 is corrected in place with a note, as the plan's revisions have done for facts before.
- Two notes of my own were wrong in the first data commit `dd26bb8` and were corrected in `873b49e`, before the docs commit: 170's override reason ("the forefoot does not move") and 37's review note ("radius 16 and 24 keep the cut").
- The committed override file tagged 13 of the 15 A-102 overrides "(A-097)" (section 7, A-109).

## 11. Timings

| What | Time |
|---|---|
| Ellipse crossing probe (631 shoes) | 1 min 13 s |
| Ellipse trial, 28 shoes x 4 variants (14 jobs) | 2 min 16 s; 7 shoes x 5 variants: 23 s |
| NEW step 0a-0b; full step 0 (14 jobs) | 31 s; 1 min 48 s (snakes 76 s) |
| NEW QA (metrics, sheets, figures, flagged, cross-check) | 3 min 25 s |
| Threshold study; before/after figure; override writer | 18 s; 28 s; 18 s |
| `test_qa_snake` and four other modules; 8 mutants | 25 s; about 4 min |
| `tests/run_all.sh` (first run, beside nothing else) | 4 min 0 s |
| `tests/rebuild_new.sh --full` (beside the two OLD gates) | 7 min 1 s |
