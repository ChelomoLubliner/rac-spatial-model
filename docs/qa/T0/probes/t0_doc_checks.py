"""T0 checks of the plan document itself (stdlib only, run from repo root).

    python3 docs/qa/T0/probes/t0_doc_checks.py

1. Every tracked artifact under data/, processed_data/, saved_models/,
   model_images/ and reports/ appears in the plan's file-naming table.
2. Every NEW output path in the table has a 'new' folder component
   ('new', 'new_shoes' or 'images_new') and a file stem ending in '_new'
   (raw inputs, whose names are fixed, are exempt).
3. The mermaid block has balanced 'subgraph' / 'end' lines.
"""
import re
import subprocess

PLAN = 'docs/plans/2026-11-05-new-shoes-pipeline.md'
RAW_INPUTS = {'data/new_shoes/locations_data_new_raw.txt',
              'data/new_shoes/locations_new_snake_2023.csv'}
NEW_FOLDERS = ('new', 'new_shoes', 'images_new')

plan = open(PLAN).read()
section = plan.split('## 5. File naming')[1].split('## 6.')[0]
rows = [r for r in section.splitlines()
        if r.startswith('| ') and '---' not in r][1:]
tick = re.compile(r'`([^`]+)`')
old_paths, new_paths = [], []
for row in rows:
    cells = [c.strip() for c in row.strip('|').split('|')]
    old_paths += tick.findall(cells[2])
    new_paths += [(p, cells[0]) for p in tick.findall(cells[3])]

tracked = subprocess.run(
    ['git', 'ls-files', 'data', 'processed_data', 'saved_models',
     'model_images', 'reports'],
    capture_output=True, text=True, check=True).stdout.split()
old_text = ' '.join(old_paths)
missing = []
for path in tracked:
    if path.startswith('data/new_shoes/'):
        covered = (any(path == p for p, _ in new_paths)
                   or path.endswith('README.md'))
    else:
        covered = path in old_text
    if not covered:
        missing.append(path)
print(f'1. tracked artifacts: {len(tracked)} | missing from the table: '
      f'{missing}')

bad = []
for path, step in new_paths:
    if path in RAW_INPUTS:
        continue
    parts = path.split('/')
    stem = parts[-1].split('.')[0]
    if not (any(x in NEW_FOLDERS for x in parts[:-1])
            and stem.endswith('_new')):
        bad.append((step, path))
print(f'2. NEW paths in the table: {len(new_paths)} | violating the rule: '
      f'{bad}')

mermaid = plan.split('```mermaid')[1].split('```')[0]
n_sub = len(re.findall(r'^\s*subgraph ', mermaid, re.M))
n_end = len(re.findall(r'^\s*end\s*$', mermaid, re.M))
n_nodes = mermaid.count('["')
n_edges = mermaid.count('-->')
print(f'3. mermaid: subgraph={n_sub} end={n_end} labelled nodes={n_nodes} '
      f'edges={n_edges}')
ok = not missing and not bad and n_sub == n_end
print('RESULT:', 'PASS' if ok else 'FAIL')
raise SystemExit(0 if ok else 1)
