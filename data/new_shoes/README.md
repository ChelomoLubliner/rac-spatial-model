# New shoes dataset (second dataset, used for out-of-sample validation)

These are 631 shoes from a **separate dataset**. The original note said that none of them are among the 387 original shoes; the data contradict this (see the notes below).
It was added to answer FSI reviewer 1, point 6 (out-of-sample validation), manuscript FSI-D-26-01184.

Copied on 2026-11-05 from `Desktop/These/Files_thesis/Data/new_shoes/`. The files are byte-identical to the originals.

| File in repo | Original name | Content |
|---|---|---|
| `contacts_data_new.txt` | `contacts_data_naomi_fast.txt` | Binary contact surfaces: 631 shoes x (255 cols x 367 rows = 93,585 chars), one record per shoe, records separated by `\r\n` (so the record stride is 93,585 + 2) |
| `locations_data_new_raw.txt` | `results_data_naomi_fast.txt` | Raw RAC locations from Naomi: 20,013 rows, space-separated, no header: `shoe rac_num x y type`. **Coordinates are 2x the original scale** (y in about [-1, 1]) |
| `locations_new_snake_2023.csv` | `locations_chelomo_new.csv` | Shlomo's 2023 processing: same 20,013 RACs, **coordinates divided by 2** (same scale as `data/locations_data.csv`), plus `COL, ROW` and the snake/convex-hull distances (`INSIDE_SNAKE, HORIZ_DIST_SNAKE, DIST_SNAKE, INSIDE_CONV, ...`) |

Derived file (T3, 2026-11-06; not a copy of an original, decision A-088):

| File | Written by | Content |
|---|---|---|
| `locations_data_new.csv` | `RAC_DATASET=new python -m contour_algorithm.locations` (`--check` compares) | The raw locations in the column format of `data/locations_data.csv`: `shoe,x,y,type,rac_num` (OLD has `orientation, grade` instead of `rac_num`; the NEW data have neither). x and y = raw / 2 in exact decimal arithmetic, 7 decimals, LF line endings, file order. Equal to the 2023 file's x and y for all 20,013 RACs (to the last bit, in Python and in R); the pipeline still reads the raw file through the profile (divisor 2), with the same values |

T4 files (2026-11-06; decisions A-095, A-097, A-098; revised in the T4 review fixes, A-100, A-102, and the second T4 review fixes, A-107 to A-109):

| File | Written by | Content |
|---|---|---|
| `contour_Active_Contour_new.txt` | `RAC_DATASET=new python -m contour_algorithm.main --qa --jobs 14` | The snake contour of every NEW shoe: 631 records of 255 x 367 characters `0`/`1`, each followed by `\r\n` (the stride of `contacts_data_new.txt`); record k = shoe k (no shoe skipped or excluded). Built on WSL with one OpenBLAS thread and the Haswell kernel (the NEW profile fixes both: `python.blas_threads`, `python.blas_kernel`; step 0 refuses another, A-108), sha256 `f7703bcd...` since the second T4 review fixes (T4 review fixes: `0af52b05...`; T4: `88d55933...`); QA in `docs/qa/snake-qa.md`; `tests/rebuild_new.sh` rebuilds it in a scratch copy and compares it with HEAD |
| `sticker_masks_new.csv` | the T4 reviewer, from pixel dumps | Erase list (`shoe,row0,row1,col0,col1,reason`, 1-based inclusive ranges of the stored record): 49 rectangles of frame artefacts and debris on 11 shoes that overlap the prototype region (T4: 25 on 8; the review fixes added 584's line, 586's band block, 580's bar outside the same-design heel envelope, line ends of 148 and 186, 105's debris blob, 481's dash; the second review fixes a piece of 186's vertical frame line); written by `docs/qa/T4/probes/t4fix_erase_list.py`; erased when the contacts are read by step 0 (Python) and step 1 (R). The raw file itself is never changed |
| `snake_overrides_new.csv` | the T4 reviewer | Per-shoe snake fallbacks (`shoe,first_closing_radius,center_r,center_c,radius_r,radius_c,reason`; empty = the profile's value): closing radius 24 for 22 shoes and 16 for one (165) whose profile contour failed QA or, for 376, showed a finger toe, and the initial ellipse (187, 127) / (167, 98) for 170, whose heel-pad rim lay beyond the profile ellipse (A-107); each with its before/after metrics and its decision (T4: 9 shoes); written by `docs/qa/T4/probes/t4fix_overrides.py`, which holds every reason and decision tag (A-109) |

## Notes
- Comparing the first rows: raw x = -0.409554 corresponds to x = -0.204777 in the 2023 file. That is exactly a factor of 2.
- The 2023 snake distances were computed before the final Active_Contour settings used in the paper. Recompute them with the adapted snake before relying on them.
- Do **not** convert the line endings. The R readers use fixed byte offsets (`col_shoe * row_shoe + 2`).
- Mean of about 32 RACs per shoe (maximum 281).
- **Pixel mapping (T3, decisions A-086, A-087):** the NEW images use the OLD mapping: 300 px per coordinate unit on both axes (after the division by 2), x mirrored, y not flipped, the legacy centre (R `aspix` with `col_shoe` 255, `row_shoe` 367). Calibrated from the data: 80.8% of the RACs fall on a contact pixel, 97.5% within one pixel; the 2023 `COL, ROW` equal this mapping for every RAC.
- **"No overlap" is contradicted by the data:** about 67 NEW shoes look like reprints of OLD shoes (decision D-012, plan F25).
