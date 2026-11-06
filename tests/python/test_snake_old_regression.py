"""OLD snake regression (T1): the snake code must reproduce the committed
contour records exactly on the platform that produced them, and the
recorded Linux rerun (Tier B) exactly on Linux.

T1 found (docs/tests/T1-baseline-results.md, decision A-060): the
committed contour is a Windows result. The verbatim legacy code reproduces
all 386 records under the thesis Windows venv; under the WSL venv (same
package versions) most records are reproduced and the others differ by
about one pixel (deterministic on each platform).

Default (fast, about 40 s): runs the legacy snake (`contour_algorithm/`,
the verbatim thesis code at 109f30a) in a temporary folder (the module-level
FOLDER of the legacy modules points there; nothing in the repo is written):
  - shoes reproduced on both platforms -> equal to the committed record;
  - platform-sensitive shoes -> the committed record on Windows, the Tier B
    record (tests/baseline/local/contour_linux_diff.npz) on Linux.
Recorded: the npz rebuilds the Tier B contour from the committed bytes with
the sha256 in tests/baseline/local/python_contour.sha256, and the Windows
check (contour_windows_check.txt) found 0 differing records of 386.
Full (optional): RAC_REGRESS_PY_RUN=<folder of run_legacy_python.sh>
compares all 386 records of that run with Tier B (Linux) or Tier A, and
(Linux) all 1,556 intermediate .npy/.png files with Tier B. The folder
must first prove that it wrote them (decision A-067,
tests/lib/run_manifest.py): exit_status 0, step0 with exit 0 in
timings.tsv, the contour on its outputs_regenerated.sha256 list, and every
intermediate newer than its outputs_expected.txt. Only a run that Tier B
was not written from is evidence: Tier B came from
<scratch>/t1/legacy_py_MXmkvc, so that folder can only pass (A-066); the
T1 run folders predate the manifest and are refused.

Run from the repo root with the thesis venv python:
  MPLBACKEND=Agg python -B -m unittest tests.python.test_snake_old_regression
"""

import hashlib
import os
import platform
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

from tests.lib import contour_platform_diff as cpd
from tests.lib.run_manifest import check_run_manifest

REPO = Path(__file__).resolve().parents[2]
LEGACY = REPO / 'contour_algorithm'
LOCAL = REPO / 'tests' / 'baseline' / 'local'
W, H = 307, 395
SKIPPED_IDX0 = 126  # shoe 127: no RACs, no contour record
# 0-based image indices: shoe 1; shoe 9 (left shoe, not flipped, K1);
# shoes 35 and 153 (lowest RAC on-contact rates, plan F27); shoe 236
# (printed twice inside OLD, K10); shoe 387 (last record).
SHOES_IDX0 = (0, 8, 34, 152, 235, 386)
# Shoes whose Linux record differs from the committed (Windows) one:
# 176 (1,402 px, mean distance 1.15 px) and 354 (18 px).
PLATFORM_SENSITIVE_IDX0 = (175, 353)
COMMITTED_CONTOUR_SHA256 = (
    'ca8a07f2a46614a14383a8017b688663caba8350c3ea41c51792d8ebd0ec7e56')
ON_WINDOWS = platform.system() == 'Windows'


def read_records(path, width=W, height=H):
    """Records of a fixed-stride 0/1 file (LF or CRLF), as uint8 (n, H, W)."""
    data = Path(path).read_bytes()
    size = width * height
    for sep in (b'\r\n', b'\n'):
        stride = size + len(sep)
        if len(data) % stride == 0:
            arr = np.frombuffer(data, dtype=np.uint8).reshape(-1, stride)
            if np.all(arr[:, size:] == np.frombuffer(sep, dtype=np.uint8)):
                return (arr[:, :size] - 48).reshape(-1, height, width)
    raise ValueError(f'{path}: not a fixed-stride 0/1 file')


def record_index(idx0):
    """Contour record (0-based) of the shoe with 0-based image index idx0."""
    if idx0 == SKIPPED_IDX0:
        raise ValueError('shoe 127 has no contour record')
    return idx0 if idx0 < SKIPPED_IDX0 else idx0 - 1


def load_legacy_modules():
    os.environ.setdefault('MPLBACKEND', 'Agg')
    if str(LEGACY) not in sys.path:
        sys.path.insert(0, str(LEGACY))
    import active_contour_snake
    import remove_noise
    return active_contour_snake, remove_noise


def linux_records():
    """{record index: bool (H, W) array} of the Tier B (Linux) rerun where it
    differs from the committed contour."""
    npz = np.load(LOCAL / 'contour_linux_diff.npz')
    bits = np.unpackbits(npz['packed'], axis=1, count=W * H).astype(bool)
    return {int(k): b.reshape(H, W) for k, b in zip(npz['records'], bits)}


