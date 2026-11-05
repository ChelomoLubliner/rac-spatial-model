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
The verbatim legacy code under the thesis **Windows** venv (venv-wind: Python 3.13.14, numpy 2.2.6, scipy 1.16.3, scikit-image 0.25.2) reproduces **all 386** committed records. Under the WSL venv (Python 3.12.3, the same package versions), 356 records are identical and **30 differ**, by a mean distance of up to 1.50 px and a maximum of 8.94 px (`tests/baseline/local/contour_linux_diff.csv`). The cause is floating-point differences of about 1e-8 px between the two numeric builds: `np.int32` truncation in `cv2.polylines` and the 2,500-iteration snake amplify them for some shoes (shoe 176: first snakes 3e-9 px apart, second snakes 5 px apart). Each platform is deterministic. That is why the gallery was built with venv-wind: its snake panels are exactly the snakes that produced the committed contour. A first build on WSL (kept in the T1 scratch folder) differed in 8 of the 67 gallery shoes (11, 21, 80, 152, 176, 221, 349, 354). Decision A-060 records what this means for T2 and T4.
