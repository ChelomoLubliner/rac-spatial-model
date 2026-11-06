# Snake QA: what a good contour looks like (OLD reference)

**Date:** 2026-11-06. **Task:** T1 (baseline). **Written by:** the T1 implementer, after opening every image named here with the Read tool.

This page is the quality bar for the new shoes (T4): the old shoes were checked one by one by hand when the paper was written, and the same care is expected for the 631 new shoes. It shows how the legacy snake (`contour_algorithm/`, the thesis code at `109f30a`) produced the committed contour `data/contour_Active_Contour.txt`, and what a good result looks like.

## How the gallery was made

```bash
# Windows venv of the thesis repo (venv-wind), through WSL interop; see "Platform" below
cd /mnt/c/Users/mehes && /mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint/venv-wind/Scripts/python.exe -B \
  '\\wsl.localhost\Ubuntu\home\mehes\projects\rac-spatial-model\tests\legacy\old_snake_gallery.py' \
  --out '\\wsl.localhost\Ubuntu\home\mehes\projects\rac-spatial-model\docs\qa\sheets_old' --work <scratch folder>
# metrics of all 386 committed contours (any platform; reads committed files only)
python -B tests/legacy/old_snake_metrics.py
```

`tests/legacy/old_snake_gallery.py` re-runs the legacy snake for 68 OLD shoes in a temporary folder. It captures the legacy figures of `plot_active_contour()` (the legacy code calls `Image.show()`; the script redirects that call to a list) and checks every re-run contour against its committed record: **all 67 records equal the committed ones (0 differing pixels)**, and the re-run prototype equals `data/freq_min_18.png`. Output: `docs/qa/sheets_old/`.

| File | Content |
|---|---|
| `prototype_old.png` | The cleaning prototype: superposition of the 387 raw shoes, the >= 18 region, the two prototype snakes, the filled `freq_min_18.png` with its boundary, and the R stamp mask `data/all_cont.csv` |
| `sheet_old_01.png` ... `sheet_old_09.png` | 8 shoes per sheet, 3 panels per shoe: (1) cleaned shoe + initial ellipse (red dashed) + **first** snake (blue); (2) cleaned shoe + initial ellipse + **second** snake; (3) raw shoe: grey = contact kept by the prototype mask, red = contact **removed** by the mask (stamps, stickers, noise, or real sole outside the mask), green = mask boundary (`data/contour_prototype.png`), blue = final contour (the committed record). Lines in panel 3 are dilated by 1 px for display |
| `gallery_shoes_old.csv` | The 68 shoes, why each was chosen, metrics, and the re-run check (`rerun_diff_px`) |
| `snake_metrics_old.csv` | Metrics of all 386 committed contours (definitions in `tests/legacy/old_snake_metrics.py`) |

**Shoe selection (68):** the known special cases (9: left shoe not flipped, K1; 127: no RACs and no contour record; 35 and 153: lowest RAC on-contact rates; 236/277 and 237/278: printed twice inside OLD, K10; 38: possible duplicate of 299; 194: square sticker below the heel), the 18 shoes with a sticker seen in T0 (7, 12, 24, 29, 55, 56, 66, 94, 110, 113, 116, 121, 160, 239, 264, 267, 299, 371), the 8 lowest snake coverages, the 3 shortest and 3 longest contours, the 3 smallest and 3 largest contact areas, the 4 shoes with the most pixels removed by the mask, and 24 random shoes (seed 20261105).

## The prototype (`prototype_old.png`)
- The superposition of the 387 shoes shows the sole with toe up, the tread visible as high counts in the forefoot and a ring in the heel, and faint shadows of the stamps beside the toe.
- The >= 18 region is a sole silhouette with a jagged right side in the arch.
- The first prototype snake (beta = 10, stiff) starts from the red dashed ellipse (centre row 200, column 155; radii 162 rows, 90 columns; rows 38-362, columns 65-245) and contracts onto the silhouette, smoothing the jagged arch.
- The second snake (beta = 0.1, flexible), run on the combined image, follows the outline closely.
- The filled result is `freq_min_18.png` (32,975 px); `data/contour_prototype.png` is exactly its 4-connected inner boundary (748 px; checked in T1).
- The R stamp mask `all_cont.csv` lies entirely inside `freq_min_18.png`: a thin rim of prototype-only pixels runs all around, and no pixel of the R mask lies outside the prototype (plan F11).

