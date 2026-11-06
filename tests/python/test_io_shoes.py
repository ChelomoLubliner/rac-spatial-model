"""Fixed-stride shoe files and the contour-record mapping (plan T2 step 1;
review focus 2 and 4; decisions A-031, A-053).

read_shoes must give the arrays of the legacy text-mode parse
(`open(..., 'r').readlines()`, universal newlines, `line[:-1]`) for both
datasets, and refuse a wrong size, a separator other than CRLF or a byte
other than 0/1. write_shoes must write binary CRLF on every platform: the
thesis snakes of 2025-11-13 written with the OLD skip list give the
committed contour file byte for byte. Contour record k is the k-th
analysis shoe. Reads the repo and the thesis repo only; writes to a
tempfile folder.
"""

import hashlib
import tempfile
import unittest
from pathlib import Path

import numpy as np

from contour_algorithm.io_shoes import read_shoes, write_shoes
from contour_algorithm.profiles import load_profile

REPO = Path(__file__).resolve().parents[2]
PROFILE_FILE = REPO / 'config' / 'datasets.json'
THESIS_NPY = Path('/mnt/c/Users/mehes/Documents/repo/'
                  'master_thesis_forensic_shoeprint/images/saved/'
                  'active-contour_all.npy')


def committed_sha256(path):
    for line in (REPO / 'tests/baseline/committed_79247d8.sha256'
                 ).read_text().splitlines():
        if line[66:] == path:
            return line[:64]
    raise KeyError(path)


def legacy_lines(path):
    """The legacy reader: text mode, universal newlines (create_files_shoes
    at 109f30a)."""
    with open(path, 'r') as f:
        return f.readlines()


def legacy_parse(line, width, height):
    """The legacy expression for one line (slow: about 30 ms a record)."""
    return np.array(list(map(int, line[:-1]))).reshape(height, width)


class ReadShoes(unittest.TestCase):

    def check_dataset(self, dataset, sample_step):
        p = load_profile(dataset, file=PROFILE_FILE)
        got = read_shoes(p.contacts, p.W, p.H, p.num_shoe)
        self.assertEqual(got.shape, (p.num_shoe, p.H, p.W))
        self.assertEqual(got.dtype, bool)
        lines = legacy_lines(p.contacts)
        self.assertEqual(len(lines), p.num_shoe)
        self.assertTrue(all(len(x) == p.W * p.H + 1 for x in lines))
        # every record: the legacy characters, byte for byte
        for i, line in enumerate(lines):
            chars = np.frombuffer(line[:-1].encode('ascii'), dtype=np.uint8)
            if not np.array_equal(chars.reshape(p.H, p.W) == 49, got[i]):
                self.fail(f'{dataset} record {i} differs')
        # a sample: the exact legacy expression (int per character)
        for i in sorted(set(range(0, p.num_shoe, sample_step))
                        | {p.num_shoe - 1}):
            with self.subTest(dataset=dataset, record=i):
                legacy = legacy_parse(lines[i], p.W, p.H)
                self.assertTrue(np.array_equal(legacy == 1, got[i]))
                self.assertTrue(np.all((legacy == 0) | (legacy == 1)))

    def test_matches_legacy_readlines(self):
        self.check_dataset('old', 43)
        self.check_dataset('new', 70)

    def test_rejects_bad_files(self):
        good = b'0110' + b'\r\n' + b'1001' + b'\r\n'
        cases = {'lf': b'0110\n1001\n\n\n',
                 'short': good[:-1],
                 'byte': b'0120\r\n1001\r\n',
                 'separator': b'0110\n\r1001\r\n'}
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / 'shoes.txt'
            f.write_bytes(good)
            self.assertTrue(np.array_equal(
                read_shoes(f, 2, 2, 2),
                np.array([[[0, 1], [1, 0]], [[1, 0], [0, 1]]], dtype=bool)))
            with self.assertRaises(ValueError):
                read_shoes(f, 2, 2, 3)
            for name, data in cases.items():
                f.write_bytes(data)
                with self.subTest(case=name), self.assertRaises(ValueError):
                    read_shoes(f, 2, 2, 2)


