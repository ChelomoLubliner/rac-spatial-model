# New shoes dataset (second dataset, used for out-of-sample validation)

These are 631 shoes from a **separate dataset**. None of them are among the 387 original shoes.
It was added to answer FSI reviewer 1, point 6 (out-of-sample validation), manuscript FSI-D-26-01184.

Copied on 2026-11-05 from `Desktop/These/Files_thesis/Data/new_shoes/`. The files are byte-identical to the originals.

| File in repo | Original name | Content |
|---|---|---|
| `contacts_data_new.txt` | `contacts_data_naomi_fast.txt` | Binary contact surfaces: 631 shoes x (255 cols x 367 rows = 93,585 chars), one record per shoe, records separated by `\r\n` (so the record stride is 93,585 + 2) |
| `locations_data_new_raw.txt` | `results_data_naomi_fast.txt` | Raw RAC locations from Naomi: 20,013 rows, space-separated, no header: `shoe rac_num x y type`. **Coordinates are 2x the original scale** (y in about [-1, 1]) |
| `locations_new_snake_2023.csv` | `locations_chelomo_new.csv` | Shlomo's 2023 processing: same 20,013 RACs, **coordinates divided by 2** (same scale as `data/locations_data.csv`), plus `COL, ROW` and the snake/convex-hull distances (`INSIDE_SNAKE, HORIZ_DIST_SNAKE, DIST_SNAKE, INSIDE_CONV, ...`) |

## Notes
- Comparing the first rows: raw x = -0.409554 corresponds to x = -0.204777 in the 2023 file. That is exactly a factor of 2.
- The 2023 snake distances were computed before the final Active_Contour settings used in the paper. Recompute them with the adapted snake before relying on them.
- Do **not** convert the line endings. The R readers use fixed byte offsets (`col_shoe * row_shoe + 2`).
- Mean of about 32 RACs per shoe (maximum 281).
