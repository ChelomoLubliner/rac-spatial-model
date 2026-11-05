"""Compare a legacy Python contour run with the committed OLD files.

Plan T1 step 3. Reads only; writes the Tier B hash files when asked.

Usage (thesis venv python, from the repo root):
  python -B tests/lib/compare_legacy_python.py RUN_DIR \
      [--thesis-images DIR] [--write-tier-b DIR]

RUN_DIR is a folder made by tests/legacy/run_legacy_python.sh. Checks:
  1. data/contour_Active_Contour.txt of the run vs the committed one:
     raw sha256, sha256 after LF -> CRLF, per-record pixel differences.
  2. images/saved/freq_min_18.png vs data/freq_min_18.png (bytes, pixels),
     and the 4-connected inner boundary of the regenerated mask vs
     data/contour_prototype.png (pixels).
  3. With --thesis-images (the thesis images/ folder of the 2025-11-13
     run, read-only): every saved .npy (array and bytes) and every per-shoe
     PNG (pixels and bytes).
With --write-tier-b DIR: python_contour.sha256 and
python_intermediates.sha256 (paths relative to RUN_DIR; the plotly HTML
files are not hashed: plotly gives every figure a random div id).
"""

import argparse
import hashlib
import sys
from pathlib import Path

import numpy as np
from PIL import Image

W, H = 307, 395
N_RECORDS = 386
SKIPPED_IDX0 = 126  # shoe 127 has no RACs; the contour file has no record
PER_SHOE_DIRS = (
    ('shoes', 'im{}.png'),
    ('shoe_on_prototype', 'im_{}.png'),
    ('cleaned_shoes', 'im_{}.png'),
    ('active-contour', 'im_{}.png'),
)
SAVED_NPY = ('list_matrices.npy', 'old_freq_min_18.npy', 'freq_min_18.npy',
             'list_contour.npy', 'active-contour_all.npy')
SAVED_PNG = ('all_shoes_superposed.png', 'old_freq_min_18.png',
             'freq_min_18.png')


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    return sha256_bytes(Path(path).read_bytes())


def read_records(data, width, height):
    """Parse a fixed-stride 0/1 file with LF or CRLF separators.

    Returns (records as uint8 array (n, height, width), separator bytes).
    Raises ValueError if the layout is not a whole number of records with
    one consistent separator, or if a byte is not '0' or '1'.
    """
    size = width * height
    for sep in (b'\r\n', b'\n'):
        stride = size + len(sep)
        if len(data) % stride:
            continue
        n = len(data) // stride
        arr = np.frombuffer(data, dtype=np.uint8).reshape(n, stride)
        if not np.all(arr[:, size:] == np.frombuffer(sep, dtype=np.uint8)):
            continue
        body = arr[:, :size]
        if not np.all((body == 48) | (body == 49)):
            raise ValueError('bytes other than 0/1 in the records')
        return (body - 48).reshape(n, height, width), sep
    raise ValueError('not a fixed-stride file with LF or CRLF separators')


def inner_boundary4(mask):
    """Pixels of mask with at least one 4-neighbour outside it."""
    m = np.asarray(mask, dtype=bool)
    p = np.pad(m, 1, constant_values=False)
    interior = (p[1:-1, 1:-1] & p[:-2, 1:-1] & p[2:, 1:-1]
                & p[1:-1, :-2] & p[1:-1, 2:])
    return m & ~interior


def png_bool(path):
    return np.array(Image.open(path).convert('L')) > 0


def compare_contour(run, repo, out):
    committed = (repo / 'data/contour_Active_Contour.txt').read_bytes()
    regen_path = run / 'data/contour_Active_Contour.txt'
    regen = regen_path.read_bytes()
    a, sep_a = read_records(committed, W, H)
    b, sep_b = read_records(regen, W, H)
    out.append('## contour txt')
    out.append(f'committed: {len(committed)} bytes, {a.shape[0]} records, '
               f'separator {sep_a!r}, sha256 {sha256_bytes(committed)}')
    out.append(f'regenerated: {len(regen)} bytes, {b.shape[0]} records, '
               f'separator {sep_b!r}, sha256 {sha256_bytes(regen)}')
    as_crlf = regen.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
    out.append('regenerated with LF -> CRLF: sha256 '
               f'{sha256_bytes(as_crlf)}; equals committed bytes: '
               f'{as_crlf == committed}')
    same_n = a.shape == b.shape
    out.append(f'same number of records: {same_n}')
    if not same_n:
        return False
    diff = (a != b).reshape(a.shape[0], -1).sum(axis=1)
    bad = np.flatnonzero(diff)
    out.append(f'records with any differing pixel: {bad.size} of '
               f'{a.shape[0]}; total differing pixels: {int(diff.sum())}')
    for k in bad[:50]:
        shoe = k + 1 if k < SKIPPED_IDX0 else k + 2
        out.append(f'  record {k + 1} (shoe {shoe}): {int(diff[k])} px '
                   f'(committed {int(a[k].sum())}, regenerated '
                   f'{int(b[k].sum())} contour px)')
    contour_px = a.reshape(a.shape[0], -1).sum(axis=1)
    out.append(f'committed contour px per record: min {contour_px.min()}, '
               f'median {int(np.median(contour_px))}, max {contour_px.max()}')
    return bad.size == 0 and as_crlf == committed