class SnakeOld(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.acs, cls.rn = load_legacy_modules()
        cls.tmp = tempfile.TemporaryDirectory(prefix='snake_old_')
        folder = cls.tmp.name + os.sep
        os.makedirs(folder + 'saved')
        os.makedirs(folder + 'cleaned_shoes')
        mask = np.array(Image.open(REPO / 'data/freq_min_18.png')) > 0
        np.save(folder + 'saved/freq_min_18.npy', mask)
        cls.saved_folders = (cls.acs.FOLDER, cls.rn.FOLDER)
        cls.acs.FOLDER = folder
        cls.rn.FOLDER = folder
        cls.mask = mask
        cls.shoes = read_records(REPO / 'data/contacts_data.txt') == 1
        cls.contour = read_records(REPO / 'data/contour_Active_Contour.txt')

    @classmethod
    def tearDownClass(cls):
        cls.acs.FOLDER, cls.rn.FOLDER = cls.saved_folders
        cls.tmp.cleanup()

    def rerun(self, idx0):
        self.rn.save_cleaned_shoes(self.shoes, idx0)
        return self.acs.active_contour_shoe(
            None, plot_img=False, save_img_bool=False, im_num=idx0)

    def test_inputs(self):
        self.assertEqual(self.shoes.shape, (387, H, W))
        self.assertEqual(self.contour.shape, (386, H, W))
        self.assertEqual(int(self.mask.sum()), 32975)

    def test_reproduces_committed_records(self):
        for idx0 in SHOES_IDX0:
            with self.subTest(shoe=idx0 + 1):
                got = self.rerun(idx0)
                want = self.contour[record_index(idx0)] == 1
                self.assertEqual(got.shape, (H, W))
                self.assertEqual(int((got != want).sum()), 0)

    def test_platform_sensitive_records(self):
        linux = linux_records()
        for idx0 in PLATFORM_SENSITIVE_IDX0:
            k = record_index(idx0)
            with self.subTest(shoe=idx0 + 1):
                self.assertIn(k, linux)
                got = self.rerun(idx0)
                want = (self.contour[k] == 1) if ON_WINDOWS else linux[k]
                self.assertEqual(int((got != want).sum()), 0)

    def test_full_rerun_recorded(self):
        lines = (LOCAL / 'python_contour.sha256').read_text().splitlines()
        crlf = [ln.split()[0] for ln in lines if ln.endswith('[LF->CRLF]')]
        self.assertEqual(len(crlf), 1)
        npz = np.load(LOCAL / 'contour_linux_diff.npz')
        self.assertEqual(str(npz['sha_crlf']), crlf[0])
        self.assertNotEqual(crlf[0], COMMITTED_CONTOUR_SHA256)
        committed = (REPO / 'data/contour_Active_Contour.txt').read_bytes()
        rebuilt = cpd.apply_records(committed, npz)
        self.assertEqual(hashlib.sha256(rebuilt).hexdigest(), crlf[0])
        check = (LOCAL / 'contour_windows_check.txt').read_text()
        self.assertIn('records compared: 386', check)
        self.assertIn('records with differing pixels: 0', check)

    @unittest.skipUnless(os.environ.get('RAC_REGRESS_PY_RUN'),
                         'set RAC_REGRESS_PY_RUN to a legacy run folder')
    def test_full_run_folder(self):
        run = Path(os.environ['RAC_REGRESS_PY_RUN'])
        contour = 'data/contour_Active_Contour.txt'
        check_run_manifest(run, [contour], steps=('step0',))
        got = read_records(run / contour)
        want = self.contour.copy()
        if not ON_WINDOWS:
            for k, rec in linux_records().items():
                want[k] = rec
        self.assertEqual(got.shape, want.shape)
        per_record = (got != want).reshape(got.shape[0], -1).sum(1)
        self.assertEqual(np.flatnonzero(per_record).tolist(), [])

    @unittest.skipUnless(os.environ.get('RAC_REGRESS_PY_RUN'),
                         'set RAC_REGRESS_PY_RUN to a legacy run folder')
    @unittest.skipIf(ON_WINDOWS, 'Tier B intermediates are Linux bytes')
    def test_full_run_intermediates(self):
        run = Path(os.environ['RAC_REGRESS_PY_RUN'])
        check_run_manifest(run, ['images/saved/freq_min_18.npy'],
                           steps=('step0',))
        start = (run / 'outputs_expected.txt').stat().st_mtime_ns
        want = {}
        for line in (LOCAL / 'python_intermediates.sha256').read_text(
                ).splitlines():
            want[line[66:]] = line[:64]
        have = sorted(p.relative_to(run).as_posix()
                      for p in (run / 'images').rglob('*')
                      if p.is_file() and p.suffix in ('.npy', '.png'))
        self.assertEqual(len(want), 1556)
        self.assertEqual(have, sorted(want))
        old = [p for p in have if (run / p).stat().st_mtime_ns <= start]
        self.assertEqual(old, [], 'files older than the start of the run')
        bad = [p for p in have
               if hashlib.sha256((run / p).read_bytes()).hexdigest()
               != want[p]]
        self.assertEqual(bad, [])


if __name__ == '__main__':
    unittest.main()