## What I saw, sheet by sheet

| Sheet | Shoes | Observations |
|---|---|---|
| 1 | 3, 7, 9, 11, 12, 21, 23, 24 | The ellipse encloses every print with a margin. The first snake hugs the outer envelope loosely; the second follows the outline, arch included. Stickers beside the toe (3: square top-left; 7: rectangle right; 12: bar right; 24: vertical bar right) are outside the mask and removed (red). **9** (left shoe, not flipped, K1): a strip of real sole along the left edge of the forefoot falls outside the mask and is removed; the contour follows the mask boundary there. **11**: a faint, partial print with a strong diagonal arch line; the contour wraps only the printed part, well inside the mask. 21 (sparse chevron dots, smallest contact area): the contour encloses the dot envelope; one removed speck beside the arch. 23: oblique print, contour fine |
| 2 | 29, 35, 38, 55, 56, 61, 66, 73 | All eight contours follow the outline; no toe or heel cut. Stickers removed: 29 (rectangle right of the toe), 55 (small square right), 56 (rectangle top-left), 66 (vertical bar right); 61 has a tiny removed speck beside the forefoot. 35 (lowest RAC on-contact rate) is a clean, complete print with a good contour: its RAC problem is one of registration, not of the snake |
| 3 | 78, 80, 90, 94, 100, 110, 113, 116 | **80**: the striped forefoot reaches the mask edge, so a few real edge pixels at the top right are removed and the contour follows the mask there. **100** (coverage 0.985): sticker left of the toe removed; the contour notches into the left side of the heel and leaves some heel pixels outside, the clearest under-coverage in the gallery. Stickers removed: 94, 110, 113 (tiny mark), 116 (small piece at the forefoot edge) |
| 4 | 121, 127, 144, 150, 152, 153, 160, 165 | 121, 144, 150, 152, 160, 165 good; stickers removed on 121, 150, 152, 160. 127 has no contour record (no RACs); its re-run snake is shown for completeness, with a sticker left of the toe removed. **153** is the hardest OLD case: a faint, partial print (forefoot blocks, part of the heel); the snakes shrink onto the printed parts and the contour lies well inside the mask (coverage 0.978, the shortest contour, 614 px) |
| 5 | 168, 175, 176, 177, 183, 187, 194, 196 | 168, 176, 177, 194, 196 good. **194**: the square sticker below the heel is outside the mask and removed; 175: sticker left of the toe removed; 176: a few specks to the right removed. **183**: the print has a flat, cut-off top edge (toe not printed); the contour follows the print, not the mask. **187**: partial print (forefoot blocks, faint heel), coverage 0.986 |
| 6 | 201, 209, 221, 229, 236, 237, 239, 241 | 209, 221, 229, 236, 237 good (236 and 237: the chevron boots of the K10 pair); specks and a square below the heel removed on 209 and 221. **201** and **239**: the final contour bulges slightly outside the green mask boundary (heel bottom right; toe top left): the snake polyline is not constrained by the mask, only the image it runs on is. 239: bar right of the toe and a speck below the heel removed. 241: rotated print, sticker removed, coverage 0.986 |
| 7 | 263, 264, 267, 277, 278, 285, 289, 295 | All good. Stickers beside the toe removed on 263 (bar; plus a speck below the heel), 264 (square), 267 (small mark). 277 and 278 (second prints of the K10 pair) look like 236 and 237, with equally good contours |
| 8 | 299, 308, 311, 332, 335, 343, 348, 349 | 299, 308, 311, 332, 335, 343, 348 good; stickers removed on 299 (rectangle top-left), 308 (square top-right), 311 (bar right), 348 (square top-right). **349**: partial print (forefoot lugs and a heel strip), coverage 0.990, contour 615 px, inside the mask |
| 9 | 351, 354, 371, 378 | All good; 371: thin bar left of the toe removed |

