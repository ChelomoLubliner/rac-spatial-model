"""Tier A baseline and raw-data invariants (plan T1 step 1).

Run from the repo root with the thesis venv python:
  python -B -m unittest tests.python.test_baseline_raw_data -v
"""

import csv
import hashlib
import unittest
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
BASE = REPO / 'tests' / 'baseline'

STRIDE_FILES = (
    ('data/contacts_data.txt', 307, 395, 387),
    ('data/contour_Active_Contour.txt', 307, 395, 386),
    ('data/new_shoes/contacts_data_new.txt', 255, 367, 631),
)
OLD_ARTIFACTS = (
    'data/contour_Active_Contour.txt', 'data/freq_min_18.png',
    'data/contour_prototype.png', 'data/all_cont.csv',
    'processed_data/dataCC.csv', 'processed_data/dataCC_distance.csv',
    'processed_data/dataCC_distance_part4.csv',
    'processed_data/dataCC_distance_temp.csv',
    'processed_data/shoe_pixel_counts.csv',
    'saved_models/CML_MODEL.rds', 'saved_models/NEW_X_NS_XY.rds',
)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def read_sha_file(path):
    entries = []
    for line in path.read_text().splitlines():
        digest, name = line.split('  ', 1)
        entries.append((digest, name))
    return entries


class Raw(unittest.TestCase):

    def test_committed_checksums(self):
        entries = read_sha_file(BASE / 'committed_79247d8.sha256')
        self.assertEqual(len(entries), 24)
        for digest, name in entries:
            with self.subTest(file=name):
                self.assertEqual(sha256_file(REPO / name), digest)

    def test_old_baseline_subset(self):
        allf = dict((n, d) for d, n in
                    read_sha_file(BASE / 'committed_79247d8.sha256'))
        old = read_sha_file(BASE / 'old_baseline.sha256')
        self.assertEqual(sorted(n for _, n in old), sorted(OLD_ARTIFACTS))
        for digest, name in old:
            self.assertEqual(allf[name], digest)

    def test_eol_table(self):
        with open(BASE / 'committed_79247d8_eol.tsv', newline='') as f:
            rows = list(csv.DictReader(f, delimiter='\t'))
        self.assertEqual(len(rows), 24)
        for row in rows:
            with self.subTest(file=row['path']):
                data = (REPO / row['path']).read_bytes()
                self.assertEqual(len(data), int(row['bytes']))
                self.assertEqual(data.count(b'\n'), int(row['lf']))
                self.assertEqual(data.count(b'\r'), int(row['cr']))
                self.assertEqual(data.count(b'\r\n'), int(row['crlf']))
        eol = {r['path']: (int(r['lf']), int(r['crlf'])) for r in rows}
        # plan F19: three step-1 outputs are CRLF, the step-2 outputs LF
        for name in ('processed_data/dataCC.csv',
                     'processed_data/shoe_pixel_counts.csv',
                     'data/all_cont.csv'):
            self.assertEqual(eol[name][0], eol[name][1], name)
        for name in ('processed_data/dataCC_distance.csv',
                     'processed_data/dataCC_distance_temp.csv'):
            self.assertEqual(eol[name][1], 0, name)

    def test_fixed_stride_layout(self):
        for name, width, height, n in STRIDE_FILES:
            with self.subTest(file=name):
                data = np.fromfile(REPO / name, dtype=np.uint8)
                stride = width * height + 2
                self.assertEqual(data.size, n * stride)
                rec = data.reshape(n, stride)
                self.assertTrue(np.all(rec[:, -2] == 13))
                self.assertTrue(np.all(rec[:, -1] == 10))
                body = rec[:, :-2]
                self.assertTrue(np.all((body == 48) | (body == 49)))

    def test_location_counts(self):
        with open(REPO / 'data/locations_data.csv', newline='') as f:
            old = list(csv.DictReader(f))
        old_shoes = sorted({int(r['shoe']) for r in old})
        self.assertEqual(len(old), 13287)
        self.assertEqual(len(old_shoes), 386)
        self.assertEqual(sorted(set(range(1, 388)) - set(old_shoes)), [127])

        raw = [line.split() for line in
               (REPO / 'data/new_shoes/locations_data_new_raw.txt')
               .read_text().splitlines()]
        self.assertEqual(len(raw), 20013)
        self.assertTrue(all(len(r) == 5 for r in raw))
        new_shoes = sorted({int(r[0]) for r in raw})
        self.assertEqual(new_shoes, list(range(1, 632)))
        with open(REPO / 'data/new_shoes/locations_new_snake_2023.csv',
                  newline='') as f:
            y2023 = list(csv.DictReader(f))
        self.assertEqual(len(y2023), 20013)
        raw_xy = np.array([[float(r[2]), float(r[3])] for r in raw]) / 2
        xy23 = np.array([[float(r['x']), float(r['y'])] for r in y2023])
        self.assertTrue(np.array_equal(raw_xy, xy23))
        self.assertEqual([int(r[0]) for r in raw],
                         [int(r['shoe']) for r in y2023])


if __name__ == '__main__':
    unittest.main()
