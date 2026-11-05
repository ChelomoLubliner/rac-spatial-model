"""tests/lib/scratch.sh guards (plan section 4.5, decision A-034)."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LIB = REPO / 'tests' / 'lib' / 'scratch.sh'


def run_bash(script, scratch):
    env = dict(os.environ)
    env.pop('RAC_SCRATCH', None)
    if scratch is not None:
        env['RAC_SCRATCH'] = str(scratch)
    return subprocess.run(
        ['bash', '-c', f'set -euo pipefail; source "{LIB}"; {script}'],
        env=env, capture_output=True, text=True, timeout=60)


class Guards(unittest.TestCase):

    def test_unset_or_empty_is_refused(self):
        for value in (None, ''):
            with self.subTest(value=value):
                r = run_bash('echo reached', value)
                self.assertNotEqual(r.returncode, 0)
                self.assertNotIn('reached', r.stdout)
                self.assertIn('RAC_SCRATCH', r.stderr)

    def test_dangerous_roots_are_refused(self):
        bad = ['/', os.path.expanduser('~'), REPO, REPO / 'tests',
               REPO.parent, '/nonexistent_rac_scratch_dir']
        for value in bad:
            with self.subTest(value=str(value)):
                r = run_bash('echo reached', value)
                self.assertNotEqual(r.returncode, 0)
                self.assertNotIn('reached', r.stdout)

    def test_new_and_remove(self):
        with tempfile.TemporaryDirectory() as tmp:
            r = run_bash('d=$(rac_scratch_new probe); echo "$d"; '
                         'test -d "$d"; rac_scratch_remove "$d"; '
                         'test ! -e "$d"; echo removed', tmp)
            self.assertEqual(r.returncode, 0, r.stderr)
            made = Path(r.stdout.splitlines()[0])
            self.assertEqual(made.parent, Path(tmp).resolve())
            self.assertTrue(made.name.startswith('probe_'))
            self.assertIn('removed', r.stdout)

    def test_two_runs_do_not_collide(self):
        with tempfile.TemporaryDirectory() as tmp:
            r = run_bash('a=$(rac_scratch_new x); b=$(rac_scratch_new x); '
                         '[[ "$a" != "$b" ]] && echo distinct', tmp)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn('distinct', r.stdout)

    def test_remove_refuses_outside_paths(self):
        with tempfile.TemporaryDirectory() as tmp, \
                tempfile.TemporaryDirectory() as other:
            for target in ('', other, f'{tmp}', f'{tmp}/../x'):
                with self.subTest(target=target):
                    r = run_bash(f'rac_scratch_remove "{target}"', tmp)
                    self.assertNotEqual(r.returncode, 0)
            self.assertTrue(Path(other).is_dir())
            self.assertTrue(Path(tmp).is_dir())

    def test_bad_run_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            r = run_bash('rac_scratch_new "../escape"', tmp)
            self.assertNotEqual(r.returncode, 0)
            self.assertEqual(list(Path(tmp).iterdir()), [])


if __name__ == '__main__':
    unittest.main()