## What 'good' looks like (the bar for the new shoes)
1. **Initial ellipse:** encloses the whole print with a margin on every side; no print touches it (OLD: rows 38-362, columns 65-245 for prints in rows 44-347; plan F16).
2. **First snake (beta = 10):** contracts smoothly onto the outer envelope of the print. It may bridge concavities (the arch) and round the toe and heel tips; on a partial print it shrinks onto the printed parts.
3. **Second snake (beta = 0.1, on the combined image):** follows the outline closely, including the arch concavity, without loops or self-intersections, within about 1-3 px of the outermost contact pixels.
4. **Final contour:** one closed outline of 614-742 px (OLD range; median 700; plan T4 flags outside [553, 816]); it never touches the image border (0 of 386).
5. **Coverage:** the row-span fill of the contour contains at least 97.75% of the cleaned contact pixels in every OLD shoe (p1 0.9886, p5 0.9968, median 1), and at least 96.95% of the RAC pixels except shoe 9 (p1 0.9695; shoe 9: 1 of 2, 0.5, because of K1).
6. **Stickers and stamps:** every sticker or label seen on the OLD prints (31 of the 68 gallery shoes) lies **outside** the prototype mask: beside the toe or forefoot, left or right, within the top 60 rows, on 29 shoes (3, 7, 12, 24, 29, 55, 56, 66, 94, 100, 110, 113, 116, 121, 127, 150, 152, 160, 175, 239, 241, 263, 264, 267, 299, 308, 311, 348, 371), and as a square below the heel on 2 (194, 221). Small specks outside the sole (beside the arch of 21 and the forefoot of 61, below the heel of 209, 239 and 263) behave the same way. The AND-cleaning removes all of them (red in panel 3), so none enters a cleaned shoe, a snake image or a contour. **No sticker inside the mask was seen on any of the 68 OLD shoes.** For the new shoes the mask is rebuilt from the new prints (A-002), so each new shoe must be checked: a sticker inside the new mask would survive the cleaning and pull the snake (plan T3/T4, sticker census).
7. **Mask vs sole:** the mask must contain the whole sole. Where the sole extends beyond it (left shoe 9, the wide forefoot of 80), real sole pixels are removed and the contour follows the mask edge. The plan's T4 rule (the new mask must contain >= 99.5% of the RAC pixels and >= 99% of the contact pixels of the median shoe) guards against this.
8. **Contour vs mask:** the contour may lie a little outside the mask boundary (median 5.7% of the contour pixels, p95 23.7%, max 40.9%), because the second snake smooths along the cleaned print's edge. That is expected, not a defect.

## Defects present in the committed OLD contours (kept: the OLD analysis is not changed)
- Shoe 9: left shoe not flipped (K1): sole strip cut by the mask, RAC coverage 0.5.
- Partial or faint prints (11, 153, 183, 187, 349): the contour is the envelope of what was printed, not of the whole sole. Contours of partial new prints will behave the same; T3's quality rule handles prints with RACs on unprinted parts.
- Shoe 100: a notch into the heel (coverage 0.985).

## Platform: the committed contour is a Windows result
The verbatim legacy code under the thesis **Windows** venv (venv-wind: Python 3.13.14, numpy 2.2.6, scipy 1.16.3, scikit-image 0.25.2; its base is the self-updating Microsoft Store Python, 3.13.9 when the venv was created, so every venv-wind check logs its interpreter, A-071) reproduces **all 386** committed records. Under the WSL venv (Python 3.12.3, the same package versions), 356 records are identical and **30 differ**, by a mean distance of up to 1.50 px and a maximum of 8.94 px (`tests/baseline/local/contour_linux_diff.csv`). The cause is floating-point differences of about 1e-8 px between the two numeric builds: `np.int32` truncation in `cv2.polylines` and the 2,500-iteration snake amplify them for some shoes (shoe 176: first snakes 3e-9 px apart, second snakes 5 px apart). Each platform is deterministic, on this evidence (A-066). On WSL, three full runs that do not depend on each other wrote the same contour file (sha256 `d43fda7e...`) and the same 1,556 intermediate images and arrays: the T1 Tier B run, the reproducibility reviewer's run, and the run of the T1 review fixes. On Windows, the 386-shoe snake run and the gallery reproduce the committed records. Where the platforms differ is shown in `docs/qa/T1/old/contour_platform_diff_old.png` (white = both, green = Windows/committed only, magenta = WSL only). Shoe 176 is a parallel one-pixel offset almost all the way round, with a small bump at the top right of the toe. Shoes 21 and 11 differ by one pixel on most of the outline, but at the left arch the Windows contour bows several pixels further into the concavity than the WSL contour, and for shoe 11 the toe's top left differs too (up to 8-9 px). Shoe 354 differs in 18 single pixels. That is why the gallery was built with venv-wind: its snake panels are exactly the snakes that produced the committed contour. A first build on WSL (kept in the T1 scratch folder) differed in 8 of the 67 gallery shoes (11, 21, 80, 152, 176, 221, 349, 354). Decision A-060 records what this means for T2 and T4.

