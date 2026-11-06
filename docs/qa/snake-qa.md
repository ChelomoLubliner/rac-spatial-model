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

# NEW shoes (T4, 2026-11-06): what the snake does on the 631 new shoes

**Written by:** the T4 implementer, after opening every image named here with the Read tool (user rule 10). Decisions A-091 to A-098; numbers and commands in `docs/tests/T4-snake-results.md`. Several images I opened during the work came back without their picture (a request limit of the viewer); I reopened every image that this page describes, and nothing here rests on an image I did not see.

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
| `docs/qa/T4/new/flagged/im_<i>_new.png` (12) | Each flagged shoe at twice the size: init + first snake, init + second snake, raw shoe with mask boundary, removed and erased pixels, final snake and RAC pixels |
| `docs/qa/T4/new/overrides_before_after_new.png` | The 9 per-shoe fallbacks: final snake with the profile radius 10 (before) and radius 24 (after), RAC pixels green inside the contour fill, magenta outside |
| `images_new/qa_snake/im_<i>_new.png` (631, gitignored) | The plan's two-panel QA figure of every shoe (init red dashed + first snake blue; init + second snake), rebuilt by `qa_snake --figures` |

## The prototype (`prototype_mask_new.png`)
- The superposition of the 631 new shoes is a sole silhouette with toe up, the round-lug forefoot and the four heel pads of the most common design as high counts; the ellipse (2023 values: centre row 185, column 128; radii 162 and 95) encloses it with margins at the sides and the heel and touches it at the toe tip, as the OLD ellipse does for the OLD prototype.
- Both prototype snakes follow the silhouette; the mask boundary hugs it. The mask from >= 18 shoes (35,156 px) and from >= 29 (33,250 px) differ only in a ring of 1-3 px all around the outline (1,908 px), widest at the toe and along the right side of the forefoot.
- The union of all prints (grey) shows what the mask must remove: frame and debris regions above the toe, beside the forefoot and right of the heel (580's wedge); all of them lie outside both masks.
- 18 was chosen (A-096): it keeps more real sole. Of the 21 shoes with the most contact in the 18-29 ring (looked at before the erase list), the ring held sole edges on 36, 104, 14, 105, 125, 15, 35, 114, 37, 156 and others, and frame artefacts only on 586, 186 and 580, which the erase list now removes.

## Prototype sheets (raw shoes against the mask)

| Sheet | Shoes | What I saw |
|---|---|---|
| 1 | 1-49 | Every print inside the boundary. Specks removed beside the toe on 3, 6, 13, 14, 15, 23, 24; the margin debris of 35 (236 px, top left of the toe and left of the forefoot) and 36 (303 px, left of the forefoot and right of the toe) removed. 8 is the very faint partial print. No sole cut |
| 2 | 50-98 | All inside. Removed: specks left of the forefoot and heel of 55 (155 px), small marks on 56, 66, 67, 73, 92, 96; 93's thin frame line right of the heel (53 px) |
| 3 | 99-147 | All inside. Removed: debris above and right of the toe of 104 (141 px) and 105 (129 px), the fragment left of the toe of 114 (136 px), a speck top left of 133; **125 loses 22 px of its toe tip**, which pokes 1-3 px above the mask edge (zoomed: real toe pixels) |
| 4 | 148-196 | The frame lines of 148, 149 (top) and 186 (top and bottom) in magenta (erased) and red; all prints inside |
| 5 | 197-245 | All inside; specks removed on 216 and 231 |
| 6 | 246-294 | All inside; small debris removed on 260, 264, 285 |
| 7 | 295-343 | All inside; specks removed on 314, 329, 330 |
| 8 | 344-392 | All inside. **379 loses 40 px**, a 2-3 px strip of its heel rim below the mask edge (zoomed) |
| 9 | 393-441 | All inside. **422 and 423 lose 75 and 59 px** at the bottom-left and bottom-right corners of the heel, beyond the mask edge (zoomed; 422 also a separate blob right of the heel) |
| 10 | 442-490 | All inside; 462's margin debris (98 px) removed |
| 11 | 491-539 | All inside; specks removed on 493, 520, 524, 539 |
| 12 | 540-588 | The artefacts of 580 (band above the toe, wedge and bars at the heel), 582 (tilted line above the toe), 585 (thin line under the heel), 586 (thick band over the toe) in magenta (erased) and red; debris right of the toe of 581 (57 px) and 588 (81 px) removed |
| 13 | 589-631 | 589's wedge and specks at the top right (140 px) removed (its tip erased); 611's blob right of the heel (123 px) and a speck below 610's heel removed; the different image type 598-599 and the flat soles 628-631 inside |

**Prototype fit:** the mask fits every new print. Real sole beyond the mask edge is cut on four shoes (125 toe tip 22 px; 379, 422, 423 heel bottom 40-75 px; 0.3-0.6% of each print), the same effect as on OLD 80 and 9: there the contour follows the mask edge. The plan's criteria hold (every RAC pixel inside the mask, the median shoe keeps 100% of its contact, p5 99.76%).

## Ellipse and first-snake sheets

| Sheet | Shoes | What I saw |
|---|---|---|
| 1 | 1-49 | Every ellipse encloses its print with a margin (at the toe tip the margin is smallest, as on OLD). With the closing (radius 10) the first snakes wrap forefoot and heel pads as one silhouette; 8 (fallback radius 24) a sole-shaped outline of a faint print; 11 includes its partly printed heel; the wide forefoots of 14 and 15 and the over-inked forefoots of 35 and 36 are followed |
| 2 | 50-98 | Every first snake wraps forefoot and all four heel pads; no cut |
| 3 | 99-147 | Fine; 112 (fallback) reaches its heel fragments; 107, 121, 140 have sound outlines |
| 4 | 148-196 | Fine; 163 (fallback) follows a narrow faint print with a small bump at the toe fragment; 165 a pointed toe; 186 wraps its smeared print with no frame line left |
| 5 | 197-245 | Fine; on the boots the first snake bridges the arch, which is its role |
| 6 | 246-294 | Boots, all fine; 286 (very faint) and 274 (partial) follow their printed parts |
| 7 | 295-343 | Fine |
| 8 | 344-392 | Fine; on 354 and 355 the first snake bridges the narrow waist with a straight edge |
| 9 | 393-441 | Fine; 427's first snake dips where the top right of the toe did not print; 428 (the faintest print) follows its outline |
| 10 | 442-490 | Fine |
| 11 | 491-539 | Fine |
| 12 | 540-588 | 580's first snake hugs the real print (no band, no wedge); 586's follows the toe; 557 (fallback) includes its faint toe tip |
| 13 | 589-631 | Fine; 598-599 and the flat soles 628-631 wrapped closely |

## Final-snake sheets (the contour that step 2 uses)

| Sheet | Shoes | What I saw |
|---|---|---|
| 1 | 1-49 | Every second snake follows the outline, arch included, heel pads enclosed; the debris of 35 and 36 (red) lies outside the contour |
| 2 | 50-98 | Fine; 93's frame line (red) outside |
| 3 | 99-147 | Fine; the debris of 104, 105, 114 outside |
| 4 | 148-196 | Fine; the erased frame lines of 148, 149, 186 (magenta) and 186's vertical line right of the print (red) do not touch the contours |
| 5 | 197-245 | Fine; the boots' second snakes follow the arch concavity |
| 6 | 246-294 | Fine |
| 7 | 295-343 | Fine |
| 8 | 344-392 | Fine; 375 (flagged: tightness) follows its S-shaped narrow print |
| 9 | 393-441 | Fine; 405 (flagged: tightness) follows its waist; the heel-edge losses of 422 and 423 are small red marks at the heel bottom |
| 10 | 442-490 | Fine; on 486 a small blob at the toe tip lies just outside the contour (coverage 0.994, above the band) |
| 11 | 491-539 | Fine; 503 and 506 (flagged only for RACs off the print) have sound outlines |
| 12 | 540-588 | The contours of 580, 582, 585, 586 follow the real sole; the artefacts (magenta, red) lie outside |
| 13 | 589-631 | Fine |

No loop, no self-intersection (0 of 631 by the metric), no border contact, no cut-off toe or heel among the 631 contours; contours 611-766 px (OLD 614-742).

## Cleaned sheets (what the snake runs on)

Looked at all 13 (shoes 1-631): every cleaned record holds sole only. The frame artefacts of 148, 149, 186, 580, 582, 585, 586, 589 are gone (erased or outside the mask); the debris beside the sole is gone; tiny specks remain at the toe edge of 35 and 36 inside the mask. Two known residuals (A-095): the middle of 580's straight bottom bar merges with the heel bottom and stays (about 195 px of bar in its contact surface; the heel's extent equals that of 584), and 223's thin 1-px stroke between the heel pads (37 px) stays inside the outline. 344 and 345 keep their transverse heel band, which is moulded sole (T3: RACs on it).

