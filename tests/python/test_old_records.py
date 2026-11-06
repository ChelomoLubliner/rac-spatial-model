"""tests/lib/old_records.py: the one OLD record reader of tests/ (nit 1).

Reads the committed OLD files (read-only); writes nothing.
"""

import hashlib
import unittest
from pathlib import Path

import numpy as np

from tests.lib import old_records as orc

REPO = Path(__file__).resolve().parents[2]


class Reader(unittest.TestCase):

    def test_committed_files(self):
        shoes = orc.read_records(REPO / 'data/contacts_data.txt',
                                 sep=b'\r\n')
        contour = orc.read_records(REPO / 'data/contour_Active_Contour.txt',
                                   sep=b'\r\n')
        self.assertEqual(shoes.shape, (387, 395, 307))
        self.assertEqual(contour.shape, (386, 395, 307))
        self.assertEqual(shoes.dtype, np.bool_)
        # pinned from the T1 baseline (compare_legacy_python.py output)
        px = contour.reshape(386, -1).sum(axis=1)
        self.assertEqual((int(px.min()), int(np.median(px)), int(px.max())),
                         (614, 700, 742))

    def test_lf_and_crlf_give_the_same_records(self):
        crlf = (REPO / 'data/contour_Active_Contour.txt').read_bytes()
        lf = crlf.replace(b'\r\n', b'\n')
        a, sep_a = orc.parse_records(crlf)
        b, sep_b = orc.parse_records(lf)
        self.assertEqual((sep_a, sep_b), (b'\r\n', b'\n'))
        self.assertTrue(np.array_equal(a, b))
        self.assertEqual(hashlib.sha256(lf.replace(b'\n', b'\r\n'))
                         .hexdigest(), hashlib.sha256(crlf).hexdigest())

    def test_bad_layouts_are_refused(self):
        rec = b'01' * 3
        cases = {
            'empty': b'',
            'short record': rec + b'\r\n' + rec[:-1] + b'\r\n',
            'mixed separators': rec + b'\r\n' + rec + b'\n',
            'not 0/1': b'012' + rec[3:] + b'\r\n',
        }
        for label, data in cases.items():
            with self.subTest(case=label):
                with self.assertRaises(ValueError):
                    orc.parse_records(data, width=3, height=2)
        a, sep = orc.parse_records(rec + b'\r\n' + rec + b'\r\n', 3, 2)
        self.assertEqual((a.shape, sep), ((2, 2, 3), b'\r\n'))
        self.assertEqual(a[0].astype(int).tolist(), [[0, 1, 0], [1, 0, 1]])

    def test_expected_separator(self):
        two = (REPO / 'data/contacts_data.txt').read_bytes()[:2 * orc.W
                                                             * orc.H + 4]
        self.assertEqual(orc.parse_records(two)[0].shape, (2, 395, 307))
        with self.assertRaises(ValueError):    # a trailing partial record
            orc.parse_records(two + b'0')
        path = REPO / 'data/contour_Active_Contour.txt'
        with self.assertRaises(ValueError):    # committed files are CRLF
            orc.read_records(path, sep=b'\n')


class Mapping(unittest.TestCase):

    def test_record_shoe_mapping(self):
        self.assertEqual(orc.shoe_of_record(0), 1)
        self.assertEqual(orc.shoe_of_record(125), 126)
        self.assertEqual(orc.shoe_of_record(126), 128)
        self.assertEqual(orc.shoe_of_record(385), 387)
        for k in range(386):
            s = orc.shoe_of_record(k)
            self.assertEqual(orc.record_of_shoe(s), k)
            self.assertEqual(orc.record_of_idx0(s - 1), k)
        shoes = [orc.shoe_of_record(k) for k in range(386)]
        self.assertEqual(sorted(set(range(1, 388)) - set(shoes)), [127])

    def test_out_of_range(self):
        for bad in (lambda: orc.record_of_shoe(127),
                    lambda: orc.record_of_idx0(126),
                    lambda: orc.record_of_idx0(387),
                    lambda: orc.record_of_idx0(-1),
                    lambda: orc.shoe_of_record(386),
                    lambda: orc.shoe_of_record(-1)):
            with self.assertRaises(ValueError):
                bad()


if __name__ == '__main__':
    unittest.main()
