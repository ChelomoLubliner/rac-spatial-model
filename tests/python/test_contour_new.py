"""The committed NEW contour file (plan T4 step 2; decisions A-091 to A-097).

Layout: one record per analysis shoe (every NEW shoe: none skipped or
excluded, A-089), each W x H bytes '0'/'1' followed by CRLF, so the R
readers' stride holds (plan review focus 2); every record a plausible
outline (400 to 1,000 contour pixels, plan T4). Record k is the k-th
analysis shoe: the bounding box of every record equals the one the QA
table stored for that shoe. RAC coverage: the share of each shoe's RAC
pixels inside the row-span fill of its record (what the R distances see)
is at least the OLD p5 minus 0.02 (plan T4), except the accepted
exceptions: the shoes reviewed in docs/qa/T4/new/snake_review_new.csv and
those named below with their reason (every RAC that their contour leaves
out lies off the print). Reads only.
"""

import unittest
from pathlib import Path

import numpy as np
import pandas as pd

from contour_algorithm import qa_snake as q
from contour_algorithm.io_shoes import SEPARATOR, read_shoes
from contour_algorithm.profiles import load_profile

REPO = Path(__file__).resolve().parents[2]
# Shoes whose RAC coverage passes the QA band (A-093, the OLD p1) but not
# the plan's OLD-p5-minus-0.02 test, each looked at (T4 results doc):
ACCEPTED = {
    18: 'one RAC of 38 lies 15 px below the heel, 22 px from any contact',
    113: 'two RACs of 70 lie 2-3 px below the heel, 10 px from contact',
    120: 'one RAC of 49 lies 9 px beside the heel, 12 px from contact',
    286: 'very faint print: one RAC of 40 near a faint fragment 11 px left '
         'of the forefoot outline',
}


class ContourNew(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.p = load_profile('new')
        cls.shoes = cls.p.analysis_shoes()
        cls.records = read_shoes(cls.p.contour_out, cls.p.W, cls.p.H,
                                 len(cls.shoes))
        cls.table = pd.read_csv(cls.p.prep_path('snake_qa'),
                                keep_default_na=False)

    def test_layout(self):
        p = self.p
        self.assertEqual(len(self.shoes), p.num_shoe)
        data = p.contour_out.read_bytes()
        stride = p.W * p.H + len(SEPARATOR)
        self.assertEqual(len(data), len(self.shoes) * stride)
        seps = np.frombuffer(data, np.uint8).reshape(-1, stride)[:, -2:]
        self.assertTrue((seps == np.frombuffer(SEPARATOR, np.uint8)).all())
        n_px = self.records.sum(axis=(1, 2))
        self.assertGreaterEqual(int(n_px.min()), 400)
        self.assertLessEqual(int(n_px.max()), 1000)

    def test_record_is_its_shoe(self):
        t = self.table
        self.assertEqual(t['shoe'].tolist(), list(self.shoes))
        for k, row in enumerate(t.to_dict('records')):
            rec = self.records[k]
            rows = np.flatnonzero(rec.any(axis=1))
            cols = np.flatnonzero(rec.any(axis=0))
            with self.subTest(record=k + 1):
                self.assertEqual(
                    (rows[0], rows[-1], cols[0], cols[-1]),
                    (row['bbox_r0'], row['bbox_r1'], row['bbox_c0'],
                     row['bbox_c1']))
                self.assertEqual(int(rec.sum()), row['n_contour_px'])

    def test_rac_coverage(self):
        old = pd.read_csv(REPO / 'docs/qa/T4/old/snake_metrics.csv',
                          keep_default_na=False)
        threshold = float(np.quantile(old['rac_coverage'], 0.05)) - 0.02
        review = pd.read_csv(q.snake_qa_path(self.p, 'snake_review', 'csv'),
                             keep_default_na=False)
        accepted = set(review['shoe']) | set(ACCEPTED)
        racs = q.rac_pixels(self.p)
        stored = self.table.set_index('shoe')['rac_coverage']
        low = []
        for k, shoe in enumerate(self.shoes):
            rc = racs[shoe]
            fill = q.row_span_fill(self.records[k])
            cov = float(fill[rc[:, 0], rc[:, 1]].mean())
            self.assertAlmostEqual(cov, stored[shoe], places=4)
            if cov < threshold:
                low.append(shoe)
        self.assertEqual(sorted(set(low) - accepted), [])
        # every named exception is still one (the list stays tight)
        self.assertEqual(sorted(set(ACCEPTED) - set(low)), [])


if __name__ == '__main__':
    unittest.main()
