# T6 results: the OLD vs NEW comparison (commands and outputs)

**Date:** 2026-11-07. **Task:** T6-compare (plan task T6), and in section 12 its review fixes. **Branch:** `feature/new-shoes-pipeline`, HEAD `a3e7a06` during the first run (which made no commit: T7 worked in the same tree in parallel) and `a4edb42` when the review fixes started; the review fixes commit the T6 files (section 12.12). **Results and their reading:** `docs/results/old-vs-new.md`. Every output below is pasted from a real run; `<scratch>` = `/tmp/claude-1000/-home-mehes-projects-rac-spatial-model/1d789329-e60a-4147-af28-9c8214affef3/scratchpad`. Times are wall-clock on a machine shared with T7 (load from 4 to about 300 while T7 knitted with 4 forked workers of 2.5-3.5 GB each).

## 1. Summary

| Item | Result |
|---|---|
| Code | `statistical_model/compare_old_new_7.Rmd` (the comparison), `statistical_model/R/compare_old_new.R` (helpers), `tools/fit_compare_models.R` (one fit per call), `tools/run_compare_fits.sh` (every fit, in dependency order, each from a private copy of the script), `tests/r/test_compare_old_new.R` |
| Fits | 25 records in `saved_models/t6/` (8, OLD) and `saved_models/new/t6/*_new.rds` (17, NEW): 14 fits (the offset refit without reprints, full tensor, finer y with nAGQ 0, nAGQ 0 checks, NEW without reprints, NEW group B), five shoe bootstraps (B = 1,000, 0 failed; the two of the full tensors added by the review fixes), six sigma^2 profiles; the plan's two offset refits at `saved_models/NEW_X_NS_XY_offset.rds` and `saved_models/new/NEW_X_NS_XY_offset_new.rds` |
| Not fitted | the exact CMLs on the finer y basis (3.5 GB each; all five attempts killed (exit 137) while T7 ran, out of memory, section 3.3), the GLMMs on the finer y basis with nAGQ 1 (stopped; the Rmd uses nAGQ 0, validated) |
| Outputs | after the review fixes: 29 CSVs `processed_data/compare/*_old_vs_new.csv`, 21 PDFs `model_images/compare/*_old_vs_new.pdf`, 21 PNG copies `docs/qa/T6/*_old_vs_new.png`, every PNG looked at (results doc section 10) |
| Tests | `tests/r/test_compare_old_new.R` ALL PASS (section 6; with the review fixes' section 11, section 12.8); `bash tests/run_all.sh` see sections 7 and 12.9 |
| OLD regression | **identical**: `tests/regress_old.sh --steps 1-6` ALL PASS (sections 8 and 12.10); T6 changes no OLD pipeline file and no committed output |

## 2. Resuming an interrupted session

This task resumed after an interruption ("continue!"). The earlier T6 session had written the four code files (untracked), copied the repository to `<scratch>/t6/fits_repo` and started its fits there in the background: a queue `sched.sh` (6 at a time) and a bootstrap chain `boots.sh`. State at 07:10:

- done: `offset_old` (1273 s), `offset_new` (1651 s); running: `full_new_glmm`, `full_new_cml`, `norep_glmm`, `boot_old`; queued: 11 more.
- **an incident:** at 06:53 the earlier session had edited `tools/fit_compare_models.R` (and its scratch copy) in place while fits were running. Rscript reads its `--file` while it runs, so each job that had started before the edit read the new bytes once its fit returned. `/proc/<pid>/fdinfo` showed the jobs at file offsets 8192 and 12288; the bytes at offset 8192 of the edited file are 10 spaces and `profiles[[nm]]$fit))`, exactly the context of the first crash:

```
== full_old_glmm.log (started 06:09, crashed after its fit)
Error: unexpected symbol in:
"if (inherits(m, "error")) {
  if (!j$offset || !grepl("PIRLS|maxstephalfit", c          profiles"
Execution halted
== full_old_cml.log, and later full_new_cml.log and norep_glmm.log (the same error)
Error: unexpected symbol in:
"              min((se_boot / se_model)[-1]), max((se_boot / se_model)[-1])))
  quit(save = "no"
Execution halted
```

  `full_old_glmm` lost 3630 s, `full_old_cml` about 22 min, `full_new_cml` 2348 s, `norep_glmm` 2490 s, the old `full_new_glmm` 6420 s, all before saving anything. `fineY_new_cml` had been killed (exit 137) and `fineY_old_cml` terminated (exit 143) at the same time; swap was full and the load near 300.
- I tried to stop the doomed jobs and the queue (`kill -TERM` of the queue's process group); **the harness refused** ("Interfere With Workloads": processes of the earlier session). So they ran to their crash, and the queue and the bootstrap chain ran on; their later jobs had read the final script and are valid (section 3.1).
- From then on every fit of this session ran from a **frozen copy** of the script (`<scratch>/t6r/launch.sh`: copy the script, record the sha256 of the script and of `compare_old_new.R`, run, log START/END). `tools/run_compare_fits.sh` does the same for future runs, and the script's header now warns against in-place edits (A-T6-6).

## 3. The fits

### 3.1 What ran, where, and with which code

All fits wrote into `<scratch>/t6/fits_repo` (a copy of the repository) and were copied into the repository at the end (sha256 verified, 25 files `OK`). Every job ran `tools/fit_compare_models.R` with sha256 `c6e4da8c...` and `statistical_model/R/compare_old_new.R` `b4555d0d...` (15 of this session's 17 frozen copies record these two; the queue's jobs started after 06:53:31 read the same two files), except: the two plan offset refits (written by the earlier session at 06:30 and 06:36 with an earlier version, reproduced exactly by the final code in section 4.2) and the last two launches, the bobyqa refit of `full_new_glmm` (section 3.2) and the third `fineY_new_cml` attempt, which ran `03b1da22...` (the final script up to comments). The final repository files differ from those versions as follows, and no fit function changed:

```
$ diff <(grep -v '^ *#' <scratch>/t6r/frozen/20261107_072937_full_new_glmm/fit_compare_models.R) <(grep -v '^ *#' tools/fit_compare_models.R)
34c34,35
<   full_new_glmm = job("new", glmm, "full_own", stem = "NEW_X_NS_XY_full"),
---
>   full_new_glmm = job("new", glmm, "full_own", stem = "NEW_X_NS_XY_full",
>                       optimizer = "bobyqa"),
$ diff <(grep -v '^ *#' <scratch>/t6r/frozen/20261107_091028_full_new_glmm/fit_compare_models.R) <(grep -v '^ *#' tools/fit_compare_models.R)
(no output: the bobyqa refit of 3.2 ran from 03b1da22..., which differs from the final file only in comments)
$ sha256sum tools/fit_compare_models.R
699c8ddd9bf5d187df80e2eaa5b56edf5e498f8e72070a5fbdc1426be39f3f6c  tools/fit_compare_models.R
$ Rscript -e '<both versions of compare_old_new.R in two environments; identical(deparse()) per function>'
         t6_spec        t6_design           t6_fit       t6_shoe_px
            TRUE             TRUE             TRUE             TRUE
t6_offset_values       fit_offset  t6_offset_start          t6_keys
            TRUE             TRUE             TRUE             TRUE
      t6_summary    t6_from_model    t6_pirls_beta      t6_resample
            TRUE             TRUE             TRUE             TRUE
     t6_fit_path    t6_new_output   t6_reprint_ids       t6_group_a
            TRUE             TRUE             TRUE             TRUE
T6_SEEDS identical: TRUE
changed functions: t6_boot_draws, t6_boot_pair, t6_cal_rows, t6_logdens_sd, t6_wald_boot (new); t6_grid (changed)
```

Each job, its log line (`done ...`) and who ran it (Q = the earlier session's queue or bootstrap chain, which kept running; S = this session):

| job | output | by | log |
|---|---|---|---|
| offset_old | `saved_models/NEW_X_NS_XY_offset.rds` (full model) | Q | 1273 s; conv 0; loglik -25821.7980; sigma^2 0.9793341 |
| offset_new | `saved_models/new/NEW_X_NS_XY_offset_new.rds` | Q | 1651 s; conv 0; loglik -41523.2326; sigma^2 0.6410199 |
| nagq0_old / nagq0_new | `t6/NEW_X_NS_XY_nagq0` | Q | 6 s, loglik -25819.3962, sigma^2 0.9605549 / 8 s, -41569.3869, 0.7579198 |
| full_old_glmm | `t6/NEW_X_NS_XY_full` | S | 2099 s; conv 0; loglik -25800.2537; sigma^2 0.9611115; 35 coefficients |
| full_new_glmm | `t6/NEW_X_NS_XY_full_new` | S | see 3.2 |
| full_old_cml / full_new_cml | `t6/CML_MODEL_full` | S | 1212 s, loglik -24163.0380 / 1684 s, -38892.0048; 34 coefficients |
| fineY_old_glmm0 | `t6/NEW_X_NS_XY_fineY_nagq0` | Q | 18 s; loglik -25738.1993; sigma^2 0.9617056; 85 coefficients |
| fineY_new_glmm0 | `t6/NEW_X_NS_XY_fineY_nagq0_new` | Q | 73 s; loglik -41379.8248; sigma^2 0.7303256 |
| fineYold_new_glmm0 | `t6/NEW_X_NS_XY_fineYold_nagq0_new` | Q | 100 s; loglik -41389.8529; sigma^2 0.7302406 |
| norep_glmm | `t6/NEW_X_NS_XY_oldbasis_norep_new` | S | 1486 s; conv 0; loglik -34197.5334; sigma^2 0.7768825 (542 shoes, 70,280 rows, 16,080 cases) |
| norep_cml | `t6/CML_MODEL_oldbasis_norep_new` | Q | 475 s; loglik -31962.9100 |
| groupB_glmm / groupB_cml | `t6/..._oldbasis_groupB_new` | Q | 198 s, loglik -13571.0870, sigma^2 0.6750451 / 102 s, -12628.2030 (239 shoes, 5,881 cases) |
| offset_norep | `t6/NEW_X_NS_XY_offset_oldbasis_norep_new` | Q | 1988 s; conv 0; loglik -34156.9346; sigma^2 0.654482 |
| boot_old | `t6/NEW_X_NS_XY_bootpirls` | Q | 1000 draws (0 failed), 1298 s; \|beta_pirls(all) - fit\| max 0.0281; bootstrap / model SE (spatial): median 1.130, min 1.025, max 1.352 |
| boot_new_ob | `t6/NEW_X_NS_XY_oldbasis_bootpirls_new` | Q | 1000 draws (0 failed), 1550 s; max 0.0238; median 1.089, min 0.965, max 1.220 |
| boot_norep | `t6/NEW_X_NS_XY_oldbasis_norep_bootpirls_new` | Q | 1000 draws (0 failed), 898 s; max 0.0257; median 1.100, min 1.005, max 1.204 |
| profile_glmm_old | `t6/profile_NEW_X_NS_XY` | S | deviance at the estimates 51638.5679 (-2 logLik 51638.5679); sigma^2 [0.8217, 1.1272]; 587 evaluations, 111 s |
| profile_glmm_new | `t6/profile_NEW_X_NS_XY_new` | S | 83138.2438 (= -2 logLik); [0.6666, 0.8592]; 583, 169 s |
| profile_off_old | `t6/profile_NEW_X_NS_XY_offset` | S | 51643.5959 (=); [0.8391, 1.1493]; 663, 155 s |
| profile_off_new | `t6/profile_NEW_X_NS_XY_offset_new` | S | 83046.4653 (=); [0.5645, 0.7301]; 545, 198 s |
| profile_norep | `t6/profile_NEW_X_NS_XY_oldbasis_norep_new` | S | 68395.0669 (=); [0.6784, 0.8929]; 582, 114 s |
| profile_off_norep | `t6/profile_NEW_X_NS_XY_offset_oldbasis_norep_new` | S | 68313.8692 (=); [0.5703, 0.7538]; 479, 91 s |

The bootstraps resample whole shoes (a shoe drawn twice is two groups) and refit the fixed effects by PIRLS at the fit's theta (lme4's nAGQ 0 deviance function), centred on the fit; their seeds are `T6_SEEDS` (20261107-20261109) and the resampled ids are stored with the draws. The profiles move theta with the intercept re-optimized and the spatial coefficients held at the estimates (the Laplace deviance of `glmer`); in every profile the deviance at the estimates equals -2 logLik of the fit, which ties the profile's design to the fit.

### 3.2 The NEW full-tensor GLMM: nlminb's iteration limit, refitted with bobyqa

The first run (step-3's optimizer `nlminbwrap`) stopped at nlminb's iteration limit:

```
Warning message:
In optwrap(optimizer, devfun, start, rho$lower, control = control,  :
  convergence code 1 from nlminbwrap: iteration limit reached without convergence (10)
done full_new_glmm: 4148 s; conv 1; loglik -41523.5066; sigma^2 0.7571055; 35 coefficients
```

`test_compare_old_new.R` caught it (`r$conv == 0 is not TRUE`). The job now uses bobyqa (as the finer-y nAGQ 1 jobs do; A-T6-9) and was refitted with `--force`; the conv-1 record is kept as `<scratch>/t6r/NEW_X_NS_XY_full_new_nlminb_conv1.rds`:

```
$ cp tools/fit_compare_models.R <scratch>/t6/fits_repo/tools/ && <scratch>/t6r/launch.sh full_new_glmm --force
Warning messages:
1: In commonArgs(par, fn, control, environment()) :
  maxfun < 10 * length(par)^2 is not recommended.
2: In optwrap(optimizer, devfun, start, rho$lower, control = control,  :
  convergence code 1 from bobyqa: bobyqa -- maximum number of function evaluations exceeded
done full_new_glmm: 2797 s; conv 1; loglik -41523.5066; sigma^2 0.7571014; 35 coefficients
```

bobyqa also stopped at its limit (minqa's default maxfun of 10,000 evaluations, below the 10 x 36^2 = 12,960 that minqa recommends for 36 parameters), at the same point as nlminb. Two different optimizers agreeing is evidence of the optimum; the gradient check (`<scratch>/t6r/probes/full_new_gradcheck.R`) confirms it: the Laplace deviance rebuilt from the NEW step-2 rows equals -2 logLik at both points and is flat there.

```
$ Rscript <scratch>/t6r/probes/full_new_gradcheck.R <dev copy> <nlminb record> <bobyqa record>
t6r (nlminbwrap): deviance 83047.0132 vs -2 logLik 83047.0132; gradient: theta 0.0047, fixed effects max |g| 0.0170 (y5); max |g| x SE 0.0415
t6 (bobyqa): deviance 83047.0131 vs -2 logLik 83047.0131; gradient: theta -0.0015, fixed effects max |g| 0.0127 (x2:y3); max |g| x SE 0.0135
$ Rscript -e '<the two records>'
loglik -41523.5065835 -41523.5065639
theta 0.8701181 0.8701157
max |fixef diff| 0.006205567 at x3:y5 ; max |diff| / SE 0.003251491
```

The bobyqa record is the one used (higher log-likelihood by 2e-5, smaller gradient). It keeps the optimizer's code 1; `tests/r/test_compare_old_new.R` accepts a GLMM record with a nonzero code only after recomputing this gradient check itself (|g| <= 0.05 for theta and |g| x SE <= 0.05 for every fixed effect; A-T6-9). For comparison, the T5 NEW GLMM was accepted on a gradient of 0.024 (theta) and 0.0051 (fixed effects) (A-115).

### 3.3 The exact CMLs on the finer y basis: out of memory

The exact conditional likelihood (survival's `clogit(method = "exact")`) on the 84-coefficient finer y basis needs about 3.5 GB, set by the largest strata (NEW shoes 72 and 73 with 281 and 267 case pixels). Measured on the five largest NEW strata alone (`<scratch>/t6r/probes/cml_mem.R`):

```
largest NEW shoes: 72 73 60 61 187 cases 281 267 209 202 153
exact CML fineY on the 5 largest strata (1612 rows, 1112 cases): 348 s, iter 5
	Maximum resident set size (kbytes): 3302612
```

Every attempt ended with exit 137 (SIGKILL) while T7's knits held about 10 GB (four forked workers of 2.5-3.5 GB): `fineY_new_cml` started at 06:09 (earlier session; killed after 3631 s), 08:12 (996 s) and 09:17 (2358 s, started alone behind an 8 GB check); `fineY_old_cml` (545 s) and `fineYold_new_cml` (1239 s) from the queue at 08:31-08:52. The kernel log still holds three of the kills, each the out-of-memory killer's kill of a 3.5 GB R process (08:29, 08:52, 09:56; e.g. `Out of memory: Killed process 31670 (R) total-vm:3692416kB, anon-rss:3529736kB`); the older ones have left the log. I stopped retrying (A-T6-10): the finer-y sensitivity is complete through the GLMMs (nAGQ 0), and the Rmd includes the exact CMLs automatically once they exist (`bash tools/run_compare_fits.sh --jobs 1 fineY_old_cml fineY_new_cml fineYold_new_cml` on an otherwise idle machine, about 1.5-2 h each). The three nAGQ 1 GLMMs on the finer y basis were started at 08:16 and stopped by me after 14 minutes (exit 143) to relieve the memory; the Rmd uses them too if their records exist.

## 4. Checks of the code and of the inherited fits

### 4.1 The bootstrap helpers (`<scratch>/t6r/probes/boot_probe.R`, OLD bootstrap)

```
draws 1000 25 failed 0 seconds 1298
draw means - coef: max 0.0933215 (bootstrap bias of the PIRLS surrogate, centred)
all-spatial Wald: model-based (RX) W 427.77; bootstrap W 255.27, F 10.391 on (24, 976), p 1.73e-34
     new_x       y dens1000 se_model se_boot ratio    lo    hi
1  0.18495 0.10500    3.603  0.04928 0.05937 1.205 3.208 4.034
2 -0.06167 0.37500    3.705  0.04320 0.05519 1.278 3.292 4.094
3 -0.09965 0.09167    3.396  0.05364 0.06666 1.243 2.986 3.869
4  0.03807 0.47167    1.620  0.09729 0.13216 1.359 1.242 2.069
streaming SD 0.05519285 explicit sd() 0.05519285 diff -6.80983e-14
quantile check 3.292052 4.093762
```

### 4.2 The inherited offset refits reproduce exactly (`<scratch>/t6r/probes/offset_repro.R`)

The two plan-path offset models were written by the earlier session's script; the final `fit_offset()` refits them and every field is `identical()`:

```
old refit: 334 s
  fixef   theta  logLik vcov_rx VarCorr   ranef  offset       X       y
   TRUE    TRUE    TRUE    TRUE    TRUE    TRUE    TRUE    TRUE    TRUE
max |fixef diff| 0; sigma^2 0.9793341 vs 0.9793341
SAME: every field identical()
new refit: 1074 s
  fixef   theta  logLik vcov_rx VarCorr   ranef  offset       X       y
   TRUE    TRUE    TRUE    TRUE    TRUE    TRUE    TRUE    TRUE    TRUE
max |fixef diff| 0; sigma^2 0.6410199 vs 0.6410199
SAME: every field identical()
```

### 4.3 Smaller checks

- **The prototype grid was not bit-identical to step 4's.** The inherited `t6_grid()` computed x as `(-col/2 + k) * (0.5 / 150)`, step 4 as `(-col/2 + k) * 0.5 / 150`; the test's step-4 comparison failed (`identical(xy[[1]], G$x) is not TRUE`). `t6_grid()` now uses step 4's operations, and the test passes (section 6: the step-3 design on the grid and the map are `identical()` to step 4's).
- **A latent bug, fixed before it fired:** the Rmd read the nAGQ 1 finer-y GLMMs in `for (k in c(fineY = ..., fineYold = ...))` and named them with `names(k)`, which is NULL inside such a loop, so an existing record would have replaced `FIT$glmm_old`.
- **T6 and T7 transcribe Naomi's areas alike:** `naomi_area()` of `compare_old_new.R` and of T7's `validation.R` give identical labels on 200,008 points (200,000 random, 8 on the boundaries).
- **Colours:** `node scripts/validate_palette.js "#2a78d6,#eb6834,#1baf7a,#6250d6" --mode light` (dataviz skill): every check PASS (worst colour-vision-deficiency pair ΔE 9.2), one WARN (aqua against the surface, 2.74:1), so those series always carry legends or direct labels. Sequential maps use one blue ramp, ratio and difference maps a blue-red diverging ramp with a grey midpoint.
- **The Efron approximation is not a substitute for the exact CML on maps** (`efron_vs_exact_cml_old_vs_new.csv`): on OLD's basis it moves the CML map by 0.90-1.39 (OLD; p5 0.94, p95 1.16) and 0.92-1.29 (NEW), coefficients by up to 0.59 and 0.49.

## 5. The knit

```bash
cd statistical_model && Rscript -e 'rmarkdown::render("compare_old_new_7.Rmd", output_dir = "../logs/knit/compare", intermediates_dir = tempdir())'
```

Run at 10:00 (the third full run; the first two, at 08:57 and 09:04, preceded the figure polish and the bobyqa record). `/usr/bin/time -v`: elapsed 2:58.51, maximum resident set size 1237700 kB. The end of its printed output:

```
## every required fit present
## not included (the slow exact CMLs on the finer y basis are not fitted yet):
##    saved_models/t6/CML_MODEL_fineY.rds
##   saved_models/new/t6/CML_MODEL_fineY_new.rds
##   saved_models/new/t6/CML_MODEL_fineYold_new.rds
##   cml variant fineY
##   cml variant fineYcommon
## T6 Rmd: 169 s
```

Outputs: 24 CSVs in `processed_data/compare/`, 18 PDFs in `model_images/compare/`, 18 PNGs in `docs/qa/T6/` (one per PDF), and the HTML log `logs/knit/compare/compare_old_new_7.html` (ignored by git). The CSVs come from a fixed seed (`set.seed(313)`, the OLD profile's seed, before the parametric area simulation); the bootstrap draws are stored with their resampled ids. Development runs used `T6_ALLOW_MISSING=1` in a scratch copy of the repository (`<scratch>/t6r/dev_repo`) while fits were missing; the committed outputs come from runs without it.

**The outputs reproduce.** A second, independent knit at 10:09 in the scratch copy (the final code, the same fit records read from `<scratch>/t6/fits_repo`, outputs written into the copy) against the repository's outputs:

```
CSVs compared: 24, differing: 0
PNGs compared: 18 byte-identical: 18
$ diff <(python3 tests/lib/pdf_normalize.py model_images/compare/*.pdf) <(python3 tests/lib/pdf_normalize.py <copy>/model_images/compare/*.pdf)
18 PDFs equal after their dates are removed
```

## 6. Tests: `tests/r/test_compare_old_new.R`

```
$ Rscript tests/r/test_compare_old_new.R
PASS names: compare files in compare folders with _old_vs_new; NEW fits new/t6/*_new.rds; OLD fits t6/*.rds; no overwrite
PASS bases: the step-3 design on the prototype grid = step 4's newdesignmat (both datasets); full 34, finer y 84 columns
PASS maps: t6_step4_map = step 4's intens, identical(), OLD GLMM and NEW CML; 395 x 307, NA outside the mask (19 s)
        known      paired_F separate_chi2
       0.0415        0.0425        0.0825
PASS equality_wald: W(b, b) = 0; under H0 known V 0.0415, paired draws with F(24, 176) 0.0425 (both in [0.03, 0.07]); separate draws with chi^2 0.0825 (reported)
PASS fit_offset: offsets log((px - n)/100) on 20 NEW shoes (max diff 0), own basis; t6_eta refuses MEAN_OFFSET for an offset refit
PASS OLD offset refit: offsets exact; intercept -6.883741 vs predicted -6.882471; largest spatial change 0.0177; sigma^2 0.979334 (no offset 0.959779)
PASS NEW offset refit: offsets exact; intercept -6.348111 vs predicted -6.352160; largest spatial change 0.0835; sigma^2 0.641020 (no offset 0.755613)
PASS calibration: weights sum to the contact pixels, the RAC total reproduced; delta gradient = numerical (max diff 9.5e-09)
PASS Naomi's areas: = her loops on 20,003 points; 14 areas on the prototype; mirrored differs from unmirrored on 100% of it
PASS NEW_X_NS_XY_full_new.rds: bobyqa stopped at its limit (conv 1); the deviance = -2 logLik there, gradient theta -0.0015, max |g| x SE 0.0135
PASS T6 records: 14 fits tied to the step-2 rows of their rule (knots, shoes, rows, cases), converged
PASS T6 tables: fixef table = the models (OLD GLMM, NEW GLMM on the OLD basis); GLMM equality W 129.523 recomputed
PASS bootstrap helpers: draws tied to their fit, paired differences, Wald with F(p, B - p), streamed SD and quantiles = explicit
PASS bootstrap record NEW_X_NS_XY_bootpirls.rds: 1000 draws (0 failed), seed 20261107, centred on NEW_X_NS_XY, ids of its 386 shoes
PASS bootstrap record NEW_X_NS_XY_oldbasis_bootpirls_new.rds: 1000 draws (0 failed), seed 20261108, centred on NEW_X_NS_XY_oldbasis, ids of its 631 shoes
PASS bootstrap record NEW_X_NS_XY_oldbasis_norep_bootpirls_new.rds: 1000 draws (0 failed), seed 20261109, centred on NEW_X_NS_XY_oldbasis_norep, ids of its 542 shoes
PASS T6 tables: the bootstrap equality Wald 51.878 (F(24, 976), p 0.00143) recomputed from the two bootstrap records
PASS T6 tables: the OLD bootstrap all-spatial Wald 255.266 (F reference, B = 1000) recomputed from its record
PASS fit runner: tools/run_compare_fits.sh runs each of the 31 jobs of fit_compare_models.R --list once, in dependency order
ALL PASS test_compare_old_new (90 s)
```

Elapsed 1:33.24 (`/usr/bin/time`), exit 0 (rerun at 10:45 on the final files, after two comment-only edits of the scripts: `ALL PASS test_compare_old_new (85 s)`); R's warnings about the OLD GLMM's two vcovs (Hessian and RX differ by more than 1e-4, known issue K11) omitted. What the sections assert is in the test's header; the ones that came from this task: the full-tensor gradient rule (8), the bootstrap helpers and records and both bootstrap Wald statistics recomputed from the records (9), and the fit runner's coverage (10). Earlier runs of the same test found the two defects of section 4.3 (grid arithmetic, before the fix: `identical(xy[[1]], G$x) is not TRUE`) and of section 3.2 (`r$conv == 0 is not TRUE`), and a table filter that matched two rows once the bootstrap row existed (`nrow(e1) == 1 is not TRUE`, fixed in the test).

## 7. The fast suite

```bash
bash tests/run_all.sh
```

**Second run (10:20-10:31), after the fixes below; no file of this task changed during it:**

```
== summary
PASS         0s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS       150s  python unittest discover tests/python
PASS         5s  Rscript tests/r/test_baseline_committed.R
PASS        39s  Rscript tests/r/test_compare.R
PASS        22s  Rscript tests/r/test_compare_glmm_fits.R
PASS         3s  Rscript tests/r/test_compare_models.R
PASS        84s  Rscript tests/r/test_compare_old_new.R
PASS        50s  Rscript tests/r/test_distances_vectorized.R
PASS        20s  Rscript tests/r/test_figures_png.R
PASS        37s  Rscript tests/r/test_new_outputs.R
PASS         6s  Rscript tests/r/test_no_hardcoding.R
PASS         3s  Rscript tests/r/test_old_regression.R
PASS        38s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         2s  Rscript tests/r/test_profile.R
PASS        56s  Rscript tests/r/test_profile_sentinels.R
PASS         9s  Rscript tests/r/test_run_manifest.R
PASS         1s  Rscript tests/r/test_step5_variant.R
PASS        10s  Rscript tests/r/test_sticker_masks.R
PASS         3s  Rscript tests/r/test_validation_areas.R
PASS         1s  Rscript tests/r/test_validation_pairs.R
PASS        39s  Rscript tests/r/test_validation_pixels.R
PASS        30s  Rscript tests/r/test_validation_stats.R
PASS         4s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python files)
PASS         6s  shellcheck (all shell scripts)
FAIL(1)      0s  work tree unchanged by the tests (no file created or modified)
SOME CHECKS FAILED

real	10m20.143s
user	11m7.709s
sys	0m59.822s
```

Every test passes. The one failed check, "work tree unchanged", saw T7's files change while the suite ran (T7 kept working in the same tree); its diff (truncated by the runner at 20 lines) begins:

```
== work tree unchanged by the tests (no file created or modified)
427c427
< ./docs/results/validation.md 44081 1794037613.6488072250
---
> ./docs/results/validation.md 44457 1794039939.4089436730
449c449
< ./docs/tests/T7-results.md 28595 1794039654.9642786370
---
> ./docs/tests/T7-results.md 30678 1794039925.0744204100
3625c3625
< ./logs/knit/validation/validation_8.html 725292 1794039574.8145426730
---
> ./logs/knit/validation/validation_8.html 725386 1794039873.8869998510
```

None of T6's files changed during the run (`find <the T6 files and folders> -newermt "2026-11-07 10:20:56"` finds 0), and `sha256sum -c tests/baseline/old_added_t6.sha256` passes after it. `tests/r/test_compare_old_new.R` took 84 s in the suite.

**First run (10:08-10:20), three failures, each traced:**

| check | cause | fix |
|---|---|---|
| `test_new_outputs.R` (no collision) | T7's `processed_data/validation/` files were in no `old_added_*` list (the T6 files outside the NEW folders already were, in `tests/baseline/old_added_t6.sha256`, written at 10:07; a separate run of the same test at 09:35, before that list, had failed on them too, and one at 10:08 listed only T7's files as extra) | T7 added its own `old_added_t7.sha256` before the second run |
| `test_no_hardcoding.R` | the bootstrap toy of `test_compare_old_new.R` used 300 draws, and 300 is one of the scanned dataset numbers (`rel_row_shoe`) | the toy uses 240 draws |
| work tree unchanged | I edited the two T6 docs during the run, and T7 wrote its files | none needed: the second run was left alone by me |

## 8. OLD regression

T6 adds files only. `git diff --stat a3e7a06` lists no tracked file (the tracked tree is unchanged; T6's files are all new), so no OLD pipeline code, profile value, committed output or raw file changed. The gate was run anyway, from a copy of the work tree taken at 08:22 (with the T6 code):

```
$ RAC_SCRATCH=<scratch>/t6r/regress bash tests/regress_old.sh --steps 1-6
== regress_old.sh --steps 1-6: <scratch>/t6r/regress/regress_old_Hr2ZGk
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
step1       513.703949962  0
step2       36.167509477   0
step3_glmm  393.332029041  0
step3_cml   983.305380463  0
step4_glmm  23.888326317   0
step4_cml   22.320813917   0
step5       42.046571005   0
step6       29.971838052   0
ALL PASS
```

Step 0 was not rerun: T6 does not touch the contour code or its inputs.

## 9. Decisions (agent calls)

Numbered `A-T6-n` here so that they could not clash with T7's numbers. **Merged into `docs/decisions.md` by the review fixes as A-122 to A-132** (A-T6-n = A-(121 + n)), with pointers to their corrections A-133 to A-138 (section 12). The text below is the first run's.

### A-T6-1 Names of the T6 outputs, and a write-once list of the files outside the NEW folders
- **Decision:** the plan's names (section 5): `processed_data/compare/<what>_old_vs_new.csv`, `model_images/compare/<what>_old_vs_new.pdf`, `docs/qa/T6/<what>_old_vs_new.png`; T6 fits `saved_models/t6/<stem>.rds` (OLD) and `saved_models/new/t6/<stem>_new.rds` (NEW, user rule 1); the two offset refits at the plan's paths. Not the task text's `*_compare.*`: the plan rules, and the T0 and T5 compare files already end in `_old_vs_new`; both forms namespace the files (folder and suffix). The OLD-side files (50: the 24 CSVs, the 18 PDFs, the OLD offset refit and the 7 OLD records) are listed in `tests/baseline/old_added_t6.sha256`, the per-task list that `tests/r/test_new_outputs.R`'s collision check reads (A-082). Its hashes of the PDFs change with every knit (embedded dates); only the names are read by that check.
- **Note:** T7 added its own list, `tests/baseline/old_added_t7.sha256` (10:25); the collision check passes since (section 7). Neither list is checked by hash in `tests/run_all.sh` (only `old_added_t2.sha256` is); if the closing agent wants that, the PDF entries need the date-free hash of `tests/lib/pdf_normalize.py`.

### A-T6-2 The maps are calibrated to each dataset's observed RAC total
- **Decision:** each map = the model surface with the random effect at 0, scaled to reproduce its dataset's RAC total over all shoes' contact surfaces (RAC pixels per 1,000 contact pixels), with the delta-method SE of its log; step 4's levels (`MEAN_OFFSET`, exp(-sigma^2/2)) are shown once (`intensity_maps_asdrawn`). **Why:** the two datasets' step-4 levels are not comparable (K3, K4, D-009, plan F81); calibrated, the level and the shape mean the same in both. The calibration's weights add up to every shoe's contact pixels and its gradient equals a numerical one (test section 6).

### A-T6-3 The shoe bootstrap of the GLMMs by PIRLS at the fit's theta; the CML gets the Efron cluster-robust test only
- **Decision:** B = 1,000 shoe resamples per dataset (OLD; NEW on the OLD basis; NEW without reprints), fixed effects refitted by PIRLS (lme4's nAGQ 0 deviance function) at the fit's theta and centred on the fit, ids stored, seeds `T6_SEEDS`; the equality test pairs the draws of the two datasets by index (Hotelling F(24, B - 24), A-045); bootstrap bands at the cuts and bootstrap |z| on the common-basis maps. The exact CML is not bootstrapped (2-16 min per refit here). **Why:** a Laplace refit took 6-33 min here, 3,000 of them were out of reach; the PIRLS surrogate's draws reproduce the cluster-robust picture (SE ratios median 1.13 OLD and 1.09 NEW, against the Efron cluster-robust 1.13 and 1.06), and its own bias is removed by the centring (|beta_pirls(all) - fit| at most 0.028). This substitutes, for T6, the Laplace bootstrap of T5 step 3b, which is still open.

### A-T6-4 The finer-y GLMMs at nAGQ 0
- **Decision:** the finer-y maps and cuts use GLMMs fitted with nAGQ 0 (18-100 s); the nAGQ 1 fits are used if their records exist. **Evidence:** on the step-3 basis nAGQ 0 and nAGQ 1 give maps within 0.997-1.009 (OLD) and 0.997-1.007 (NEW), fixed effects within 0.028, SEs within 0.05% (`nagq0_check_old_vs_new.csv`); the nAGQ 1 fits on the finer basis did not finish in T5's 2 h 26 min.

### A-T6-5 "Without reprints" means without the 89 NEW shoes judged same_shoe or uncertain in T0
- **Decision:** T0's visual verdicts (`docs/qa/T0/compare/overlap_verdicts_t0_old_vs_new.csv`; 67 same_shoe, 22 uncertain) define the sensitivity "NEW without the reprinted shoes". **Why:** T3's pre-registered overlap screen and the Part 2 shoe set do not exist yet; if they come, the norep fits should be rerun with T3's list (`bash tools/run_compare_fits.sh --force norep_glmm norep_cml offset_norep boot_norep profile_norep profile_off_norep`).

### A-T6-6 Background fits run from a private copy of the script
- **Decision:** every long R job runs from its own copy of `tools/fit_compare_models.R` (`tools/run_compare_fits.sh`; the script's header warns against in-place edits). **Evidence:** section 2: an in-place edit crashed five fits after up to 107 minutes (Rscript reads its `--file` while running).

### A-T6-7 Naomi's areas on the prototype are applied to (-new_x, y); the meeting's numbers are corrected
- **Decision:** the 2022 rules are applied to the mirrored x (the step-1 frame mirrors x, plan F7). The meeting's 1.75x / 2.4x / 5.5x came from the unmirrored x; they are reproduced exactly (1.753, 2.408, 5.515) and corrected: OLD between 1.79 [1.67, 1.98], within p90/p10 up to 2.63, max/min up to 6.32; NEW 1.58 [1.51, 1.72], 2.64, 5.30. **For Naomi and Shlomo:** the R&R answer to R1 point 1 should quote the corrected numbers; the conclusion is unchanged.

### A-T6-8 sigma^2 intervals by an approximate profile likelihood
- **Decision:** theta is profiled with the intercept re-optimized and the spatial coefficients held at their estimates (Laplace deviance); z of the OLD-NEW difference on the log scale with SEs from the interval widths. **Why:** lme4's full profile on 25 fixed effects and 50,000-80,000 rows costs hours per fit; the spatial coefficients hardly move with sigma (an offset changes sigma^2 by 0.02-0.11 and the spatial coefficients by at most 0.018-0.085, F35, F82).

### A-T6-9 The NEW full-tensor GLMM: bobyqa, converged by a gradient check
- **Decision:** `full_new_glmm` uses bobyqa; its record keeps code 1 (bobyqa's evaluation limit), and convergence rests on the agreement of two optimizers and a flat gradient, which `tests/r/test_compare_old_new.R` recomputes. **Evidence:** section 3.2 (log-likelihoods within 2e-5, fixed effects within 0.003 SE, max |g| x SE 0.0135).

### A-T6-10 The exact CMLs on the finer y basis are optional
- **Decision:** the Rmd includes them when their records exist and lists them as missing otherwise (the GLMM finer-y variants are required); the CML sensitivity figure says so in its empty panel. **Evidence:** section 3.3 (3.5 GB each; five out-of-memory kills while T7's knits ran). To complete: `bash tools/run_compare_fits.sh --jobs 1 fineY_old_cml fineY_new_cml fineYold_new_cml` on an idle machine, then knit the Rmd again.

### A-T6-11 An empirical density map beside every model ratio
- **Decision (an addition to the plan):** the figures `empirical_density*` and the last panel of the sensitivity figures show the model-free NEW / OLD ratio (RAC pixels over the contact pixels the controls stand for, 21 x 21-pixel box). **Why:** the step-3 surfaces are restricted (K8, 5 y knots); the raw ratio shows which model differences are in the data (forefoot, heel bottom) and which features the step-3 basis cannot follow (the midfoot-top and heel-front bands).

## 10. LOG entry (merged into `docs/progress/LOG.md` by the review fixes, with its results sentence restated as the review corrected it)

```markdown
## 2026-11-07 07:10-10:45, T6-compare (implementer; resumed after an interruption), done except the optional exact finer-y CMLs

**What.** Resumed the interrupted T6 session (its code untracked, its fits running in `<scratch>/t6/fits_repo`). Found that an in-place edit of `tools/fit_compare_models.R` at 06:53 had doomed every fit started before it (Rscript reads its `--file` while running): five crashed after their fits, before saving. Killing the earlier session's processes was refused by the harness, so they ran on; the missing fits were relaunched from frozen script copies (A-T6-6). Completed the Rmd (bootstrap tests and bands, profile intervals of sigma^2, empirical density maps, readable figures), the helpers (bootstrap helpers; the prototype grid made bit-identical to step 4's), the test (sections 8-10), `tools/run_compare_fits.sh`, the results `docs/results/old-vs-new.md` and `docs/tests/T6-results.md`. No commit (T7 in parallel).

**Results** (details in `docs/results/old-vs-new.md`): the surfaces differ beyond chance but modestly: equality of the 24 spatial coefficients, GLMM, shoe bootstrap W = 51.9, F(24, 976) p = 0.0014 (model-based 129.5; without reprints 46.8, p = 0.0056); NEW / OLD calibrated-map ratio median 1.11, central 90% 0.84-1.44 on the common basis; robust differences: NEW lower in the forefoot centre, higher at the heel bottom and the forefoot edges; in the raw data also a NEW midfoot-top high and heel-front low that only the finer y basis follows. sigma^2 with the offset OLD 0.979 [0.839, 1.149], NEW 0.641 [0.565, 0.730]. Naomi's areas: between OLD 1.79, NEW 1.58; within p90/p10 up to 2.63 and 2.64 (the meeting's 1.75/2.4/5.5 used unmirrored areas; corrected, A-T6-7). The RAC type coding differs between the collections (same soles: type-1 share 0.47 NEW vs 0.24 OLD, 58 of 67 pairs). Random vs CML within 2% on both datasets.

**Tests and gates.** `tests/r/test_compare_old_new.R` ALL PASS (90 s). `tests/regress_old.sh --steps 1-6` ALL PASS (OLD identical: Tier A CSVs, models identical() to Tier B, PDFs, W 427.7804472165). `bash tests/run_all.sh` (10:20-10:31): every test PASS; only "work tree unchanged" FAIL, from T7's files changing during the run (no T6 file changed). The inherited offset refits are reproduced by the final code in every field; an independent knit reproduces all 24 CSVs and 18 PNGs byte for byte and the 18 PDFs without their dates.

**Not done.** The exact CMLs on the finer y basis (3.5 GB each; five attempts killed, exit 137, out of memory while T7's knits held about 10 GB): `bash tools/run_compare_fits.sh --jobs 1 fineY_old_cml fineY_new_cml fineYold_new_cml` on an idle machine, then knit again. The nAGQ 1 GLMMs on the finer basis (optional).

**Open for people.** Naomi/Shlomo: the corrected within/between numbers for the R&R (A-T6-7). Shlomo/Naomi/Yoram: is there a codebook of the RAC `type` column, and were the two collections coded by the same protocol? Micha: the datasets' sigma^2 differ (NEW's shoes vary less in RAC density).

**For the closing agent.** Commit the files of `docs/tests/T6-results.md` section 11; merge the decisions A-T6-1 to A-T6-11 (renumbered) and this entry; the plan's T6 steps can be ticked (step 1 tests, step 2 run and looked at, step 3 gate, step 4 docs; the commit is yours).
```

## 11. Files of this task (committed by the review fixes, section 12.12)

| Kind | Files |
|---|---|
| code | `statistical_model/compare_old_new_7.Rmd`, `statistical_model/R/compare_old_new.R`, `tools/fit_compare_models.R`, `tools/run_compare_fits.sh` |
| test | `tests/r/test_compare_old_new.R` (in the fast suite: every `tests/r/test_*.R` runs) |
| baseline list | `tests/baseline/old_added_t6.sha256` (A-T6-1) |
| fits | `saved_models/NEW_X_NS_XY_offset.rds` (26 MB), `saved_models/new/NEW_X_NS_XY_offset_new.rds` (41 MB), `saved_models/t6/*.rds` (7), `saved_models/new/t6/*_new.rds` (16) |
| outputs | `processed_data/compare/*_old_vs_new.csv` (24), `model_images/compare/*_old_vs_new.pdf` (18), `docs/qa/T6/*_old_vs_new.png` (18) |
| docs | `docs/results/old-vs-new.md`, `docs/tests/T6-results.md` |
| not to commit | `logs/knit/compare/` (ignored), everything under `<scratch>` (fit logs, frozen copies, probes, the dev copy) |

Probes of this task (not in the repository; in `<scratch>/t6r/probes/`): `boot_probe.R`, `offset_repro.R`, `cml_mem.R`, `full_new_gradcheck.R`, `digest.R` (prints the CSV tables used to write the results).

## 12. Review fixes (2026-11-07, 11:00-12:30)

The statistics review of 11:00 (`docs/progress/LOG.md`, commit `a4edb42`) asked for two major and four minor fixes. Each was first reproduced with the reviewer's own probes (`<scratch>/t6review/*.R`), then fixed in the code, knitted, tested and documented. Decisions A-133 to A-138; the first run's decisions merged as A-122 to A-132 (section 9). The machine was shared with the T7 review-fix session (its knits and slow tests ran at the same time; load average 6 to 120), so timings are loaded timings.

### 12.1 The review's probes reproduced (read-only; run from the repository root)

```
$ for p in level region edge edge_share shape area sigma type wald; do Rscript <scratch>/t6review/${p}_probe.R > <scratch>/t6fix/probe_out/$p.log; done
== level
glmm_old: B 1000; SD of the level part (resampled N* minus fixed N) 0.0566; median SD log density fixed-N 0.0690, resampled 0.0895 (ratio median 1.31); 39 s
glmm_new_ob: B 1000; SD of the level part (resampled N* minus fixed N) 0.0362; median SD log density fixed-N 0.0496, resampled 0.0616 (ratio median 1.24); 58 s
glmm_new_ob vs OLD: median ratio 1.110; share |z|>1.96 NEW higher: fixed N 0.277, resampled N 0.215; NEW lower: fixed N 0.054, resampled N 0.039
glmm_norep_new vs OLD: median ratio 1.060; share |z|>1.96 NEW higher: fixed N 0.197, resampled N 0.142; NEW lower: fixed N 0.115, resampled N 0.066
row 110 new_x -0.0517 glmm_old: 4.77; band fixed N [4.30, 5.29]; resampled N [4.17, 5.51]
row 110 new_x -0.0517 glmm_new_ob: 3.92; band fixed N [3.60, 4.26]; resampled N [3.55, 4.29]
row 110 glmm_new_ob: disjoint bands NEW above/below: fixed N 0.10 / 0.10; resampled N 0.06 / 0.00
== shape
glmm_new_ob shape-only (each map / its observed density; level ratio 1.0621): NEW higher 0.204, lower 0.123; away from the pinned edges (0.03): higher 0.149, lower 0.132; median shape ratio 1.045
== edge_share
within 0.03 of the pinned edges (6.8% of the prototype): NEW-higher pixels (fixed N) in it 24.4% of all NEW-higher; share NEW higher away from the edges: fixed N 0.224, resampled N 0.160; NEW lower: 0.058, 0.042
== region (B = 2000, seed 2)
  overall density ratio 1.062 [0.930, 1.210]
  forefoot_centre      cases OLD  804 NEW 1001; ratio 0.875 [0.729, 1.037]; shape-only ratio 0.824 [0.721, 0.939]
  heel_bottom_all      cases OLD 1481 NEW 2828; ratio 1.225 [1.049, 1.451]; shape-only ratio 1.154 [1.050, 1.273]
  midfoot_top_band     cases OLD 1023 NEW 1711; ratio 1.323 [1.105, 1.587]; shape-only ratio 1.245 [1.106, 1.409]
  heel_front_band      cases OLD  308 NEW  271; ratio 0.630 [0.455, 0.889]; shape-only ratio 0.593 [0.444, 0.813]
== edge (seed 3)
  ff_rim_right_15pct   cases OLD  166 NEW  294; ratio 1.119 [0.851, 1.509]; shape-only 1.053 [0.817, 1.376]
  toe_right_y_gt_0.38  cases OLD  443 NEW  649; ratio 1.013 [0.798, 1.297]; shape-only 0.953 [0.785, 1.140]
  midfoot_right_edge   cases OLD  518 NEW  898; ratio 1.191 [0.981, 1.460]; shape-only 1.121 [0.973, 1.310]
== sigma (B = 4000, seed 1)
offset FALSE: new/OLD ratio 0.832, bootstrap z -1.83, percentile 95% of the ratio [0.687, 1.017]
offset TRUE: new/OLD ratio 0.713, bootstrap z -3.27, percentile 95% of the ratio [0.583, 0.880]
== type
pairs with >= 5 RACs on both prints: 67; matched RACs 1436 of 2905 OLD and 3158 NEW (median share of OLD matched 0.53)
matched RACs with the same type: 0.653; type-1 share among matched: OLD 0.271, NEW 0.425
== wald
bootstrap paired W 51.878, F p 0.001431; separate covariances W 51.512 (chi2 p 0.0009056)
norep: model W 118.10; bootstrap paired W 46.746, F p 0.005617
== area
full_old between 1.96 (areas 13/1); within p90/p10 max 2.90 (areas 6,1,10)
fineY_old between 1.90 (areas 14/1); within p90/p10 max 4.48 (areas 6,5,1)
```

(Trimmed to the lines the docs cite; the full logs are in `<scratch>/t6fix/probe_out/`.) Every number the review quoted reproduces.

### 12.2 New fits: the shoe bootstraps of the full tensors (Naomi's areas without K8, A-135)

Two new jobs in `tools/fit_compare_models.R` (`boot_full_old`, `boot_full_new`: the PIRLS shoe bootstrap of the full-tensor GLMM records, seeds `T6_SEEDS$boot_full_old` and `$boot_full_new`), stage 2 of `tools/run_compare_fits.sh`:

```
$ bash tools/run_compare_fits.sh --jobs 2 boot_full_old boot_full_new
== logs/compare_fits/progress.txt
START boot_full_old 11:05:58
START boot_full_new 11:05:58
END boot_full_old exit=0 800s 11:19:18
END boot_full_new exit=0 1077s 11:23:55
== logs/compare_fits/boot_full_old.log
bootstrap boot_full_old: old data, 386 shoes, B = 1000, 4 workers, theta 0.980363, seed 20261111
done boot_full_old: 1000 draws (0 failed), 795 s; |beta_pirls(all) - fit| max 0.0355; bootstrap / model SE (spatial): median 1.089, min 0.974, max 1.168
== logs/compare_fits/boot_full_new.log
bootstrap boot_full_new: new data, 631 shoes, B = 1000, 4 workers, theta 0.870116, seed 20261112
done boot_full_new: 1000 draws (0 failed), 1071 s; |beta_pirls(all) - fit| max 0.0261; bootstrap / model SE (spatial): median 1.034, min 0.962, max 1.129
```

Outputs: `saved_models/t6/NEW_X_NS_XY_full_bootpirls.rds` and `saved_models/new/t6/NEW_X_NS_XY_full_bootpirls_new.rds`.

### 12.3 Code changes

- `statistical_model/R/compare_old_new.R`: `t6_cal_rows()` also returns the rows' shoes and per shoe its cases and contact pixels; new `t6_boot_ids()`, `t6_boot_counts()`, `t6_logdens_boot()` (kinds `fixed`, `resampled`, `shape`; `t6_logdens_sd()` is now its `fixed` case, unchanged in output), `t6_pinned_band()`, `t6_per_shoe()`, `t6_sigma2_moment()`, `t6_shoe_regions()`, `t6_region_density()`, `t6_match_racs()`; `T6_SEEDS` gains `boot_full_old`, `boot_full_new`, `regions`, `sigma_moment` (the four old seeds unchanged); the comment of `t6_boot_pair()` no longer calls the datasets independent (A-138).
- `statistical_model/compare_old_new_7.Rmd`: the RAC-level type matching (chunk `t6_data`), the moment-estimator bootstrap of sigma^2 (`t6_sigma2`), the `samples` and `primary` columns of the equality tests (`t6_wald`), the level and shape bootstrap of the maps with the shares table and the shape figure (`t6_maps_boot`), the model-free regional table and figure (new chunk `t6_regions`), the level and shape bands at the cuts with the shape figure (`t6_cuts`), the area ratios on every basis with bootstrap intervals and the full-tensor area figure (`t6_areas`, `t6_area_figure`), the labels of the model-based |z| contours of the main maps.
- `tools/fit_compare_models.R`, `tools/run_compare_fits.sh`: the two bootstrap jobs (12.2).
- `tests/r/test_compare_old_new.R`: section 11 (header of the file), and the runner check of section 10 knows the new jobs.

### 12.4 Development check of the new helper (`<scratch>/t6fix/dev_helpers.R`)

```
$ Rscript <scratch>/t6fix/dev_helpers.R
helper = explicit per-draw computation for fixed, resampled and shape: OK
glmm_old: median SD fixed 0.0690, resampled 0.0895 (x 1.31), shape 0.0690 (x 1.000 of fixed), proto-mean shape 0.0693 (x 0.997); 34 s
glmm_new_ob: median SD fixed 0.0496, resampled 0.0616 (x 1.24), shape 0.0496 (x 1.000 of fixed), proto-mean shape 0.0499 (x 1.001); 39 s
glmm_norep_new: median SD fixed 0.0550, resampled 0.0682 (x 1.25), shape 0.0550 (x 1.000 of fixed), proto-mean shape 0.0552 (x 1.001); 32 s
pinned band (0.03) covers 6.8% of the prototype
glmm_new_ob vs OLD (higher / lower): absolute fixed N 0.277 / 0.054; absolute resampled 0.215 / 0.039 (away from band 0.160 / 0.042); shape fixed rows 0.204 / 0.123 (away 0.149 / 0.132); shape resampled 0.204 / 0.123 (away 0.149 / 0.132); shape proto-mean 0.171 / 0.154 (away 0.115 / 0.165)
glmm_norep_new vs OLD (higher / lower): absolute fixed N 0.197 / 0.115; absolute resampled 0.142 / 0.066 (away from band 0.087 / 0.071); shape fixed rows 0.192 / 0.121 (away 0.135 / 0.130); shape resampled 0.192 / 0.121 (away 0.135 / 0.130); shape proto-mean 0.156 / 0.159 (away 0.099 / 0.170)
total 130 s
```

So the shape bootstrap with its normalisation resampled has the same SDs as the first run's fixed-total version (the reviewer's recipe "fixed-N SDs for the shape" holds), while absolute densities need the resampled level.

### 12.5 The knit

A development knit ran first in a scratch copy of the repository (`<scratch>/t6fix/dev_repo`: the tree without `.git`, `logs`, `images_new` and T7's 611 MB `processed_data/validation`, with `data/` and `saved_models/` linked read-only; the Rmd writes only CSVs and figures): the first attempt stopped in the new chunk `t6_regions` (`REG_EST[[nw]][, r]: incorrect number of dimensions`, a one-row `vapply` result; `t6_region_density()` now always returns a matrix), the second passed (4:53, 1.70 GB). After two label fixes (12.7) the knit in the repository, with the first run's outputs saved to `<scratch>/t6fix/first_run_outputs/` before:

```
$ cd statistical_model && /usr/bin/time -v Rscript -e 'rmarkdown::render("compare_old_new_7.Rmd", output_dir = "../logs/knit/compare", intermediates_dir = tempdir())'
	Elapsed (wall clock) time (h:mm:ss or m:ss): 6:26.79
	Maximum resident set size (kbytes): 1750276
	Exit status: 0
== printed output (logs/knit/compare/compare_old_new_7.html), the new lines
## bootstrap full_old: 1000 draws (0 failed), seed 20261111, theta 0.980363, 795 s, |beta_pirls(all) - fit| max 0.036
## bootstrap full_new: 1000 draws (0 failed), seed 20261112, theta 0.870116, 1071 s, |beta_pirls(all) - fit| max 0.026
## matched RACs on the 67 same_shoe pairs: 1436 of 2905 OLD and 3158 NEW RACs (median share of an OLD print matched 0.53); mirror +1 in 67 pairs, -1 in 0; median |dx| 0.0033, |dy| 0.0033; 4 s
## matched RACs with the same type on both prints: 0.653; type 2 on OLD -> type 1 on NEW: 258, type 1 on OLD -> type 2 on NEW: 73; type-1 share among the matched RACs: OLD print 0.271, NEW print 0.425; type-1 share of the NEW RACs without an OLD match 0.456
## shoe-bootstrap SD of the log overall RAC density: OLD 0.0558, NEW 0.0372, NEW without reprints 0.0403
## row 110 at OLD's peak, new_x -0.0517, OLD: 4.77 [4.17, 5.51] per 1,000 contact px (fixed N [4.30, 5.29]); relative 1.470 [1.326, 1.631]; vs OLD z 0.00 (absolute), 0.00 (shape)
## row 110 at OLD's peak, new_x -0.0517, NEW (all): 3.92 [3.55, 4.29] per 1,000 contact px (fixed N [3.60, 4.26]); relative 1.137 [1.047, 1.236]; vs OLD z -2.28 (absolute), -3.71 (shape)
## row 110 at OLD's peak, new_x -0.0517, NEW without reprints: 3.70 [3.36, 4.11] per 1,000 contact px (fixed N [3.37, 4.06]); relative 1.135 [1.035, 1.243]; vs OLD z -2.84 (absolute), -3.60 (shape)
## area simulations: 15 fit x method combinations, 186 s
## every required fit present
## not included (the slow exact CMLs on the finer y basis are not fitted yet):
## T6 Rmd: 375 s
```

The tables behind the docs (`<scratch>/t6fix/digest.R`, which prints the CSVs) are pasted into `docs/results/old-vs-new.md` sections 3-7 as they are; the main ones:

```
== equality_wald (the new columns)
 GLMM OLD vs NEW without reprints, OLD basis shoe bootstrap (paired difference draws)  46.746 24 5.6172e-03 F(24, 976) independent (no NEW reprint of an OLD sole)    TRUE
 GLMM            OLD vs NEW (all), OLD basis shoe bootstrap (paired difference draws)  51.878 24 1.4306e-03 F(24, 976)          shared soles ignored: conservative   FALSE
== sigma2_moment_bootstrap
            offset                  new sigma2_old sigma2_new ratio_new_old ratio_lo ratio_hi se_log_old se_log_new  z_log p_two_sided    B
              none            NEW (all)      1.034     0.8607        0.8325   0.6846   1.0172    0.07495    0.06654 -1.829    0.067365 4000
              none NEW without reprints      1.034     0.8821        0.8532   0.7009   1.0407    0.07495    0.06906 -1.558    0.119205 4000
 log((px - n)/100)            NEW (all)      1.039     0.7409        0.7133   0.5818   0.8717    0.07490    0.07131 -3.267    0.001086 4000
 log((px - n)/100) NEW without reprints      1.039     0.7560        0.7278   0.5912   0.8896    0.07490    0.07589 -2.979    0.002887 4000
== bootstrap_map_se (median over the prototype)
            fit sd_log_model sd_log_boot_fixedN sd_log_boot_resampled fixedN/model resampled/model resampled/fixedN shape/fixedN (max |dev|)
       glmm_old       0.0509             0.0690                0.0895         1.33            1.77             1.31          1 (0.00598)
    glmm_new_ob       0.0406             0.0496                0.0616         1.22            1.50             1.24          1 (0.00835)
 glmm_norep_new       0.0449             0.0550                0.0682         1.21            1.51             1.25          1 (0.00679)
== map_shares (share of the prototype with |z| > 1.96: higher, lower; away from the 0.03 band)
NEW (all)   absolute, resampled level  0.215 0.0389 | 0.1604 0.0417 (higher in band 0.305)
NEW (all)   absolute, RAC total fixed  0.277 0.0536 | 0.2241 0.0575
NEW (all)   absolute, model-based      0.362 0.0802 | 0.3162 0.0860
NEW (all)   shape / observed density   0.204 0.1232 | 0.1490 0.1321
NEW (all)   shape / prototype mean     0.171 0.1539 | 0.1151 0.1651
no reprints absolute, resampled level  0.142 0.0662 | 0.0869 0.0710
no reprints shape / observed density   0.192 0.1212 | 0.1347 0.1299
```

(The `bootstrap_map_se` and `map_shares` blocks are reformatted from the digest's wide print; the values are the printed ones.)

### 12.6 Determinism and what changed

```
== the repository's CSVs against the development knit's: 29 compared, 0 differ
== against the first run (saved before the knit)
changed: areas14, areas14_summary, bootstrap_map_se, ci_cuts_bootstrap, ci_cuts_bootstrap_summary, equality_wald, map_ratio_main
new:     empirical_regions, map_shares, rac_types_matched, rac_types_matched_pairs, sigma2_moment_bootstrap
same:    the other 17 CSVs, byte for byte
PNGs changed: areas14, ci_cuts_commonbasis_boot, intensity_maps_cml, intensity_maps_glmm, intensity_maps_glmm_commonbasis_boot, intensity_maps_glmm_commonbasis_norep_boot
PNGs new:     ci_cuts_commonbasis_shape_boot, empirical_regions, ratio_maps_commonbasis_shape_boot
PNGs same:    the other 12, byte for byte
```

Every change is one the fixes intended. The refactored area simulation reproduces the first run's model-based area table exactly:

```
$ Rscript -e '<first-run areas14 CSV against the new one, per fit, all.equal(tolerance = 0) on 18 columns>'
glmm_old 14 14 all identical: TRUE
glmm_new 14 14 all identical: TRUE
cml_old 14 14 all identical: TRUE
cml_new 14 14 all identical: TRUE
glmm_old_meeting 14 14 all identical: TRUE
```

### 12.7 Figures looked at (with the Read tool, after the knit)

All new and changed figures were opened (the observations are in `docs/results/old-vs-new.md` section 10). Two defects were found and fixed before the repository knit: the ratio-panel label of the main maps ("ratio; black line: |z| = 1.96, model-based (too narrow: K9, level fixed)") ran past the right edge of the figure (shortened to "model-based |z| = 1.96 (too narrow)", the explanation moved into the note), and the shape-cut caption had a space before its period ("3.261 ."). One reading was corrected after a check: the 6% of row-110 columns where NEW's absolute band lies above OLD's are at the K8-pinned left edge (new_x -0.188 to -0.168), not at the right edge, as a first draft of the results said.

### 12.8 Tests

```
$ /usr/bin/time Rscript tests/r/test_compare_old_new.R    (on the repository outputs, while the OLD gate of 12.10 ran)
[sections 1-9 and 10 as in section 6, plus the two new bootstrap records:]
PASS bootstrap record NEW_X_NS_XY_full_bootpirls.rds: 1000 draws (0 failed), seed 20261111, centred on NEW_X_NS_XY_full, ids of its 386 shoes
PASS bootstrap record NEW_X_NS_XY_full_bootpirls_new.rds: 1000 draws (0 failed), seed 20261112, centred on NEW_X_NS_XY_full, ids of its 631 shoes
PASS level and shape: t6_logdens_boot = the explicit per-draw calibration (fixed, resampled, shape); all shoes once = fixed
PASS bootstrap cut table: OLD row 110 bands recomputed from the record (122 columns); the level adds a factor 1.33 to the SD at the median column
PASS pinned band: 6.8% of the prototype within 0.03 units of OLD's K8 edges, as in the shares table
PASS model-free regions: heel bottom and forefoot centre ratios and their 2000-draw shoe-bootstrap intervals recomputed
PASS sigma^2 moment estimator: = plan F82 (1.034 OLD, 0.861 NEW without offset); the bootstrap table's estimates recomputed
PASS RAC matching: a synthetic shift and mirror recovered; 3 of the 67 same_shoe pairs recomputed; 1436 matched RACs
PASS primary equality test: GLMM without reprints, shoe bootstrap W 46.746 (F(24, 976), p 0.00562) recomputed
PASS areas: full-tensor between-area ratios recomputed from the records; bootstrap intervals for 5 fits (33 s for section 11)
PASS fit runner: tools/run_compare_fits.sh runs each of the 33 jobs of fit_compare_models.R --list once, in dependency order
ALL PASS test_compare_old_new (166 s)
elapsed 171.01 s, max RSS 1180884 kB, exit 0
$ Rscript tests/r/test_new_outputs.R
PASS no collision: 92 files in the NEW folders, every stem ends in _new; the OLD output folders hold only Tier A, the old_added lists and README files
ALL PASS test_new_outputs
$ python3 -m unittest tests.python.test_no_hardcoding
Ran 3 tests in 1.240s
OK
$ Rscript tests/r/test_no_hardcoding.R
tests/r/test_validation_stats.R:332: dataset number: Lc <- ifelse(Sc > 0, log(EMc / pmax(EUc, 1e-300)), 0)
Error: 1 dataset literal(s) in R code
```

The one hard-coding finding is in T7's `tests/r/test_validation_stats.R`, which the parallel T7 review-fix session modified at 11:33 (the token `300` inside `1e-300`); no T6 file has a finding. It is T7's to fix (an `rac: literal-ok` comment or `.Machine$double.xmin`); T6 does not edit T7's files.

`tests/baseline/old_added_t6.sha256` was rewritten for the new OLD-side files (59 entries: 29 CSVs, 21 PDFs, the OLD offset refit and 8 OLD records; `sha256sum -c` 59 OK); the test of the collision check above reads it.

### 12.9 The fast suite

```
$ time bash tests/run_all.sh          (12:04-12:16, while the OLD gate of 12.10 and T7's knits ran)
== summary
PASS         1s  sha256 committed_79247d8 (Tier A, 24 files)
PASS         0s  sha256 old_baseline (11 OLD artifacts)
PASS         0s  sha256 old_added_t2 (the 2 OLD files T2 added)
PASS       176s  python unittest discover tests/python
PASS         6s  Rscript tests/r/test_baseline_committed.R
PASS        43s  Rscript tests/r/test_compare.R
PASS        25s  Rscript tests/r/test_compare_glmm_fits.R
PASS         5s  Rscript tests/r/test_compare_models.R
PASS       113s  Rscript tests/r/test_compare_old_new.R
PASS        54s  Rscript tests/r/test_distances_vectorized.R
PASS        21s  Rscript tests/r/test_figures_png.R
PASS        34s  Rscript tests/r/test_new_outputs.R
FAIL(1)      7s  Rscript tests/r/test_no_hardcoding.R
PASS         4s  Rscript tests/r/test_old_regression.R
PASS        40s  Rscript tests/r/test_output_guards.R
PASS         1s  Rscript tests/r/test_pixel_mapping.R
PASS         2s  Rscript tests/r/test_profile.R
PASS        62s  Rscript tests/r/test_profile_sentinels.R
PASS         9s  Rscript tests/r/test_run_manifest.R
PASS         2s  Rscript tests/r/test_step5_variant.R
PASS        10s  Rscript tests/r/test_sticker_masks.R
PASS         4s  Rscript tests/r/test_validation_areas.R
PASS         1s  Rscript tests/r/test_validation_pairs.R
PASS        43s  Rscript tests/r/test_validation_pixels.R
PASS        35s  Rscript tests/r/test_validation_stats.R
PASS         5s  Rscript tests/r/test_wald.R
PASS         1s  flake8 (all Python files)
PASS         6s  shellcheck (all shell scripts)
FAIL(1)      0s  work tree unchanged by the tests (no file created or modified)
SOME CHECKS FAILED

real	11m49.873s
== Rscript tests/r/test_no_hardcoding.R
tests/r/test_validation_stats.R:332: dataset number: Lc <- ifelse(Sc > 0, log(EMc / pmax(EUc, 1e-300)), 0)
Error: 1 dataset literal(s) in R code
== work tree unchanged by the tests (no file created or modified)
432,433c432,433
< ./docs/results/validation.md 54536 1794045654.3059547940
< ./docs/tests/README.md 11338 1794014429.1268910750
---
> ./docs/results/validation.md 59986 1794046210.1670387690
> ./docs/tests/README.md 11888 1794046104.6140963920
3932c3932
< ./tests/r/slow/test_validation_real_calibration.R 15011 1794043895.7124980040
---
> ./tests/r/slow/test_validation_real_calibration.R 15089 1794046075.6737981970
$ find <every T6 file and folder> -newermt "2026-11-07 12:04:01" | wc -l
0
$ sha256sum -c tests/baseline/old_added_t6.sha256 | grep -vc ': OK$'
0
```

Every test passes except two checks, and neither comes from T6. The hard-coding scan fails on T7's `tests/r/test_validation_stats.R` (12.8). The work-tree check saw the parallel T7 review-fix session edit `docs/results/validation.md`, `docs/tests/README.md` and a slow T7 test during the run. No T6 file changed during the run (the `find` above), and the T6 list of OLD-side files checks OK.

### 12.10 OLD regression

```
$ RAC_SCRATCH=<scratch>/t6fix/regress /usr/bin/time -v bash tests/regress_old.sh --steps 1-6     (11:42-12:07)
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
step1       177.393473066  0
step2       37.124233908   0
step3_glmm  908.165402163  0
step3_cml   244.906498565  0
step4_glmm  18.271417730   0
step4_cml   16.699111141   0
step5       33.189776206   0
step6       26.810825536   0
ALL PASS
	Elapsed (wall clock) time (h:mm:ss or m:ss): 24:48.70
	Maximum resident set size (kbytes): 3383100
	Exit status: 0
```

OLD is identical: the five step-1/2 CSVs = Tier A byte for byte, `shoe_codes.csv` = `old_added_t2`, both models `identical()` to Tier B in every field, the 8 date-free PDFs = Tier B, W = Tier B's 427.7804472165. The review fixes changed no OLD pipeline file and no committed output (`git diff --stat` before the commits lists only `docs/decisions.md`, `docs/plans/2026-11-05-new-shoes-pipeline.md`, `docs/progress/LOG.md`, and T7's edit of `docs/tests/README.md`). Step 0 was not rerun: T6 does not touch the contour code.

### 12.11 Still open

- The exact CMLs on the finer y basis (A-131) and the nAGQ 1 finer-y GLMMs: optional, unchanged from section 3.3.
- The reprint list from T3's screen (A-126): when it exists, rerun the six reprint-dependent fits with `--force` and knit again.
- T7's hard-coding finding (12.8) is T7's to fix; the fast suite cannot be all green until then.
- For people: the corrected area numbers for the R&R (A-135, Naomi and Shlomo); the codebook of the RAC `type` column (A-137, Shlomo, Naomi, Yoram).

### 12.12 Commits

- `8b1d2f2` `feat: old vs new comparison (T6), with the statistics review fixes`: the code (`statistical_model/compare_old_new_7.Rmd`, `statistical_model/R/compare_old_new.R`, `tools/fit_compare_models.R`, `tools/run_compare_fits.sh`), the test `tests/r/test_compare_old_new.R`, `tests/baseline/old_added_t6.sha256`, the fit records (`saved_models/t6/` 8, `saved_models/new/t6/` 17, the plan's two offset refits), the outputs (29 CSVs, 21 PDFs, 21 PNGs); 104 files. Only T6 paths were added and committed: T7's files, which the parallel session is still changing, are not in it.
- the docs commit that follows: `docs/results/old-vs-new.md`, this file, `docs/decisions.md` (A-122 to A-138), `docs/progress/LOG.md` (the first run's entry, merged and corrected, and the review-fix entry), the plan (revision 15, the T6 steps ticked), `docs/README.md` (the results row). Not committed: `logs/` (ignored), everything under `<scratch>`, and T7's edit of `docs/tests/README.md`.
- a third commit corrects the last digit of eight regional numbers in the docs (the whole-shoe interval 1.06 [0.93, 1.22], not 1.21; the forefoot-left, left-rim, right-midfoot-edge, inner and edge heel-bottom rows; the heel bottom without reprints 1.16 as shape): the first draft rounded them from three-digit prints; every quoted number was then checked against the CSVs at full precision. That check also corrected four numbers carried over from the first run: the finer-y common-basis p95 1.91 (not 1.92), the group-B equality p 0.0040 (not 0.0041), the bootstrap all-spatial p "at most 1.7e-34" (not "< 1e-34"; OLD's is 1.73e-34) and the nAGQ 0 map ratio of OLD 0.998-1.009 (not 0.997; in A-125 too). The first run's own record (sections 1-11 above) is left as it was written.