class WriteShoes(unittest.TestCase):

    def test_crlf_roundtrip(self):
        rng = np.random.default_rng(5)
        arrays = rng.random((6, 7, 5)) < 0.5
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / 'out.txt'
            n = write_shoes(f, arrays, skip_idx0=[1, 4])
            self.assertEqual(n, 4)
            data = f.read_bytes()
            self.assertEqual(len(data), 4 * (5 * 7 + 2))
            stride = 5 * 7 + 2
            for k in range(4):
                self.assertEqual(data[k * stride + 35:(k + 1) * stride],
                                 b'\r\n')
            self.assertEqual(data.count(b'\n'), 4)
            self.assertEqual(data.count(b'\r'), 4)
            back = read_shoes(f, 5, 7, 4)
            self.assertTrue(np.array_equal(back, arrays[[0, 2, 3, 5]]))
            # 0/1 integer arrays give the same bytes as booleans
            write_shoes(f, arrays.astype(np.int64), skip_idx0=[1, 4])
            self.assertEqual(f.read_bytes(), data)
            with self.assertRaises(ValueError):
                write_shoes(f, [np.full((7, 5), 2)])
            with self.assertRaises(ValueError):
                write_shoes(f, [arrays[0], arrays[0][:, :4]])

    @unittest.skipUnless(THESIS_NPY.is_file(), 'thesis snakes not available')
    def test_old_contour_bytes_from_thesis_npy(self):
        """The thesis run of 2025-11-13 wrote the committed contour (plan
        F8); write_shoes with the OLD skip list gives its exact bytes."""
        snakes = np.load(THESIS_NPY)  # read-only access
        p = load_profile('old', file=PROFILE_FILE)
        self.assertEqual(snakes.shape, (387, 395, 307))
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / 'contour.txt'
            n = write_shoes(f, snakes, skip_idx0=p.skip_idx0())
            self.assertEqual(n, 386)
            self.assertEqual(p.skip_idx0(), (126,))
            got = hashlib.sha256(f.read_bytes()).hexdigest()
        self.assertEqual(got, committed_sha256(
            'data/contour_Active_Contour.txt'))


class RecordMap(unittest.TestCase):

    def test_record_shoe_mapping(self):
        old = load_profile('old', file=PROFILE_FILE)
        for k in range(386):
            want = k + 1 if k < 126 else k + 2
            self.assertEqual(old.shoe_of_record(k), want)
            self.assertEqual(old.record_of_shoe(want), k)
        new = load_profile('new', file=PROFILE_FILE)
        self.assertEqual([new.shoe_of_record(k) for k in range(631)],
                         list(range(1, 632)))
        with self.assertRaises(ValueError):
            new.shoe_of_record(631)

    def test_synthetic_profile(self):
        """num_shoe 6, shoes_without_racs [2], excluded_shoes [5]: analysis
        shoes [1, 3, 4, 6], records 1-4 (A-031)."""
        import dataclasses
        p = dataclasses.replace(load_profile('new', file=PROFILE_FILE),
                                num_shoe=6, shoes_without_racs=(2,),
                                excluded_shoes=(5,))
        self.assertEqual(p.analysis_shoes(), (1, 3, 4, 6))
        self.assertEqual(p.skip_idx0(), (1, 4))
        self.assertEqual([p.shoe_of_record(k) for k in range(4)],
                         [1, 3, 4, 6])
        self.assertEqual([p.record_of_shoe(s) for s in (1, 3, 4, 6)],
                         [0, 1, 2, 3])
        arrays = [np.full((3, 2), i % 2 == 0) for i in range(6)]
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / 'c.txt'
            self.assertEqual(write_shoes(f, arrays, p.skip_idx0()), 4)
            back = read_shoes(f, 2, 3, 4)
        for k, shoe in enumerate(p.analysis_shoes()):
            self.assertTrue(np.array_equal(back[k], arrays[shoe - 1]))


if __name__ == '__main__':
    unittest.main()