---

# NEW shoes (T4, 2026-11-06; revised in the T4 review fixes): what the snake does on the 631 new shoes

**Written by:** the T4 implementer, revised by the implementer of the T4 review fixes, after opening every image named here with the Read tool (user rule 10). Decisions A-091 to A-106; numbers and commands in `docs/tests/T4-snake-results.md` (T4) and `docs/tests/T4-review-fixes-results.md` (review fixes). The viewer drops images after a request limit; every image this page describes was reopened until it displayed, and the notes were written right after each view (`<scratch>/t4fix/visual_notes.md`).

**What the T4 review changed (and what the first version of this page got wrong).** The first version called every sheet "fine" and said that "every ellipse encloses its print with a margin" and that no artefact "survives in a cleaned shoe or a contour". Three reviews showed otherwise: contours of shoes that no band flagged cut unprinted heel corners or toes and left a RAC far outside (120, 18, 222, 286, 12, 267, 328), frame artefacts survived in cleaned shoes (584's line, 586's band block, 580's bar, line ends on 148 and 186, 105's debris blob, 481's dash), and the toe tip crosses the ellipse on 43 shoes. The fixes: absolute QA triggers (A-099), a longer erase list and the mask rebuilt from it (A-100), the fallback on every newly flagged shoe (A-102), review classes (A-101). The text below describes the corrected run (contour sha256 `0af52b05...`).

## How the images were made

```bash
RAC_DATASET=new python -m contour_algorithm.main --qa --jobs 14          # step 0, saves the ellipses and snakes
RAC_DATASET=new python -m contour_algorithm.qa_snake --metrics --sheets --figures --flagged --crosscheck --jobs 14
RAC_DATASET=new OPENBLAS_NUM_THREADS=1 python -m contour_algorithm.qa_snake --thresholds 13,18,24,29,36 --compare 18,29
OPENBLAS_NUM_THREADS=1 RAC_DATASET=new python -B docs/qa/T4/probes/t4_overrides_figure.py
```

| File | Content |
|---|---|
| `docs/qa/sheets_new/prototype/prototype_mask_new.png` | The cleaning mask for thresholds 18 (chosen) and 29: superposition count, mask boundary (green), initial ellipse (red dashed), prototype snakes 1 (light blue) and 2 (blue); the filled masks; their difference over the union of all prints |
| `docs/qa/sheets_new/prototype/prototype_sheet_<kk>_new.png` (13) | 49 shoes per sheet (7 x 7): raw contact kept by the mask (white), removed by the mask (red), erased by the erase list (magenta), mask boundary (green); label: shoe, pixels removed by the mask |
| `docs/qa/sheets_new/ellipse_first_snake/..._sheet_<kk>_new.png` (13) | Cleaned shoe (grey), initial ellipse (red dashed), **first** snake (blue); label: coverage, tightness, `!` and yellow when the shoe is flagged |
| `docs/qa/sheets_new/final_snake/..._sheet_<kk>_new.png` (13) | Raw shoe (white kept, red removed by the mask, magenta erased) and the **final (second)** snake (blue) |
| `docs/qa/sheets_new/cleaned/cleaned_sheet_<kk>_new.png` (13) | The cleaned shoe (raw AND mask, after the erase list): what the snake and the contour see; label: cleaned pixels |
| `docs/qa/sheets_new/snake_qa_new.csv` | The task's copy of the metrics table, written by `qa_snake --metrics` (A-104) |
| `docs/qa/T4/new/flagged/im_<i>_new.png` (30) | Each flagged shoe at twice the size: init + first snake, init + second snake, raw shoe with mask boundary, removed and erased pixels, final snake and RAC pixels |
| `docs/qa/T4/new/overrides_before_after_new.png` | The 23 per-shoe fallbacks: final snake with the profile radius 10 (before) and with the override (after; radius 24, or 16 for 165), RAC pixels green inside the contour fill, magenta outside |
| `images_new/qa_snake/im_<i>_new.png` (631, gitignored) | The plan's two-panel QA figure of every shoe (init red dashed + first snake blue; init + second snake), rebuilt by `qa_snake --figures` |

## The prototype (`prototype_mask_new.png`, after the erase-list fix)
- The superposition of the 631 new shoes is a sole silhouette with toe up, the round-lug forefoot and the four heel pads of the most common design as high counts. The ellipse (2023 values: centre row 185, column 128; radii 162 and 95) encloses it with margins at the sides and the heel and touches it at the toe tip.
- The mask from >= 18 shoes (34,509 px; 35,156 before the erase-list fix, A-100) and from >= 29 (33,428 px) differ only in a thin ring (1,083 px), widest along the left side of the arch and the right side of the heel. The >= 18 mask keeps a straight left edge at the arch with a step at the arch-heel transition.
- The union of all prints (grey) shows the debris and frame regions above the toe, beside the forefoot and right of the heel; all lie outside both masks.
- 18 is kept (A-096): it keeps more real sole.

## Prototype sheets (raw shoes against the mask)

| Sheet | Shoes | What I saw (removed px in brackets) |
|---|---|---|
| 1 | 1-49 | Every print inside the boundary. The toe-stripe tips of 14 (53) and 15 (52) poke above the mask's top edge (real toe, `mask_cut`), with specks top right; debris of 35 (247, top left, left, below the heel) and 36 (333, the strip along the left forefoot edge and specks top right); specks on 3, 6, 9, 13, 23, 24, 37; 8 is the very faint partial print |
| 2 | 50-98 | All inside. Removed: specks of 55 (171), 56 (19), 92 (21); 93's thin frame line right of the heel (53); small marks on 66, 67, 73, 96 |
| 3 | 99-147 | All inside. Removed: debris above and right of the toe of 104 (163; its over-inked toe reaches the boundary), 105 (52; its blob now magenta, erased), 114 (144, a fragment top left), a speck of 133 (31); **125 loses its toe tip above the mask edge (36)** |
| 4 | 148-196 | The frame lines of 148 (3) and 149 (19) across the top in magenta; 186 (217): double line at the top and the line below the heel in magenta, the vertical line right of the print red with its ends magenta; specks on 156, 167, 172, 184, 185 |
| 5 | 197-245 | All inside; 216's blob below-left of the heel (36), 231's speck top right (26) |
| 6 | 246-294 | All inside; debris of 264 (61), 285 (57), 260 (16); specks on 254, 271, 273, 281 |
| 7 | 295-343 | All inside; debris of 329 (65), 330 (54), 314 (20); specks on 325, 326, 332, 337 |
| 8 | 344-392 | All inside. **379 loses a strip of its heel rim below the mask edge (47)**; specks on 372, 386, 388 |
| 9 | 393-441 | All inside. **422 (82) and 423 (48) lose heel-bottom corners beyond the mask edge** (422 also a blob right of the heel); specks on 401, 406, 432, 433 |
| 10 | 442-490 | All inside; 462's blob left of the heel bottom (98), 486's toe tip (14), specks on 455, 457, 477, 490; 481's dash is erased |
| 11 | 491-539 | All inside; specks on 493, 510, 520, 524, 539 |
| 12 | 540-588 | 580 (685): band above the toe, wedge right of the heel and the bar below the heel magenta and red; 582 (181): top frame line magenta, debris left of forefoot and heel red; 585 (29): the tilted line under the heel magenta; 586 (93): band and the block over the toe magenta; 584 (10): its line under the heel magenta; debris of 577, 581, 583, 588 |
| 13 | 589-631 | 589's wedge and specks top right (140; its tip erased); 611's blob right of the heel (123), specks on 597, 608, 610; 598-599 and the flat soles 628-631 inside |

**Prototype fit:** the mask fits every new print. Real sole beyond the mask edge is removed on 14, 15, 36, 104, 125, 486 (toe tips and forefoot edges, 10-36 px) and 379, 422, 423 (heel rims and corners), class `mask_cut` in the review file; elsewhere the red is debris.

## Ellipse and first-snake sheets
- **Initial ellipse:** it encloses the print with margins at the sides and the heel, but **not always at the toe**: the cleaned print touches or crosses the ellipse's top on 43 of 631 NEW shoes (OLD 13 of 386; smallest margin p5 -1.1 px against +0.8 on OLD), most on 14 (97 px outside), 15 (72), 104 (46), 35 (44), 125 (38), 170 (35); seen on sheets 1-4 (14, 15, 35, 36, 104, 125). The final contours of these shoes still reach the toe tip. A larger ellipse was tried and did not improve the snakes (A-105).
- **First snakes:** with the closing (radius 10) they wrap forefoot and heel pads as one silhouette on every sheet; on the boots (sheets 5-7) they bridge the arch, which is their role. Fallback shapes: 8 (large outline with a V bottom), 12, 46, 69, 120, 140, 173, 222, 235, 267, 286, 427, 456, 506 (rounder heels, toes or edges on radius 24; 427's toe top rises at the right to its toe-tip mark), 376 (radius 24: the first snake still rises to a short peak at the toe, the final contour is rounded), 163 (mitten with a thumb), 557 (neck to the toe tip), 165 (radius 16, pointed toe). 580's first snake hugs the real print with a rounded heel bottom; 586's is flat at the top (the erase leaves a flat print top, below).

## Final-snake sheets (the contour that step 2 uses)

| Sheet | Shoes | What I saw |
|---|---|---|
| 1 | 1-49 | Forefoot and the four heel pads enclosed on nearly all. 8 (partial print, V bottom); 9 (a point at the toe up to an isolated mark, `spike`); 11 (wedge around a partly printed heel); 12 and 46 now on radius 24 (heel bottom, right forefoot edge enclosed); 14 and 15 toe stripes at the mask edge; 18 (lower-left heel corner unprinted, a RAC there); 35, 36 debris outside; 47 a bulge top left of the toe |
| 2 | 50-98 | Every contour encloses forefoot and pads; 63 heel bottom (radius 24), 69 rounded toe (radius 24); 89 a small protrusion at a toe mark; 93's frame line outside |
| 3 | 99-147 | 107 (lower heel fragments, a RAC on a speck outside), 109 (horn at the toe, radius 24), 112 (diagonal heel bottom, radius 24), 113, 121 (fragmentary heels), 120 and 140 (heel corners on radius 24), 125 (toe tip cut by the mask); debris of 104, 105, 114, 133 outside |
| 4 | 148-196 | Erased frame lines of 148, 149, 186; 163 (mitten, radius 24); 165 (radius 16); 170 (heel-pad rim 1-3 px outside, `rim_cut`); 173 (wider toe top, radius 24); 185 (profile radius again); 186 follows its clipped left edge |
| 5 | 197-245 | 205 (a dip between the lower heel pads, a RAC 2 px below it); 222 (heel corner, radius 24); 223's thin stroke inside; 231 (a speck above-left of the toe outside); 235 (convex edge, radius 24); boots with straight contours at the waist, as on OLD |
| 6 | 246-294 | 263 (a RAC below the printed heel arc); 267 (rounded heel bottom, radius 24); 274 (narrow partial print); 286 (toe top raised, radius 24); 294 (1-3 px inside the toe smear, `rim_cut`) |
| 7 | 295-343 | 302, 314 (specks outside); 328 (the U rim's bottom did not print; specks below it outside, beyond where the same-design 327's heel ends) |
| 8 | 344-392 | 344/345 heel plate inside (moulded, RACs on it); 354/355 straight left side across the waist; 361 flat slanted top (toe not printed); 375 S-shaped print; 376 rounded toe (radius 24, no longer a finger); 379 heel rim cut by the mask |
| 9 | 393-441 | 401 (a speck below-right of the heel); 405 (real waist); 420 (partial spiral print); 422, 423 heel corners cut by the mask; 427 (rounded toe over its toe-tip mark, radius 24); 432 (a debris blob below-left of the heel); 437 (a speck right of the arch) |
| 10 | 442-490 | 456 (rounded toe top, radius 24); 486's toe-tip blob inside; 462's debris and 481's erased dash outside |
| 11 | 491-539 | 503 (a RAC 2 px outside); 506 (rounded toe top, radius 24; two RACs above the toe off the print); 518, 527 striped toes peaking to a top mark |
| 12 | 540-588 | 557 (neck to the toe tip, radius 24); 580 (rounded heel bottom, no box); 582, 585 artefacts erased; 583 and 585 marks right of the arch outside; 586 (blunt toe, below) |
| 13 | 589-631 | All follow their outlines; 589's wedge outside |

No loop, no self-intersection (0 of 631 by the metric), no border contact; contours 611-766 px (OLD 614-742). The flagged shoes, the overrides and the classes are listed in the review file.

## Cleaned sheets (what the snake runs on)

Looked at all 13 (shoes 1-631): every cleaned record holds sole only. The frame artefacts of 148, 149, 186, 580, 582, 584, 585, 586, 589 are gone (erased or outside the mask), as are 105's debris blob and 481's dash; the debris beside the sole is gone; tiny specks remain at the toe edge of 35 and 36 inside the mask. Known residuals: 223's thin 1-px stroke between the heel pads (37 px) stays inside the outline (nothing marks it as non-sole, and it cannot move the contour); 586's toe: the erase leaves a flat print top on row 43, so its contour's toe is 15-20 px wider near the top than that of the same-design 587, while its top row (34) lies within 1 row of 587's aligned one (35). 344 and 345 keep their transverse heel plate, which is moulded sole (T3: RACs on it).

## Stickers (מדבקות)

**No police-type sticker or label (a solid rectangle or a label with text, as on OLD 59, 66, 142, 150, 374) is on any of the 631 new prints.** What the new prints carry are straight-edged frame artefacts (the edge of the lifting medium or the scanner plate) and margin debris; above-right of 14's toe a few red marks look like characters, outside the mask and removed. The artefacts and debris outside the mask are removed by the AND-cleaning, as the stickers were on OLD; those that overlap the mask (11 shoes) are erased explicitly (`data/new_shoes/sticker_masks_new.csv`, 48 rectangles, 4,143 contact pixels, 2,010 of them inside the mask; A-095, A-100), in Python and in R. **After the review fixes no artefact is left in a cleaned shoe or a contour** (looked at on all 13 cleaned and 13 final-snake sheets and at 4x on 580, 584, 586, 587, 581, 583, 148, 186, 105, 481); the residuals are the two named above.

## Flagged shoes (`docs/qa/T4/new/flagged/`, 30)

Looked at all 30 at twice the size, three per view. By kind:
- RACs off the print (outside on every radius): 8, 11, 18, 107, 113, 121, 140, 263, 503, 506 (partial prints, except 503);
- isolated specks or debris far from the print (the contact trigger; the fallback would bulge out to them): 14, 24, 35, 120, 149, 231, 302, 314, 328, 401, 422, 432, 437, 583, 585, 586;
- the contour along the mask edge (`outside_mask_frac`): 14, 36;
- a printed heel-pad rim 1-3 px outside: 170;
- waisted soles (tightness): 375, 405.
Before/after of the 23 fallbacks (`overrides_before_after_new.png`, looked at with all 23 pairs): radius 24 encloses the cut heel corners and toes (12, 63, 69, 109, 112, 113, 120, 140, 173, 222, 235, 267, 286, 427, 456, 506, 557), replaces 376's narrow finger by a rounded toe, and 165 takes radius 16; 8 and 163 stay envelopes of a partial print; 175 changes little.

## Review classes (`docs/qa/T4/new/snake_review_new.csv`, A-101)
- `partial_print` (28): 8, 11, 12, 18, 69, 107, 109, 112, 113, 120, 121, 140, 163, 173, 186, 222, 263, 267, 274, 286, 328, 361, 376, 420, 427, 456, 506, 557;
- `spike` (1): 9; `rim_cut` (3): 170, 205, 294; `mask_cut` (9): 14, 15, 36, 104, 125, 379, 422, 423, 486.

## Against the OLD bar (the eight points above)
1. Initial ellipse: encloses every print at the sides and the heel; at the toe the print touches or crosses it on 43 shoes (OLD 13), and the final contours still reach the toe tip.
2. First snake: smooth, on the outer envelope; with the closing it no longer stops between separate elements.
3. Second snake: follows the outline within a few pixels; no loop.
4. Final contour: 611-766 px; no border contact.
5. Coverage: the row-span fill holds at least 98.4% of the cleaned contact in every shoe (p1 99.6%), the snake polygon at least 98.0% (p1 99.3%); RAC coverage p1 0.963; a RAC 3 px or more outside on 7 shoes and contact more than 8 px outside on 19, all reviewed (off-print RACs and specks).
6. Stickers: none on NEW; artefacts removed or erased; none left in a cleaned shoe or contour (two named residuals).
7. Mask vs sole: real sole beyond the mask edge on 9 shoes (`mask_cut`, 10-82 px each).
8. Contour vs mask: share of contour pixels outside the mask median 0.006, p99 0.28 (OLD median 0.057, p99 0.34).
