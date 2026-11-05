"""tests/lib/scratch.sh guards (plan section 4.5, decisions A-034, A-062)."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LIB = REPO / 'tests' / 'lib' / 'scratch.sh'


def run_bash(script, scratch, *args):
    """Run script after sourcing scratch.sh; args become $1, $2, ..."""
    env = dict(os.environ)
    env.pop('RAC_SCRATCH', None)
    if scratch is not None:
        env['RAC_SCRATCH'] = str(scratch)
    return subprocess.run(
        ['bash', '-c', f'set -euo pipefail; source "{LIB}"; {script}',
         'bash', *[str(a) for a in args]],
        env=env, capture_output=True, text=True, timeout=60)


def make_tree(root):
    """Folders a real scratchpad holds next to the run folders."""
    keep = root / 'keep_me'
    keep.mkdir()
    (keep / 'file.txt').write_text('keep\n')
    (root / 'venv_copy' / 'bin').mkdir(parents=True)
    (root / 'a' / 'b').mkdir(parents=True)
    (root / 'a' / 'b_abcdef').mkdir()       # mktemp shape, but nested
    (root / 'file_abcdef').write_text('a file, not a folder\n')
    return keep / 'file.txt'


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

    def test_remove_refuses_root_and_non_run_paths(self):
        # T1 review finding 1: "$RAC_SCRATCH/" passed the old prefix test
        # (the * matched the empty string) and rm -rf removed the root.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            keep_file = make_tree(root)
            cases = {
                f'{root}/': root, f'{root}//': root, f'{root}/.': root,
                f'{root}/./': root, f'{root}/..': root.parent,
                f'{root}/a/b': root / 'a' / 'b',
                f'{root}/a/b_abcdef': root / 'a' / 'b_abcdef',
                f'{root}/a/../a/b_abcdef': root / 'a' / 'b_abcdef',
                f'{root}/keep_me': root / 'keep_me',
                f'{root}/keep_me/': root / 'keep_me',
                f'{root}//keep_me': root / 'keep_me',
                f'{root}/venv_copy': root / 'venv_copy',
                f'{root}/file_abcdef': root / 'file_abcdef',
                'keep_me': root / 'keep_me',
                '/': Path('/'),
            }
            for target, must_survive in cases.items():
                with self.subTest(target=target):
                    r = run_bash('cd "$RAC_SCRATCH"; rac_scratch_remove "$1"',
                                 root, target)
                    self.assertEqual(r.returncode, 2, r.stderr)
                    self.assertTrue(must_survive.exists())
                    self.assertTrue(keep_file.is_file())
            self.assertTrue((root / 'venv_copy' / 'bin').is_dir())

    def test_empty_name_does_not_wipe_the_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            keep_file = make_tree(root)
            r = run_bash('run=$(rac_scratch_new probe); name=""; '
                         'rac_scratch_remove "$RAC_SCRATCH/$name"', root)
            self.assertEqual(r.returncode, 2)
            self.assertIn('refusing', r.stderr)
            self.assertTrue(keep_file.is_file())
            self.assertEqual(len(list(root.glob('probe_*'))), 1)

    def test_remove_refuses_a_symlink(self):
        with tempfile.TemporaryDirectory() as tmp, \
                tempfile.TemporaryDirectory() as other:
            root = Path(tmp).resolve()
            target = Path(other) / 'file.txt'
            target.write_text('other\n')
            link = root / 'link_abcdef'
            link.symlink_to(other, target_is_directory=True)
            for arg in (link, f'{link}/'):
                with self.subTest(arg=str(arg)):
                    r = run_bash('rac_scratch_remove "$1"', root, arg)
                    self.assertEqual(r.returncode, 2)
                    self.assertIn('symlink', r.stderr)
                    self.assertTrue(link.is_symlink())
                    self.assertTrue(target.is_file())

    def test_remove_ignores_a_later_change_of_rac_scratch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            keep_file = make_tree(root)
            r = run_bash('RAC_SCRATCH=""; rac_scratch_remove "/x_abcdef"; ',
                         root)
            self.assertEqual(r.returncode, 2)
            r = run_bash(f'RAC_SCRATCH="{root}/a"; '
                         'rac_scratch_remove "$RAC_SCRATCH/b_abcdef"', root)
            self.assertEqual(r.returncode, 2)
            self.assertTrue((root / 'a' / 'b_abcdef').is_dir())
            self.assertTrue(keep_file.is_file())

    def test_remove_run_with_trailing_slash_spares_siblings(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            keep_file = make_tree(root)
            r = run_bash('a=$(rac_scratch_new run); b=$(rac_scratch_new run);'
                         ' mkdir "$a/sub"; touch "$a/sub/x"; '
                         'rac_scratch_remove "$a/"; test ! -e "$a"; '
                         'test -d "$b"; echo "$b"', root)
            self.assertEqual(r.returncode, 0, r.stderr)
            survivors = sorted(p.name for p in root.iterdir())
            self.assertEqual(
                survivors, sorted(['a', 'file_abcdef', 'keep_me',
                                   'venv_copy', Path(r.stdout.strip()).name]))
            self.assertTrue(keep_file.is_file())

    def test_bad_run_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            r = run_bash('rac_scratch_new "../escape"', tmp)
            self.assertNotEqual(r.returncode, 0)
            self.assertEqual(list(Path(tmp).iterdir()), [])


if __name__ == '__main__':
    unittest.main()
