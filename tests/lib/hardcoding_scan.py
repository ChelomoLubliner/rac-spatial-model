"""Scanner for dataset literals in code (plan T2 step 1; decisions A-035,
A-072). Used by tests/python/test_no_hardcoding.py; tests/r/
test_no_hardcoding.R applies the same rules to R in R.

A grep cannot prove that a profile value is used (the sentinel tests do
that), but it stops a dataset constant or a fixed path from coming back:
  DATASET_NUMBERS  the dimensions and counts of both datasets (OLD 307 x 395,
                   387 shoes, 386 with RACs, index 126 of shoe 127; NEW
                   255 x 367, 631 shoes) and the OLD pixel scale 150 / 300
  CONSTANTS        values the profile supplies (stamp threshold, prototype
                   threshold, snake init, seed, number of controls)
  PARENT_PATHS     the legacy relative paths ../images/, ../data/, ../Data/
  OUTPUT_PATHS     a string literal that names a data or output location
                   (only in the pipeline code, where the profile gives all
                   paths)
Comments are not code: Python comments and docstrings, R and shell
comments, and the text outside the code chunks of an Rmd are removed
before the scan. A line whose comment holds `rac: literal-ok` is exempt
(for a value that only looks like a dataset number, e.g. the 8-bit colour
255). The profile files themselves are not scanned.
"""

import ast
import io
import re
import subprocess
import tokenize
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PROFILE_FILES = {'config/datasets.json', 'contour_algorithm/profiles.py',
                 'statistical_model/R/profile.R'}
PIPELINE_DIRS = ('contour_algorithm/', 'statistical_model/', 'tools/')
SCANNED_DIRS = PIPELINE_DIRS + ('tests/',)
MARKER = 'rac: literal-ok'

DATASET_NUMBERS = re.compile(
    r'(?<![\w.$])(?:307|395|387|386|255|367|631|126|150|300)(?![\w.])')
CONSTANTS = [
    ('stamp threshold', re.compile(r'allcont\s*>=\s*\d')),
    ('prototype threshold', re.compile(r'max_pix\s*==\s*\d')),
    ('snake init', re.compile(
        r'(?:200\s*\+\s*162|155\s*\+\s*90|185\s*\+\s*162|128\s*\+\s*95)')),
    ('seed 313', re.compile(r'set\.seed\(\s*313\s*\)')),
    ('controls', re.compile(r'N_CONTROLS\s*<-\s*\d')),
]
PIPELINE_CONSTANTS = [
    ('seed literal', re.compile(r'set\.seed\(\s*\d')),
]
PARENT_PATHS = re.compile(r'\.\./(?:images|data|Data)/')
_QUOTED = re.compile(r'"[^"\n]*"|\'[^\'\n]*\'')
OUTPUT_PATHS = re.compile(
    r'processed_data|saved_models|model_images|images_new|'
    r'(?:^|[/"\'])(?:data|images)/|\w\.(?:csv|rds|pdf|npy|png|txt|html)\b')


def code_files(suffixes):
    """Tracked and new (not ignored) files under SCANNED_DIRS."""
    out = subprocess.run(
        ['git', '-C', str(REPO), 'ls-files', '-co', '--exclude-standard'],
        check=True, capture_output=True, text=True).stdout.splitlines()
    return sorted(f for f in set(out)
                  if f.startswith(SCANNED_DIRS) and f.endswith(suffixes)
                  and f not in PROFILE_FILES and (REPO / f).is_file())


def python_code_lines(text):
    """{line number: code} without comments, docstrings or bare strings;
    lines with the exemption marker dropped."""
    lines = text.splitlines()
    blank = set()
    for node in ast.walk(ast.parse(text)):
        if (isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant)
                and isinstance(node.value.value, str)):
            blank.update(range(node.lineno, node.end_lineno + 1))
    cut = {}
    exempt = set()
    for tok in tokenize.generate_tokens(io.StringIO(text).readline):
        if tok.type == tokenize.COMMENT:
            row, col = tok.start
            cut[row] = col
            if MARKER in tok.string:
                exempt.add(row)
    out = {}
    for i, line in enumerate(lines, start=1):
        if i in blank or i in exempt:
            continue
        out[i] = line[:cut.get(i, len(line))]
    return out


def _strip_hash_comment(line, shell=False):
    """The line without its # comment (a # outside quotes; in shell only at
    the start or after a space)."""
    quote = None
    for k, ch in enumerate(line):
        if quote:
            if ch == '\\':
                continue
            if ch == quote:
                quote = None
        elif ch in ('"', "'"):
            quote = ch
        elif ch == '#' and (not shell or k == 0 or line[k - 1].isspace()):
            return line[:k], line[k:]
    return line, ''


def hash_code_lines(text, shell=False, rmd=False):
    """{line number: code} of R, Rmd (code chunks only) or shell text."""
    out = {}
    in_chunk = not rmd
    for i, line in enumerate(text.splitlines(), start=1):
        if rmd:
            if re.match(r'^\s*```\s*\{r', line):
                in_chunk = True
                continue
            if in_chunk and re.match(r'^\s*```\s*$', line):
                in_chunk = False
                continue
        if not in_chunk:
            continue
        code, comment = _strip_hash_comment(line, shell=shell)
        if MARKER in comment:
            continue
        out[i] = code
    return out


def code_lines(path):
    text = (REPO / path).read_text()
    if path.endswith('.py'):
        return python_code_lines(text)
    return hash_code_lines(text, shell=path.endswith('.sh'),
                           rmd=path.endswith('.Rmd'))


def findings(path):
    """[(line, kind, text)] of the dataset literals in the code of path."""
    pipeline = path.startswith(PIPELINE_DIRS)
    out = []
    for i, code in code_lines(path).items():
        if DATASET_NUMBERS.search(code):
            out.append((i, 'dataset number', code.strip()))
        for name, rx in CONSTANTS + (PIPELINE_CONSTANTS if pipeline else []):
            if rx.search(code):
                out.append((i, name, code.strip()))
        if PARENT_PATHS.search(code):
            out.append((i, 'parent path', code.strip()))
        if pipeline and not path.endswith('.sh'):
            for s in _QUOTED.findall(code):
                if OUTPUT_PATHS.search(s):
                    out.append((i, 'output path', code.strip()))
                    break
    return out


if __name__ == '__main__':
    import sys
    for f in code_files(tuple(sys.argv[1:]) or ('.py', '.sh', '.R', '.Rmd')):
        for line, kind, text in findings(f):
            print(f'{f}:{line}: {kind}: {text[:90]}')
