"""RAC location files (step 0; T3 extends and tests them for NEW).

`read_locations(profile)` returns the RAC table of a dataset: the OLD CSV
as it is (shoe, x, y, type, orientation, grade); the NEW raw file
(space-separated, no header: shoe rac_num x y type) as columns shoe,
rac_num, x, y, type. x and y are divided by `coords.divisor` (NEW raw
coordinates are 2 times the OLD scale, plan F4). `shoe` is the 1-based
shoe id.

The contour file has no record for a shoe without RACs (OLD shoe 127) or
excluded by a decision (`excluded_shoes`). `record_skip_idx0` computes the
shoes without RACs from the locations, checks them against the profile's
`shoes_without_racs` and returns the 0-based indices of every shoe without
a record, so no index is hard-coded (the legacy code skipped index 126 for
any dataset).

T3 (decision A-088): `derived_csv_bytes(profile)` turns the NEW raw file
into a CSV in the column format of the OLD `data/locations_data.csv`
(shoe, x, y, type; plus rac_num, the raw file's RAC number; the OLD
columns orientation and grade do not exist in the NEW data), with x and y
divided by `coords.divisor` in exact decimal arithmetic and written with a
fixed number of decimals (7 for NEW: the raw file has 6), LF line endings.
Every value is the exact decimal of the half, so it parses to the same
double as the raw value divided by 2 (halving a double is exact). The
pipeline keeps reading the raw file through `read_locations` (plan 4.3);
the tests show that both give the same values. Command line (writes the
profile's `prep.locations_csv`; `--check` compares instead of writing):

    RAC_DATASET=new python -m contour_algorithm.locations [--check]
"""

import argparse
import decimal
import sys

import pandas as pd

from .profiles import env, load_profile

CSV_COLUMNS = ('shoe', 'x', 'y', 'type', 'rac_num')


def read_locations(profile):
    """RAC table of the profile's dataset (shoe ids 1-based)."""
    fmt = profile.locations_format
    if fmt == 'csv':
        locations = pd.read_csv(profile.locations)
    elif fmt == 'space_no_header':
        # a leading space makes column 0 empty; some lines end with a space
        locations = pd.read_csv(profile.locations, sep=' ', header=None)
        locations = locations[[1, 2, 3, 4, 5]]
        locations.columns = ['shoe', 'rac_num', 'x', 'y', 'type']
    else:
        raise ValueError(f'unknown locations format {fmt!r}')
    divisor = profile.coords.divisor
    if divisor != 1:
        locations['x'] = locations['x'] / divisor
        locations['y'] = locations['y'] / divisor
    shoes = locations['shoe']
    if shoes.isna().any() or not ((shoes >= 1)
                                  & (shoes <= profile.num_shoe)).all():
        raise ValueError(f'{profile.locations}: shoe ids outside 1..'
                         f'{profile.num_shoe}')
    return locations


def shoes_without_racs(profile, locations):
    """1-based ids of the shoes that have no RAC in `locations`."""
    have = set(int(s) for s in locations['shoe'].unique())
    return tuple(s for s in range(1, profile.num_shoe + 1) if s not in have)


def record_skip_idx0(profile, locations=None):
    """0-based image indices of the shoes without a contour record: the
    shoes without RACs (computed from the locations and required to equal
    the profile's shoes_without_racs) and the excluded shoes."""
    if locations is None:
        locations = read_locations(profile)
    computed = shoes_without_racs(profile, locations)
    if computed != tuple(profile.shoes_without_racs):
        raise ValueError(
            f'{profile.dataset} profile: shoes_without_racs is '
            f'{list(profile.shoes_without_racs)}, but the shoes without '
            f'RACs in {profile.locations.name} are {list(computed)}')
    return tuple(sorted(s - 1 for s in set(computed)
                        | set(profile.excluded_shoes)))


