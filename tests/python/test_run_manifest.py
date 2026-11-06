"""tests/lib/run_outputs.sh and tests/lib/run_manifest.py (decision A-067).

T1 review 2, reproducibility finding 1: a run folder that holds the
committed files at the committed paths passed the live checks although no
step had run. The runners now delete the outputs of every step they run,
list them (outputs_expected.txt) and hash the regenerated ones
(outputs_regenerated.sha256); the live checks accept only listed files.
Writes only to temporary folders.
"""

import hashlib
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from tests.lib import run_manifest
from tests.lib.run_manifest import ManifestError, check_run_manifest

REPO = Path(__file__).resolve().parents[2]
LIB = REPO / 'tests' / 'lib' / 'run_outputs.sh'
OUTS = ['repo/data/a.csv', 'repo/models/m.rds']


def bash(script, *args):
    return subprocess.run(
        ['bash', '-c', f'set -euo pipefail; source "{LIB}"; {script}',
         'bash', *[str(a) for a in args]],
        capture_output=True, text=True, timeout=60)


def committed_copy(run):
    """A run folder that holds 'committed' files at the output paths."""
    for p in OUTS + ['repo/data/input.csv']:
        f = run / p
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(f'committed {p}\n')
        os.utime(f, (1_600_000_000, 1_600_000_000))


def finished_run(run, write=OUTS, exit_code=0, steps=('step1', 'step2')):
    """Begin, 'run' the steps (write the outputs), end: like a runner."""
    committed_copy(run)
    r = bash('rac_outputs_begin "$1" "${@:2}"', run, *OUTS)
    assert r.returncode == 0, r.stderr
    for p in write:
        (run / p).write_text(f'regenerated {p}\n')
    r = bash('rac_outputs_end "$1"', run)
    rows = ''.join(f'{s}\t1.5\t{exit_code}\n' for s in steps)
    (run / 'timings.tsv').write_text('step\tseconds\texit\n' + rows)
    status = exit_code if r.returncode == 0 else 1
    (run / 'exit_status').write_text(f'{status}\n')
    return r


class RunOutputsShell(unittest.TestCase):

    def test_begin_deletes_and_lists(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            committed_copy(run)
            r = bash('rac_outputs_begin "$1" "${@:2}"', run, *OUTS)
            self.assertEqual(r.returncode, 0, r.stderr)
            for p in OUTS:
                self.assertFalse((run / p).exists())
            self.assertTrue((run / 'repo/data/input.csv').is_file())
            self.assertEqual((run / 'outputs_expected.txt').read_text(),
                             ''.join(f'{p}\n' for p in OUTS))
            again = bash('rac_outputs_begin "$1" "${@:2}"', run, *OUTS)
            self.assertEqual(again.returncode, 2)

    def test_begin_refuses_bad_paths_before_deleting(self):
        bad = ['', '/abs/x', '../x', 'a/../b', 'a/./b', './a', 'a//b', 'a/',
               'repo/data']
        for p in bad:
            with self.subTest(path=p), tempfile.TemporaryDirectory() as tmp:
                run = Path(tmp)
                committed_copy(run)
                r = bash('rac_outputs_begin "$1" "${@:2}"', run, OUTS[0], p)
                self.assertEqual(r.returncode, 2, r.stderr)
                self.assertTrue((run / OUTS[0]).is_file())
                self.assertFalse((run / 'outputs_expected.txt').exists())
        with tempfile.TemporaryDirectory() as tmp:
            for args in ([tmp], [Path(tmp) / 'missing', OUTS[0]]):
                with self.subTest(args=args):
                    r = bash('rac_outputs_begin "$@"', *args)
                    self.assertEqual(r.returncode, 2)
                    self.assertIn('usage', r.stderr)

    def test_end_hashes_regenerated_and_lists_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            r = finished_run(run, write=OUTS[:1])
            self.assertEqual(r.returncode, 1)
            self.assertIn('repo/models/m.rds', r.stderr)
            data = (run / OUTS[0]).read_bytes()
            self.assertEqual(
                (run / 'outputs_regenerated.sha256').read_text(),
                f'{hashlib.sha256(data).hexdigest()}  {OUTS[0]}\n')
            self.assertEqual((run / 'outputs_missing.txt').read_text(),
                             f'{OUTS[1]}\n')

    def test_end_rejects_a_restored_old_file_and_a_symlink(self):
        with tempfile.TemporaryDirectory() as tmp, \
                tempfile.TemporaryDirectory() as keep:
            run = Path(tmp)
            committed_copy(run)
            old = Path(keep) / 'old.csv'
            old.write_text('committed\n')
            os.utime(old, (1_600_000_000, 1_600_000_000))
            bash('rac_outputs_begin "$1" "${@:2}"', run, *OUTS)
            # cp -p keeps the old mtime: a step that copies the committed
            # file into place does not count as having written it.
            subprocess.run(['cp', '-p', str(old), str(run / OUTS[0])],
                           check=True)
            os.symlink(old, run / OUTS[1])
            r = bash('rac_outputs_end "$1"', run)
            self.assertEqual(r.returncode, 1)
            self.assertEqual((run / 'outputs_regenerated.sha256').read_text(),
                             '')
            self.assertEqual((run / 'outputs_missing.txt').read_text(),
                             ''.join(f'{p}\n' for p in OUTS))


class CheckRunManifest(unittest.TestCase):

    def assert_refused(self, run, message, files=OUTS, steps=('step1',)):
        with self.assertRaises(ManifestError) as cm:
            check_run_manifest(run, files, steps)
        self.assertIn(message, str(cm.exception))

    def test_a_finished_run_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            self.assertEqual(finished_run(run).returncode, 0)
            self.assertEqual(check_run_manifest(run, OUTS, ['step2']), OUTS)

    def test_a_copy_of_the_committed_tree_is_refused(self):
        # The shape of the reviewer's <scratch>/rv2_t1/fake_stale_zv7m57:
        # committed files at the output paths and nothing else.
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            committed_copy(run)
            self.assert_refused(run, 'no exit_status')
            (run / 'exit_status').write_text('0\n')
            self.assert_refused(run, 'no timings.tsv')
            (run / 'timings.tsv').write_text('step\tseconds\texit\n'
                                             'step1\t1\t0\n')
            self.assert_refused(run, 'no outputs_expected.txt')

    def test_failed_or_missing_steps_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            finished_run(run, exit_code=1)
            self.assert_refused(run, "exit_status is ['1'], not 0")
            (run / 'exit_status').write_text('0\n')
            self.assert_refused(run, 'steps with a non-zero exit: step1, '
                                'step2')
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            finished_run(run, steps=('step2',))
            self.assert_refused(run, 'steps not run: step1')

    def test_missing_unlisted_changed_or_old_outputs_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            finished_run(run, write=OUTS[:1])
            (run / 'exit_status').write_text('0\n')
            self.assert_refused(run, 'outputs missing after the run: '
                                'repo/models/m.rds')
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            finished_run(run)
            self.assert_refused(run, 'not regenerated by this run: '
                                'repo/data/input.csv',
                                files=['repo/data/input.csv'])
            (run / OUTS[1]).write_text('replaced after the run\n')
            self.assert_refused(run, 'changed after the run: '
                                'repo/models/m.rds')
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            finished_run(run)
            os.utime(run / OUTS[0], (1_600_000_000, 1_600_000_000))
            self.assert_refused(run, 'not newer than the start of the run: '
                                'repo/data/a.csv')

    def test_module_is_the_one_documented(self):
        self.assertIn('A-067', run_manifest.__doc__)


if __name__ == '__main__':
    unittest.main()
