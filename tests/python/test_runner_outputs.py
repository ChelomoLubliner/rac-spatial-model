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
    which comes from the 79247d8 blob (sha256 ae670fd3...); a stub whose
    knit .md has a knitr error line, or that writes no .md, -> exit 1 even
    with a fresh model (decision A-084: knitr::knit's default error = TRUE
    had turned chunk errors into text, T2 review);
  - run_windows_r_steps.sh (steps 1, 2, 5 under the Windows R): a bad
    --steps is refused before a run folder exists; a stub that writes no
    output -> exit 1; a stub that writes the committed step-5 outputs ->
    every comparison passes (wald_test.csv = old_added_t2.sha256);
  - tests/lib/win_r.sh with the real Windows R (skipped without it): a
    chunk that calls stop() fails the knit and the next chunk does not run.
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
# Windows path of step3_win.R, in the run folder; a real knit writes
# step3_win.md next to it.
run=$(dirname "$(wslpath -u "$1")")
fit="$run/repo/saved_models/NEW_X_NS_XY.rds"
md="$run/step3_win.md"
case "$STUB_MODE" in
  none) echo knit > "$md" ;;
  stale) cp -p "$STUB_GLMM" "$fit"; echo knit > "$md" ;;
  fresh) cp "$STUB_GLMM" "$fit"; echo knit > "$md" ;;
  error) cp "$STUB_GLMM" "$fit"; printf 'x\n## Error: boom\n' > "$md" ;;
  nomd) cp "$STUB_GLMM" "$fit" ;;
esac
exit 0
"""

STEPS_STUB = r"""#!/usr/bin/env bash
# Stub for the Windows Rscript of run_windows_r_steps.sh: $1 is the
# Windows path of step<N>_win.R; mode copy writes the committed outputs of
# step 5 into the copy, as a knit would.
driver=$(wslpath -u "$1")
run=$(dirname "$driver")
echo knit > "${driver%.R}.md"
if [[ "$STUB_MODE" == copy && "$driver" == */step5_win.R ]]; then
  for f in processed_data/wald_test.csv model_images/CI_shoe_cuts.pdf \
    model_images/CI_cut_110.pdf model_images/CI_cut_190.pdf \
    model_images/CI_cut_250.pdf; do
    cp "$STUB_REPO/$f" "$run/repo/$f"
  done
fi
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
                self.assertIn('no comparison: knit exit 0, model written '
                              'by this knit: no', texts['compare.txt'])

    def test_a_knit_error_line_or_no_md_fails(self):
        """A-084: with a fresh model, a knitr error line in the .md or a
        missing .md still fails the gate."""
        for mode in ('error', 'nomd'):
            with self.subTest(stub=mode):
                r, texts = self.run_runner(mode)
                self.assertEqual(r.returncode, 1, r.stderr)
                self.assertEqual(texts['exit_status'], '1\n')
                self.assertEqual(texts['outputs_missing.txt'], '')
                self.assertIn('no comparison: knit exit 1, model written '
                              'by this knit: yes', texts['compare.txt'])

    def test_a_fresh_model_is_compared_with_the_tier_a_blob(self):
        r, texts = self.run_runner('fresh')
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = texts['compare.txt'].splitlines()
        self.assertEqual(lines[0], 'reference 79247d8:saved_models/'
                         f'NEW_X_NS_XY.rds sha256 {TIER_A_GLMM} (Tier A)')
        self.assertIn('RESULT 27 of 27 fields the same', lines)


@unittest.skipUnless(shutil.which('wslpath'), 'needs WSL (wslpath)')
class WindowsSteps(unittest.TestCase):
    """tests/legacy/run_windows_r_steps.sh with a stub Windows Rscript."""

    def run_runner(self, mode, steps='5'):
        with tempfile.TemporaryDirectory() as scratch, \
                tempfile.TemporaryDirectory() as bin_dir:
            stub = make_stub(bin_dir, 'Rscript.exe', STEPS_STUB)
            env = {'RAC_WIN_RSCRIPT': str(stub), 'STUB_MODE': mode,
                   'STUB_REPO': str(REPO)}
            r, run = run_script('tests/legacy/run_windows_r_steps.sh',
                                scratch, env, '--steps', steps)
            texts = {}
            if run is not None and run.is_dir():
                texts = {name: (run / name).read_text() for name in (
                    'exit_status', 'compare.tsv', 'outputs_missing.txt')}
            return r, texts, sorted(Path(scratch).iterdir())

    def test_bad_steps_are_refused_first(self):
        for steps in ('3', '1-2', '1,4', ''):
            with self.subTest(steps=steps):
                r, texts, made = self.run_runner('copy', steps)
                self.assertEqual(r.returncode, 2, r.stderr)
                self.assertEqual(made, [])

    def test_no_outputs_fails(self):
        r, texts, _ = self.run_runner('none')
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertEqual(texts['exit_status'], '1\n')
        self.assertIn('repo/processed_data/wald_test.csv',
                      texts['outputs_missing.txt'])
        self.assertIn('FAIL\tstep 5 wald_test.csv = old_added_t2',
                      texts['compare.tsv'])

    def test_the_committed_step5_outputs_pass(self):
        r, texts, _ = self.run_runner('copy')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(texts['exit_status'], '0\n')
        self.assertIn('PASS\tstep 5 wald_test.csv = old_added_t2',
                      texts['compare.tsv'])
        self.assertIn('INFO\tCI_cut_110.pdf\tequal to the committed PDF',
                      texts['compare.tsv'])


WIN_RSCRIPT = Path('/mnt/c/Users/mehes/AppData/Local/Programs/R/R-4.4.3/'
                   'bin/Rscript.exe')


@unittest.skipUnless(shutil.which('wslpath') and WIN_RSCRIPT.is_file(),
                     'needs WSL and the Windows R 4.4.3')
class WindowsKnit(unittest.TestCase):
    """rac_win_knit (tests/lib/win_r.sh) with the real Windows R: a chunk
    error fails the knit and stops it (A-084)."""

    def knit(self, folder, name, chunks):
        wd = Path(folder) / 'wd'
        wd.mkdir(exist_ok=True)
        (wd / f'{name}.Rmd').write_text(''.join(
            f'```{{r}}\n{c}\n```\n\n' for c in chunks))
        script = ('set -euo pipefail; source "$1"; st=0; '
                  'rac_win_knit "$2" "$3" "$2/wd" "$3.Rmd" RAC_DATASET=old '
                  '|| st=$?; echo "status $st"')
        r = subprocess.run(['bash', '-c', script, 'knit',
                            str(REPO / 'tests/lib/win_r.sh'), str(folder),
                            name], capture_output=True, text=True,
                           timeout=300, env=dict(os.environ,
                                                 RAC_WIN_RSCRIPT=str(
                                                     WIN_RSCRIPT)))
        return r.stdout.strip(), wd

    def test_a_chunk_error_fails_and_stops_the_knit(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, wd = self.knit(tmp, 'fail', [
                'stop("boom from a chunk")',
                'writeLines("after", "after_stop.txt")'])
            self.assertEqual(out, 'status 1')
            self.assertFalse((wd / 'after_stop.txt').exists())
            out, wd = self.knit(tmp, 'ok', [
                'writeLines(Sys.getenv("RAC_DATASET"), "ok.txt")'])
            self.assertEqual(out, 'status 0')
            self.assertEqual((wd / 'ok.txt').read_text().strip(), 'old')


if __name__ == '__main__':
    unittest.main()
