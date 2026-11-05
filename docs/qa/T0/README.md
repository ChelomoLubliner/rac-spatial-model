# T0 visual evidence and probes

Read-only evidence for the plan (`docs/plans/2026-11-05-new-shoes-pipeline.md`, section 2). Nothing here is part of the pipeline.

## Probes (`probes/`)

| Script | Output | Covers (plan facts) |
|---|---|---|
| `t0_probe.py` | `t0_probe.out` + the four PNGs below | raw formats, RAC counts, contact pixels, pixel calibration grid, left/right score, committed contour coverage, prototype files, cleaning masks (F1-F4, F6, F10-F12, F17, F24) |
| `t0_facts.py` | `t0_facts.out` | provenance of the committed contour, mirrored frame, shoe 9, duplicates, 2023 COL/ROW, geometry vs init ellipses, `get_snake_image` orientation (F2, F5, F7-F9, F15, F16) |
| `t0_probe.R` | `t0_probe_R.out` | R environment, committed models, manual Wald, committed CSV consistency, `&&` semantics, float window of step 2, legacy stamp sweep on new dimensions (F13, F14, F18, F21, F23) |
| `t0_probe.sh` | `t0_probe_sh.out` | line endings, the March EOL-only regeneration, PDF metadata, thesis code vs HEAD, venv versions, thesis run outputs, tools (F8, F19-F22) |

Exact commands and timings: `docs/tests/T0-architecture-results.md`. First versions of `t0_probe.py`, `t0_probe.R` and `t0_probe.sh` were written by the interrupted first T0 run (18:52-18:54, scratchpad only). This folder holds the lint-clean versions, extended with `t0_facts.py` and new R and shell checks, re-run from 20:17; the regenerated PNGs are byte-identical to the first run's.

## Images (opened and inspected with the Read tool on 2026-11-05)

| File | What it shows | What I saw |
|---|---|---|
| `old_prototypes.png` | Old shoes, four panels: `data/freq_min_18.png`; superposition >= 18 (shoe 9 flipped as in R); `data/contour_prototype.png`; union of all 387 contact surfaces | Panel 1 is a smooth filled sole, toe at the top, narrow arch on the left, heel at the bottom. Panel 2 has the same shape with ragged edges. Panel 3 is the thin outline of panel 1. Panel 4 is a broad rectangle-like region: solid rectangular blocks above and beside the toe, blocks beside the heel and a small text-like mark at the top right. These are the police stamps and stickers outside the sole that the masks remove |
| `old_rmask_stamps.png` | Old masks: white = R mask `data/all_cont.csv`; red = removed by the R stamp sweep; blue = `freq_min_18.png` outside the R mask | White sole; two red blobs either side of the toe (the stamps, 1,110 px); a blue ring all around the sole: the Python prototype region is a few pixels wider than the R mask, and nothing of the R mask lies outside it |
| `new_superposition.png` | New shoes, four panels: union of all 631; superposition >= 18; >= 29; density | Union: the sole plus noise: horizontal streaks and blocks above the toe, speckles along the left side, a long thin diagonal line along the lower right side, blobs at the bottom left (stickers, labels and scanning debris to check in T3). >= 18 and >= 29: clean single silhouettes of the same orientation as the old prototype (toe up, arch on the left), the >= 29 one slightly smaller. Density: dense toe and forefoot, sparse arch, a ring pattern at the heel shared by many shoes |
| `new_sheet_16_racs.png` | 16 new shoes (top row: the 8 with the fewest contact pixels; bottom row: 8 random) with RACs as red squares (mapping col = floor(126.5 - 300 x/2), row = floor(182.5 - 300 y/2)) | Top row: partial or faint prints (shoe 428 shows little more than the sole's outline; shoe 112 has almost no heel contact but a cluster of RACs there; shoe 8 has 3 RACs). Bottom row: full prints of varied designs. The red squares sit mostly on tread elements, so the mapping is plausible. All right shoes in the same orientation as the old ones; no sticker visible in these 16 |
| thesis `images/active-contour/im_8.png` (not copied) | Old shoe 9, second snake in blue, from the 2025-11-13 run | A left shoe (arch on the right); the blue snake fits tightly around the unflipped print (known issue K1: R flips this shoe's contact) |
| thesis `images/active-contour/im_149.png` (not copied) | Old shoe 150, the second-worst coverage (0.889) | The snake encloses the print except a small piece of tread at the bottom right of the heel, which lies outside the blue line |
