"""SHA-256 of a PDF without its embedded dates (plan T1, section 4.5).

R's pdf() device writes `/CreationDate (D:...)` and `/ModDate (D:...)` into
the document information dictionary, so two renders of the same figure
differ in bytes. `normalized_sha256` hashes the file after replacing each
of those values by `()`. R writes them with a fixed width, so the xref
offsets of two renders still agree. Everything else, the `/Producer (R x.y.z)`
string included, stays in the hash: PDFs written by another R version do
not compare equal, by design (plan F20).

CLI: python tests/lib/pdf_normalize.py FILE... (prints sha256sum lines).
"""

import hashlib
import re
import sys

_DATE = re.compile(rb'/(CreationDate|ModDate)\s*\((?:[^()\\]|\\.)*\)')


def normalized_bytes(data: bytes) -> bytes:
    """Return the PDF bytes with every CreationDate/ModDate value emptied."""
    return _DATE.sub(lambda m: b'/' + m.group(1) + b' ()', data)


def normalized_sha256(path: str) -> str:
    """SHA-256 hex digest of the PDF at path after normalized_bytes()."""
    with open(path, 'rb') as f:
        return hashlib.sha256(normalized_bytes(f.read())).hexdigest()


def main(argv):
    for p in argv:
        print(f'{normalized_sha256(p)}  {p}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
