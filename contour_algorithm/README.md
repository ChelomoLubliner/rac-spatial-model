# contour_algorithm: verbatim copy of the thesis snake code (legacy)

The `.py` files and `requirements.txt` in this folder are **byte-identical copies** of
`contour_algorithm/` in the thesis repository
(`/mnt/c/Users/mehes/Documents/repo/master_thesis_forensic_shoeprint`) at commit `109f30a`
(the git blobs, LF line endings; the thesis working tree holds the same text with CRLF).
They were copied in T1 (2026-11-05) so that the plan's T2 port (style fixes, dataset profiles)
is a reviewable diff against the code that produced the committed old contour.

`requirements-lock.txt` is the `pip freeze` of the thesis venv (Python 3.12.3) that runs this code.
`requirements.txt` lists `alphashape`, which is not installed and is only used by
`alphas_shape.py` (not imported by `main.py`).

## Do not run it in place
The legacy code uses paths relative to its working directory: it reads `../data/contacts_data.txt`
and `../Data/locations_data.csv`, writes about 3.6 GB under `../images/`, and **overwrites
`../data/contour_Active_Contour.txt`** (with LF line endings, which breaks the committed CRLF file).
Run it only through `tests/legacy/run_legacy_python.sh`, which copies the code and the inputs into
a fresh scratch folder (`RAC_SCRATCH`). The only other user is
`tests/python/test_snake_old_regression.py`, which imports two modules and points their `FOLDER` at a
temporary folder. This holds until the T2d commit replaces the fixed paths with profile paths
(decision A-064). If `data/contour_Active_Contour.txt` is ever overwritten, restore it with
`git checkout -- data/contour_Active_Contour.txt`; the Tier A checksum of `tests/run_all.sh` fails
until it is restored.

Known issues kept as they are (plan, known issues): the left-shoe flip of image 8
(`create_files_shoes.py:26-30`) is dead code (`FOLDER` never equals `'Images/Old_Shoes/'`), so shoe 9
is not flipped (K1); `active_contour_snake.py:175` writes the fixed path above and `:177` skips
index 126 (shoe 127) for any dataset; `globals.py` selects the dataset with `OLD_DATASET` and uses
`../images/` for both datasets. flake8 reports 106 findings in these files. T2c, the first T2
commit, fixes them in a style-only commit before any change of logic (A-064). Until then the lint
check of `tests/run_all.sh` skips this folder.
