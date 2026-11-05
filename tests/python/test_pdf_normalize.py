"""tests/lib/pdf_normalize.py: hashes ignore only the embedded dates."""

import tempfile
import unittest
from pathlib import Path

from tests.lib import pdf_normalize

INFO = (b'1 0 obj\n<<\n/CreationDate (D:%s)\n/ModDate (D:%s)\n'
        b'/Title (R Graphics Output)\n/Producer (R 4.3.3)\n>>\nendobj\n')


def fake_pdf(date, body=b'BT /F1 12 Tf (x) Tj ET'):
    return b'%PDF-1.4\n' + INFO % (date, date) + body + b'\n%%EOF\n'


class Normalize(unittest.TestCase):

    def test_dates_are_ignored(self):
        a = pdf_normalize.normalized_bytes(fake_pdf(b'20260316125710'))
        b = pdf_normalize.normalized_bytes(fake_pdf(b'20261105235959'))
        self.assertEqual(a, b)
        self.assertIn(b'/CreationDate ()', a)
        self.assertIn(b'/ModDate ()', a)
        self.assertIn(b'/Producer (R 4.3.3)', a)

    def test_content_and_producer_are_kept(self):
        a = pdf_normalize.normalized_bytes(fake_pdf(b'20260316125710'))
        b = pdf_normalize.normalized_bytes(
            fake_pdf(b'20260316125710', body=b'BT (y) Tj ET'))
        c = pdf_normalize.normalized_bytes(
            fake_pdf(b'20260316125710').replace(b'R 4.3.3', b'R 4.4.3'))
        self.assertNotEqual(a, b)
        self.assertNotEqual(a, c)

    def test_escaped_parenthesis_in_date(self):
        raw = b'/CreationDate (D:2026\\)x) rest'
        self.assertEqual(pdf_normalize.normalized_bytes(raw),
                         b'/CreationDate () rest')

    def test_file_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            p1, p2 = Path(tmp, 'a.pdf'), Path(tmp, 'b.pdf')
            p1.write_bytes(fake_pdf(b'20260316125710'))
            p2.write_bytes(fake_pdf(b'20261105000000'))
            self.assertEqual(pdf_normalize.normalized_sha256(p1),
                             pdf_normalize.normalized_sha256(p2))
            self.assertEqual(len(pdf_normalize.normalized_sha256(p1)), 64)


if __name__ == '__main__':
    unittest.main()
