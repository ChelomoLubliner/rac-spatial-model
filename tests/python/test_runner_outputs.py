"""The runners fail when a step does not write its outputs (decision A-067).

T1 review 2, reproducibility finding 1: run_legacy_r.sh extracts every
committed output into its copy, so a step that wrote nothing left the
committed file in place and nothing noticed. The runners now delete the
outputs of the steps they run and fail if one is missing or not newer than
the start afterwards. These tests run the real runner scripts with a stub
in place of R (no model is fitted), in temporary scratch folders:
  - run_legacy_r.sh, step 4: a stub that writes nothing -> exit 1, both
    PDFs listed as missing; a stub that writes them -> exit 0;
  - run_windows_r_step3.sh: a stub that writes no model, or copies the
    committed GLMM with its old mtime (cp -p) -> exit 1; a stub that writes
    a fresh copy -> exit 0, 27 of 27 fields equal the Tier A reference,
    which comes from the 79247d8 blob (sha256 ae670fd3...).
"""

import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TIER_A_GLMM = ('ae670fd392cef406b4170aa2a1480fe4b5e9c6cc1969ef0e5df21aa7bc'
               'd9fb57')

R_STUB = r"""#!/usr/bin/env bash
# Stub Rscript for run_legacy_r.sh (test_runner_outputs.py).
if [[ "${1:-}" == *step5_without_car.R ]]; then cp "$2" "$3"; exit 0; fi
if [[ "${1:-}" == -e && "$2" == *rmarkdown::render* ]]; then
  if [[ "$STUB_MODE" == write && "$2" == *shoe_std_results_4.Rmd* ]]; then
    feature=$(sed -n 's/^MODEL_FEATURE <- "\([A-Z_]*\)"/\1/p' config.R)
    echo stub > "../model_images/${feature}_SHOE.pdf"
  fi
  exit 0
fi
exit 0
"""

WIN_STUB = r"""#!/usr/bin/env bash
# Stub for the Windows Rscript of run_windows_r_step3.sh: $1 is the
# Windows path of step3_win.R, in the run folder.
run=$(dirname "$(wslpath -u "$1")")
fit="$run/repo/saved_models/NEW_X_NS_XY.rds"
case "$STUB_MODE" in
  none) ;;
  stale) cp -p "$STUB_GLMM" "$fit" ;;
  fresh) cp "$STUB_GLMM" "$fit" ;;
esac
exit 0
"""


def make_stub(folder, name, text):
    path = Path(folder) / name
    path.write_text(text)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path


def run_script(script, scratch, env_extra, *args):
    env = dict(os.environ, RAC_SCRATCH=str(scratch), **env_extra)
    r = subprocess.run(['bash', str(REPO / script), *args], env=env,
                       capture_output=True, text=True, timeout=300)
    run = Path(r.stdout.splitlines()[0]) if r.stdout else None
    return r, run


class LegacyR(unittest.TestCase):

    def run_step4(self, mode):
        with tempfile.TemporaryDirectory() as scratch, \
                tempfile.TemporaryDirectory() as bin_dir:
            make_stub(bin_dir, 'Rscript', R_STUB)
            path = f'{bin_dir}:{os.environ["PATH"]}'
            r, run = run_script('tests/legacy/run_legacy_r.sh', scratch,
                                {'PATH': path, 'STUB_MODE': mode}, '4')
            out = {name: (run / name).read_text() for name in (
                'exit_status', 'outputs_expected.txt',
                'outputs_regenerated.sha256', 'outputs_missing.txt',
                'timings.tsv')}
            committed_pdf = (run / 'repo/model_images/CI_cut_110.pdf'
                             ).is_file()
            return r, out, committed_pdf

    def test_a_step_that_writes_nothing_fails_the_run(self):
        r, out, committed_pdf = self.run_step4('none')
        pdfs = ('repo/model_images/NEW_X_NS_XY_SHOE.pdf\n'
                'repo/model_images/CML_MODEL_SHOE.pdf\n')
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertEqual(out['exit_status'], '1\n')
        self.assertEqual(out['outputs_expected.txt'], pdfs)
        self.assertEqual(out['outputs_missing.txt'], pdfs)
        self.assertEqual(out['outputs_regenerated.sha256'], '')
        # the knits themselves "succeeded": only the output check fails
        self.assertIn('step4_glmm\t', out['timings.tsv'])
        self.assertNotIn('\t1\n', out['timings.tsv'])
        self.assertTrue(committed_pdf)   # outputs of other steps stay

    def test_a_step_that_writes_its_outputs_passes(self):
        r, out, _ = self.run_step4('write')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(out['exit_status'], '0\n')
        self.assertEqual(out['outputs_missing.txt'], '')
        self.assertEqual(len(out['outputs_regenerated.sha256'].splitlines()),
                         2)


@unittest.skipUnless(shutil.which('wslpath'), 'needs WSL (wslpath)')
class WindowsStep3(unittest.TestCase):

    def run_runner(self, mode):
        with tempfile.TemporaryDirectory() as scratch, \
                tempfile.TemporaryDirectory() as bin_dir:
            stub = make_stub(bin_dir, 'Rscript.exe', WIN_STUB)
            env = {'RAC_WIN_RSCRIPT': str(stub), 'STUB_MODE': mode,
                   'STUB_GLMM': str(REPO / 'saved_models/NEW_X_NS_XY.rds')}
            r, run = run_script('tests/legacy/run_windows_r_step3.sh',
                                scratch, env)
            texts = {name: (run / name).read_text() for name in (
                'exit_status', 'compare.txt', 'outputs_missing.txt')}
            return r, texts

    def test_no_model_or_a_stale_model_fails(self):
        for mode in ('none', 'stale'):
            with self.subTest(stub=mode):
                r, texts = self.run_runner(mode)
                self.assertEqual(r.returncode, 1, r.stderr)
                self.assertEqual(texts['exit_status'], '1\n')
                self.assertEqual(texts['outputs_missing.txt'],
                                 'repo/saved_models/NEW_X_NS_XY.rds\n')
                self.assertIn('no model written by this knit',
                              texts['compare.txt'])

    def test_a_fresh_model_is_compared_with_the_tier_a_blob(self):
        r, texts = self.run_runner('fresh')
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = texts['compare.txt'].splitlines()
        self.assertEqual(lines[0], 'reference 79247d8:saved_models/'
                         f'NEW_X_NS_XY.rds sha256 {TIER_A_GLMM} (Tier A)')
        self.assertIn('RESULT 27 of 27 fields the same', lines)


if __name__ == '__main__':
    unittest.main()
