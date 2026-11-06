"""No dataset literal in the Python and shell code (plan T2 step 1;
decisions A-035, A-072). tests/r/test_no_hardcoding.R covers R and Rmd.

Scans contour_algorithm/, tools/ and tests/ (rules and comment handling:
tests/lib/hardcoding_scan.py; the profile files are not scanned). The
pipeline code must hold no dataset number, profile constant, legacy
relative path or literal output path. Under tests/, every file is scanned
except the OLD-only files below, which state legacy values on purpose,
each with its reason; a new file under tests/ is scanned unless it is
added here with a reason, so NEW tooling cannot slip in a literal (A-072).
An entry whose file no longer has a finding must be removed (the test
fails), so the list stays tight.
"""

import unittest

from tests.lib import hardcoding_scan as scan

ALLOWLIST = {
    'tests/lib/old_records.py':
        'the one OLD frame, record reader and record mapping of the test '
        'helpers (A-072)',
    'tests/lib/hardcoding_scan.py':
        'holds the scanned patterns themselves',
    'tests/python/test_no_hardcoding.py':
        'its self-test feeds the patterns to the scanner',
    'tests/python/test_baseline_raw_data.py':
        'T1 baseline: states the dimensions and counts of both raw files',
    'tests/python/test_old_records.py':
        'T1 baseline: states the OLD frame and record counts',
    'tests/python/test_snake_old_regression.py':
        'OLD shoes chosen by 0-based image index (386 = shoe 387)',
    'tests/python/test_profiles.py':
        'states the legacy OLD constants and paths that the profile must '
        'give (T2)',
    'tests/python/test_io_shoes.py':
        'states the shape of the thesis snakes and the OLD skip list (T2)',
    'tests/python/test_locations.py':
        'states the OLD and NEW RAC counts and skip lists (T2)',
    'tests/python/test_snake_geometry.py':
        'pixel positions (row 300) and the 8-bit value 255, not dimensions',
    'tests/python/test_runner_outputs.py':
        '300 is a subprocess timeout in seconds (T1)',
    'tests/legacy/old_snake_gallery.py':
        'OLD-only diagnostic; 255 is an 8-bit colour value (A-072)',
    'tests/legacy/old_snake_metrics.py':
        'OLD-only diagnostic of the committed OLD contours (A-072)',
    'tests/legacy/plot_contour_platform_diff.py':
        'OLD-only diagnostic; 255 is an 8-bit colour value (A-072)',
}


class NoHardcoding(unittest.TestCase):

    def test_python_and_shell(self):
        files = scan.code_files(('.py', '.sh'))
        self.assertTrue(any(f.startswith('contour_algorithm/')
                            for f in files))
        self.assertIn('tools/run_pipeline.sh', files)
        bad = []
        for f in files:
            if f in ALLOWLIST:
                continue
            bad += [f'{f}:{line}: {kind}: {text[:80]}'
                    for line, kind, text in scan.findings(f)]
        self.assertEqual(bad, [], '\n' + '\n'.join(bad))

    def test_allowlist_is_needed(self):
        files = set(scan.code_files(('.py', '.sh')))
        for f in ALLOWLIST:
            with self.subTest(file=f):
                self.assertIn(f, files)
                self.assertTrue(scan.findings(f),
                                f'{f} has no finding: remove its entry')

    def test_scanner_catches(self):
        """The rules catch each kind of literal, and skip comments,
        docstrings and the exemption marker."""
        py = '\n'.join([
            '"""Docstring with 307 and 387."""',
            'W = 307',
            'n = len(x)  # 387 shoes in a comment',
            "f = open('../data/contacts_data.txt')",
            "out = 'processed_data/new/dataCC_new.csv'",
            'grey = 255  # rac: literal-ok (a colour)',
            'y = 200 + 162 * s',
            'v = 0.126 + x307 + 3870',
        ])
        found = scan.python_code_lines(py)
        self.assertEqual(sorted(found), [2, 3, 4, 5, 7, 8])
        kinds = {}
        for i, code in found.items():
            kinds[i] = (bool(scan.DATASET_NUMBERS.search(code)),
                        bool(scan.PARENT_PATHS.search(code)))
        self.assertEqual(kinds[2], (True, False))
        self.assertEqual(kinds[3], (False, False))
        self.assertEqual(kinds[4], (False, True))
        self.assertEqual(kinds[8], (False, False))
        self.assertTrue(scan.OUTPUT_PATHS.search(found[5]))
        self.assertTrue(any(rx.search(found[7])
                            for _, rx in scan.CONSTANTS))
        sh = 'n=${#a[@]}  # 631 shoes\necho "$x" # 255\ncount=631\n'
        self.assertEqual(scan.hash_code_lines(sh, shell=True),
                         {1: 'n=${#a[@]}  ', 2: 'echo "$x" ',
                          3: 'count=631'})


if __name__ == '__main__':
    unittest.main()
