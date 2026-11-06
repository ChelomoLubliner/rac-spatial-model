"""Column-by-column difference of regenerated T4 QA tables against HEAD
(T5, decision A-110: which columns the NEW stamp threshold changes).

Usage (repo root): python3 docs/qa/T5/probes/t5_t4_table_diff.py RUN_REPO
  RUN_REPO = the repo copy of a tests/rebuild_new.sh run folder
"""
import csv
import io
import subprocess
import sys

FILES = ('docs/qa/T4/new/snake_metrics_new.csv',
         'docs/qa/sheets_new/snake_qa_new.csv',
         'docs/qa/T4/new/mask_threshold_new.csv')


def main(run):
    for f in FILES:
        head = subprocess.run(['git', 'show', f'HEAD:{f}'],
                              capture_output=True, text=True,
                              check=True).stdout
        a = list(csv.DictReader(io.StringIO(head)))
        with open(f'{run}/{f}') as fh:
            b = list(csv.DictReader(fh))
        ca, cb = list(a[0].keys()), list(b[0].keys())
        print(f, 'rows', len(a), len(b), '| columns only in HEAD:',
              [c for c in ca if c not in cb], '| only in new:',
              [c for c in cb if c not in ca])
        changed = {}
        for ra, rb in zip(a, b):
            for c in ca:
                if c in rb and ra[c] != rb[c]:
                    changed.setdefault(c, []).append(
                        (ra.get('shoe', ra.get('threshold')), ra[c], rb[c]))
        for c, v in changed.items():
            print('   changed column', c, 'in', len(v), 'rows; e.g.', v[:4])
        if 'coverage_r' in changed:
            d = [float(x[2]) - float(x[1]) for x in changed['coverage_r']]
            print('   coverage_r change: min', min(d), 'max', max(d))


if __name__ == '__main__':
    main(*sys.argv[1:])
