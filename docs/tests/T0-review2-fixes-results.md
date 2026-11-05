# T0 second review fixes: results

**Date:** 2026-11-05/06. **Task:** fix the second round of review findings on T0-architecture (one critical, four major, twelve minor). **Agent:** T0 second fix pass. No pipeline code or data changed; the changes are in `docs/` only (plan, decisions, LOG, READMEs, probes and QA evidence).

Every finding was checked against the data before the plan was changed. Quick commands below were re-run by the assembly script of this file (`<scratchpad>/t0fix2/assemble_results.py`, not committed; it runs each command with `bash -c`, so `grep` is GNU grep); long runs are pasted from their saved output files. `<scratchpad>` is the session scratch directory, `$PY` the thesis venv interpreter (`/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv/bin/python`, run with `-I -B`). Commits are pinned: `b970b92` is the last commit before this pass.

## 1. Findings, verification and fixes

| # | Finding (severity) | Verified? | Evidence (section) | Fix (plan, decision) |
|---|---|---|---|---|
| B1 | NEW 92 overlap evidence mislabelled (major) | Yes: OLD 103 has image r 0.851, rank 5; 0.497/226 belong to OLD 63. I looked at the image: same design, RACs at chance level | 2 | `t0_review_pairs.py` fixed and re-run (only the label region of the 8 images changed); 92 re-judged uncertain; F25, QA README, old results doc 4.2 and 7 corrected; A-041 |
| B2 | Part 2 treats OLD-fitted expectations as known (critical) | Yes: reviewer probe A re-run identical (ratio median 1.12, rejection 0.80); my own toy: fixed-E 0.787, NEW-only bootstrap 0.795; two-sample bootstrap 0.050 | 4 | Section 9 rewritten (two-sample bootstrap primary, parameter-corrected pooled Wald, fixed-surface test descriptive, effect sizes net of the floor, two-sample intervals for Delta X^2 and log scores); T5 stores ids and more OLD GLMM draws; T7 calibration with E re-estimated; F34, R31; A-043 |
| B3 | Overlap rule not calibrated by n; heavy reprints missed (major) | Yes, and larger than reported: the n-calibrated screen and a visual review of 91 shoes give 67 same shoe, 22 uncertain; the reviewer's 8 all flagged (I judge 7 same shoe, 1 uncertain) | 3 | T3 interface, step 3b, tests rewritten (order-free `pair_stats`, five statistics, pair-level NEW-NEW thresholds, review of every candidate, heavy-reprint test, port test not a lock-in); F25, F26, R24; D-012 updated; A-042 |
| B4 | Offset sign of the T6 refit (major) | Yes: reviewer probe B re-run identical; on the real OLD data the corrected sign recovers the intercept (-6.883741 vs -6.882487), the plan's sign does not converge. Narrowed: the proposed check "sigma^2 below 0.96" is wrong for these data (0.979) | 5 | T6 `fit_offset`, its test, section 5 row, A-037 pointer, D-008 update; F35, R33; A-044 |
| B5 | Bootstrap-V Wald over-rejects (major) | Yes: reviewer probe C re-run identical; my own run 0.142 (chi^2) vs 0.045 (F) at B = 200; paired-difference F 0.0507 | 6 | T5 `wald_V` with the F reference, T6 paired-difference `equality_wald`, rejection-rate tests; F36, R32; A-045 |
| m1 | `sym_match` depends on argument order | Yes: 2,800 pairs, and the three named pairs reproduce (0.463/0.439, 0.333/0.389, 0.417/0.389); the order-free version flags the same 26 | 3 | Order-free `pair_stats` (exactly symmetric); exact symmetry test incl. those pairs; nulls with the same definition; A-042 |
| m2 | Two-half rule `>=` at the null max; not a refinement | Yes: 92 and 556 at exactly 0.400; 531 and 34 lower under two halves | 3 | Strict `>` and >= 3 matched; rigid and two-half are separate statistics in a union; A-042 |
| m3 | A-031 did not reach the T2 Modify list | Yes; and R returns an all-NA matrix silently for a missing record | 9.1 | T2 Modify line, step-2 record-count stop, T5 test; A-053 |
| m4 | Sentinels do not cover coords or the frame split | Yes (by reading: OLD values coincide in both frames) | plan | T2 sentinel test with 20 px/unit and a 44 x 66 prototype for 40 x 60 data, mutation check; A-050 |
| m5 | Results doc 6.2 used `git show HEAD:` | Yes; also `grep "\$SCRATCH"` prints 0 under the tool shell's ugrep | 9.2 | Command pinned to `42af8dd` and `grep -F`; correction note |
| m6 | Empty-string rule only for RAC_DATASET; RAC_PROFILE_FILE leak | Yes (same `Sys.getenv` behaviour, F33) | plan | `rac_env()` / `profiles.env()` for every RAC_* variable; runners refuse RAC_PROFILE_FILE; A-049 |
| m7 | CML budget used the OLD fit time | Yes; OLD GLMM fit measured here: 231-281 s (5 fits) | 5 | T5 times both models per dataset first; OLD GLMM B = 1,000 if affordable; A-052 |
| m8 | A-028/T8 wording contradicts A-026 | Yes (by reading) | plan | Reworded in T8 and by A-047 |
| m9 | Pair test r = 4 mixes repulsion and clustering | Yes: probe F re-run identical; annuli and pair shares (68.7%/62.4%) recomputed | 7 | Annuli, unordered pairs, primary (2, 8] px, shoe-weighted version, below-h heterogeneity test; F38; A-046 |
| m10 | Common misfit inflates phi | Yes, but small: phi 1.008 vs phi_0 0.968 at X^2 about 207; centring halves it | 8 | Residuals minus the pooled-misfit share; "or systematic misfit" in the wording; F39; A-051 (the reviewer's O_ik - n_i O_k / N not adopted as written: it drops the shoe-specific expectations) |
| m11 | Bootstrap interval of a grid argmax unreliable | Accepted (statistical argument) | plan | Rule (ii) by the smooth difference rate(s*) - rate(300) < 0.005; A-048 |
| m12 | F31 values cited as magnitudes; dataset shift missing | Accepted; the reprints do have 3-4 times the RACs in NEW (images, section 3) | plan | F31 labelled illustrations; dataset shift in the interpretation guard and T8; A-051 |

## 2. Finding B1: the two-half partner's own image r and rank (NEW 92)

The fix in `docs/qa/T0/probes/t0_review_pairs.py`: the image features of `t0_review.py` section R5 are recomputed in the script, and the OLD tile label and the printed `image r` / `rank` now belong to the drawn two-half partner `old2h`; when the rigid partner differs (only NEW 92), its values are printed separately.

```bash
Q=docs/qa/T0/probes; s=$(date +%s); timeout 900 "$PY" -I -B $Q/t0_review_pairs.py "$PWD" "$PWD/docs/qa/T0" > $Q/t0_review_pairs.out 2>&1; echo "t0_review_pairs.py exit $? in $(( $(date +%s) - s ))s"; cat $Q/t0_review_pairs.out
```

```text
t0_review_pairs.py exit 0 in 24s
rigid rule: 26 shoes; two-half rule: 26; union: 34 NEW shoes, 1309 RACs (0.065 of all NEW RACs)
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_342_166_old_vs_new.png NEW 342 vs OLD 166: two-half sym=0.474 shifts front (1.12, -1.69), back (0.65, 0.18); rigid sym of this pair=0.263; image r=0.985 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_358_116_old_vs_new.png NEW 358 vs OLD 116: two-half sym=0.465 shifts front (-0.08, 2.79), back (1.10, 1.00); rigid sym of this pair=0.256; image r=0.793 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_14_87_old_vs_new.png NEW 14 vs OLD 87: two-half sym=0.440 shifts front (0.50, 3.52), back (-0.38, 0.03); rigid sym of this pair=0.240; image r=0.875 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_295_189_old_vs_new.png NEW 295 vs OLD 189: two-half sym=0.439 shifts front (-2.20, -1.01), back (-0.10, -2.05); rigid sym of this pair=0.263; image r=0.987 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_100_73_old_vs_new.png NEW 100 vs OLD 73: two-half sym=0.435 shifts front (1.23, 3.48), back (2.81, 2.13); rigid sym of this pair=0.261; image r=0.880 rank=1
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_15_94_old_vs_new.png NEW 15 vs OLD 94: two-half sym=0.433 shifts front (-2.70, -0.79), back (-0.84, -1.55); rigid sym of this pair=0.233; image r=0.839 rank=4
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_213_180_old_vs_new.png NEW 213 vs OLD 180: two-half sym=0.405 shifts front (5.37, 0.75), back (2.46, -0.30); rigid sym of this pair=0.286; image r=0.840 rank=5
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs/pair2h_92_103_old_vs_new.png NEW 92 vs OLD 103: two-half sym=0.400 shifts front (-1.95, 5.27), back (6.23, -0.38); rigid sym of this pair=0.200; image r=0.851 rank=5 | rigid partner OLD 63: rigid sym=0.200, image r=0.497 rank=226
```

Only the label region of the OLD tile changed in the 8 images (compared with the pre-fix blobs at `b970b92`):

```bash
$PY -I -B - <<'EOF'
import glob, io, subprocess
import numpy as np
from PIL import Image
for p in sorted(glob.glob('docs/qa/T0/compare/overlap_pairs/pair2h_*.png')):
    old = np.array(Image.open(io.BytesIO(subprocess.run(['git', 'show', f'b970b92:{p}'], capture_output=True, check=True).stdout)))
    new = np.array(Image.open(p))
    d = np.argwhere((old != new).any(-1))
    print(p.split('/')[-1], 'same size', old.shape == new.shape, '| differing px', len(d), '| rows %d-%d, cols %d-%d' % (d[:, 0].min(), d[:, 0].max(), d[:, 1].min(), d[:, 1].max()))
EOF
```

```text
pair2h_100_73_old_vs_new.png same size True | differing px 1620 | rows 10-29, cols 658-793
pair2h_14_87_old_vs_new.png same size True | differing px 1596 | rows 10-29, cols 658-795
pair2h_15_94_old_vs_new.png same size True | differing px 1688 | rows 10-29, cols 658-795
pair2h_213_180_old_vs_new.png same size True | differing px 1692 | rows 10-29, cols 670-807
pair2h_295_189_old_vs_new.png same size True | differing px 1640 | rows 10-29, cols 670-807
pair2h_342_166_old_vs_new.png same size True | differing px 1660 | rows 10-29, cols 670-807
pair2h_358_116_old_vs_new.png same size True | differing px 1600 | rows 10-29, cols 670-807
pair2h_92_103_old_vs_new.png same size True | differing px 1680 | rows 10-29, cols 658-795
```

The OLD tile starts at column 518 of the x2 image; rows 10-29 hold the label text. Looked at (`pair2h_92_103_old_vs_new.png`): both prints show the same round-lug design with a crescent of small toe lugs and four round heel pads, same outline and position. OLD 103 has only 4 RACs; 2 of the 5 NEW RACs match, one in the forefoot and one on the lower-left heel pad, at large and inconsistent shifts (front (-1.95, 5.27) px, back (6.23, -0.38) px). Lugs are rings and the heel pads have cross-shaped holes in OLD 103, solid discs in NEW 92 (perhaps inking). The order-free screen does not flag the pair (rigid k = 1, k2h = 2). Verdict: **uncertain** (A-041).

## 3. Findings B3, m1, m2: order-free, n-calibrated overlap screen

`docs/qa/T0/probes/t0_review2_overlap.py`, mode `compute` (every NEW-OLD, NEW-NEW and OLD-OLD pair; background, 8 worker processes):

```bash
nohup bash -c "s=\$(date +%s); timeout 7200 $PY -I -B docs/qa/T0/probes/t0_review2_overlap.py compute $PWD <scratchpad>/t0fix2/overlap_pairs_cache.npz 8 > <scratchpad>/t0fix2/t0_review2_overlap_compute.out 2>&1; echo \"compute exit \$? in \$(( \$(date +%s) - s ))s\" >> <scratchpad>/t0fix2/t0_review2_overlap_compute.out" &
```

```text
  ... 200 of 1648 jobs
  ... 400 of 1648 jobs
  ... 600 of 1648 jobs
  ... 800 of 1648 jobs
  ... 1000 of 1648 jobs
  ... 1200 of 1648 jobs
  ... 1400 of 1648 jobs
  ... 1600 of 1648 jobs
saved <scratchpad>/t0fix2/overlap_pairs_cache.npz: NEW-OLD 243566 pairs, NEW-NEW 198765, OLD-OLD 74305
compute exit 0 in 163s
```

Before the full run, the statistic was checked on known pairs (T0 values, the engineer's reverse-order values, exact symmetry):

```bash
cd docs/qa/T0/probes && timeout 600 $PY -B - <<'EOF'
import t0_review2_overlap as o
P = o.load_points('/home/mehes/projects/rac-spatial-model')
F = o.FIELDS
for sn, so in [(469, 212), (92, 63), (92, 103), (241, 380), (245, 91), (531, 67), (240, 320), (604, 134)]:
    f = dict(zip(F, o.pair_stats(P['new'][sn], P['old'][so])))
    r = dict(zip(F, o.pair_stats(P['old'][so], P['new'][sn])))
    symm = all(f[k] == r[k] for k in ('sym', 'k', 'sym2h', 'k2h')) and (f['ka'], f['kb']) == (r['kb'], r['ka'])
    print(f"NEW {sn} OLD {so}: t0_sym {f['t0_sym']:.3f} sym_rev {f['sym_rev']:.3f} sym {f['sym']:.3f} k {int(f['k'])} | t0_sym2h {f['t0_sym2h']:.3f} sym2h {f['sym2h']:.3f} k2h {int(f['k2h'])} | order-free symmetric: {symm}")
EOF
```

```text
NEW 469 OLD 212: t0_sym 0.535 sym_rev 0.535 sym 0.535 k 23 | t0_sym2h 0.605 sym2h 0.605 k2h 26 | order-free symmetric: True
NEW 92 OLD 63: t0_sym 0.200 sym_rev 0.200 sym 0.200 k 1 | t0_sym2h 0.200 sym2h 0.200 k2h 1 | order-free symmetric: True
NEW 92 OLD 103: t0_sym 0.200 sym_rev 0.200 sym 0.200 k 1 | t0_sym2h 0.400 sym2h 0.400 k2h 2 | order-free symmetric: True
NEW 241 OLD 380: t0_sym 0.463 sym_rev 0.439 sym 0.463 k 19 | t0_sym2h 0.561 sym2h 0.561 k2h 23 | order-free symmetric: True
NEW 245 OLD 91: t0_sym 0.333 sym_rev 0.389 sym 0.389 k 7 | t0_sym2h 0.556 sym2h 0.611 k2h 11 | order-free symmetric: True
NEW 531 OLD 67: t0_sym 0.417 sym_rev 0.389 sym 0.417 k 15 | t0_sym2h 0.361 sym2h 0.361 k2h 13 | order-free symmetric: True
NEW 240 OLD 320: t0_sym 0.157 sym_rev 0.157 sym 0.157 k 19 | t0_sym2h 0.157 sym2h 0.157 k2h 19 | order-free symmetric: True
NEW 604 OLD 134: t0_sym 0.154 sym_rev 0.154 sym 0.154 k 20 | t0_sym2h 0.169 sym2h 0.169 k2h 22 | order-free symmetric: True
```

Mode `analyze` (reads the cache; merges the hand-written verdicts of `docs/qa/T0/compare/overlap_verdicts_t0_old_vs_new.csv`; writes `overlap_candidates_t0_old_vs_new.csv` and the 61 evidence images; deterministic: two further runs reproduced all images byte for byte):

```bash
Q=docs/qa/T0/probes; s=$(date +%s); timeout 900 "$PY" -I -B $Q/t0_review2_overlap.py analyze "$PWD" "$PWD/docs/qa/T0" <scratchpad>/t0fix2/overlap_pairs_cache.npz > $Q/t0_review2_overlap.out 2>&1; echo "analyze exit $? in $(( $(date +%s) - s ))s"; cat $Q/t0_review2_overlap.out
```

```text
analyze exit 0 in 26s

=== A. reproduction of the T0 screen (t0_review.py R5, R8)
best rigid sym: equal to the T0 CSV for all 631 NEW shoes (Python round to 3 dp, as T0): True
second-best rigid sym: equal to the T0 CSV for all 631 NEW shoes (Python round to 3 dp, as T0): True
best two-half sym: equal to the T0 CSV for all 631 NEW shoes (Python round to 3 dp, as T0): True
second-best two-half: equal to the T0 CSV for all 631 NEW shoes (Python round to 3 dp, as T0): True
NEW-OLD pairs whose T0 value depends on the argument order: 2800 of 243566; order-free sym > T0 sym: 1358 pairs; order-free sym2h > T0 sym2h: 1257
T0 rule on t0_sym vs on the order-free sym (same threshold 0.3, margin 0.15): 26 vs 26 NEW shoes; same shoes True; same partners True
T0 rule on t0_sym2h vs on the order-free sym2h (same threshold 0.4, margin 0.15): 26 vs 26 NEW shoes; same shoes True; same partners True

=== B. within-dataset nulls, order-free statistics
NEW-NEW best sym per shoe, max by n bin: [5, 10): 0.286; [10, 20): 0.222; [20, 40): 0.174; [40, 80): 0.127; [80, 1000000): 0.120
NEW-NEW best sym2h per shoe, max by n bin: [5, 10): 0.400; [10, 20): 0.273; [20, 40): 0.217; [40, 80): 0.150; [80, 1000000): 0.132
OLD-OLD best sym per shoe, max by n bin: [5, 10): 0.222; [10, 20): 0.222; [20, 40): 0.150; [40, 80): 0.400; [80, 1000000): 0.109
OLD-OLD best sym2h per shoe, max by n bin: [5, 10): 0.400; [10, 20): 0.300; [20, 40): 0.167; [40, 80): 0.486; [80, 1000000): 0.123
NEW-NEW pairs with the most RACs matched (rigid k): 72-73 k=26 (n 281, 267; image r 0.937); 61-73 k=21 (n 202, 267; image r 0.845); 60-72 k=19 (n 209, 281; image r 0.897); 73-147 k=19 (n 267, 137; image r 0.915); 38-72 k=18 (n 146, 281; image r 0.810)

=== C. is the NEW-NEW null representative of NEW-OLD pairs?
sym, NEW n in [5, 10) (67 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 0.167/0.200; vs NEW p50/p90 0.167/0.222
sym, NEW n in [10, 20) (145 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 0.138/0.185; vs NEW p50/p90 0.125/0.167
sym, NEW n in [20, 40) (210 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 0.103/0.138; vs NEW p50/p90 0.103/0.130
sym, NEW n in [40, 80) (123 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 0.089/0.106; vs NEW p50/p90 0.091/0.106
sym, NEW n in [80, 1000000) (39 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 0.082/0.095; vs NEW p50/p90 0.076/0.092
k, NEW n in [5, 10) (67 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 3.000/3.000; vs NEW p50/p90 3.000/3.000
k, NEW n in [10, 20) (145 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 4.000/5.000; vs NEW p50/p90 4.000/4.000
k, NEW n in [20, 40) (210 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 5.000/7.000; vs NEW p50/p90 5.000/6.000
k, NEW n in [40, 80) (123 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 8.000/10.000; vs NEW p50/p90 7.000/9.000
k, NEW n in [80, 1000000) (39 shoes), best partner among pairs with image r < 0.80, 386 partners each: vs OLD p50/p90 12.000/17.200; vs NEW p50/p90 11.000/14.200

=== D. n-calibrated rules: pair-level NEW-NEW maxima per stratum of (n bin, n bin), strict >, >= 3 matched
sym  : NEW shoes flagged 77 (T0 candidates among them 33 of 34; reviewer 8: 8) | OLD-OLD pairs flagged by the same thresholds: 6 [(11, 190), (38, 299), (76, 107), (78, 227), (236, 277), (237, 278)]
sym2h: NEW shoes flagged 91 (T0 candidates among them 33 of 34; reviewer 8: 8) | OLD-OLD pairs flagged by the same thresholds: 5 [(77, 319), (103, 315), (129, 338), (236, 277), (237, 278)]
k    : NEW shoes flagged 76 (T0 candidates among them 33 of 34; reviewer 8: 8) | OLD-OLD pairs flagged by the same thresholds: 3 [(38, 299), (236, 277), (237, 278)]
k2h  : NEW shoes flagged 83 (T0 candidates among them 33 of 34; reviewer 8: 8) | OLD-OLD pairs flagged by the same thresholds: 4 [(45, 213), (103, 315), (236, 277), (237, 278)]
msh  : NEW shoes flagged 74 (T0 candidates among them 32 of 34; reviewer 8: 8) | OLD-OLD pairs flagged by the same thresholds: 4 [(236, 277), (237, 278), (261, 364), (323, 385)]
wrote /home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_candidates_t0_old_vs_new.csv: 122 NEW shoes (any n-calibrated flag, the T0 candidates and the reviewer 8); by number of statistics flagging the pair: {5: 59, 4: 7, 3: 2, 2: 15, 1: 38, 0: 1}
  not T0 candidates, flagged by 4-5 statistics: 33 shoes, 1597 NEW RACs; image rank <= 3: 25
  not T0 candidates, flagged by 2-3 statistics: 17 shoes, 916 NEW RACs; image rank <= 3: 13
  not T0 candidates, flagged by 1 statistics: 38 shoes, 1746 NEW RACs; image rank <= 3: 7
T0 candidates not flagged by any n-calibrated statistic: [92]
 new  n_new  old  n_old  n_stats               stats other_flagged_old  t0_rigid  t0_two_half  reviewer8   sym  k  sym2h  k2h   msh     r  img_rank        verdict      visual
 204    111    5    147        5 sym+sym2h+k+k2h+msh                        True         True      False 0.313 46  0.449   65 0.423 0.981         1      same_shoe very_likely
 203    126    6    102        5 sym+sym2h+k+k2h+msh                        True         True      False 0.310 39  0.437   55 0.392 0.953         1      same_shoe very_likely
  84    122   26    112        5 sym+sym2h+k+k2h+msh                       False        False       True 0.270 32  0.369   44 0.286 0.930         1      same_shoe very_likely
  20     48  299     70        5 sym+sym2h+k+k2h+msh                        True         True      False 0.371 26  0.529   37 0.542 0.805         9      same_shoe      likely
  34     67  217     38        5 sym+sym2h+k+k2h+msh                        True        False      False 0.373 25  0.328   22 0.658 0.930         1      same_shoe      likely
 469     36  212     43        5 sym+sym2h+k+k2h+msh                        True         True      False 0.535 23  0.605   26 0.667 0.948         1      same_shoe very_likely
 297     60  121     33        5 sym+sym2h+k+k2h+msh                        True        False      False 0.333 20  0.333   20 0.606 0.938         1      same_shoe      likely
 604    130  134     40        5 sym+sym2h+k+k2h+msh                       False        False       True 0.154 20  0.169   22 0.500 0.967         1      same_shoe very_likely
 240    121  320     29        5 sym+sym2h+k+k2h+msh                       False        False       True 0.157 19  0.157   19 0.655 0.980         1      same_shoe very_likely
 241     36  380     41        5 sym+sym2h+k+k2h+msh                        True         True      False 0.463 19  0.561   23 0.528 0.987         1      same_shoe very_likely
 100     69   73     60        5 sym+sym2h+k+k2h+msh                       False         True      False 0.261 18  0.435   30 0.300 0.880         1      same_shoe      likely
 193     67  106     56        5 sym+sym2h+k+k2h+msh                       False        False      False 0.269 18  0.269   17 0.321 0.889         2      same_shoe      likely
  58     50  322     33        5 sym+sym2h+k+k2h+msh                        True        False      False 0.300 15  0.340   17 0.455 0.964         1      same_shoe      likely
  96     34  194     40        5 sym+sym2h+k+k2h+msh                        True         True      False 0.375 15  0.500   20 0.441 0.944         1      same_shoe      likely
 192     69  105     37        5 sym+sym2h+k+k2h+msh                       False        False       True 0.217 15  0.217   15 0.405 0.942         1      same_shoe      likely
 239    105  321     36        5 sym+sym2h+k+k2h+msh                       False        False       True 0.143 15  0.181   19 0.417 0.988         1      same_shoe very_likely
 295     51  189     57        5 sym+sym2h+k+k2h+msh                       False         True      False 0.263 15  0.439   25 0.294 0.987         1      same_shoe      likely
 531     24   67     36        5 sym+sym2h+k+k2h+msh                        True        False      False 0.417 15  0.361   13 0.625 0.669        43      same_shoe very_likely
 627     85  326     54        5 sym+sym2h+k+k2h+msh                       False        False      False 0.176 15  0.306   26 0.278 0.964         1      same_shoe very_likely
  86     40  338     37        5 sym+sym2h+k+k2h+msh                        True         True      False 0.350 14  0.425   17 0.378 0.979         1      same_shoe      likely
  87     40  337     39        5 sym+sym2h+k+k2h+msh               292      True         True      False 0.325 13  0.425   17 0.333 0.909         4      same_shoe      likely
 196     70   56     62        5 sym+sym2h+k+k2h+msh                       False        False      False 0.186 13  0.314   22 0.210 0.834         3      same_shoe      likely
 626     53  300     75        5 sym+sym2h+k+k2h+msh                       False        False      False 0.173 13  0.347   26 0.245 0.919         1      same_shoe very_likely
  21     56   38     58        5 sym+sym2h+k+k2h+msh                       False        False      False 0.207 12  0.362   21 0.214 0.843        13      same_shoe      likely
 214     32  148     33        5 sym+sym2h+k+k2h+msh                        True         True      False 0.364 12  0.485   16 0.406 0.899         1      same_shoe      likely
 358     43  116     39        5 sym+sym2h+k+k2h+msh                       False         True      False 0.279 12  0.465   20 0.359 0.793         1      same_shoe      likely
 619     30   81     37        5 sym+sym2h+k+k2h+msh                        True        False      False 0.324 12  0.351   13 0.400 0.876         1      same_shoe      likely
 195     48   55     48        5 sym+sym2h+k+k2h+msh                       False        False      False 0.229 11  0.271   13 0.229 0.874         2      same_shoe      likely
 213     42  180     33        5 sym+sym2h+k+k2h+msh                       False         True      False 0.286 11  0.405   16 0.333 0.840         5      same_shoe      likely
 359     30  357     31        5 sym+sym2h+k+k2h+msh                        True         True      False 0.355 11  0.548   17 0.367 0.324       283      same_shoe      likely
 547     27   85     18        5 sym+sym2h+k+k2h+msh                        True         True      False 0.407 11  0.667   18 0.611 0.823         7      same_shoe      likely
  10     35  306     44        5 sym+sym2h+k+k2h+msh                       False        False      False 0.227 10  0.386   17 0.286 0.887         1      same_shoe very_likely
  57     52  177     21        5 sym+sym2h+k+k2h+msh                       False        False       True 0.192 10  0.212   11 0.476 0.954         2      same_shoe      likely
  99     28  167     37        5 sym+sym2h+k+k2h+msh                       False        False       True 0.270 10  0.378   13 0.357 0.949         1      same_shoe      likely
 238     32  198     26        5 sym+sym2h+k+k2h+msh               338      True        False      False 0.312 10  0.344   11 0.385 0.982         1      same_shoe      likely
 342     38  166     27        5 sym+sym2h+k+k2h+msh                       False         True      False 0.263 10  0.474   18 0.370 0.985         1      same_shoe      likely
 556     30  247     17        5 sym+sym2h+k+k2h+msh                        True         True      False 0.333 10  0.400   12 0.588 0.882         1      same_shoe      likely
   3     33   29     65        5 sym+sym2h+k+k2h+msh                       False        False      False 0.138  9  0.246   16 0.273 0.852         3      same_shoe      likely
 198     41  371     27        5 sym+sym2h+k+k2h+msh                       False        False       True 0.220  9  0.220    9 0.333 0.799         5      uncertain   uncertain
 242     28  379     28        5 sym+sym2h+k+k2h+msh                63      True         True      False 0.321  9  0.429   12 0.321 0.964         1      same_shoe very_likely
 294     25   24     26        5 sym+sym2h+k+k2h+msh                        True        False      False 0.346  9  0.346    9 0.360 0.764        11      uncertain   uncertain
 453     17  267     19        5 sym+sym2h+k+k2h+msh                        True         True      False 0.474  9  0.526   10 0.529 0.885         1      same_shoe      likely
 468     33  296     49        5 sym+sym2h+k+k2h+msh                       False        False      False 0.184  9  0.224   11 0.273 0.843         2      same_shoe      likely
 532     17  335     33        5 sym+sym2h+k+k2h+msh                        True        False      False 0.303  9  0.364   10 0.529 0.883         1      uncertain   uncertain
 577     26  135     45        5 sym+sym2h+k+k2h+msh                       False        False      False 0.200  9  0.289   13 0.346 0.792         2      same_shoe very_likely
   9     37  345     32        5 sym+sym2h+k+k2h+msh                       False        False      False 0.216  8  0.297   11 0.250 0.888         1      same_shoe      likely
  11     30   30     47        5 sym+sym2h+k+k2h+msh               129     False        False      False 0.170  8  0.255   12 0.267 0.725         1      same_shoe      likely
 533     30  336     31        5 sym+sym2h+k+k2h+msh                       False        False      False 0.267  8  0.333   10 0.290 0.679         6      same_shoe      likely
 548     22   84     22        5 sym+sym2h+k+k2h+msh                        True         True      False 0.364  8  0.500   11 0.364 0.926         1      same_shoe      likely
  15     30   94     27        5 sym+sym2h+k+k2h+msh                       False         True      False 0.233  7  0.433   13 0.259 0.839         4      same_shoe      likely
 180     17  196     38        5 sym+sym2h+k+k2h+msh                       False        False      False 0.184  7  0.289   11 0.412 0.960         1      same_shoe      likely
 194     36    7     25        5 sym+sym2h+k+k2h+msh                       False        False      False 0.222  7  0.250    8 0.280 0.897         2      same_shoe      likely
 245     18   91     14        5 sym+sym2h+k+k2h+msh                        True         True      False 0.389  7  0.611   11 0.500 0.851         1      same_shoe      likely
 501     17   12      9        5 sym+sym2h+k+k2h+msh                        True         True      False 0.412  7  0.412    7 0.778 0.878         1      same_shoe      likely
 426     23   99     27        5 sym+sym2h+k+k2h+msh                       False        False      False 0.222  6  0.370   10 0.304 0.563        57      uncertain   uncertain
 314     24  161     25        5 sym+sym2h+k+k2h+msh                       False        False      False 0.200  5  0.320    8 0.208 0.823         1      same_shoe      likely
 315     23  162     24        5 sym+sym2h+k+k2h+msh                       False        False      False 0.208  5  0.375    9 0.217 0.707        15      same_shoe      likely
 389     25  382      8        5 sym+sym2h+k+k2h+msh                       False        False      False 0.200  5  0.240    6 0.625 0.911         1      same_shoe      likely
 452      9  113     12        5 sym+sym2h+k+k2h+msh                        True         True      False 0.417  5  0.417    5 0.556 0.661         3      uncertain   uncertain
 101     53  332     34        4     sym+sym2h+k+k2h                       False        False      False 0.151  8  0.226   12 0.235 0.905         4      same_shoe      likely
 355     28  220     72        4     sym2h+k+k2h+msh                       False        False      False 0.111  8  0.181   12 0.286 0.981         1      same_shoe      likely
  97     38  119     36        4     sym+sym2h+k+k2h                       False        False      False 0.184  7  0.211    8 0.194 0.907         2      same_shoe      likely
  14     25   87     19        4     sym+sym2h+k+k2h                       False         True      False 0.240  6  0.440   11 0.316 0.875         1      same_shoe      likely
 179     16  197     53        4     sym+sym2h+k+k2h               324     False        False      False 0.113  6  0.189   10 0.375 0.872         1      same_shoe      likely
   4     23  110     37        4     sym2h+k+k2h+msh                       False        False      False 0.135  5  0.216    8 0.217 0.809         8      uncertain   uncertain
 218     20  239      8        4     sym+sym2h+k+k2h                       False        False      False 0.200  4  0.250    5 0.500 0.749         8      uncertain   uncertain
  61    202  224     37        3           k+k2h+msh                       False        False      False 0.064 13  0.074   15 0.351 0.948         1      uncertain   uncertain
 237     31  199     27        3         sym2h+k+k2h                       False        False      False 0.161  5  0.323   10 0.185 0.956         1      same_shoe      likely
  85    120   25    156        2           sym+sym2h                26     False        False      False 0.115 18  0.160   24 0.150 0.792         2      same_shoe      likely
 147    137   37    126        2           sym+sym2h                       False        False      False 0.117 16  0.131   18 0.135 0.772        30 different_shoe    unlikely
  30     80   50     77        2           sym+sym2h                       False        False      False 0.138 11  0.208   16 0.143 0.870         3      uncertain   uncertain
  29     77   49     47        2           sym2h+k2h                       False        False      False 0.091  7  0.195   15 0.149 0.794         4      uncertain   uncertain
 343     60  188     30        2           sym2h+k2h                       False        False      False 0.100  6  0.183   11 0.200 0.799         2      same_shoe      likely
 470     37   95     19        2               k+k2h                       False        False      False 0.162  6  0.189    7 0.316 0.766         1      same_shoe      likely
  74     16  209     35        2               k+k2h                       False        False      False 0.143  5  0.200    7 0.312 0.860         2      same_shoe      likely
  75     16  210     34        2               k+k2h                       False        False      False 0.147  5  0.176    6 0.312 0.771        14      same_shoe      likely
 578     27   96     43        2           sym2h+k2h                       False        False      False 0.116  5  0.209    9 0.185 0.758         3      uncertain   uncertain
 344     32   77     87        2           sym+sym2h                       False        False      False 0.080  4  0.092    5 0.125 0.774        24 different_shoe   different
 471     20  264     19        2           sym+sym2h                       False        False      False 0.200  4  0.250    5 0.211 0.699         2      uncertain   uncertain
 246     15   39      3        2               k+k2h                       False        False      False 0.200  3  0.200    3 1.000 0.862         3      uncertain   uncertain
 386     15  192     13        2           sym2h+k2h                       False        False      False 0.200  3  0.333    5 0.231 0.711         1      uncertain   uncertain
 427     19  228     14        2           sym2h+k2h                       False        False      False 0.158  3  0.316    6 0.214 0.765         1      uncertain   uncertain
 500     12   97      6        2           sym2h+k2h                       False        False      False 0.167  2  0.333    4 0.333 0.830         1      uncertain   uncertain
  72    281   37    126        1                 msh           129 263     False        False      False 0.064 18  0.071   20 0.159 0.811        21            NaN         NaN
 606     83  385    309        1                 msh                       False        False      False 0.049 14  0.055   16 0.169 0.571       165            NaN         NaN
  73    267  129     80        1                 msh                       False        False      False 0.049 13  0.060   16 0.163 0.794        25            NaN         NaN
 498     96  131     67        1               sym2h                       False        False      False 0.083  8  0.135   13 0.119 0.760         1      same_shoe      likely
  48     92  180     33        1                 sym                       False        False      False 0.076  7  0.065    6 0.212 0.543        91            NaN         NaN
 216     67  129     80        1               sym2h                       False        False      False 0.104  7  0.134    9 0.113 0.697        53            NaN         NaN
 585     18  282    165        1                   k                       False        False      False 0.042  7  0.042    7 0.389 0.544        11            NaN         NaN
 354     39  219     69        1                 k2h                       False        False      False 0.087  6  0.130    9 0.154 0.974         1      same_shoe      likely
 197     27  129     80        1               sym2h                       False        False      False 0.075  5  0.100    7 0.185 0.667       118            NaN         NaN
 225     42  221     18        1                 sym                       False        False      False 0.119  5  0.119    5 0.278 0.617       170            NaN         NaN
 605     83  145     24        1               sym2h                       False        False      False 0.060  5  0.108    8 0.208 0.774         3      uncertain   uncertain
 621     37  217     38        1                   k                       False        False      False 0.132  5  0.132    5 0.162 0.706        89            NaN         NaN
  13     18  129     80        1                 sym               263     False        False      False 0.062  4  0.075    5 0.222 0.642        44            NaN         NaN
  32     88  372      9        1                 sym               103     False        False      False 0.045  4  0.045    4 0.444 0.651        75            NaN         NaN
  54     47   30     47        1               sym2h                       False        False      False 0.085  4  0.170    8 0.106 0.609        74            NaN         NaN
 133      9   36    104        1                 sym                       False        False      False 0.048  4  0.038    3 0.444 0.681        16            NaN         NaN
 153     15  129     80        1                 sym                       False        False      False 0.062  4  0.075    5 0.267 0.645        15            NaN         NaN
 286     40   17     18        1                 sym                       False        False      False 0.100  4  0.100    4 0.222 0.393       229            NaN         NaN
 287     66  126      7        1                   k                       False        False      False 0.061  4  0.061    4 0.571 0.447       374            NaN         NaN
 421     46   86     46        1               sym2h                       False        False      False 0.087  4  0.152    7 0.087 0.675       105            NaN         NaN
 530     10   66     29        1                 msh                       False        False      False 0.138  4  0.172    5 0.400 0.747         2      uncertain   uncertain
   7     19  261     12        1                 msh                       False        False      False 0.158  3  0.105    2 0.250 0.433       356            NaN         NaN
 125     14  122     12        1                 msh                       False        False      False 0.214  3  0.214    3 0.250 0.835         7            NaN         NaN
 217     20  160     10        1               sym2h                       False        False      False 0.150  3  0.250    5 0.300 0.763         1      uncertain   uncertain
 249      9  129     80        1                 sym                       False        False      False 0.050  3  0.050    3 0.333 0.457       334            NaN         NaN
 270     18   89     18        1                 k2h                       False        False      False 0.167  3  0.222    4 0.167 0.713        41            NaN         NaN
 383     14  125     18        1                 msh                       False        False      False 0.167  3  0.167    3 0.286 0.686       125            NaN         NaN
 449     16  287     12        1                 msh                       False        False      False 0.188  3  0.188    3 0.250 0.555       240            NaN         NaN
 474     16   41     13        1                 msh                       False        False      False 0.188  3  0.188    3 0.308 0.586        11            NaN         NaN
 508     16  122     12        1                 msh                       False        False      False 0.188  3  0.188    3 0.250 0.396       248            NaN         NaN
 525     12  263     18        1                 msh                       False        False      False 0.167  3  0.167    3 0.250 0.549       241            NaN         NaN
 625     43  348      9        1               sym2h                       False        False      False 0.070  3  0.093    4 0.333 0.605       188            NaN         NaN
 159      5  288      8        1                 k2h                       False        False      False 0.250  2  0.375    3 0.400 0.909         2      uncertain   uncertain
 259      5  303      9        1                 k2h                       False        False      False 0.222  2  0.333    3 0.400 0.755        16            NaN         NaN
 348      9   77     87        1               sym2h                       False        False      False 0.023  2  0.057    5 0.222 0.812        38            NaN         NaN
 387      7   96     43        1               sym2h                       False        False      False 0.047  2  0.093    3 0.286 0.548        71            NaN         NaN
 575      7  351     10        1               sym2h                       False        False      False 0.200  2  0.300    3 0.286 0.691         2      uncertain   uncertain
 599     45   18      8        1               sym2h                       False        False      False 0.044  2  0.089    4 0.250 0.762        78            NaN         NaN
  92      5  103      4        0                                           False         True      False 0.200  1  0.400    2 0.250 0.851         5      uncertain   uncertain

=== E. evidence images (green: matched at the rigid shift of k; orange: matched in addition with one shift per half, k2h; red: not matched)
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_84_26_old_vs_new.png: matched at the rigid shift 33/122 NEW, 32/112 OLD; at the rigid or a per-half shift 46, 44
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_604_134_old_vs_new.png: matched at the rigid shift 20/130 NEW, 20/40 OLD; at the rigid or a per-half shift 22, 22
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_240_320_old_vs_new.png: matched at the rigid shift 19/121 NEW, 19/29 OLD; at the rigid or a per-half shift 20, 20
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_193_106_old_vs_new.png: matched at the rigid shift 18/67 NEW, 18/56 OLD; at the rigid or a per-half shift 19, 18
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_192_105_old_vs_new.png: matched at the rigid shift 15/69 NEW, 15/37 OLD; at the rigid or a per-half shift 17, 17
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_239_321_old_vs_new.png: matched at the rigid shift 15/105 NEW, 15/36 OLD; at the rigid or a per-half shift 21, 21
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_627_326_old_vs_new.png: matched at the rigid shift 15/85 NEW, 15/54 OLD; at the rigid or a per-half shift 26, 26
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_196_56_old_vs_new.png: matched at the rigid shift 13/70 NEW, 13/62 OLD; at the rigid or a per-half shift 22, 22
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_626_300_old_vs_new.png: matched at the rigid shift 13/53 NEW, 13/75 OLD; at the rigid or a per-half shift 26, 26
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_21_38_old_vs_new.png: matched at the rigid shift 12/56 NEW, 12/58 OLD; at the rigid or a per-half shift 22, 22
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_195_55_old_vs_new.png: matched at the rigid shift 11/48 NEW, 11/48 OLD; at the rigid or a per-half shift 21, 21
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_10_306_old_vs_new.png: matched at the rigid shift 10/35 NEW, 10/44 OLD; at the rigid or a per-half shift 17, 17
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_57_177_old_vs_new.png: matched at the rigid shift 10/52 NEW, 10/21 OLD; at the rigid or a per-half shift 13, 13
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_99_167_old_vs_new.png: matched at the rigid shift 10/28 NEW, 10/37 OLD; at the rigid or a per-half shift 14, 15
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_3_29_old_vs_new.png: matched at the rigid shift 9/33 NEW, 9/65 OLD; at the rigid or a per-half shift 16, 16
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_198_371_old_vs_new.png: matched at the rigid shift 9/41 NEW, 9/27 OLD; at the rigid or a per-half shift 11, 11
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_468_296_old_vs_new.png: matched at the rigid shift 9/33 NEW, 9/49 OLD; at the rigid or a per-half shift 16, 16
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_577_135_old_vs_new.png: matched at the rigid shift 9/26 NEW, 9/45 OLD; at the rigid or a per-half shift 13, 13
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_9_345_old_vs_new.png: matched at the rigid shift 8/37 NEW, 8/32 OLD; at the rigid or a per-half shift 11, 11
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_11_30_old_vs_new.png: matched at the rigid shift 8/30 NEW, 8/47 OLD; at the rigid or a per-half shift 12, 12
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_533_336_old_vs_new.png: matched at the rigid shift 8/30 NEW, 9/31 OLD; at the rigid or a per-half shift 10, 11
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_180_196_old_vs_new.png: matched at the rigid shift 7/17 NEW, 7/38 OLD; at the rigid or a per-half shift 11, 13
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_194_7_old_vs_new.png: matched at the rigid shift 8/36 NEW, 7/25 OLD; at the rigid or a per-half shift 9, 8
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_426_99_old_vs_new.png: matched at the rigid shift 7/23 NEW, 6/27 OLD; at the rigid or a per-half shift 11, 10
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_314_161_old_vs_new.png: matched at the rigid shift 5/24 NEW, 5/25 OLD; at the rigid or a per-half shift 8, 8
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_315_162_old_vs_new.png: matched at the rigid shift 5/23 NEW, 5/24 OLD; at the rigid or a per-half shift 9, 9
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_389_382_old_vs_new.png: matched at the rigid shift 5/25 NEW, 5/8 OLD; at the rigid or a per-half shift 6, 6
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_101_332_old_vs_new.png: matched at the rigid shift 8/53 NEW, 8/34 OLD; at the rigid or a per-half shift 12, 12
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_355_220_old_vs_new.png: matched at the rigid shift 8/28 NEW, 8/72 OLD; at the rigid or a per-half shift 15, 17
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_97_119_old_vs_new.png: matched at the rigid shift 7/38 NEW, 7/36 OLD; at the rigid or a per-half shift 11, 11
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_179_197_old_vs_new.png: matched at the rigid shift 6/16 NEW, 6/53 OLD; at the rigid or a per-half shift 11, 11
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_4_110_old_vs_new.png: matched at the rigid shift 5/23 NEW, 5/37 OLD; at the rigid or a per-half shift 8, 8
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_218_239_old_vs_new.png: matched at the rigid shift 4/20 NEW, 4/8 OLD; at the rigid or a per-half shift 5, 5
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_61_224_old_vs_new.png: matched at the rigid shift 13/202 NEW, 13/37 OLD; at the rigid or a per-half shift 16, 16
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_237_199_old_vs_new.png: matched at the rigid shift 5/31 NEW, 5/27 OLD; at the rigid or a per-half shift 10, 10
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_85_25_old_vs_new.png: matched at the rigid shift 18/120 NEW, 18/156 OLD; at the rigid or a per-half shift 37, 39
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_147_37_old_vs_new.png: matched at the rigid shift 16/137 NEW, 17/126 OLD; at the rigid or a per-half shift 18, 19
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_30_50_old_vs_new.png: matched at the rigid shift 11/80 NEW, 11/77 OLD; at the rigid or a per-half shift 18, 17
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_29_49_old_vs_new.png: matched at the rigid shift 7/77 NEW, 7/47 OLD; at the rigid or a per-half shift 15, 15
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_343_188_old_vs_new.png: matched at the rigid shift 6/60 NEW, 6/30 OLD; at the rigid or a per-half shift 11, 11
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_470_95_old_vs_new.png: matched at the rigid shift 6/37 NEW, 6/19 OLD; at the rigid or a per-half shift 7, 7
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_74_209_old_vs_new.png: matched at the rigid shift 5/16 NEW, 5/35 OLD; at the rigid or a per-half shift 7, 7
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_75_210_old_vs_new.png: matched at the rigid shift 5/16 NEW, 5/34 OLD; at the rigid or a per-half shift 6, 6
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_578_96_old_vs_new.png: matched at the rigid shift 5/27 NEW, 5/43 OLD; at the rigid or a per-half shift 9, 9
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_344_77_old_vs_new.png: matched at the rigid shift 4/32 NEW, 7/87 OLD; at the rigid or a per-half shift 5, 8
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_471_264_old_vs_new.png: matched at the rigid shift 4/20 NEW, 4/19 OLD; at the rigid or a per-half shift 5, 5
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_246_39_old_vs_new.png: matched at the rigid shift 3/15 NEW, 3/3 OLD; at the rigid or a per-half shift 3, 3
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_386_192_old_vs_new.png: matched at the rigid shift 3/15 NEW, 3/13 OLD; at the rigid or a per-half shift 5, 5
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_427_228_old_vs_new.png: matched at the rigid shift 3/19 NEW, 3/14 OLD; at the rigid or a per-half shift 6, 6
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_500_97_old_vs_new.png: matched at the rigid shift 2/12 NEW, 2/6 OLD; at the rigid or a per-half shift 4, 4
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_498_131_old_vs_new.png: matched at the rigid shift 8/96 NEW, 8/67 OLD; at the rigid or a per-half shift 13, 13
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_354_219_old_vs_new.png: matched at the rigid shift 6/39 NEW, 6/69 OLD; at the rigid or a per-half shift 10, 10
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_605_145_old_vs_new.png: matched at the rigid shift 5/83 NEW, 5/24 OLD; at the rigid or a per-half shift 9, 8
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_530_66_old_vs_new.png: matched at the rigid shift 4/10 NEW, 4/29 OLD; at the rigid or a per-half shift 5, 5
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_217_160_old_vs_new.png: matched at the rigid shift 3/20 NEW, 3/10 OLD; at the rigid or a per-half shift 5, 5
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_159_288_old_vs_new.png: matched at the rigid shift 2/5 NEW, 2/8 OLD; at the rigid or a per-half shift 3, 3
/home/mehes/projects/rac-spatial-model/docs/qa/T0/compare/overlap_pairs2/pair_575_351_old_vs_new.png: matched at the rigid shift 2/7 NEW, 2/10 OLD; at the rigid or a per-half shift 3, 3
/home/mehes/projects/rac-spatial-model/docs/qa/T0/new/pair_new_72_73_new.png: sym 0.093 k 26 sym2h 0.114 k2h 31; matched at the rigid shift 26, 26; at the rigid or a per-half shift 52, 54
/home/mehes/projects/rac-spatial-model/docs/qa/T0/new/pair_new_60_61_new.png: sym 0.081 k 17 sym2h 0.096 k2h 20; matched at the rigid shift 17, 17; at the rigid or a per-half shift 24, 25
/home/mehes/projects/rac-spatial-model/docs/qa/T0/old/pair_old_38_299.png: sym 0.143 k 10 sym2h 0.129 k2h 9; matched at the rigid shift 10, 10; at the rigid or a per-half shift 11, 11
/home/mehes/projects/rac-spatial-model/docs/qa/T0/old/pair_old_103_315.png: sym 0.200 k 2 sym2h 0.300 k2h 3; matched at the rigid shift 2, 2; at the rigid or a per-half shift 3, 3
```

Verdicts by group (the 91 shoes I looked at; what I saw in each pair is in the `note` column of the verdict file and summarised in `docs/qa/T0/README.md`):

```bash
$PY -I -B - <<'EOF'
import pandas as pd
c = pd.read_csv('docs/qa/T0/compare/overlap_candidates_t0_old_vs_new.csv')
v = pd.read_csv('docs/qa/T0/compare/overlap_verdicts_t0_old_vs_new.csv')
print('verdict rows', len(v), '| unique NEW', v.new.nunique(), '| candidate rows', len(c), '| candidates with a verdict', int(c.verdict.notna().sum()))
t0 = c.t0_rigid | c.t0_two_half
c['group'] = 'not reviewed'
c.loc[c.verdict.notna() & t0, 'group'] = 'T0 34'
c.loc[c.reviewer8, 'group'] = 'reviewer 8'
c.loc[c.verdict.notna() & ~t0 & ~c.reviewer8 & (c.n_stats >= 4), 'group'] = 'new, 4-5 statistics'
c.loc[c.verdict.notna() & ~t0 & ~c.reviewer8 & c.n_stats.between(2, 3), 'group'] = 'new, 2-3 statistics'
c.loc[c.verdict.notna() & ~t0 & ~c.reviewer8 & (c.n_stats == 1), 'group'] = 'new, 1 statistic (spot check)'
print(c.groupby(['group', c.verdict.fillna('not reviewed')]).agg(shoes=('new', 'size'), racs=('n_new', 'sum')).reset_index().to_string(index=False))
for vv in ('same_shoe', 'uncertain', 'different_shoe'):
    s = c[c.verdict == vv]
    print(f'{vv}: {len(s)} NEW shoes, {int(s.n_new.sum())} RACs ({s.n_new.sum() / 20013:.3f} of all NEW RACs)')
s = c[c.verdict.isin(['same_shoe', 'uncertain'])]
print(f'same_shoe + uncertain: {len(s)} shoes, {int(s.n_new.sum())} RACs ({s.n_new.sum() / 20013:.3f})')
EOF
```

```text
verdict rows 91 | unique NEW 91 | candidate rows 122 | candidates with a verdict 91
                        group        verdict  shoes  racs
                        T0 34      same_shoe     30  1253
                        T0 34      uncertain      4    56
new, 1 statistic (spot check)      same_shoe      2   135
new, 1 statistic (spot check)      uncertain      5   125
          new, 2-3 statistics different_shoe      2   169
          new, 2-3 statistics      same_shoe      6   280
          new, 2-3 statistics      uncertain      9   467
          new, 4-5 statistics      same_shoe     22   863
          new, 4-5 statistics      uncertain      3    66
                 not reviewed   not reviewed     31  1486
                   reviewer 8      same_shoe      7   627
                   reviewer 8      uncertain      1    41
same_shoe: 67 NEW shoes, 3158 RACs (0.158 of all NEW RACs)
uncertain: 22 NEW shoes, 755 RACs (0.038 of all NEW RACs)
different_shoe: 2 NEW shoes, 169 RACs (0.008 of all NEW RACs)
same_shoe + uncertain: 89 shoes, 3913 RACs (0.196)
```

Structural check. First without any visual input: pairs of consecutive NEW ids among the screen-flagged shoes, with the screen's partner; then the same among my verdicts; then the RAC match inside 21 such consecutive NEW pairs and between their OLD partners:

```bash
$PY -I -B - <<'EOF'
import pandas as pd
c = pd.read_csv('docs/qa/T0/compare/overlap_candidates_t0_old_vs_new.csv')
v = pd.read_csv('docs/qa/T0/compare/overlap_verdicts_t0_old_vs_new.csv')
c = c[c.n_stats >= 1]
sets = [('flagged by >= 1 statistic', c), ('flagged by >= 2 statistics', c[c.n_stats >= 2]), ('flagged by >= 4 statistics', c[c.n_stats >= 4]), ('flagged by all 5', c[c.n_stats == 5]),
        ('verdict same_shoe', v[v.verdict == 'same_shoe']), ('verdict same_shoe or uncertain', v[v.verdict != 'different_shoe'])]
for lab, sel in sets:
    part = dict(zip(sel.new, sel.old))
    pairs = [(a, a + 1) for a in sorted(part) if a + 1 in part]
    cons = [(a, b, part[a], part[b]) for a, b in pairs if abs(part[a] - part[b]) == 1]
    print(f'{lab} ({len(sel)} NEW shoes): {len(pairs)} consecutive-id NEW pairs, {len(cons)} onto consecutive OLD ids; expected if unrelated {len(pairs) * 2 / 386:.2f}')
    if lab == 'flagged by >= 1 statistic':
        print('   (NEW a, NEW a+1, OLD, OLD):', cons)
EOF
```

```text
flagged by >= 1 statistic (121 NEW shoes): 57 consecutive-id NEW pairs, 16 onto consecutive OLD ids; expected if unrelated 0.30
   (NEW a, NEW a+1, OLD, OLD): [(29, 30, 49, 50), (74, 75, 209, 210), (84, 85, 26, 25), (86, 87, 338, 337), (179, 180, 197, 196), (192, 193, 105, 106), (195, 196, 55, 56), (203, 204, 6, 5), (237, 238, 199, 198), (239, 240, 321, 320), (241, 242, 380, 379), (314, 315, 161, 162), (354, 355, 219, 220), (530, 531, 66, 67), (532, 533, 335, 336), (547, 548, 85, 84)]
flagged by >= 2 statistics (83 NEW shoes): 43 consecutive-id NEW pairs, 14 onto consecutive OLD ids; expected if unrelated 0.22
flagged by >= 4 statistics (66 NEW shoes): 30 consecutive-id NEW pairs, 10 onto consecutive OLD ids; expected if unrelated 0.16
flagged by all 5 (59 NEW shoes): 25 consecutive-id NEW pairs, 9 onto consecutive OLD ids; expected if unrelated 0.13
verdict same_shoe (67 NEW shoes): 32 consecutive-id NEW pairs, 13 onto consecutive OLD ids; expected if unrelated 0.17
verdict same_shoe or uncertain (89 NEW shoes): 46 consecutive-id NEW pairs, 16 onto consecutive OLD ids; expected if unrelated 0.24
```

```bash
$PY -I -B - <scratchpad>/t0fix2/overlap_pairs_cache.npz <<'EOF'
import sys
import numpy as np
z = np.load(sys.argv[1]); f = {k: i for i, k in enumerate(z['fields'])}
NN, OO = z['NEW_NEW'], z['OLD_OLD']; old_ids = list(z['old_ids']); nn, no = z['n_new'], z['n_old']
pairs = {(9, 10): (345, 306), (3, 4): (29, 110), (14, 15): (87, 94), (20, 21): (299, 38), (74, 75): (209, 210), (84, 85): (26, 25),
         (86, 87): (338, 337), (99, 100): (167, 73), (179, 180): (197, 196), (192, 193): (105, 106), (195, 196): (55, 56), (203, 204): (6, 5),
         (237, 238): (199, 198), (239, 240): (321, 320), (241, 242): (380, 379), (314, 315): (161, 162), (426, 427): (99, 228),
         (470, 471): (95, 264), (547, 548): (85, 84), (577, 578): (135, 96), (626, 627): (300, 326)}
o = lambda s: old_ids.index(s)
for (a, b), (c, d) in pairs.items():
    print(f'NEW {a}-{b} (n {nn[a-1]}, {nn[b-1]}): k {int(NN[a - 1, b - 1, f["k"]]):2d} | OLD {c}-{d} (n {no[o(c)]}, {no[o(d)]}): k {int(OO[o(c), o(d), f["k"]]):2d}')
EOF
```

```text
NEW 9-10 (n 37, 35): k  3 | OLD 345-306 (n 32, 44): k  2
NEW 3-4 (n 33, 23): k  2 | OLD 29-110 (n 65, 37): k  2
NEW 14-15 (n 25, 30): k  2 | OLD 87-94 (n 19, 27): k  2
NEW 20-21 (n 48, 56): k  4 | OLD 299-38 (n 70, 58): k 10
NEW 74-75 (n 16, 16): k  1 | OLD 209-210 (n 35, 34): k  3
NEW 84-85 (n 122, 120): k 12 | OLD 26-25 (n 112, 156): k 12
NEW 86-87 (n 40, 40): k  3 | OLD 338-337 (n 37, 39): k  4
NEW 99-100 (n 28, 69): k  2 | OLD 167-73 (n 37, 60): k  2
NEW 179-180 (n 16, 17): k  1 | OLD 197-196 (n 53, 38): k  5
NEW 192-193 (n 69, 67): k  4 | OLD 105-106 (n 37, 56): k  3
NEW 195-196 (n 48, 70): k  4 | OLD 55-56 (n 48, 62): k  2
NEW 203-204 (n 126, 111): k  9 | OLD 6-5 (n 102, 147): k  9
NEW 237-238 (n 31, 32): k  3 | OLD 199-198 (n 27, 26): k  2
NEW 239-240 (n 105, 121): k  8 | OLD 321-320 (n 36, 29): k  2
NEW 241-242 (n 36, 28): k  2 | OLD 380-379 (n 41, 28): k  2
NEW 314-315 (n 24, 23): k  1 | OLD 161-162 (n 25, 24): k  1
NEW 426-427 (n 23, 19): k  3 | OLD 99-228 (n 27, 14): k  1
NEW 470-471 (n 37, 20): k  2 | OLD 95-264 (n 19, 19): k  1
NEW 547-548 (n 27, 22): k  1 | OLD 85-84 (n 18, 22): k  1
NEW 577-578 (n 26, 27): k  2 | OLD 135-96 (n 45, 43): k  3
NEW 626-627 (n 53, 85): k  4 | OLD 300-326 (n 75, 54): k  5
```

The consecutive NEW shoes do not match each other (matched counts 1-12, at chance level for their n), so they are two soles of one wearer, not duplicates inside NEW; their OLD partners do not match each other either, except OLD 299-38 (10 matched; plan F26). A note on circularity: some verdicts cite this structure (for example 85-25 and 354-219), so the verdict-based lines are not independent evidence; the first four lines use only the screen's own flags and partners.

**Decision on the rule (A-042).** I did not adopt the reviewer's count z-score with 20 quantile bins of n_a x n_b as the rule. Its threshold (12.02) is set by a single heavy same-design NEW pair (72-73, 26 matched of 281 and 267 RACs, which I looked at: different soles, scattered chance coincidences), and its top bins mix pairs with very different n. Pair-level maxima within strata of both n bins, for five statistics, are simpler, and section D above shows what they flag and how often they fire on OLD-OLD pairs. Single flags include chance hits, so every candidate is reviewed by eye.

## 4. Finding B2 (critical): OLD estimation error in Part 2

Reviewer probe A, re-run unchanged:

```bash
cd /home/mehes/projects/rac-spatial-model && timeout 600 Rscript <scratchpad>/review_stat2/probeA_param_uncertainty.R > <scratchpad>/t0fix2/rerun_probeA.out 2>&1; diff <(grep -v "^exit" <scratchpad>/review_stat2/probeA.out) <scratchpad>/t0fix2/rerun_probeA.out && echo "probeA output identical"; cat <scratchpad>/t0fix2/rerun_probeA.out
```

```text
probeA output identical
max |G[, intercept]| = 2.96e-14 (must be ~0)
OLD proxy: 386 shoes, N = 13249 RAC pixels, K = 15 cells
E_k: 770 769 709 1046 859 992 943 981 979 978 953 856 896 824 696 
per-cell Var_param / Var_multinomial (N = N_old, model-based V): 0.978 0.998 0.944 1.282 1.079 1.234 1.218 1.098 1.232 1.102 1.077 1.139 1.238 1.156 1.122 
  median 1.122, max 1.282
N_new = 13249, V x 1.000: E[X^2] =  29.32 (K-1 = 14); true-model rejection at nominal 5%: 0.661, at 1%: 0.457
N_new = 13249, V x 1.281: E[X^2] =  33.69 (K-1 = 14); true-model rejection at nominal 5%: 0.772, at 1%: 0.597
N_new = 13249, V x 1.885: E[X^2] =  43.07 (K-1 = 14); true-model rejection at nominal 5%: 0.903, at 1%: 0.798
N_new = 18000, V x 1.000: E[X^2] =  34.89 (K-1 = 14); true-model rejection at nominal 5%: 0.796, at 1%: 0.630
N_new = 18000, V x 1.281: E[X^2] =  40.83 (K-1 = 14); true-model rejection at nominal 5%: 0.882, at 1%: 0.761
N_new = 18000, V x 1.885: E[X^2] =  53.57 (K-1 = 14); true-model rejection at nominal 5%: 0.960, at 1%: 0.907
N_new = 20013, V x 1.000: E[X^2] =  37.25 (K-1 = 14); true-model rejection at nominal 5%: 0.837, at 1%: 0.689
N_new = 20013, V x 1.281: E[X^2] =  43.85 (K-1 = 14); true-model rejection at nominal 5%: 0.910, at 1%: 0.809
N_new = 20013, V x 1.885: E[X^2] =  58.01 (K-1 = 14); true-model rejection at nominal 5%: 0.972, at 1%: 0.932
without the parameter term (what section 9 assumes): E[X^2] = 13.79, rejection at 5%: 0.046
```

Independent check, written from scratch (`docs/qa/T0/probes/t0_review2_param.R`, background, 500 s; the full output, with P2 and P3 used in sections 6 and 8):

```bash
Q=docs/qa/T0/probes; nohup bash -c "s=\$(date +%s); timeout 3600 Rscript $Q/t0_review2_param.R > <scratchpad>/t0fix2/t0_review2_param.out 2>&1; echo \"t0_review2_param.R exit \$? in \$(( \$(date +%s) - s ))s\" > <scratchpad>/t0fix2/t0_review2_param.status" &   # copied to $Q/t0_review2_param.out with the status line
```

```text
n_i: OLD 386 shoes, 13287 RACs; NEW 631 shoes, 20013 RACs

=== P1. Part 2 goodness of fit with OLD-estimated expectations
independent RACs (H0 true): 400 replicates, B = 199, 192 s
  mean X^2 (fixed E) = 33.65 (K - 1 = 14); mean two-sample bootstrap X^2* = 34.09
  rejection at nominal 5% (binomial SE 0.011): fixed-E pooled 0.787 | Wald, multinomial only 0.812 | Wald + parameter term 0.045 | NEW-only bootstrap 0.795 | two-sample bootstrap 0.050
between-shoe heterogeneity, Dirichlet(100 pi): 400 replicates, B = 199, 196 s
  mean X^2 (fixed E) = 57.08 (K - 1 = 14); mean two-sample bootstrap X^2* = 56.79
  rejection at nominal 5% (binomial SE 0.011): fixed-E pooled 0.968 | Wald, multinomial only 0.968 | Wald + parameter term 0.470 | NEW-only bootstrap 0.787 | two-sample bootstrap 0.035

=== P2. dispersion phi under a common misfit (NEW n_i, model known)
indep  (200 replicates): mean X^2 13.6 | phi centred on the model 0.966 | phi centred on the model minus the pooled misfit 0.965 | phi_0 0.968
misfit (200 replicates): mean X^2 207.4 | phi centred on the model 1.008 | phi centred on the model minus the pooled misfit 0.987 | phi_0 0.968
het    (200 replicates): mean X^2 20.9 | phi centred on the model 1.543 | phi centred on the model minus the pooled misfit 1.538 | phi_0 0.968
var(n)/mean(n): NEW 29.8, OLD 41.3

=== P3. Wald tests with a bootstrap covariance, p = 24
one dataset, B =  200: mean W 27.38 (theory p (B - 1) / (B - p - 2) = 27.45); rejection chi^2_24 0.1421, F(p, B - p) 0.0449
one dataset, B = 1000: mean W 24.55 (theory p (B - 1) / (B - p - 2) = 24.62); rejection chi^2_24 0.0622, F(p, B - p) 0.0485
equality, B = 200 per dataset (V2 = 2.25 V1): V1 + V2 from separate draws, chi^2_24: 0.0971 | one covariance of the paired differences: chi^2_24 0.1425, F(p, B - p) 0.0507

total 500 s
t0_review2_param.R exit 0 in 500s
```

Reading of P1: with OLD-estimated expectations, the fixed-E test, the NEW-only bootstrap and a multinomial Wald all reject a true model about 80% of the time. Adding the parameter term G V G' restores the size under independence (0.045) but not under heterogeneity (0.470). The two-sample bootstrap holds its size in both cases (0.050, 0.035), so it becomes the primary test (A-043).

## 5. Finding B4: the offset sign, on simulated and on real data

Reviewer probe B, re-run unchanged:

```bash
timeout 600 Rscript <scratchpad>/review_stat2/probeB_offset_sign.R > <scratchpad>/t0fix2/rerun_probeB.out 2>&1; diff <(grep -v "^exit" <scratchpad>/review_stat2/probeB.out) <scratchpad>/t0fix2/rerun_probeB.out && echo "probeB output identical"; cat <scratchpad>/t0fix2/rerun_probeB.out
```

```text
probeB output identical
simulated: 300 shoes, 8252 cases, true alpha = -6.20, slope 0.5, sigma^2 = 0.640 (sample var of a = 0.639), var(log(100/(px-cases))) = 0.1073
                                              intercept  slope sigma2
no offset (committed model form)                -1.6873 0.4858 0.7186
offset(log(100/(px - cases)))  [plan T6]         2.8139 0.4865 1.0522
offset(log((px - cases)/100))  [sign flipped]   -6.2018 0.4857 0.6145
mean log(100/(px - cases)) = -4.5144
```

On the committed OLD data (`docs/qa/T0/probes/t0_review2_offset.R`, background, 484 s; an earlier run stopped at the corrected fit because the probe passed per-shoe instead of per-row offsets, and a second run stopped at the plan-sign fit before the error was caught; both are in the scratchpad, and their first fit gave the same refit numbers):

```bash
Q=docs/qa/T0/probes; nohup bash -c "s=\$(date +%s); timeout 5400 Rscript $Q/t0_review2_offset.R > <scratchpad>/t0fix2/t0_review2_offset.out 2>&1; echo \"t0_review2_offset.R exit \$? in \$(( \$(date +%s) - s ))s\" > <scratchpad>/t0fix2/t0_review2_offset.status" &   # copied to $Q/t0_review2_offset.out with the status line
```

```text
OLD: 51849 rows, 386 shoes, 13249 cases; mean log(100/(px - cases)) = -4.610889, var = 0.0981

=== committed GLMM (written by R 4.4.3 on Windows)
intercept -2.271582 | sigma^2 0.9597791 | logLik -25819.2839

=== fits on this machine (R version 4.3.3 (2024-02-29))
no offset (committed form, local refit)      fit  245.8 s | intercept -2.271598 | sigma^2 0.9597959 | logLik -25819.2839 | conv 0
  refit vs committed: identical(fixef) FALSE, max |diff fixef| 0.000767, identical(vcov) FALSE, max |diff vcov| 2.12, |diff sigma^2| 1.68e-05
  relative: max |diff fixef| / |fixef| 0.00189, max |diff vcov| / max |vcov| 0.248, max |diff SE| / SE 0.121
  manual Wald (24 spatial coefficients = 0): committed W = 428.6933, local refit W = 427.7804
  committed model: max |vcov(use.hessian = TRUE) - vcov(use.hessian = FALSE)| / max |vcov| = 0.248
Warning message:
In vcov.merMod(m_comm, use.hessian = FALSE) :
  variance-covariance matrix computed from finite-difference Hessian
and from RX differ by >1e-04: consider 'use.hessian=TRUE'
offset(log((px - cases) / 100)) [corrected]  fit  231.0 s | intercept -6.883741 | sigma^2 0.9793341 | logLik -25821.7980 | conv 0
offset(log(100 / (px - cases))) [plan T6]    ERROR with default starting values: (maxstephalfit) PIRLS step-halvings failed to reduce deviance in pwrssUpdate
  retry from the implied starting values: ERROR: (maxstephalfit) PIRLS step-halvings failed to reduce deviance in pwrssUpdate

=== checks
expected corrected intercept = intercept(no offset) + mean(log(100/(px - cases))) = -6.882487; fitted -6.883741; difference -0.0013
max |spatial coefficients (corrected) - (no offset)| = 0.0184
cor(predicted random effect, log(1/f)): no-offset fit 0.130, corrected fit -0.178; var(log(1/f)) = 0.0981
sigma^2: no offset 0.9598, corrected 0.9793 (< 0.96: FALSE)
t0_review2_offset.R exit 0 in 484s
```

The corrected sign recovers the intercept relation (difference 0.0013), but its sigma^2 (0.979) is above the no-offset 0.960, so the reviewer's proposed check "sigma^2 below 0.96" is not used (A-044). The predicted random effect correlates 0.130 with log(1/f) in the no-offset fit and -0.178 in the corrected one: larger prints have a lower per-pixel intensity. The refit vs the committed model is a T1 lead (plan F37, K11). The largest vcov difference equals the committed model's own Hessian-vs-RX difference, so T1 must compare vcov computed the same way.

## 6. Finding B5: Wald tests with a bootstrap covariance

Reviewer probe C, re-run unchanged (background, 351 s):

```bash
nohup bash -c "s=\$(date +%s); timeout 1800 Rscript <scratchpad>/review_stat2/probeC_boot_wald.R > <scratchpad>/t0fix2/rerun_probeC.out 2>&1; echo \"exit \$? in \$(( \$(date +%s) - s ))s\" >> <scratchpad>/t0fix2/rerun_probeC.out" & # later: diff with the reviewer output (exit lines removed): "probeC output identical"
```

```text
probeC output identical
B =  200: mean W = 27.40 (theory 27.45 = p (B-1)/(B-p-2)); rejection at chi^2_24 5%: 0.1413; with the F(p, B-p) reference: 0.0495
B =  500: mean W = 25.19 (theory 25.27 = p (B-1)/(B-p-2)); rejection at chi^2_24 5%: 0.0756; with the F(p, B-p) reference: 0.0470
B = 1000: mean W = 24.58 (theory 24.62 = p (B-1)/(B-p-2)); rejection at chi^2_24 5%: 0.0640; with the F(p, B-p) reference: 0.0503
B = 2000: mean W = 24.33 (theory 24.30 = p (B-1)/(B-p-2)); rejection at chi^2_24 5%: 0.0576; with the F(p, B-p) reference: 0.0510
equality Wald, V1 + V2 each from B = 200: mean W = 25.62, rejection at chi^2_24 5%: 0.0900
exit 0 in 351s
```

My own run is in the P3 block of section 4 (B = 200: chi^2 0.1421, F 0.0449; B = 1,000: 0.0622, 0.0485; equality: separate V1 + V2 with chi^2 0.0971, paired differences with F 0.0507).

## 7. Minor m9: within-shoe pairs at small distances

```bash
nohup bash -c "s=\$(date +%s); timeout 1800 $PY -I -B <scratchpad>/review_stat2/probeF_pairs_small_r.py $PWD > <scratchpad>/t0fix2/rerun_probeF.out 2>&1; echo \"exit \$? in \$(( \$(date +%s) - s ))s\" >> <scratchpad>/t0fix2/rerun_probeF.out" & # later: diff with the reviewer output: "probeF output identical"
```

```text
probeF output identical
old: duplicate-pixel pairs (distance 0): 38
old: r (px)  observed pairs  expected (uniform on own contact)  ratio
     1.0       167         159.8  1.045
     1.5       372         307.8  1.209
     2.0       619         447.6  1.383
     3.0      1494         968.8  1.542
     4.0      2598        1574.3  1.650
     6.0      5437        3307.7  1.644
     8.0      8505        5350.9  1.589
    12.0     15615       10760.4  1.451
    16.0     24722       18054.2  1.369
    24.0     46610       36446.5  1.279
    32.0     70861       58608.2  1.209
old: nearest-neighbour distance (px) p1/p5/p10/p25/p50 = [1.0, 1.41, 2.24, 3.61, 6.4]; share <= 2 px: 0.088; <= 4 px: 0.282
new: duplicate-pixel pairs (distance 0): 23
new: r (px)  observed pairs  expected (uniform on own contact)  ratio
     1.0       127         201.8  0.629
     1.5       278         390.9  0.711
     2.0       530         568.7  0.932
     3.0      1557        1238.1  1.258
     4.0      2855        2012.0  1.419
     6.0      6263        4221.0  1.484
     8.0      9771        6789.0  1.439
    12.0     17963       13372.2  1.343
    16.0     27892       22179.5  1.258
    24.0     52394       44389.7  1.180
    32.0     77828       70323.4  1.107
new: nearest-neighbour distance (px) p1/p5/p10/p25/p50 = [1.0, 2.0, 2.83, 4.12, 8.0]; share <= 2 px: 0.051; <= 4 px: 0.224
exit 0 in 157s
```

Annulus ratios from the cumulative counts above, and the share of within-shoe pairs in the top 10% of shoes:

```bash
python3 - <scratchpad>/t0fix2/rerun_probeF.out <<'EOF'
import re, sys
txt = open(sys.argv[1]).read()
for ds in ('old', 'new'):
    block = txt.split(f'{ds}: r (px)')[1].split(f'{ds}: nearest')[0]
    rows = [tuple(map(float, l.split()[:3])) for l in block.strip().splitlines()[1:] if re.match(r'\s*\d', l)]
    r = {a: (b, c) for a, b, c in rows}
    out = [f'r <= 1: {r[1.0][0] / r[1.0][1]:.3f}', f'r <= 2: {r[2.0][0] / r[2.0][1]:.3f}']
    for lo, hi in ((2.0, 4.0), (4.0, 8.0), (2.0, 8.0), (8.0, 16.0), (16.0, 32.0)):
        o = r[hi][0] - r[lo][0]; e = r[hi][1] - r[lo][1]
        out.append(f'({lo:g}, {hi:g}]: {o:.0f}/{e:.1f} = {o / e:.3f}')
    print(f'{ds}: ' + '; '.join(out))
EOF
Rscript -e 'o <- read.csv("data/locations_data.csv"); r <- read.table("data/new_shoes/locations_data_new_raw.txt"); for (n in list(OLD = as.numeric(table(o$shoe)), NEW = as.numeric(table(r$V1)))) { p <- sort(n * (n - 1) / 2, decreasing = TRUE); cat(sprintf("shoes %d, unordered within-shoe pairs %d, share in the top 10%% of shoes (%d): %.3f\n", length(n), sum(p), floor(length(n) / 10), sum(p[seq_len(floor(length(n) / 10))]) / sum(p))) }'
```

```text
old: r <= 1: 1.045; r <= 2: 1.383; (2, 4]: 1979/1126.7 = 1.756; (4, 8]: 5907/3776.6 = 1.564; (2, 8]: 7886/4903.3 = 1.608; (8, 16]: 16217/12703.3 = 1.277; (16, 32]: 46139/40554.0 = 1.138
new: r <= 1: 0.629; r <= 2: 0.932; (2, 4]: 2325/1443.3 = 1.611; (4, 8]: 6916/4777.0 = 1.448; (2, 8]: 9241/6220.3 = 1.486; (8, 16]: 18121/15390.5 = 1.177; (16, 32]: 49936/48143.9 = 1.037
shoes 386, unordered within-shoe pairs 495507, share in the top 10% of shoes (38): 0.687
shoes 631, unordered within-shoe pairs 604681, share in the top 10% of shoes (63): 0.624
```

## 8. Minor m10: dispersion under a common misfit

See the P2 block of section 4: under independence both centrings match phi_0 (0.966, 0.965 vs 0.968). A common misfit with mean X^2 207 raises phi to 1.008 (centred on the model) and 0.987 (model minus the pooled-misfit share). Heterogeneity is detected by both (1.543, 1.538). The leak is real but small; A-051 adopts the second centring and the wording "or a systematic misfit".

## 9. Other checks

### 9.1 Minor m3: a missing contour record in step 2

```bash
cd /tmp && Rscript -e 'col_shoe <- 2; row_shoe <- 2; d <- "0101\r\n1100\r\n"; i <- 3; x <- substr(d, 1 + (col_shoe * row_shoe + 2) * (i - 1), (col_shoe * row_shoe + 2) * i - 2); cat(sprintf("record %d substring: [%s] nchar=%d\n", i, x, nchar(x))); m <- withCallingHandlers(matrix(as.numeric(unlist(strsplit(x, split = ""))), row_shoe, col_shoe, byrow = 1), warning = function(w) cat("WARNING:", conditionMessage(w), "\n")); print(m); cat("all NA:", all(is.na(m)), "| m == 1 selects", sum(m == 1, na.rm = TRUE), "cells; xcoor[m == 1] length:", length((1:4)[m == 1]), "\n")' 2>&1
```

```text
record 3 substring: [] nchar=0
     [,1] [,2]
[1,]   NA   NA
[2,]   NA   NA
all NA: TRUE | m == 1 selects 0 cells; xcoor[m == 1] length: 4
```

The expression is the reader of `dataCC_distance_2.Rmd:45-48` on a 2-record toy: record 3 does not exist, and R gives an all-NA matrix with no warning, whose `== 1` index then selects a full-length vector of NA (A-053).

### 9.2 Minor m5: the pinned `$SCRATCH` count

```bash
for c in 7165aa4 42af8dd f65911c; do printf '%s: %s / %s\n' $c "$(git show $c:docs/plans/2026-11-05-new-shoes-pipeline.md | grep -c -F '$SCRATCH')" "$(git show $c:docs/plans/2026-11-05-new-shoes-pipeline.md | grep -c -F 'SCRATCH=')"; done
```

```text
7165aa4: 3 / 0
42af8dd: 3 / 0
f65911c: 0 / 0
```

At `42af8dd` (before the first fix) the plan used `$SCRATCH` 3 times and never defined it; the fix commit `f65911c` replaced it by `RAC_SCRATCH`. In the agent's tool shell `grep` is a ugrep wrapper, which reads the leading `$` of `"\$SCRATCH"` as an anchor and prints 0, hence `-F`.

### 9.3 Reviewer probe D analysis, re-run unchanged

```bash
timeout 600 "$PY" -I -B <scratchpad>/review_stat2/probeD_analyze.py "$PWD" <scratchpad>/review_stat2/probeD_counts.npz > <scratchpad>/t0fix2/rerun_probeD_analyze.out 2>&1; diff <scratchpad>/review_stat2/probeD_analyze.out <scratchpad>/t0fix2/rerun_probeD_analyze.out && echo "probeD_analyze identical"
```

```text
probeD_analyze identical
T0 candidates (rigid or two-half): 34
NEW-NEW null: best z per shoe (n >= 5) p99 = 7.61, max = 12.02
count-z rule (z above the NEW-NEW null max 12.02): 34 NEW shoes; of them T0 candidates: 28; new: [57, 84, 99, 192, 198, 240]
not flagged by T0 but above the count-z null max:
 new  n_new  old  n_old  k_new  k_old  s_new  s_old      z    z2  cand   sym
 240    121  320     29     19     19  0.157  0.655 19.303 4.852 False 0.157
  84    122   26    112     33     32  0.270  0.286 15.332 4.300 False 0.270
 192     69  105     37     15     15  0.217  0.405 14.574 3.934 False 0.217
  57     52  177     21     10     10  0.192  0.476 13.647 3.727 False 0.192
  99     28  167     37     10     10  0.357  0.270 13.647 2.936 False 0.270
 198     41  371     27      9      9  0.220  0.333 12.034 3.230 False 0.220
T0 candidates below the count-z null max:
 new  n_new  old  n_old  k_new  k_old  s_new  s_old      z    z2  cand   sym
  14     25   87     19      6      6  0.240  0.316  9.765 3.653  True 0.240
  15     30   94     27      7      7  0.233  0.259 10.929 3.653  True 0.233
  92      5  209     35      2      2  0.400  0.057  2.414 1.765  True 0.057
 100     69   73     60     18     18  0.261  0.300  7.610 3.881  True 0.261
 245     18   91     14      6      7  0.333  0.500 10.106 3.970  True 0.333
 452      9  113     12      5      5  0.556  0.417  8.635 3.765  True 0.417
not flagged, max share >= 0.4 with >= 8 matched: 5
 new  n_new  old  n_old  k_new  k_old  s_new  s_old      z    z2  cand   sym
  57     52  177     21     10     10  0.192  0.476 13.647 3.727 False 0.192
 192     69  105     37     15     15  0.217  0.405 14.574 3.934 False 0.217
 239    105  321     36     15     15  0.143  0.417  5.955 5.955 False 0.143
 240    121  320     29     19     19  0.157  0.655 19.303 4.852 False 0.157
 604    130  134     40     20     20  0.154  0.500  8.713 4.852 False 0.154
NEW-NEW pairs with max share >= 0.4 and >= 8 matched: 0 of 198765
NEW-NEW best sym, n in [5, 10): shoes 67, p50 0.200, p99 0.286, max 0.286
NEW-NEW best sym, n in [10, 20): shoes 145, p50 0.143, p99 0.214, max 0.222
NEW-NEW best sym, n in [20, 40): shoes 210, p50 0.111, p99 0.166, max 0.174
NEW-NEW best sym, n in [40, 80): shoes 123, p50 0.094, p99 0.127, max 0.127
NEW-NEW best sym, n in [80, 300): shoes 39, p50 0.085, p99 0.116, max 0.120
```

## 10. Document checks, lint, CR bytes, tables

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
for f in $(git status --porcelain --untracked-files=all docs | awk '{print $2}' | grep -v -E "\.png$|T0-review2-fixes-results.md$"); do printf '%s %s\n' "$(tr -cd '\r' < "$f" | wc -c)" "$f"; done
```

```text
0 docs/2026-11-05-meeting-micha-new-shoes.md
0 docs/README.md
0 docs/decisions.md
0 docs/plans/2026-11-05-new-shoes-pipeline.md
0 docs/qa/T0/README.md
0 docs/qa/T0/probes/t0_review_pairs.out
0 docs/qa/T0/probes/t0_review_pairs.py
0 docs/tests/README.md
0 docs/tests/T0-review-fixes-results.md
0 docs/qa/T0/compare/overlap_candidates_t0_old_vs_new.csv
0 docs/qa/T0/compare/overlap_verdicts_t0_old_vs_new.csv
0 docs/qa/T0/probes/t0_review2_offset.R
0 docs/qa/T0/probes/t0_review2_offset.out
0 docs/qa/T0/probes/t0_review2_overlap.out
0 docs/qa/T0/probes/t0_review2_overlap.py
0 docs/qa/T0/probes/t0_review2_overlap_compute.out
0 docs/qa/T0/probes/t0_review2_param.R
0 docs/qa/T0/probes/t0_review2_param.out
```

```bash
python3 <scratchpad>/t0fix2/table_check.py docs/plans/2026-11-05-new-shoes-pipeline.md docs/decisions.md docs/qa/T0/README.md docs/tests/README.md docs/README.md docs/2026-11-05-meeting-micha-new-shoes.md docs/tests/T0-review-fixes-results.md   # every table row has the header's cell count
```

```text
inconsistent table rows: 0
```

This file itself was checked after it was written (0 CR bytes, consistent tables; see the LOG entry).

## 11. Old regression (docs-only change)

No pipeline step was re-executed, because no code or data changed (T1 builds the re-run harness). The check is byte identity of every tracked pipeline file with the baseline commit `79247d8`, and no change outside `docs/` (also counting untracked files):

```bash
git diff --name-only 79247d8 -- . ':(exclude)docs' | wc -l; git status --porcelain --untracked-files=all -- . ':(exclude)docs' | wc -l; n=0; bad=0; while IFS= read -r f; do a=$(git show "79247d8:$f" | sha256sum | cut -d" " -f1); b=$(sha256sum < "$f" | cut -d" " -f1); n=$((n+1)); if [ "$a" != "$b" ]; then bad=$((bad+1)); echo "DIFF $f"; fi; done < <(git ls-tree -r --name-only 79247d8 -- data processed_data saved_models model_images statistical_model reports); echo "compared $n files with their 79247d8 blobs, differing: $bad"
```

```text
0
0
compared 32 files with their 79247d8 blobs, differing: 0
```

The committed GLMM's manual Wald W = 428.6933 (df 24) is reprinted by `t0_review2_offset.R` (section 5), and nothing in this pass writes to the repo outside `docs/`.

## 12. Limits of this pass
- The overlap verdicts are my visual impressions; T3 re-checks every one (not copied) and reviews the 31 single-statistic candidates I did not look at. Only Micha and Yoram can say which shoes were printed twice (D-012).
- The n-calibrated thresholds come from NEW-NEW pairs, and chance matches against OLD shoes run slightly higher (section 3, part C), so single-statistic flags include chance hits. Shoes with < 5 RACs, and OLD partners with very few RACs (e.g. OLD 39 with 3), cannot be decided from RACs.
- The Part 2 corrections are specified and checked in a toy (cell model, independent shoes); T7 must re-check them on the real structure (the slow calibration test of plan T7).
- The GLMM reproducibility observations (F37) come from one refit; T1 owns that comparison.