## Stickers (מדבקות)

**No police-type sticker or label (a solid rectangle or a label with text, as on OLD 59, 66, 142, 150, 374) is on any of the 631 new prints**: not on the raw sheets (T3), not on the 13 prototype sheets, not on the 13 cleaned sheets, not on the 42 shoes with the most contact between the Python mask and the R stamp mask. What the new prints carry instead are straight-edged frame artefacts (the edge of the lifting medium or the scanner plate) and margin debris. Those outside the mask are removed by the AND-cleaning, as the stickers were on OLD; the ones that overlap the mask (8 shoes, list above) are erased explicitly (`data/new_shoes/sticker_masks_new.csv`, 25 rectangles), in Python and in R. **None survives in a cleaned shoe or in a contour** (looked at on all 631 cleaned shoes and final snakes).

## Flagged shoes (`docs/qa/T4/new/flagged/`)

Looked at all 12 at twice the size: 8 (faint partial print, fallback contour sole-shaped; specks and one RAC off the print outside), 11, 107, 121, 140, 263, 503, 506 (RACs off the print: the contours follow the printed outline, and 107's missed RAC sits on an isolated speck right of the heel), 165 and 170 (coverage 0.990 and 0.988: specks at a faint toe; a snake 1-2 px inside a heel-pad rim), 375 and 405 (tightness 0.86 and 0.89: narrow or waisted soles, contours that follow them correctly). Before/after of the 9 fallbacks (`overrides_before_after_new.png`): with radius 24 the contours enclose the heel fragments of 112, 113, 163, the heel bottom of 63 and 185, the toe parts of 109 and 557, and replace 8's notch by a sole-shaped outline.

## Against the OLD bar (the eight points above)
1. Initial ellipse: encloses every new print; the toe-tip margin is small, as on OLD.
2. First snake: smooth, on the outer envelope; with the closing it no longer stops between separate elements (the 2023-style failure on heel pads and partial prints).
3. Second snake: follows the outline within a few pixels (median contour 7, 6, 7, 5 px beyond the outermost print at top, bottom, left, right; OLD 7, 5, 7, 5); no loop.
4. Final contour: 611-766 px; no border contact.
5. Coverage: the row-span fill holds at least 98.4% of the cleaned contact in every shoe (p1 99.5%), the snake polygon at least 98.0% (p1 99.1%); RAC coverage p1 0.953 (missed RACs lie off the print).
6. Stickers: none on NEW; artefacts removed or erased; none in a cleaned shoe or contour.
7. Mask vs sole: the mask contains the sole except four small edge cuts (125, 379, 422, 423).
8. Contour vs mask: share of contour pixels outside the mask median 0, p99 0.22 (OLD median 0.057, p99 0.34).
