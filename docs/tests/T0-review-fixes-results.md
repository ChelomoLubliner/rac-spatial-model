# T0 review fixes: results

**Date:** 2026-11-05. **Task:** fix the review findings on T0-architecture (one critical, five major, thirteen minor). **Agent:** T0 fix pass. No pipeline code or data changed; the changes are in `docs/` only.

Every finding was first checked against the data and the code before the plan was changed. Each check below shows the exact command and its real output: quick commands were re-run by the assembly script for this file, and long runs are pasted from their saved output files. `<scratchpad>` stands for the session scratch directory `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`. Python runs use the thesis venv interpreter with `-I -B`.

## 1. Findings, verification and fixes

| # | Finding (severity) | Verified? | Evidence (section of this file) | Fix (plan section, decision) |
|---|---|---|---|---|
| 1 | Some NEW shoes are OLD shoes (critical) | **Yes, and more than reported**: 34 candidates (the statistician's 16 included, same partners), 30 likely by eye | 4.1 (R5-R8), 4.2, 7 | F25, F26, K10; T3 steps 3b-3d; section 9 primary set; T6; R24; D-012, A-024; meeting note correction box |
| 2 | Regional X^2 tilted toward the regional model (major) | Yes: in-sample X^2 = 7e-24 on the fitting partition | 4.3 (S2) | Section 9: log score primary, the real 2022 model as comparator, grid test, "identically 0 by construction"; A-025 |
| 3 | phi read as dependence (major) | Yes: phi_0 = 0.968 < 1 under independence; heterogeneity alone 3.44, clumps alone 1.84 | 4.3 (S3) | Section 9: phi vs phi_0, within-shoe pair test; T7 tests relabelled; A-026 |
| 4 | K8 edge restriction (major) | Yes: eta = -2.271582 on both edges, X rebuilt == `getME(X)` | 4.3 (S1) | K8, F28; T5 step 4; section 9 full-tensor sensitivity; R26; A-027 |
| 5 | Model-based variance under dependence (major) | Yes: SE ratio median 1.132, max 1.373; W 394.20 -> 234.41; exact method cannot carry a robust variance | 2, 3, 4.3 (S4) | K9, F29; T5 step 3b (bootstrap both models), T6 robust equality Wald; R27; A-028 |
| 6 | Per-shoe data quality (major) | Yes: all counts reproduced (e.g. NEW 23 shoes < 0.5, 112/177/286/420/498) | 4.1 (R3), 7 | F27; T3 step 3c; section 9 primary set; R25; D-013, A-029 |
| m1 | F14 one direction only | Yes: 160 above, 161 below (OLD); NEW 152/151 | 5.1 | F14 restated, probe fixed; A-039 |
| m2 | F6 0.8479 from the multiply form | Yes: R form 0.847821, 2 RACs differ (shoes 46, 239) | 4.1 (R1), 5.2 | F6, probe D fixed; A-032 |
| m3 | 500-RAC OLD sample in `test_matches_r_aspix` | Yes: P(miss both) = 0.9262 | 4.1 (R1) | T3 test uses all 13,287 OLD RACs and pins both RACs |
| m4 | Empty `RAC_DATASET` | Yes, in R and Python | 6.1, 4.3 (S6) | 4.1, 4.4, T2 tests; F33; A-033 |
| m5 | `$SCRATCH` undefined | Yes | 6.2 | 4.5, T1, R30; A-034 |
| m6 | `test_no_hardcoding` misses dataset constants | Yes (lines 98, 52, 55-59) | 6.2 | T2 literal list + sentinel tests; A-035 |
| m7 | No `excluded_shoes` | Yes | (plan text) | 4.3 field and indexing, T2 RecordMap, T4; A-031 |
| m8 | `!reports/*.html` | Yes: the March report exists, untracked, ignored | 6.2 | T8, section 5; A-036 |
| m9 | Meeting note line numbers | Yes: 175 and 177 | 6.2 | T2 step 2; meeting note correction box |
| m10 | sigma^2 comparison confounded; exact offset | Yes: 0.0954 vs 0.1210 raw; max 0.0335 | 4.3 (S5), 6.3 | T6 content (c) + offset refits; F32; A-037 |
| m11 | F5 not calibration evidence; flat criterion | Yes: flat in x, sharp in y; the distance criterion is **not** sharper | 4.1 (R2) | F5, F30, T3 rule (ii) by bootstrap interval; A-032 |
| m12 | Log score weights; shoe pairs | Yes: top 10% hold 31.8%; 13 of 15 consecutive, sym <= 0.068 | 4.1 (R4, R6) | Section 9 log score; pair-resampling sensitivity; A-038 |
| m13 | No named primary test, no effect size, CML not validated, KS calibration | Accepted (design points) | none needed | Section 9 named primary analyses, effect sizes, CML secondary; T7 binomial checks; A-030 |

One reviewer statement is narrowed rather than adopted: the suggested sharper calibration criterion (mean distance from each RAC to the nearest contact pixel) was computed and has the same shape as the on-contact rate (4.1, R2), so it is kept as a cross-check, and the rule uses a shoe-bootstrap interval instead (A-032). The reviewer's cluster-robust suggestion for the CML cannot be applied to the exact fit (`survival` refuses it, section 3), so the exact CML gets a shoe bootstrap (A-028).

## 2. The statistician's cluster-robust CML check, re-run unchanged

```bash
cd /home/mehes/projects/rac-spatial-model && (date '+start %F %T'; s=$(date +%s); timeout 3000 Rscript <scratchpad>/review_stat/verify7.R; echo "exit $? in $(( $(date +%s) - s ))s") > <scratchpad>/t0fix/verify7_rerun.out 2>&1; cat <scratchpad>/t0fix/verify7_rerun.out
```

```text
start 2026-11-05 21:19:48
fit time (s): 2.2 
max |coef(robust fit) - coef(committed CML)| = 0.5890854 
max |naive SE - committed CML SE| = 0.5380335 
robust/model SE ratio: min 0.999 median 1.132 max 1.373 
CML Wald all 24 = 0: model-based W=394.20, cluster-robust W=234.41 (df 24)
exit 0 in 5s
```

All numbers of the review (max coefficient difference 0.589, SE ratio median 1.13 and max 1.37, W 394 -> 234) reproduce exactly.

## 3. Exact CML: robust variance and refit identity

First check (scratch script, `<scratchpad>/t0fix/exact_cml_check.R`, run in the background):

```bash
cd /home/mehes/projects/rac-spatial-model && (s=$(date +%s); timeout 1800 Rscript "<scratchpad>/t0fix/exact_cml_check.R"; echo "exit $? in $(( $(date +%s) - s ))s") > "<scratchpad>/t0fix/exact_cml_check.out" 2>&1 &   # background; later: cat "<scratchpad>/t0fix/exact_cml_check.out"
```

```text
committed CML method: exact  call:
coxph(formula = Surv(rep(1, 51849L), dat$n_Acc) ~ ns(dat$new_x, 
    knots = knots_new_x):ns(dat$y, knots = knotsy) + strata(shoe), 
    data = dat, method = "exact")
exact refit time (s): 189.3 
exact refit identical coef to committed: TRUE  max abs diff: 0 
score residuals ERROR: score residuals are not available for the exact method 
exact + cluster ERROR: robust variance plus the exact method is not supported 
exit 0 in 191s
```

The same check as a committed probe (`docs/qa/T0/probes/t0_review_cml.R`, background):

```bash
Q=docs/qa/T0/probes; (s=$(date +%s); timeout 1800 Rscript $Q/t0_review_cml.R > $Q/t0_review_cml.out 2>&1; echo "t0_review_cml.R exit $? in $(( $(date +%s) - s ))s" > <scratchpad>/t0fix/t0_review_cml_run.txt) &   # background; when done: cat <scratchpad>/t0fix/t0_review_cml_run.txt $Q/t0_review_cml.out
```

```text
t0_review_cml.R exit 0 in 192s
committed CML method: exact 
exact refit: 189.3 s; coefficients identical() to committed: TRUE; vcov identical(): TRUE | loglik identical(): TRUE 
score residuals of the exact fit: ERROR: score residuals are not available for the exact method 
exact method + cluster(shoe): ERROR: robust variance plus the exact method is not supported 
```

An exact refit on this machine reproduces the committed CML bit for bit (coefficients, `vcov`, `loglik`), which T1 will confirm from its own step-2 output. `survival` supports neither score residuals nor a robust variance for the exact method, so the exact CML needs a shoe bootstrap (189 s per fit).

## 4. Probes of this pass

### 4.1 `t0_review.py` (Python: R1-R8)

Run 1 (sections R1-R7) and run 2 (R8 added; R1-R7 re-run), both in the background:

```bash
PY=/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python; Q=docs/qa/T0/probes; (date '+start %F %T'; s=$(date +%s); timeout 3000 "$PY" -I -B $Q/t0_review.py "$PWD" "$PWD/docs/qa/T0" > $Q/t0_review.out 2>&1; echo "t0_review.py exit $? in $(( $(date +%s) - s ))s") > <scratchpad>/t0fix/t0_review_run.txt 2>&1 &   # run 1 (R1-R7); run 2 (R8 added) the same with t0_review_run2.txt, after cp $Q/t0_review.out <scratchpad>/t0fix/t0_review_run1.out and sha256sum of the run-1 PNGs into <scratchpad>/t0fix/review_png_run1.sha256; then cat both .txt
```

```text
start 2026-11-05 21:25:41
t0_review.py exit 0 in 261s
start 2026-11-05 21:35:59
t0_review.py exit 0 in 541s
```

Determinism: run 2 reproduces run 1 (R1-R7 output and all 29 PNGs of run 1):

```bash
diff -B <(sed '/=== R8/,$d' <scratchpad>/t0fix/t0_review_run1.out) <(sed '/=== R8/,$d' docs/qa/T0/probes/t0_review.out) && echo "R1-R7 identical apart from the blank line before the R8 header"; (cd docs/qa/T0 && sha256sum -c --quiet <scratchpad>/t0fix/review_png_run1.sha256 && echo "29 PNGs of run 1 byte-identical after run 2")
```

```text
R1-R7 identical apart from the blank line before the R8 header
29 PNGs of run 1 byte-identical after run 2
```

Output of run 2 (`docs/qa/T0/probes/t0_review.out`, verbatim):

```text

=== R1. exact R aspix (division form) vs multiply form
old: RACs=13287 on contact: R division form=0.847821 multiply form=0.847896; RACs mapped differently: 2
  shoe 46 x=np.float64(0.09425) y=np.float64(0.2): R (col, row)=(125, 138) multiply=(125, 137) on contact R=False multiply=True
  shoe 239 x=np.float64(-0.07) y=np.float64(-0.47346): R (col, row)=(175, 340) multiply=(174, 340) on contact R=True multiply=True
new: RACs=20013 on contact: R division form=0.807775 multiply form=0.807775; RACs mapped differently: 0
P(a random 500-RAC OLD sample misses both differing RACs) = 0.9262

=== R2. calibration criterion vs scale (NEW and OLD)
old scale on x (other axis 300; best offset within +-1.5 px for each scale):
  x scale 290: on-contact 0.8634 (drop 0.0182) | mean distance to contact 0.1739 px (rise 0.0208)
  x scale 292: on-contact 0.8702 (drop 0.0114) | mean distance to contact 0.1656 px (rise 0.0125)
  x scale 294: on-contact 0.8748 (drop 0.0068) | mean distance to contact 0.1595 px (rise 0.0064)
  x scale 296: on-contact 0.8775 (drop 0.0041) | mean distance to contact 0.1555 px (rise 0.0024)
  x scale 298: on-contact 0.8794 (drop 0.0022) | mean distance to contact 0.1533 px (rise 0.0002)
  x scale 300: on-contact 0.8816 (drop 0.0000) | mean distance to contact 0.1531 px (rise 0.0000)
  x scale 302: on-contact 0.8812 (drop 0.0005) | mean distance to contact 0.1547 px (rise 0.0016)
  x scale 304: on-contact 0.8777 (drop 0.0039) | mean distance to contact 0.1586 px (rise 0.0055)
  x scale 306: on-contact 0.8739 (drop 0.0078) | mean distance to contact 0.1652 px (rise 0.0121)
  x scale 308: on-contact 0.8645 (drop 0.0171) | mean distance to contact 0.1749 px (rise 0.0219)
  x scale 310: on-contact 0.8560 (drop 0.0256) | mean distance to contact 0.1886 px (rise 0.0355)
old scale on y (other axis 300; best offset within +-1.5 px for each scale):
  y scale 290: on-contact 0.7353 (drop 0.1463) | mean distance to contact 0.3972 px (rise 0.2441)
  y scale 292: on-contact 0.7603 (drop 0.1213) | mean distance to contact 0.3354 px (rise 0.1823)
  y scale 294: on-contact 0.7886 (drop 0.0930) | mean distance to contact 0.2754 px (rise 0.1223)
  y scale 296: on-contact 0.8216 (drop 0.0600) | mean distance to contact 0.2203 px (rise 0.0672)
  y scale 298: on-contact 0.8583 (drop 0.0233) | mean distance to contact 0.1756 px (rise 0.0226)
  y scale 300: on-contact 0.8816 (drop 0.0000) | mean distance to contact 0.1531 px (rise 0.0000)
  y scale 302: on-contact 0.8739 (drop 0.0078) | mean distance to contact 0.1662 px (rise 0.0132)
  y scale 304: on-contact 0.8342 (drop 0.0474) | mean distance to contact 0.2109 px (rise 0.0578)
  y scale 306: on-contact 0.7943 (drop 0.0873) | mean distance to contact 0.2750 px (rise 0.1219)
  y scale 308: on-contact 0.7688 (drop 0.1128) | mean distance to contact 0.3408 px (rise 0.1877)
  y scale 310: on-contact 0.7422 (drop 0.1395) | mean distance to contact 0.4103 px (rise 0.2572)
new scale on x (other axis 300; best offset within +-1.5 px for each scale):
  x scale 290: on-contact 0.8243 (drop 0.0118) | mean distance to contact 0.2523 px (rise 0.0158)
  x scale 292: on-contact 0.8298 (drop 0.0063) | mean distance to contact 0.2450 px (rise 0.0085)
  x scale 294: on-contact 0.8341 (drop 0.0020) | mean distance to contact 0.2400 px (rise 0.0035)
  x scale 296: on-contact 0.8359 (drop 0.0002) | mean distance to contact 0.2371 px (rise 0.0006)
  x scale 298: on-contact 0.8361 (drop 0.0000) | mean distance to contact 0.2365 px (rise 0.0000)
  x scale 300: on-contact 0.8355 (drop 0.0006) | mean distance to contact 0.2377 px (rise 0.0012)
  x scale 302: on-contact 0.8337 (drop 0.0024) | mean distance to contact 0.2404 px (rise 0.0039)
  x scale 304: on-contact 0.8314 (drop 0.0047) | mean distance to contact 0.2453 px (rise 0.0088)
  x scale 306: on-contact 0.8264 (drop 0.0097) | mean distance to contact 0.2535 px (rise 0.0170)
  x scale 308: on-contact 0.8203 (drop 0.0158) | mean distance to contact 0.2644 px (rise 0.0279)
  x scale 310: on-contact 0.8118 (drop 0.0243) | mean distance to contact 0.2798 px (rise 0.0433)
new scale on y (other axis 300; best offset within +-1.5 px for each scale):
  y scale 290: on-contact 0.7248 (drop 0.1106) | mean distance to contact 0.4582 px (rise 0.2205)
  y scale 292: on-contact 0.7467 (drop 0.0888) | mean distance to contact 0.3964 px (rise 0.1588)
  y scale 294: on-contact 0.7705 (drop 0.0649) | mean distance to contact 0.3388 px (rise 0.1011)
  y scale 296: on-contact 0.7986 (drop 0.0369) | mean distance to contact 0.2885 px (rise 0.0508)
  y scale 298: on-contact 0.8217 (drop 0.0137) | mean distance to contact 0.2532 px (rise 0.0156)
  y scale 300: on-contact 0.8355 (drop 0.0000) | mean distance to contact 0.2377 px (rise 0.0000)
  y scale 302: on-contact 0.8300 (drop 0.0055) | mean distance to contact 0.2494 px (rise 0.0118)
  y scale 304: on-contact 0.8020 (drop 0.0335) | mean distance to contact 0.2905 px (rise 0.0528)
  y scale 306: on-contact 0.7692 (drop 0.0663) | mean distance to contact 0.3511 px (rise 0.1134)
  y scale 308: on-contact 0.7401 (drop 0.0954) | mean distance to contact 0.4205 px (rise 0.1828)
  y scale 310: on-contact 0.7142 (drop 0.1213) | mean distance to contact 0.4984 px (rise 0.2608)

=== R3. per-shoe RAC on-contact rate (R aspix), flip and shift
old: shoes=386 per-shoe on-contact p5/p10/p25/p50=[0.584, 0.643, 0.778, 0.88]
  rate < 0.5: 6 shoes, 77 RACs (0.006 of all RACs)
  rate < 0.6: 22 shoes, 368 RACs (0.028 of all RACs)
  rate < 0.7: 55 shoes, 1257 RACs (0.095 of all RACs)
  shoes with >=10 RACs: 302; below 0.6 under every flip and shift (+-4 px): 2 (45 RACs): [35, 153]
  shift gain > 0.2: 35 of 302 shoes; > 0.1: 101; median gain 0.071
  flip raises the best rate by > 0.15: 0 shoes []
new: shoes=631 per-shoe on-contact p5/p10/p25/p50=[0.5, 0.571, 0.718, 0.829]
  rate < 0.5: 23 shoes, 514 RACs (0.026 of all RACs)
  rate < 0.6: 68 shoes, 1449 RACs (0.072 of all RACs)
  rate < 0.7: 135 shoes, 3259 RACs (0.163 of all RACs)
  shoes with >=10 RACs: 517; below 0.6 under every flip and shift (+-4 px): 5 (280 RACs): [112, 177, 286, 420, 498]
  shift gain > 0.2: 62 of 517 shoes; > 0.1: 196; median gain 0.077
  flip raises the best rate by > 0.15: 0 shoes []
  largest shift gain: shoe 599 (0.689)
OLD per-shoe p5 = 0.5841; NEW shoes below it: 66 (1403 RACs)
NEW examples:
 shoe  n  rate  best_shift  best_flip_shift
  112 76 0.408       0.474            0.289
  177 27 0.444       0.593            0.296
  286 40 0.350       0.500            0.350
  420 41 0.488       0.585            0.390
  498 96 0.458       0.562            0.417
  599 45 0.222       0.911            0.822

=== R4. concentration of RACs in heavy shoes
old: shoes=386 RACs=13287 share of RACs in the top 10% of shoes (38) = 0.364; max per shoe 309
new: shoes=631 RACs=20013 share of RACs in the top 10% of shoes (63) = 0.318; max per shoe 281

=== R5. overlap screen: every NEW shoe against every OLD shoe
  ... 100 NEW shoes screened
  ... 200 NEW shoes screened
  ... 300 NEW shoes screened
  ... 400 NEW shoes screened
  ... 500 NEW shoes screened
  ... 600 NEW shoes screened
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_screen_t0_old_vs_new.csv (631 rows)
best sym over all OLD shoes, quantiles p50/p90/p95/p99/max: [0.118, 0.25, 0.333, 0.5, 0.535]
second-best sym, quantiles p50/p90/p99/max: [0.1, 0.167, 0.333, 0.5]
flagged (n_new >= 5, sym >= 0.30, sym - second best >= 0.15): 26 NEW shoes, 1006 NEW RACs; image rank of the matched OLD shoe: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 4, 7, 9, 11, 43, 283]
 new  n_new  old  n_old   sym  matched    dx    dy  sym2  sym_med     r  img_rank  img_best  sym_img_best  null10_max
 469     36  212     43 0.535       24 -0.95 -1.11 0.111    0.028 0.948         1       212         0.535       0.061
 453     17  267     19 0.474        9 -1.60  0.44 0.118    0.037 0.885         1       267         0.474       0.059
 241     36  380     41 0.463       19 -0.17 -0.99 0.111    0.028 0.987         1       380         0.463       0.083
 452      9  113     12 0.417        5 -4.18  1.37 0.200    0.029 0.661         3       267         0.105       0.417
 531     24   67     36 0.417       15 -0.01 -3.23 0.086    0.042 0.669        43        66         0.034       0.042
 501     17   12      9 0.412        7  1.37 -1.28 0.118    0.040 0.878         1        12         0.412       0.059
 547     27   85     18 0.407       11 -3.51 -0.21 0.074    0.037 0.823         7        84         0.037       0.407
  96     34  194     40 0.375       15  1.19 -1.77 0.088    0.029 0.944         1       194         0.375       0.073
  34     67  217     38 0.373       25  0.44 -1.19 0.064    0.030 0.930         1       217         0.373       0.060
  20     48  299     70 0.371       26 -1.55 -3.43 0.120    0.022 0.805         9       309         0.021       0.371
 214     32  148     33 0.364       13 -0.30  0.36 0.118    0.031 0.899         1       148         0.364       0.091
 548     22   84     22 0.364        8 -1.24 -0.28 0.091    0.040 0.926         1        84         0.364       0.045
 359     30  357     31 0.355       11 -3.30  5.60 0.100    0.033 0.324       283        52         0.027       0.059
  86     40  338     37 0.350       14  0.88 -0.53 0.100    0.025 0.979         1       338         0.350       0.075
 294     25   24     26 0.346        9  0.70 -0.24 0.107    0.040 0.764        11       379         0.107       0.346
 556     30  247     17 0.333       10  2.88 -0.42 0.100    0.033 0.882         1       247         0.333       0.067
 245     18   91     14 0.333        6  2.06 -1.55 0.111    0.036 0.851         1        91         0.333       0.077
 297     60  121     33 0.333       20 -0.61 -0.86 0.117    0.033 0.938         1       121         0.333       0.083
  87     40  337     39 0.325       13 -2.15 -1.05 0.100    0.025 0.909         4        25         0.032       0.325
 619     30   81     37 0.324       12 -0.83 -0.12 0.105    0.033 0.876         1        81         0.324       0.061
 242     28  379     28 0.321        9 -0.84  1.46 0.107    0.036 0.964         1       379         0.321       0.073
 204    111    5    147 0.313       47  1.47 -1.51 0.081    0.018 0.981         1         5         0.313       0.072
 238     32  198     26 0.312       10 -1.37  0.24 0.135    0.031 0.982         1       198         0.312       0.094
 203    126    6    102 0.310       39 -0.03 -0.94 0.095    0.024 0.953         1         6         0.310       0.095
 532     17  335     33 0.303        9 -2.60  0.24 0.118    0.032 0.883         1       335         0.303       0.083
  58     50  322     33 0.300       15  0.44  0.64 0.080    0.020 0.964         1       322         0.300       0.080
statistician's rule with this code (image-best OLD shoe, sym >= 0.30 and > max over the next 10 image-similar + 0.15): 19 shoes: [34, 58, 86, 96, 203, 204, 214, 238, 241, 242, 245, 297, 453, 469, 501, 532, 548, 556, 619]
OLD shoes matched by more than one flagged NEW shoe: {}

=== R6. within-dataset screens (NEW-NEW, OLD-OLD)
new-new: best sym per shoe (>= 5 RACs) quantiles p50/p90/p99/max: [0.111, 0.167, 0.222, 0.286]
  top (sym, shoe, partner): [(0.286, 575, 291), (0.286, 496, 417), (0.286, 417, 496), (0.286, 291, 575), (0.222, 591, 451), (0.222, 519, 452)]
  NEW shoes with an image partner at r >= 0.95: 15; partner has a consecutive id: 13; RAC sym with the partner max=0.068
  pairs (shoe, partner, r, sym): [(66, 67, 0.961, 0.049), (67, 66, 0.961, 0.049), (79, 82, 0.952, 0.0), (82, 79, 0.952, 0.0), (190, 191, 0.958, 0.068), (191, 190, 0.958, 0.068), (241, 242, 0.962, 0.056), (242, 241, 0.962, 0.056), (254, 255, 0.95, 0.031), (255, 256, 0.958, 0.046), (256, 255, 0.958, 0.046), (354, 355, 0.954, 0.051), (355, 354, 0.954, 0.051), (472, 473, 0.968, 0.067), (473, 472, 0.968, 0.067)]
old-old: best sym per shoe (>= 5 RACs) quantiles p50/p90/p99/max: [0.111, 0.182, 0.285, 0.4]
  top (sym, shoe, partner): [(0.4, 277, 236), (0.4, 236, 277), (0.356, 278, 237), (0.356, 237, 278), (0.222, 374, 165), (0.222, 319, 12)]

=== R7. evidence images
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_469_212_old_vs_new.png NEW 469 vs OLD 212: sym=0.535 shift=(-0.95, -1.11) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_453_267_old_vs_new.png NEW 453 vs OLD 267: sym=0.474 shift=(-1.60, 0.44) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_241_380_old_vs_new.png NEW 241 vs OLD 380: sym=0.463 shift=(-0.17, -0.99) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_452_113_old_vs_new.png NEW 452 vs OLD 113: sym=0.417 shift=(-4.18, 1.37) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_531_67_old_vs_new.png NEW 531 vs OLD 67: sym=0.417 shift=(-0.01, -3.23) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_501_12_old_vs_new.png NEW 501 vs OLD 12: sym=0.412 shift=(1.37, -1.28) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_547_85_old_vs_new.png NEW 547 vs OLD 85: sym=0.407 shift=(-3.51, -0.21) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_96_194_old_vs_new.png NEW 96 vs OLD 194: sym=0.375 shift=(1.19, -1.77) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_34_217_old_vs_new.png NEW 34 vs OLD 217: sym=0.373 shift=(0.44, -1.19) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_20_299_old_vs_new.png NEW 20 vs OLD 299: sym=0.371 shift=(-1.55, -3.43) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_214_148_old_vs_new.png NEW 214 vs OLD 148: sym=0.364 shift=(-0.30, 0.36) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_548_84_old_vs_new.png NEW 548 vs OLD 84: sym=0.364 shift=(-1.24, -0.28) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_359_357_old_vs_new.png NEW 359 vs OLD 357: sym=0.355 shift=(-3.30, 5.60) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_86_338_old_vs_new.png NEW 86 vs OLD 338: sym=0.350 shift=(0.88, -0.53) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_294_24_old_vs_new.png NEW 294 vs OLD 24: sym=0.346 shift=(0.70, -0.24) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_556_247_old_vs_new.png NEW 556 vs OLD 247: sym=0.333 shift=(2.88, -0.42) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_245_91_old_vs_new.png NEW 245 vs OLD 91: sym=0.333 shift=(2.06, -1.55) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_297_121_old_vs_new.png NEW 297 vs OLD 121: sym=0.333 shift=(-0.61, -0.86) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_87_337_old_vs_new.png NEW 87 vs OLD 337: sym=0.325 shift=(-2.15, -1.05) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_619_81_old_vs_new.png NEW 619 vs OLD 81: sym=0.324 shift=(-0.83, -0.12) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_242_379_old_vs_new.png NEW 242 vs OLD 379: sym=0.321 shift=(-0.84, 1.46) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_204_5_old_vs_new.png NEW 204 vs OLD 5: sym=0.313 shift=(1.47, -1.51) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_238_198_old_vs_new.png NEW 238 vs OLD 198: sym=0.312 shift=(-1.37, 0.24) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_203_6_old_vs_new.png NEW 203 vs OLD 6: sym=0.310 shift=(-0.03, -0.94) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_532_335_old_vs_new.png NEW 532 vs OLD 335: sym=0.303 shift=(-2.60, 0.24) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair_58_322_old_vs_new.png NEW 58 vs OLD 322: sym=0.300 shift=(0.44, 0.64) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/control_354_219_old_vs_new.png NEW 354 vs OLD 219: sym=0.087 shift=(2.30, 2.99) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/control_57_196_old_vs_new.png NEW 57 vs OLD 196: sym=0.058 shift=(0.08, 0.04) px
/home/mehes/projects/rac-spatial-model/docs/qa/T0/new/low_contact_shoes_new.png shoes [112, 177, 286, 420, 498, 599] (green = RAC on contact under the R mapping, red = off contact)

=== R8. non-rigid prints: separate shifts for the front and back halves
NEW-NEW null, two-half sym, best per shoe (>= 5 RACs) quantiles p50/p90/p99/max: [0.143, 0.222, 0.333, 0.4]
  ... 100 NEW shoes screened
  ... 200 NEW shoes screened
  ... 300 NEW shoes screened
  ... 400 NEW shoes screened
  ... 500 NEW shoes screened
  ... 600 NEW shoes screened
rewrote /home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_screen_t0_old_vs_new.csv with the two-half columns
two-half rule (n_new >= 5, sym2h >= max(0.30, NEW-NEW null max) = 0.400, margin >= 0.15): 26 NEW shoes, 1004 NEW RACs
  also flagged by the rigid rule: 18; two-half only: [14, 15, 92, 100, 213, 295, 342, 358]; rigid only: [34, 58, 238, 294, 297, 531, 532, 619]
  same OLD partner under both rules: 18 of 18
 new  n_new  old  old2h   sym  sym2h  sym2h_2nd     r  img_rank
 547     27   85     85 0.407  0.667      0.111 0.823         7
 469     36  212    212 0.535  0.605      0.118 0.948         1
 241     36  380    380 0.463  0.561      0.139 0.987         1
 245     18   91     91 0.333  0.556      0.136 0.851         1
 359     30  357    357 0.355  0.548      0.118 0.324       283
  20     48  299    299 0.371  0.529      0.125 0.805         9
 453     17  267    267 0.474  0.526      0.133 0.885         1
 548     22   84     84 0.364  0.500      0.136 0.926         1
  96     34  194    194 0.375  0.500      0.118 0.944         1
 214     32  148    148 0.364  0.485      0.125 0.899         1
 342     38  166    166 0.263  0.474      0.105 0.985         1
 358     43  116    116 0.256  0.465      0.102 0.793         1
 204    111    5      5 0.313  0.449      0.108 0.981         1
  14     25   87     87 0.240  0.440      0.121 0.875         1
 295     51  189    189 0.263  0.439      0.098 0.987         1
 203    126    6      6 0.310  0.437      0.116 0.953         1
 100     69   73     73 0.261  0.435      0.087 0.880         1
  15     30   94     94 0.233  0.433      0.133 0.839         4
 242     28  379    379 0.321  0.429      0.129 0.964         1
  86     40  338    338 0.350  0.425      0.116 0.979         1
  87     40  337    337 0.325  0.425      0.125 0.909         4
 452      9  113    113 0.417  0.417      0.222 0.661         3
 501     17   12     12 0.412  0.412      0.167 0.878         1
 213     42  180    180 0.286  0.405      0.114 0.840         5
  92      5   63    103 0.200  0.400      0.200 0.497       226
 556     30  247    247 0.333  0.400      0.125 0.882         1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/old/pair_old_236_277.png OLD 236 vs OLD 277: sym=0.400 two-half 0.486
/home/mehes/projects/rac-spatial-model/docs/qa/T0/old/pair_old_237_278.png OLD 237 vs OLD 278: sym=0.356 two-half 0.384
```

### 4.2 `t0_review_pairs.py` (the candidates found only by the two-half statistic)

```bash
Q=docs/qa/T0/probes; s=$(date +%s); timeout 900 "$PY" -I -B $Q/t0_review_pairs.py "$PWD" "$PWD/docs/qa/T0" > $Q/t0_review_pairs.out 2>&1; echo "t0_review_pairs.py exit $? in $(( $(date +%s) - s ))s"; cat $Q/t0_review_pairs.out
```

```text
t0_review_pairs.py exit 0 in 21s
rigid rule: 26 shoes; two-half rule: 26; union: 34 NEW shoes, 1309 RACs (0.065 of all NEW RACs)
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_342_166_old_vs_new.png NEW 342 vs OLD 166: two-half sym=0.474 shifts front (1.12, -1.69), back (0.65, 0.18); image r=0.985 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_358_116_old_vs_new.png NEW 358 vs OLD 116: two-half sym=0.465 shifts front (-0.08, 2.79), back (1.10, 1.00); image r=0.793 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_14_87_old_vs_new.png NEW 14 vs OLD 87: two-half sym=0.440 shifts front (0.50, 3.52), back (-0.38, 0.03); image r=0.875 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_295_189_old_vs_new.png NEW 295 vs OLD 189: two-half sym=0.439 shifts front (-2.20, -1.01), back (-0.10, -2.05); image r=0.987 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_100_73_old_vs_new.png NEW 100 vs OLD 73: two-half sym=0.435 shifts front (1.23, 3.48), back (2.81, 2.13); image r=0.880 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_15_94_old_vs_new.png NEW 15 vs OLD 94: two-half sym=0.433 shifts front (-2.70, -0.79), back (-0.84, -1.55); image r=0.839 rank=4
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_213_180_old_vs_new.png NEW 213 vs OLD 180: two-half sym=0.405 shifts front (5.37, 0.75), back (2.46, -0.30); image r=0.840 rank=5
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_92_103_old_vs_new.png NEW 92 vs OLD 103: two-half sym=0.400 shifts front (-1.95, 5.27), back (6.23, -0.38); image r=0.497 rank=226
```

> **Correction (2026-11-06, second T0 review; A-041):** the `image r` and `rank` printed on every line above, and the "rigid sym" in the OLD tile label of every `pair2h_*` image, came from the CSV columns of the **rigid** partner. They are right for the 7 shoes whose two partners coincide, but not for NEW 92, whose drawn two-half partner is OLD 103: r 0.851, rank 5 (r 0.497, rank 226 belong to the rigid partner OLD 63). The probe was fixed and re-run; its output is in `docs/tests/T0-review2-fixes-results.md` section 2. The output above is kept as it was printed.

Comparison with the statistician's list (`<scratchpad>/review_stat/overlap_sym.csv`, their rule: n >= 5, sym >= 0.3, sym > max over the next 10 image-similar OLD shoes + 0.15):

```bash
python3 - <scratchpad>/review_stat/overlap_sym.csv docs/qa/T0/compare/overlap_screen_t0_old_vs_new.csv <<'PY'
import csv, sys
rev = list(csv.DictReader(open(sys.argv[1])))
mine = list(csv.DictReader(open(sys.argv[2])))
r16 = {int(r['new']): int(r['old']) for r in rev
       if int(r['n_new']) >= 5 and float(r['sym']) >= 0.3
       and float(r['sym']) > float(r['null_max']) + 0.15}
m26 = {int(r['new']): int(r['old']) for r in mine
       if int(r['n_new']) >= 5 and float(r['sym']) >= 0.30
       and float(r['sym']) - float(r['sym2']) >= 0.15}
print(f"statistician's list: {len(r16)} shoes; rigid rule here: {len(m26)}")
print('in both:', len(set(r16) & set(m26)), '| same OLD partner:',
      sum(r16[k] == m26[k] for k in set(r16) & set(m26)))
print("statistician's only:", sorted(set(r16) - set(m26)), "| here only:", sorted(set(m26) - set(r16)))
PY
```

```text
statistician's list: 16 shoes; rigid rule here: 26
in both: 16 | same OLD partner: 16
statistician's only: [] | here only: [20, 87, 203, 204, 294, 359, 452, 531, 547, 619]
```

### 4.3 `t0_review.R` (R: S1-S6)

```bash
Q=docs/qa/T0/probes; s=$(date +%s); timeout 900 Rscript $Q/t0_review.R > $Q/t0_review_R.out 2>&1; echo "t0_review.R exit $? in $(( $(date +%s) - s ))s"; cat $Q/t0_review_R.out
```

```text
t0_review.R exit 0 in 26s
=== S1. K8: ns(new_x):ns(y) without main effects
columns: 25; max |rebuilt X - getME(X)| = 0
boundary knots new_x: -0.1916667  0.2416667 | y: -0.5016667  0.5116667 
ns basis at its left boundary: new_x 0  y 0 
intercept = -2.271582
eta on the edge new_x = min (5 y values): -2.271582 -2.271582 -2.271582 -2.271582 -2.271582 
eta on the heel edge y = min (5 new_x values): -2.271582 -2.271582 -2.271582 -2.271582 -2.271582 
eta on the edge new_x = max (same 5 y): -2.271582 -1.07811 -1.221581 -1.21372 -3.607891 
eta on the toe edge y = max (same 5 new_x): -2.271582 -2.554992 -2.658025 -2.421676 -3.607891 
eta over the 51,849 dataCC rows: quantiles 1/10/50/90/99%: -2.238 -1.9 -1.491 -1.277 -1.166 
rows within 0.03 of the new_x = min edge: 200 (37 cases); within 0.03 of the heel edge: 569 (89 cases)
eta on those rows, quantiles 10/50/90%: new_x edge -2.067 -1.969 -1.918 | heel edge -2.211 -2.146 -2.088 
fixed effects of the full tensor (main effects + interaction): 35 

=== S2. regional theta fitted on the test partition: in-sample X^2
toy (40 shoes, 6 areas, N = 661): max |O_k - E~R_k| = 1.71e-11; X^2 = 7.26e-24; max |E~R - fitted(glm)| = 1.56e-09

=== S3. phi under independent multinomials; heterogeneity vs dependence
631 shoes with the real NEW n_i (N = 20013), K = 15, 2000 replicates:
  (a) independent, shoe-specific pi_i (Dirichlet, alpha = 30), X^2 with the true pi_i: mean 13.429, exact E[X^2] = 13.550, K - 1 = 14, phi = 0.9592, exact phi_0 = 0.9679
  (b) the same independent data, X^2 with the common pi0 (heterogeneity ignored): mean 48.19, phi = 3.44
  (c) clumped RACs (dependence), common pi0, no heterogeneity: mean 25.71, phi = 1.84

=== S4. CML: cluster-robust variance needs Efron ties
committed CML method: exact 
exact + cluster(shoe): robust variance plus the exact method is not supported 
efron + cluster(shoe) fit: 1.9 s
max |coef(efron) - coef(committed exact)| = 0.5891
robust / model SE ratio (efron): min 0.999 median 1.132 max 1.373 
Wald all 24 = 0 (efron fit): model-based W = 394.20, cluster-robust W = 234.41; committed exact CML model-based W = 420.67

=== S5. offsets
OLD var(log(100/px)) (committed cleaned counts) = 0.0978
OLD max |log(100/px) - log(100/(px - cases))| = 0.0335 (shoe 385: px 9321, cases 307)
raw (uncleaned) contact px: var(log(100/px)) OLD (386) = 0.0954, NEW (631) = 0.1210

=== S6. Sys.getenv() for RAC_DATASET
unset: [old]
set to the empty string: []
```

## 5. The two T0 probes the reviewers asked to fix

### 5.1 `t0_probe.R`: float window in both directions, real `write.csv`/`read.csv` round trip

```bash
Q=docs/qa/T0/probes; s=$(date +%s); timeout 900 Rscript $Q/t0_probe.R > $Q/t0_probe_R.out 2>&1; echo "t0_probe.R exit $? in $(( $(date +%s) - s ))s"; git diff --no-color $Q/t0_probe_R.out
```

```text
t0_probe.R exit 0 in 10s
diff --git a/docs/qa/T0/probes/t0_probe_R.out b/docs/qa/T0/probes/t0_probe_R.out
index a6478dd..ff8d6a4 100644
--- a/docs/qa/T0/probes/t0_probe_R.out
+++ b/docs/qa/T0/probes/t0_probe_R.out
@@ -59,9 +59,14 @@ logical(0) && TRUE  -> NA
 logical(0) && FALSE -> FALSE 
 
 === float semantics of abs(dy) < 0.01 in dataCC_distance_2.Rmd
-|drow| = 2: pairs with abs(dy) < 0.01: 393 of 393
-|drow| = 3: pairs with abs(dy) < 0.01: 160 of 392
-|drow| = 4: pairs with abs(dy) < 0.01: 0 of 391
+row_shoe = 395: y values changed by the round trip: 263 of 395; second round trip identical: TRUE
+  |drow| = 2: pairs with abs(dy) < 0.01: data row above the contour row 393 of 393, below 393 of 393
+  |drow| = 3: pairs with abs(dy) < 0.01: data row above the contour row 160 of 392, below 161 of 392
+  |drow| = 4: pairs with abs(dy) < 0.01: data row above the contour row 0 of 391, below 0 of 391
+row_shoe = 367: y values changed by the round trip: 245 of 367; second round trip identical: TRUE
+  |drow| = 2: pairs with abs(dy) < 0.01: data row above the contour row 365 of 365, below 365 of 365
+  |drow| = 3: pairs with abs(dy) < 0.01: data row above the contour row 152 of 364, below 151 of 364
+  |drow| = 4: pairs with abs(dy) < 0.01: data row above the contour row 0 of 363, below 0 of 363
 
 === legacy stamp sweep (dataCC_1.Rmd lines 93-136) on NEW dims
 new t=8: >=t px=29536 | sweep with legacy bound 300: ERROR: subscript out of bounds | with bound col_shoe=255: kept px=29532 removed=4
```

Only the float-window section changed; the manual Wald (W = 428.6933, df 24) and everything else are reproduced.

### 5.2 `t0_probe.py`: section D in the exact R division form; NEW images renamed

```bash
git mv docs/qa/T0/new_superposition.png docs/qa/T0/new/superposition_new.png; git mv docs/qa/T0/new_sheet_16_racs.png docs/qa/T0/new/sheet_16_racs_new.png; (cd docs/qa/T0 && sha256sum old_prototypes.png old_rmask_stamps.png new/superposition_new.png new/sheet_16_racs_new.png | tee <scratchpad>/t0fix/t0_png_before.sha256); s=$(date +%s); timeout 900 "$PY" -I -B $Q/t0_probe.py "$PWD" "$TH/contour_algorithm" "$PWD/docs/qa/T0" > $Q/t0_probe.out 2>&1; echo "t0_probe.py exit $? in $(( $(date +%s) - s ))s"; (cd docs/qa/T0 && sha256sum -c <scratchpad>/t0fix/t0_png_before.sha256); git diff --no-color $Q/t0_probe.out
```

```text
7de8663d8a15e381162f98b1b2a6e651ac10cc293390611641d6af6733afbd7a  old_prototypes.png
41aa4b10cb13d5b01eb4dd0e96c5bc7e8ca9781f4f9f2797a3b39ec4b244baa9  old_rmask_stamps.png
6153807e4672240721318cd5cf90e00767f60ac18f6e31ee6d781e1f0bdf1619  new/superposition_new.png
dbf06a98873cc3ffba7ed018d2dbc6e2806c7087bca99c370eeb62ce35c71ecb  new/sheet_16_racs_new.png
t0_probe.py exit 0 in 62s
old_prototypes.png: OK
old_rmask_stamps.png: OK
new/superposition_new.png: OK
new/sheet_16_racs_new.png: OK
diff --git a/docs/qa/T0/probes/t0_probe.out b/docs/qa/T0/probes/t0_probe.out
index 1918154..45d65df 100644
--- a/docs/qa/T0/probes/t0_probe.out
+++ b/docs/qa/T0/probes/t0_probe.out
@@ -17,7 +17,8 @@ new: min=1343 median=8924.0 max=19145
 new smallest 8 (shoe, px): [(428, 1343), (163, 1376), (8, 2016), (375, 2963), (359, 2965), (112, 2988), (165, 3070), (286, 3154)]
 
 === D. pixel calibration feasibility
-old legacy R aspix mapping: RACs on contact = 0.8479
+old legacy R aspix mapping (exact R division form): RACs on contact = 0.847821
+old multiply form (x + 0.25) * 300 (an approximation of R; maps 2 RACs differently): RACs on contact = 0.847896
 old best (rate, s, mirror_x, flip_y, dc, dr): (np.float64(0.8816), 300, True, False, -1, -1)
 new coarse best (rate, s, mirror_x, flip_y, dc, dr): (np.float64(0.7534), 300, True, False, 0, 0)
 new fine top5 (rate, sx, sy, dc, dr): [(np.float64(0.8352), 298, 300, -1, -1), (np.float64(0.8345), 296, 300, -1, -1), (np.float64(0.8343), 300, 300, -1, -1), (np.float64(0.8328), 294, 300, -1, -1), (np.float64(0.8318), 298, 302, -1, -1)]
@@ -46,6 +47,6 @@ new t=29: px=27881 components=1 outside main=0
 === I. evidence images written
 /home/mehes/projects/rac-spatial-model/docs/qa/T0/old_prototypes.png (2492, 790)
 /home/mehes/projects/rac-spatial-model/docs/qa/T0/old_rmask_stamps.png (614, 790)
-/home/mehes/projects/rac-spatial-model/docs/qa/T0/new_superposition.png (2076, 734)
-/home/mehes/projects/rac-spatial-model/docs/qa/T0/new_sheet_16_racs.png (2040, 734)
+/home/mehes/projects/rac-spatial-model/docs/qa/T0/new/superposition_new.png (2076, 734)
+/home/mehes/projects/rac-spatial-model/docs/qa/T0/new/sheet_16_racs_new.png (2040, 734)
 sheet shoes: [428, 163, 8, 375, 359, 112, 165, 286, 22, 91, 296, 320, 473, 519, 596, 599]
```

The four PNGs are byte-identical to the first T0 run (the two NEW ones have the sha256 recorded in `docs/tests/T0-architecture-results.md` section 2). Only section D and the image paths changed in the output.

## 6. Small checks

### 6.1 A set-but-empty `RAC_DATASET`

```bash
cd /tmp && echo "R, set but empty:"; RAC_DATASET= Rscript -e 'v <- Sys.getenv("RAC_DATASET", "old"); cat(sprintf("[%s] nchar=%d\n", v, nchar(v)))'; echo "R, unset:"; env -u RAC_DATASET Rscript -e 'cat(sprintf("[%s]\n", Sys.getenv("RAC_DATASET", "old")))'; echo "Python, set but empty:"; RAC_DATASET= python3 -c 'import os; v = os.environ.get("RAC_DATASET", "old"); print(f"[{v}] len={len(v)}")'; echo "Python, unset:"; env -u RAC_DATASET python3 -c 'import os; print("[" + os.environ.get("RAC_DATASET", "old") + "]")'
```

```text
R, set but empty:
[] nchar=0
R, unset:
[old]
Python, set but empty:
[] len=0
Python, unset:
[old]
```

### 6.2 Code locations, `$SCRATCH`, `.gitignore` and `reports/`

```bash
TH=/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/contour_algorithm; grep -n "contour_Active_Contour.txt\|i == 126\|200 + 162\|155 + 90\|185 + 162\|128 + 95" "$TH/active_contour_snake.py" | tr -d "\r"; grep -n "max_pix == 18" "$TH/create_files_shoes.py" | tr -d "\r"; grep -n "allcont >= 8\|set.seed(313)" statistical_model/dataCC_1.Rmd; grep -n "N_CONTROLS <- 100" statistical_model/config.R; echo "--- \$SCRATCH in the plan before the fix:"; git show 42af8dd:docs/plans/2026-11-05-new-shoes-pipeline.md | grep -c -F '$SCRATCH'; git show 42af8dd:docs/plans/2026-11-05-new-shoes-pipeline.md | grep -c -F 'SCRATCH=' ; echo "--- .gitignore html rules and reports/:"; grep -n "html" .gitignore; ls -la --time-style=long-iso reports/; git ls-files reports | wc -l; git status --ignored --porcelain reports
```

```text
55:        y = 200 + 162 * np.sin(s)
56:        x = 155 + 90 * np.cos(s)
58:        y = 185 + 162 * np.sin(s)
59:        x = 128 + 95 * np.cos(s)
175:    with open(f'../data/contour_Active_Contour.txt', 'w') as f:
177:            if i == 126:  # Skip shoe 127 (0-indexed, has no RACs)
188:#    with open(f'{FOLDER}saved/contour_Active_Contour.txt', 'w') as f:
190:#         if i == 126:  # Skip shoe 127 (0-indexed, has no RACs)
52:        if max_pix == 18:
12:set.seed(313)
98:allcont <- (allcont >= 8) * 1 #here we see pixels that appear in more than 8 shoes
20:N_CONTROLS <- 100  # number of control pixels sampled per shoe in case-control design
--- $SCRATCH in the plan before the fix:
3
0
--- .gitignore html rules and reports/:
25:*.html
26:*.nb.html
total 24
drwxr-xr-x  2 mehes mehes  4096 2026-03-16 13:22 .
drwxr-xr-x 11 mehes mehes  4096 2026-11-05 18:09 ..
-rw-r--r--  1 mehes mehes 12681 2026-03-16 13:22 offset_changes_report.html
0
!! reports/
```

The plan used `$SCRATCH` in 3 places and never defined it (`SCRATCH=` occurs 0 times).

> **Correction (2026-11-06):** the command above was changed from `git show HEAD:...` (HEAD has moved past the fix, so it no longer printed 3 / 0) to the pre-fix commit `42af8dd`, and from `grep -c "\$SCRATCH"` to `grep -c -F '$SCRATCH'` (in the agent's tool shell `grep` is a ugrep wrapper that reads a leading `$` as an anchor and prints 0; GNU grep prints 3). Re-run: 3 and 0 (`docs/tests/T0-review2-fixes-results.md` section 6).

### 6.3 OLD shoe ids behind the offset comparison, and `predict.coxph`

```bash
Rscript -e 'l <- read.csv("data/locations_data.csv"); pc <- read.csv("processed_data/shoe_pixel_counts.csv"); cat("OLD locations sorted by shoe:", !is.unsorted(l$shoe), "| pc$shoe == sorted unique ids:", identical(as.integer(pc$shoe), sort(unique(as.integer(l$shoe)))), "| row of id 385:", which(pc$shoe == 385), "\n")'; Rscript -e 'suppressMessages(library(survival)); print(args(survival:::predict.coxph))' 2>&1 | head -4
```

```text
OLD locations sorted by shoe: TRUE | pc$shoe == sorted unique ids: TRUE | row of id 385: 384 
function (object, newdata, type = c("lp", "risk", "expected", 
    "terms", "survival"), se.fit = FALSE, na.action = na.pass, 
    terms = names(object$assign), collapse, reference = c("strata", 
        "sample", "zero"), ...) 
```

So the shoe with the largest offset difference is OLD id 385 (`dataCC` code 384), and `reference = "zero"` exists for the T7 CML-weight test.

## 7. Images looked at in this pass

All images were opened with the Read tool. Descriptions (identical text in `docs/qa/T0/README.md`):


Pair images show a NEW shoe (left) and an OLD shoe cropped to the NEW frame (right; OLD pixel (r + 14, c + 26) = NEW (r, c)), scaled x2, RACs as squares: green = matched within 1 px under the best shift (`pair_*`: one rigid shift; `pair2h_*`: one shift per half), red = not matched.

| File | What I saw |
|---|---|
| `compare/overlap_pairs/pair_469_212_old_vs_new.png` | Same tread (shoe with segmented forefoot and a heel with logo text), same outline and print position; matched RACs from toe to heel. NEW's midfoot printed fainter. Same shoe |
| `pair_453_267`, `pair_452_113`, `pair_501_12` | One boot family with diamond or square lugs; matched clusters in the forefoot. 452 has only 9 RACs (5 matched, 2 more within about 3 px): uncertain. The OLD prints 12, 113, 267 carry a vertical white bar beside the toe (a sticker outside the sole) |
| `pair_241_380`, `pair_242_379` (a consecutive NEW pair onto a consecutive OLD pair) | Same military-style boot (chevrons, central circles), r 0.987 and 0.964; matched forefoot clusters. Same pair of shoes |
| `pair_547_85`, `pair_548_84` (consecutive pair onto consecutive pair) | Same sole (horizontal toe bars, square blocks, triangles in the heel); one cluster matched at the found shift, and 4 toe RACs (547) or about 7 heel RACs (548) in the same configuration at a shift 1-4 px away: the print deforms between toe and heel |
| `pair_96_194`, `pair_34_217`, `pair_20_299`, `pair_87_337`, `pair_86_338`, `pair_58_322` | Soles with round lugs and round heel pads; matched clusters in the heel pads and midfoot; in 96, 20 and 87 the forefoot RACs line up as well at a slightly different shift. OLD 299 has a large white label beside the toe, OLD 194 a small square below the heel |
| `pair_531_67` | Same forefoot design; OLD 67's heel did not print, hence image rank 43; 14 RAC pairs at one consistent offset of about (0, -3) px from toe to heel. Same shoe; an image-only screen would have missed it |
| `pair_359_357` | Faint prints of a square-dot sole; about 8 RAC pairs at a consistent shift (-3.3, 5.6) px; two-half match 0.548. Likely the same shoe |
| `pair_204_5`, `pair_203_6` (consecutive pair onto consecutive pair) | Same sole, about 100 or more RACs each; large matched clusters on the heel pads (204) and in the forefoot (203) |
| `pair_214_148`, `pair_238_198`, `pair_245_91`, `pair_294_24`, `pair_297_121`, `pair_556_247`, `pair_619_81`, `pair_532_335` | Same designs side by side with matched clusters (294 and 532 uncertain: one cluster only, and OLD 24 heavily inked); OLD 24 and 121 carry stickers beside the toe |
| `pair2h_342_166`, `pair2h_358_116`, `pair2h_14_87`, `pair2h_295_189`, `pair2h_100_73`, `pair2h_15_94`, `pair2h_213_180` | Found only with one shift per half: same designs (r 0.79-0.99), matched RACs in both halves. Likely the same shoes. OLD 94 and 116 carry a sticker beside the toe |
| `pair2h_92_103` | **Wrong, corrected 2026-11-06 (A-041):** "2 of 5 RACs matched, different-looking print (image rank 226): unlikely" used the image rank of the rigid partner OLD 63. The image shows OLD 103: the same round-lug design with four heel pads (r 0.851, rank 5), 2 of 5 RACs matched at large inconsistent per-half shifts, exactly at the null maximum: uncertain |
| `control_354_219`, `control_57_196` | Controls: same design (r 0.974, 0.954) and visibly unrelated RACs (sym 0.087, 0.058). This is what "same design, different shoe" looks like. (Caveat 2026-11-06: NEW 354 is probably a reprint of OLD 219, see `docs/qa/T0/README.md`; only 57-196 remains a valid control) |
| `old/pair_old_236_277.png`, `old/pair_old_237_278.png` | Two OLD prints of the same chevron boot with U-shaped lugs, same outline, about 24-26 RACs matched over forefoot and heel; the consecutive pair 236/237 maps onto 277/278: very likely one pair of shoes printed twice inside OLD (K10) |
| `new/low_contact_shoes_new.png` | NEW 112: faint forefoot, heel almost unprinted with about 30 RACs on it; 177: faint circles, RACs in the unprinted midfoot; 286: very faint; 420: partial spiral-textured print; 498: faint, a RAC cluster in the arch gap; 599: a different image type (thick rim band, dot texture), RACs a few px off the dots (0.22 on contact, 0.91 after a shift). No sticker on these six |

Summary: of the 34 NEW candidates, 30 look like the same physical shoe, 3 are uncertain (452, 294, 532) and 1 is unlikely (92). **Corrected 2026-11-06:** 30 likely, 4 uncertain (92 included), 0 unlikely; the second review pass judged 37 more NEW shoes the same shoe as an OLD shoe and 18 more uncertain (plan F25). No sticker was seen on the NEW prints of these pairs; many OLD prints carry one outside the sole.

## 8. Document checks, lint, CR bytes, tables

```bash
head -2 docs/plans/2026-11-05-new-shoes-pipeline.md; flake8 docs/qa/T0/probes/*.py && echo "flake8 clean"; shellcheck docs/qa/T0/probes/t0_probe.sh && echo "shellcheck clean"; python3 docs/qa/T0/probes/t0_doc_checks.py
```

```text
# Plan: Run the full RAC pipeline on the new 631-shoe dataset and validate it
**Date:** 2026-11-05
flake8 clean
shellcheck clean
1. tracked artifacts: 25 | missing from the table: []
2. NEW paths in the table: 67 | violating the rule: []
3. mermaid: subgraph=3 end=3 labelled nodes=32 edges=44
RESULT: PASS
```

```bash
for f in docs/2026-11-05-meeting-micha-new-shoes.md docs/README.md docs/decisions.md docs/plans/2026-11-05-new-shoes-pipeline.md docs/progress/LOG.md docs/qa/T0/README.md docs/qa/T0/compare/overlap_screen_t0_old_vs_new.csv docs/qa/T0/probes/* docs/tests/README.md docs/tests/T0-architecture-results.md; do printf '%s %s\n' "$(tr -cd '\r' < "$f" | wc -c)" "$f"; done
```

```text
0 docs/2026-11-05-meeting-micha-new-shoes.md
0 docs/README.md
0 docs/decisions.md
0 docs/plans/2026-11-05-new-shoes-pipeline.md
0 docs/progress/LOG.md
0 docs/qa/T0/README.md
0 docs/qa/T0/compare/overlap_screen_t0_old_vs_new.csv
0 docs/qa/T0/probes/t0_doc_checks.py
0 docs/qa/T0/probes/t0_facts.out
0 docs/qa/T0/probes/t0_facts.py
0 docs/qa/T0/probes/t0_probe.R
0 docs/qa/T0/probes/t0_probe.out
0 docs/qa/T0/probes/t0_probe.py
0 docs/qa/T0/probes/t0_probe.sh
0 docs/qa/T0/probes/t0_probe_R.out
0 docs/qa/T0/probes/t0_probe_sh.out
0 docs/qa/T0/probes/t0_review.R
0 docs/qa/T0/probes/t0_review.out
0 docs/qa/T0/probes/t0_review.py
0 docs/qa/T0/probes/t0_review_R.out
0 docs/qa/T0/probes/t0_review_cml.R
0 docs/qa/T0/probes/t0_review_cml.out
0 docs/qa/T0/probes/t0_review_pairs.out
0 docs/qa/T0/probes/t0_review_pairs.py
0 docs/tests/README.md
0 docs/tests/T0-architecture-results.md
```

Markdown tables: a column-count check over the plan, the decision register, the READMEs, the meeting note and both T0 results files found 0 inconsistent tables.

## 9. Old regression (docs-only change)

No pipeline step was re-executed, because no code or data changed; T1 builds the re-run harness. The check is byte identity of every tracked pipeline file with the baseline commit `79247d8`, plus the absence of any change outside `docs/`:

```bash
git diff --name-only 79247d8 -- . ':(exclude)docs' | wc -l; n=0; bad=0; while IFS= read -r f; do a=$(git show "79247d8:$f" | sha256sum | cut -d" " -f1); b=$(sha256sum < "$f" | cut -d" " -f1); n=$((n+1)); if [ "$a" != "$b" ]; then bad=$((bad+1)); echo "DIFF $f"; fi; done < <(git ls-tree -r --name-only 79247d8 -- data processed_data saved_models model_images statistical_model reports); echo "compared $n files with their 79247d8 blobs, differing: $bad"
```

```text
0
compared 32 files with their 79247d8 blobs, differing: 0
```

In addition, the re-run `t0_probe_R.out` reprints the manual Wald W = 428.6933 (df 24) from the committed GLMM, and an exact CML refit from the committed `dataCC_distance.csv` is `identical()` to the committed CML (section 3).

## 10. Limits of this pass
- The overlap verdicts are my visual impressions at T0; T3 repeats the screen with tests and records a decision per candidate, and only Micha and Yoram can say which shoes were printed twice (D-012).
- The within-shoe pair test, the robust variances and the quality rule are specified, not implemented (T3, T5, T7).
- The T0 overlap statistic searches shifts up to +-8 px with a 1 px tolerance; reprints printed with larger offsets or stronger deformation can be missed, and 47 NEW shoes with < 5 RACs cannot be screened by RACs.
- The assembly script of this file is `<scratchpad>/t0fix/assemble_fix_results.py` (not committed).
