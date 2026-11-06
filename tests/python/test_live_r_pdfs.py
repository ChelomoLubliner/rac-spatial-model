"""Normalized PDFs of a live OLD R rerun equal Tier B (plan 4.5, A-067).

Optional, like the live check of tests/r/test_old_regression.R, and read
from the same variable: RAC_REGRESS_R_RUN=<run folder of
tests/legacy/run_legacy_r.sh or tests/regress_old.sh>. The folder must
prove that steps 4-6 ran and wrote the 8 PDFs (exit_status 0, exit 0 in
timings.tsv, every PDF on outputs_regenerated.sha256; T1 review 2,
reproducibility finding 1); then each PDF, with its /CreationDate and
/ModDate values removed (tests/lib/pdf_normalize.py), must have the Tier B
hash of tests/baseline/local/pdf_normalized.sha256. Reads only.
"""

import os
import unittest
from pathlib import Path

from tests.lib import pdf_normalize
from tests.lib.run_manifest import check_run_manifest

REPO = Path(__file__).resolve().parents[2]
TIER_B = REPO / 'tests' / 'baseline' / 'local' / 'pdf_normalized.sha256'
STEPS = ('step4_glmm', 'step4_cml', 'step5', 'step6')


def tier_b_pdfs():
    """{path relative to the repo: normalized sha256} of the 8 PDFs."""
    out = {}
    for line in TIER_B.read_text().splitlines():
        out[line[66:]] = line[:64]
    return out


class TierB(unittest.TestCase):

    def test_tier_b_lists_the_8_pdfs(self):
        self.assertEqual(sorted(tier_b_pdfs()), sorted(
            f'model_images/{n}.pdf' for n in (
                'CI_cut_110', 'CI_cut_190', 'CI_cut_250', 'CI_shoe_cuts',
                'CML_MODEL_SHOE', 'NEW_X_NS_XY_SHOE',
                'difference_random_cml', 'pixel_inten_JASAup')))


@unittest.skipUnless(os.environ.get('RAC_REGRESS_R_RUN'),
                     'set RAC_REGRESS_R_RUN to an R run folder')
class LiveRun(unittest.TestCase):

    def test_normalized_pdfs_equal_tier_b(self):
        run = Path(os.environ['RAC_REGRESS_R_RUN'])
        want = tier_b_pdfs()
        check_run_manifest(run, [f'repo/{p}' for p in want], steps=STEPS)
        got = {p: pdf_normalize.normalized_sha256(run / 'repo' / p)
               for p in want}
        self.assertEqual(got, want)


if __name__ == '__main__':
    unittest.main()