def _raw_records(profile):
    """[(shoe, rac_num, x_text, y_text, type)] of the raw space-separated
    file (a leading space, CRLF line ends, one line with a trailing
    space), every field checked."""
    if profile.locations_format != 'space_no_header':
        raise ValueError(f'{profile.dataset} profile: no raw locations file '
                         f'to derive a CSV from')
    out = []
    lines = profile.locations.read_bytes().decode('ascii').splitlines()
    for k, line in enumerate(lines, start=1):
        fields = line.split()
        if len(fields) != 5:
            raise ValueError(f'{profile.locations}:{k}: {len(fields)} '
                             'fields, not 5')
        shoe, rac, x, y, typ = fields
        for name, v in (('shoe', shoe), ('rac_num', rac), ('type', typ)):
            if not v.isdigit():
                raise ValueError(f'{profile.locations}:{k}: {name} {v!r}')
        out.append((int(shoe), int(rac), x, y, int(typ)))
    return out


def _exact_quotients(texts, divisor):
    """The exact decimal quotients text / divisor (decimal.Inexact is an
    error) and the number of decimals that writes all of them exactly."""
    ctx = decimal.Context(prec=50, traps=[decimal.Inexact,
                                          decimal.InvalidOperation])
    div = decimal.Decimal(str(divisor))
    values = [ctx.divide(decimal.Decimal(t), div) for t in texts]
    places = max(max(0, -v.as_tuple().exponent) for v in values)
    return values, places


def derived_csv_bytes(profile):
    """The derived locations CSV of a profile with a raw locations file:
    header shoe,x,y,type,rac_num, one row per RAC in file order, x and y
    divided by coords.divisor exactly, LF line endings."""
    recs = _raw_records(profile)
    divisor = profile.coords.divisor
    xs, px = _exact_quotients([r[2] for r in recs], divisor)
    ys, py = _exact_quotients([r[3] for r in recs], divisor)
    q = {'x': decimal.Decimal(1).scaleb(-px),
         'y': decimal.Decimal(1).scaleb(-py)}
    ctx = decimal.Context(prec=50, traps=[decimal.Inexact])
    rows = [','.join(CSV_COLUMNS)]
    for (shoe, rac, _, _, typ), x, y in zip(recs, xs, ys):
        xq = x.quantize(q['x'], context=ctx)
        yq = y.quantize(q['y'], context=ctx)
        rows.append(f'{shoe},{xq:f},{yq:f},{typ},{rac}')
    return ('\n'.join(rows) + '\n').encode('ascii')


def write_derived_csv(profile, path=None):
    """Write the derived locations CSV to `path` (default: the profile's
    prep.locations_csv); return the path."""
    if path is None:
        path = profile.prep_path('locations_csv')
        if path is None:
            raise ValueError(f'the {profile.dataset} profile has no '
                             'prep.locations_csv')
    data = derived_csv_bytes(profile)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def main(argv=None):
    if env('RAC_PROFILE_FILE', None) is not None:
        print('contour_algorithm.locations: RAC_PROFILE_FILE is set; it is a '
              'test hook and a real run refuses it (decision A-049)',
              file=sys.stderr)
        return 2
    parser = argparse.ArgumentParser(
        prog='python -m contour_algorithm.locations',
        description='Write (or --check) the derived locations CSV of the '
                    'RAC_DATASET profile.')
    parser.add_argument('--check', action='store_true',
                        help='compare the existing file with a fresh build')
    args = parser.parse_args(argv)
    try:
        profile = load_profile()
        target = profile.prep_path('locations_csv')
        if target is None:
            raise ValueError(f'the {profile.dataset} profile has no derived '
                             'locations CSV (prep.locations_csv is null)')
        data = derived_csv_bytes(profile)
    except ValueError as e:
        print(f'contour_algorithm.locations: {e}', file=sys.stderr)
        return 2
    if args.check:
        same = target.exists() and target.read_bytes() == data
        print(f'{target}: {"identical to" if same else "DIFFERS from"} a '
              'fresh build')
        return 0 if same else 1
    write_derived_csv(profile, target)
    n = data.count(b'\n') - 1
    print(f'wrote {target} ({n} RACs, {len(data)} bytes)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