def compare_masks(run, repo, out):
    out.append('## prototype masks')
    ok = True
    c_path = repo / 'data/freq_min_18.png'
    r_path = run / 'images/saved/freq_min_18.png'
    c, r = png_bool(c_path), png_bool(r_path)
    same_bytes = c_path.read_bytes() == r_path.read_bytes()
    out.append(f'freq_min_18.png: bytes equal {same_bytes} '
               f'({c_path.stat().st_size} vs {r_path.stat().st_size} bytes); '
               f'pixels equal {np.array_equal(c, r)}; differing px '
               f'{int((c != r).sum())}; mask px {int(c.sum())} vs '
               f'{int(r.sum())}')
    ok &= np.array_equal(c, r)
    npy = np.load(run / 'images/saved/freq_min_18.npy')
    out.append('images/saved/freq_min_18.npy equals the committed PNG '
               f'pixels: {np.array_equal(npy, c)}')
    ok &= np.array_equal(npy, c)
    proto = png_bool(repo / 'data/contour_prototype.png')
    b_committed = inner_boundary4(c)
    b_regen = inner_boundary4(r)
    out.append('contour_prototype.png == inner 4-boundary of the committed '
               f'mask: {np.array_equal(proto, b_committed)} '
               f'({int(proto.sum())} px)')
    out.append('contour_prototype.png == inner 4-boundary of the '
               f'regenerated mask: {np.array_equal(proto, b_regen)}; '
               f'differing px {int((proto != b_regen).sum())}')
    ok &= np.array_equal(proto, b_regen)
    return bool(ok)


def compare_thesis(run, thesis, out):
    out.append('## intermediates vs the thesis run (read-only)')
    ok = True
    for name in SAVED_NPY:
        a = np.load(run / 'images/saved' / name)
        b = np.load(thesis / 'saved' / name)
        same_arr = a.shape == b.shape and np.array_equal(a, b)
        same_bytes = (sha256_file(run / 'images/saved' / name)
                      == sha256_file(thesis / 'saved' / name))
        out.append(f'{name}: array equal {same_arr}, bytes equal '
                   f'{same_bytes}, shape {a.shape}')
        ok &= same_arr
    for name in SAVED_PNG:
        a = np.array(Image.open(run / 'images/saved' / name))
        b = np.array(Image.open(thesis / 'saved' / name))
        same_bytes = (sha256_file(run / 'images/saved' / name)
                      == sha256_file(thesis / 'saved' / name))
        out.append(f'{name}: pixels equal {np.array_equal(a, b)}, bytes '
                   f'equal {same_bytes}')
        ok &= np.array_equal(a, b)
    for sub, pattern in PER_SHOE_DIRS:
        px_diff, byte_same, n = [], 0, 0
        for i in range(387):
            pa = run / 'images' / sub / pattern.format(i)
            pb = thesis / sub / pattern.format(i)
            a, b = np.array(Image.open(pa)), np.array(Image.open(pb))
            n += 1
            if a.shape != b.shape or not np.array_equal(a, b):
                px_diff.append(i)
            byte_same += pa.read_bytes() == pb.read_bytes()
        out.append(f'{sub}/: {n} images; pixels differ in {len(px_diff)} '
                   f'{px_diff[:20]}; bytes equal in {byte_same}')
        ok &= not px_diff
    return bool(ok)


def write_tier_b(run, dest):
    dest.mkdir(parents=True, exist_ok=True)
    contour = run / 'data/contour_Active_Contour.txt'
    lines = [f'{sha256_file(contour)}  data/contour_Active_Contour.txt']
    lf = contour.read_bytes().replace(b'\r\n', b'\n')
    crlf = lf.replace(b'\n', b'\r\n')
    lines.append(f'{sha256_bytes(crlf)}  data/contour_Active_Contour.txt '
                 '[LF->CRLF]')
    (dest / 'python_contour.sha256').write_text('\n'.join(lines) + '\n')
    rel = sorted(p.relative_to(run) for p in (run / 'images').rglob('*')
                 if p.is_file() and p.suffix in ('.npy', '.png'))
    with open(dest / 'python_intermediates.sha256', 'w') as f:
        for p in rel:
            f.write(f'{sha256_file(run / p)}  {p.as_posix()}\n')
    return len(rel)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('run', type=Path)
    ap.add_argument('--repo', type=Path,
                    default=Path(__file__).resolve().parents[2])
    ap.add_argument('--thesis-images', type=Path)
    ap.add_argument('--write-tier-b', type=Path)
    args = ap.parse_args(argv)
    out = [f'# legacy Python run {args.run}']
    ok_contour = compare_contour(args.run, args.repo, out)
    ok_masks = compare_masks(args.run, args.repo, out)
    ok_thesis = True
    if args.thesis_images:
        ok_thesis = compare_thesis(args.run, args.thesis_images, out)
    if args.write_tier_b:
        n = write_tier_b(args.run, args.write_tier_b)
        out.append(f'## Tier B written to {args.write_tier_b} ({n} '
                   'intermediate files hashed)')
    out.append(f'RESULT contour_identical={ok_contour} masks_identical='
               f'{ok_masks} thesis_intermediates_identical={ok_thesis}')
    print('\n'.join(out))
    return 0 if (ok_contour and ok_masks and ok_thesis) else 1


if __name__ == '__main__':
    sys.exit(main())
