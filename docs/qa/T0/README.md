# T0 visual evidence and probes

Read-only evidence for the plan (`docs/plans/2026-11-05-new-shoes-pipeline.md`, section 2). Nothing here is part of the pipeline.

## Probes (`probes/`)

| Script | Output | Covers (plan facts) |
|---|---|---|
| `t0_probe.py` | `t0_probe.out` + the four PNGs below | raw formats, RAC counts, contact pixels, pixel calibration grid (section D: exact R division form since the review pass), left/right score, committed contour coverage, prototype files, cleaning masks (F1-F4, F6, F10-F12, F17, F24) |
| `t0_facts.py` | `t0_facts.out` | provenance of the committed contour, mirrored frame, shoe 9, duplicates, 2023 COL/ROW, geometry vs init ellipses, `get_snake_image` orientation (F2, F5, F7-F9, F15, F16) |
| `t0_probe.R` | `t0_probe_R.out` | R environment, committed models, manual Wald, committed CSV consistency, `&&` semantics, float window of step 2 (both directions, real CSV round trip, OLD and NEW lattices since the review pass), legacy stamp sweep on new dimensions (F13, F14, F18, F21, F23) |
| `t0_probe.sh` | `t0_probe_sh.out` | line endings, the March EOL-only regeneration, PDF metadata, thesis code vs HEAD, venv versions, thesis run outputs, tools (F8, F19-F22) |
| `t0_review.py` (review pass) | `t0_review.out`, `compare/overlap_screen_t0_old_vs_new.csv`, the overlap, OLD-OLD and low-contact PNGs below | exact R mapping vs multiply form, calibration criterion vs scale, per-shoe on-contact rates and flip/shift diagnostics, RAC concentration, overlap screen of every NEW shoe against every OLD shoe (rigid and two-half), within-dataset screens (F6, F25-F27, F30) |
| `t0_review_pairs.py` (review pass) | `t0_review_pairs.out`, `compare/overlap_pairs/pair2h_*.png` | the candidates found only by the two-half statistic, drawn with per-half matching (F25) |
| `t0_review.R` (review pass) | `t0_review_R.out` | K8 edge restriction, in-sample regional X^2 identity, phi under independence vs heterogeneity vs clumps, Efron + `cluster(shoe)` CML, offsets, `Sys.getenv` for an empty variable (F28, F29, F31-F33) |
| `t0_review_cml.R` (review pass) | `t0_review_cml.out` | exact CML: refit time and identity with the committed model, no robust variance for the exact method (F29) |

Exact commands and timings: `docs/tests/T0-architecture-results.md` (first T0 run) and `docs/tests/T0-review-fixes-results.md` (review pass, 2026-11-05). First versions of `t0_probe.py`, `t0_probe.R` and `t0_probe.sh` were written by the interrupted first T0 run (18:52-18:54, scratchpad only). This folder holds the lint-clean versions, extended with `t0_facts.py` and new R and shell checks, re-run from 20:17; the regenerated PNGs are byte-identical to the first run's.

## Images (opened and inspected with the Read tool on 2026-11-05)

| File | What it shows | What I saw |
|---|---|---|
| `old_prototypes.png` | Old shoes, four panels: `data/freq_min_18.png`; superposition >= 18 (shoe 9 flipped as in R); `data/contour_prototype.png`; union of all 387 contact surfaces | Panel 1 is a smooth filled sole, toe at the top, narrow arch on the left, heel at the bottom. Panel 2 has the same shape with ragged edges. Panel 3 is the thin outline of panel 1. Panel 4 is a broad rectangle-like region: solid rectangular blocks above and beside the toe, blocks beside the heel and a small text-like mark at the top right. These are the police stamps and stickers outside the sole that the masks remove |
| `old_rmask_stamps.png` | Old masks: white = R mask `data/all_cont.csv`; red = removed by the R stamp sweep; blue = `freq_min_18.png` outside the R mask | White sole; two red blobs either side of the toe (the stamps, 1,110 px); a blue ring all around the sole: the Python prototype region is a few pixels wider than the R mask, and nothing of the R mask lies outside it |
| `new/superposition_new.png` (was `new_superposition.png`; same bytes) | New shoes, four panels: union of all 631; superposition >= 18; >= 29; density | Union: the sole plus noise: horizontal streaks and blocks above the toe, speckles along the left side, a long thin diagonal line along the lower right side, blobs at the bottom left (stickers, labels and scanning debris to check in T3). >= 18 and >= 29: clean single silhouettes of the same orientation as the old prototype (toe up, arch on the left), the >= 29 one slightly smaller. Density: dense toe and forefoot, sparse arch, a ring pattern at the heel shared by many shoes |
| `new/sheet_16_racs_new.png` (was `new_sheet_16_racs.png`; same bytes) | 16 new shoes (top row: the 8 with the fewest contact pixels; bottom row: 8 random) with RACs as red squares (mapping col = floor(126.5 - 300 x/2), row = floor(182.5 - 300 y/2)) | Top row: partial or faint prints (shoe 428 shows little more than the sole's outline; shoe 112 has almost no heel contact but a cluster of RACs there; shoe 8 has 3 RACs). Bottom row: full prints of varied designs. The red squares sit mostly on tread elements, so the mapping is plausible. All right shoes in the same orientation as the old ones; no sticker visible in these 16 |
| thesis `images/active-contour/im_8.png` (not copied) | Old shoe 9, second snake in blue, from the 2025-11-13 run | A left shoe (arch on the right); the blue snake fits tightly around the unflipped print (known issue K1: R flips this shoe's contact) |
| thesis `images/active-contour/im_149.png` (not copied) | Old shoe 150, the second-worst coverage (0.889) | The snake encloses the print except a small piece of tread at the bottom right of the heel, which lies outside the blue line |

## Images added in the review pass (opened and inspected with the Read tool on 2026-11-05)

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
| `pair2h_92_103` | 2 of 5 RACs matched, different-looking print (image rank 226): unlikely, a chance match at the threshold |
| `control_354_219`, `control_57_196` | Controls: same design (r 0.974, 0.954) and visibly unrelated RACs (sym 0.087, 0.058). This is what "same design, different shoe" looks like |
| `old/pair_old_236_277.png`, `old/pair_old_237_278.png` | Two OLD prints of the same chevron boot with U-shaped lugs, same outline, about 24-26 RACs matched over forefoot and heel; the consecutive pair 236/237 maps onto 277/278: very likely one pair of shoes printed twice inside OLD (K10) |
| `new/low_contact_shoes_new.png` | NEW 112: faint forefoot, heel almost unprinted with about 30 RACs on it; 177: faint circles, RACs in the unprinted midfoot; 286: very faint; 420: partial spiral-textured print; 498: faint, a RAC cluster in the arch gap; 599: a different image type (thick rim band, dot texture), RACs a few px off the dots (0.22 on contact, 0.91 after a shift). No sticker on these six |
