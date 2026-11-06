"""tests/lib/scratch.sh guards (plan section 4.5, decisions A-034, A-062,
A-068)."""

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

    def test_new_writes_the_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            r = run_bash('d=$(rac_scratch_new probe); echo "$d"', tmp)
            self.assertEqual(r.returncode, 0, r.stderr)
            made = Path(r.stdout.strip())
            marker = made / '.rac_scratch_run'
            self.assertTrue(marker.is_file())
            self.assertEqual(marker.read_text(), f'{made}\n')

    def test_remove_refuses_handmade_mktemp_shaped_folders(self):
        # T1 review 2 (engineering finding 3): these names have the mktemp
        # shape NAME_XXXXXX, and the shape rule alone accepted them (rc 0).
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            for name in ('legacy_python', 'results_backup', 'tier_b_backup',
                         'gallery_output', 'shoe11_images'):
                folder = root / name
                (folder / 'sub').mkdir(parents=True)
                (folder / 'sub' / 'file.txt').write_text('keep\n')
                with self.subTest(name=name):
                    r = run_bash('rac_scratch_remove "$1"', root, folder)
                    self.assertEqual(r.returncode, 2, r.stderr)
                    self.assertIn('marker', r.stderr)
                    self.assertTrue((folder / 'sub' / 'file.txt').is_file())

    def test_remove_refuses_a_copy_or_a_bad_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            # A copy of a run folder carries a marker that names the
            # original, so the copy is refused and the original is not.
            r = run_bash('a=$(rac_scratch_new run); '
                         'cp -a "$a" "$RAC_SCRATCH/copy_abcdef"; echo "$a"; '
                         'rac_scratch_remove "$RAC_SCRATCH/copy_abcdef"',
                         root)
            self.assertEqual(r.returncode, 2, r.stderr)
            self.assertTrue((root / 'copy_abcdef').is_dir())
            original = Path(r.stdout.strip())
            r = run_bash('rac_scratch_remove "$1"', root, original)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertFalse(original.exists())
            # A run folder whose marker was deleted (for example by an
            # rsync --delete into the run folder), emptied, rewritten or
            # replaced by a symlink is refused.
            other = root / 'elsewhere.txt'
            other.write_text('x\n')
            cases = {
                'deleted': 'rm "$d/.rac_scratch_run"',
                'emptied': ': > "$d/.rac_scratch_run"',
                'rewritten': 'echo "$RAC_SCRATCH" > "$d/.rac_scratch_run"',
                'symlink': ('rm "$d/.rac_scratch_run"; '
                            f'ln -s "{other}" "$d/.rac_scratch_run"'),
                'a directory': ('rm "$d/.rac_scratch_run"; '
                                'mkdir "$d/.rac_scratch_run"'),
            }
            for label, damage in cases.items():
                with self.subTest(marker=label):
                    r = run_bash(f'd=$(rac_scratch_new run); {damage}; '
                                 'echo "$d"; rac_scratch_remove "$d"', root)
                    self.assertEqual(r.returncode, 2, r.stderr)
                    self.assertIn('marker', r.stderr)
                    self.assertTrue(Path(r.stdout.strip()).is_dir())
            self.assertEqual(other.read_text(), 'x\n')

    def test_root_is_readonly(self):
        # T1 review 2: assigning rac_scratch_root moved the deletion scope.
        # Now bash stops the script at the assignment (status 1), so the
        # rm below is never reached.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            (root / 'a' / 'b_abcdef').mkdir(parents=True)
            (root / 'a' / 'b_abcdef' / '.rac_scratch_run').write_text(
                f'{root}/a/b_abcdef\n')
            r = run_bash(f'rac_scratch_root="{root}/a"; echo reached; '
                         'rac_scratch_remove "$RAC_SCRATCH/a/b_abcdef"', root)
            self.assertEqual(r.returncode, 1)
            self.assertIn('readonly variable', r.stderr)
            self.assertNotIn('reached', r.stdout)
            self.assertTrue((root / 'a' / 'b_abcdef').is_dir())

    def test_second_source(self):
        with tempfile.TemporaryDirectory() as tmp, \
                tempfile.TemporaryDirectory() as other:
            root = Path(tmp).resolve()
            # The same root again: accepted, still read-only.
            r = run_bash(f'source "{LIB}"; declare -p rac_scratch_root', root)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn(f'declare -r rac_scratch_root="{root}"', r.stdout)
            # A different root: refused, the first one stays.
            r = run_bash(f'RAC_SCRATCH="{other}"; source "{LIB}"; '
                         'echo reached', root)
            self.assertEqual(r.returncode, 2)
            self.assertIn('already sourced', r.stderr)
            self.assertNotIn('reached', r.stdout)
            # A plain (not read-only) variable set before the first source
            # is replaced by the validated root.
            env = dict(os.environ, RAC_SCRATCH=str(root))
            r = subprocess.run(
                ['bash', '-c', 'rac_scratch_root=/; set -euo pipefail; '
                 f'source "{LIB}"; declare -p rac_scratch_root'],
                env=env, capture_output=True, text=True, timeout=60)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn(f'declare -r rac_scratch_root="{root}"', r.stdout)


if __name__ == '__main__':
    unittest.main()
