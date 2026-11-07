# T5 second review fixes: results

**Date:** 2026-11-07. **Task:** fix the findings of the three reviews of the T5 review fixes (statistician `26625b8`, engineer `f1acd06`, reproducibility `a6011ca`; LOG 2026-11-07 02:40, 02:45, 02:55): two majors (statistics) and nine minors. **Branch:** `feature/new-shoes-pipeline`. **Commits:** `3bab0a6` (the NEW outputs test, the only code change), `197069c` (the probes), then the docs commits. **Decisions:** A-119 to A-121 and D-015 (new); corrections appended to A-113, A-115 and A-116, A-114 superseded in part, a new update of D-008 (`docs/decisions.md`); plan revision 14 (F75, F77-F80 and F82 corrected; F84 and risk R34 added; T5-T8, sections 4.5, 9 and 12 annotated). Every number below is real output of the command above it; `<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`. No OLD output, raw data file, profile value or pipeline code changed (section 9).

Each finding was checked before it was accepted (the reviewer's scratch probes were ported into committed probes and rerun here; every number of the review reproduces). Three results go beyond the review (section 2): the out-of-sample gain of the finer basis is real but modest overall (held-out log score z 2.1 against the step-3 basis) and clear at the heel front (held-out O/E intervals, held-out cell residuals); on OLD the finer basis lowers the held-out cell residuals away from the heel front although it does not improve the held-out log score, so the knot question concerns both datasets; and the finer full tensor raises spurious map maxima at the sparse left edge of the data, so it is a sensitivity, not a better map by itself.

## 1. Summary

| Finding (reviewer, severity) | What was done | Evidence |
|---|---|---|
| The NEW heel-front misfit comes mainly from the y resolution of the step-3 basis, not from sole design (statistician, major 1) | Ported the reviewer's three probes into `docs/qa/T5/probes/t5_basis_y.R` (every number reproduced), added shoe-level SEs of the cross-validation gains, shoe-bootstrap intervals of the held-out O/E, held-out cell residuals by region and the local maxima of the surfaces (a GLMM refit on the finer basis was stopped unfinished after 2 h 26 min); the attribution corrected in A-114 (superseded in part by A-119), plan F77-F79 (new F84), the T5 results (correction 2), the T5 review-fix results (section 3) and the LOG; a finer-y-knot sensitivity added to T6 and T7; the knots go to Naomi and Micha (D-015) | section 2 |
| "Word a band rejection as a design effect, not as model failure" is a false choice, and the group splits are circular in the band (statistician, major 2) | A-120 replaces A-114 (4), the T7 step 4 note and the section 9 sentence: group splits descriptive, a band rejection worded "the one-surface model does not hold across sole designs, and/or the step-3 basis is too coarse there", a design classification without the RAC locations for a confirmatory split, the detection alternative named beside wear in T8 | section 3 |
| Binomial z values without caveat; group A's z post hoc; group B compared with OLD at different power (statistician, minor 5) | `docs/qa/T5/probes/t5_boot.R` (the reviewer's intervals reproduced exactly, plus cuts 110 and 190 and OLD); intervals beside the z values in F77-F79 and A-120; the B-vs-OLD comparison dropped | section 4 |
| "LR x 0.57" is not a robust test (statistician, minor 3) | `t5_inference.R` section 3 now computes the direct cluster-robust Wald of the 10 main effects with the generalized design effects and Rao-Scott (OLD 32.47, NEW 87.98, both far beyond chi^2_10); A-116, F80, results 4.3 and the LOG corrected | section 5 |
| The no-offset sigma^2 is called a spread of RAC density (statistician, minor 4) | Worded as a spread of RAC counts (density times area); only the offset refit measures density: A-115, D-008, F75, F82, T6 (c), corrections 6 | section 6 |
| A missing step-2 CSV stops `test_new_outputs.R` before 8 checks (engineer, minor 1) | Reproduced; fixed (`3bab0a6`): CSVs initialised and renamed, knots inside the checks, clear FAIL reasons, the LF check on its own; three missing-file scenarios and the mutants M1, M2 (A-113 corrected) | section 7 |
| The fast suite is over its documented budget (engineer, minor 2) | The documented budget follows the measured time (A-121) | section 8.3 |
| Three nits (engineer) | "of section 4.2"; `t5_stamp_figure.py` lists the `rebuild_new.sh --keep` route first; the header of `test_no_hardcoding.R` rewrapped | section 8.4 |
| The figures are checked for existence only (reproducibility, minor 1) | As planned (T8's e2e test); until then the test's message, the tests README and A-113 say to rerun `t5_new_rerun.sh --oldbasis --png` after any change of a NEW model | section 8.1 |
| NEW step 0 is not pinned to a platform (reproducibility, minor 2) | Kept as recorded in A-117 (Shlomo may ask for the pin) | section 8.2 |
| The OLD gates ran at `8de60f5`, not the final commit (reproducibility, note) | This task's gates ran on a clean clone of the final code commit `3bab0a6` | section 9 |

## 2. The NEW heel-front misfit: mainly the y resolution of the step-3 basis (A-119)

The claim of the review: the step-3 basis (3 knots in `new_x`, 5 in y, interaction only, plan K8) is too coarse in y to follow NEW's sharp dip of RAC density at the heel front, and a finer y basis removes most of the misfit that the T5 review fixes attributed to sole design. `docs/qa/T5/probes/t5_basis_y.R` ports the reviewer's `finer_basis.R`, `cv_basis.R` and `stat_checks.R` (section 2) into one committed probe. It adds a 5x9 full tensor to the cross-validation (the basis on which the earlier "a richer basis does not remove it" rested), a standard error over shoes for each cross-validation gain (the shoe is the independent unit), shoe-bootstrap intervals of the held-out O/E, the held-out cell residuals by region, and the local maxima of the K8 and the finer CML surfaces on the prototype grid of the step-4 maps with the raw case/control ratio around each (the maps are drawn from the GLMM, while the evidence here is the Efron CML; on the step-3 basis the CML and the GLMM maps agree within 1-2%, F77, and the K8 CML surface has the six local maxima of the committed GLMM map, section A).

```bash
time Rscript docs/qa/T5/probes/t5_basis_y.R
```
```
== A. in sample (Efron CML)
old: 51849 rows, 13249 cases, 386 shoes (fits 11 s)
  K8       24 coef, loglik -64623.37, AIC 129294.7 | band O/E 0.88, cut 250 1.03, peak window 1.02 | cells E >= 15: 112, |z| > 3: 1, sum z^2 182
  full     34 coef, loglik -64603.84, AIC 129275.7 | band O/E 0.89, cut 250 1.04, peak window 1.03 | cells E >= 15: 112, |z| > 3: 0, sum z^2 149
  full_5x9 76 coef, loglik -64560.51, AIC 129273.0 | band O/E 0.90, cut 250 1.04, peak window 1.00 | cells E >= 15: 110, |z| > 3: 0, sum z^2 86
  fullU    84 coef, loglik -64542.12, AIC 129252.2 | band O/E 0.93, cut 250 1.02, peak window 0.95 | cells E >= 15: 110, |z| > 3: 0, sum z^2 103
  model-based LR: K8 -> full LR 39.0 on 10 df (p 2.5e-05) ; full -> fullU LR 123.4 on 50 df (p 3.8e-08) ; K8 -> fullU LR 162.5 on 60 df (p 2.2e-11) 
  y (heel front)     O     K8  fullU
  (-0.32,-0.3]     399   1.05   1.01
  (-0.3,-0.28]     373   0.95   0.90
  (-0.28,-0.26]    455   1.08   1.02
  (-0.26,-0.24]    417   1.00   0.94
  (-0.24,-0.22]    355   0.97   0.93
  (-0.22,-0.2]     270   1.04   1.00
  (-0.2,-0.18]     195   1.06   1.02
  (-0.18,-0.16]    149   1.00   0.99
  (-0.16,-0.14]     93   0.91   0.96
  (-0.14,-0.12]     66   0.78   0.87
  (-0.12,-0.1]      60   0.72   0.85
  (-0.1,-0.08]      66   0.93   1.08
  (-0.08,-0.06]     87   1.01   1.14
  (-0.06,-0.04]    122   1.08   1.21
new: 83090 rows, 19990 cases, 631 shoes (fits 16 s)
  K8       24 coef, loglik -96639.22, AIC 193326.4 | band O/E 0.64, cut 250 0.79, peak window 0.64 (band: A 0.31, B 0.88) | cells E >= 15: 113, |z| > 3: 10, sum z^2 330
  full     34 coef, loglik -96591.90, AIC 193251.8 | band O/E 0.66, cut 250 0.81, peak window 0.65 (band: A 0.32, B 0.91) | cells E >= 15: 113, |z| > 3: 3, sum z^2 248
  full_5x9 76 coef, loglik -96511.97, AIC 193175.9 | band O/E 0.75, cut 250 0.88, peak window 0.76 (band: A 0.36, B 1.02) | cells E >= 15: 113, |z| > 3: 2, sum z^2 207
  fullU    84 coef, loglik -96456.26, AIC 193080.5 | band O/E 0.92, cut 250 1.04, peak window 0.91 (band: A 0.45, B 1.24) | cells E >= 15: 113, |z| > 3: 2, sum z^2 171
  model-based LR: K8 -> full LR 94.6 on 10 df (p 6.4e-16) ; full -> fullU LR 271.3 on 50 df (p 3.6e-32) ; K8 -> fullU LR 365.9 on 60 df (p 1.9e-45) 
  K8 surface, local maxima: new_x, y, height above the median; around each (|dx| < 0.025, |dy| < 0.04) cases, controls and their ratio / NEW's
     -0.065  -0.315 +0.27 | cases  391 controls   776 ratio 1.59
     -0.062   0.325 +0.11 | cases  321 controls   935 ratio 1.08
      0.005   0.008 +0.23 | cases  145 controls   310 ratio 1.48
      0.132  -0.152 +0.24 | cases  109 controls   507 ratio 0.68
      0.188   0.365 +0.34 | cases   43 controls   119 ratio 1.14
      0.235   0.072 +0.35 | cases   78 controls   126 ratio 1.95
  fullU surface, local maxima: new_x, y, height above the median; around each (|dx| < 0.025, |dy| < 0.04) cases, controls and their ratio / NEW's
     -0.192   0.172 +0.17 | cases    3 controls    11 ratio 0.86
     -0.175   0.075 +0.57 | cases   11 controls    48 ratio 0.72
     -0.172  -0.358 +0.23 | cases    0 controls     8 ratio 0.00
     -0.168   0.375 +0.19 | cases   11 controls    47 ratio 0.74
     -0.145  -0.142 +0.70 | cases    2 controls     9 ratio 0.70
     -0.138  -0.505 +0.96 | cases   73 controls   144 ratio 1.60
     -0.065   0.295 +0.19 | cases  331 controls   907 ratio 1.15
     -0.058   0.205 +0.00 | cases  302 controls  1120 ratio 0.85
     -0.058  -0.292 +0.47 | cases  522 controls   946 ratio 1.74
      0.035   0.012 +0.39 | cases  145 controls   361 ratio 1.27
      0.132  -0.242 +0.38 | cases  591 controls  1313 ratio 1.42
      0.138  -0.488 +0.70 | cases   72 controls   233 ratio 0.98
      0.165   0.405 +0.45 | cases   40 controls   147 ratio 0.86
      0.218   0.282 +0.41 | cases   43 controls   108 ratio 1.26
      0.238   0.085 +0.45 | cases   73 controls   120 ratio 1.92
  y (heel front)     O     K8  fullU
  (-0.32,-0.3]     604   1.03   0.92
  (-0.3,-0.28]     757   1.09   0.94
  (-0.28,-0.26]    910   1.13   0.99
  (-0.26,-0.24]    756   0.98   0.89
  (-0.24,-0.22]    698   1.04   1.00
  (-0.22,-0.2]     389   0.95   1.00
  (-0.2,-0.18]     182   0.83   1.00
  (-0.18,-0.16]    133   0.83   1.14
  (-0.16,-0.14]     82   0.61   0.91
  (-0.14,-0.12]     56   0.42   0.63
  (-0.12,-0.1]      77   0.66   0.94
  (-0.1,-0.08]     108   0.86   1.11
  (-0.08,-0.06]    176   0.95   1.11
  (-0.06,-0.04]    230   1.02   1.09

== B. 5-fold cross-validation by shoe (seed 2026)
new K8       24 cols: held-out log score -100632.0 | held-out band O/E 0.64, cut 250 0.79, peak window 0.64 (band: A 0.31, B 0.88)
new full     34 cols: held-out log score -100611.8 | held-out band O/E 0.66, cut 250 0.81, peak window 0.65 (band: A 0.32, B 0.91)
new full_5x9 76 cols: held-out log score -100614.3 | held-out band O/E 0.75, cut 250 0.88, peak window 0.76 (band: A 0.37, B 1.02)
new fullU    84 cols: held-out log score -100588.9 | held-out band O/E 0.92, cut 250 1.04, peak window 0.91 (band: A 0.46, B 1.25)
new: held-out log score of fullU minus K8 +43.1 (SE 20.7, z 2.1; 338 of 631 shoes gain); full +22.9 (SE 18.1, z 1.3; 339 of 631 shoes gain); full_5x9 +25.4 (SE 13.4, z 1.9; 341 of 631 shoes gain) (63 s)
  K8, held-out cells (E >= 15): heel front y (-0.28, -0.04] 24 cells, sum z^2 136, |z| > 3: 7; the other 89 cells, sum z^2 195, |z| > 3: 3
  fullU, held-out cells (E >= 15): heel front y (-0.28, -0.04] 24 cells, sum z^2 37, |z| > 3: 1; the other 89 cells, sum z^2 137, |z| > 3: 1
  K8, held-out O/E with shoe-bootstrap intervals: band 0.64 [0.56, 0.73]; cut250 0.79 [0.69, 0.89]; peak 0.64 [0.51, 0.77]; band_A 0.31 [0.21, 0.42]; band_B 0.88 [0.76, 0.99]
  fullU, held-out O/E with shoe-bootstrap intervals: band 0.92 [0.80, 1.05]; cut250 1.04 [0.90, 1.17]; peak 0.91 [0.73, 1.10]; band_A 0.46 [0.31, 0.61]; band_B 1.25 [1.08, 1.41]
old K8       24 cols: held-out log score -67682.1 | held-out band O/E 0.87, cut 250 1.03, peak window 1.02
old full     34 cols: held-out log score -67677.7 | held-out band O/E 0.89, cut 250 1.04, peak window 1.03
old full_5x9 76 cols: held-out log score -67700.8 | held-out band O/E 0.90, cut 250 1.03, peak window 0.99
old fullU    84 cols: held-out log score -67694.0 | held-out band O/E 0.93, cut 250 1.01, peak window 0.94
old: held-out log score of fullU minus K8 -11.8 (SE 12.8, z -0.9; 190 of 386 shoes gain); full -16.3 (SE 11.8, z -1.4; 190 of 386 shoes gain); full_5x9 +6.8 (SE 8.7, z 0.8; 196 of 386 shoes gain) (38 s)
  K8, held-out cells (E >= 15): heel front y (-0.28, -0.04] 24 cells, sum z^2 22, |z| > 3: 0; the other 88 cells, sum z^2 159, |z| > 3: 1
  fullU, held-out cells (E >= 15): heel front y (-0.28, -0.04] 23 cells, sum z^2 18, |z| > 3: 0; the other 87 cells, sum z^2 85, |z| > 3: 0
  K8, held-out O/E with shoe-bootstrap intervals: band 0.87 [0.77, 0.97]; cut250 1.03 [0.93, 1.13]; peak 1.02 [0.84, 1.19]
  fullU, held-out O/E with shoe-bootstrap intervals: band 0.93 [0.82, 1.03]; cut250 1.01 [0.92, 1.11]; peak 0.94 [0.78, 1.10]

== C. NEW: one surface for both groups? Band O/E, pooled vs own-group fits
K8       pooled fit: all 0.64 (O 348, E 542.6), A 0.31 (O 70, E 226.8), B 0.88 (O 278, E 315.8) | own-group fits: A 0.31 (O 70, E 224.0), B 0.87 (O 278, E 321.1)
full_5x9 pooled fit: all 0.75 (O 348, E 464.0), A 0.36 (O 70, E 192.0), B 1.02 (O 278, E 272.0) | own-group fits: A 0.39 (O 70, E 178.4), B 0.94 (O 278, E 295.7)
fullU    pooled fit: all 0.92 (O 348, E 377.5), A 0.45 (O 70, E 154.1), B 1.24 (O 278, E 223.4) | own-group fits: A 0.63 (O 70, E 111.1), B 0.97 (O 278, E 285.6)
Warning message:
In coxph.fit(X, Y, istrat, offset, init, control, weights = weights,  :
  Loglik converged before variable  30 ; coefficient may be infinite. 

t5_basis_y.R done in 150 s

real	2m32.216s
user	2m26.734s
sys	0m5.436s
exit 0
```

**Reading.**
- **Reproduced.** Every number of the review: in sample the band O/E 0.64, 0.66, 0.92 and cut 250 0.79, 0.81, 1.04 for K8, the full tensor and the finer basis; LR 271.3 on 50 df from the full tensor to the finer basis, AIC lower by 171.3; held out +43.1 against K8 and +22.9 against the full tensor, the held-out band 0.92 and cut 250 1.04, group A 0.46 and group B 1.25; on OLD -11.8 against K8 (the review's -11.9 is the difference of the rounded scores, -67694.0 + 67682.1); own-group fits on the step-3 basis A 0.31, B 0.87. The K8, full and 5x9 rows of section A equal `t5_gof.R` section H (10, 3 and 2 cells beyond |z| 3; sum z^2 330, 248, 207), so the port computes what the earlier probe computed.
- **The mechanism.** NEW's step-3 y knots (-0.348, -0.218, 0.078, 0.202, 0.315; quantiles of the case-control rows) leave a gap of 0.30 in y, about 89 pixel rows, from -0.218 to 0.078: the heel front and the lower midfoot, where NEW's density first falls (O/E of the step-3 fit 0.83, 0.83, 0.61, 0.42, 0.66 in 0.02 bins from y -0.20 to -0.10) and then rises (the dense rows above the band). One cubic piece spans that whole stretch, and a single cubic, smooth at both ends, cannot follow a dip about 0.08 wide inside it: the fit bridges the dip, and on the right side the bridge forms the withdrawn local maximum. The nested basis adds knots at -0.262, -0.172 and 0.028 (from a separate check of the knots: `basis_knots()` plus `quantile(y, 1:10/11)` on each CSV) and follows the dip (1.00, 1.14, 0.91, 0.63, 0.94). It is the resolution in y that matters: the full tensor (main effects, the same knots) keeps cut 250 at 0.81, and the 5x9 tensor, which adds x knots and only four y knots, at 0.88.
- **The map.** On the step-3 basis the NEW CML surface has the six local maxima of the committed GLMM map (`t5_gof.R` C), and the data around five of them are dense (raw case/control ratio 1.08-1.95 of NEW's), but around (0.132, -0.152) the ratio is 0.68: the withdrawn maximum. On the finer basis it is gone; the right-side maximum moves down to the dense heel pads ((0.132, -0.242), ratio 1.42). But the finer full tensor has 15 local maxima, and five of them lie at the left edge of the data on 0 to 11 cases (for example (-0.145, -0.142) at +0.70 on 2 cases and 9 controls, and (-0.175, 0.075) at +0.57 on 11 and 48): a free full tensor extrapolates where the data are sparse (the left edge that K8 pins, A-116). So a finer basis is not a better map by itself; T6's finer-y maps show the data density or mask the cells with little data (plan T6 (d)).
- **Out of sample.** The held-out O/E of the finer basis (band 0.92 [0.80, 1.05], cut 250 1.04 [0.90, 1.17], the window 0.91 [0.73, 1.10]) contain 1, those of the step-3 basis (0.64 [0.56, 0.73], 0.79 [0.69, 0.89], 0.64 [0.51, 0.77]) exclude it. The held-out log score gains +43.1 (SE 20.7 over shoes, z 2.1, 338 of 631 shoes gain; the SE treats the shoes as independent, which the shared training fits of a fold make approximate) against K8 and +22.9 (SE 18.1, z 1.3) against the full tensor: a real but modest overall gain, as one would expect from 60 more coefficients whose estimation noise costs a little everywhere. The held-out cell residuals show where the fit improves: most at the heel front (24 cells with y in (-0.28, -0.04]: sum z^2 136 to 37, cells beyond |z| 3 from 7 to 1), less elsewhere (89 cells: 195 to 137). An intermediate version of the probe also split the log-score gain by the place of the case (band cases -122.2, heel-front cases -221.9, the other cases +265.0); that split cannot localize anything, because a model that correctly lowers the band's probability costs the band's own cases and, through each shoe's normalization, pays every other case of the shoe. It was replaced by the cell residuals.
- **OLD.** The step-3 basis has no heel-front misfit on OLD (held-out heel-front cells: sum z^2 22 on 24 cells; 18 with the finer basis), and the finer basis does not improve OLD's held-out log score (-11.8, SE 12.8; -16.3, SE 11.8, against the full tensor). It does lower OLD's held-out cell residuals elsewhere (159 to 85 on 88 cells). So the review's "the step-3 basis is adequate on OLD" holds for the heel front and by the log score, not by every measure: the knot question (D-015) concerns both datasets.
- **No GLMM refit.** I also tried the step-3 GLMM refitted on NEW with the finer basis (glmer, 85 fixed effects, step 3's `nlminbwrap`), as a section D of the probe run with `--glmm` in the background (`<scratch>/t5fix2/basis_y_glmm.out`). It had not finished after 2 h 26 min of fitting (149 min wall in all) and was stopped (exit 143): one deviance evaluation takes 0.72 s here (timed separately, at the committed GLMM's theta and intercept with the 84 other coefficients near 0), and nlminb differentiates the 86 parameters numerically, about a minute per gradient. Section D was removed from the committed probe. The CML surfaces above answer the map question; the GLMM maps on a finer basis belong to T6 (A-119 (2)), which should budget hours for such a fit (background), or use a faster first look.
- **What stands of A-114: the design heterogeneity, as a separate finding.** On the step-3 surface both groups are overpredicted in the band (A 0.31, B 0.88; group B alone on the same basis 0.87), so "the pooled surface sits between the two groups" was false there. On the finer basis it does sit between them (held out: A 0.46 [0.31, 0.61], B 1.25 [1.08, 1.41]); neither interval contains 1, so one surface does not fit both groups: a failure of the common-surface assumption (R1 point 4). Own-group fits on the finer basis bring group B to 0.97 and group A only to 0.63; one coefficient of an own-group fit on the finer basis did not converge ("Loglik converged before variable 30; coefficient may be infinite", printed in section C), a sign that 84 coefficients are many for one group, so 0.63 is indicative. Group A's own dip seems too sharp, or not at the same y on all its soles, for 15 knots.
- **So** (A-119): the misfit of the NEW map and of cut 250 at the heel front is mainly the y resolution of the step-3 basis on NEW, not sole design as such; the design heterogeneity is real (the OLD prints of the same soles replicate it, section 4) and is reported separately (A-120). T6 adds a finer-y-knot sensitivity of the maps and CI cuts on both datasets, T7 the same for Part 2, and the knots go to Naomi and Micha (D-015).

## 3. How the design heterogeneity is read (A-120)

The review's second major finding is about the reading, not a number, and it is right on each point:
- **A false choice.** Revision 13 told T7 to word a band-driven rejection "as a design effect, not as model failure", and section 9 said "cells there will reject for design reasons". If the RAC intensity depends on sole design, that *is* a failure of the model: step 3 assumes one intensity surface for all shoes with a single shoe-specific level, which reviewer 1 point 4 criticizes. Section 2 adds a second component: on NEW the basis is too coarse there.
- **Circular splits.** Group A (ids 1-343 and 442-490) was found by the reviewer in the O/E per block of 49 ids *inside the band* (`t5_gof.R` section E). Any comparison of groups A and B in the band (T6's maps with and without group A, T7's residuals by group) is therefore circular there and can only describe.
- **What is confirmatory.** The OLD prints of the 50 group-A `same_shoe` reprints were not used to choose the groups. Their band holds 7 RAC pixels on 6 shoes where 33.7 are expected at their own density: 0.16 [0.06, 0.31] of it, against 0.94 [0.73, 1.17] for the 319 other OLD shoes (section 4). A confirmatory split in T6 or T7 needs a design classification made from the images without looking at the RAC locations (meeting question 6).
- **Wear or detection.** The replication shows that the deficit belongs to the soles, not to how the NEW collection was marked. It cannot show *why*: fewer RACs may form where the sole meets the ground little (the waist, heel breast or shank), or RACs there may be under-marked inside moulded logos or hatched shanks, where the texture hides them. T8 and the paper name both.

Where it changed: A-114 (superseded in part), A-120 (new); plan T6 content (d), T7 step 4 (the note of revision 13 replaced), section 9 ("Also reported" and the interpretation guard), T8 (the sole-design limitation), section 12 (the classification without the RAC locations), F79 (retitled "Design heterogeneity at the heel front"), R34; the T5 results (correction 2, section 7 markers, the residual table's group rows), the T5 review-fix results (readings F, G, H and "What this means"), the T5 QA README (the two band figures are descriptive in the band).

## 4. Shoe-bootstrap intervals beside the binomial z (A-120)

`docs/qa/T5/probes/t5_boot.R` ports the reviewer's `stat_checks.R` section 3 and `reprint_boot.R` with the same seeds and the same order of draws, and adds cuts 110 and 190 and OLD's band and cut 250 (OLD on its own seed, so the NEW draws are unchanged):
```bash
time Rscript docs/qa/T5/probes/t5_boot.R
```
```
== 1. O/E of the committed GLMMs (BLUPs held fixed), shoe bootstrap
new: 631 shoes, B = 2000
  cut 250 pooled                     0.802 [0.700, 0.906] (O 304, E 378.8)
  cut 250 right peak (new_x 0.135)   0.704 [0.554, 0.852] (O 63, E 89.5)
  peak window (0.135, -0.155)        0.651 [0.520, 0.780] (O 104, E 159.7)
  band, all NEW                      0.650 [0.563, 0.735] (O 348, E 535.7)
  band, group A (post hoc)           0.317 [0.216, 0.428] (O 70, E 221.1)
  band, group B                      0.884 [0.770, 0.998] (O 278, E 314.6)
  cut 110 pooled                     1.009 [0.958, 1.060] (O 1169, E 1158.2)
  cut 190 pooled                     1.004 [0.942, 1.064] (O 886, E 882.8)
old: 386 shoes, B = 2000
  band, all OLD                      0.892 [0.774, 0.994] (O 368, E 412.7)
  cut 250 pooled                     1.053 [0.948, 1.148] (O 357, E 339.2)

== 2. band RAC density / the group's own, shoe bootstrap (B = 4000, seed 3)
OLD prints of the 50 group-A reprints: 0.164 [0.057, 0.310] (50 shoes; RAC px in the band 7, expected at the shoes' own density 33.7; shoes with a band RAC 6) 
OLD shoes that are not same_shoe partners: 0.942 [0.726, 1.166] (319 shoes; RAC px in the band 330, expected at the shoes' own density 323.1; shoes with a band RAC 91) 
NEW group A (post hoc): 0.239 [0.157, 0.327] (392 shoes; RAC px in the band 70, expected at the shoes' own density 249.5; shoes with a band RAC 37) 
NEW group B: 1.005 [0.849, 1.163] (239 shoes; RAC px in the band 278, expected at the shoes' own density 263.3; shoes with a band RAC 118) 
band RAC px per OLD reprint shoe that has one: 1, 1, 1, 2, 1, 1 

t5_boot.R done in 16 s

real	0m19.025s
user	0m16.620s
sys	0m2.409s
exit 0
```
Every interval of the review is reproduced to the last digit. They keep every conclusion about the size of the deficits: cut 250 lies above the data by about a quarter (the interval excludes 1), more at its right peak; the band deficit of group A is large; group B's band O/E 0.88 [0.77, 1.00] touches 1; cuts 110 and 190 fit. The binomial z values of `t5_gof.R` (-12.4, -5.4, -4.6) overstate the precision: they ignore the dependence of RACs within a shoe and the differences between shoes. The intervals hold the fit fixed, so they do not carry its estimation error. In the plan and the results the z values are now labelled binomial and descriptive, group A's z as post hoc, and group B (5,881 cases) is no longer set beside OLD (13,249 cases) by its sum of z^2.

## 5. The cost of K8: the direct cluster-robust Wald (A-116 corrected)

`t5_inference.R` section 3 no longer multiplies the LR by 0.57 (the robust-to-model ratio of the 24-coefficient W of section 2, which is a different hypothesis). It refits the full tensor with `cluster(shoe)` (the same estimates) and tests the 10 main-effect coefficients directly, with the model-based and the robust variance, and gives the generalized design effects (the eigenvalues of naive.var^-1 var on those 10 coefficients) and the first- and second-order Rao-Scott corrections of the LR (the reviewer's `stat_checks.R` section 1):
```bash
time Rscript docs/qa/T5/probes/t5_inference.R
```
```
== 1. convergence of the NEW GLMM (lme4 1.1.38 )
check.conv.nobsmax: 10000 ; nobs 83090 ; derivatives stored: FALSE 
deviance at the stored optimum 83138.243772, -2 logLik 83138.243772; central-difference gradient (step 0.0001): |d/dtheta| 0.0237, max |d/dbeta| 0.0051 (term 23), median |d/dbeta| 0.0022

== 2. model-based and cluster(shoe)-robust Wald, Efron CML
old: Efron W model-based 394.2, cluster-robust 234.4 (ratio 0.595); robust/model SE median 1.132, max 1.373; cases 13249; W per case: exact CML 0.0318, GLMM (RX) 0.0323, Efron model-based 0.0298, robust 0.0177
new: Efron W model-based 580.9, cluster-robust 329.0 (ratio 0.566); robust/model SE median 1.064, max 1.211; cases 19990; W per case: exact CML 0.0288, GLMM (RX) 0.0293, Efron model-based 0.0291, robust 0.0165

== 3. the cost of K8 (Efron CML: step-3 basis vs full tensor)
old: K8 24 coef, loglik -64623.366; full 34 coef, loglik -64603.845; LR 39.04 on 10 df (p 2.5e-05, model-based)
   the 10 main effects of the full tensor, cluster(shoe) (max |estimate - the fit above| 0.0e+00): Wald model-based 38.74 (p 2.8e-05), cluster-robust 32.47 (p 0.00033); generalized design effects mean 1.232, range 0.711-1.995; Rao-Scott LR / mean 31.70 (p 0.00045), second order 29.02 on 9.15 df (p 0.00071)
y band (decile)        x_L     x_R |   K8 L full L   diff |   K8 R full R   diff
[-0.502,-0.395]     -0.138   0.139 |  -0.16   0.02   0.18 |  -0.11  -0.13  -0.02
(-0.395,-0.298]     -0.139   0.152 |  -0.22  -0.10   0.12 |  -0.09  -0.20  -0.11
(-0.298,-0.222]     -0.140   0.158 |  -0.12  -0.07   0.06 |   0.12   0.10  -0.02
(-0.222,-0.00833]   -0.119   0.171 |   0.08   0.13   0.05 |   0.33   0.37   0.04
(-0.00833,0.095]    -0.130   0.210 |  -0.29  -0.20   0.09 |  -0.00  -0.02  -0.02
(0.095,0.165]       -0.155   0.217 |  -0.29  -0.14   0.16 |   0.05   0.03  -0.02
(0.165,0.228]       -0.161   0.212 |  -0.20  -0.10   0.10 |   0.16   0.15  -0.02
(0.228,0.295]       -0.158   0.195 |  -0.32  -0.23   0.09 |   0.04   0.05   0.01
(0.295,0.375]       -0.145   0.178 |  -0.43  -0.42   0.01 |  -0.29  -0.30  -0.01
(0.375,0.512]       -0.119   0.133 |  -0.16  -0.33  -0.18 |  -0.27  -0.30  -0.03
   full - K8 at the left edge: -0.18 to 0.18, |diff| > 0.1 in 5 of 10 bands; at the right edge: -0.11 to 0.04, |diff| <= 0.06 in 9 of 10
   O/E across the width (u = new_x / distance_shape), GLMM with BLUPs:
   u (-1,-0.95]       rows     21 cases     6 O/E 2.072 z   2.07
   u (-0.95,-0.85]    rows    370 cases    61 O/E 0.884 z  -1.14
   u (-0.85,-0.7]     rows   3784 cases   874 O/E 1.056 z   1.96
   u (-0.7,-0.4]      rows   8573 cases  2276 O/E 1.000 z  -0.01
   u (-0.4,0]         rows  10297 cases  2903 O/E 0.997 z  -0.18
   u (0,0.4]          rows  11212 cases  2812 O/E 1.010 z   0.63
   u (0.4,0.7]        rows   9989 cases  2384 O/E 0.976 z  -1.51
   u (0.7,0.85]       rows   5532 cases  1395 O/E 1.013 z   0.62
   u (0.85,0.95]      rows   2015 cases   530 O/E 0.988 z  -0.36
   u (0.95,1]         rows     56 cases     8 O/E 0.710 z  -1.20
new: K8 24 coef, loglik -96639.219; full 34 coef, loglik -96591.898; LR 94.64 on 10 df (p 6.4e-16, model-based)
   the 10 main effects of the full tensor, cluster(shoe) (max |estimate - the fit above| 0.0e+00): Wald model-based 94.57 (p 6.6e-16), cluster-robust 87.98 (p 1.3e-14); generalized design effects mean 1.065, range 0.743-1.466; Rao-Scott LR / mean 88.86 (p 9e-15), second order 85.15 on 9.58 df (p 3e-14)
y band (decile)        x_L     x_R |   K8 L full L   diff |   K8 R full R   diff
[-0.515,-0.412]     -0.138   0.135 |  -0.09   0.40   0.49 |  -0.06  -0.01   0.05
(-0.412,-0.312]     -0.137   0.149 |  -0.08  -0.21  -0.13 |   0.02  -0.13  -0.15
(-0.312,-0.245]     -0.146   0.160 |  -0.08  -0.18  -0.11 |   0.16   0.11  -0.05
(-0.245,-0.0617]    -0.131   0.158 |   0.01   0.16   0.15 |   0.21   0.27   0.07
(-0.0617,0.0783]    -0.125   0.205 |  -0.21  -0.03   0.18 |   0.13   0.12  -0.01
(0.0783,0.155]      -0.152   0.219 |  -0.20  -0.03   0.18 |   0.23   0.20  -0.03
(0.155,0.218]       -0.160   0.214 |  -0.05  -0.01   0.04 |   0.25   0.26   0.01
(0.218,0.288]       -0.159   0.199 |  -0.08  -0.03   0.05 |   0.16   0.17   0.01
(0.288,0.372]       -0.147   0.181 |  -0.14   0.01   0.14 |   0.13   0.14   0.01
(0.372,0.525]       -0.117   0.137 |   0.06   0.16   0.09 |   0.13   0.12  -0.01
   full - K8 at the left edge: -0.13 to 0.49, |diff| > 0.1 in 7 of 10 bands; at the right edge: -0.15 to 0.07, |diff| <= 0.06 in 8 of 10
   O/E across the width (u = new_x / distance_shape), GLMM with BLUPs:
   u (-1,-0.95]       rows     16 cases     7 O/E 2.606 z   2.98
   u (-0.95,-0.85]    rows    565 cases    82 O/E 0.778 z  -2.66
   u (-0.85,-0.7]     rows   6854 cases  1590 O/E 1.088 z   4.00
   u (-0.7,-0.4]      rows  13767 cases  3556 O/E 1.014 z   0.99
   u (-0.4,0]         rows  15598 cases  3786 O/E 0.966 z  -2.65
   u (0,0.4]          rows  17198 cases  3972 O/E 1.018 z   1.33
   u (0.4,0.7]        rows  16211 cases  3803 O/E 0.996 z  -0.34
   u (0.7,0.85]       rows   9161 cases  2181 O/E 0.957 z  -2.53
   u (0.85,0.95]      rows   3685 cases   992 O/E 1.032 z   1.23
   u (0.95,1]         rows     35 cases    21 O/E 1.821 z   3.62

== 4. the level of the maps (plan K3, D-009)
old: RAC px per S px 0.003247 (13249 / 4080720); map mean 0.001302 (map / empirical 0.401); MEAN_OFFSET -4.6143, exp(-sigma^2/2) 0.619
   predicted RAC total / observed: each shoe's BLUP 0.999; b = 0 0.636; b = 0 x exp(+sigma^2/2) 1.028; b = 0 x exp(-sigma^2/2) 0.394
new: RAC px per S px 0.003448 (19990 / 5796891); map mean 0.001771 (map / empirical 0.514); MEAN_OFFSET -4.4655, exp(-sigma^2/2) 0.685
   predicted RAC total / observed: each shoe's BLUP 0.995; b = 0 0.706; b = 0 x exp(+sigma^2/2) 1.029; b = 0 x exp(-sigma^2/2) 0.484
NEW / OLD: empirical RAC px per S px 1.062; map mean 1.361

t5_inference.R done in 31 s

real	0m33.719s
user	0m32.285s
sys	0m1.429s
exit 0
```
Sections 1, 2 and 4 print the same lines as in `docs/tests/T5-review-fixes-results.md` section 4 (compared line by line with the pasted block; only the two section-3 header lines changed, and the 10 OLD u-bin lines that the earlier paste omitted match its omission note). **Reading:** the direct cluster-robust Wald of the 10 main effects is 32.47 on OLD (p 3.3e-4) and 87.98 on NEW (p 1.3e-14), with design effects of mean 1.23 (OLD) and 1.07 (NEW); the Rao-Scott corrections agree (31.70, 88.86). Both are far beyond chi^2_10 (99.9% point 29.6): the statistics review's original "both far beyond" was right, and the T5 review fixes' "OLD 22.3, p 0.014, not far" was wrong, because the deflation was not a test of this hypothesis.

## 6. What sigma^2 measures (A-115 corrected)

No new computation: the numbers are those of `t5_sigma2.R` (T5 review-fix results section 4.5). The committed no-offset sigma^2 (OLD 0.960, NEW 0.756) tracks log n_i, the number of RAC pixels of the shoe (the BLUPs correlate 0.992 and 0.989 with it). A count is density times contact area, so this sigma^2 is the between-shoe spread of the **RAC counts**, and var log(100/px) (OLD 0.098, NEW 0.121) enters it. The offset refit removes the contact area: only its sigma^2 (NEW 0.641, OLD 0.979) is the between-shoe spread of the **RAC density** per contact pixel. Neither is spatial. Corrected in A-115 (appended), the D-008 update, plan F75, F82 and T6 (c) (T6 compares the offset refits as the density pair), correction 6 and the section 6 reading of the T5 results, the review-fix results 4.5, and the LOG.

## 7. `tests/r/test_new_outputs.R` with a missing CSV (A-113 corrected)

**Before** (the test of `2f49373`, in a fresh clone of `3bab0a6` with `processed_data/new/dataCC_distance_new.csv` moved away; `<scratch>/t5fix2/scenarios.sh`):
```
# processed_data/new/dataCC_distance_new.csv moved away; Rscript tests/r/test_new_outputs_prev.R (= git show 2f49373:tests/r/test_new_outputs.R)
FAIL step 1 : cannot open the connection 
Warning message:
In file(con, "rb") :
  cannot open file '<scratch>/t5fix2/clone_scen/processed_data/new/dataCC_distance_new.csv': No such file or directory
FAIL step 2 : cannot open the connection 
Warning message:
In file(file, "rt") :
  cannot open file '<scratch>/t5fix2/clone_scen/processed_data/new/dataCC_distance_new.csv': No such file or directory
Error in data$new_x : object of type 'closure' is not subsettable
Calls: basis_knots -> quantile
Execution halted
exit 1 (10.6 s)
```
The engineer's finding, reproduced: `dist` was never assigned, so it resolved to `stats::dist`, and the top-level `basis_knots(dist)` stopped the script; 8 checks never ran and no summary was printed (exit 1, so not a false pass).

**The fix** (`3bab0a6`): `dataCC` and the step-2 CSV (renamed `dist_csv`) start as NULL; step 2 reads its CSV before it needs `dataCC`; the knots are computed inside each step-3 check through `step2_csv()` and `old_basis()`, which stop with "step-2 CSV unavailable", "OLD step-2 CSV unavailable" (and step 2 with "step-1 CSV unavailable") when a CSV could not be read; the LF check of the seven NEW CSVs became a check of its own, so a missing step-2 CSV is no longer a step-1 failure. The test has 11 checks.

**After**, the same clone:
```
# the same CSV moved away; Rscript tests/r/test_new_outputs.R (3bab0a6)
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw records, the erase list, the stamp mask (>= 8 shoes, no pixel swept) and the RAC pixels = the pixel counts; every control on S and on no RAC pixel 
FAIL LF line endings : missing: dataCC_distance_new.csv 
FAIL step 2 : cannot open the connection 
Warning message:
In file(file, "rt") :
  cannot open file '<scratch>/t5fix2/clone_scen/processed_data/new/dataCC_distance_new.csv': No such file or directory
FAIL step 3 GLMM : step-2 CSV unavailable: dataCC_distance_new.csv could not be read (see the step 2 check) 
FAIL step 3 CML : step-2 CSV unavailable: dataCC_distance_new.csv could not be read (see the step 2 check) 
FAIL OLD-basis NEW_X_NS_XY : step-2 CSV unavailable: dataCC_distance_new.csv could not be read (see the step 2 check) 
FAIL OLD-basis CML_MODEL : step-2 CSV unavailable: dataCC_distance_new.csv could not be read (see the step 2 check) 
FAIL negative control : step-2 CSV unavailable: dataCC_distance_new.csv could not be read (see the step 2 check) 
PASS step 5: wald_test_new.csv W = 585.8888, df 24, vcov RX = the W of the committed GLMM 
PASS steps 4-6: the 8 NEW PDFs and their PNG twins exist (existence only; a stale figure is not detected here: after a change of a NEW model rerun docs/qa/T5/probes/t5_new_rerun.sh --oldbasis --png until T8's e2e test compares them) 
PASS no collision: 48 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the old_added lists and README files 
Error: 7 check(s) failed: LF line endings; step 2; step 3 GLMM; step 3 CML; OLD-basis NEW_X_NS_XY; OLD-basis CML_MODEL; negative control
Execution halted
exit 1 (12.8 s)
```

Every check now runs: the five checks that need the step-2 CSV FAIL with that reason, the LF check names the missing file, the summary lists the 7 failed checks, exit 1.

The OLD step-2 CSV `processed_data/dataCC_distance.csv` moved away instead (only the two OLD-basis checks need it):
```
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw records, the erase list, the stamp mask (>= 8 shoes, no pixel swept) and the RAC pixels = the pixel counts; every control on S and on no RAC pixel 
PASS LF line endings: the 7 NEW CSVs of steps 1, 2 and 5 have LF only 
PASS step 2: (n_Acc, x, y, shoe) = dataCC; finite distances, horiz_dist >= min_dist, |new_x| <= distance_shape; every distance_shape a half-width of the prototype in its own frame; 631 contour records; step 2 recomputed for all 631 shoes (83090 rows, 8.1 s) from the committed contour writes both step-2 CSVs byte for byte (new_x in [-0.1850, 0.2317]) 
PASS step 3 GLMM: converged, 25 fixed effects, 631 groups, 83090 rows; fitted on the committed CSV (its basis = the knots of the CSV, y = n_Acc, groups = the shoe codes, getME(X) = the step-3 design rebuilt from the CSV); sigma^2 0.7556 
PASS step 3 CML: 24 coefficients, 19990 events; fitted on the committed CSV (its basis = the knots of the CSV, status = n_Acc, strata = the shoe codes, model.matrix = the step-3 design without the intercept) 
FAIL OLD-basis NEW_X_NS_XY : OLD step-2 CSV unavailable: dataCC_distance.csv could not be read (cannot open the connection) 
FAIL OLD-basis CML_MODEL : OLD step-2 CSV unavailable: dataCC_distance.csv could not be read (cannot open the connection) 
PASS negative control: the model-CSV comparisons reject a CSV with one shoe's new_x moved by a pixel (X), a case and a control swapped (y, status) and a row moved to another shoe (groups, strata) 
PASS step 5: wald_test_new.csv W = 585.8888, df 24, vcov RX = the W of the committed GLMM 
PASS steps 4-6: the 8 NEW PDFs and their PNG twins exist (existence only; a stale figure is not detected here: after a change of a NEW model rerun docs/qa/T5/probes/t5_new_rerun.sh --oldbasis --png until T8's e2e test compares them) 
PASS no collision: 48 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the old_added lists and README files 
Error: 2 check(s) failed: OLD-basis NEW_X_NS_XY; OLD-basis CML_MODEL
Execution halted
exit 1 (30.1 s)
```
The step-1 CSV `processed_data/new/dataCC_new.csv` moved away instead (step 2 now says why it cannot compare; the step-3 checks still compare the models with the step-2 CSV and pass):
```
FAIL step 1 : cannot open the connection 
Warning message:
In file(file, "rt") :
  cannot open file '<scratch>/t5fix2/clone_scen/processed_data/new/dataCC_new.csv': No such file or directory
FAIL LF line endings : missing: dataCC_new.csv 
FAIL step 2 : step-1 CSV unavailable: dataCC_new.csv could not be read (see the step 1 check) 
PASS step 3 GLMM: converged, 25 fixed effects, 631 groups, 83090 rows; fitted on the committed CSV (its basis = the knots of the CSV, y = n_Acc, groups = the shoe codes, getME(X) = the step-3 design rebuilt from the CSV); sigma^2 0.7556 
PASS step 3 CML: 24 coefficients, 19990 events; fitted on the committed CSV (its basis = the knots of the CSV, status = n_Acc, strata = the shoe codes, model.matrix = the step-3 design without the intercept) 
PASS OLD-basis NEW_X_NS_XY (A-112): on the OLD basis and fitted on the committed CSV (y, shoe, X) 
PASS OLD-basis CML_MODEL (A-112): on the OLD basis and fitted on the committed CSV (status, strata, X, n) 
PASS negative control: the model-CSV comparisons reject a CSV with one shoe's new_x moved by a pixel (X), a case and a control swapped (y, status) and a row moved to another shoe (groups, strata) 
PASS step 5: wald_test_new.csv W = 585.8888, df 24, vcov RX = the W of the committed GLMM 
PASS steps 4-6: the 8 NEW PDFs and their PNG twins exist (existence only; a stale figure is not detected here: after a change of a NEW model rerun docs/qa/T5/probes/t5_new_rerun.sh --oldbasis --png until T8's e2e test compares them) 
PASS no collision: 48 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the old_added lists and README files 
Error: 3 check(s) failed: step 1; LF line endings; step 2
Execution halted
exit 1 (18.5 s)
```
All files back (`git status` empty), the unchanged clone:
```
PASS step 1: 631 shoes, 100 controls each, 19990 cases (the distinct RAC pixels), 83090 rows; S recomputed from the raw records, the erase list, the stamp mask (>= 8 shoes, no pixel swept) and the RAC pixels = the pixel counts; every control on S and on no RAC pixel 
PASS LF line endings: the 7 NEW CSVs of steps 1, 2 and 5 have LF only 
PASS step 2: (n_Acc, x, y, shoe) = dataCC; finite distances, horiz_dist >= min_dist, |new_x| <= distance_shape; every distance_shape a half-width of the prototype in its own frame; 631 contour records; step 2 recomputed for all 631 shoes (83090 rows, 8.0 s) from the committed contour writes both step-2 CSVs byte for byte (new_x in [-0.1850, 0.2317]) 
PASS step 3 GLMM: converged, 25 fixed effects, 631 groups, 83090 rows; fitted on the committed CSV (its basis = the knots of the CSV, y = n_Acc, groups = the shoe codes, getME(X) = the step-3 design rebuilt from the CSV); sigma^2 0.7556 
PASS step 3 CML: 24 coefficients, 19990 events; fitted on the committed CSV (its basis = the knots of the CSV, status = n_Acc, strata = the shoe codes, model.matrix = the step-3 design without the intercept) 
PASS OLD-basis NEW_X_NS_XY (A-112): on the OLD basis and fitted on the committed CSV (y, shoe, X) 
PASS OLD-basis CML_MODEL (A-112): on the OLD basis and fitted on the committed CSV (status, strata, X, n) 
PASS negative control: the model-CSV comparisons reject a CSV with one shoe's new_x moved by a pixel (X), a case and a control swapped (y, status) and a row moved to another shoe (groups, strata) 
PASS step 5: wald_test_new.csv W = 585.8888, df 24, vcov RX = the W of the committed GLMM 
PASS steps 4-6: the 8 NEW PDFs and their PNG twins exist (existence only; a stale figure is not detected here: after a change of a NEW model rerun docs/qa/T5/probes/t5_new_rerun.sh --oldbasis --png until T8's e2e test compares them) 
PASS no collision: 48 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the old_added lists and README files 
ALL PASS test_new_outputs
exit 0 (31.9 s)
```
The mutants of A-113, with the fixed test (record 591 of the NEW contour shifted one column right, `mutate_contour.py` of the T5 review fixes: `record 591: rows all shifted one column right; contour px before 703, after 703; bytes changed 1232`):
```
# M1: the mutated contour, step 2 not rerun
[... 2 PASS line(s) omitted: as in the unchanged run ...]
FAIL step 2 : step 2 recomputed from the committed contour differs from dataCC_distance_temp_new.csv and dataCC_distance_new.csv; the rows of 1 shoe code(s) differ (first: 591): rerun NEW steps 2-6 
[... 8 PASS line(s) omitted: as in the unchanged run ...]
Error: 1 check(s) failed: step 2
Execution halted
exit 1 (32.2 s)
# M2: M1, then RAC_DATASET=new bash tools/run_pipeline.sh --steps 2 (exit 0, 30 s; git status: the contour and both step-2 CSVs modified)
[... 3 PASS line(s) omitted: as in the unchanged run ...]
FAIL step 3 GLMM : the step-3 GLMM was not fitted on dataCC_distance_new.csv (basis, X differ): rerun NEW steps 3-6 
FAIL step 3 CML : the step-3 CML was not fitted on dataCC_distance_new.csv (basis, X differ): rerun NEW steps 3-6 
FAIL OLD-basis NEW_X_NS_XY : the OLD-basis NEW_X_NS_XY refit was not fitted on dataCC_distance_new.csv (X differ): rerun tools/fit_oldbasis_new.R NEW_X_NS_XY 
FAIL OLD-basis CML_MODEL : the OLD-basis CML_MODEL refit was not fitted on dataCC_distance_new.csv (X differ): rerun tools/fit_oldbasis_new.R CML_MODEL 
[... 4 PASS line(s) omitted: as in the unchanged run ...]
Error: 4 check(s) failed: step 3 GLMM; step 3 CML; OLD-basis NEW_X_NS_XY; OLD-basis CML_MODEL
Execution halted
exit 1 (31.4 s)
```
M1 fails at step 2 and names shoe 591; M2 passes step 2 and fails at both step-3 models and both OLD-basis refits, as with the test of the T5 review fixes. In the work tree: ALL PASS (31.2 s, under the load of a running GLMM refit; section 9.1 for the suite).

## 8. Smaller items

### 8.1 The figures are checked for existence only (reproducibility minor 1)
As planned: T8's `tests/e2e/test_new_rerun.sh` re-renders steps 4-6, redraws the PNG twins and refits the OLD-basis models and compares them with HEAD, starting from `docs/qa/T5/probes/t5_new_rerun.sh --oldbasis --png` (A-113 (5)). Until then that probe is rerun after any change of a NEW model; the test's PASS line now says so, and so do the test's header, `docs/tests/README.md` and the A-113 correction. Not rerun in this task: no NEW model or figure changed (the reproducibility reviewer re-rendered NEW steps 4-6 at `2f49373`: the 8 PDFs equal the committed ones without their dates, and the 16 PNG twins redraw byte for byte).

### 8.2 NEW step 0 has no platform pin (reproducibility minor 2)
Kept as recorded in A-117: the kernel pin stops another thread count or kernel, not another platform; a venv-wind NEW step 0 would rewrite 14 of 631 contour records in place, which `git status`, `tests/rebuild_new.sh` and (when step 2 changes) `tests/r/test_new_outputs.R` reveal. Shlomo may still ask for a `sys.platform` pin with an override for `docs/qa/T4/probes/t4_win_new_step0.sh`. The usage of `t5_stamp_figure.py` now lists the scratch route (`tests/rebuild_new.sh --keep`) first, because an in-place NEW step 0 is the risky one (section 8.4).

### 8.3 The fast suite's budget (A-121)
The suite took 6 min 40 s on the idle machine at `1a330ed` and 6 min 54 s here at the final commit (7 min 17 s earlier with one core busy; section 9.1); it was already over "< 5 min" at T5 (5 min 47 s to 6 min 15 s). Moving `test_compare.R`'s `Random()` equivalence (30-75 s) to a slow tier alone would not bring it under 5 minutes, and that check guards `fit_common_basis()`, on which T6 builds; so the documented budget follows the measured time instead: about 7 min idle, with 10 min idle as the ceiling beyond which a test moves to a slow tier (plan section 4.5, `docs/tests/README.md`).

### 8.4 Nits
- `docs/tests/T5-review-fixes-results.md` section 7: "the robust W of 4.2" is now "the robust W of section 4.2".
- `docs/qa/T5/probes/t5_stamp_figure.py`: the usage lists `RAC_SCRATCH=<scratch> bash tests/rebuild_new.sh --keep` first (it builds the gitignored `freq_min_18_new.png` in a scratch copy) and warns that an in-place NEW step 0 rewrites the committed contour, with the same bytes only on this WSL venv (A-117); flake8 clean.
- `tests/r/test_no_hardcoding.R`: the header paragraph is rewrapped (no line over 79 characters); the test passes (ALL PASS, 36 R/Rmd files).

## 9. Gates

The only code change of this task is `tests/r/test_new_outputs.R` (and a comment of `tests/r/test_no_hardcoding.R`), on no OLD step's path; the other changes are probes under `docs/qa/` and documents. The OLD gates ran on a clean clone of `3bab0a6`, the final code commit (`<scratch>/t5fix2/gate_clone`, `git status` empty), as the reproducibility reviewer asked.

### 9.1 The fast suite
```bash
time bash tests/run_all.sh        # early run: code at 3bab0a6, the probes and docs of this task uncommitted; a GLMM refit of section 2 on one core
```
```
== sha256 committed_79247d8 (Tier A, 24 files)
== sha256 old_baseline (11 OLD artifacts)
== sha256 old_added_t2 (the 2 OLD files T2 added)
[... 295 lines omitted: the checksum checks and the verbose unittest output ...]
Ran 184 tests in 113.956s

OK (skipped=3)
[... 146 lines omitted: the PASS lines of the 17 R scripts (test_new_outputs.R as in section 7) and the lint runs, flake8: 88 files, shellcheck: 17 files ...]
== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         1s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS       143s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        39s  Rscript tests/r/test_compare.R
PASS        22s  Rscript tests/r/test_compare_glmm_fits.R
PASS         4s  Rscript tests/r/test_compare_models.R
PASS        47s  Rscript tests/r/test_distances_vectorized.R
PASS        19s  Rscript tests/r/test_figures_png.R
PASS        29s  Rscript tests/r/test_new_outputs.R
PASS         3s  Rscript tests/r/test_no_hardcoding.R
PASS         2s  Rscript tests/r/test_old_regression.R
PASS        36s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         1s  Rscript tests/r/test_profile.R
PASS        55s  Rscript tests/r/test_profile_sentinels.R
PASS         9s  Rscript tests/r/test_run_manifest.R
PASS         1s  Rscript tests/r/test_step5_variant.R
PASS         9s  Rscript tests/r/test_sticker_masks.R
PASS         5s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python files)
PASS         5s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS

real	7m17.236s
user	7m44.878s
sys	0m51.498s
exit 0
```
ALL PASS: 184 Python tests (3 skipped live checks), 17 R scripts, flake8 88 files, shellcheck 17 files, the work tree unchanged by the tests; 7 min 17 s with one core busy.

Rerun at the final docs commit `e93c706` on the idle machine (no other job running; the only later commit adds these lines to the documents, which no test reads):
```bash
time bash tests/run_all.sh        # at e93c706
```
```
[... 447 lines omitted: as above (Ran 184 tests in 106.174s, OK (skipped=3); flake8: 88 files; shellcheck: 17 files) ...]
== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         1s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS       140s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        36s  Rscript tests/r/test_compare.R
PASS        21s  Rscript tests/r/test_compare_glmm_fits.R
PASS         4s  Rscript tests/r/test_compare_models.R
PASS        45s  Rscript tests/r/test_distances_vectorized.R
PASS        17s  Rscript tests/r/test_figures_png.R
PASS        28s  Rscript tests/r/test_new_outputs.R
PASS         2s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        33s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         1s  Rscript tests/r/test_profile.R
PASS        49s  Rscript tests/r/test_profile_sentinels.R
PASS         8s  Rscript tests/r/test_run_manifest.R
PASS         2s  Rscript tests/r/test_step5_variant.R
PASS         8s  Rscript tests/r/test_sticker_masks.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python files)
PASS         5s  shellcheck (all shell scripts)
PASS         0s  work tree unchanged by the tests (no file created or modified)
ALL PASS

real	6m53.703s
user	6m5.226s
sys	0m47.349s
exit 0
```
ALL PASS at the final commit, 6 min 54 s on the idle machine.

### 9.2 OLD regression
Steps 1-6, then step 0 (the gate compares them in separate runs, A-081), from the clean clone:
```bash
cd <scratch>/t5fix2/gate_clone      # git clone of the repo, git checkout 3bab0a6; git status --short: empty
time RAC_SCRATCH=<scratch>/t5fix2/gates bash tests/regress_old.sh --steps 1-6 --keep
```
```
<scratch>/t5fix2/gates/regress_old_6Hu25m

== regress_old.sh --steps 1-6: <scratch>/t5fix2/gates/regress_old_6Hu25m
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
step1       115.034934903  0
step2       23.942936586   0
step3_glmm  270.323812390  0
step3_cml   217.099568906  0
step4_glmm  14.290695728   0
step4_cml   14.123317296   0
step5       27.064797720   0
step6       20.222146810   0
ALL PASS

real	11m56.304s
user	11m2.137s
sys	0m54.115s
exit 0
```
The run folder's `source.txt` and the model comparison (`logs/compare_models.txt`, every field `identical()` to Tier B):
```
steps=1-6
head=3bab0a66a6a039aa8ccbabfd219845b050786582
python=/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python
work tree changes (git status --short):
```
```
fixef         n=25   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov          n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
vcov_rx       n=625  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
theta         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
sigma2        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
varcorr       n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
loglik        n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
deviance      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
nobs          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
ngrps         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
conv          n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=   NA
optimizer     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
cml_coef      n=24   identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_vcov      n=576  identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_loglik    n=2    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_n         n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_nevent    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_iter      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
cml_method    n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=   NA       rel=   NA
wald_glmm     n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_glmm_rx  n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
wald_cml      n=1    identical=TRUE  all.equal(tol=0)=TRUE  max|diff|=    0       rel=    0
```
```bash
time RAC_SCRATCH=<scratch>/t5fix2/gates bash tests/regress_old.sh --steps 0
```
```
<scratch>/t5fix2/gates/regress_old_aOzeMs

== regress_old.sh --steps 0: <scratch>/t5fix2/gates/regress_old_aOzeMs
result  check                                          detail
PASS    pipeline run                                   every step exit 0, every output regenerated
PASS    step 0 OpenBLAS threads and kernel = baseline  16 threads, kernel Haswell
PASS    step 0 contour = Tier B (CRLF)                 data/contour_Active_Contour.txt sha256 e18d50df5da9...
PASS    step 0 intermediates = Tier B                  1556 npy/png files, all equal
PASS    live check test_snake_old_regression           logs/live_snake.txt
timings (s):
step   seconds        exit
step0  725.786789762  0
ALL PASS

real	13m42.646s
user	112m48.657s
sys	1m29.205s
exit 0
```
Both gates ALL PASS at `3bab0a6`: the five step-1/2 CSVs = Tier A byte for byte, `shoe_codes.csv` = `old_added_t2`, the GLMM and the CML `identical()` to Tier B in all 22 dumped fields, the 8 normalized PDFs = Tier B, Wald W 427.7804472165 = Tier B, both live R checks; step 0 with 16 threads and the Haswell kernel, the contour = Tier B (`e18d50df...`) and all 1,556 intermediates = Tier B, the live snake check. (Load up to about 17 during step 0, which ran beside a GLMM refit of section 2.)

Committed OLD files, in the work tree:
```bash
sha256sum --quiet -c tests/baseline/committed_79247d8.sha256 && echo "Tier A (24 files): OK"
sha256sum --quiet -c tests/baseline/old_baseline.sha256 && echo "old_baseline (11): OK"
sha256sum --quiet -c tests/baseline/old_added_t2.sha256 && echo "old_added_t2 (2): OK"
git diff --stat a6011ca HEAD
```
```
Tier A (24 files): OK
old_baseline (11): OK
old_added_t2 (2): OK
 tests/r/test_new_outputs.R   | 141 ++++++++++++++++++++++++++++++-------------
 tests/r/test_no_hardcoding.R |  11 ++--
 2 files changed, 105 insertions(+), 47 deletions(-)
```
(At `3bab0a6`, before the probe and docs commits.) No OLD output, raw data file, profile value, contour code, Rmd, `config.R` or `statistical_model/R` file changed in this task.

## 10. Files, timings, open points
| Kind | Files |
|---|---|
| test | `tests/r/test_new_outputs.R` (every check runs when a CSV is missing; the LF check on its own; 11 checks), `tests/r/test_no_hardcoding.R` (header rewrapped) |
| probes | `docs/qa/T5/probes/t5_basis_y.R` (new: the step-3 basis against finer bases, in sample, in 5-fold cross-validation by shoe, own-group fits, `--glmm`), `t5_boot.R` (new: shoe-bootstrap intervals), `t5_inference.R` (section 3: the direct cluster-robust Wald of the K8 cost), `t5_stamp_figure.py` (usage order) |
| docs | this file; `docs/decisions.md` (A-119 to A-121, D-015; corrections appended to A-113, A-115, A-116; A-114 superseded in part, marked in its heading; a new update of D-008); the plan (revision 14); `docs/tests/T5-new-pipeline-results.md` and `docs/tests/T5-review-fixes-results.md` (second-correction markers; a corrections block at the top of the latter; "of section 4.2"); `docs/progress/LOG.md` (this task's entry; markers in the 23:10 and 02:10 entries); `docs/tests/README.md` (the budget, the test's behaviour); `docs/qa/T5/README.md` (the two new probes, the band figures descriptive); `docs/README.md` and `docs/tests/T5-results.md` (the T5 review-fix results listed) |

No OLD output, raw data file, profile value, contour code, Rmd or `statistical_model/R` file changed; no NEW output changed (the probes write nothing).

| What | Time |
|---|---|
| `t5_basis_y.R` (sections A-C) | 2 min 32 s (the final run; 2 min 31 s to 3 min 34 s in the earlier runs, some under load) |
| `t5_basis_y.R --glmm` (the stopped GLMM refit) | stopped after 2 h 26 min of fitting, 149 min 10 s wall in all |
| `t5_boot.R` / `t5_inference.R` | 19 s / 34 s |
| `test_new_outputs.R`: the scenarios in a clean clone | 10.6-32.2 s each; M2's step-2 rerun 30 s |
| `regress_old.sh --steps 1-6` / `--steps 0` (clean clone of `3bab0a6`) | 11 min 56 s / 13 min 43 s |
| `run_all.sh` | 6 min 54 s at `e93c706`, idle; 7 min 17 s early (one core busy) |

**Open points.**
- T5 step 3b (shoe bootstrap and cluster-robust variances on both datasets) is still to do.
- For Naomi and Micha (D-015, meeting issue 8.4): the knots of step 3. On NEW the 5 y knots leave a 0.30 gap across the heel front, and a finer y basis fixes the misfit there out of sample; on OLD there is no heel-front misfit, but the finer basis lowers OLD's held-out cell residuals elsewhere. Keep the knots and report the sensitivity, or choose knots by a stated rule (a new OLD baseline).
- For Micha and Naomi (A-120): the design heterogeneity at the heel front is real (the OLD prints of the same soles replicate it), its mechanism is open (less wear or under-marked RACs), and a confirmatory split needs a design classification made without the RAC locations (meeting question 6).
- For Shlomo: A-121 (the fast suite's budget) and A-117 (no platform pin of NEW step 0), both kept as recorded unless he asks otherwise.
- For T6: the full-tensor and the finer-y maps and CI cuts on both datasets (A-116, A-119); sigma^2 compared as the offset refits' density pair (A-115 corrected); group splits descriptive (A-120).
- For T7: the finer-y sensitivity of Part 2 (section 9 "Also reported"); residuals by group descriptive; a band rejection worded "the one-surface model does not hold across sole designs, and/or the step-3 basis is too coarse there" (A-120).
- For T8: the e2e rerun compares the figures, the PNG twins and the OLD-basis refits (A-113 (5)); the report names wear and detection, and the basis resolution, under the limitations.
