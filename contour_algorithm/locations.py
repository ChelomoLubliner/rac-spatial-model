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
"""

import pandas as pd


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
